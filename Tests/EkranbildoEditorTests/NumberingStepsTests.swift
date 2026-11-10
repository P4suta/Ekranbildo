import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Numbering the steps")
struct NumberingStepsTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 600, height: 400)

    private func document(_ annotations: [Annotation] = []) -> Document {
        Document(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: annotations,
                style: .standard
            ),
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func annotation(_ id: UInt32, badge: BadgeNumber? = nil) -> Annotation {
        Annotation(
            id: AnnotationID(id),
            target: SceneRect(x: Double(id) * 40, y: 100, width: 30, height: 30),
            label: "Step",
            placement: nil,
            badge: badge
        )
    }

    private func badges(_ document: Document) -> [BadgeNumber?] {
        document.scene.annotations.map(\.badge)
    }

    @Test("Numbering an unnumbered one gives it the first number")
    func firstNumber() {
        var subject = document([annotation(1)])
        subject.apply([.number(AnnotationID(1))])
        #expect(badges(subject) == [BadgeNumber(1)])
    }

    @Test("The next one numbered carries on from the last")
    func carriesOn() {
        var subject = document([annotation(1), annotation(2), annotation(3)])
        subject.apply([.number(AnnotationID(2))])
        subject.apply([.number(AnnotationID(3))])
        subject.apply([.number(AnnotationID(1))])
        #expect(badges(subject) == [BadgeNumber(3), BadgeNumber(1), BadgeNumber(2)])
    }

    @Test("Numbering one does not renumber the others")
    func othersKeepTheirNumbers() {
        var subject = document([
            annotation(1, badge: BadgeNumber(1)),
            annotation(2, badge: BadgeNumber(2)),
            annotation(3),
        ])
        subject.apply([.number(AnnotationID(3))])
        #expect(badges(subject) == [BadgeNumber(1), BadgeNumber(2), BadgeNumber(3)])
    }

    @Test("Numbering one that already has a number takes the number away")
    func numberingTwiceRemovesIt() {
        var subject = document([annotation(1, badge: BadgeNumber(1))])
        subject.apply([.number(AnnotationID(1))])
        #expect(badges(subject) == [nil])
    }

    @Test("Taking a number away closes the gap it leaves")
    func closesTheGap() {
        var subject = document([
            annotation(1, badge: BadgeNumber(1)),
            annotation(2, badge: BadgeNumber(2)),
            annotation(3, badge: BadgeNumber(3)),
        ])
        subject.apply([.number(AnnotationID(2))])
        #expect(badges(subject) == [BadgeNumber(1), nil, BadgeNumber(2)])
    }

    @Test("Removing a numbered annotation closes the gap too")
    func removingClosesTheGap() {
        var subject = document([
            annotation(1, badge: BadgeNumber(1)),
            annotation(2, badge: BadgeNumber(2)),
            annotation(3, badge: BadgeNumber(3)),
        ])
        subject.apply([.removeAnnotations([AnnotationID(1)])])
        #expect(badges(subject) == [BadgeNumber(1), BadgeNumber(2)])
    }

    @Test("Numbering one that is not there changes nothing")
    func unknownAnnotation() {
        var subject = document([annotation(1)])
        subject.apply([.number(AnnotationID(9))])
        #expect(badges(subject) == [nil])
    }

    @Test("Numbering is a step that can be taken back")
    func undoable() {
        var subject = document([annotation(1)])
        subject.checkpoint()
        subject.apply([.number(AnnotationID(1))])
        subject.undo()
        #expect(badges(subject) == [nil])
    }

    @Test("The numbers are always one to however many there are")
    func alwaysContiguous() {
        var subject = document([annotation(1), annotation(2), annotation(3), annotation(4)])
        for id in [2, 4, 1] {
            subject.apply([.number(AnnotationID(UInt32(id)))])
        }
        subject.apply([.number(AnnotationID(4))])
        let given = badges(subject).compactMap { $0?.value }.sorted()
        #expect(given == Array(1...given.count))
    }
}

@Suite("Asking for a number")
struct AskingForANumberTests {

    private let interactor = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())

    private func selected(_ ids: [AnnotationID]) -> EditorState {
        var state = EditorState(scene: SceneLibrary.sampleAnnotated)
        state.selection = ids
        return state
    }

    @Test("Asking numbers what is selected")
    func numbersTheSelection() {
        let outcome = interactor.handle(.typed("n"), in: selected([AnnotationID(1)]))
        #expect(outcome.commands == [.number(AnnotationID(1))])
        #expect(outcome.effects.contains(.checkpoint))
    }

    @Test("Asking with several selected numbers all of them, in the order they were chosen")
    func numbersSeveral() {
        let outcome = interactor.handle(
            .typed("n"), in: selected([AnnotationID(2), AnnotationID(1)]))
        #expect(outcome.commands == [.number(AnnotationID(2)), .number(AnnotationID(1))])
    }

    @Test("Asking with nothing selected does nothing")
    func nothingSelected() {
        #expect(interactor.handle(.typed("n"), in: selected([])).commands.isEmpty)
    }

    @Test("An n typed into a name is part of the name")
    func nInsideAName() {
        var state = selected([AnnotationID(1)])
        state.typing = Typing(annotation: AnnotationID(1), text: "Ope", wasNamed: nil)
        let outcome = interactor.handle(.typed("n"), in: state)
        #expect(outcome.state.typing?.text == "Open")
        #expect(!outcome.commands.contains { if case .number = $0 { true } else { false } })
    }
}
