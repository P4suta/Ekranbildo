import AVFoundation
import CoreMedia
import CoreVideo
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoObservability
import Foundation

public struct EncodeError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public static let nothingToWrite: DiagnosticCode = 1000
    public static let writerUnavailable: DiagnosticCode = 1001
    public static let writeFailed: DiagnosticCode = 1002
}

public struct EncodeSettings: Sendable {
    public let width: Int
    public let height: Int
    public let framesPerSecond: Int
    public let bitRate: Int

    public init(
        width: Int,
        height: Int,
        framesPerSecond: Int = Defaults.framesPerSecond,
        bitRate: Int? = nil
    ) {
        self.width = max(Defaults.smallest, width - width % Defaults.evenness)
        self.height = max(Defaults.smallest, height - height % Defaults.evenness)
        self.framesPerSecond = max(1, framesPerSecond)
        self.bitRate = bitRate ?? Defaults.bitRate(width: self.width, height: self.height)
    }

    public enum Defaults {
        public static let framesPerSecond = 30
        static let evenness = 2
        static let smallest = 2

        public static func bitRate(width: Int, height: Int) -> Int {
            max(minimumBitRate, width * height * bitsPerPixelPerSecond)
        }

        private static let bitsPerPixelPerSecond = 4
        private static let minimumBitRate = 2_000_000
    }
}

public struct EncodeResult: Hashable, Sendable {
    public let frames: Int
    public let duration: Timestamp
    public let width: Int
    public let height: Int
}

public struct VideoWriter: Sendable {
    private let settings: EncodeSettings

    public init(settings: EncodeSettings) {
        self.settings = settings
    }

    public func write(
        frames: [TimedFrame],
        to url: URL
    ) async throws -> EncodeResult {
        var remaining = frames.makeIterator()
        return try await write(to: url) { remaining.next() }
    }

    public func write(
        to url: URL,
        next: () throws -> TimedFrame?
    ) async throws -> EncodeResult {
        guard let first = try next() else {
            throw EncodeError(
                code: EncodeError.nothingToWrite,
                detail: "there are no frames to write"
            )
        }

        try? FileManager.default.removeItem(at: url)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw EncodeError(
                code: EncodeError.writerUnavailable,
                detail: "the system would not start writing: \(error)"
            )
        }

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: settings.width,
                AVVideoHeightKey: settings.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: settings.bitRate
                ],
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: settings.width,
                kCVPixelBufferHeightKey as String: settings.height,
            ]
        )

        guard writer.canAdd(input) else {
            throw EncodeError(
                code: EncodeError.writerUnavailable,
                detail: "the system would not take a video track"
            )
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw EncodeError(
                code: EncodeError.writerUnavailable,
                detail:
                    "the system would not begin: \(Self.reason(writer.error))"
            )
        }
        writer.startSession(atSourceTime: .zero)

        var written = 0
        var last = first.at
        var frame: TimedFrame? = first
        while let current = frame {
            last = current.at
            if let buffer = Self.pixelBuffer(of: current.image, pool: adaptor.pixelBufferPool) {
                while !input.isReadyForMoreMediaData {
                    await Task.yield()
                }

                let time = CMTime(
                    value: CMTimeValue(current.at.nanoseconds),
                    timescale: CMTimeScale(Scale.nanosecondsPerSecond)
                )
                if adaptor.append(buffer, withPresentationTime: time) {
                    written += 1
                }
            }
            frame = try next()
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw EncodeError(
                code: EncodeError.writeFailed,
                detail:
                    "the system stopped part way: \(Self.reason(writer.error))"
            )
        }

        return EncodeResult(
            frames: written,
            duration: last,
            width: settings.width,
            height: settings.height
        )
    }

    static func pixelBuffer(of image: ImageBuffer, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }

        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
            let buffer
        else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let width = min(image.width, CVPixelBufferGetWidth(buffer))
        let height = min(image.height, CVPixelBufferGetHeight(buffer))

        let raw = UnsafeMutableRawBufferPointer(
            start: base, count: bytesPerRow * CVPixelBufferGetHeight(buffer))
        for row in 0..<height {
            for column in 0..<width {
                let pixel = image[x: column, y: row]
                let offset = row * bytesPerRow + column * PixelFormat.bytesPerPixel
                raw[offset + PixelFormat.Offset.blue] = pixel.blue
                raw[offset + PixelFormat.Offset.green] = pixel.green
                raw[offset + PixelFormat.Offset.red] = pixel.red
                raw[offset + PixelFormat.Offset.alpha] = pixel.alpha
            }
        }
        return buffer
    }

    static func reason(_ error: (any Error)?) -> String {
        error.map(String.init(describing:)) ?? "no reason given"
    }

    private enum Scale {
        static let nanosecondsPerSecond = 1_000_000_000
    }
}
