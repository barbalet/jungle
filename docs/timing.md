# Engine timing

Cycle 5 defines the timing and frame pacing policy for the current scaffold.

## Policy

* Render pacing target: 60 frames per second.
* Simulation update mode: fixed step.
* Fixed simulation step: 1/60 second.
* Maximum accepted frame delta before clamping: 100 milliseconds.
* Maximum catch-up work in one pacing tick: 3 simulation steps.
* Maximum retained lag after catch-up: 1 fixed step.

## Ownership

* `JungleEngineCoordinator` owns pacing and simulation stepping.
* `JungleShared` owns the fixed-step planning rules so they can be tested without UI code.
* `JungleCore` receives deterministic `delta_seconds` values and emits timing fields in its snapshot.
* `JungleRenderer` consumes snapshots and honors the pacing target for the Metal view.

## Why this shape

* A fixed step keeps the simulation deterministic while the renderer stays free to evolve separately.
* Delta clamping prevents one long stall from flooding the engine with catch-up work.
* Catch-up caps avoid a spiral-of-death loop where the app falls behind and never recovers.
* Retaining at most one step of lag preserves short-term responsiveness without carrying an unbounded backlog.

## Next step

Cycle 19 should carry this fixed-step traversal into the shallow-water prototype without widening the timing boundary.
