@testable import DevKit
import Testing

@Suite("Rebuilding a value from its own parts")
struct RebuildTests {

    private func findings(_ source: String) -> [Finding] {
        RebuildRules.findings(
            in: source, path: "Example.swift", protecting: ["Annotation", "Scene", "Pair"])
    }

    @Test("A value built from two of another value's fields is a rebuild")
    func twoFields() {
        let found = findings(
            """
            func changed(_ annotation: Annotation) -> Annotation {
                Annotation(id: annotation.id, target: annotation.target, label: "New")
            }
            """
        )
        #expect(found.count == 1)
        #expect(found[0].advice.contains("annotation"))
    }

    @Test("What it says names the call that has to change")
    func namesTheCall() {
        let found = findings(
            """
            let next = Scene(canvas: scene.canvas, annotations: scene.annotations)
            """
        )
        #expect(found[0].advice.contains("Scene"))
        #expect(found[0].advice.contains("replacing"))
    }

    @Test("One field of another value is not a rebuild")
    func oneField() {
        #expect(findings("let made = Scene(canvas: other.canvas, style: .standard)").isEmpty)
    }

    @Test("A type with no replacing method of its own is not protected")
    func unprotectedType() {
        #expect(findings("let size = Size(width: box.width, height: box.height)").isEmpty)
    }

    @Test("Turning one value into another kind of value is not a rebuild")
    func conversion() {
        #expect(
            findings("let size = NSSize(width: scene.width, height: scene.height)").isEmpty)
    }

    @Test("A value built from parts that are not another value's is not a rebuild")
    func fresh() {
        #expect(
            findings(
                """
                let made = Annotation(
                    id: AnnotationID(1), target: rect, label: "New", placement: nil)
                """
            ).isEmpty)
    }

    @Test("Fields taken from two different values are not a rebuild of either")
    func twoSources() {
        #expect(
            findings(
                "let made = Pair(left: first.value, right: second.value)"
            ).isEmpty)
    }

    @Test("A deeper path counts as coming from the value it starts at")
    func deeperPath() {
        let found = findings(
            "let next = Scene(canvas: scene.canvas.raw, annotations: scene.annotations)")
        #expect(found.count == 1)
    }

    @Test("Calling a method on a value is not building one")
    func methodCall() {
        #expect(
            findings("let next = scene.replacing(annotations: scene.annotations)").isEmpty)
    }

    @Test("A marker on the line above allows one")
    func allowedByMarker() {
        #expect(
            findings(
                """
                // rebuild:allow:next the projection is not a copy
                let next = Scene(canvas: timeline.canvas, style: timeline.style)
                """
            ).isEmpty)
    }

    @Test("A marker on the line itself allows one")
    func allowedOnTheLine() {
        #expect(
            findings(
                "let next = Scene(canvas: t.canvas, style: t.style)  // rebuild:allow a projection"
            ).isEmpty)
    }

    @Test("A marker allows the line it is on and nothing after it")
    func markerDoesNotCarry() {
        let found = findings(
            """
            // rebuild:allow:next a projection
            let first = Scene(canvas: t.canvas, style: t.style)
            let second = Scene(canvas: t.canvas, style: t.style)
            """
        )
        #expect(found.count == 1)
        #expect(found[0].line == 3)
    }

    @Test("A lowercase name is a function rather than a type")
    func notAType() {
        #expect(findings("let x = make(a: value.one, b: value.two)").isEmpty)
    }

    @Test("Every finding says where it is")
    func located() {
        let found = findings(
            """
            let a = 1
            let b = 2
            let next = Scene(canvas: scene.canvas, style: scene.style)
            """
        )
        #expect(found[0].line == 3)
        #expect(found[0].path == "Example.swift")
    }
}
