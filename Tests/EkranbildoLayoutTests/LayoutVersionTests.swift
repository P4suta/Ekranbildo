import EkranbildoContracts
import EkranbildoLayout
import Testing

@Suite("The solver's version")
struct LayoutVersionTests {

    @Test("Every part is named")
    func everyPartIsNamed() {
        #expect(!LayoutVersion.normalization.isEmpty)
        #expect(!LayoutVersion.candidateGeneration.isEmpty)
        #expect(!LayoutVersion.comparator.isEmpty)
        #expect(!LayoutVersion.weights.isEmpty)
    }

    @Test("The parts are not each other")
    func partsAreDistinct() {
        let parts = [
            LayoutVersion.normalization,
            LayoutVersion.candidateGeneration,
            LayoutVersion.comparator,
            LayoutVersion.weights,
        ]
        #expect(Set(parts).count == parts.count)
    }

    @Test("Normalization moves when any term's calibration moves")
    func normalizationFollowsTheTerms() {
        let asIs = ScoreTerms.unary.map(\.calibrationConstants)
        var moved = asIs
        moved[0] += [CalibrationConstant(name: "somethingNew", value: 1)]
        #expect(
            LayoutVersion.fingerprint(ofTerms: ScoreTerms.unary.map(\.identifier), constants: asIs)
                != LayoutVersion.fingerprint(
                    ofTerms: ScoreTerms.unary.map(\.identifier), constants: moved)
        )
    }

    @Test("Normalization moves when a term is renamed")
    func normalizationFollowsTermNames() {
        let constants = ScoreTerms.unary.map(\.calibrationConstants)
        var names = ScoreTerms.unary.map(\.identifier)
        names[0] = TermID("renamed")
        #expect(
            LayoutVersion.fingerprint(
                ofTerms: ScoreTerms.unary.map(\.identifier), constants: constants)
                != LayoutVersion.fingerprint(ofTerms: names, constants: constants)
        )
    }

    @Test("The whole tuple is the same in every process")
    func stableAcrossProcesses() {
        #expect(
            LayoutVersion.current.canonicalText
                == "pipeline candidates=b153eb65 normalization=eb5ec88a weights=976c7bd4 "
                + "comparator=313d0fd4 renderer=- vision=-"
        )
    }

    @Test("Naming the renderer and the recogniser fills in the rest of the tuple")
    func namingTheRestFillsItIn() {
        let whole = LayoutVersion.current.with(renderer: "cg-1", visionRevision: "vision-3")
        #expect(whole.renderer == "cg-1")
        #expect(whole.visionRevision == "vision-3")
        #expect(whole.normalization == LayoutVersion.normalization)
    }
}
