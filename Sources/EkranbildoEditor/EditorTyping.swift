import EkranbildoContracts
import EkranbildoCore

extension EditorInteractor {

    func typed(_ text: String, _ state: EditorState) -> Outcome {
        guard var typing = state.typing else {
            if let tool = Self.tool(for: text) {
                return toolSelected(tool, state)
            }
            guard text == Self.numbering, !state.selection.isEmpty else {
                return Outcome(state: state, commands: [], effects: [])
            }
            return Outcome(
                state: state,
                commands: state.selection.map { EditorCommand.number($0) },
                effects: [.checkpoint]
            )
        }
        typing.text += text.filter { !$0.isNewline }
        var next = state
        next.typing = typing
        return Outcome(
            state: next,
            commands: [.setLabel(typing.annotation, typing.text)],
            effects: []
        )
    }

    func backspaced(_ typing: Typing, _ state: EditorState) -> Outcome {
        guard !typing.text.isEmpty else {
            return Outcome(state: state, commands: [], effects: [])
        }
        var shorter = typing
        shorter.text.removeLast()
        var next = state
        next.typing = shorter
        return Outcome(
            state: next,
            commands: [.setLabel(shorter.annotation, shorter.text)],
            effects: []
        )
    }

    func finishedTyping(_ typing: Typing, _ state: EditorState) -> Outcome {
        var next = state
        next.typing = nil
        return Outcome(
            state: next,
            commands: [.setLabel(typing.annotation, typing.text), .solve],
            effects: [.checkpoint]
        )
    }

    func abandonedTyping(_ typing: Typing, _ state: EditorState) -> Outcome {
        var next = state
        next.typing = nil
        guard let before = typing.wasNamed else {
            return Outcome(
                state: next,
                commands: [.removeAnnotations([typing.annotation]), .solve],
                effects: [.checkpoint]
            )
        }
        return Outcome(
            state: next,
            commands: [.setLabel(typing.annotation, before), .solve],
            effects: []
        )
    }

    func naming(_ id: AnnotationID, in state: EditorState) -> EditorState {
        var next = state
        let existing = state.scene.annotations.first { $0.id == id }?.label
        next.typing = Typing(annotation: id, text: existing ?? "", wasNamed: existing)
        return next
    }

    func namingSomethingNew(_ id: AnnotationID, in state: EditorState) -> EditorState {
        var next = state
        next.typing = Typing(annotation: id, text: "", wasNamed: nil)
        return next
    }
}
