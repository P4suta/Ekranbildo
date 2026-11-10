@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoCore
import Testing

@Suite("Replay arguments")
struct ReplayArgumentTests {

    @Test("A bundle path is required")
    func bundleRequired() {
        #expect(throws: CommandError.self) { try ReplayOptions(arguments: []) }
    }

    @Test("The bundle is the first positional argument")
    func bundlePath() throws {
        #expect(try ReplayOptions(arguments: ["a.ekranbildotrace"]).input == "a.ekranbildotrace")
    }

    @Test("Re-recording is off unless asked for")
    func recordingIsOptIn() throws {
        #expect(try !ReplayOptions(arguments: ["a.ekranbildotrace"]).rerecord)
        #expect(try ReplayOptions(arguments: ["a.ekranbildotrace", "--record", "yes"]).rerecord)
    }

    @Test("The answer can be written out on its own, for a bisect to compare")
    func answerOutput() throws {
        let options = try ReplayOptions(arguments: ["a.ekranbildotrace", "--answer", "out.txt"])
        #expect(options.answerOutput == "out.txt")
    }

    @Test("The subcommand is recognised")
    func subcommandRecognised() throws {
        guard case .replay = try Command(arguments: ["replay", "a.ekranbildotrace"]) else {
            Issue.record("replay was not recognised")
            return
        }
    }
}

@Suite("Replay")
struct ReplayCommandTests {

    private static let sceneJSON = """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "annotations": [
            {"id": {"raw": 1},
             "target": {"raw": {"origin": {"x": 40, "y": 180},
                       "size": {"width": 80, "height": 24}}},
             "label": "First", "placement": null},
            {"id": {"raw": 2},
             "target": {"raw": {"origin": {"x": 240, "y": 60},
                       "size": {"width": 80, "height": 24}}},
             "label": "Second", "placement": null}
          ]
        }
        """

    private func recorded() throws -> String {
        try ReplayCommand().record(sceneJSON: Self.sceneJSON)
    }

    @Test("A bundle recorded from a scene replays as unchanged")
    func replaysUnchanged() throws {
        let outcome = try ReplayCommand().run(bundleJSON: recorded())
        #expect(outcome.verdict.isUnchanged)
    }

    @Test("It still replays as unchanged when replayed again")
    func replaysUnchangedTwice() throws {
        let bundle = try recorded()
        #expect(try ReplayCommand().run(bundleJSON: bundle).verdict.isUnchanged)
        #expect(try ReplayCommand().run(bundleJSON: bundle).verdict.isUnchanged)
    }

    @Test("A recorded answer that has been tampered with is reported as changed")
    func changedAnswerIsReported() throws {
        let tampered = try recorded().replacingOccurrences(
            of: "\"leaderLength\" : 44", with: "\"leaderLength\" : 124")
        let outcome = try ReplayCommand().run(bundleJSON: tampered)
        #expect(!outcome.verdict.isUnchanged)
        #expect(outcome.verdict.report.contains("changed"))
    }

    @Test("A recording from a build that decides differently is not comparable")
    func otherPipelineIsNotComparable() throws {
        let moved = try recorded().replacingOccurrences(
            of: "\"normalization\" : \"", with: "\"normalization\" : \"x")
        let outcome = try ReplayCommand().run(bundleJSON: moved)
        #expect(!outcome.verdict.isUnchanged)
        #expect(outcome.verdict.report.contains("not comparable"))
    }

    @Test("Re-recording replaces the answer and the build that gave it")
    func rerecording() throws {
        let moved = try recorded().replacingOccurrences(
            of: "\"normalization\" : \"", with: "\"normalization\" : \"x")
        let outcome = try ReplayCommand().run(bundleJSON: moved, rerecord: true)
        let again = try #require(outcome.rerecorded)
        #expect(try ReplayCommand().run(bundleJSON: again).verdict.isUnchanged)
    }

    @Test("The answer on its own is the same text a second run produces")
    func answerTextIsStable() throws {
        let bundle = try recorded()
        let first = try ReplayCommand().run(bundleJSON: bundle).answerText
        let second = try ReplayCommand().run(bundleJSON: bundle).answerText
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("A bundle that is not a bundle is refused with a readable reason")
    func rubbishIsRefused() {
        #expect(throws: CommandError.self) { try ReplayCommand().run(bundleJSON: "{}") }
    }

    @Test("Solving a scene keeps what this version has no name for")
    func solvingKeepsUnknownKeys() throws {
        let fromTheFuture = Self.sceneJSON.replacingOccurrences(
            of: "\"annotations\"", with: "\"somethingAddedLater\": {\"depth\": 3},\n \"annotations\""
        )
        let bundle = try ReplayCommand().record(sceneJSON: fromTheFuture)
        #expect(bundle.contains("somethingAddedLater"))
    }
}

@Suite("Traces name the build")
struct TracePipelineTests {

    private static let sceneJSON = """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "annotations": [
            {"id": {"raw": 1},
             "target": {"raw": {"origin": {"x": 40, "y": 180},
                       "size": {"width": 80, "height": 24}}},
             "label": "First", "placement": null}
          ]
        }
        """

    private func trace() throws -> String {
        let options = try RenderOptions(arguments: ["scene.json", "--trace", "t.json"])
        let outputs = try RenderCommand().run(sceneJSON: Self.sceneJSON, options: options)
        return try #require(outputs.trace)
    }

    @Test("Every part of the pipeline version is in the trace")
    func everyPartIsRecorded() throws {
        let text = try trace()
        let version = ReplayCommand.pipeline
        for part in [
            version.candidateGeneration, version.normalization,
            version.weights, version.comparator, version.renderer,
        ] {
            #expect(text.contains(part), Comment(rawValue: "\(part) is not in the trace"))
        }
    }

    @Test("A trace is still the same text twice")
    func stillDeterministic() throws {
        let first = try trace()
        let second = try trace()
        #expect(first == second)
    }
}
