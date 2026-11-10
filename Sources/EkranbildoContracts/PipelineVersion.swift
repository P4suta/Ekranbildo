public struct PipelineVersion: Hashable, Sendable, Codable {
    public let candidateGeneration: String
    public let normalization: String
    public let weights: String
    public let comparator: String
    public let renderer: String
    public let visionRevision: String

    public init(
        candidateGeneration: String,
        normalization: String,
        weights: String,
        comparator: String,
        renderer: String,
        visionRevision: String
    ) {
        self.candidateGeneration = candidateGeneration
        self.normalization = normalization
        self.weights = weights
        self.comparator = comparator
        self.renderer = renderer
        self.visionRevision = visionRevision
    }

    public var canonicalText: String {
        "pipeline candidates=\(candidateGeneration) normalization=\(normalization) "
            + "weights=\(weights) comparator=\(comparator) renderer=\(renderer) "
            + "vision=\(visionRevision)"
    }

    public static let unnamed = "-"

    public func with(renderer: String, visionRevision: String) -> Self {
        Self(
            candidateGeneration: candidateGeneration,
            normalization: normalization,
            weights: weights,
            comparator: comparator,
            renderer: renderer,
            visionRevision: visionRevision
        )
    }

    public func canComparedWith(_ other: Self) -> Bool { self == other }

    public static func stamp(_ recorded: String?, matches current: Self) -> String? {
        guard let recorded, recorded != current.canonicalText else { return nil }
        return recorded
    }
}
