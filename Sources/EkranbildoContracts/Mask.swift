public enum MaskStyle: String, Hashable, Sendable, Codable, CaseIterable {
    case solid
    case pixelate

    public var isIrreversible: Bool {
        switch self {
        case .solid, .pixelate: true
        }
    }
}

public struct Mask: Hashable, Sendable, Codable {
    public let rect: SceneRect
    public let style: MaskStyle

    public init(rect: SceneRect, style: MaskStyle = .pixelate) {
        self.rect = rect
        self.style = style
    }
}
