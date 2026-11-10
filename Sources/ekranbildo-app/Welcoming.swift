import AppKit
import EkranbildoApp
import EkranbildoShell
import EkranbildoViews

extension Shell {
    func showWelcome(_ step: OnboardingStep) {
        let controller =
            welcomeWindow
            ?? WelcomeWindowController(step: step) { [weak self] in
                self?.actOnWelcome()
            }
        welcomeWindow = controller
        controller.show(step)
        bringForward()
    }

    func hideWelcome() {
        welcomeWindow?.close()
    }

    private func actOnWelcome() {
        switch state.onboarding.stage {
        case .askForPermission, .tryIt: apply(.capture)
        case .openSettings: apply(.capture)
        case .restart: NSApp.terminate(nil)
        case .done: hideWelcome()
        }
    }
}
