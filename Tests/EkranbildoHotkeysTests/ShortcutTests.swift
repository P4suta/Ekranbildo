import EkranbildoContracts
@testable import EkranbildoHotkeys
import EkranbildoTestKit
import Testing

@Suite("Shortcuts")
struct ShortcutTests {

    @Test("A shortcut with command is allowed")
    func withCommand() {
        #expect(Shortcut(key: .four, modifiers: [.command, .shift]).refusalReason == nil)
    }

    @Test("A shortcut with control is allowed")
    func withControl() {
        #expect(Shortcut(key: .four, modifiers: [.control]).refusalReason == nil)
    }

    @Test(
        "A shortcut with only shift or option is cautioned about",
        arguments: [
            Modifiers.shift,
            Modifiers.option,
            [Modifiers.shift, Modifiers.option],
        ]
    )
    func shiftAndOptionAlone(modifiers: Modifiers) {
        let shortcut = Shortcut(key: .four, modifiers: modifiers)
        #expect(shortcut.refusalReason == nil)
        let caution = shortcut.cautionReason
        #expect(caution != nil)
        #expect(caution?.contains("command") == true || caution?.contains("control") == true)
    }

    @Test("A shortcut with command or control is not cautioned about")
    func noCaution() {
        #expect(Shortcut(key: .four, modifiers: [.command]).cautionReason == nil)
        #expect(Shortcut(key: .four, modifiers: [.control, .shift]).cautionReason == nil)
    }

    @Test("A shortcut with no modifier at all is refused")
    func noModifier() {
        #expect(Shortcut(key: .four, modifiers: .plain).refusalReason != nil)
    }

    @Test("A refused shortcut says so before anybody tries to use it")
    func refusedIsNotUsable() {
        #expect(!Shortcut(key: .four, modifiers: .plain).isUsable)
        #expect(Shortcut(key: .four, modifiers: [.command, .shift]).isUsable)
    }

    @Test("A shortcut reads the way it is written on a menu")
    func displayed() {
        #expect(Shortcut(key: .four, modifiers: [.command, .shift]).displayed == "⇧⌘4")
        #expect(Shortcut(key: .five, modifiers: [.control, .option]).displayed == "⌃⌥5")
    }

    @Test("Modifiers are shown in the order a menu shows them")
    func modifierOrder() {
        let all = Shortcut(key: .four, modifiers: [.command, .option, .control, .shift])
        #expect(all.displayed == "⌃⌥⇧⌘4")
    }

    @Test("A shortcut survives a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(Shortcut(key: .five, modifiers: [.command, .shift])))
    }

    @Test("Every default shortcut works everywhere, with nothing to warn about")
    func defaultsAreUsable() {
        for shortcut in Shortcut.Defaults.all {
            #expect(shortcut.isUsable, "\(shortcut.displayed) cannot be registered")
            #expect(shortcut.cautionReason == nil, "\(shortcut.displayed) needs a warning")
        }
    }

    @Test("No two defaults are the same")
    func defaultsAreDistinct() {
        let all = Shortcut.Defaults.all
        #expect(Set(all).count == all.count)
    }
}
