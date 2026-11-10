import CoreGraphics
import EkranbildoContracts
import Foundation

public final class KeyWatcher: @unchecked Sendable {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var seen: [Keystroke] = []
    private let lock = NSLock()
    private let began: Timestamp
    private let clock: any Clocking

    public init(began: Timestamp, clock: any Clocking) {
        self.began = began
        self.clock = clock
    }

    public enum Access: Hashable, Sendable {
        case granted
        case refused
        case notDetermined
    }

    public static func access() -> Access {
        guard CGPreflightListenEventAccess() else { return .notDetermined }
        return .granted
    }

    public static func ask() -> Access {
        CGRequestListenEventAccess() ? .granted : .notDetermined
    }

    public var keystrokes: [Keystroke] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    public enum Watching: Hashable, Sendable, CaseIterable {
        case watching
        case refused
    }

    public func start() -> Watching {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, _, event, pointer in
                    guard let pointer else { return Unmanaged.passUnretained(event) }
                    let watcher = Unmanaged<KeyWatcher>.fromOpaque(pointer)
                        .takeUnretainedValue()
                    watcher.saw(event)
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return .refused }

        tap = port
        let loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        source = loop
        CFRunLoopAddSource(CFRunLoopGetMain(), loop, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return CGEvent.tapIsEnabled(tap: port) ? .watching : .refused
    }

    public func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        source = nil
        tap = nil
    }

    private func saw(_ event: CGEvent) {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard let cap = Self.cap(for: Self.typed(in: event), keyCode: code) else { return }
        let keystroke = Keystroke(
            at: .seconds(clock.now() - began.seconds),
            cap: cap,
            modifiers: Self.modifiers(from: event.flags)
        )
        lock.lock()
        seen.append(keystroke)
        lock.unlock()
    }

    static func typed(in event: CGEvent) -> String {
        var length = 0
        var characters = [UniChar](repeating: 0, count: Codes.mostCharacters)
        event.keyboardGetUnicodeString(
            maxStringLength: Codes.mostCharacters,
            actualStringLength: &length,
            unicodeString: &characters
        )
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: characters, count: length)
    }

    static func cap(for typed: String, keyCode: Int64) -> String? {
        if let named = Codes.names.first(where: { $0.code == keyCode }) { return named.symbol }
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.uppercased()
    }

    static func modifiers(from flags: CGEventFlags) -> Modifiers {
        var found: Modifiers = []
        if flags.contains(.maskCommand) { found.insert(.command) }
        if flags.contains(.maskShift) { found.insert(.shift) }
        if flags.contains(.maskAlternate) { found.insert(.option) }
        if flags.contains(.maskControl) { found.insert(.control) }
        return found
    }

    public enum Codes {
        public static let enter: Int64 = 36
        public static let tab: Int64 = 48
        public static let space: Int64 = 49
        public static let delete: Int64 = 51
        public static let escape: Int64 = 53
        public static let leftArrow: Int64 = 123
        public static let rightArrow: Int64 = 124
        public static let downArrow: Int64 = 125
        public static let upArrow: Int64 = 126
        public static let unnamed: Int64 = 0

        struct Named {
            let code: Int64
            let symbol: String
        }

        static let names = [
            Named(code: enter, symbol: "⏎"),
            Named(code: tab, symbol: "⇥"),
            Named(code: space, symbol: "␣"),
            Named(code: delete, symbol: "⌫"),
            Named(code: escape, symbol: "⎋"),
            Named(code: leftArrow, symbol: "←"),
            Named(code: rightArrow, symbol: "→"),
            Named(code: downArrow, symbol: "↓"),
            Named(code: upArrow, symbol: "↑"),
        ]

        static let mostCharacters = 4
    }
}
