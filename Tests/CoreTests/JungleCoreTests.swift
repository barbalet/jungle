import XCTest
import JungleCore

final class JungleCoreTests: XCTestCase {
    func testBootstrapSnapshotUsesConfiguredCameraHeight() {
        var config = jungle_engine_config()
        config.seed = 42
        config.initial_camera_height = 1.8

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.frame_index, 0)
        XCTAssertEqual(snapshot.camera_height, 1.8, accuracy: 0.0001)
        XCTAssertEqual(snapshot.simulated_time_seconds, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.last_delta_seconds, 0, accuracy: 0.0001)
        XCTAssertTrue(snapshot.renderer_ready)
    }

    func testStepAdvancesFrameCounter() {
        var config = jungle_engine_config()
        config.initial_camera_height = 1.7

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
        XCTAssertEqual(snapshot.camera_height, 1.7, accuracy: 0.0001)
        XCTAssertEqual(snapshot.simulated_time_seconds, 1.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.last_delta_seconds, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testEngineAppliesMovementLookAndProjectionInputs() {
        var config = jungle_engine_config()
        config.initial_camera_height = 1.7

        let engine = jungle_engine_create(&config)

        XCTAssertNotNil(engine)
        defer {
            jungle_engine_destroy(engine)
        }

        var input = jungle_input_state()
        input.move_forward = 1.0
        input.look_yaw = Float.pi / 2.0
        input.viewport_width = 1920
        input.viewport_height = 1080

        jungle_engine_step(engine, &input, 1.0)

        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        XCTAssertEqual(snapshot.camera_position.x, 4.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_position.y, 1.7, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_position.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_yaw_radians, .pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_forward.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_forward.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.camera_aspect_ratio, 1920.0 / 1080.0, accuracy: 0.0001)
    }

    func testVersionStringIsAvailable() {
        XCTAssertEqual(String(cString: jungle_engine_version()), "cycle-7-camera-controls")
    }
}
