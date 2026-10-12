import SwiftData
import SwiftUI

@main struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      RootTabView()
    }
    .modelContainer(for: Palette.self)
  }
}

// Only Capture and Library exist so far. Today and Profile are added once
// their features (daily prompt, friends, settings) are built.
private struct RootTabView: View {
  var body: some View {
    TabView {
      CaptureView()
        .tabItem { Label("Capture", systemImage: "camera.fill") }

      NavigationStack {
        LibraryView()
      }
      .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }
    }
  }
}
