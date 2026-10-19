// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReminderSnap",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "ReminderSnapCore", targets: ["ReminderSnapCore"]),
        .executable(name: "ReminderSnap", targets: ["ReminderSnapApp"]),
        .executable(name: "remindersnap-cli", targets: ["ReminderSnapCLI"])
    ],
    targets: [
        .target(name: "ReminderSnapCore"),
        .executableTarget(name: "ReminderSnapApp", dependencies: ["ReminderSnapCore"]),
        .executableTarget(name: "ReminderSnapCLI", dependencies: ["ReminderSnapCore"]),
        .executableTarget(name: "ReminderSnapTests", dependencies: ["ReminderSnapCore"], path: "Tests/ReminderSnapCoreTests")
    ]
)
