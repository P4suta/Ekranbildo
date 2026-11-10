import EkranbildoContracts
import EkranbildoGeometry
import Testing

@Suite("What handles an event")
struct WhatHandlesAnEventTests {

    @Test("Undo and redo are the history's business, not the editor's")
    func history() {
        #expect(InputEvent.undo.handledBy == .history(.back))
        #expect(InputEvent.redo.handledBy == .history(.forward))
    }

    @Test(
        "Everything else is the editor's",
        arguments: [
            InputEvent.pointerDown(ScenePoint(x: 0, y: 0), []),
            .pointerMoved(ScenePoint(x: 0, y: 0), []),
            .pointerUp(ScenePoint(x: 0, y: 0), []),
            .pointerExited,
            .key(.escape, []),
            .typed("a"),
            .toolSelected(.select),
            .widen,
        ])
    func editor(_ event: InputEvent) {
        #expect(event.handledBy == .theEditor)
    }

    @Test("An arrow says which way it points, and nothing else does")
    func arrows() {
        #expect(KeyCode.arrowUp.arrow == .up)
        #expect(KeyCode.arrowDown.arrow == .down)
        #expect(KeyCode.arrowLeft.arrow == .left)
        #expect(KeyCode.arrowRight.arrow == .right)
        for key in [KeyCode.escape, .delete, .enter, .tab] {
            #expect(key.arrow == nil, "\(key) is not an arrow")
        }
    }

    @Test("Each arrow moves one step its own way")
    func steps() {
        let step = 4.0
        #expect(Arrow.up.step(step) == P2(x: 0, y: -step))
        #expect(Arrow.down.step(step) == P2(x: 0, y: step))
        #expect(Arrow.left.step(step) == P2(x: -step, y: 0))
        #expect(Arrow.right.step(step) == P2(x: step, y: 0))
    }

    @Test("No two arrows move the same way")
    func arrowsDiffer() {
        let moves = Arrow.allCases.map { $0.step(1) }
        for (place, move) in moves.enumerated() {
            #expect(!moves[(place + 1)...].contains(move))
        }
    }
}
