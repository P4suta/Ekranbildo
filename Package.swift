// swift-tools-version: 6.4
import PackageDescription

let commonSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "Ekranbildo",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "EkranbildoGeometry", targets: ["EkranbildoGeometry"]),
        .library(name: "EkranbildoObservability", targets: ["EkranbildoObservability"]),
        .library(name: "EkranbildoContracts", targets: ["EkranbildoContracts"]),
        .library(name: "EkranbildoFixtures", targets: ["EkranbildoFixtures"]),
        .library(name: "EkranbildoCore", targets: ["EkranbildoCore"]),
        .library(name: "EkranbildoField", targets: ["EkranbildoField"]),
        .library(name: "EkranbildoSemantics", targets: ["EkranbildoSemantics"]),
        .library(name: "EkranbildoLayout", targets: ["EkranbildoLayout"]),
        .library(name: "EkranbildoInspector", targets: ["EkranbildoInspector"]),
        .library(name: "EkranbildoRender", targets: ["EkranbildoRender"]),
        .library(name: "EkranbildoTestKit", targets: ["EkranbildoTestKit"]),
        .library(name: "EkranbildoImaging", targets: ["EkranbildoImaging"]),
        .library(name: "EkranbildoVision", targets: ["EkranbildoVision"]),
        .library(name: "EkranbildoCapture", targets: ["EkranbildoCapture"]),
        .library(name: "EkranbildoStitch", targets: ["EkranbildoStitch"]),
        .library(name: "EkranbildoRecord", targets: ["EkranbildoRecord"]),
        .library(name: "EkranbildoEditor", targets: ["EkranbildoEditor"]),
        .library(name: "EkranbildoRedaction", targets: ["EkranbildoRedaction"]),
        .library(name: "EkranbildoExport", targets: ["EkranbildoExport"]),
        .library(name: "EkranbildoHotkeys", targets: ["EkranbildoHotkeys"]),
        .library(name: "EkranbildoLibrary", targets: ["EkranbildoLibrary"]),
        .library(name: "EkranbildoOverlay", targets: ["EkranbildoOverlay"]),
        .library(name: "EkranbildoShell", targets: ["EkranbildoShell"]),
        .library(name: "EkranbildoTimeline", targets: ["EkranbildoTimeline"]),
        .library(name: "EkranbildoEncode", targets: ["EkranbildoEncode"]),
        .library(name: "EkranbildoRenderCoreGraphics", targets: ["EkranbildoRenderCoreGraphics"]),
        .library(name: "EkranbildoTestHooks", targets: ["EkranbildoTestHooks"]),
        .library(name: "EkranbildoSignposts", targets: ["EkranbildoSignposts"]),
        .library(name: "EkranbildoApp", targets: ["EkranbildoApp"]),
        .library(name: "EkranbildoViews", targets: ["EkranbildoViews"]),
        .library(name: "EkranbildoFuzz", type: .static, targets: ["EkranbildoFuzz"]),
        .library(name: "EkranbildoCLI", targets: ["EkranbildoCLI"]),
        .executable(name: "ekranbildo-app", targets: ["ekranbildo-app"]),
        .executable(name: "ekranbildo-cli", targets: ["ekranbildo-cli"]),
    ],
    targets: [
        .target(
            name: "EkranbildoGeometry",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoGeometryTests",
            dependencies: ["EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoObservability",
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoObservabilityTests",
            dependencies: ["EkranbildoObservability", "EkranbildoTestKit"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoContracts",
            dependencies: ["EkranbildoGeometry", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoContractsTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoFixtures",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoGeometry",
                "EkranbildoObservability",
                "EkranbildoRecord",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoFixturesTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoCore",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoCoreTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoField",
            dependencies: ["EkranbildoContracts", "EkranbildoCore", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoFieldTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoField",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoSemantics",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoSemanticsTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoSemantics",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoLayout",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoField",
                "EkranbildoGeometry",
                "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoLayoutTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoField",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoLayout",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoRender",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoGeometry",
                "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoRenderTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoRender",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoInspector",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoField",
                "EkranbildoGeometry",
                "EkranbildoLayout",
                "EkranbildoObservability",
                "EkranbildoRender",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoInspectorTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoField",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoInspector",
                "EkranbildoLayout",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoTestKit",
            dependencies: ["EkranbildoContracts"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoTestKitTests",
            dependencies: ["EkranbildoContracts", "EkranbildoTestKit"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoEncode",
            dependencies: ["EkranbildoContracts", "EkranbildoImaging", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoEncodeTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoEncode",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoTimeline",
            dependencies: ["EkranbildoContracts", "EkranbildoCore", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoTimelineTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoRender",
                "EkranbildoTestKit",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoShell",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoGeometry", "EkranbildoHotkeys",
                "EkranbildoLibrary",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoShellTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoGeometry",
                "EkranbildoHotkeys",
                "EkranbildoLibrary",
                "EkranbildoShell",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoOverlay",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry", "EkranbildoSemantics"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoOverlayTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoOverlay",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoLibrary",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoLibraryTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoGeometry",
                "EkranbildoLibrary",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoHotkeys",
            dependencies: [
                "EkranbildoGeometry", "EkranbildoContracts", "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoHotkeysTests",
            dependencies: ["EkranbildoContracts", "EkranbildoHotkeys", "EkranbildoTestKit"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoExport",
            dependencies: ["EkranbildoContracts", "EkranbildoImaging", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoExportTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoExport",
                "EkranbildoFixtures",
                "EkranbildoImaging",
                "EkranbildoRedaction",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoRedaction",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoRedactionTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoRedaction",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoEditor",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoGeometry",
                "EkranbildoLayout",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoEditorTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoEditor",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoRecord",
            dependencies: ["EkranbildoContracts"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoRecordTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoRecord",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoStitch",
            dependencies: ["EkranbildoContracts", "EkranbildoGeometry", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoStitchTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoStitch",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoCapture",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoRecord",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoCaptureTests",
            dependencies: [
                "EkranbildoCapture",
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoVision",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoVisionTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoLayout",
                "EkranbildoRender",
                "EkranbildoRenderCoreGraphics",
                "EkranbildoTestKit",
                "EkranbildoVision",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoImaging",
            dependencies: ["EkranbildoContracts", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoImagingTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoTestKit",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoRenderCoreGraphics",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoImaging",
                "EkranbildoObservability",
                "EkranbildoRender",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoRenderCoreGraphicsTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoRenderCoreGraphics",
                "EkranbildoTestKit",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoTestHooks",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoEditor", "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings + [
                .define("EKRANBILDO_TESTHOOKS", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "EkranbildoTestHooksTests",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoEditor",
                "EkranbildoFixtures",
                "EkranbildoTestHooks",
            ],
            swiftSettings: commonSwiftSettings + [
                .define("EKRANBILDO_TESTHOOKS", .when(configuration: .debug))
            ]
        ),

        .target(
            name: "EkranbildoSignposts",
            dependencies: ["EkranbildoGeometry", "EkranbildoObservability"],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoSignpostsTests",
            dependencies: ["EkranbildoGeometry", "EkranbildoObservability", "EkranbildoSignposts"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoApp",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoEditor", "EkranbildoFixtures",
                "EkranbildoGeometry", "EkranbildoInspector", "EkranbildoLayout", "EkranbildoLibrary",
                "EkranbildoOverlay", "EkranbildoShell", "EkranbildoStitch",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoAppTests",
            dependencies: [
                "EkranbildoApp", "EkranbildoContracts", "EkranbildoCore", "EkranbildoFixtures",
                "EkranbildoGeometry", "EkranbildoLibrary", "EkranbildoOverlay", "EkranbildoShell",
                "EkranbildoStitch",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoFuzz",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoGeometry", "EkranbildoObservability",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoFuzzTests",
            dependencies: ["EkranbildoContracts", "EkranbildoFuzz", "EkranbildoGeometry"],
            swiftSettings: commonSwiftSettings
        ),

        .target(
            name: "EkranbildoCLI",
            dependencies: [
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoEncode",
                "EkranbildoExport",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoInspector",
                "EkranbildoLayout",
                "EkranbildoObservability",
                "EkranbildoRecord",
                "EkranbildoRedaction",
                "EkranbildoRender",
                "EkranbildoRenderCoreGraphics",
                "EkranbildoSemantics",
                "EkranbildoStitch",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoCLITests",
            dependencies: [
                "EkranbildoCLI",
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoObservability",
                "EkranbildoFixtures",
                "EkranbildoGeometry",
                "EkranbildoImaging",
                "EkranbildoRecord",
                "EkranbildoRedaction",
                "EkranbildoTestKit",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .target(
            name: "EkranbildoViews",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoExport", "EkranbildoFixtures",
                "EkranbildoHotkeys", "EkranbildoImaging", "EkranbildoLibrary", "EkranbildoOverlay",
                "EkranbildoRender", "EkranbildoRenderCoreGraphics", "EkranbildoShell", "EkranbildoStitch",
                "EkranbildoTimeline",
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "EkranbildoViewsTests",
            dependencies: [
                "EkranbildoContracts", "EkranbildoCore", "EkranbildoExport", "EkranbildoFixtures",
                "EkranbildoGeometry", "EkranbildoImaging", "EkranbildoOverlay", "EkranbildoRender",
                "EkranbildoRenderCoreGraphics", "EkranbildoTimeline", "EkranbildoViews",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .executableTarget(
            name: "ekranbildo-app",
            dependencies: [
                "EkranbildoApp", "EkranbildoCapture", "EkranbildoContracts", "EkranbildoCore",
                "EkranbildoExport", "EkranbildoFixtures", "EkranbildoGeometry", "EkranbildoHotkeys",
                "EkranbildoImaging", "EkranbildoLibrary", "EkranbildoOverlay", "EkranbildoRender",
                "EkranbildoRedaction", "EkranbildoRenderCoreGraphics", "EkranbildoSemantics",
                "EkranbildoShell",
                "EkranbildoEncode", "EkranbildoRecord", "EkranbildoStitch",
                "EkranbildoTimeline",
                "EkranbildoViews", "EkranbildoVision",
            ],
            swiftSettings: commonSwiftSettings
        ),

        .executableTarget(
            name: "ekranbildo-cli",
            dependencies: [
                "EkranbildoGeometry",
                "EkranbildoCLI",
                "EkranbildoCapture",
                "EkranbildoContracts",
                "EkranbildoCore",
                "EkranbildoFixtures",
                "EkranbildoImaging",
                "EkranbildoRecord",
                "EkranbildoSemantics",
                "EkranbildoSignposts",
                "EkranbildoTestHooks",
                "EkranbildoTimeline",
                "EkranbildoVision",
            ],
            swiftSettings: commonSwiftSettings + [
                .define("EKRANBILDO_TESTHOOKS", .when(configuration: .debug))
            ]
        ),
    ]
)
