public enum TraceSynthesis {

    public static func applied(
        to text: String,
        replacing: (String) -> String = Self.sameLength
    ) -> String {
        var output = ""
        output.reserveCapacity(text.count)

        var index = text.startIndex
        while index < text.endIndex {
            guard text[index] == Mark.tilde,
                let quote = text.index(index, offsetBy: 1, limitedBy: text.endIndex),
                quote < text.endIndex, text[quote] == Mark.quote
            else {
                output.append(text[index])
                index = text.index(after: index)
                continue
            }

            let body = text.index(after: quote)
            guard let end = closingQuote(in: text[body...]) else {
                output += text[index...]
                return output
            }
            let borrowed = CanonicalText.unescaped(String(text[body..<end]))
            output += "\(Mark.tilde)\(Mark.quote)\(CanonicalText.escaped(replacing(borrowed)))\(Mark.quote)"
            index = text.index(after: end)
        }
        return output
    }

    public static func sameLength(_ text: String) -> String {
        String(repeating: Mark.standIn, count: text.count)
    }

    private static func closingQuote(in body: Substring) -> String.Index? {
        var index = body.startIndex
        var escaped = false
        while index < body.endIndex {
            let character = body[index]
            if escaped {
                escaped = false
            } else if character == Mark.escape {
                escaped = true
            } else if character == Mark.quote {
                return index
            }
            index = body.index(after: index)
        }
        return nil
    }

    private enum Mark {
        static let tilde: Character = "~"
        static let quote: Character = "\""
        static let escape: Character = "\\"
        static let standIn: Character = "x"
    }
}
