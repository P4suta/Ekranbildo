import EkranbildoGeometry

public enum WindowTag: Sendable {}
public typealias WindowID = StableID<WindowTag>

public struct WindowDescriptor: Hashable, Sendable, Codable, Identifiable {
    public let id: WindowID
    public let title: String?
    public let applicationName: String?
    public let bundleIdentifier: String?
    public let frame: ScreenRect
    public let isOnScreen: Bool
    public let layer: Int

    public init(
        id: WindowID,
        title: String?,
        applicationName: String?,
        bundleIdentifier: String?,
        frame: ScreenRect,
        isOnScreen: Bool,
        layer: Int
    ) {
        self.id = id
        self.title = title
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
        self.isOnScreen = isOnScreen
        self.layer = layer
    }

    public var describedName: String {
        if let title, !title.isEmpty { return title }
        return applicationName ?? Untitled.label
    }

    private enum Untitled {
        static let label = "Window"
    }
}

public struct WindowStack: Hashable, Sendable {
    public let windows: [WindowDescriptor]

    public init(windows: [WindowDescriptor]) {
        self.windows = windows
    }

    public var onScreen: [WindowDescriptor] { windows.filter(\.isOnScreen) }

    public func window(under point: ScreenPoint) -> WindowDescriptor? {
        var best: (window: WindowDescriptor, position: Int)?
        for (position, window) in windows.enumerated() {
            guard window.isOnScreen, window.frame.raw.contains(point.raw) else { continue }
            guard let current = best else {
                best = (window, position)
                continue
            }
            if window.layer > current.window.layer {
                best = (window, position)
            }
        }
        return best?.window
    }

    public func snap(_ rect: ScreenRect, within distance: Double) -> ScreenRect {
        guard distance > 0 else { return rect }

        var verticals: [Double] = []
        var horizontals: [Double] = []
        for window in onScreen {
            verticals.append(window.frame.minX)
            verticals.append(window.frame.maxX)
            horizontals.append(window.frame.minY)
            horizontals.append(window.frame.maxY)
        }

        let minX = Self.nearest(to: rect.minX, among: verticals, within: distance)
        let maxX = Self.nearest(to: rect.maxX, among: verticals, within: distance)
        let minY = Self.nearest(to: rect.minY, among: horizontals, within: distance)
        let maxY = Self.nearest(to: rect.maxY, among: horizontals, within: distance)

        return ScreenRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func nearest(
        to value: Double,
        among candidates: [Double],
        within distance: Double
    ) -> Double {
        var best = value
        var bestDistance = distance
        for candidate in candidates {
            let gap = abs(candidate - value)
            guard gap <= bestDistance else { continue }
            if gap < bestDistance || candidate < best {
                best = candidate
                bestDistance = gap
            }
        }
        return best
    }
}
