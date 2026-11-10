import EkranbildoContracts
import EkranbildoCore

public enum SceneLibrary {

    public static var threeControls: SyntheticScreenshot {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        screen.add(
            SceneRect(x: 20, y: 20, width: 60, height: 24),
            color: .opaque(red: 60, green: 120, blue: 220),
            named: "primary button"
        )
        screen.add(
            SceneRect(x: 100, y: 20, width: 60, height: 24),
            color: .opaque(red: 220, green: 220, blue: 225),
            named: "secondary button"
        )
        screen.add(
            SceneRect(x: 20, y: 70, width: 140, height: 30),
            color: .opaque(red: 255, green: 255, blue: 255),
            named: "text field"
        )
        return screen
    }

    public static var applicationWindow: SyntheticScreenshot {
        var screen = SyntheticScreenshot(width: 320, height: 220)
        screen.add(
            SceneRect(x: 0, y: 0, width: 320, height: 36),
            color: .opaque(red: 232, green: 232, blue: 236),
            named: "toolbar"
        )
        screen.add(
            SceneRect(x: 8, y: 6, width: 48, height: 24),
            color: .opaque(red: 70, green: 130, blue: 230),
            named: "toolbar button"
        )
        screen.add(
            SceneRect(x: 0, y: 36, width: 72, height: 184),
            color: .opaque(red: 216, green: 216, blue: 222),
            named: "sidebar"
        )
        screen.add(
            SceneRect(x: 88, y: 56, width: 200, height: 120),
            color: .opaque(red: 255, green: 255, blue: 255),
            named: "content panel"
        )
        screen.add(
            SceneRect(x: 104, y: 76, width: 160, height: 26),
            color: .opaque(red: 238, green: 238, blue: 242),
            named: "search field"
        )
        return screen
    }

    public static let applicationWindowButton = ScenePoint(x: 32, y: 18)

    public static var dialog: SyntheticScreenshot {
        var screen = SyntheticScreenshot(
            width: 280,
            height: 180,
            background: .opaque(red: 96, green: 98, blue: 104)
        )
        screen.add(
            SceneRect(x: 50, y: 40, width: 180, height: 100),
            color: .opaque(red: 248, green: 248, blue: 250),
            named: "dialog"
        )
        screen.add(
            SceneRect(x: 146, y: 106, width: 72, height: 24),
            color: .opaque(red: 60, green: 120, blue: 230),
            named: "confirm button"
        )
        screen.add(
            SceneRect(x: 62, y: 106, width: 72, height: 24),
            color: .opaque(red: 226, green: 226, blue: 230),
            named: "cancel button"
        )
        return screen
    }

    public static var nestedControls: SyntheticScreenshot {
        var screen = SyntheticScreenshot(
            width: 240,
            height: 160,
            background: .opaque(red: 250, green: 250, blue: 250)
        )
        screen.add(
            SceneRect(x: 20, y: 20, width: 200, height: 120),
            color: .opaque(red: 236, green: 236, blue: 238),
            named: "window"
        )
        screen.add(
            SceneRect(x: 30, y: 30, width: 180, height: 40),
            color: .opaque(red: 212, green: 214, blue: 218),
            named: "toolbar"
        )
        screen.add(
            SceneRect(x: 40, y: 38, width: 60, height: 24),
            color: .opaque(red: 40, green: 110, blue: 220),
            named: "button"
        )
        return screen
    }

    public static let nestedControlsButton = ScenePoint(x: 70, y: 50)

    public static var all: [NamedScreen] {
        [
            NamedScreen(name: "application-window", screen: applicationWindow),
            NamedScreen(name: "three-controls", screen: threeControls),
            NamedScreen(name: "dialog", screen: dialog),
            NamedScreen(name: "nested-controls", screen: nestedControls),
        ]
    }
}

extension SceneLibrary {
    public static var sampleAnnotated: Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: Sample.width, height: Sample.height),
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(Sample.firstIdentifier),
                    target: Sample.firstTarget,
                    label: "Press this first",
                    placement: Placement(direction: .ne, leaderLength: Sample.leader),
                    badge: BadgeNumber(Sample.firstStep)
                ),
                Annotation(
                    id: AnnotationID(Sample.secondIdentifier),
                    target: Sample.secondTarget,
                    label: "Then this",
                    placement: Placement(direction: .w, leaderLength: Sample.leader),
                    badge: BadgeNumber(Sample.secondStep)
                ),
            ],
            style: .standard
        )
    }

    private enum Sample {
        static let width: Double = 560
        static let height: Double = 360
        static let leader: Double = 64
        static let firstIdentifier: UInt32 = 1
        static let secondIdentifier: UInt32 = 2
        static let firstStep = 1
        static let secondStep = 2
        static let firstTarget = SceneRect(x: 60, y: 200, width: 140, height: 32)
        static let secondTarget = SceneRect(x: 340, y: 90, width: 120, height: 32)
    }
}

public struct NamedScreen: Sendable {
    public let name: String
    public let screen: SyntheticScreenshot

    public init(name: String, screen: SyntheticScreenshot) {
        self.name = name
        self.screen = screen
    }
}
