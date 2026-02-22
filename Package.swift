// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "WhisperNotesLib",
            path: "Sources/WhisperNotes",
            exclude: ["WhisperNotesApp.swift"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "WhisperNotes",
            dependencies: ["WhisperNotesLib"],
            path: "Sources/WhisperNotesApp"
        ),
        .testTarget(
            name: "WhisperNotesTests",
            dependencies: ["WhisperNotesLib"]
        ),
    ]
)
