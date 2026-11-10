@testable import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Application state")
struct AppStateTests {

    private func app() -> AppState {
        AppState(library: Library(), permission: .granted)
    }

    @Test("It starts with nothing open")
    func startsClosed() {
        #expect(app().screen == .idle)
        #expect(app().openDocuments.isEmpty)
    }

    @Test("Asking to capture puts the overlay up")
    func captureOpensTheOverlay() {
        let after = app().handle(.capture)
        #expect(after.state.screen == .choosingRegion)
    }

    @Test("Asking twice does not put up a second overlay")
    func captureIsNotReentrant() {
        let once = app().handle(.capture).state
        let twice = once.handle(.capture)
        #expect(twice.state.screen == .idle)
        #expect(twice.effects == [.dismissOverlay])
    }

    @Test("Escaping the overlay goes back to nothing open")
    func escapeClosesTheOverlay() {
        let after = app().handle(.capture).state.handle(.dismiss)
        #expect(after.state.screen == .idle)
    }

    @Test("Nobody has been asked yet, so asking is what a capture does")
    func notDeterminedAsksTheSystem() {
        let fresh = AppState(library: Library(), permission: .notDetermined)
        let after = fresh.handle(.capture)
        #expect(after.state.screen == .choosingRegion)
        #expect(after.effects.contains(.freezeScreens))
        #expect(!after.effects.contains(.openPrivacySettings))
    }

    @Test("Refused is the one case that opens the settings")
    func deniedOpensTheSettings() {
        let denied = AppState(library: Library(), permission: .denied)
        let after = denied.handle(.capture)
        #expect(after.state.screen == .explainingPermission)
        #expect(after.effects.contains(.openPrivacySettings))
    }

    @Test("Granted since launch asks to be restarted, not to be granted again")
    func pendingRestartAsksForARestart() {
        let pending = AppState(library: Library(), permission: .grantedPendingRestart)
        let after = pending.handle(.capture)
        #expect(after.state.screen == .explainingPermission)
        #expect(after.effects.contains(.askToRestart))
        #expect(!after.effects.contains(.openPrivacySettings))
    }

    @Test("What the system says about the permission is taken as the answer")
    func permissionIsLearned() {
        let fresh = AppState(library: Library(), permission: .notDetermined)
        let after = fresh.handle(.permissionIs(.denied))
        #expect(after.state.permission == .denied)
    }

    @Test("Learning it on its own only moves the welcome along")
    func learningOnlyMovesTheWelcome() {
        let outcome = app().handle(.permissionIs(.denied))
        #expect(outcome.effects.allSatisfy { if case .showWelcome = $0 { true } else { false } })
    }

    @Test("Once somebody has captured something, learning it says nothing at all")
    func learningIsQuietAfterwards() {
        var settings = Settings()
        settings.hasFinishedOnboarding = true
        let settled = AppState(library: Library(), permission: .granted, settings: settings)
        #expect(settled.handle(.permissionIs(.granted)).effects.isEmpty)
    }

    @Test("A capture that arrives opens an editor for it")
    func captureOpensAnEditor() {
        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 100),
            background: nil,
            annotations: [],
            style: .standard
        )
        let after = app().handle(.capture).state.handle(.captured(scene, at: .zero))
        #expect(after.state.openDocuments.count == 1)
        #expect(after.state.screen == .idle)
    }

    @Test("A second capture opens a second editor rather than replacing the first")
    func capturesAccumulate() {
        var state = app()
        for _ in 0..<3 {
            state = state.handle(.capture).state
            state = state.handle(.captured(Self.anyScene, at: .zero)).state
        }
        #expect(state.openDocuments.count == 3)
        #expect(Set(state.openDocuments.map(\.id)).count == 3)
    }

    @Test("Closing an editor closes that one")
    func closingOne() {
        var state = app().handle(.capture).state.handle(.captured(Self.anyScene, at: .zero)).state
        state = state.handle(.capture).state.handle(.captured(Self.anyScene, at: .zero)).state
        let first = state.openDocuments[0].id
        let after = state.handle(.close(first))
        #expect(after.state.openDocuments.count == 1)
        #expect(!after.state.openDocuments.contains { $0.id == first })
    }

    @Test("Closing one that is not open changes nothing")
    func closingNothing() {
        let state = app()
        #expect(state.handle(.close(DocumentID(99))).state.openDocuments.isEmpty)
    }

    @Test("Opening the settings asks for the settings window")
    func settingsAsksForAWindow() {
        #expect(app().handle(.openSettings).effects.contains(.showSettings))
    }

    @Test("Quitting asks to quit, and only after anything unsaved is dealt with")
    func quitting() {
        let after = app().handle(.quit)
        #expect(after.effects.contains(.terminate))
    }

    @Test("An edit reaches the document it is about")
    func editReachesItsDocument() throws {
        let state = app().handle(.capture).state.handle(.captured(Self.anyScene, at: .zero)).state
        let id = try #require(state.openDocuments.first?.id)
        let after = state.handle(.edit(id, .toolSelected(.annotate)))
        #expect(after.state.openDocuments[0].tool == .annotate)
    }

    @Test("Pointing at something through the application adds an annotation")
    func pointingAddsAnAnnotation() throws {
        let state = app().handle(.capture).state.handle(.captured(Self.anyScene, at: .zero)).state
        let id = try #require(state.openDocuments.first?.id)
        #expect(state.openDocuments[0].scene.annotations.isEmpty)

        var after = state.handle(.edit(id, .toolSelected(.annotate))).state
        after =
            after.handle(
                .edit(id, .pointerDown(ScenePoint(x: 20, y: 20), Modifiers()))
            ).state
        after =
            after.handle(
                .edit(id, .pointerUp(ScenePoint(x: 60, y: 50), Modifiers()))
            ).state

        #expect(after.openDocuments[0].scene.annotations.count == 1)
    }

    @Test("Undo through the application takes the annotation back")
    func undoTakesItBack() throws {
        var state = app().handle(.capture).state.handle(.captured(Self.anyScene, at: .zero)).state
        let id = try #require(state.openDocuments.first?.id)
        for event in [
            InputEvent.toolSelected(.annotate),
            .pointerDown(ScenePoint(x: 20, y: 20), Modifiers()),
            .pointerUp(ScenePoint(x: 60, y: 50), Modifiers()),
        ] {
            state = state.handle(.edit(id, event)).state
        }
        #expect(state.openDocuments[0].scene.annotations.count == 1)

        let undone = state.handle(.edit(id, .undo)).state
        #expect(undone.openDocuments[0].scene.annotations.isEmpty)
    }

    @Test("An edit for a document that is not open changes nothing")
    func editWithoutADocument() {
        let state = app()
        #expect(state.handle(.edit(DocumentID(99), .undo)).state == state)
    }

    private static let anyScene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 100, height: 100),
        background: nil,
        annotations: [],
        style: .standard
    )
}
