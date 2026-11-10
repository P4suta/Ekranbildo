import EkranbildoContracts
import EkranbildoGeometry

extension Overlay {
    public var drawList: DrawList {
        var commands: [DrawCommand] = []

        commands.append(
            .image(
                Self.reference(for: frozen),
                SceneRect(frozen.display.bounds),
                opacity: 1,
                cornerRadius: 0
            )
        )

        for part in Self.around(selection, in: SceneRect(frozen.display.bounds)) {
            commands.append(.fill(.rect(part), .solid(Shade.dim)))
        }

        if let selection {
            commands.append(
                .stroke(
                    .rect(SceneRect(selection.raw)),
                    Stroke(paint: .solid(Shade.edge), width: Shade.edgeWidth)
                )
            )
        }

        if let snapped, selection == nil {
            commands.append(
                .stroke(
                    .rect(fromDisplay(snapped)),
                    Stroke(paint: .solid(Shade.highlight), width: Shade.edgeWidth)
                )
            )
        }

        if let highlighted, selection == nil, snapped == nil {
            commands.append(
                .stroke(
                    .rect(SceneRect(highlighted.frame.raw)),
                    Stroke(paint: .solid(Shade.highlight), width: Shade.edgeWidth)
                )
            )
        }

        return DrawList(
            canvas: SceneRect(frozen.display.bounds),
            colorSpace: frozen.image.colorSpace,
            commands: commands
        )
    }

    func fromDisplay(_ rect: SceneRect) -> SceneRect {
        SceneRect(
            x: rect.minX + frozen.display.bounds.minX,
            y: rect.minY + frozen.display.bounds.minY,
            width: rect.width,
            height: rect.height
        )
    }

    static func around(_ selection: ScreenRect?, in canvas: SceneRect) -> [SceneRect] {
        guard let chosen = selection?.raw.intersection(canvas.raw) else { return [canvas] }
        let above = SceneRect(
            x: canvas.minX,
            y: canvas.minY,
            width: canvas.width,
            height: chosen.minY - canvas.minY
        )
        let below = SceneRect(
            x: canvas.minX,
            y: chosen.maxY,
            width: canvas.width,
            height: canvas.maxY - chosen.maxY
        )
        let left = SceneRect(
            x: canvas.minX,
            y: chosen.minY,
            width: chosen.minX - canvas.minX,
            height: chosen.height
        )
        let right = SceneRect(
            x: chosen.maxX,
            y: chosen.minY,
            width: canvas.maxX - chosen.maxX,
            height: chosen.height
        )
        let parts = [above, below, left, right]
        return parts.filter { $0.width > 0 && $0.height > 0 }
    }

    private enum Shade {
        static let dim = Color(red: 0, green: 0, blue: 0, alpha: dimming)
        static let edge = Color(red: 1, green: 1, blue: 1, alpha: opaqueEnough)
        static let highlight = Color(
            red: highlightRed, green: highlightGreen, blue: 1, alpha: opaqueEnough)

        private static let dimming = 0.45
        private static let opaqueEnough = 0.9
        private static let highlightRed = 0.32
        private static let highlightGreen = 0.6

        static let edgeWidth: Double = 1
    }
}

extension Overlay {
    public static func frozenName(of frozen: FrozenScreen) -> String {
        "frozen-\(frozen.display.displayID)"
    }

    static func reference(for frozen: FrozenScreen) -> ImageRef {
        ImageRef(
            contentHash: frozenName(of: frozen),
            pixelWidth: frozen.image.width,
            pixelHeight: frozen.image.height
        )
    }
}
