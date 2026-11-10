enum LZW {

    static func encode(_ indices: [UInt8], bits: Int) -> [UInt8] {
        let codeSize = max(Code.smallestSize, bits)
        let clear = 1 << codeSize
        let end = clear + 1

        var output = BitWriter()
        var table = Table(codeSize: codeSize)
        var width = codeSize + 1

        output.append(clear, bits: width)

        var current: Int?
        for index in indices {
            let next = Int(index)
            guard let previous = current else {
                current = next
                continue
            }

            if let combined = table.code(for: previous, next) {
                current = combined
                continue
            }

            output.append(previous, bits: width)
            table.add(previous, next)

            if table.isFull {
                output.append(clear, bits: width)
                table = Table(codeSize: codeSize)
                width = codeSize + 1
            } else if table.needsWiderCodes(at: width) {
                width += 1
            }
            current = next
        }

        if let current { output.append(current, bits: width) }
        output.append(end, bits: width)

        return [UInt8(codeSize)] + blocked(output.finish())
    }

    private struct Table {
        private var codes: [Int: Int] = [:]
        private var next: Int
        private let codeSize: Int

        init(codeSize: Int) {
            self.codeSize = codeSize
            next = (1 << codeSize) + Code.reserved
        }

        func code(for previous: Int, _ index: Int) -> Int? {
            codes[Self.key(previous, index)]
        }

        mutating func add(_ previous: Int, _ index: Int) {
            guard next < Code.largest else { return }
            codes[Self.key(previous, index)] = next
            next += 1
        }

        var isFull: Bool { next >= Code.largest }

        func needsWiderCodes(at width: Int) -> Bool {
            next > (1 << width) && width < Code.widest
        }

        private static func key(_ previous: Int, _ index: Int) -> Int {
            (previous << Code.indexBits) | index
        }
    }

    private struct BitWriter {
        private var bytes: [UInt8] = []
        private var pending = 0
        private var pendingBits = 0

        mutating func append(_ code: Int, bits: Int) {
            pending |= code << pendingBits
            pendingBits += bits

            let whole = pendingBits / Byte.bits
            for _ in 0..<whole {
                bytes.append(UInt8(pending & Byte.mask))
                pending >>= Byte.bits
            }
            pendingBits -= whole * Byte.bits
        }

        mutating func finish() -> [UInt8] {
            if pendingBits > 0 {
                bytes.append(UInt8(pending & Byte.mask))
                pending = 0
                pendingBits = 0
            }
            return bytes
        }
    }

    private static func blocked(_ data: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        for start in stride(from: 0, to: data.count, by: Block.largest) {
            let size = min(Block.largest, data.count - start)
            output.append(UInt8(size))
            output.append(contentsOf: data[start..<(start + size)])
        }
        output.append(Block.terminator)
        return output
    }

    private enum Code {
        static let smallestSize = 2
        static let widest = 12
        static let largest = 1 << widest
        static let indexBits = 8
        static let reserved = 2
    }

    private enum Block {
        static let largest = 255
        static let terminator: UInt8 = 0
    }

    private enum Byte {
        static let bits = 8
        static let mask = 0xFF
    }
}
