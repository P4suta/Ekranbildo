import EkranbildoCore
import EkranbildoGeometry

public struct SolverBudget: Sendable, Equatable, Codable {
    public var candidatesPerAnnotation: Int
    public var maxUnaryEvaluations: Int
    public var maxPairEvaluations: Int
    public var maxSearchNodes: Int
    public var exactSolveLimit: Int
    public var refinementSweeps: Int
    public var candidatesRecordedPerAnnotation: Int

    public init(
        candidatesPerAnnotation: Int = Defaults.candidatesPerAnnotation,
        maxUnaryEvaluations: Int = Defaults.maxUnaryEvaluations,
        maxPairEvaluations: Int = Defaults.maxPairEvaluations,
        maxSearchNodes: Int = Defaults.maxSearchNodes,
        exactSolveLimit: Int = Defaults.exactSolveLimit,
        refinementSweeps: Int = Defaults.refinementSweeps,
        candidatesRecordedPerAnnotation: Int = Defaults.candidatesRecordedPerAnnotation
    ) {
        self.candidatesPerAnnotation = candidatesPerAnnotation
        self.maxUnaryEvaluations = maxUnaryEvaluations
        self.maxPairEvaluations = maxPairEvaluations
        self.maxSearchNodes = maxSearchNodes
        self.exactSolveLimit = exactSolveLimit
        self.refinementSweeps = refinementSweeps
        self.candidatesRecordedPerAnnotation = candidatesRecordedPerAnnotation
    }

    public static let standard = Self()

    public enum Defaults {
        public static let candidatesPerAnnotation = 24

        public static let maxSearchNodes = 400_000

        public static let maxPairEvaluations = 2_000_000

        public static let maxUnaryEvaluations = 200_000

        public static let exactSolveLimit = 8

        public static let refinementSweeps = 12

        public static let candidatesRecordedPerAnnotation = 8
    }
}

public struct WorkUnitCounters: Sendable, Equatable, Codable {
    public var candidatesGenerated = 0
    public var unaryEvaluations = 0
    public var pairEvaluations = 0
    public var searchNodes = 0
    public var prunedBranches = 0
    public var refinementMoves = 0

    public init() {}
}

public struct LayoutAssignment: Hashable, Sendable, Codable {
    public let annotationID: AnnotationID
    public let annotationIndex: Int
    public let placement: Placement
    public let candidateID: CandidateID

    public init(
        annotationID: AnnotationID,
        annotationIndex: Int,
        placement: Placement,
        candidateID: CandidateID
    ) {
        self.annotationID = annotationID
        self.annotationIndex = annotationIndex
        self.placement = placement
        self.candidateID = candidateID
    }
}

public struct UnplacedAnnotation: Hashable, Sendable, Codable {
    public let annotationID: AnnotationID
    public let reason: String

    public init(annotationID: AnnotationID, reason: String) {
        self.annotationID = annotationID
        self.reason = reason
    }
}
