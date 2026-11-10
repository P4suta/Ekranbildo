import EkranbildoContracts
@testable import EkranbildoCore
import Testing

@Suite("The asset store")
struct AssetStoreTests {

    private func image(_ value: UInt8, width: Int = 2, height: Int = 2) -> ImageBuffer {
        ImageBuffer(
            width: width,
            height: height,
            colorSpace: .displayP3,
            pixels: [UInt8](repeating: value, count: width * height * 4)
        )
    }

    @Test("A picture put in comes back")
    func roundTrips() {
        let store = AssetStore()
        let ref = store.put(image(1))
        #expect(store.image(for: ref)?.pixels == image(1).pixels)
    }

    @Test("A reference says how big the picture is")
    func referenceCarriesTheShape() {
        let ref = AssetStore().put(image(1, width: 6, height: 4))
        #expect(ref.pixelWidth == 6)
        #expect(ref.pixelHeight == 4)
    }

    @Test("A picture nobody put in is not there")
    func missingIsMissing() {
        let store = AssetStore()
        let ref = ImageRef(contentHash: "nothing", pixelWidth: 1, pixelHeight: 1)
        #expect(store.image(for: ref) == nil)
    }

    @Test("The same picture twice is one picture")
    func sameContentSameName() {
        let store = AssetStore()
        let first = store.put(image(1))
        let second = store.put(image(1))
        #expect(first == second)
        #expect(store.count == 1)
    }

    @Test("Different pictures are different")
    func differentContentDifferentName() {
        let store = AssetStore()
        let one = store.put(image(1))
        let other = store.put(image(2))
        #expect(one != other)
        #expect(store.count == 2)
    }

    @Test("A picture of a different shape is a different picture")
    func shapeIsPartOfIt() {
        let store = AssetStore()
        let tall = store.put(image(1, width: 2, height: 8))
        let wide = store.put(image(1, width: 8, height: 2))
        #expect(tall != wide)
    }

    @Test("A name does not depend on which process made it")
    func namesAreStable() {
        #expect(AssetStore().put(image(7)).contentHash == ContentHash.of(image(7)))
    }

    @Test("A picture can be let go of")
    func canBeRemoved() {
        let store = AssetStore()
        let ref = store.put(image(1))
        store.remove(ref)
        #expect(store.image(for: ref) == nil)
        #expect(store.isEmpty)
    }

    @Test("Letting go of one nobody put in changes nothing")
    func removingNothing() {
        let store = AssetStore()
        store.put(image(1))
        store.remove(ImageRef(contentHash: "nothing", pixelWidth: 1, pixelHeight: 1))
        #expect(store.count == 1)
    }
}
