import AppKit
import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoRedaction
import EkranbildoViews
import EkranbildoVision

extension Shell {
    func freezeScreens() {
        let capturing = CaptureSession(assets: assets)
        session = capturing
        capturing.finished = { [weak self] scene, region in
            guard let self else { return }
            self.session = nil
            if self.choosingForARecording {
                self.choosingForARecording = false
                self.apply(region.map { AppCommand.choseRecordingRegion($0) } ?? .dismiss)
                return
            }
            if self.choosingForAScroll {
                self.choosingForAScroll = false
                self.apply(region.map { AppCommand.choseScrollRegion($0) } ?? .dismiss)
                return
            }
            self.apply(scene.map { AppCommand.captured($0, at: Self.now()) } ?? .dismiss)
        }
        Task { await capturing.begin() }
    }

    func dismissOverlay() {
        session?.dismiss()
        session = nil
    }

    func lookForSecrets(_ id: DocumentID, _ picture: ImageRef) {
        guard let pixels = assets.image(for: picture) else { return }
        Task { [weak self] in
            let found = await Self.secrets(in: pixels)
            guard !found.isEmpty else { return }
            self?.say("hid \(found.count) thing(s) that should not have been in the picture")
            self?.apply(.foundSecrets(id, found))
        }
    }

    nonisolated private static func secrets(in picture: ImageBuffer) async -> [Mask] {
        let found = Task.detached(priority: .userInitiated) {
            guard let semantics = try? VisionSemanticProvider().analyse(picture) else {
                return [Mask]()
            }
            return MaskSuggester().masks(in: semantics.elements)
        }
        return await found.value
    }

    func redrawEditor(_ id: DocumentID) {
        guard let document = state.openDocuments.first(where: { $0.id == id }) else { return }
        editors[id]?.scene = document.scene
    }

    func openEditor(_ id: DocumentID) {
        guard let document = state.openDocuments.first(where: { $0.id == id }) else { return }
        let controller = EditorWindowController(
            scene: document.scene, title: "Capture \(id.raw)", assets: assets)
        controller.cameForward = { [weak self] in self?.apply(.frontEditorIs(id)) }
        controller.wentAway = { [weak self] in self?.apply(.close(id)) }
        controller.send = { [weak self, weak controller] event in
            guard let self else { return }
            switch event.handledBy {
            case .history(.back): self.apply(.undo)
            case .history(.forward): self.apply(.redo)
            case .theEditor: self.apply(.edit(id, event))
            }
            guard let open = self.state.openDocuments.first(where: { $0.id == id }) else { return }
            controller?.scene = open.scene
            controller?.tool = open.tool
        }
        editors[id] = controller
        controller.showWindow(nil)
        apply(.frontEditorIs(id))
        bringForward()
    }

    func closeEditor(_ id: DocumentID) {
        editors[id]?.close()
        editors[id] = nil
    }
}
