import EkranbildoContracts
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Timeline interactor")
struct TimelineInteractorTests {
    private let interactor = TimelineInteractor()
    private let frame = SceneRect(x: 0, y: 0, width: 1000, height: 800)

    private func state(playhead: Double = 0, overrides: [CameraOverride] = []) -> TimelineState {
        TimelineState(
            frame: frame,
            duration: .seconds(20),
            events: [],
            overrides: overrides,
            playhead: .seconds(playhead),
            selected: nil
        )
    }

    private func after(_ events: [TimelineEvent], from start: TimelineState) -> TimelineState {
        events.reduce(start) { interactor.handle($1, in: $0).state }
    }

    @Test("Scrubbing moves the playhead")
    func scrubs() {
        let moved = interactor.handle(.scrubbed(to: .seconds(7)), in: state()).state
        #expect(moved.playhead == .seconds(7))
    }

    @Test("Scrubbing past either end stops at the end", arguments: [-5.0, 99.0])
    func scrubbingIsClamped(second: Double) {
        let moved = interactor.handle(.scrubbed(to: .seconds(second)), in: state()).state
        #expect(moved.playhead >= .zero)
        #expect(moved.playhead <= .seconds(20))
    }

    @Test("Pinning records what the camera should show now")
    func pins() throws {
        let view = SceneRect(x: 100, y: 50, width: 400, height: 320)
        let pinned = after([.scrubbed(to: .seconds(5)), .pinned(view)], from: state())

        let override = try #require(pinned.overrides.first)
        #expect(override.at == .seconds(5))
        #expect(override.view == view)
    }

    @Test("What was just pinned is what is selected")
    func pinningSelects() {
        let view = SceneRect(x: 100, y: 50, width: 400, height: 320)
        let pinned = after([.scrubbed(to: .seconds(5)), .pinned(view)], from: state())
        #expect(pinned.selected == .seconds(5))
    }

    @Test("Pinning again at the same moment replaces what was there")
    func pinningAgainReplaces() throws {
        let first = SceneRect(x: 100, y: 50, width: 400, height: 320)
        let second = SceneRect(x: 700, y: 50, width: 400, height: 320)
        let pinned = after(
            [.scrubbed(to: .seconds(5)), .pinned(first), .pinned(second)], from: state())

        #expect(pinned.overrides.count == 1)
        #expect(try #require(pinned.overrides.first).view == second)
    }

    @Test("A keyframe can be selected by pointing at its moment")
    func selects() {
        let existing = CameraOverride(at: .seconds(5), view: frame)
        let selected = interactor.handle(
            .keyframeTouched(at: .seconds(5)), in: state(overrides: [existing])
        ).state
        #expect(selected.selected == .seconds(5))
    }

    @Test("Selecting a keyframe moves the playhead to it")
    func selectingScrubs() {
        let existing = CameraOverride(at: .seconds(5), view: frame)
        let selected = interactor.handle(
            .keyframeTouched(at: .seconds(5)), in: state(overrides: [existing])
        ).state
        #expect(selected.playhead == .seconds(5))
    }

    @Test("Pointing where there is no keyframe selects nothing")
    func selectsNothing() {
        let selected = interactor.handle(.keyframeTouched(at: .seconds(9)), in: state()).state
        #expect(selected.selected == nil)
    }

    @Test("A selected keyframe can be moved to another moment")
    func moves() throws {
        let existing = CameraOverride(at: .seconds(5), view: frame)
        let moved = after(
            [.keyframeTouched(at: .seconds(5)), .keyframeMoved(to: .seconds(12))],
            from: state(overrides: [existing])
        )
        #expect(try #require(moved.overrides.first).at == .seconds(12))
        #expect(moved.selected == .seconds(12))
    }

    @Test("Moving a keyframe onto another leaves one")
    func movingOntoAnother() {
        let moved = after(
            [.keyframeTouched(at: .seconds(5)), .keyframeMoved(to: .seconds(12))],
            from: state(overrides: [
                CameraOverride(at: .seconds(5), view: frame),
                CameraOverride(at: .seconds(12), view: SceneRect(x: 9, y: 9, width: 9, height: 9)),
            ])
        )
        #expect(moved.overrides.count == 1)
        #expect(moved.overrides.first?.view == frame)
    }

