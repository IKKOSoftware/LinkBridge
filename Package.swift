// swift-tools-version: 6.0
//
// LinkBridge: Ableton Link in a process of its own, serving the shared timeline over gRPC on a local socket.
// GPL v2 or later, like Link (see COPYING.md). The protocol (Protos/link_bridge.proto) is MIT licensed.

import PackageDescription

let package = Package(
    name: "LinkBridge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "link-bridge", targets: ["link-bridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
    ],
    targets: [
        // Ableton Link's C++ SDK (header only) and ASIO, vendored, behind a small C interface
        .target(
            name: "CLink",
            exclude: ["vendor"],
            cxxSettings: [
                .headerSearchPath("vendor/link/include"),
                .headerSearchPath("vendor/asio/include"),
                .define("LINK_PLATFORM_UNIX", to: "1"),
                .define("LINK_PLATFORM_MACOSX", to: "1"),
            ]
        ),
        // Generated from Protos/link_bridge.proto by Scripts/generate.sh
        .target(
            name: "LinkBridgeProtocol",
            dependencies: [
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "link-bridge",
            dependencies: [
                "CLink",
                "LinkBridgeProtocol",
                .product(name: "GRPC", package: "grpc-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
