import EkranbildoContracts

public struct StyleTokens: Hashable, Sendable, Codable {

    public var tipGap: Double
    public var leaderWidth: Double
    public var leaderColor: Color
    public var arrowheadLength: Double
    public var arrowheadHalfWidth: Double

    public var labelFont: FontSpec
    public var labelColor: Color
    public var labelPlateColor: Color
    public var labelPlateCornerRadius: Double
    public var labelPaddingHorizontal: Double
    public var labelPaddingVertical: Double
    public var labelMinimumGap: Double

    public var badgeDiameter: Double
    public var badgeColor: Color
    public var badgeTextColor: Color
    public var badgeFont: FontSpec
    public var badgeGap: Double

    public var cursorSize: Double
    public var cursorColor: Color
    public var cursorOutlineColor: Color
    public var cursorOutlineWidth: Double
    public var rippleColor: Color
    public var rippleSpread: Double
    public var rippleWidth: Double

    public init(
        tipGap: Double,
        leaderWidth: Double,
        leaderColor: Color,
        arrowheadLength: Double,
        arrowheadHalfWidth: Double,
        labelFont: FontSpec,
        labelColor: Color,
        labelPlateColor: Color,
        labelPlateCornerRadius: Double,
        labelPaddingHorizontal: Double,
        labelPaddingVertical: Double,
        labelMinimumGap: Double,
        badgeDiameter: Double = Standard.badgeDiameter,
        badgeColor: Color = Standard.accent,
        badgeTextColor: Color = Standard.labelForeground,
        badgeFont: FontSpec = Standard.badgeFont,
        badgeGap: Double = Standard.badgeGap,
        cursorSize: Double = Standard.cursorSize,
        cursorColor: Color = Standard.cursorColor,
        cursorOutlineColor: Color = Standard.labelForeground,
        cursorOutlineWidth: Double = Standard.cursorOutlineWidth,
        rippleColor: Color = Standard.accent,
        rippleSpread: Double = Standard.rippleSpread,
        rippleWidth: Double = Standard.rippleWidth
    ) {
        self.tipGap = tipGap
        self.leaderWidth = leaderWidth
        self.leaderColor = leaderColor
        self.arrowheadLength = arrowheadLength
        self.arrowheadHalfWidth = arrowheadHalfWidth
        self.labelFont = labelFont
        self.labelColor = labelColor
        self.labelPlateColor = labelPlateColor
        self.labelPlateCornerRadius = labelPlateCornerRadius
        self.labelPaddingHorizontal = labelPaddingHorizontal
        self.labelPaddingVertical = labelPaddingVertical
        self.labelMinimumGap = labelMinimumGap
        self.badgeDiameter = badgeDiameter
        self.badgeColor = badgeColor
        self.badgeTextColor = badgeTextColor
        self.badgeFont = badgeFont
        self.badgeGap = badgeGap
        self.cursorSize = cursorSize
        self.cursorColor = cursorColor
        self.cursorOutlineColor = cursorOutlineColor
        self.cursorOutlineWidth = cursorOutlineWidth
        self.rippleColor = rippleColor
        self.rippleSpread = rippleSpread
        self.rippleWidth = rippleWidth
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }

