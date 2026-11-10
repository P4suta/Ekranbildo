@testable import EkranbildoCLI
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoRecord
import EkranbildoTestKit
import Foundation
import Testing

@Suite("Record command")
struct RecordCommandTests {

    private static let geometry = CaptureGeometry(
        fullDisplay: DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 200, height: 150),
            backingScale: 2
        )
    )

    private func options(_ arguments: [String]) throws -> RecordOptions {
        try RecordOptions(arguments: arguments)
    }

    private func recorded(_ source: FakeFrameSource) throws -> RecordedRun {
        try SourceRecorder(geometry: Self.geometry).record(from: source)
    }

    private func recorded(cursor: [CursorSample]) -> Recording {
        Recording(
            geometry: Self.geometry,
            frames: [],
            cursor: cursor,
            events: [],
            droppedFrameCount: 0
        )
    }

    private func recorded(frames moments: [Double]) throws -> Recording {
        var recorder = Recorder(geometry: Self.geometry)
        try recorder.start()
        for (index, second) in moments.enumerated() {
            try recorder.append(picture(index), at: .seconds(second))
        }
        return try recorder.finish()
    }

    private func picture(_ index: Int) -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 20, height: 15)
        screen.paint(
            SceneRect(x: 0, y: 0, width: 20, height: 15),
            color: .opaque(red: UInt8(index * 10), green: 40, blue: 60)
        )
        return screen.image
    }

    private func describe(_ recording: Recording) throws -> RecordOutputs {
        try RecordCommand()
            .describe(recording, assets: InMemoryAssetStore(), options: options([]))
    }

    @Test("A length and a display can be asked for")
    func parsing() throws {
        let parsed = try options(["--seconds", "12.5", "--display", "3", "--scale", "2"])
        #expect(parsed.seconds == 12.5)
        #expect(parsed.displayID == 3)
        #expect(parsed.scale == 2)
    }

    @Test("Sensible defaults when nothing is said")
    func defaults() throws {
        let parsed = try options([])
        #expect(parsed.seconds == RecordOptions.Defaults.seconds)
        #expect(parsed.displayID == nil)
        #expect(parsed.scale == 1)
    }

    @Test("A length that is not a length is refused", arguments: ["0", "-1", "soon", "nan"])
    func malformedLength(text: String) {
        #expect(throws: CommandError.self) { try self.options(["--seconds", text]) }
    }

    @Test("A stray argument is refused")
    func strayArgument() {
        #expect(throws: CommandError.self) { try self.options(["now"]) }
    }

    @Test("The summary says what was recorded")
    func summary() throws {
        let run = try recorded(.steady(frameCount: 10))
        let outputs = try RecordCommand().describe(run.recording, assets: run.assets, options: options([]))

        #expect(outputs.summary.contains("frames 10"))
        #expect(outputs.summary.contains("distinct pictures 10"))
        #expect(outputs.summary.contains("dropped 0"))
        #expect(outputs.summary.contains("size 400x300px"))
    }

    @Test("A still screen is reported as many frames and one picture")
    func stillScreen() throws {
        let still = FakeFrameSource(
            (0..<20).map { .frame(FakeFrameSource.frame(1), at: .seconds(Double($0) / 30)) }
        )
        let run = try recorded(still)
        let outputs = try RecordCommand().describe(run.recording, assets: run.assets, options: options([]))
        #expect(outputs.summary.contains("frames 20"))
        #expect(outputs.summary.contains("distinct pictures 1"))
    }

    @Test("Events are named rather than counted")
    func namesEvents() throws {
        let run = try recorded(
            FakeFrameSource([
                .frame(FakeFrameSource.frame(0), at: .seconds(0)),
                .dropped(9, at: .seconds(0.5)),
                .event(RecordedEvent(at: .seconds(0.8), kind: .click)),
            ])
        )
        let outputs = try RecordCommand().describe(run.recording, assets: run.assets, options: options([]))
        #expect(outputs.summary.contains("dropped 9"))
        #expect(outputs.summary.contains("framesDropped"))
        #expect(outputs.summary.contains("click"))
    }

    @Test("Frame names sort into the order they were recorded")
    func frameNames() throws {
        let run = try recorded(.steady(frameCount: 12))
        let outputs = try RecordCommand().describe(
            run.recording, assets: run.assets, options: options(["--frames", "out"]))

        let names = outputs.frames.map(\.name)
        #expect(names.count == 12)
        #expect(names == names.sorted())
        #expect(names.first == "frame-000000.png")
    }

    @Test("No frames are written when none were asked for")
    func onlyWhatWasAsked() throws {
        let run = try recorded(.steady(frameCount: 4))
        #expect(
            try RecordCommand().describe(run.recording, assets: run.assets, options: options([]))
                .frames.isEmpty
        )
    }

    @Test("The frames written are the frames recorded")
    func framesAreTheFrames() throws {
        let run = try recorded(.steady(frameCount: 3))
        let outputs = try RecordCommand().describe(
            run.recording, assets: run.assets, options: options(["--frames", "out"]))
        for (index, frame) in outputs.frames.enumerated() {
            let written = FakeFrameSource.frame(index)
            #expect(try ImageCodec.decode(frame.png, into: written.colorSpace).image == written)
        }
    }

    @Test("Describing a recording is reproducible")
    func reproducible() throws {
        let run = try recorded(.steady(frameCount: 6))
        let parsed = try options([])
        #expect(
            isReproducible {
                try? RecordCommand().describe(run.recording, assets: run.assets, options: parsed).summary
            }
        )
    }

    @Test("The subcommand is reachable from the argument list")
    func dispatch() throws {
        guard case .record = try Command(arguments: ["record"]) else {
            Issue.record("expected the record subcommand")
            return
        }
    }

    @Test("Where the pointer went is written down")
    func writesTheCursor() throws {
        let recording = recorded(
            cursor: [
                CursorSample(at: .zero, position: ScreenPoint(x: 10, y: 20), pressed: false),
                CursorSample(at: .seconds(1), position: ScreenPoint(x: 30, y: 40), pressed: true),
            ])
        let outputs = try describe(recording)

        let written = try JSONDecoder().decode(
            RecordedCursor.self, from: Data(outputs.cursor.utf8))
        #expect(written.samples == recording.cursor)
    }

    @Test("The pointer is written with the screen it was on")
    func writesTheGeometry() throws {
        let recording = recorded(
            cursor: [CursorSample(at: .zero, position: ScreenPoint(x: 10, y: 20), pressed: false)])
        let written = try JSONDecoder().decode(
            RecordedCursor.self, from: Data(try describe(recording).cursor.utf8))
        #expect(written.geometry == recording.geometry)
    }

    @Test("A recording with no pointer still writes a file rather than nothing")
    func writesAnEmptyCursor() throws {
        let written = try JSONDecoder().decode(
            RecordedCursor.self, from: Data(try describe(recorded(cursor: [])).cursor.utf8))
        #expect(written.samples.isEmpty)
    }

    @Test("What is written is the same every time")
    func cursorIsReproducible() {
        let recording = recorded(
            cursor: [
                CursorSample(at: .zero, position: ScreenPoint(x: 10, y: 20), pressed: false),
                CursorSample(at: .seconds(1), position: ScreenPoint(x: 30, y: 40), pressed: true),
            ])
        #expect(isReproducible { try? describe(recording).cursor })
    }

    @Test("Each line says when the frame was shown, not which frame it was")
    func timingsSayMoments() throws {
        let outputs = try describe(try recorded(frames: [0, 2.5, 7.25]))

        let lines = outputs.timings.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0].hasSuffix(" 0.000"))
        #expect(lines[1].hasSuffix(" 2.500"))
        #expect(lines[2].hasSuffix(" 7.250"))
    }

    @Test("Each line names the picture it is about")
    func timingsNameFrames() throws {
        let line = try describe(try recorded(frames: [1.5])).timings
        #expect(line.hasPrefix(RecordCommand.frameName(0)))
    }
}
