import EkranbildoContracts
import EkranbildoGeometry

public struct FakeScreenCapturer: ScreenCapturing {
    private let screen: SyntheticScreenshot
    private let geometry: CaptureGeometry
    private let stack: WindowStack
    private let granted: CapturePermission
    private let failure: CaptureError?

    public init(
        screen: SyntheticScreenshot,
        geometry: CaptureGeometry? = nil,
        windows: WindowStack = WindowStack(windows: []),
        permission: CapturePermission = .granted,
        failure: CaptureError? = nil
    ) {
        self.screen = screen
        self.geometry =
            geometry
            ?? CaptureGeometry(
                fullDisplay: DisplayGeometry(
                    displayID: Defaults.displayID,
                    bounds: Rect(
                        x: 0, y: 0, width: Double(screen.width), height: Double(screen.height)),
                    backingScale: 1
                )
            )
        stack = windows
        granted = permission
        self.failure = failure
    }

    public func permission() async -> CapturePermission { granted }

    public func displays() async throws -> [DisplayGeometry] {
        try refuseIfUnable()
        return [geometry.display]
    }

    public func windows() async throws -> WindowStack {
        try refuseIfUnable()
        return stack
    }

    public func capture(_ subject: CaptureSubject) async throws -> ScreenCapture {
        try refuseIfUnable()
        return ScreenCapture(image: screen.image, geometry: geometry, windows: stack)
    }

    private func refuseIfUnable() throws {
        if let failure { throw failure }
        guard granted == .granted else {
            throw CaptureError(
                code: CaptureError.permissionMissing,
                detail: "screen recording is \(granted.rawValue)"
            )
        }
    }

    public enum Defaults {
        static let displayID: UInt32 = 1
    }
}
