import EkranbildoContracts
import EkranbildoTestKit
@testable import EkranbildoTimeline
import Testing

@Suite("Dead time")
struct DeadTimeTests {

    private func recording() -> [ActivityWindow] {
        [
            ActivityWindow(from: .seconds(0), to: .seconds(3), changed: true),
            ActivityWindow(from: .seconds(3), to: .seconds(12), changed: false),
            ActivityWindow(from: .seconds(12), to: .seconds(16), changed: true),
        ]
    }

    private func cuts(_ windows: [ActivityWindow]) -> [TimeCut] {
        DeadTimeRemover().cuts(in: windows)
    }

    private static func window(_ from: Double, _ to: Double, changed: Bool) -> ActivityWindow {
        ActivityWindow(from: .seconds(from), to: .seconds(to), changed: changed)
    }

    private static let arrangements: [[ActivityWindow]] = [
        [],
        [window(0, 5, changed: false)],
        [window(0, 5, changed: false), window(5, 10, changed: true)],
        [window(5, 1, changed: false), window(0, 10, changed: false)],
        [window(3, 3, changed: false), window(3, 3, changed: false)],
        [window(10, 2, changed: false), window(2, 10, changed: false)],
        [window(0, 2.5, changed: false)],
        [window(0, 2.9, changed: false)],
    ]

    @Test("A long stretch of nothing is taken out")
    func removesNothing() {
        #expect(!cuts(recording()).isEmpty)
    }

    @Test("A cut stops short of what happened either side")
    func leavesRoom() throws {
        let cut = try #require(cuts(recording()).first)
        #expect(cut.from.seconds > 3)
        #expect(cut.to.seconds < 12)
    }

    @Test("A short pause is left alone")
    func keepsShortPauses() {
        let brief = [
            ActivityWindow(from: .seconds(0), to: .seconds(3), changed: true),
            ActivityWindow(from: .seconds(3), to: .seconds(4), changed: false),
            ActivityWindow(from: .seconds(4), to: .seconds(8), changed: true),
        ]
        #expect(cuts(brief).isEmpty)
    }

    @Test("A recording where something always happens is not cut")
    func nothingToCut() {
        let busy = [ActivityWindow(from: .seconds(0), to: .seconds(20), changed: true)]
        #expect(cuts(busy).isEmpty)
    }

    @Test("A recording of nothing at all is cut down to almost nothing")
    func allDead() {
        let empty = [ActivityWindow(from: .seconds(0), to: .seconds(30), changed: false)]
        let removed = DeadTimeRemover().removed(from: empty)
        #expect(removed.seconds > 20)
    }

    @Test("Cutting never makes a recording longer")
    func neverLonger() {
        for windows in [recording(), [ActivityWindow(from: .zero, to: .seconds(5), changed: true)]] {
            #expect(DeadTimeRemover().removed(from: windows).seconds >= 0)
        }
    }

    @Test("Cuts never overlap")
    func cutsAreDisjoint() {
        let busy = [
            ActivityWindow(from: .seconds(0), to: .seconds(2), changed: true),
            ActivityWindow(from: .seconds(2), to: .seconds(14), changed: false),
            ActivityWindow(from: .seconds(14), to: .seconds(16), changed: true),
            ActivityWindow(from: .seconds(16), to: .seconds(30), changed: false),
            ActivityWindow(from: .seconds(30), to: .seconds(32), changed: true),
        ]
        let cuts = cuts(busy)
        for (earlier, later) in zip(cuts, cuts.dropFirst()) {
            #expect(earlier.to <= later.from, "cuts overlap")
        }
    }

    @Test("Cuts come out in order")
    func ordered() {
        let cuts = cuts(recording())
        #expect(cuts.map(\.from) == cuts.map(\.from).sorted())
    }

    @Test("Every cut removes something")
    func everyCutRemoves() {
        for cut in cuts(recording()) {
            #expect(cut.to > cut.from)
        }
    }

    @Test("A cut survives a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(cuts(recording())))
    }

    @Test("Cutting is reproducible")
    func reproducible() {
        let windows = recording()
        #expect(isReproducible { DeadTimeRemover().cuts(in: windows) })
    }

    @Test("A recording with nothing in it produces no cuts rather than failing")
    func emptyRecording() {
        #expect(DeadTimeRemover().cuts(in: []).isEmpty)
        #expect(DeadTimeRemover().removed(from: []) == .zero)
    }

    @Test("However the windows are arranged, no cut runs backwards")
    func noCutRunsBackwards() {
        for windows in Self.arrangements {
            for cut in cuts(windows) {
                #expect(cut.to > cut.from, "a backwards cut from \(windows)")
            }
        }
    }

    @Test("However the windows are arranged, nothing is ever added")
    func neverAdds() {
        for windows in Self.arrangements {
            #expect(
                DeadTimeRemover().removed(from: windows).nanoseconds >= 0,
                "removing time added some for \(windows)"
            )
        }
    }

    @Test("What is removed is no more than there was")
    func removesNoMoreThanExists() {
        let windows = [Self.window(0, 20, changed: false), Self.window(20, 25, changed: true)]
        let removed = DeadTimeRemover().removed(from: windows)
        #expect(removed <= .seconds(25))
    }

    @Test("A pause with no room left in the middle is not cut at all")
    func nothingLeftAfterLeavingRoom() {
        let generous = DeadTimeRemover(longestPause: 1, breathingRoom: 5)
        #expect(generous.cuts(in: [Self.window(0, 4, changed: false)]).isEmpty)
        #expect(generous.removed(from: [Self.window(0, 4, changed: false)]) == .zero)
    }

    @Test("A pause with room to spare is still cut")
    func roomToSpareIsStillCut() {
        let generous = DeadTimeRemover(longestPause: 1, breathingRoom: 5)
        let cuts = generous.cuts(in: [Self.window(0, 20, changed: false)])
        #expect(cuts.count == 1)
        #expect(cuts.first?.from == .seconds(5))
        #expect(cuts.first?.to == .seconds(15))
    }
}
