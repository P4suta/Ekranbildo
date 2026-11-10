import Foundation

public enum ColorVision: String, Hashable, Sendable, Codable, CaseIterable {
    case typical
    case protanopia
    case deuteranopia
    case tritanopia
}

extension Color {
    public func seen(with vision: ColorVision) -> Self {
        guard vision != .typical else { return self }

        let linear = Light(
            red: Transfer.toLinear(red),
            green: Transfer.toLinear(green),
            blue: Transfer.toLinear(blue)
        )

        let cones = Cones.from(linear)
        let adjusted = Cones.without(vision.missingCone, cones)
        let back = Cones.toLinear(adjusted)

        return Self(
            red: Transfer.fromLinear(back.red),
            green: Transfer.fromLinear(back.green),
            blue: Transfer.fromLinear(back.blue),
            alpha: alpha
        )
    }
}

extension ColorVision {
    fileprivate var missingCone: Cones.Kind {
        switch self {
        case .typical, .protanopia: .long
        case .deuteranopia: .middle
        case .tritanopia: .short
        }
    }
}

private struct Light {
    let red: Double
    let green: Double
    let blue: Double
}

private enum Cones {
    enum Kind { case long, middle, short }

    struct Response {
        let long: Double
        let middle: Double
        let short: Double
    }

    struct Row {
        let red: Double
        let green: Double
        let blue: Double

        func applied(_ light: Light) -> Double {
            red * light.red + green * light.green + blue * light.blue
        }

        func applied(_ response: Response) -> Double {
            red * response.long + green * response.middle + blue * response.short
        }
    }

    enum Hunt {
        static let toResponse = (
            long: Row(red: 17.882_4, green: 43.516_1, blue: 4.119_35),
            middle: Row(red: 3.455_65, green: 27.155_4, blue: 3.867_14),
            short: Row(red: 0.029_956_6, green: 0.184_309, blue: 1.467_09)
        )

        static let toLight = (
            red: Row(red: 0.080_944_45, green: -0.130_504_41, blue: 0.116_721_07),
            green: Row(red: -0.010_248_53, green: 0.054_019_33, blue: -0.113_614_71),
            blue: Row(red: -0.000_365_30, green: -0.004_121_61, blue: 0.693_511_40)
        )
    }

    enum Brettel {
        static let long = Row(red: 0, green: 2.023_44, blue: -2.525_81)
        static let middle = Row(red: 0.494_207, green: 0, blue: 1.248_27)
        static let short = Row(red: -0.395_913, green: 0.801_109, blue: 0)
    }

    static func from(_ linear: Light) -> Response {
        Response(
            long: Hunt.toResponse.long.applied(linear),
            middle: Hunt.toResponse.middle.applied(linear),
            short: Hunt.toResponse.short.applied(linear)
        )
    }

    static func toLinear(_ response: Response) -> Light {
        Light(
            red: Hunt.toLight.red.applied(response),
            green: Hunt.toLight.green.applied(response),
            blue: Hunt.toLight.blue.applied(response)
        )
    }

    static func without(_ missing: Kind, _ response: Response) -> Response {
        switch missing {
        case .long:
            return Response(
                long: atLeastNothing(Brettel.long.applied(response)),
                middle: response.middle,
                short: response.short
            )
        case .middle:
            return Response(
                long: response.long,
                middle: atLeastNothing(Brettel.middle.applied(response)),
                short: response.short
            )
        case .short:
            return Response(
                long: response.long,
                middle: response.middle,
                short: atLeastNothing(Brettel.short.applied(response))
            )
        }
    }

    static func atLeastNothing(_ response: Double) -> Double { max(0, response) }
}

private enum Transfer {
    static func toLinear(_ channel: Double) -> Double {
        channel <= Curve.kink
            ? channel / Curve.slope
            : pow((channel + Curve.offset) / (1 + Curve.offset), Curve.gamma)
    }

    static func fromLinear(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped <= Curve.linearKink
            ? clamped * Curve.slope
            : (1 + Curve.offset) * pow(clamped, 1 / Curve.gamma) - Curve.offset
    }

    private enum Curve {
        static let kink = 0.040_45
        static let linearKink = 0.003_130_8
        static let slope = 12.92
        static let offset = 0.055
        static let gamma = 2.4
    }
}
