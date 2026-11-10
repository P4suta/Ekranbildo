import EkranbildoContracts
import Foundation

public struct WallClock: Clocking {
    public init() {}

    public func now() -> Double { Date().timeIntervalSince1970 }
}
