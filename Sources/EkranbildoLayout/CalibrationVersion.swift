import EkranbildoContracts

public struct CalibrationConstant: Hashable, Sendable {
    public let name: String
    public let value: Double

    public init(name: String, value: Double) {
        self.name = name
        self.value = value
    }
}

public enum CalibrationFingerprint {
    public static func of(_ constants: [CalibrationConstant]) -> String {
        var bytes: [UInt8] = []
        for constant in constants {
            bytes.append(contentsOf: Array(constant.name.utf8))
            bytes.append(Separator.nameFromValue)
            bytes.append(contentsOf: Fingerprint.bytes(of: constant.value))
            bytes.append(Separator.betweenConstants)
        }
        return Fingerprint.of(bytes)
    }

    private enum Separator {
        static let nameFromValue = UInt8(ascii: "=")
        static let betweenConstants = UInt8(ascii: ";")
    }
}

extension Calibration {
    public var constants: [CalibrationConstant] {
        anchors.enumerated().flatMap { index, anchor in
            [
                CalibrationConstant(name: "anchor\(index).raw", value: anchor.raw),
                CalibrationConstant(name: "anchor\(index).badness", value: anchor.badness),
            ]
        }
    }
}

extension UnaryScoreTerm {
    public var calibrationVersion: String {
        CalibrationFingerprint.of(calibrationConstants)
    }
}

extension PairScoreTerm {
    public var calibrationVersion: String {
        CalibrationFingerprint.of(calibrationConstants)
    }
}
