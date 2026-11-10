import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import Testing

@Suite("A label with nothing in it yet")
struct AnEmptyLabelTests {

    private static func scene(label: String) -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 180, y: 140, width: 40, height: 40),
                    label: label,
                    placement: Placement(direction: .ne, leaderLength: 60)
                )
            ],
            style: .standard
        )
    }

    private func commands(_ label: String) -> [DrawCommand] {
        DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
            .build(Self.scene(label: label))
            .commands
    }

    private func plates(_ label: String) -> [SceneRect] {
        commands(label).compactMap { command -> SceneRect? in
            guard case .fill(let path, _) = command else { return nil }
            return path.bounds
        }
    }

    @Test("It still has somewhere for the words to go")
    func emptyStillHasAPlate() throws {
        let empty = try #require(plates("").last)
        #expect(empty.width > 0)
        #expect(empty.height > 0)
    }

    @Test("It is about as tall as a label with words in it")
    func asTallAsANamedOne() throws {
        let empty = try #require(plates("").last)
        let named = try #require(plates("Save").last)
        #expect(empty.height == named.height)
    }

    @Test("The arrow is drawn whether or not it has been named")
    func theArrowIsThere() {
        #expect(commands("").contains { if case .stroke = $0 { true } else { false } })
    }
}
