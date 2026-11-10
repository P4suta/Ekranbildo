@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoTimeline
import Foundation
import Testing

@Suite("Render video limits")
struct RenderVideoLimitsTests {

    private func source(_ count: Int) -> [ImageBuffer] {
        (0..<count).map { index in
            var screen = SyntheticScreenshot(width: 120, height: 80)
            screen.paint(
                SceneRect(x: 0, y: 0, width: 120, height: 80),
                color: .opaque(red: UInt8(truncatingIfNeeded: index * 5), green: 60, blue: 120)
            )
            return screen.image
        }
    }

    private func options(_ arguments: [String]) throws -> RenderVideoOptions {
        try RenderVideoOptions(arguments: arguments)
    }

    private func input(_ pictures: [ImageBuffer], cursor: CursorTrack? = nil) -> RenderVideoInput {
        RenderVideoInput(
            source: pictures,
            timings: cursor == nil ? [] : [.zero],
            cursor: cursor
        )
    }

    private func movingPointer(until second: Double) -> CursorTrack {
        CursorTrack(
            samples: [
                CursorKeyframe(at: .zero, position: ScenePoint(x: 0, y: 0)),
                CursorKeyframe(at: .seconds(second), position: ScenePoint(x: 1, y: 1)),
            ])
    }

    @Test("Frames too many to hold at once are refused with a reason")
    func refusesAnImpossibleRender() throws {
        let thrown = #expect(throws: CommandError.self) {
            try RenderVideoCommand(pixelBudget: 1000).frames(
                self.input(self.source(4)), options: try self.options(["dir"]))
        }
        #expect(thrown?.detail.contains("memory") == true)
    }

    @Test("Frames within the budget are rendered")
    func rendersWithinTheBudget() throws {
        let rendered = try RenderVideoCommand(pixelBudget: 120 * 80 * 4).frames(
            input(source(4)), options: try options(["dir"]))
        #expect(rendered.frames.count == 4)
    }

    @Test("Frames held after the last recorded one count against the budget")
    func heldFramesCountTowardsTheBudget() {
        #expect(throws: CommandError.self) {
            try RenderVideoCommand(pixelBudget: 120 * 80 * 3).frames(
                self.input(self.source(1), cursor: self.movingPointer(until: 1)),
                options: try self.options(["dir", "--fps", "10"])
            )
        }
    }

    struct Export {
        let pixels: Int
        let frames: Int
        let fits: Bool
    }

    @Test(
        "The budget admits what is held at once and refuses what no machine holds",
        arguments: [
            Export(pixels: 2_073_600, frames: 900, fits: true),
            Export(pixels: 2_073_600, frames: 54_000, fits: false),
            Export(pixels: 8_294_400, frames: 240, fits: true),
            Export(pixels: 8_294_400, frames: 900, fits: false),
        ]
    )
    func budgetIsTheRightSize(export: Export) {
        let held = export.pixels * export.frames
        #expect((held <= RenderVideoCommand.Limits.pixels) == export.fits)
    }

    @Test("A video too large to hold at once can still be written")
    func streamsPastTheBudget() async throws {
        let written = try await RenderVideoCommand(pixelBudget: 1).write(
            input(source(4)), options: try options(["dir"]), to: nil)
        #expect(written.frameCount == 4)
    }

    @Test("A GIF too large to hold at once is refused with a reason")
    func refusesAnImpossibleGIF() async throws {
        await #expect(throws: CommandError.self) {
            try await RenderVideoCommand(pixelBudget: 1).write(
                self.input(self.source(4)),
                options: try self.options(["dir"]),
                to: nil,
                gif: URL(fileURLWithPath: "/dev/null")
            )
        }
    }
}
