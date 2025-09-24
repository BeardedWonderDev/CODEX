// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BasicAgInventory",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BasicAgInventory",
            targets: ["BasicAgInventory"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BasicAgInventory",
            dependencies: [],
            resources: [
                .process("BasicAgInventory.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "BasicAgInventoryTests",
            dependencies: ["BasicAgInventory"]),
    ]
)