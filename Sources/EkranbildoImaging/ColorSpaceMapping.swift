import CoreGraphics
import EkranbildoContracts

public enum CoreGraphicsColorSpace {
    public static func resolve(_ space: CanonicalColorSpace) -> CGColorSpace {
        switch space {
        case .sRGB:
            CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        case .displayP3:
            CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        case .extendedLinearDisplayP3:
            CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) ?? CGColorSpaceCreateDeviceRGB()
        }
    }
}
