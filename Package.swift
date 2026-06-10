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
        .library(name: "XMarkupUI", targets: ["XMarkupUI"]),
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
        .target(
            name: "XMarkupUI",
            dependencies: ["XMarkup"],
            path: "platforms/ios/Sources/XMarkupUI"
        ),
        .testTarget(
            name: "XMarkupTests",
            dependencies: ["XMarkup"],
            path: "platforms/ios/Tests/XMarkupTests"
        ),
        .testTarget(
            name: "XMarkupUITests",
            dependencies: ["XMarkupUI"],
            path: "platforms/ios/Tests/XMarkupUITests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
