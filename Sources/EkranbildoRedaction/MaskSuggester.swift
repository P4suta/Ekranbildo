import EkranbildoContracts
import EkranbildoGeometry

public struct MaskSuggester: Sendable {
    private let detector: SecretDetector
    private let style: MaskStyle
    private let bleed: Double

    public init(
        detector: SecretDetector = SecretDetector(),
        style: MaskStyle = .pixelate,
        bleed: Double = Defaults.bleed
    ) {
        self.detector = detector
        self.style = style
        self.bleed = max(0, bleed)
    }

    public enum Defaults {
        public static let bleed: Double = 3
    }

    public func masks(in elements: [ScreenElement]) -> [Mask] {
        elements
            .filter { $0.kind == .text }
            .flatMap { element -> [Mask] in
                guard let text = element.text, !text.isEmpty else { return [] }
                return detector.secrets(in: text).map { secret in
                    Mask(rect: Self.place(secret, of: text, in: element.rect, bleed: bleed), style: style)
                }
            }
            .sorted {
                ($0.rect.minY, $0.rect.minX) < ($1.rect.minY, $1.rect.minX)
            }
    }

    static func place(
        _ secret: Secret,
        of text: String,
        in line: SceneRect,
        bleed: Double
    ) -> SceneRect {
        let total = text.count
        guard total > 0 else { return line }

        let start = text.distance(from: text.startIndex, to: secret.range.lowerBound)
        let length = text.distance(from: secret.range.lowerBound, to: secret.range.upperBound)
        let perCharacter = line.raw.width / Double(total)

        let x = line.minX + Double(start) * perCharacter - bleed
        let width = Double(length) * perCharacter + bleed * Spread.bothSides

        return SceneRect(
            x: x,
            y: line.minY - bleed,
            width: width,
            height: line.raw.height + bleed * Spread.bothSides
        )
    }

    private enum Spread {
        static let bothSides: Double = 2
    }
}
