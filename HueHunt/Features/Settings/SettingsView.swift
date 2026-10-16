import SwiftUI
import UserNotifications

// Local-only settings (PRD F9): appearance, the palette-tint toggle, and a notifications toggle
// that reserves permission ahead of the daily-prompt backend. Sign out and delete account need
// an account system first, so they aren't here yet.
struct SettingsView: View {
  @AppStorage("appearance") private var appearance: AppAppearance = .system
  @AppStorage("tintWithLatestPalette") private var tintWithLatestPalette = true
  @AppStorage("promptNotificationsEnabled") private var notificationsEnabled = false

  var body: some View {
    List {
      Section("Appearance") {
        Picker("Appearance", selection: $appearance) {
          ForEach(AppAppearance.allCases) { option in
            Text(option.label).tag(option)
          }
        }
      }

      Section {
        Toggle("Tint App With Latest Palette", isOn: $tintWithLatestPalette)
      } footer: {
        Text("Uses a color from your most recently caught palette as the app's accent color.")
      }

      Section {
        Toggle("Daily Prompt Notifications", isOn: $notificationsEnabled)
          .onChange(of: notificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task { await requestNotificationAuthorization() }
          }
      } footer: {
        Text(
          "Hue Hunt doesn't have daily prompts from a server yet. This reserves notification permission for when that feature ships."
        )
      }
    }
    .navigationTitle("Settings")
  }

  private func requestNotificationAuthorization() async {
    _ = try? await UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge])
  }
}

enum AppAppearance: String, CaseIterable, Identifiable {
  case system, light, dark

  var id: Self { self }

  var label: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView()
  }
}
