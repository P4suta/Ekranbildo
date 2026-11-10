import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoLayout

public struct SolvedScene: Sendable {
    public let scene: Scene
    public let problem: LayoutProblem?
    public let solution: LayoutSolution?

    public var reasons: [UnplacedReason] {
        solution?.unplaced.map {
            UnplacedReason(annotation: $0.annotationID, reason: $0.reason)
        } ?? []
    }
}

public struct SceneSolver: Sendable {
    private let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring = TabulatedTextMeasurer.uniform()) {
        self.measurer = measurer
    }

    public func solve(_ scene: Scene) -> SolvedScene {
        let unplaced = scene.annotations.filter { $0.placement == nil }
        guard !unplaced.isEmpty else {
            return SolvedScene(scene: scene, problem: nil, solution: nil)
        }

        let problem = LayoutProblem(
            canvas: scene.canvas,
            style: scene.style,
            annotations: unplaced,
            measurer: measurer
        )
        let solution = ExactSolver().solve(problem, budget: .standard)
        let solved = solution.applied(to: unplaced)

        return SolvedScene(
            scene: scene.replacing(
                annotations: scene.annotations.map { annotation in
                    solved.first { $0.id == annotation.id } ?? annotation
                }
            ),
            problem: problem,
            solution: solution
        )
    }
}
