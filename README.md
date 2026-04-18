# jungle

# Definition

Jungle is a first person perspective graphics engine designed to display:

* jungle
* grassland
* beach
* shallow water
* deep water

Jungle first person perspective for the Mac. It is written with METAL, SwiftUI and an engine core in C. It is anticipated that this engine can be defined in 100 cycles of work and the engine can be time reviewed at:

	25 cycles - first demo
	50 cycles - alpha review
	75 cycles - beta review

This README also includes the current cycle information for ease of review:

18

It is imagined that rather than hard surfaces, the engine is made with sinusoidal output of three or four alpha plains that undulate to simulate ground-cover, waist height plants, head height plants and high plants represented like fern fonds cutting out the light.

In addition the sky should be rendered with time-of-day and weather cover. This should also bring various categories of rain.

Adding to the engine requirements the characters that move through the environment are apes of various sizes and ages. As with the abstract procedural generation of the trees, the apes should also be shown to be a variety of ages, sizers and battle injuries.

## Development cycles

Current cycle output: cycles 8 through 18 now define the world scale, launch configuration, detached debug panels, seeded terrain mesh, layered material channels, terrain-aware camera collision, and the first grassland, jungle, and beach biome prototypes with shoreline-space metrics and coastal haze. The behavior is summarized in [docs/world.md](docs/world.md).

### Cycles 1-25: Foundation and first demo

1. Establish the full 100-cycle roadmap, milestone definitions and engineering assumptions.
2. Define module boundaries between the SwiftUI shell, Metal renderer and C simulation core.
3. Create the Xcode workspace, build settings and app target skeleton.
4. Bring up a Metal-backed view inside SwiftUI with a stable render loop.
5. Establish engine timing, frame pacing and fixed/update step policy.
6. Implement math primitives in C for vectors, matrices, transforms and noise helpers.
7. Add a first-person camera model, movement controls and projection setup.
8. Define a world scale, unit system and coordinate conventions for every biome.
9. Build a configuration system for seeds, graphics options and debug toggles.
10. Create a debug HUD for FPS, camera position, biome, weather and seed values.
11. Generate the first procedural ground mesh as a continuous walkable surface.
12. Layer sinusoidal height bands to shape ground-cover, waist, head and canopy zones.
13. Implement material channels for color, alpha, motion and wetness response.
14. Add collision against the ground plane and stable camera height handling.
15. Introduce deterministic world seeding so scenes can be reproduced exactly.
16. Prototype the grassland biome with sparse vegetation and long sight lines.
17. Prototype the jungle biome with dense layered vegetation and heavy occlusion.
18. Prototype the beach biome with flatter terrain, sand coloration and shoreline space.
19. Prototype shallow water zones with transparency and gentle surface motion.
20. Prototype deep water zones with color falloff and stronger depth cues.
21. Create the first sky gradient with sun direction and horizon blending.
22. Add fog and humidity falloff to improve depth perception in dense scenes.
23. Wire a basic directional lighting model across terrain and vegetation.
24. Integrate the five environment types into a single guided demo path.
25. Run the first demo review and capture the next block of issues.

### Cycles 26-50: Alpha build

26. Convert first demo notes into an alpha backlog with priorities and acceptance checks.
27. Replace ad hoc constants with data-driven biome parameter sets.
28. Introduce world chunking and streaming boundaries for larger traversal spaces.
29. Build foliage instancing so dense scenes render without duplicating mesh data.
30. Add alpha-cutout plant rendering for leaf cards, fronds and layered grass.
31. Animate plant sway using shared wind parameters and per-instance variation.
32. Expand terrain texturing to support sand, mud, grass and wet ground blends.
33. Add time-of-day states for dawn, day, dusk and night transitions.
34. Render cloud cover layers that influence light intensity and sky color.
35. Implement light rain with droplets, surface darkening and visibility changes.
36. Implement heavy rain with denser particle fields, stronger wetness and reduced range.
37. Improve shallow water shading with wave direction, ripples and edge blending.
38. Improve deep water shading with color absorption, darker depths and horizon continuity.
39. Blend shoreline transitions so beach, shallow water and terrain meet cleanly.
40. Define the ape system architecture, data model and rendering hooks.
41. Build a simple ape body rig or segmented proxy suitable for procedural animation.
42. Add age and size parameter ranges for juveniles, adults and elders.
43. Add battle-injury variation slots for scars, missing fur, posture and asymmetry.
44. Implement basic navigation targets so apes can move through open terrain.
45. Add idle, walk and run motion cycles driven by speed and terrain slope.
46. Introduce frustum culling and coarse visibility pruning for vegetation and apes.
47. Profile CPU and GPU hotspots using representative jungle and beach scenes.
48. Tighten memory ownership between Swift, Metal and the C core.
49. Stabilize the alpha feature set and prepare review scenes for inspection.
50. Hold the alpha review and convert findings into beta objectives.

