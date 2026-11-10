import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoSemantics
import EkranbildoTestKit
import Testing

@Suite("Detection goldens")
struct DetectionGoldenTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "detection")

    @Test("Every screen in the library", arguments: SceneLibrary.all.map(\.name))
    func screen(named name: String) throws {
        let screen = try #require(SceneLibrary.all.first { $0.name == name }?.screen)
        let elements = ElementDetector().detect(in: screen.image)
        let result = try goldens.compare(ScreenElement.listing(elements), named: name)
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("The snap ladder for a click on a nested control")
    func snapLadder() throws {
        let ladder = TargetSnapper()
            .targets(in: SceneLibrary.nestedControls.image, at: SceneLibrary.nestedControlsButton)
        let result = try goldens.compare(
            ladder.map(\.canonicalText).joined(separator: "\n"),
            named: "snap-ladder"
        )
        #expect(result.isAcceptable, "\(result.message)")
    }
}
