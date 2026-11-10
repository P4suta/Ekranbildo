import EkranbildoContracts
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Cursor")
struct CursorTests {

    private struct Step {
        let moment: Double
        let x: Double
        let y: Double
    }

    private func path(_ steps: [Step]) -> [CursorSample] {
        steps.map {
            CursorSample(
                at: .seconds($0.moment),
                position: ScreenPoint(x: $0.x, y: $0.y),
                pressed: false
            )
        }
    }

    private func jittery() -> [CursorSample] {
        path([
            Step(moment: 0, x: 0, y: 0),
            Step(moment: 0.1, x: 10, y: 0),
            Step(moment: 0.2, x: 20, y: 0),
            Step(moment: 0.3, x: 30, y: 14),
            Step(moment: 0.4, x: 40, y: 0),
            Step(moment: 0.5, x: 50, y: 0),
            Step(moment: 0.6, x: 60, y: 0),
        ])
    }

    @Test("Smoothing takes the twitch out")
    func removesJitter() throws {
        let smoothed = CursorPolish().smooth(jittery())
        let middle = try #require(smoothed.first { $0.at == .seconds(0.3) })
        #expect(middle.position.y < 14, "the twitch is still there")
    }

    @Test("A path that was already straight stays where it was")
    func leavesSmoothPathsAlone() {
        let straight = path([
            Step(moment: 0, x: 0, y: 0),
            Step(moment: 0.1, x: 10, y: 0),
            Step(moment: 0.2, x: 20, y: 0),
            Step(moment: 0.3, x: 30, y: 0),
        ])
        for (before, after) in zip(straight, CursorPolish().smooth(straight)) {
            #expect(abs(after.position.y - before.position.y) < Tolerances.position)
        }
    }

    @Test("The ends are not moved")
    func keepsEnds() throws {
        let smoothed = CursorPolish().smooth(jittery())
        #expect(try #require(smoothed.first).position == ScreenPoint(x: 0, y: 0))
        #expect(try #require(smoothed.last).position == ScreenPoint(x: 60, y: 0))
    }

    @Test("Smoothing changes where, never when")
    func keepsTiming() {
        let original = jittery()
        #expect(CursorPolish().smooth(original).map(\.at) == original.map(\.at))
    }

    @Test("A press survives smoothing")
    func keepsPresses() {
        var samples = jittery()
        samples[3] = CursorSample(
            at: samples[3].at, position: samples[3].position, pressed: true)
        let smoothed = CursorPolish().smooth(samples)
        #expect(smoothed.filter(\.pressed).count == 1)
    }

    @Test("Too few samples to smooth are returned as they are")
    func tooFewToSmooth() {
        for count in 0..<3 {
            let few = Array(jittery().prefix(count))
            #expect(CursorPolish().smooth(few).count == few.count)
        }
    }

    @Test("A press becomes a ripple")
    func pressBecomesRipple() {
        var samples = path([Step(moment: 0, x: 10, y: 10), Step(moment: 0.5, x: 20, y: 20)])
        samples[1] = CursorSample(at: samples[1].at, position: samples[1].position, pressed: true)
        let ripples = CursorPolish().ripples(in: samples)
        #expect(ripples.count == 1)
        #expect(ripples[0].at == .seconds(0.5))
        #expect(ripples[0].centre == ScreenPoint(x: 20, y: 20))
    }

    @Test("A button held down is one ripple")
    func heldButtonIsOneRipple() {
        let held = (0..<6).map { index in
            CursorSample(
                at: .seconds(Double(index) / 10),
                position: ScreenPoint(x: 10, y: 10),
                pressed: index >= 2
            )
        }
        #expect(CursorPolish().ripples(in: held).count == 1)
    }

    @Test("Two separate presses are two ripples")
    func twoPresses() {
        let twice = (0..<8).map { index in
            CursorSample(
                at: .seconds(Double(index) / 10),
                position: ScreenPoint(x: 10, y: 10),
                pressed: index == 2 || index == 6
            )
        }
        #expect(CursorPolish().ripples(in: twice).count == 2)
    }

    @Test("A recording nobody clicked in has no ripples")
    func noPresses() {
        #expect(CursorPolish().ripples(in: jittery()).isEmpty)
    }

    @Test("A cursor that has stopped fades out")
    func fadesWhenStill() {
        let still = (0..<40).map { index in
            CursorSample(
                at: .seconds(Double(index) / 10),
                position: ScreenPoint(x: 100, y: 100),
                pressed: false
            )
        }
        let polish = CursorPolish()
        #expect(polish.opacity(at: .seconds(0.1), in: still) == 1)
        #expect(polish.opacity(at: .seconds(3.5), in: still) < 1)
    }

    @Test("A cursor that is moving stays visible")
    func staysWhileMoving() {
        let moving = (0..<40).map { index in
            CursorSample(
                at: .seconds(Double(index) / 10),
                position: ScreenPoint(x: Double(index) * 20, y: 100),
                pressed: false
            )
        }
        #expect(CursorPolish().opacity(at: .seconds(3.5), in: moving) == 1)
    }

    @Test("A cursor that moves again comes straight back")
    func returnsOnMovement() {
        var samples = (0..<40).map { index in
            CursorSample(
                at: .seconds(Double(index) / 10),
                position: ScreenPoint(x: 100, y: 100),
                pressed: false
            )
        }
        samples.append(
            CursorSample(at: .seconds(4), position: ScreenPoint(x: 300, y: 100), pressed: false))
        #expect(CursorPolish().opacity(at: .seconds(4), in: samples) == 1)
    }

    @Test("With nothing recorded there is nothing to show")
    func nothingRecorded() {
        #expect(CursorPolish().opacity(at: .seconds(1), in: []) == 0)
    }

    @Test("Polishing is reproducible")
    func reproducible() {
        let samples = jittery()
        #expect(isReproducible { CursorPolish().smooth(samples) })
    }

    private enum Tolerances {
        static let position: Double = 1e-9
    }
}
