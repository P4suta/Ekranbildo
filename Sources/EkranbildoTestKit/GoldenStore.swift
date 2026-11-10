import EkranbildoContracts
import Foundation

public enum GoldenResult: Equatable, Sendable {
    case matched
    case created
    case updated
    case mismatched(diff: String)
    case incomparable(recorded: String, now: String)
}

extension GoldenResult {
    public var isAcceptable: Bool {
        switch self {
        case .matched, .created, .updated: true
        case .mismatched, .incomparable: false
        }
    }

    public var message: String {
        switch self {
        case .matched: "golden matched"
        case .created: "golden did not exist and was written; review it in the diff"
        case .updated: "golden was re-recorded because EKRANBILDO_UPDATE_GOLDENS is set"
        case .mismatched(let diff):
            """
            golden mismatch. Re-record with EKRANBILDO_UPDATE_GOLDENS=1 swift test
            once the change is intended.

            \(diff)
            """
        case .incomparable(let recorded, let now):
            """
            golden not comparable: it was recorded by a different pipeline.

            recorded by: \(recorded)
               running:  \(now)

            Nothing here says anything is wrong. Re-record with \
            EKRANBILDO_UPDATE_GOLDENS=1 swift test once you have decided the change \
            that moved the pipeline was intended.
            """
        }
    }
}

public struct GoldenStore: Sendable {
    private let directory: URL
    private let updating: Bool

    public init(directory: URL, updating: Bool = ProcessInfo.processInfo.isUpdatingGoldens) {
        self.directory = directory
        self.updating = updating
    }

    public func compare(
        _ actual: String,
        named name: String,
        version: PipelineVersion? = nil
    ) throws -> GoldenResult {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let stamped = version.map { "\($0.canonicalText)\n\(actual)" } ?? actual

        guard FileManager.default.fileExists(atPath: url.path) else {
            try write(stamped, to: url)
            return .created
        }

        let recorded = try String(contentsOf: url, encoding: .utf8)
        let stored = Self.split(recorded)
        let recordedVersion = stored.version
        let expected = stored.contents

        if let version, let moved = PipelineVersion.stamp(recordedVersion, matches: version) {
            if updating {
                try write(stamped, to: url)
                return .updated
            }
            return .incomparable(recorded: moved, now: version.canonicalText)
        }

        guard let diff = LineDiff.unified(expected: expected, actual: actual) else {
            return .matched
        }
        if updating {
            try write(stamped, to: url)
            return .updated
        }
        return .mismatched(diff: diff)
    }

    struct Stored {
        let version: String?
        let contents: String
    }

    static func split(_ recorded: String) -> Stored {
        guard let newline = recorded.firstIndex(of: "\n") else {
            return Stored(version: nil, contents: recorded)
        }
        let first = String(recorded[..<newline])
        guard first.hasPrefix(Stamp.prefix) else {
            return Stored(version: nil, contents: recorded)
        }
        return Stored(
            version: first, contents: String(recorded[recorded.index(after: newline)...]))
    }

    private enum Stamp {
        static let prefix = "pipeline "
    }

    private func write(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func forRepository(
        subdirectory: String,
        testFile: StaticString = #filePath
    ) -> Self {
        var url = URL(fileURLWithPath: "\(testFile)")
        while url.pathComponents.count > 1 && url.lastPathComponent != "Tests" {
            url = url.deletingLastPathComponent()
        }
        return Self(directory: url.appendingPathComponent("Goldens/\(subdirectory)"))
    }
}

extension ProcessInfo {
    public var isUpdatingGoldens: Bool {
        let value = environment["EKRANBILDO_UPDATE_GOLDENS"] ?? "0"
        return value == "1" || value.lowercased() == "true"
    }
}