    @Test("Moving nothing does nothing")
    func movingWithNothingSelected() {
        let existing = CameraOverride(at: .seconds(5), view: frame)
        let moved = interactor.handle(
            .keyframeMoved(to: .seconds(12)), in: state(overrides: [existing])
        ).state
        #expect(moved.overrides == [existing])
    }

    @Test("A selected keyframe can be removed")
    func removes() {
        let removed = after(
            [.keyframeTouched(at: .seconds(5)), .keyframeRemoved],
            from: state(overrides: [CameraOverride(at: .seconds(5), view: frame)])
        )
        #expect(removed.overrides.isEmpty)
        #expect(removed.selected == nil)
    }

    @Test("Removing the last keyframe gives the camera back to the solver")
    func removingReturnsToTheSolver() {
        let removed = after(
            [.keyframeTouched(at: .seconds(5)), .keyframeRemoved],
            from: state(overrides: [CameraOverride(at: .seconds(5), view: frame)])
        )
        #expect(interactor.path(of: removed).keyframes.isEmpty == false)
    }

    @Test("Removing nothing does nothing")
    func removingWithNothingSelected() {
        let existing = CameraOverride(at: .seconds(5), view: frame)
        let removed = interactor.handle(
            .keyframeRemoved, in: state(overrides: [existing])
        ).state
        #expect(removed.overrides == [existing])
    }

    @Test("Keyframes are kept in the order they happen, not the order they were made")
    func keyframesAreInMomentOrder() {
        let late = SceneRect(x: 10, y: 0, width: 300, height: 240)
        let early = SceneRect(x: 600, y: 0, width: 300, height: 240)

        let backwards = after(
            [
                .scrubbed(to: .seconds(9)), .pinned(late),
                .scrubbed(to: .seconds(3)), .pinned(early),
            ],
            from: state()
        )
        #expect(backwards.overrides.map(\.at) == [.seconds(3), .seconds(9)])

        let forwards = after(
            [
                .scrubbed(to: .seconds(3)), .pinned(early),
                .scrubbed(to: .seconds(9)), .pinned(late),
            ],
            from: state()
        )
        #expect(backwards.overrides == forwards.overrides)
    }

    @Test("Moving a keyframe past another puts it in its new place in the order")
    func movingReorders() {
        let moved = after(
            [.keyframeTouched(at: .seconds(2)), .keyframeMoved(to: .seconds(15))],
            from: state(overrides: [
                CameraOverride(
                    at: .seconds(2), view: SceneRect(x: 900, y: 0, width: 100, height: 80)),
                CameraOverride(
                    at: .seconds(8), view: SceneRect(x: 0, y: 0, width: 100, height: 80)),
            ])
        )
        #expect(moved.overrides.map(\.at) == [.seconds(8), .seconds(15)])
    }

    @Test("The path honours what was pinned")
    func pathHonoursPins() throws {
        let view = SceneRect(x: 123, y: 50, width: 400, height: 320)
        let pinned = after([.scrubbed(to: .seconds(5)), .pinned(view)], from: state())
        #expect(try #require(interactor.path(of: pinned).view(at: .seconds(5))) == view)
    }

    @Test("The same events always give the same timeline")
    func reproducible() {
        let events: [TimelineEvent] = [
            .scrubbed(to: .seconds(3)),
            .pinned(SceneRect(x: 10, y: 10, width: 300, height: 240)),
            .scrubbed(to: .seconds(11)),
            .pinned(SceneRect(x: 600, y: 10, width: 300, height: 240)),
            .keyframeTouched(at: .seconds(3)),
            .keyframeMoved(to: .seconds(4)),
        ]
        #expect(isReproducible { self.after(events, from: self.state()) })
        #expect(isReproducible { self.interactor.path(of: self.after(events, from: self.state())) })
    }
}
