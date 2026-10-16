import SwiftUI

// A 3-screen intro followed by a camera permission explainer. Shown once; MyApp gates it behind
// the hasOnboarded flag. Camera access and boards both work without an account (PRD F1).
struct OnboardingView: View {
  let onFinished: () -> Void

  @State private var pageIndex = 0

  private let introPages: [OnboardingPage] = [
    OnboardingPage(
      systemImage: "camera.viewfinder",
      title: "Catch Color From the Real World",
      body: "Point your camera at anything and watch a live 5-color palette update in real time."
    ),
    OnboardingPage(
      systemImage: "square.grid.2x2.fill",
      title: "Build a Library",
      body: "Save the palettes you catch and organize them into boards you can search and sort."
    ),
    OnboardingPage(
      systemImage: "sun.max.fill",
      title: "Hunt Every Day",
      body: "Each day brings a new color to find, right from your own camera."
    ),
  ]

  var body: some View {
    TabView(selection: $pageIndex) {
      ForEach(Array(introPages.enumerated()), id: \.offset) { index, page in
        OnboardingPageView(page: page)
          .tag(index)
      }

      CameraPermissionPageView(onContinue: onFinished)
        .tag(introPages.count)
    }
    .tabViewStyle(.page)
    .indexViewStyle(.page(backgroundDisplayMode: .always))
    .overlay(alignment: .topTrailing) {
      if pageIndex < introPages.count {
        Button("Skip") { pageIndex = introPages.count }
          .padding()
      }
    }
    .animation(.default, value: pageIndex)
  }
}

private struct OnboardingPage {
  let systemImage: String
  let title: String
  let body: String
}

private struct OnboardingPageView: View {
  let page: OnboardingPage

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: page.systemImage)
        .font(.system(size: 72))
        .foregroundStyle(.tint)
      Text(page.title)
        .font(.title.bold())
        .multilineTextAlignment(.center)
      Text(page.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Spacer()
      Spacer()
    }
    .padding(32)
  }
}

private struct CameraPermissionPageView: View {
  let onContinue: () -> Void

  @State private var isRequesting = false

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "camera.fill")
        .font(.system(size: 72))
        .foregroundStyle(.tint)
      Text("Allow Camera Access")
        .font(.title.bold())
        .multilineTextAlignment(.center)
      Text(
        "Hue Hunt reads colors from your camera to build live palettes. Video is processed on your device and never uploaded."
      )
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      Spacer()
      Spacer()
      Button {
        Task {
          isRequesting = true
          _ = await CameraService.requestAccess()
          isRequesting = false
          onContinue()
        }
      } label: {
        Text("Continue")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(isRequesting)
    }
    .padding(32)
  }
}

#Preview {
  OnboardingView(onFinished: {})
}
