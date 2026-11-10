import EkranbildoContracts
import EkranbildoHotkeys

public enum OnboardingStage: String, Hashable, Sendable, CaseIterable {
    case askForPermission
    case openSettings
    case restart
    case tryIt
    case done
}

public struct OnboardingStep: Hashable, Sendable {
    public let permission: CapturePermission
    public let hasCapturedAnything: Bool
    public let captureShortcut: Shortcut

    public init(
        permission: CapturePermission,
        hasCapturedAnything: Bool,
        captureShortcut: Shortcut = Settings.Defaults.captureShortcut
    ) {
        self.permission = permission
        self.hasCapturedAnything = hasCapturedAnything
        self.captureShortcut = captureShortcut
    }

    public var stage: OnboardingStage {
        switch permission {
        case .notDetermined: .askForPermission
        case .denied: .openSettings
        case .grantedPendingRestart: .restart
        case .granted: hasCapturedAnything ? .done : .tryIt
        }
    }

    public var isComplete: Bool { stage == .done }

    public var title: String {
        switch stage {
        case .askForPermission: "Let Ekranbildo see your screen"
        case .openSettings: "Ekranbildo cannot see your screen"
        case .restart: "Almost there"
        case .tryIt: "Take your first screenshot"
        case .done: "Ready"
        }
    }

    public var instruction: String {
        switch stage {
        case .askForPermission:
            """
            Ekranbildo needs to see your screen to capture it. Choose Allow when \
            macOS asks.
            """
        case .openSettings:
            """
            Open System Settings, go to Privacy & Security, then Screen \
            Recording, and turn Ekranbildo on.
            """
        case .restart:
            """
            You have allowed it, but Ekranbildo was already running. Quit Ekranbildo \
            and open it again.
            """
        case .tryIt:
            "Press \(captureShortcut.displayed) and drag to capture part of your screen."
        case .done:
            ""
        }
    }
}
