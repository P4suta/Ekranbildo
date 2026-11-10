import EkranbildoGeometry

public enum PathElement: Hashable, Sendable, Codable {
    case move(ScenePoint)
    case line(ScenePoint)
    case quadCurve(to: ScenePoint, control: ScenePoint)
    case cubicCurve(to: ScenePoint, control1: ScenePoint, control2: ScenePoint)
    case close

    public var referencedPoints: [ScenePoint] {
        switch self {
        case .move(let point), .line(let point):
            return [point]
        case .quadCurve(let to, let control):
            return [to, control]
        case .cubicCurve(let to, let control1, let control2):
            return [to, control1, control2]
        case .close:
            return []
        }
    }

    var canonicalText: String {
        switch self {
        case .move(let point):
            return "M \(DrawListFormat.number(point.x)) \(DrawListFormat.number(point.y))"
        case .line(let point):
            return "L \(DrawListFormat.number(point.x)) \(DrawListFormat.number(point.y))"
        case .quadCurve(let to, let control):
            return
                "Q \(DrawListFormat.number(control.x)) \(DrawListFormat.number(control.y)) "
                + "\(DrawListFormat.number(to.x)) \(DrawListFormat.number(to.y))"
        case .cubicCurve(let to, let control1, let control2):
            return
                "C \(DrawListFormat.number(control1.x)) \(DrawListFormat.number(control1.y)) "
                + "\(DrawListFormat.number(control2.x)) \(DrawListFormat.number(control2.y)) "
                + "\(DrawListFormat.number(to.x)) \(DrawListFormat.number(to.y))"
        case .close:
            return "Z"
        }
    }
}

public struct Path: Hashable, Sendable, Codable {
    public let elements: [PathElement]

    public init(elements: [PathElement]) {
        self.elements = elements
    }

    public var isEmpty: Bool { elements.isEmpty }

    public var bounds: SceneRect? {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        var sawPoint = false

        for element in elements {
            for point in element.referencedPoints {
                sawPoint = true
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
        }
        guard sawPoint else { return nil }
        return SceneRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var canonicalText: String {
        "[" + elements.map(\.canonicalText).joined(separator: "|") + "]"
    }

    public static func circle(centre: ScenePoint, radius: Double) -> Self {
        let diameter = max(0, radius) * Circle.diameter
        return roundedRect(
            SceneRect(
                x: centre.x - diameter / Circle.diameter,
                y: centre.y - diameter / Circle.diameter,
                width: diameter,
                height: diameter
            ),
            radius: diameter / Circle.diameter
        )
    }

    private enum Circle {
        static let diameter: Double = 2
    }

    public static func roundedRect(_ rect: SceneRect, radius: Double) -> Self {
        let limit = rect.raw.radius
        let corner = min(max(0, radius), limit)
        guard corner > 0 else { return .rect(rect) }

        let handle = corner * Geo.circleHandle

        func point(_ x: Double, _ y: Double) -> ScenePoint { ScenePoint(x: x, y: y) }
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY

        return Self(elements: [
            .move(point(left + corner, top)),
            .line(point(right - corner, top)),
            .cubicCurve(
                to: point(right, top + corner),
                control1: point(right - corner + handle, top),
                control2: point(right, top + corner - handle)
            ),
            .line(point(right, bottom - corner)),
            .cubicCurve(
                to: point(right - corner, bottom),
                control1: point(right, bottom - corner + handle),
                control2: point(right - corner + handle, bottom)
            ),
            .line(point(left + corner, bottom)),
            .cubicCurve(
                to: point(left, bottom - corner),
                control1: point(left + corner - handle, bottom),
                control2: point(left, bottom - corner + handle)
            ),
            .line(point(left, top + corner)),
            .cubicCurve(
                to: point(left + corner, top),
                control1: point(left, top + corner - handle),
                control2: point(left + corner - handle, top)
            ),
            .close,
        ])
    }

    public static func rect(_ rect: SceneRect) -> Self {
        Self(elements: [
            .move(ScenePoint(x: rect.minX, y: rect.minY)),
            .line(ScenePoint(x: rect.maxX, y: rect.minY)),
            .line(ScenePoint(x: rect.maxX, y: rect.maxY)),
            .line(ScenePoint(x: rect.minX, y: rect.maxY)),
            .close,
        ])
    }

    public static func polyline(_ polyline: Polyline) -> Self {
        guard let first = polyline.points.first else { return Self(elements: []) }
        var elements: [PathElement] = [.move(ScenePoint(first))]
        elements.reserveCapacity(polyline.points.count)
        for point in polyline.points.dropFirst() {
            elements.append(.line(ScenePoint(point)))
        }
        return Self(elements: elements)
    }

    public static func roundedRect(_ rect: SceneRect, cornerRadius: Double) -> Self {
        let limit = rect.radius
        let radius = max(0, min(cornerRadius, limit))
        if radius <= 0 { return .rect(rect) }

        let control = radius * (1 - CircularArc.controlPointRatio)

        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY

        return Self(elements: [
            .move(ScenePoint(x: minX + radius, y: minY)),
            .line(ScenePoint(x: maxX - radius, y: minY)),
            .cubicCurve(
                to: ScenePoint(x: maxX, y: minY + radius),
                control1: ScenePoint(x: maxX - control, y: minY),
                control2: ScenePoint(x: maxX, y: minY + control)
            ),
            .line(ScenePoint(x: maxX, y: maxY - radius)),
            .cubicCurve(
                to: ScenePoint(x: maxX - radius, y: maxY),
                control1: ScenePoint(x: maxX, y: maxY - control),
                control2: ScenePoint(x: maxX - control, y: maxY)
            ),
            .line(ScenePoint(x: minX + radius, y: maxY)),
            .cubicCurve(
                to: ScenePoint(x: minX, y: maxY - radius),
                control1: ScenePoint(x: minX + control, y: maxY),
                control2: ScenePoint(x: minX, y: maxY - control)
            ),
            .line(ScenePoint(x: minX, y: minY + radius)),
            .cubicCurve(
                to: ScenePoint(x: minX + radius, y: minY),
                control1: ScenePoint(x: minX, y: minY + control),
                control2: ScenePoint(x: minX + control, y: minY)
            ),
            .close,
        ])
    }
}

private enum CircularArc {
    static let controlPointRatio = 0.552_284_749_830_793_4
}
