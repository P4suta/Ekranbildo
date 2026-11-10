import EkranbildoContracts

public struct MaskFailure: Hashable, Sendable {
    public let rect: SceneRect
    public let reason: String
}

public struct Redactor: Sendable {
    private let blockSize: Int

    public init(blockSize: Int = Defaults.blockSize) {
        self.blockSize = max(1, blockSize)
    }

    public enum Defaults {
        public static let blockSize = 12
    }

    public func apply(_ masks: [Mask], to image: ImageBuffer) -> ImageBuffer {
        guard !masks.isEmpty, image.isWellFormed, !image.isEmpty else { return image }

        var pixels = image.pixels
        for mask in masks {
            guard let area = Self.clamped(mask.rect, to: image) else { continue }
            switch mask.style {
            case .solid:
                Self.fill(&pixels, image: image, area: area)
            case .pixelate:
                Self.pixelate(&pixels, image: image, area: area, blockSize: blockSize)
            }
        }
        return ImageBuffer(
            width: image.width,
            height: image.height,
            colorSpace: image.colorSpace,
            pixels: pixels
        )
    }

    struct Area {
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
    }

    static func clamped(_ rect: SceneRect, to image: ImageBuffer) -> Area? {
        let minX = max(0, Int(rect.minX.rounded(.down)))
        let minY = max(0, Int(rect.minY.rounded(.down)))
        let maxX = min(image.width, Int(rect.maxX.rounded(.up)))
        let maxY = min(image.height, Int(rect.maxY.rounded(.up)))
        guard minX < maxX, minY < maxY else { return nil }
        return Area(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    private static func fill(
        _ pixels: inout [UInt8],
        image: ImageBuffer,
        area: Area
    ) {
        for row in area.minY..<area.maxY {
            for column in area.minX..<area.maxX {
                write(&pixels, image: image, column: column, row: row, to: Cover.color)
            }
        }
    }

    private static func pixelate(
        _ pixels: inout [UInt8],
        image: ImageBuffer,
        area: Area,
        blockSize: Int
    ) {
        var row = area.minY
        while row < area.maxY {
            var column = area.minX
            while column < area.maxX {
                let lastRow = min(row + blockSize, area.maxY)
                let lastColumn = min(column + blockSize, area.maxX)

                var red = 0
                var green = 0
                var blue = 0
                var count = 0
                for sampleRow in row..<lastRow {
                    for sampleColumn in column..<lastColumn {
                        let pixel = image[x: sampleColumn, y: sampleRow]
                        red += Int(pixel.red)
                        green += Int(pixel.green)
                        blue += Int(pixel.blue)
                        count += 1
                    }
                }
                guard count > 0 else {
                    column += blockSize
                    continue
                }

                let average = ImageBuffer.Pixel(
                    red: UInt8(red / count),
                    green: UInt8(green / count),
                    blue: UInt8(blue / count),
                    alpha: UInt8(ImageBuffer.Channel.maximum)
                )
                for sampleRow in row..<lastRow {
                    for sampleColumn in column..<lastColumn {
                        write(
                            &pixels,
                            image: image,
                            column: sampleColumn,
                            row: sampleRow,
                            to: average
                        )
                    }
                }
                column += blockSize
            }
            row += blockSize
        }
    }

    private static func write(
        _ pixels: inout [UInt8],
        image: ImageBuffer,
        column: Int,
        row: Int,
        to value: ImageBuffer.Pixel
    ) {
        let offset = (row * image.width + column) * ImageBuffer.Channel.count
        let channel = ImageBuffer.Channel.Offset.self
        pixels[offset + channel.red] = value.red
        pixels[offset + channel.green] = value.green
        pixels[offset + channel.blue] = value.blue
        pixels[offset + channel.alpha] = value.alpha
    }

    public func verify(
        _ masks: [Mask],
        original: ImageBuffer,
        masked: ImageBuffer
    ) -> [MaskFailure] {
        guard original.width == masked.width, original.height == masked.height else {
            return masks.map {
                MaskFailure(rect: $0.rect, reason: "the two pictures are not the same size")
            }
        }

        return masks.compactMap { mask in
            guard let area = Self.clamped(mask.rect, to: original) else { return nil }

            var changed = false
            var hadAnythingToHide = false
            let first = original[x: area.minX, y: area.minY]
            for row in area.minY..<area.maxY {
                for column in area.minX..<area.maxX {
                    let before = original[x: column, y: row]
                    if masked[x: column, y: row] != before { changed = true }
                    if before != first { hadAnythingToHide = true }
                }
            }

            guard hadAnythingToHide, !changed else { return nil }
            return MaskFailure(
                rect: mask.rect,
                reason: "the pixels under this mask are exactly what they were"
            )
        }
    }

    private enum Cover {
        private static let charcoal = (red: UInt8(24), green: UInt8(24), blue: UInt8(28))

        static let color = ImageBuffer.Pixel(
            red: charcoal.red,
            green: charcoal.green,
            blue: charcoal.blue,
            alpha: UInt8(ImageBuffer.Channel.maximum)
        )
    }
}
