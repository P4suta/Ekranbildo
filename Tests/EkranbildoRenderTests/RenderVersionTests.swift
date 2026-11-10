import EkranbildoContracts
import EkranbildoCore
import EkranbildoRender
import Testing

@Suite("The renderer's version")
struct RenderVersionTests {

    @Test("The version is the same in every process")
    func stableAcrossProcesses() {
        #expect(RenderVersion.current == "draw-b6d6c4da")
    }

    @Test("Asking twice gives the same answer")
    func stableWithinAProcess() {
        #expect(RenderVersion.current == RenderVersion.of(RenderVersion.reference))
    }

    @Test("A scene that draws differently gets a different version")
    func differentDrawingDifferentVersion() {
        let reference = RenderVersion.reference
        let moved = Scene(
            canvas: reference.canvas,
            background: reference.background,
            annotations: reference.annotations.map { annotation in
                Annotation(
                    id: annotation.id,
                    target: annotation.target,
                    label: annotation.label + " and more",
                    placement: annotation.placement,
                    badge: annotation.badge
                )
            },
            style: reference.style
        )
        #expect(RenderVersion.of(moved) != RenderVersion.current)
    }
}
