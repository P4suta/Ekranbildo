import EkranbildoContracts
import EkranbildoGeometry

public struct ScrollSimulator: Sendable {
    public struct Frame: Sendable {
        public let image: ImageBuffer
        public let offset: Int
    }

    private let page: ImageBuffer
    private let viewportHeight: Int
    private let stickyTop: Int
    private let stickyBottom: Int
    private let restless: SceneRect?
    private let noise: Int

    public init(
        page: ImageBuffer,
        viewportHeight: Int,
        stickyTop: Int = 0,
        stickyBottom: Int = 0,
        restless: SceneRect? = nil,
        noise: Int = 0
    ) {
        self.page = page
        self.viewportHeight = max(1, viewportHeight)
        self.stickyTop = max(0, stickyTop)
        self.stickyBottom = max(0, stickyBottom)
        self.restless = restless
        self.noise = max(0, noise)
    }

    public func frames(offsets: [Int]) -> [Frame] {
        offsets.enumerated().map { index, wanted in
            let offset = min(max(0, wanted), max(0, page.height - viewportHeight))
            return Frame(image: view(at: offset, index: index), offset: offset)
        }
    }

    private func view(at offset: Int, index: Int) -> ImageBuffer {
        var pixels = [UInt8](
            repeating: 0, count: page.width * viewportHeight * ImageBuffer.Channel.count)

        for row in 0..<viewportHeight {
            let sourceRow: Int
            if row < stickyTop {
                sourceRow = row
            } else if row >= viewportHeight - stickyBottom {
                sourceRow = page.height - (viewportHeight - row)
            } else {
                sourceRow = row + offset
            }

            for column in 0..<page.width {
                let pixel = page[x: column, y: sourceRow]
                let destination = (row * page.width + column) * ImageBuffer.Channel.count
                let channel = ImageBuffer.Channel.Offset.self
                pixels[destination + channel.red] = pixel.red
                pixels[destination + channel.green] = pixel.green
                pixels[destination + channel.blue] = pixel.blue
                pixels[destination + channel.alpha] = pixel.alpha
            }
        }

        var image = ImageBuffer(
            width: page.width,
            height: viewportHeight,
            colorSpace: page.colorSpace,
            pixels: pixels
        )
        image = disturbing(image, index: index)
        return noisy(image, index: index)
    }

    private func disturbing(_ image: ImageBuffer, index: Int) -> ImageBuffer {
        guard let restless else { return image }
        var pixels = image.pixels
        let shade = UInt8(truncatingIfNeeded: index &* Restless.stride)
        for row in Int(restless.minY)..<min(image.height, Int(restless.maxY)) {
            for column in Int(restless.minX)..<min(image.width, Int(restless.maxX)) {
                let offset = (row * image.width + column) * ImageBuffer.Channel.count
                let channel = ImageBuffer.Channel.Offset.self
                pixels[offset + channel.red] = shade
                pixels[offset + channel.green] = shade
                pixels[offset + channel.blue] = shade
            }
        }
        return ImageBuffer(
            width: image.width, height: image.height, colorSpace: image.colorSpace, pixels: pixels)
    }

    private func noisy(_ image: ImageBuffer, index: Int) -> ImageBuffer {
        guard noise > 0 else { return image }
        var pixels = image.pixels
        var generator = SplitMix64(seed: UInt64(truncatingIfNeeded: index) &+ Noise.seed)
        for offset in pixels.indices {
            let channel = offset % ImageBuffer.Channel.count
            guard channel != ImageBuffer.Channel.Offset.alpha else { continue }
            let span = noise * Noise.directions + 1
            let shift = Int(generator.next() % UInt64(span)) - noise
            pixels[offset] = UInt8(
                min(ImageBuffer.Channel.maximum, max(0, Int(pixels[offset]) + shift)))
        }
        return ImageBuffer(
            width: image.width, height: image.height, colorSpace: image.colorSpace, pixels: pixels)
    }

    public static func page(width: Int, height: Int) -> ImageBuffer {
        var screen = SyntheticScreenshot(width: width, height: height)
        var generator = SplitMix64(seed: Content.seed)
        var row = 0
        while row < height {
            let bandHeight = Content.minimumBand + Int(generator.next() % UInt64(Content.bandRange))
            screen.paint(
                SceneRect(
                    x: 0,
                    y: Double(row),
                    width: Double(width),
                    height: Double(min(bandHeight, height - row))
                ),
                color: Self.bandColor(&generator)
            )
            row += bandHeight
        }
        return screen.image
    }

    private static func bandColor(_ generator: inout SplitMix64) -> ImageBuffer.Pixel {
        let range = UInt64(ImageBuffer.Channel.maximum)
        return .opaque(
            red: UInt8(generator.next() % range),
            green: UInt8(generator.next() % range),
            blue: UInt8(generator.next() % range)
        )
    }

    private enum Restless {
        static let stride = 40
    }

    private enum Noise {
        static let seed: UInt64 = 0x5EED
        static let directions = 2
    }

    private enum Content {
        static let seed: UInt64 = 0xBA5E
        static let minimumBand = 4
        static let bandRange = 20
    }
}
