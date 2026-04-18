# Xcode workspace

The repo now has two supported Xcode entry points:

* `Package.swift` remains the lightweight source-controlled target graph for SwiftPM builds.
* `jungle.xcodeproj` is the native macOS app project for opening and running the app directly in Xcode.

## Why this shape

* The Swift package still keeps the module graph small and reviewable while the codebase is moving quickly.
* The checked-in Xcode project mirrors that same module split so the Mac app can be built and run without relying on package-only workspace behavior.
* Both entry points stay aligned to the architecture document from cycle 2.

## Targets

* The `jungle` app target is the runnable macOS shell.
* `JungleRenderer` is the Metal-facing renderer module.
* `JungleShared` holds Swift data shared across modules.
* `JungleCore` is the C simulation core.
* The Swift package still hosts `JungleCoreTests` and `JungleSharedTests` for command-line test runs.

## Build settings captured in the manifest

* Platform floor: macOS 14.
* C language standard: C17.
* Renderer framework linkage: Metal and MetalKit.
* Target dependency graph aligned to the cycle 2 module boundary.

## Next step

Open `jungle.xcodeproj` in Xcode when you want a native run target for macOS, or use `swift build` / `swift test` when you want the package workflow. The next planned terrain-facing cycle is cycle 19, which adds the first shallow-water prototype to the new beach shoreline.
