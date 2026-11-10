import EkranbildoGeometry

public protocol AssetStoring: Sendable {
    func image(for ref: ImageRef) -> ImageBuffer?
}

public enum ContentHash {

    public static func of(_ image: ImageBuffer) -> String {
        var hash = Constants.offsetBasis
        func absorb(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= Constants.prime
        }
        func absorb(_ value: Int) {
            var remaining = UInt64(bitPattern: Int64(value))
            for _ in 0..<Constants.bytesPerInteger {
                absorb(UInt8(truncatingIfNeeded: remaining))
                remaining >>= Constants.bitsPerByte
            }
        }

        for dimension in Self.shape(of: image) { absorb(dimension) }
        for byte in image.pixels { absorb(byte) }

        return String(hash, radix: Constants.radix)
    }

    static func shape(of image: ImageBuffer) -> [Int] {
        [image.width, image.height]
    }

    private enum Constants {
        static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        static let prime: UInt64 = 1_099_511_628_211
        static let bytesPerInteger = 8
        static let bitsPerByte: UInt64 = 8
        static let radix = 36
    }
}

public struct InMemoryAssetStore: AssetStoring {
    private var images: Lookup<String, ImageBuffer> = Lookup()

    public init() {}

    public var count: Int { images.count }

    @discardableResult
    public mutating func store(_ image: ImageBuffer) -> ImageRef {
        let hash = ContentHash.of(image)
        images[hash] = image
        return ImageRef(contentHash: hash, pixelWidth: image.width, pixelHeight: image.height)
    }

    public func image(for ref: ImageRef) -> ImageBuffer? {
        images[ref.contentHash]
    }
}
