import SwiftData
import SwiftUI

// The "All palettes" grid. Boards, search, and sort options are separate, later work.
struct LibraryView: View {
  @Query(sort: \Palette.createdAt, order: .reverse) private var palettes: [Palette]

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    ScrollView {
      if palettes.isEmpty {
        ContentUnavailableView(
          "No palettes yet", systemImage: "square.grid.2x2",
          description: Text("Catch a palette to see it here.")
        )
        .padding(.top, 80)
      } else {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(palettes) { palette in
            PaletteCell(palette: palette)
          }
        }
        .padding(16)
      }
    }
    .navigationTitle("Library")
  }
}

private struct PaletteCell: View {
  let palette: Palette

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PaletteStrip(colors: palette.decodedColors)
      Text(palette.name)
        .font(.subheadline)
        .lineLimit(1)
    }
  }
}