### Cycles 51-75: Beta build

51. Reprioritize the roadmap based on alpha review findings and performance data.
52. Refine first-person movement, acceleration and camera comfort.
53. Improve terrain collision on slopes, shoreline edges and layered vegetation.
54. Add canopy-aware lighting so dense jungle cover meaningfully changes exposure.
55. Introduce a shadow strategy for terrain, foliage layers and moving apes.
56. Smooth transitions between weather states instead of abrupt toggles.
57. Add storm conditions with darker skies, stronger wind and intense rainfall.
58. Expand biome density controls for foliage coverage, plant height and openness.
59. Blend biome borders so jungle, grassland and beach can coexist in one world.
60. Add foam, sediment tint and wave interruption at the shoreline.
61. Support shallow-water viewing with distortion, depth tint and color shift.
62. Add small-group ape behaviors such as following, spacing and alert reactions.
63. Tie injury presentation into behavior so wounded apes move and rest differently.
64. Tune age, size and injury combinations so ape silhouettes stay legible at range.
65. Introduce spawn rules that vary ape encounters by biome, time and weather.
66. Add level-of-detail reduction for foliage geometry and alpha complexity.
67. Add level-of-detail reduction for apes, animation cost and update frequency.
68. Reduce synchronization stalls between the simulation core and render submission.
69. Tune frame budgets across target Mac hardware classes.
70. Build a SwiftUI settings and debug panel for seed, biome, weather and time controls.
71. Add deterministic scene presets for review, regression checking and captures.
72. Create repeatable capture paths to compare visuals across builds.
73. Harden error handling, assertions and crash logging around the engine core.
74. Polish the beta feature set and close the most visible immersion breaks.
75. Run the beta review and lock the final release priorities.

### Cycles 76-100: Release candidate and handoff

76. Convert beta feedback into a release candidate punch list.
77. Perform a full art-direction pass on color, contrast, fog and atmospheric cohesion.
78. Tune sunrise, noon, sunset and night presets across every biome.
79. Validate the full weather matrix against each biome and time-of-day combination.
80. Refine traversal pacing so each environment feels distinct but coherent.
81. Eliminate remaining seams between terrain layers, water edges and biome borders.
82. Polish ape animation blending, turns, stops and terrain response.
83. Expand visual diversity in apes through fur tone, body proportion and scar combinations.
84. Curate showcase routes that demonstrate jungle, grassland, beach and water transitions.
85. Add an in-app control and review overlay for first-time demonstrations.
86. Build a benchmark suite for low, medium and high-density scenes.
87. Add smoke-test coverage for startup, traversal, weather change and ape spawning.
88. Prepare packaging, app metadata, icons and distribution settings for external review.
89. Draft release notes covering engine scope, known limitations and review guidance.
90. Improve accessibility-related control options such as sensitivity and inversion settings.
91. Add a performance mode that lowers density and effect cost on weaker Macs.
92. Add a quality mode that enables richer foliage, weather and water fidelity.
93. Resolve remaining high-severity crashes, leaks and frame-time spikes.
94. Document the engine architecture, render pipeline and C core boundaries.
95. Document procedural generation rules for terrain, vegetation, weather and apes.
96. Execute a final QA pass across seeds, settings and target hardware profiles.
97. Produce the release candidate build and validate installation and startup behavior.
98. Fix release blockers discovered during release candidate testing.
99. Sign off the 100-cycle build as the initial complete engine definition.
100. Record a postmortem and seed the backlog for the next 100-cycle program.

## Contact

barbalet at gmail dot com
