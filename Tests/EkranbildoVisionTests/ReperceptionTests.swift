import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoLayout
import EkranbildoRender
import EkranbildoRenderCoreGraphics
@testable import EkranbildoVision
import Testing

@Suite("Reperception")
struct ReperceptionTests {

    private static let scale: Double = 2

    private func annotated(_ labels: [String], style: StyleTokens = .standard) throws
        -> ImageBuffer
    {
        var screen = SceneLibrary.applicationWindow
        screen.paint(
            SceneRect(x: 0, y: 0, width: 420, height: 260),
            color: .opaque(red: 246, green: 246, blue: 248)
        )

        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 420, height: 260),
            background: nil,
            annotations: labels.enumerated().map { index, label in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: SceneRect(
                        x: 40 + Double(index % 2) * 240,
                        y: 60 + Double(index / 2) * 90,
                        width: 70,
                        height: 26
                    ),
                    label: label,
                    placement: nil
                )
            },
            style: style
        )

        let measurer = TabulatedTextMeasurer.uniform()
        let solved = ExactSolver().solve(
            LayoutProblem(
                canvas: scene.canvas,
                style: scene.style,
                annotations: scene.annotations,
                measurer: measurer
            ),
            budget: .standard
        )
        let placed = Scene(
            canvas: scene.canvas,
            background: nil,
            annotations: solved.applied(to: scene.annotations),
            style: style
        )

        let list = DrawListBuilder(measurer: measurer).build(placed)
        let onPaper = DrawList(
            canvas: list.canvas,
            colorSpace: list.colorSpace,
            commands: [.fill(.rect(list.canvas), .solid(Color(red: 1, green: 1, blue: 1, alpha: 1)))]
                + list.commands
        )
        return try CoreGraphicsRenderer().render(onPaper, scale: Self.scale).bitmap.imageBuffer
    }

    private func read(_ image: ImageBuffer) throws -> [String] {
        try VisionSemanticProvider(findsSaliency: false).analyse(image)
            .elements
            .compactMap(\.text)
    }

    @Test("A label this application drew can be read back off the picture")
    func labelsAreLegible() throws {
        let words = ["Search field", "Save changes", "Toggle"]
        let seen = try read(try annotated(words))

        for word in words {
            #expect(
                seen.contains { $0.localizedCaseInsensitiveContains(word) },
                "'\(word)' could not be read back; the recogniser saw \(seen)"
            )
        }
    }

    @Test("A label stays legible at the size it is actually drawn")
    func legibleAtTheShippedSize() throws {
        var style = StyleTokens.standard
        style.labelFont = FontSpec(
            family: style.labelFont.family, size: style.labelFont.size, weight: .semibold)

        let seen = try read(try annotated(["Open settings"], style: style))
        #expect(seen.contains { $0.localizedCaseInsensitiveContains("settings") }, "saw \(seen)")
    }

    @Test("A label nobody could read is not read back")
    func unreadableIsNotRead() throws {
        var style = StyleTokens.standard
        style.labelPlateColor = Color(red: 1, green: 1, blue: 1, alpha: 1)
        style.labelColor = Color(red: 1, green: 1, blue: 1, alpha: 1)

        let seen = try read(try annotated(["Search field"], style: style))
        #expect(
            !seen.contains { $0.localizedCaseInsensitiveContains("Search") },
            "an invisible label was read back as \(seen); the check cannot fail"
        )
    }
}
