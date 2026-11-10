import EkranbildoContracts
@testable import EkranbildoCore
import Foundation
import Testing

@Suite("Document corpus")
struct DocumentCorpusTests {

    private static func documents(testFile: StaticString = #filePath) throws -> [(
        name: String, json: String
    )] {
        var url = URL(fileURLWithPath: "\(testFile)")
        while url.pathComponents.count > 1 && url.lastPathComponent != "Tests" {
            url = url.deletingLastPathComponent()
        }
        let directory = url.deletingLastPathComponent().appendingPathComponent("Examples/Documents")

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "ekranbildo" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    @Test("The corpus holds every shape the format has had")
    func corpusIsPresent() throws {
        #expect(try Self.documents().count >= 6)
    }

    @Test("Every document this project has written still opens")
    func everyDocumentOpens() throws {
        for document in try Self.documents() {
            #expect(throws: Never.self, "\(document.name) no longer opens") {
                try JSONDecoder().decode(Scene.self, from: Data(document.json.utf8))
            }
        }
    }

    @Test("Every document still says what it said")
    func everyDocumentKeepsItsContents() throws {
        for document in try Self.documents() {
            let scene = try JSONDecoder().decode(Scene.self, from: Data(document.json.utf8))
            #expect(scene.canvas.raw.width > 0, "\(document.name) lost its canvas")

            let written = try #require(
                try JSONSerialization.jsonObject(with: Data(document.json.utf8))
                    as? [String: Any])
            let expected = (written["annotations"] as? [[String: Any]] ?? []).count
            #expect(scene.annotations.count == expected, "\(document.name) lost annotations")
            for annotation in scene.annotations {
                #expect(!annotation.label.isEmpty, "\(document.name) lost a label")
            }
        }
    }

    @Test("Saving a document keeps what this version does not understand")
    func savingKeepsTheUnfamiliar() throws {
        for document in try Self.documents() {
            let scene = try JSONDecoder().decode(Scene.self, from: Data(document.json.utf8))
            guard !scene.unknownKeys.isEmpty else { continue }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let saved = String(bytes: try encoder.encode(scene), encoding: .utf8) ?? ""
            for entry in scene.unknownKeys.entries {
                #expect(saved.contains(entry.key), "\(document.name) dropped \(entry.key)")
            }
        }
    }

    @Test("The corpus contains a document from a later version")
    func corpusExercisesTheUnfamiliar() throws {
        var carried = 0
        for document in try Self.documents() {
            let scene = try JSONDecoder().decode(Scene.self, from: Data(document.json.utf8))
            carried += scene.unknownKeys.isEmpty ? 0 : 1
        }
        #expect(carried > 0)
    }

    @Test("A document opened and saved twice is the same both times")
    func savingIsStable() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for document in try Self.documents() {
            let once = try encoder.encode(
                try JSONDecoder().decode(Scene.self, from: Data(document.json.utf8)))
            let twice = try encoder.encode(
                try JSONDecoder().decode(Scene.self, from: once))
            #expect(once == twice, "\(document.name) changes every time it is saved")
        }
    }
}
