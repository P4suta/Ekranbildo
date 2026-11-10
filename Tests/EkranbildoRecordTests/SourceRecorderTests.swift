import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRecord
import EkranbildoTestKit
import Testing

@Suite("Source recorder")
struct SourceRecorderTests {

    private static let geometry = CaptureGeometry(
        fullDisplay: DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 200, height: 150),
            backingScale: 2
        )
    )

    private func recorded(_ source: FakeFrameSource) throws -> Recording {
        try SourceRecorder(geometry: Self.geometry).record(from: source).recording
    }

    @Test("A steady recording keeps every frame")
    func steady() throws {
        let recording = try recorded(.steady(frameCount: 12))
        #expect(recording.frames.count == 12)
        #expect(recording.frames.first?.presentedAt == .zero)
        #expect(recording.geometry.display.backingScale == 2)
    }

    @Test("Frames out of order are put back in order")
    func reorders() throws {
        let recording = try recorded(
            FakeFrameSource([
                .frame(FakeFrameSource.frame(0), at: .seconds(0)),
                .frame(FakeFrameSource.frame(2), at: .seconds(0.2)),
                .frame(FakeFrameSource.frame(1), at: .seconds(0.1)),
            ])
        )
        #expect(recording.frames.map(\.presentedAt) == [.seconds(0), .seconds(0.1), .seconds(0.2)])
    }

    @Test("Dropped frames are recorded, not filled in")
    func dropped() throws {
        let recording = try recorded(
            FakeFrameSource([
                .frame(FakeFrameSource.frame(0), at: .seconds(0)),
                .dropped(40, at: .seconds(0.5)),
                .frame(FakeFrameSource.frame(1), at: .seconds(1.8)),
            ])
        )
        #expect(recording.droppedFrameCount == 40)
        #expect(recording.frames.count == 2)
        #expect(recording.events.contains { $0.kind == .framesDropped })
    }

    @Test("A recording cut short keeps everything up to the cut")
    func salvages() throws {
        let recording = try recorded(
            FakeFrameSource([
                .frame(FakeFrameSource.frame(0), at: .seconds(0)),
                .frame(FakeFrameSource.frame(1), at: .seconds(0.1)),
                .interrupted(
                    RecordingError(code: RecordingError.diskFull, detail: "no room left")),
                .frame(FakeFrameSource.frame(2), at: .seconds(0.2)),
            ])
        )
        #expect(recording.frames.count == 2, "what was captured before the cut survives")
    }

    @Test("Cursor and clicks travel with the frames")
    func cursorAndClicks() throws {
        let recording = try recorded(
            FakeFrameSource([
                .frame(FakeFrameSource.frame(0), at: .seconds(0)),
                .cursor(
                    CursorSample(
                        at: .seconds(0.05), position: ScreenPoint(x: 40, y: 60), pressed: false)),
                .cursor(
                    CursorSample(
                        at: .seconds(0.1), position: ScreenPoint(x: 44, y: 66), pressed: true)),
                .event(RecordedEvent(at: .seconds(0.1), kind: .click)),
            ])
        )
        #expect(recording.cursor.count == 2)
        #expect(recording.events.map(\.kind) == [.click])
    }

    @Test("A source that delivered nothing gives an empty recording")
    func nothingDelivered() throws {
        let recording = try recorded(FakeFrameSource([]))
        #expect(recording.isEmpty)
        #expect(recording.duration == .zero)
    }

    @Test("The pictures come back through the store")
    func assetsKept() throws {
        let run = try SourceRecorder(geometry: Self.geometry)
            .record(from: FakeFrameSource.steady(frameCount: 3))
        for (index, frame) in run.recording.frames.enumerated() {
            #expect(run.assets.image(for: frame.image) == FakeFrameSource.frame(index))
        }
    }

    @Test("A still screen is stored once")
    func stillScreen() throws {
        let still = FakeFrameSource(
            (0..<20).map { .frame(FakeFrameSource.frame(7), at: .seconds(Double($0) / 30)) }
        )
        let run = try SourceRecorder(geometry: Self.geometry).record(from: still)
        #expect(run.recording.frames.count == 20)
        #expect(run.assets.count == 1)
    }

    @Test("Recording the same deliveries twice gives the same run.recording")
    func reproducible() {
        let source = FakeFrameSource.steady(frameCount: 8)
        #expect(
            isReproducible { try? SourceRecorder(geometry: Self.geometry).record(from: source).recording }
        )
    }
}
