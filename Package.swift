// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShadKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Design tokens + the shadcn/ui primitive set.
        .library(name: "ShadcnUI", targets: ["ShadcnUI"]),
        // Vercel AI Elements, ported on top of ShadcnUI.
        .library(name: "AIElementsUI", targets: ["AIElementsUI"]),
        // Node-graph canvas. Separate so consumers who don't want a graph
        // editor don't pay for it.
        .library(name: "CanvasUI", targets: ["CanvasUI"]),
        // Living showcase of every component. Ships with the package so any
        // consumer can drop it in a window and eyeball the whole set.
        .library(name: "AIElementsGallery", targets: ["AIElementsGallery"]),
    ],
    targets: [
        // `swift run ShadKitDemo` opens the gallery in a window.
        .executableTarget(
            name: "ShadKitDemo",
            dependencies: ["AIElementsGallery", "ShadcnUI"]
        ),
        .target(name: "ShadcnUI"),
        .target(name: "AIElementsUI", dependencies: ["ShadcnUI"]),
        .target(name: "CanvasUI", dependencies: ["ShadcnUI"]),
        .target(name: "AIElementsGallery", dependencies: ["ShadcnUI", "AIElementsUI", "CanvasUI"]),
        .testTarget(
            name: "ShadKitTests",
            dependencies: ["ShadcnUI", "AIElementsUI", "CanvasUI", "AIElementsGallery"]),
    ]
)
