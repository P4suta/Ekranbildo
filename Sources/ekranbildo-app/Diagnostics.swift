import AppKit
import EkranbildoApp

extension Shell {
    #if DEBUG
        func captureTheScreenWithoutBeingAsked() {
            guard ProcessInfo.processInfo.environment[Self.captureOnLaunch] != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.apply(.capture) }
        }

        static let captureOnLaunch = "EKRANBILDO_CAPTURE_ON_LAUNCH"
    #endif
}
