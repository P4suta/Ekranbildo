import EkranbildoContracts
import EkranbildoCore
import EkranbildoLayout
import EkranbildoRender
import Foundation

public struct CorpusScene: Sendable {
    public let name: String
    public let json: String

    public init(name: String, json: String) {
        self.name = name
        self.json = json
    }
}

public struct CorpusEntry: Sendable {
    public let name: String
    public let metrics: QualityMetrics?
    public let failure: String?
    public let concern: Double
    public let thumbnail: String?
}

public struct CorpusReport: Sendable {
    public let entries: [CorpusEntry]

    public var failureCount: Int { entries.count { $0.failure != nil } }

    public var scoreboard: String {
        entries
            .sorted { $0.name < $1.name }
            .flatMap { entry -> [String] in
                guard let metrics = entry.metrics else {
                    return ["\(entry.name) failed \(entry.failure ?? "unknown")"]
                }
                return metrics.canonicalText
                    .split(separator: "\n")
                    .map { "\(entry.name) \($0)" }
            }
            .joined(separator: "\n")
    }

    public var html: String { ContactSheet.html(for: entries) }
}

public struct CorpusRunner: Sendable {
    private let measurer: any TextMeasuring
    private let budget: SolverBudget

    public init(measurer: any TextMeasuring, budget: SolverBudget = .standard) {
        self.measurer = measurer
        self.budget = budget
    }

    public func run(_ scenes: [CorpusScene]) -> CorpusReport {
        let entries = scenes.map(entry(for:))
        return CorpusReport(
            entries: entries.sorted {
                $0.concern == $1.concern ? $0.name < $1.name : $0.concern > $1.concern
            }
        )
    }

    private func entry(for corpusScene: CorpusScene) -> CorpusEntry {
        let scene: Scene
        do {
            scene = try JSONDecoder().decode(Scene.self, from: Data(corpusScene.json.utf8))
        } catch {
            return CorpusEntry(
                name: corpusScene.name,
                metrics: nil,
                failure: "could not decode: \(error)",
                concern: .infinity,
                thumbnail: nil
            )
        }

        let problem = LayoutProblem(
            canvas: scene.canvas,
            style: scene.style,
            annotations: scene.annotations,
            measurer: measurer
        )
        let solution = ExactSolver().solve(problem, budget: budget)
        let metrics = QualityMetrics(of: solution, in: problem)

        let solved = scene.replacing(
            annotations: solution.applied(to: scene.annotations),
            background: .some(nil)
        )
        let drawList = DrawListBuilder(measurer: measurer).build(solved)

        return CorpusEntry(
            name: corpusScene.name,
            metrics: metrics,
            failure: nil,
            concern: Self.concern(of: metrics),
            thumbnail: SVGRenderer().render(drawList)
        )
    }

    static func concern(of metrics: QualityMetrics) -> Double {
        let violations =
            metrics.labelCollisions + metrics.leaderCrossings
            + metrics.labelsOutsideCanvas + metrics.labelsOverTargets
        var score = Double(violations) * Weights.defect
        score += Double(metrics.unplaced) * Weights.unplaced
        score += Double(metrics.relaxationRung) * Weights.relaxedRung
        score += metrics.worstPointingAmbiguity * Weights.ambiguity
        score += Double(metrics.axisAlignedLeaders) * Weights.axisAligned
        score += metrics.minimumDecisionMargin < Weights.fragileMargin ? Weights.fragile : 0
        return score
    }

    enum Weights {
        static let defect: Double = 1_000
        static let unplaced: Double = 500
        static let relaxedRung: Double = 100
        static let ambiguity: Double = 10
        static let axisAligned: Double = 1
        static let fragile: Double = 0.5
        static let fragileMargin: Double = 1e-6
    }
}
