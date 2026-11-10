public enum Finishing: String, Hashable, Sendable, CaseIterable, Comparable {
    case smoothThePointer
    case showClicks
    case showKeystrokes
    case cutDeadTime

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .smoothThePointer: "Smooth the pointer"
        case .showClicks: "Show clicks"
        case .showKeystrokes: "Show the keys that were pressed"
        case .cutDeadTime: "Cut out the parts where nothing happens"
        }
    }
}

public struct Polish: Hashable, Sendable {
    private let steps: [Finishing]

    public init(wanted: [Finishing]) {
        steps = Finishing.allCases.filter(wanted.contains)
    }

    public func wants(_ step: Finishing) -> Bool { steps.contains(step) }

    public var asked: [Finishing] { steps }
}

extension Settings {
    public var polish: Polish {
        Polish(wanted: Finishing.allCases.filter(isOn))
    }

    public func isOn(_ step: Finishing) -> Bool {
        switch step {
        case .smoothThePointer: smoothsThePointer
        case .showClicks: showsClicks
        case .showKeystrokes: showsKeystrokes
        case .cutDeadTime: cutsDeadTime
        }
    }

    public mutating func turn(_ step: Finishing, on wanted: Bool) {
        switch step {
        case .smoothThePointer: smoothsThePointer = wanted
        case .showClicks: showsClicks = wanted
        case .showKeystrokes: showsKeystrokes = wanted
        case .cutDeadTime: cutsDeadTime = wanted
        }
    }
}
