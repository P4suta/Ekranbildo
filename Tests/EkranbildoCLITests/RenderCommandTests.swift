@testable import EkranbildoCLI
import Testing

@Suite("Argument parsing")
struct ArgumentParsingTests {

    @Test("An input path is required")
    func inputRequired() {
        #expect(throws: CommandError.self) {
            try RenderOptions(arguments: [])
        }
    }

    @Test("The input path is taken as the first positional argument")
    func inputPath() throws {
        #expect(try RenderOptions(arguments: ["scene.json"]).input == "scene.json")
    }

    @Test("Output paths are optional and default to nothing")
    func outputsDefaultToNothing() throws {
        let options = try RenderOptions(arguments: ["scene.json"])
        #expect(options.pngOutput == nil)
        #expect(options.svgOutput == nil)
        #expect(options.traceOutput == nil)
    }

    @Test("Each output has a flag")
    func outputFlags() throws {
        let options = try RenderOptions(
            arguments: [
                "scene.json", "--png", "a.png", "--svg", "b.svg", "--trace", "c.trace",
            ]
        )
        #expect(options.pngOutput == "a.png")
        #expect(options.svgOutput == "b.svg")
        #expect(options.traceOutput == "c.trace")
    }

    @Test("Scale defaults to one and can be set")
    func scale() throws {
        #expect(try RenderOptions(arguments: ["s.json"]).scale == 1)
        #expect(try RenderOptions(arguments: ["s.json", "--scale", "2"]).scale == 2)
    }

    @Test("A flag with no value is rejected rather than silently ignored")
    func missingValue() {
        #expect(throws: CommandError.self) {
            try RenderOptions(arguments: ["s.json", "--png"])
        }
    }

    @Test("An unknown flag is rejected")
    func unknownFlag() {
        #expect(throws: CommandError.self) {
            try RenderOptions(arguments: ["s.json", "--wat", "1"])
        }
    }

    @Test("A scale that is not a positive number is rejected")
    func invalidScale() {
        #expect(throws: CommandError.self) {
            try RenderOptions(arguments: ["s.json", "--scale", "zero"])
        }
        #expect(throws: CommandError.self) {
            try RenderOptions(arguments: ["s.json", "--scale", "0"])
        }
    }
}

@Suite("Render command")
struct RenderCommandTests {

    private let sceneJSON = """
        {
          "canvas": { "raw": { "origin": { "x": 0, "y": 0 },
                               "size": { "width": 200, "height": 120 } } },
          "background": null,
          "annotations": [
            {
              "id": { "raw": 1 },
              "target": { "raw": { "origin": { "x": 40, "y": 40 },
                                   "size": { "width": 60, "height": 24 } } },
              "label": "Save",
              "placement": { "direction": 0, "leaderLength": 40 }
            }
          ],
          "style": null
        }
        """

    @Test("A scene renders to every requested output")
    func rendersAllOutputs() throws {
        let outputs = try RenderCommand().run(
            sceneJSON: sceneJSON,
            options: try RenderOptions(arguments: ["s.json", "--png", "a", "--svg", "b", "--trace", "c"])
        )
        #expect(outputs.png?.isEmpty == false)
        #expect(outputs.svg?.contains("<svg") == true)
        #expect(outputs.trace?.isEmpty == false)
    }

    @Test("Only the requested outputs are produced")
    func onlyRequestedOutputs() throws {
        let outputs = try RenderCommand().run(
            sceneJSON: sceneJSON,
            options: try RenderOptions(arguments: ["s.json", "--svg", "b"])
        )
        #expect(outputs.png == nil)
        #expect(outputs.svg != nil)
        #expect(outputs.trace == nil)
    }

    @Test("Malformed input is reported rather than crashing")
    func malformedInput() {
        #expect(throws: CommandError.self) {
            try RenderCommand().run(
                sceneJSON: "{ not json",
                options: try RenderOptions(arguments: ["s.json"])
            )
        }
    }

    @Test("Running twice produces identical output")
    func reproducible() throws {
        let options = try RenderOptions(arguments: ["s.json", "--png", "a", "--svg", "b", "--trace", "c"])
        let first = try RenderCommand().run(sceneJSON: sceneJSON, options: options)
        let second = try RenderCommand().run(sceneJSON: sceneJSON, options: options)
        #expect(first.svg == second.svg)
        #expect(first.trace == second.trace)
        #expect(first.png == second.png)
    }

    @Test("The trace records the stages of the render and carries no wall-clock time")
    func traceContents() throws {
        let outputs = try RenderCommand().run(
            sceneJSON: sceneJSON,
            options: try RenderOptions(arguments: ["s.json", "--png", "a", "--trace", "c"])
        )
        let trace = try #require(outputs.trace)
        #expect(trace.contains("decode"))
        #expect(trace.contains("build"))
        #expect(trace.contains("rasterise"))
        #expect(trace.contains("annotations=1"))
    }

    @Test("Render warnings reach the trace")
    func warningsAreTraced() throws {
        let outputs = try RenderCommand().run(
            sceneJSON: sceneJSON,
            options: try RenderOptions(arguments: ["s.json", "--png", "a", "--trace", "c"])
        )
        #expect(outputs.trace?.contains("warning") == true)
    }
}
