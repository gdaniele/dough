// swift-tools-version:5.9
// Pizzeria, a macOS menu bar focus timer.
// - PizzeriaCore: the rules, the session clock, the bank and the file on disk. Foundation only, so it's all unit tested.
// - PizzeriaUI: the blocker and the SwiftUI views.
// - Pizzeria: the app's entry point. Build the .app with scripts/build-app.sh.
import PackageDescription

let package = Package(
    name: "Pizzeria",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PizzeriaCore"),
        .target(name: "PizzeriaUI", dependencies: ["PizzeriaCore"]),
        .executableTarget(name: "Pizzeria", dependencies: ["PizzeriaUI"]),
        .testTarget(name: "PizzeriaCoreTests", dependencies: ["PizzeriaCore"]),
        .testTarget(name: "PizzeriaUITests", dependencies: ["PizzeriaCore", "PizzeriaUI"]),
    ]
)
