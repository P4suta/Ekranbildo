public struct P2: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Self(x: 0, y: 0)

    public static func + (a: Self, b: Self) -> Self { Self(x: a.x + b.x, y: a.y + b.y) }
    public static func - (a: Self, b: Self) -> Self { Self(x: a.x - b.x, y: a.y - b.y) }
    public static func * (p: Self, s: Double) -> Self { Self(x: p.x * s, y: p.y * s) }
    public static func * (s: Double, p: Self) -> Self { p * s }
    public static prefix func - (p: Self) -> Self { Self(x: -p.x, y: -p.y) }

    public func dot(_ other: Self) -> Double { x * other.x + y * other.y }

    public func cross(_ other: Self) -> Double { x * other.y - y * other.x }

    public var lengthSquared: Double { x * x + y * y }

    public var isFinite: Bool { x.isFinite && y.isFinite }
}

public struct Size: Hashable, Sendable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = Self(width: 0, height: 0)

    public var area: Double { width * height }
    public var isFinite: Bool { width.isFinite && height.isFinite }
    public var isValid: Bool { isFinite && width >= 0 && height >= 0 }
}

public struct Rect: Hashable, Sendable, Codable {
    public var origin: P2
    public var size: Size

    public init(origin: P2, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: P2(x: x, y: y), size: Size(width: width, height: height))
    }

    public init(centredOn centre: P2, size: Size) {
        self.init(
            x: centre.x - Geo.half(size.width),
            y: centre.y - Geo.half(size.height),
            width: size.width,
            height: size.height
        )
    }

    public var radius: Double { Geo.half(min(size.width, size.height)) }

    public static let zero = Self(origin: .zero, size: .zero)

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public var area: Double { size.area }
    public var center: P2 {
        P2(x: origin.x + Geo.half(size.width), y: origin.y + Geo.half(size.height))
    }

    public var isFinite: Bool { origin.isFinite && size.isFinite }
    public var isValid: Bool { origin.isFinite && size.isValid }

    public var corners: [P2] {
        [
            P2(x: minX, y: minY),
            P2(x: maxX, y: minY),
            P2(x: maxX, y: maxY),
            P2(x: minX, y: maxY),
        ]
    }

    public var edges: [Segment] {
        let corner = corners
        return [
            Segment(a: corner[0], b: corner[1]),
            Segment(a: corner[1], b: corner[2]),
            Segment(a: corner[2], b: corner[3]),
            Segment(a: corner[3], b: corner[0]),
        ]
    }

    public func contains(_ point: P2) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func contains(_ other: Self) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }

    public func intersection(_ other: Self) -> Self? {
        let left = max(minX, other.minX)
        let top = max(minY, other.minY)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return nil }
        return Self(x: left, y: top, width: right - left, height: bottom - top)
    }

    public func inset(by amount: Double) -> Self {
        let insetWidth = size.width - 2 * amount
        let insetHeight = size.height - 2 * amount
        return Self(
            x: origin.x + amount,
            y: origin.y + amount,
            width: insetWidth > 0 ? insetWidth : 0,
            height: insetHeight > 0 ? insetHeight : 0
        )
    }
}

public struct Segment: Hashable, Sendable, Codable {
    public var a: P2
    public var b: P2

    public init(a: P2, b: P2) {
        self.a = a
        self.b = b
    }

    public var delta: P2 { b - a }
    public var lengthSquared: Double { delta.lengthSquared }
    public var isFinite: Bool { a.isFinite && b.isFinite }
}

public struct Polyline: Hashable, Sendable, Codable {
    public var points: [P2]

    public init(points: [P2]) {
        self.points = points
    }

    public var segments: [Segment] {
        guard points.count >= 2 else { return [] }
        var result: [Segment] = []
        result.reserveCapacity(points.count - 1)
        for index in 0..<(points.count - 1) {
            result.append(Segment(a: points[index], b: points[index + 1]))
        }
        return result
    }

    public var isFinite: Bool { points.allSatisfy(\.isFinite) }
}
