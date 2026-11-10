import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoGeometry
import Testing

@Suite("Editor interactor")
struct InteractorTests {

    @Test("Clicking something selects it")
    func selects() {
        let start = EditorFixture.state(2)
        let outcome = EditorFixture.after(
            [.pointerDown(EditorFixture.targetCentre(start), .plain)], from: start)
        #expect(outcome.state.selection == [AnnotationID(1)])
    }

    @Test("Clicking empty space clears the selection")
    func clearsSelection() {
        var start = EditorFixture.state(2)
        start.selection = [AnnotationID(1)]
        let outcome = EditorFixture.after([.pointerDown(ScenePoint(x: 10, y: 280), .plain)], from: start)
        #expect(outcome.state.selection.isEmpty)
    }

    @Test("Shift-clicking adds to the selection, in order")
    func addsToSelection() {
        let start = EditorFixture.state(3)
        let outcome = EditorFixture.after(
            [
                .pointerDown(EditorFixture.targetCentre(start, 2), .plain),
                .pointerUp(EditorFixture.targetCentre(start, 2), .plain),
                .pointerDown(EditorFixture.targetCentre(start, 0), .shift),
                .pointerUp(EditorFixture.targetCentre(start, 0), .shift),
            ],
            from: start
        )
        #expect(outcome.state.selection == [AnnotationID(3), AnnotationID(1)])
    }

    @Test("Shift-clicking something already selected takes it out again")
    func togglesSelection() {
        var start = EditorFixture.state(2)
        start.selection = [AnnotationID(1), AnnotationID(2)]
        let outcome = EditorFixture.after(
            [.pointerDown(EditorFixture.targetCentre(start), .shift)], from: start)
        #expect(outcome.state.selection == [AnnotationID(2)])
    }

    @Test("Pressing inside a multiple selection keeps it")
    func keepsMultipleSelection() {
        var start = EditorFixture.state(2)
        start.selection = [AnnotationID(1), AnnotationID(2)]
        let outcome = EditorFixture.after(
            [.pointerDown(EditorFixture.targetCentre(start), .plain)], from: start)
        #expect(outcome.state.selection == [AnnotationID(1), AnnotationID(2)])
    }

