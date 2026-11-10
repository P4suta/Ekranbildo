import EkranbildoContracts
import EkranbildoCore
@testable import EkranbildoEditor
import EkranbildoFixtures
import EkranbildoGeometry
import Foundation
import Testing

@Suite("Placing several annotations")
struct PlacingSeveralTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 600, height: 400)

    private func document() -> Document {
        Document(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: [],
                style: .standard
            ),
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func pointing(at targets: [SceneRect]) -> Document {
        var document = document()
        for target in targets {
            document.apply([.addAnnotation(target: target, label: "Label"), .solve])
        }
        return document
    }

    private func labels(_ document: Document) throws -> [SceneRect] {
        let tester = HitTester(
            scene: document.scene, measurer: TabulatedTextMeasurer.uniform())
        return try document.scene.annotations.map { annotation in
            try #require(tester.labelRect(of: annotation.id))
        }
    }

    private static let clustered = [
        SceneRect(x: 280, y: 180, width: 40, height: 40),
        SceneRect(x: 300, y: 190, width: 40, height: 40),
        SceneRect(x: 260, y: 200, width: 40, height: 40),
    ]

    @Test("One annotation is placed")
    func justOne() throws {
        let placed = try labels(pointing(at: [Self.clustered[0]]))
        #expect(placed.count == 1)
        #expect(Self.canvas.raw.contains(placed[0].raw))
    }

    @Test("Labels placed one after another do not overlap")
    func labelsDoNotOverlap() throws {
        let placed = try labels(pointing(at: Self.clustered))
        #expect(placed.count == Self.clustered.count)
        for (index, label) in placed.enumerated() {
            for other in placed[(index + 1)...] {
                #expect(label.raw.intersection(other.raw) == nil)
            }
        }
    }

    @Test("Every label stays on the picture")
    func labelsStayOnTheCanvas() throws {
        for label in try labels(pointing(at: Self.clustered)) {
            #expect(Self.canvas.raw.contains(label.raw))
        }
    }

    @Test("No label covers anything being pointed at")
    func labelsDoNotCoverTargets() throws {
        let document = pointing(at: Self.clustered)
        for label in try labels(document) {
            for annotation in document.scene.annotations {
                #expect(label.raw.intersection(annotation.target.raw) == nil)
            }
        }
    }

    @Test("Several more still do not overlap")
    func moreOfThem() throws {
        let many = (0..<6).map {
            SceneRect(x: 150.0 + Double($0) * 45, y: 170, width: 36, height: 36)
        }
        let placed = try labels(pointing(at: many))
        for (index, label) in placed.enumerated() {
            for other in placed[(index + 1)...] {
                #expect(label.raw.intersection(other.raw) == nil)
            }
        }
    }

    @Test("The same annotations are placed the same way twice")
    func reproducible() throws {
        let once = try labels(pointing(at: Self.clustered))
        let again = try labels(pointing(at: Self.clustered))
        #expect(once == again)
    }
}

@Suite("A placement somebody chose")
struct PinnedPlacementTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 600, height: 400)

    private func document() -> Document {
        Document(
            scene: Scene(
                canvas: Self.canvas,
                background: ImageRef(contentHash: "picture", pixelWidth: 600, pixelHeight: 400),
                annotations: [],
                style: .standard
            ),
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func labels(_ document: Document) throws -> [SceneRect] {
        let tester = HitTester(
            scene: document.scene, measurer: TabulatedTextMeasurer.uniform())
        return try document.scene.annotations.map { annotation in
            try #require(tester.labelRect(of: annotation.id))
        }
    }

    private func afterPinning() -> Document {
        var document = document()
        document.apply([
            .addAnnotation(
                target: SceneRect(x: 280, y: 180, width: 40, height: 40), label: "Mine"),
            .solve,
        ])
        document.apply([.setPlacement(AnnotationID(1), Placement(direction: .sw, leaderLength: 96))])
        for offset in 1...3 {
            document.apply([
                .addAnnotation(
                    target: SceneRect(
                        x: 260 + Double(offset) * 20,
                        y: 190 + Double(offset) * 10,
                        width: 40,
                        height: 40
                    ),
                    label: "Other"
                ),
                .solve,
            ])
        }
        return document
    }

    @Test("It is still where it was put")
    func staysPut() {
        let document = afterPinning()
        #expect(
            document.scene.annotations[0].placement
                == Placement(direction: .sw, leaderLength: 96))
        #expect(document.scene.annotations[0].isPinned)
    }

    @Test("Nothing else is placed on top of it")
    func othersKeepClear() throws {
        let placed = try labels(afterPinning())
        for other in placed.dropFirst() {
            #expect(placed[0].raw.intersection(other.raw) == nil)
        }
    }

    @Test("What the solver placed is not pinned by having been placed")
    func solverPlacementsAreNotPinned() {
        var document = document()
        document.apply([
            .addAnnotation(
                target: SceneRect(x: 100, y: 100, width: 40, height: 40), label: "Label"),
            .solve,
        ])
        #expect(document.scene.annotations[0].placement != nil)
        #expect(!document.scene.annotations[0].isPinned)
    }

    @Test("An annotation read from an older document is not pinned")
    func olderDocuments() throws {
        let current = Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 0, y: 0, width: 10, height: 10),
            label: "Old",
            placement: Placement(direction: .n, leaderLength: 40),
            isPinned: true
        )
        let written = try JSONEncoder().encode(current)
        var fields = try #require(
            JSONSerialization.jsonObject(with: written) as? [String: Any])
        #expect(fields["isPinned"] != nil, "there would be nothing to take away")
        fields.removeValue(forKey: "isPinned")

        let older = try JSONSerialization.data(withJSONObject: fields)
        let read = try JSONDecoder().decode(Annotation.self, from: older)
        #expect(!read.isPinned)
        #expect(read.placement == current.placement)
        #expect(read.label == current.label)
    }
}
