import PaletteEngine
import SwiftData
import SwiftUI

// The "All palettes" grid, with search by name and a few sort orders. Boards are separate,
// later work.
struct LibraryView: View {
  @Query(sort: \Palette.createdAt, order: .reverse) private var palettes: [Palette]
  @State private var searchText = ""
  @State private var sortOption: SortOption = .newest

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  private var displayedPalettes: [Palette] {
    let filtered =
      searchText.isEmpty
      ? palettes
      : palettes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    return filtered.sorted(by: sortOption.areInIncreasingOrder)
  }

  var body: some View {
    ScrollView {
      if palettes.isEmpty {
        ContentUnavailableView(
          "No palettes yet", systemImage: "square.grid.2x2",
          description: Text("Catch a palette to see it here.")
        )
        .padding(.top, 80)
      } else if displayedPalettes.isEmpty {
        ContentUnavailableView.search(text: searchText)
          .padding(.top, 80)
      } else {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(displayedPalettes) { palette in
            NavigationLink {
              PaletteDetailView(palette: palette)
            } label: {
              PaletteCell(palette: palette)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(16)
      }
    }
    .navigationTitle("Library")
    .searchable(text: $searchText, prompt: "Search palettes")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Picker("Sort", selection: $sortOption) {
          ForEach(SortOption.allCases) { option in
            Text(option.label).tag(option)
          }
        }
        .pickerStyle(.menu)
      }
    }
  }
}

private enum SortOption: String, CaseIterable, Identifiable {
  case newest, oldest, nameAZ

  var id: Self { self }

  var label: String {
    switch self {
    case .newest: "Newest"
    case .oldest: "Oldest"
    case .nameAZ: "Name (A-Z)"
    }
  }

  func areInIncreasingOrder(_ lhs: Palette, _ rhs: Palette) -> Bool {
    switch self {
    case .newest: lhs.createdAt > rhs.createdAt
    case .oldest: lhs.createdAt < rhs.createdAt
    case .nameAZ: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
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

#Preview {
  let container = try! ModelContainer(
    for: Palette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let hexValues = ["#FF6B6B", "#4ECDC4", "#FFD93D"]
  let sampleColors = hexValues.map { hex -> PaletteColor in
    let lab = ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: hex))
    return PaletteColor(hex: hex, lab: lab, weight: 1.0 / 3, name: ColorNamer.name(for: lab))
  }
  let colorsData = (try? JSONEncoder().encode(sampleColors)) ?? Data()
  for name in ["Sunset Dock", "Morning Mist", "City Lights", "Autumn Walk"] {
    container.mainContext.insert(Palette(name: name, colorsData: colorsData, thumbnail: nil))
  }

  return NavigationStack {
    LibraryView()
  }
  .modelContainer(container)
}
