import EkranbildoContracts
@testable import EkranbildoShell
import EkranbildoTestKit
import Testing

@Suite("Onboarding")
struct OnboardingTests {

    private func step(_ permission: CapturePermission, hasCaptured: Bool = false) -> OnboardingStep {
        OnboardingStep(permission: permission, hasCapturedAnything: hasCaptured)
    }

    @Test("A fresh install is asked to allow screen recording")
    func fresh() {
        #expect(step(.notDetermined).stage == .askForPermission)
    }

    @Test("A refusal is asked to turn it on in settings")
    func refused() {
        #expect(step(.denied).stage == .openSettings)
    }

    @Test("Permission granted while running asks for a restart")
    func pendingRestart() {
        #expect(step(.grantedPendingRestart).stage == .restart)
    }

    @Test("Permission in effect but nothing captured yet is invited to try")
    func readyToTry() {
        #expect(step(.granted).stage == .tryIt)
    }

    @Test("Permission in effect and something captured is finished")
    func done() {
        #expect(step(.granted, hasCaptured: true).stage == .done)
    }

    @Test("Every stage has one thing to do")
    func everyStageHasAnInstruction() {
        for permission in [
            CapturePermission.notDetermined, .denied, .grantedPendingRestart, .granted,
        ] {
            let step = step(permission)
            #expect(!step.title.isEmpty, "\(permission) has no title")
            #expect(!step.instruction.isEmpty, "\(permission) has nothing to do")
        }
    }

    @Test("The restart step says to restart and not to visit settings")
    func restartSaysRestart() {
        let instruction = step(.grantedPendingRestart).instruction.lowercased()
        #expect(instruction.contains("again"))
        #expect(!instruction.contains("settings"))
    }

    @Test("The settings step says where to look")
    func settingsSaysWhere() {
        let instruction = step(.denied).instruction
        #expect(instruction.contains("Privacy"))
        #expect(instruction.contains("Screen Recording"))
    }

    @Test("The finished step has nothing to do")
    func finishedHasNothingToDo() {
        #expect(step(.granted, hasCaptured: true).instruction.isEmpty)
        #expect(step(.granted, hasCaptured: true).isComplete)
    }

    @Test("Every unfinished step says it is unfinished")
    func unfinished() {
        for permission in [CapturePermission.notDetermined, .denied, .grantedPendingRestart] {
            #expect(!step(permission).isComplete)
        }
    }

    @Test("The stages are in the order somebody meets them")
    func order() {
        let stages: [OnboardingStage] = [.askForPermission, .openSettings, .restart, .tryIt, .done]
        #expect(stages == OnboardingStage.allCases)
    }

    @Test("Refusing and changing your mind does not start over")
    func refusingDoesNotRestart() {
        #expect(step(.denied).stage != .askForPermission)
    }

    @Test("Working out where somebody is is reproducible")
    func reproducible() {
        #expect(isReproducible { step(.grantedPendingRestart).stage })
    }
}
