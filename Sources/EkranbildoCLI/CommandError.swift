import EkranbildoObservability

public struct CommandError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public static let missingInput: DiagnosticCode = 300
    public static let missingValue: DiagnosticCode = 301
    public static let unknownFlag: DiagnosticCode = 302
    public static let invalidValue: DiagnosticCode = 303
    public static let undecodableScene: DiagnosticCode = 304
    public static let unavailableDetector: DiagnosticCode = 305
    public static let unwritableText: DiagnosticCode = 306
    public static let permissionMissing: DiagnosticCode = 306
}
