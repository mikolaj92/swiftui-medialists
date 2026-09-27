// swift-tools-version: 6.2
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
        .target(name: "SwiftUIMediaLists"),
        .testTarget(name: "SwiftUIMediaListsTests", dependencies: ["SwiftUIMediaLists"]),
        .testTarget(name: "SwiftUIMediaListsConsumerTests", dependencies: ["SwiftUIMediaLists"])
    ]
)
