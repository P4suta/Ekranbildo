import EkranbildoContracts
import EkranbildoCore

public enum RenderVersion {
    public static let current = of(reference)

    public static func of(_ scene: Scene) -> String {
        "draw-" + Fingerprint.of(DrawListBuilder(measurer: FixedMetrics()).build(scene).canonicalText)
    }

    public static let reference = Scene(
        canvas: SceneRect(x: 0, y: 0, width: Reference.canvasWidth, height: Reference.canvasHeight),
        background: nil,
        annotations: [
            Annotation(
                id: AnnotationID(Reference.firstIdentifier),
                target: SceneRect(
                    x: Reference.firstTargetX,
                    y: Reference.firstTargetY,
                    width: Reference.targetWidth,
                    height: Reference.targetHeight
                ),
                label: "Reference",
                placement: Placement(direction: .nne, leaderLength: Reference.leader),
                badge: BadgeNumber(Reference.firstStep)
            ),
            Annotation(
                id: AnnotationID(Reference.secondIdentifier),
                target: SceneRect(
                    x: Reference.secondTargetX,
                    y: Reference.secondTargetY,
                    width: Reference.targetWidth,
                    height: Reference.targetHeight
                ),
                label: "Second",
                placement: Placement(direction: .w, leaderLength: Reference.leader),
                badge: nil
            ),
        ],
        style: .standard
    )

    private enum Reference {
        static let firstIdentifier: UInt32 = 1
        static let secondIdentifier: UInt32 = 2
        static let firstStep = 1
        static let canvasWidth: Double = 400
        static let canvasHeight: Double = 300
        static let firstTargetX: Double = 40
        static let firstTargetY: Double = 180
        static let secondTargetX: Double = 240
        static let secondTargetY: Double = 60
        static let targetWidth: Double = 80
        static let targetHeight: Double = 24
        static let leader: Double = 64
    }

    private struct FixedMetrics: TextMeasuring {
        func measure(_ text: String, font: FontSpec) -> TextMetrics {
            TextMetrics(
                width: Double(text.count) * font.size * Glyph.widthInEms,
                ascent: font.size * Glyph.ascentInEms,
                descent: font.size * Glyph.descentInEms
            )
        }

        private enum Glyph {
            static let widthInEms = 0.6
            static let ascentInEms = 0.8
            static let descentInEms = 0.2
        }
    }
}
