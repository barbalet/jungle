import XCTest
import JungleCore

final class JungleCameraTests: XCTestCase {
    func testDefaultCameraLooksDownPositiveZAxis() {
        let camera = jungle_camera_default(1.7)
        let forward = jungle_camera_forward(camera)
        let right = jungle_camera_right(camera)
        let up = jungle_camera_up(camera)

        XCTAssertEqual(forward.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(forward.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(forward.z, 1.0, accuracy: 0.0001)
        XCTAssertEqual(right.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(up.y, 1.0, accuracy: 0.0001)
        XCTAssertEqual(jungle_vec3_dot(forward, right), 0.0, accuracy: 0.0001)
    }

    func testCameraLookProducesExpectedOrientation() {
        let camera = jungle_camera_apply_look(
            jungle_camera_default(1.7),
            .pi / 2.0,
            .pi / 6.0
        )
        let forward = jungle_camera_forward(camera)

        XCTAssertEqual(forward.x, 0.8660, accuracy: 0.0005)
        XCTAssertEqual(forward.y, 0.5, accuracy: 0.0005)
        XCTAssertEqual(forward.z, 0.0, accuracy: 0.0005)
    }

    func testViewMatrixMovesForwardPointIntoNegativeCameraZ() {
        let camera = jungle_camera_default(1.7)
        let viewMatrix = jungle_camera_view_matrix(camera)
        let pointAhead = jungle_mat4_transform_point(
            viewMatrix,
            jungle_vec3_make(0.0, 1.7, 5.0)
        )

        XCTAssertEqual(pointAhead.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(pointAhead.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(pointAhead.z, -5.0, accuracy: 0.0001)
    }
}
