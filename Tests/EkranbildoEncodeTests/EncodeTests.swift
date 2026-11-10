import AVFoundation
import EkranbildoContracts
@testable import EkranbildoEncode
import EkranbildoFixtures
import Foundation
import Testing

@Suite("Encoding")
struct EncodeTests {

    private func frames(_ count: Int) -> [TimedFrame] {
        (0..<count).map { index in
            var screen = SyntheticScreenshot(width: 64, height: 48)
            screen.paint(
                SceneRect(x: 0, y: 0, width: 64, height: 48),
                color: .opaque(
                    red: UInt8(truncatingIfNeeded: index * 8),
                    green: 90,
                    blue: 140
                )
            )
            return TimedFrame(image: screen.image, at: .seconds(Double(index) / 30))
        }
    }

    private func temporaryURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-\(UUID().uuidString).mp4")
    }

    @Test("An odd size is brought down to an even one")
    func evenSizes() {
        let settings = EncodeSettings(width: 1921, height: 1081)
        #expect(settings.width.isMultiple(of: 2))
        #expect(settings.height.isMultiple(of: 2))
    }

    @Test("A size of nothing is brought up to something")
    func smallestSize() {
        let settings = EncodeSettings(width: 0, height: 0)
        #expect(settings.width > 0)
        #expect(settings.height > 0)
    }

    @Test("A larger picture is given more to work with")
    func bitRateScales() {
        let small = EncodeSettings(width: 640, height: 480)
        let large = EncodeSettings(width: 2560, height: 1600)
        #expect(large.bitRate > small.bitRate)
    }

    @Test("Even a tiny picture gets enough to keep text readable")
    func minimumBitRate() {
        #expect(EncodeSettings(width: 64, height: 48).bitRate >= 2_000_000)
    }

    @Test("A stated bit rate is the one used")
    func statedBitRate() {
        #expect(EncodeSettings(width: 640, height: 480, bitRate: 9_000_000).bitRate == 9_000_000)
    }

    @Test("Nothing to write is refused rather than written")
    func nothingToWrite() async {
        let writer = VideoWriter(settings: EncodeSettings(width: 64, height: 48))
        await #expect(throws: EncodeError.self) {
            try await writer.write(frames: [], to: self.temporaryURL())
        }
    }

    @Test("A file comes out, and it opens")
    func writesAPlayableFile() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await VideoWriter(settings: EncodeSettings(width: 64, height: 48))
            .write(frames: frames(30), to: url)

        #expect(result.frames == 30)
        #expect(FileManager.default.fileExists(atPath: url.path))

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(tracks.count == 1)
    }

    @Test("The file is as long as the frames it was given")
    func duration() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await VideoWriter(settings: EncodeSettings(width: 64, height: 48))
            .write(frames: frames(60), to: url)

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        #expect(abs(CMTimeGetSeconds(duration) - 2) < 0.1)
    }

    @Test("The file is the size it was asked for")
    func size() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await VideoWriter(settings: EncodeSettings(width: 64, height: 48))
            .write(frames: frames(10), to: url)

        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 64)
        #expect(Int(size.height) == 48)
    }

    @Test("Writing twice to the same place works the second time")
    func overwrites() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = VideoWriter(settings: EncodeSettings(width: 64, height: 48))
        _ = try await writer.write(frames: frames(10), to: url)
        let second = try await writer.write(frames: frames(20), to: url)
        #expect(second.frames == 20)
    }

    @Test("Two runs over the same frames agree about what was written")
    func consistentResult() async throws {
        let first = temporaryURL()
        let second = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let writer = VideoWriter(settings: EncodeSettings(width: 64, height: 48))
        let a = try await writer.write(frames: frames(15), to: first)
        let b = try await writer.write(frames: frames(15), to: second)
        #expect(a == b)
    }

    @Test("Frames pulled one at a time give the same file as frames handed over")
    func pullingMatchesHandingOver() async throws {
        let source = frames(8)
        let settings = EncodeSettings(width: 64, height: 48, framesPerSecond: 30)

        let handed = try await VideoWriter(settings: settings)
            .write(frames: source, to: temporaryURL())

        var remaining = source.makeIterator()
        let pulled = try await VideoWriter(settings: settings)
            .write(to: temporaryURL()) { remaining.next() }

        #expect(handed.frames == pulled.frames)
        #expect(handed.duration == pulled.duration)
        #expect(handed.width == pulled.width)
    }

    @Test("A pulled file is as long as the frames that were pulled")
    func pulledFileLength() async throws {
        let source = frames(5)
        var index = 0
        let result = try await VideoWriter(
            settings: EncodeSettings(width: 64, height: 48, framesPerSecond: 30)
        ).write(to: temporaryURL()) {
            guard index < source.count else { return nil }
            defer { index += 1 }
            return TimedFrame(image: source[index].image, at: .seconds(Double(index)))
        }
        #expect(result.duration == .seconds(4))
        #expect(result.frames == 5)
    }

    @Test("Nothing to pull is refused, and says that is what happened")
    func nothingToPull() async throws {
        let thrown = await #expect(throws: EncodeError.self) {
            try await VideoWriter(
                settings: EncodeSettings(width: 64, height: 48)
            ).write(to: self.temporaryURL()) { nil }
        }
        #expect(thrown?.code == EncodeError.nothingToWrite)
    }

    @Test("Nothing handed over is refused, and says that is what happened")
    func nothingHandedOver() async throws {
        let thrown = await #expect(throws: EncodeError.self) {
            try await VideoWriter(settings: EncodeSettings(width: 64, height: 48))
                .write(frames: [], to: self.temporaryURL())
        }
        #expect(thrown?.code == EncodeError.nothingToWrite)
    }
}
