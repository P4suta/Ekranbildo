import EkranbildoContracts
import EkranbildoCore
import EkranbildoField
import EkranbildoGeometry
import EkranbildoLayout
import EkranbildoObservability
import EkranbildoRender

public struct InspectorReport: Sendable {
    private let measurer: any TextMeasuring
    private let candidatesShown: Int

    public init(measurer: any TextMeasuring, candidatesShown: Int = 6) {
        self.measurer = measurer
        self.candidatesShown = candidatesShown
    }

    public func html(for problem: LayoutProblem, solution: LayoutSolution) -> String {
        let sections =
            [
                summarySection(problem, solution),
                layoutSection(problem, solution),
                fieldSection(problem),
            ]
            + problem.annotations.indices.compactMap { index in
                annotationSection(problem, solution, index: index)
            }

        return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <title>Ekranbildo layout inspector</title>
            <style>\(Self.styles)</style>
            </head>
            <body>
            <h1>Layout inspector</h1>
            \(sections.joined(separator: "\n"))
            </body>
            </html>
            """
    }

    private func summarySection(_ problem: LayoutProblem, _ solution: LayoutSolution) -> String {
        let work = solution.work
        let rows = [
            ("annotations", "\(problem.annotations.count)"),
            ("placed", "\(solution.assignments.count)"),
            ("unplaced", "\(solution.unplaced.count)"),
            ("relaxation rung", "\(solution.relaxationRung)"),
            (
                "relaxed",
                solution.trace.relaxedConstraints.isEmpty
                    ? "nothing"
                    : solution.trace.relaxedConstraints.map(\.name).joined(separator: ", ")
            ),
            ("candidatesGenerated", "\(work.candidatesGenerated)"),
            ("unaryEvaluations", "\(work.unaryEvaluations)"),
            ("pairEvaluations", "\(work.pairEvaluations)"),
            ("searchNodes", "\(work.searchNodes)"),
            ("prunedBranches", "\(work.prunedBranches)"),
        ]
        let cells =
            rows
            .map { "<tr><th>\(escaped($0.0))</th><td>\(escaped($0.1))</td></tr>" }
            .joined(separator: "\n")
        return "<section><h2>Summary</h2><table class=\"kv\">\n\(cells)\n</table></section>"
    }

    private func layoutSection(_ problem: LayoutProblem, _ solution: LayoutSolution) -> String {
        let scene = problem.scene(showing: solution.applied(to: problem.annotations))
        let drawList = DrawListBuilder(measurer: measurer).build(scene)
        let svg = SVGRenderer().render(drawList)
        return "<section><h2>Result</h2>\(svg)</section>"
    }

    private func fieldSection(_ problem: LayoutProblem) -> String {
        let field = problem.field
        var panels: [String] = [heatmap(field.cells, field: field, title: "composite")]
        for layer in FieldLayer.allCases {
            panels.append(heatmap(field.plane(layer), field: field, title: layer.rawValue))
        }
        return """
            <section><h2>Cost field</h2>
            <div class="panels">\(panels.joined(separator: "\n"))</div>
            </section>
            """
    }

    private func heatmap(_ cells: [Double], field: OccupancyField, title: String) -> String {
        var rects: [String] = []
        for row in 0..<field.rows {
            for column in 0..<field.columns {
                let value = cells[row * field.columns + column]
                guard value > 0 else { continue }
                let alpha = SVGRenderer.number(min(1, value))
                rects.append(
                    "<rect x=\"\(column)\" y=\"\(row)\" width=\"1\" height=\"1\" "
                        + "fill=\"#c0392b\" fill-opacity=\"\(alpha)\"/>"
                )
            }
        }
        let body = rects.isEmpty ? "<text x=\"1\" y=\"3\" class=\"empty\">empty</text>" : rects.joined()
        return """
            <figure>
            <figcaption>\(escaped(title))</figcaption>
            <svg viewBox="0 0 \(field.columns) \(field.rows)" class="heat">
            <rect x="0" y="0" width="\(field.columns)" height="\(field.rows)" fill="#f4f4f5"/>
            \(body)
            </svg>
            </figure>
            """
    }

    private func annotationSection(
        _ problem: LayoutProblem,
        _ solution: LayoutSolution,
        index: Int
    ) -> String {
        let annotation = problem.annotations[index]
        guard
            let decision = solution.trace.decisions.first(where: { $0.annotationID == annotation.id })
        else { return "" }

        let reason = decision.winReason.map(Self.describe) ?? "only one candidate survived"
        var shown = Array(decision.candidates.prefix(candidatesShown))
        if let winner = decision.winner, !shown.contains(where: { $0.id == winner }),
            let record = decision.candidates.first(where: { $0.id == winner })
        {
            shown.append(record)
        }

        let override =
            decision.overrodeUnaryFavourite
            ? "<p class=\"override\">The joint search chose rank "
                + "\(decision.winnerRank.map { "\($0)" } ?? "?") over this annotation's own "
                + "favourite, to fit the others.</p>"
            : ""

        let header =
            "<tr><th>#</th><th>direction</th><th>length</th>"
            + ObjectiveGroup.allCases.map { "<th>\(escaped("\($0)"))</th>" }.joined()
            + (shown.first?.terms.map { "<th>\(escaped($0.term.name))</th>" }.joined() ?? "")
            + "</tr>"

        let rows = shown.map { candidate -> String in
            let winner = candidate.id == decision.winner
            let groups = ObjectiveGroup.allCases
                .map { "<td>\(number(candidate.groupScores[$0]))</td>" }
                .joined()
            let terms = candidate.terms.map { "<td>\(number($0.value.value))</td>" }.joined()
            return """
                <tr class="\(winner ? "winner" : "")">
                <td>\(candidate.rank)\(winner ? " ★" : "")</td>
                <td>\(escaped("\(candidate.placement.direction)"))</td>
                <td>\(number(candidate.placement.leaderLength))</td>
                \(groups)\(terms)</tr>
                """
        }
        .joined(separator: "\n")

        return """
            <section>
            <h2>\(escaped(annotation.label))</h2>
            <p class="reason">\(escaped(reason)), margin \(number(decision.margin))
            &mdash; \(decision.consideredCount) candidates survived the constraints</p>
            \(override)
            <table class="candidates">\n\(header)\n\(rows)\n</table>
            </section>
            """
    }

    private static func describe(_ explanation: ComparisonExplanation) -> String {
        guard let deciding = explanation.decidingGroup else {
            return "decided by identifier: every group was too close to call"
        }
        guard !explanation.tiedGroups.isEmpty else {
            return "decided by \(deciding)"
        }
        let tied = explanation.tiedGroups.map { "\($0)" }.joined(separator: ", ")
        return "decided by \(deciding), after \(tied) came out too close to call"
    }

    private func number(_ value: Double) -> String {
        CanonicalText.rounded(value, places: ReportPrecision.places)
    }

    private func escaped(_ text: String) -> String { HTMLText.escaped(text) }

    private static let styles = """
        :root { color-scheme: light dark; }
        body { font: 13px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 24px; max-width: 1100px; }
        h1 { font-size: 20px; }
        h2 { font-size: 15px; margin-top: 28px; border-bottom: 1px solid #8884; padding-bottom: 4px; }
        table { border-collapse: collapse; font-variant-numeric: tabular-nums; }
        th, td { padding: 2px 8px; text-align: right; border-bottom: 1px solid #8882; }
        th:first-child, td:first-child, .kv th { text-align: left; }
        .kv th { font-weight: 600; width: 180px; }
        .candidates { font-size: 12px; }
        .winner { background: #2ecc7130; font-weight: 600; }
        .reason { font-size: 13px; color: #666; }
        .override { font-size: 13px; color: #b9770e; }
        .panels { display: flex; flex-wrap: wrap; gap: 12px; }
        figure { margin: 0; }
        figcaption { font-size: 11px; color: #666; margin-bottom: 2px; }
        .heat { width: 200px; height: auto; image-rendering: pixelated; border: 1px solid #8884; }
        .empty { font-size: 2px; fill: #999; }
        svg { max-width: 100%; height: auto; }
        """
}
