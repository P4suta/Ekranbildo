import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import Foundation
import Testing

@Suite("An edit carries the whole scene")
struct SceneCarriedThroughTests {

    private static let fromTheFuture = """
        {
          "canvas": {"raw": {"origin": {"x": 0, "y": 0},
                    "size": {"width": 400, "height": 300}}},
          "annotations": [
            {"id": {"raw": 1},
             "target": {"raw": {"origin": {"x": 40, "y": 180},
                       "size": {"width": 80, "height": 24}}},
             "label": "First", "placement": null}
          ],
          "cursor": {"position": {"raw": {"x": 12, "y": 34}}, "icon": "pointer",
                     "pressed": false, "scale": 1},
          "somethingAddedLater": {"depth": 3}
        }
        """

    private func document() throws -> Document {
        let scene = try JSONDecoder().decode(Scene.self, from: Data(Self.fromTheFuture.utf8))
        #expect(scene.cursor != nil)
        #expect(!scene.unknownKeys.isEmpty)
        return Document(scene: scene, measurer: TabulatedTextMeasurer.uniform())
    }

    @Test("Adding an annotation keeps the pointer and the unfamiliar keys")
    func addingKeepsEverything() throws {
        var document = try document()
        document.apply([
            .addAnnotation(
                target: SceneRect(x: 200, y: 40, width: 60, height: 20), label: "Added")
        ])
        #expect(document.scene.annotations.count == 2)
        #expect(document.scene.cursor != nil)
        #expect(!document.scene.unknownKeys.isEmpty)
    }

    @Test("Removing an annotation keeps them too")
    func removingKeepsEverything() throws {
        var document = try document()
        document.apply([.removeAnnotations([AnnotationID(1)])])
        #expect(document.scene.annotations.isEmpty)
        #expect(document.scene.cursor != nil)
        #expect(!document.scene.unknownKeys.isEmpty)
    }

    @Test("Moving a target keeps them")
    func movingKeepsEverything() throws {
        var document = try document()
        document.apply([
            .moveTarget(AnnotationID(1), to: SceneRect(x: 10, y: 10, width: 20, height: 20))
        ])
        #expect(document.scene.cursor != nil)
        #expect(!document.scene.unknownKeys.isEmpty)
    }
}
