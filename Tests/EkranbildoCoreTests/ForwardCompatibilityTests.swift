import EkranbildoContracts
@testable import EkranbildoCore
import Foundation
import Testing

@Suite("Forward compatibility")
struct ForwardCompatibilityTests {

    private static let fromTheFuture = """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "annotations": [],
          "somethingAddedLater": {"depth": 3, "names": ["a", "b"]},
          "aFlagFromTheFuture": true
        }
        """

    private func reopened(_ json: String) throws -> String {
        let scene = try JSONDecoder().decode(Scene.self, from: Data(json.utf8))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(bytes: try encoder.encode(scene), encoding: .utf8) ?? ""
    }

    @Test("A key this version has never heard of survives being opened and saved")
    func unknownKeysSurvive() throws {
        let saved = try reopened(Self.fromTheFuture)
        #expect(saved.contains("somethingAddedLater"))
        #expect(saved.contains("aFlagFromTheFuture"))
    }

    @Test("What is carried comes back unchanged")
    func unknownKeysAreUnchanged() throws {
        let saved = try reopened(Self.fromTheFuture)
        let reparsed = try #require(
            try JSONSerialization.jsonObject(with: Data(saved.utf8)) as? [String: Any])

        let nested = try #require(reparsed["somethingAddedLater"] as? [String: Any])
        #expect(nested["depth"] as? Int == 3)
        #expect(nested["names"] as? [String] == ["a", "b"])
        #expect(reparsed["aFlagFromTheFuture"] as? Bool == true)
    }

    @Test("Everything this version does understand is unaffected")
    func knownKeysAreUnaffected() throws {
        let scene = try JSONDecoder().decode(
            Scene.self, from: Data(Self.fromTheFuture.utf8))
        #expect(scene.canvas.raw.width == 400)
        #expect(scene.annotations.isEmpty)
    }

    @Test("A scene with nothing unfamiliar in it gains nothing")
    func noUnknownKeys() throws {
        let plain = """
            {"canvas": {"raw": {"origin": {"x": 0, "y": 0},
             "size": {"width": 10, "height": 10}}}, "annotations": []}
            """
        let saved = try reopened(plain)
        let reparsed = try #require(
            try JSONSerialization.jsonObject(with: Data(saved.utf8)) as? [String: Any])
        #expect(reparsed["unknown"] == nil)
        #expect(
            Set(reparsed.keys).isSubset(of: [
                "canvas", "annotations", "masks", "style", "background", "cursor", "keys",
            ]))
    }

    @Test("Opening and saving twice changes nothing more")
    func stableAcrossTwoRoundTrips() throws {
        let once = try reopened(Self.fromTheFuture)
        #expect(try reopened(once) == once)
    }
}

@Suite("Unknown keys keep an order")
struct UnknownKeyOrderTests {

    @Test("Entries are held in name order, whatever order they arrived in")
    func heldInNameOrder() {
        let keys = UnknownKeys(
            entries: [
                UnknownEntry(key: "zebra", value: .bool(true)),
                UnknownEntry(key: "alpha", value: .number(1)),
                UnknownEntry(key: "middle", value: .string("x")),
            ]
        )
        #expect(keys.entries.map(\.key) == ["alpha", "middle", "zebra"])
    }

    @Test("Two sets of the same entries in different orders are the same set")
    func orderDoesNotChangeIdentity() {
        let one = UnknownKeys(entries: [
            UnknownEntry(key: "b", value: .number(2)), UnknownEntry(key: "a", value: .number(1)),
        ])
        let other = UnknownKeys(entries: [
            UnknownEntry(key: "a", value: .number(1)), UnknownEntry(key: "b", value: .number(2)),
        ])
        #expect(one == other)
    }
}

@Suite("Synthesis stops carrying")
struct SynthesisUnknownKeyTests {

    @Test("A synthesised scene has none of the keys this version could not read")
    func unknownKeysDoNotSurviveSynthesis() throws {
        let json = """
            {
              "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                        "size": {"width": 400, "height": 300}}},
              "annotations": [],
              "aFieldFromLater": "the customer's actual password hint"
            }
            """
        let scene = try JSONDecoder().decode(Scene.self, from: Data(json.utf8))
        #expect(!scene.unknownKeys.isEmpty)

        let synthesised = Synthesis().synthesised(scene)
        #expect(synthesised.unknownKeys.isEmpty)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let saved = String(bytes: try encoder.encode(synthesised), encoding: .utf8) ?? ""
        #expect(!saved.contains("password"))
        #expect(!saved.contains("aFieldFromLater"))
    }
}
