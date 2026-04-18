# Engine camera

Cycle 7 adds the first-person camera model, movement controls and projection setup.

## Scope

* `jungle_camera` defines position, yaw, pitch, field of view and clip planes.
* The engine step now consumes movement and look inputs as part of `jungle_input_state`.
* The engine snapshot now exposes camera position, direction, yaw, pitch and aspect ratio.
* The SwiftUI shell forwards keyboard and drag-look input into the fixed-step loop.

## Control mapping

* `W` and `S`: move forward and backward.
* `A` and `D`: strafe left and right.
* Arrow keys: look left, right, up and down.
* Drag inside the Metal viewport: mouse-look.

## API surface

* [jungle_camera.h](/Users/barbalet/github/jungle/Sources/Core/include/jungle_camera.h:1) exposes the camera model and projection helpers.
* [jungle_camera.c](/Users/barbalet/github/jungle/Sources/Core/jungle_camera.c:1) implements orientation, view and projection math.
* [jungle_engine.h](/Users/barbalet/github/jungle/Sources/Core/include/jungle_engine.h:1) now carries camera-aware input and snapshot fields.

## Next step

Cycle 19 should extend this first-person traversal across the beach edge and into the first shallow-water prototype.
