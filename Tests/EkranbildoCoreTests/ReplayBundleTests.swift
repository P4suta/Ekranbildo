import EkranbildoContracts
@testable import EkranbildoCore
import Foundation
import Testing

@Suite("Replay bundles")
struct ReplayBundleTests {

    private static let pipeline = PipelineVersion(
        candidateGeneration: "grid-1",
        normalization: "norm-1",
        weights: "w-1",
        comparator: "cmp-1",
        renderer: "draw-1",
        visionRevision: "vision-3"
    )

    private static let scene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
        background: nil,
        annotations: [
            Annotation(
                id: AnnotationID(1),
                target: SceneRect(x: 40, y: 180, width: 80, height: 24),
                label: "First",
                placement: nil
            ),
            Annotation(
                id: AnnotationID(2),
                target: SceneRect(x: 240, y: 60, width: 80, height: 24),
                label: "Second",
                placement: nil
            ),
        ],
        style: .standard
    )

    private static func answer(
        first: Placement? = Placement(direction: .ne, leaderLength: 44),
        second: Placement? = Placement(direction: .w, leaderLength: 64)
    ) -> [RecordedPlacement] {
        [
            RecordedPlacement(
                annotation: AnnotationID(1),
                outcome: first.map { .placed($0) } ?? .unplaced(reason: "noFeasibleCandidate")
            ),
            RecordedPlacement(
                annotation: AnnotationID(2),
                outcome: second.map { .placed($0) } ?? .unplaced(reason: "noFeasibleCandidate")
            ),
        ]
    }

    private static func bundle() -> ReplayBundle {
        ReplayBundle(scene: scene, pipeline: pipeline, answer: answer())
    }

    @Test("The same answer from the same build replays as unchanged")
    func sameAnswerMatches() {
        let verdict = Self.bundle().compare(Self.answer(), from: Self.pipeline)
        #expect(verdict == .matched)
    }

    @Test("A placement that moved is named, with what it was and what it is now")
    func movedPlacementIsNamed() {
        let now = Self.answer(first: Placement(direction: .se, leaderLength: 90))
        let verdict = Self.bundle().compare(now, from: Self.pipeline)
        guard case .changed(let changes) = verdict else {
            Issue.record("expected a change, got \(verdict)")
            return
        }
        #expect(changes.count == 1)
        #expect(changes[0].annotation == AnnotationID(1))
        #expect(changes[0].was.contains("ne"))
        #expect(changes[0].now.contains("se"))
    }

    @Test("An annotation that stopped being placed at all is a change")
    func vanishedPlacementIsAChange() {
        let verdict = Self.bundle().compare(Self.answer(second: nil), from: Self.pipeline)
        guard case .changed(let changes) = verdict else {
            Issue.record("expected a change, got \(verdict)")
            return
        }
        #expect(changes.count == 1)
        #expect(changes[0].annotation == AnnotationID(2))
        #expect(changes[0].now.contains("noFeasibleCandidate"))
    }

    @Test("An annotation the recording never mentioned is a change too")
    func newAnnotationIsAChange() {
        let now =
            Self.answer()
            + [
                RecordedPlacement(
                    annotation: AnnotationID(3),
                    outcome: .placed(Placement(direction: .n, leaderLength: 28))
                )
            ]
        let verdict = Self.bundle().compare(now, from: Self.pipeline)
        guard case .changed(let changes) = verdict else {
            Issue.record("expected a change, got \(verdict)")
            return
        }
        #expect(changes.map(\.annotation) == [AnnotationID(3)])
        #expect(changes[0].was.contains("nothing"))
    }

    @Test("Changes are reported in annotation order, not in the order they were found")
    func changesAreOrdered() {
        let now = [
            RecordedPlacement(
                annotation: AnnotationID(2),
                outcome: .placed(Placement(direction: .n, leaderLength: 28))
            )
        ]
        let verdict = Self.bundle().compare(now, from: Self.pipeline)
        guard case .changed(let changes) = verdict else {
            Issue.record("expected a change, got \(verdict)")
            return
        }
        #expect(changes.map(\.annotation) == [AnnotationID(1), AnnotationID(2)])
    }

    @Test("A recording from a build that decides differently is not comparable")
    func differentPipelineIsNotComparable() {
        let moved = PipelineVersion(
            candidateGeneration: "grid-1",
            normalization: "norm-2",
            weights: "w-1",
            comparator: "cmp-1",
            renderer: "draw-1",
            visionRevision: "vision-3"
        )
        let verdict = Self.bundle().compare(
            Self.answer(first: Placement(direction: .se, leaderLength: 90)), from: moved)
        #expect(verdict == .incomparable(recorded: Self.pipeline, now: moved))
    }

    @Test("Not comparable is decided before the answers are looked at")
    func versionIsCheckedFirst() {
        let moved = Self.pipeline.with(renderer: "draw-2", visionRevision: "vision-3")
        #expect(Self.bundle().compare(Self.answer(), from: moved) != .matched)
    }

    @Test("A verdict says what it is in words somebody can act on")
    func verdictReads() {
        let changed = Self.bundle().compare(
            Self.answer(first: Placement(direction: .se, leaderLength: 90)), from: Self.pipeline)
        #expect(changed.report.contains("1"))
        #expect(!changed.isUnchanged)
        #expect(Self.bundle().compare(Self.answer(), from: Self.pipeline).isUnchanged)
    }

    @Test("A bundle comes back from JSON as what went in")
    func roundTrips() throws {
        let written = try ReplayBundle.encode(Self.bundle())
        let read = try ReplayBundle.decode(written)
        #expect(read == Self.bundle())
    }

    @Test("Writing the same bundle twice gives the same bytes")
    func writesTheSameTwice() throws {
        let first = try ReplayBundle.encode(Self.bundle())
        let second = try ReplayBundle.encode(Self.bundle())
        #expect(first == second)
    }

    @Test("A bundle from a later format is refused, and says so")
    func laterFormatIsRefused() throws {
        var text = try ReplayBundle.encode(Self.bundle())
        text = text.replacingOccurrences(
            of: "\"format\" : \(ReplayBundle.currentFormat)",
            with: "\"format\" : \(ReplayBundle.currentFormat + 1)"
        )
        #expect(throws: ReplayBundleError.self) { try ReplayBundle.decode(text) }
    }

    @Test("The written shape has no compiler-chosen names in it")
    func noSynthesisedNames() throws {
        let text = try ReplayBundle.encode(
            ReplayBundle(
                scene: Self.scene,
                pipeline: Self.pipeline,
                answer: Self.answer(second: nil)
            )
        )
        #expect(!text.contains("_0"))
        #expect(text.contains("\"placed\""))
        #expect(text.contains("\"unplaced\""))
    }

    @Test("An outcome that is neither placed nor unplaced is refused")
    func outcomeMustBeOneOrTheOther() throws {
        let text = try ReplayBundle.encode(Self.bundle())
            .replacingOccurrences(of: "\"placed\"", with: "\"sideways\"")
        #expect(throws: ReplayBundleError.self) { try ReplayBundle.decode(text) }
    }

    @Test("A bundle from this format is accepted")
    func thisFormatIsAccepted() throws {
        #expect(
            try ReplayBundle.decode(ReplayBundle.encode(Self.bundle())).format
                == ReplayBundle.currentFormat)
    }
}
