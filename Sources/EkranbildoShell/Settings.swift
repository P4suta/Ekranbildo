import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoHotkeys
import EkranbildoLibrary
import Foundation

public struct Settings: Hashable, Sendable {
    public var captureShortcut: Shortcut
    public var includesPointer: Bool
    public var includesWindowShadow: Bool
    public var opensEditorAfterCapture: Bool
    public var copiesToClipboard: Bool
    public var hidesSecretsAutomatically: Bool
    public var smoothsThePointer: Bool
    public var showsClicks: Bool
    public var showsKeystrokes: Bool
    public var cutsDeadTime: Bool
    public var libraryLimit: Int
    public var exportScale: Double
    public var sendsDiagnostics: Bool
    public var hasFinishedOnboarding: Bool
    public var unknownKeys: UnknownKeys

    public init(
        captureShortcut: Shortcut = Defaults.captureShortcut,
        includesPointer: Bool = Defaults.includesPointer,
        includesWindowShadow: Bool = Defaults.includesWindowShadow,
        opensEditorAfterCapture: Bool = Defaults.opensEditorAfterCapture,
        copiesToClipboard: Bool = Defaults.copiesToClipboard,
        hidesSecretsAutomatically: Bool = Defaults.hidesSecretsAutomatically,
        smoothsThePointer: Bool = Defaults.smoothsThePointer,
        showsClicks: Bool = Defaults.showsClicks,
        showsKeystrokes: Bool = Defaults.showsKeystrokes,
        cutsDeadTime: Bool = Defaults.cutsDeadTime,
        libraryLimit: Int = Defaults.libraryLimit,
        exportScale: Double = Defaults.exportScale,
        sendsDiagnostics: Bool = Defaults.sendsDiagnostics,
        hasFinishedOnboarding: Bool = Defaults.hasFinishedOnboarding,
        unknownKeys: UnknownKeys = .nothing
    ) {
        self.captureShortcut = captureShortcut
        self.includesPointer = includesPointer
        self.includesWindowShadow = includesWindowShadow
        self.opensEditorAfterCapture = opensEditorAfterCapture
        self.copiesToClipboard = copiesToClipboard
        self.hidesSecretsAutomatically = hidesSecretsAutomatically
        self.smoothsThePointer = smoothsThePointer
        self.showsClicks = showsClicks
        self.showsKeystrokes = showsKeystrokes
        self.cutsDeadTime = cutsDeadTime
        self.libraryLimit = libraryLimit
        self.exportScale = exportScale
        self.sendsDiagnostics = sendsDiagnostics
        self.hasFinishedOnboarding = hasFinishedOnboarding
        self.unknownKeys = unknownKeys
    }

    public enum Defaults {
        public static let captureShortcut = Shortcut(key: .four, modifiers: [.control, .shift])
        public static let includesPointer = true
        public static let includesWindowShadow = false
        public static let opensEditorAfterCapture = true
        public static let copiesToClipboard = true
        public static let hidesSecretsAutomatically = true
        public static let smoothsThePointer = true
        public static let showsClicks = true
        public static let showsKeystrokes = false
        public static let cutsDeadTime = true
        public static let libraryLimit = Library.Defaults.limit
        public static let exportScale: Double = 1
        public static let sendsDiagnostics = false
        public static let hasFinishedOnboarding = false
    }

    static let smallestLibrary = 1

    public struct Opened: Hashable, Sendable {
        public let settings: Settings
        public let reset: [String]
    }

    public static func read(from data: Data) throws -> Opened {
        let stored = try JSONDecoder().decode(Stored.self, from: data)
        var settings = stored.settings
        var reset: [String] = []

        if let reason = settings.captureShortcut.refusalReason {
            settings.captureShortcut = Defaults.captureShortcut
            reset.append("The capture shortcut was reset. \(reason)")
        }
        if settings.libraryLimit < smallestLibrary {
            settings.libraryLimit = Defaults.libraryLimit
            reset.append(
                "The history size was reset: a history of \(stored.settings.libraryLimit) "
                    + "would forget a capture as it was taken."
            )
        }
        if !(settings.exportScale > 0) || !settings.exportScale.isFinite {
            settings.exportScale = Defaults.exportScale
            reset.append("The export scale was reset: it has to be a positive number.")
        }

        return Opened(settings: settings, reset: reset)
    }

    public static func write(_ settings: Self) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(Stored(settings: settings))
    }
}

struct Stored: Codable {
    let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<Value: Decodable>(_ key: CodingKeys, _ fallback: Value) throws -> Value {
            try container.decodeIfPresent(Value.self, forKey: key) ?? fallback
        }

        let defaults = Settings()
        settings = Settings(
            captureShortcut: try value(.captureShortcut, defaults.captureShortcut),
            includesPointer: try value(.includesPointer, defaults.includesPointer),
            includesWindowShadow: try value(.includesWindowShadow, defaults.includesWindowShadow),
            opensEditorAfterCapture: try value(
                .opensEditorAfterCapture, defaults.opensEditorAfterCapture),
            copiesToClipboard: try value(.copiesToClipboard, defaults.copiesToClipboard),
            hidesSecretsAutomatically: try value(
                .hidesSecretsAutomatically, defaults.hidesSecretsAutomatically),
            smoothsThePointer: try value(.smoothsThePointer, defaults.smoothsThePointer),
            showsClicks: try value(.showsClicks, defaults.showsClicks),
            showsKeystrokes: try value(.showsKeystrokes, defaults.showsKeystrokes),
            cutsDeadTime: try value(.cutsDeadTime, defaults.cutsDeadTime),
            libraryLimit: try value(.libraryLimit, defaults.libraryLimit),
            exportScale: try value(.exportScale, defaults.exportScale),
            sendsDiagnostics: try value(.sendsDiagnostics, defaults.sendsDiagnostics),
            hasFinishedOnboarding: try value(
                .hasFinishedOnboarding, defaults.hasFinishedOnboarding),
            unknownKeys: try UnknownKeys.read(
                from: decoder, known: NameSet(CodingKeys.allCases.map(\.rawValue)))
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings.captureShortcut, forKey: .captureShortcut)
        try container.encode(settings.includesPointer, forKey: .includesPointer)
        try container.encode(settings.includesWindowShadow, forKey: .includesWindowShadow)
        try container.encode(settings.opensEditorAfterCapture, forKey: .opensEditorAfterCapture)
        try container.encode(settings.copiesToClipboard, forKey: .copiesToClipboard)
        try container.encode(
            settings.hidesSecretsAutomatically, forKey: .hidesSecretsAutomatically)
        try container.encode(settings.smoothsThePointer, forKey: .smoothsThePointer)
        try container.encode(settings.showsClicks, forKey: .showsClicks)
        try container.encode(settings.showsKeystrokes, forKey: .showsKeystrokes)
        try container.encode(settings.cutsDeadTime, forKey: .cutsDeadTime)
        try container.encode(settings.libraryLimit, forKey: .libraryLimit)
        try container.encode(settings.exportScale, forKey: .exportScale)
        try container.encode(settings.sendsDiagnostics, forKey: .sendsDiagnostics)
        try container.encode(settings.hasFinishedOnboarding, forKey: .hasFinishedOnboarding)
        try settings.unknownKeys.write(to: encoder)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case captureShortcut, includesPointer, includesWindowShadow, opensEditorAfterCapture
        case copiesToClipboard, libraryLimit, exportScale, sendsDiagnostics
        case hidesSecretsAutomatically, smoothsThePointer, showsClicks, cutsDeadTime
        case hasFinishedOnboarding, showsKeystrokes
    }
}
