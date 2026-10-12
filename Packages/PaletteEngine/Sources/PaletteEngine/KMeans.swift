import simd

// K-means++ clustering of pixel samples in CIELAB space. dE76 (CIE76 color difference) is a
// plain Euclidean distance in Lab, so simd_distance doubles as the color difference metric here.
public struct KMeans {
  public struct Cluster: Sendable {
    public let centroid: SIMD3<Float>
    public let members: [SIMD3<Float>]
  }

  private let k: Int
  private let maxIterations: Int
  private let convergenceThreshold: Float
  private var rng: SplitMix64

  // seed defaults to 42 so repeated runs on the same frame produce identical output (required for determinism).
  public init(
    k: Int = 5, maxIterations: Int = 12, convergenceThreshold: Float = 0.5, seed: UInt64 = 42
  ) {
    self.k = k
    self.maxIterations = maxIterations
    self.convergenceThreshold = convergenceThreshold
    self.rng = SplitMix64(seed: seed)
  }

  public mutating func run(on points: [SIMD3<Float>]) -> [Cluster] {
    guard !points.isEmpty else {
      return (0..<k).map { _ in Cluster(centroid: SIMD3(repeating: 0), members: []) }
    }

    var centroids = seedCentroids(from: points)
    var assignments = [Int](repeating: 0, count: points.count)

    for _ in 0..<maxIterations {
      for index in points.indices {
        assignments[index] = nearestCentroidIndex(to: points[index], in: centroids)
      }

      var maxMove: Float = 0
      for clusterIndex in 0..<k {
        let members = pointsAssigned(to: clusterIndex, points: points, assignments: assignments)
        guard !members.isEmpty else { continue }
        let mean = members.reduce(SIMD3<Float>(repeating: 0), +) / Float(members.count)
        maxMove = max(maxMove, simd_distance(mean, centroids[clusterIndex]))
        centroids[clusterIndex] = mean
      }

      if maxMove < convergenceThreshold { break }
    }

    return (0..<k).map { clusterIndex in
      Cluster(
        centroid: centroids[clusterIndex],
        members: pointsAssigned(to: clusterIndex, points: points, assignments: assignments)
      )
    }
  }

  private func pointsAssigned(to clusterIndex: Int, points: [SIMD3<Float>], assignments: [Int])
    -> [SIMD3<Float>]
  {
    points.indices.filter { assignments[$0] == clusterIndex }.map { points[$0] }
  }

  private func nearestCentroidIndex(to point: SIMD3<Float>, in centroids: [SIMD3<Float>]) -> Int {
    var bestIndex = 0
    var bestDistance = Float.greatestFiniteMagnitude
    for (index, centroid) in centroids.enumerated() {
      let distance = simd_distance(point, centroid)
      if distance < bestDistance {
        bestDistance = distance
        bestIndex = index
      }
    }
    return bestIndex
  }

  // Picks the first centroid uniformly, then each next one with probability proportional to its
  // squared distance from the nearest centroid already chosen, so initial centroids spread out.
  private mutating func seedCentroids(from points: [SIMD3<Float>]) -> [SIMD3<Float>] {
    var centroids: [SIMD3<Float>] = [points[Int.random(in: points.indices, using: &rng)]]

    while centroids.count < k {
      let squaredDistances = points.map { point -> Float in
        let nearest = centroids.map { simd_distance(point, $0) }.min() ?? 0
        return nearest * nearest
      }
      let total = squaredDistances.reduce(0, +)
      guard total > 0 else {
        centroids.append(points[Int.random(in: points.indices, using: &rng)])
        continue
      }
      let threshold = Float.random(in: 0..<total, using: &rng)
      var cumulative: Float = 0
      var chosen = points[0]
      for (index, value) in squaredDistances.enumerated() {
        cumulative += value
        if cumulative >= threshold {
          chosen = points[index]
          break
        }
      }
      centroids.append(chosen)
    }

    return centroids
  }
}

// Deterministic, seedable generator. Swift's SystemRandomNumberGenerator cannot be seeded,
// and k-means++ init must be reproducible across runs of the same frame.
private struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
