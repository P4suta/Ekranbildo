import EkranbildoContracts
import EkranbildoGeometry

public enum ApplicationIcon {
    public static let sizes = [16, 32, 64, 128, 256, 512, 1024]

    public static func drawList(side: Double) -> DrawList {
        let canvas = SceneRect(x: 0, y: 0, width: side, height: side)
        let plate = SceneRect(
            x: side * Layout.margin,
            y: side * Layout.margin,
            width: side * Layout.plate,
            height: side * Layout.plate
        )
        let lens = SceneRect(
            Rect(
                centredOn: plate.raw.center,
                size: Size(width: side * Layout.lens, height: side * Layout.lens)
            ))
        let pupil = SceneRect(
            Rect(
                centredOn: plate.raw.center,
                size: Size(width: side * Layout.pupil, height: side * Layout.pupil)
            ))

        return DrawList(
            canvas: canvas,
            colorSpace: .displayP3,
            commands: [
                .fill(
                    .roundedRect(plate, radius: side * Layout.corner),
                    .solid(Palette.plate)
                ),
                .fill(
                    .circle(centre: ScenePoint(lens.raw.center), radius: lens.raw.radius),
                    .solid(Palette.lens)
                ),
                .fill(
                    .circle(centre: ScenePoint(pupil.raw.center), radius: pupil.raw.radius),
                    .solid(Palette.pupil)
                ),
            ]
        )
    }

    private enum Layout {
        static let margin = 0.08
        static let plate = 0.84
        static let corner = 0.19
        static let lens = 0.46
        static let pupil = 0.22
    }

    private enum Palette {
        static let plate = Color(red: 0.16, green: 0.20, blue: 0.28, alpha: 1)
        static let lens = Color(red: 0.98, green: 0.98, blue: 1, alpha: 1)
        static let pupil = Color(red: 0.32, green: 0.60, blue: 1, alpha: 1)
    }
}
