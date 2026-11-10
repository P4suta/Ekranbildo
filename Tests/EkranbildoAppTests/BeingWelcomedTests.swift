import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Being welcomed")
struct BeingWelcomedTests {

    private static func app(
        _ permission: CapturePermission,
        finished: Bool = false
    ) -> AppState {
        var settings = Settings()
        settings.hasFinishedOnboarding = finished
        return AppState(library: Library(), permission: permission, settings: settings)
    }

    private static func scene() -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            background: ImageRef(contentHash: "a", pixelWidth: 10, pixelHeight: 10),
            annotations: [],
            style: .standard
        )
    }

    @Test("A fresh install is welcomed as soon as it knows where it stands")
    func welcomedOnLaunch() {
        let outcome = Self.app(.notDetermined).handle(.permissionIs(.denied))
        #expect(outcome.effects.contains(.showWelcome(outcome.state.onboarding)))
        #expect(outcome.state.onboarding.stage == .openSettings)
    }

    @Test("The welcome follows the permission as it changes")
    func followsPermission() {
        var state = Self.app(.notDetermined)
        state = state.handle(.permissionIs(.denied)).state
        let outcome = state.handle(.permissionIs(.granted))
        #expect(outcome.state.onboarding.stage == .tryIt)
        #expect(outcome.effects.contains(.showWelcome(outcome.state.onboarding)))
    }

    @Test("A permission report that changes nothing does not reopen the welcome")
    func doesNotNag() {
        var state = Self.app(.granted)
        state = state.handle(.permissionIs(.granted)).state
        #expect(state.handle(.permissionIs(.granted)).effects.isEmpty)
    }

    @Test("The first capture finishes the welcome for good")
    func firstCaptureFinishesIt() {
        let state = Self.app(.granted)
        let outcome = state.handle(.captured(Self.scene(), at: .seconds(1)))
        #expect(outcome.state.settings.hasFinishedOnboarding)
        #expect(outcome.state.onboarding.stage == .done)
        #expect(outcome.effects.contains(.hideWelcome))
        #expect(outcome.effects.contains(.rememberSettings))
    }

    @Test("Someone who has already captured is not welcomed again")
    func notWelcomedTwice() {
        let outcome = Self.app(.granted, finished: true).handle(.permissionIs(.granted))
        #expect(!outcome.effects.contains { $0 == .showWelcome(outcome.state.onboarding) })
    }

    @Test("A second capture does not save the settings all over again")
    func savesOnlyOnce() {
        let state = Self.app(.granted, finished: true)
        let outcome = state.handle(.captured(Self.scene(), at: .seconds(1)))
        #expect(!outcome.effects.contains(.rememberSettings))
    }

    @Test("The welcome can be asked for again from the menu")
    func askedForAgain() {
        let outcome = Self.app(.granted, finished: true).handle(.showWelcome)
        #expect(outcome.effects == [.showWelcome(outcome.state.onboarding)])
    }

    @Test("The invitation to try names the shortcut that is actually set")
    func namesTheRealShortcut() {
        let state = Self.app(.granted)
        #expect(
            state.onboarding.instruction.contains(state.settings.captureShortcut.displayed))
    }
}
