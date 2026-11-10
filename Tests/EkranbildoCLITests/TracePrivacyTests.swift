@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoObservability
import Testing

@Suite("A trace somebody could send")
struct TracePrivacyTests {

    private enum Theirs {
        static let label = "Quarterly revenue, confidential"
        static let otherLabel = "Board deck, do not circulate"
        static let font = "AcmeCorpDisplay"
    }

    private static func sceneJSON() -> String {
        """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "annotations": [
            {"id": {"raw": 1},
             "target": {"raw": {"origin": {"x": 40, "y": 180},
                       "size": {"width": 80, "height": 24}}},
             "label": "\(Theirs.label)", "placement": null},
            {"id": {"raw": 2},
             "target": {"raw": {"origin": {"x": 240, "y": 60},
                       "size": {"width": 80, "height": 24}}},
             "label": "\(Theirs.otherLabel)", "placement": null}
          ],
          "style": {"labelFont": {"family": "\(Theirs.font)", "size": 13,
                    "weight": "regular", "italic": false}}
        }
        """
    }

    private func trace() throws -> String {
        let options = try RenderOptions(
            arguments: ["scene.json", "--trace", "t.json", "--png", "out.png"])
        let outputs = try RenderCommand().run(sceneJSON: Self.sceneJSON(), options: options)
        return try #require(outputs.trace)
    }

    @Test("The trace does carry their words before anything is done about it")
    func theirWordsAreThereToBeginWith() throws {
        #expect(try trace().contains(Theirs.font))
    }

    @Test("A synthesised trace carries none of them")
    func noneOfTheirWordsSurvive() throws {
        let synthesised = TraceSynthesis.applied(to: try trace())
        #expect(!synthesised.contains(Theirs.label))
        #expect(!synthesised.contains(Theirs.otherLabel))
        #expect(!synthesised.contains(Theirs.font))
    }

    @Test("It still describes the run it was sent to explain")
    func theRunIsStillDescribed() throws {
        let synthesised = TraceSynthesis.applied(to: try trace())
        #expect(synthesised.contains("solve"))
        #expect(synthesised.contains("render"))
        #expect(synthesised.contains("annotations"))
    }

    @Test("It is the same trace, line for line")
    func theShapeIsUnchanged() throws {
        let before = try trace().split(separator: "\n").count
        let after = TraceSynthesis.applied(to: try trace()).split(separator: "\n").count
        #expect(before == after)
    }
}

@Suite("A trace of somebody annotating")
struct AnnotateTracePrivacyTests {

    private static let theirLabel = "Quarterly revenue, confidential"

    private func trace() throws -> String {
        let outputs = try AnnotateCommand().run(
            imageBytes: try ImageCodec.encodePNG(SceneLibrary.applicationWindow.image),
            options: try AnnotateOptions(
                arguments: [
                    "a.png", "--point", "32,18:\(Self.theirLabel)", "--trace", "t.json",
                ]
            )
        )
        return try #require(outputs.trace)
    }

    @Test("Their words are in the trace to begin with")
    func theirWordsAreThereToBeginWith() throws {
        #expect(try trace().contains(Self.theirLabel))
    }

    @Test("A synthesised trace carries none of them")
    func noneOfTheirWordsSurvive() throws {
        #expect(!TraceSynthesis.applied(to: try trace()).contains(Self.theirLabel))
    }

    @Test("It still describes what was solved")
    func theRunIsStillDescribed() throws {
        let synthesised = TraceSynthesis.applied(to: try trace())
        #expect(synthesised.contains("solve"))
        #expect(synthesised.contains("marks=1"))
        #expect(synthesised.contains("solved"))
    }
}

@Suite("Synthesising a trace from the command line")
struct SynthesiseTraceArgumentTests {

    @Test("A trace to make safe is optional")
    func traceIsOptional() throws {
        #expect(try SynthesiseOptions(arguments: ["scene.json"]).traceInput == nil)
        let both = try SynthesiseOptions(
            arguments: ["scene.json", "--trace", "t.json", "--trace-out", "safe.json"])
        #expect(both.traceInput == "t.json")
    }

    @Test("Where the safe trace goes can be said separately")
    func traceOutputIsSeparate() throws {
        let options = try SynthesiseOptions(
            arguments: ["scene.json", "--trace", "t.json", "--trace-out", "safe.json"])
        #expect(options.traceOutput == "safe.json")
    }

    @Test("Nowhere to put it is refused rather than written over the original")
    func outputIsRequired() {
        #expect(throws: CommandError.self) {
            try SynthesiseOptions(arguments: ["scene.json", "--trace", "t.json", "--out", "s.json"])
        }
    }

    @Test("The command replaces the borrowed words and nothing else")
    func commandSynthesisesTheTrace() throws {
        let trace = #"[0] begin solve annotations=2"# + "\n" + #"[1]   placed label=~"Secret""#
        let safe = SynthesiseCommand().synthesised(trace: trace)
        #expect(!safe.contains("Secret"))
        #expect(safe.contains("annotations=2"))
    }
}
