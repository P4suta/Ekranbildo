import EkranbildoContracts
import EkranbildoCore
import EkranbildoField
import EkranbildoGeometry

public struct TermID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    public static func < (a: Self, b: Self) -> Bool { a.name < b.name }
    public var description: String { name }
}

public protocol UnaryScoreTerm: Sendable {
    var identifier: TermID { get }
    var group: ObjectiveGroup { get }
    var calibrationConstants: [CalibrationConstant] { get }

    func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized
}

public protocol PairScoreTerm: Sendable {
    var identifier: TermID { get }
    var group: ObjectiveGroup { get }
    var calibrationConstants: [CalibrationConstant] { get }

    func evaluate(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Normalized
}

public struct LabelClearance: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("labelClearance") }
    public var group: ObjectiveGroup { .clearance }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.clearSpace, badness: .best),
            Calibration.Anchor(raw: Anchors.halfCovered, badness: .worst),
        ]
    )

    private enum Anchors {
        static let clearSpace: Double = 0
        static let halfCovered: Double = 0.5
    }

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        Self.calibration.normalize(problem.field.meanCost(in: candidate.labelRect))
    }
}

public struct LeaderClearance: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("leaderClearance") }
    public var group: ObjectiveGroup { .clearance }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
            + [CalibrationConstant(name: "corridorWidthInStrokes", value: Anchors.corridorWidthInStrokes)]
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.clearCorridor, badness: .best),
            Calibration.Anchor(raw: Anchors.crowdedCorridor, badness: .worst),
        ]
    )

    private enum Anchors {
        static let clearCorridor: Double = 0
        static let crowdedCorridor: Double = 0.4
        static let corridorWidthInStrokes: Double = 2
    }

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        let halfWidth = problem.style.leaderWidth * Anchors.corridorWidthInStrokes
        return Self.calibration.normalize(
            problem.field.corridorCost(candidate.leader, halfWidth: halfWidth)
        )
    }
}

public struct TargetAmbiguity: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("targetAmbiguity") }
    public var group: ObjectiveGroup { .targetClarity }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.unmistakable, badness: .best),
            Calibration.Anchor(raw: Anchors.coinToss, badness: .worst),
        ]
    )

    private enum Anchors {
        static let unmistakable: Double = 0.05
        static let coinToss: Double = 0.5
    }

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        let tip = candidate.tip.raw
        let own = Geo.distanceSquared(from: tip, to: problem.targets[candidate.annotationIndex].raw)

        var nearestOther = Double.infinity
        for (index, target) in problem.targets.enumerated() where index != candidate.annotationIndex {
            nearestOther = min(nearestOther, Geo.distanceSquared(from: tip, to: target.raw))
        }
        guard nearestOther.isFinite, nearestOther > 0 else {
            return nearestOther.isFinite ? .worst : .best
        }
        return Self.calibration.normalize((own / nearestOther).squareRoot())
    }
}

public struct CanvasEdgeProximity: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("canvasEdgeProximity") }
    public var group: ObjectiveGroup { .readability }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.comfortable, badness: .best),
            Calibration.Anchor(raw: Anchors.crowdingTheEdge, badness: .worst),
        ]
    )

    private enum Anchors {
        static let comfortable: Double = 24
        static let crowdingTheEdge: Double = 4
    }

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        let label = candidate.labelRect.raw
        let canvas = problem.canvas.raw
        let clearance = min(
            min(label.minX - canvas.minX, canvas.maxX - label.maxX),
            min(label.minY - canvas.minY, canvas.maxY - label.maxY)
        )
        return Self.calibration.normalize(clearance)
    }
}

public struct AxisAlignment: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("axisAlignment") }
    public var group: ObjectiveGroup { .aesthetics }
    public var calibrationConstants: [CalibrationConstant] {
        [CalibrationConstant(name: "axisPenalty", value: Self.axisPenalty)]
    }

    private static let penalty = Normalized(axisPenalty)
    private static let axisPenalty = 0.6

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        candidate.placement.direction.isAxisAligned ? Self.penalty : .best
    }
}

public struct LeaderLengthPreference: UnaryScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("leaderLength") }
    public var group: ObjectiveGroup { .aesthetics }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
            + [CalibrationConstant(name: "preferred", value: Self.preferred)]
    }

    private static let preferred: Double = 64
    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.onTarget, badness: .best),
            Calibration.Anchor(raw: Anchors.farOff, badness: .worst),
        ]
    )

    private enum Anchors {
        static let onTarget: Double = 0
        static let farOff: Double = 60
    }

    public func evaluate(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> Normalized {
        let deviation = abs(candidate.placement.leaderLength - Self.preferred)
        return Self.calibration.normalize(deviation)
    }
}

public struct DirectionConsistency: PairScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("directionConsistency") }
    public var group: ObjectiveGroup { .consistency }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.sameDirection, badness: .best),
            Calibration.Anchor(raw: Anchors.opposite, badness: .worst),
        ]
    )

    private enum Anchors {
        static let sameDirection: Double = 0
        static let opposite = Double(Direction16.allCases.count / 2)
    }

    public func evaluate(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Normalized {
        let steps = first.placement.direction.stepDistance(to: second.placement.direction)
        return Self.calibration.normalize(Double(steps))
    }
}

public struct LengthConsistency: PairScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("lengthConsistency") }
    public var group: ObjectiveGroup { .consistency }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.identical, badness: .best),
            Calibration.Anchor(raw: Anchors.unrelated, badness: .worst),
        ]
    )

    private enum Anchors {
        static let identical: Double = 0
        static let unrelated: Double = 80
    }

    public func evaluate(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Normalized {
        Self.calibration.normalize(
            abs(first.placement.leaderLength - second.placement.leaderLength)
        )
    }
}

public struct LabelProximity: PairScoreTerm {
    public init() {}

    public var identifier: TermID { TermID("labelProximity") }
    public var group: ObjectiveGroup { .clearance }
    public var calibrationConstants: [CalibrationConstant] {
        Self.calibration.constants
    }

    private static let calibration = Calibration(
        anchors: [
            Calibration.Anchor(raw: Anchors.roomy, badness: .best),
            Calibration.Anchor(raw: Anchors.touching, badness: .worst),
        ]
    )

    private enum Anchors {
        static let roomy: Double = 48
        static let touching: Double = 0
    }

    public func evaluate(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> Normalized {
        let gap = Geo.gapSquared(first.labelRect.raw, second.labelRect.raw).squareRoot()
        return Self.calibration.normalize(gap)
    }
}

public enum ScoreTerms {
    public static let unary: [any UnaryScoreTerm] = [
        CanvasEdgeProximity(),
        TargetAmbiguity(),
        LabelClearance(),
        LeaderClearance(),
        AxisAlignment(),
        LeaderLengthPreference(),
    ]

    public static let pair: [any PairScoreTerm] = [
        LabelProximity(),
        DirectionConsistency(),
        LengthConsistency(),
    ]
}
