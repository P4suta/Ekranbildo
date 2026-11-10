import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Picking a tool from the keyboard")
struct ToolShortcutTests {

    private let interactor = EditorInteractor(measurer: TabulatedTextMeasurer.uniform())

    private func state(_ tool: ToolID = .select) -> EditorState {
        var state = EditorState(scene: SceneLibrary.sampleAnnotated)
        state.tool = tool
        return state
    }

    private func after(_ typed: String, from tool: ToolID = .select) -> EditorState {
        interactor.handle(.typed(typed), in: state(tool)).state
    }

    @Test(
        "A number picks the tool in that place in the toolbar",
        arguments: [("1", ToolID.select), ("2", .annotate), ("3", .redact)]
    )
    func numbersPickTools(_ typed: String, _ tool: ToolID) {
        #expect(after(typed, from: .redact).tool == tool)
    }

    @Test("Picking the tool already in hand changes nothing")
    func sameTool() {
        #expect(after("1", from: .select).tool == .select)
    }

    @Test("A number no tool answers to leaves the tool alone")
    func otherNumbers() {
        #expect(after("9", from: .redact).tool == .redact)
    }

    @Test("A letter is not a tool")
    func letters() {
        #expect(after("a", from: .redact).tool == .redact)
    }

    @Test("Picking a tool abandons what the last one had started")
    func abandonsWhatWasInProgress() {
        var start = state(.annotate)
        start.drag = .placing(from: ScenePoint(x: 10, y: 10), to: ScenePoint(x: 40, y: 40))
        #expect(interactor.handle(.typed("2"), in: start).state.drag == .idle)
    }

    @Test(
        "A number typed into a name is part of the name",
        arguments: ["1", "2", "3"]
    )
    func numbersInsideAName(_ digit: String) {
        var start = state(.select)
        start.typing = Typing(annotation: AnnotationID(1), text: "Step ", wasNamed: nil)
        let after = interactor.handle(.typed(digit), in: start).state
        #expect(after.typing?.text == "Step \(digit)")
        #expect(after.tool == .select)
    }

    @Test("Picking a tool from the keyboard asks for nothing to be drawn again")
    func noCommands() {
        #expect(interactor.handle(.typed("2"), in: state()).commands.isEmpty)
    }
}
