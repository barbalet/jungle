# Xcode workspace

Cycle 3 uses a multi-target Swift package as the checked-in project definition.

## Why this shape

* Xcode 26 opens `Package.swift` directly and presents the package as a workspace with schemes.
* The package manifest keeps target boundaries small and reviewable while the codebase is still young.
* Build settings live in source control through the manifest instead of a hand-edited project file.
* The package layout matches the architecture document from cycle 2.

## Targets

* `JungleApp` is the SwiftUI application shell.
* `JungleRenderer` is the Metal-facing renderer module.
* `JungleShared` holds Swift data shared across modules.
* `JungleCore` is the C simulation core.
* `JungleCoreTests` validates the C core bootstrap behavior.

## Build settings captured in the manifest

* Platform floor: macOS 14.
* C language standard: C17.
* Renderer framework linkage: Metal.
* Target dependency graph aligned to the cycle 2 module boundary.

## Next step

Cycle 8 should add world-scale conventions without widening the current module boundaries.
