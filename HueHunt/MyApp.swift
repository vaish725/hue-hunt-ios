import SwiftData
import SwiftUI

@main struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      RootTabView()
    }
    .modelContainer(for: [Palette.self, Board.self])
  }
}

private struct RootTabView: View {
  @AppStorage("hasOnboarded") private var hasOnboarded = false
  @AppStorage("appearance") private var appearance: AppAppearance = .system
  @AppStorage("tintWithLatestPalette") private var tintWithLatestPalette = true
  @Query(sort: \Palette.createdAt, order: .reverse) private var palettes: [Palette]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @Environment(\.colorScheme) private var colorScheme
  @State private var authService = AuthService(client: .live)

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
    .tint(tintColor)
    .animation(.easeInOut(duration: 0.6), value: tintColor)
    .preferredColorScheme(appearance.colorScheme)
    .environment(authService)
    .fullScreenCover(isPresented: isOnboardingPresented) {
      OnboardingView(onFinished: { hasOnboarded = true })
    }
  }

  // PRD 11.3: off whenever Reduce Motion or Increase Contrast is on, or the user disabled it.
  private var tintColor: Color? {
    guard tintWithLatestPalette, !reduceMotion, colorSchemeContrast == .standard,
      let latest = palettes.first
    else { return nil }
    return PaletteTint.accentColor(
      for: latest.decodedColors, isDarkBackground: colorScheme == .dark)
  }

  private var isOnboardingPresented: Binding<Bool> {
    Binding(get: { !hasOnboarded }, set: { isPresented in hasOnboarded = !isPresented })
  }
}
