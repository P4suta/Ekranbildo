import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability

public enum FixtureDefaults {
    public static let clockTime: Double = 1_767_225_600
}

public struct Advance: Hashable, Sendable {
    public let character: Character
    public let ratio: Double

    public init(_ character: Character, _ ratio: Double) {
        self.character = character
        self.ratio = ratio
    }
}

public struct TabulatedTextMeasurer: TextMeasuring, Sendable {
    private let defaultAdvanceRatio: Double
    private let wideAdvanceRatio: Double
    private let ascentRatio: Double
    private let descentRatio: Double
    private let overrideCharacters: [Character]
    private let overrideRatios: [Double]

    public init(
        defaultAdvanceRatio: Double = 0.5,
        wideAdvanceRatio: Double = 1.0,
        ascentRatio: Double = 0.8,
        descentRatio: Double = 0.2,
        advances: [Advance] = []
    ) {
        self.defaultAdvanceRatio = defaultAdvanceRatio
        self.wideAdvanceRatio = wideAdvanceRatio
        self.ascentRatio = ascentRatio
        self.descentRatio = descentRatio
        let sorted = advances.sorted { String($0.character) < String($1.character) }
        overrideCharacters = sorted.map(\.character)
        overrideRatios = sorted.map(\.ratio)
    }

    public static func uniform() -> Self { Self() }

    public func measure(_ text: String, font: FontSpec) -> TextMetrics {
        var total = DeterministicSum()
        for character in text {
            total.add(ratio(for: character) * font.size)
        }
        return TextMetrics(
            width: total.value(),
            ascent: ascentRatio * font.size,
            descent: descentRatio * font.size
        )
    }

    private func ratio(for character: Character) -> Double {
        if let index = overrideCharacters.firstIndex(of: character) {
            return overrideRatios[index]
        }
        return Self.isWide(character) ? wideAdvanceRatio : defaultAdvanceRatio
    }

    static func isWide(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return WideScripts.ranges.contains { $0.contains(scalar.value) }
    }

    private enum WideScripts {
        static let hangulJamo: ClosedRange<UInt32> = 0x1100...0x115F
        static let cjkRadicalsAndSymbols: ClosedRange<UInt32> = 0x2E80...0x303E
        static let kanaAndCompatibility: ClosedRange<UInt32> = 0x3041...0x33FF
        static let cjkExtensionA: ClosedRange<UInt32> = 0x3400...0x4DBF
        static let cjkUnifiedIdeographs: ClosedRange<UInt32> = 0x4E00...0x9FFF
        static let yiSyllables: ClosedRange<UInt32> = 0xA000...0xA4CF
        static let hangulSyllables: ClosedRange<UInt32> = 0xAC00...0xD7A3
        static let cjkCompatibilityIdeographs: ClosedRange<UInt32> = 0xF900...0xFAFF
        static let cjkCompatibilityForms: ClosedRange<UInt32> = 0xFE30...0xFE6F
        static let fullwidthForms: ClosedRange<UInt32> = 0xFF00...0xFF60
        static let fullwidthSigns: ClosedRange<UInt32> = 0xFFE0...0xFFE6
        static let emoji: ClosedRange<UInt32> = 0x1F300...0x1F64F
        static let supplementalSymbols: ClosedRange<UInt32> = 0x1F900...0x1F9FF
        static let cjkExtensionsBeyondA: ClosedRange<UInt32> = 0x20000...0x3FFFD

        static let ranges = [
            hangulJamo, cjkRadicalsAndSymbols, kanaAndCompatibility, cjkExtensionA,
            cjkUnifiedIdeographs, yiSyllables, hangulSyllables, cjkCompatibilityIdeographs,
            cjkCompatibilityForms, fullwidthForms, fullwidthSigns, emoji,
            supplementalSymbols, cjkExtensionsBeyondA,
        ]
    }
}

public final class ManualClock: Clocking, @unchecked Sendable {
    private var current: Double

    public init(now: Double = FixtureDefaults.clockTime) {
        current = now
    }

    public func now() -> Double { current }

    public func advance(by seconds: Double) { current += seconds }
}

public final class InMemoryFileStore: FileStoring, @unchecked Sendable {
    private var storedNames: [String] = []
    private var storedBytes: [[UInt8]] = []

    public init() {}

    public var names: [String] { storedNames }

    public func store(_ bytes: [UInt8], as name: String) throws -> StoredFile {
        if let index = storedNames.firstIndex(of: name) {
            storedBytes[index] = bytes
        } else {
            let insertion = storedNames.firstIndex { $0 > name } ?? storedNames.count
            storedNames.insert(name, at: insertion)
            storedBytes.insert(bytes, at: insertion)
        }
        return StoredFile(identifier: name, byteCount: bytes.count)
    }

    public func load(_ file: StoredFile) throws -> [UInt8] {
        guard let index = storedNames.firstIndex(of: file.identifier) else {
            throw CapabilityError(
                code: CapabilityError.noSuchFile,
                detail: "no stored file named '\(file.identifier)'"
            )
        }
        return storedBytes[index]
    }
}

extension Capabilities {
    public static func fixture(
        text: any TextMeasuring = TabulatedTextMeasurer.uniform(),
        clock: any Clocking = ManualClock(),
        files: any FileStoring = InMemoryFileStore()
    ) -> Capabilities {
        Capabilities(text: text, clock: clock, files: files)
    }
}
