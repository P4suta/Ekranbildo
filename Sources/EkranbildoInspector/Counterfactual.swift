import EkranbildoLayout
import EkranbildoObservability

public struct Counterfactual: Sendable {
    private let comparator: LexicographicComparator

    public init(comparator: LexicographicComparator = LexicographicComparator()) {
        self.comparator = comparator
    }

    public struct Change: Hashable, Sendable {
        public let group: ObjectiveGroup
        public let wasTolerance: Double
        public let tolerance: Double
    }

    public enum Answer: Hashable, Sendable {
        case alreadyPreferred
        case impossible
        case widen([Change])

        public var canonicalText: String {
            switch self {
            case .alreadyPreferred:
                return "already preferred"
            case .impossible:
                return "nothing would do it: it is nowhere better"
            case .widen(let changes):
                return
                    changes
                    .map {
                        "\($0.group) would have to stop deciding: "
                            + "tolerance \(CanonicalText.rounded($0.wasTolerance, places: Places.tolerance)) "
                            + "-> \(CanonicalText.rounded($0.tolerance, places: Places.tolerance))"
                    }
                    .joined(separator: "\n")
            }
        }

        private enum Places {
            static let tolerance = 3
        }
    }

    public func toPrefer(_ wanted: GroupScores, over chosen: GroupScores) -> Answer {
        guard
            let strength = ObjectiveGroup.allCases.first(where: { wanted[$0] < chosen[$0] })
        else {
            return .impossible
        }

        var changes: [Change] = []
        for group in ObjectiveGroup.allCases where group.rawValue < strength.rawValue {
            let difference =
                comparator.bucket(wanted[group], in: group)
                - comparator.bucket(chosen[group], in: group)
            if difference < 0 {
                return .alreadyPreferred
            }
            if difference == 0 {
                continue
            }
            changes.append(
                Change(
                    group: group,
                    wasTolerance: comparator.tolerances[group],
                    tolerance: Self.tying(wanted[group], chosen[group])
                ))
        }

        guard !changes.isEmpty else { return .alreadyPreferred }
        return .widen(changes)
    }

    static func tying(_ first: Double, _ second: Double) -> Double {
        max(first, second) * Widening.margin
    }

    private enum Widening {
        static let margin = 1.001
    }
}
