import SwiftData
import SwiftUI

// Settings and account-free housekeeping. Friends and other social features need an
// accounts/backend decision first, so this stays local-only for now.
struct ProfileView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var palettes: [Palette]
  @State private var showingDeleteConfirmation = false

  var body: some View {
    List {
      Section("Library") {
        LabeledContent("Palettes caught", value: "\(palettes.count)")
        Button("Delete All Palettes", role: .destructive) {
          showingDeleteConfirmation = true
        }
        .disabled(palettes.isEmpty)
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
}
