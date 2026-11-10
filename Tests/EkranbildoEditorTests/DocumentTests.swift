import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Document")
struct DocumentTests {

    private func document(_ count: Int = 2) -> Document {
        Document(scene: EditorFixture.scene(count), measurer: TabulatedTextMeasurer.uniform())
    }

    private func target(_ index: Int) -> SceneRect {
        SceneRect(x: 40 + Double(index) * 90, y: 200, width: 30, height: 16)
    }

    @Test("Adding an annotation puts it in the scene")
    func adds() {
        var subject = document(0)
        subject.apply([.addAnnotation(target: target(0), label: "New")])
        #expect(subject.scene.annotations.count == 1)
        #expect(subject.scene.annotations[0].label == "New")
    }

    @Test("A new annotation arrives without a placement and leaves with one")
    func solves() {
        var subject = document(0)
        subject.apply([.addAnnotation(target: target(0), label: "New"), .solve])
        #expect(subject.scene.annotations[0].placement != nil)
    }

    @Test("Removing an annotation takes it out")
    func removes() {
        var subject = document(2)
        subject.apply([.removeAnnotations([AnnotationID(1)])])
        #expect(subject.scene.annotations.map(\.id) == [AnnotationID(2)])
    }

    @Test("Removing one annotation does not renumber the others")
    func doesNotRenumber() {
        var subject = document(3)
        subject.apply([.removeAnnotations([AnnotationID(2)]), .solve])
        #expect(subject.scene.annotations.map(\.id) == [AnnotationID(1), AnnotationID(3)])
    }

    @Test("Moving a target moves it")
    func moves() {
        var subject = document(1)
        subject.apply([.moveTarget(AnnotationID(1), to: target(5))])
        #expect(subject.scene.annotations[0].target == target(5))
    }

    @Test("A command about an annotation that is not there changes nothing")
    func unknownAnnotation() {
        var subject = document(1)
        let before = subject.scene
        subject.apply([.moveTarget(AnnotationID(99), to: target(0))])
        #expect(subject.scene == before)
    }

    @Test("A new annotation after a deletion gets a number nobody is using")
    func numbersAfterDeletion() {
        var subject = document(3)
        subject.apply([.removeAnnotations([AnnotationID(1)])])
        subject.apply([.addAnnotation(target: target(0), label: "New")])

        let ids = subject.scene.annotations.map(\.id)
        #expect(Set(ids).count == ids.count, "a number was handed out twice: \(ids)")
        #expect(ids.contains(AnnotationID(4)))
    }

    @Test("A placement made by hand survives the solver")
    func keepsHandPlacement() {
        var subject = document(0)
        subject.apply([.addAnnotation(target: target(0), label: "Mine"), .solve])
        let chosen = Placement(direction: .sw, leaderLength: 96)
        subject.apply([.setPlacement(AnnotationID(1), chosen)])

        subject.apply([.addAnnotation(target: target(2), label: "Other"), .solve])
        #expect(subject.scene.annotations[0].placement == chosen)
    }

    @Test("Undo puts back what was there before")
    func undoes() {
        var subject = document(1)
        let before = subject.scene
        subject.checkpoint()
        subject.apply([.addAnnotation(target: target(0), label: "New"), .solve])

        #expect(subject.canUndo)
        subject.undo()
        #expect(subject.scene == before)
    }

    @Test("Redo puts it back again")
    func redoes() {
        var subject = document(1)
        subject.checkpoint()
        subject.apply([.addAnnotation(target: target(0), label: "New"), .solve])
        let after = subject.scene

        subject.undo()
        #expect(subject.canRedo)
        subject.redo()
        #expect(subject.scene == after)
    }

    @Test("Doing something new after undoing abandons the redo")
    func newWorkAbandonsRedo() {
        var subject = document(1)
        subject.checkpoint()
        subject.apply([.addAnnotation(target: target(0), label: "First")])
        subject.undo()

        subject.checkpoint()
        subject.apply([.addAnnotation(target: target(1), label: "Second")])
        #expect(!subject.canRedo)
        #expect(subject.scene.annotations.contains { $0.label == "Second" })
    }

    @Test("Undo with nothing to undo does nothing")
    func undoNothing() {
        var subject = document(1)
        let before = subject.scene
        #expect(!subject.canUndo)
        subject.undo()
        #expect(subject.scene == before)
    }

    @Test("The history has a limit, and it is the oldest step that goes")
    func historyIsBounded() {
        var subject = Document(
            scene: EditorFixture.scene(0),
            measurer: TabulatedTextMeasurer.uniform(),
            historyLimit: 3
        )
        for index in 0..<6 {
            subject.checkpoint()
            subject.apply([.addAnnotation(target: target(index), label: "Step \(index)")])
        }
        var undone = 0
        while subject.canUndo {
            subject.undo()
            undone += 1
        }
        #expect(undone == 3)
        #expect(subject.scene.annotations.count == 3)
    }

    @Test("Applying the same commands gives the same scene")
    func reproducible() {
        let commands: [EditorCommand] = [
            .addAnnotation(target: target(0), label: "One"),
            .addAnnotation(target: target(1), label: "Two"),
            .solve,
        ]
        #expect(
            isReproducible {
                var subject = self.document(0)
                subject.apply(commands)
                return subject.scene
            }
        )
    }
}

@Suite("Badges through editing")
struct BadgeEditingTests {

    private func document() -> Document {
        Document(
            scene: Scene(
                canvas: EditorFixture.canvas,
                background: nil,
                annotations: [
                    Annotation(
                        id: AnnotationID(1),
                        target: SceneRect(x: 100, y: 140, width: 30, height: 20),
                        label: "First",
                        placement: Placement(direction: .n, leaderLength: 40),
                        badge: BadgeNumber(7)
                    )
                ],
                style: .standard
            ),
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    @Test("Moving what a step points at keeps its number")
    func moving() {
        var subject = document()
        subject.apply([
            .moveTarget(AnnotationID(1), to: SceneRect(x: 200, y: 60, width: 30, height: 20)),
            .solve,
        ])
        #expect(subject.scene.annotations[0].badge == BadgeNumber(7))
    }

    @Test("Renaming a step keeps its number")
    func renaming() {
        var subject = document()
        subject.apply([.setLabel(AnnotationID(1), "Renamed")])
        #expect(subject.scene.annotations[0].badge == BadgeNumber(7))
    }

    @Test("Placing a step by hand keeps its number")
    func placing() {
        var subject = document()
        subject.apply([.setPlacement(AnnotationID(1), Placement(direction: .sw, leaderLength: 80))])
        #expect(subject.scene.annotations[0].badge == BadgeNumber(7))
    }

    @Test("Undo puts the number back with everything else")
    func undo() {
        var subject = document()
        subject.checkpoint()
        subject.apply([.removeAnnotations([AnnotationID(1)])])
        subject.undo()
        #expect(subject.scene.annotations[0].badge == BadgeNumber(7))
    }
}
