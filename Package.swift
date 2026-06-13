// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemoteInfo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RemoteInfo", targets: ["RemoteInfoApp"])
    ],
    targets: [
        .target(
            name: "RemoteInfoCore"
        ),
        .executableTarget(
            name: "RemoteInfoApp",
            dependencies: ["RemoteInfoCore"]
        ),
        .testTarget(
            name: "RemoteInfoCoreTests",
            dependencies: ["RemoteInfoCore"]
        )
    ]
)
