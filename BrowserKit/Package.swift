// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "BrowserKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SiteImageView",
            targets: ["SiteImageView"]),
        .library(name: "MozillaAppServices", targets: ["MozillaAppServices"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/nbhasin2/Fuzi.git",
            branch: "master"),
        .package(
            url: "https://github.com/onevcat/Kingfisher.git",
            exact: "7.2.2"),
    ],
    targets: [
        /*
        * A placeholder wrapper for our binaryTarget so that Xcode will ensure this is
        * downloaded/built before trying to use it in the build process
        * A bit hacky but necessary for now https://github.com/mozilla/application-services/issues/4422
        */
        .target(
            name: "MozillaRustComponentsWrapper",
            dependencies: [
                .target(name: "MozillaRustComponents", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/MozillaRustComponentsWrapper"
        ),
        .binaryTarget(
            name: "MozillaRustComponents",
            path: "./bin/MozillaRustComponents.xcframework"
        ),
        .target(
            name: "MozillaAppServices",
            dependencies: ["MozillaRustComponentsWrapper"],
            path: "Sources/application-services/"
        ),
        .target(
            name: "SiteImageView",
            dependencies: ["Fuzi", "Kingfisher"]),
        .testTarget(
            name: "SiteImageViewTests",
            dependencies: ["SiteImageView"]),
    ]
)
