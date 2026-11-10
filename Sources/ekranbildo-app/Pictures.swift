import AppKit
import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoExport
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoRender
import EkranbildoRenderCoreGraphics
import EkranbildoViews
import UniformTypeIdentifiers

extension Shell {
    @objc func saveFrontDocument() {
        apply(.saveFront)
    }

    func savePicture(_ id: DocumentID) {
        guard let document = state.openDocuments.first(where: { $0.id == id }) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Capture \(id.raw).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let drawing = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
                .build(document.scene)
            let rendered = try CoreGraphicsRenderer(assets: assets)
                .render(drawing, scale: settings.exportScale)
            let bytes = try Exporter().export(rendered.bitmap.imageBuffer, as: .png)
            try Data(bytes).write(to: destination)
        } catch {
            present(error)
        }
    }

    func copyToClipboard(_ scene: Scene) {
        do {
            let bytes = try Clipboard.png(
                of: scene, assets: assets, scale: settings.exportScale)
            guard Clipboard.put(bytes, on: .general) else {
                say("the clipboard refused \(bytes.count) bytes")
                return
            }
            say("copied \(bytes.count) bytes to the clipboard")
        } catch {
            say("could not copy that picture: \(error)")
        }
    }

    func say(_ what: String) {
        FileHandle.standardError.write(Data("ekranbildo: \(what)\n".utf8))
    }

    func present(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Ekranbildo could not write that picture"
        alert.informativeText = "\(error)"
        alert.runModal()
    }

    func thumbnail(of reference: ImageRef) -> NSImage? {
        guard let picture = assets.image(for: reference) else { return nil }
        guard let rendered = try? ImageCodec.cgImage(of: picture) else { return nil }
        return NSImage(
            cgImage: rendered,
            size: NSSize(width: reference.pixelWidth, height: reference.pixelHeight))
    }
}
