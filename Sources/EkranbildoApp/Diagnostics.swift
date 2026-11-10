import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoInspector
import EkranbildoLayout

public enum Diagnostics {
    public static func html(of scene: Scene) -> String {
        let measurer = TabulatedTextMeasurer.uniform()
        let problem = LayoutProblem(
            canvas: scene.canvas,
            style: scene.style,
            annotations: scene.annotations,
            measurer: measurer
        )
        let solution = ExactSolver().solve(problem, budget: .standard)
        return InspectorReport(measurer: measurer).html(for: problem, solution: solution)
    }
}
