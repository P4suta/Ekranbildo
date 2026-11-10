public enum Bisection {

    public enum Outcome: Hashable, Sendable {
        case nothingToSearch
        case noneDiffer
        case allDiffer(oldest: String)
        case found(version: String, previous: String)
    }

    public struct Search: Hashable, Sendable {
        public let outcome: Outcome
        public let probes: Int

        public init(outcome: Outcome, probes: Int) {
            self.outcome = outcome
            self.probes = probes
        }

        public var report: String {
            switch outcome {
            case .nothingToSearch:
                "no versions to search"
            case .noneDiffer:
                "the newest version still gives the recorded answer (\(probes) build asked)"
            case .allDiffer(let oldest):
                "every version differs, including the oldest offered (\(oldest)); "
                    + "whatever changed the answer is older than the range (\(probes) build asked)"
            case .found(let version, let previous):
                "\(version) differs and \(previous) does not, in \(probes) builds asked"
            }
        }
    }

    public static func firstDiffering(
        over versions: [String],
        matching recorded: String,
        answer: (String) throws -> String
    ) rethrows -> Search {
        guard let oldest = versions.first, let newest = versions.last else {
            return Search(outcome: .nothingToSearch, probes: 0)
        }

        var probes = 0
        func differs(_ version: String) throws -> Bool {
            probes += 1
            return try answer(version) != recorded
        }

        guard try differs(newest) else {
            return Search(outcome: .noneDiffer, probes: probes)
        }
        guard versions.count > 1 else {
            return Search(outcome: .allDiffer(oldest: oldest), probes: probes)
        }
        guard try !differs(oldest) else {
            return Search(outcome: .allDiffer(oldest: oldest), probes: probes)
        }

        var agreeing = versions.startIndex
        var differing = versions.index(before: versions.endIndex)
        while differing - agreeing > Adjacent.gap {
            let middle = agreeing + (differing - agreeing) / Halving.divisor
            if try differs(versions[middle]) {
                differing = middle
            } else {
                agreeing = middle
            }
        }

        return Search(
            outcome: .found(version: versions[differing], previous: versions[agreeing]),
            probes: probes
        )
    }

    private enum Adjacent {
        static let gap = 1
    }

    private enum Halving {
        static let divisor = 2
    }
}
