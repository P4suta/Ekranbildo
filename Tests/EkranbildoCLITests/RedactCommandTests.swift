@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoTestKit
import Testing

@Suite("Redact command")
struct RedactCommandTests {

    private static let line = SceneRect(x: 20, y: 20, width: 170, height: 16)

    private struct StatedText: SemanticProvider {
        let text: String
        let rect: SceneRect
        var version: String { "stated" }

        func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
            SceneSemantics(
                canvas: SceneRect(
                    x: 0, y: 0, width: Double(image.width), height: Double(image.height)),
                elements: [
                    ScreenElement(
                        rect: rect,
                        kind: .text,
                        text: text,
                        confidence: 1,
                        provenance: .textRecognition
                    )
                ],
                saliency: .empty,
                providerVersion: version
            )
        }
    }

    private func screenshotPNG() throws -> [UInt8] {
        var screen = SyntheticScreenshot(width: 220, height: 60)
        for column in 0..<20 {
            screen.paint(
                SceneRect(x: 22 + Double(column) * 8, y: 22, width: 3, height: 12),
                color: .opaque(red: 30, green: 30, blue: 30)
            )
        }
        return try ImageCodec.encodePNG(screen.image)
    }

    private func command(_ text: String) -> RedactCommand {
        RedactCommand(textProvider: StatedText(text: text, rect: Self.line))
    }

    private func options(_ arguments: [String]) throws -> RedactOptions {
        try RedactOptions(arguments: arguments)
    }

    @Test("A screenshot is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("A style nobody has is refused")
    func unknownStyle() {
        #expect(throws: CommandError.self) { try self.options(["a.png", "--style", "smudge"]) }
    }

    @Test("The default style leaves nothing behind")
    func defaultStyle() throws {
        #expect(try options(["a.png"]).style.isIrreversible)
    }

    @Test("A secret in the picture is covered")
    func covers() throws {
        let outputs = try command("key sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc here").run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png", "--png", "out.png"])
        )
        #expect(outputs.maskCount == 1)
        #expect(outputs.failureCount == 0)
        #expect(outputs.png != nil)
    }

    @Test("A picture with nothing in it gets no masks")
    func nothingToCover() throws {
        let outputs = try command("Deployment target and signing identity").run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png"])
        )
        #expect(outputs.maskCount == 0)
        #expect(outputs.report.contains("masks 0"))
    }

    @Test("The report never repeats what it covered")
    func reportKeepsTheSecret() throws {
        let secret = "sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc"
        let outputs = try command("key \(secret) here").run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png"])
        )
        #expect(!outputs.report.contains(secret))
        #expect(outputs.report.contains("mask pixelate"))
    }

    @Test("The report says every mask took")
    func reportsSuccess() throws {
        let outputs = try command("alice@example.org").run(
            imageBytes: try screenshotPNG(),
            options: try options(["a.png"])
        )
        #expect(outputs.report.contains("every mask took"))
    }

    @Test("What comes out is not what went in")
    func pixelsChanged() throws {
        let before = try screenshotPNG()
        let outputs = try command("alice@example.org").run(
            imageBytes: before,
            options: try options(["a.png", "--png", "out.png"])
        )
        #expect(try #require(outputs.png) != before)
    }

    @Test("Redacting is reproducible")
    func reproducible() throws {
        let png = try screenshotPNG()
        let parsed = try options(["a.png", "--png", "out.png"])
        let subject = command("alice@example.org")
        #expect(isReproducible { try? subject.run(imageBytes: png, options: parsed).png })
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .redact = try Command(arguments: ["redact", "a.png"]) else {
            Issue.record("expected the redact subcommand")
            return
        }
    }
}
