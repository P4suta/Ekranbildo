import EkranbildoContracts
import EkranbildoGeometry

extension EditorInteractor {

    func key(_ key: KeyCode, _ modifiers: Modifiers, _ state: EditorState) -> Outcome {
        if let typing = state.typing {
            return whileNaming(key, typing, state)
        }

        var next = state
        switch key {
        case .escape:
            next.drag = .idle
            next.selection = []
            return Outcome(state: next, commands: [], effects: [])

        case .delete:
            guard !state.selection.isEmpty else {
                return Outcome(state: state, commands: [], effects: [])
            }
            next.selection = []
            return Outcome(
                state: next,
                commands: [.removeAnnotations(state.selection), .solve],
                effects: [.checkpoint]
            )

        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight:
            guard !state.selection.isEmpty else {
                return Outcome(state: state, commands: [], effects: [])
            }
            let step = modifiers.contains(.shift) ? coarseNudge : nudge
            let delta = Self.direction(of: key, step: step)
            let commands =
                state.selection.compactMap { id -> EditorCommand? in
                    guard let annotation = state.scene.annotations.first(where: { $0.id == id })
                    else { return nil }
                    return .moveTarget(
                        id,
                        to: SceneRect(
                            x: annotation.target.minX + delta.x,
                            y: annotation.target.minY + delta.y,
                            width: annotation.target.raw.width,
                            height: annotation.target.raw.height
                        )
                    )
                } + [.solve]
            return Outcome(state: next, commands: commands, effects: [.checkpoint])

        case .enter, .tab:
            return Outcome(state: state, commands: [], effects: [])
        }
    }

    func whileNaming(_ key: KeyCode, _ typing: Typing, _ state: EditorState) -> Outcome {
        switch key {
        case .escape: abandonedTyping(typing, state)
        case .enter, .tab: finishedTyping(typing, state)
        case .delete: backspaced(typing, state)
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight:
            Outcome(state: state, commands: [], effects: [])
        }
    }

    static let numbering = "n"

    static func tool(for typed: String) -> ToolID? {
        switch typed {
        case "1": .select
        case "2": .annotate
        case "3": .redact
        default: nil
        }
    }
}
