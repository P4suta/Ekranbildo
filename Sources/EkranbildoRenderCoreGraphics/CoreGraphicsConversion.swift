import CoreGraphics
import EkranbildoContracts

extension CoreGraphicsRenderer {
    enum Shadowing {
        static let blurToRadius: Double = 2
    }

    static func makePath(_ path: Path) -> CGPath? {
        guard !path.isEmpty else { return nil }
        let cgPath = CGMutablePath()
        for element in path.elements {
            switch element {
            case .move(let point):
                cgPath.move(to: CGPoint(x: point.x, y: point.y))
            case .line(let point):
                cgPath.addLine(to: CGPoint(x: point.x, y: point.y))
            case .quadCurve(let to, let control):
                cgPath.addQuadCurve(
                    to: CGPoint(x: to.x, y: to.y),
                    control: CGPoint(x: control.x, y: control.y)
                )
            case .cubicCurve(let to, let control1, let control2):
                cgPath.addCurve(
                    to: CGPoint(x: to.x, y: to.y),
                    control1: CGPoint(x: control1.x, y: control1.y),
                    control2: CGPoint(x: control2.x, y: control2.y)
                )
            case .close:
                cgPath.closeSubpath()
            }
        }
        return cgPath.isEmpty ? nil : cgPath
    }

    static func cgColor(_ color: Color, in context: CGContext) -> CGColor {
        CGColor(
            colorSpace: context.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            components: [
                CGFloat(color.red), CGFloat(color.green), CGFloat(color.blue), CGFloat(color.alpha),
            ]
        ) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    static func lineCap(_ cap: LineCap) -> CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    static func lineJoin(_ join: LineJoin) -> CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
