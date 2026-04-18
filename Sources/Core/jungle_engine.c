#include "jungle_engine.h"

#include "jungle_math.h"

#include <math.h>
#include <stdlib.h>

static const double jungle_pi = 3.14159265358979323846;

struct jungle_engine {
    jungle_engine_config config;
    jungle_camera camera;
    double camera_aspect_ratio;
    uint64_t frame_index;
    double simulated_time_seconds;
    double last_delta_seconds;
};

jungle_engine *jungle_engine_create(const jungle_engine_config *config) {
    jungle_engine *engine = calloc(1, sizeof(*engine));

    if (engine == NULL) {
        return NULL;
    }

    if (config != NULL) {
        engine->config = *config;
    } else {
        engine->config.seed = 1;
        engine->config.initial_camera_height = 1.7;
        engine->config.reserved = 0;
    }

    if (engine->config.initial_camera_height <= 0.0) {
        engine->config.initial_camera_height = 1.7;
    }

    engine->camera = jungle_camera_default(engine->config.initial_camera_height);
    engine->camera_aspect_ratio = 16.0 / 9.0;
    return engine;
}

void jungle_engine_destroy(jungle_engine *engine) {
    free(engine);
}

void jungle_engine_step(
    jungle_engine *engine,
    const jungle_input_state *input,
    double delta_seconds
) {
    (void)input;

    if (engine == NULL) {
        return;
    }

    if (delta_seconds < 0.0) {
        delta_seconds = 0.0;
    }

    if (input != NULL) {
        if (input->viewport_width > 0u && input->viewport_height > 0u) {
            engine->camera_aspect_ratio = (double)input->viewport_width /
                (double)input->viewport_height;
        }

        engine->camera = jungle_camera_apply_look(
            engine->camera,
            input->look_yaw,
            input->look_pitch
        );

        jungle_vec3 forward = jungle_camera_forward(engine->camera);
        jungle_vec3 right = jungle_camera_right(engine->camera);
        jungle_vec3 flat_forward = jungle_vec3_make(forward.x, 0.0, forward.z);
        jungle_vec3 flat_right = jungle_vec3_make(right.x, 0.0, right.z);
        double move_forward = input->move_forward;
        double move_right = input->move_right;
        double move_magnitude = sqrt(move_forward * move_forward + move_right * move_right);
        jungle_vec3 move_direction;

        if (move_magnitude > 1.0) {
            move_forward /= move_magnitude;
            move_right /= move_magnitude;
        }

        flat_forward = jungle_vec3_normalize(flat_forward);
        flat_right = jungle_vec3_normalize(flat_right);
        move_direction = jungle_vec3_add(
            jungle_vec3_scale(flat_forward, move_forward),
            jungle_vec3_scale(flat_right, move_right)
        );

        if (jungle_vec3_length(move_direction) > 0.0) {
            move_direction = jungle_vec3_normalize(move_direction);
            engine->camera.position = jungle_vec3_add(
                engine->camera.position,
                jungle_vec3_scale(
                    move_direction,
                    engine->camera.move_speed_units_per_second * delta_seconds
                )
            );
        }

        engine->camera.position.y = engine->config.initial_camera_height;
    }

    engine->frame_index += 1;
    engine->simulated_time_seconds += delta_seconds;
    engine->last_delta_seconds = delta_seconds;
}

void jungle_engine_snapshot_copy(
    const jungle_engine *engine,
    jungle_frame_snapshot *out_snapshot
) {
    if (out_snapshot == NULL) {
        return;
    }

    if (engine == NULL) {
        out_snapshot->frame_index = 0;
        out_snapshot->camera_height = 0.0;
        out_snapshot->camera_position = jungle_vec3_make(0.0, 0.0, 0.0);
        out_snapshot->camera_forward = jungle_vec3_make(0.0, 0.0, 1.0);
        out_snapshot->camera_right = jungle_vec3_make(1.0, 0.0, 0.0);
        out_snapshot->camera_yaw_radians = 0.0;
        out_snapshot->camera_pitch_radians = 0.0;
        out_snapshot->camera_aspect_ratio = 16.0 / 9.0;
        out_snapshot->vertical_field_of_view_radians = jungle_pi / 3.0;
        out_snapshot->simulated_time_seconds = 0.0;
        out_snapshot->last_delta_seconds = 0.0;
        out_snapshot->view_matrix = jungle_mat4_identity();
        out_snapshot->projection_matrix = jungle_mat4_identity();
        out_snapshot->renderer_ready = false;
        return;
    }

    out_snapshot->frame_index = engine->frame_index;
    out_snapshot->camera_height = engine->camera.position.y;
    out_snapshot->camera_position = engine->camera.position;
    out_snapshot->camera_forward = jungle_camera_forward(engine->camera);
    out_snapshot->camera_right = jungle_camera_right(engine->camera);
    out_snapshot->camera_yaw_radians = engine->camera.yaw_radians;
    out_snapshot->camera_pitch_radians = engine->camera.pitch_radians;
    out_snapshot->camera_aspect_ratio = engine->camera_aspect_ratio;
    out_snapshot->vertical_field_of_view_radians = engine->camera.vertical_field_of_view_radians;
    out_snapshot->simulated_time_seconds = engine->simulated_time_seconds;
    out_snapshot->last_delta_seconds = engine->last_delta_seconds;
    out_snapshot->view_matrix = jungle_camera_view_matrix(engine->camera);
    out_snapshot->projection_matrix = jungle_camera_projection_matrix(
        engine->camera,
        engine->camera_aspect_ratio
    );
    out_snapshot->renderer_ready = true;
}

const char *jungle_engine_version(void) {
    return "cycle-7-camera-controls";
}
