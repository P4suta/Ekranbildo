import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoRender
import Testing

@Suite("Layered drawings")
struct LayeredDrawListTests {

    private static let scene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
        background: ImageRef(contentHash: "abc", pixelWidth: 400, pixelHeight: 300),
        annotations: [
            Annotation(
                id: AnnotationID(1),
                target: SceneRect(x: 40, y: 180, width: 80, height: 24),
                label: "First",
                placement: Placement(direction: .ne, leaderLength: 44)
            ),
            Annotation(
                id: AnnotationID(2),
                target: SceneRect(x: 240, y: 60, width: 80, height: 24),
                label: "Second",
                placement: Placement(direction: .w, leaderLength: 64)
            ),
        ],
        style: .standard
    )

    private func builder() -> DrawListBuilder {
        DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
    }

    @Test("With nothing being moved, the layers are the drawing")
    func layersReassembleIntoTheDrawing() {
        let flat = builder().build(Self.scene)
        let layered = builder().layered(Self.scene, moving: [])
        #expect(layered.background + layered.still + layered.moving == flat.commands)
    }

    @Test("A layered drawing carries what a layer needs to be drawn")
    func carriesWhatALayerNeeds() {
        let flat = builder().build(Self.scene)
        let layered = builder().layered(Self.scene, moving: [])
        #expect(layered.canvas == flat.canvas)
        #expect(layered.colorSpace == flat.colorSpace)
    }

    @Test("Each layer reassembles into a drawing that is the same kind as the whole")
    func eachLayerIsADrawing() {
        let layered = builder().layered(Self.scene, moving: [AnnotationID(1)])
        let one = layered.drawing(of: layered.moving)
        #expect(one.canvas == layered.canvas)
        #expect(one.colorSpace == layered.colorSpace)
        #expect(one.commands == layered.moving)
    }

    @Test("What is being moved comes out of the still layer, not out of the drawing")
    func movingComesOutOfStill() {
        let all = builder().layered(Self.scene, moving: [])
        let one = builder().layered(Self.scene, moving: [AnnotationID(1)])
        #expect(one.background == all.background)
        #expect(!one.moving.isEmpty)
        #expect(one.still.count + one.moving.count == all.still.count)
    }

    @Test("Moving everything leaves nothing still")
    func movingEverything() {
        let layered = builder().layered(
            Self.scene, moving: [AnnotationID(1), AnnotationID(2)])
        #expect(layered.still.isEmpty)
        #expect(!layered.moving.isEmpty)
    }

    @Test("The background layer holds the picture and nothing else")
    func backgroundHoldsThePicture() {
        let layered = builder().layered(Self.scene, moving: [AnnotationID(1)])
        #expect(layered.background.count == 1)
    }

    @Test("An identifier that is not in the scene moves nothing")
    func unknownIdentifierMovesNothing() {
        let all = builder().layered(Self.scene, moving: [])
        let odd = builder().layered(Self.scene, moving: [AnnotationID(99)])
        #expect(odd.moving.isEmpty)
        #expect(odd.still == all.still)
    }

    @Test("The moving layer knows the area it covers")
    func movingKnowsItsArea() throws {
        let layered = builder().layered(Self.scene, moving: [AnnotationID(1)])
        let area = try #require(layered.movingBounds)
        for command in layered.moving {
            let bounds = try #require(command.bounds)
            #expect(area.raw.contains(bounds.raw))
        }
    }

    @Test("Nothing being moved covers no area")
    func nothingMovingCoversNothing() {
        #expect(builder().layered(Self.scene, moving: []).movingBounds == nil)
    }

    @Test("Asking twice gives the same layers")
    func stableBetweenFrames() {
        let first = builder().layered(Self.scene, moving: [AnnotationID(2)])
        let second = builder().layered(Self.scene, moving: [AnnotationID(2)])
        #expect(first.moving == second.moving)
        #expect(first.still == second.still)
    }

    @Test("An unplaced annotation is in no layer")
    func unplacedIsInNoLayer() {
        let scene = Self.scene.replacing(
            annotations: Self.scene.annotations.map { annotation in
                Annotation(
                    id: annotation.id,
                    target: annotation.target,
                    label: annotation.label,
                    placement: annotation.id == AnnotationID(1) ? nil : annotation.placement
                )
            }
        )
        let layered = builder().layered(scene, moving: [AnnotationID(1)])
        #expect(layered.moving.isEmpty)
        #expect(!layered.still.isEmpty)
    }
}
