import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public struct DrawListBuilder: Sendable {
    let measurer: any TextMeasuring
    private let reading: ReadingDirection
    let colorSpace: CanonicalColorSpace

    public init(
        measurer: any TextMeasuring,
        colorSpace: CanonicalColorSpace = .displayP3,
        reading: ReadingDirection = .leftToRight
    ) {
        self.measurer = measurer
        self.colorSpace = colorSpace
        self.reading = reading
    }

    public func build(_ scene: Scene) -> DrawList {
        var commands: [DrawCommand] = []

        if let background = scene.background {
            commands.append(.image(background, scene.canvas, opacity: 1, cornerRadius: 0))
        }

        for mask in scene.masks {
            commands.append(contentsOf: maskCommands(mask))
        }

        if let cursor = scene.cursor {
            commands.append(contentsOf: cursorCommands(cursor, style: scene.style))
        }

        for annotation in scene.annotations {
            guard let placement = annotation.placement else { continue }
            commands.append(
                contentsOf: commandsFor(annotation, placement: placement, style: scene.style)
            )
        }

        commands.append(
            contentsOf: keyCapCommands(scene.keys, style: scene.style, canvas: scene.canvas))

        return DrawList(canvas: scene.canvas, colorSpace: colorSpace, commands: commands)
    }

    func maskCommands(_ mask: Mask) -> [DrawCommand] {
        [.fill(.rect(mask.rect), .solid(Self.shade(of: mask.style)))]
    }

    static func shade(of mask: MaskStyle) -> Color {
        switch mask {
        case .solid, .pixelate:
            Color(red: Hidden.grey, green: Hidden.grey, blue: Hidden.grey, alpha: 1)
        }
    }

    enum Hidden {
        static let grey = 0.35
    }

    func commandsFor(
        _ annotation: Annotation,
        placement: Placement,
        style: StyleTokens
    ) -> [DrawCommand] {
        let resolved = ResolvedPlacement(target: annotation.target, placement: placement, style: style)
        let plate = labelPlate(for: annotation, at: resolved, style: style)

        return [
            .stroke(
                Path.polyline(resolved.leader),
                Stroke(paint: .solid(style.leaderColor), width: style.leaderWidth, cap: .round)
            ),
            .fill(arrowhead(at: resolved, style: style), .solid(style.leaderColor)),
            .fill(
                Path.roundedRect(plate.rect, cornerRadius: style.labelPlateCornerRadius),
                .solid(style.labelPlateColor)
            ),
            .text(
                TextRun(
                    text: annotation.label,
                    font: style.labelFont,
                    baselineOrigin: plate.baselineOrigin,
                    paint: .solid(style.labelColor),
                    metrics: plate.metrics
                )
            ),
        ]
            + badgeCommands(
                annotation.badge, in: plate.rect, style: style, reading: reading)
    }

    func cursorCommands(_ cursor: Cursor, style: StyleTokens) -> [DrawCommand] {
        guard cursor.opacity > 0 else { return [] }

        func faded(_ color: Color) -> Paint {
            .solid(
                Color(
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: color.alpha * cursor.opacity
                ))
        }

        var commands: [DrawCommand] = []

        if let ripple = cursor.ripple {
            commands.append(
                .stroke(
                    Path.circle(
                        centre: cursor.position,
                        radius: style.cursorSize * style.rippleSpread * ripple
                    ),
                    Stroke(
                        paint: faded(
                            Color(
                                red: style.rippleColor.red,
                                green: style.rippleColor.green,
                                blue: style.rippleColor.blue,
                                alpha: style.rippleColor.alpha * (1 - ripple)
                            )),
                        width: style.rippleWidth,
                        cap: .round
                    )
                ))
        }

        let outline = Icon.pointer.path(
            in: Icon.pointer.box(size: style.cursorSize, pointingAt: cursor.position))

        commands.append(
            .stroke(
                outline,
                Stroke(
                    paint: faded(style.cursorOutlineColor),
                    width: style.cursorOutlineWidth,
                    join: .round
                )
            ))
        commands.append(.fill(outline, faded(style.cursorColor)))

        return commands
    }

    private func badgeCommands(
        _ badge: BadgeNumber?,
        in plate: SceneRect,
        style: StyleTokens,
        reading: ReadingDirection
    ) -> [DrawCommand] {
        guard let badge else { return [] }

        let disc = BadgeGeometry.rect(in: plate, style: style, reading: reading)
        let text = badge.description
        let metrics = measurer.measure(text, font: style.badgeFont)

        return [
            .fill(BadgeGeometry.path(of: disc), .solid(style.badgeColor)),
            .text(
                TextRun(
                    text: text,
                    font: style.badgeFont,
                    baselineOrigin: BadgeGeometry.baseline(in: disc, metrics: metrics),
                    paint: .solid(style.badgeTextColor),
                    metrics: metrics
                )
            ),
        ]
    }

    private func labelPlate(
        for annotation: Annotation,
        at resolved: ResolvedPlacement,
        style: StyleTokens
    ) -> LabelPlate {
        let metrics = measurer.measure(annotation.label, font: style.labelFont)
        let size = LabelMetrics.size(of: annotation, style: style, measurer: measurer)
        let rect = resolved.labelBox(textSize: size, style: style)
        let baseline = resolved.labelBaseline(metrics: metrics, style: style, textSize: size)
        return LabelPlate(
            rect: rect,
            baselineOrigin: annotation.badge == nil || reading == .rightToLeft
                ? baseline
                : ScenePoint(
                    x: baseline.x + LabelMetrics.badgeAllowance(style: style),
                    y: baseline.y
                ),
            metrics: metrics
        )
    }

    private struct LabelPlate {
        let rect: SceneRect
        let baselineOrigin: ScenePoint
        let metrics: TextMetrics
    }

    private func arrowhead(at resolved: ResolvedPlacement, style: StyleTokens) -> Path {
        let outward = resolved.direction.unit
        let perpendicular = P2(x: -outward.y, y: outward.x)
        let apex = resolved.tip.raw
        let baseCenter = P2(
            x: apex.x + outward.x * style.arrowheadLength,
            y: apex.y + outward.y * style.arrowheadLength
        )
        let half = style.arrowheadHalfWidth

        return Path(elements: [
            .move(ScenePoint(apex)),
            .line(
                ScenePoint(
                    P2(
                        x: baseCenter.x + perpendicular.x * half,
                        y: baseCenter.y + perpendicular.y * half
                    )
                )
            ),
            .line(
                ScenePoint(
                    P2(
                        x: baseCenter.x - perpendicular.x * half,
                        y: baseCenter.y - perpendicular.y * half
                    )
                )
            ),
            .close,
        ])
    }
}
