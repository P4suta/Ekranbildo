import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Hit testing")
struct HitTestTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    private let measurer = TabulatedTextMeasurer.uniform()

    private struct Placed {
        let target: SceneRect
        let direction: Direction16
        let length: Double
    }

    private func scene(_ placements: [Placed]) -> Scene {
        Scene(
            canvas: Self.canvas,
            background: nil,
            annotations: placements.enumerated().map { index, each in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: each.target,
                    label: "Label \(index + 1)",
                    placement: Placement(direction: each.direction, leaderLength: each.length)
                )
            },
            style: .standard
        )
    }

    private func tester(_ scene: Scene) -> HitTester {
        HitTester(scene: scene, measurer: measurer)
    }

    private func simple() -> Scene {
        scene([Placed(target: SceneRect(x: 180, y: 140, width: 40, height: 20), direction: .e, length: 60)])
    }

    @Test("A click on a label finds the label")
    func hitsLabel() throws {
        let subject = tester(simple())
        let label = try #require(subject.labelRect(of: AnnotationID(1)))
        let found = subject.hit(at: ScenePoint(x: label.raw.center.x, y: label.raw.center.y))
        #expect(found == .label(AnnotationID(1)))
    }

    @Test("A click on a target finds the target")
    func hitsTarget() {
        let found = tester(simple()).hit(at: ScenePoint(x: 200, y: 150))
        #expect(found == .target(AnnotationID(1)))
    }

    @Test("A click near a leader finds the leader")
    func hitsLeaderWithTolerance() throws {
        let subject = tester(simple())
        let leader = try #require(subject.leader(of: AnnotationID(1)))
        let middle = ScenePoint(
            x: (leader.points[0].x + leader.points[1].x) / 2,
            y: (leader.points[0].y + leader.points[1].y) / 2 + 3
        )
        #expect(subject.hit(at: middle) == .leader(AnnotationID(1)))
    }

    @Test("A click on nothing finds nothing")
    func hitsNothing() {
        #expect(tester(simple()).hit(at: ScenePoint(x: 20, y: 280)) == HitResult.nothing)
    }

    @Test("A click outside the canvas finds nothing")
    func outsideCanvas() {
        #expect(tester(simple()).hit(at: ScenePoint(x: -10, y: -10)) == HitResult.nothing)
    }

    @Test("The frontmost of two overlapping labels wins")
    func frontmostWins() throws {
        let subject = tester(
            scene([
                Placed(
                    target: SceneRect(x: 100, y: 140, width: 20, height: 20),
                    direction: .e,
                    length: 40
                ),
                Placed(
                    target: SceneRect(x: 104, y: 144, width: 20, height: 20),
                    direction: .e,
                    length: 40
                ),
            ])
        )
        let second = try #require(subject.labelRect(of: AnnotationID(2)))
        let found = subject.hit(at: ScenePoint(x: second.raw.center.x, y: second.raw.center.y))
        #expect(found == .label(AnnotationID(2)))
    }

    @Test("A label in front of a target beats the target")
    func labelBeatsTarget() throws {
        let subject = tester(
            scene([Placed(target: SceneRect(x: 180, y: 140, width: 40, height: 20), direction: .e, length: 0)]
            ))
        let label = try #require(subject.labelRect(of: AnnotationID(1)))
        #expect(
            subject.hit(at: ScenePoint(x: label.minX + 1, y: label.raw.center.y))
                == .label(AnnotationID(1))
        )
    }

    @Test("A handle beats the label it belongs to")
    func handleBeatsLabel() throws {
        let subject = tester(simple())
        let label = try #require(subject.labelRect(of: AnnotationID(1)))
        let corner = ScenePoint(x: label.maxX, y: label.maxY)
        #expect(subject.hit(at: corner) == .handle(AnnotationID(1), .bottomTrailing))
    }

    @Test("Every corner of a label is a handle")
    func everyCorner() throws {
        let subject = tester(simple())
        let label = try #require(subject.labelRect(of: AnnotationID(1)))
        let corners: [(ScenePoint, HitResult.Handle)] = [
            (ScenePoint(x: label.minX, y: label.minY), .topLeading),
            (ScenePoint(x: label.maxX, y: label.minY), .topTrailing),
            (ScenePoint(x: label.minX, y: label.maxY), .bottomLeading),
            (ScenePoint(x: label.maxX, y: label.maxY), .bottomTrailing),
        ]
        for (point, handle) in corners {
            #expect(subject.hit(at: point) == .handle(AnnotationID(1), handle))
        }
    }

    @Test("An unplaced annotation has a target but no label")
    func unplacedAnnotation() {
        let unsolved = Scene(
            canvas: Self.canvas,
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 100, y: 100, width: 40, height: 20),
                    label: "Waiting",
                    placement: nil
                )
            ],
            style: .standard
        )
        let subject = tester(unsolved)
        #expect(subject.labelRect(of: AnnotationID(1)) == nil)
        #expect(subject.hit(at: ScenePoint(x: 120, y: 110)) == .target(AnnotationID(1)))
    }

    @Test("Hit testing is reproducible")
    func reproducible() {
        let subject = tester(simple())
        #expect(isReproducible { subject.hit(at: ScenePoint(x: 200, y: 150)) })
    }

    @Test("An empty scene finds nothing anywhere")
    func emptyScene() {
        let empty = Scene(canvas: Self.canvas, background: nil, annotations: [], style: .standard)
        #expect(tester(empty).hit(at: ScenePoint(x: 200, y: 150)) == HitResult.nothing)
    }
}
