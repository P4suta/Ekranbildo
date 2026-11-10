@testable import EkranbildoCLI
import Testing

@Suite("Bisect arguments")
struct BisectArgumentTests {

    private static let minimum = [
        "a.ekranbildotrace", "--versions", "v1,v2", "--run", "ask {version}",
    ]

    @Test("A bundle path is required")
    func bundleRequired() {
        #expect(throws: CommandError.self) { try BisectOptions(arguments: []) }
    }

    @Test("Versions are required, oldest first")
    func versionsRequired() throws {
        #expect(throws: CommandError.self) {
            try BisectOptions(arguments: ["a.ekranbildotrace", "--run", "ask {version}"])
        }
        let options = try BisectOptions(arguments: Self.minimum)
        #expect(options.versions == ["v1", "v2"])
    }

    @Test("A command to run is required")
    func runRequired() {
        #expect(throws: CommandError.self) {
            try BisectOptions(arguments: ["a.ekranbildotrace", "--versions", "v1,v2"])
        }
    }

    @Test("A command that does not mention the version is refused")
    func runMustMentionTheVersion() {
        #expect(throws: CommandError.self) {
            try BisectOptions(
                arguments: ["a.ekranbildotrace", "--versions", "v1,v2", "--run", "ask nothing"])
        }
    }

    @Test("Fewer than two versions is not a range")
    func rangeNeedsTwoEnds() {
        #expect(throws: CommandError.self) {
            try BisectOptions(
                arguments: ["a.ekranbildotrace", "--versions", "v1", "--run", "ask {version}"])
        }
    }

    @Test("Blank entries between commas are not versions")
    func blanksAreRejected() {
        #expect(throws: CommandError.self) {
            try BisectOptions(
                arguments: ["a.ekranbildotrace", "--versions", "v1,,v2", "--run", "ask {version}"])
        }
    }

    @Test("The command line names the version and the bundle")
    func commandLineIsFilledIn() throws {
        let line = BisectCommand.commandLine(
            "run {version} on {bundle}", version: "v3", bundle: "a.ekranbildotrace")
        #expect(line == "run v3 on a.ekranbildotrace")
    }

    @Test("The subcommand is recognised")
    func subcommandRecognised() throws {
        guard case .bisect = try Command(arguments: ["bisect"] + Self.minimum) else {
            Issue.record("bisect was not recognised")
            return
        }
    }
}

@Suite("Bisect")
struct BisectCommandTests {

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

    private func options(_ versions: [String]) throws -> BisectOptions {
        try BisectOptions(
            arguments: [
                "a.ekranbildotrace", "--versions", versions.joined(separator: ","),
                "--run", "ask {version}",
            ]
        )
    }

    @Test("The recorded answer is what the builds are compared against")
    func comparesAgainstTheRecording() throws {
        let bundle = try ReplayCommand().record(sceneJSON: Self.sceneJSON)
        let recorded = try ReplayCommand().run(bundleJSON: bundle).answerText

        let search = try BisectCommand().run(
            bundleJSON: bundle,
            options: options(["v1", "v2", "v3", "v4"])
        ) { version in
            version == "v3" || version == "v4" ? "something else" : recorded
        }
        #expect(search.outcome == .found(version: "v3", previous: "v2"))
    }

    @Test("A bundle that is not a bundle is refused before any build is run")
    func rubbishIsRefused() throws {
        var asked = 0
        #expect(throws: CommandError.self) {
            try BisectCommand().run(bundleJSON: "{}", options: options(["v1", "v2"])) { _ in
                asked += 1
                return ""
            }
        }
        #expect(asked == 0)
    }
}
