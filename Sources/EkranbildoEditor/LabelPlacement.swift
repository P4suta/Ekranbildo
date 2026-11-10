import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

extension EditorInteractor {
    static func placement(
        of annotation: Annotation,
        droppedAt point: ScenePoint,
        style: StyleTokens
    ) -> Placement {
        let centre = annotation.target.raw.center
        let offset = P2(x: point.x - centre.x, y: point.y - centre.y)
        let direction = Direction16.nearest(to: offset)
        let toTip =
            BoxGeometry.distanceFromCenterToBorder(
                size: annotation.target.size, direction: direction) + style.tipGap
        let reach = offset.lengthSquared.squareRoot()
        return Placement(
            direction: direction,
            leaderLength: min(Defaults.longestLeader, max(Defaults.shortestLeader, reach - toTip))
        )
    }
}
