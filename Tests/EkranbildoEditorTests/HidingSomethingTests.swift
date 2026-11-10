import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Hiding something")
struct HidingSomethingTests {

    private let interactor = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())
    private static let canvas = SceneRect(x: 0, y: 0, width: 600, height: 400)

    private func after(_ events: [InputEvent], from start: EditorState)
        -> EditorInteractor.Outcome
    {
        var document = Document(scene: start.scene, measurer: TabulatedTextMeasurer.uniform())
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

    private func hiding() -> EditorState {
        var state = EditorState(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: [],
                style: .standard
            )
        )
        state.tool = .redact
        return state
    }

    private func sweep(_ rect: Rect, in state: EditorState) -> EditorInteractor.Outcome {
        after(
            [
                .pointerDown(ScenePoint(x: rect.minX, y: rect.minY), []),
                .pointerMoved(ScenePoint(x: rect.maxX, y: rect.maxY), []),
                .pointerUp(ScenePoint(x: rect.maxX, y: rect.maxY), []),
            ],
            from: state
        )
    }

    @Test("Sweeping out a region with the hiding tool hides it")
    func sweepingHides() {
        let swept = Rect(x: 100, y: 80, width: 200, height: 60)
        let after = sweep(swept, in: hiding())
        #expect(after.state.scene.masks.count == 1)
        #expect(after.state.scene.masks[0].rect == SceneRect(swept))
    }

    @Test("What it hides with cannot be undone")
    func irreversibleByDefault() {
        let after = sweep(Rect(x: 100, y: 80, width: 200, height: 60), in: hiding())
        #expect(after.state.scene.masks[0].style.isIrreversible)
    }

    @Test("Hiding something is a step that can be taken back")
    func undoable() {
        let after = sweep(Rect(x: 100, y: 80, width: 200, height: 60), in: hiding())
        #expect(after.effects.contains(.checkpoint))
    }

    @Test("Hiding several things hides all of them")
    func several() {
        var state = hiding()
        state = sweep(Rect(x: 20, y: 20, width: 80, height: 40), in: state).state
        state.tool = .redact
        state = sweep(Rect(x: 300, y: 200, width: 80, height: 40), in: state).state
        #expect(state.scene.masks.count == 2)
    }

    @Test("A click that sweeps nothing hides nothing")
    func aClickHidesNothing() {
        let after = sweep(Rect(x: 100, y: 80, width: 0, height: 0), in: hiding())
        #expect(after.state.scene.masks.isEmpty)
    }

    @Test("Hiding does not add an annotation")
    func noAnnotation() {
        let after = sweep(Rect(x: 100, y: 80, width: 200, height: 60), in: hiding())
        #expect(after.state.scene.annotations.isEmpty)
        #expect(after.state.typing == nil)
    }

    @Test("A region swept backwards is the same region")
    func backwards() {
        let after = after(
            [
                .pointerDown(ScenePoint(x: 300, y: 140), []),
                .pointerMoved(ScenePoint(x: 100, y: 80), []),
                .pointerUp(ScenePoint(x: 100, y: 80), []),
            ],
            from: hiding()
        )
        #expect(
            after.state.scene.masks[0].rect
                == SceneRect(Rect(x: 100, y: 80, width: 200, height: 60)))
    }

    @Test("Undo takes back what was hidden")
    func undone() {
        var document = Document(
            scene: hiding().scene, measurer: TabulatedTextMeasurer.uniform())
        document.checkpoint()
        document.apply([
            .hide(Mask(rect: SceneRect(x: 10, y: 10, width: 50, height: 20), style: .pixelate))
        ])
        #expect(document.scene.masks.count == 1)
        document.undo()
        #expect(document.scene.masks.isEmpty)
    }
}
