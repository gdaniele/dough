// swift-tools-version:5.9
// Panificio, a macOS menu bar focus timer.
// - PanificioCore: the rules, the session clock, the bank and the file on disk. Foundation only, so it's all unit tested.
// - PanificioUI: the blocker and the SwiftUI views.
// - Panificio: the app's entry point. Build the .app with scripts/build-app.sh.
import PackageDescription

let package = Package(
    name: "Panificio",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PanificioCore"),
        .target(name: "PanificioUI", dependencies: ["PanificioCore"]),
        .executableTarget(name: "Panificio", dependencies: ["PanificioUI"]),
        .testTarget(name: "PanificioCoreTests", dependencies: ["PanificioCore"]),
        .testTarget(name: "PanificioUITests", dependencies: ["PanificioCore", "PanificioUI"]),
    ]
)
