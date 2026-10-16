import Foundation
import SwiftData

// A caught palette. colorsData holds a JSON-encoded [PaletteColor] from the PaletteEngine
// package rather than the type itself, so this model has no dependency on that module.
@Model
final class Palette: Identifiable {
  @Attribute(.unique) var id: UUID
  var name: String
  var colorsData: Data
  @Attribute(.externalStorage) var thumbnail: Data?
  var createdAt: Date
  @Relationship(inverse: \Board.palettes) var boards: [Board] = []

  init(
    id: UUID = UUID(), name: String, colorsData: Data, thumbnail: Data?,
    createdAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.colorsData = colorsData
    self.thumbnail = thumbnail
    self.createdAt = createdAt
  }
}
