import EkranbildoFixtures
@testable import EkranbildoInspector
import EkranbildoTestKit
import Testing

@Suite("Corpus runner")
struct CorpusRunnerTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "corpus")

    private struct TargetSpec {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    private func scene(name: String, targets: [TargetSpec]) -> CorpusScene {
        let annotations = targets.enumerated().map { index, rect in
            """
            { "id": { "raw": \(index + 1) },
              "target": { "raw": { "origin": { "x": \(rect.x), "y": \(rect.y) },
                                   "size": { "width": \(rect.width), "height": \(rect.height) } } },
              "label": "Item \(index + 1)", "placement": null }
            """
        }
        return CorpusScene(
            name: name,
            json: """
                {
                  "canvas": { "raw": { "origin": { "x": 0, "y": 0 },
                                       "size": { "width": 420, "height": 280 } } },
                  "background": null,
                  "annotations": [\(annotations.joined(separator: ","))]
                }
                """
        )
    }

    private var corpus: [CorpusScene] {
        [
            scene(
                name: "roomy",
                targets: [
                    TargetSpec(x: 60, y: 50, width: 40, height: 24),
                    TargetSpec(x: 300, y: 200, width: 50, height: 26),
                ]
            ),
            scene(
                name: "crowded",
                targets: [
                    TargetSpec(x: 190, y: 130, width: 30, height: 20),
                    TargetSpec(x: 230, y: 130, width: 30, height: 20),
                    TargetSpec(x: 210, y: 180, width: 30, height: 20),
                ]
            ),
            scene(name: "single", targets: [TargetSpec(x: 180, y: 120, width: 60, height: 30)]),
        ]
    }

    private func run() -> CorpusReport {
        CorpusRunner(measurer: TabulatedTextMeasurer.uniform()).run(corpus)
    }

    @Test("Every scene is reported on")
    func coversEveryScene() {
        #expect(run().entries.count == 3)
        #expect(Set(run().entries.map(\.name)) == ["roomy", "crowded", "single"])
    }

    @Test("A scene that fails to parse is reported rather than skipped")
    func malformedScene() {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run([CorpusScene(name: "broken", json: "{ not json")])
        #expect(report.entries.count == 1)
        #expect(report.entries[0].failure != nil)
        #expect(report.entries[0].metrics == nil)
    }

    @Test("Failures are counted in the summary")
    func failuresAreCounted() {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run(corpus + [CorpusScene(name: "broken", json: "nope")])
        #expect(report.failureCount == 1)
        #expect(report.entries.count == 4)
    }

    @Test("Entries needing attention come first")
    func sortedByConcern() {
        let report = run()
        let concerns = report.entries.map(\.concern)
        #expect(concerns == concerns.sorted(by: >))
    }

    @Test("A single defect outranks every mild concern combined")
    func defectsOutrankMildConcerns() {
        let oneCollision = QualityMetrics(annotations: 8, placed: 8, labelCollisions: 1)
        let asMildAsPossible = QualityMetrics(
            annotations: 8,
            placed: 8,
            meanPointingAmbiguity: 1,
            worstPointingAmbiguity: 1,
            axisAlignedLeaders: 8,
            meanLabelClearance: 1,
            minimumDecisionMargin: 0
        )
        #expect(CorpusRunner.concern(of: oneCollision) > CorpusRunner.concern(of: asMildAsPossible))
    }

    @Test("Each kind of defect counts", arguments: [0, 1, 2, 5])
    func defectsAccumulate(_ count: Int) {
        let clean = QualityMetrics(annotations: 4, placed: 4)
        for metrics in [
            QualityMetrics(annotations: 4, placed: 4, labelCollisions: count),
            QualityMetrics(annotations: 4, placed: 4, leaderCrossings: count),
            QualityMetrics(annotations: 4, placed: 4, labelsOutsideCanvas: count),
            QualityMetrics(annotations: 4, placed: 4, labelsOverTargets: count),
        ] {
            if count == 0 {
                #expect(CorpusRunner.concern(of: metrics) == CorpusRunner.concern(of: clean))
            } else {
                #expect(CorpusRunner.concern(of: metrics) > CorpusRunner.concern(of: clean))
            }
        }
    }

    @Test("An unplaced annotation outranks a relaxed layout")
    func unplacedOutranksRelaxed() {
        let unplaced = QualityMetrics(annotations: 4, placed: 3, unplaced: 1)
        let relaxed = QualityMetrics(annotations: 4, placed: 4, relaxationRung: 3)
        #expect(CorpusRunner.concern(of: unplaced) > CorpusRunner.concern(of: relaxed))
    }

    @Test("A relaxed layout outranks a clean one")
    func relaxedOutranksClean() {
        #expect(
            CorpusRunner.concern(of: QualityMetrics(annotations: 4, placed: 4, relaxationRung: 1))
                > CorpusRunner.concern(of: QualityMetrics(annotations: 4, placed: 4))
        )
    }

    @Test("A scene that failed to load sorts above everything")
    func failuresSortFirst() {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run(corpus + [CorpusScene(name: "broken", json: "nope")])
        #expect(report.entries.first?.name == "broken")
    }

    @Test("The scoreboard lists every scene and metric in a stable order")
    func scoreboardIsStable() {
        let scoreboard = run().scoreboard
        #expect(scoreboard.contains("roomy"))
        #expect(scoreboard.contains("crowded"))
        #expect(isReproducible { run().scoreboard })
    }

    @Test("The contact sheet is a self-contained page")
    func contactSheet() {
        let html = run().html
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(!html.contains("<script src="))
        #expect(html.contains("<svg"))
        #expect(html.contains("roomy"))
    }

    @Test("The scoreboard for the sample corpus is unchanged")
    func scoreboardGolden() throws {
        let result = try goldens.compare(run().scoreboard, named: "sample.scoreboard")
        #expect(result.isAcceptable, "\(result.message)")
    }
}
