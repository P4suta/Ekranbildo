import EkranbildoContracts
@testable import EkranbildoTestKit
import Foundation
import Testing

@Suite("Pipeline versions in goldens")
struct GoldenPipelineVersionTests {

    private func version(
        candidates: String = "grid-1",
        normalization: String = "norm-1",
        weights: String = "w-1",
        comparator: String = "cmp-1",
        renderer: String = "cg-1",
        vision: String = "vision-3"
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

    @Test("A golden from another build is reported as not comparable, not as wrong")
    func notComparableIsNotAFailure() {
        let result = GoldenResult.incomparable(
            recorded: version().canonicalText, now: version(weights: "def456").canonicalText)
        #expect(!result.isAcceptable)
        #expect(result.message.contains("not comparable"))
        #expect(!result.message.lowercased().contains("mismatch"))
    }

    @Test("It says which part of the pipeline moved")
    func saysWhatMoved() {
        let result = GoldenResult.incomparable(
            recorded: version().canonicalText,
            now: version(weights: "def456").canonicalText
        )
        #expect(result.message.contains("w-1"))
        #expect(result.message.contains("def456"))
    }

    private func store() -> (GoldenStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-goldens-\(UUID().uuidString)")
        return (GoldenStore(directory: directory, updating: false), directory)
    }

    @Test("A golden records the pipeline that made it")
    func recordsTheVersion() throws {
        let (store, directory) = store()
        #expect(try store.compare("answer", named: "a.txt", version: version()) == .created)

        let written = try String(
            contentsOf: directory.appendingPathComponent("a.txt"), encoding: .utf8)
        #expect(written.hasPrefix("pipeline "))
        #expect(written.contains("answer"))
    }

    @Test("A golden from the same pipeline is compared as usual")
    func samePipelineCompares() throws {
        let (store, _) = store()
        _ = try store.compare("answer", named: "a.txt", version: version())
        #expect(try store.compare("answer", named: "a.txt", version: version()) == .matched)
        #expect(!(try store.compare("different", named: "a.txt", version: version())).isAcceptable)
    }

    @Test("A golden from another pipeline is not compared at all")
    func otherPipelineIsNotCompared() throws {
        let (store, _) = store()
        _ = try store.compare("answer", named: "a.txt", version: version())

        let result = try store.compare("different", named: "a.txt", version: version(renderer: "9"))
        guard case .incomparable = result else {
            Issue.record("expected not comparable, got \(result)")
            return
        }
    }

    @Test("A golden from another pipeline is not compared even when it agrees")
    func otherPipelineIsNotComparedWhenItAgrees() throws {
        let (store, _) = store()
        _ = try store.compare("answer", named: "a.txt", version: version())

        let result = try store.compare("answer", named: "a.txt", version: version(renderer: "9"))
        guard case .incomparable = result else {
            Issue.record("expected not comparable, got \(result)")
            return
        }
    }

    @Test("A golden written before versions existed still compares")
    func unstampedStillCompares() throws {
        let (store, _) = store()
        #expect(try store.compare("answer", named: "a.txt") == .created)
        #expect(try store.compare("answer", named: "a.txt", version: version()) == .matched)
    }

    @Test("A golden that merely starts with the word is not read as a stamp")
    func lookalikeFirstLine() {
        let stored = GoldenStore.split("pipelines are fine\nsecond line")
        let recorded = stored.version
        let contents = stored.contents
        #expect(recorded == nil)
        #expect(contents == "pipelines are fine\nsecond line")
    }

    @Test("Re-recording replaces the version as well as the contents")
    func reRecordingUpdatesTheVersion() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-goldens-\(UUID().uuidString)")
        _ = try GoldenStore(directory: directory, updating: false)
            .compare("answer", named: "a.txt", version: version())

        let updating = GoldenStore(directory: directory, updating: true)
        #expect(try updating.compare("new", named: "a.txt", version: version(renderer: "9")) == .updated)

        let written = try String(
            contentsOf: directory.appendingPathComponent("a.txt"), encoding: .utf8)
        #expect(written.contains("renderer=9"))
        #expect(written.contains("new"))
    }
}
