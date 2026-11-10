@testable import EkranbildoContracts
import Foundation
import Testing

@Suite("Pipeline version")
struct PipelineVersionTests {

    private func version(
        candidates: String = "1",
        normalization: String = "1",
        weights: String = "abc123",
        comparator: String = "1",
        renderer: String = "1",
        vision: String = "3"
    ) -> PipelineVersion {
        PipelineVersion(
            candidateGeneration: candidates,
            normalization: normalization,
            weights: weights,
            comparator: comparator,
            renderer: renderer,
            visionRevision: vision
        )
    }

    @Test("A version reads as one line")
    func oneLine() {
        let text = version().canonicalText
        #expect(!text.contains("\n"))
        #expect(text.contains("abc123"))
    }

    @Test("Two identical versions are comparable")
    func identical() {
        #expect(version().canComparedWith(version()))
    }

    @Test(
        "A version differing in any part is not comparable",
        arguments: ["candidates", "normalization", "weights", "comparator", "renderer", "vision"]
    )
    func anyPartMakesItIncomparable(part: String) {
        let other =
            switch part {
            case "candidates": version(candidates: "2")
            case "normalization": version(normalization: "2")
            case "weights": version(weights: "def456")
            case "comparator": version(comparator: "2")
            case "renderer": version(renderer: "2")
            default: version(vision: "4")
            }
        #expect(!version().canComparedWith(other))
    }

    @Test("A golden with no version recorded is compared as before")
    func noVersionRecorded() {
        #expect(PipelineVersion.stamp(nil, matches: version()) == nil)
    }

    @Test("A golden whose version matches is compared as before")
    func matchingVersion() {
        #expect(PipelineVersion.stamp(version().canonicalText, matches: version()) == nil)
    }

    @Test("A golden whose version differs is not compared")
    func differingVersion() {
        let stamped = PipelineVersion.stamp(
            version().canonicalText, matches: version(renderer: "9"))
        #expect(stamped != nil)
    }
}
