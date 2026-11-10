import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Score terms")
struct ScoreTermTests {

    private func problem(targets: [SceneRect]) -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            style: .standard,
            annotations: targets.enumerated().map { index, rect in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: rect,
                    label: "Label",
                    placement: nil
                )
            },
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func candidate(
        _ subject: LayoutProblem,
        annotation: Int = 0,
        direction: Direction16,
        length: Double
    ) -> LayoutCandidate {
        GridCandidateGenerator(directions: [direction], leaderLengths: [length])
            .generate(forAnnotationAt: annotation, in: subject)[0]
    }

    @Test("A label over a busy area scores worse than one over empty space")
    func labelClearance() {
        let subject = problem(
            targets: [
                SceneRect(x: 200, y: 140, width: 20, height: 20),
                SceneRect(x: 250, y: 120, width: 140, height: 60),
            ]
        )
        let term = LabelClearance()
        let overBusy = candidate(subject, direction: .e, length: 40)
        let overEmpty = candidate(subject, direction: .w, length: 40)
        #expect(term.evaluate(overBusy, in: subject) == .worst)
        #expect(term.evaluate(overEmpty, in: subject) == .best)
    }

    @Test("A tip near a second target scores as ambiguous")
    func targetAmbiguity() {
        let crowded = problem(
            targets: [
                SceneRect(x: 100, y: 140, width: 20, height: 20),
                SceneRect(x: 160, y: 140, width: 20, height: 20),
            ]
        )
        let term = TargetAmbiguity()
        let towardsTheOther = candidate(crowded, direction: .e, length: 30)
        let awayFromIt = candidate(crowded, direction: .w, length: 30)
        #expect(term.evaluate(towardsTheOther, in: crowded) > term.evaluate(awayFromIt, in: crowded))
    }

    @Test("A single annotation is never ambiguous")
    func singleAnnotationIsUnambiguous() {
        let alone = problem(targets: [SceneRect(x: 180, y: 140, width: 20, height: 20)])
        #expect(TargetAmbiguity().evaluate(candidate(alone, direction: .e, length: 40), in: alone) == .best)
    }

    @Test("A label near the canvas edge scores worse than one well inside")
    func edgeProximity() {
        let subject = problem(targets: [SceneRect(x: 40, y: 140, width: 20, height: 20)])
        let term = CanvasEdgeProximity()
        let nearEdge = candidate(subject, direction: .w, length: 10)
        let wellInside = candidate(subject, direction: .e, length: 80)
        #expect(term.evaluate(nearEdge, in: subject) > term.evaluate(wellInside, in: subject))
    }

    @Test("An axis-aligned leader scores worse than a diagonal one")
    func axisAlignment() {
        let subject = problem(targets: [SceneRect(x: 180, y: 140, width: 20, height: 20)])
        let term = AxisAlignment()
        #expect(
            term.evaluate(candidate(subject, direction: .e, length: 40), in: subject)
                > term.evaluate(candidate(subject, direction: .ne, length: 40), in: subject)
        )
    }

    @Test("Siblings pointing the same way score as consistent")
    func directionConsistency() {
        let subject = problem(
            targets: [
                SceneRect(x: 100, y: 100, width: 20, height: 20),
                SceneRect(x: 100, y: 200, width: 20, height: 20),
            ]
        )
        let term = DirectionConsistency()
        let first = candidate(subject, annotation: 0, direction: .e, length: 40)
        let sameWay = candidate(subject, annotation: 1, direction: .e, length: 40)
        let otherWay = candidate(subject, annotation: 1, direction: .w, length: 40)
        #expect(term.evaluate(first, sameWay, in: subject) < term.evaluate(first, otherWay, in: subject))
    }

    @Test("Every term is reproducible", arguments: [Direction16.e, .nw, .s])
    func termsAreReproducible(_ direction: Direction16) {
        let subject = problem(
            targets: [
                SceneRect(x: 100, y: 100, width: 20, height: 20),
                SceneRect(x: 240, y: 180, width: 30, height: 30),
            ]
        )
        let subject0 = candidate(subject, annotation: 0, direction: direction, length: 50)
        let subject1 = candidate(subject, annotation: 1, direction: direction, length: 50)
        #expect(isReproducible { LabelClearance().evaluate(subject0, in: subject) })
        #expect(isReproducible { TargetAmbiguity().evaluate(subject0, in: subject) })
        #expect(isReproducible { DirectionConsistency().evaluate(subject0, subject1, in: subject) })
    }
}

