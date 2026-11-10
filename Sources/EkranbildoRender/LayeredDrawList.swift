import EkranbildoContracts
import EkranbildoCore

public struct LayeredDrawList: Hashable, Sendable {
    public let canvas: SceneRect
    public let colorSpace: CanonicalColorSpace
    public let background: [DrawCommand]
    public let still: [DrawCommand]
    public let moving: [DrawCommand]

    public init(
        canvas: SceneRect,
        colorSpace: CanonicalColorSpace,
        background: [DrawCommand],
        still: [DrawCommand],
        moving: [DrawCommand]
    ) {
        self.canvas = canvas
        self.colorSpace = colorSpace
        self.background = background
        self.still = still
        self.moving = moving
    }

    public func drawing(of commands: [DrawCommand]) -> DrawList {
        DrawList(canvas: canvas, colorSpace: colorSpace, commands: commands)
    }

    public var movingBounds: SceneRect? { DrawCommand.bounds(of: moving) }
}

extension DrawListBuilder {
    public func layered(_ scene: Scene, moving: [AnnotationID]) -> LayeredDrawList {
        var background: [DrawCommand] = []
        var still: [DrawCommand] = []
        var active: [DrawCommand] = []

        if let picture = scene.background {
            background.append(.image(picture, scene.canvas, opacity: 1, cornerRadius: 0))
        }
        if let cursor = scene.cursor {
            background.append(contentsOf: cursorCommands(cursor, style: scene.style))
        }

        for annotation in scene.annotations {
            guard let placement = annotation.placement else { continue }
            let commands = commandsFor(annotation, placement: placement, style: scene.style)
            if moving.contains(annotation.id) {
                active.append(contentsOf: commands)
            } else {
                still.append(contentsOf: commands)
            }
        }

        return LayeredDrawList(
            canvas: scene.canvas,
            colorSpace: colorSpace,
            background: background,
            still: still,
            moving: active
        )
    }
}
