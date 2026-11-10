import EkranbildoContracts
import Foundation

public struct GIFWriter: Sendable {
    private let colors: Int
    private let loops: Int

    public init(colors: Int = Quantiser.Limits.colors, loops: Int = 0) {
        self.colors = colors
        self.loops = max(0, loops)
    }

    public func write(_ frames: [HeldFrame]) throws -> [UInt8] {
        guard let first = frames.first?.image else {
            throw EncodeError(
                code: EncodeError.nothingToWrite,
                detail: "there are no frames to write"
            )
        }
        guard first.width > 0, first.height > 0 else {
            throw EncodeError(
                code: EncodeError.nothingToWrite,
                detail: "the first frame has no pixels"
            )
        }

        let quantised = Quantiser(colors: colors).quantise(frames.map(\.image))
        let table = Self.paddedTable(quantised.palette)

        var bytes: [UInt8] = []
        bytes.append(contentsOf: Array(Header.signature.utf8))
        bytes.append(
            contentsOf: Self.screenDescriptor(
                width: first.width, height: first.height, tableSize: table.count))
        for color in table {
            bytes.append(contentsOf: [color.red, color.green, color.blue])
        }

        if frames.count > 1 {
            bytes.append(contentsOf: Self.loopExtension(loops))
        }

        let bits = Self.indexBits(table.count)
        for (index, frame) in frames.enumerated() {
            bytes.append(contentsOf: Self.graphicControl(frame.showFor))
            bytes.append(
                contentsOf: Self.imageDescriptor(
                    width: frame.image.width, height: frame.image.height))
            bytes.append(contentsOf: LZW.encode(quantised.frames[index], bits: bits))
        }

        bytes.append(Header.trailer)
        return bytes
    }

    static func paddedTable(_ palette: [PaletteColor]) -> [PaletteColor] {
        let size = tableSize(holding: palette.count)
        return palette
            + Array(
                repeating: PaletteColor(red: 0, green: 0, blue: 0),
                count: size - palette.count
            )
    }

    static func tableSize(holding colors: Int) -> Int {
        min(Quantiser.Limits.colors, 1 << indexBits(max(Table.smallest, colors)))
    }

    static func indexBits(_ tableSize: Int) -> Int {
        let highest = Int.bitWidth - max(1, tableSize - 1).leadingZeroBitCount
        return min(Table.widestIndex, max(1, highest))
    }

    static func screenDescriptor(width: Int, height: Int, tableSize: Int) -> [UInt8] {
        let flags = UInt8(Flags.globalTable | (indexBits(tableSize) - 1))
        return little(width) + little(height) + [flags, Flags.backgroundIndex, Flags.squarePixels]
    }

    static func graphicControl(_ showFor: Timestamp) -> [UInt8] {
        let hundredths = max(
            Timing.shortest,
            Int((showFor.seconds * Double(Timing.hundredthsPerSecond)).rounded())
        )
        return [Header.extensionIntroducer, Header.graphicControlLabel, Blocks.graphicControlSize]
            + [Flags.noDisposal] + little(min(Timing.longest, hundredths)) + [0, Blocks.terminator]
    }

    static func imageDescriptor(width: Int, height: Int) -> [UInt8] {
        [Header.imageSeparator] + little(0) + little(0) + little(width) + little(height) + [0]
    }

    static func loopExtension(_ loops: Int) -> [UInt8] {
        [Header.extensionIntroducer, Header.applicationLabel, Blocks.applicationNameSize]
            + Array(Header.netscape.utf8)
            + [Blocks.loopDataSize, Blocks.loopSubBlockID]
            + little(min(Timing.longest, loops))
            + [Blocks.terminator]
    }

    static func little(_ value: Int) -> [UInt8] {
        [UInt8(value & Byte.mask), UInt8((value >> Byte.bits) & Byte.mask)]
    }

    private enum Header {
        static let signature = "GIF89a"
        static let trailer: UInt8 = 0x3B
        static let extensionIntroducer: UInt8 = 0x21
        static let graphicControlLabel: UInt8 = 0xF9
        static let applicationLabel: UInt8 = 0xFF
        static let imageSeparator: UInt8 = 0x2C
        static let netscape = "NETSCAPE2.0"
    }

    private enum Flags {
        static let globalTable = 0x80
        static let backgroundIndex: UInt8 = 0
        static let squarePixels: UInt8 = 0
        static let noDisposal: UInt8 = 0
    }

    private enum Blocks {
        static let graphicControlSize: UInt8 = 4
        static let applicationNameSize: UInt8 = 11
        static let loopDataSize: UInt8 = 3
        static let loopSubBlockID: UInt8 = 1
        static let terminator: UInt8 = 0
    }

    private enum Table {
        static let smallest = 2
        static let widestIndex = 8
    }

    private enum Timing {
        static let hundredthsPerSecond = 100
        static let shortest = 1
        static let longest = 65_535
    }

    private enum Byte {
        static let bits = 8
        static let mask = 0xFF
    }
}
