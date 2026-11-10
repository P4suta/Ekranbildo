import EkranbildoObservability

public struct FlagScanner: Sendable {
    public let positional: [String]
    private let flags: [(name: String, value: String)]

    public func value(of name: String) -> String? {
        flags.last { $0.name == name }?.value
    }

    public func values(of name: String) -> [String] {
        flags.filter { $0.name == name }.map(\.value)
    }

    public static func scan(_ arguments: [String], knownFlags: [String]) throws -> Self {
        var positional: [String] = []
        var flags: [(name: String, value: String)] = []
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix(Syntax.flagPrefix) else {
                positional.append(argument)
                index += 1
                continue
            }
            guard knownFlags.contains(argument) else {
                throw CommandError(
                    code: CommandError.unknownFlag,
                    detail: "unknown flag '\(argument)'"
                )
            }
            guard index + 1 < arguments.count else {
                throw CommandError(
                    code: CommandError.missingValue,
                    detail: "'\(argument)' needs a value"
                )
            }
            flags.append((argument, arguments[index + 1]))
            index += Syntax.flagAndValue
        }

        return Self(positional: positional, flags: flags)
    }

    private enum Syntax {
        static let flagPrefix = "--"
        static let flagAndValue = 2
    }
}
