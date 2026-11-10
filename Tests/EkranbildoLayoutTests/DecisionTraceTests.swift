import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import Testing

@Suite("Decision trace")
struct DecisionTraceTests {

    private func problem(_ targets: [SceneRect]) -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 320),
            style: .standard,
            annotations: targets.enumerated().map { index, rect in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: rect,
                    label: "Label \(index + 1)",
                    placement: nil
                )
            },
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func solve(_ subject: LayoutProblem, recording: Int = 8) -> LayoutSolution {
        ExactSolver().solve(
            subject,
            budget: SolverBudget(candidatesRecordedPerAnnotation: recording)
        )
    }

    private var sample: LayoutProblem {
        problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 300, y: 200, width: 60, height: 30),
        ])
    }

    @Test("Each decision records the candidates it ranked")
    func recordsCandidates() {
        let solution = solve(sample)
        for decision in solution.trace.decisions {
            #expect(!decision.candidates.isEmpty)
            #expect(decision.candidates.count <= 8)
        }
    }

    @Test("Recorded candidates are ranked best first")
    func candidatesAreRanked() {
        let solution = solve(sample)
        for decision in solution.trace.decisions {
            #expect(decision.candidates.map(\.rank) == Array(0..<decision.candidates.count))
        }
    }

    @Test("Every recorded candidate carries a score for every term")
    func recordsTermScores() {
        let solution = solve(sample)
        let expected = Set(ScoreTerms.unary.map(\.identifier))
        for decision in solution.trace.decisions {
            for candidate in decision.candidates {
                #expect(Set(candidate.terms.map(\.term)) == expected)
            }
        }
    }

    @Test("Term scores are listed in a stable order")
    func termOrderIsStable() {
        let solution = solve(sample)
        let orders = solution.trace.decisions.flatMap { $0.candidates.map { $0.terms.map(\.term) } }
        for order in orders {
            #expect(order == orders[0])
        }
    }

    @Test("The recorded group scores match the terms they came from")
    func groupScoresAgreeWithTerms() {
        let solution = solve(sample)
        for decision in solution.trace.decisions {
            for candidate in decision.candidates {
                for group in ObjectiveGroup.allCases {
                    let inGroup = candidate.terms.filter { $0.group == group }
                    guard !inGroup.isEmpty else {
                        #expect(candidate.groupScores[group] == 0)
                        continue
                    }
                    let mean = inGroup.map(\.value.value).reduce(0, +) / Double(inGroup.count)
                    #expect(approximatelyEqual(candidate.groupScores[group], mean, tolerance: 1e-9))
                }
            }
        }
    }

    @Test("The winner is explained against the best alternative")
    func explainsTheWinner() {
        let solution = solve(sample)
        for decision in solution.trace.decisions where decision.candidates.count > 1 {
            #expect(decision.winReason != nil)
        }
    }

    @Test("The alternative the winner is compared against is a different candidate")
    func alternativeIsNotTheWinner() {
        let solution = solve(sample)
        for decision in solution.trace.decisions where decision.consideredCount > 1 {
            #expect(decision.runnerUp != nil)
            #expect(decision.runnerUp != decision.winner)
        }
    }

    @Test("The explanation is about the winner, not about the pruning order")
    func explainsTheChosenCandidate() {
        let solution = solve(sample)
        for decision in solution.trace.decisions {
            guard let winner = decision.winner, !decision.candidates.isEmpty else { continue }
            #expect(decision.candidates.contains { $0.id == winner })
            #expect(decision.winnerRank != nil)
            let rank = decision.candidates.first { $0.id == winner }?.rank
            #expect(decision.winnerRank == rank)
        }
    }

    @Test("It is recorded when the joint search overrode the per-annotation favourite")
    func recordsWhenTheSearchOverrides() {
        let crowded = problem([
            SceneRect(x: 60, y: 60, width: 40, height: 24),
            SceneRect(x: 130, y: 60, width: 40, height: 24),
            SceneRect(x: 100, y: 180, width: 40, height: 24),
        ])
        let solution = solve(crowded)
        for decision in solution.trace.decisions {
            guard let rank = decision.winnerRank else { continue }
            #expect(decision.overrodeUnaryFavourite == (rank > 0))
        }
    }

    @Test("The number of candidates recorded is capped")
    func recordingIsCapped() {
        let solution = solve(sample, recording: 3)
        for decision in solution.trace.decisions {
            #expect(decision.candidates.count <= 4)
        }
    }

    @Test("The winner is always recorded, however low it ranked", arguments: [0, 1, 2, 8])
    func winnerIsAlwaysRecorded(_ recording: Int) {
        let crowded = problem([
            SceneRect(x: 60, y: 60, width: 40, height: 24),
            SceneRect(x: 130, y: 60, width: 40, height: 24),
            SceneRect(x: 100, y: 180, width: 40, height: 24),
        ])
        let solution = solve(crowded, recording: recording)
        for decision in solution.trace.decisions {
            guard let winner = decision.winner else { continue }
            #expect(
                decision.candidates.contains { $0.id == winner },
                "the chosen candidate is missing from the report"
            )
        }
    }

    @Test("Recording nothing still records the winner")
    func recordingCanBeDisabled() {
        let solution = solve(sample, recording: 0)
        for decision in solution.trace.decisions {
            #expect(decision.candidates.count == 1)
            #expect(decision.candidates.first?.id == decision.winner)
        }
    }

    @Test("The trace is the same on every run")
    func traceIsReproducible() {
        let subject = sample
        let first = solve(subject).trace.canonicalText
        let second = solve(subject).trace.canonicalText
        #expect(first == second)
    }

    @Test("The trace renders as readable text")
    func canonicalText() {
        let text = solve(sample).trace.canonicalText
        #expect(text.contains("annotation"))
        #expect(text.contains("winner"))
        #expect(text.contains("labelClearance"))
    }
}
