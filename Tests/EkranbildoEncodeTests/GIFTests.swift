import EkranbildoContracts
@testable import EkranbildoEncode
import EkranbildoGeometry
import EkranbildoTestKit
import ImageIO
import Testing
import UniformTypeIdentifiers

@Suite("GIF")
struct GIFTests {

    private enum Sizes {
        static let busy = 200
    }

    private func picture(_ colors: [RGB], width: Int) -> ImageBuffer {
        var pixels: [UInt8] = []
        for color in colors { pixels.append(contentsOf: [color.red, color.green, color.blue, 255]) }
        return ImageBuffer(
            width: width, height: colors.count / width, colorSpace: .sRGB, pixels: pixels)
    }

    private func checkerboard(_ shade: UInt8 = 0) -> ImageBuffer {
        var colors: [RGB] = []
        for row in 0..<8 {
            for column in 0..<8 {
                colors.append(
                    (row + column).isMultiple(of: 2) ? RGB(255, 255, 255) : RGB(shade, shade, shade))
            }
        }
        return picture(colors, width: 8)
    }

    private func written(
        _ frames: [ImageBuffer],
        delay: Double = 0.1,
        loops: Int = 0
    ) throws -> [UInt8] {
        try GIFWriter(loops: loops)
            .write(frames.map { HeldFrame(image: $0, showFor: .seconds(delay)) })
    }

    @Test("It says it is a GIF")
    func header() throws {
        let bytes = try written([checkerboard()])
        #expect(Array(bytes.prefix(6)) == Array("GIF89a".utf8))
    }

    @Test("It ends where a GIF ends")
    func trailer() throws {
        #expect(try written([checkerboard()]).last == 0x3B)
    }

    @Test("It says how big the picture is")
    func screenDescriptor() throws {
        let bytes = try written([picture(Array(repeating: RGB(1, 2, 3), count: 12), width: 4)])
        #expect(Int(bytes[6]) | Int(bytes[7]) << 8 == 4)
        #expect(Int(bytes[8]) | Int(bytes[9]) << 8 == 3)
    }

    @Test("A file with no frames is refused rather than written empty")
    func nothingToWrite() {
        #expect(throws: EncodeError.self) { try self.written([]) }
    }

    @Test("The system can read back what was written")
    func systemReadsIt() throws {
        let bytes = try written([checkerboard(), checkerboard(64), checkerboard(128)])
        let source = try #require(
            CGImageSourceCreateWithData(Data(bytes) as CFData, nil))

