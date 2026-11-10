import CoreGraphics
@testable import EkranbildoCapture
import EkranbildoContracts
import EkranbildoGeometry
import ScreenCaptureKit
import Testing

@Suite("Capture geometry")
struct CaptureGeometryTests {

    @Test("A retina display is captured at its pixel size")
    func retinaPixelSize() {
        let display = DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 1440, height: 900),
            backingScale: 2
        )
        let geometry = CaptureGeometry(fullDisplay: display)
        #expect(geometry.pixelWidth == 2880)
        #expect(geometry.pixelHeight == 1800)
        #expect(geometry.sceneSize.width == 1440)
    }

    @Test("A region is captured at the region's size, not the display's")
    func regionSize() {
        let display = DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 1440, height: 900),
            backingScale: 2
        )
        let geometry = CaptureGeometry(
            display: display,
            regionInScreen: Rect(x: 100, y: 50, width: 400, height: 300)
        )
        #expect(geometry.pixelWidth == 800)
        #expect(geometry.pixelHeight == 600)
        #expect(geometry.sceneSize.width == 400)
    }

    @Test("A display left of the primary keeps its negative origin")
    func negativeOrigin() {
        let display = DisplayGeometry(
            displayID: 2,
            bounds: Rect(x: -1920, y: 0, width: 1920, height: 1080),
            backingScale: 1
        )
        let geometry = CaptureGeometry(fullDisplay: display)
        #expect(geometry.regionInScreen.minX == -1920)
        #expect(geometry.sceneSize.width == 1920)
    }
}

@Suite("Capture configuration")
struct CaptureConfigurationTests {

    @Test("Shadows are excluded unless asked for")
    func shadowsExcluded() {
        #expect(ScreenCaptureKitCapturer().capturesShadows == false)
        #expect(ScreenCaptureKitCapturer(includesShadows: true).capturesShadows)
    }

    @Test("The cursor is excluded unless asked for")
    func cursorExcluded() {
        #expect(ScreenCaptureKitCapturer().capturesCursor == false)
        #expect(ScreenCaptureKitCapturer(includesCursor: true).capturesCursor)
    }

    @Test("The backing scale is pixels over points")
    func scaleDirection() {
        #expect(ScreenCaptureKitCapturer.backingScale(points: 1440, pixels: 2880) == 2)
        #expect(ScreenCaptureKitCapturer.backingScale(points: 1920, pixels: 1920) == 1)
    }

    @Test("A display that reports nothing usable falls back rather than dividing by zero")
    func scaleFallback() {
        #expect(ScreenCaptureKitCapturer.backingScale(points: 0, pixels: 2880) == 1)
        #expect(ScreenCaptureKitCapturer.backingScale(points: 1440, pixels: 0) == 1)
    }

    @Test("An unknown backing scale is assumed to be one to one")
    func conservativeScale() {
        #expect(ScreenCaptureKitCapturer.Defaults.backingScale == 1)
    }
}

@Suite("Frame status")
struct FrameStatusTests {

    @Test("A complete frame is recorded")
    func complete() {
        #expect(StreamFrameSource.isNewContent(.complete))
    }

    @Test(
        "A frame the system says did not change is not recorded",
        arguments: [SCFrameStatus.idle, .blank, .suspended, .started, .stopped]
    )
    func notNewContent(status: SCFrameStatus) {
        #expect(!StreamFrameSource.isNewContent(status))
    }

    @Test("A frame the system said nothing about is recorded")
    func noStatus() {
        #expect(StreamFrameSource.isNewContent(nil))
    }
}
