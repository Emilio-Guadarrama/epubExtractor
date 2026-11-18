// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EpubExtractor",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "EpubExtractor", targets: ["EpubExtractor"]),
        .library(name: "ReadAloudCore", targets: ["ReadAloudCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/tadija/AEXML.git", from: "4.6.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "EpubExtractor",
            dependencies: [
                .product(name: "AEXML", package: "AEXML"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .target(name: "ReadAloudCore"),
        .testTarget(
            name: "EpubExtractorTests",
            dependencies: ["EpubExtractor"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ReadAloudCoreTests",
            dependencies: ["ReadAloudCore"]
        )
    ]
)
