import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public enum RelaxationRung {
    public static let nothingRelaxed = 0
    public static let labelGap = 1
    public static let leaderCollisions = 2
    public static let leaderOverTarget = 3
}

public struct ConstraintID: Hashable, Sendable, CustomStringConvertible {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var description: String { name }
}

public protocol HardConstraint: Sendable {
    var identifier: ConstraintID { get }

    var relaxableAtRung: Int? { get }

    func isSatisfied(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Bool

    func isSatisfied(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Bool
}

extension HardConstraint {
    public func isSatisfied(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Bool { true }

    public func isSatisfied(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Bool { true }
}

public struct LabelInsideCanvas: HardConstraint {
    public let margin: Double

    public init(margin: Double = 4) {
        self.margin = margin
    }

    public var identifier: ConstraintID { ConstraintID("labelInsideCanvas") }
    public var relaxableAtRung: Int? { nil }

    public func isSatisfied(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Bool {
        problem.canvas.raw.inset(by: margin).contains(candidate.labelRect.raw)
    }
}

public struct LabelClearOfTargets: HardConstraint {
    public init() {}

    public var identifier: ConstraintID { ConstraintID("labelClearOfTargets") }
    public var relaxableAtRung: Int? { nil }

    public func isSatisfied(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Bool {
        for target in problem.targets where Geo.overlaps(candidate.labelRect.raw, target.raw) {
            return false
        }
        return true
    }
}

public struct LeaderClearOfTargets: HardConstraint {
    public init() {}

    public var identifier: ConstraintID { ConstraintID("leaderClearOfTargets") }
    public var relaxableAtRung: Int? { RelaxationRung.leaderOverTarget }

    public func isSatisfied(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Bool {
        let leader = candidate.leader
        for (index, target) in problem.targets.enumerated() where index != candidate.annotationIndex {
            if Geo.polylineIntersectsInterior(leader, of: target.raw) { return false }
        }
        return true
    }
}

public struct LabelsAreSeparated: HardConstraint {
    public let minimumGap: Double

    public init(minimumGap: Double) {
        self.minimumGap = minimumGap
    }

    public var identifier: ConstraintID { ConstraintID("labelsAreSeparated") }
    public var relaxableAtRung: Int? { RelaxationRung.labelGap }

    public func isSatisfied(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Bool {
        if Geo.overlaps(first.labelRect.raw, second.labelRect.raw) { return false }
        guard minimumGap > 0 else { return true }
        return Geo.gapSquared(first.labelRect.raw, second.labelRect.raw) >= minimumGap * minimumGap
    }
}

public struct LeadersDoNotCross: HardConstraint {
    public init() {}

    public var identifier: ConstraintID { ConstraintID("leadersDoNotCross") }
    public var relaxableAtRung: Int? { RelaxationRung.leaderCollisions }

    public func isSatisfied(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Bool {
        !Geo.polylinesConflict(first.leader, second.leader)
    }
}

public struct LeaderClearOfOtherLabels: HardConstraint {
    public init() {}

    public var identifier: ConstraintID { ConstraintID("leaderClearOfOtherLabels") }
    public var relaxableAtRung: Int? { RelaxationRung.leaderCollisions }

    public func isSatisfied(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Bool {
        !Geo.polylineIntersectsInterior(first.leader, of: second.labelRect.raw)
            && !Geo.polylineIntersectsInterior(second.leader, of: first.labelRect.raw)
    }
}

public enum HardConstraints {
    public static func standard(style: StyleTokens) -> [any HardConstraint] {
        [
            LabelInsideCanvas(),
            LabelClearOfTargets(),
            LeaderClearOfTargets(),
            LabelsAreSeparated(minimumGap: style.labelMinimumGap),
            LeadersDoNotCross(),
            LeaderClearOfOtherLabels(),
        ]
    }
}
