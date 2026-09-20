enum CameraAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

struct SessionViewport: Sendable, Equatable {
    let widthPoints: Double
    let heightPoints: Double
    let transformRevision: UInt64

    var isValid: Bool {
        widthPoints.isFinite && heightPoints.isFinite && widthPoints > 0 && heightPoints > 0
    }

    /// Bounds changes smaller than half a point are layout noise. The comparison
    /// remains against the last accepted viewport, so accumulated motion is not lost.
    /// A transform revision change is always meaningful, regardless of point jitter.
    func isMeaningfullyDifferent(from other: SessionViewport) -> Bool {
        transformRevision != other.transformRevision
            || isValid != other.isValid
            || widthPoints.isFinite != other.widthPoints.isFinite
            || heightPoints.isFinite != other.heightPoints.isFinite
            || abs(widthPoints - other.widthPoints) >= 0.5
            || abs(heightPoints - other.heightPoints) >= 0.5
    }
}

enum CameraStatus: Sendable, Equatable {
    case stopped
    case starting(sessionID: UInt64)
    case running(sessionID: UInt64)
    case stopping(sessionID: UInt64)
    case interrupted
}

enum SessionFailure: Sendable, Equatable {
    case frontCameraUnavailable
    case cameraUnavailable
    case detectorUnavailable
    case sessionIdentifierExhausted
    case geometryRevisionExhausted

    var isRetryable: Bool {
        switch self {
        case .sessionIdentifierExhausted, .geometryRevisionExhausted:
            false
        case .frontCameraUnavailable, .cameraUnavailable, .detectorUnavailable:
            true
        }
    }
}

enum LightingAssessment: Sendable, Equatable {
    case unknown
    case acceptable
    case dark
    case bright
    case uneven
}

enum LightingSide: Sendable, Equatable {
    case left
    case right
    case top
    case bottom
}

/// Storage needed by plan 07. Plan 02 deliberately leaves the assessment unknown.
struct LightingHistory: Sendable, Equatable {
    var activeAssessment: LightingAssessment = .unknown
    var activeSide: LightingSide?
    var candidateAssessment: LightingAssessment?
    var candidateSide: LightingSide?
    var candidateSinceMS: Int64?
    var acceptableEvidenceSinceMS: Int64?
    var previousSampleMS: Int64?

    static let empty = LightingHistory()
}

struct SessionState: Sendable, Equatable {
    var authorization: CameraAuthorization = .notDetermined
    var isSceneActive = false
    var isRoutePresent = false
    var viewport: SessionViewport?
    var geometryRevision: UInt64 = 0

    var lastAllocatedSessionID: UInt64 = 0
    var activeSessionID: UInt64?
    var desiredRunning = false
    var cameraStatus: CameraStatus = .stopped
    var isInterrupted = false

    var stage: TrackingStage = .aligning
    var rawFace: FaceSample?
    var lastAcceptedSampleMS: Int64?
    var positioningHistory: PositioningHistory = .empty
    var lightingHistory: LightingHistory = .empty

    var attemptStartedAtMS: Int64?
    var lastSuccessfulAnalysisMS: Int64?
    var failure: SessionFailure?

    var isTrackingLost: Bool {
        stage == .following && rawFace == nil
    }

    var target: FaceGeometry? {
        guard let viewport else { return nil }
        return PreviewGeometry.target(
            viewportWidthPoints: viewport.widthPoints,
            viewportHeightPoints: viewport.heightPoints
        )
    }

    var isEligibleToRun: Bool {
        authorization == .authorized
            && isSceneActive
            && isRoutePresent
            && viewport?.isValid == true
            && failure == nil
            && !isInterrupted
    }
}