    @Test("Dragging a target moves what the annotation points at")
    func movesTarget() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [
                .pointerDown(from, .plain),
                .pointerMoved(ScenePoint(x: from.x + 30, y: from.y + 10), .plain),
                .pointerUp(ScenePoint(x: from.x + 30, y: from.y + 10), .plain),
            ],
            from: start
        )

        guard
            case .moveTarget(let id, let rect) = outcome.commands.first(where: {
                if case .moveTarget = $0 { return true }
                return false
            })
        else {
            Issue.record("expected the target to move: \(outcome.commands)")
            return
        }
        #expect(id == AnnotationID(1))
        #expect(rect.minX == start.scene.annotations[0].target.minX + 30)
        #expect(rect.minY == start.scene.annotations[0].target.minY + 10)
    }

    @Test("Moving a target asks for the layout again")
    func resolvesAfterMove() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [
                .pointerDown(from, .plain),
                .pointerMoved(ScenePoint(x: from.x + 30, y: from.y), .plain),
                .pointerUp(ScenePoint(x: from.x + 30, y: from.y), .plain),
            ],
            from: start
        )
        #expect(outcome.commands.contains(.solve))
        #expect(outcome.effects.contains(.checkpoint))
    }

    @Test("A click is not a drag")
    func clickIsNotADrag() {
        let start = EditorFixture.state()
        let point = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [.pointerDown(point, .plain), .pointerUp(point, .plain)], from: start)
        #expect(outcome.commands.isEmpty)
        #expect(outcome.effects.isEmpty)
        #expect(outcome.state.drag == .idle)
    }

    @Test("A click that wobbles is still a click")
    func wobbleIsNotADrag() {
        let start = EditorFixture.state()
        let point = EditorFixture.targetCentre(start)
        let nudged = ScenePoint(x: point.x + 1, y: point.y + 1)
        let outcome = EditorFixture.after(
            [.pointerDown(point, .plain), .pointerMoved(nudged, .plain), .pointerUp(nudged, .plain)],
            from: start
        )
        #expect(outcome.commands.isEmpty)
        #expect(outcome.effects.isEmpty)
    }

    @Test("The pointer leaving does not end a drag")
    func exitDoesNotEndDrag() {
        let start = EditorFixture.state()
        let from = EditorFixture.targetCentre(start)
        let outcome = EditorFixture.after(
            [
                .pointerDown(from, .plain),
                .pointerMoved(ScenePoint(x: from.x + 20, y: from.y), .plain),
                .pointerExited,
            ],
            from: start
        )
        #expect(outcome.state.isDragging)
    }

    @Test("Dragging from empty space sweeps a marquee")
    func marquee() {
        let start = EditorFixture.state(2)
        let outcome = EditorFixture.after(
            [
                .pointerDown(ScenePoint(x: 20, y: 260), .plain),
                .pointerMoved(ScenePoint(x: 260, y: 100), .plain),
            ],
            from: start
        )
        guard case .marquee(let from, let to) = outcome.state.drag else {
            Issue.record("expected a marquee: \(outcome.state.drag)")
            return
        }
        #expect(from == ScenePoint(x: 20, y: 260))
        #expect(to == ScenePoint(x: 260, y: 100))
    }

    @Test("A marquee selects everything it swept over")
    func marqueeSelects() {
        let start = EditorFixture.state(3)
        let outcome = EditorFixture.after(
            [
                .pointerDown(ScenePoint(x: 20, y: 260), .plain),
                .pointerMoved(ScenePoint(x: 220, y: 100), .plain),
                .pointerUp(ScenePoint(x: 220, y: 100), .plain),
            ],
            from: start
        )
        #expect(outcome.state.selection == [AnnotationID(1), AnnotationID(2)])
        #expect(outcome.state.drag == .idle)
    }

    @Test("With the annotate tool, dragging places a new annotation")
    func placesAnnotation() {
        let start = EditorFixture.state(0, tool: .annotate)
        let outcome = EditorFixture.after(
            [
                .pointerDown(ScenePoint(x: 100, y: 100), .plain),
                .pointerMoved(ScenePoint(x: 160, y: 130), .plain),
                .pointerUp(ScenePoint(x: 160, y: 130), .plain),
            ],
            from: start
        )
        guard case .addAnnotation(let target, _) = outcome.commands.first else {
            Issue.record("expected an annotation: \(outcome.commands)")
            return
        }
        #expect(target == SceneRect(x: 100, y: 100, width: 60, height: 30))
        #expect(outcome.commands.contains(.solve))
    }

    @Test("Placing backwards gives the same rectangle")
    func placesBackwards() {
        let start = EditorFixture.state(0, tool: .annotate)
        let outcome = EditorFixture.after(
            [
                .pointerDown(ScenePoint(x: 160, y: 130), .plain),
                .pointerMoved(ScenePoint(x: 100, y: 100), .plain),
                .pointerUp(ScenePoint(x: 100, y: 100), .plain),
            ],
            from: start
        )
        guard case .addAnnotation(let target, _) = outcome.commands.first else {
            Issue.record("expected an annotation: \(outcome.commands)")
            return
        }
        #expect(target == SceneRect(x: 100, y: 100, width: 60, height: 30))
    }

    @Test("A tap with the annotate tool still points at something")
    func tapPlaces() {
        let start = EditorFixture.state(0, tool: .annotate)
        let point = ScenePoint(x: 120, y: 120)
        let outcome = EditorFixture.after(
            [.pointerDown(point, .plain), .pointerUp(point, .plain)], from: start)
        guard case .addAnnotation(let target, _) = outcome.commands.first else {
            Issue.record("expected an annotation: \(outcome.commands)")
            return
        }
        #expect(target.raw.contains(point.raw))
        #expect(target.raw.width > 0)
    }
}
