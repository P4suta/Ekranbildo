import EkranbildoContracts
import EkranbildoGeometry
import Foundation

public final class AssetStore: AssetStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var images: Lookup<String, ImageBuffer> = Lookup()

    public init() {}

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return images.count
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return images.isEmpty
    }

    @discardableResult
    public func put(_ image: ImageBuffer) -> ImageRef {
        let name = ContentHash.of(image)
        lock.lock()
        defer { lock.unlock() }
        images[name] = image
        return ImageRef(
            contentHash: name, pixelWidth: image.width, pixelHeight: image.height)
    }

    public func put(_ image: ImageBuffer, as name: String) {
        lock.lock()
        defer { lock.unlock() }
        images[name] = image
    }

    public func image(for ref: ImageRef) -> ImageBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return images[ref.contentHash]
    }

    public func remove(_ ref: ImageRef) {
        lock.lock()
        defer { lock.unlock() }
        images[ref.contentHash] = nil
    }
}