@Suite("Exact solver")
struct ExactSolverTests {

    private func problem(
        canvas: SceneRect = SceneRect(x: 0, y: 0, width: 480, height: 320),
        targets: [SceneRect],
        labels: [String]? = nil
    ) -> LayoutProblem {
        let annotations = targets.enumerated().map { index, rect in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: rect,
                label: labels?[index] ?? "Label \(index + 1)",
                placement: nil
            )
        }
        return LayoutProblem(
            canvas: canvas,
            style: .standard,
            annotations: annotations,
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func solve(_ subject: LayoutProblem) -> LayoutSolution {
        ExactSolver().solve(subject, budget: .standard)
    }

    @Test("An empty problem solves to nothing")
    func emptyProblem() {
        let solution = solve(problem(targets: []))
        #expect(solution.assignments.isEmpty)
        #expect(solution.unplaced.isEmpty)
    }

    @Test("Every annotation is placed exactly once")
    func everyAnnotationPlaced() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
                SceneRect(x: 200, y: 140, width: 30, height: 30),
            ]
        )
        let solution = solve(subject)
        #expect(solution.assignments.count == 3)
        #expect(solution.unplaced.isEmpty)
        #expect(Set(solution.assignments.map(\.annotationID)).count == 3)
    }

    @Test("The solution satisfies every hard constraint")
    func solutionIsFeasible() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
                SceneRect(x: 200, y: 140, width: 30, height: 30),
            ]
        )
        let solution = solve(subject)
        let violations = solution.violations(of: HardConstraints.standard(style: subject.style), in: subject)
        #expect(violations.isEmpty, "violated: \(violations.map(\.name))")
    }

    @Test("Solving the same problem twice gives the same answer")
    func reproducible() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
            ]
        )
        #expect(isReproducible { solve(subject).assignments })
    }

    @Test("Solving is idempotent when the answer is fed back in")
    func idempotent() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
            ]
        )
        let once = solve(subject)
        let applied = LayoutProblem(
            canvas: subject.canvas,
            style: subject.style,
            annotations: once.applied(to: subject.annotations),
            measurer: TabulatedTextMeasurer.uniform()
        )
        #expect(solve(applied).assignments == once.assignments)
    }

    @Test("The solver reports how much work it did")
    func workIsCounted() {
        let subject = problem(targets: [SceneRect(x: 80, y: 60, width: 40, height: 24)])
        let solution = solve(subject)
        #expect(solution.work.candidatesGenerated > 0)
        #expect(solution.work.unaryEvaluations > 0)
    }

    @Test("Work counts are reproducible")
    func workIsReproducible() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
            ]
        )
        #expect(isReproducible { solve(subject).work })
    }

    @Test("The trace names a winner for every annotation")
    func traceNamesWinners() {
        let subject = problem(
            targets: [
                SceneRect(x: 80, y: 60, width: 40, height: 24),
                SceneRect(x: 300, y: 200, width: 60, height: 30),
            ]
        )
        let solution = solve(subject)
        #expect(solution.trace.decisions.count == 2)
        for decision in solution.trace.decisions {
            #expect(decision.consideredCount > 0)
            #expect(decision.winner != nil)
        }
    }

    @Test("An impossible scene relaxes rather than failing")
    func relaxationLadder() {
        let subject = problem(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 150),
            targets: [
                SceneRect(x: 20, y: 20, width: 60, height: 30),
                SceneRect(x: 110, y: 20, width: 60, height: 30),
                SceneRect(x: 20, y: 90, width: 60, height: 30),
                SceneRect(x: 110, y: 90, width: 60, height: 30),
            ],
            labels: ["A long label here", "Another long one", "Third long label", "Fourth long label"]
        )
        let solution = solve(subject)
        #expect(solution.assignments.count + solution.unplaced.count == 4)
        #expect(solution.relaxationRung >= 0)
    }

    @Test("A solution never silently drops an annotation")
    func nothingIsLost() {
        var generator = SplitMix64(seed: 2_026)
        for _ in 0..<20 {
            let count = Int(generator.next() % 4) + 1
            let targets = (0..<count).map { _ in
                SceneRect(
                    x: Double(generator.next() % 400),
                    y: Double(generator.next() % 260),
                    width: Double(generator.next() % 60) + 10,
                    height: Double(generator.next() % 40) + 10
                )
            }
            let subject = problem(targets: targets)
            let solution = solve(subject)
            #expect(solution.assignments.count + solution.unplaced.count == count)
        }
    }
}
