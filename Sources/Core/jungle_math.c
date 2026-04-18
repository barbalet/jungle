#include "jungle_math.h"

#include <math.h>
#include <stddef.h>

static size_t jungle_mat4_index(uint32_t row, uint32_t column) {
    return (size_t)column * 4u + (size_t)row;
}

static double jungle_lerp(double start, double end, double t) {
    return start + (end - start) * t;
}

static double jungle_smoothstep(double t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

static uint32_t jungle_hash_u32(uint32_t value) {
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    value ^= value >> 16;
    return value;
}

static jungle_mat4 jungle_mat4_set(
    jungle_mat4 matrix,
    uint32_t row,
    uint32_t column,
    double value
) {
    if (row < 4u && column < 4u) {
        matrix.m[jungle_mat4_index(row, column)] = value;
    }

    return matrix;
}

static jungle_vec4 jungle_mat4_multiply_vec4(jungle_mat4 matrix, jungle_vec4 value) {
    return jungle_vec4_make(
        jungle_mat4_get(matrix, 0, 0) * value.x +
            jungle_mat4_get(matrix, 0, 1) * value.y +
            jungle_mat4_get(matrix, 0, 2) * value.z +
            jungle_mat4_get(matrix, 0, 3) * value.w,
        jungle_mat4_get(matrix, 1, 0) * value.x +
            jungle_mat4_get(matrix, 1, 1) * value.y +
            jungle_mat4_get(matrix, 1, 2) * value.z +
            jungle_mat4_get(matrix, 1, 3) * value.w,
        jungle_mat4_get(matrix, 2, 0) * value.x +
            jungle_mat4_get(matrix, 2, 1) * value.y +
            jungle_mat4_get(matrix, 2, 2) * value.z +
            jungle_mat4_get(matrix, 2, 3) * value.w,
        jungle_mat4_get(matrix, 3, 0) * value.x +
            jungle_mat4_get(matrix, 3, 1) * value.y +
            jungle_mat4_get(matrix, 3, 2) * value.z +
            jungle_mat4_get(matrix, 3, 3) * value.w
    );
}

jungle_vec2 jungle_vec2_make(double x, double y) {
    jungle_vec2 value = { x, y };
    return value;
}

jungle_vec3 jungle_vec3_make(double x, double y, double z) {
    jungle_vec3 value = { x, y, z };
    return value;
}

jungle_vec3 jungle_vec3_add(jungle_vec3 left, jungle_vec3 right) {
    return jungle_vec3_make(
        left.x + right.x,
        left.y + right.y,
        left.z + right.z
    );
}

jungle_vec3 jungle_vec3_subtract(jungle_vec3 left, jungle_vec3 right) {
    return jungle_vec3_make(
        left.x - right.x,
        left.y - right.y,
        left.z - right.z
    );
}

jungle_vec3 jungle_vec3_scale(jungle_vec3 value, double scalar) {
    return jungle_vec3_make(
        value.x * scalar,
        value.y * scalar,
        value.z * scalar
    );
}

double jungle_vec3_dot(jungle_vec3 left, jungle_vec3 right) {
    return left.x * right.x + left.y * right.y + left.z * right.z;
}

jungle_vec3 jungle_vec3_cross(jungle_vec3 left, jungle_vec3 right) {
    return jungle_vec3_make(
        left.y * right.z - left.z * right.y,
        left.z * right.x - left.x * right.z,
        left.x * right.y - left.y * right.x
    );
}

double jungle_vec3_length(jungle_vec3 value) {
    return sqrt(jungle_vec3_dot(value, value));
}

jungle_vec3 jungle_vec3_normalize(jungle_vec3 value) {
    double length = jungle_vec3_length(value);

    if (length <= 0.0) {
        return jungle_vec3_make(0.0, 0.0, 0.0);
    }

    return jungle_vec3_scale(value, 1.0 / length);
}

jungle_vec4 jungle_vec4_make(double x, double y, double z, double w) {
    jungle_vec4 value = { x, y, z, w };
    return value;
}

jungle_mat4 jungle_mat4_identity(void) {
    jungle_mat4 matrix = { {
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    } };
    return matrix;
}

double jungle_mat4_get(jungle_mat4 matrix, uint32_t row, uint32_t column) {
    if (row >= 4u || column >= 4u) {
        return 0.0;
    }

    return matrix.m[jungle_mat4_index(row, column)];
}

jungle_mat4 jungle_mat4_multiply(jungle_mat4 left, jungle_mat4 right) {
    jungle_mat4 result = { { 0 } };

    for (uint32_t row = 0; row < 4u; row += 1u) {
        for (uint32_t column = 0; column < 4u; column += 1u) {
            double total = 0.0;

            for (uint32_t k = 0; k < 4u; k += 1u) {
                total += jungle_mat4_get(left, row, k) *
                    jungle_mat4_get(right, k, column);
            }

            result = jungle_mat4_set(result, row, column, total);
        }
    }

    return result;
}

jungle_mat4 jungle_mat4_translation(jungle_vec3 translation) {
    jungle_mat4 matrix = jungle_mat4_identity();
    matrix = jungle_mat4_set(matrix, 0, 3, translation.x);
    matrix = jungle_mat4_set(matrix, 1, 3, translation.y);
    matrix = jungle_mat4_set(matrix, 2, 3, translation.z);
    return matrix;
}

jungle_mat4 jungle_mat4_scale(jungle_vec3 scale) {
    jungle_mat4 matrix = jungle_mat4_identity();
    matrix = jungle_mat4_set(matrix, 0, 0, scale.x);
    matrix = jungle_mat4_set(matrix, 1, 1, scale.y);
    matrix = jungle_mat4_set(matrix, 2, 2, scale.z);
    return matrix;
}

jungle_mat4 jungle_mat4_rotation_x(double radians) {
    double cosine = cos(radians);
    double sine = sin(radians);
    jungle_mat4 matrix = jungle_mat4_identity();

    matrix = jungle_mat4_set(matrix, 1, 1, cosine);
    matrix = jungle_mat4_set(matrix, 1, 2, -sine);
    matrix = jungle_mat4_set(matrix, 2, 1, sine);
    matrix = jungle_mat4_set(matrix, 2, 2, cosine);

    return matrix;
}

jungle_mat4 jungle_mat4_rotation_y(double radians) {
    double cosine = cos(radians);
    double sine = sin(radians);
    jungle_mat4 matrix = jungle_mat4_identity();

    matrix = jungle_mat4_set(matrix, 0, 0, cosine);
    matrix = jungle_mat4_set(matrix, 0, 2, sine);
    matrix = jungle_mat4_set(matrix, 2, 0, -sine);
    matrix = jungle_mat4_set(matrix, 2, 2, cosine);

    return matrix;
}

jungle_mat4 jungle_mat4_rotation_z(double radians) {
    double cosine = cos(radians);
    double sine = sin(radians);
    jungle_mat4 matrix = jungle_mat4_identity();

    matrix = jungle_mat4_set(matrix, 0, 0, cosine);
    matrix = jungle_mat4_set(matrix, 0, 1, -sine);
    matrix = jungle_mat4_set(matrix, 1, 0, sine);
    matrix = jungle_mat4_set(matrix, 1, 1, cosine);

    return matrix;
}

jungle_mat4 jungle_mat4_perspective(
    double vertical_field_of_view_radians,
    double aspect_ratio,
    double near_z,
    double far_z
) {
    if (vertical_field_of_view_radians <= 0.0 ||
            aspect_ratio <= 0.0 ||
            near_z <= 0.0 ||
            far_z <= near_z) {
        return jungle_mat4_identity();
    }

    double y_scale = 1.0 / tan(vertical_field_of_view_radians * 0.5);
    double x_scale = y_scale / aspect_ratio;
    double z_scale = far_z / (near_z - far_z);
    double z_translation = (near_z * far_z) / (near_z - far_z);

    jungle_mat4 matrix = { { 0 } };
    matrix = jungle_mat4_set(matrix, 0, 0, x_scale);
    matrix = jungle_mat4_set(matrix, 1, 1, y_scale);
    matrix = jungle_mat4_set(matrix, 2, 2, z_scale);
    matrix = jungle_mat4_set(matrix, 2, 3, z_translation);
    matrix = jungle_mat4_set(matrix, 3, 2, -1.0);
    return matrix;
}

jungle_vec3 jungle_mat4_transform_point(jungle_mat4 matrix, jungle_vec3 point) {
    jungle_vec4 result = jungle_mat4_multiply_vec4(
        matrix,
        jungle_vec4_make(point.x, point.y, point.z, 1.0)
    );
    double w = result.w;

    if (fabs(w) <= 0.0000001) {
        w = 1.0;
    }

    return jungle_vec3_make(result.x / w, result.y / w, result.z / w);
}

jungle_vec3 jungle_mat4_transform_direction(jungle_mat4 matrix, jungle_vec3 direction) {
    jungle_vec4 result = jungle_mat4_multiply_vec4(
        matrix,
        jungle_vec4_make(direction.x, direction.y, direction.z, 0.0)
    );

    return jungle_vec3_make(result.x, result.y, result.z);
}

jungle_transform jungle_transform_identity(void) {
    jungle_transform transform = {
        jungle_vec3_make(0.0, 0.0, 0.0),
        jungle_vec3_make(0.0, 0.0, 0.0),
        jungle_vec3_make(1.0, 1.0, 1.0)
    };
    return transform;
}

jungle_transform jungle_transform_make(
    jungle_vec3 translation,
    jungle_vec3 rotation_radians,
    jungle_vec3 scale
) {
    jungle_transform transform = { translation, rotation_radians, scale };
    return transform;
}

jungle_mat4 jungle_transform_to_matrix(jungle_transform transform) {
    jungle_mat4 translation = jungle_mat4_translation(transform.translation);
    jungle_mat4 rotation_x = jungle_mat4_rotation_x(transform.rotation_radians.x);
    jungle_mat4 rotation_y = jungle_mat4_rotation_y(transform.rotation_radians.y);
    jungle_mat4 rotation_z = jungle_mat4_rotation_z(transform.rotation_radians.z);
    jungle_mat4 scale = jungle_mat4_scale(transform.scale);

    jungle_mat4 rotation = jungle_mat4_multiply(
        jungle_mat4_multiply(rotation_z, rotation_y),
        rotation_x
    );

    return jungle_mat4_multiply(
        jungle_mat4_multiply(translation, rotation),
        scale
    );
}

double jungle_noise_hash_2d(uint32_t seed, int32_t x, int32_t y) {
    uint32_t hash = jungle_hash_u32(seed ^ ((uint32_t)x * 0x8da6b343u));
    hash = jungle_hash_u32(hash ^ ((uint32_t)y * 0xd8163841u));
    return (double)hash / 4294967295.0;
}

double jungle_noise_value_2d(uint32_t seed, double x, double y) {
    double floor_x = floor(x);
    double floor_y = floor(y);
    int32_t x0 = (int32_t)floor_x;
    int32_t y0 = (int32_t)floor_y;
    int32_t x1 = x0 + 1;
    int32_t y1 = y0 + 1;
    double tx = jungle_smoothstep(x - floor_x);
    double ty = jungle_smoothstep(y - floor_y);
    double a = jungle_noise_hash_2d(seed, x0, y0);
    double b = jungle_noise_hash_2d(seed, x1, y0);
    double c = jungle_noise_hash_2d(seed, x0, y1);
    double d = jungle_noise_hash_2d(seed, x1, y1);
    double top = jungle_lerp(a, b, tx);
    double bottom = jungle_lerp(c, d, tx);

    return jungle_lerp(top, bottom, ty);
}

double jungle_noise_fbm_2d(
    uint32_t seed,
    double x,
    double y,
    uint32_t octaves,
    double lacunarity,
    double gain
) {
    if (octaves == 0u) {
        return 0.0;
    }

    if (lacunarity <= 0.0) {
        lacunarity = 2.0;
    }

    if (gain <= 0.0) {
        gain = 0.5;
    }

    double amplitude = 1.0;
    double frequency = 1.0;
    double total = 0.0;
    double amplitude_total = 0.0;

    for (uint32_t octave = 0; octave < octaves; octave += 1u) {
        total += jungle_noise_value_2d(
            seed + octave * 1013904223u,
            x * frequency,
            y * frequency
        ) * amplitude;
        amplitude_total += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    if (amplitude_total <= 0.0) {
        return 0.0;
    }

    return total / amplitude_total;
}
