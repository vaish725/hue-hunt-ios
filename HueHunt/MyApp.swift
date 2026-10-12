import SwiftData
import SwiftUI

@main struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      CaptureView()
    }
    .modelContainer(for: Palette.self)
  }
}
