// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TriviaKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TriviaKit", targets: ["TriviaKit"])
    ],
    targets: [
        .target(name: "TriviaKit"),
        .testTarget(name: "TriviaKitTests", dependencies: ["TriviaKit"])
    ]
)
