import EkranbildoGeometry

public enum ReadingDirection: String, Hashable, Sendable, Codable, CaseIterable {
    case leftToRight
    case rightToLeft

    public var leading: Direction16 {
        switch self {
        case .leftToRight: .w
        case .rightToLeft: .e
        }
    }

    public var trailing: Direction16 {
        switch self {
        case .leftToRight: .e
        case .rightToLeft: .w
        }
    }

    public var mirrored: Self {
        switch self {
        case .leftToRight: .rightToLeft
        case .rightToLeft: .leftToRight
        }
    }
}
