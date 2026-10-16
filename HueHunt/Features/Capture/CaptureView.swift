import PaletteEngine
import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var viewModel = CaptureViewModel()
  @State private var caughtPalette: Palette?
  @State private var catchCount = 0

  var body: some View {
    Group {
      if viewModel.isCameraAccessDenied {
        CameraAccessDeniedView()
      } else {
        CameraPreview(previewLayer: viewModel.previewLayer)
          .ignoresSafeArea()
          .overlay(alignment: .bottom) {
            VStack(spacing: 24) {
              PaletteStrip(colors: viewModel.palette.colors)
              ShutterButton {
                catchCount += 1
                Task { caughtPalette = await viewModel.catchPalette(in: modelContext) }
              }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
          }
          .sensoryFeedback(.impact(weight: .medium), trigger: catchCount)
          .sheet(item: $caughtPalette) { palette in
            NavigationStack {
              PaletteDetailView(palette: palette)
            }
          }
      }
    }
    .task { await viewModel.prepareAndStart() }
    .onDisappear { viewModel.stop() }
  }
}

private struct ShutterButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Circle()
        .strokeBorder(.white, lineWidth: 4)
        .frame(width: 72, height: 72)
        .background(Circle().fill(.white.opacity(0.3)))
    }
  }
}

private struct CameraAccessDeniedView: View {
  var body: some View {
    ContentUnavailableView {
      Label("Camera Access Needed", systemImage: "camera.fill")
    } description: {
      Text("Hue Hunt needs camera access to catch palettes. Enable it in Settings.")
    } actions: {
      Button("Open Settings") {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
      }
    }
  }
}
