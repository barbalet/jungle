# World foundation

This document captures the combined output for cycles 8 through 18.

## Scope

These cycles moved the engine from camera-only scaffolding into the first seeded world prototype.

* Cycle 8 defines the world scale and unit conventions.
* Cycle 9 extends launch configuration with graphics quality and starting-biome selection.
* Cycle 10 surfaces biome, weather, FPS, and terrain state through the detached debug panels.
* Cycles 11 through 15 generate and render a deterministic terrain patch with material channels and terrain-aware camera height.
* Cycles 16 through 18 add the first grassland, jungle, and beach biome prototypes.

## World scale

The current convention is simple and explicit.

* `1.0` world unit equals `1.0` meter.
* The camera eye height is driven by launch configuration and defaults to `1.7` units.
* Vegetation bands are expressed relative to terrain floor height:
  * ground-cover band: `0.35` units
  * waist band: `1.10` units
  * head band: `1.80` units
  * canopy band: `4.80` units
* Forward remains positive `Z`, right remains positive `X`, and up remains positive `Y`.

## Configuration

The launch configuration now includes:

* Seed
* Initial camera height
* Graphics quality: low, medium, high
* Starting biome selection: automatic, grassland, jungle, beach
* Debug preferences for detached panels and future render diagnostics

Graphics quality currently controls terrain patch density:

* low: `17 x 17` samples at `3.0` units spacing
* medium: `25 x 25` samples at `2.0` units spacing
* high: `33 x 33` samples at `1.5` units spacing

## Terrain snapshot

Each frame snapshot now carries:

* Active biome and weather kind
* Biome blend value
* World-scale metrics
* Terrain patch center, spacing, and samples
* Layer weights for ground-cover, waist, head, and canopy bands
* Material channels for color, alpha, motion, and wetness response
* Visibility distance and ambient wetness
* Shoreline-space openness for coastal debug and future water integration
* Camera floor height for collision/debug review

The renderer uses that snapshot to build a terrain mesh every frame and shades it with biome-aware fog, wetness cues, and coastal sky variation.

## Biome prototypes

### Grassland

* Lower canopy and head-layer density
* Longer visibility range
* Brighter sky and drier ground response
* Sparse vegetation weighting with open sight lines

### Jungle

* Heavier canopy and head-layer density
* Shorter visibility range
* Darker, wetter material response
* Dense layered vegetation cues and stronger atmospheric occlusion

### Beach

* Flatter terrain shaping with low dune-style relief
* Sand-forward ground materials with sparse coastal scrub
* Longer visibility range with brighter coastal haze
* Shoreline-space metric reserved for the next shallow-water cycle

The current world trends from grassland through jungle and out to beach terrain as you move east, with seed-driven noise preventing the transitions from feeling like hard straight seams.

## Collision

The camera no longer rides a fixed flat plane.

* Horizontal movement is still first-person camera motion.
* After every simulation step the engine samples terrain height below the camera.
* Camera `Y` is reset to `terrain floor + configured eye height`.
* The result is a stable eye line over rolling seeded terrain.

## Verification

Current automated checks cover:

* deterministic terrain patch generation for matching seeds
* differing terrain for different seeds
* terrain-aware eye-height preservation
* jungle-biome startup behavior
* beach-biome startup behavior
* existing camera, timing, math, and engine-step behavior
