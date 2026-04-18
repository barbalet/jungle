# Engine math

Cycle 6 adds the first reusable C math layer for the engine core.

## Scope

* Vector primitives: `jungle_vec2`, `jungle_vec3`, `jungle_vec4`.
* Matrix primitive: `jungle_mat4` with column-major storage.
* Transform primitive: `jungle_transform`.
* Deterministic noise helpers for hashed value noise and normalized fractal noise.

## API surface

* [jungle_math.h](/Users/barbalet/github/jungle/Sources/Core/include/jungle_math.h:1) exposes the public types and functions.
* [jungle_math.c](/Users/barbalet/github/jungle/Sources/Core/jungle_math.c:1) implements the math routines inside the core module.
* [JungleMathTests.swift](/Users/barbalet/github/jungle/Tests/CoreTests/JungleMathTests.swift:1) validates the new math behavior from Swift.

## Design choices

* Matrices are column-major so later camera and render code can share the same convention.
* Transform composition order is fixed and documented to keep scene graph math predictable.
* Noise stays deterministic for a given seed and coordinate pair.
* The noise helpers normalize results to `0...1` so terrain and foliage systems can build on them directly.

## Next step

Cycle 19 should reuse this math layer for the first shallow-water surface and shoreline transition work.
