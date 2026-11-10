import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay
import Testing

@Suite("What somebody chose on the overlay")
struct ChosenCaptureTests {

    private static let scale = 2.0

    private static func frozen(
        at origin: P2 = P2(x: 0, y: 0),
        windows: [WindowDescriptor] = []
    ) -> FrozenScreen {
        let display = DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: origin.x, y: origin.y, width: 800, height: 600),
            backingScale: scale
        )
        return FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: Int(800 * scale),
                height: Int(600 * scale),
                colorSpace: .displayP3,
                pixels: [UInt8](
                    repeating: Grey.value,
                    count: Int(800 * scale) * Int(600 * scale) * Grey.channels
                )
            ),
            windows: WindowStack(windows: windows)
        )
    }

    private enum Grey {
        static let value: UInt8 = 128
        static let channels = 4
    }

    private func scene(_ region: Rect, in frozen: FrozenScreen) -> Scene? {
        ChosenCapture.scene(
            of: .region(ScreenRect(region)), in: frozen, assets: AssetStore())
    }

    @Test("A region in the middle of the screen is the size somebody swept")
    func regionInTheMiddle() throws {
        let made = try #require(scene(Rect(x: 100, y: 120, width: 300, height: 200), in: Self.frozen()))
        #expect(made.canvas.width == 300)
        #expect(made.canvas.height == 200)
        #expect(made.background?.pixelWidth == Int(300 * Self.scale))
        #expect(made.background?.pixelHeight == Int(200 * Self.scale))
    }

    @Test(
        "A region swept past the edge of the screen is the part that is on it",
        arguments: [
            Rect(x: -40, y: 100, width: 200, height: 100),
            Rect(x: 700, y: 100, width: 200, height: 100),
            Rect(x: 100, y: -40, width: 200, height: 100),
            Rect(x: 100, y: 550, width: 200, height: 100),
            Rect(x: -50, y: -50, width: 900, height: 700),
        ]
    )
    func regionOverTheEdge(_ swept: Rect) throws {
        let frozen = Self.frozen()
        let made = try #require(scene(swept, in: frozen))
        let onScreen = swept.intersection(frozen.display.bounds)
        #expect(made.canvas.width == onScreen?.width)
        #expect(made.canvas.height == onScreen?.height)
    }

    @Test(
        "The document is the size of the picture in it",
        arguments: [
            Rect(x: 100.5, y: 100.5, width: 299.5, height: 199.5),
            Rect(x: 0.4, y: 0.6, width: 799.2, height: 598.8),
            Rect(x: 100.25, y: 100.75, width: 300.5, height: 200.5),
        ]
    )
    func documentMatchesPicture(_ swept: Rect) throws {
        let made = try #require(scene(swept, in: Self.frozen()))
        #expect(made.canvas.width * Self.scale == Double(made.background?.pixelWidth ?? 0))
        #expect(made.canvas.height * Self.scale == Double(made.background?.pixelHeight ?? 0))
    }

    @Test("A region entirely off the screen is not a capture")
    func regionOffTheScreen() {
        #expect(scene(Rect(x: 900, y: 100, width: 100, height: 100), in: Self.frozen()) == nil)
    }

    @Test("A region on a display away from the origin is cropped from that display's picture")
    func regionOnASecondDisplay() throws {
        let frozen = Self.frozen(at: P2(x: -1920, y: -600))
        let made = try #require(
            scene(Rect(x: -1820, y: -480, width: 300, height: 200), in: frozen))
        #expect(made.canvas.width == 300)
        #expect(made.canvas.height == 200)
    }

    private func window(_ frame: Rect) -> WindowDescriptor {
        WindowDescriptor(
            id: WindowID(7),
            title: "Front",
            applicationName: "Test",
            bundleIdentifier: "test",
            frame: ScreenRect(frame),
            isOnScreen: true,
            layer: 0
        )
    }

    @Test("Clicking a window captures it")
    func clickingAWindow() throws {
        let frozen = Self.frozen(windows: [window(Rect(x: 50, y: 60, width: 200, height: 150))])
        let made = try #require(
            ChosenCapture.scene(of: .window(WindowID(7)), in: frozen, assets: AssetStore()))
        #expect(made.canvas.width == 200)
        #expect(made.canvas.height == 150)
    }

    @Test("Clicking a window that hangs off the screen captures the part that is on it")
    func clickingAWindowOverTheEdge() throws {
        let frozen = Self.frozen(windows: [window(Rect(x: -60, y: 60, width: 200, height: 150))])
        let made = try #require(
            ChosenCapture.scene(of: .window(WindowID(7)), in: frozen, assets: AssetStore()))
        #expect(made.canvas.width == 140)
        #expect(made.canvas.height == 150)
    }

    @Test("Changing your mind is not a capture")
    func cancelled() {
        #expect(ChosenCapture.scene(of: .cancelled, in: Self.frozen(), assets: AssetStore()) == nil)
    }

    @Test("Taking the whole display is the whole display")
    func wholeDisplay() throws {
        let made = try #require(
            ChosenCapture.scene(of: .display(1), in: Self.frozen(), assets: AssetStore()))
        #expect(made.canvas.width == 800)
        #expect(made.canvas.height == 600)
    }
}

@Suite("What part of the screen was chosen")
struct ChosenRegionTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: -77, y: -1080, width: 1920, height: 1080),
        backingScale: 1
    )

    private static func frozen(windows: [WindowDescriptor] = []) -> FrozenScreen {
        FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: 1920,
                height: 1080,
                colorSpace: .displayP3,
                pixels: [UInt8](repeating: 128, count: 1920 * 1080 * 4)
            ),
            windows: WindowStack(windows: windows)
        )
    }

    @Test("A swept region is the region, in the screen's own coordinates")
    func swept() {
        let region = ScreenRect(x: -20, y: -900, width: 600, height: 400)
        #expect(ChosenCapture.region(of: .region(region), in: Self.frozen()) == region)
    }

    @Test("A region swept past the edge is the part that is on the screen")
    func overTheEdge() {
        let swept = ScreenRect(x: -200, y: -900, width: 600, height: 400)
        let onScreen = ChosenCapture.region(of: .region(swept), in: Self.frozen())
        #expect(onScreen == ScreenRect(x: -77, y: -900, width: 477, height: 400))
    }

    @Test("A chosen window is that window's place on the screen")
    func window() {
        let frame = ScreenRect(x: 100, y: -800, width: 500, height: 300)
        let frozen = Self.frozen(windows: [
            WindowDescriptor(
                id: WindowID(3),
                title: "A window",
                applicationName: "Test",
                bundleIdentifier: "test",
                frame: frame,
                isOnScreen: true,
                layer: 0
            )
        ])
        #expect(ChosenCapture.region(of: .window(WindowID(3)), in: frozen) == frame)
    }

    @Test("A chosen display is the whole of it")
    func display() {
        #expect(
            ChosenCapture.region(of: .display(1), in: Self.frozen())
                == ScreenRect(Self.display.bounds))
    }

    @Test("Changing your mind chose nothing")
    func cancelled() {
        #expect(ChosenCapture.region(of: .cancelled, in: Self.frozen()) == nil)
    }

    @Test("A region entirely off the screen is nothing")
    func offTheScreen() {
        let swept = ScreenRect(x: 5000, y: 5000, width: 100, height: 100)
        #expect(ChosenCapture.region(of: .region(swept), in: Self.frozen()) == nil)
    }
}
