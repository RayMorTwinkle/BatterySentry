// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatterySentry",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "BatterySentry", targets: ["BatterySentry"])
    ],
    targets: [
        .executableTarget(
            name: "BatterySentry",
            path: "Sources/BatterySentry"
        )
    ]
)
