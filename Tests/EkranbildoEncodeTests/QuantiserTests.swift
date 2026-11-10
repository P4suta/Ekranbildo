import EkranbildoContracts
@testable import EkranbildoEncode
import EkranbildoFixtures
import EkranbildoTestKit
import Testing

@Suite("Quantiser")
struct QuantiserTests {

    private func picture(_ colors: [RGB], width: Int? = nil) -> ImageBuffer {
        var pixels: [UInt8] = []
        for color in colors {
            pixels.append(contentsOf: [color.red, color.green, color.blue, 255])
        }
        return ImageBuffer(
            width: width ?? colors.count,
            height: width.map { colors.count / $0 } ?? 1,
            colorSpace: .sRGB,
            pixels: pixels
        )
    }

    private func screenshot() -> ImageBuffer {
        let palette: [RGB] = [
            RGB(246, 246, 248), RGB(28, 28, 30), RGB(0, 122, 255), RGB(142, 142, 147), RGB(255, 59, 48),
        ]
        var colors: [RGB] = []
        for row in 0..<40 {
            for column in 0..<40 {
                colors.append(palette[(row / 8 + column / 20) % palette.count])
            }
        }
        return picture(colors, width: 40)
    }

    @Test("The palette never has more colours than were asked for", arguments: [2, 16, 256])
    func staysWithinTheLimit(limit: Int) {
        let result = Quantiser(colors: limit).quantise([screenshot()])
        #expect(result.palette.count <= limit)
        #expect(!result.palette.isEmpty)
    }

    @Test("A picture that already fits keeps its colours exactly")
    func exactWhenItFits() throws {
        let source = picture([RGB(255, 0, 0), RGB(0, 255, 0), RGB(0, 0, 255), RGB(255, 0, 0)])
        let result = Quantiser(colors: 256).quantise([source])

        let frame = try #require(result.frames.first)
        for (index, expected) in [RGB(255, 0, 0), RGB(0, 255, 0), RGB(0, 0, 255), RGB(255, 0, 0)].enumerated()
        {
            let color = result.palette[Int(frame[index])]
            #expect(Int(color.red) == expected.red)
            #expect(Int(color.green) == expected.green)
            #expect(Int(color.blue) == expected.blue)
        }
    }

    @Test("One index comes back per pixel")
    func oneIndexPerPixel() throws {
        let result = Quantiser(colors: 16).quantise([screenshot(), screenshot()])
        #expect(result.frames.count == 2)
        for frame in result.frames {
            #expect(frame.count == 40 * 40)
        }
    }

    @Test("Frames are quantised together rather than one at a time")
    func oneePaletteForEveryFrame() {
        let red = picture([RGB(255, 0, 0), RGB(255, 0, 0)])
        let blue = picture([RGB(0, 0, 255), RGB(0, 0, 255)])
        let result = Quantiser(colors: 256).quantise([red, blue])

        #expect(result.palette.contains { $0.red == 255 && $0.blue == 0 })
        #expect(result.palette.contains { $0.blue == 255 && $0.red == 0 })
    }

    @Test("A screenshot's own colours come back unchanged")
    func screenshotSurvives() throws {
        let source = screenshot()
        let result = Quantiser(colors: 256).quantise([source])
        let frame = try #require(result.frames.first)

        var worst = 0
        for index in 0..<(source.width * source.height) {
            let was = source[x: index % source.width, y: index / source.width]
            let now = result.palette[Int(frame[index])]
            worst = max(
                worst,
                max(
                    abs(Int(was.red) - Int(now.red)),
                    max(abs(Int(was.green) - Int(now.green)), abs(Int(was.blue) - Int(now.blue)))
                ))
        }
        #expect(worst == 0, "a screenshot's five colours should need no approximating")
    }

    @Test("Colours that do not fit are approximated closely rather than crudely")
    func approximatesCloselyWhenItMustChoose() throws {
        let ramp = (0..<200).map { RGB(UInt8($0), UInt8($0), UInt8($0)) }
        let source = picture(ramp)
        let result = Quantiser(colors: 16).quantise([source])
        let frame = try #require(result.frames.first)

        var worst = 0
        for index in 0..<ramp.count {
            let now = result.palette[Int(frame[index])]
            worst = max(worst, abs(Int(ramp[index].red) - Int(now.red)))
        }
        #expect(worst <= 200 / 16)
    }

