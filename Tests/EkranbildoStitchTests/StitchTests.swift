import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoStitch
import EkranbildoTestKit
import Testing

@Suite("Stitching")
struct StitchTests {

    private static let pageHeight = 600
    private static let viewport = 120

    private func page() -> ImageBuffer {
        ScrollSimulator.page(width: 160, height: Self.pageHeight)
    }

    private func frames(
        _ offsets: [Int],
        stickyTop: Int = 0,
        stickyBottom: Int = 0,
        restless: SceneRect? = nil,
        noise: Int = 0,
        page content: ImageBuffer? = nil
    ) -> [ImageBuffer] {
        ScrollSimulator(
            page: content ?? page(),
            viewportHeight: Self.viewport,
            stickyTop: stickyTop,
            stickyBottom: stickyBottom,
            restless: restless,
            noise: noise
        )
        .frames(offsets: offsets)
        .map(\.image)
    }

    @Test("The shift between two frames is the distance scrolled")
    func findsShift() throws {
        let taken = frames([0, 40])
        let found = try #require(
            Stitcher().shift(from: taken[0], to: taken[1]))
        #expect(found.rows == 40)
        #expect(found.confidence > Stitcher.Defaults.acceptableCorrelation)
    }

    @Test("Two frames of the same place have not moved")
    func noShift() throws {
        let taken = frames([80, 80])
        #expect(try #require(Stitcher().shift(from: taken[0], to: taken[1])).rows == 0)
    }

    @Test("Scrolling back is found as a negative shift")
    func backwards() throws {
        let taken = frames([80, 50])
        #expect(try #require(Stitcher().shift(from: taken[0], to: taken[1])).rows == -30)
    }

    @Test("Noise does not stop the shift being found")
    func tolerantOfNoise() throws {
        let taken = frames([0, 45], noise: 4)
        let found = try #require(Stitcher().shift(from: taken[0], to: taken[1]))
        #expect(found.rows == 45)
    }

    @Test("A scroll with no overlap is refused rather than guessed at")
    func noOverlap() {
        let taken = frames([0, Self.viewport + 40])
        #expect(Stitcher().shift(from: taken[0], to: taken[1]) == nil)
    }

    @Test("Frames join back into the page they came from")
    func rejoins() throws {
        let content = page()
        let taken = frames([0, 60, 120, 180, 240], page: content)
        let result = try Stitcher().stitch(taken)

        #expect(result.image.height == 240 + Self.viewport)
        #expect(result.image.width == content.width)
        for y in stride(from: 0, to: result.image.height, by: 7) {
            #expect(result.image[x: 80, y: y] == content[x: 80, y: y], "row \(y) is wrong")
        }
        #expect(result.uncertainJoins.isEmpty)
    }

    @Test("A single frame is already a picture")
    func singleFrame() throws {
        let result = try Stitcher().stitch(frames([30]))
        #expect(result.image.height == Self.viewport)
    }

    @Test("No frames at all is reported rather than producing an empty picture")
    func noFrames() {
        #expect(throws: StitchError.self) { try Stitcher().stitch([]) }
    }

    @Test("An overshoot and a correction still give the page")
    func overshoot() throws {
        let content = page()
        let result = try Stitcher().stitch(frames([0, 60, 140, 100, 160], page: content))
        for y in stride(from: 0, to: result.image.height, by: 9) {
            #expect(result.image[x: 80, y: y] == content[x: 80, y: y], "row \(y) is wrong")
        }
    }

    @Test("A scroll too fast to join is reported with where it happened")
    func reportsUncertainJoins() throws {
        let result = try Stitcher().stitch(frames([0, 40, 40 + Self.viewport + 30, 400]))
        #expect(!result.uncertainJoins.isEmpty)
        #expect(result.uncertainJoins.contains { $0.betweenFrames == 1 })
    }

    @Test("A pinned header appears once, not once per frame")
    func stickyHeaderAppearsOnce() throws {
        let band = 24
        let content = page()
        let result = try Stitcher().stitch(
            frames([0, 60, 120, 180], stickyTop: band, page: content))

        #expect(result.stickyTop == band)
        for y in stride(from: band, to: result.image.height, by: 7) {
            #expect(result.image[x: 80, y: y] == content[x: 80, y: y], "row \(y) repeats a header")
        }
    }

    @Test("A pinned footer is recognised too")
    func stickyFooter() throws {
        let band = 18
        let result = try Stitcher().stitch(
            frames([0, 50, 100, 150], stickyBottom: band))
        #expect(result.stickyBottom == band)
    }

    @Test("A page with nothing pinned has no band")
    func noStickyBand() throws {
        let result = try Stitcher().stitch(frames([0, 60, 120]))
        #expect(result.stickyTop == 0)
        #expect(result.stickyBottom == 0)
    }

    @Test("A restless corner does not stop the page being joined")
    func restlessRegion() throws {
        let content = page()
        let result = try Stitcher().stitch(
            frames(
                [0, 50, 100],
                restless: SceneRect(x: 130, y: 8, width: 25, height: 16),
                page: content
            )
        )
        #expect(result.image.height == 100 + Self.viewport)
        for y in stride(from: 0, to: result.image.height, by: 8) {
            #expect(result.image[x: 40, y: y] == content[x: 40, y: y], "row \(y) is wrong")
        }
    }

    @Test("Frames of a page that never moved give that page")
    func nothingScrolled() throws {
        let result = try Stitcher().stitch(frames([40, 40, 40]))
        #expect(result.stickyTop == 0)
        #expect(result.stickyBottom == 0)
        #expect(result.image.height == Self.viewport)
    }

    @Test("The later view of a row is the one kept")
    func laterViewWins() throws {
        let content = page()
        var taken = ScrollSimulator(page: content, viewportHeight: Self.viewport)
            .frames(offsets: [0, 30])
            .map(\.image)
        taken[1] = Self.painted(
            taken[1],
            SceneRect(x: 30, y: 0, width: 40, height: 20),
            red: 255,
            green: 0,
            blue: 255
        )

        let result = try Stitcher().stitch(taken)
        let seen = result.image[x: 50, y: 40]
        #expect(seen.red == 255 && seen.blue == 255, "the first view of the row was kept")
    }

    @Test("A deep pinned band does not let a tiny overlap win")
    func deepStickyBand() throws {
        let band = Self.viewport / 2
        let result = try Stitcher().stitch(
            frames([0, 20, 40], stickyTop: band, noise: 1))

        #expect(result.stickyTop == band)
        #expect(result.image.height == 40 + Self.viewport, "the frames were joined in the wrong places")
        #expect(result.uncertainJoins.isEmpty)
    }

    private static func painted(
        _ image: ImageBuffer,
        _ rect: SceneRect,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) -> ImageBuffer {
        var pixels = image.pixels
        let channel = ImageBuffer.Channel.Offset.self
        for row in Int(rect.minY)..<min(image.height, Int(rect.maxY)) {
            for column in Int(rect.minX)..<min(image.width, Int(rect.maxX)) {
                let offset = (row * image.width + column) * ImageBuffer.Channel.count
                pixels[offset + channel.red] = red
                pixels[offset + channel.green] = green
                pixels[offset + channel.blue] = blue
            }
        }
        return ImageBuffer(
            width: image.width,
            height: image.height,
            colorSpace: image.colorSpace,
            pixels: pixels
        )
    }

    @Test("Stitching is reproducible")
    func reproducible() {
        let taken = frames([0, 55, 110], noise: 3)
        #expect(isReproducible { try? Stitcher().stitch(taken).image.pixels })
    }

    @Test("Frames of different widths are refused")
    func mismatchedFrames() {
        let short = ScrollSimulator(
            page: ScrollSimulator.page(width: 100, height: 400),
            viewportHeight: Self.viewport
        ).frames(offsets: [0]).map(\.image)
        #expect(throws: StitchError.self) {
            try Stitcher().stitch(frames([0, 40]) + short)
        }
    }
}
