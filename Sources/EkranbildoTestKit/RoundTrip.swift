import Foundation

public func roundTripped<Value: Codable>(_ value: Value) throws -> Value {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try JSONDecoder().decode(Value.self, from: encoder.encode(value))
}

public func isJSONRoundTrippable<Value: Codable & Equatable>(_ value: Value) throws -> Bool {
    try roundTripped(value) == value
}
