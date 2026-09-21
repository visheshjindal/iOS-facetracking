import XCTest
@testable import facetracking

final class FrameCoordinateMapperTests: XCTestCase {
    func testG01VisionLowerLeftConversionHorizontalCropMirrorAndPartialClipping() {
        // Hand calculation: 400x200 -> 300x300 uses scale 1.5, x offset -150.
        // Vision (0.1,0.2,0.2,0.3) becomes image x 40...120, y 100...160.
        // Preview x -90...30 mirrors to 270...390; y 150...240.
        let snapshot = fixture(
            raw: (400, 200), oriented: (400, 200), viewport: (300, 300), mirrored: true
        )
        let mapped = FrameCoordinateMapper.mapVisionBounds(
            VisionNormalizedRect(x: 0.1, y: 0.2, width: 0.2, height: 0.3),
            using: snapshot
        )

        assertGeometry(mapped, centerX: 1.1, centerY: 0.65, width: 0.4, height: 0.3)
    }

    func testG01VisionVerticalCropNonSquareBoundsAndMirrorExactlyOnce() {
        // 200x400 -> 300x200 uses scale 1.5, y offset -200.
        // Image rect x 50...100, y 140...260 maps to preview x 75...150,
        // y 10...190, then mirrors to x 150...225.
        let snapshot = fixture(
            raw: (200, 400), oriented: (200, 400), viewport: (300, 200), mirrored: true
        )
        let bounds = VisionNormalizedRect(x: 0.25, y: 0.35, width: 0.25, height: 0.3)
        let mirrored = FrameCoordinateMapper.mapVisionBounds(bounds, using: snapshot)
        let unmirrored = FrameCoordinateMapper.mapVisionBounds(
            bounds,
            using: fixture(raw: (200, 400), oriented: (200, 400), viewport: (300, 200), mirrored: false)
        )

        assertGeometry(mirrored, centerX: 0.625, centerY: 0.5, width: 0.25, height: 0.9)
        assertGeometry(unmirrored, centerX: 0.375, centerY: 0.5, width: 0.25, height: 0.9)
    }

    func testG01EveryQuarterTurnMapsDistinctRawCorners() {
        let fixtures: [(FrameQuarterTurn, (Double, Double), [LabeledCorner])] = [
            (.degrees0, (4, 2), [
                .init(label: "top-left", raw: .init(xPixels: 0, yPixels: 0), expected: .init(x: 0, y: 0)),
                .init(label: "top-right", raw: .init(xPixels: 4, yPixels: 0), expected: .init(x: 1, y: 0)),
                .init(label: "bottom-left", raw: .init(xPixels: 0, yPixels: 2), expected: .init(x: 0, y: 1)),
                .init(label: "bottom-right", raw: .init(xPixels: 4, yPixels: 2), expected: .init(x: 1, y: 1))
            ]),
            (.degrees90Clockwise, (2, 4), [
                .init(label: "top-left", raw: .init(xPixels: 0, yPixels: 0), expected: .init(x: 1, y: 0)),
                .init(label: "top-right", raw: .init(xPixels: 4, yPixels: 0), expected: .init(x: 1, y: 1)),
                .init(label: "bottom-left", raw: .init(xPixels: 0, yPixels: 2), expected: .init(x: 0, y: 0)),
                .init(label: "bottom-right", raw: .init(xPixels: 4, yPixels: 2), expected: .init(x: 0, y: 1))
            ]),
            (.degrees180, (4, 2), [
                .init(label: "top-left", raw: .init(xPixels: 0, yPixels: 0), expected: .init(x: 1, y: 1)),
                .init(label: "top-right", raw: .init(xPixels: 4, yPixels: 0), expected: .init(x: 0, y: 1)),
                .init(label: "bottom-left", raw: .init(xPixels: 0, yPixels: 2), expected: .init(x: 1, y: 0)),
                .init(label: "bottom-right", raw: .init(xPixels: 4, yPixels: 2), expected: .init(x: 0, y: 0))
            ]),
            (.degrees270Clockwise, (2, 4), [
                .init(label: "top-left", raw: .init(xPixels: 0, yPixels: 0), expected: .init(x: 0, y: 1)),
                .init(label: "top-right", raw: .init(xPixels: 4, yPixels: 0), expected: .init(x: 0, y: 0)),
                .init(label: "bottom-left", raw: .init(xPixels: 0, yPixels: 2), expected: .init(x: 1, y: 1)),
                .init(label: "bottom-right", raw: .init(xPixels: 4, yPixels: 2), expected: .init(x: 1, y: 0))
            ])
        ]

        for (rotation, oriented, points) in fixtures {
            let snapshot = fixture(
                raw: (4, 2),
                oriented: oriented,
                viewport: oriented,
                mirrored: false,
                rotation: rotation,
                visionPolicy: .visionAppliesSnapshotRotation
            )
            for corner in points {
                assertPoint(
                    FrameCoordinateMapper.mapRawSamplePoint(corner.raw, using: snapshot),
                    corner.expected,
                    message: "\(rotation.rawValue)° \(corner.label)"
                )
            }
        }
    }

