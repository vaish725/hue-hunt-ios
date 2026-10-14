import PaletteEngine
import SwiftData
import SwiftUI
import simd

// Today's color hunt: a prompt picked deterministically from a local list by day of year, so
// everyone sees the same prompt on a given day without needing a backend. Complete by catching
// a palette, any time today, that contains a close enough color.
struct TodayView: View {
  @Query private var palettes: [Palette]

  // How close a caught color's Lab value must be to the prompt's to count as a match. Looser
  // than PaletteExtractor's near-duplicate threshold (dE < 6), since this only needs to confirm
  // the same general color family, not a near-identical shade.
  private let matchThreshold: Float = 20

  private var prompt: DailyPrompt { .today }

  private var isCompleted: Bool {
    let targetLab = ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: prompt.hex))
    return palettes.contains { palette in
      Calendar.current.isDateInToday(palette.createdAt)
        && palette.decodedColors.contains { simd_distance($0.lab, targetLab) < matchThreshold }
    }
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      RoundedRectangle(cornerRadius: 24)
        .fill(Color(paletteHex: prompt.hex))
        .frame(width: 120, height: 120)

      Text("Today's hunt")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text(prompt.title)
        .font(.title.bold())
        .multilineTextAlignment(.center)

      if isCompleted {
        Label("Caught today", systemImage: "checkmark.circle.fill")
          .font(.headline)
          .foregroundStyle(.green)
      } else {
        Text("Catch a palette with this color to complete today's hunt.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Spacer()
    }
    .padding(32)
    .navigationTitle("Today")
  }
}

private struct DailyPrompt: Identifiable {
  let id: Int
  let title: String
  let hex: String

  static var today: DailyPrompt { prompt(for: .now) }

  static func prompt(for date: Date, calendar: Calendar = .current) -> DailyPrompt {
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    return all[(dayOfYear - 1) % all.count]
  }

  private static let all: [DailyPrompt] = [
    DailyPrompt(id: 0, title: "Find something golden", hex: "#FFD700"),
    DailyPrompt(id: 1, title: "Find something leafy green", hex: "#4CAF50"),
    DailyPrompt(id: 2, title: "Find something sky blue", hex: "#87CEEB"),
    DailyPrompt(id: 3, title: "Find something fire engine red", hex: "#D32F2F"),
    DailyPrompt(id: 4, title: "Find something lavender", hex: "#B57EDC"),
    DailyPrompt(id: 5, title: "Find something sandy beige", hex: "#D2B48C"),
    DailyPrompt(id: 6, title: "Find something deep purple", hex: "#4B0082"),
    DailyPrompt(id: 7, title: "Find something coral", hex: "#FF7F50"),
    DailyPrompt(id: 8, title: "Find something minty", hex: "#98FF98"),
    DailyPrompt(id: 9, title: "Find something charcoal", hex: "#36454F"),
    DailyPrompt(id: 10, title: "Find something sunflower yellow", hex: "#FFC107"),
    DailyPrompt(id: 11, title: "Find something ocean teal", hex: "#008080"),
    DailyPrompt(id: 12, title: "Find something rose pink", hex: "#FFC0CB"),
    DailyPrompt(id: 13, title: "Find something earthy brown", hex: "#8B4513"),
    DailyPrompt(id: 14, title: "Find something icy white", hex: "#F0FFFF"),
    DailyPrompt(id: 15, title: "Find something burnt orange", hex: "#CC5500"),
    DailyPrompt(id: 16, title: "Find something forest green", hex: "#228B22"),
    DailyPrompt(id: 17, title: "Find something midnight blue", hex: "#191970"),
    DailyPrompt(id: 18, title: "Find something cherry red", hex: "#DE3163"),
    DailyPrompt(id: 19, title: "Find something soft gray", hex: "#B0B0B0"),
  ]
}

#Preview {
  let container = try! ModelContainer(
    for: Palette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  return NavigationStack {
    TodayView()
  }
  .modelContainer(container)
}
