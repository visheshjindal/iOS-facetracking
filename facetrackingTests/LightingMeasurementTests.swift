import XCTest
@testable import facetracking

final class LightingMeasurementTests: XCTestCase {
    func testL02EvenOddMedianAndPartialBucketTrimAreRankExact() {
        var even = histogram([(10, 1), (20, 1)])
        XCTAssertEqual(LightingMeasurement.median(histogram: even, count: 2), 15)
        even[30] = 1
        XCTAssertEqual(LightingMeasurement.median(histogram: even, count: 3), 20)

        let partial = histogram([(0, 1), (10, 3), (50, 12), (100, 3), (255, 1)])
        XCTAssertEqual(LightingMeasurement.median(histogram: partial, count: 20), 50)
        // Trim ranks 0..<2 and 18..<20, retaining 2×10 + 12×50 + 2×100.
        XCTAssertEqual(LightingMeasurement.trimmedMean(histogram: partial, count: 20), 51.25)
    }

    func testL02UniformAsymmetricMeansAndInclusiveShadowHighlightCutoffs() throws {
        var samples: [CanonicalLumaSample] = []
        for quadrant in quadrants {
            samples += Array(repeating: sample(100, quadrant), count: 22)
            samples.append(sample(24, quadrant))
            samples.append(sample(235, quadrant))
        }
        let metrics = try XCTUnwrap(measure(samples))
        XCTAssertEqual(metrics.totalCount, 96)
        XCTAssertEqual(metrics.leftCount, 48)
        XCTAssertEqual(metrics.rightCount, 48)
        XCTAssertEqual(metrics.topCount, 48)
        XCTAssertEqual(metrics.bottomCount, 48)
        XCTAssertEqual(metrics.median, 100)
        XCTAssertEqual(metrics.globalTrimmedMean, 100, accuracy: 0.000_001)
        XCTAssertEqual(metrics.shadowFraction, 4.0 / 96.0, accuracy: 0.000_001)
        XCTAssertEqual(metrics.highlightFraction, 4.0 / 96.0, accuracy: 0.000_001)

        let asymmetric = quadrants.flatMap { point -> [CanonicalLumaSample] in
            let value: UInt8 = point.x < 0.5 ? 40 : 200
            return Array(repeating: sample(value, point), count: 32)
        }
        let asymmetricMetrics = try XCTUnwrap(measure(asymmetric))
        XCTAssertEqual(asymmetricMetrics.leftTrimmedMean, 40)
        XCTAssertEqual(asymmetricMetrics.rightTrimmedMean, 200)
        XCTAssertEqual(asymmetricMetrics.topTrimmedMean, 120)
        XCTAssertEqual(asymmetricMetrics.bottomTrimmedMean, 120)
    }

    func testL03Total95FailsAnd96Passes() {
        var passing = quadrants.flatMap { Array(repeating: sample(100, $0), count: 24) }
        XCTAssertNotNil(measure(passing))
        passing.removeLast()
        XCTAssertNil(measure(passing))
    }

    func testL03Regional31FailsAnd32Passes() {
        let passing = [
            Array(repeating: sample(100, NormalizedViewportPoint(x: 0.3, y: 0.3)), count: 32),
            Array(repeating: sample(100, NormalizedViewportPoint(x: 0.3, y: 0.7)), count: 32),
            Array(repeating: sample(100, NormalizedViewportPoint(x: 0.7, y: 0.3)), count: 32),
            Array(repeating: sample(100, NormalizedViewportPoint(x: 0.7, y: 0.7)), count: 32)
        ].flatMap { $0 }
        XCTAssertNotNil(measure(passing))

        let failing = Array(repeating: sample(100, NormalizedViewportPoint(x: 0.3, y: 0.3)), count: 15)
            + Array(repeating: sample(100, NormalizedViewportPoint(x: 0.3, y: 0.7)), count: 16)
            + Array(repeating: sample(100, NormalizedViewportPoint(x: 0.7, y: 0.3)), count: 49)
            + Array(repeating: sample(100, NormalizedViewportPoint(x: 0.7, y: 0.7)), count: 48)
        XCTAssertNil(measure(failing)) // left count is exactly 31.
    }

