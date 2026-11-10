@testable import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoTestKit
import Testing

@Suite("Asset store")
struct AssetStoreTests {

    @Test("A stored picture comes back")
    func storeAndFetch() {
        var store = InMemoryAssetStore()
        let screen = SceneLibrary.applicationWindow.image
        let ref = store.store(screen)

        #expect(store.image(for: ref) == screen)
        #expect(ref.pixelWidth == screen.width)
        #expect(ref.pixelHeight == screen.height)
    }

    @Test("A picture nobody stored is absent rather than invented")
    func missing() {
        let store = InMemoryAssetStore()
        let ref = ImageRef(contentHash: "nothing", pixelWidth: 1, pixelHeight: 1)
        #expect(store.image(for: ref) == nil)
    }

    @Test("The same pixels get the same name")
    func contentAddressed() {
        var store = InMemoryAssetStore()
        let first = store.store(SceneLibrary.dialog.image)
        let second = store.store(SceneLibrary.dialog.image)
        #expect(first == second)
        #expect(store.count == 1)
    }

    @Test("Different pixels get different names")
    func distinguishes() {
        var store = InMemoryAssetStore()
        #expect(
            store.store(SceneLibrary.dialog.image)
                != store.store(SceneLibrary.applicationWindow.image)
        )
    }

    @Test("A single changed pixel changes the name")
    func sensitive() {
        var screen = SceneLibrary.dialog
        var store = InMemoryAssetStore()
        let before = store.store(screen.image)
        screen.paint(
            SceneRect(x: 0, y: 0, width: 1, height: 1),
            color: .opaque(red: 1, green: 2, blue: 3)
        )
        #expect(store.store(screen.image) != before)
    }

    @Test("A picture and its transpose get different names")
    func transposeDiffers() {
        let flat = [UInt8](repeating: 0, count: 6 * ImageBuffer.Channel.count)
        let wide = ImageBuffer(width: 3, height: 2, colorSpace: .sRGB, pixels: flat)
        let tall = ImageBuffer(width: 2, height: 3, colorSpace: .sRGB, pixels: flat)
        #expect(ContentHash.of(wide) != ContentHash.of(tall))
    }

    @Test("Naming is reproducible")
    func reproducible() {
        let screen = SceneLibrary.applicationWindow.image
        #expect(isReproducible { ContentHash.of(screen) })
    }

    @Test("An empty picture is nameable")
    func emptyImage() {
        var store = InMemoryAssetStore()
        let ref = store.store(ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []))
        #expect(store.image(for: ref) != nil)
    }
}
