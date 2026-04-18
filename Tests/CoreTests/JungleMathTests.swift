import XCTest
import JungleCore

final class JungleMathTests: XCTestCase {
    func testVec3OperationsProduceExpectedResults() {
        let up = jungle_vec3_make(0, 1, 0)
        let forward = jungle_vec3_make(0, 0, 1)
        let right = jungle_vec3_cross(up, forward)
        let scaled = jungle_vec3_scale(jungle_vec3_make(3, 0, 4), 0.5)
        let normalized = jungle_vec3_normalize(jungle_vec3_make(0, 3, 4))

        XCTAssertEqual(right.x, 1, accuracy: 0.0001)
        XCTAssertEqual(right.y, 0, accuracy: 0.0001)
        XCTAssertEqual(right.z, 0, accuracy: 0.0001)
        XCTAssertEqual(jungle_vec3_dot(right, up), 0, accuracy: 0.0001)
        XCTAssertEqual(scaled.x, 1.5, accuracy: 0.0001)
        XCTAssertEqual(scaled.z, 2.0, accuracy: 0.0001)
        XCTAssertEqual(jungle_vec3_length(normalized), 1.0, accuracy: 0.0001)
        XCTAssertEqual(normalized.y, 0.6, accuracy: 0.0001)
        XCTAssertEqual(normalized.z, 0.8, accuracy: 0.0001)
    }

    func testTransformCompositionMovesPointAsExpected() {
        let transform = jungle_transform_make(
            jungle_vec3_make(2, 3, 4),
            jungle_vec3_make(0, 0, .pi / 2.0),
            jungle_vec3_make(2, 1, 1)
        )
        let matrix = jungle_transform_to_matrix(transform)
        let point = jungle_mat4_transform_point(matrix, jungle_vec3_make(1, 0, 0))
        let direction = jungle_mat4_transform_direction(matrix, jungle_vec3_make(1, 0, 0))

        XCTAssertEqual(point.x, 2.0, accuracy: 0.0001)
        XCTAssertEqual(point.y, 5.0, accuracy: 0.0001)
        XCTAssertEqual(point.z, 4.0, accuracy: 0.0001)
        XCTAssertEqual(direction.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(direction.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(direction.z, 0.0, accuracy: 0.0001)
    }

    func testPerspectiveMatrixUsesMetalStyleDepthConvention() {
        let matrix = jungle_mat4_perspective(.pi / 3.0, 16.0 / 9.0, 0.1, 100.0)

        XCTAssertGreaterThan(jungle_mat4_get(matrix, 0, 0), 0)
        XCTAssertGreaterThan(jungle_mat4_get(matrix, 1, 1), 0)
        XCTAssertEqual(jungle_mat4_get(matrix, 3, 2), -1.0, accuracy: 0.0001)
        XCTAssertLessThan(jungle_mat4_get(matrix, 2, 2), 0)
    }

    func testNoiseHelpersAreDeterministicAndBounded() {
        let hashA = jungle_noise_hash_2d(7, 3, 9)
        let hashB = jungle_noise_hash_2d(7, 3, 9)
        let hashC = jungle_noise_hash_2d(8, 3, 9)
        let valueNoise = jungle_noise_value_2d(99, 12.25, -4.75)
        let fbmNoise = jungle_noise_fbm_2d(99, 12.25, -4.75, 4, 2.0, 0.5)

        XCTAssertEqual(hashA, hashB, accuracy: 0.0000001)
        XCTAssertNotEqual(hashA, hashC, accuracy: 0.0000001)
        XCTAssertGreaterThanOrEqual(valueNoise, 0.0)
        XCTAssertLessThanOrEqual(valueNoise, 1.0)
        XCTAssertGreaterThanOrEqual(fbmNoise, 0.0)
        XCTAssertLessThanOrEqual(fbmNoise, 1.0)
    }
}
