#ifndef JUNGLE_MATH_H
#define JUNGLE_MATH_H

#include <stdint.h>

typedef struct jungle_vec2 {
    double x;
    double y;
} jungle_vec2;

typedef struct jungle_vec3 {
    double x;
    double y;
    double z;
} jungle_vec3;

typedef struct jungle_vec4 {
    double x;
    double y;
    double z;
    double w;
} jungle_vec4;

/* Matrices use column-major storage to match typical graphics pipelines. */
typedef struct jungle_mat4 {
    double m[16];
} jungle_mat4;

/* Transform composition order is translation * rotationZ * rotationY * rotationX * scale. */
typedef struct jungle_transform {
    jungle_vec3 translation;
    jungle_vec3 rotation_radians;
    jungle_vec3 scale;
} jungle_transform;

jungle_vec2 jungle_vec2_make(double x, double y);

jungle_vec3 jungle_vec3_make(double x, double y, double z);
jungle_vec3 jungle_vec3_add(jungle_vec3 left, jungle_vec3 right);
jungle_vec3 jungle_vec3_subtract(jungle_vec3 left, jungle_vec3 right);
jungle_vec3 jungle_vec3_scale(jungle_vec3 value, double scalar);
double jungle_vec3_dot(jungle_vec3 left, jungle_vec3 right);
jungle_vec3 jungle_vec3_cross(jungle_vec3 left, jungle_vec3 right);
double jungle_vec3_length(jungle_vec3 value);
jungle_vec3 jungle_vec3_normalize(jungle_vec3 value);

jungle_vec4 jungle_vec4_make(double x, double y, double z, double w);

jungle_mat4 jungle_mat4_identity(void);
double jungle_mat4_get(jungle_mat4 matrix, uint32_t row, uint32_t column);
jungle_mat4 jungle_mat4_multiply(jungle_mat4 left, jungle_mat4 right);
jungle_mat4 jungle_mat4_translation(jungle_vec3 translation);
jungle_mat4 jungle_mat4_scale(jungle_vec3 scale);
jungle_mat4 jungle_mat4_rotation_x(double radians);
jungle_mat4 jungle_mat4_rotation_y(double radians);
jungle_mat4 jungle_mat4_rotation_z(double radians);
jungle_mat4 jungle_mat4_perspective(
    double vertical_field_of_view_radians,
    double aspect_ratio,
    double near_z,
    double far_z
);
jungle_vec3 jungle_mat4_transform_point(jungle_mat4 matrix, jungle_vec3 point);
jungle_vec3 jungle_mat4_transform_direction(jungle_mat4 matrix, jungle_vec3 direction);

jungle_transform jungle_transform_identity(void);
jungle_transform jungle_transform_make(
    jungle_vec3 translation,
    jungle_vec3 rotation_radians,
    jungle_vec3 scale
);
jungle_mat4 jungle_transform_to_matrix(jungle_transform transform);

double jungle_noise_hash_2d(uint32_t seed, int32_t x, int32_t y);
double jungle_noise_value_2d(uint32_t seed, double x, double y);
double jungle_noise_fbm_2d(
    uint32_t seed,
    double x,
    double y,
    uint32_t octaves,
    double lacunarity,
    double gain
);

#endif
