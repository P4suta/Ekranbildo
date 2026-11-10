public enum PseudoLocalisation {

    public static func of(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var accented = ""
        accented.reserveCapacity(text.count)
        for character in text {
            accented.append(Self.lookalikes[character] ?? character)
        }

        let wanted = max(
            text.count + Padding.shortest,
            Int((Double(text.count) * Padding.expansion).rounded(.up))
        )
        let padding = String(repeating: Padding.filler, count: max(0, wanted - text.count))

        return "[\(accented)\(padding)]"
    }

    private enum Padding {
        static let expansion: Double = 1.4
        static let shortest = 3
        static let filler: Character = "·"
    }

    private static let lookalikes: [Character: Character] = [
        "a": "à", "b": "ƀ", "c": "ç", "d": "ð", "e": "é", "f": "ƒ", "g": "ğ",
        "h": "ĥ", "i": "ï", "j": "ĵ", "k": "ķ", "l": "ł", "m": "ɱ", "n": "ñ",
        "o": "ø", "p": "þ", "q": "ɋ", "r": "ŕ", "s": "š", "t": "ţ", "u": "ü",
        "v": "ṽ", "w": "ŵ", "x": "ẋ", "y": "ý", "z": "ž",
        "A": "À", "B": "Ɓ", "C": "Ç", "D": "Ð", "E": "É", "F": "Ƒ", "G": "Ğ",
        "H": "Ĥ", "I": "Ï", "J": "Ĵ", "K": "Ķ", "L": "Ł", "M": "Ṁ", "N": "Ñ",
        "O": "Ø", "P": "Þ", "Q": "Ɋ", "R": "Ŕ", "S": "Š", "T": "Ţ", "U": "Ü",
        "V": "Ṽ", "W": "Ŵ", "X": "Ẋ", "Y": "Ý", "Z": "Ž",
    ]
}
