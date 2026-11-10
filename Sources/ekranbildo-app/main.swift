import AppKit
import EkranbildoApp
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoHotkeys
import EkranbildoLibrary
import EkranbildoShell
import EkranbildoViews
import UniformTypeIdentifiers

@MainActor
final class Shell: NSObject, NSApplicationDelegate {
    static var shared: Shell?

    var state = AppState(library: Library(), permission: .notDetermined)
    private var statusItem: NSStatusItem?
    var session: CaptureSession?
    let assets = AssetStore()
    var settingsWindow: SettingsWindowController?
    var libraryWindow: LibraryWindowController?
    private let settingsFile = SettingsFile()
    var settingsProblems: [String] = []
    private var hotkeys: HotkeyRegistry?
    var scrolling: ScrollSessionRunner?
    var choosingForAScroll = false
    var choosingForARecording = false
    var progress: ScrollProgressWindowController?
    var recorder: RecordingRunner?
    var recordingPanel: RecordingPanelController?
    var editors: Lookup<DocumentID, EditorWindowController> = Lookup()
    var welcomeWindow: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        loadSettings()
        registerHotkey()
        refreshPermission()
        #if DEBUG
            captureTheScreenWithoutBeingAsked()
        #endif

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder", accessibilityDescription: "Ekranbildo")
        item.button?.image?.isTemplate = true
        item.menu = buildMenu()
        statusItem = item
    }

    private func loadSettings() {
        guard let opened = try? settingsFile.read() else { return }
        settingsProblems = opened.reset
        apply(.settingsChanged(opened.settings))
    }

    var settings: Settings { state.settings }

    func save() {
        do {
            try settingsFile.write(settings)
        } catch {
            FileHandle.standardError.write(
                Data("ekranbildo: could not save your settings: \(error)\n".utf8))
        }
    }

    private func registerHotkey() {
        let registry = HotkeyRegistry { action in
            guard action == .captureRegion else { return }
            Task { @MainActor in Self.shared?.apply(.capture) }
        }
        hotkeys = registry
        do {
            try registry.register(settings.captureShortcut, for: .captureRegion)
        } catch {
            FileHandle.standardError.write(
                Data("ekranbildo: the capture shortcut is not available: \(error)\n".utf8))
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermission()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Capture…", action: #selector(capture), keyEquivalent: "4"
        ).target = self
        menu.addItem(
            withTitle: "Record…", action: #selector(record), keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Capture a Scroll…",
            action: #selector(captureScrolling),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Open a Sample…", action: #selector(openSample), keyEquivalent: "s"
        ).target = self
        menu.addItem(.separator())
        for line in Self.editorShortcuts {
            menu.addItem(withTitle: line, action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Save the Front Picture…",
            action: #selector(saveFrontDocument),
            keyEquivalent: "s"
        ).target = self
        menu.addItem(
            withTitle: "History…", action: #selector(openLibrary), keyEquivalent: "l"
        ).target = self
        menu.addItem(
            withTitle: "Save a Diagnostic Report…",
            action: #selector(saveDiagnostics),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Welcome…", action: #selector(openWelcome), keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ","
        ).target = self
        menu.addItem(
            withTitle: "Quit Ekranbildo", action: #selector(quit), keyEquivalent: "q"
        ).target = self
        return menu
    }

    private static let editorShortcuts = [
        "In an editor:",
        "    ⌘Z  Undo            ⇧⌘Z  Redo",
        "    1  Select      2  Point at      3  Hide",
        "    N  Number a step    ⌫  Delete    ←↑↓→  Nudge",
        "    Click a label to rename it, drag it to move it",
    ]

    @objc private func capture() {
        choosingForAScroll = false
        choosingForARecording = false
        apply(.capture)
    }

    @objc private func record() {
        choosingForARecording = true
        apply(.record)
    }

    @objc private func captureScrolling() {
        choosingForAScroll = true
        apply(.captureScrolling)
    }

    @objc private func openSample() {
        apply(.captured(SceneLibrary.sampleAnnotated, at: Self.now()))
    }

    static func now() -> Timestamp {
        Timestamp.seconds(Date().timeIntervalSince1970)
    }

    @objc private func openSettings() { apply(.openSettings) }
    @objc private func openWelcome() { apply(.showWelcome) }

    @objc private func openLibrary() { apply(.openLibrary) }
    @objc private func quit() { apply(.quit) }

    func apply(_ command: AppCommand) {
        let outcome = state.handle(command)
        state = outcome.state
        for effect in outcome.effects {
            perform(effect)
        }
    }

    private func perform(_ effect: AppEffect) {
        switch effect {
        case .terminate: NSApp.terminate(nil)
        case .openPrivacySettings: openPrivacySettings()
        case .askToRestart: askToRestart()
        case .freezeScreens: freezeScreens()
        case .dismissOverlay: dismissOverlay()
        case .openEditor(let id): openEditor(id)
        case .closeEditor(let id): closeEditor(id)
        case .copyPicture(let scene): copyToClipboard(scene)
        case .redrawEditor(let id): redrawEditor(id)
        case .savePicture(let id): savePicture(id)
        case .lookForSecrets(let id, let picture): lookForSecrets(id, picture)
        case .followTheScroll(let region): followTheScroll(region)
        case .joinTheScroll: joinTheScroll()
        case .startRecording(let region): startRecording(region)
        case .finishRecording(let polish): finishRecording(polish)
        case .forget(let pictures): pictures.forEach(assets.remove)
        case .showWelcome(let step): showWelcome(step)
        case .hideWelcome: hideWelcome()
        case .rememberSettings: save()
        case .showSettings: showSettings()
        case .showLibrary: showLibrary()
        }
    }

    private func askToRestart() {
        let alert = NSAlert()
        alert.messageText = "Ekranbildo needs to start again"
        alert.informativeText =
            "You have allowed screen recording, and Ekranbildo reads that permission when it "
            + "starts. Quit and open it again and capturing will work."
        alert.addButton(withTitle: "Quit Ekranbildo")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    func refreshPermission() {
        Task {
            let permission = await ScreenCaptureKitCapturer().permission()
            await MainActor.run { self.apply(.permissionIs(permission)) }
        }
    }

    private func openPrivacySettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security"
                    + "?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }

    func bringForward() {
        NSApp.activate()
    }
}

let application = NSApplication.shared
let shell = Shell()
application.delegate = shell
application.setActivationPolicy(.accessory)
application.run()
