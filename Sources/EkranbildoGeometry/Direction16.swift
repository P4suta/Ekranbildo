public enum Direction16: UInt8, CaseIterable, Sendable, Codable, Comparable {
    case e = 0
    case ene = 1
    case ne = 2
    case nne = 3
    case n = 4
    case nnw = 5
    case nw = 6
    case wnw = 7
    case w = 8
    case wsw = 9
    case sw = 10
    case ssw = 11
    case s = 12
    case sse = 13
    case se = 14
    case ese = 15

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    @usableFromInline static let cos22Point5 = 0.923_879_532_511_286_8
    @usableFromInline static let cos45 = 0.707_106_781_186_547_6
    @usableFromInline static let cos67Point5 = 0.382_683_432_365_089_8

    @inlinable
    public var unit: P2 {
        switch self {
        case .e: P2(x: 1, y: 0)
        case .ene: P2(x: Self.cos22Point5, y: -Self.cos67Point5)
        case .ne: P2(x: Self.cos45, y: -Self.cos45)
        case .nne: P2(x: Self.cos67Point5, y: -Self.cos22Point5)
        case .n: P2(x: 0, y: -1)
        case .nnw: P2(x: -Self.cos67Point5, y: -Self.cos22Point5)
        case .nw: P2(x: -Self.cos45, y: -Self.cos45)
        case .wnw: P2(x: -Self.cos22Point5, y: -Self.cos67Point5)
        case .w: P2(x: -1, y: 0)
        case .wsw: P2(x: -Self.cos22Point5, y: Self.cos67Point5)
        case .sw: P2(x: -Self.cos45, y: Self.cos45)
        case .ssw: P2(x: -Self.cos67Point5, y: Self.cos22Point5)
        case .s: P2(x: 0, y: 1)
        case .sse: P2(x: Self.cos67Point5, y: Self.cos22Point5)
        case .se: P2(x: Self.cos45, y: Self.cos45)
        case .ese: P2(x: Self.cos22Point5, y: Self.cos67Point5)
        }
    }

    @usableFromInline static let count = UInt8(Self.allCases.count)
    @usableFromInline static let halfTurn = count / 2

    @inlinable
    public var opposite: Self {
        Self(rawValue: (rawValue + Self.halfTurn) % Self.count)!
    }

    @inlinable
    public var mirroredHorizontally: Self {
        let turn = Int(Self.count) + Int(Self.halfTurn) - Int(rawValue)
        return Self(rawValue: UInt8(turn % Int(Self.count)))!
    }

    @inlinable
    public var mirroredVertically: Self {
        let turn = Int(Self.count) - Int(rawValue)
        return Self(rawValue: UInt8(turn % Int(Self.count)))!
    }

    @inlinable
    public func stepDistance(to other: Self) -> Int {
        let raw = abs(Int(rawValue) - Int(other.rawValue))
        return min(raw, Int(Self.count) - raw)
    }

    @inlinable
    public var isAxisAligned: Bool {
        self == .e || self == .n || self == .w || self == .s
    }
}

extension Direction16 {
    public static func nearest(to offset: P2) -> Self {
        guard offset.isFinite, offset.lengthSquared > 0 else { return .e }
        var best = Self.e
        var bestAlignment = -Double.infinity
        for direction in Self.allCases {
            let alignment = direction.unit.dot(offset)
            guard alignment > bestAlignment else { continue }
            bestAlignment = alignment
            best = direction
        }
        return best
    }
}
