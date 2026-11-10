import EkranbildoCore
import EkranbildoHotkeys
@testable import EkranbildoShell
import Foundation
import Testing

@Suite("Settings")
struct SettingsTests {

    @Test("Everything has a value before anybody chooses one")
    func defaultsExist() {
        let settings = Settings()
        #expect(settings.captureShortcut.refusalReason == nil)
        #expect(settings.libraryLimit > 0)
        #expect(settings.exportScale > 0)
    }

    @Test("Nothing is sent anywhere unless somebody says so")
    func diagnosticsAreOffByDefault() {
        #expect(!Settings().sendsDiagnostics)
    }

    @Test("The system's window shadow is left out by default")
    func windowShadowIsOffByDefault() {
        #expect(!Settings().includesWindowShadow)
    }

    private func decoded(_ json: String) throws -> Settings.Opened {
        try Settings.read(from: Data(json.utf8))
    }

    @Test("A file with nothing in it is the defaults")
    func emptyFileIsDefaults() throws {
        let opened = try decoded("{}")
        #expect(opened.settings == Settings())
        #expect(opened.reset.isEmpty)
    }

    @Test("A file that says something says it")
    func aFileIsRead() throws {
        let opened = try decoded(#"{"libraryLimit": 12, "copiesToClipboard": true}"#)
        #expect(opened.settings.libraryLimit == 12)
        #expect(opened.settings.copiesToClipboard)
    }

    @Test("A shortcut the system would refuse is reset, and reported")
    func unusableShortcutIsResetAndReported() throws {
        let opened = try decoded(#"{"captureShortcut": {"key": "four", "modifiers": 0}}"#)
        #expect(opened.settings.captureShortcut == Settings().captureShortcut)
        #expect(opened.reset.contains { $0.contains("shortcut") })
    }

    @Test("A limit below one is reset, and reported")
    func impossibleLimitIsResetAndReported() throws {
        let opened = try decoded(#"{"libraryLimit": 0}"#)
        #expect(opened.settings.libraryLimit == Settings().libraryLimit)
        #expect(opened.reset.contains { $0.contains("history") })
    }

    @Test("A scale that is not a scale is reset, and reported", arguments: ["0", "-2"])
    func impossibleScaleIsResetAndReported(value: String) throws {
        let opened = try decoded(#"{"exportScale": \#(value)}"#)
        #expect(opened.settings.exportScale == Settings().exportScale)
        #expect(opened.reset.contains { $0.contains("scale") })
    }

    @Test("A setting of the wrong kind is refused rather than guessed at")
    func wrongKindIsRefused() {
        #expect(throws: (any Error).self) { try decoded(#"{"libraryLimit": "lots"}"#) }
    }

    @Test("Everything that was reset is named once")
    func everythingResetIsNamed() throws {
        let opened = try decoded(#"{"libraryLimit": 0, "exportScale": 0}"#)
        #expect(opened.reset.count == 2)
    }

    @Test("Settings come back as they went in")
    func roundTrips() throws {
        var settings = Settings()
        settings.libraryLimit = 42
        settings.copiesToClipboard = true
        settings.exportScale = 2
        let reopened = try Settings.read(from: try Settings.write(settings))
        #expect(reopened.settings == settings)
        #expect(reopened.reset.isEmpty)
    }

    @Test("Writing the same settings twice gives the same bytes")
    func writesTheSameTwice() throws {
        let first = try Settings.write(Settings())
        let second = try Settings.write(Settings())
        #expect(first == second)
    }

    @Test("A setting this version has never heard of survives being saved")
    func unknownSettingsSurvive() throws {
        let opened = try decoded(#"{"libraryLimit": 7, "aChoiceFromLater": {"depth": 3}}"#)
        let saved = String(bytes: try Settings.write(opened.settings), encoding: .utf8) ?? ""
        #expect(saved.contains("aChoiceFromLater"))
        #expect(saved.contains("depth"))
    }

    @Test("Carrying it does not make it a setting")
    func carriedIsNotUnderstood() throws {
        let opened = try decoded(#"{"aChoiceFromLater": true}"#)
        #expect(opened.settings.libraryLimit == Settings().libraryLimit)
        #expect(opened.reset.isEmpty)
    }
}
