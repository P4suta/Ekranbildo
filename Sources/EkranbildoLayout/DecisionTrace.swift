import EkranbildoContracts
import EkranbildoCore
import EkranbildoObservability

public struct TermScore: Sendable, Equatable {
    public let term: TermID
    public let group: ObjectiveGroup
    public let value: Normalized

    public init(term: TermID, group: ObjectiveGroup, value: Normalized) {
        self.term = term
        self.group = group
        self.value = value
    }
}

public struct CandidateRecord: Sendable {
    public let id: CandidateID
    public let placement: Placement
    public let labelRect: SceneRect
    public let tip: ScenePoint
    public let tail: ScenePoint
    public let groupScores: GroupScores
    public let terms: [TermScore]
    public let rank: Int
}

public struct AnnotationDecision: Sendable {
    public let annotationID: AnnotationID
    public let consideredCount: Int
    public let winner: CandidateID?
    public let margin: Double
    public let runnerUp: CandidateID?
    public let winnerRank: Int?
    public let overrodeUnaryFavourite: Bool
    public let candidates: [CandidateRecord]
    public let winReason: ComparisonExplanation?
}

public struct DecisionTrace: Sendable {
    public let decisions: [AnnotationDecision]
    public let relaxationRung: Int
    public let relaxedConstraints: [ConstraintID]

    public init(
        decisions: [AnnotationDecision],
        relaxationRung: Int,
        relaxedConstraints: [ConstraintID]
    ) {
        self.decisions = decisions
        self.relaxationRung = relaxationRung
        self.relaxedConstraints = relaxedConstraints
    }

    private static let marginPlaces = 6
    private static let scorePlaces = 4
    private static let lengthPlaces = 1

    public var canonicalText: String {
        var lines: [String] = ["trace rung=\(relaxationRung)"]
        if !relaxedConstraints.isEmpty {
            lines.append("relaxed \(relaxedConstraints.map(\.name).joined(separator: " "))")
        }
        for decision in decisions {
            lines.append(
                "annotation \(decision.annotationID.raw) considered=\(decision.consideredCount) "
                    + "winner=\(decision.winner.map { "\($0.raw)" } ?? "none") "
                    + "rank=\(decision.winnerRank.map { "\($0)" } ?? "-") "
                    + "margin="
                    + CanonicalText.rounded(decision.margin, places: Self.marginPlaces)
            )
            if let reason = decision.winReason {
                let decided = reason.decidingGroup.map { "\($0)" } ?? "tie"
                let tied = reason.tiedGroups.map { "\($0)" }.joined(separator: ",")
                lines.append("  decided by \(decided)\(tied.isEmpty ? "" : " after \(tied)")")
            }
            for candidate in decision.candidates {
                lines.append(
                    "  #\(candidate.rank) candidate=\(candidate.id.raw) "
                        + "\(candidate.placement.direction) "
                        + "len="
                        + CanonicalText.rounded(
                            candidate.placement.leaderLength, places: Self.lengthPlaces)
                )
                for score in candidate.terms {
                    let value = CanonicalText.rounded(score.value.value, places: Self.scorePlaces)
                    lines.append("    \(score.term) \(value)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

public struct LayoutSolution: Sendable {
    public let assignments: [LayoutAssignment]
    public let unplaced: [UnplacedAnnotation]
    public let score: GroupScores
    public let relaxationRung: Int
    public let work: WorkUnitCounters
    public let trace: DecisionTrace
    public let refinementSweepsUsed: Int
    public let isOptimal: Bool

    public init(
        assignments: [LayoutAssignment],
        unplaced: [UnplacedAnnotation],
        score: GroupScores,
        relaxationRung: Int,
        work: WorkUnitCounters,
        trace: DecisionTrace,
        refinementSweepsUsed: Int = 0,
        isOptimal: Bool = false
    ) {
        self.assignments = assignments
        self.unplaced = unplaced
        self.score = score
        self.relaxationRung = relaxationRung
        self.work = work
        self.trace = trace
        self.refinementSweepsUsed = refinementSweepsUsed
        self.isOptimal = isOptimal
    }

    public func applied(to annotations: [Annotation]) -> [Annotation] {
        annotations.map { annotation in
            guard let assignment = assignments.first(where: { $0.annotationID == annotation.id })
            else { return annotation }
            return annotation.replacing(placement: assignment.placement)
        }
    }

    public func violations(
        of constraints: [any HardConstraint],
        in problem: LayoutProblem
    ) -> [ConstraintID] {
        let placed = assignments.map { assignment in
            LayoutCandidate(
                id: assignment.candidateID,
                annotationID: assignment.annotationID,
                annotationIndex: assignment.annotationIndex,
                placement: assignment.placement,
                tip: resolved(assignment, in: problem).tip,
                tail: resolved(assignment, in: problem).tail,
                labelRect: resolved(assignment, in: problem).labelBox(
                    textSize: problem.textSizes[assignment.annotationIndex],
                    style: problem.style
                )
            )
        }

        var broken: [ConstraintID] = []
        for constraint in constraints {
            var satisfied = true
            for candidate in placed where !constraint.isSatisfied(candidate, in: problem) {
                satisfied = false
            }
            for outer in 0..<placed.count {
                for inner in (outer + 1)..<placed.count
                where !constraint.isSatisfied(placed[outer], placed[inner], in: problem) {
                    satisfied = false
                }
            }
            if !satisfied { broken.append(constraint.identifier) }
        }
        return broken
    }

    private func resolved(_ assignment: LayoutAssignment, in problem: LayoutProblem)
        -> ResolvedPlacement
    {
        ResolvedPlacement(
            target: problem.annotations[assignment.annotationIndex].target,
            placement: assignment.placement,
            style: problem.style
        )
    }
}

public protocol LayoutSolving: Sendable {
    var version: String { get }
    func solve(_ problem: LayoutProblem, budget: SolverBudget) -> LayoutSolution
}