    func testG01CleanApertureOffsetRawCellCenterAndMirror() {
        // Crop raw (2,1,4,2), rotate 90°: cell center (2.5,1.5) ->
        // aperture-local (0.5,0.5) -> oriented (1.5,0.5) in 2x4 ->
        // normalized (0.75,0.125), then mirrored x = 0.25.
        let snapshot = FrameTransformSnapshot(
            geometryRevision: 9,
            rawBufferPixels: .init(width: 8, height: 6),
            orientedImagePixels: .init(width: 2, height: 4),
            rawToOrientedRotation: .degrees90Clockwise,
            visionOrientationPolicy: .visionAppliesSnapshotRotation,
            cleanAperturePolicy: .crop(.init(x: 2, y: 1, width: 4, height: 2)),
            viewportPoints: .init(width: 2, height: 4),
            interfaceOrientation: .portrait,
            isPreviewMirrored: true
        )
        let mapped = FrameCoordinateMapper.mapRawSamplePoint(
            RawBufferPoint(xPixels: 2.5, yPixels: 1.5),
            using: snapshot
        )

        assertPoint(mapped, .init(x: 0.25, y: 0.125))
        XCTAssertNil(FrameCoordinateMapper.mapRawSamplePoint(
            RawBufferPoint(xPixels: 1.5, yPixels: 1.5),
            using: snapshot
        ))
    }

    func testG02SameSnapshotMapsVisionAndRawPointToSameViewportLocation() {
        // Raw center (1,0.5) rotated 90° in a 4x2 buffer is oriented (1.5,1).
        // The Vision rectangle is centered at the same oriented coordinate.
        let snapshot = fixture(
            raw: (4, 2), oriented: (2, 4), viewport: (200, 400), mirrored: true,
            rotation: .degrees90Clockwise,
            visionPolicy: .visionAppliesSnapshotRotation,
            revision: 12
        )
        let rawPoint = FrameCoordinateMapper.mapRawSamplePoint(
            RawBufferPoint(xPixels: 1, yPixels: 0.5),
            using: snapshot
        )
        let vision = FrameCoordinateMapper.mapVisionBounds(
            VisionNormalizedRect(x: 0.7, y: 0.7, width: 0.1, height: 0.1),
            using: snapshot
        )

        XCTAssertEqual(snapshot.geometryRevision, 12)
        XCTAssertNotNil(rawPoint)
        XCTAssertNotNil(vision)
        XCTAssertEqual(vision!.centerX, rawPoint!.x, accuracy: 0.000_001)
        XCTAssertEqual(vision!.centerY, rawPoint!.y, accuracy: 0.000_001)
    }

    func testG02AsymmetricLeftRightLumaFixtureUsesSameSingleMirror() {
        let snapshot = fixture(
            raw: (8, 4), oriented: (8, 4), viewport: (8, 4), mirrored: true,
            revision: 13
        )
        let fixture = AsymmetricLumaFixture(
            rawLeft: .init(point: .init(xPixels: 1.5, yPixels: 2.5), luma: 32),
            rawRight: .init(point: .init(xPixels: 6.5, yPixels: 2.5), luma: 208)
        )
        let displayedLeftSource = FrameCoordinateMapper.mapRawSamplePoint(fixture.rawLeft.point, using: snapshot)
        let displayedRightSource = FrameCoordinateMapper.mapRawSamplePoint(fixture.rawRight.point, using: snapshot)

        XCTAssertNotEqual(fixture.rawLeft.luma, fixture.rawRight.luma)
        XCTAssertEqual(snapshot.geometryRevision, 13)
        XCTAssertGreaterThan(displayedLeftSource!.x, displayedRightSource!.x)
        assertPoint(displayedLeftSource, .init(x: 0.8125, y: 0.625))
        assertPoint(displayedRightSource, .init(x: 0.1875, y: 0.625))
    }

