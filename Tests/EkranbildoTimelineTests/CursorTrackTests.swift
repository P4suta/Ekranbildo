import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Cursor track")
struct CursorTrackTests {

    private struct At {
        let second: Double
        let x: Double
        let y: Double
        var pressed = false

        init(_ second: Double, _ x: Double, _ y: Double, _ pressed: Bool = false) {
            self.second = second
            self.x = x
            self.y = y
            self.pressed = pressed
        }

        var point: ScenePoint { ScenePoint(x: x, y: y) }
    }

    private func track(
        _ positions: [At],
        ripples: [At] = [],
        rippleFor: Double = 0.4
    ) -> CursorTrack {
        CursorTrack(
            samples: positions.map {
                CursorKeyframe(at: .seconds($0.second), position: $0.point, opacity: 1)
            },
            ripples: ripples.map {
                RippleKeyframe(at: .seconds($0.second), centre: $0.point)
            },
            rippleFor: .seconds(rippleFor)
        )
    }

    @Test("Between two samples the pointer is between the two positions")
    func interpolates() throws {
        let cursor = try #require(track([At(0, 0, 0), At(2, 100, 50)]).cursor(at: .seconds(1)))
        #expect(approximatelyEqual(cursor.position.x, 50, tolerance: 1e-9))
        #expect(approximatelyEqual(cursor.position.y, 25, tolerance: 1e-9))
    }

    @Test("At a sample the pointer is exactly where the sample says")
    func exactAtSamples() throws {
        let path = track([At(0, 0, 0), At(2, 100, 50)])
        #expect(try #require(path.cursor(at: .seconds(2))).position.x == 100)
        #expect(try #require(path.cursor(at: .zero)).position.x == 0)
    }

    @Test("Outside the samples the pointer stays at the nearest one")
    func holdsAtTheEnds() throws {
        let path = track([At(1, 10, 10), At(2, 20, 20)])
        #expect(try #require(path.cursor(at: .zero)).position.x == 10)
        #expect(try #require(path.cursor(at: .seconds(9))).position.x == 20)
    }

    @Test("A track with no samples has no pointer")
    func nothingRecorded() {
        #expect(track([]).cursor(at: .seconds(1)) == nil)
    }

    @Test("Two samples at the same moment do not divide by nothing")
    func simultaneousSamples() throws {
        let cursor = try #require(track([At(1, 10, 10), At(1, 30, 30)]).cursor(at: .seconds(1)))
        #expect(cursor.position.x.isFinite)
    }

    @Test("A ripple starts at nothing when the click happens")
    func rippleBegins() throws {
        let path = track([At(0, 0, 0), At(2, 0, 0)], ripples: [At(1, 0, 0)])
        #expect(try #require(path.cursor(at: .seconds(1))).ripple == 0)
    }

    @Test("A ripple is finished by the time it has run its course")
    func rippleEnds() throws {
        let path = track([At(0, 0, 0), At(2, 0, 0)], ripples: [At(1, 0, 0)], rippleFor: 0.4)
        let halfway = try #require(path.cursor(at: .seconds(1.2))).ripple
        #expect(approximatelyEqual(halfway ?? .nan, 0.5, tolerance: 1e-9))
        #expect(try #require(path.cursor(at: .seconds(1.4))).ripple == nil)
        #expect(try #require(path.cursor(at: .seconds(1.9))).ripple == nil)
    }

    @Test("Before a click there is no ripple")
    func noRippleYet() throws {
        let path = track([At(0, 0, 0), At(2, 0, 0)], ripples: [At(1, 0, 0)])
        #expect(try #require(path.cursor(at: .seconds(0.5))).ripple == nil)
    }

    @Test("Two clicks close together show the newer ripple")
    func newerRippleWins() throws {
        let path = track([At(0, 0, 0), At(2, 0, 0)], ripples: [At(1, 0, 0), At(1.1, 0, 0)])
        let cursor = try #require(path.cursor(at: .seconds(1.2)))
        let ripple = try #require(cursor.ripple)
        #expect(approximatelyEqual(ripple, 0.25, tolerance: 1e-9))
    }

