import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Hiding what should not have been in the picture")
struct HidingSecretsTests {

    private static func scene() -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            background: ImageRef(contentHash: "picture", pixelWidth: 400, pixelHeight: 300),
            annotations: [],
            style: .standard
        )
    }

    private static func app(_ change: (inout Settings) -> Void = { _ in }) -> AppState {
        var settings = Settings()
        change(&settings)
        return AppState(library: Library(), permission: .granted, settings: settings)
    }

    private static func captured(
        _ change: (inout Settings) -> Void = { _ in }
    ) -> (state: AppState, effects: [AppEffect]) {
        let outcome = app(change).handle(.capture).state
            .handle(.captured(scene(), at: Timestamp.seconds(1)))
        return (outcome.state, outcome.effects)
    }

    private static let secret = Mask(
        rect: SceneRect(x: 40, y: 60, width: 120, height: 14), style: .pixelate)

    @Test("A capture is looked over for things that should not be shown")
    func looksByDefault() {
        #expect(
            Self.captured().effects.contains { effect in
                if case .lookForSecrets = effect { true } else { false }
            })
    }

    @Test("Somebody who turned it off is not looked over")
    func canBeTurnedOff() {
        let effects = Self.captured { $0.hidesSecretsAutomatically = false }.effects
        #expect(!effects.contains { if case .lookForSecrets = $0 { true } else { false } })
    }

    @Test("What was found is hidden")
    func foundIsHidden() throws {
        let state = Self.captured().state
        let after = state.handle(.foundSecrets(DocumentID(1), [Self.secret])).state
        let document = try #require(after.openDocuments.first)
        #expect(document.scene.masks == [Self.secret])
    }

    @Test("Hiding what was found can be taken back on its own")
    func undoable() throws {
        var state = Self.captured().state
        state = state.handle(.frontEditorIs(DocumentID(1))).state
        state = state.handle(.foundSecrets(DocumentID(1), [Self.secret])).state
        #expect(state.canUndo)

        let back = state.handle(.undo).state
        #expect(try #require(back.openDocuments.first).scene.masks.isEmpty)
        #expect(try #require(back.openDocuments.first).scene.background != nil)
    }

    @Test("Finding nothing changes nothing")
    func foundNothing() throws {
        let state = Self.captured().state
        let after = state.handle(.foundSecrets(DocumentID(1), []))
        #expect(after.effects.isEmpty)
        #expect(try #require(after.state.openDocuments.first).scene.masks.isEmpty)
    }

    @Test("Something found for a document that has gone changes nothing")
    func documentGone() {
        let state = Self.captured().state
        #expect(state.handle(.foundSecrets(DocumentID(9), [Self.secret])).effects.isEmpty)
    }

    @Test("What was found is drawn, so somebody can see what was hidden")
    func redrawn() {
        let state = Self.captured().state
        #expect(
            state.handle(.foundSecrets(DocumentID(1), [Self.secret])).effects
                == [.redrawEditor(DocumentID(1))])
    }

    @Test("With the editor turned off nothing is looked for")
    func noEditor() {
        let effects = Self.captured { $0.opensEditorAfterCapture = false }.effects
        #expect(!effects.contains { if case .lookForSecrets = $0 { true } else { false } })
    }
}
