import Foundation
import Supabase

// Wraps Supabase's email OTP (one-time code) sign-in and the username claim that follows a
// first sign-in. The PRD's eventual auth method is Sign in with Apple, but that needs a paid
// Apple Developer Program membership; email OTP exercises the same session/profile flow for
// free until that membership exists, and can be swapped in later without touching callers of
// this type (they only see `session`, `username`, and `isSignedIn`).
@Observable
@MainActor
final class AuthService {
  private(set) var session: Session?
  private(set) var username: String?

  private let client: SupabaseClient
  private var authStateTask: Task<Void, Never>?

  var isSignedIn: Bool { session != nil }
  var needsUsername: Bool { isSignedIn && username == nil }

  // No default for `client`: a default-value expression is type-checked in a nonisolated
  // context even on a @MainActor type, so `= .live` here would warn under strict concurrency.
  // Callers pass `.live` explicitly instead (see MyApp.swift).
  //
  // AuthService lives for the app's whole lifetime (held at the root view), so authStateTask is
  // never explicitly cancelled, there's no shorter-lived owner to cancel it on behalf of.
  init(client: SupabaseClient) {
    self.client = client
    authStateTask = Task { [weak self] in
      guard let self else { return }
      for await (_, session) in client.auth.authStateChanges {
        await self.handle(session: session)
      }
    }
  }

  // Sends a 6-digit sign-in code to the given email. Supabase creates the user on first use.
  func sendSignInCode(to email: String) async throws {
    try await client.auth.signInWithOTP(email: email)
  }

  func verifySignInCode(email: String, code: String) async throws {
    try await client.auth.verifyOTP(email: email, token: code, type: .email)
  }

  func signOut() async throws {
    try await client.auth.signOut()
  }

  func isUsernameAvailable(_ username: String) async throws -> Bool {
    let response =
      try await client
      .from("profiles")
      .select("id", head: true, count: .exact)
      .eq("username", value: username)
      .execute()
    return response.count == 0
  }

  func claimUsername(_ username: String) async throws {
    guard let userID = session?.user.id else { return }
    try await client
      .from("profiles")
      .insert(NewProfile(id: userID, username: username))
      .execute()
    self.username = username
  }

  private func handle(session: Session?) async {
    self.session = session
    guard let session else {
      username = nil
      return
    }
    username = try? await fetchUsername(for: session.user.id)
  }

  private func fetchUsername(for userID: UUID) async throws -> String? {
    let response: PostgrestResponse<[ProfileRow]> =
      try await client
      .from("profiles")
      .select("username")
      .eq("id", value: userID)
      .execute()
    return response.value.first?.username
  }

  private struct ProfileRow: Decodable {
    let username: String
  }

  private struct NewProfile: Encodable {
    let id: UUID
    let username: String
  }
}
