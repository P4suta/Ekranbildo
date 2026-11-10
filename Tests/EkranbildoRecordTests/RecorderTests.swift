import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRecord
import EkranbildoTestKit
import Testing

@Suite("Recorder")
struct RecorderTests {

    private static let geometry = CaptureGeometry(
        fullDisplay: DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 400, height: 300),
            backingScale: 2
        )
    )

    private func frame(_ index: Int) -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 20, height: 15)
        screen.paint(
            SceneRect(x: 0, y: 0, width: 20, height: 15),
            color: .opaque(red: UInt8(index * 10), green: 40, blue: 60)
        )
        return screen.image
    }

    private func started() -> Recorder {
        var recorder = Recorder(geometry: Self.geometry)
        try? recorder.start()
        return recorder
    }

    @Test("Frames are kept in the order they were presented")
    func recordsFrames() throws {
        var recorder = started()
        for index in 0..<4 {
            try recorder.append(frame(index), at: .seconds(Double(index) / 10))
        }
        let recording = try recorder.finish()

        #expect(recording.frames.count == 4)
        #expect(recording.frames.map(\.sequence) == [0, 1, 2, 3])
        #expect(recording.duration == .seconds(0.3))
    }

    @Test("The duration is the span, not the last moment")
    func durationIsASpan() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(2))
        try recorder.append(frame(1), at: .seconds(3.5))
        #expect(try recorder.finish().duration == .seconds(1.5))
    }

    @Test("An unchanged frame is stored once")
    func deduplicates() throws {
        var recorder = started()
        try recorder.append(frame(1), at: .seconds(0))
        try recorder.append(frame(1), at: .seconds(0.1))
        try recorder.append(frame(2), at: .seconds(0.2))
        let recording = try recorder.finish()

        #expect(recording.frames.count == 3, "every frame is still a moment in time")
        #expect(recording.frames[0].image == recording.frames[1].image)
        #expect(recorder.assets.count == 2, "but only two pictures were kept")
    }

    @Test("The pixels come back through the store")
    func framesAreRetrievable() throws {
        var recorder = started()
        try recorder.append(frame(3), at: .seconds(0))
        let recording = try recorder.finish()
        #expect(recorder.assets.image(for: recording.frames[0].image) == frame(3))
    }

    @Test("Cursor samples and events are kept as they arrive")
    func recordsCursorAndEvents() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        recorder.append(
            CursorSample(at: .seconds(0.05), position: ScreenPoint(x: 10, y: 20), pressed: false))
        recorder.append(
            CursorSample(at: .seconds(0.1), position: ScreenPoint(x: 12, y: 22), pressed: true))
        recorder.append(RecordedEvent(at: .seconds(0.1), kind: .click))
        let recording = try recorder.finish()

        #expect(recording.cursor.count == 2)
        #expect(recording.cursor[1].pressed)
        #expect(recording.events.map(\.kind) == [.click])
    }

    @Test("Frames that arrive out of order are put back in order")
    func reordersFrames() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        try recorder.append(frame(2), at: .seconds(0.2))
        try recorder.append(frame(1), at: .seconds(0.1))
        let recording = try recorder.finish()

        #expect(recording.frames.map(\.presentedAt) == [.seconds(0), .seconds(0.1), .seconds(0.2)])
        #expect(recording.frames.map(\.sequence) == [0, 2, 1])
    }

    @Test("Two frames at the same moment become one")
    func duplicateTimestamps() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0.5))
        try recorder.append(frame(1), at: .seconds(0.5))
        let recording = try recorder.finish()

        #expect(recording.frames.count == 1)
        #expect(recorder.assets.image(for: recording.frames[0].image) == frame(1))
    }

    @Test("A gap in the frames is recorded rather than filled")
    func recordsGaps() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        recorder.noteDroppedFrames(12)
        try recorder.append(frame(1), at: .seconds(3))
        let recording = try recorder.finish()

        #expect(recording.droppedFrameCount == 12)
        #expect(recording.events.contains { $0.kind == .framesDropped })
        #expect(recording.frames.count == 2, "nothing was invented to fill the gap")
    }

    @Test("Time before the recording started is refused")
    func negativeTime() {
        var recorder = started()
        #expect(throws: RecordingError.self) {
            try recorder.append(self.frame(0), at: Timestamp(nanoseconds: -1))
        }
    }

    @Test("Appending before starting is refused")
    func appendBeforeStart() {
        var recorder = Recorder(geometry: Self.geometry)
        #expect(throws: RecordingError.self) {
            try recorder.append(self.frame(0), at: .seconds(0))
        }
    }

    @Test("Starting twice is refused")
    func startTwice() {
        var recorder = started()
        #expect(throws: RecordingError.self) { try recorder.start() }
    }

    @Test("Finishing without starting is refused")
    func finishWithoutStarting() {
        var recorder = Recorder(geometry: Self.geometry)
        #expect(throws: RecordingError.self) { try recorder.finish() }
    }

    @Test("A recording cut short by a full disk keeps what it had")
    func salvagesAfterDiskFull() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        try recorder.append(frame(1), at: .seconds(0.1))
        recorder.interrupt(
            RecordingError(code: RecordingError.diskFull, detail: "no room left"))

        let salvaged = try recorder.finish()
        #expect(salvaged.frames.count == 2)
        #expect(salvaged.events.contains { $0.kind == .resumed } == false)
    }

    @Test("An interrupted recorder takes no more frames")
    func interruptedStopsRecording() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        recorder.interrupt(
            RecordingError(code: RecordingError.interrupted, detail: "the system stopped it"))
        #expect(throws: RecordingError.self) {
            try recorder.append(self.frame(1), at: .seconds(0.1))
        }
    }

    @Test("A recording with no frames is empty rather than broken")
    func emptyRecording() throws {
        var recorder = started()
        let recording = try recorder.finish()
        #expect(recording.isEmpty)
        #expect(recording.duration == .zero)
    }

    @Test("A recording survives a round trip")
    func roundTrip() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .seconds(0))
        recorder.append(RecordedEvent(at: .seconds(0.1), kind: .click))
        #expect(try isJSONRoundTrippable(try recorder.finish()))
    }

    @Test("Recording the same thing twice gives the same recording")
    func reproducible() {
        #expect(
            isReproducible {
                var recorder = self.started()
                for index in 0..<3 {
                    try? recorder.append(self.frame(index), at: .seconds(Double(index) / 10))
                }
                return try? recorder.finish()
            }
        )
    }

    @Test("A recording lasts as long as it was recording, not as long as its frames")
    func durationCoversTheWholeRecording() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .zero)
        try recorder.append(frame(1), at: .seconds(0.2))
        for tenth in 0...40 {
            recorder.append(
                CursorSample(
                    at: .seconds(Double(tenth) / 10),
                    position: ScreenPoint(x: Double(tenth), y: 0),
                    pressed: false
                ))
        }

        #expect(try recorder.finish().duration == .seconds(4))
    }

    @Test("A recording of nothing has no length")
    func noFramesNoDuration() throws {
        var recorder = started()
        recorder.append(
            CursorSample(at: .seconds(9), position: ScreenPoint(x: 0, y: 0), pressed: false))
        #expect(try recorder.finish().duration == .zero)
    }

    @Test("A recording whose frames outlast everything else is as long as its frames")
    func framesDecideWhenTheyAreLast() throws {
        var recorder = started()
        try recorder.append(frame(0), at: .zero)
        try recorder.append(frame(1), at: .seconds(6))
        recorder.append(
            CursorSample(at: .seconds(1), position: ScreenPoint(x: 0, y: 0), pressed: false))
        #expect(try recorder.finish().duration == .seconds(6))
    }
}
