@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoTestKit
import Testing

@Suite("Annotate command")
struct AnnotateCommandTests {

    private func screenshotPNG() throws -> [UInt8] {
        try ImageCodec.encodePNG(SceneLibrary.applicationWindow.image)
    }

    private func options(_ arguments: [String]) throws -> AnnotateOptions {
        try AnnotateOptions(arguments: arguments)
    }

    @Test("A point carries its own label")
    func pointAndLabel() throws {
        let parsed = try options(["a.png", "--point", "12,34:Search field"])
        #expect(parsed.marks.count == 1)
        #expect(parsed.marks[0].point == ScenePoint(x: 12, y: 34))
        #expect(parsed.marks[0].label == "Search field")
    }

    @Test("Points keep the order they were given in")
    func pointOrder() throws {
        let parsed = try options([
            "a.png", "--point", "1,1:First", "--point", "2,2:Second", "--point", "3,3:Third",
        ])
        #expect(parsed.marks.map(\.label) == ["First", "Second", "Third"])
    }

    @Test("A label may contain the separator")
    func labelWithColon() throws {
        #expect(try options(["a.png", "--point", "1,1:Step 1: begin"]).marks[0].label == "Step 1: begin")
    }

    @Test(
        "A malformed point is refused",
        arguments: ["1,1", "Label", "1:Label", "a,b:Label", "1,1:", "1,1,1:Label"]
    )
    func malformedPoint(text: String) {
        #expect(throws: CommandError.self) { try self.options(["a.png", "--point", text]) }
    }

    @Test("At least one point is required")
    func pointRequired() {
        #expect(throws: CommandError.self) { try self.options(["a.png"]) }
    }

    @Test("A screenshot is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options(["--point", "1,1:X"]) }
    }

    @Test("A malformed capture scale is refused")
    func malformedScale() {
        #expect(throws: CommandError.self) {
            try self.options(["a.png", "--point", "1,1:X", "--capture-scale", "0"])
        }
    }

    @Test("A click lands on the control under it")
    func snapsToControl() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--point", "32,18:Toolbar button"])
        )
        let button = try #require(SceneLibrary.applicationWindow.region(named: "toolbar button"))
        #expect(Geo.intersectionOverUnion(outputs.targets[0].raw, button.raw) > 0.9)
    }

    @Test("A retina screenshot is annotated in points, not pixels")
    func capturePoints() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options([
                "a.png", "--point", "16,9:Toolbar button", "--capture-scale", "2",
            ])
        )
        let button = try #require(SceneLibrary.applicationWindow.region(named: "toolbar button"))
        #expect(outputs.targets[0].minX * 2 == button.minX)
        #expect(outputs.targets[0].raw.width * 2 == button.raw.width)
    }

    @Test("A click on nothing still gets a target")
    func bareClick() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try ImageCodec.encodePNG(
                SyntheticScreenshot(width: 200, height: 120).image),
            options: try options(["a.png", "--point", "100,60:Here"])
        )
        #expect(outputs.targets.count == 1)
        #expect(outputs.targets[0].raw.contains(P2(x: 100, y: 60)))
    }

    @Test("The picture that comes out is of the screenshot")
    func rendersTheScreenshot() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--point", "32,18:Button", "--png", "out.png"])
        )
        let png = try #require(outputs.png)
        let rendered = try ImageCodec.decode(png).image
        #expect(rendered.width == SceneLibrary.applicationWindow.width)

        let sidebar = rendered[x: 30, y: 150]
        #expect(sidebar.red > 200 && sidebar.blue > 200 && sidebar.alpha == 255)
    }

    @Test("The trace says what each click was taken to mean")
    func traced() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options([
                "a.png", "--point", "32,18:Button", "--trace", "out.trace",
            ])
        )
        let trace = try #require(outputs.trace)
        #expect(trace.contains("snapped"))
        #expect(trace.contains("Button"))
        #expect(trace.contains("solved"))
    }

    @Test("Nothing is produced for an output that was not asked for")
    func onlyWhatWasAsked() throws {
        let outputs = try AnnotateCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--point", "32,18:Button"])
        )
        #expect(outputs.png == nil)
        #expect(outputs.svg == nil)
        #expect(outputs.report == nil)
        #expect(outputs.trace == nil)
    }

    @Test("Annotating is reproducible")
    func reproducible() throws {
        let png = try screenshotPNG()
        let parsed = try options(["a.png", "--point", "32,18:Button", "--svg", "out.svg"])
        #expect(isReproducible { try? AnnotateCommand().run(imageBytes: png, options: parsed).svg })
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .annotate = try Command(arguments: ["annotate", "a.png", "--point", "1,1:X"])
        else {
            Issue.record("expected the annotate subcommand")
            return
        }
    }
}
