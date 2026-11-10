public enum Fingerprint {
    public static func of(_ bytes: [UInt8]) -> String {
        var hash = FNV.basis
        for byte in bytes {
            hash ^= UInt32(byte)
            hash &*= FNV.prime
        }
        return hexadecimal(hash)
    }

    public static func of(_ text: String) -> String { of(Array(text.utf8)) }

    public static func bytes(of value: Double) -> [UInt8] {
        let pattern = value.bitPattern
        return (0..<Width.bytesInDouble).reversed().map { index in
            UInt8(truncatingIfNeeded: pattern >> (index * Width.bitsInByte))
        }
    }

    private static func hexadecimal(_ value: UInt32) -> String {
        let digits = String(value, radix: Width.hexadecimal)
        return String(repeating: "0", count: Width.digits - digits.count) + digits
    }

    private enum FNV {
        static let basis: UInt32 = 2_166_136_261
        static let prime: UInt32 = 16_777_619
    }

    private enum Width {
        static let bytesInDouble = 8
        static let bitsInByte = 8
        static let hexadecimal = 16
        static let digits = 8
    }
}
