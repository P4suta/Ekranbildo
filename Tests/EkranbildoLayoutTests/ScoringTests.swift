import EkranbildoGeometry
@testable import EkranbildoLayout
import Testing

@Suite("Normalized")
struct NormalizedTests {

    @Test("Values are clamped into range")
    func clamping() {
        #expect(Normalized(-1).value == 0)
        #expect(Normalized(2).value == 1)
        #expect(Normalized(0.25).value == 0.25)
    }

    @Test("A value that is not a number counts as the worst case")
    func notANumber() {
        #expect(Normalized(.nan).value == 1)
    }

    @Test("Zero is best and one is worst")
    func ordering() {
        #expect(Normalized.best < Normalized.worst)
        #expect(Normalized.best.value == 0)
        #expect(Normalized.worst.value == 1)
    }

    @Test("A piecewise calibration maps raw measurements onto the scale")
    func calibration() {
        let calibration = Calibration(anchors: [
            Calibration.Anchor(raw: 7, badness: 0), Calibration.Anchor(raw: 4.5, badness: 0.5),
            Calibration.Anchor(raw: 1, badness: 1),
        ])
        #expect(calibration.normalize(7).value == 0)
        #expect(calibration.normalize(4.5).value == 0.5)
        #expect(calibration.normalize(1).value == 1)
    }

    @Test("Calibration interpolates between anchors")
    func calibrationInterpolates() {
        let calibration = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0), Calibration.Anchor(raw: 10, badness: 1),
        ])
        #expect(approximatelyEqual(calibration.normalize(5).value, 0.5))
        #expect(approximatelyEqual(calibration.normalize(2.5).value, 0.25))
    }

    @Test("Calibration clamps rather than extrapolating")
    func calibrationClamps() {
        let calibration = Calibration(anchors: [
            Calibration.Anchor(raw: 0, badness: 0), Calibration.Anchor(raw: 10, badness: 1),
        ])
        #expect(calibration.normalize(-100).value == 0)
        #expect(calibration.normalize(1_000).value == 1)
    }

    @Test("Calibration works with descending anchors")
    func descendingAnchors() {
        let calibration = Calibration(anchors: [
            Calibration.Anchor(raw: 100, badness: 0), Calibration.Anchor(raw: 0, badness: 1),
        ])
        #expect(calibration.normalize(100).value == 0)
        #expect(calibration.normalize(0).value == 1)
        #expect(approximatelyEqual(calibration.normalize(50).value, 0.5))
    }
}

@Suite("Objective groups")
struct ObjectiveGroupTests {

    @Test("Groups are ordered from most to least important")
    func ordering() {
        #expect(ObjectiveGroup.readability < ObjectiveGroup.targetClarity)
        #expect(ObjectiveGroup.targetClarity < ObjectiveGroup.clearance)
        #expect(ObjectiveGroup.clearance < ObjectiveGroup.consistency)
        #expect(ObjectiveGroup.consistency < ObjectiveGroup.aesthetics)
    }

    @Test("Every group has a tolerance")
    func tolerances() {
        let tolerances = GroupTolerances.standard
        for group in ObjectiveGroup.allCases {
            #expect(tolerances[group] >= 0)
        }
    }
}

@Suite("Lexicographic comparison")
struct LexicographicComparisonTests {
    private let comparator = LexicographicComparator(tolerances: GroupTolerances.standard)

    private func scores(_ values: [Double]) -> GroupScores {
        var scores = GroupScores()
        for (index, value) in values.enumerated() {
            scores[ObjectiveGroup.allCases[index]] = value
        }
        return scores
    }

    @Test("A clear win in the first group settles it")
    func firstGroupDecides() {
        let better = scores([0.1, 0.9, 0.9, 0.9, 0.9])
        let worse = scores([0.8, 0.0, 0.0, 0.0, 0.0])
        #expect(
            comparator.compare(better, worse, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
                == .orderedAscending
        )
    }

