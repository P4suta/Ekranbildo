@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoTestKit
import Testing

@Suite("Detect command")
struct DetectCommandTests {

    private func screenshotPNG() throws -> [UInt8] {
        var screen = SyntheticScreenshot(
            width: 200,
            height: 140,
            background: .opaque(red: 250, green: 250, blue: 250)
        )
        screen.paint(
            SceneRect(x: 20, y: 20, width: 160, height: 100),
            color: .opaque(red: 236, green: 236, blue: 238)
        )
        screen.paint(
            SceneRect(x: 40, y: 40, width: 60, height: 24),
            color: .opaque(red: 40, green: 110, blue: 220)
        )
        return try ImageCodec.encodePNG(screen.image)
    }

    private func options(_ arguments: [String]) throws -> DetectOptions {
        try DetectOptions(arguments: arguments)
    }

    @Test("An image path is required")
    func requiresInput() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("Unknown flags are refused rather than ignored")
    func unknownFlag() {
        #expect(throws: CommandError.self) { try self.options(["a.png", "--nope", "x"]) }
    }

    @Test("A flag without a value is refused")
    func missingValue() {
        #expect(throws: CommandError.self) { try self.options(["a.png", "--elements"]) }
    }

    @Test("A malformed snap point is refused", arguments: ["1", "1,2,3", "a,b", "1,", "nan,2"])
    func malformedSnapPoint(text: String) {
        #expect(throws: CommandError.self) { try self.options(["a.png", "--snap", text]) }
    }

    @Test("A snap point is read as x,y")
    func snapPoint() throws {
        let parsed = try options(["a.png", "--snap", "12.5,-3"])
        #expect(parsed.snapPoint == ScenePoint(x: 12.5, y: -3))
    }

    @Test("Nothing is produced for an output that was not asked for")
    func onlyWhatWasAsked() throws {
        let outputs = try DetectCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png"])
        )
        #expect(outputs.elements == nil)
        #expect(outputs.report == nil)
        #expect(outputs.ladder.isEmpty)
    }

    @Test("The element listing names what was found")
    func elementListing() throws {
        let outputs = try DetectCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--elements", "out.txt"])
        )
        let text = try #require(outputs.elements)
        let lines = text.split(separator: "\n")
        #expect(lines.count >= 3, "background, window and button should all be found")
        #expect(lines[0].hasPrefix("0 "))
        #expect(text.contains("regionAnalysis"))
    }

    @Test("The listing is reproducible")
    func reproducibleListing() throws {
        let png = try screenshotPNG()
        let parsed = try options(["a.png", "--elements", "out.txt"])
        #expect(isReproducible { try? DetectCommand().run(imageBytes: png, options: parsed).elements })
    }

    @Test("The report embeds the picture the rectangles came from")
    func reportEmbedsImage() throws {
        let outputs = try DetectCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--report", "out.html", "--snap", "70,52"])
        )
        let html = try #require(outputs.report)
        #expect(html.contains("data:image/png;base64,"))
        #expect(html.contains("<svg"))
        #expect(html.contains("class=\"rung\""), "the snap ladder should be drawn")
        #expect(!html.contains("<script"))
    }

    @Test("A click resolves to a ladder of readings")
    func snapLadder() throws {
        let outputs = try DetectCommand().run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--snap", "70,52"])
        )
        #expect(outputs.ladder.count >= 2)
        for (inner, outer) in zip(outputs.ladder, outputs.ladder.dropFirst()) {
            #expect(outer.raw.contains(inner.raw))
        }
    }

    @Test("Bytes that are not an image are reported")
    func notAnImage() {
        #expect(throws: (any Error).self) {
            try DetectCommand().run(
                imageBytes: [0x01, 0x02],
                options: try self.options(["a.png", "--elements", "out.txt"])
            )
        }
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .detect = try Command(arguments: ["detect", "a.png"]) else {
            Issue.record("expected the detect subcommand")
            return
        }
    }
}
