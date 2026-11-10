import EkranbildoContracts
import EkranbildoGeometry

public enum Icon: String, Hashable, Sendable, Codable, CaseIterable {
    case tick
    case cross
    case dot
    case masked
    case pointer

    public func path(in box: SceneRect) -> Path {
        guard box.raw.width > 0, box.raw.height > 0 else { return Path(elements: []) }

        if self == .dot {
            return Path.circle(
                centre: ScenePoint(x: box.raw.center.x, y: box.raw.center.y),
                radius: min(box.raw.width, box.raw.height) * Unit.dotRadius
            )
        }

        return Path(
            elements: Self.closed(
                Outline.of(self).map { corner in
                    ScenePoint(
                        x: box.minX + corner.x * box.raw.width,
                        y: box.minY + corner.y * box.raw.height
                    )
                }
            )
        )
    }

    static func closed(_ corners: [ScenePoint]) -> [PathElement] {
        guard let first = corners.first else { return [] }
        return [.move(first)] + corners.dropFirst().map { PathElement.line($0) } + [.close]
    }

    enum Outline {
        static func of(_ icon: Icon) -> [P2] {
            switch icon {
            case .tick: tick
            case .cross: cross
            case .masked: masked
            case .pointer: pointer
            case .dot: []
            }
        }

        static let tick: [P2] = [
            P2(x: 0.08, y: 0.52),
            P2(x: 0.20, y: 0.40),
            P2(x: 0.40, y: 0.60),
            P2(x: 0.80, y: 0.16),
            P2(x: 0.92, y: 0.28),
            P2(x: 0.40, y: 0.86),
        ]

        static let cross: [P2] = [
            P2(x: 0.14, y: 0.26),
            P2(x: 0.26, y: 0.14),
            P2(x: 0.50, y: 0.38),
            P2(x: 0.74, y: 0.14),
            P2(x: 0.86, y: 0.26),
            P2(x: 0.62, y: 0.50),
            P2(x: 0.86, y: 0.74),
            P2(x: 0.74, y: 0.86),
            P2(x: 0.50, y: 0.62),
            P2(x: 0.26, y: 0.86),
            P2(x: 0.14, y: 0.74),
            P2(x: 0.38, y: 0.50),
        ]

        static let masked: [P2] = [
            P2(x: 0.06, y: 0.24),
            P2(x: 0.94, y: 0.24),
            P2(x: 0.94, y: 0.76),
            P2(x: 0.06, y: 0.76),
        ]

        static let pointer: [P2] = [
            P2(x: Unit.pointerTipX, y: Unit.pointerTipY),
            P2(x: 0.78, y: 0.52),
            P2(x: 0.52, y: 0.55),
            P2(x: 0.66, y: 0.90),
            P2(x: 0.52, y: 0.96),
            P2(x: 0.38, y: 0.62),
            P2(x: Unit.pointerTipX, y: 0.84),
        ]
    }

    public var hotSpot: P2 {
        switch self {
        case .pointer:
            return P2(x: Unit.pointerTipX, y: Unit.pointerTipY)
        case .tick, .cross, .dot, .masked:
            return P2(x: Unit.middle, y: Unit.middle)
        }
    }

    public func box(size: Double, pointingAt point: ScenePoint) -> SceneRect {
        SceneRect(
            x: point.x - hotSpot.x * size,
            y: point.y - hotSpot.y * size,
            width: size,
            height: size
        )
    }

    private enum Unit {
        static let dotRadius: Double = 0.4
        static let middle: Double = 0.5
        static let pointerTipX: Double = 0.22
        static let pointerTipY: Double = 0.06
    }
}