    func testL03UnknownPoseIneligiblePoseNoFaceAndInvalidMetricsAreUnavailable() {
        let samples = quadrants.flatMap { Array(repeating: sample(100, $0), count: 32) }
        let workspace = LightingHistogramWorkspace()
        XCTAssertNotNil(LightingMeasurement.measure(samples: samples, face: face, isPoseEligible: true, workspace: workspace))
        XCTAssertNil(LightingMeasurement.measure(samples: samples, face: nil, isPoseEligible: true, workspace: workspace))
        XCTAssertNil(LightingMeasurement.measure(
            samples: samples,
            face: FaceSample(geometry: face.geometry, pose: nil),
            isPoseEligible: true,
            workspace: workspace
        ))
        XCTAssertNil(LightingMeasurement.measure(samples: samples, face: face, isPoseEligible: false, workspace: workspace))

        XCTAssertNil(FaceLightingMetrics(
            median: .nan, globalTrimmedMean: 100, leftTrimmedMean: 100, rightTrimmedMean: 100,
            topTrimmedMean: 100, bottomTrimmedMean: 100, shadowFraction: 0, highlightFraction: 0,
            totalCount: 96, leftCount: 48, rightCount: 48, topCount: 48, bottomCount: 48
        ).validated)
        XCTAssertNil(FaceLightingMetrics(
            median: 100, globalTrimmedMean: 100, leftTrimmedMean: 100, rightTrimmedMean: 100,
            topTrimmedMean: 100, bottomTrimmedMean: 100, shadowFraction: 0, highlightFraction: 0,
            totalCount: 95, leftCount: 47, rightCount: 48, topCount: 47, bottomCount: 48
        ).validated)
        XCTAssertNil(FaceLightingMetrics(
            median: 100, globalTrimmedMean: 100, leftTrimmedMean: 100, rightTrimmedMean: 100,
            topTrimmedMean: 100, bottomTrimmedMean: 100, shadowFraction: 0.6, highlightFraction: 0.5,
            totalCount: 96, leftCount: 48, rightCount: 48, topCount: 48, bottomCount: 48
        ).validated)
        XCTAssertNil(FaceLightingMetrics(
            median: 100, globalTrimmedMean: 100, leftTrimmedMean: 100, rightTrimmedMean: 100,
            topTrimmedMean: 100, bottomTrimmedMean: 100, shadowFraction: 0, highlightFraction: 0,
            totalCount: 96, leftCount: 47, rightCount: 48, topCount: 48, bottomCount: 48
        ).validated)
    }

    func testEllipseBoundaryIncludedAndEqualitySplitsRightBottom() throws {
        var samples = quadrants.flatMap { Array(repeating: sample(100, $0), count: 32) }
        samples.append(sample(200, NormalizedViewportPoint(x: 0.9, y: 0.5))) // ellipse equality at u=0.9
        let metrics = try XCTUnwrap(measure(samples))
        XCTAssertEqual(metrics.rightCount, 65)
        XCTAssertEqual(metrics.bottomCount, 65)
    }

    private let quadrants = [
        NormalizedViewportPoint(x: 0.3, y: 0.3),
        NormalizedViewportPoint(x: 0.7, y: 0.3),
        NormalizedViewportPoint(x: 0.3, y: 0.7),
        NormalizedViewportPoint(x: 0.7, y: 0.7)
    ]
    private let face = FaceSample(
        geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 1, height: 1),
        pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    )

    private func sample(_ value: UInt8, _ point: NormalizedViewportPoint) -> CanonicalLumaSample {
        CanonicalLumaSample(value: value, viewportPoint: point)
    }
    private func measure(_ samples: [CanonicalLumaSample]) -> FaceLightingMetrics? {
        LightingMeasurement.measure(samples: samples, face: face, isPoseEligible: true, workspace: LightingHistogramWorkspace())
    }
    private func histogram(_ entries: [(Int, Int)]) -> [Int] {
        var result = Array(repeating: 0, count: 256)
        for (value, count) in entries { result[value] = count }
        return result
    }
}
