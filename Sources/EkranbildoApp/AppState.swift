import EkranbildoContracts
import EkranbildoCore
import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell
import EkranbildoStitch

public enum DocumentTag: Sendable {}
public typealias DocumentID = StableID<DocumentTag>

public struct OpenDocument: Sendable {
    public let id: DocumentID
    public var document: Document
    public var editor: EditorState

    public var scene: Scene { document.scene }
    public var tool: ToolID { editor.tool }
    public var selection: [AnnotationID] { editor.selection }

    public init(id: DocumentID, document: Document) {
        self.id = id
        self.document = document
        editor = EditorState(scene: document.scene)
    }
}

extension OpenDocument: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.scene == b.scene && a.tool == b.tool && a.selection == b.selection
    }
}

public enum Screen: Sendable, Equatable {
    case idle
    case choosingRegion
    case scrolling
    case recording
    case explainingPermission
}

public enum AppEffect: Sendable, Equatable {
    case freezeScreens
    case dismissOverlay
    case showSettings
    case showLibrary
    case openPrivacySettings
    case askToRestart
    case openEditor(DocumentID)
    case closeEditor(DocumentID)
    case copyPicture(Scene)
    case redrawEditor(DocumentID)
    case savePicture(DocumentID)
    case lookForSecrets(DocumentID, ImageRef)
    case followTheScroll(ScreenRect)
    case joinTheScroll
    case startRecording(ScreenRect)
    case finishRecording(Polish)
    case forget([ImageRef])
    case showWelcome(OnboardingStep)
    case hideWelcome
    case rememberSettings
    case terminate
}

public enum AppCommand: Sendable, Equatable {
    case capture
    case captured(Scene, at: Timestamp)
    case settingsChanged(Settings)
    case openFromLibrary(CaptureID)
    case frontEditorIs(DocumentID?)
    case undo
    case redo
    case saveFront
    case foundSecrets(DocumentID, [Mask])
    case captureScrolling
    case choseScrollRegion(ScreenRect)
    case scrolled(seen: Int, advice: ScrollAdvice)
    case finishScrolling
    case record
    case choseRecordingRegion(ScreenRect)
    case recorded(seconds: Double, dropped: Int)
    case stopRecording
    case recordingWritten(ImageRef, seconds: Double, at: Timestamp)
    case permissionIs(CapturePermission)
    case showWelcome
    case dismiss
    case close(DocumentID)
    case edit(DocumentID, InputEvent)
    case openSettings
    case openLibrary
    case quit
}

public struct AppState: Sendable, Equatable {
    public internal(set) var screen: Screen
    public internal(set) var openDocuments: [OpenDocument]
    public internal(set) var library: Library
    public internal(set) var permission: CapturePermission
    public internal(set) var settings: Settings
    public internal(set) var scroll: Scrolling?
    public internal(set) var recording: RecordingProgress?
    var front: DocumentID?
    var nextDocument: UInt32
    var nextCapture: UInt32

    public init(
        library: Library,
        permission: CapturePermission,
        settings: Settings = Settings(),
        screen: Screen = .idle,
        openDocuments: [OpenDocument] = []
    ) {
        self.library = library
        self.permission = permission
        self.settings = settings
        self.screen = screen
        self.openDocuments = openDocuments
        nextDocument = 1
        nextCapture = 1
    }

    public struct Outcome: Sendable, Equatable {
        public let state: AppState
        public let effects: [AppEffect]
    }

