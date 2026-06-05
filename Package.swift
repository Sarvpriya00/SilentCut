// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SilenceEditor",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SilenceEditor", targets: ["SilenceEditor"])
    ],
    targets: [
        .executableTarget(
            name: "SilenceEditor",
            dependencies: [],
            path: "SilenceEditor",
            exclude: ["Tests"],
            sources: [
                "App",
                "Models",
                "Services",
                "ViewModels",
                "Views",
                "Components",
                "Utilities",
                "Resources"
            ]
        ),
        .testTarget(
            name: "SilenceEditorTests",
            dependencies: ["SilenceEditor"],
            path: "SilenceEditor/Tests"
        )
    ]
)
