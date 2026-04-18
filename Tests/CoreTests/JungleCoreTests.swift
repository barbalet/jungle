import XCTest
import JungleCore

final class JungleCoreTests: XCTestCase {
    func testBootstrapSnapshotUsesConfiguredCameraHeight() {
        var config = jungle_engine_config()
        config.seed = 42
        config.initial_camera_height = 1.8
        config.graphics_quality = UInt32(JUNGLE_GRAPHICS_QUALITY_MEDIUM.rawValue)
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_GRASSLAND.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.frame_index, 0)
        XCTAssertEqual(snapshot.camera_height - snapshot.camera_floor_height, 1.8, accuracy: 0.0001)
        XCTAssertEqual(snapshot.simulated_time_seconds, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.last_delta_seconds, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.world_units_per_meter, 1.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.terrain_patch_side, 25)
        XCTAssertTrue(snapshot.renderer_ready)
    }

    func testStepAdvancesFrameCounter() {
        var config = jungle_engine_config()
        config.initial_camera_height = 1.7
        config.graphics_quality = UInt32(JUNGLE_GRAPHICS_QUALITY_MEDIUM.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var input = jungle_input_state()
        jungle_engine_step(engine, &input, 1.0 / 60.0)

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.frame_index, 1)
        XCTAssertEqual(snapshot.camera_height - snapshot.camera_floor_height, 1.7, accuracy: 0.0001)
        XCTAssertEqual(snapshot.simulated_time_seconds, 1.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.last_delta_seconds, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testEngineAppliesMovementLookAndProjectionInputs() {
        var config = jungle_engine_config()
        config.initial_camera_height = 1.7
        config.initial_biome = UInt32(JUNGLE_BIOME_SELECTION_GRASSLAND.rawValue)

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var initialSnapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &initialSnapshot)

        var input = jungle_input_state()
        input.move_forward = 1.0
        input.look_yaw = Float.pi / 2.0
        input.viewport_width = 1920
        input.viewport_height = 1080

        jungle_engine_step(engine, &input, 1.0)

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(
            snapshot.camera_position.x - initialSnapshot.camera_position.x,
            4.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(snapshot.camera_yaw_radians, .pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_forward.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_forward.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_aspect_ratio, 1920.0 / 1080.0, accuracy: 0.0001)
        XCTAssertEqual(
            snapshot.camera_height - snapshot.camera_floor_height,
            1.7,
            accuracy: 0.0001
        )
    }

    func testVersionStringIsAvailable() {
        XCTAssertEqual(String(cString: jungle_engine_version()), "cycle-18-beach-biome")
    }
}