        tipGap = try value(.tipGap, Standard.tipGap)
        leaderWidth = try value(.leaderWidth, Standard.leaderWidth)
        leaderColor = try value(.leaderColor, Standard.accent)
        arrowheadLength = try value(.arrowheadLength, Standard.arrowheadLength)
        arrowheadHalfWidth = try value(.arrowheadHalfWidth, Standard.arrowheadHalfWidth)
        labelFont = try value(.labelFont, Standard.labelFont)
        labelColor = try value(.labelColor, Standard.labelForeground)
        labelPlateColor = try value(.labelPlateColor, Standard.accent)
        labelPlateCornerRadius = try value(
            .labelPlateCornerRadius, Standard.labelPlateCornerRadius)
        labelPaddingHorizontal = try value(
            .labelPaddingHorizontal, Standard.labelPaddingHorizontal)
        labelPaddingVertical = try value(.labelPaddingVertical, Standard.labelPaddingVertical)
        labelMinimumGap = try value(.labelMinimumGap, Standard.labelMinimumGap)
        badgeDiameter = try value(.badgeDiameter, Standard.badgeDiameter)
        badgeColor = try value(.badgeColor, Standard.accent)
        badgeTextColor = try value(.badgeTextColor, Standard.labelForeground)
        badgeFont = try value(.badgeFont, Standard.badgeFont)
        badgeGap = try value(.badgeGap, Standard.badgeGap)
        cursorSize = try value(.cursorSize, Standard.cursorSize)
        cursorColor = try value(.cursorColor, Standard.cursorColor)
        cursorOutlineColor = try value(.cursorOutlineColor, Standard.labelForeground)
        cursorOutlineWidth = try value(.cursorOutlineWidth, Standard.cursorOutlineWidth)
        rippleColor = try value(.rippleColor, Standard.accent)
        rippleSpread = try value(.rippleSpread, Standard.rippleSpread)
        rippleWidth = try value(.rippleWidth, Standard.rippleWidth)
    }

    public var labelContrast: Double {
        labelColor.contrastRatio(against: labelPlateColor)
    }

    public var badgeContrast: Double {
        badgeTextColor.contrastRatio(against: badgeColor)
    }

    public func labelContrast(over background: Color) -> Double {
        labelColor.composited(over: labelPlateColor.composited(over: background))
            .contrastRatio(against: labelPlateColor.composited(over: background))
    }

    public func labelContrast(seenWith vision: ColorVision) -> Double {
        labelColor.seen(with: vision)
            .contrastRatio(against: labelPlateColor.seen(with: vision))
    }

    public func badgeContrast(seenWith vision: ColorVision) -> Double {
        badgeTextColor.seen(with: vision)
            .contrastRatio(against: badgeColor.seen(with: vision))
    }

    public func isReadable(seenWith vision: ColorVision) -> Bool {
        labelContrast(seenWith: vision) >= Readability.required
            && badgeContrast(seenWith: vision) >= Readability.required
    }

    public var isReadable: Bool {
        labelContrast >= Readability.required && badgeContrast >= Readability.required
    }

    public enum Readability {
        public static let required: Double = 4.5
    }

    public static let standard = Self(
        tipGap: Standard.tipGap,
        leaderWidth: Standard.leaderWidth,
        leaderColor: Standard.accent,
        arrowheadLength: Standard.arrowheadLength,
        arrowheadHalfWidth: Standard.arrowheadHalfWidth,
        labelFont: Standard.labelFont,
        labelColor: Standard.labelForeground,
        labelPlateColor: Standard.accent,
        labelPlateCornerRadius: Standard.labelPlateCornerRadius,
        labelPaddingHorizontal: Standard.labelPaddingHorizontal,
        labelPaddingVertical: Standard.labelPaddingVertical,
        labelMinimumGap: Standard.labelMinimumGap
    )

    public enum Standard {
        public static let tipGap: Double = 6
        public static let leaderWidth: Double = 2.5
        public static let arrowheadLength: Double = leaderWidth * arrowheadLengthRatio
        public static let arrowheadHalfWidth: Double = leaderWidth * arrowheadWidthRatio
        private static let arrowheadLengthRatio: Double = 4.8
        private static let arrowheadWidthRatio: Double = 2

        public static let accent = Color(
            red: 0.76, green: 0.14, blue: 0.14, alpha: 1
        )
        public static let labelForeground = Color(red: 1, green: 1, blue: 1, alpha: 1)

        public static let badgeDiameter: Double = 26
        public static let badgeFont = FontSpec(
            family: labelFontFamily,
            size: badgeFontSize,
            weight: .bold
        )
        private static let badgeFontSize: Double = badgeDiameter * badgeTextRatio
        private static let badgeTextRatio: Double = 0.55
        public static let badgeGap: Double = 6

        public static let labelFont = FontSpec(
            family: labelFontFamily,
            size: labelFontSize,
            weight: .semibold
        )
        private static let labelFontFamily = "Inter"
        private static let labelFontSize: Double = 14

        public static let labelPlateCornerRadius: Double = 6
        public static let labelPaddingHorizontal: Double = 10
        public static let labelPaddingVertical: Double = 6
        public static let labelMinimumGap: Double = 8

        public static let cursorSize: Double = 28
        public static let cursorColor = Color(
            red: 0.12, green: 0.12, blue: 0.14, alpha: 1
        )
        public static let cursorOutlineWidth: Double = 1.5
        public static let rippleSpread: Double = 1.5
        public static let rippleWidth: Double = 2
    }
}
