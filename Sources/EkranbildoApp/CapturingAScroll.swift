import EkranbildoContracts
import EkranbildoStitch

public struct Scrolling: Hashable, Sendable {
    public let region: ScreenRect
    public var seen: Int
    public var advice: ScrollAdvice

    public init(region: ScreenRect, seen: Int = 0, advice: ScrollAdvice = .keepGoing) {
        self.region = region
        self.seen = seen
        self.advice = advice
    }
}

extension AppState {
    func captureScrolling() -> Outcome {
        guard screen == .idle else { return dismiss() }
        var next = self
        next.screen = .choosingRegion
        next.scroll = nil
        return Outcome(state: next, effects: [.freezeScreens])
    }

    func choseScrollRegion(_ region: ScreenRect) -> Outcome {
        guard screen == .choosingRegion else { return Outcome(state: self, effects: []) }
        var next = self
        next.screen = .scrolling
        next.scroll = Scrolling(region: region)
        return Outcome(state: next, effects: [.dismissOverlay, .followTheScroll(region)])
    }

    func scrolled(_ seen: Int, _ advice: ScrollAdvice) -> Outcome {
        guard var scrolling = scroll else { return Outcome(state: self, effects: []) }
        scrolling.seen = seen
        scrolling.advice = advice
        var next = self
        next.scroll = scrolling
        return Outcome(state: next, effects: [])
    }

    func finishScrolling() -> Outcome {
        guard screen == .scrolling else { return Outcome(state: self, effects: []) }
        var next = self
        next.screen = .idle
        next.scroll = nil
        return Outcome(state: next, effects: [.joinTheScroll])
    }
}
