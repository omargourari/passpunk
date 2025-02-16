// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PassPunk",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "PassPunk",
            targets: ["PassPunk"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PassPunk",
            path: "PassPunk",
            resources: [
                .process("Assets.xcassets"),
                .copy("PassPunk.entitlements"),
                .copy("com.passpunk.launcher.plist")
            ]
        )
    ]
)

