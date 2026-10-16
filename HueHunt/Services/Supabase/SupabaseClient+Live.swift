import Foundation
import Supabase

extension SupabaseClient {
  // Reads SUPABASE_URL/SUPABASE_ANON_KEY from Info.plist, populated at build time from
  // Config/Secrets.xcconfig (gitignored, copied from Secrets.xcconfig.example).
  static let live: SupabaseClient = {
    guard
      let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
      let url = URL(string: urlString),
      let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
      !anonKey.isEmpty
    else {
      fatalError(
        "Missing SUPABASE_URL or SUPABASE_ANON_KEY. Copy Config/Secrets.xcconfig.example to "
          + "Config/Secrets.xcconfig and fill in your project's values.")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
  }()
}
