// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XMarkup",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "XMarkup", targets: ["XMarkup"]),
    ],
    targets: [
        .target(
            name: "CXMarkup",
            path: "core",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("src"),
            ]
        ),
        .target(
            name: "XMarkup",
            dependencies: ["CXMarkup"],
            path: "platforms/ios/Sources/XMarkup"
        ),
        .testTarget(
            name: "XMarkupTests",
            dependencies: ["XMarkup"],
            path: "platforms/ios/Tests/XMarkupTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
