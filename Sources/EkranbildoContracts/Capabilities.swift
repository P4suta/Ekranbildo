import EkranbildoObservability

public protocol TextMeasuring: Sendable {
    func measure(_ text: String, font: FontSpec) -> TextMetrics
}

public protocol Clocking: Sendable {
    func now() -> Double
}

public protocol FileStoring: Sendable {
    func store(_ bytes: [UInt8], as name: String) throws -> StoredFile
    func load(_ file: StoredFile) throws -> [UInt8]
}

public struct StoredFile: Hashable, Sendable, Codable {
    public let identifier: String
    public let byteCount: Int

    public init(identifier: String, byteCount: Int) {
        self.identifier = identifier
        self.byteCount = byteCount
    }
}

public struct CapabilityError: Error, Hashable, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let noSuchFile: DiagnosticCode = 100
    public static let notPermitted: DiagnosticCode = 101
}

public struct Capabilities: Sendable {
    public var text: any TextMeasuring
    public var clock: any Clocking
    public var files: any FileStoring

    public init(text: any TextMeasuring, clock: any Clocking, files: any FileStoring) {
        self.text = text
        self.clock = clock
        self.files = files
    }
}
