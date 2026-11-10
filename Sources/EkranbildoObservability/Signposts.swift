import Synchronization

public protocol SignpostEmitting: Sendable {
    func began(_ name: String)
    func ended(_ name: String)
    func happened(_ name: String)
}

public struct NoSignposts: SignpostEmitting {
    public init() {}
    public func began(_ name: String) {}
    public func ended(_ name: String) {}
    public func happened(_ name: String) {}
}

public final class RecordingSignposts: SignpostEmitting {
    private let lines = Mutex<[String]>([])

    public init() {}

    public var emitted: [String] { lines.withLock { $0 } }

    public func began(_ name: String) { lines.withLock { $0.append("begin \(name)") } }
    public func ended(_ name: String) { lines.withLock { $0.append("end \(name)") } }
    public func happened(_ name: String) { lines.withLock { $0.append("event \(name)") } }
}

public struct PerformanceBudget: Hashable, Sendable {
    public let stage: String
    public let signpost: String
    public let milliseconds: Int
    public let checkedBy: String

    public init(stage: String, signpost: String, milliseconds: Int, checkedBy: String) {
        self.stage = stage
        self.signpost = signpost
        self.milliseconds = milliseconds
        self.checkedBy = checkedBy
    }

    public static let all: [Self] = [
        Self(
            stage: "hotkey to overlay",
            signpost: "overlay",
            milliseconds: Budget.overlay,
            checkedBy: "nothing deterministic; it is dominated by the system's first "
                + "SCShareableContent call, which is why the overlay is pre-warmed"
        ),
        Self(
            stage: "capture to editor",
            signpost: "capture",
            milliseconds: Budget.capture,
            checkedBy: "nothing deterministic; the capture itself is the system's work"
        ),
        Self(
            stage: "element detection",
            signpost: "detect",
            milliseconds: Budget.detect,
            checkedBy: "the detection fixtures, which compare what is found rather than "
                + "how long finding it took"
        ),
        Self(
            stage: "solving twenty annotations",
            signpost: "solve",
            milliseconds: Budget.solve,
            checkedBy: "the work goldens: candidates generated, search nodes and pruned "
                + "branches, which are the same number on every machine"
        ),
        Self(
            stage: "drawing a frame while dragging",
            signpost: "draw",
            milliseconds: Budget.draw,
            checkedBy: "the draw list's command count, which is what the work is "
                + "proportional to and what a golden holds"
        ),
    ]

    private enum Budget {
        static let overlay = 150
        static let capture = 400
        static let detect = 300
        static let solve = 50
        static let draw = 8
    }
}
