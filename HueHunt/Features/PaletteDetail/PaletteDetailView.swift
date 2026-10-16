import CoreGraphics
import ImageIO
import PaletteEngine
import SwiftData
import SwiftUI
import UIKit

// Full-screen view for a single caught palette: rename, per-color breakdown, contrast pairs
// against each other (via PaletteEngine's Contrast), and a shareable card image. Reached from
// the Library grid and from the catch confirmation sheet in Capture.
struct PaletteDetailView: View {
  @Bindable var palette: Palette
  @Environment(\.displayScale) private var displayScale
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Board.createdAt, order: .reverse) private var boards: [Board]
  @State private var shareImage: Image?
  @State private var showingDeleteConfirmation = false
  @State private var showingNewBoardPrompt = false
  @State private var newBoardName = ""
  @State private var didCopy = false

  private var colors: [PaletteColor] { palette.decodedColors }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if let thumbnail = palette.thumbnail, let cgImage = Self.makeCGImage(from: thumbnail) {
          Image(cgImage, scale: 1, label: Text(palette.name))
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        TextField("Palette name", text: $palette.name)
          .font(.title2.bold())
          .textFieldStyle(.roundedBorder)

        colorList
        contrastSection
      }
      .padding(16)
    }
    .navigationTitle("Palette")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if let shareImage {
          ShareLink(item: shareImage, preview: SharePreview(palette.name, image: shareImage))
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button {
            copyAllHexValues()
          } label: {
            Label("Copy All Hex Values", systemImage: "doc.on.doc")
          }
          Menu {
            ForEach(boards) { board in
              Button {
                toggle(board)
              } label: {
                if palette.boards.contains(where: { $0.id == board.id }) {
                  Label(board.name, systemImage: "checkmark")
                } else {
                  Text(board.name)
                }
              }
            }
            Button {
              showingNewBoardPrompt = true
            } label: {
              Label("New Board...", systemImage: "plus")
            }
          } label: {
            Label("Add to Board", systemImage: "rectangle.stack.badge.plus")
          }
          Button(role: .destructive) {
            showingDeleteConfirmation = true
          } label: {
            Label("Delete", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .task(id: palette.id) { shareImage = renderShareCard() }
    .sensoryFeedback(.success, trigger: didCopy)
    .confirmationDialog(
      "Delete this palette? This can't be undone.",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        modelContext.delete(palette)
        dismiss()
      }
      Button("Cancel", role: .cancel) {}
    }
    .alert("New Board", isPresented: $showingNewBoardPrompt) {
      TextField("Board name", text: $newBoardName)
      Button("Cancel", role: .cancel) { newBoardName = "" }
      Button("Create") {
        let trimmed = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          let board = Board(name: trimmed)
          modelContext.insert(board)
          palette.boards.append(board)
        }
        newBoardName = ""
      }
    }
  }

  private func toggle(_ board: Board) {
    if let index = palette.boards.firstIndex(where: { $0.id == board.id }) {
      palette.boards.remove(at: index)
    } else {
      palette.boards.append(board)
    }
  }

  private func copyAllHexValues() {
    UIPasteboard.general.string = colors.map { $0.hex.uppercased() }.joined(separator: "\n")
    didCopy.toggle()
  }

  private var colorList: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Colors")
        .font(.headline)
      ForEach(colors, id: \.hex) { color in
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(paletteHex: color.hex))
            .frame(width: 32, height: 32)
          VStack(alignment: .leading) {
            Text(color.name)
              .font(.subheadline)
            Text(color.hex)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(String(format: "%.0f%%", color.weight * 100))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var contrastSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Contrast")
        .font(.headline)
      ForEach(contrastPairs) { pair in
        HStack(spacing: 12) {
          HStack(spacing: -8) {
            Circle().fill(Color(paletteHex: pair.first.hex)).frame(width: 24, height: 24)
            Circle().fill(Color(paletteHex: pair.second.hex)).frame(width: 24, height: 24)
          }
          Text(String(format: "%.1f:1", pair.ratio))
            .font(.subheadline.monospacedDigit())
          Spacer()
          contrastBadge(for: pair.ratio)
        }
      }
    }
  }

  private func contrastBadge(for ratio: Float) -> some View {
    Group {
      if Contrast.passesAAA(ratio) {
        Label("AAA", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
      } else if Contrast.passesAA(ratio) {
        Label("AA", systemImage: "checkmark.circle").foregroundStyle(.green)
      } else {
        Label("Low", systemImage: "xmark.circle").foregroundStyle(.secondary)
      }
    }
    .font(.caption)
    .labelStyle(.titleAndIcon)
  }

  private struct ContrastPair: Identifiable {
    let id = UUID()
    let first: PaletteColor
    let second: PaletteColor
    let ratio: Float
  }

  // All unique pairs among the palette's colors, best contrast first.
  private var contrastPairs: [ContrastPair] {
    var pairs: [ContrastPair] = []
    for i in colors.indices {
      for j in colors.indices where j > i {
        let ratio = Contrast.contrastRatio(
          ColorSpace.labToSRGB(colors[i].lab), ColorSpace.labToSRGB(colors[j].lab))
        pairs.append(ContrastPair(first: colors[i], second: colors[j], ratio: ratio))
      }
    }
    return pairs.sorted { $0.ratio > $1.ratio }
  }

  @MainActor
  private func renderShareCard() -> Image? {
    let renderer = ImageRenderer(content: ShareCard(name: palette.name, colors: colors))
    renderer.scale = displayScale
    guard let uiImage = renderer.uiImage else { return nil }
    return Image(uiImage: uiImage)
  }

  private static func makeCGImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }
}

// The image rendered into the system share sheet: name, swatches, and hex codes, laid out
// independently of the on-screen detail view so it stays a clean, fixed-size card.
private struct ShareCard: View {
  let name: String
  let colors: [PaletteColor]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(name)
        .font(.title2.bold())
      PaletteStrip(colors: colors)
        .frame(height: 64)
      ForEach(colors, id: \.hex) { color in
        HStack {
          Text(color.name)
          Spacer()
          Text(color.hex)
            .foregroundStyle(.secondary)
        }
        .font(.callout)
      }
      Text("Hue Hunt")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(width: 360)
    .background(.background)
  }
}

#Preview {
  let hexValues = ["#FF6B6B", "#4ECDC4", "#FFD93D", "#1A535C", "#F7FFF7"]
  let sampleColors = hexValues.map { hex -> PaletteColor in
    let lab = ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: hex))
    return PaletteColor(
      hex: hex, lab: lab, weight: 1.0 / Float(hexValues.count), name: ColorNamer.name(for: lab))
  }
  let colorsData = (try? JSONEncoder().encode(sampleColors)) ?? Data()
  let palette = Palette(name: "Sunset Dock", colorsData: colorsData, thumbnail: nil)
  let container = try! ModelContainer(
    for: Palette.self, Board.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  container.mainContext.insert(palette)

  return NavigationStack {
    PaletteDetailView(palette: palette)
  }
  .modelContainer(container)
}

#Preview("Share card") {
  let hexValues = ["#FF6B6B", "#4ECDC4", "#FFD93D", "#1A535C", "#F7FFF7"]
  let sampleColors = hexValues.map { hex -> PaletteColor in
    let lab = ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: hex))
    return PaletteColor(
      hex: hex, lab: lab, weight: 1.0 / Float(hexValues.count), name: ColorNamer.name(for: lab))
  }
  return ShareCard(name: "Sunset Dock", colors: sampleColors)
}
