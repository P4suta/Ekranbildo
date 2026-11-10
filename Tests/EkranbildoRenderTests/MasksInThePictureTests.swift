import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import Testing

@Suite("What is hidden is hidden in the picture")
struct MasksInThePictureTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    private static let hidden = SceneRect(x: 50, y: 40, width: 120, height: 60)

    private static func scene(masks: [Mask]) -> Scene {
        Scene(
            canvas: canvas,
            background: ImageRef(contentHash: "picture", pixelWidth: 400, pixelHeight: 300),
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 300, y: 200, width: 30, height: 30),
                    label: "Elsewhere",
                    placement: Placement(direction: .e, leaderLength: 40)
                )
            ],
            style: .standard,
            masks: masks
        )
    }

    private func commands(_ masks: [Mask]) -> [DrawCommand] {
        DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
            .build(Self.scene(masks: masks))
            .commands
    }

    private static func index(of rect: SceneRect, in commands: [DrawCommand]) -> Int? {
        commands.firstIndex { command in
            switch command {
            case .fill(let path, _): path.bounds == rect
            case .image(_, let placed, _, _): placed == rect
            default: false
            }
        }
    }

    @Test("Nothing hidden draws no masks")
    func nothingHidden() {
        #expect(Self.index(of: Self.hidden, in: commands([])) == nil)
    }

    @Test("Something hidden is drawn over")
    func somethingHidden() {
        let drawn = commands([Mask(rect: Self.hidden, style: .pixelate)])
        #expect(Self.index(of: Self.hidden, in: drawn) != nil)
    }

    @Test("It goes over the picture and under what was written about it")
    func inTheRightOrder() throws {
        let drawn = commands([Mask(rect: Self.hidden, style: .pixelate)])
        let picture = try #require(Self.index(of: Self.canvas, in: drawn))
        let mask = try #require(Self.index(of: Self.hidden, in: drawn))
        let lastAnnotation = try #require(
            drawn.lastIndex { if case .text = $0 { true } else { false } })
        #expect(picture < mask)
        #expect(mask < lastAnnotation)
    }

    @Test("Several hidden things are all drawn")
    func several() {
        let other = SceneRect(x: 200, y: 150, width: 60, height: 40)
        let drawn = commands([
            Mask(rect: Self.hidden, style: .pixelate),
            Mask(rect: other, style: .solid),
        ])
        #expect(Self.index(of: Self.hidden, in: drawn) != nil)
        #expect(Self.index(of: other, in: drawn) != nil)
    }

    @Test("The same scene draws the same list twice")
    func reproducible() {
        let masks = [Mask(rect: Self.hidden, style: .pixelate)]
        let once = commands(masks)
        let again = commands(masks)
        #expect(once == again)
    }
}
