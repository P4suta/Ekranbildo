import EkranbildoGeometry

public struct Normalized: Hashable, Sendable, Codable, Comparable {
    public let value: Double

    public init(_ value: Double) {
        if value.isNaN {
            self.value = 1
        } else {
            self.value = value < 0 ? 0 : (value > 1 ? 1 : value)
        }
    }

    public static let best = Self(0)
    public static let worst = Self(1)

    public static func < (a: Self, b: Self) -> Bool { a.value < b.value }
}

public struct TieBreak: Sendable, Equatable {
    public let first: CandidateID
    public let second: CandidateID

    public init(_ first: CandidateID, _ second: CandidateID) {
        self.first = first
        self.second = second
    }

    public static let neither = Self(CandidateID(0), CandidateID(0))
}

public struct Calibration: Sendable, Equatable {
    public let anchors: [Anchor]

    public struct Anchor: Sendable, Equatable {
        public let raw: Double
        public let badness: Double

        public init(raw: Double, badness: Double) {
            self.raw = raw
            self.badness = badness
        }

        public init(raw: Double, badness: Normalized) {
            self.init(raw: raw, badness: badness.value)
        }
    }

    public init(anchors: [Anchor]) {
        self.anchors = anchors
    }

    public func normalize(_ raw: Double) -> Normalized {
        guard let first = anchors.first, let last = anchors.last else { return .worst }
        guard anchors.count > 1 else { return Normalized(first.badness) }

        let ascending = last.raw > first.raw
        if ascending {
            if raw <= first.raw { return Normalized(first.badness) }
            if raw >= last.raw { return Normalized(last.badness) }
        } else {
            if raw >= first.raw { return Normalized(first.badness) }
            if raw <= last.raw { return Normalized(last.badness) }
        }

        for index in 0..<(anchors.count - 1) {
            let low = anchors[index]
            let high = anchors[index + 1]
            let within = ascending ? (raw >= low.raw && raw <= high.raw) : (raw <= low.raw && raw >= high.raw)
            guard within else { continue }
            let span = high.raw - low.raw
            guard span != 0 else { return Normalized(low.badness) }
            let fraction = (raw - low.raw) / span
            return Normalized(low.badness + (high.badness - low.badness) * fraction)
        }
        return Normalized(last.badness)
    }
}

public enum ObjectiveGroup: Int, CaseIterable, Comparable, Sendable, Codable {
    case readability = 0
    case targetClarity
    case clearance
    case consistency
    case aesthetics

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct GroupScores: Hashable, Sendable, Codable {
    public var readability: Double = 0
    public var targetClarity: Double = 0
    public var clearance: Double = 0
    public var consistency: Double = 0
    public var aesthetics: Double = 0

    public init() {}

    public subscript(group: ObjectiveGroup) -> Double {
        get {
            switch group {
            case .readability: readability
            case .targetClarity: targetClarity
            case .clearance: clearance
            case .consistency: consistency
            case .aesthetics: aesthetics
            }
        }
        set {
            switch group {
            case .readability: readability = newValue
            case .targetClarity: targetClarity = newValue
            case .clearance: clearance = newValue
            case .consistency: consistency = newValue
            case .aesthetics: aesthetics = newValue
            }
        }
    }

    public var total: Double {
        var sum = DeterministicSum()
        sum.add(readability)
        sum.add(targetClarity)
        sum.add(clearance)
        sum.add(consistency)
        sum.add(aesthetics)
        return sum.value()
    }
}

public struct GroupTolerances: Sendable, Equatable {
    private let values: [Double]

    public init(values: [Double]) {
        var padded = values
        while padded.count < ObjectiveGroup.allCases.count { padded.append(0) }
        self.values = padded
    }

    public subscript(group: ObjectiveGroup) -> Double { values[group.rawValue] }

    public static let standard = Self(
        values: [
            Starting.readability,
            Starting.targetClarity,
            Starting.clearance,
            Starting.consistency,
            Starting.aesthetics,
        ]
    )

    private enum Starting {
        static let readability: Double = 0.02
        static let targetClarity: Double = 0.03
        static let clearance: Double = 0.05
        static let consistency: Double = 0.08
        static let aesthetics: Double = 0.10
    }
}

public struct ComparisonExplanation: Sendable, Equatable {
    public let decidingGroup: ObjectiveGroup?
    public let tiedGroups: [ObjectiveGroup]
    public let result: ComparisonResult
}

public enum ComparisonResult: Sendable, Equatable {
    case orderedAscending
    case orderedSame
    case orderedDescending
}

public struct LexicographicComparator: Sendable {
    public let tolerances: GroupTolerances

    public init(tolerances: GroupTolerances = .standard) {
        self.tolerances = tolerances
    }

    public func bucket(_ score: Double, in group: ObjectiveGroup) -> Double {
        let tolerance = tolerances[group]
        guard tolerance > 0 else { return score }
        return (score / tolerance).rounded(.down)
    }

    public func compare(
        _ first: GroupScores,
        _ second: GroupScores,
        tieBreak: TieBreak
    ) -> ComparisonResult {
        explain(first, second, tieBreak: tieBreak).result
    }

    public func explain(
        _ first: GroupScores,
        _ second: GroupScores,
        tieBreak: TieBreak
    ) -> ComparisonExplanation {
        var tied: [ObjectiveGroup] = []
        for group in ObjectiveGroup.allCases {
            let difference = bucket(first[group], in: group) - bucket(second[group], in: group)
            guard difference != 0 else {
                tied.append(group)
                continue
            }
            return ComparisonExplanation(
                decidingGroup: group,
                tiedGroups: tied,
                result: difference < 0 ? .orderedAscending : .orderedDescending
            )
        }

        let result: ComparisonResult
        if tieBreak.first == tieBreak.second {
            result = .orderedSame
        } else {
            result =
                tieBreak.first < tieBreak.second ? .orderedAscending : .orderedDescending
        }
        return ComparisonExplanation(decidingGroup: nil, tiedGroups: tied, result: result)
    }
}
