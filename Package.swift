// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Cvoxtral",
            path: "Sources/Cvoxtral",
            exclude: ["voxtral_shaders.metal", "LICENSE"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("USE_BLAS"),
                .define("USE_METAL"),
                .define("ACCELERATE_NEW_LAPACK"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalPerformanceShaders"),
                .linkedFramework("MetalPerformanceShadersGraph"),
                .linkedFramework("Foundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .target(
            name: "WhisperNotesLib",
            dependencies: ["Cvoxtral"],
            path: "Sources/WhisperNotes",
            resources: [
                .copy("Resources/CohereBackend"),
            ],
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
