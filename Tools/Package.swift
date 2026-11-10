// swift-tools-version: 6.4
import PackageDescription

let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "ekranbildo-dev",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0")
    ],
    targets: [
        .target(
            name: "DevKit",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "ekranbildo-dev",
            dependencies: ["DevKit"],
            swiftSettings: settings
        ),
        .testTarget(
            name: "DevKitTests",
            dependencies: ["DevKit"],
            swiftSettings: settings
        ),
    ]
)
