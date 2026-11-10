import EkranbildoGeometry
import EkranbildoObservability

public enum CapturePermission: String, Hashable, Sendable, Codable {
    case notDetermined
    case denied
    case granted
    case grantedPendingRestart
}

public enum CaptureSubject: Hashable, Sendable, Codable {
    case display(DisplayGeometry)
    case region(DisplayGeometry, ScreenRect)
    case window(WindowID)
}

public struct ScreenCapture: Sendable {
    public let image: ImageBuffer
    public let geometry: CaptureGeometry
    public let windows: WindowStack

    public init(image: ImageBuffer, geometry: CaptureGeometry, windows: WindowStack) {
        self.image = image
        self.geometry = geometry
        self.windows = windows
    }
}

public protocol ScreenCapturing: Sendable {
    func permission() async -> CapturePermission
    func displays() async throws -> [DisplayGeometry]
    func windows() async throws -> WindowStack
    func capture(_ subject: CaptureSubject) async throws -> ScreenCapture
}

public struct CaptureError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let permissionMissing: DiagnosticCode = 500
    public static let subjectGone: DiagnosticCode = 501
    public static let captureFailed: DiagnosticCode = 502
}
