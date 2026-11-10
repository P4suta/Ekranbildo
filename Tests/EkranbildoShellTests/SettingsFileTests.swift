@testable import EkranbildoShell
import Foundation
import Testing

@Suite("The settings file")
struct SettingsFileTests {

    private func scratch() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ekranbildo-settings-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Settings come back from where they were put")
    func roundTrips() throws {
        let file = SettingsFile(directory: scratch())
        var settings = Settings()
        settings.libraryLimit = 42
        try file.write(settings)
        #expect(try file.read().settings.libraryLimit == 42)
    }

    @Test("No file at all is the defaults")
    func missingFileIsDefaults() throws {
        let opened = try SettingsFile(directory: scratch()).read()
        #expect(opened.settings == Settings())
        #expect(opened.reset.isEmpty)
    }

    @Test("A file that is not settings at all is the defaults, and says so")
    func corruptFileIsDefaultsAndSaysSo() throws {
        let directory = scratch()
        let file = SettingsFile(directory: directory)
        try Data("this is not settings".utf8).write(to: file.location)

        let opened = try file.read()
        #expect(opened.settings == Settings())
        #expect(opened.reset.contains { $0.contains("could not be read") })
    }

    @Test("A file that could not be read is kept beside the new one")
    func unreadableFileIsKept() throws {
        let directory = scratch()
        let file = SettingsFile(directory: directory)
        try Data("not settings".utf8).write(to: file.location)
        _ = try file.read()
        #expect(FileManager.default.fileExists(atPath: file.rejected.path))
    }

    @Test("Writing twice gives the same bytes")
    func writesTheSameTwice() throws {
        let file = SettingsFile(directory: scratch())
        try file.write(Settings())
        let first = try Data(contentsOf: file.location)
        try file.write(Settings())
        #expect(try Data(contentsOf: file.location) == first)
    }

    @Test("A setting a later version wrote survives a read and a write")
    func unknownSettingsSurvive() throws {
        let directory = scratch()
        let file = SettingsFile(directory: directory)
        try Data(#"{"libraryLimit": 7, "aChoiceFromLater": true}"#.utf8).write(to: file.location)

        let opened = try file.read()
        try file.write(opened.settings)
        let saved = try String(contentsOf: file.location, encoding: .utf8)
        #expect(saved.contains("aChoiceFromLater"))
    }

    @Test("It writes where a sandboxed application may write")
    func insideTheContainer() {
        let file = SettingsFile()
        #expect(file.location.path.contains("Application Support"))
        #expect(file.location.lastPathComponent.hasSuffix(".json"))
    }
}
