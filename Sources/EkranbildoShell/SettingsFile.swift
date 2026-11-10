import Foundation

public struct SettingsFile: Sendable {
    private let directory: URL

    public init(directory: URL? = nil) {
        self.directory =
            directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Names.folder)
            ?? FileManager.default.temporaryDirectory
    }

    public var location: URL { directory.appendingPathComponent(Names.file) }

    public var rejected: URL { directory.appendingPathComponent(Names.rejected) }

    public func read() throws -> Settings.Opened {
        guard let data = try? Data(contentsOf: location) else {
            return Settings.Opened(settings: Settings(), reset: [])
        }

        do {
            return try Settings.read(from: data)
        } catch {
            try? FileManager.default.removeItem(at: rejected)
            try? data.write(to: rejected)
            return Settings.Opened(
                settings: Settings(),
                reset: [
                    "Your settings could not be read, so the defaults are in use. "
                        + "The file is kept at \(rejected.lastPathComponent)."
                ]
            )
        }
    }

    public func write(_ settings: Settings) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        try Settings.write(settings).write(to: location, options: .atomic)
    }

    private enum Names {
        static let folder = "Ekranbildo"
        static let file = "settings.json"
        static let rejected = "settings-that-could-not-be-read.json"
    }
}
