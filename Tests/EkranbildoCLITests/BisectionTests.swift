@testable import EkranbildoCLI
import Testing

@Suite("Bisection")
struct BisectionTests {

    private final class Range: @unchecked Sendable {
        let versions: [String]
        private(set) var asked: [String] = []
        private let changingAt: Int

        init(_ count: Int, changingAt: Int) {
            versions = (0..<count).map { "v\($0)" }
            self.changingAt = changingAt
        }

        func answer(_ version: String) -> String {
            asked.append(version)
            let index = versions.firstIndex(of: version) ?? 0
            return index >= changingAt ? "different" : "recorded"
        }

        func search() -> Bisection.Search {
            Bisection.firstDiffering(over: versions, matching: "recorded", answer: answer)
        }
    }

    @Test("There is nothing to search when no version is offered")
    func nothingToSearch() {
        let search = Bisection.firstDiffering(over: [], matching: "recorded") { _ in "recorded" }
        #expect(search.outcome == .nothingToSearch)
        #expect(search.probes == 0)
    }

    @Test("Nothing differs when the newest version still agrees")
    func noneDiffer() {
        let range = Range(8, changingAt: 8)
        #expect(range.search().outcome == .noneDiffer)
        #expect(range.asked == ["v7"])
    }

    @Test("Everything differs when the oldest version already disagrees")
    func allDiffer() {
        #expect(Range(8, changingAt: 0).search().outcome == .allDiffer(oldest: "v0"))
    }

    @Test("The boundary is found, and the version before it is named")
    func findsTheBoundary() {
        #expect(Range(8, changingAt: 5).search().outcome == .found(version: "v5", previous: "v4"))
    }

    @Test("It finds a boundary at either end of the range too", arguments: [1, 7])
    func findsEdgeBoundaries(changingAt: Int) {
        #expect(
            Range(8, changingAt: changingAt).search().outcome
                == .found(version: "v\(changingAt)", previous: "v\(changingAt - 1)")
        )
    }

    @Test("A single version that differs is the whole range differing")
    func singleDifferingVersion() {
        #expect(Range(1, changingAt: 0).search().outcome == .allDiffer(oldest: "v0"))
    }

    @Test("The number of builds asked grows with the logarithm of the range")
    func probesGrowLogarithmically() {
        let range = Range(1024, changingAt: 613)
        let search = range.search()
        #expect(search.outcome == .found(version: "v613", previous: "v612"))
        #expect(search.probes == 12)
        #expect(range.asked.count == search.probes)
    }

    @Test("No version is asked twice")
    func asksEachVersionOnce() {
        let range = Range(64, changingAt: 37)
        _ = range.search()
        #expect(Set(range.asked).count == range.asked.count)
    }

    @Test("The boundary it reports is one it actually asked about")
    func theBoundaryIsProven() {
        let range = Range(32, changingAt: 19)
        guard case .found(let version, let previous) = range.search().outcome else {
            Issue.record("expected a boundary")
            return
        }
        #expect(range.asked.contains(version))
        #expect(range.asked.contains(previous))
    }

    @Test("What it found reads as something to act on")
    func outcomeReads() {
        let report = Range(8, changingAt: 5).search().report
        #expect(report.contains("v5"))
        #expect(report.contains("v4"))
    }
}
