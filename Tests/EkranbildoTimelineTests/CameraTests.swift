import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Camera path")
struct CameraTests {

    private static let frame = SceneRect(x: 0, y: 0, width: 1600, height: 1000)

    private func clicks(_ seconds: [Double]) -> [CameraEvent] {
        seconds.enumerated().map { index, moment in
            CameraEvent(
                at: .seconds(moment),
                focus: SceneRect(
                    x: 200 + Double(index) * 300,
                    y: 300,
                    width: 120,
                    height: 60
                )
            )
        }
    }

    private func path(_ events: [CameraEvent], duration: Double = 20) -> CameraPath {
        CameraPathSolver().solve(
            events: events,
            frame: Self.frame,
            duration: .seconds(duration)
        )
    }

    @Test("The camera never looks outside the picture")
    func staysInside() {
        let path = path(clicks([2, 6, 11]))
        for keyframe in path.keyframes {
            #expect(
                Self.frame.raw.contains(keyframe.view.raw),
                "at \(keyframe.at.seconds)s the camera shows \(keyframe.view.canonicalText)"
            )
        }
    }

    @Test("The camera never zooms out past the whole picture")
    func neverZoomsOut() {
        for keyframe in path(clicks([2, 6])).keyframes {
            #expect(keyframe.view.raw.width <= Self.frame.raw.width)
            #expect(keyframe.view.raw.height <= Self.frame.raw.height)
        }
    }

    @Test("The camera never zooms in further than it is allowed to")
    func respectsMaximumZoom() {
        let solver = CameraPathSolver(maximumZoom: 2)
        let path = solver.solve(
            events: clicks([2, 6]), frame: Self.frame, duration: .seconds(20))
        for keyframe in path.keyframes {
            #expect(keyframe.view.raw.width >= Self.frame.raw.width / 2 - Tolerances.size)
        }
    }

    @Test("The camera stays still long enough to be looked at")
    func restsBetweenMoves() {
        let path = path(clicks([2, 2.3, 2.6, 3]))
        let moves = zip(path.keyframes, path.keyframes.dropFirst())
            .filter { $0.view != $1.view }
            .map { $1.at.seconds }

        for (earlier, later) in zip(moves, moves.dropFirst()) {
            #expect(
                later - earlier >= CameraPathSolver.Defaults.minimumRest - Tolerances.time,
                "only \(later - earlier)s between moves"
            )
        }
    }

    @Test("The camera never moves faster than the eye can follow")
    func staysSlowEnough() {
        let path = path(clicks([2, 5, 9]))
        for (earlier, later) in zip(path.keyframes, path.keyframes.dropFirst()) {
            let seconds = later.at.seconds - earlier.at.seconds
            guard seconds > 0 else { continue }
            let travelled = Geo.distanceSquared(
                earlier.view.raw.center, later.view.raw.center
            ).squareRoot()
            let speed = travelled / seconds
            #expect(
                speed <= CameraPathSolver.Defaults.maximumSpeed + Tolerances.speed,
                "\(speed) points a second between \(earlier.at.seconds)s and \(later.at.seconds)s"
            )
        }
    }

    @Test("The camera starts showing the whole picture")
    func startsWide() throws {
        let first = try #require(path(clicks([3])).keyframes.first)
        #expect(first.at == .zero)
        #expect(first.view == Self.frame)
    }

    @Test("The camera ends showing the whole picture")
    func endsWide() throws {
        let last = try #require(path(clicks([3])).keyframes.last)
        #expect(last.view == Self.frame)
    }

    @Test("The camera is on what was clicked when it was clicked")
    func looksAtTheClick() throws {
        let events = clicks([6])
        let path = path(events)
        let view = try #require(path.view(at: .seconds(6)))
        #expect(
            Geo.overlaps(view.raw, events[0].focus.raw),
            "the camera is showing \(view.canonicalText) rather than what was clicked"
        )
        #expect(view.raw.width < Self.frame.raw.width, "the camera did not move in at all")
    }

    @Test("A recording nobody clicked in is one long wide shot")
    func nothingHappened() {
        let path = path([])
        #expect(path.keyframes.allSatisfy { $0.view == Self.frame })
    }

    @Test("Clicks in the same place are one move")
    func groupsNearbyClicks() {
        let together = [
            CameraEvent(at: .seconds(3), focus: SceneRect(x: 200, y: 300, width: 100, height: 50)),
            CameraEvent(at: .seconds(3.4), focus: SceneRect(x: 210, y: 305, width: 100, height: 50)),
            CameraEvent(at: .seconds(3.8), focus: SceneRect(x: 205, y: 300, width: 100, height: 50)),
        ]
        let apart = clicks([3, 8, 13])
        #expect(path(together).keyframes.count < path(apart).keyframes.count)
    }

    @Test("A path survives a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(path(clicks([2, 7]))))
    }

    @Test("The same recording gives the same path")
    func reproducible() {
        let events = clicks([2, 6, 11])
        #expect(isReproducible { path(events) })
    }

    @Test("The keyframes are in order")
    func ordered() {
        let path = path(clicks([9, 2, 5]))
        #expect(path.keyframes.map(\.at) == path.keyframes.map(\.at).sorted())
    }

    private enum Tolerances {
        static let size: Double = 1
        static let time: Double = 1e-6
        static let speed: Double = 1e-6
    }

    @Test(
        "A tiny thing to look at does not take the camera past the limit",
        arguments: [1.0, 4.0, 20.0]
    )
    func neverPastTheLimit(side: Double) {
        let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)
        let view = CameraPathSolver(maximumZoom: 2.5)
            .framing(SceneRect(x: 500, y: 400, width: side, height: side), in: frame)

        #expect(view.raw.width >= frame.raw.width / 2.5 - Tolerance.geometric)
        #expect(view.raw.height >= frame.raw.height / 2.5 - Tolerance.geometric)
    }

    @Test("Something large is still framed to fit")
    func largeFocusIsNotZoomedIn() {
        let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)
        let view = CameraPathSolver(maximumZoom: 2.5)
            .framing(SceneRect(x: 100, y: 100, width: 700, height: 560), in: frame)
        #expect(view.raw.width > frame.raw.width / 2.5)
    }

    @Test("Clicks close in time but far apart are separate things")
    func differentPlacesAreDifferentThings() {
        let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)
        let path = CameraPathSolver().solve(
            events: [
                CameraEvent(at: .seconds(1), focus: SceneRect(x: 20, y: 20, width: 40, height: 30)),
                CameraEvent(
                    at: .seconds(1.2), focus: SceneRect(x: 900, y: 700, width: 40, height: 30)),
            ],
            frame: frame,
            duration: .seconds(20)
        )

        let close = path.keyframes.filter { $0.view != frame }
        #expect(Set(close.map(\.view)).count == 2)
    }

    @Test("Clicks close in time and in the same place are one thing")
    func samePlaceIsOneThing() {
        let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)
        let path = CameraPathSolver().solve(
            events: [
                CameraEvent(at: .seconds(1), focus: SceneRect(x: 20, y: 20, width: 40, height: 30)),
                CameraEvent(
                    at: .seconds(1.2), focus: SceneRect(x: 30, y: 25, width: 40, height: 30)),
            ],
            frame: frame,
            duration: .seconds(20)
        )
        let close = path.keyframes.filter { $0.view != frame }
        #expect(Set(close.map(\.view)).count == 1)
    }

    @Test("The camera starts and stops gently rather than abruptly")
    func easesInAndOut() {
        let path = CameraPath(keyframes: [
            CameraKeyframe(at: .zero, view: SceneRect(x: 0, y: 0, width: 100, height: 100)),
            CameraKeyframe(at: .seconds(4), view: SceneRect(x: 400, y: 0, width: 100, height: 100)),
        ])

        #expect(path.view(at: .seconds(1))?.minX ?? .nan < 100 - Tolerance.geometric)
        #expect(approximatelyEqual(path.view(at: .seconds(2))?.minX ?? .nan, 200))
        #expect(path.view(at: .seconds(3))?.minX ?? .nan > 300 + Tolerance.geometric)
    }

    @Test("The ends of a move are exactly where they were asked to be")
    func endsAreExact() {
        let from = SceneRect(x: 0, y: 0, width: 100, height: 100)
        let to = SceneRect(x: 400, y: 0, width: 100, height: 100)
        let path = CameraPath(keyframes: [
            CameraKeyframe(at: .zero, view: from),
            CameraKeyframe(at: .seconds(4), view: to),
        ])
        #expect(path.view(at: .zero) == from)
        #expect(path.view(at: .seconds(4)) == to)
    }
}
