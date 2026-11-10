import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Dragging a label")
struct DraggingALabelTests {

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

    private func placed() -> EditorState {
        var state = EditorState(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: [],
                style: .standard
            )
        )
        state.tool = .annotate
        state =
            after(
                [
                    .pointerDown(ScenePoint(x: 300, y: 200), []),
                    .pointerUp(ScenePoint(x: 300, y: 200), []),
                    .typed("Save"),
                    .key(.enter, []),
                ],
                from: state
            ).state
        state.tool = .select
        return state
    }

    private func labelMiddle(_ state: EditorState) -> ScenePoint {
        let rect = HitTester(scene: state.scene, measurer: TabulatedTextMeasurer.uniform())
            .labelRect(of: AnnotationID(1))
        guard let rect else { return ScenePoint(x: 0, y: 0) }
        return ScenePoint(x: rect.raw.center.x, y: rect.raw.center.y)
    }

    private func dragged(from: ScenePoint, to: ScenePoint, in state: EditorState)
        -> EditorInteractor.Outcome
    {
        after([.pointerDown(from, []), .pointerMoved(to, []), .pointerUp(to, [])], from: state)
    }

    @Test("Dragging the words moves the words, not what they are about")
    func movesTheLabel() {
        let state = placed()
        let before = state.scene.annotations[0].target
        let outcome = dragged(
            from: labelMiddle(state),
            to: ScenePoint(x: 120, y: 340),
            in: state
        )
        #expect(!outcome.commands.contains { if case .moveTarget = $0 { true } else { false } })
        #expect(outcome.commands.contains { if case .setPlacement = $0 { true } else { false } })
        #expect(outcome.state.scene.annotations[0].target == before)
    }

    @Test("A label dragged somewhere is pinned there")
    func pinned() {
        let state = placed()
        let outcome = dragged(
            from: labelMiddle(state), to: ScenePoint(x: 120, y: 340), in: state)
        #expect(outcome.state.scene.annotations[0].isPinned)
    }

    @Test("It ends up nearer where it was dropped than where it started")
    func endsUpNearTheDrop() throws {
        let state = placed()
        let started = labelMiddle(state)
        let dropped = ScenePoint(x: 120, y: 340)
        let after = dragged(from: started, to: dropped, in: state).state
        let ended = labelMiddle(after)

        func distance(_ one: ScenePoint, _ other: ScenePoint) -> Double {
            Geo.distanceSquared(one.raw, other.raw)
        }
        #expect(distance(ended, dropped) < distance(started, dropped))
    }

    @Test("Dragging what is being pointed at still moves it")
    func draggingTheTarget() {
        let state = placed()
        let outcome = dragged(
            from: ScenePoint(x: 300, y: 200), to: ScenePoint(x: 380, y: 260), in: state)
        #expect(outcome.commands.contains { if case .moveTarget = $0 { true } else { false } })
    }

    @Test("Moving what is pointed at unpins the label")
    func movingUnpins() {
        var state = placed()
        state = dragged(from: labelMiddle(state), to: ScenePoint(x: 120, y: 340), in: state).state
        #expect(state.scene.annotations[0].isPinned)

        let moved = dragged(
            from: ScenePoint(x: 300, y: 200), to: ScenePoint(x: 380, y: 260), in: state)
        #expect(!moved.state.scene.annotations[0].isPinned)
    }

    @Test("A drag too small to mean anything renames rather than moves")
    func tinyDragRenames() {
        let state = placed()
        let middle = labelMiddle(state)
        let outcome = dragged(
            from: middle, to: ScenePoint(x: middle.x + 1, y: middle.y + 1), in: state)
        #expect(outcome.state.typing?.annotation == AnnotationID(1))
        #expect(outcome.commands.isEmpty)
    }
}
