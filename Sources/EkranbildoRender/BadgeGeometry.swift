import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public enum BadgeGeometry {

    public static func rect(
        in plate: SceneRect,
        style: StyleTokens,
        reading: ReadingDirection = .leftToRight
    ) -> SceneRect {
        let inset = max(0, Geo.centring(style.badgeDiameter, in: plate.raw.height))
        let x =
            reading == .leftToRight
            ? plate.minX + inset
            : plate.maxX - inset - style.badgeDiameter
        return SceneRect(
            x: x,
            y: plate.minY + inset,
            width: style.badgeDiameter,
            height: style.badgeDiameter
        )
    }

    public static func baseline(
        in disc: SceneRect,
        metrics: TextMetrics
    ) -> ScenePoint {
        ScenePoint(
            x: disc.raw.center.x - Geo.half(metrics.width),
            y: disc.raw.center.y + Geo.half(metrics.ascent)
        )
    }

    public static func path(of disc: SceneRect) -> Path {
        Path.roundedRect(disc, radius: disc.raw.radius)
    }
}
