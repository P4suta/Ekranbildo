@testable import EkranbildoTestKit
import Foundation
import Testing

@Suite("LineDiff")
struct LineDiffTests {

    @Test("Identical text produces no diff")
    func identical() {
        #expect(LineDiff.unified(expected: "a\nb", actual: "a\nb") == nil)
    }

    @Test("A changed line is shown with both versions")
    func changedLine() {
        let diff = LineDiff.unified(expected: "a\nb\nc", actual: "a\nB\nc")
        #expect(diff?.contains("-b") == true)
        #expect(diff?.contains("+B") == true)
    }

    @Test("Unchanged lines around a change are kept as context")
    func context() {
        let diff = LineDiff.unified(expected: "a\nb\nc", actual: "a\nB\nc")
        #expect(diff?.contains(" a") == true)
        #expect(diff?.contains(" c") == true)
    }

    @Test("An added line is marked as an addition only")
    func addition() {
        let diff = LineDiff.unified(expected: "a\nc", actual: "a\nb\nc")
        #expect(diff?.contains("+b") == true)
        #expect(diff?.contains("-") == false)
    }

    @Test("A removed line is marked as a removal only")
    func removal() {
        let diff = LineDiff.unified(expected: "a\nb\nc", actual: "a\nc")
        #expect(diff?.contains("-b") == true)
        #expect(diff?.contains("+") == false)
    }

    @Test("Distant unchanged regions are elided")
    func elision() {
        let expected = (0..<60).map { "line \($0)" }.joined(separator: "\n")
        let actual = expected.replacingOccurrences(of: "line 30", with: "line THIRTY")
        let diff = LineDiff.unified(expected: expected, actual: actual)
        #expect(diff?.contains("line 0") == false)
        #expect(diff?.contains("line 29") == true)
        #expect(diff?.contains("@@") == true)
    }
}

@Suite("GoldenStore")
struct GoldenStoreTests {

    private func makeStore(updating: Bool = false) throws -> (GoldenStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-golden-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (GoldenStore(directory: directory, updating: updating), directory)
    }

    @Test("A missing golden is written and reported as created")
    func createsMissingGolden() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try store.compare("hello", named: "sample.txt")
        #expect(result == .created)
        #expect(
            try String(contentsOf: directory.appendingPathComponent("sample.txt"), encoding: .utf8) == "hello"
        )
    }

    @Test("Matching content is reported as a match")
    func matches() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try store.compare("hello", named: "sample.txt")
        #expect(try store.compare("hello", named: "sample.txt") == .matched)
    }

    @Test("A mismatch fails rather than quietly updating the file")
    func mismatchDoesNotUpdate() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try store.compare("hello", named: "sample.txt")
        let result = try store.compare("goodbye", named: "sample.txt")

        guard case .mismatched(let diff) = result else {
            Issue.record("expected a mismatch, got \(result)")
            return
        }
        #expect(diff.contains("-hello"))
        #expect(diff.contains("+goodbye"))
        let onDisk = try String(
            contentsOf: directory.appendingPathComponent("sample.txt"), encoding: .utf8)
        #expect(onDisk == "hello")
    }

    @Test("Updating is explicit and rewrites the file")
    func explicitUpdate() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try store.compare("hello", named: "sample.txt")
        let updating = GoldenStore(directory: directory, updating: true)
        #expect(try updating.compare("goodbye", named: "sample.txt") == .updated)
        let onDisk = try String(
            contentsOf: directory.appendingPathComponent("sample.txt"), encoding: .utf8)
        #expect(onDisk == "goodbye")
    }

    @Test("Nested names create the directories they need")
    func nestedNames() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try store.compare("x", named: "render/basic.svg") == .created)
        #expect(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("render/basic.svg").path))
    }
}
