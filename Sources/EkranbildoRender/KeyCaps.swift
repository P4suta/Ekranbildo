import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

extension DrawListBuilder {
    func keyCapCommands(_ caps: [String], style: StyleTokens, canvas: SceneRect) -> [DrawCommand] {
        guard !caps.isEmpty else { return [] }

        let boxes = Self.plates(for: caps, style: style, canvas: canvas, measurer: measurer)
        var commands: [DrawCommand] = []
        for (cap, box) in zip(caps, boxes) {
            commands.append(
                .fill(
                    .roundedRect(box, radius: style.labelPlateCornerRadius),
                    .solid(style.labelPlateColor)
                ))
            let metrics = measurer.measure(cap, font: style.labelFont)
            commands.append(
                .text(
                    TextRun(
                        text: cap,
                        font: style.labelFont,
                        baselineOrigin: ScenePoint(
                            x: box.minX + style.labelPaddingHorizontal,
                            y: box.minY + style.labelPaddingVertical + metrics.ascent
                        ),
                        paint: .solid(style.labelColor),
                        metrics: metrics
                    )))
        }
        return commands
    }

    static func plates(
        for caps: [String],
        style: StyleTokens,
        canvas: SceneRect,
        measurer: any TextMeasuring
    ) -> [SceneRect] {
        let widths = caps.map {
            measurer.measure($0, font: style.labelFont).width
                + Spacing.sides * style.labelPaddingHorizontal
        }
        let tallest =
            caps.map { measurer.measure($0, font: style.labelFont) }
            .map { $0.ascent + $0.descent }
            .max() ?? 0
        let height = tallest + Spacing.sides * style.labelPaddingVertical

        var total = DeterministicSum()
        for width in widths { total.add(width) }
        let row = total.value() + Double(max(0, caps.count - 1)) * style.labelMinimumGap

        var left = canvas.minX + (canvas.width - row) / Spacing.sides
        let top = canvas.maxY - height - Spacing.bottomMargin * height

        var boxes: [SceneRect] = []
        for width in widths {
            boxes.append(SceneRect(x: left, y: top, width: width, height: height))
            left += width + style.labelMinimumGap
        }
        return boxes
    }

    private enum Spacing {
        static let sides: Double = 2
        static let bottomMargin: Double = 0.5
    }
}
