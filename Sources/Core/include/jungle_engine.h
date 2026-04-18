#ifndef JUNGLE_ENGINE_H
#define JUNGLE_ENGINE_H

#include "jungle_camera.h"

#include <stdbool.h>
#include <stdint.h>

typedef struct jungle_engine jungle_engine;

typedef struct jungle_engine_config {
    uint64_t seed;
    double initial_camera_height;
    uint32_t reserved;
} jungle_engine_config;

typedef struct jungle_input_state {
    float move_forward;
    float move_right;
    float look_yaw;
    float look_pitch;
    uint32_t viewport_width;
    uint32_t viewport_height;
} jungle_input_state;

typedef struct jungle_frame_snapshot {
    uint64_t frame_index;
    double camera_height;
    jungle_vec3 camera_position;
    jungle_vec3 camera_forward;
    jungle_vec3 camera_right;
    double camera_yaw_radians;
    double camera_pitch_radians;
    double camera_aspect_ratio;
    double vertical_field_of_view_radians;
    double simulated_time_seconds;
    double last_delta_seconds;
    jungle_mat4 view_matrix;
    jungle_mat4 projection_matrix;
    bool renderer_ready;
} jungle_frame_snapshot;

jungle_engine *jungle_engine_create(const jungle_engine_config *config);
void jungle_engine_destroy(jungle_engine *engine);
void jungle_engine_step(
    jungle_engine *engine,
    const jungle_input_state *input,
    double delta_seconds
);
void jungle_engine_snapshot_copy(
    const jungle_engine *engine,
    jungle_frame_snapshot *out_snapshot
);
const char *jungle_engine_version(void);

#endif
