import Foundation

extension Color {
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= Luminance.kink
                ? channel / Luminance.slope
                : pow((channel + Luminance.offset) / (1 + Luminance.offset), Luminance.gamma)
        }
        return Luminance.red * linear(red)
            + Luminance.green * linear(green)
            + Luminance.blue * linear(blue)
    }

    public func contrastRatio(against other: Self) -> Double {
        let first = relativeLuminance
        let second = other.relativeLuminance
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + Contrast.offset) / (darker + Contrast.offset)
    }

    public func composited(over background: Self) -> Self {
        guard alpha < 1 else { return self }
        func mix(_ front: Double, _ back: Double) -> Double {
            front * alpha + back * (1 - alpha)
        }
        return Self(
            red: mix(red, background.red),
            green: mix(green, background.green),
            blue: mix(blue, background.blue),
            alpha: background.alpha + alpha * (1 - background.alpha)
        )
    }

    private enum Luminance {
        static let kink = 0.040_45
        static let slope = 12.92
        static let offset = 0.055
        static let gamma = 2.4
        static let red = 0.2126
        static let green = 0.7152
        static let blue = 0.0722
    }

    private enum Contrast {
        static let offset = 0.05
    }
}
