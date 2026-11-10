import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
@testable import EkranbildoViews
import Testing

@Suite("The keys a canvas answers to", .serialized)
@MainActor
struct CanvasKeyTests {

    private func canvas() -> (view: CanvasView, sent: Sent) {
        let view = CanvasView(scene: SceneLibrary.sampleAnnotated)
        let sent = Sent()
        view.send = { sent.events.append($0) }
        return (view, sent)
    }

    private final class Sent {
        var events: [InputEvent] = []
    }

    private func press(
        _ characters: String,
        code: UInt16 = 0,
        _ flags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: code
            )
        )
    }

    @Test("Command and Z is an undo")
    func undo() throws {
        let (view, sent) = canvas()
        #expect(view.performKeyEquivalent(with: try press("z", .command)))
        #expect(sent.events == [.undo])
    }

    @Test("Command and shift and Z is a redo")
    func redo() throws {
        let (view, sent) = canvas()
        #expect(view.performKeyEquivalent(with: try press("z", [.command, .shift])))
        #expect(sent.events == [.redo])
    }

    @Test("Command and Y is a redo too")
    func redoTheOtherWay() throws {
        let (view, sent) = canvas()
        #expect(view.performKeyEquivalent(with: try press("y", .command)))
        #expect(sent.events == [.redo])
    }

    @Test(
        "A command key that is not one of these is left alone",
        arguments: ["c", "v", "q", "w", "a"]
    )
    func otherCommandKeys(_ character: String) throws {
        let (view, sent) = canvas()
        #expect(!view.performKeyEquivalent(with: try press(character, .command)))
        #expect(sent.events.isEmpty)
    }

    @Test("A Z with no command is not an undo")
    func plainZ() throws {
        let (view, sent) = canvas()
        #expect(!view.performKeyEquivalent(with: try press("z")))
        #expect(sent.events.isEmpty)
    }

    @Test(
        "A digit is a character, whatever it may go on to mean",
        arguments: [("1", UInt16(18)), ("2", UInt16(19)), ("3", UInt16(20)), ("9", UInt16(25))]
    )
    func digitsAreCharacters(_ character: String, _ code: UInt16) throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press(character, code: code))
        #expect(sent.events == [.typed(character)])
    }
}

@Suite("What the canvas does with ordinary typing", .serialized)
@MainActor
struct CanvasTypingTests {

    private func canvas() -> (view: CanvasView, sent: Sent) {
        let view = CanvasView(scene: SceneLibrary.sampleAnnotated)
        let sent = Sent()
        view.send = { sent.events.append($0) }
        return (view, sent)
    }

    private final class Sent {
        var events: [InputEvent] = []
    }

    private func press(
        _ characters: String,
        code: UInt16 = 0,
        _ flags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: code
            )
        )
    }

    @Test(
        "Letters, digits and punctuation reach the editor as what was typed",
        arguments: ["a", "Z", "7", " ", ".", "-"]
    )
    func ordinaryCharacters(_ character: String) throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press(character, code: 99))
        #expect(sent.events == [.typed(character)])
    }

    @Test(
        "Characters outside the Latin alphabet arrive whole",
        arguments: ["日", "ひらがな", "é", "🙂"]
    )
    func otherAlphabets(_ character: String) throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press(character, code: 99))
        #expect(sent.events == [.typed(character)])
    }

    @Test("A command key is not typing")
    func commandIsNotTyping() throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press("a", code: 99, .command))
        #expect(sent.events.isEmpty)
    }

    @Test("An arrow key is not a character to put in a label")
    func arrowsAreNotCharacters() throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press("\u{F702}", code: 123))
        #expect(sent.events == [.key(.arrowLeft, [])])
    }

    @Test(
        "Return and the keypad's enter both finish what is being typed",
        arguments: [UInt16(36), UInt16(76)]
    )
    func returnFinishes(_ code: UInt16) throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press("\r", code: code))
        #expect(sent.events == [.key(.enter, [])])
    }

    @Test("Tab finishes it too")
    func tabFinishes() throws {
        let (view, sent) = canvas()
        view.keyDown(with: try press("\t", code: 48))
        #expect(sent.events == [.key(.tab, [])])
    }
}
