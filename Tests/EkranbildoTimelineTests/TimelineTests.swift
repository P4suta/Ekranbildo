import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoRender
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Timeline")
struct TimelineTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene(label: String = "Here") -> Scene {
        Scene(
            canvas: Self.canvas,
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 180, y: 140, width: 40, height: 20),
                    label: label,
                    placement: Placement(direction: .n, leaderLength: 40)
                )
            ],
            style: .standard
        )
    }

    @Test("A still picture is a timeline of one frame")
    func stillIsATimeline() {
        let timeline = Timeline(still: scene())
        #expect(timeline.duration == .zero)
        #expect(timeline.scene(at: .zero) == scene())
    }

    @Test("A still timeline says the same thing at every moment")
    func stillIsConstant() {
        let timeline = Timeline(still: scene())
        for moment in [Timestamp.zero, .seconds(5), .seconds(-5)] {
            #expect(timeline.scene(at: moment) == scene())
        }
    }

    private func moving() -> Timeline {
        Timeline(
            canvas: Self.canvas,
            style: .standard,
            background: nil,
            duration: .seconds(10),
            tracks: [
                AnnotationTrack(
                    annotation: scene().annotations[0],
                    appears: .seconds(2),
                    disappears: .seconds(6)
                )
            ]
        )
    }

    @Test("An annotation is absent before it appears")
    func absentBefore() {
        #expect(moving().scene(at: .seconds(1)).annotations.isEmpty)
    }

    @Test("An annotation is there while it is there")
    func presentDuring() {
        #expect(moving().scene(at: .seconds(4)).annotations.count == 1)
    }

    @Test("An annotation is gone after it goes")
    func absentAfter() {
        #expect(moving().scene(at: .seconds(8)).annotations.isEmpty)
    }

    @Test("The moment it appears is a moment it is there")
    func boundariesAreInclusive() {
        #expect(moving().scene(at: .seconds(2)).annotations.count == 1)
        #expect(moving().scene(at: .seconds(6)).annotations.count == 1)
    }

    @Test("An annotation with no end stays to the end")
    func staysToTheEnd() {
        let timeline = Timeline(
            canvas: Self.canvas,
            style: .standard,
            background: nil,
            duration: .seconds(10),
            tracks: [AnnotationTrack(annotation: scene().annotations[0], appears: .seconds(1))]
        )
        #expect(timeline.scene(at: .seconds(9)).annotations.count == 1)
    }

    @Test("A moment outside the timeline is the nearest moment inside it")
    func clampsToTheEnds() {
        let timeline = moving()
        #expect(timeline.scene(at: .seconds(-3)) == timeline.scene(at: .zero))
        #expect(timeline.scene(at: .seconds(99)) == timeline.scene(at: timeline.duration))
    }

    @Test("A still timeline draws what the scene it came from draws")
    func drawsTheSame() {
        let scene = scene()
        let direct = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(scene)
        let throughTimeline = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
            .build(Timeline(still: scene).scene(at: .zero))
        #expect(direct == throughTimeline)
    }

    @Test("A timeline survives a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(moving()))
    }

    @Test("Asking twice gives the same answer")
    func reproducible() {
        let timeline = moving()
        #expect(isReproducible { timeline.scene(at: .seconds(4)) })
    }

    @Test("A timeline with nothing on it is empty rather than broken")
    func emptyTimeline() {
        let timeline = Timeline(
            canvas: Self.canvas,
            style: .standard,
            background: nil,
            duration: .seconds(3),
            tracks: []
        )
        #expect(timeline.scene(at: .seconds(1)).annotations.isEmpty)
    }
}
