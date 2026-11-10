import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoLibrary

public struct RecordingProgress: Hashable, Sendable {
    public let region: ScreenRect
    public var seconds: Double
    public var dropped: Int

    public init(region: ScreenRect, seconds: Double = 0, dropped: Int = 0) {
        self.region = region
        self.seconds = seconds
        self.dropped = dropped
    }
}

extension AppState {
    public var isRecording: Bool { recording != nil }

    func record() -> Outcome {
        guard !isRecording else { return stopRecording() }
        guard screen == .idle else { return dismiss() }
        var next = self
        next.screen = .choosingRegion
        return Outcome(state: next, effects: [.freezeScreens])
    }

    func choseRecordingRegion(_ region: ScreenRect) -> Outcome {
        guard screen == .choosingRegion else { return Outcome(state: self, effects: []) }
        var next = self
        next.screen = .recording
        next.recording = RecordingProgress(region: region)
        return Outcome(state: next, effects: [.dismissOverlay, .startRecording(region)])
    }

    func recorded(_ seconds: Double, _ dropped: Int) -> Outcome {
        guard var progress = recording else { return Outcome(state: self, effects: []) }
        progress.seconds = seconds
        progress.dropped = dropped
        var next = self
        next.recording = progress
        return Outcome(state: next, effects: [])
    }

    func stopRecording() -> Outcome {
        guard isRecording else { return Outcome(state: self, effects: []) }
        var next = self
        next.screen = .idle
        next.recording = nil
        return Outcome(state: next, effects: [.finishRecording(settings.polish)])
    }

    func recordingWritten(_ picture: ImageRef, _ seconds: Double, at time: Timestamp) -> Outcome {
        var next = self
        let dropped = next.library.add(
            LibraryEntry(
                id: CaptureID(next.nextCapture),
                takenAt: time,
                image: picture,
                canvas: Size(
                    width: Double(picture.pixelWidth), height: Double(picture.pixelHeight)),
                seconds: seconds,
                source: .recording
            )
        )
        next.nextCapture += 1
        return Outcome(state: next, effects: next.releasing(dropped.map(\.image)))
    }
}
