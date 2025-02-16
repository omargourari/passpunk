// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PassPunk",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "PassPunk", targets: ["PassPunk"])
    ],
    targets: [
        .executableTarget(
            name: "PassPunk",
            path: "PassPunk",
            exclude: [
                "Assets.xcassets",
                "Info.plist"
            ]
        )
    ]
)