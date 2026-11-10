import EkranbildoContracts
import EkranbildoTimeline

public enum RecordingPolish {
    public static func withoutStillness(
        _ frames: [ImageBuffer],
        framesPerSecond: Int
    ) -> [ImageBuffer] {
        guard frames.count > 1 else { return frames }

        let windows = Self.windows(of: frames, framesPerSecond: framesPerSecond)
        let cuts = DeadTimeRemover().cuts(in: windows)
        guard !cuts.isEmpty else { return frames }

        return frames.enumerated().compactMap { index, frame in
            let at = Timestamp.seconds(Double(index) / Double(framesPerSecond))
            return cuts.contains { $0.from <= at && at < $0.to } ? nil : frame
        }
    }

    static func windows(
        of frames: [ImageBuffer],
        framesPerSecond: Int
    ) -> [ActivityWindow] {
        func at(_ index: Int) -> Timestamp {
            Timestamp.seconds(Double(index) / Double(framesPerSecond))
        }

        var windows: [ActivityWindow] = []
        var runStart = 1
        var running: Bool?

        for index in frames.indices.dropFirst() {
            let changed = frames[index].pixels != frames[index - 1].pixels
            guard let was = running else {
                running = changed
                continue
            }
            guard was != changed else { continue }
            windows.append(ActivityWindow(from: at(runStart), to: at(index), changed: was))
            runStart = index
            running = changed
        }
        if let was = running {
            windows.append(ActivityWindow(from: at(runStart), to: at(frames.count), changed: was))
        }
        return windows
    }
}
