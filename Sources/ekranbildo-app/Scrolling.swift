import AppKit
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoStitch

@MainActor
final class ScrollSessionRunner {
    private let capturer = ScreenCaptureKitCapturer()
    private let display: DisplayGeometry
    private let region: ScreenRect
    private var session = ScrollSession()
    private var timer: Timer?

    var saw: (@MainActor (Int, ScrollAdvice) -> Void)?
    var failed: (@MainActor (String) -> Void)?

    init(display: DisplayGeometry, region: ScreenRect) {
        self.display = display
        self.region = region
    }

    func begin() {
        timer = Timer.scheduledTimer(
            withTimeInterval: Pace.between,
            repeats: true,
            block: { [weak self] _ in
                Task { @MainActor in await self?.takeOne() }
            }
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var frames: [ImageBuffer] { session.framesToJoin }

    func joined() throws -> StitchResult {
        try session.finish()
    }

    private func takeOne() async {
        do {
            let capture = try await capturer.capture(.region(display, region))
            session = session.offered(capture.image)
            saw?(session.coveredRows, session.advice)
        } catch {
            failed?("\(error)")
            stop()
        }
    }

    private enum Pace {
        static let between = 0.2
    }
}
