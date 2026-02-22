// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WhisperNotes",
            path: "Sources/WhisperNotes",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        )
    ]
)
