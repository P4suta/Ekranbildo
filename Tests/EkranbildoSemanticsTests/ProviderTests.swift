import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoSemantics
import EkranbildoTestKit
import Testing

@Suite("Region provider")
struct RegionProviderTests {

    @Test("The answer describes the picture it was asked about")
    func canvasTravels() throws {
        let screen = SceneLibrary.applicationWindow
        let semantics = try RegionSemanticProvider().analyse(screen.image)
        #expect(semantics.canvas.raw.width == Double(screen.width))
        #expect(semantics.canvas.raw.height == Double(screen.height))
    }

    @Test("Everything drawn turns up as an element")
    func findsElements() throws {
        let semantics = try RegionSemanticProvider().analyse(SceneLibrary.applicationWindow.image)
        #expect(semantics.elements.count >= 5)
        #expect(semantics.elements.allSatisfy { $0.provenance == .regionAnalysis })
    }

    @Test("It offers no opinion about saliency")
    func noSaliency() throws {
        #expect(try RegionSemanticProvider().analyse(SceneLibrary.dialog.image).saliency.isEmpty)
    }

    @Test("The version says which detector answered")
    func versionRecorded() throws {
        let provider = RegionSemanticProvider()
        #expect(try provider.analyse(SceneLibrary.dialog.image).providerVersion == provider.version)
        #expect(!provider.version.isEmpty)
    }

    @Test("An empty picture produces an empty answer rather than failing")
    func emptyImage() throws {
        let semantics = try RegionSemanticProvider()
            .analyse(ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []))
        #expect(semantics.elements.isEmpty)
    }

    @Test("Analysis is reproducible")
    func reproducible() {
        let image = SceneLibrary.applicationWindow.image
        #expect(isReproducible { try? RegionSemanticProvider().analyse(image) })
    }
}

@Suite("Recorded provider")
struct RecordedProviderTests {

    private func recorded() throws -> SceneSemantics {
        try RegionSemanticProvider().analyse(SceneLibrary.applicationWindow.image)
    }

    @Test("It returns exactly what was recorded")
    func replays() throws {
        let snapshot = try recorded()
        let replayed = try RecordedSemanticProvider(snapshot).analyse(
            SceneLibrary.applicationWindow.image)
        #expect(replayed == snapshot)
    }

    @Test("It refuses a picture it was not recorded from")
    func refusesADifferentPicture() throws {
        let provider = RecordedSemanticProvider(try recorded())
        #expect(throws: (any Error).self) {
            try provider.analyse(SceneLibrary.dialog.image)
        }
    }

    @Test("The recorded version travels rather than being restated")
    func keepsVersion() throws {
        let snapshot = try recorded()
        #expect(RecordedSemanticProvider(snapshot).version == snapshot.providerVersion)
    }
}
