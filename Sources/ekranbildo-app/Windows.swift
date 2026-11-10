import AppKit
import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoShell
import EkranbildoViews
import UniformTypeIdentifiers

extension Shell {
    func showSettings() {
        let keep: @MainActor (Settings) -> Void = { [weak self] updated in
            guard let self else { return }
            self.apply(.settingsChanged(updated))
            self.save()
        }
        let controller =
            settingsWindow
            ?? SettingsWindowController(
                settings: settings, reset: settingsProblems, save: keep)
        settingsWindow = controller
        controller.showWindow(nil)
        bringForward()
    }

    @objc func saveDiagnostics() {
        guard let document = state.frontDocument else {
            say("there is nothing open to report on")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "Ekranbildo Diagnostics.html"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let shown =
            settings.sendsDiagnostics
            ? document.scene
            : Synthesis().synthesised(document.scene)
        do {
            try Data(Diagnostics.html(of: shown).utf8).write(to: destination)
            say("wrote a report to \(destination.path)")
        } catch {
            present(error)
        }
    }

    func showLibrary() {
        let controller =
            libraryWindow
            ?? LibraryWindowController(
                library: state.library,
                thumbnail: { [weak self] reference in self?.thumbnail(of: reference) },
                open: { [weak self] id in self?.apply(.openFromLibrary(id)) }
            )
        controller.library = state.library
        libraryWindow = controller
        controller.showWindow(nil)
        bringForward()
    }
}
