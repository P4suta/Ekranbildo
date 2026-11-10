import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("After a capture")
struct AfterACaptureTests {

    private static let time = Timestamp.seconds(1)

    private static func scene(_ name: String, width: Double = 100) -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: width, height: 80),
            background: ImageRef(contentHash: name, pixelWidth: Int(width), pixelHeight: 80),
            annotations: [],
            style: .standard
        )
    }

    private static func app(_ change: (inout Settings) -> Void = { _ in }) -> AppState {
        var settings = Settings()
        change(&settings)
        return AppState(library: Library(), permission: .granted, settings: settings)
    }

    private static func capturing(
        _ scenes: [Scene],
        _ change: (inout Settings) -> Void = { _ in }
    ) -> (state: AppState, effects: [AppEffect]) {
        var state = app(change)
        var effects: [AppEffect] = []
        for (index, scene) in scenes.enumerated() {
            let outcome = state.handle(.capture).state
                .handle(.captured(scene, at: Timestamp.seconds(Double(index + 1))))
            state = outcome.state
            effects = outcome.effects
        }
        return (state, effects)
    }

    @Test("A capture opens an editor, because that is what this is for")
    func opensAnEditor() {
        let outcome = Self.capturing([Self.scene("one")])
        #expect(outcome.effects.contains(.openEditor(DocumentID(1))))
        #expect(outcome.state.openDocuments.count == 1)
    }

    @Test("Turning the editor off leaves no editor and no document open")
    func editorTurnedOff() {
        let outcome = Self.capturing([Self.scene("one")]) { $0.opensEditorAfterCapture = false }
        #expect(!outcome.effects.contains { if case .openEditor = $0 { true } else { false } })
        #expect(outcome.state.openDocuments.isEmpty)
    }

    @Test("Nothing is copied when the clipboard has been turned off")
    func notCopiedWhenTurnedOff() {
        let outcome = Self.capturing(
            [Self.scene("one")], { $0.copiesToClipboard = false })
        #expect(!outcome.effects.contains { if case .copyPicture = $0 { true } else { false } })
    }

    @Test("Asking for it copies the picture that was taken")
    func copiedWhenAsked() {
        let taken = Self.scene("one")
        let outcome = Self.capturing([taken]) { $0.copiesToClipboard = true }
        #expect(outcome.effects.contains(.copyPicture(taken)))
    }

    @Test("What is copied is what was captured, editor or no editor")
    func copiedWithoutAnEditor() {
        let taken = Self.scene("one")
        let outcome = Self.capturing([taken]) {
            $0.copiesToClipboard = true
            $0.opensEditorAfterCapture = false
        }
        #expect(outcome.effects.contains(.copyPicture(taken)))
    }

    @Test("A capture goes into the history")
    func recorded() throws {
        let state = Self.capturing([Self.scene("one")]).state
        #expect(state.library.entries.count == 1)
        let entry = try #require(state.library.newest)
        #expect(entry.image.contentHash == "one")
        #expect(entry.takenAt == Self.time)
    }

    @Test("Captures go into the history newest first")
    func recordedInOrder() {
        let state = Self.capturing([Self.scene("one"), Self.scene("two")]).state
        #expect(state.library.entries.map(\.image.contentHash) == ["two", "one"])
    }

    @Test("Each capture in the history is its own")
    func distinctIdentities() {
        let state = Self.capturing([Self.scene("one"), Self.scene("two")]).state
        #expect(Set(state.library.entries.map(\.id)).count == 2)
    }

    @Test("A picture that falls off the end of the history is let go of")
    func evictedPicturesAreForgotten() throws {
        var settings = Settings()
        settings.libraryLimit = 2
        settings.opensEditorAfterCapture = false
        var state = AppState(
            library: Library(limit: settings.libraryLimit),
            permission: .granted,
            settings: settings
        )

        var effects: [AppEffect] = []
        for index in 1...3 {
            let outcome = state.handle(.capture).state.handle(
                .captured(Self.scene("picture-\(index)"), at: Timestamp.seconds(Double(index))))
            state = outcome.state
            effects = outcome.effects
        }

        #expect(state.library.entries.count == 2)
        let forgotten = try #require(
            effects.compactMap { if case .forget(let refs) = $0 { refs } else { nil } }.first)
        #expect(forgotten.map(\.contentHash) == ["picture-1"])
    }

    @Test("A picture something else still refers to is not let go of")
    func sharedPicturesSurvive() {
        var settings = Settings()
        settings.libraryLimit = 2
        settings.opensEditorAfterCapture = false
        var state = AppState(
            library: Library(limit: settings.libraryLimit),
            permission: .granted,
            settings: settings
        )

        var effects: [AppEffect] = []
        for (index, name) in ["same", "same", "other"].enumerated() {
            let outcome = state.handle(.capture).state.handle(
                .captured(Self.scene(name), at: Timestamp.seconds(Double(index + 1))))
            state = outcome.state
            effects = outcome.effects
        }
        #expect(!effects.contains { if case .forget = $0 { true } else { false } })
    }

    @Test("A picture an open editor is showing is not let go of")
    func picturesInOpenEditorsSurvive() {
        var settings = Settings()
        settings.libraryLimit = 1
        var state = AppState(
            library: Library(limit: settings.libraryLimit),
            permission: .granted,
            settings: settings
        )

        var effects: [AppEffect] = []
        for (index, name) in ["kept-open", "newer"].enumerated() {
            let outcome = state.handle(.capture).state.handle(
                .captured(Self.scene(name), at: Timestamp.seconds(Double(index + 1))))
            state = outcome.state
            effects = outcome.effects
        }
        #expect(state.openDocuments.count == 2)
        #expect(!effects.contains { if case .forget = $0 { true } else { false } })
    }

    @Test("A setting changed applies to the next capture")
    func settingsChange() {
        var state = Self.app()
        state =
            state.handle(
                .settingsChanged(
                    {
                        var settings = Settings()
                        settings.copiesToClipboard = true
                        return settings
                    }())
            ).state
        let taken = Self.scene("one")
        let outcome = state.handle(.capture).state.handle(.captured(taken, at: Self.time))
        #expect(outcome.effects.contains(.copyPicture(taken)))
    }

    @Test("Changing a setting on its own shows nothing")
    func settingsChangeIsQuiet() {
        #expect(Self.app().handle(.settingsChanged(Settings())).effects.isEmpty)
    }

    @Test("Lowering the history limit forgets what no longer fits")
    func loweringTheLimit() throws {
        var state = Self.capturing([Self.scene("one"), Self.scene("two"), Self.scene("three")]) {
            $0.opensEditorAfterCapture = false
        }.state
        #expect(state.library.entries.count == 3)

        var smaller = Settings()
        smaller.opensEditorAfterCapture = false
        smaller.libraryLimit = 1
        let outcome = state.handle(.settingsChanged(smaller))
        state = outcome.state
        #expect(state.library.entries.map(\.image.contentHash) == ["three"])
        let forgotten = try #require(
            outcome.effects.compactMap { if case .forget(let refs) = $0 { refs } else { nil } }.first)
        #expect(Set(forgotten.map(\.contentHash)) == ["one", "two"])
    }
}

