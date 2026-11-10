import EkranbildoContracts

public enum ScrollAdvice: Hashable, Sendable {
    case keepGoing
    case slowDown
    case nothingIsMoving
    case theScreenChanged
}

public struct ScrollSession: Sendable {
    public private(set) var kept: [ImageBuffer] = []
    public private(set) var advice: ScrollAdvice = .keepGoing
    public private(set) var coveredRows: Int = 0
    public private(set) var missedJoins: Int = 0
    public private(set) var rowComparisons: Int = 0

    private let stitcher: Stitcher
    private var trailing: ImageBuffer?
    private var pinnedTop = -1
    private var pinnedBottom = -1
    private var positionOfLastKept = 0
    private var highest = 0
    private var lowest = 0
    private var travellingDown = true
    private var stillFrames = 0

    public init(stitcher: Stitcher = Stitcher()) {
        self.stitcher = stitcher
    }

    public enum Defaults {
        public static let stillnessBeforeSaying = 12

        public static let advanceShare = 2
    }

    public func offered(_ frame: ImageBuffer) -> Self {
        var next = self
        guard let first = kept.first else {
            next.kept = [frame]
            next.coveredRows = frame.height
            next.advice = .keepGoing
            return next
        }

        guard frame.width == first.width, frame.height == first.height, frame.isWellFormed else {
            next.advice = .theScreenChanged
            return next
        }

        next.learnPinned(first, frame)

        var comparisons = 0
        let ignored = next.ignoredRows(height: frame.height)
        let found = withUnsafeMutablePointer(to: &comparisons) { counter in
            stitcher.shift(
                from: kept[kept.count - 1], to: frame, ignoringRows: ignored, comparisons: counter)
        }
        next.rowComparisons += comparisons

        guard let found else {
            let assumed =
                positionOfLastKept + (travellingDown ? frame.height : -frame.height)
            next.kept.append(frame)
            next.trailing = nil
            next.positionOfLastKept = assumed
            next.missedJoins += 1
            next.stillFrames = 0
            next.advice = .slowDown
            next.see(assumed, height: frame.height)
            return next
        }

        let position = positionOfLastKept + found.rows
        next.see(position, height: frame.height)

        guard found.rows != 0 else {
            next.stillFrames += 1
            next.advice =
                next.stillFrames >= Defaults.stillnessBeforeSaying ? .nothingIsMoving : .keepGoing
            return next
        }

        next.stillFrames = 0
        next.travellingDown = found.rows > 0
        next.advice = .keepGoing

        guard abs(found.rows) >= Self.advance(within: frame.height, for: stitcher) else {
            next.trailing = frame
            return next
        }
        next.kept.append(frame)
        next.trailing = nil
        next.positionOfLastKept = position
        return next
    }

    public var framesToJoin: [ImageBuffer] {
        guard let trailing else { return kept }
        return kept + [trailing]
    }

    private mutating func learnPinned(_ first: ImageBuffer, _ frame: ImageBuffer) {
        var top = 0
        while top < frame.height, Stitcher.rowIsUnchanged(top, in: [first, frame]) {
            top += 1
        }
        guard top < frame.height else { return }

        var bottom = 0
        while bottom < frame.height - top,
            Stitcher.rowIsUnchanged(frame.height - 1 - bottom, in: [first, frame])
        {
            bottom += 1
        }
        pinnedTop = pinnedTop < 0 ? top : min(pinnedTop, top)
        pinnedBottom = pinnedBottom < 0 ? bottom : min(pinnedBottom, bottom)
    }

    private func ignoredRows(height: Int) -> Set<Int> {
        let top = max(0, pinnedTop)
        let bottom = max(0, pinnedBottom)
        guard top > 0 || bottom > 0 else { return [] }
        let fromTop = Array(0..<top)
        let fromBottom = (0..<bottom).map { height - 1 - $0 }
        return Set(fromTop + fromBottom)
    }

    private mutating func see(_ position: Int, height: Int) {
        highest = max(highest, position)
        lowest = min(lowest, position)
        coveredRows = highest - lowest + height
    }

    static func advance(within height: Int, for stitcher: Stitcher) -> Int {
        max(1, stitcher.affordableMovement(within: height) / Defaults.advanceShare)
    }

    public func finish() throws -> StitchResult {
        try stitcher.stitch(framesToJoin)
    }
}

extension Stitcher {
    func affordableMovement(within height: Int) -> Int {
        max(1, height - minimumOverlap)
    }
}
