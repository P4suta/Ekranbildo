@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoTestKit
import Testing

@Suite("Stitch command")
struct StitchCommandTests {

    private static let viewport = 120

    private func frames(_ offsets: [Int]) throws -> [[UInt8]] {
        try ScrollSimulator(
            page: ScrollSimulator.page(width: 160, height: 600),
            viewportHeight: Self.viewport
        )
        .frames(offsets: offsets)
        .map { try ImageCodec.encodePNG($0.image) }
    }

    private func options(_ arguments: [String]) throws -> StitchOptions {
        try StitchOptions(arguments: arguments)
    }

    @Test("Frames are taken in the order they were given")
    func inputOrder() throws {
        let parsed = try options(["a.png", "b.png", "c.png", "--png", "out.png"])
        #expect(parsed.inputs == ["a.png", "b.png", "c.png"])
        #expect(parsed.pngOutput == "out.png")
    }

    @Test("At least one frame is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options(["--png", "out.png"]) }
    }

    @Test("The joined page is taller than any one frame")
    func joins() throws {
        let outputs = try StitchCommand().run(
            frames: try frames([0, 60, 120]),
            options: try options(["a.png", "--png", "out.png"])
        )
        let png = try #require(outputs.png)
        #expect(try ImageCodec.decode(png).image.height == 120 + Self.viewport)
        #expect(outputs.uncertainJoinCount == 0)
    }

    @Test("The report says what was found and what it cost")
    func report() throws {
        let outputs = try StitchCommand().run(
            frames: try frames([0, 60, 120]),
            options: try options(["a.png"])
        )
        #expect(outputs.report.contains("frames 3"))
        #expect(outputs.report.contains("row comparisons"))
        #expect(outputs.report.contains("every join matched"))
    }

    @Test("An uncertain join is named rather than counted")
    func namesUncertainJoins() throws {
        let outputs = try StitchCommand().run(
            frames: try frames([0, 40, 40 + Self.viewport + 30]),
            options: try options(["a.png"])
        )
        #expect(outputs.uncertainJoinCount > 0)
        #expect(outputs.report.contains("uncertain join after frame 1"))
    }

    @Test("Bytes that are not an image are reported")
    func notAnImage() {
        #expect(throws: (any Error).self) {
            try StitchCommand().run(
                frames: [[0x01, 0x02]],
                options: try self.options(["a.png"])
            )
        }
    }

    @Test("Stitching is reproducible")
    func reproducible() throws {
        let taken = try frames([0, 55, 110])
        let parsed = try options(["a.png", "--png", "out.png"])
        #expect(isReproducible { try? StitchCommand().run(frames: taken, options: parsed).png })
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .stitch = try Command(arguments: ["stitch", "a.png"]) else {
            Issue.record("expected the stitch subcommand")
            return
        }
    }
}
