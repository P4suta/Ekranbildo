import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoSemantics
import Testing

@Suite("Snap targets")
struct SnapTargetTests {

    private static let click = SceneLibrary.nestedControlsButton

    @Test("A click returns the region it landed on")
    func finestTarget() throws {
        let targets = TargetSnapper().targets(in: SceneLibrary.nestedControls.image, at: Self.click)
        let finest = try #require(targets.first)
        let button = try #require(SceneLibrary.nestedControls.region(named: "button"))
        #expect(Geo.intersectionOverUnion(finest.raw, button.raw) > 0.9)
    }

    @Test("Clicking again widens to what contains it")
    func laddersOutward() {
        let targets = TargetSnapper().targets(in: SceneLibrary.nestedControls.image, at: Self.click)
        #expect(targets.count >= 2, "nested regions should offer more than one reading")

        for (inner, outer) in zip(targets, targets.dropFirst()) {
            #expect(outer.raw.area > inner.raw.area, "each rung must be wider than the last")
            #expect(
                outer.raw.contains(inner.raw),
                "a coarser reading has to contain the finer one, or it is not a ladder"
            )
        }
    }

    @Test("Every rung contains the point that was clicked")
    func allContainThePoint() {
        for target in TargetSnapper().targets(in: SceneLibrary.nestedControls.image, at: Self.click) {
            #expect(target.raw.contains(Self.click.raw))
        }
    }

    @Test("The ladder is reproducible")
    func reproducible() {
        let image = SceneLibrary.nestedControls.image
        let first = TargetSnapper().targets(in: image, at: Self.click)
        #expect(first == TargetSnapper().targets(in: image, at: Self.click))
    }

    @Test("A click outside the image returns nothing")
    func outsideTheImage() {
        let image = SceneLibrary.nestedControls.image
        #expect(TargetSnapper().targets(in: image, at: ScenePoint(x: -1, y: 10)).isEmpty)
        #expect(TargetSnapper().targets(in: image, at: ScenePoint(x: 10, y: 500)).isEmpty)
    }

    @Test("A flat image offers a single reading")
    func flatImage() {
        let size = 60
        let screen = SyntheticScreenshot(width: size, height: size)
        let targets = TargetSnapper()
            .targets(in: screen.image, at: ScenePoint(x: Double(size / 2), y: Double(size / 2)))
        #expect(targets.count == 1)
        #expect(targets.first?.raw.area == Double(size * size))
    }

    @Test("Readings of nearly the same size are one rung")
    func nearDuplicatesCollapse() {
        let outer = SceneRect(x: 0, y: 0, width: 100, height: 100)
        let inner = outer.raw.inset(by: 1)
        let innerRect = SceneRect(
            x: inner.minX, y: inner.minY, width: inner.width, height: inner.height)
        let elements = [outer, innerRect].map {
            ScreenElement(rect: $0, kind: .surface, confidence: 1, provenance: .given)
        }
        let targets = TargetSnapper().targets(among: elements, at: ScenePoint(x: 50, y: 50))
        #expect(targets == [innerRect])
    }

    @Test("A wider reading beside the one below is not a rung")
    func rungsMustSurround() {
        let control = SceneRect(x: 10, y: 10, width: 20, height: 20)
        let band = SceneRect(x: 0, y: 15, width: 200, height: 10)
        let elements = [control, band].map {
            ScreenElement(rect: $0, kind: .surface, confidence: 1, provenance: .given)
        }
        let targets = TargetSnapper().targets(among: elements, at: ScenePoint(x: 20, y: 20))
        #expect(targets == [control])
    }

    @Test("Cycling past the end comes back to the start")
    func cycles() {
        let targets = TargetSnapper().targets(in: SceneLibrary.nestedControls.image, at: Self.click)
        #expect(TargetSnapper.target(at: targets.count, among: targets) == targets.first)
        #expect(TargetSnapper.target(at: -1, among: targets) == targets.last)
        #expect(TargetSnapper.target(at: 0, among: []) == nil)
    }
}
