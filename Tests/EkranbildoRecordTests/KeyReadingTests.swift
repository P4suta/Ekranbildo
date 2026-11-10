import EkranbildoContracts
@testable import EkranbildoRecord
import Testing

@Suite("Reading a key press")
struct KeyReadingTests {

    @Test("A letter reads as the letter, in capitals")
    func letter() {
        #expect(KeyWatcher.cap(for: "a", keyCode: KeyWatcher.Codes.unnamed) == "A")
    }

    @Test(
        "A key with a name of its own reads as its symbol",
        arguments: [
            (KeyWatcher.Codes.enter, "⏎"),
            (KeyWatcher.Codes.delete, "⌫"),
            (KeyWatcher.Codes.escape, "⎋"),
            (KeyWatcher.Codes.tab, "⇥"),
            (KeyWatcher.Codes.space, "␣"),
            (KeyWatcher.Codes.leftArrow, "←"),
            (KeyWatcher.Codes.rightArrow, "→"),
            (KeyWatcher.Codes.upArrow, "↑"),
            (KeyWatcher.Codes.downArrow, "↓"),
        ])
    func named(_ code: Int64, _ symbol: String) {
        #expect(KeyWatcher.cap(for: "", keyCode: code) == symbol)
    }

    @Test("A key that types nothing and has no name is not shown at all")
    func unknown() {
        #expect(KeyWatcher.cap(for: "", keyCode: KeyWatcher.Codes.unnamed) == nil)
    }

    @Test("What was typed is never shown, only which key was hit")
    func passwordsAreNotSpelledOut() {
        #expect(KeyWatcher.cap(for: "•", keyCode: KeyWatcher.Codes.unnamed) == "•")
    }

    @Test("Modifiers are read from the flags, not guessed")
    func modifiers() {
        #expect(KeyWatcher.modifiers(from: []).isEmpty)
        #expect(KeyWatcher.modifiers(from: .maskCommand) == [.command])
        #expect(
            KeyWatcher.modifiers(from: [.maskCommand, .maskShift, .maskAlternate, .maskControl])
                == [.command, .shift, .option, .control])
    }

    @Test("Caps lock and the function key are not modifiers anybody wants to see")
    func ignoredFlags() {
        #expect(KeyWatcher.modifiers(from: [.maskAlphaShift, .maskSecondaryFn]).isEmpty)
    }
}
