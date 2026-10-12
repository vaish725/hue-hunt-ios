import simd

// Smooths palette changes across frames so colors do not flicker between updates.
public struct PaletteSmoother {
  public let alpha: Float
  public let sceneCutThreshold: Float

  public init(alpha: Float = 0.35, sceneCutThreshold: Float = 40) {
    self.alpha = alpha
    self.sceneCutThreshold = sceneCutThreshold
  }

  // Matches each current centroid to the closest unmatched previous centroid, then blends
  // toward it with an exponential moving average. Returns the raw centroids unchanged when
  // there is no previous frame to match against, or when the mean shift looks like a scene cut.
  public func smooth(current: [SIMD3<Float>], previous: [SIMD3<Float>]?) -> [SIMD3<Float>] {
    guard let previous, previous.count == current.count, !current.isEmpty else {
      return current
    }

    let matches = greedyMatches(current: current, previous: previous)
    let shifts = current.indices.compactMap { index in
      matches[index].map { simd_distance(current[index], $0) }
    }
    let meanShift = shifts.reduce(0, +) / Float(max(shifts.count, 1))
    guard meanShift <= sceneCutThreshold else { return current }

    return current.indices.map { index in
      guard let previousMatch = matches[index] else { return current[index] }
      // Linear interpolation is a convex combination, so the result can never land
      // farther from the previous centroid than the raw current target does.
      return previousMatch + (current[index] - previousMatch) * alpha
    }
  }

  private func greedyMatches(current: [SIMD3<Float>], previous: [SIMD3<Float>]) -> [SIMD3<Float>?] {
    var matches = [SIMD3<Float>?](repeating: nil, count: current.count)
    var candidates: [(distance: Float, currentIndex: Int, previousIndex: Int)] = []
    for i in current.indices {
      for j in previous.indices {
        candidates.append((simd_distance(current[i], previous[j]), i, j))
      }
    }
    candidates.sort { $0.distance < $1.distance }

    var usedCurrent = Set<Int>()
    var usedPrevious = Set<Int>()
    for candidate in candidates {
      guard !usedCurrent.contains(candidate.currentIndex),
        !usedPrevious.contains(candidate.previousIndex)
      else {
        continue
      }
      matches[candidate.currentIndex] = previous[candidate.previousIndex]
      usedCurrent.insert(candidate.currentIndex)
      usedPrevious.insert(candidate.previousIndex)
      if usedCurrent.count == current.count { break }
    }
    return matches
  }
}
