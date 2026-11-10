import EkranbildoContracts

extension Stitcher {

    public func stitch(_ frames: [ImageBuffer]) throws -> StitchResult {
        guard let first = frames.first else {
            throw StitchError(
                code: StitchError.nothingToJoin,
                detail: "there are no frames to join"
            )
        }
        guard
            frames.allSatisfy({
                $0.width == first.width && $0.height == first.height && $0.isWellFormed
            })
        else {
            throw StitchError(
                code: StitchError.mismatchedFrames,
                detail: "the frames are not all the same size"
            )
        }

        let pinned = Self.pinnedBands(frames)
        let fromTop = Array(0..<pinned.top)
        let fromBottom = (0..<pinned.bottom).map { first.height - 1 - $0 }
        let ignored = Set(fromTop + fromBottom)

        var comparisons = 0
        var positions: [Int] = [0]
        var uncertain: [UncertainJoin] = []

        for index in 1..<frames.count {
            let found = withUnsafeMutablePointer(to: &comparisons) { counter in
                shift(
                    from: frames[index - 1],
                    to: frames[index],
                    ignoringRows: ignored,
                    comparisons: counter
                )
            }
            guard let found else {
                let assumed = positions[index - 1] + first.height - pinned.top - pinned.bottom
                uncertain.append(
                    UncertainJoin(
                        betweenFrames: index - 1,
                        atRow: assumed + pinned.top,
                        confidence: 0
                    )
                )
                positions.append(assumed)
                continue
            }
            positions.append(positions[index - 1] + found.rows)
        }

        return Self.compose(
            frames,
            positions: positions,
            pinned: pinned,
            uncertain: uncertain,
            comparisons: comparisons
        )
    }

    static func pinnedBands(_ frames: [ImageBuffer]) -> PinnedBands {
        guard let first = frames.first, frames.count > 1 else { return PinnedBands(top: 0, bottom: 0) }

        var top = 0
        while top < first.height, Self.rowIsUnchanged(top, in: frames) {
            top += 1
        }
        guard top < first.height else { return PinnedBands(top: 0, bottom: 0) }

        var bottom = 0
        while bottom < first.height - top,
            Self.rowIsUnchanged(first.height - 1 - bottom, in: frames)
        {
            bottom += 1
        }
        return PinnedBands(top: top, bottom: bottom)
    }

    static func rowIsUnchanged(_ row: Int, in frames: [ImageBuffer]) -> Bool {
        guard let first = frames.first else { return false }
        for frame in frames.dropFirst() {
            for column in 0..<first.width {
                let a = first[x: column, y: row]
                let b = frame[x: column, y: row]
                guard Self.alike(a, b) else { return false }
            }
        }
        return true
    }

    static func alike(_ a: ImageBuffer.Pixel, _ b: ImageBuffer.Pixel) -> Bool {
        let tolerance = Defaults.stillnessTolerance
        return abs(Int(a.red) - Int(b.red)) <= tolerance
            && abs(Int(a.green) - Int(b.green)) <= tolerance
            && abs(Int(a.blue) - Int(b.blue)) <= tolerance
    }

    static func compose(
        _ frames: [ImageBuffer],
        positions: [Int],
        pinned: PinnedBands,
        uncertain: [UncertainJoin],
        comparisons: Int
    ) -> StitchResult {
        guard let first = frames.first else {
            return StitchResult(
                image: ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []),
                stickyTop: 0,
                stickyBottom: 0,
                uncertainJoins: uncertain,
                rowComparisons: comparisons
            )
        }

        let scrollingHeight = first.height - pinned.top - pinned.bottom
        let lowest = positions.min() ?? 0
        let highest = (positions.max() ?? 0) + scrollingHeight
        let pageHeight = highest - lowest + pinned.top + pinned.bottom

        var pixels = [UInt8](
            repeating: 0, count: first.width * pageHeight * ImageBuffer.Channel.count)

        func draw(_ source: ImageBuffer, sourceRow: Int, destinationRow: Int) {
            guard destinationRow >= 0, destinationRow < pageHeight else { return }
            for column in 0..<first.width {
                let pixel = source[x: column, y: sourceRow]
                let offset =
                    (destinationRow * first.width + column) * ImageBuffer.Channel.count
                let channel = ImageBuffer.Channel.Offset.self
                pixels[offset + channel.red] = pixel.red
                pixels[offset + channel.green] = pixel.green
                pixels[offset + channel.blue] = pixel.blue
                pixels[offset + channel.alpha] = pixel.alpha
            }
        }

        for (frame, position) in zip(frames, positions) {
            for row in 0..<scrollingHeight {
                draw(
                    frame,
                    sourceRow: row + pinned.top,
                    destinationRow: position - lowest + row + pinned.top
                )
            }
        }

        for row in 0..<pinned.top {
            draw(first, sourceRow: row, destinationRow: row)
        }
        for row in 0..<pinned.bottom {
            draw(
                first,
                sourceRow: first.height - 1 - row,
                destinationRow: pageHeight - 1 - row
            )
        }

        return StitchResult(
            image: ImageBuffer(
                width: first.width,
                height: pageHeight,
                colorSpace: first.colorSpace,
                pixels: pixels
            ),
            stickyTop: pinned.top,
            stickyBottom: pinned.bottom,
            uncertainJoins: uncertain,
            rowComparisons: comparisons
        )
    }
}

public struct PinnedBands: Hashable, Sendable {
    public let top: Int
    public let bottom: Int

    public init(top: Int, bottom: Int) {
        self.top = top
        self.bottom = bottom
    }
}

public struct Overlap: Hashable, Sendable {
    public let score: Double
    public let rows: Int

    public init(score: Double, rows: Int) {
        self.score = score
        self.rows = rows
    }
}
