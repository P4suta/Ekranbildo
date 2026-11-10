import EkranbildoContracts
import EkranbildoHotkeys
import EkranbildoLibrary

public enum MenuCommand: Hashable, Sendable {
    case captureRegion
    case captureWindow
    case captureScreen
    case startRecording
    case stopRecording
    case openCapture(CaptureID)
    case openSettings
    case quit

    public var needsScreen: Bool {
        switch self {
        case .captureRegion, .captureWindow, .captureScreen, .startRecording, .stopRecording:
            true
        case .openCapture, .openSettings, .quit:
            false
        }
    }

    public var capture: CaptureID? {
        guard case .openCapture(let id) = self else { return nil }
        return id
    }
}

public struct MenuItem: Hashable, Sendable {
    public let title: String
    public let command: MenuCommand
    public let shortcut: Shortcut?
    public let isEnabled: Bool
}

public struct Menu: Sendable {
    private let permission: CapturePermission
    private let isRecording: Bool
    private let library: Library

    public init(permission: CapturePermission, isRecording: Bool, library: Library) {
        self.permission = permission
        self.isRecording = isRecording
        self.library = library
    }

    public enum Defaults {
        public static let recentShown = 5
    }

    public var explanation: String? {
        switch permission {
        case .granted:
            nil
        case .notDetermined:
            "Ekranbildo will ask to see your screen the first time you capture something."
        case .denied:
            """
            Ekranbildo is not allowed to see your screen. Turn it on in System \
            Settings, under Privacy & Security, Screen Recording.
            """
        case .grantedPendingRestart:
            """
            Ekranbildo is allowed to see your screen, but it started before you \
            allowed it. Quit Ekranbildo and open it again.
            """
        }
    }

    public var items: [MenuItem] {
        var items: [MenuItem] = []
        let canSeeScreen = permission == .granted

        if isRecording {
            items.append(
                MenuItem(
                    title: "Stop Recording",
                    command: .stopRecording,
                    shortcut: Shortcut.Defaults.startRecording,
                    isEnabled: canSeeScreen
                )
            )
            items.append(contentsOf: captureItems(enabled: false))
        } else {
            items.append(contentsOf: captureItems(enabled: canSeeScreen))
            items.append(
                MenuItem(
                    title: "Start Recording",
                    command: .startRecording,
                    shortcut: Shortcut.Defaults.startRecording,
                    isEnabled: canSeeScreen
                )
            )
        }

        items.append(contentsOf: recentItems())

        items.append(
            MenuItem(title: "Settings…", command: .openSettings, shortcut: nil, isEnabled: true)
        )
        items.append(MenuItem(title: "Quit Ekranbildo", command: .quit, shortcut: nil, isEnabled: true))
        return items
    }

    private func captureItems(enabled: Bool) -> [MenuItem] {
        [
            MenuItem(
                title: "Capture Region",
                command: .captureRegion,
                shortcut: Shortcut.Defaults.captureRegion,
                isEnabled: enabled
            ),
            MenuItem(
                title: "Capture Window",
                command: .captureWindow,
                shortcut: Shortcut.Defaults.captureWindow,
                isEnabled: enabled
            ),
            MenuItem(
                title: "Capture Screen",
                command: .captureScreen,
                shortcut: Shortcut.Defaults.captureScreen,
                isEnabled: enabled
            ),
        ]
    }

    private func recentItems() -> [MenuItem] {
        library.entries.prefix(Defaults.recentShown).map { entry in
            MenuItem(
                title: "\(entry.source.rawValue.capitalized) \(entry.id.raw)",
                command: .openCapture(entry.id),
                shortcut: nil,
                isEnabled: true
            )
        }
    }
}
