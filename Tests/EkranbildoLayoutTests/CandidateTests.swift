import EkranbildoContracts
import EkranbildoCore
import EkranbildoField
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Candidate generation")
struct CandidateGenerationTests {

    private func problem(
        canvas: SceneRect = SceneRect(x: 0, y: 0, width: 400, height: 300),
        targets: [SceneRect] = [SceneRect(x: 180, y: 130, width: 40, height: 24)]
    ) -> LayoutProblem {
        let annotations = targets.enumerated().map { index, rect in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: rect,
                label: "Label \(index + 1)",
                placement: nil
            )
        }
        return LayoutProblem(
            canvas: canvas,
            style: .standard,
            annotations: annotations,
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    @Test("One candidate is produced for every direction and length")
    func candidateCount() {
        let generator = GridCandidateGenerator()
        let candidates = generator.generate(forAnnotationAt: 0, in: problem())
        #expect(candidates.count == generator.directions.count * generator.leaderLengths.count)
    }

    @Test("Candidates cover every direction")
    func coversDirections() {
        let candidates = GridCandidateGenerator().generate(forAnnotationAt: 0, in: problem())
        let directions = Set(candidates.map(\.placement.direction))
        #expect(directions.count == Direction16.allCases.count)
    }

    @Test("Every candidate carries the annotation it belongs to")
    func carriesAnnotation() {
        let subject = problem(
            targets: [
                SceneRect(x: 40, y: 40, width: 20, height: 20),
                SceneRect(x: 240, y: 140, width: 20, height: 20),
            ]
        )
        let first = GridCandidateGenerator().generate(forAnnotationAt: 0, in: subject)
        let second = GridCandidateGenerator().generate(forAnnotationAt: 1, in: subject)
        #expect(first.allSatisfy { $0.annotationID == AnnotationID(1) })
        #expect(second.allSatisfy { $0.annotationID == AnnotationID(2) })
    }

    @Test("Identifiers are stable and unique within a problem")
    func stableIdentifiers() {
        let subject = problem(
            targets: [
                SceneRect(x: 40, y: 40, width: 20, height: 20),
                SceneRect(x: 240, y: 140, width: 20, height: 20),
            ]
        )
        let generator = GridCandidateGenerator()
        let all =
            generator.generate(forAnnotationAt: 0, in: subject)
            + generator.generate(forAnnotationAt: 1, in: subject)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(isReproducible { generator.generate(forAnnotationAt: 0, in: subject).map(\.id) })
    }

    @Test("Generation order is the same every time")
    func deterministicOrder() {
        let subject = problem()
        #expect(
            isReproducible {
                GridCandidateGenerator().generate(forAnnotationAt: 0, in: subject)
                    .map(\.placement)
            }
        )
    }

    @Test("Each candidate has its geometry already worked out")
    func geometryIsResolved() {
        let candidate = GridCandidateGenerator().generate(forAnnotationAt: 0, in: problem())[0]
        #expect(candidate.leader.points.count == 2)
        #expect(candidate.labelRect.width > 0)
        #expect(candidate.labelRect.height > 0)
    }

    @Test("A generator can be restricted to fewer directions")
    func restrictedDirections() {
        let generator = GridCandidateGenerator(directions: [.e, .w], leaderLengths: [40])
        let candidates = generator.generate(forAnnotationAt: 0, in: problem())
        #expect(candidates.count == 2)
        #expect(candidates.map(\.placement.direction) == [.e, .w])
    }
}

@Suite("Hard constraints")
struct HardConstraintTests {

