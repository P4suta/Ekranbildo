public enum CanonicalText {

    public static func double(_ value: Double) -> String {
        if value.isNaN { return "nan" }
        if value == .infinity { return "inf" }
        if value == -.infinity { return "-inf" }
        if value == 0 { return "0.0" }
        return String(value)
    }

    public static func rounded(_ value: Double, places: Int) -> String {
        if value.isNaN { return "nan" }
        if value == .infinity { return "inf" }
        if value == -.infinity { return "-inf" }

        let decimalBase = 10.0
        var scale = 1.0
        for _ in 0..<places { scale *= decimalBase }
        let scaled = (value * scale).rounded()
        let quantised = scaled / scale
        if quantised == 0 { return zeroText(places: places) }

        let negative = quantised < 0
        let magnitude = negative ? -scaled : scaled
        var digits = String(Int64(magnitude))
        while digits.count <= places {
            digits = "0" + digits
        }
        let split = digits.index(digits.endIndex, offsetBy: -places)
        let whole = String(digits[digits.startIndex..<split])
        let fraction = String(digits[split...])
        let sign = negative ? "-" : ""
        return places == 0 ? sign + whole : "\(sign)\(whole).\(fraction)"
    }

    private static func zeroText(places: Int) -> String {
        places == 0 ? "0" : "0." + String(repeating: "0", count: places)
    }

    public static func escaped(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\t": escaped += "\\t"
            case "\r": escaped += "\\r"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    public static func unescaped(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var escaping = false
        for character in text {
            guard escaping else {
                if character == "\\" {
                    escaping = true
                } else {
                    result.append(character)
                }
                continue
            }
            escaping = false
            switch character {
            case "n": result.append("\n")
            case "t": result.append("\t")
            case "r": result.append("\r")
            default: result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    public static func quoted(_ text: String) -> String { "\"\(escaped(text))\"" }
}
