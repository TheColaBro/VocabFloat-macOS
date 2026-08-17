// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VocabFloat",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "VocabFloat", targets: ["VocabFloat"])
    ],
    targets: [
        .executableTarget(
            name: "VocabFloat",
            resources: [.process("Resources")]
        )
    ]
)
