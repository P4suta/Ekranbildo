public enum LineDiff {

    private static let contextLines = 3

    public static func unified(expected: String, actual: String) -> String? {
        let before = expected.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let after = actual.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if before == after { return nil }

        let script = editScript(before, after)
        return render(script, before: before, after: after)
    }

    enum Edit: Equatable {
        case keep(beforeIndex: Int, afterIndex: Int)
        case remove(beforeIndex: Int)
        case insert(afterIndex: Int)
    }

    static func editScript(_ before: [String], _ after: [String]) -> [Edit] {
        let rows = before.count
        let columns = after.count
        var lengths = [[Int]](repeating: [Int](repeating: 0, count: columns + 1), count: rows + 1)

        for row in stride(from: rows - 1, through: 0, by: -1) {
            for column in stride(from: columns - 1, through: 0, by: -1) {
                lengths[row][column] =
                    before[row] == after[column]
                    ? lengths[row + 1][column + 1] + 1
                    : max(lengths[row + 1][column], lengths[row][column + 1])
            }
        }

        var script: [Edit] = []
        var row = 0
        var column = 0
        while row < rows && column < columns {
            if before[row] == after[column] {
                script.append(.keep(beforeIndex: row, afterIndex: column))
                row += 1
                column += 1
            } else if lengths[row + 1][column] >= lengths[row][column + 1] {
                script.append(.remove(beforeIndex: row))
                row += 1
            } else {
                script.append(.insert(afterIndex: column))
                column += 1
            }
        }
        while row < rows {
            script.append(.remove(beforeIndex: row))
            row += 1
        }
        while column < columns {
            script.append(.insert(afterIndex: column))
            column += 1
        }
        return script
    }

    private static func render(_ script: [Edit], before: [String], after: [String]) -> String {
        var interesting = [Bool](repeating: false, count: script.count)
        for (index, edit) in script.enumerated() where edit != .keep(beforeIndex: -1, afterIndex: -1) {
            guard case .keep = edit else {
                let lower = max(0, index - contextLines)
                let upper = min(script.count - 1, index + contextLines)
                for nearby in lower...upper { interesting[nearby] = true }
                continue
            }
        }

        var lines: [String] = []
        var elided = false
        for (index, edit) in script.enumerated() {
            guard interesting[index] else {
                if !elided {
                    lines.append("@@ ...")
                    elided = true
                }
                continue
            }
            elided = false
            switch edit {
            case .keep(let beforeIndex, _):
                lines.append(" \(before[beforeIndex])")
            case .remove(let beforeIndex):
                lines.append("-\(before[beforeIndex])")
            case .insert(let afterIndex):
                lines.append("+\(after[afterIndex])")
            }
        }
        return lines.joined(separator: "\n")
    }
}
