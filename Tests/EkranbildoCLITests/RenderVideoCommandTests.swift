@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoTestKit
import EkranbildoTimeline
import Foundation
import Testing

@Suite("Render video")
struct RenderVideoCommandTests {

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

    private func input(
        _ pictures: [ImageBuffer],
        events: [CameraEvent] = [],
        timings: [Timestamp] = [],
        cursor: CursorTrack? = nil
    ) -> RenderVideoInput {
        RenderVideoInput(source: pictures, events: events, timings: timings, cursor: cursor)
    }

    private func events() -> [CameraEvent] {
        [
            CameraEvent(
                at: .seconds(2),
                focus: SceneRect(x: 20, y: 20, width: 20, height: 12)
            )
        ]
    }

    @Test("A directory is required")
    func inputRequired() {
        #expect(throws: CommandError.self) { try self.options([]) }
    }

    @Test("A frame rate that is not one is refused", arguments: ["0", "-5", "fast"])
    func malformedRate(text: String) {
        #expect(throws: CommandError.self) { try self.options(["dir", "--fps", text]) }
    }

    @Test("Nothing to render is reported rather than producing an empty file")
    func nothingToRender() {
        #expect(throws: CommandError.self) {
            try RenderVideoCommand().frames(
                self.input([]), options: try self.options(["dir"]))
        }
    }

    @Test("Every frame given comes out")
    func everyFrame() throws {
        let result = try RenderVideoCommand().frames(
            input(source(30), events: events()), options: try options(["dir"]))
        #expect(result.frames.count == 30)
    }

    @Test("A recording's own timings are used when there are any")
    func usesRecordedTimings() throws {
        let moments = [
            Timestamp.seconds(0), .seconds(0.2), .seconds(4), .seconds(8),
        ]
        let result = try RenderVideoCommand().frames(
            input(source(4), timings: moments), options: try options(["dir"]))
        #expect(result.frames.map(\.at) == moments)
    }

    @Test("Without timings the frames are evenly spaced")
    func evenlySpacedWithoutTimings() throws {
        let result = try RenderVideoCommand().frames(
            input(source(4)), options: try options(["dir", "--fps", "10"]))
        #expect(result.frames.map(\.at.seconds) == [0, 0.1, 0.2, 0.3])
    }

    @Test("Timings that do not match the frames are ignored")
    func mismatchedTimings() throws {
        let result = try RenderVideoCommand().frames(
            input(source(4), timings: [.seconds(0), .seconds(5)]),
            options: try options(["dir", "--fps", "10"])
        )
        #expect(result.frames.map(\.at.seconds) == [0, 0.1, 0.2, 0.3])
    }

    @Test("The camera path comes out with the frames")
    func producesAPath() throws {
        let result = try RenderVideoCommand().frames(
            input(source(90), events: events()), options: try options(["dir"]))
        #expect(result.path.keyframes.count > 2, "the camera never moved")
    }

    @Test("Every frame is the same size")
    func sameSize() throws {
        let result = try RenderVideoCommand().frames(
            input(source(90), events: events()), options: try options(["dir"]))
        for frame in result.frames {
            #expect(frame.image.width == 120)
            #expect(frame.image.height == 80)
        }
    }

    @Test("Rendering is reproducible")
    func reproducible() throws {
        let pictures = source(40)
        let marks = events()
        let parsed = try options(["dir"])
        #expect(
            isReproducible {
                try? RenderVideoCommand()
                    .frames(self.input(pictures, events: marks), options: parsed)
                    .frames.map(\.image.pixels)
            }
        )
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .renderVideo = try Command(arguments: ["render-video", "dir"]) else {
            Issue.record("expected the render-video subcommand")
            return
        }
    }

    private func cursorTrack() -> CursorTrack {
        CursorTrack(
            samples: [
                CursorKeyframe(at: .zero, position: ScenePoint(x: 10, y: 10)),
                CursorKeyframe(at: .seconds(4), position: ScenePoint(x: 100, y: 60)),
            ],
            ripples: [RippleKeyframe(at: .seconds(2), centre: ScenePoint(x: 55, y: 35))]
        )
    }

    @Test("The pointer is drawn into the frames")
    func drawsThePointer() throws {
        let plain = try RenderVideoCommand().frames(
            input(source(4)), options: try options(["dir"]))
        let withCursor = try RenderVideoCommand().frames(
            input(source(4), cursor: cursorTrack()), options: try options(["dir"]))

        #expect(plain.frames.map(\.image) != withCursor.frames.map(\.image))
    }

    @Test("With no pointer recorded the frames are the frames")
    func withoutAPointer() throws {
        let plain = try RenderVideoCommand().frames(
            input(source(3)), options: try options(["dir"]))
        #expect(plain.frames.map(\.image) == source(3))
    }

    @Test("The pointer is drawn where it was at each moment")
    func followsTheMoment() throws {
        let rendered = try RenderVideoCommand().frames(
            input(
                source(4).map { _ in source(1)[0] },
                timings: (0..<4).map { Timestamp.seconds(Double($0)) },
                cursor: cursorTrack()
            ),
            options: try options(["dir"])
        )
        let distinct = Set(rendered.frames.map(\.image))
        #expect(distinct.count == rendered.frames.count)
    }

    @Test("Drawing the pointer is reproducible")
    func reproduciblePointer() throws {
        let pictures = source(4)
        let track = cursorTrack()
        let parsed = try options(["dir"])
        #expect(
            try isReproducible {
                try RenderVideoCommand()
                    .frames(input(pictures, cursor: track), options: parsed)
                    .frames.map(\.image)
            })
    }

    @Test("A recording that went on after its last frame plays for as long as it ran")
    func holdsTheLastFrame() throws {
        let rendered = try RenderVideoCommand().frames(
            input(
                source(3),
                timings: [.zero, .seconds(0.1), .seconds(0.2)],
                cursor: CursorTrack(
                    samples: [
                        CursorKeyframe(at: .zero, position: ScenePoint(x: 0, y: 0)),
                        CursorKeyframe(at: .seconds(2), position: ScenePoint(x: 100, y: 60)),
                    ])
            ),
            options: try options(["dir", "--fps", "10"])
        )

        #expect(rendered.frames.last?.at == .seconds(2))
        #expect(rendered.frames.count == 21)
    }

    @Test("The held frames still follow the pointer")
    func heldFramesFollowThePointer() throws {
        let rendered = try RenderVideoCommand().frames(
            input(
                source(2),
                timings: [.zero, .seconds(0.1)],
                cursor: CursorTrack(
                    samples: [
                        CursorKeyframe(at: .zero, position: ScenePoint(x: 0, y: 0)),
                        CursorKeyframe(at: .seconds(1), position: ScenePoint(x: 110, y: 70)),
                    ])
            ),
            options: try options(["dir", "--fps", "10"])
        )
        let tail = rendered.frames.suffix(from: 2).map(\.image)
        #expect(Set(tail).count == tail.count)
    }

    @Test("A recording that stopped with its last frame is not extended")
    func noHoldWhenNothingFollowed() throws {
        let rendered = try RenderVideoCommand().frames(
            input(source(3), timings: [.zero, .seconds(0.1), .seconds(0.2)]),
            options: try options(["dir", "--fps", "10"])
        )
        #expect(rendered.frames.count == 3)
    }

    @Test("A tail too long to hold is refused with a reason")
    func refusesAnAbsurdTail() {
        #expect(throws: CommandError.self) {
            try RenderVideoCommand(heldFrameLimit: 4).frames(
                self.input(
                    self.source(1),
                    timings: [.zero],
                    cursor: CursorTrack(
                        samples: [
                            CursorKeyframe(at: .zero, position: ScenePoint(x: 0, y: 0)),
                            CursorKeyframe(at: .seconds(5), position: ScenePoint(x: 1, y: 1)),
                        ])
                ),
                options: try self.options(["dir", "--fps", "10"])
            )
        }
    }

    @Test("A tail within the limit is held")
    func holdsATailWithinTheLimit() throws {
        let rendered = try RenderVideoCommand(heldFrameLimit: 40).frames(
            input(
                source(1),
                timings: [.zero],
                cursor: CursorTrack(
                    samples: [
                        CursorKeyframe(at: .zero, position: ScenePoint(x: 0, y: 0)),
                        CursorKeyframe(at: .seconds(2), position: ScenePoint(x: 1, y: 1)),
                    ])
            ),
            options: try options(["dir", "--fps", "10"])
        )
        #expect(rendered.frames.count == 21)
    }
}
