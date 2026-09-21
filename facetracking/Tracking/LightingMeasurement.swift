import Foundation

struct CanonicalLumaSample: Sendable, Equatable {
    let value: UInt8
    let viewportPoint: NormalizedViewportPoint
}

final class LightingHistogramWorkspace {
    fileprivate var all = Array(repeating: 0, count: 256)
    fileprivate var left = Array(repeating: 0, count: 256)
    fileprivate var right = Array(repeating: 0, count: 256)
    fileprivate var top = Array(repeating: 0, count: 256)
    fileprivate var bottom = Array(repeating: 0, count: 256)

    fileprivate func reset() {
        all.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        left.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        right.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        top.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        bottom.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
    }
}

enum LightingMeasurement {
    static func measure(
        samples: [CanonicalLumaSample],
        face: FaceSample?,
        isPoseEligible: Bool,
        workspace: LightingHistogramWorkspace,
        configuration: TrackingConfiguration = .provisional
    ) -> FaceLightingMetrics? {
        guard isPoseEligible,
              let face = face?.validated,
              face.pose?.isFinite == true,
              face.geometry.width > 0,
              face.geometry.height > 0
        else { return nil }

        workspace.reset()
        var total = 0
        var leftCount = 0
        var rightCount = 0
        var topCount = 0
        var bottomCount = 0
        let faceLeft = face.geometry.centerX - face.geometry.width / 2
        let faceTop = face.geometry.centerY - face.geometry.height / 2

        for sample in samples {
            let u = (sample.viewportPoint.x - faceLeft) / face.geometry.width
            let v = (sample.viewportPoint.y - faceTop) / face.geometry.height
            guard u.isFinite, v.isFinite else { continue }
            let ellipse = pow((u - configuration.sampling.faceEllipseCenterU) / configuration.sampling.faceEllipseHorizontalRadius, 2)
                + pow((v - configuration.sampling.faceEllipseCenterV) / configuration.sampling.faceEllipseVerticalRadius, 2)
            guard ellipse <= 1 else { continue }

            let bin = Int(sample.value)
            workspace.all[bin] += 1
            total += 1
            if u < configuration.sampling.horizontalRegionSplitU {
                workspace.left[bin] += 1
                leftCount += 1
            } else {
                workspace.right[bin] += 1
                rightCount += 1
            }
            if v < configuration.sampling.verticalRegionSplitV {
                workspace.top[bin] += 1
                topCount += 1
            } else {
                workspace.bottom[bin] += 1
                bottomCount += 1
            }
        }

        guard total >= configuration.sampling.minimumTotalSampleCount,
              leftCount >= configuration.sampling.minimumRegionalSampleCount,
              rightCount >= configuration.sampling.minimumRegionalSampleCount,
              topCount >= configuration.sampling.minimumRegionalSampleCount,
              bottomCount >= configuration.sampling.minimumRegionalSampleCount,
              leftCount + rightCount == total,
              topCount + bottomCount == total,
              let median = median(histogram: workspace.all, count: total),
              let globalMean = trimmedMean(histogram: workspace.all, count: total),
              let leftMean = trimmedMean(histogram: workspace.left, count: leftCount),
              let rightMean = trimmedMean(histogram: workspace.right, count: rightCount),
              let topMean = trimmedMean(histogram: workspace.top, count: topCount),
              let bottomMean = trimmedMean(histogram: workspace.bottom, count: bottomCount)
        else { return nil }

        let shadowCount = workspace.all[0...configuration.luma.shadowMaximumInclusive].reduce(0, +)
        let highlightCount = workspace.all[configuration.luma.highlightMinimumInclusive...255].reduce(0, +)
        return FaceLightingMetrics(
            median: median,
            globalTrimmedMean: globalMean,
            leftTrimmedMean: leftMean,
            rightTrimmedMean: rightMean,
            topTrimmedMean: topMean,
            bottomTrimmedMean: bottomMean,
            shadowFraction: Double(shadowCount) / Double(total),
            highlightFraction: Double(highlightCount) / Double(total),
            totalCount: total,
            leftCount: leftCount,
            rightCount: rightCount,
            topCount: topCount,
            bottomCount: bottomCount
        ).validated
    }

    static func median(histogram: [Int], count: Int) -> Double? {
        guard histogram.count == 256, count > 0, histogram.allSatisfy({ $0 >= 0 }), histogram.reduce(0, +) == count else { return nil }
        let lowerRank = (count - 1) / 2
        let upperRank = count / 2
        guard let lower = value(at: lowerRank, histogram: histogram),
              let upper = value(at: upperRank, histogram: histogram)
        else { return nil }
        return Double(lower + upper) / 2
    }

    static func trimmedMean(histogram: [Int], count: Int) -> Double? {
        guard histogram.count == 256, count > 0, histogram.allSatisfy({ $0 >= 0 }), histogram.reduce(0, +) == count else { return nil }
        let trim = count / 10
        let firstIncludedRank = trim
        let lastExcludedRank = count - trim
        guard firstIncludedRank < lastExcludedRank else { return nil }
        var rank = 0
        var sum = 0.0
        var included = 0
        for (value, bucketCount) in histogram.enumerated() where bucketCount > 0 {
            let bucketStart = rank
            let bucketEnd = rank + bucketCount
            let overlapStart = max(bucketStart, firstIncludedRank)
            let overlapEnd = min(bucketEnd, lastExcludedRank)
            if overlapStart < overlapEnd {
                let retained = overlapEnd - overlapStart
                sum += Double(value * retained)
                included += retained
            }
            rank = bucketEnd
        }
        guard included == count - 2 * trim, included > 0 else { return nil }
        return sum / Double(included)
    }

    private static func value(at rank: Int, histogram: [Int]) -> Int? {
        var seen = 0
        for (value, count) in histogram.enumerated() {
            seen += count
            if rank < seen { return value }
        }
        return nil
    }
}

extension FaceLightingMetrics {
    var validated: FaceLightingMetrics? {
        let sampling = TrackingConfiguration.provisional.sampling
        let values = [median, globalTrimmedMean, leftTrimmedMean, rightTrimmedMean, topTrimmedMean, bottomTrimmedMean]
        guard values.allSatisfy({ $0.isFinite && (0...255).contains($0) }),
              shadowFraction.isFinite, highlightFraction.isFinite,
              (0...1).contains(shadowFraction), (0...1).contains(highlightFraction),
              shadowFraction + highlightFraction <= 1,
              totalCount >= sampling.minimumTotalSampleCount,
              leftCount >= sampling.minimumRegionalSampleCount,
              rightCount >= sampling.minimumRegionalSampleCount,
              topCount >= sampling.minimumRegionalSampleCount,
              bottomCount >= sampling.minimumRegionalSampleCount,
              leftCount + rightCount == totalCount,
              topCount + bottomCount == totalCount
        else { return nil }
        return self
    }
}
