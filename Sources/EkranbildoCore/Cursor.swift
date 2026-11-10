import EkranbildoContracts

public struct Cursor: Hashable, Sendable, Codable {
    public let position: ScenePoint
    public let opacity: Double
    public let ripple: Double?

    public init(position: ScenePoint, opacity: Double = 1, ripple: Double? = nil) {
        self.position = position
        self.opacity = Self.clamped(opacity)
        self.ripple = ripple.map(Self.clamped)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            position: try container.decode(ScenePoint.self, forKey: .position),
            opacity: try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1,
            ripple: try container.decodeIfPresent(Double.self, forKey: .ripple)
        )
    }

    private static func clamped(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return value < 0 ? 0 : (value > 1 ? 1 : value)
    }
}
