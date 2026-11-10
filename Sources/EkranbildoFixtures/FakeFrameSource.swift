import EkranbildoContracts
import EkranbildoRecord

public struct FakeFrameSource: FrameSourceDeliveries {
    public let deliveries: [FrameDelivery]

    public init(_ deliveries: [FrameDelivery]) {
        self.deliveries = deliveries
    }

    public static func steady(
        frameCount: Int,
        size: Int = Defaults.size,
        interval: Timestamp = Defaults.interval
    ) -> Self {
        Self(
            (0..<frameCount).map { index in
                .frame(
                    Self.frame(index, size: size),
                    at: Timestamp(nanoseconds: interval.nanoseconds * Int64(index))
                )
            }
        )
    }

    public static func frame(_ index: Int, size: Int = Defaults.size) -> ImageBuffer {
        var screen = SyntheticScreenshot(width: size, height: size)
        screen.paint(
            SceneRect(x: 0, y: 0, width: Double(size), height: Double(size)),
            color: .opaque(
                red: UInt8(truncatingIfNeeded: index),
                green: UInt8(truncatingIfNeeded: index &* Defaults.greenStride),
                blue: Defaults.blue
            )
        )
        return screen.image
    }

    public enum Defaults {
        public static let size = 16
        public static let interval = Timestamp(
            nanoseconds: Timing.nanosecondsPerSecond / Timing.framesPerSecond)
        static let greenStride = 7

        private enum Timing {
            static let nanosecondsPerSecond: Int64 = 1_000_000_000
            static let framesPerSecond: Int64 = 30
        }
        static let blue: UInt8 = 90
    }
}

public protocol FrameSourceDeliveries: FrameSource {
    var deliveries: [FrameDelivery] { get }
}

extension FrameSourceDeliveries {
    public func deliveries() -> [FrameDelivery] { deliveries }
}
