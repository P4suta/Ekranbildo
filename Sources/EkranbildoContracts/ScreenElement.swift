public struct ScreenElement: Hashable, Sendable, Codable {
    public let rect: SceneRect
    public let kind: Kind
    public let text: String?
    public let confidence: Double
    public let provenance: Provenance

    public enum Kind: String, Hashable, Sendable, Codable {
        case surface
        case text
        case canvas
    }

    public enum Provenance: String, Hashable, Sendable, Codable {
        case regionAnalysis
        case textRecognition
        case given
    }

    public init(
        rect: SceneRect,
        kind: Kind,
        text: String? = nil,
        confidence: Double,
        provenance: Provenance
    ) {
        self.rect = rect
        self.kind = kind
        self.text = text
        self.confidence = confidence
        self.provenance = provenance
    }
}
