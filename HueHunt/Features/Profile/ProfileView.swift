import SwiftData
import SwiftUI

// Account (email sign-in, stands in for Sign in with Apple until there's a paid Apple Developer
// account), library housekeeping, and settings. Friends/feed still need the social schema wired
// up client-side, so they aren't here yet even though sign-in now works.
struct ProfileView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AuthService.self) private var authService
  @Query private var palettes: [Palette]
  @State private var showingDeleteConfirmation = false
  @State private var showingSignOutConfirmation = false

  var body: some View {
    List {
      Section("Account") {
        if authService.needsUsername {
          NavigationLink("Choose a Username") {
            AccountView()
          }
        } else if authService.isSignedIn {
          LabeledContent("Signed in as", value: authService.username ?? "")
          Button("Sign Out", role: .destructive) {
            showingSignOutConfirmation = true
          }
        } else {
          NavigationLink("Sign In") {
            AccountView()
          }
        }
      }

      Section("Library") {
        LabeledContent("Palettes caught", value: "\(palettes.count)")
        Button("Delete All Palettes", role: .destructive) {
          showingDeleteConfirmation = true
        }
        .disabled(palettes.isEmpty)
      }

      Section {
        NavigationLink("Settings") {
          SettingsView()
        }
      }

      Section("About") {
        LabeledContent("Version", value: appVersion)
      }
    }
    .navigationTitle("Profile")
    .confirmationDialog(
      "Delete all palettes? This can't be undone.",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete All Palettes", role: .destructive) {
        for palette in palettes {
          modelContext.delete(palette)
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Sign out?",
      isPresented: $showingSignOutConfirmation,
      titleVisibility: .visible
    ) {
      Button("Sign Out", role: .destructive) {
        Task { try? await authService.signOut() }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
  }
}

#Preview {
  let container = try! ModelContainer(
    for: Palette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  container.mainContext.insert(Palette(name: "Sunset Dock", colorsData: Data(), thumbnail: nil))
  return NavigationStack {
    ProfileView()
  }
  .modelContainer(container)
  .environment(AuthService(client: .live))
}
