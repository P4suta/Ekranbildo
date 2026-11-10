@testable import EkranbildoCLI
import Testing

@Suite("Corpus command")
struct CorpusCommandTests {

    @Test("The corpus subcommand needs a directory")
    func directoryRequired() {
        #expect(throws: CommandError.self) {
            try CorpusOptions(arguments: [])
        }
    }

    @Test("Output paths are optional")
    func optionalOutputs() throws {
        let options = try CorpusOptions(arguments: ["corpus/"])
        #expect(options.input == "corpus/")
        #expect(options.sheetOutput == nil)
        #expect(options.scoreboardOutput == nil)
    }

    @Test("Each output has a flag")
    func outputFlags() throws {
        let options = try CorpusOptions(
            arguments: ["corpus/", "--sheet", "s.html", "--scoreboard", "b.txt"]
        )
        #expect(options.sheetOutput == "s.html")
        #expect(options.scoreboardOutput == "b.txt")
    }

    @Test("An unknown flag is rejected")
    func unknownFlag() {
        #expect(throws: CommandError.self) {
            try CorpusOptions(arguments: ["corpus/", "--nope", "1"])
        }
    }

    @Test("The first argument selects the subcommand")
    func subcommandDispatch() throws {
        guard case .corpus = try Command(arguments: ["corpus", "dir/"]) else {
            Issue.record("expected the corpus subcommand")
            return
        }
        guard case .render = try Command(arguments: ["scene.json"]) else {
            Issue.record("expected the render subcommand")
            return
        }
    }

    @Test("Running a corpus produces both outputs")
    func runsACorpus() throws {
        let scenes = [
            CorpusInput(
                name: "one",
                json: """
                    { "canvas": { "raw": { "origin": { "x": 0, "y": 0 },
                                           "size": { "width": 300, "height": 200 } } },
                      "background": null,
                      "annotations": [
                        { "id": { "raw": 1 },
                          "target": { "raw": { "origin": { "x": 100, "y": 80 },
                                               "size": { "width": 40, "height": 24 } } },
                          "label": "A", "placement": null }
                      ] }
                    """
            )
        ]
        let outputs = CorpusCommand().run(scenes: scenes)
        #expect(outputs.sheet.contains("<!doctype html>"))
        #expect(outputs.scoreboard.contains("one "))
        #expect(outputs.failureCount == 0)
    }

    @Test("A failing scene is counted rather than swallowed")
    func failingScene() {
        let outputs = CorpusCommand().run(scenes: [CorpusInput(name: "bad", json: "{")])
        #expect(outputs.failureCount == 1)
        #expect(outputs.scoreboard.contains("failed"))
    }
}