    func testG01RejectsMissingNonFiniteZeroAndInconsistentSnapshots() {
        let validBounds = VisionNormalizedRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
        XCTAssertNil(FrameCoordinateMapper.mapVisionBounds(validBounds, using: nil))
        XCTAssertNil(FrameCoordinateMapper.mapVisionBounds(
            VisionNormalizedRect(x: .nan, y: 0, width: 1, height: 1),
            using: fixture(raw: (4, 2), oriented: (4, 2), viewport: (4, 2))
        ))
        XCTAssertNil(FrameCoordinateMapper.mapVisionBounds(
            VisionNormalizedRect(x: 2, y: 0.2, width: 0.2, height: 0.2),
            using: fixture(raw: (4, 2), oriented: (4, 2), viewport: (4, 2))
        ))
        XCTAssertNil(FrameCoordinateMapper.mapVisionBounds(
            validBounds,
            using: fixture(raw: (4, 2), oriented: (4, 2), viewport: (0, 2))
        ))
        XCTAssertNil(FrameCoordinateMapper.mapRawSamplePoint(
            RawBufferPoint(xPixels: 1, yPixels: 1),
            using: fixture(
                raw: (4, 2), oriented: (2, 4), viewport: (2, 4),
                rotation: .degrees90Clockwise,
                visionPolicy: .bufferAlreadyOriented
            )
        ))
        XCTAssertNil(FrameCoordinateMapper.mapRawSamplePoint(
            RawBufferPoint(xPixels: .infinity, yPixels: 1),
            using: fixture(raw: (4, 2), oriented: (4, 2), viewport: (4, 2))
        ))
    }

    func testG02RevisionRejectionLayoutDedupAndTargetRemainIndependent() {
        var state = SessionState()
        state.authorization = .authorized
        state.isSceneActive = true
        state.isRoutePresent = true
        let viewport = SessionViewport(widthPoints: 390, heightPoints: 700, transformRevision: 4)
        let first = SessionTransition.reduce(state: state, event: .viewportChanged(viewport, atMS: 0))
        let duplicate = SessionTransition.reduce(
            state: first.state,
            event: .viewportChanged(viewport, atMS: 1)
        )
        let wrongRevision = SessionTransition.reduce(
            state: first.state,
            event: .observation(FrameObservation(
                sessionID: 1,
                geometryRevision: 3,
                capturedAtMS: 2,
                face: FaceSample(
                    geometry: FaceGeometry(centerX: 0.4, centerY: 0.4, width: 0.2, height: 0.3),
                    pose: nil
                ),
                lighting: nil
            ))
        )

        XCTAssertEqual(first.state.geometryRevision, 1)
        XCTAssertEqual(duplicate.state, first.state)
        XCTAssertTrue(duplicate.effects.isEmpty)
        XCTAssertEqual(wrongRevision.state, first.state)
        XCTAssertTrue(wrongRevision.effects.isEmpty)
        XCTAssertEqual(first.state.target, PreviewGeometry.target(
            viewportWidthPoints: 390,
            viewportHeightPoints: 700
        ))
    }

    private func fixture(
        raw: (Double, Double),
        oriented: (Double, Double),
        viewport: (Double, Double),
        mirrored: Bool = true,
        rotation: FrameQuarterTurn = .degrees0,
        visionPolicy: VisionOrientationPolicy = .bufferAlreadyOriented,
        revision: UInt64 = 1
    ) -> FrameTransformSnapshot {
        FrameTransformSnapshot(
            geometryRevision: revision,
            rawBufferPixels: .init(width: raw.0, height: raw.1),
            orientedImagePixels: .init(width: oriented.0, height: oriented.1),
            rawToOrientedRotation: rotation,
            visionOrientationPolicy: visionPolicy,
            cleanAperturePolicy: .fullBuffer,
            viewportPoints: .init(width: viewport.0, height: viewport.1),
            interfaceOrientation: .portrait,
            isPreviewMirrored: mirrored
        )
    }

    private func assertGeometry(
        _ geometry: FaceGeometry?,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(geometry, file: file, line: line)
        XCTAssertEqual(geometry!.centerX, centerX, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(geometry!.centerY, centerY, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(geometry!.width, width, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(geometry!.height, height, accuracy: 0.000_001, file: file, line: line)
    }

    private func assertPoint(
        _ point: NormalizedViewportPoint?,
        _ expected: NormalizedViewportPoint,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(point, message, file: file, line: line)
        XCTAssertEqual(point!.x, expected.x, accuracy: 0.000_001, message, file: file, line: line)
        XCTAssertEqual(point!.y, expected.y, accuracy: 0.000_001, message, file: file, line: line)
    }
}

private struct LabeledCorner {
    let label: String
    let raw: RawBufferPoint
    let expected: NormalizedViewportPoint
}

private struct AsymmetricLumaFixture {
    struct Sample {
        let point: RawBufferPoint
        let luma: UInt8
    }

    let rawLeft: Sample
    let rawRight: Sample
}
