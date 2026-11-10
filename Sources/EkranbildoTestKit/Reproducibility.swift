public func isReproducible<Value: Equatable>(_ produce: () throws -> Value) rethrows -> Bool {
    let once = try produce()
    let again = try produce()
    return once == again
}

public func areEquivalent<Value: Equatable>(_ first: Value, _ second: Value) -> Bool {
    first == second
}
