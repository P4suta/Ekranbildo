import EkranbildoGeometry
import EkranbildoLayout
import EkranbildoObservability

public enum Verdict: String, Hashable, Sendable, Codable {
    case first
    case second
    case noDifference
}

public struct Judgement: Hashable, Sendable, Codable {
    public let scene: String
    public let first: CandidateID
    public let second: CandidateID
    public let verdict: Verdict

    public init(scene: String, first: CandidateID, second: CandidateID, verdict: Verdict) {
        self.scene = scene
        self.first = first
        self.second = second
        self.verdict = verdict
    }

    public var preferred: CandidateID? {
        switch verdict {
        case .first: first
        case .second: second
        case .noDifference: nil
        }
    }
}

public struct PreferenceReport: Sendable {
    public let agreement: Double
    public let judged: Int
    public let unanswered: Int
    public let disagreements: [String]

    public let toleranceAgreement: Double
    public let toleranceJudged: Int

    public init(
        judgements: [Judgement],
        chosen: Lookup<String, CandidateID>,
        tolerance: Double,
        margins: Lookup<String, Double> = Lookup()
    ) {
        var agreed = 0
        var counted = 0
        var missing = 0
        var wrong: [String] = []

        for judgement in judgements {
            guard let picked = chosen[judgement.scene] else {
                missing += 1
                continue
            }
            counted += 1

            guard let preferred = judgement.preferred else {
                agreed += 1
                continue
            }
            if picked == preferred {
                agreed += 1
            } else {
                wrong.append(judgement.scene)
            }
        }

        var toleranceAgreed = 0
        var toleranceCounted = 0
        for judgement in judgements {
            guard let margin = margins[judgement.scene] else { continue }
            toleranceCounted += 1
            let solverSawNoDifference = margin <= tolerance
            let personSawNoDifference = judgement.verdict == .noDifference
            if solverSawNoDifference == personSawNoDifference { toleranceAgreed += 1 }
        }

        judged = counted
        unanswered = missing
        agreement = counted > 0 ? Double(agreed) / Double(counted) : 0
        toleranceJudged = toleranceCounted
        toleranceAgreement =
            toleranceCounted > 0 ? Double(toleranceAgreed) / Double(toleranceCounted) : 0
        disagreements = wrong.sorted()
    }

    public var summary: String {
        var lines = [
            "judged \(judged)",
            "agreement \(CanonicalText.rounded(agreement, places: Precision.places))",
            "unanswered \(unanswered)",
        ]
        if toleranceJudged > 0 {
            lines.append(
                "tolerance agreement "
                    + CanonicalText.rounded(toleranceAgreement, places: Precision.places)
                    + " over \(toleranceJudged)"
            )
        }
        if disagreements.isEmpty {
            lines.append("no disagreements")
        } else {
            lines.append(contentsOf: disagreements.map { "disagreed \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    private enum Precision {
        static let places = 2
    }
}
