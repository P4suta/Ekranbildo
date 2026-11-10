@testable import EkranbildoCLI
import EkranbildoTestKit
import Testing

@Suite("Camera command")
struct CameraCommandTests {

    private static let sample = """
        {
          "frame": {"raw": {"origin": {"x": 0, "y": 0},
                            "size": {"width": 1600, "height": 1000}}},
          "duration": {"nanoseconds": 20000000000},
          "events": [
            {"at": {"nanoseconds": 3000000000},
             "focus": {"raw": {"origin": {"x": 200, "y": 300},
                               "size": {"width": 120, "height": 60}}}},
            {"at": {"nanoseconds": 9000000000},
             "focus": {"raw": {"origin": {"x": 1100, "y": 600},
                               "size": {"width": 140, "height": 50}}}}
          ]
        }
        """

    private func options(_ arguments: [String]) throws -> CameraOptions {
        try CameraOptions(arguments: arguments)
    }

    @Test("A file of events is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("Something that is not a list of events is reported")
    func malformedInput() {
        #expect(throws: CommandError.self) {
            try CameraCommand().run(inputJSON: "{", options: try self.options(["a.json"]))
        }
    }

    @Test("The keyframes say where the camera looks and when")
    func producesKeyframes() throws {
        let outputs = try CameraCommand().run(
            inputJSON: Self.sample,
            options: try options(["a.json"])
        )
        #expect(outputs.keyframeCount > 2)
        #expect(outputs.keyframes.contains("0.000s"))
        #expect(outputs.keyframes.contains("scene["))
    }

    @Test("Nothing is drawn unless it was asked for")
    func onlyWhatWasAsked() throws {
        let outputs = try CameraCommand().run(
            inputJSON: Self.sample,
            options: try options(["a.json"])
        )
        #expect(outputs.report == nil)
    }

    @Test("The drawing shows the path over the picture")
    func drawsThePath() throws {
        let outputs = try CameraCommand().run(
            inputJSON: Self.sample,
            options: try options(["a.json", "--report", "out.html"])
        )
        let html = try #require(outputs.report)
        #expect(html.contains("Camera path"))
        #expect(html.contains("class=\"travel\""))
        #expect(!html.contains("<script"))
    }

    @Test("The same events give the same keyframes")
    func reproducible() throws {
        let parsed = try options(["a.json"])
        #expect(
            isReproducible {
                try? CameraCommand().run(inputJSON: Self.sample, options: parsed).keyframes
            }
        )
    }

    @Test("A recording nobody clicked in still produces a path")
    func nothingHappened() throws {
        let empty = """
            {
              "frame": {"raw": {"origin": {"x": 0, "y": 0},
                                "size": {"width": 800, "height": 600}}},
              "duration": {"nanoseconds": 5000000000},
              "events": []
            }
            """
        let outputs = try CameraCommand().run(inputJSON: empty, options: try options(["a.json"]))
        #expect(outputs.keyframeCount == 2)
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .camera = try Command(arguments: ["camera", "a.json"]) else {
            Issue.record("expected the camera subcommand")
            return
        }
    }

    @Test("A pinned view in the file is the view that comes out")
    func usesPinnedViews() throws {
        let outputs = try CameraCommand().run(
            inputJSON: """
                {
                  "frame": {"raw": {"origin": {"x": 0, "y": 0},
                            "size": {"width": 1000, "height": 800}}},
                  "duration": {"nanoseconds": 20000000000},
                  "events": [],
                  "overrides": [
                    {"at": {"nanoseconds": 5000000000},
                     "view": {"raw": {"origin": {"x": 123, "y": 0},
                              "size": {"width": 400, "height": 320}}}}
                  ]
                }
                """,
            options: try CameraOptions(arguments: ["events.json"])
        )
        #expect(outputs.keyframes.contains("123"))
    }

    @Test("A file with nothing pinned still opens")
    func opensAFileWithoutOverrides() throws {
        let outputs = try CameraCommand().run(
            inputJSON: """
                {
                  "frame": {"raw": {"origin": {"x": 0, "y": 0},
                            "size": {"width": 1000, "height": 800}}},
                  "duration": {"nanoseconds": 20000000000},
                  "events": []
                }
                """,
            options: try CameraOptions(arguments: ["events.json"])
        )
        #expect(outputs.keyframeCount > 0)
    }
}
