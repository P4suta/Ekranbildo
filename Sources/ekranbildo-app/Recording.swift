import AVFoundation
import AppKit
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoRecord
import ScreenCaptureKit

@MainActor
final class RecordingRunner {
    private let capturer = ScreenCaptureKitCapturer()
    private let display: DisplayGeometry
    private let region: ScreenRect
    private var source: StreamFrameSource?
    private var frames: [ImageBuffer] = []
    private var dropped = 0
    private var reading: Task<Void, Never>?
    private var watcher: KeyWatcher?
    private var pointer: [CursorSample] = []

    var went: (@MainActor (Double, Int) -> Void)?
    var failed: (@MainActor (String) -> Void)?

    init(display: DisplayGeometry, region: ScreenRect) {
        self.display = display
        self.region = region
    }

    var seconds: Double {
        Double(frames.count) / Double(ScreenCaptureKitCapturer.Recording.framesPerSecond)
    }
    var taken: [ImageBuffer] { frames }
    var typed: [Keystroke] { watcher?.keystrokes ?? [] }
    var pointed: [CursorSample] { pointer }
    var geometry: CaptureGeometry { CaptureGeometry(display: display, regionInScreen: region.raw) }
    var lost: Int { dropped }

    func watchTheKeyboard(from began: Timestamp, clock: any Clocking) -> KeyWatcher.Watching {
        let watching = KeyWatcher(began: began, clock: clock)
        switch watching.start() {
        case .watching:
            watcher = watching
            return .watching
        case .refused:
            return .refused
        }
    }

    func begin() async {
        do {
            let made = try await capturer.frameSource(for: .region(display, region))
            source = made
            reading = Task { [weak self] in await self?.read(from: made) }
        } catch {
            failed?("\(error)")
        }
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        reading?.cancel()
        reading = nil
        source?.stop()
        source = nil
    }

    static func whereThePointerIs(at moment: Double) -> CursorSample {
        let onScreen = NSEvent.mouseLocation
        let flipped = (NSScreen.screens.first?.frame.maxY ?? 0) - onScreen.y
        return CursorSample(
            at: .seconds(moment),
            position: ScreenPoint(x: Double(onScreen.x), y: Double(flipped)),
            pressed: NSEvent.pressedMouseButtons != 0
        )
    }

    private func read(from source: StreamFrameSource) async {
        for await delivery in source.deliveries() {
            switch delivery {
            case .frame(let picture, _):
                frames.append(picture)
                pointer.append(Self.whereThePointerIs(at: seconds))
            case .dropped(let count, _):
                dropped += count
            case .interrupted(let error):
                failed?("\(error)")
                return
            case .cursor, .event:
                break
            }
            went?(seconds, dropped)
        }
    }
}
