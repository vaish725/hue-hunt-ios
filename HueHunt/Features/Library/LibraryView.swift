import PaletteEngine
import SwiftData
import SwiftUI

// The "All palettes" grid, with search by palette name or color name, a few sort orders, and
// a horizontal strip of boards above it for organizing palettes into named collections.
struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Palette.createdAt, order: .reverse) private var palettes: [Palette]
  @Query(sort: \Board.createdAt, order: .reverse) private var boards: [Board]
  @State private var searchText = ""
  @State private var sortOption: SortOption = .newest
  @State private var isShowingNewBoardPrompt = false
  @State private var newBoardName = ""
  @State private var renamingBoard: Board?
  @State private var renameText = ""

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  private var displayedPalettes: [Palette] {
    let filtered =
      searchText.isEmpty
      ? palettes
      : palettes.filter { palette in
        palette.name.localizedCaseInsensitiveContains(searchText)
          || palette.decodedColors.contains {
            $0.name.localizedCaseInsensitiveContains(searchText)
          }
      }
    return filtered.sorted(by: sortOption.areInIncreasingOrder)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        boardsSection

        if palettes.isEmpty {
          ContentUnavailableView(
            "No palettes yet", systemImage: "square.grid.2x2",
            description: Text("Catch a palette to see it here.")
          )
          .padding(.top, 40)
        } else if displayedPalettes.isEmpty {
          ContentUnavailableView.search(text: searchText)
            .padding(.top, 40)
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
          .padding(.horizontal, 16)
        }
      }
      .padding(.vertical, 16)
    }
    .navigationTitle("Library")
    .searchable(text: $searchText, prompt: "Search palettes or colors")
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
    .alert("New Board", isPresented: $isShowingNewBoardPrompt) {
      TextField("Board name", text: $newBoardName)
      Button("Cancel", role: .cancel) { newBoardName = "" }
      Button("Create") {
        let trimmed = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          modelContext.insert(Board(name: trimmed))
        }
        newBoardName = ""
      }
    }
    .alert("Rename Board", isPresented: isRenamingBoard) {
      TextField("Board name", text: $renameText)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { renamingBoard?.name = trimmed }
      }
    }
  }

  private var isRenamingBoard: Binding<Bool> {
    Binding(get: { renamingBoard != nil }, set: { if !$0 { renamingBoard = nil } })
  }

  private var boardsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Boards")
          .font(.headline)
        Spacer()
        Button {
          isShowingNewBoardPrompt = true
        } label: {
          Label("New Board", systemImage: "plus.circle.fill")
            .labelStyle(.iconOnly)
        }
      }
      .padding(.horizontal, 16)

      if boards.isEmpty {
        Text("Create a board to organize your palettes.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(boards) { board in
              NavigationLink {
                BoardDetailView(board: board)
              } label: {
                BoardChip(board: board)
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button("Rename") {
                  renameText = board.name
                  renamingBoard = board
                }
                Button("Delete", role: .destructive) {
                  modelContext.delete(board)
                }
              }
            }
          }
          .padding(.horizontal, 16)
        }
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

private struct BoardChip: View {
  let board: Board

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let firstPalette = board.palettes.first {
        PaletteStrip(colors: firstPalette.decodedColors)
          .frame(height: 48)
      } else {
        RoundedRectangle(cornerRadius: 12)
          .fill(.quaternary)
          .frame(height: 48)
      }
      Text(board.name)
        .font(.subheadline)
        .lineLimit(1)
      Text("\(board.palettes.count) palette\(board.palettes.count == 1 ? "" : "s")")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(width: 140)
  }
}

// A single board's palettes. Removing a palette here only drops it from the board, it stays in
// the library.
struct BoardDetailView: View {
  @Bindable var board: Board

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    ScrollView {
      if board.palettes.isEmpty {
        ContentUnavailableView(
          "No palettes in this board", systemImage: "square.grid.2x2",
          description: Text("Add palettes to \(board.name) from their detail screen.")
        )
        .padding(.top, 40)
      } else {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(board.palettes) { palette in
            NavigationLink {
              PaletteDetailView(palette: palette)
            } label: {
              PaletteCell(palette: palette)
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button("Remove from Board", role: .destructive) {
                board.palettes.removeAll { $0.id == palette.id }
              }
            }
          }
        }
        .padding(16)
      }
    }
    .navigationTitle(board.name)
  }
}

#Preview {
  let container = try! ModelContainer(
    for: Palette.self, Board.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
