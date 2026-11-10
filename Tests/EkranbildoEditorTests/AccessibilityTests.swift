import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Accessibility")
struct AccessibilityTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene(_ annotations: [Annotation]) -> Scene {
        Scene(canvas: Self.canvas, background: nil, annotations: annotations, style: .standard)
    }

    private func annotation(
        _ id: UInt32,
        label: String = "Open settings",
        at x: Double = 180,
        badge: BadgeNumber? = nil
    ) -> Annotation {
        Annotation(
            id: AnnotationID(id),
            target: SceneRect(x: x, y: 140, width: 40, height: 20),
            label: label,
            placement: Placement(direction: .n, leaderLength: 50),
            badge: badge
        )
    }

    private func described(_ scene: Scene) -> [AccessibleElement] {
        AccessibilityDescription(measurer: TabulatedTextMeasurer.uniform()).elements(of: scene)
    }

    @Test("Every annotation is something that can be reached")
    func everyAnnotation() {
        #expect(described(scene([annotation(1), annotation(2, at: 60)])).count == 2)
    }

    @Test("An annotation that has not been placed is not offered")
    func unplacedIsNotOffered() {
        let waiting = Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 100, y: 100, width: 40, height: 20),
            label: "Waiting",
            placement: nil
        )
        #expect(described(scene([waiting])).isEmpty)
    }

    @Test("An empty picture describes nothing rather than failing")
    func emptyScene() {
        #expect(described(scene([])).isEmpty)
    }

    @Test("An annotation is read as what it says")
    func readsTheLabel() throws {
        let element = try #require(described(scene([annotation(1, label: "Open settings")])).first)
        #expect(element.label.contains("Open settings"))
    }

    @Test("A numbered step is read with its number")
    func readsTheNumber() throws {
        let element = try #require(
            described(scene([annotation(1, label: "Press save", badge: BadgeNumber(3))])).first
        )
        #expect(element.label.contains("3"))
        #expect(element.label.contains("Press save"))
    }

    @Test("An annotation that is not a step is not read as one")
    func plainAnnotation() throws {
        let element = try #require(described(scene([annotation(1, label: "Just this")])).first)
        #expect(!element.label.lowercased().contains("step"))
    }

    @Test("An annotation with no words is still described")
    func emptyLabel() throws {
        let element = try #require(described(scene([annotation(1, label: "")])).first)
        #expect(!element.label.isEmpty)
    }

    @Test("An annotation knows where it is on screen")
    func hasAFrame() throws {
        let element = try #require(described(scene([annotation(1)])).first)
        #expect(element.frame.raw.width > 0)
        #expect(element.frame.raw.height > 0)
        #expect(Self.canvas.raw.contains(element.frame.raw))
    }

    @Test("What is described covers the label and the arrow together")
    func coversBoth() throws {
        let subject = annotation(1)
        let element = try #require(described(scene([subject])).first)
        let resolved = ResolvedPlacement(
            target: subject.target,
            placement: subject.placement!,
            style: .standard
        )
        #expect(element.frame.raw.contains(resolved.tip.raw))
    }

    @Test("Annotations are read in the order the picture is read")
    func readingOrder() {
        let scattered = scene([
            annotation(1, label: "Right", at: 300),
            annotation(2, label: "Left", at: 40),
        ])
        #expect(described(scattered).map(\.label).first?.contains("Left") == true)
    }

    @Test("Describing is reproducible")
    func reproducible() {
        let subject = scene([annotation(1), annotation(2, at: 60)])
        #expect(isReproducible { described(subject) })
    }
}
