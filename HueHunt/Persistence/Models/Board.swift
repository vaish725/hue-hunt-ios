import Foundation
import SwiftData

// A named collection of palettes. A palette can belong to many boards, and deleting a board
// only removes the membership, never the palettes themselves (the default SwiftData delete
// rule for this relationship is nullify, not cascade).
@Model
final class Board: Identifiable {
  @Attribute(.unique) var id: UUID
  var name: String
  var createdAt: Date
  var palettes: [Palette] = []

  init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
  }
}
