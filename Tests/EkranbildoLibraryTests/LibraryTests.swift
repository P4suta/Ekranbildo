import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoLibrary
import EkranbildoTestKit
import Testing

@Suite("Library")
struct LibraryTests {

    private func entry(_ index: Int, at moment: Double) -> LibraryEntry {
        LibraryEntry(
            id: CaptureID(UInt32(index)),
            takenAt: Timestamp.seconds(moment),
            image: ImageRef(contentHash: "shot-\(index)", pixelWidth: 100, pixelHeight: 60),
            canvas: Size(width: 100, height: 60),
            source: .region
        )
    }

    private func library(_ count: Int, limit: Int = Library.Defaults.limit) -> Library {
        var library = Library(limit: limit)
        for index in 0..<count {
            library.add(entry(index, at: Double(index)))
        }
        return library
    }

    @Test("The newest capture comes first")
    func newestFirst() {
        #expect(library(3).entries.map(\.id) == [CaptureID(2), CaptureID(1), CaptureID(0)])
    }

    @Test("Two captures at the same moment still have an order")
    func sameMoment() {
        var library = Library()
        library.add(entry(1, at: 5))
        library.add(entry(2, at: 5))
        #expect(library.entries.map(\.id) == [CaptureID(2), CaptureID(1)])
    }

    @Test("An empty library is empty rather than broken")
    func empty() {
        let library = Library()
        #expect(library.entries.isEmpty)
        #expect(library.newest == nil)
    }

    @Test("The newest is the first")
    func newest() {
        #expect(library(3).newest?.id == CaptureID(2))
    }

    @Test("The library keeps only as many as it is allowed")
    func obeysLimit() {
        #expect(library(20, limit: 5).entries.count == 5)
    }

    @Test("It is the oldest that goes")
    func oldestGoes() {
        let library = library(8, limit: 3)
        #expect(library.entries.map(\.id) == [CaptureID(7), CaptureID(6), CaptureID(5)])
    }

    @Test("What was dropped is reported")
    func reportsDropped() {
        var library = Library(limit: 2)
        library.add(entry(1, at: 1))
        library.add(entry(2, at: 2))
        let dropped = library.add(entry(3, at: 3))
        #expect(dropped.map(\.id) == [CaptureID(1)])
    }

    @Test("Nothing is dropped while there is room")
    func nothingDropped() {
        var library = Library(limit: 5)
        #expect(library.add(entry(1, at: 1)).isEmpty)
    }

    @Test("An entry can be found by its identifier")
    func findsByID() {
        #expect(library(5).entry(CaptureID(2))?.id == CaptureID(2))
        #expect(library(5).entry(CaptureID(99)) == nil)
    }

    @Test("Removing takes one out and says what it was")
    func removes() {
        var library = library(3)
        let removed = library.remove(CaptureID(1))
        #expect(removed?.id == CaptureID(1))
        #expect(library.entries.count == 2)
        #expect(library.entry(CaptureID(1)) == nil)
    }

    @Test("Removing something that is not there changes nothing")
    func removesNothing() {
        var library = library(3)
        #expect(library.remove(CaptureID(99)) == nil)
        #expect(library.entries.count == 3)
    }

    @Test("Clearing reports everything it removed")
    func clears() {
        var library = library(4)
        #expect(library.clear().count == 4)
        #expect(library.entries.isEmpty)
    }

    @Test("A library survives a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(library(3)))
    }

    @Test("The order survives a round trip")
    func orderSurvives() throws {
        #expect(try roundTripped(library(4)).entries.map(\.id) == library(4).entries.map(\.id))
    }

    @Test("Adding is reproducible")
    func reproducible() {
        #expect(isReproducible { library(6, limit: 4).entries.map(\.id) })
    }
}
