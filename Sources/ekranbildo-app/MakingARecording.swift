import AppKit
import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoEncode
import EkranbildoFixtures
import EkranbildoRecord
import EkranbildoRenderCoreGraphics
import EkranbildoShell
import EkranbildoTimeline
import EkranbildoViews
import UniformTypeIdentifiers

extension Shell {
    func startRecording(_ region: ScreenRect) {
        guard let display = Self.display(under: region) else {
            say("no screen holds that region, so there is nothing to record")
            apply(.dismiss)
            return
        }
        let running = RecordingRunner(display: display, region: region)
        recorder = running
        running.went = { [weak self] seconds, dropped in
            self?.apply(.recorded(seconds: seconds, dropped: dropped))
            self?.recordingPanel?.show(seconds: seconds, dropped: dropped)
        }
        running.failed = { [weak self] said in
            self?.say("the recording stopped: \(said)")
            self?.apply(.stopRecording)
        }
        if settings.showsKeystrokes {
            watchTheKeyboard(with: running)
        }
        recordingPanel = RecordingPanelController(
            stop: { [weak self] in self?.apply(.stopRecording) })
        recordingPanel?.showWindow(nil)
        bringForward()
        Task { await running.begin() }
    }

    func finishRecording(_ polish: Polish) {
        defer { endRecording() }
        guard let running = recorder else { return }
        running.stop()
        let frames = running.taken
        guard !frames.isEmpty else {
            say("the recording has no frames in it")
            return
        }
        let kept =
            polish.wants(.cutDeadTime)
            ? RecordingPolish.withoutStillness(frames, framesPerSecond: Frames.perSecond)
            : frames
        say(
            "recorded \(frames.count) frame(s), \(running.lost) dropped, "
                + "\(frames.count - kept.count) cut for being still"
        )
        let shown = Self.composer(
            over: kept,
            typed: polish.wants(.showKeystrokes) ? running.typed : [],
            pointed: running.pointed,
            geometry: running.geometry,
            polish: polish
        ).compose(kept)
        writeDown(shown, seconds: Double(kept.count) / Double(Frames.perSecond))
    }

    private func writeDown(_ frames: [ImageBuffer], seconds: Double) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "Recording.mp4"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let first = frames[0]
        let timed = frames.enumerated().map { moment, picture in
            TimedFrame(
                image: picture,
                at: .seconds(Double(moment) / Double(Frames.perSecond))
            )
        }
        Task { [weak self] in
            do {
                let settings = EncodeSettings(
                    width: first.width,
                    height: first.height,
                    framesPerSecond: Frames.perSecond
                )
                _ = try await VideoWriter(settings: settings)
                    .write(frames: timed, to: destination)
                self?.say("wrote the recording to \(destination.path)")
                self?.apply(
                    .recordingWritten(
                        self?.assets.put(first)
                            ?? ImageRef(contentHash: "", pixelWidth: 0, pixelHeight: 0),
                        seconds: seconds,
                        at: Self.now()
                    ))
            } catch {
                self?.present(error)
            }
        }
    }

    static func composer(
        over frames: [ImageBuffer],
        typed: [Keystroke],
        pointed: [CursorSample],
        geometry: CaptureGeometry,
        polish: Polish
    ) -> RecordingComposer {
        return RecordingComposer(
            timeline: Timeline(
                canvas: geometry.sceneBounds,
                style: .standard,
                background: nil,
                duration: .seconds(Double(frames.count) / Double(Frames.perSecond)),
                tracks: [],
                cursor: pointed.isEmpty
                    ? nil
                    : CursorTrack(
                        recorded: pointed,
                        geometry: geometry,
                        polish: CursorPolish(
                            smooths: polish.wants(.smoothThePointer),
                            showsClicks: polish.wants(.showClicks)
                        )
                    ),
                keys: typed.isEmpty ? nil : KeystrokeTrack(recorded: typed)
            ),
            measurer: TabulatedTextMeasurer.uniform(),
            framesPerSecond: Frames.perSecond
        )
    }

    private func watchTheKeyboard(with running: RecordingRunner) {
        switch running.watchTheKeyboard(from: Self.now(), clock: WallClock()) {
        case .watching:
            return
        case .refused:
            break
        }

        switch askForTheKeyboard() {
        case .granted:
            switch running.watchTheKeyboard(from: Self.now(), clock: WallClock()) {
            case .watching: return
            case .refused: say("the keyboard is allowed but the tap would not start")
            }
        case .refused, .notDetermined:
            say("the keys will not be on this recording")
        }
    }

    private func askForTheKeyboard() -> KeyWatcher.Access {
        let alert = NSAlert()
        alert.messageText = "Ekranbildo cannot see which keys you press"
        alert.informativeText =
            "To put the keys on the recording, macOS has to let Ekranbildo watch the keyboard. "
            + "Choose Ask macOS, then turn Ekranbildo on under Input Monitoring. The recording "
            + "carries on either way, without the keys."
        alert.addButton(withTitle: "Ask macOS")
        alert.addButton(withTitle: "Carry on without them")
        guard alert.runModal() == .alertFirstButtonReturn else { return .refused }
        return KeyWatcher.ask()
    }

    private func endRecording() {
        recorder?.stop()
        recorder = nil
        recordingPanel?.close()
        recordingPanel = nil
    }

    private enum Frames {
        static let perSecond = 30
    }
}
