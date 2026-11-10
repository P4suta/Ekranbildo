import EkranbildoContracts
@testable import EkranbildoFixtures
import EkranbildoGeometry
import Testing

@Suite("Fake capturer")
struct FakeCapturerTests {

    @Test("A capture is of the screen it was given")
    func capturesTheScreen() async throws {
        let screen = SceneLibrary.applicationWindow
        let capture = try await FakeScreenCapturer(screen: screen)
            .capture(
                .display(
                    DisplayGeometry(displayID: 1, bounds: .zero, backingScale: 1)))
        #expect(capture.image.width == screen.width)
        #expect(capture.image.height == screen.height)
    }

    @Test("A capture knows where it came from")
    func carriesGeometry() async throws {
        let screen = SceneLibrary.applicationWindow
        let capture = try await FakeScreenCapturer(screen: screen).capture(
            .display(DisplayGeometry(displayID: 1, bounds: .zero, backingScale: 1)))
        #expect(capture.geometry.pixelWidth == screen.width)
        #expect(capture.geometry.sceneSize.width == Double(screen.width))
    }

    @Test(
        "Without permission every request is refused",
        arguments: [CapturePermission.notDetermined, .denied, .grantedPendingRestart]
    )
    func refusesWithoutPermission(state: CapturePermission) async {
        let capturer = FakeScreenCapturer(screen: SceneLibrary.dialog, permission: state)
        await #expect(throws: CaptureError.self) { try await capturer.windows() }
        await #expect(throws: CaptureError.self) { try await capturer.displays() }
        await #expect(throws: CaptureError.self) {
            try await capturer.capture(
                .display(DisplayGeometry(displayID: 1, bounds: .zero, backingScale: 1)))
        }
    }

    @Test("The permission it was given is the one it reports")
    func reportsPermission() async {
        let capturer = FakeScreenCapturer(screen: SceneLibrary.dialog, permission: .denied)
        #expect(await capturer.permission() == .denied)
    }

    @Test("A stated failure is what comes back")
    func statedFailure() async {
        let capturer = FakeScreenCapturer(
            screen: SceneLibrary.dialog,
            failure: CaptureError(code: CaptureError.subjectGone, detail: "unplugged")
        )
        await #expect(throws: CaptureError.self) { try await capturer.windows() }
    }

    @Test("The windows it was given are the ones it reports")
    func reportsWindows() async throws {
        let stack = WindowStack(windows: [
            WindowDescriptor(
                id: WindowID(1),
                title: "Report",
                applicationName: "Preview",
                bundleIdentifier: "com.apple.Preview",
                frame: ScreenRect(Rect(x: 0, y: 0, width: 100, height: 100)),
                isOnScreen: true,
                layer: 0
            )
        ])
        let capturer = FakeScreenCapturer(screen: SceneLibrary.dialog, windows: stack)
        #expect(try await capturer.windows() == stack)
        #expect(
            try await capturer.capture(
                .display(DisplayGeometry(displayID: 1, bounds: .zero, backingScale: 1))
            ).windows == stack
        )
    }
}
