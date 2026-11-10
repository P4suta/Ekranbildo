import Carbon.HIToolbox
import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability
import Foundation

public enum HotkeyAction: String, Hashable, Sendable, Codable, CaseIterable {
    case captureRegion
    case captureWindow
    case captureScreen
    case startRecording
}

public protocol HotkeyWatching: AnyObject, Sendable {
    func register(_ shortcut: Shortcut, for action: HotkeyAction) throws
    func unregisterAll()
}

public struct HotkeyError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String
    public let remedy: String

    public var description: String { "\(code): \(detail)" }

    public init(code: DiagnosticCode, detail: String, remedy: String) {
        self.code = code
        self.detail = detail
        self.remedy = remedy
    }

    public static let unacceptableCombination: DiagnosticCode = 900
    public static let alreadyTaken: DiagnosticCode = 901
    public static let registrationFailed: DiagnosticCode = 902
}

public final class HotkeyRegistry: HotkeyWatching, @unchecked Sendable {
    private let lock = NSLock()
    private var registered: [(reference: EventHotKeyRef, action: HotkeyAction)] = []
    private let perform: @Sendable (HotkeyAction) -> Void

    public init(perform: @escaping @Sendable (HotkeyAction) -> Void) {
        self.perform = perform
    }

    deinit {
        unregisterAll()
    }

    public func register(_ shortcut: Shortcut, for action: HotkeyAction) throws {
        if let reason = shortcut.refusalReason {
            throw HotkeyError(
                code: HotkeyError.unacceptableCombination,
                detail: "\(shortcut.displayed) is not a combination the system will watch for",
                remedy: reason
            )
        }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: UInt32(HotkeyAction.allCases.firstIndex(of: action) ?? 0)
        )
        let status = RegisterEventHotKey(
            Self.keyCode(of: shortcut.key),
            Self.carbonModifiers(of: shortcut.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            throw HotkeyError(
                code: HotkeyError.alreadyTaken,
                detail: "the system would not watch for \(shortcut.displayed) (status \(status))",
                remedy: shortcut.cautionReason
                    ?? """
                    Another application is probably already watching for \
                    \(shortcut.displayed). Choose a different combination.
                    """
            )
        }

        lock.lock()
        registered.append((reference, action))
        lock.unlock()
    }

    public func unregisterAll() {
        lock.lock()
        let all = registered
        registered = []
        lock.unlock()
        for entry in all {
            UnregisterEventHotKey(entry.reference)
        }
    }

    private static let signature: OSType = {
        var value: OSType = 0
        for character in "SNPL".utf8 {
            value = (value << Bits.perCharacter) | OSType(character)
        }
        return value
    }()

    private enum Bits {
        static let perCharacter: OSType = 8
    }

    static func keyCode(of key: ShortcutKey) -> UInt32 {
        UInt32(Self.virtualKeys[key] ?? kVK_ANSI_A)
    }

    private static let virtualKeys = Lookup<ShortcutKey, Int>([
        .one: kVK_ANSI_1,
        .two: kVK_ANSI_2,
        .three: kVK_ANSI_3,
        .four: kVK_ANSI_4,
        .five: kVK_ANSI_5,
        .six: kVK_ANSI_6,
        .seven: kVK_ANSI_7,
        .eight: kVK_ANSI_8,
        .nine: kVK_ANSI_9,
        .zero: kVK_ANSI_0,
        .a: kVK_ANSI_A,
        .c: kVK_ANSI_C,
        .d: kVK_ANSI_D,
        .e: kVK_ANSI_E,
        .f: kVK_ANSI_F,
        .r: kVK_ANSI_R,
        .s: kVK_ANSI_S,
        .v: kVK_ANSI_V,
        .w: kVK_ANSI_W,
        .x: kVK_ANSI_X,
        .space: kVK_Space,
        .escape: kVK_Escape,
    ])

    static func carbonModifiers(of modifiers: Modifiers) -> UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        return value
    }
}
