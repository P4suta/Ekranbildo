import EkranbildoApp
import EkranbildoContracts
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Recording")
struct RecordingTests {

    private static let region = ScreenRect(x: 100, y: 80, width: 640, height: 480)

    private static func app() -> AppState {
        AppState(library: Library(), permission: .granted)
    }

    private static func recording() -> AppState {
        app().handle(.record).state.handle(.choseRecordingRegion(Self.region)).state
    }

    @Test("Asking to record puts the overlay up to choose a region with")
    func startsByChoosing() {
        let outcome = Self.app().handle(.record)
        #expect(outcome.effects == [.freezeScreens])
        #expect(outcome.state.screen == .choosingRegion)
    }

    @Test("Choosing a region starts recording it")
    func choosingStarts() {
        let outcome = Self.app().handle(.record).state.handle(.choseRecordingRegion(Self.region))
        #expect(outcome.effects == [.dismissOverlay, .startRecording(Self.region)])
        #expect(outcome.state.screen == .recording)
        #expect(outcome.state.isRecording)
    }

    @Test("While recording, how it is going is known")
    func progress() {
        let state = Self.recording()
            .handle(.recorded(seconds: 12.5, dropped: 3)).state
        #expect(state.recording?.seconds == 12.5)
        #expect(state.recording?.dropped == 3)
    }

    @Test("Stopping asks for what was recorded to be written down")
    func stopping() {
        let outcome = Self.recording().handle(.stopRecording)
        #expect(outcome.effects.contains { if case .finishRecording = $0 { true } else { false } })
        #expect(outcome.state.screen == .idle)
        #expect(!outcome.state.isRecording)
    }

    @Test("Asking to record while recording stops it rather than starting a second")
    func notReentrant() {
        let outcome = Self.recording().handle(.record)
        #expect(outcome.effects.contains { if case .finishRecording = $0 { true } else { false } })
        #expect(!outcome.state.isRecording)
    }

    @Test("Changing your mind stops it too")
    func dismissed() {
        let outcome = Self.recording().handle(.dismiss)
        #expect(!outcome.state.isRecording)
        #expect(outcome.state.screen == .idle)
    }

    @Test("What was recorded goes into the history")
    func remembered() throws {
        var state = Self.recording().handle(.stopRecording).state
        let written = ImageRef(contentHash: "a-recording", pixelWidth: 640, pixelHeight: 480)
        state =
            state.handle(
                .recordingWritten(written, seconds: 12.5, at: Timestamp.seconds(9))
            ).state
        let entry = try #require(state.library.newest)
        #expect(entry.image == written)
        #expect(entry.source == .recording)
    }

    @Test("A recording that wrote nothing is not remembered")
    func nothingWritten() {
        let state = Self.recording().handle(.stopRecording).state
        #expect(state.library.entries.isEmpty)
    }

    @Test("Being told about a recording nobody started changes nothing")
    func notRecording() {
        let outcome = Self.app().handle(.recorded(seconds: 1, dropped: 0))
        #expect(outcome.effects.isEmpty)
        #expect(outcome.state.recording == nil)
    }
}
