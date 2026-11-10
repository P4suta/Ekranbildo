import EkranbildoContracts
import EkranbildoCore
import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell

extension AppState {
    public var frontDocument: OpenDocument? {
        guard let front else { return nil }
        return openDocuments.first { $0.id == front }
    }

    public var canUndo: Bool { frontDocument?.document.canUndo ?? false }
    public var canRedo: Bool { frontDocument?.document.canRedo ?? false }
    public var canSave: Bool { frontDocument != nil }

    func frontEditorIs(_ id: DocumentID?) -> Outcome {
        var next = self
        next.front = id.flatMap { wanted in
            openDocuments.contains { $0.id == wanted } ? wanted : nil
        }
        return Outcome(state: next, effects: [])
    }

    func foundSecrets(_ id: DocumentID, _ masks: [Mask]) -> Outcome {
        guard !masks.isEmpty,
            let index = openDocuments.firstIndex(where: { $0.id == id })
        else { return Outcome(state: self, effects: []) }

        var next = self
        var open = next.openDocuments[index]
        open.document.checkpoint()
        open.document.apply(masks.map { EditorCommand.hide($0) })
        open.editor = EditorState(scene: open.document.scene)
        next.openDocuments[index] = open
        return Outcome(state: next, effects: [.redrawEditor(id)])
    }

    func goingBack(_ step: (inout Document) -> Void) -> Outcome {
        guard let front, let index = openDocuments.firstIndex(where: { $0.id == front })
        else { return Outcome(state: self, effects: []) }

        var next = self
        var open = next.openDocuments[index]
        let before = open.document.scene
        step(&open.document)
        guard open.document.scene != before else { return Outcome(state: self, effects: []) }

        open.editor = EditorState(scene: open.document.scene)
        next.openDocuments[index] = open
        return Outcome(state: next, effects: [.redrawEditor(front)])
    }

    func openFromLibrary(_ capture: CaptureID) -> Outcome {
        guard let entry = library.entry(capture) else {
            return Outcome(state: self, effects: [])
        }
        var next = self
        let id = DocumentID(next.nextDocument)
        next.nextDocument += 1
        next.openDocuments.append(
            OpenDocument(
                id: id,
                document: Document(
                    scene: Scene(
                        canvas: SceneRect(
                            x: 0,
                            y: 0,
                            width: entry.canvas.width,
                            height: entry.canvas.height
                        ),
                        background: entry.image,
                        annotations: [],
                        style: .standard
                    ),
                    measurer: TabulatedTextMeasurer.uniform()
                )
            )
        )
        return Outcome(state: next, effects: [.openEditor(id)])
    }

    func changed(to updated: Settings) -> Outcome {
        var next = self
        next.settings = updated
        guard updated.libraryLimit != library.limit else {
            return Outcome(state: next, effects: [])
        }
        var resized = Library(entries: [], limit: updated.libraryLimit)
        var dropped: [LibraryEntry] = []
        for entry in library.entries.reversed() {
            dropped += resized.add(entry)
        }
        next.library = resized
        return Outcome(state: next, effects: next.releasing(dropped.map(\.image)))
    }

    func releasing(_ pictures: [ImageRef]) -> [AppEffect] {
        guard !pictures.isEmpty else { return [] }
        let wanted = Set(
            library.entries.map(\.image) + openDocuments.compactMap(\.scene.background))
        let orphaned = pictures.filter { !wanted.contains($0) }
        guard !orphaned.isEmpty else { return [] }
        return [.forget(orphaned)]
    }

    func dismiss() -> Outcome {
        var next = self
        next.screen = .idle
        next.scroll = nil
        next.recording = nil
        return Outcome(state: next, effects: [.dismissOverlay])
    }

    func close(_ id: DocumentID) -> Outcome {
        guard openDocuments.contains(where: { $0.id == id }) else {
            return Outcome(state: self, effects: [])
        }
        var next = self
        next.openDocuments.removeAll { $0.id == id }
        if next.front == id { next.front = nil }
        return Outcome(state: next, effects: [.closeEditor(id)])
    }
}
