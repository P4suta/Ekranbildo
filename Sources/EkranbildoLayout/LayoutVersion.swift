import EkranbildoContracts
import EkranbildoGeometry

public enum LayoutVersion {

    public static let normalization: String = fingerprint(
        ofTerms: ScoreTerms.unary.map(\.identifier) + ScoreTerms.pair.map(\.identifier),
        constants: ScoreTerms.unary.map(\.calibrationConstants)
            + ScoreTerms.pair.map(\.calibrationConstants)
    )

    public static let candidateGeneration: String = CalibrationFingerprint.of(
        [CalibrationConstant(name: "directions", value: Double(Direction16.allCases.count))]
            + GridCandidateGenerator.Defaults.leaderLengths.enumerated().map { index, length in
                CalibrationConstant(name: "leaderLength\(index)", value: length)
            }
    )

    public static let comparator: String = CalibrationFingerprint.of(
        ObjectiveGroup.allCases.map { group in
            CalibrationConstant(name: "tolerance.\(group)", value: GroupTolerances.standard[group])
        }
    )

    public static let weights: String = CalibrationFingerprint.of(
        (ScoreTerms.unary.map { ($0.identifier, $0.group) }
            + ScoreTerms.pair.map { ($0.identifier, $0.group) })
            .map { CalibrationConstant(name: "\($0.0)", value: Double($0.1.rawValue)) }
    )

    public static let current = PipelineVersion(
        candidateGeneration: candidateGeneration,
        normalization: normalization,
        weights: weights,
        comparator: comparator,
        renderer: PipelineVersion.unnamed,
        visionRevision: PipelineVersion.unnamed
    )

    public static func fingerprint(
        ofTerms terms: [TermID],
        constants: [[CalibrationConstant]]
    ) -> String {
        CalibrationFingerprint.of(
            zip(terms, constants).flatMap { term, constants in
                [CalibrationConstant(name: "term", value: Double(term.name.count))]
                    + constants.map {
                        CalibrationConstant(name: "\(term.name).\($0.name)", value: $0.value)
                    }
            }
        )
    }
}
