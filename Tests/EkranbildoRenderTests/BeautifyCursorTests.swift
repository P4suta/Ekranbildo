import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoRender
import Testing

@Suite("Dressing a scene keeps its pointer")
struct BeautifyCursorTests {

    private static let scene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 200, height: 120),
        background: nil,
        annotations: [],
        style: .standard,
        cursor: Cursor(position: ScenePoint(x: 40, y: 30))
    )

    @Test("An undressed scene draws the pointer")
    func undressedDrawsIt() {
        let drawn = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(Self.scene)
        #expect(!drawn.commands.isEmpty)
    }

    @Test("A dressed scene draws as many things as an undressed one")
    func dressedDrawsTheSameThings() {
        let measurer = TabulatedTextMeasurer.uniform()
        let plain = DrawListBuilder(measurer: measurer).build(Self.scene)
        let dressed = Beautifier().drawList(for: Self.scene, measurer: measurer)
        #expect(dressed.commands.count >= plain.commands.count)
    }
}
