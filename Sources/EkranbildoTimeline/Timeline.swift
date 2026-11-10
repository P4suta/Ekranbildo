import EkranbildoContracts
import EkranbildoCore

public struct AnnotationTrack: Hashable, Sendable, Codable {
    public let annotation: Annotation
    public let appears: Timestamp
    public let disappears: Timestamp?

    public init(annotation: Annotation, appears: Timestamp, disappears: Timestamp? = nil) {
        self.annotation = annotation
        self.appears = appears
        self.disappears = disappears
    }

    public func isPresent(at moment: Timestamp) -> Bool {
        guard moment >= appears else { return false }
        guard let disappears else { return true }
        return moment <= disappears
    }
}

public struct Timeline: Hashable, Sendable, Codable {
    public let canvas: SceneRect
    public let style: StyleTokens
    public let background: ImageRef?
    public let duration: Timestamp
    public let tracks: [AnnotationTrack]
    public let cursor: CursorTrack?
    public let keys: KeystrokeTrack?

    public init(
        canvas: SceneRect,
        style: StyleTokens,
        background: ImageRef?,
        duration: Timestamp,
        tracks: [AnnotationTrack],
        cursor: CursorTrack? = nil,
        keys: KeystrokeTrack? = nil
    ) {
        self.canvas = canvas
        self.style = style
        self.background = background
        self.duration = duration
        self.tracks = tracks
        self.cursor = cursor
        self.keys = keys
    }

    public init(still scene: Scene) {
        self.init(
            canvas: scene.canvas,
            style: scene.style,
            background: scene.background,
            duration: .zero,
            tracks: scene.annotations.map { AnnotationTrack(annotation: $0, appears: .zero) }
        )
    }

    public func scene(at moment: Timestamp) -> Scene {
        let inside = Self.clamped(moment, to: duration)
        return Scene(
            canvas: canvas,
            background: background,
            annotations: tracks.filter { $0.isPresent(at: inside) }.map(\.annotation),
            style: style,
            cursor: cursor?.cursor(at: inside),
            keys: keys?.showing(at: inside) ?? []
        )
    }

    static func clamped(_ moment: Timestamp, to duration: Timestamp) -> Timestamp {
        if moment < .zero { return .zero }
        if moment > duration { return duration }
        return moment
    }
}
