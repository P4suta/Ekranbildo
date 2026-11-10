import EkranbildoGeometry
import EkranbildoObservability
import Foundation
import os

public struct SystemSignposts: SignpostEmitting {
    private let log: OSLog

    public init(subsystem: String = Defaults.subsystem, category: String = Defaults.category) {
        log = OSLog(subsystem: subsystem, category: category)
    }

    public enum Defaults {
        public static let subsystem = "app.ekranbildo.Ekranbildo"
        public static let category = "stages"
    }

    public func began(_ name: String) {
        os_signpost(.begin, log: log, name: Self.interval, "%{public}s", name)
    }

    public func ended(_ name: String) {
        os_signpost(.end, log: log, name: Self.interval, "%{public}s", name)
    }

    public func happened(_ name: String) {
        os_signpost(.event, log: log, name: Self.interval, "%{public}s", name)
    }

    private static let interval: StaticString = "stage"
}

public enum Signposting {
    public static func emitter(
        environment: Lookup<String, String>
    ) -> any SignpostEmitting {
        let value = environment[Variable.name] ?? ""
        return value == Variable.on || value.lowercased() == Variable.alsoOn
            ? SystemSignposts() : NoSignposts()
    }

    private enum Variable {
        static let name = "EKRANBILDO_SIGNPOSTS"
        static let on = "1"
        static let alsoOn = "true"
    }
}
