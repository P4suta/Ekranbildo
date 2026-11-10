import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public enum HitResult: Hashable, Sendable {
    case nothing
    case label(AnnotationID)
    case target(AnnotationID)
    case leader(AnnotationID)
    case handle(AnnotationID, Handle)

    public enum Handle: String, Hashable, Sendable, Codable, CaseIterable {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }

    public var isLabel: Bool {
        if case .label = self { return true }
        return false
    }

    public var annotationID: AnnotationID? {
        switch self {
        case .nothing: nil
        case .label(let id), .target(let id), .leader(let id): id
        case .handle(let id, _): id
        }
    }
}

public struct HitTester: Sendable {
    private let scene: Scene
    private let measurer: any TextMeasuring
    private let tolerance: Double
    private let handleRadius: Double

    public init(
        scene: Scene,
        measurer: any TextMeasuring,
        tolerance: Double = Defaults.tolerance,
        handleRadius: Double = Defaults.handleRadius
    ) {
        self.scene = scene
        self.measurer = measurer
        self.tolerance = tolerance
        self.handleRadius = handleRadius
    }

    public enum Defaults {
        public static let tolerance: Double = 6

        public static let handleRadius: Double = 8
    }

    public func hit(at point: ScenePoint) -> HitResult {
        guard scene.canvas.raw.contains(point.raw) else { return .nothing }
        return handleHit(at: point)
            ?? labelHit(at: point)
            ?? leaderHit(at: point)
            ?? targetHit(at: point)
            ?? .nothing
    }

    private func handleHit(at point: ScenePoint) -> HitResult? {
        for annotation in scene.annotations.reversed() {
            guard let label = labelRect(of: annotation.id),
                let handle = Self.handle(of: label, at: point, within: handleRadius)
            else { continue }
            return .handle(annotation.id, handle)
        }
        return nil
    }

    private func labelHit(at point: ScenePoint) -> HitResult? {
        for annotation in scene.annotations.reversed() {
            guard let label = labelRect(of: annotation.id), label.raw.contains(point.raw) else {
                continue
            }
            return .label(annotation.id)
        }
        return nil
    }

    private func leaderHit(at point: ScenePoint) -> HitResult? {
        for annotation in scene.annotations.reversed() {
            guard let leader = leader(of: annotation.id),
                Self.isNear(leader, point: point.raw, within: tolerance)
            else { continue }
            return .leader(annotation.id)
        }
        return nil
    }

    private func targetHit(at point: ScenePoint) -> HitResult? {
        for annotation in scene.annotations.reversed()
        where annotation.target.raw.contains(point.raw) {
            return .target(annotation.id)
        }
        return nil
    }

    public func labelRect(of id: AnnotationID) -> SceneRect? {
        guard let annotation = annotation(id), let placement = annotation.placement else {
            return nil
        }
        let resolved = ResolvedPlacement(
            target: annotation.target,
            placement: placement,
            style: scene.style
        )
        let metrics = measurer.measure(annotation.label, font: scene.style.labelFont)
        return resolved.labelBox(
            textSize: Size(width: metrics.width, height: metrics.height),
            style: scene.style
        )
    }

    public func leader(of id: AnnotationID) -> Polyline? {
        guard let annotation = annotation(id), let placement = annotation.placement else {
            return nil
        }
        return ResolvedPlacement(
            target: annotation.target,
            placement: placement,
            style: scene.style
        ).leader
    }

    private func annotation(_ id: AnnotationID) -> Annotation? {
        scene.annotations.first { $0.id == id }
    }

    static func handle(of rect: SceneRect, at point: ScenePoint, within radius: Double)
        -> HitResult.Handle?
    {
        let corners: [(HitResult.Handle, P2)] = [
            (.topLeading, P2(x: rect.minX, y: rect.minY)),
            (.topTrailing, P2(x: rect.maxX, y: rect.minY)),
            (.bottomLeading, P2(x: rect.minX, y: rect.maxY)),
            (.bottomTrailing, P2(x: rect.maxX, y: rect.maxY)),
        ]
        var best: (handle: HitResult.Handle, distance: Double)?
        for (handle, corner) in corners {
            let distance = Geo.distanceSquared(point.raw, corner)
            guard distance <= radius * radius else { continue }
            if best == nil || distance < best!.distance {
                best = (handle, distance)
            }
        }
        return best?.handle
    }

    static func isNear(_ line: Polyline, point: P2, within tolerance: Double) -> Bool {
        for segment in line.segments
        where Geo.distanceSquared(from: point, to: segment) <= tolerance * tolerance {
            return true
        }
        return false
    }
}
