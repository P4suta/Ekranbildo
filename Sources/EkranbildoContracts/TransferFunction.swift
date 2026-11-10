import Foundation

public enum TransferFunction {

    public static func linearFromEncoded(_ value: Double) -> Double {
        guard value > Curve.knee else { return value / Curve.slope }
        return pow((value + Curve.offset) / (1 + Curve.offset), Curve.exponent)
    }

    public static func encodedFromLinear(_ value: Double) -> Double {
        guard value > Curve.linearKnee else { return value * Curve.slope }
        return (1 + Curve.offset) * pow(value, 1 / Curve.exponent) - Curve.offset
    }

    private enum Curve {
        static let knee = 0.040_45
        static let linearKnee = 0.003_130_8
        static let slope = 12.92
        static let offset = 0.055
        static let exponent = 2.4
    }
}