    @Test("A difference within tolerance passes the decision down")
    func toleranceDefersToTheNextGroup() {
        let tolerances = GroupTolerances(values: [0.1, 0, 0, 0, 0])
        let comparator = LexicographicComparator(tolerances: tolerances)
        let first = scores([0.50, 0.9, 0, 0, 0])
        let second = scores([0.55, 0.1, 0, 0, 0])
        #expect(
            comparator.compare(first, second, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
                == .orderedDescending)
    }

    @Test("A difference outside tolerance decides immediately")
    func outsideToleranceDecides() {
        let tolerances = GroupTolerances(values: [0.1, 0, 0, 0, 0])
        let comparator = LexicographicComparator(tolerances: tolerances)
        let first = scores([0.30, 0.9, 0, 0, 0])
        let second = scores([0.55, 0.1, 0, 0, 0])
        #expect(
            comparator.compare(first, second, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
                == .orderedAscending
        )
    }

    @Test("A complete tie falls back to the identifier")
    func tieBreaksByIdentifier() {
        let equal = scores([0.5, 0.5, 0.5, 0.5, 0.5])
        #expect(
            comparator.compare(equal, equal, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
                == .orderedAscending)
        #expect(
            comparator.compare(equal, equal, tieBreak: TieBreak(CandidateID(2), CandidateID(1)))
                == .orderedDescending
        )
        #expect(
            comparator.compare(equal, equal, tieBreak: TieBreak(CandidateID(3), CandidateID(3)))
                == .orderedSame)
    }

    @Test("Comparison is antisymmetric")
    func antisymmetric() {
        var generator = SplitMix64(seed: 808)
        func randomScores() -> GroupScores {
            scores((0..<5).map { _ in Double(generator.next() % 1_000) / 1_000 })
        }
        for index in 0..<300 {
            let first = randomScores()
            let second = randomScores()
            let ids = TieBreak(
                CandidateID(UInt32(index * 2)), CandidateID(UInt32(index * 2 + 1)))
            let forward = comparator.compare(first, second, tieBreak: ids)
            let backward = comparator.compare(
                second, first, tieBreak: TieBreak(ids.second, ids.first))
            switch forward {
            case .orderedAscending: #expect(backward == .orderedDescending)
            case .orderedDescending: #expect(backward == .orderedAscending)
            case .orderedSame: #expect(backward == .orderedSame)
            }
        }
    }

    @Test("Comparison is transitive")
    func transitive() {
        var generator = SplitMix64(seed: 31_337)
        func randomScores() -> GroupScores {
            scores((0..<5).map { _ in Double(generator.next() % 20) / 100 })
        }

        var identifier: UInt32 = 0
        func nextID() -> CandidateID {
            identifier += 1
            return CandidateID(identifier)
        }

        for _ in 0..<2_000 {
            let (a, b, c) = (randomScores(), randomScores(), randomScores())
            let (idA, idB, idC) = (nextID(), nextID(), nextID())

            let abBeats = comparator.compare(a, b, tieBreak: TieBreak(idA, idB)) == .orderedAscending
            let bcBeats = comparator.compare(b, c, tieBreak: TieBreak(idB, idC)) == .orderedAscending
            guard abBeats, bcBeats else { continue }

            #expect(
                comparator.compare(a, c, tieBreak: TieBreak(idA, idC)) == .orderedAscending,
                "a beat b and b beat c, but c beat a"
            )
        }
    }

    @Test("The comparison says which group decided")
    func explanation() {
        let tolerances = GroupTolerances(values: [0.1, 0, 0, 0, 0])
        let comparator = LexicographicComparator(tolerances: tolerances)
        let first = scores([0.50, 0.9, 0, 0, 0])
        let second = scores([0.55, 0.1, 0, 0, 0])
        let explained = comparator.explain(first, second, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
        #expect(explained.decidingGroup == .targetClarity)
        #expect(explained.tiedGroups == [.readability])
    }

    @Test("A tie in every group is explained as such")
    func explainedTie() {
        let equal = scores([0.5, 0.5, 0.5, 0.5, 0.5])
        let explained = comparator.explain(equal, equal, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
        #expect(explained.decidingGroup == nil)
        #expect(explained.tiedGroups == ObjectiveGroup.allCases)
    }
}
