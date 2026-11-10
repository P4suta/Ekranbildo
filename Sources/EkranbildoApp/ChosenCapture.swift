import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay

public enum ChosenCapture {

    public static func scene(
        of outcome: OverlayOutcome,
        in frozen: FrozenScreen,
        assets: AssetStore
    ) -> Scene? {
        switch outcome {
        case .cancelled:
            return nil
        case .region(let region):
            return scene(of: region, in: frozen, assets: assets)
        case .window(let id):
            let frame = frozen.windows.windows.first { $0.id == id }?.frame
            return frame.flatMap { scene(of: $0, in: frozen, assets: assets) }
        case .display:
            return scene(of: ScreenRect(frozen.display.bounds), in: frozen, assets: assets)
        }
    }

    public static func region(
        of outcome: OverlayOutcome,
        in frozen: FrozenScreen
    ) -> ScreenRect? {
        let wanted: ScreenRect?
        switch outcome {
        case .cancelled:
            wanted = nil
        case .region(let region):
            wanted = region
        case .window(let id):
            wanted = frozen.windows.windows.first { $0.id == id }?.frame
        case .display:
            wanted = ScreenRect(frozen.display.bounds)
        }
        return wanted?.raw.intersection(frozen.display.bounds).map { ScreenRect($0) }
    }

    static func scene(
        of region: ScreenRect,
        in frozen: FrozenScreen,
        assets: AssetStore
    ) -> Scene? {
        guard let pixels = Self.pixels(of: region, in: frozen),
            let cropped = frozen.image.cropped(to: pixels)
        else { return nil }

        let reference = assets.put(cropped)
        let scale = frozen.display.backingScale
        return Scene(
            canvas: SceneRect(
                x: 0,
                y: 0,
                width: Double(cropped.width) / scale,
                height: Double(cropped.height) / scale
            ),
            background: reference,
            annotations: [],
            style: .standard
        )
    }

    static func pixels(of region: ScreenRect, in frozen: FrozenScreen) -> ImageRect? {
        guard let onScreen = region.raw.intersection(frozen.display.bounds) else { return nil }
        let geometry = CaptureGeometry(
            display: frozen.display, regionInScreen: frozen.display.bounds)
        let wanted = geometry.imageRect(of: geometry.sceneRect(of: ScreenRect(onScreen)))

        let left = max(0, Int(wanted.minX.rounded()))
        let top = max(0, Int(wanted.minY.rounded()))
        let right = min(frozen.image.width, Int(wanted.maxX.rounded()))
        let bottom = min(frozen.image.height, Int(wanted.maxY.rounded()))
        guard right > left, bottom > top else { return nil }

        return ImageRect(
            x: Double(left),
            y: Double(top),
            width: Double(right - left),
            height: Double(bottom - top)
        )
    }
}