@Suite("Opening something out of the history")
struct OpeningFromHistoryTests {

    private static func app() -> AppState {
        var settings = Settings()
        settings.opensEditorAfterCapture = false
        return AppState(library: Library(), permission: .granted, settings: settings)
    }

    private static func captured() -> AppState {
        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 640, height: 400),
            background: ImageRef(contentHash: "taken", pixelWidth: 1280, pixelHeight: 800),
            annotations: [],
            style: .standard
        )
        return app().handle(.capture).state
            .handle(.captured(scene, at: Timestamp.seconds(1))).state
    }

    @Test("Picking one out of the history opens an editor for it")
    func opens() throws {
        let state = Self.captured()
        let entry = try #require(state.library.newest)
        let outcome = state.handle(.openFromLibrary(entry.id))
        #expect(outcome.effects == [.openEditor(DocumentID(1))])
        #expect(outcome.state.openDocuments.count == 1)
    }

    @Test("What opens is the size the capture was")
    func theRightSize() throws {
        let state = Self.captured()
        let entry = try #require(state.library.newest)
        let opened = try #require(state.handle(.openFromLibrary(entry.id)).state.openDocuments.first)
        #expect(opened.scene.canvas.width == 640)
        #expect(opened.scene.canvas.height == 400)
        #expect(opened.scene.background?.contentHash == "taken")
    }

    @Test("Picking one that is not there changes nothing")
    func missing() {
        let outcome = Self.app().handle(.openFromLibrary(CaptureID(99)))
        #expect(outcome.effects.isEmpty)
        #expect(outcome.state.openDocuments.isEmpty)
    }

    @Test("Opening the same one twice opens two editors")
    func twice() throws {
        var state = Self.captured()
        let entry = try #require(state.library.newest)
        state = state.handle(.openFromLibrary(entry.id)).state
        state = state.handle(.openFromLibrary(entry.id)).state
        #expect(state.openDocuments.count == 2)
    }
}
