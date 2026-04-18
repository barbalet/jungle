#ifndef JUNGLE_CAMERA_H
#define JUNGLE_CAMERA_H

#include "jungle_math.h"

typedef struct jungle_camera {
    jungle_vec3 position;
    double yaw_radians;
    double pitch_radians;
    double vertical_field_of_view_radians;
    double near_z;
    double far_z;
    double move_speed_units_per_second;
} jungle_camera;

jungle_camera jungle_camera_default(double eye_height);
jungle_camera jungle_camera_make(
    jungle_vec3 position,
    double yaw_radians,
    double pitch_radians,
    double vertical_field_of_view_radians,
    double near_z,
    double far_z,
    double move_speed_units_per_second
);
jungle_camera jungle_camera_apply_look(
    jungle_camera camera,
    double delta_yaw_radians,
    double delta_pitch_radians
);
jungle_vec3 jungle_camera_forward(jungle_camera camera);
jungle_vec3 jungle_camera_right(jungle_camera camera);
jungle_vec3 jungle_camera_up(jungle_camera camera);
jungle_mat4 jungle_camera_view_matrix(jungle_camera camera);
jungle_mat4 jungle_camera_projection_matrix(jungle_camera camera, double aspect_ratio);

#endif
