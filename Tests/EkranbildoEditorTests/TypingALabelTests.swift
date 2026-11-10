import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Typing a label")
struct TypingALabelTests {

    private let interactor = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())

    private static let canvas = SceneRect(x: 0, y: 0, width: 600, height: 400)

    private func empty() -> EditorState {
        var state = EditorState(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: [],
                style: .standard
            )
        )
        state.tool = .annotate
        return state
    }

    private func after(_ events: [InputEvent], from start: EditorState) -> EditorInteractor.Outcome {
        var document = Document(
            scene: start.scene, measurer: TabulatedTextMeasurer.uniform())
        var state = start
        var commands: [EditorCommand] = []
        var effects: [EditorEffect] = []
        for event in events {
            let outcome = interactor.handle(event, in: state)
            state = outcome.state
            commands += outcome.commands
            effects += outcome.effects
            if outcome.effects.contains(.checkpoint) { document.checkpoint() }
            document.apply(outcome.commands)
            state.scene = document.scene
        }
        return EditorInteractor.Outcome(state: state, commands: commands, effects: effects)
    }

    private func pointingAtSomething() -> [InputEvent] {
        [
            .pointerDown(ScenePoint(x: 200, y: 150), []),
            .pointerUp(ScenePoint(x: 200, y: 150), []),
        ]
    }

    @Test("Pointing at something asks for what to call it")
    func placingStartsTyping() {
        let outcome = after(pointingAtSomething(), from: empty())
        #expect(outcome.state.typing != nil)
    }

    @Test("What is typed becomes the label")
    func typingSetsTheLabel() {
        let outcome = after(
            pointingAtSomething() + [.typed("The"), .typed(" button")], from: empty())
        #expect(outcome.state.typing?.text == "The button")
        #expect(outcome.commands.contains(.setLabel(AnnotationID(1), "The button")))
    }

    @Test("Nothing typed yet is nothing rather than the word Label")
    func startsEmpty() {
        #expect(after(pointingAtSomething(), from: empty()).state.typing?.text.isEmpty == true)
    }

    @Test("Deleting takes back what was typed, one character at a time")
    func deleting() {
        let outcome = after(
            pointingAtSomething() + [.typed("abc"), .key(.delete, []), .key(.delete, [])],
            from: empty()
        )
        #expect(outcome.state.typing?.text == "a")
    }

    @Test("Deleting with nothing typed does not remove the annotation")
    func deletingNothing() {
        let outcome = after(
            pointingAtSomething() + [.key(.delete, []), .key(.delete, [])], from: empty())
        #expect(outcome.state.typing != nil)
        #expect(!outcome.commands.contains { if case .removeAnnotations = $0 { true } else { false } })
    }

    @Test("Enter finishes, and the words stay")
    func enterCommits() {
        let outcome = after(
            pointingAtSomething() + [.typed("Save"), .key(.enter, [])], from: empty())
        #expect(outcome.state.typing == nil)
        #expect(outcome.commands.last == .solve)
        #expect(outcome.commands.contains(.setLabel(AnnotationID(1), "Save")))
    }

    @Test("Escape takes the whole annotation back, because an unnamed one says nothing")
    func escapeRemoves() {
        let outcome = after(
            pointingAtSomething() + [.typed("Sto"), .key(.escape, [])], from: empty())
        #expect(outcome.state.typing == nil)
        #expect(outcome.commands.contains(.removeAnnotations([AnnotationID(1)])))
    }

    private func labelMiddle(_ state: EditorState) -> ScenePoint {
        let rect = HitTester(scene: state.scene, measurer: TabulatedTextMeasurer.uniform())
            .labelRect(of: AnnotationID(1))
        guard let rect else { return ScenePoint(x: 0, y: 0) }
        return ScenePoint(x: rect.raw.center.x, y: rect.raw.center.y)
    }

    private func named(_ words: String) -> EditorState {
        var state = after(
            pointingAtSomething() + [.typed(words), .key(.enter, [])], from: empty()
        ).state
        state.tool = .select
        return state
    }

    @Test("Escape after it was already named keeps it and keeps the name")
    func escapeAfterNaming() {
        let state = named("Save")
        let label = labelMiddle(state)
        let outcome = after(
            [
                .pointerDown(label, []),
                .pointerUp(label, []),
                .typed("x"),
                .key(.escape, []),
            ],
            from: state
        )
        #expect(
            !outcome.commands.contains { if case .removeAnnotations = $0 { true } else { false } })
        #expect(outcome.commands.contains(.setLabel(AnnotationID(1), "Save")))
    }

    @Test("Clicking a label that is already there starts typing it again")
    func clickingToEdit() {
        let state = named("Save")
        let label = labelMiddle(state)
        let outcome = after([.pointerDown(label, []), .pointerUp(label, [])], from: state)
        #expect(outcome.state.typing?.annotation == AnnotationID(1))
        #expect(outcome.state.typing?.text == "Save")
    }

    @Test("Clicking what is being pointed at selects it rather than renaming it")
    func clickingTheTarget() {
        let state = named("Save")
        let outcome = after(
            [
                .pointerDown(ScenePoint(x: 200, y: 150), []),
                .pointerUp(ScenePoint(x: 200, y: 150), []),
            ],
            from: state
        )
        #expect(outcome.state.typing == nil)
        #expect(outcome.state.selection == [AnnotationID(1)])
    }

    @Test("Typing with nothing being named changes nothing")
    func typingWithNothingToName() {
        var state = empty()
        state.tool = .select
        let outcome = after([.typed("hello")], from: state)
        #expect(outcome.commands.isEmpty)
        #expect(outcome.state.typing == nil)
    }

    @Test("Picking another tool finishes the naming rather than losing it")
    func toolEndsTyping() {
        let outcome = after(
            pointingAtSomething() + [.typed("Save"), .toolSelected(.select)], from: empty())
        #expect(outcome.state.typing == nil)
        #expect(outcome.commands.contains(.setLabel(AnnotationID(1), "Save")))
        #expect(!outcome.commands.contains(.removeAnnotations([AnnotationID(1)])))
    }

    @Test("Arrow keys nudge the words along rather than the annotation")
    func arrowsDoNotNudgeWhileTyping() {
        let outcome = after(
            pointingAtSomething() + [.typed("Save"), .key(.arrowLeft, [])], from: empty())
        #expect(!outcome.commands.contains { if case .moveTarget = $0 { true } else { false } })
    }

    @Test("A newline typed rather than pressed does not end up in the words")
    func newlineIsNotTyped() {
        let outcome = after(
            pointingAtSomething() + [.typed("a\nb")], from: empty())
        #expect(outcome.state.typing?.text == "ab")
    }
}
