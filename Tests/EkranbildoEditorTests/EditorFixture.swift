import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

enum EditorFixture {
    static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    static let interactor = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())

    static func scene(_ count: Int = 1) -> Scene {
        Scene(
            canvas: canvas,
            background: nil,
            annotations: (0..<count).map { index in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: SceneRect(
                        x: 60 + Double(index) * 120,
                        y: 140,
                        width: 40,
                        height: 20
                    ),
                    label: "Label \(index + 1)",
                    placement: Placement(direction: .n, leaderLength: 50)
                )
            },
            style: .standard
        )
    }

    static func state(_ count: Int = 1, tool: ToolID = .select) -> EditorState {
        EditorState(scene: scene(count), tool: tool)
    }

    struct Replay {
        let state: EditorState
        let commands: [EditorCommand]
        let effects: [EditorEffect]
    }

    static func after(_ events: [InputEvent], from start: EditorState) -> Replay {
        var state = start
        var commands: [EditorCommand] = []
        var effects: [EditorEffect] = []
        for event in events {
            let outcome = interactor.handle(event, in: state)
            state = outcome.state
            commands += outcome.commands
            effects += outcome.effects
        }
        return Replay(state: state, commands: commands, effects: effects)
    }

    static func targetCentre(_ state: EditorState, _ index: Int = 0) -> ScenePoint {
        let rect = state.scene.annotations[index].target
        return ScenePoint(x: rect.raw.center.x, y: rect.raw.center.y)
    }
}
