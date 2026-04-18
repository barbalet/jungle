import XCTest
import JungleCore

final class JungleWorldTests: XCTestCase {
    func testSeededTerrainPatchIsDeterministic() {
        var config = jungle_engine_config()
        config.seed = 7
        config.graphics_quality = UInt32(JUNGLE_GRAPHICS_QUALITY_LOW.rawValue)
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_GRASSLAND.rawValue)

        let firstEngine = jungle_engine_create(&config)
        let secondEngine = jungle_engine_create(&config)

        XCTAssertNotNil(firstEngine)
        XCTAssertNotNil(secondEngine)
        defer {
            jungle_engine_destroy(firstEngine)
            jungle_engine_destroy(secondEngine)
        }

        var firstSnapshot = jungle_frame_snapshot()
        var secondSnapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(firstEngine, &firstSnapshot)
        jungle_engine_snapshot_copy(secondEngine, &secondSnapshot)

        let firstHeights = copyArray(
            from: firstSnapshot.terrain_heights,
            count: Int(firstSnapshot.terrain_patch_side * firstSnapshot.terrain_patch_side),
            as: Double.self
        )
        let secondHeights = copyArray(
            from: secondSnapshot.terrain_heights,
            count: Int(secondSnapshot.terrain_patch_side * secondSnapshot.terrain_patch_side),
            as: Double.self
        )

        XCTAssertEqual(firstSnapshot.biome_kind, secondSnapshot.biome_kind)
        XCTAssertEqual(firstSnapshot.weather_kind, secondSnapshot.weather_kind)
        XCTAssertEqual(firstHeights, secondHeights)
    }

    func testDifferentSeedsProduceDifferentTerrainSamples() {
        var firstConfig = jungle_engine_config()
        firstConfig.seed = 11
        firstConfig.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_GRASSLAND.rawValue)

        var secondConfig = jungle_engine_config()
        secondConfig.seed = 12
        secondConfig.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_GRASSLAND.rawValue)

        let firstEngine = jungle_engine_create(&firstConfig)
        let secondEngine = jungle_engine_create(&secondConfig)

        XCTAssertNotNil(firstEngine)
        XCTAssertNotNil(secondEngine)
        defer {
            jungle_engine_destroy(firstEngine)
            jungle_engine_destroy(secondEngine)
        }

        var firstSnapshot = jungle_frame_snapshot()
        var secondSnapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(firstEngine, &firstSnapshot)
        jungle_engine_snapshot_copy(secondEngine, &secondSnapshot)

        let firstHeights = copyArray(
            from: firstSnapshot.terrain_heights,
            count: Int(firstSnapshot.terrain_patch_side * firstSnapshot.terrain_patch_side),
            as: Double.self
        )
        let secondHeights = copyArray(
            from: secondSnapshot.terrain_heights,
            count: Int(secondSnapshot.terrain_patch_side * secondSnapshot.terrain_patch_side),
            as: Double.self
        )

        XCTAssertNotEqual(firstHeights.first, secondHeights.first)
    }

    func testTerrainCollisionMaintainsConfiguredEyeHeight() {
        var config = jungle_engine_config()
        config.seed = 27
        config.initial_camera_height = 1.75
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_JUNGLE.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var input = jungle_input_state()
        input.move_forward = 1.0
        input.move_right = 0.35

        for _ in 0..<12 {
            jungle_engine_step(engine, &input, 0.25)
        }

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.camera_height - snapshot.camera_floor_height, 1.75, accuracy: 0.0001)
    }

    func testJungleSelectionStartsInDenseHumidBiome() {
        var config = jungle_engine_config()
        config.seed = 91
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_JUNGLE.rawValue)
        config.graphics_quality = UInt32(JUNGLE_GRAPHICS_QUALITY_HIGH.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.biome_kind, UInt32(JUNGLE_BIOME_KIND_JUNGLE.rawValue))
        XCTAssertEqual(snapshot.weather_kind, UInt32(JUNGLE_WEATHER_KIND_HUMID_CANOPY.rawValue))
        XCTAssertEqual(snapshot.terrain_patch_side, 33)
        XCTAssertLessThan(snapshot.visibility_distance, 40.0)
        XCTAssertGreaterThan(snapshot.ambient_wetness, 0.5)
    }

    func testBeachSelectionStartsInOpenCoastalBiome() {
        var config = jungle_engine_config()
        config.seed = 91
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_BEACH.rawValue)
        config.graphics_quality = UInt32(JUNGLE_GRAPHICS_QUALITY_HIGH.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.biome_kind, UInt32(JUNGLE_BIOME_KIND_BEACH.rawValue))
        XCTAssertEqual(snapshot.weather_kind, UInt32(JUNGLE_WEATHER_KIND_COASTAL_HAZE.rawValue))
        XCTAssertEqual(snapshot.camera_position.x, 176.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_position.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.terrain_patch_side, 33)
        XCTAssertGreaterThan(snapshot.visibility_distance, 80.0)
        XCTAssertGreaterThan(snapshot.shoreline_space, 0.2)
        XCTAssertLessThan(snapshot.ambient_wetness, 0.55)
        XCTAssertGreaterThan(snapshot.ground_material.red, snapshot.ground_material.blue)
    }

    private func copyArray<Element, Storage>(
        from storage: Storage,
        count: Int,
        as elementType: Element.Type
    ) -> [Element] {
        withUnsafeBytes(of: storage) { rawBuffer in
            Array(rawBuffer.bindMemory(to: elementType).prefix(count))
        }
    }
}
