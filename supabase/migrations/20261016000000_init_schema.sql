-- Initial schema for Hue Hunt (PRD section 8.3). Row Level Security is enabled on every table;
-- the client is treated as untrusted and all authorization is enforced here, not in app code.

create table profiles (
  id          uuid primary key references auth.users on delete cascade,
  username    text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  created_at  timestamptz not null default now()
);

create table prompts (
  id           uuid primary key default gen_random_uuid(),
  day          date unique not null,
  text         text not null,
  published_at timestamptz
);

create table palettes (
  id            uuid primary key,                 -- client-generated
  user_id       uuid not null references profiles on delete cascade,
  name          text not null,
  colors        jsonb not null,                   -- [PaletteColor]
  thumbnail_path text,
  prompt_id     uuid references prompts,
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);
create unique index one_submission_per_prompt
  on palettes(user_id, prompt_id) where prompt_id is not null and deleted_at is null;
create index palettes_feed_idx on palettes(prompt_id, created_at desc, id);

create table boards (
  id          uuid primary key,
  user_id     uuid not null references profiles on delete cascade,
  name        text not null,
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  deleted_at  timestamptz
);

create table board_palettes (
  board_id    uuid references boards on delete cascade,
  palette_id  uuid references palettes on delete cascade,
  user_id     uuid not null references profiles on delete cascade,
  primary key (board_id, palette_id)
);

create table friendships (
  requester_id uuid references profiles on delete cascade,
  addressee_id uuid references profiles on delete cascade,
  status       text not null check (status in ('pending','accepted')),
  created_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table blocks (
  blocker_id uuid references profiles on delete cascade,
  blocked_id uuid references profiles on delete cascade,
  primary key (blocker_id, blocked_id)
);

create table likes (
  palette_id uuid references palettes on delete cascade,
  user_id    uuid references profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (palette_id, user_id)
);

create table reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles on delete cascade,
  palette_id  uuid not null references palettes on delete cascade,
  reason      text not null check (reason in ('spam','inappropriate','harassment','other')),
  created_at  timestamptz not null default now()
);

create table device_tokens (
  token      text primary key,
  user_id    uuid not null references profiles on delete cascade,
  notify_prompts boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Helper functions (security definer, stable), used by the RLS policies below.

create function are_friends(a uuid, b uuid) returns boolean
  language sql security definer stable as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester_id = a and addressee_id = b) or (requester_id = b and addressee_id = a))
  )
  and not exists (
    select 1 from blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

create function has_submitted(uid uuid, pid uuid) returns boolean
  language sql security definer stable as $$
  select exists (
    select 1 from palettes
    where user_id = uid and prompt_id = pid and deleted_at is null
  );
$$;

-- Row Level Security: enabled on all tables.

alter table profiles enable row level security;
alter table prompts enable row level security;
alter table palettes enable row level security;
alter table boards enable row level security;
alter table board_palettes enable row level security;
alter table friendships enable row level security;
alter table blocks enable row level security;
alter table likes enable row level security;
alter table reports enable row level security;
alter table device_tokens enable row level security;

-- profiles: select by any authenticated user, update only your own row.
create policy "profiles_select_authenticated" on profiles
  for select to authenticated using (true);
create policy "profiles_update_own" on profiles
  for update to authenticated using (id = auth.uid());
create policy "profiles_insert_own" on profiles
  for insert to authenticated with check (id = auth.uid());

-- prompts: select only published prompts, no client writes.
create policy "prompts_select_published" on prompts
  for select to authenticated using (published_at is not null);

-- palettes: full access to your own rows; friends can see your prompt submissions only after
-- they've submitted their own answer to the same prompt.
create policy "palettes_all_own" on palettes
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "palettes_select_friends_feed" on palettes
  for select to authenticated using (
    prompt_id is not null
    and deleted_at is null
    and are_friends(auth.uid(), user_id)
    and has_submitted(auth.uid(), prompt_id)
  );

-- boards, board_palettes: own rows only.
create policy "boards_all_own" on boards
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "board_palettes_all_own" on board_palettes
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- friendships: either party can read; only the requester can create a pending request; only
-- the addressee can accept; either party can delete (unfriend/decline/cancel).
create policy "friendships_select_either_party" on friendships
  for select to authenticated using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "friendships_insert_as_requester" on friendships
  for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');
create policy "friendships_update_as_addressee" on friendships
  for update to authenticated using (addressee_id = auth.uid());
create policy "friendships_delete_either_party" on friendships
  for delete to authenticated using (requester_id = auth.uid() or addressee_id = auth.uid());

-- blocks: own rows only.
create policy "blocks_all_own" on blocks
  for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- likes: insert/delete your own; select only if the underlying palette is visible to you.
create policy "likes_insert_own" on likes
  for insert to authenticated with check (user_id = auth.uid());
create policy "likes_delete_own" on likes
  for delete to authenticated using (user_id = auth.uid());
create policy "likes_select_if_palette_visible" on likes
  for select to authenticated using (
    exists (
      select 1 from palettes p
      where p.id = likes.palette_id
        and (
          p.user_id = auth.uid()
          or (
            p.prompt_id is not null
            and p.deleted_at is null
            and are_friends(auth.uid(), p.user_id)
            and has_submitted(auth.uid(), p.prompt_id)
          )
        )
    )
  );

-- reports: insert your own, no select (reports are reviewed out of band).
create policy "reports_insert_own" on reports
  for insert to authenticated with check (reporter_id = auth.uid());

-- device_tokens: own rows only.
create policy "device_tokens_all_own" on device_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
