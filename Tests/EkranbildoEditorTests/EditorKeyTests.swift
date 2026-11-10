import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Editor keys and tools")
struct EditorKeyTests {

    @Test("Delete removes what is selected")
    func deletes() {
        var start = EditorFixture.state(2)
        start.selection = [AnnotationID(2)]
        let outcome = EditorFixture.after([.key(.delete, .plain)], from: start)
        #expect(outcome.commands.contains(.removeAnnotations([AnnotationID(2)])))
        #expect(outcome.commands.contains(.solve))
        #expect(outcome.state.selection.isEmpty)
    }

    @Test("Delete with nothing selected does nothing at all")
    func deleteNothing() {
        let outcome = EditorFixture.after([.key(.delete, .plain)], from: EditorFixture.state(2))
        #expect(outcome.commands.isEmpty)
        #expect(outcome.effects.isEmpty)
    }

    @Test("Escape clears the selection and abandons a drag")
    func escape() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [
                .pointerDown(from, .plain),
                .pointerMoved(ScenePoint(x: from.x + 40, y: from.y), .plain),
                .key(.escape, .plain),
            ],
            from: start
        )
        #expect(outcome.state.drag == .idle)
        #expect(outcome.state.selection.isEmpty)
        #expect(
            !outcome.commands.contains { if case .moveTarget = $0 { return true } else { return false } },
            "an abandoned drag must not move anything"
        )
    }

    @Test("Arrow keys nudge the selection")
    func nudges() {
        var start = EditorFixture.state()
        start.selection = [AnnotationID(1)]
        let outcome = EditorFixture.after([.key(.arrowRight, .plain)], from: start)

        guard case .moveTarget(_, let rect) = outcome.commands.first else {
            Issue.record("expected a nudge: \(outcome.commands)")
            return
        }
        #expect(rect.minX == start.scene.annotations[0].target.minX + 1)
    }

    @Test("Shift nudges further")
    func nudgesFurther() {
        var start = EditorFixture.state()
        start.selection = [AnnotationID(1)]
        let outcome = EditorFixture.after([.key(.arrowRight, .shift)], from: start)

        guard case .moveTarget(_, let rect) = outcome.commands.first else {
            Issue.record("expected a nudge: \(outcome.commands)")
            return
        }
        #expect(rect.minX > start.scene.annotations[0].target.minX + 1)
    }

    @Test("Changing tool abandons whatever was in progress")
    func toolChangeAbandonsDrag() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [
                .pointerDown(from, .plain),
                .pointerMoved(ScenePoint(x: from.x + 40, y: from.y), .plain),
                .toolSelected(.redact),
            ],
            from: start
        )
        #expect(outcome.state.tool == .redact)
        #expect(outcome.state.drag == .idle)
    }

    @Test("Moving the pointer says what is under it")
    func hovers() {
        let start = EditorFixture.state()
        let outcome = EditorFixture.after(
            [.pointerMoved(EditorFixture.targetCentre(start), .plain)], from: start)
        #expect(outcome.state.hovered == .target(AnnotationID(1)))
    }

    @Test("Moving over nothing says nothing")
    func hoversNothing() {
        let outcome = EditorFixture.after(
            [.pointerMoved(ScenePoint(x: 10, y: 280), .plain)], from: EditorFixture.state())
        #expect(outcome.state.hovered == HitResult.nothing)
    }

    @Test("Nothing is hovered while something is being dragged")
    func noHoverWhileDragging() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [.pointerDown(from, .plain), .pointerMoved(ScenePoint(x: from.x + 20, y: from.y), .plain)],
            from: start
        )
        #expect(outcome.state.hovered == HitResult.nothing)
    }

    @Test("Replaying the same events gives the same state")
    func reproducible() {
        let start = EditorFixture.state(2)
        let from = EditorFixture.targetCentre(start)
        let events: [InputEvent] = [
            .pointerDown(from, .plain),
            .pointerMoved(ScenePoint(x: from.x + 25, y: from.y + 5), .plain),
            .pointerUp(ScenePoint(x: from.x + 25, y: from.y + 5), .plain),
            .key(.arrowRight, .shift),
        ]
        #expect(isReproducible { EditorFixture.after(events, from: start).state })
    }

    @Test("An event with nothing to act on changes nothing")
    func unexpectedEvents() {
        let start = EditorFixture.state()
        for event in [
            InputEvent.pointerUp(ScenePoint(x: 50, y: 50), .plain),
            .pointerExited,
            .typed("hello"),
            .key(.enter, .plain),
        ] {
            let outcome = EditorFixture.interactor.handle(event, in: start)
            #expect(outcome.commands.isEmpty, "\(event) produced \(outcome.commands)")
        }
    }
}
