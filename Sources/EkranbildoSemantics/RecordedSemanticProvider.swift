import EkranbildoContracts

public struct RecordedSemanticProvider: SemanticProvider {
    private let snapshot: SceneSemantics

    public init(_ snapshot: SceneSemantics) {
        self.snapshot = snapshot
    }

    public var version: String { snapshot.providerVersion }

    public func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
        let asked = SceneRect(
            x: 0, y: 0, width: Double(image.width), height: Double(image.height))
        guard asked == snapshot.canvas else {
            throw SemanticsError(
                code: SemanticsError.snapshotMismatch,
                detail: """
                    this answer was recorded for \(snapshot.canvas.canonicalText), \
                    not \(asked.canonicalText)
                    """
            )
        }
        return snapshot
    }
}
