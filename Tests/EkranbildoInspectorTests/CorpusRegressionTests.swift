import EkranbildoCore
import EkranbildoFixtures
@testable import EkranbildoInspector
import EkranbildoTestKit
import Foundation
import Testing

@Suite("Corpus regression")
struct CorpusRegressionTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "corpus")

    private func loadCorpus(testFile: StaticString = #filePath) throws -> [CorpusScene] {
        var url = URL(fileURLWithPath: "\(testFile)")
        while url.pathComponents.count > 1 && url.lastPathComponent != "Tests" {
            url = url.deletingLastPathComponent()
        }
        let directory = url.deletingLastPathComponent().appendingPathComponent("Examples/Corpus")

        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try files.map { url in
            CorpusScene(
                name: url.deletingPathExtension().lastPathComponent,
                json: try String(contentsOf: url, encoding: .utf8)
            )
        }
    }

    @Test("The corpus is not empty")
    func corpusExists() throws {
        #expect(try loadCorpus().count >= 8)
    }

    @Test("Every scene in the corpus solves")
    func everySceneSolves() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform()).run(try loadCorpus())
        #expect(report.failureCount == 0)
        for entry in report.entries {
            #expect(entry.metrics != nil, "\(entry.name) produced no measurements")
        }
    }

    @Test("No scene in the corpus has a layout defect")
    func corpusHasNoDefects() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform()).run(try loadCorpus())
        for entry in report.entries {
            guard let metrics = entry.metrics else { continue }
            #expect(metrics.labelCollisions == 0, "\(entry.name) has overlapping labels")
            #expect(metrics.leaderCrossings == 0, "\(entry.name) has crossing leaders")
            #expect(metrics.labelsOutsideCanvas == 0, "\(entry.name) has a label off the canvas")
            #expect(metrics.labelsOverTargets == 0, "\(entry.name) has a label over a target")
            #expect(metrics.unplaced == 0, "\(entry.name) left an annotation unplaced")
        }
    }

    @Test("The corpus measurements are unchanged")
    func scoreboardIsUnchanged() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform()).run(try loadCorpus())
        let result = try goldens.compare(report.scoreboard, named: "examples.scoreboard")
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("Translating the corpus actually changes it")
    func translationHappens() throws {
        let corpus = try loadCorpus()
        let translated = corpus.map(Self.translated)
        #expect(corpus.map(\.json) != translated.map(\.json))

        for (before, after) in zip(corpus, translated) {
            guard before.json.contains(Self.labelKey) else { continue }
            #expect(before.json != after.json, "\(before.name) was left in English")
        }
    }

    @Test("No scene has a layout defect once its labels are translated")
    func translatedCorpusHasNoDefects() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run(try loadCorpus().map(Self.translated))

        for entry in report.entries {
            guard let metrics = entry.metrics else {
                Issue.record("\(entry.name) produced no measurements once translated")
                continue
            }
            #expect(metrics.labelCollisions == 0, "\(entry.name) has overlapping labels")
            #expect(metrics.leaderCrossings == 0, "\(entry.name) has crossing leaders")
            #expect(metrics.labelsOutsideCanvas == 0, "\(entry.name) has a label off the canvas")
            #expect(metrics.labelsOverTargets == 0, "\(entry.name) has a label over a target")
        }
    }

    @Test("Every scene still solves once its labels are translated")
    func translatedCorpusSolves() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run(try loadCorpus().map(Self.translated))
        #expect(report.failureCount == 0)
    }

    @Test("What translation costs the corpus is unchanged")
    func translatedScoreboardIsUnchanged() throws {
        let report = CorpusRunner(measurer: TabulatedTextMeasurer.uniform())
            .run(try loadCorpus().map(Self.translated))
        let result = try goldens.compare(report.scoreboard, named: "translated.scoreboard")
        #expect(result.isAcceptable, "\(result.message)")
    }

    private static func translated(_ scene: CorpusScene) -> CorpusScene {
        CorpusScene(name: scene.name, json: Self.translatedLabels(in: scene.json))
    }

    private static func translatedLabels(in json: String) -> String {
        var result = ""
        var rest = Substring(json)
        while let start = rest.range(of: Self.labelKey) {
            result += rest[..<start.upperBound]
            rest = rest[start.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { break }
            result += PseudoLocalisation.of(String(rest[..<end]))
            rest = rest[end...]
        }
        return result + rest
    }

    private static let labelKey = "\"label\": \""

    @Test("Every scene in the corpus draws labels somebody can read")
    func corpusIsReadable() throws {
        for scene in try loadCorpus() {
            let decoded = try JSONDecoder().decode(
                Scene.self, from: Data(scene.json.utf8))
            #expect(
                decoded.style.labelContrast >= StyleTokens.Readability.required,
                "\(scene.name) draws labels at \(decoded.style.labelContrast):1"
            )
            #expect(
                decoded.style.badgeContrast >= StyleTokens.Readability.required,
                "\(scene.name) draws step numbers at \(decoded.style.badgeContrast):1"
            )
        }
    }
}
