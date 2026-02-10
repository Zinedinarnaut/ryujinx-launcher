// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RyjinxLauncher",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "RyjinxLauncher", targets: ["RyjinxLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "RyjinxLauncher",
            path: "Sources/RyjinxLauncher",
            resources: [
                .process("Metal")
            ]
        )
    ]
)
