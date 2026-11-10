import EkranbildoContracts
import Testing

@Suite("Frames in time")
struct FramesInTimeTests {
    private func picture() -> ImageBuffer {
        ImageBuffer(width: 1, height: 1, colorSpace: .displayP3, pixels: [0, 0, 0, 0])
    }

    @Test("A frame knows the moment it belongs to")
    func timed() {
        let frame = TimedFrame(image: picture(), at: .seconds(2))
        #expect(frame.at == .seconds(2))
    }

    @Test("A held frame knows how long it stays, not when it started")
    func held() {
        let frame = HeldFrame(image: picture(), showFor: .seconds(0.5))
        #expect(frame.showFor == .seconds(0.5))
    }

    @Test("Each frame stays up until the next one arrives")
    func lengths() {
        let frames = [
            TimedFrame(image: picture(), at: .zero),
            TimedFrame(image: picture(), at: .seconds(1)),
            TimedFrame(image: picture(), at: .seconds(3)),
        ]
        #expect(
            TimedFrame.held(frames).map(\.showFor)
                == [.seconds(1), .seconds(2), .seconds(2)])
    }

    @Test("Nothing in gives nothing out")
    func nothing() {
        #expect(TimedFrame.held([]).isEmpty)
    }

    @Test("The last frame stays up as long as the one before it did")
    func lastMatchesThePrevious() {
        let frames = [
            TimedFrame(image: picture(), at: .zero),
            TimedFrame(image: picture(), at: .seconds(2)),
        ]
        #expect(TimedFrame.held(frames).map(\.showFor) == [.seconds(2), .seconds(2)])
    }

    @Test("A frame with nothing before or after it has no length to take from")
    func single() {
        let only = [TimedFrame(image: picture(), at: .seconds(1))]
        #expect(TimedFrame.held(only).map(\.showFor) == [.zero])
    }

    @Test("Moments that run backwards never make a frame stay a negative while")
    func backwards() {
        let frames = [
            TimedFrame(image: picture(), at: .seconds(3)),
            TimedFrame(image: picture(), at: .seconds(1)),
        ]
        #expect(TimedFrame.held(frames).allSatisfy { $0.showFor >= .zero })
    }

    @Test("A scheduled frame says which picture and when, and nothing else")
    func scheduled() {
        let shown = ScheduledFrame(picture: 3, at: .seconds(2))
        #expect(shown.picture == 3)
        #expect(shown.at == .seconds(2))
    }
}
