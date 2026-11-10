import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("The front editor")
struct TheFrontEditorTests {

    private static func scene(_ width: Double = 200) -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: width, height: 120),
            background: ImageRef(contentHash: "picture", pixelWidth: 400, pixelHeight: 240),
            annotations: [],
            style: .standard
        )
    }

    private static func app() -> AppState {
        AppState(library: Library(), permission: .granted)
    }

    private static func editing() -> AppState {
        var state = app().handle(.capture).state
            .handle(.captured(scene(), at: Timestamp.seconds(1))).state
        let id = DocumentID(1)
        state = state.handle(.frontEditorIs(id)).state
        state = state.handle(.edit(id, .toolSelected(.annotate))).state
        state = state.handle(.edit(id, .pointerDown(ScenePoint(x: 60, y: 40), []))).state
        state = state.handle(.edit(id, .pointerUp(ScenePoint(x: 60, y: 40), []))).state
        return state
    }

    @Test("With nothing open there is nothing to undo")
    func nothingOpen() {
        let state = Self.app()
        #expect(!state.canUndo)
        #expect(!state.canRedo)
    }

    @Test("A fresh capture has nothing to undo")
    func freshCapture() {
        let state = Self.app().handle(.capture).state
            .handle(.captured(Self.scene(), at: Timestamp.seconds(1))).state
            .handle(.frontEditorIs(DocumentID(1))).state
        #expect(!state.canUndo)
        #expect(!state.canRedo)
    }

    @Test("Drawing something makes it undoable")
    func afterDrawing() throws {
        let state = Self.editing()
        #expect(try #require(state.frontDocument).scene.annotations.count == 1)
        #expect(state.canUndo)
        #expect(!state.canRedo)
    }

    @Test("Undoing takes it back, and makes it redoable")
    func undoing() throws {
        let state = Self.editing().handle(.undo).state
        #expect(try #require(state.frontDocument).scene.annotations.isEmpty)
        #expect(!state.canUndo)
        #expect(state.canRedo)
    }

    @Test("Redoing puts it back")
    func redoing() throws {
        let state = Self.editing().handle(.undo).state.handle(.redo).state
        #expect(try #require(state.frontDocument).scene.annotations.count == 1)
        #expect(state.canUndo)
    }

    @Test("Undoing asks for the editor to be redrawn")
    func undoRedraws() {
        #expect(Self.editing().handle(.undo).effects == [.redrawEditor(DocumentID(1))])
    }

    @Test("Undoing with nothing to undo does nothing and says nothing")
    func undoingNothing() {
        let outcome = Self.app().handle(.undo)
        #expect(outcome.effects.isEmpty)
        #expect(outcome.state == Self.app())
    }

    @Test("An undo goes to the window in front, not to the newest")
    func theFrontOne() throws {
        var state = Self.editing()
        state =
            state.handle(.capture).state
            .handle(.captured(Self.scene(300), at: Timestamp.seconds(2))).state
            .handle(.frontEditorIs(DocumentID(2))).state
        #expect(!state.canUndo)

        state = state.handle(.frontEditorIs(DocumentID(1))).state
        #expect(state.canUndo)
        #expect(state.handle(.undo).effects == [.redrawEditor(DocumentID(1))])
    }

    @Test("With no window in front there is nothing to act on")
    func nothingInFront() {
        let state = Self.app().handle(.capture).state
            .handle(.captured(Self.scene(), at: Timestamp.seconds(1))).state
        #expect(state.frontDocument == nil)
        #expect(!state.canUndo)
    }

    @Test("Closing the front window leaves nothing in front")
    func closingTheFrontOne() {
        let state = Self.editing().handle(.close(DocumentID(1))).state
        #expect(state.frontDocument == nil)
        #expect(!state.canUndo)
    }

    @Test("A window that was never opened cannot be in front")
    func unknownWindow() {
        let state = Self.app().handle(.frontEditorIs(DocumentID(9))).state
        #expect(state.frontDocument == nil)
    }

    @Test("What gets saved is the document in front")
    func saving() {
        #expect(Self.editing().handle(.saveFront).effects == [.savePicture(DocumentID(1))])
    }

    @Test("With nothing in front there is nothing to save")
    func savingNothing() {
        #expect(Self.app().handle(.saveFront).effects.isEmpty)
    }

    @Test("What can be saved is what is in front")
    func canSave() {
        #expect(!Self.app().canSave)
        #expect(Self.editing().canSave)
    }
}
