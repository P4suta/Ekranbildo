@testable import EkranbildoCLI
import EkranbildoTestKit
import Foundation
import Testing

@Suite("Synthesise command")
struct SynthesiseCommandTests {

    private static let scene = """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "background": {"contentHash": "the-users-screen",
                         "pixelWidth": 800, "pixelHeight": 600},
          "annotations": [
            {"id": {"raw": 1},
             "target": {"raw": {"origin": {"x": 40, "y": 40},
                        "size": {"width": 60, "height": 24}}},
             "label": "Transfer to 4111 1111 1111 1111",
             "placement": {"direction": 4, "leaderLength": 70},
             "badge": 1},
            {"id": {"raw": 2},
             "target": {"raw": {"origin": {"x": 200, "y": 120},
                        "size": {"width": 60, "height": 24}}},
             "label": "yasunobu@example.com",
             "placement": null}
          ]
        }
        """

    private func options(_ arguments: [String]) throws -> SynthesiseOptions {
        try SynthesiseOptions(arguments: arguments)
    }

    @Test("A scene is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("A stray argument is refused")
    func strayArgument() {
        #expect(throws: CommandError.self) { try self.options(["a.json", "b.json"]) }
    }

    @Test("A scene that is not a scene is refused with a reason")
    func undecodable() {
        #expect(throws: CommandError.self) {
            try SynthesiseCommand().run(sceneJSON: "{ not a scene")
        }
    }

    @Test(
        "Nothing real survives into the file",
        arguments: ["Transfer", "4111", "yasunobu@example.com", "the-users-screen"]
    )
    func nothingSurvivesTheFile(secret: String) throws {
        let outputs = try SynthesiseCommand().run(sceneJSON: Self.scene)
        #expect(!outputs.scene.contains(secret))
    }

    @Test("What comes out is still a scene that opens")
    func stillOpens() throws {
        let outputs = try SynthesiseCommand().run(sceneJSON: Self.scene)
        let reopened = try SynthesiseCommand().run(sceneJSON: outputs.scene)
        #expect(reopened.replacedLabels == 2)
    }

    @Test("The report shows what each label became")
    func reportShowsReplacements() throws {
        let outputs = try SynthesiseCommand().run(sceneJSON: Self.scene)
        #expect(outputs.report.contains("label 1"))
        #expect(outputs.report.contains("label 2"))
        #expect(outputs.report.contains("picture 800x600"))
        #expect(!outputs.report.contains("Transfer"))
    }

    @Test("It says how much it replaced")
    func counts() throws {
        let outputs = try SynthesiseCommand().run(sceneJSON: Self.scene)
        #expect(outputs.replacedLabels == 2)
        #expect(outputs.replacedPictures == 1)
    }

    @Test("The subcommand is reachable from the argument list")
    func reachable() throws {
        guard case .synthesise = try Command(arguments: ["synthesise", "scene.json"]) else {
            Issue.record("synthesise did not resolve to the synthesise command")
            return
        }
    }

    @Test("Synthesising the same scene twice gives the same file")
    func reproducible() {
        #expect(isReproducible { try? SynthesiseCommand().run(sceneJSON: Self.scene).scene })
    }
}
