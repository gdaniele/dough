// swift-tools-version:5.9
// Dough, a macOS menu bar focus timer.
// - DoughCore: the rules, the session clock, the bank and the file on disk. Foundation only, so it's all unit tested.
// - DoughUI: the blocker and the SwiftUI views.
// - Dough: the app's entry point. Build the .app with scripts/build-app.sh.
import PackageDescription

let package = Package(
    name: "Dough",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DoughCore"),
        .target(name: "DoughUI", dependencies: ["DoughCore"]),
        .executableTarget(name: "Dough", dependencies: ["DoughUI"]),
        .testTarget(name: "DoughCoreTests", dependencies: ["DoughCore"]),
        .testTarget(name: "DoughUITests", dependencies: ["DoughCore", "DoughUI"]),
    ]
)