    @Test("A picture of nothing gives nothing rather than trapping")
    func emptyPicture() {
        let result = Quantiser(colors: 16)
            .quantise([ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: [])])
        #expect(result.frames.first?.isEmpty == true)
        #expect(!result.palette.isEmpty)
    }

    @Test("No pictures at all gives no frames")
    func noPictures() {
        #expect(Quantiser(colors: 16).quantise([]).frames.isEmpty)
    }

    @Test("A picture of one colour gives a palette of one")
    func oneColour() {
        let result = Quantiser(colors: 256).quantise([picture([RGB(9, 9, 9), RGB(9, 9, 9)])])
        #expect(result.palette.count == 1)
    }

    @Test("A limit of nothing is treated as a limit of one", arguments: [0, -5])
    func absurdLimit(limit: Int) {
        #expect(Quantiser(colors: limit).quantise([screenshot()]).palette.count == 1)
    }

    @Test("The same pictures always give the same palette")
    func reproducible() {
        let pictures = [screenshot(), picture((0..<50).map { RGB(UInt8($0 * 5), 40, 90) })]
        #expect(isReproducible { Quantiser(colors: 32).quantise(pictures).palette })
        #expect(isReproducible { Quantiser(colors: 32).quantise(pictures).frames })
    }

    private func meanSquaredError(_ source: ImageBuffer, colors: Int) throws -> Double {
        let result = Quantiser(colors: colors).quantise([source])
        let frame = try #require(result.frames.first)

        var total = 0.0
        for index in 0..<(source.width * source.height) {
            let was = source[x: index % source.width, y: index / source.width]
            let now = result.palette[Int(frame[index])]
            let red = Double(Int(was.red) - Int(now.red))
            let green = Double(Int(was.green) - Int(now.green))
            let blue = Double(Int(was.blue) - Int(now.blue))
            total += red * red + green * green + blue * blue
        }
        return total / Double(source.width * source.height)
    }

    private func screenLike() -> ImageBuffer {
        var screen = SceneLibrary.applicationWindow

        let ink = ImageBuffer.Pixel(red: 30, green: 30, blue: 34, alpha: 255)
        let paper = ImageBuffer.Pixel(red: 246, green: 246, blue: 248, alpha: 255)
        for line in 0..<6 {
            for step in 0..<32 {
                let mix = Double(step) / 31
                screen.paint(
                    SceneRect(x: Double(20 + step * 2), y: Double(60 + line * 6), width: 2, height: 4),
                    color: ImageBuffer.Pixel(
                        red: Self.blend(ink.red, paper.red, mix),
                        green: Self.blend(ink.green, paper.green, mix),
                        blue: Self.blend(ink.blue, paper.blue, mix),
                        alpha: 255
                    )
                )
            }
        }
        return screen.image
    }

    private static func blend(_ from: UInt8, _ to: UInt8, _ position: Double) -> UInt8 {
        UInt8((Double(from) + (Double(to) - Double(from)) * position).rounded())
    }

    @Test(
        "Colours are spent where the pixels are and where the range is",
        arguments: [(16, 60.0), (64, 16.0), (256, 4.0)]
    )
    func spendsColoursWell(colors: Int, bound: Double) throws {
        #expect(try meanSquaredError(screenLike(), colors: colors) < bound)
    }

    @Test("A larger palette is never a worse fit")
    func moreColoursNeverHurt() throws {
        var worse = Double.infinity
        for size in [2, 4, 8, 16, 64] {
            let error = try meanSquaredError(screenLike(), colors: size)
            #expect(error <= worse + 1e-9, "\(size) colours fitted worse than fewer did")
            worse = error
        }
    }

    @Test("A picture that is mostly one shade does not lose everything else")
    func oneDominantShade() throws {
        var colors: [RGB] = []
        for _ in 0..<5000 { colors.append(RGB(5, 5, 5)) }
        for shade in 0..<250 { colors.append(RGB(UInt8(shade), UInt8(shade), UInt8(shade))) }
        let source = picture(colors, width: 150)

        #expect(try meanSquaredError(source, colors: 2) < 1000)
        #expect(try meanSquaredError(source, colors: 8) < 100)
    }

    @Test("A palette entry is rounded to the nearest rather than down")
    func roundsToNearest() throws {
        let source = picture([RGB(10, 10, 10), RGB(11, 11, 11)], width: 2)
        let result = Quantiser(colors: 1).quantise([source])
        #expect(result.palette.first?.red == 11)
    }

    @Test("The work is proportional to the pixels and the colours, not to either squared")
    func workIsCounted() {
        let source = screenshot()
        let result = Quantiser(colors: 16).quantise([source])

        #expect(result.work.pixelsRead == source.width * source.height * 2)
        #expect(result.work.distinctColors == 5)
        #expect(result.work.paletteComparisons == 5 * result.palette.count)
    }

    @Test("A larger picture of the same colours costs no more to choose a palette for")
    func costScalesOnColoursRatherThanPixels() {
        let small = Quantiser(colors: 16).quantise([screenshot()])
        let large = Quantiser(colors: 16).quantise([screenshot(), screenshot(), screenshot()])

        #expect(large.work.pixelsRead > small.work.pixelsRead)
        #expect(large.work.paletteComparisons == small.work.paletteComparisons)
    }
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
