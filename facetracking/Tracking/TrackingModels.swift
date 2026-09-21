struct FaceGeometry: Sendable, Equatable {
    let centerX: Double
    let centerY: Double
    let width: Double
    let height: Double

    var isUsableInViewport: Bool {
        centerX.isFinite && centerY.isFinite && width.isFinite && height.isFinite
            && width > 0 && height > 0
            && centerX + width / 2 > 0 && centerX - width / 2 < 1
            && centerY + height / 2 > 0 && centerY - height / 2 < 1
    }
}

struct FacePose: Sendable, Equatable {
    let yawDegrees: Double
    let pitchDegrees: Double
    let rollDegrees: Double

    var isFinite: Bool {
        yawDegrees.isFinite && pitchDegrees.isFinite && rollDegrees.isFinite
    }
}

struct FaceSample: Sendable, Equatable {
    let geometry: FaceGeometry
    let pose: FacePose?

    var validated: FaceSample? {
        guard geometry.isUsableInViewport else { return nil }
        return FaceSample(geometry: geometry, pose: pose?.isFinite == true ? pose : nil)
    }
}

struct FaceLightingMetrics: Sendable, Equatable {
    let median: Double
    let globalTrimmedMean: Double
    let leftTrimmedMean: Double
    let rightTrimmedMean: Double
    let topTrimmedMean: Double
    let bottomTrimmedMean: Double
    let shadowFraction: Double
    let highlightFraction: Double
    let totalCount: Int
    let leftCount: Int
    let rightCount: Int
    let topCount: Int
    let bottomCount: Int
}

struct FrameObservation: Sendable, Equatable {
    let sessionID: UInt64
    let geometryRevision: UInt64
    let capturedAtMS: Int64
    /// Monotonic time when Vision completed successfully. Capture time drives
    /// face freshness; result time drives analysis-stall monitoring.
    let resultAtMS: Int64
    let face: FaceSample?
    let lighting: FaceLightingMetrics?

    init(
        sessionID: UInt64,
        geometryRevision: UInt64,
        capturedAtMS: Int64,
        resultAtMS: Int64? = nil,
        face: FaceSample?,
        lighting: FaceLightingMetrics?
    ) {
        self.sessionID = sessionID
        self.geometryRevision = geometryRevision
        self.capturedAtMS = capturedAtMS
        self.resultAtMS = resultAtMS ?? capturedAtMS
        self.face = face
        self.lighting = lighting
    }
}
