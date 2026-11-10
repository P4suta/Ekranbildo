import EkranbildoContracts
import EkranbildoExport
import EkranbildoRender
import EkranbildoRenderCoreGraphics
import Foundation

public struct IconOptions: Sendable, Equatable {
    public let directory: String

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard let directory = parsed.value(of: "--out") ?? parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "somewhere to write the icon is required"
            )
        }
        self.directory = directory
    }

    static let knownFlags = ["--out"]
}

public struct NamedPicture: Sendable, Equatable {
    public let name: String
    public let png: [UInt8]

    public init(name: String, png: [UInt8]) {
        self.name = name
        self.png = png
    }
}

public struct IconOutputs: Sendable, Equatable {
    public let pngs: [NamedPicture]
}

public struct IconCommand: Sendable {
    public init() {}

    public func run() throws -> IconOutputs {
        IconOutputs(
            pngs: try Self.wanted.map { wanted in
                NamedPicture(
                    name: wanted.name,
                    png: try Self.png(side: wanted.side, scale: wanted.scale)
                )
            })
    }

    struct Wanted: Sendable, Equatable {
        let name: String
        let side: Int
        let scale: Int
    }

    static var wanted: [Wanted] {
        ApplicationIcon.sizes.flatMap { side in
            [
                Wanted(name: "icon_\(side)x\(side).png", side: side, scale: 1),
                Wanted(name: "icon_\(side)x\(side)@2x.png", side: side, scale: 2),
            ]
        }
    }

    static func png(side: Int, scale: Int) throws -> [UInt8] {
        let rendered = try CoreGraphicsRenderer()
            .render(ApplicationIcon.drawList(side: Double(side)), scale: Double(scale))
        return try Exporter().export(rendered.bitmap.imageBuffer, as: .png)
    }
}
