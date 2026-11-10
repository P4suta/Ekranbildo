import CoreGraphics
@testable import EkranbildoCapture
import EkranbildoContracts
import EkranbildoGeometry
import Foundation
import Testing

@Suite(
    "Real capture",
    .enabled(if: ProcessInfo.processInfo.environment["EKRANBILDO_REAL_CAPTURE"] == "1")
)
struct RealCaptureTests {

    private let capturer = ScreenCaptureKitCapturer()

    @Test("The permission is granted and in effect")
    func permissionGranted() async {
        let state = await capturer.permission()
        #expect(
            state == .granted,
            """
            screen recording is \(state.rawValue). \
            Grant it in System Settings, then start the run again - \
            a process started before the grant cannot see anything.
            """
        )
    }

    @Test("The backing scale is the display's, not a ratio of two point sizes")
    func backingScaleIsReal() async throws {
        let display = try #require(try await capturer.displays().first)
        let mode = try #require(CGDisplayCopyDisplayMode(display.displayID))
        #expect(display.backingScale == Double(mode.pixelWidth) / Double(mode.width))
        #expect(display.pixelWidth == mode.pixelWidth)
    }

    @Test("There is at least one display, and it has a sensible scale")
    func displays() async throws {
        let found = try await capturer.displays()
        #expect(!found.isEmpty)
        for display in found {
            #expect(display.bounds.width > 0)
            #expect(display.backingScale >= 1)
            #expect(display.pixelWidth >= Int(display.bounds.width))
        }
    }

    @Test("The window list describes other applications")
    func windows() async throws {
        let stack = try await capturer.windows()
        #expect(!stack.windows.isEmpty)
        #expect(stack.windows.contains { $0.applicationName != nil })
    }

    @Test("A display is captured at its full pixel size")
    func captureDisplay() async throws {
        let display = try #require(try await capturer.displays().first)
        let capture = try await capturer.capture(.display(display))

        #expect(capture.image.width == display.pixelWidth)
        #expect(capture.image.height == display.pixelHeight)
        #expect(capture.image.isWellFormed)
        #expect(capture.geometry.display.displayID == display.displayID)
    }

    @Test("A region is captured where it was asked for")
    func captureRegion() async throws {
        let display = try #require(try await capturer.displays().first)
        let region = ScreenRect(
            x: display.bounds.minX,
            y: display.bounds.minY,
            width: min(Sample.side, display.bounds.width),
            height: min(Sample.side, display.bounds.height)
        )
        let capture = try await capturer.capture(.region(display, region))
        #expect(capture.geometry.regionInScreen == region.raw)
    }

    @Test("A window that is not there is reported")
    func missingWindow() async {
        await #expect(throws: CaptureError.self) {
            try await capturer.capture(.window(WindowID(UInt32.max)))
        }
    }

    private enum Sample {
        static let side: Double = 200
    }
}
