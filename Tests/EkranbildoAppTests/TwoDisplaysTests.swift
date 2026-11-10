import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay
import Testing

@Suite("A laptop with a monitor above it")
struct TwoDisplaysTests {

    private static let laptop = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 1728, height: 1117),
        backingScale: 2
    )
    private static let monitor = DisplayGeometry(
        displayID: 5,
        bounds: Rect(x: -77, y: -1080, width: 1920, height: 1080),
        backingScale: 1
    )

    private static func frozen(_ display: DisplayGeometry) -> FrozenScreen {
        let width = Int(display.bounds.width * display.backingScale)
        let height = Int(display.bounds.height * display.backingScale)
        return FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: width,
                height: height,
                colorSpace: .displayP3,
                pixels: [UInt8](repeating: Grey.value, count: width * height * Grey.channels)
            ),
            windows: WindowStack(windows: [])
        )
    }

    private enum Grey {
        static let value: UInt8 = 128
        static let channels = 4
    }

    private static func drag(
        on display: DisplayGeometry,
        from: P2,
        to: P2
    ) -> Overlay {
        var overlay = Overlay(frozen: frozen(display))
        overlay = overlay.handle(.pointerDown(ScenePoint(x: from.x, y: from.y), []))
        overlay = overlay.handle(.pointerMoved(ScenePoint(x: to.x, y: to.y), []))
        overlay = overlay.handle(.pointerUp(ScenePoint(x: to.x, y: to.y), []))
        return overlay
    }

    @Test(
        "A drag in the middle of either screen is a capture of that screen",
        arguments: [laptop, monitor]
    )
    func dragInTheMiddle(_ display: DisplayGeometry) throws {
        let overlay = Self.drag(
            on: display,
            from: P2(x: 300, y: 200),
            to: P2(x: 800, y: 500)
        )
        let outcome = try #require(overlay.outcome)
        let made = try #require(
            ChosenCapture.scene(of: outcome, in: Self.frozen(display), assets: AssetStore()))
        #expect(made.canvas.width == 500)
        #expect(made.canvas.height == 300)
    }

    @Test(
        "A drag into the corner of either screen is a capture of that screen",
        arguments: [laptop, monitor]
    )
    func dragIntoTheCorner(_ display: DisplayGeometry) throws {
        let overlay = Self.drag(
            on: display,
            from: P2(x: display.bounds.width - 200, y: display.bounds.height - 150),
            to: P2(x: display.bounds.width + 40, y: display.bounds.height + 30)
        )
        let outcome = try #require(overlay.outcome)
        let made = try #require(
            ChosenCapture.scene(of: outcome, in: Self.frozen(display), assets: AssetStore()))
        #expect(made.canvas.width == 200)
        #expect(made.canvas.height == 150)
    }

    @Test("The same drag gives the same document on either screen")
    func sameDragEitherScreen() throws {
        func document(on display: DisplayGeometry) throws -> SceneRect {
            let overlay = Self.drag(
                on: display, from: P2(x: 120, y: 90), to: P2(x: 520, y: 390))
            let outcome = try #require(overlay.outcome)
            let made = try #require(
                ChosenCapture.scene(of: outcome, in: Self.frozen(display), assets: AssetStore()))
            return made.canvas
        }
        #expect(try document(on: Self.laptop) == document(on: Self.monitor))
    }

    @Test("The window under the pointer is one on the screen being pointed at")
    func windowUnderThePointer() throws {
        let onTheMonitor = WindowDescriptor(
            id: WindowID(11),
            title: "On the monitor",
            applicationName: "Test",
            bundleIdentifier: "test",
            frame: ScreenRect(Rect(x: -77 + 100, y: -1080 + 100, width: 400, height: 300)),
            isOnScreen: true,
            layer: 0
        )
        let onTheLaptop = WindowDescriptor(
            id: WindowID(12),
            title: "On the laptop",
            applicationName: "Test",
            bundleIdentifier: "test",
            frame: ScreenRect(Rect(x: 100, y: 100, width: 400, height: 300)),
            isOnScreen: true,
            layer: 0
        )
        let frozen = FrozenScreen(
            display: Self.monitor,
            image: Self.frozen(Self.monitor).image,
            windows: WindowStack(windows: [onTheMonitor, onTheLaptop])
        )

        let overlay = Overlay(frozen: frozen)
            .handle(.pointerMoved(ScenePoint(x: 200, y: 200), []))
        #expect(overlay.highlighted?.id == WindowID(11))
    }
}
