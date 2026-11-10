import EkranbildoContracts

public enum ShortcutKey: String, Hashable, Sendable, Codable, CaseIterable {
    case one, two, three, four, five, six, seven, eight, nine, zero
    case a, c, d, e, f, r, s, v, w, x
    case space
    case escape

    public var displayed: String {
        switch self {
        case .one: "1"
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .five: "5"
        case .six: "6"
        case .seven: "7"
        case .eight: "8"
        case .nine: "9"
        case .zero: "0"
        case .space: "Space"
        case .escape: "⎋"
        case .a, .c, .d, .e, .f, .r, .s, .v, .w, .x: rawValue.uppercased()
        }
    }
}

public struct Shortcut: Hashable, Sendable, Codable {
    public let key: ShortcutKey
    public let modifiers: Modifiers

    public init(key: ShortcutKey, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    public var refusalReason: String? {
        guard !modifiers.isEmpty else {
            return """
                A shortcut needs at least one modifier key. Without one it would \
                take that key away from every other application.
                """
        }
        return nil
    }

    public var cautionReason: String? {
        guard refusalReason == nil else { return nil }
        guard !modifiers.contains(.command), !modifiers.contains(.control) else { return nil }
        return """
            Some systems will not watch for a combination held with only shift \
            and option. Adding command or control makes it work everywhere.
            """
    }

    public var isUsable: Bool { refusalReason == nil }

    public var displayed: String {
        var text = ""
        if modifiers.contains(.control) { text += Symbols.control }
        if modifiers.contains(.option) { text += Symbols.option }
        if modifiers.contains(.shift) { text += Symbols.shift }
        if modifiers.contains(.command) { text += Symbols.command }
        return text + key.displayed
    }

    private enum Symbols {
        static let control = "⌃"
        static let option = "⌥"
        static let shift = "⇧"
        static let command = "⌘"
    }

    public enum Defaults {
        public static let captureRegion = Shortcut(key: .four, modifiers: [.command, .shift, .option])
        public static let captureWindow = Shortcut(key: .five, modifiers: [.command, .shift, .option])
        public static let captureScreen = Shortcut(key: .six, modifiers: [.command, .shift, .option])
        public static let startRecording = Shortcut(key: .r, modifiers: [.command, .shift, .option])

        public static let all: [Shortcut] = [
            captureRegion, captureWindow, captureScreen, startRecording,
        ]
    }
}
