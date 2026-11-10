import EkranbildoContracts
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Camera override")
struct CameraOverrideTests {
    private let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)

    private func solved(
        _ overrides: [CameraOverride] = [],
        events: [CameraEvent] = []
    ) -> CameraPath {
        CameraPathSolver().solve(
            events: events,
            frame: frame,
            duration: .seconds(20),
            overrides: overrides
        )
    }

    private func pinned(at second: Double, x: Double) -> CameraOverride {
        CameraOverride(
            at: .seconds(second),
            view: SceneRect(x: x, y: 0, width: 400, height: 320)
        )
    }

    @Test("A pinned view is where the camera is at that moment")
    func pinnedViewIsUsed() throws {
        let path = solved([pinned(at: 5, x: 100)])
        #expect(try #require(path.view(at: .seconds(5))).minX == 100)
    }

    @Test("A pinned view is used exactly, not approximately")
    func pinnedViewIsExact() throws {
        let odd = CameraOverride(
            at: .seconds(7),
            view: SceneRect(x: 137.5, y: 42.25, width: 401, height: 320.8)
        )
        #expect(try #require(solved([odd]).view(at: .seconds(7))) == odd.view)
    }

    @Test("A pinned view closer than the solver would go is still used")
    func pinnedViewBeyondTheLimit() throws {
        let close = CameraOverride(
            at: .seconds(5),
            view: SceneRect(x: 10, y: 10, width: 50, height: 40)
        )
        #expect(try #require(solved([close]).view(at: .seconds(5))) == close.view)
    }

    @Test("Pinning nothing leaves the solver's own answer alone")
    func noOverrides() {
        let automatic = solved(events: [
            CameraEvent(at: .seconds(4), focus: SceneRect(x: 20, y: 20, width: 40, height: 30))
        ])
        #expect(
            automatic.keyframes
                == solved(events: [
                    CameraEvent(at: .seconds(4), focus: SceneRect(x: 20, y: 20, width: 40, height: 30))
                ]).keyframes)
    }

    @Test("The camera moves between two pinned views")
    func movesBetweenPins() throws {
        let path = solved([pinned(at: 4, x: 0), pinned(at: 8, x: 500)])
        let between = try #require(path.view(at: .seconds(6)))
        #expect(between.minX > 0)
        #expect(between.minX < 500)
    }

    @Test("A pin at the same moment as a click replaces the solver's answer")
    func pinBeatsAClick() throws {
        let path = solved(
            [pinned(at: 5, x: 100)],
            events: [
                CameraEvent(at: .seconds(5), focus: SceneRect(x: 900, y: 700, width: 40, height: 30))
            ]
        )
        #expect(try #require(path.view(at: .seconds(5))).minX == 100)
    }

    @Test("Pins are used in order however they arrive")
    func orderOfArrival() {
        let forwards = solved([pinned(at: 2, x: 0), pinned(at: 9, x: 500)])
        let backwards = solved([pinned(at: 9, x: 500), pinned(at: 2, x: 0)])
        #expect(forwards.keyframes == backwards.keyframes)
    }

    @Test("Two pins at the same moment give one view, the same one every time")
    func twoPinsAtOneMoment() {
        let path = solved([pinned(at: 5, x: 100), pinned(at: 5, x: 700)])
        #expect(path.keyframes.filter { $0.at == .seconds(5) }.count == 1)
        #expect(isReproducible { self.solved([self.pinned(at: 5, x: 100), self.pinned(at: 5, x: 700)]) })
    }

    @Test("A pin past the end of the recording lands at the end")
    func pinPastTheEnd() throws {
        let path = solved([pinned(at: 99, x: 100)])
        #expect(try #require(path.view(at: .seconds(20))).minX == 100)
    }

    @Test("A pin before the start lands at the start")
    func pinBeforeTheStart() throws {
        let path = solved([
            CameraOverride(
                at: Timestamp(nanoseconds: -5_000_000_000),
                view: SceneRect(x: 100, y: 0, width: 400, height: 320)
            )
        ])
        #expect(try #require(path.view(at: .zero)).minX == 100)
    }

    @Test("The same pins always give the same path")
    func reproducible() {
        let overrides = [pinned(at: 3, x: 40), pinned(at: 11, x: 600)]
        let events = [
            CameraEvent(at: .seconds(7), focus: SceneRect(x: 300, y: 200, width: 60, height: 40))
        ]
        #expect(isReproducible { self.solved(overrides, events: events) })
    }

    @Test("A pinned path survives being saved and opened")
    func roundTrips() throws {
        let override = pinned(at: 5, x: 100)
        #expect(try roundTripped(override) == override)
    }
}
