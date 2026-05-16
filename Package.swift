// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Sideline",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SidelineCore", targets: ["Shared"]),
        .executable(name: "Sideline", targets: ["Sideline"])
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Shared"
        ),
        .executableTarget(
            name: "Sideline",
            dependencies: ["Shared"],
            path: "Sideline",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Sideline.entitlements",
                "copy/PAYWALL.md"
            ]
        ),
        .testTarget(
            name: "SidelineTests",
            dependencies: ["Shared"],
            path: "Tests/SidelineTests"
        )
    ]
)