    public func handle(_ command: AppCommand) -> Outcome {
        switch command {
        case .capture: capture()
        case .captured(let scene, let time): captured(scene, at: time)
        case .settingsChanged(let updated): changed(to: updated)
        case .openFromLibrary(let id): openFromLibrary(id)
        case .frontEditorIs(let id): frontEditorIs(id)
        case .undo: goingBack { $0.undo() }
        case .redo: goingBack { $0.redo() }
        case .saveFront:
            Outcome(state: self, effects: front.map { [.savePicture($0)] } ?? [])
        case .foundSecrets(let id, let masks): foundSecrets(id, masks)
        case .captureScrolling: captureScrolling()
        case .choseScrollRegion(let region): choseScrollRegion(region)
        case .scrolled(let seen, let advice): scrolled(seen, advice)
        case .finishScrolling: finishScrolling()
        case .record: record()
        case .choseRecordingRegion(let region): choseRecordingRegion(region)
        case .recorded(let seconds, let dropped): recorded(seconds, dropped)
        case .stopRecording: stopRecording()
        case .recordingWritten(let picture, let seconds, let time):
            recordingWritten(picture, seconds, at: time)
        case .permissionIs(let permission): learned(permission)
        case .showWelcome: Outcome(state: self, effects: [.showWelcome(onboarding)])
        case .dismiss: dismiss()
        case .close(let id): close(id)
        case .edit(let id, let event): edit(id, event)
        case .openSettings: Outcome(state: self, effects: [.showSettings])
        case .openLibrary: Outcome(state: self, effects: [.showLibrary])
        case .quit: Outcome(state: self, effects: [.terminate])
        }
    }

    private func learned(_ permission: CapturePermission) -> Outcome {
        var next = self
        next.permission = permission
        guard next.onboarding != onboarding else { return Outcome(state: next, effects: []) }
        return Outcome(state: next, effects: [next.welcoming])
    }

    public var onboarding: OnboardingStep {
        OnboardingStep(
            permission: permission,
            hasCapturedAnything: settings.hasFinishedOnboarding,
            captureShortcut: settings.captureShortcut
        )
    }

    var welcoming: AppEffect {
        onboarding.isComplete ? .hideWelcome : .showWelcome(onboarding)
    }

    private func capture() -> Outcome {
        guard screen != .choosingRegion else { return dismiss() }

        switch permission {
        case .granted, .notDetermined:
            var next = self
            next.screen = .choosingRegion
            return Outcome(state: next, effects: [.freezeScreens])

        case .denied:
            var next = self
            next.screen = .explainingPermission
            return Outcome(state: next, effects: [.openPrivacySettings])

        case .grantedPendingRestart:
            var next = self
            next.screen = .explainingPermission
            return Outcome(state: next, effects: [.askToRestart])
        }
    }

    func captured(_ scene: Scene, at time: Timestamp) -> Outcome {
        var next = self
        next.screen = .idle
        var effects: [AppEffect] = [.dismissOverlay]

        if !next.settings.hasFinishedOnboarding {
            next.settings.hasFinishedOnboarding = true
            effects.append(.rememberSettings)
            effects.append(next.welcoming)
        }

        if settings.copiesToClipboard {
            effects.append(.copyPicture(scene))
        }

        if settings.opensEditorAfterCapture {
            let id = DocumentID(next.nextDocument)
            next.nextDocument += 1
            next.openDocuments.append(
                OpenDocument(
                    id: id,
                    document: Document(scene: scene, measurer: TabulatedTextMeasurer.uniform())
                )
            )
            effects.append(.openEditor(id))
            if settings.hidesSecretsAutomatically, let background = scene.background {
                effects.append(.lookForSecrets(id, background))
            }
        }

        if let background = scene.background {
            let dropped = next.library.add(
                LibraryEntry(
                    id: CaptureID(next.nextCapture),
                    takenAt: time,
                    image: background,
                    canvas: scene.canvas.size,
                    source: .region
                )
            )
            next.nextCapture += 1
            effects += next.releasing(dropped.map(\.image))
        }

        return Outcome(state: next, effects: effects)
    }

    private func edit(_ id: DocumentID, _ event: InputEvent) -> Outcome {
        guard let index = openDocuments.firstIndex(where: { $0.id == id }) else {
            return Outcome(state: self, effects: [])
        }
        var next = self
        var open = openDocuments[index]

        switch event.handledBy {
        case .history(.back):
            open.document.undo()
        case .history(.forward):
            open.document.redo()
        case .theEditor:
            let outcome = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())
                .handle(event, in: open.editor)
            open.editor = outcome.state
            if outcome.effects.contains(.checkpoint) {
                open.document.checkpoint()
            }
            open.document.apply(outcome.commands)
        }

        open.editor.scene = open.document.scene

        next.openDocuments[index] = open
        return Outcome(state: next, effects: [])
    }
}