    @Test("A ripple of no length does not divide by nothing")
    func instantRipple() throws {
        let path = track([At(0, 0, 0), At(2, 0, 0)], ripples: [At(1, 0, 0)], rippleFor: 0)
        #expect(try #require(path.cursor(at: .seconds(1))).ripple == nil)
    }

    @Test("Asking twice gives the same answer")
    func reproducible() {
        let path = track([At(0, 0, 0), At(1, 40, 10), At(2, 90, 70)], ripples: [At(0.5, 20, 5)])
        #expect(isReproducible { (0...20).map { path.cursor(at: .seconds(Double($0) / 10)) } })
    }

    @Test("A track survives being saved and opened")
    func roundTrips() throws {
        let path = track([At(0, 0, 0), At(1, 40, 10)], ripples: [At(0.5, 20, 5)])
        #expect(try roundTripped(path) == path)
    }

    @Test("A timeline hands the scene a pointer at the moment asked for")
    func onATimeline() throws {
        let timeline = Timeline(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 100),
            style: .standard,
            background: nil,
            duration: .seconds(2),
            tracks: [],
            cursor: track([At(0, 0, 0), At(2, 100, 50)])
        )
        let cursor = try #require(timeline.scene(at: .seconds(1)).cursor)
        #expect(approximatelyEqual(cursor.position.x, 50, tolerance: 1e-9))
    }

    @Test("A still picture has no pointer")
    func stillPicture() {
        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            background: nil,
            annotations: [],
            style: .standard
        )
        #expect(Timeline(still: scene).scene(at: .zero).cursor == nil)
    }

    private func geometry(originX: Double = 100, originY: Double = 50) -> CaptureGeometry {
        CaptureGeometry(
            display: DisplayGeometry(
                displayID: 1,
                bounds: Rect(x: 0, y: 0, width: 1000, height: 800),
                backingScale: 2
            ),
            regionInScreen: Rect(x: originX, y: originY, width: 400, height: 300)
        )
    }

    private func recorded(_ samples: [At]) -> [CursorSample] {
        samples.map {
            CursorSample(
                at: .seconds($0.second),
                position: ScreenPoint(x: $0.x, y: $0.y),
                pressed: $0.pressed
            )
        }
    }

    @Test("A recorded pointer is moved into the document's own coordinates")
    func convertsToSceneSpace() throws {
        let track = CursorTrack(
            recorded: recorded([At(0, 150, 90, false)]), geometry: geometry())
        let cursor = try #require(track.cursor(at: .zero))
        #expect(cursor.position.x == 50)
        #expect(cursor.position.y == 40)
    }

    @Test("A press becomes a ring")
    func pressBecomesARipple() throws {
        let track = CursorTrack(
            recorded: recorded([
                At(0, 150, 90, false), At(1, 150, 90, true), At(2, 150, 90, false),
            ]),
            geometry: geometry()
        )
        #expect(try #require(track.cursor(at: .seconds(1))).ripple != nil)
        #expect(try #require(track.cursor(at: .zero)).ripple == nil)
    }

    @Test("A held button is one ring, not one per frame")
    func heldButtonIsOneRipple() {
        let held = (0..<10).map { At(Double($0) / 10, 150, 90, true) }
        let track = CursorTrack(recorded: recorded(held), geometry: geometry())
        #expect(track.ripples.count == 1)
    }

    @Test("A pointer that has not moved for a while fades")
    func fades() throws {
        let still = (0..<60).map { At(Double($0) / 10, 150, 90, false) }
        let track = CursorTrack(recorded: recorded(still), geometry: geometry())
        let early = try #require(track.cursor(at: .zero)).opacity
        let late = try #require(track.cursor(at: .seconds(5))).opacity
        #expect(late < early)
    }

    @Test("Nothing recorded is no track at all")
    func nothingToConvert() {
        #expect(CursorTrack(recorded: [], geometry: geometry()).cursor(at: .zero) == nil)
    }

    @Test("Building a track from a recording is reproducible")
    func reproducibleFromRecording() {
        let samples = recorded([
            At(0, 150, 90, false), At(0.1, 152, 93, true), At(0.2, 158, 99, false),
        ])
        let place = geometry()
        #expect(isReproducible { CursorTrack(recorded: samples, geometry: place) })
    }
}
