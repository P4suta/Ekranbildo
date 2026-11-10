import EkranbildoCore
import EkranbildoGeometry
import EkranbildoObservability
import Foundation

public struct FuzzTarget: Sendable {
    public let name: String
    public let accept: @Sendable ([UInt8]) -> Void

    public init(name: String, accept: @escaping @Sendable ([UInt8]) -> Void) {
        self.name = name
        self.accept = accept
    }

    public static let all: [Self] = [
        Self(name: "scene") { bytes in
            _ = try? JSONDecoder().decode(Scene.self, from: Data(bytes))
        },
        Self(name: "replay-bundle") { bytes in
            guard let text = String(bytes: bytes, encoding: .utf8) else { return }
            _ = try? ReplayBundle.decode(text)
        },
        Self(name: "unknown-value") { bytes in
            _ = try? JSONDecoder().decode(UnknownValue.self, from: Data(bytes))
        },
        Self(name: "style-tokens") { bytes in
            _ = try? JSONDecoder().decode(StyleTokens.self, from: Data(bytes))
        },
        Self(name: "trace-synthesis") { bytes in
            guard let text = String(bytes: bytes, encoding: .utf8) else { return }
            _ = TraceSynthesis.applied(to: text)
        },
    ]
}

public enum Corpus {
    public static let seed: UInt64 = 0x536E_6170_6C79_467A
    public static let rounds = 200
    static let longest = 256

    public static let awkward: [[UInt8]] = [
        [],
        Array("{".utf8),
        Array("}".utf8),
        Array("[".utf8),
        Array("null".utf8),
        Array("{\"canvas\":".utf8),
        Array("{\"canvas\": {}}".utf8),
        Array("{\"exportScale\": 1.0e999}".utf8),
        Array("{\"exportScale\": -0}".utf8),
        Array(
            (String(repeating: "[", count: Awkward.deep)
                + String(repeating: "]", count: Awkward.deep)).utf8),
        Array(Awkward.halfACharacter),
        Array(Awkward.notTextAtAll),
        Array("scene.dump 999\n{}".utf8),
        Array("scene.dump -1\n".utf8),
    ]

    private enum Awkward {
        static let deep = 64
        static let halfACharacter: [UInt8] = [0x22, 0xE4, 0xBF]
        static let notTextAtAll: [UInt8] = [0xFF, 0xFE, 0x00, 0x01]
    }

    public static let seeds: [String] = [
        #"{"canvas": {"raw": {"origin": {"x": 0, "y": 0}, "#
            + #""size": {"width": 1, "height": 1}}}, "annotations": []}"#,
        #"{"format": 1, "scene": {}, "pipeline": {}, "answer": []}"#,
        #"{"labelFont": {"family": "A", "size": 1, "weight": "regular", "italic": false}}"#,
        #"[0] solve annotations=2 label=~"secret""#,
    ]

    public static func bytes(using generator: inout SplitMix64) -> [UInt8] {
        let count = Int(generator.next() % UInt64(longest))
        return (0..<count).map { _ in UInt8(truncatingIfNeeded: generator.next()) }
    }

    public static func corrupted(_ original: [UInt8], using generator: inout SplitMix64) -> [UInt8] {
        guard !original.isEmpty else { return original }
        var bytes = original
        let edits = 1 + Int(generator.next() % UInt64(Edits.most))
        for _ in 0..<edits {
            let at = Int(generator.next() % UInt64(bytes.count))
            bytes[at] = UInt8(truncatingIfNeeded: generator.next())
        }
        return bytes
    }

    private enum Edits {
        static let most = 4
    }
}

#if EKRANBILDO_FUZZ
    @_cdecl("LLVMFuzzerTestOneInput")
    public func fuzzOneInput(_ start: UnsafePointer<UInt8>, _ count: Int) -> CInt {
        guard count > 0 else { return 0 }
        let bytes = Array(UnsafeBufferPointer(start: start, count: count))
        let target = FuzzTarget.all[Int(bytes[0]) % FuzzTarget.all.count]
        target.accept(Array(bytes.dropFirst()))
        return 0
    }
#endif
