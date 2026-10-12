import simd

// A single color in an extracted palette, with its position in Lab space and its share of the image.
public struct PaletteColor: Codable, Hashable, Sendable {
    public let hex: String
    public let lab: SIMD3<Float>
    public let weight: Float
    public let name: String

    public init(hex: String, lab: SIMD3<Float>, weight: Float, name: String) {
        self.hex = hex
        self.lab = lab
        self.weight = weight
        self.name = name
    }
}

// The result of running the extraction pipeline on a single frame or image.
public struct ExtractedPalette: Sendable, Equatable {
    public let colors: [PaletteColor]

    public init(colors: [PaletteColor]) {
        self.colors = colors
    }
}

// Runs the extraction pipeline off the main thread so camera frames never block the UI.
// Pixels are expected in sRGB, 0...1 per channel, already downsampled by the caller.
public actor PaletteExtractor {
    private let colorCount: Int
    private let smoother: PaletteSmoother
    private var previousLabCentroids: [SIMD3<Float>]?

    public init(colorCount: Int = 5, smoother: PaletteSmoother = PaletteSmoother()) {
        self.colorCount = colorCount
        self.smoother = smoother
    }

    public func extract(pixels: [SIMD3<Float>]) -> ExtractedPalette {
        guard !pixels.isEmpty else { return ExtractedPalette(colors: []) }

        let labPixels = pixels.map(ColorSpace.srgbToLab)
        let nearNeutralFiltered = labPixels.filter { $0.x >= 3 && $0.x <= 98 }
        let pixelsToCluster = nearNeutralFiltered.count >= 512 ? nearNeutralFiltered : labPixels

        var kMeans = KMeans(k: colorCount, seed: 42)
        let clusters = mergeAndSplit(kMeans.run(on: pixelsToCluster))

        var centroids = clusters.map(\.centroid)
        centroids = smoother.smooth(current: centroids, previous: previousLabCentroids)
        previousLabCentroids = centroids

        let totalCount = pixelsToCluster.count
        let colors = zip(centroids, clusters).map { centroid, cluster -> PaletteColor in
            let weight = totalCount > 0 ? Float(cluster.members.count) / Float(totalCount) : 0
            let srgb = ColorSpace.labToSRGB(centroid)
            return PaletteColor(
                hex: ColorSpace.hex(from: srgb),
                lab: centroid,
                weight: weight,
                name: ColorNamer.name(for: centroid)
            )
        }

        return ExtractedPalette(colors: colors.sorted { $0.weight > $1.weight })
    }

    // Keeps exactly colorCount distinct clusters: whenever two centroids sit within 6 dE of each
    // other, they are folded into one, and the cluster with the most spread is split in two to
    // replace the slot. Bounded by a small pass limit so a uniform frame (e.g. a blank wall),
    // where every centroid is identical, cannot spin forever.
    private func mergeAndSplit(_ clusters: [KMeans.Cluster]) -> [KMeans.Cluster] {
        var clusters = clusters
        var remainingPasses = colorCount * 2

        while remainingPasses > 0, let pair = closeCentroidPair(in: clusters) {
            remainingPasses -= 1
            let merged = merge(clusters[pair.1], with: clusters[pair.0])
            clusters.remove(at: pair.1)
            clusters.remove(at: pair.0)
            clusters.append(merged)

            guard let largestIndex = indexOfLargestVarianceCluster(clusters) else { break }
            let (low, high) = split(clusters[largestIndex])
            clusters.remove(at: largestIndex)
            clusters.append(low)
            clusters.append(high)
        }

        return clusters
    }

    private func closeCentroidPair(in clusters: [KMeans.Cluster]) -> (Int, Int)? {
        for i in clusters.indices {
            for j in clusters.indices where j > i {
                if simd_distance(clusters[i].centroid, clusters[j].centroid) < 6 {
                    return (i, j)
                }
            }
        }
        return nil
    }

    private func merge(_ a: KMeans.Cluster, with b: KMeans.Cluster) -> KMeans.Cluster {
        let totalCount = a.members.count + b.members.count
        guard totalCount > 0 else { return KMeans.Cluster(centroid: a.centroid, members: []) }
        let weightedSum = a.centroid * Float(a.members.count) + b.centroid * Float(b.members.count)
        return KMeans.Cluster(centroid: weightedSum / Float(totalCount), members: a.members + b.members)
    }

    private func indexOfLargestVarianceCluster(_ clusters: [KMeans.Cluster]) -> Int? {
        guard !clusters.isEmpty else { return nil }
        var bestIndex = 0
        var bestVariance: Float = -1
        for (index, cluster) in clusters.enumerated() {
            let variance = totalVariance(of: cluster)
            if variance > bestVariance {
                bestVariance = variance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func totalVariance(of cluster: KMeans.Cluster) -> Float {
        guard !cluster.members.isEmpty else { return 0 }
        let sumSquared = cluster.members.reduce(Float(0)) { $0 + simd_length_squared($1 - cluster.centroid) }
        return sumSquared / Float(cluster.members.count)
    }

    // Splits along whichever Lab axis (L, a, or b) has the most spread, a cheap stand-in for a
    // full principal-component split that is accurate enough for a 5-color palette.
    private func split(_ cluster: KMeans.Cluster) -> (KMeans.Cluster, KMeans.Cluster) {
        guard cluster.members.count >= 2 else {
            return (cluster, KMeans.Cluster(centroid: cluster.centroid, members: []))
        }

        var variance = SIMD3<Float>(repeating: 0)
        for point in cluster.members {
            let delta = point - cluster.centroid
            variance += delta * delta
        }
        let axis = indexOfMaxComponent(variance)

        var low: [SIMD3<Float>] = []
        var high: [SIMD3<Float>] = []
        for point in cluster.members {
            if point[axis] <= cluster.centroid[axis] {
                low.append(point)
            } else {
                high.append(point)
            }
        }
        if low.isEmpty || high.isEmpty {
            let half = cluster.members.count / 2
            low = Array(cluster.members[..<half])
            high = Array(cluster.members[half...])
        }

        let lowCentroid = low.reduce(SIMD3<Float>(repeating: 0), +) / Float(low.count)
        let highCentroid = high.reduce(SIMD3<Float>(repeating: 0), +) / Float(high.count)
        return (KMeans.Cluster(centroid: lowCentroid, members: low), KMeans.Cluster(centroid: highCentroid, members: high))
    }

    private func indexOfMaxComponent(_ v: SIMD3<Float>) -> Int {
        if v.x >= v.y && v.x >= v.z { return 0 }
        return v.y >= v.z ? 1 : 2
    }
}
