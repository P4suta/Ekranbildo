import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLayout
import EkranbildoObservability

enum ReportPrecision {
    static let places = 3
    static let marginPlaces = 5
}

public struct QualityMetrics: Sendable, Equatable {
    public let annotations: Int
    public let placed: Int
    public let unplaced: Int
    public let relaxationRung: Int

    public let labelCollisions: Int
    public let leaderCrossings: Int
    public let labelsOutsideCanvas: Int
    public let labelsOverTargets: Int

    public let meanPointingAmbiguity: Double
    public let worstPointingAmbiguity: Double

    public let axisAlignedLeaders: Int

    public let meanLabelClearance: Double

    public let meanDecisionMargin: Double
    public let minimumDecisionMargin: Double

    public let work: WorkUnitCounters

    public init(
        annotations: Int,
        placed: Int,
        unplaced: Int = 0,
        relaxationRung: Int = 0,
        labelCollisions: Int = 0,
        leaderCrossings: Int = 0,
        labelsOutsideCanvas: Int = 0,
        labelsOverTargets: Int = 0,
        meanPointingAmbiguity: Double = 0,
        worstPointingAmbiguity: Double = 0,
        axisAlignedLeaders: Int = 0,
        meanLabelClearance: Double = 0,
        meanDecisionMargin: Double = 0,
        minimumDecisionMargin: Double = 0,
        work: WorkUnitCounters = WorkUnitCounters()
    ) {
        self.annotations = annotations
        self.placed = placed
        self.unplaced = unplaced
        self.relaxationRung = relaxationRung
        self.labelCollisions = labelCollisions
        self.leaderCrossings = leaderCrossings
        self.labelsOutsideCanvas = labelsOutsideCanvas
        self.labelsOverTargets = labelsOverTargets
        self.meanPointingAmbiguity = meanPointingAmbiguity
        self.worstPointingAmbiguity = worstPointingAmbiguity
        self.axisAlignedLeaders = axisAlignedLeaders
        self.meanLabelClearance = meanLabelClearance
        self.meanDecisionMargin = meanDecisionMargin
        self.minimumDecisionMargin = minimumDecisionMargin
        self.work = work
    }

    public init(of solution: LayoutSolution, in problem: LayoutProblem) {
        annotations = problem.annotations.count
        placed = solution.assignments.count
        unplaced = solution.unplaced.count
        relaxationRung = solution.relaxationRung
        work = solution.work

        let placements = solution.assignments.map { assignment -> PlacedAnnotation in
            let resolved = ResolvedPlacement(
                target: problem.annotations[assignment.annotationIndex].target,
                placement: assignment.placement,
                style: problem.style
            )
            return PlacedAnnotation(
                index: assignment.annotationIndex,
                placement: assignment.placement,
                tip: resolved.tip,
                leader: resolved.leader,
                labelRect: resolved.labelBox(
                    textSize: problem.textSizes[assignment.annotationIndex],
                    style: problem.style
                )
            )
        }

        labelCollisions = Self.countCollisions(placements)
        leaderCrossings = Self.countCrossings(placements)
        labelsOutsideCanvas = placements.count { !problem.canvas.raw.contains($0.labelRect.raw) }
        labelsOverTargets = placements.count { placed in
            problem.targets.contains { Geo.overlaps(placed.labelRect.raw, $0.raw) }
        }

        let ambiguities = placements.map { Self.ambiguity(of: $0, in: problem) }
        meanPointingAmbiguity = Self.mean(ambiguities)
        worstPointingAmbiguity = ambiguities.max() ?? 0

        axisAlignedLeaders = placements.count { $0.placement.direction.isAxisAligned }
        meanLabelClearance = Self.mean(placements.map { problem.field.meanCost(in: $0.labelRect) })

        let margins = solution.trace.decisions.map(\.margin)
        meanDecisionMargin = Self.mean(margins)
        minimumDecisionMargin = margins.min() ?? 0
    }

    private struct PlacedAnnotation {
        let index: Int
        let placement: Placement
        let tip: ScenePoint
        let leader: Polyline
        let labelRect: SceneRect
    }

    private static func countCollisions(_ placements: [PlacedAnnotation]) -> Int {
        var count = 0
        for outer in placements.indices {
            for inner in (outer + 1)..<placements.count
            where Geo.overlaps(placements[outer].labelRect.raw, placements[inner].labelRect.raw) {
                count += 1
            }
        }
        return count
    }

    private static func countCrossings(_ placements: [PlacedAnnotation]) -> Int {
        var count = 0
        for outer in placements.indices {
            for inner in (outer + 1)..<placements.count
            where Geo.polylinesConflict(placements[outer].leader, placements[inner].leader) {
                count += 1
            }
        }
        return count
    }

    private static func ambiguity(of placed: PlacedAnnotation, in problem: LayoutProblem) -> Double {
        let tip = placed.tip.raw
        let own = Geo.distanceSquared(from: tip, to: problem.targets[placed.index].raw)
        var nearestOther = Double.infinity
        for (index, target) in problem.targets.enumerated() where index != placed.index {
            nearestOther = min(nearestOther, Geo.distanceSquared(from: tip, to: target.raw))
        }
        guard nearestOther.isFinite, nearestOther > 0 else { return 0 }
        return (own / nearestOther).squareRoot()
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        var sum = DeterministicSum()
        for value in values { sum.add(value) }
        return sum.value() / Double(values.count)
    }

    struct Row {
        let name: String
        let value: String

        init(_ name: String, _ value: String) {
            self.name = name
            self.value = value
        }
    }

    public var canonicalText: String {
        let rows: [Row] = [
            Row("annotations", "\(annotations)"),
            Row("axisAlignedLeaders", "\(axisAlignedLeaders)"),
            Row("labelCollisions", "\(labelCollisions)"),
            Row("labelsOutsideCanvas", "\(labelsOutsideCanvas)"),
            Row("labelsOverTargets", "\(labelsOverTargets)"),
            Row("leaderCrossings", "\(leaderCrossings)"),
            Row(
                "meanDecisionMargin",
                CanonicalText.rounded(meanDecisionMargin, places: ReportPrecision.marginPlaces)
            ),
            Row(
                "meanLabelClearance",
                CanonicalText.rounded(meanLabelClearance, places: ReportPrecision.marginPlaces)
            ),
            Row(
                "meanPointingAmbiguity",
                CanonicalText.rounded(meanPointingAmbiguity, places: ReportPrecision.marginPlaces)
            ),
            Row(
                "minimumDecisionMargin",
                CanonicalText.rounded(minimumDecisionMargin, places: ReportPrecision.marginPlaces)
            ),
            Row("placed", "\(placed)"),
            Row("relaxationRung", "\(relaxationRung)"),
            Row("unplaced", "\(unplaced)"),
            Row(
                "worstPointingAmbiguity",
                CanonicalText.rounded(worstPointingAmbiguity, places: ReportPrecision.marginPlaces)
            ),
        ]
        return rows.sorted { $0.name < $1.name }
            .map { "\($0.name) \($0.value)" }
            .joined(separator: "\n")
    }
}
