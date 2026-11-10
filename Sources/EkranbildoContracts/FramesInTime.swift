public struct TimedFrame: Hashable, Sendable {
    public let image: ImageBuffer
    public let at: Timestamp

    public init(image: ImageBuffer, at: Timestamp) {
        self.image = image
        self.at = at
    }

    public static func held(_ frames: [Self]) -> [HeldFrame] {
        frames.enumerated().map { place, frame in
            HeldFrame(image: frame.image, showFor: Self.stay(at: place, among: frames))
        }
    }

    static func stay(at place: Int, among frames: [Self]) -> Timestamp {
        let frame = frames[place]
        if place + 1 < frames.count {
            return Timestamp(
                nanoseconds: max(0, frames[place + 1].at.nanoseconds - frame.at.nanoseconds))
        }
        guard place > 0 else { return .zero }
        return Timestamp(
            nanoseconds: max(0, frame.at.nanoseconds - frames[place - 1].at.nanoseconds))
    }
}

public struct HeldFrame: Hashable, Sendable {
    public let image: ImageBuffer
    public let showFor: Timestamp

    public init(image: ImageBuffer, showFor: Timestamp) {
        self.image = image
        self.showFor = showFor
    }
}

public struct ScheduledFrame: Hashable, Sendable {
    public let picture: Int
    public let at: Timestamp

    public init(picture: Int, at: Timestamp) {
        self.picture = picture
        self.at = at
    }
}
