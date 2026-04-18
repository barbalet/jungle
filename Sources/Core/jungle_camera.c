#include "jungle_camera.h"

#include <math.h>

static const double jungle_pi = 3.14159265358979323846;

static double jungle_camera_clamp_pitch(double pitch_radians) {
    double limit = 1.5533430342749532; /* 89 degrees */

    if (pitch_radians > limit) {
        return limit;
    }

    if (pitch_radians < -limit) {
        return -limit;
    }

    return pitch_radians;
}

jungle_camera jungle_camera_default(double eye_height) {
    if (eye_height <= 0.0) {
        eye_height = 1.7;
    }

    return jungle_camera_make(
        jungle_vec3_make(0.0, eye_height, 0.0),
        0.0,
        0.0,
        jungle_pi / 3.0,
        0.1,
        500.0,
        4.5
    );
}

jungle_camera jungle_camera_make(
    jungle_vec3 position,
    double yaw_radians,
    double pitch_radians,
    double vertical_field_of_view_radians,
    double near_z,
    double far_z,
    double move_speed_units_per_second
) {
    jungle_camera camera = {
        position,
        yaw_radians,
        jungle_camera_clamp_pitch(pitch_radians),
        vertical_field_of_view_radians > 0.0 ? vertical_field_of_view_radians : jungle_pi / 3.0,
        near_z > 0.0 ? near_z : 0.1,
        far_z > near_z ? far_z : 500.0,
        move_speed_units_per_second > 0.0 ? move_speed_units_per_second : 4.5
    };

    return camera;
}

jungle_camera jungle_camera_apply_look(
    jungle_camera camera,
    double delta_yaw_radians,
    double delta_pitch_radians
) {
    camera.yaw_radians += delta_yaw_radians;
    camera.pitch_radians = jungle_camera_clamp_pitch(
        camera.pitch_radians + delta_pitch_radians
    );

    return camera;
}

jungle_vec3 jungle_camera_forward(jungle_camera camera) {
    double cosine_pitch = cos(camera.pitch_radians);

    return jungle_vec3_normalize(
        jungle_vec3_make(
            sin(camera.yaw_radians) * cosine_pitch,
            sin(camera.pitch_radians),
            cos(camera.yaw_radians) * cosine_pitch
        )
    );
}

jungle_vec3 jungle_camera_right(jungle_camera camera) {
    jungle_vec3 world_up = jungle_vec3_make(0.0, 1.0, 0.0);
    return jungle_vec3_normalize(
        jungle_vec3_cross(world_up, jungle_camera_forward(camera))
    );
}

jungle_vec3 jungle_camera_up(jungle_camera camera) {
    jungle_vec3 forward = jungle_camera_forward(camera);
    jungle_vec3 right = jungle_camera_right(camera);
    return jungle_vec3_normalize(jungle_vec3_cross(forward, right));
}

jungle_mat4 jungle_camera_view_matrix(jungle_camera camera) {
    jungle_vec3 forward = jungle_camera_forward(camera);
    jungle_vec3 right = jungle_camera_right(camera);
    jungle_vec3 up = jungle_camera_up(camera);
    jungle_mat4 matrix = jungle_mat4_identity();

    matrix.m[0] = right.x;
    matrix.m[1] = up.x;
    matrix.m[2] = -forward.x;
    matrix.m[3] = 0.0;

    matrix.m[4] = right.y;
    matrix.m[5] = up.y;
    matrix.m[6] = -forward.y;
    matrix.m[7] = 0.0;

    matrix.m[8] = right.z;
    matrix.m[9] = up.z;
    matrix.m[10] = -forward.z;
    matrix.m[11] = 0.0;

    matrix.m[12] = -jungle_vec3_dot(right, camera.position);
    matrix.m[13] = -jungle_vec3_dot(up, camera.position);
    matrix.m[14] = jungle_vec3_dot(forward, camera.position);
    matrix.m[15] = 1.0;

    return matrix;
}

jungle_mat4 jungle_camera_projection_matrix(jungle_camera camera, double aspect_ratio) {
    return jungle_mat4_perspective(
        camera.vertical_field_of_view_radians,
        aspect_ratio,
        camera.near_z,
        camera.far_z
    );
}
