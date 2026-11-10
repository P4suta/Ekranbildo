import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoStitch
import Testing

@Suite("Scrolling, while it happens")
struct ScrollSessionTests {

    private static let pageHeight = 2000
    private static let viewport = 400
    private static let width = 120

    private static let page = ScrollSimulator.page(width: width, height: pageHeight)

    private static func simulator(
        stickyTop: Int = 0,
        noise: Int = 0
    ) -> ScrollSimulator {
        ScrollSimulator(
            page: page, viewportHeight: viewport, stickyTop: stickyTop, noise: noise)
    }

    private static func session(
        _ offsets: [Int],
        simulator: ScrollSimulator = simulator()
    ) -> ScrollSession {
        var session = ScrollSession()
        for frame in simulator.frames(offsets: offsets) {
            session = session.offered(frame.image)
        }
        return session
    }

    @Test("The first frame is always worth keeping")
    func firstFrame() {
        #expect(Self.session([0]).kept.count == 1)
    }

    @Test("A page that has barely moved is not worth another picture")
    func barelyMoved() {
        let crawling = (0..<20).map { $0 * 2 }
        #expect(Self.session(crawling).kept.count == 1)
    }

    @Test("A frame is kept before the frames stop overlapping")
    func keptBeforeOverlapIsLost() {
        let stepping = [0, 150, 300, 450, 600]
        let session = Self.session(stepping)
        #expect(session.missedJoins == 0)
        #expect(session.framesToJoin.count < stepping.count)
        let stitcher = Stitcher()
        for (earlier, later) in zip(session.framesToJoin, session.framesToJoin.dropFirst()) {
            #expect(stitcher.shift(from: earlier, to: later) != nil)
        }
    }

    @Test("The frame it ended on is part of the page")
    func trailingFrameIsKept() throws {
        let session = Self.session([0, 300, 340])
        #expect(session.kept.count == 2)
        #expect(session.framesToJoin.count == 3)
        #expect(try session.finish().image.height == Self.viewport + 340)
    }

    @Test("What was kept joins back into the page it came from")
    func keptFramesStitch() throws {
        let joined = try Self.session([0, 150, 300, 450, 600, 750]).finish()
        #expect(joined.uncertainJoins.isEmpty)
        #expect(joined.image.height == Self.viewport + 750)
    }

    @Test("A scroll that is going well has nothing said about it")
    func nothingToSay() {
        #expect(Self.session([0, 150, 300]).advice == .keepGoing)
    }

    @Test("A scroll faster than the frames overlap says so")
    func tooFast() {
        let session = Self.session([0, 600, 1200])
        #expect(session.advice == .slowDown)
        #expect(session.missedJoins > 0)
    }

    @Test("Slowing down stops it being said")
    func slowingDown() {
        let session = Self.session([0, 600, 750, 900])
        #expect(session.advice == .keepGoing)
        #expect(session.missedJoins == 1)
    }

    @Test("A page that has stopped is not remarked on immediately")
    func stoppedBriefly() {
        #expect(Self.session([0, 0, 0]).advice == .keepGoing)
    }

    @Test("A page that has stopped for a while is remarked on")
    func stoppedForAWhile() {
        let still = [Int](repeating: 0, count: ScrollSession.Defaults.stillnessBeforeSaying + 2)
        #expect(Self.session(still).advice == .nothingIsMoving)
    }

    @Test("A frame of a different size is refused rather than joined")
    func sizeChanged() {
        var session = ScrollSession()
        for frame in Self.simulator().frames(offsets: [0, 150]) {
            session = session.offered(frame.image)
        }
        let narrower = ScrollSimulator(
            page: ScrollSimulator.page(width: Self.width / 2, height: Self.pageHeight),
            viewportHeight: Self.viewport
        ).frames(offsets: [300])[0].image

        let after = session.offered(narrower)
        #expect(after.advice == .theScreenChanged)
        #expect(after.kept.count == session.kept.count)
    }

    @Test("What has been seen is counted in rows of the page")
    func progressInRows() {
        #expect(Self.session([0]).coveredRows == Self.viewport)
        #expect(Self.session([0, 100]).coveredRows == Self.viewport + 100)
        #expect(Self.session([0, 100, 250]).coveredRows == Self.viewport + 250)
    }

    @Test("What has been seen moves even between the frames worth keeping")
    func progressBetweenKeptFrames() {
        let session = Self.session([0, 20])
        #expect(session.kept.count == 1)
        #expect(session.coveredRows == Self.viewport + 20)
    }

    @Test("Scrolling back over the same rows does not see them twice")
    func scrollingBack() {
        #expect(Self.session([0, 150, 300, 150, 0]).coveredRows == Self.viewport + 300)
    }

    @Test("Scrolling up from the middle counts what was above")
    func scrollingUp() {
        #expect(Self.session([600, 450, 300]).coveredRows == Self.viewport + 300)
    }

    @Test("The same frames give the same session")
    func reproducible() {
        let offsets = [0, 120, 260, 260, 400, 1200, 1340]
        let once = Self.session(offsets)
        let twice = Self.session(offsets)
        #expect(once.kept.map(\.pixels) == twice.kept.map(\.pixels))
        #expect(once.coveredRows == twice.coveredRows)
        #expect(once.missedJoins == twice.missedJoins)
        #expect(once.advice == twice.advice)
        #expect(once.rowComparisons == twice.rowComparisons)
    }

    @Test("The work it did is counted")
    func workIsCounted() {
        let session = Self.session([0, 150, 300])
        #expect(session.rowComparisons > 0)
    }

    @Test("Noise on the frames does not change what is kept")
    func noiseDoesNotMatter() {
        let clean = Self.session([0, 150, 300, 450])
        let noisy = Self.session([0, 150, 300, 450], simulator: Self.simulator(noise: 6))
        #expect(clean.kept.count == noisy.kept.count)
        #expect(clean.coveredRows == noisy.coveredRows)
    }

    @Test("A header pinned to the top does not look like a page that stopped")
    func pinnedHeader() {
        let session = Self.session(
            [0, 150, 300, 450], simulator: Self.simulator(stickyTop: 60))
        #expect(session.advice == .keepGoing)
        #expect(session.coveredRows == Self.viewport + 450)
    }

    @Test("A session nobody gave a frame to has seen nothing")
    func empty() {
        let session = ScrollSession()
        #expect(session.kept.isEmpty)
        #expect(session.coveredRows == 0)
        #expect(session.advice == .keepGoing)
    }
}
