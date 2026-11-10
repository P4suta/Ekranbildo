import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoOverlay
import EkranbildoRenderCoreGraphics
import Testing

@Suite("What the overlay puts on the screen", .serialized)
@MainActor
struct OverlayLooksRightTests {

    private struct Screen {
        let bounds: Rect
        let scale: Double
    }

    private static var screens: [Screen] {
        NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            let id = (number as? UInt32) ?? 0
            let bounds = CGDisplayBounds(id)
            return Screen(
                bounds: Rect(
                    x: Double(bounds.origin.x),
                    y: Double(bounds.origin.y),
                    width: Double(bounds.width),
                    height: Double(bounds.height)
                ),
                scale: Double(screen.backingScaleFactor)
            )
        }
    }

    private static func frozen(_ screen: Screen, windows: [WindowDescriptor] = []) -> FrozenScreen {
        let display = DisplayGeometry(
            displayID: 1, bounds: screen.bounds, backingScale: screen.scale)
        let width = Int(screen.bounds.width * screen.scale)
        let height = Int(screen.bounds.height * screen.scale)
        return FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: width,
                height: height,
                colorSpace: .displayP3,
                pixels: (0..<(width * height)).flatMap { index -> [UInt8] in
                    let row = index / width
                    let value = UInt8((row * Ink.bands / max(1, height)).isMultiple(of: 2) ? 200 : 60)
                    return [value, value, value, UInt8(ImageBuffer.Channel.maximum)]
                }
            ),
            windows: WindowStack(windows: windows)
        )
    }

    private enum Ink {
        static let bands = 16
    }

    private static func pixels(of overlay: Overlay) throws -> RenderedBitmap {
        let store = AssetStore()
        store.put(overlay.frozen.image, as: Overlay.frozenName(of: overlay.frozen))
        return try CoreGraphicsRenderer(assets: store)
            .render(overlay.drawList, scale: 1)
            .bitmap
    }

    @Test("Every screen is covered edge to edge")
    func coveredEdgeToEdge() throws {
        for screen in Self.screens {
            let drawn = try Self.pixels(of: Overlay(frozen: Self.frozen(screen)))
            #expect(drawn.width == Int(screen.bounds.width))
            #expect(drawn.height == Int(screen.bounds.height))

            for corner in [
                (0, 0), (drawn.width - 1, 0), (0, drawn.height - 1),
                (drawn.width - 1, drawn.height - 1),
            ] {
                let pixel = drawn.pixel(x: corner.0, y: corner.1)
                #expect(pixel.alpha == UInt8(ImageBuffer.Channel.maximum))
                #expect(pixel.red > 0 || pixel.green > 0 || pixel.blue > 0)
            }
        }
    }

    @Test("What is being chosen is brighter than what is not")
    func chosenRegionIsBrighter() throws {
        for screen in Self.screens {
            let frozen = Self.frozen(screen)
            let middle = P2(x: frozen.display.bounds.center.x, y: frozen.display.bounds.center.y)
            var overlay = Overlay(frozen: frozen)
            overlay = overlay.handle(
                .pointerDown(
                    ScenePoint(
                        x: middle.x - screen.bounds.minX - 100,
                        y: middle.y - screen.bounds.minY - 80), []))
            overlay = overlay.handle(
                .pointerMoved(
                    ScenePoint(
                        x: middle.x - screen.bounds.minX + 100,
                        y: middle.y - screen.bounds.minY + 80), []))

            let chosen = try #require(overlay.selection)
            let inPicture = P2(
                x: chosen.raw.center.x - screen.bounds.minX,
                y: chosen.raw.center.y - screen.bounds.minY
            )
            let drawn = try Self.pixels(of: overlay)
            let inside = drawn.pixel(x: Int(inPicture.x), y: Int(inPicture.y))
            let outside = drawn.pixel(x: 2, y: 2)

            #expect(Self.brightness(inside) > Self.brightness(outside))
        }
    }

    @Test("The highlight lands on the window it is about")
    func highlightLandsOnItsWindow() throws {
        for screen in Self.screens {
            let frame = Rect(
                x: screen.bounds.minX + 200,
                y: screen.bounds.minY + 150,
                width: 300,
                height: 200
            )
            let frozen = Self.frozen(
                screen,
                windows: [
                    WindowDescriptor(
                        id: WindowID(1),
                        title: "Window",
                        applicationName: "Test",
                        bundleIdentifier: "test",
                        frame: ScreenRect(frame),
                        isOnScreen: true,
                        layer: 0
                    )
                ]
            )
            let overlay = Overlay(frozen: frozen)
                .handle(.pointerMoved(ScenePoint(x: 250, y: 200), []))
            #expect(overlay.highlighted?.id == WindowID(1))

            let drawn = try Self.pixels(of: overlay)
            let onTheEdge = drawn.pixel(x: 200, y: Int(frame.center.y - screen.bounds.minY))
            #expect(Self.isBlue(onTheEdge))

            let nearTheBottom = drawn.pixel(x: 200, y: drawn.height - 2)
            #expect(!Self.isBlue(nearTheBottom))
        }
    }

    private static func brightness(_ pixel: RenderedBitmap.Pixel) -> Int {
        Int(pixel.red) + Int(pixel.green) + Int(pixel.blue)
    }

    private static func isBlue(_ pixel: RenderedBitmap.Pixel) -> Bool {
        Int(pixel.blue) > Int(pixel.red) + Blue.margin
            && Int(pixel.blue) > Int(pixel.green) + Blue.margin
    }

    private enum Blue {
        static let margin = 20
    }
}
