import CoreGraphics
import EkranbildoContracts

public struct SystemPointerReader: PointerReader {
    public init() {}

    public func read() -> PointerReading? {
        guard let location = CGEvent(source: nil)?.location else { return nil }

        return PointerReading(
            position: ScreenPoint(x: location.x, y: location.y),
            pressed: CGEventSource.buttonState(.combinedSessionState, button: .left)
                || CGEventSource.buttonState(.combinedSessionState, button: .right)
        )
    }
}
