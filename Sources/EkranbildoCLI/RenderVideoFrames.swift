import EkranbildoContracts
import EkranbildoObservability
import EkranbildoTimeline
import Foundation

extension RenderVideoCommand {
    static func schedule(
        moments: [Timestamp],
        cursor: CursorTrack?,
        framesPerSecond: Int,
        holdingAtMost limit: Int
    ) throws -> [ScheduledFrame] {
        var schedule = moments.enumerated().map {
            ScheduledFrame(picture: $0.offset, at: $0.element)
        }
        guard let lastFrame = moments.last, let cursor else { return schedule }

        let end = max(
            cursor.samples.last?.at ?? lastFrame,
            cursor.ripples.last?.at ?? lastFrame
        )
        guard end > lastFrame else { return schedule }

        let step = Int64(Scale.nanosecondsPerSecond) / Int64(max(1, framesPerSecond))
        let held = (end.nanoseconds - lastFrame.nanoseconds) / step
        guard held <= Int64(limit) else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail:
                    "the recording runs \(CanonicalText.rounded(end.seconds, places: 1))s past its "
                    + "last frame, which is \(held) frames to hold - more than the "
                    + "\(limit) this can keep in memory at once"
            )
        }

        for step in 1...max(1, Int(held)) {
            let at = Timestamp(
                nanoseconds: lastFrame.nanoseconds + Int64(step)
                    * Int64(
                        Scale.nanosecondsPerSecond / max(1, framesPerSecond)))
            guard at <= end else { break }
            schedule.append(ScheduledFrame(picture: moments.count - 1, at: at))
        }
        return schedule
    }

    private enum Scale {
        static let nanosecondsPerSecond = 1_000_000_000
    }

    static func cropped(_ image: ImageBuffer, to view: SceneRect, of frame: SceneRect) -> ImageBuffer {
        let width = image.width
        let height = image.height
        guard view != frame, view.raw.width > 0, view.raw.height > 0 else { return image }

        var pixels = [UInt8](repeating: 0, count: width * height * ImageBuffer.Channel.count)
        let channel = ImageBuffer.Channel.Offset.self
        let scaleX = view.raw.width / Double(width)
        let scaleY = view.raw.height / Double(height)

        for row in 0..<height {
            let sourceRow = Int((view.minY + Double(row) * scaleY).rounded(.down))
            for column in 0..<width {
                let sourceColumn = Int((view.minX + Double(column) * scaleX).rounded(.down))
                let pixel = image[x: sourceColumn, y: sourceRow]
                let offset = (row * width + column) * ImageBuffer.Channel.count
                pixels[offset + channel.red] = pixel.red
                pixels[offset + channel.green] = pixel.green
                pixels[offset + channel.blue] = pixel.blue
                pixels[offset + channel.alpha] = pixel.alpha
            }
        }
        return ImageBuffer(
            width: width, height: height, colorSpace: image.colorSpace, pixels: pixels)
    }
}