    private func problem(
        canvas: SceneRect = SceneRect(x: 0, y: 0, width: 400, height: 300),
        targets: [SceneRect]
    ) -> LayoutProblem {
        let annotations = targets.enumerated().map { index, rect in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: rect,
                label: "Label",
                placement: nil
            )
        }
        return LayoutProblem(
            canvas: canvas,
            style: .standard,
            annotations: annotations,
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func candidate(
        _ subject: LayoutProblem,
        annotation: Int = 0,
        direction: Direction16,
        length: Double
    ) -> LayoutCandidate {
        GridCandidateGenerator(directions: [direction], leaderLengths: [length])
            .generate(forAnnotationAt: annotation, in: subject)[0]
    }

    @Test("A label inside the canvas satisfies the containment constraint")
    func labelInsideCanvas() {
        let subject = problem(targets: [SceneRect(x: 180, y: 130, width: 40, height: 24)])
        let inside = candidate(subject, direction: .e, length: 40)
        #expect(LabelInsideCanvas().isSatisfied(inside, in: subject))
    }

    @Test("A label pushed off the canvas fails containment")
    func labelOutsideCanvas() {
        let subject = problem(targets: [SceneRect(x: 20, y: 130, width: 40, height: 24)])
        let outside = candidate(subject, direction: .w, length: 200)
        #expect(!LabelInsideCanvas().isSatisfied(outside, in: subject))
    }

    @Test("A label flush against the canvas edge fails the margin")
    func labelFlushWithTheEdge() {
        let subject = problem(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            targets: [SceneRect(x: 180, y: 80, width: 40, height: 24)]
        )
        let generator = GridCandidateGenerator(
            directions: [.n], leaderLengths: Array(stride(from: 1.0, to: 90, by: 0.5)))
        let candidates = generator.generate(forAnnotationAt: 0, in: subject)

        let withMargin = LabelInsideCanvas(margin: 4)
        let withoutMargin = LabelInsideCanvas(margin: 0)

        let inBand = candidates.contains { candidate in
            withoutMargin.isSatisfied(candidate, in: subject)
                && !withMargin.isSatisfied(candidate, in: subject)
        }
        #expect(inBand, "no candidate landed inside the canvas but within the margin")
    }

    @Test("A label covering any target fails")
    func labelCoveringATarget() {
        let subject = problem(
            targets: [
                SceneRect(x: 180, y: 140, width: 30, height: 20),
                SceneRect(x: 230, y: 130, width: 90, height: 40),
            ]
        )
        let overlapping = candidate(subject, direction: .e, length: 20)
        #expect(!LabelClearOfTargets().isSatisfied(overlapping, in: subject))

        let clear = candidate(subject, direction: .w, length: 40)
        #expect(LabelClearOfTargets().isSatisfied(clear, in: subject))
    }

    @Test("A leader crossing another target fails")
    func leaderCrossingATarget() {
        let subject = problem(
            targets: [
                SceneRect(x: 60, y: 140, width: 20, height: 20),
                SceneRect(x: 150, y: 130, width: 40, height: 40),
            ]
        )
        let crossing = candidate(subject, direction: .e, length: 140)
        #expect(!LeaderClearOfTargets().isSatisfied(crossing, in: subject))

        let clear = candidate(subject, direction: .w, length: 40)
        #expect(LeaderClearOfTargets().isSatisfied(clear, in: subject))
    }

    @Test("Two labels that overlap fail the separation constraint")
    func overlappingLabels() {
        let subject = problem(
            targets: [
                SceneRect(x: 190, y: 120, width: 20, height: 20),
                SceneRect(x: 190, y: 160, width: 20, height: 20),
            ]
        )
        let first = candidate(subject, annotation: 0, direction: .e, length: 40)
        let second = candidate(subject, annotation: 1, direction: .e, length: 40)

        let constraint = LabelsAreSeparated(minimumGap: 40)
        #expect(!constraint.isSatisfied(first, second, in: subject))
        #expect(LabelsAreSeparated(minimumGap: 0).isSatisfied(first, second, in: subject))
    }

    @Test("Overlapping labels fail even with no minimum gap")
    func overlappingLabelsFailAtZeroGap() {
        let target = SceneRect(x: 190, y: 130, width: 20, height: 20)
        let subject = problem(targets: [target, target])
        let first = candidate(subject, annotation: 0, direction: .e, length: 40)
        let second = candidate(subject, annotation: 1, direction: .e, length: 40)

        #expect(Geo.overlaps(first.labelRect.raw, second.labelRect.raw))
        #expect(!LabelsAreSeparated(minimumGap: 0).isSatisfied(first, second, in: subject))
        #expect(!LabelsAreSeparated(minimumGap: 8).isSatisfied(first, second, in: subject))
    }

    @Test("Separation is symmetric")
    func separationIsSymmetric() {
        let subject = problem(
            targets: [
                SceneRect(x: 100, y: 100, width: 20, height: 20),
                SceneRect(x: 300, y: 200, width: 20, height: 20),
            ]
        )
        let first = candidate(subject, annotation: 0, direction: .e, length: 40)
        let second = candidate(subject, annotation: 1, direction: .w, length: 40)
        let constraint = LabelsAreSeparated(minimumGap: 8)
        #expect(
            constraint.isSatisfied(first, second, in: subject)
                == constraint.isSatisfied(second, first, in: subject)
        )
    }

    @Test("Two leaders that cross fail the crossing constraint")
    func crossingLeaders() {
        let subject = problem(
            targets: [
                SceneRect(x: 100, y: 100, width: 20, height: 20),
                SceneRect(x: 200, y: 100, width: 20, height: 20),
            ]
        )
        let first = candidate(subject, annotation: 0, direction: .se, length: 120)
        let second = candidate(subject, annotation: 1, direction: .sw, length: 120)
        #expect(!LeadersDoNotCross().isSatisfied(first, second, in: subject))

        let apart = candidate(subject, annotation: 1, direction: .e, length: 40)
        #expect(LeadersDoNotCross().isSatisfied(first, apart, in: subject))
    }

    @Test("Constraints declare where they sit on the relaxation ladder")
    func ladderRungs() {
        #expect(LabelInsideCanvas().relaxableAtRung == nil)
        #expect(LabelClearOfTargets().relaxableAtRung == nil)
        #expect(LabelsAreSeparated(minimumGap: 8).relaxableAtRung == 1)
        #expect(LeadersDoNotCross().relaxableAtRung == 2)
    }

    @Test("Every constraint has a distinct identifier")
    func distinctIdentifiers() {
        let identifiers = HardConstraints.standard(style: .standard).map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
    }
}
