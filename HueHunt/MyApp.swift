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

private struct RootTabView: View {
  var body: some View {
    TabView {
      NavigationStack {
        TodayView()
      }
      .tabItem { Label("Today", systemImage: "sun.max.fill") }

      CaptureView()
        .tabItem { Label("Capture", systemImage: "camera.fill") }

      NavigationStack {
        LibraryView()
      }
      .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }

      NavigationStack {
        ProfileView()
      }
      .tabItem { Label("Profile", systemImage: "person.fill") }
    }
  }
}
