import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public struct BeautifyStyle: Hashable, Sendable, Codable {
    public let padding: Double
    public let backgroundStart: Color
    public let backgroundEnd: Color
    public let cornerRadius: Double

    public init(
        padding: Double = Defaults.padding,
        backgroundStart: Color = Defaults.backgroundStart,
        backgroundEnd: Color = Defaults.backgroundEnd,
        cornerRadius: Double = Defaults.cornerRadius
    ) {
        self.padding = max(0, padding)
        self.backgroundStart = backgroundStart
        self.backgroundEnd = backgroundEnd
        self.cornerRadius = max(0, cornerRadius)
    }

    public enum Defaults {
        public static let padding: Double = 48
        public static let backgroundStart = Color(
            red: 0.42, green: 0.47, blue: 0.78, alpha: 1)
        public static let backgroundEnd = Color(
            red: 0.62, green: 0.44, blue: 0.72, alpha: 1)
        public static let cornerRadius: Double = 10
    }
}

public struct FramedShadow: Hashable, Sendable {
    public let blur: Double
    public let offset: P2
    public let color: Color
}

public struct FramedPicture: Hashable, Sendable {
    public let canvas: SceneRect
    public let content: SceneRect
}

public struct Beautifier: Sendable {
    private let style: BeautifyStyle

    public init(style: BeautifyStyle = BeautifyStyle()) {
        self.style = style
    }

    public func frame(_ picture: SceneRect) -> FramedPicture {
        let padding = style.padding
        return FramedPicture(
            canvas: SceneRect(
                x: 0,
                y: 0,
                width: picture.raw.width + padding * Proportion.bothSides,
                height: picture.raw.height + padding * Proportion.bothSides
            ),
            content: SceneRect(
                x: padding,
                y: padding,
                width: picture.raw.width,
                height: picture.raw.height
            )
        )
    }

    public func shadow() -> FramedShadow {
        let room = style.padding
        return FramedShadow(
            blur: room * Proportion.shadowBlur,
            offset: P2(x: 0, y: room * Proportion.shadowDrop),
            color: Depth.color
        )
    }

    public func drawList(for scene: Scene, measurer: any TextMeasuring) -> DrawList {
        let framed = frame(scene.canvas)
        var commands: [DrawCommand] = []

        commands.append(
            .fill(
                .rect(framed.canvas),
                .linearGradient(
                    stops: [
                        GradientStop(location: 0, color: style.backgroundStart),
                        GradientStop(location: 1, color: style.backgroundEnd),
                    ],
                    start: ScenePoint(x: framed.canvas.minX, y: framed.canvas.minY),
                    end: ScenePoint(x: framed.canvas.maxX, y: framed.canvas.maxY)
                )
            )
        )

        if let background = scene.background {
            let outline = Path.roundedRect(framed.content, radius: style.cornerRadius)
            let cast = shadow()
            if cast.blur > 0 || cast.offset.y != 0 {
                commands.append(
                    .shadow(
                        outline,
                        Shadow(
                            blur: cast.blur,
                            offset: ScenePoint(x: cast.offset.x, y: cast.offset.y),
                            color: cast.color
                        )
                    )
                )
            }
            commands.append(
                .image(
                    background,
                    framed.content,
                    opacity: 1,
                    cornerRadius: style.cornerRadius
                )
            )
        }

        let inner = DrawListBuilder(measurer: measurer).build(
            scene.replacing(background: .some(nil))
        )
        commands.append(
            contentsOf: inner.commands.map {
                Self.moved($0, by: P2(x: framed.content.minX, y: framed.content.minY))
            }
        )

        return DrawList(
            canvas: framed.canvas,
            colorSpace: inner.colorSpace,
            commands: commands
        )
    }

    public static func blend(_ from: Color, _ to: Color, at position: Double) -> Color {
        let amount = min(1, max(0, position))
        if amount <= 0 { return from }
        if amount >= 1 { return to }

        func mix(_ a: Double, _ b: Double) -> Double {
            let light =
                TransferFunction.linearFromEncoded(a) * (1 - amount) + TransferFunction.linearFromEncoded(b)
                * amount
            return TransferFunction.encodedFromLinear(light)
        }
        return Color(
            red: mix(from.red, to.red),
            green: mix(from.green, to.green),
            blue: mix(from.blue, to.blue),
            alpha: from.alpha * (1 - amount) + to.alpha * amount
        )
    }

    static func moved(_ command: DrawCommand, by offset: P2) -> DrawCommand {
        switch command {
        case .fill(let path, let paint):
            .fill(Self.moved(path, by: offset), Self.moved(paint, by: offset))
        case .stroke(let path, let stroke):
            .stroke(Self.moved(path, by: offset), stroke)
        case .text(let run):
            .text(
                TextRun(
                    text: run.text,
                    font: run.font,
                    baselineOrigin: ScenePoint(
                        x: run.baselineOrigin.x + offset.x,
                        y: run.baselineOrigin.y + offset.y
                    ),
                    paint: Self.moved(run.paint, by: offset),
                    metrics: run.metrics
                )
            )
        case .image(let ref, let rect, let opacity, let cornerRadius):
            .image(
                ref,
                Self.moved(rect, by: offset),
                opacity: opacity,
                cornerRadius: cornerRadius
            )
        case .shadow(let path, let shadow):
            .shadow(Self.moved(path, by: offset), shadow)
        }
    }

    private static func moved(_ path: Path, by offset: P2) -> Path {
        Path(
            elements: path.elements.map { element in
                switch element {
                case .move(let point): .move(Self.moved(point, by: offset))
                case .line(let point): .line(Self.moved(point, by: offset))
                case .quadCurve(let end, let control):
                    .quadCurve(
                        to: Self.moved(end, by: offset),
                        control: Self.moved(control, by: offset)
                    )
                case .cubicCurve(let end, let first, let second):
                    .cubicCurve(
                        to: Self.moved(end, by: offset),
                        control1: Self.moved(first, by: offset),
                        control2: Self.moved(second, by: offset)
                    )
                case .close: .close
                }
            }
        )
    }

    private static func moved(_ paint: Paint, by offset: P2) -> Paint {
        switch paint {
        case .solid:
            paint
        case .linearGradient(let stops, let start, let end):
            .linearGradient(
                stops: stops,
                start: Self.moved(start, by: offset),
                end: Self.moved(end, by: offset)
            )
        }
    }

    private static func moved(_ point: ScenePoint, by offset: P2) -> ScenePoint {
        ScenePoint(x: point.x + offset.x, y: point.y + offset.y)
    }

    private static func moved(_ rect: SceneRect, by offset: P2) -> SceneRect {
        SceneRect(
            x: rect.minX + offset.x,
            y: rect.minY + offset.y,
            width: rect.raw.width,
            height: rect.raw.height
        )
    }

    private enum Proportion {
        static let bothSides: Double = 2
        static let shadowBlur: Double = 0.5
        static let shadowDrop: Double = 0.25
    }

    private enum Depth {
        private static let opacity = 0.32

        static let color = Color(red: 0, green: 0, blue: 0, alpha: opacity)
    }
}
