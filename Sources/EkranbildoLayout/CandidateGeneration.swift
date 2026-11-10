import EkranbildoCore
import EkranbildoGeometry

public protocol CandidateGenerating: Sendable {
    var version: String { get }

    func generate(forAnnotationAt index: Int, in problem: LayoutProblem) -> [LayoutCandidate]
}

public struct GridCandidateGenerator: CandidateGenerating {
    public let directions: [Direction16]
    public let leaderLengths: [Double]

    public var version: String { "grid-1" }

    public init(
        directions: [Direction16] = Direction16.allCases,
        leaderLengths: [Double] = Defaults.leaderLengths
    ) {
        self.directions = directions
        self.leaderLengths = leaderLengths
    }

    public func generate(forAnnotationAt index: Int, in problem: LayoutProblem) -> [LayoutCandidate] {
        guard problem.annotations.indices.contains(index) else { return [] }
        let annotation = problem.annotations[index]

        if annotation.isPinned, let chosen = annotation.placement {
            return [Self.candidate(chosen, at: index, offset: 0, in: problem)]
        }

        var candidates: [LayoutCandidate] = []
        candidates.reserveCapacity(directions.count * leaderLengths.count)

        var offset = 0
        for direction in directions {
            for length in leaderLengths {
                candidates.append(
                    Self.candidate(
                        Placement(direction: direction, leaderLength: length),
                        at: index,
                        offset: offset,
                        in: problem
                    )
                )
                offset += 1
            }
        }
        return candidates
    }

    static func candidate(
        _ placement: Placement,
        at index: Int,
        offset: Int,
        in problem: LayoutProblem
    ) -> LayoutCandidate {
        let annotation = problem.annotations[index]
        let textSize = problem.textSizes[index]
        let resolved = ResolvedPlacement(
            target: annotation.target,
            placement: placement,
            style: problem.style
        )
        return LayoutCandidate(
            id: Self.identifier(annotationIndex: index, offset: offset),
            annotationID: annotation.id,
            annotationIndex: index,
            placement: placement,
            tip: resolved.tip,
            tail: resolved.tail,
            labelRect: resolved.labelBox(textSize: textSize, style: problem.style)
        )
    }

    static func identifier(annotationIndex: Int, offset: Int) -> CandidateID {
        CandidateID(UInt32(annotationIndex) &* Defaults.identifierStride &+ UInt32(offset))
    }

    public enum Defaults {
        public static let leaderLengths: [Double] = [28, 44, 64, 90, 124]

        static let identifierStride: UInt32 = 10_000
    }
}