        #expect(CGImageSourceGetType(source) as String? == UTType.gif.identifier)
        #expect(CGImageSourceGetCount(source) == 3)
    }

    @Test("Every frame comes back the size it went in")
    func framesComeBackWhole() throws {
        let bytes = try written([checkerboard(), checkerboard(64)])
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))

        for index in 0..<CGImageSourceGetCount(source) {
            let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
            #expect(image.width == 8)
            #expect(image.height == 8)
        }
    }

    @Test("The colours come back where they were put")
    func coloursComeBackInPlace() throws {
        let bytes = try written([checkerboard()])
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        let read = try ReadBack(image)
        #expect(read.isBright(x: 0, y: 0))
        #expect(!read.isBright(x: 1, y: 0))
        #expect(!read.isBright(x: 0, y: 1))
    }

    @Test("Every pixel comes back the colour it was")
    func everyPixelComesBack() throws {
        var colors: [RGB] = []
        for index in 0..<(Sizes.busy * Sizes.busy) {
            let shade = UInt8((index * 7 + index / Sizes.busy) % 256)
            colors.append(RGB(shade, UInt8(255 - Int(shade)), shade))
        }
        let source = picture(colors, width: Sizes.busy)

        let bytes = try written([source])
        let imageSource = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        let read = try ReadBack(image)

        var wrong = 0
        for y in 0..<Sizes.busy {
            for x in 0..<Sizes.busy where !read.matches(x: x, y: y, source[x: x, y: y]) {
                wrong += 1
            }
        }
        #expect(
            wrong == 0,
            "\(wrong) of \(Sizes.busy * Sizes.busy) pixels came back a different colour")
    }

    @Test("How long each frame is shown for is written down")
    func delaysAreWritten() throws {
        let bytes = try written([checkerboard(), checkerboard(64)], delay: 0.5)
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))

        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let gif = try #require(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        let delay = try #require(gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
        #expect(approximatelyEqual(delay, 0.5, tolerance: Timing.hundredth))
    }

    @Test("A frame shown for almost no time is still shown")
    func veryShortDelay() throws {
        let bytes = try written([checkerboard(), checkerboard(64)], delay: 0.001)
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let gif = try #require(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        let delay = try #require(gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
        #expect(delay >= Timing.hundredth)
    }

    @Test("It loops for ever unless told otherwise")
    func loops() throws {
        let bytes = try written([checkerboard(), checkerboard(64)])
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
        let gif = try #require(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        #expect(gif[kCGImagePropertyGIFLoopCount] as? Int == 0)
    }

    @Test("A large flat picture compresses to less than its pixels")
    func flatPictureCompresses() throws {
        let flat = picture(Array(repeating: RGB(200, 210, 220), count: 200 * 200), width: 200)
        let bytes = try written([flat])
        #expect(bytes.count < 200 * 200 / 10)

        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 1)
    }

    @Test("A picture with more colours than fit still reads back")
    func manyColours() throws {
        var colors: [RGB] = []
        for index in 0..<(120 * 120) {
            colors.append(
                RGB(UInt8(index % 256), UInt8((index / 7) % 256), UInt8((index / 53) % 256)))
        }
        let bytes = try written([picture(colors, width: 120)])

        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 120)
        #expect(image.height == 120)
    }

    @Test("A picture of no size is refused rather than written broken")
    func emptyPicture() {
        #expect(throws: EncodeError.self) {
            try self.written([ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: [])])
        }
    }

    @Test("The same frames always give the same bytes")
    func reproducible() {
        let frames = [checkerboard(), checkerboard(64), checkerboard(128)]
        #expect(isReproducible { try? self.written(frames) })
    }

    @Test(
        "A table is the smallest legal one that holds the colours",
        arguments: [[1, 2], [2, 2], [3, 4], [5, 8], [200, 256], [256, 256], [999, 256]]
    )
    func tableSize(pair: [Int]) {
        #expect(GIFWriter.tableSize(holding: pair[0]) == pair[1])
    }

    @Test(
        "An index is as many bits as the table's largest one needs",
        arguments: [[2, 1], [4, 2], [8, 3], [16, 4], [256, 8]]
    )
    func indexBits(pair: [Int]) {
        #expect(GIFWriter.indexBits(pair[0]) == pair[1])
    }

    @Test(
        "A table of an impossible size is answered rather than looped over",
        arguments: [-1, 0, 1, Int.max]
    )
    func absurdSizes(colors: Int) {
        let size = GIFWriter.tableSize(holding: colors)
        #expect(size >= 2)
        #expect(size <= 256)
        #expect(GIFWriter.indexBits(size) >= 1)
        #expect(GIFWriter.indexBits(size) <= 8)
    }
}

private struct ReadBack {
    private let pixels: [UInt8]
    private let bytesPerRow: Int

    init(_ image: CGImage) throws {
        let width = image.width
        let height = image.height
        self.bytesPerRow = width * Self.channels
        var bytes = [UInt8](repeating: 0, count: width * Self.channels * height)

        let stride = bytesPerRow
        try bytes.withUnsafeMutableBytes { raw in
            guard
                let context = CGContext(
                    data: raw.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: Self.bitsPerChannel,
                    bytesPerRow: stride,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { throw EncodeError(code: EncodeError.writeFailed, detail: "cannot read it back") }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        pixels = bytes
    }

    func isBright(x: Int, y: Int) -> Bool {
        Int(pixels[y * bytesPerRow + x * Self.channels]) > Self.midway
    }

    func matches(x: Int, y: Int, _ expected: ImageBuffer.Pixel) -> Bool {
        let offset = y * bytesPerRow + x * Self.channels
        return pixels[offset + Offset.red] == expected.red
            && pixels[offset + Offset.green] == expected.green
            && pixels[offset + Offset.blue] == expected.blue
    }

    enum Offset {
        static let red = 0
        static let green = 1
        static let blue = 2
    }

    static let channels = 4
    static let bitsPerChannel = 8
    static let midway = 128
}

private enum Timing {
    static let hundredth = 0.01
}

private struct RGB {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
