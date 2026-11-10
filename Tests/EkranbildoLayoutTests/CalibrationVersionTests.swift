import EkranbildoLayout
import Testing

@Suite("Calibration versions")
struct CalibrationVersionTests {

    @Test("Moving an anchor moves the version")
    func movingAnAnchorMovesTheVersion() {
        let before = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0.0), Calibration.Anchor(raw: 0.5, badness: 1.0),
        ])
        let after = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0.0), Calibration.Anchor(raw: 0.6, badness: 1.0),
        ])
        #expect(
            CalibrationFingerprint.of(before.constants)
                != CalibrationFingerprint.of(after.constants)
        )
    }

    @Test("Adding an anchor moves the version")
    func addingAnAnchorMovesTheVersion() {
        let before = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0.0), Calibration.Anchor(raw: 1, badness: 1.0),
        ])
        let after = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0.0), Calibration.Anchor(raw: 0.5, badness: 0.5),
            Calibration.Anchor(raw: 1, badness: 1.0),
        ])
        #expect(
            CalibrationFingerprint.of(before.constants)
                != CalibrationFingerprint.of(after.constants)
        )
    }

    @Test("Renaming a constant moves the version")
    func renamingMovesTheVersion() {
        let before = [CalibrationConstant(name: "preferred", value: 64)]
        let after = [CalibrationConstant(name: "ideal", value: 64)]
        #expect(CalibrationFingerprint.of(before) != CalibrationFingerprint.of(after))
    }

    @Test("The version is the same in every process")
    func stableAcrossProcesses() {
        let constants = [
            CalibrationConstant(name: "clearSpace", value: 0),
            CalibrationConstant(name: "halfCovered", value: 0.5),
        ]
        #expect(CalibrationFingerprint.of(constants) == "d57bab4c")
    }

    @Test("Every unary term declares the numbers its mapping depends on")
    func everyUnaryTermDeclaresItsConstants() {
        for term in ScoreTerms.unary {
            #expect(
                !term.calibrationConstants.isEmpty,
                Comment(rawValue: "\(term.identifier) declares none")
            )
        }
    }

    @Test("Every pair term declares the numbers its mapping depends on")
    func everyPairTermDeclaresItsConstants() {
        for term in ScoreTerms.pair {
            #expect(
                !term.calibrationConstants.isEmpty,
                Comment(rawValue: "\(term.identifier) declares none")
            )
        }
    }

    @Test("Terms with different mappings have different versions")
    func differentMappingsDifferentVersions() {
        let versions = ScoreTerms.unary.map(\.calibrationVersion)
        let constants = ScoreTerms.unary.map(\.calibrationConstants)
        for first in 0..<versions.count {
            for second in (first + 1)..<versions.count where constants[first] != constants[second] {
                let names =
                    "\(ScoreTerms.unary[first].identifier) and "
                    + "\(ScoreTerms.unary[second].identifier)"
                #expect(
                    versions[first] != versions[second],
                    Comment(rawValue: "\(names) share a version")
                )
            }
        }
    }
}
