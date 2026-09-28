// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SwiftUIMediaLists",
    platforms: [
        .iOS(.v26),
        .tvOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "SwiftUIMediaLists", targets: ["SwiftUIMediaLists"])
    ],
    targets: [
        .target(name: "SwiftUIMediaLists", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "SwiftUIMediaListsTests", dependencies: ["SwiftUIMediaLists"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "SwiftUIMediaListsConsumerTests", dependencies: ["SwiftUIMediaLists"], swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
