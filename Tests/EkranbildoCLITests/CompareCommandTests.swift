@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoTestKit
import Testing

@Suite("Compare command")
struct CompareCommandTests {

    private func scene(_ name: String) -> CorpusInput {
        CorpusInput(
            name: name,
            json: """
                {
                  "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                                     "size": {"width": 320, "height": 240}}},
                  "annotations": [
                    {"id": 1,
                     "target": {"raw": {"origin": {"x": 140, "y": 110},
                                        "size": {"width": 40, "height": 20}}},
                     "label": "Here"}
                  ]
                }
                """
        )
    }

    private func options(_ arguments: [String]) throws -> CompareOptions {
        try CompareOptions(arguments: arguments)
    }

    @Test("A directory is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("A count that is not a count is refused", arguments: ["0", "-2", "some"])
    func malformedCount(text: String) {
        #expect(throws: CommandError.self) { try self.options(["dir", "--questions", text]) }
    }

    @Test("A page of questions is produced")
    func asksQuestions() throws {
        let outputs = try CompareCommand().run(
            scenes: [scene("one"), scene("two")],
            options: try options(["dir", "--page", "out.html", "--questions", "4"])
        )
        let page = try #require(outputs.page)
        #expect(page.contains("Which is better?"))
        #expect(page.contains("one") || page.contains("two"))
    }

    @Test("No more questions are asked than were asked for")
    func limitsQuestions() throws {
        let outputs = try CompareCommand().run(
            scenes: (0..<20).map { scene("scene-\($0)") },
            options: try options(["dir", "--page", "out.html", "--questions", "3"])
        )
        let page = try #require(outputs.page)
        #expect(page.components(separatedBy: "<section class=\"pair\"").count - 1 <= 3)
    }

    @Test("With no answers yet there is no agreement to report")
    func noAnswers() throws {
        let outputs = try CompareCommand().run(
            scenes: [scene("one")],
            options: try options(["dir", "--page", "out.html"])
        )
        #expect(outputs.agreement == nil)
        #expect(outputs.report == nil)
    }

    @Test("A scene that cannot be decoded is skipped rather than stopping the run")
    func skipsBadScenes() throws {
        let outputs = try CompareCommand().run(
            scenes: [CorpusInput(name: "broken", json: "{"), scene("good")],
            options: try options(["dir", "--page", "out.html"])
        )
        #expect(outputs.page != nil)
    }

    @Test("A scene with nothing to solve is not asked about")
    func skipsSolvedScenes() throws {
        let solved = CorpusInput(
            name: "solved",
            json: """
                {
                  "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                                     "size": {"width": 320, "height": 240}}},
                  "annotations": [
                    {"id": 1,
                     "target": {"raw": {"origin": {"x": 140, "y": 110},
                                        "size": {"width": 40, "height": 20}}},
                     "label": "Here",
                     "placement": {"direction": "n", "leaderLength": 40}}
                  ]
                }
                """
        )
        let outputs = try CompareCommand().run(
            scenes: [solved],
            options: try options(["dir", "--page", "out.html"])
        )
        #expect(try #require(outputs.page).contains("Nothing to compare"))
    }

    @Test("Asking is reproducible")
    func reproducible() throws {
        let scenes = [scene("one"), scene("two")]
        let parsed = try options(["dir", "--page", "out.html", "--questions", "5"])
        #expect(isReproducible { try? CompareCommand().run(scenes: scenes, options: parsed).page })
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .compare = try Command(arguments: ["compare", "dir"]) else {
            Issue.record("expected the compare subcommand")
            return
        }
    }
}
