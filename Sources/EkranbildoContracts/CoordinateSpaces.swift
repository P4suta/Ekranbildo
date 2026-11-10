import EkranbildoGeometry

public protocol CoordinateSpaceTag: Sendable {
    static var name: String { get }
}

public enum ScreenSpace: CoordinateSpaceTag {
    public static let name = "screen"
}

public enum DisplayPixelSpace: CoordinateSpaceTag {
    public static let name = "displayPixel"
}

public enum ImagePixelSpace: CoordinateSpaceTag {
    public static let name = "imagePixel"
}

public enum SceneSpace: CoordinateSpaceTag {
    public static let name = "scene"
}

public struct SpacePoint<Space: CoordinateSpaceTag>: Hashable, Sendable, Codable {
    public var raw: P2

    public init(_ raw: P2) {
        self.raw = raw
    }

    public init(x: Double, y: Double) {
        raw = P2(x: x, y: y)
    }

    public var x: Double { raw.x }
    public var y: Double { raw.y }

    public static var spaceName: String { Space.name }

    public var canonicalText: String {
        "\(Space.name)\(DrawListFormat.point(self))"
    }
}

public struct SpaceRect<Space: CoordinateSpaceTag>: Hashable, Sendable, Codable {
    public var raw: Rect

    public init(_ raw: Rect) {
        self.raw = raw
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        raw = Rect(x: x, y: y, width: width, height: height)
    }

    public var origin: SpacePoint<Space> { SpacePoint(raw.origin) }
    public var size: Size { raw.size }
    public var minX: Double { raw.minX }
    public var minY: Double { raw.minY }
    public var maxX: Double { raw.maxX }
    public var maxY: Double { raw.maxY }
    public var width: Double { raw.width }
    public var height: Double { raw.height }
    public var radius: Double { raw.radius }

    public static var spaceName: String { Space.name }

    public var canonicalText: String {
        "\(Space.name)\(DrawListFormat.rect(self))"
    }
}

public typealias ScreenPoint = SpacePoint<ScreenSpace>
public typealias DisplayPixel = SpacePoint<DisplayPixelSpace>
public typealias ImagePixel = SpacePoint<ImagePixelSpace>
public typealias ScenePoint = SpacePoint<SceneSpace>

public typealias ScreenRect = SpaceRect<ScreenSpace>
public typealias DisplayPixelRect = SpaceRect<DisplayPixelSpace>
public typealias ImageRect = SpaceRect<ImagePixelSpace>
public typealias SceneRect = SpaceRect<SceneSpace>

public struct DisplayGeometry: Hashable, Sendable, Codable {
    public let displayID: UInt32
    public let bounds: Rect
    public let backingScale: Double

    public init(displayID: UInt32, bounds: Rect, backingScale: Double) {
        self.displayID = displayID
        self.bounds = bounds
        self.backingScale = backingScale
    }

    public var pixelWidth: Int { Int((bounds.width * backingScale).rounded()) }
    public var pixelHeight: Int { Int((bounds.height * backingScale).rounded()) }

    public func contains(_ point: ScreenPoint) -> Bool {
        bounds.contains(point.raw)
    }

    public func displayPixel(of point: ScreenPoint) -> DisplayPixel {
        DisplayPixel(
            x: (point.x - bounds.minX) * backingScale,
            y: (point.y - bounds.minY) * backingScale
        )
    }

    public func screenPoint(of pixel: DisplayPixel) -> ScreenPoint {
        ScreenPoint(
            x: pixel.x / backingScale + bounds.minX,
            y: pixel.y / backingScale + bounds.minY
        )
    }
}

public struct CaptureGeometry: Hashable, Sendable, Codable {
    public let display: DisplayGeometry
    public let regionInScreen: Rect

    public init(display: DisplayGeometry, regionInScreen: Rect) {
        self.display = display
        self.regionInScreen = regionInScreen
    }

    public init(fullDisplay display: DisplayGeometry) {
        self.init(display: display, regionInScreen: display.bounds)
    }

    public var backingScale: Double { display.backingScale }

    public var sceneSize: Size { regionInScreen.size }

    public var pixelWidth: Int { Int((regionInScreen.width * backingScale).rounded()) }
    public var pixelHeight: Int { Int((regionInScreen.height * backingScale).rounded()) }

    public var sceneBounds: SceneRect {
        SceneRect(x: 0, y: 0, width: sceneSize.width, height: sceneSize.height)
    }

    public func scenePoint(of point: ScreenPoint) -> ScenePoint {
        ScenePoint(x: point.x - regionInScreen.minX, y: point.y - regionInScreen.minY)
    }

    public func screenPoint(of point: ScenePoint) -> ScreenPoint {
        ScreenPoint(x: point.x + regionInScreen.minX, y: point.y + regionInScreen.minY)
    }

    public func sceneRect(of rect: ScreenRect) -> SceneRect {
        SceneRect(
            x: rect.minX - regionInScreen.minX,
            y: rect.minY - regionInScreen.minY,
            width: rect.width,
            height: rect.height
        )
    }

    public func screenRect(of rect: SceneRect) -> ScreenRect {
        ScreenRect(
            x: rect.minX + regionInScreen.minX,
            y: rect.minY + regionInScreen.minY,
            width: rect.width,
            height: rect.height
        )
    }

    public func imagePixel(of point: ScenePoint) -> ImagePixel {
        ImagePixel(x: point.x * backingScale, y: point.y * backingScale)
    }

    public func scenePoint(of pixel: ImagePixel) -> ScenePoint {
        ScenePoint(x: pixel.x / backingScale, y: pixel.y / backingScale)
    }

    public func imageRect(of rect: SceneRect) -> ImageRect {
        ImageRect(
            x: rect.minX * backingScale,
            y: rect.minY * backingScale,
            width: rect.width * backingScale,
            height: rect.height * backingScale
        )
    }

    public func sceneRect(of rect: ImageRect) -> SceneRect {
        SceneRect(
            x: rect.minX / backingScale,
            y: rect.minY / backingScale,
            width: rect.width / backingScale,
            height: rect.height / backingScale
        )
    }
}

public enum AppKitCoordinates {

    public static func screenRect(fromAppKitRect rect: Rect, primaryDisplayHeight: Double) -> ScreenRect {
        ScreenRect(
            x: rect.minX,
            y: primaryDisplayHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func appKitRect(fromScreenRect rect: ScreenRect, primaryDisplayHeight: Double) -> Rect {
        Rect(
            x: rect.minX,
            y: primaryDisplayHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func screenPoint(fromAppKitPoint point: P2, primaryDisplayHeight: Double)
        -> ScreenPoint
    {
        ScreenPoint(x: point.x, y: primaryDisplayHeight - point.y)
    }
}
