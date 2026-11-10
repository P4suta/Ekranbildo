import EkranbildoObservability

enum ContactSheet {

    static func html(for entries: [CorpusEntry]) -> String {
        let cards = entries.map(card(for:)).joined(separator: "\n")
        let failures = entries.count { $0.failure != nil }
        let summary =
            "\(entries.count) scenes"
            + (failures > 0 ? ", <strong>\(failures) failed</strong>" : "")

        return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <title>Ekranbildo corpus</title>
            <style>\(styles)</style>
            </head>
            <body>
            <h1>Corpus</h1>
            <p class="summary">\(summary) &mdash; most concerning first</p>
            <div class="grid">\(cards)</div>
            </body>
            </html>
            """
    }

    private static func card(for entry: CorpusEntry) -> String {
        guard let metrics = entry.metrics else {
            return """
                <figure class="card failed">
                <figcaption>\(escaped(entry.name))</figcaption>
                <p class="failure">\(escaped(entry.failure ?? "failed"))</p>
                </figure>
                """
        }

        let flags = [
            metrics.labelCollisions > 0 ? "\(metrics.labelCollisions) label collisions" : nil,
            metrics.leaderCrossings > 0 ? "\(metrics.leaderCrossings) crossings" : nil,
            metrics.labelsOutsideCanvas > 0 ? "\(metrics.labelsOutsideCanvas) off canvas" : nil,
            metrics.labelsOverTargets > 0 ? "\(metrics.labelsOverTargets) over targets" : nil,
            metrics.unplaced > 0 ? "\(metrics.unplaced) unplaced" : nil,
            metrics.relaxationRung > 0 ? "relaxed to rung \(metrics.relaxationRung)" : nil,
        ]
        .compactMap { $0 }

        let badge =
            flags.isEmpty
            ? "<p class=\"clean\">clean</p>"
            : "<p class=\"flags\">\(escaped(flags.joined(separator: " · ")))</p>"

        let numbers = [
            (
                "worst ambiguity",
                CanonicalText.rounded(metrics.worstPointingAmbiguity, places: ReportPrecision.places)
            ),
            (
                "mean clearance",
                CanonicalText.rounded(metrics.meanLabelClearance, places: ReportPrecision.places)
            ),
            (
                "min margin",
                CanonicalText.rounded(metrics.minimumDecisionMargin, places: ReportPrecision.marginPlaces)
            ),
            ("axis-aligned", "\(metrics.axisAlignedLeaders)/\(metrics.placed)"),
        ]
        .map { "<tr><th>\(escaped($0.0))</th><td>\(escaped($0.1))</td></tr>" }
        .joined()

        return """
            <figure class="card">
            <figcaption>\(escaped(entry.name))</figcaption>
            <div class="thumb">\(entry.thumbnail ?? "")</div>
            \(badge)
            <table>\(numbers)</table>
            </figure>
            """
    }

    private static func escaped(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    private static let styles = """
        :root { color-scheme: light dark; }
        body { font: 13px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 24px; }
        h1 { font-size: 20px; }
        .summary { color: #666; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 16px; }
        .card { margin: 0; border: 1px solid #8884; border-radius: 6px; padding: 10px; }
        .card.failed { border-color: #c0392b; }
        figcaption { font-weight: 600; margin-bottom: 6px; }
        .thumb svg { width: 100%; height: auto; background: #fafafa; border: 1px solid #8882; }
        .flags { color: #c0392b; font-size: 12px; margin: 6px 0 4px; }
        .clean { color: #27ae60; font-size: 12px; margin: 6px 0 4px; }
        .failure { color: #c0392b; font-size: 12px; }
        table { border-collapse: collapse; width: 100%; font-size: 11px;
                font-variant-numeric: tabular-nums; }
        th { text-align: left; font-weight: 400; color: #666; }
        td { text-align: right; }
        """
}
