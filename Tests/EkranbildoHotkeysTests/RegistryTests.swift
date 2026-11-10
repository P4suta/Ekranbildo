import Carbon.HIToolbox
import EkranbildoContracts
@testable import EkranbildoHotkeys
import Foundation
import Testing

@Suite("Hotkey registry")
struct RegistryTests {

    @Test("A combination with no modifier is refused before asking")
    func refusesEarly() {
        let registry = HotkeyRegistry { _ in }
        defer { registry.unregisterAll() }

        #expect(throws: HotkeyError.self) {
            try registry.register(
                Shortcut(key: .four, modifiers: .plain), for: .captureRegion)
        }
    }

    @Test("A refusal says what to do about it")
    func refusalHasARemedy() {
        let registry = HotkeyRegistry { _ in }
        defer { registry.unregisterAll() }

        do {
            try registry.register(
                Shortcut(key: .four, modifiers: .plain), for: .captureRegion)
            Issue.record("expected a refusal")
        } catch let error as HotkeyError {
            #expect(!error.remedy.isEmpty)
            #expect(error.code == HotkeyError.unacceptableCombination)
        } catch {
            Issue.record("expected a hotkey error, got \(error)")
        }
    }

    @Test("Every key has a number, and no two share one")
    func keyCodesAreDistinct() {
        let codes = ShortcutKey.allCases.map(HotkeyRegistry.keyCode(of:))
        #expect(Set(codes).count == codes.count)
    }

    @Test("The digits are the numbers the system uses for them")
    func digitKeyCodes() {
        #expect(HotkeyRegistry.keyCode(of: .a) == UInt32(kVK_ANSI_A))
        #expect(HotkeyRegistry.keyCode(of: .four) == UInt32(kVK_ANSI_4))
        #expect(HotkeyRegistry.keyCode(of: .five) == UInt32(kVK_ANSI_5))
        #expect(HotkeyRegistry.keyCode(of: .escape) == UInt32(kVK_Escape))
        #expect(HotkeyRegistry.keyCode(of: .space) == UInt32(kVK_Space))
    }

    @Test("Each modifier maps to its own bit")
    func modifiersAreDistinct() {
        let each: [Modifiers] = [.command, .shift, .option, .control]
        let values = each.map(HotkeyRegistry.carbonModifiers(of:))
        #expect(Set(values).count == values.count)
        #expect(values.allSatisfy { $0 != 0 })
    }

    @Test("Modifiers held together combine")
    func modifiersCombine() {
        let both = HotkeyRegistry.carbonModifiers(of: [.command, .shift])
        #expect(
            both == HotkeyRegistry.carbonModifiers(of: .command)
                | HotkeyRegistry.carbonModifiers(of: .shift))
    }

    @Test("No modifier at all is no bits at all")
    func noModifiers() {
        #expect(HotkeyRegistry.carbonModifiers(of: .plain) == 0)
    }

    @Test("Unregistering when nothing was registered is not a failure")
    func unregisterNothing() {
        let registry = HotkeyRegistry { _ in }
        registry.unregisterAll()
        registry.unregisterAll()
    }
}

@Suite(
    "Real hotkeys",
    .enabled(if: ProcessInfo.processInfo.environment["EKRANBILDO_REAL_HOTKEYS"] == "1"),
    .serialized
)
struct RealHotkeyTests {

    @Test("Every shortcut this product ships with can be registered")
    func defaultsRegister() throws {
        let registry = HotkeyRegistry { _ in }
        defer { registry.unregisterAll() }

        let actions: [(Shortcut, HotkeyAction)] = [
            (Shortcut.Defaults.captureRegion, .captureRegion),
            (Shortcut.Defaults.captureWindow, .captureWindow),
            (Shortcut.Defaults.captureScreen, .captureScreen),
            (Shortcut.Defaults.startRecording, .startRecording),
        ]
        for (shortcut, action) in actions {
            try registry.register(shortcut, for: action)
        }
    }

    @Test("This machine accepts shift and option alone")
    func systemAcceptsShiftAndOption() {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_8),
            UInt32(shiftKey) | UInt32(optionKey),
            EventHotKeyID(signature: 0x5445_5354, id: 1),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if let reference { UnregisterEventHotKey(reference) }
        #expect(
            status == noErr,
            "this machine refused shift and option alone; the caution can become a refusal"
        )
    }

    @Test("Registering twice without unregistering is refused")
    func twiceIsRefused() throws {
        let registry = HotkeyRegistry { _ in }
        defer { registry.unregisterAll() }

        try registry.register(Shortcut.Defaults.captureRegion, for: .captureRegion)
        #expect(throws: HotkeyError.self) {
            try registry.register(Shortcut.Defaults.captureRegion, for: .captureRegion)
        }
    }
}
