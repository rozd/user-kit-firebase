// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UserKitFirebase",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "UserKitFirebase",
            targets: ["UserKitFirebase"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/rozd/user-kit", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "12.12.1"),
        // The app pins this by the `fetchsigninwithemail-feature` branch, but that branch was
        // deleted upstream after PR #1330 merged; only the commit (refs/pull/1330/head) survives.
        // Pin the exact revision the app resolves so a fresh checkout doesn't chase a dead branch.
        .package(url: "https://github.com/firebase/FirebaseUI-iOS", revision: "757487a73c4d1728378d6f2ac8832ec380f76e99"),
    ],
    targets: [
        .target(
            name: "UserKitFirebase",
            dependencies: [
                .product(name: "UserKit", package: "user-kit"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuthSwiftUI", package: "firebaseui-ios"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
        .testTarget(
            name: "UserKitFirebaseTests",
            dependencies: ["UserKitFirebase"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
    ]
)
