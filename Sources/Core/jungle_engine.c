#include "jungle_engine.h"

#include "jungle_math.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

static const double jungle_pi = 3.14159265358979323846;
static const double jungle_world_units_per_meter = 1.0;
static const double jungle_ground_cover_height_units = 0.35;
static const double jungle_waist_height_units = 1.10;
static const double jungle_head_height_units = 1.80;
static const double jungle_canopy_height_units = 4.80;

typedef struct jungle_biome_profile {
    double grassland_weight;
    double jungle_weight;
    double beach_weight;
    double shoreline_space;
} jungle_biome_profile;

struct jungle_engine {
    jungle_engine_config config;
    jungle_camera camera;
    double eye_height_units;
    double camera_aspect_ratio;
    uint64_t frame_index;
    double simulated_time_seconds;
    double last_delta_seconds;
};

static double jungle_clamp(double value, double minimum, double maximum) {
    if (value < minimum) {
        return minimum;
    }

    if (value > maximum) {
        return maximum;
    }

    return value;
}

static double jungle_saturate(double value) {
    return jungle_clamp(value, 0.0, 1.0);
}

static double jungle_smooth_between(double edge0, double edge1, double value) {
    if (edge0 == edge1) {
        return value >= edge1 ? 1.0 : 0.0;
    }

    double t = jungle_saturate((value - edge0) / (edge1 - edge0));
    return t * t * (3.0 - 2.0 * t);
}

static double jungle_lerp(double start, double end, double t) {
    return start + (end - start) * t;
}

static jungle_material_channel jungle_material_channel_make(
    float red,
    float green,
    float blue,
    float alpha,
    float motion,
    float wetness_response
) {
    jungle_material_channel channel;
    channel.red = red;
    channel.green = green;
    channel.blue = blue;
    channel.alpha = alpha;
    channel.motion = motion;
    channel.wetness_response = wetness_response;
    return channel;
}

static jungle_material_channel jungle_material_channel_blend3(
    jungle_material_channel grassland,
    jungle_material_channel jungle,
    jungle_material_channel beach,
    jungle_biome_profile profile
) {
    return jungle_material_channel_make(
        grassland.red * (float)profile.grassland_weight +
            jungle.red * (float)profile.jungle_weight +
            beach.red * (float)profile.beach_weight,
        grassland.green * (float)profile.grassland_weight +
            jungle.green * (float)profile.jungle_weight +
            beach.green * (float)profile.beach_weight,
        grassland.blue * (float)profile.grassland_weight +
            jungle.blue * (float)profile.jungle_weight +
            beach.blue * (float)profile.beach_weight,
        grassland.alpha * (float)profile.grassland_weight +
            jungle.alpha * (float)profile.jungle_weight +
            beach.alpha * (float)profile.beach_weight,
        grassland.motion * (float)profile.grassland_weight +
            jungle.motion * (float)profile.jungle_weight +
            beach.motion * (float)profile.beach_weight,
        grassland.wetness_response * (float)profile.grassland_weight +
            jungle.wetness_response * (float)profile.jungle_weight +
            beach.wetness_response * (float)profile.beach_weight
    );
}

static jungle_graphics_quality jungle_normalized_graphics_quality(uint32_t raw_value) {
    if (raw_value > (uint32_t)JUNGLE_GRAPHICS_QUALITY_HIGH) {
        return JUNGLE_GRAPHICS_QUALITY_MEDIUM;
    }

    return (jungle_graphics_quality)raw_value;
}

static jungle_biome_selection jungle_normalized_biome_selection(uint32_t raw_value) {
    if (raw_value > (uint32_t)JUNGLE_BIOME_SELECTION_BEACH) {
        return JUNGLE_BIOME_SELECTION_AUTOMATIC;
    }

    return (jungle_biome_selection)raw_value;
}

static uint32_t jungle_patch_side_for_quality(jungle_graphics_quality quality) {
    switch (quality) {
    case JUNGLE_GRAPHICS_QUALITY_LOW:
        return 17u;
    case JUNGLE_GRAPHICS_QUALITY_HIGH:
        return 33u;
    case JUNGLE_GRAPHICS_QUALITY_MEDIUM:
    default:
        return 25u;
    }
}

static double jungle_patch_spacing_for_quality(jungle_graphics_quality quality) {
    switch (quality) {
    case JUNGLE_GRAPHICS_QUALITY_LOW:
        return 3.0;
    case JUNGLE_GRAPHICS_QUALITY_HIGH:
        return 1.5;
    case JUNGLE_GRAPHICS_QUALITY_MEDIUM:
    default:
        return 2.0;
    }
}

static jungle_biome_profile jungle_biome_profile_at(
    const jungle_engine *engine,
    double x,
    double z
) {
    uint32_t seed = (uint32_t)(engine->config.seed ^ 0x9e3779b9u);
    double world_noise = jungle_noise_fbm_2d(seed, x * 0.0045, z * 0.0045, 3u, 2.0, 0.5) * 2.0 - 1.0;
    double axis = (x / 96.0) + world_noise * 0.46 - 0.14;
    double jungle_candidate = jungle_smooth_between(-0.22, 0.42, axis);
    double beach_noise = jungle_noise_fbm_2d(seed + 17u, x * 0.0030, z * 0.0060, 3u, 2.0, 0.5) * 2.0 - 1.0;
    double beach_candidate = jungle_smooth_between(0.86, 1.38, axis + beach_noise * 0.18);
    double beach_weight = beach_candidate;
    double jungle_weight = jungle_candidate * (1.0 - beach_weight);
    double grassland_weight = 1.0 - jungle_weight - beach_weight;
    double shoreline_seed = jungle_noise_fbm_2d(seed + 33u, x * 0.010, 0.0, 2u, 2.0, 0.5);
    double shoreline_line = (shoreline_seed - 0.5) * 26.0;
    double shoreline_offset = fabs(z - shoreline_line);
    double shoreline_band = 1.0 - jungle_smooth_between(6.0, 38.0, shoreline_offset);
    jungle_biome_profile profile;

    profile.grassland_weight = jungle_saturate(grassland_weight);
    profile.jungle_weight = jungle_saturate(jungle_weight);
    profile.beach_weight = jungle_saturate(beach_weight);
    profile.shoreline_space = jungle_saturate(profile.beach_weight * shoreline_band);
    return profile;
}

static jungle_biome_kind jungle_primary_biome_kind(jungle_biome_profile profile) {
    if (profile.beach_weight >= profile.jungle_weight &&
        profile.beach_weight >= profile.grassland_weight) {
        return JUNGLE_BIOME_KIND_BEACH;
    }

    if (profile.jungle_weight >= profile.grassland_weight) {
        return JUNGLE_BIOME_KIND_JUNGLE;
    }

    return JUNGLE_BIOME_KIND_GRASSLAND;
}

static jungle_weather_kind jungle_weather_kind_for_profile(jungle_biome_profile profile) {
    if (profile.beach_weight >= profile.jungle_weight &&
        profile.beach_weight >= profile.grassland_weight) {
        return JUNGLE_WEATHER_KIND_COASTAL_HAZE;
    }

    if (profile.jungle_weight >= profile.grassland_weight) {
        return JUNGLE_WEATHER_KIND_HUMID_CANOPY;
    }

    return JUNGLE_WEATHER_KIND_CLEAR_BREEZE;
}

static double jungle_terrain_height_at(
    const jungle_engine *engine,
    double x,
    double z,
    jungle_biome_profile *out_profile
) {
    uint32_t seed = (uint32_t)engine->config.seed;
    jungle_biome_profile profile = jungle_biome_profile_at(engine, x, z);
    double grass_roll = jungle_noise_fbm_2d(seed + 11u, x * 0.018, z * 0.018, 4u, 2.0, 0.5);
    double grass_micro = jungle_noise_fbm_2d(seed + 21u, x * 0.060, z * 0.060, 3u, 2.0, 0.5);
    double jungle_roll = jungle_noise_fbm_2d(seed + 31u, x * 0.024, z * 0.024, 5u, 2.1, 0.55);
    double jungle_detail = jungle_noise_fbm_2d(seed + 41u, x * 0.090, z * 0.090, 3u, 2.2, 0.5);
    double ridge = jungle_noise_value_2d(seed + 51u, x * 0.012, z * 0.012) - 0.5;
    double beach_roll = jungle_noise_fbm_2d(seed + 111u, x * 0.015, z * 0.015, 4u, 2.0, 0.5);
    double beach_detail = jungle_noise_fbm_2d(seed + 121u, x * 0.050, z * 0.050, 3u, 2.0, 0.5);
    double shoreline_undulation = sin(x * 0.018 + z * 0.004) * 0.28 +
        cos(z * 0.026 - x * 0.002) * 0.22;
    double grass_height = (grass_roll - 0.5) * 7.0 +
        sin(x * 0.045 + 0.7) * 0.9 +
        cos(z * 0.033 - 0.4) * 0.8 +
        (grass_micro - 0.5) * 0.8;
    double jungle_height = (jungle_roll - 0.5) * 12.0 +
        (jungle_detail - 0.5) * 2.2 +
        sin((x + z) * 0.090) * 0.6 +
        cos((z - x) * 0.110) * 0.5 +
        ridge * ridge * 3.2 +
        1.5;
    double beach_height = (beach_roll - 0.5) * 2.1 +
        (beach_detail - 0.5) * 0.9 +
        shoreline_undulation +
        profile.shoreline_space * -1.4 +
        profile.beach_weight * -0.6;
    double height = grass_height * profile.grassland_weight +
        jungle_height * profile.jungle_weight +
        beach_height * profile.beach_weight;

    if (out_profile != NULL) {
        *out_profile = profile;
    }

    return height;
}

static void jungle_sample_layers(
    const jungle_engine *engine,
    double x,
    double z,
    double terrain_height,
    jungle_biome_profile profile,
    float *out_ground_cover,
    float *out_waist,
    float *out_head,
    float *out_canopy,
    float *out_wetness
) {
    uint32_t seed = (uint32_t)engine->config.seed;
    double cover_noise = jungle_noise_fbm_2d(seed + 61u, x * 0.080, z * 0.080, 3u, 2.0, 0.55);
    double waist_noise = jungle_noise_fbm_2d(seed + 71u, x * 0.050, z * 0.050, 3u, 2.0, 0.5);
    double canopy_noise = jungle_noise_fbm_2d(seed + 81u, x * 0.034, z * 0.034, 4u, 2.0, 0.55);
    double wetness_noise = jungle_noise_fbm_2d(seed + 91u, x * 0.070, z * 0.070, 3u, 2.0, 0.5);
    double beach_scrub = jungle_noise_fbm_2d(seed + 141u, x * 0.040, z * 0.040, 2u, 2.0, 0.5);
    double elevation_lift = jungle_smooth_between(-2.0, 4.0, terrain_height);
    double ground_cover = jungle_clamp(
        0.18 +
            profile.grassland_weight * 0.34 +
            profile.jungle_weight * 0.14 +
            profile.beach_weight * 0.10 +
            (cover_noise - 0.5) * 0.50 +
            elevation_lift * 0.08 -
            profile.shoreline_space * 0.16,
        0.0,
        1.0
    );
    double waist = jungle_clamp(
        0.04 +
            profile.grassland_weight * 0.18 +
            profile.jungle_weight * 0.26 +
            profile.beach_weight * 0.06 +
            (waist_noise - 0.45) * 0.60 -
            profile.shoreline_space * 0.12,
        0.0,
        1.0
    );
    double head = jungle_clamp(
        profile.grassland_weight * 0.04 +
            profile.jungle_weight * 0.22 +
            profile.beach_weight * 0.02 +
            (canopy_noise - 0.52) * 0.62 -
            profile.shoreline_space * 0.15,
        0.0,
        1.0
    );
    double canopy = jungle_clamp(
        profile.grassland_weight * 0.06 +
            profile.jungle_weight * 0.54 +
            profile.beach_weight * 0.01 +
            (canopy_noise - 0.46) * 0.88 -
            profile.beach_weight * 0.20 -
            profile.shoreline_space * 0.20,
        0.0,
        1.0
    );
    double wetness = jungle_clamp(
        profile.grassland_weight * 0.16 +
            profile.jungle_weight * 0.70 +
            profile.beach_weight * 0.28 +
            profile.shoreline_space * 0.18 +
            (wetness_noise - 0.5) * 0.22,
        0.05,
        0.95
    );

    if (profile.beach_weight > 0.45) {
        ground_cover = jungle_clamp(
            ground_cover * 0.35 + (beach_scrub - 0.55) * 0.28 + 0.08,
            0.0,
            0.38
        );
        waist *= 0.28;
        head *= 0.08;
        canopy *= 0.02;
    }

    if (out_ground_cover != NULL) {
        *out_ground_cover = (float)ground_cover;
    }

    if (out_waist != NULL) {
        *out_waist = (float)waist;
    }

    if (out_head != NULL) {
        *out_head = (float)head;
    }

    if (out_canopy != NULL) {
        *out_canopy = (float)canopy;
    }

    if (out_wetness != NULL) {
        *out_wetness = (float)wetness;
    }
}

static jungle_material_channel jungle_ground_material_for_profile(jungle_biome_profile profile) {
    jungle_material_channel grassland = jungle_material_channel_make(0.42f, 0.36f, 0.21f, 1.0f, 0.00f, 0.25f);
    jungle_material_channel jungle = jungle_material_channel_make(0.20f, 0.26f, 0.14f, 1.0f, 0.00f, 0.60f);
    jungle_material_channel beach = jungle_material_channel_make(0.78f, 0.68f, 0.44f, 1.0f, 0.00f, 0.18f);
    return jungle_material_channel_blend3(grassland, jungle, beach, profile);
}

static jungle_material_channel jungle_ground_cover_material_for_profile(jungle_biome_profile profile) {
    jungle_material_channel grassland = jungle_material_channel_make(0.40f, 0.58f, 0.22f, 0.55f, 0.38f, 0.18f);
    jungle_material_channel jungle = jungle_material_channel_make(0.16f, 0.39f, 0.18f, 0.72f, 0.56f, 0.46f);
    jungle_material_channel beach = jungle_material_channel_make(0.62f, 0.70f, 0.38f, 0.22f, 0.18f, 0.10f);
    return jungle_material_channel_blend3(grassland, jungle, beach, profile);
}

static jungle_material_channel jungle_waist_material_for_profile(jungle_biome_profile profile) {
    jungle_material_channel grassland = jungle_material_channel_make(0.52f, 0.66f, 0.28f, 0.46f, 0.44f, 0.24f);
    jungle_material_channel jungle = jungle_material_channel_make(0.12f, 0.35f, 0.17f, 0.62f, 0.62f, 0.54f);
    jungle_material_channel beach = jungle_material_channel_make(0.56f, 0.60f, 0.34f, 0.14f, 0.10f, 0.14f);
    return jungle_material_channel_blend3(grassland, jungle, beach, profile);
}

static jungle_material_channel jungle_head_material_for_profile(jungle_biome_profile profile) {
    jungle_material_channel grassland = jungle_material_channel_make(0.66f, 0.70f, 0.32f, 0.30f, 0.24f, 0.20f);
    jungle_material_channel jungle = jungle_material_channel_make(0.08f, 0.28f, 0.16f, 0.52f, 0.70f, 0.64f);
    jungle_material_channel beach = jungle_material_channel_make(0.82f, 0.76f, 0.54f, 0.06f, 0.05f, 0.10f);
    return jungle_material_channel_blend3(grassland, jungle, beach, profile);
}

static jungle_material_channel jungle_canopy_material_for_profile(jungle_biome_profile profile) {
    jungle_material_channel grassland = jungle_material_channel_make(0.44f, 0.56f, 0.24f, 0.22f, 0.16f, 0.14f);
    jungle_material_channel jungle = jungle_material_channel_make(0.04f, 0.21f, 0.12f, 0.64f, 0.76f, 0.72f);
    jungle_material_channel beach = jungle_material_channel_make(0.90f, 0.82f, 0.62f, 0.02f, 0.02f, 0.08f);
    return jungle_material_channel_blend3(grassland, jungle, beach, profile);
}

jungle_engine *jungle_engine_create(const jungle_engine_config *config) {
    jungle_engine *engine = calloc(1, sizeof(*engine));

    if (engine == NULL) {
        return NULL;
    }

    if (config != NULL) {
        engine->config = *config;
    } else {
        engine->config.seed = 1u;
        engine->config.initial_camera_height = 1.7;
        engine->config.graphics_quality = (uint32_t)JUNGLE_GRAPHICS_QUALITY_MEDIUM;
        engine->config.initial_biome = (uint32_t)JUNGLE_BIOME_SELECTION_AUTOMATIC;
    }

    if (engine->config.seed == 0u) {
        engine->config.seed = 1u;
    }

    if (engine->config.initial_camera_height <= 0.0) {
        engine->config.initial_camera_height = 1.7;
    }

    engine->config.graphics_quality =
        (uint32_t)jungle_normalized_graphics_quality(engine->config.graphics_quality);
    engine->config.initial_biome =
        (uint32_t)jungle_normalized_biome_selection(engine->config.initial_biome);
    engine->eye_height_units = engine->config.initial_camera_height;
    engine->camera = jungle_camera_default(engine->eye_height_units);
    engine->camera_aspect_ratio = 16.0 / 9.0;

    double start_x = -48.0;
    double start_z = (jungle_noise_hash_2d((uint32_t)engine->config.seed, 7, 13) - 0.5) * 36.0;
    jungle_biome_selection start_biome =
        jungle_normalized_biome_selection(engine->config.initial_biome);

    if (start_biome == JUNGLE_BIOME_SELECTION_GRASSLAND) {
        start_x = -86.0;
    } else if (start_biome == JUNGLE_BIOME_SELECTION_JUNGLE) {
        start_x = 64.0;
    } else if (start_biome == JUNGLE_BIOME_SELECTION_BEACH) {
        start_x = 176.0;
        start_z = 0.0;
    }

    engine->camera.position = jungle_vec3_make(start_x, 0.0, start_z);
    engine->camera.position.y = jungle_terrain_height_at(
        engine,
        engine->camera.position.x,
        engine->camera.position.z,
        NULL
    ) + engine->eye_height_units;
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
    }

    engine->camera.position.y = jungle_terrain_height_at(
        engine,
        engine->camera.position.x,
        engine->camera.position.z,
        NULL
    ) + engine->eye_height_units;
    engine->frame_index += 1u;
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

    memset(out_snapshot, 0, sizeof(*out_snapshot));

    if (engine == NULL) {
        out_snapshot->camera_forward = jungle_vec3_make(0.0, 0.0, 1.0);
        out_snapshot->camera_right = jungle_vec3_make(1.0, 0.0, 0.0);
        out_snapshot->camera_aspect_ratio = 16.0 / 9.0;
        out_snapshot->vertical_field_of_view_radians = jungle_pi / 3.0;
        out_snapshot->world_units_per_meter = jungle_world_units_per_meter;
        out_snapshot->eye_height_units = 1.7;
        out_snapshot->ground_cover_height = jungle_ground_cover_height_units;
        out_snapshot->waist_height = jungle_waist_height_units;
        out_snapshot->head_height = jungle_head_height_units;
        out_snapshot->canopy_height = jungle_canopy_height_units;
        out_snapshot->visibility_distance = 64.0;
        out_snapshot->view_matrix = jungle_mat4_identity();
        out_snapshot->projection_matrix = jungle_mat4_identity();
        return;
    }

    jungle_biome_profile profile = {0};
    double floor_height = jungle_terrain_height_at(
        engine,
        engine->camera.position.x,
        engine->camera.position.z,
        &profile
    );
    jungle_graphics_quality quality =
        jungle_normalized_graphics_quality(engine->config.graphics_quality);
    uint32_t patch_side = jungle_patch_side_for_quality(quality);
    double patch_spacing = jungle_patch_spacing_for_quality(quality);
    uint32_t patch_sample_count = patch_side * patch_side;
    jungle_biome_kind primary_biome = jungle_primary_biome_kind(profile);

    out_snapshot->frame_index = engine->frame_index;
    out_snapshot->camera_height = engine->camera.position.y;
    out_snapshot->camera_floor_height = floor_height;
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

    out_snapshot->biome_kind = (uint32_t)primary_biome;
    out_snapshot->weather_kind = (uint32_t)jungle_weather_kind_for_profile(profile);
    out_snapshot->biome_blend = 1.0 - profile.grassland_weight;
    out_snapshot->world_units_per_meter = jungle_world_units_per_meter;
    out_snapshot->eye_height_units = engine->eye_height_units;
    out_snapshot->ground_cover_height = jungle_ground_cover_height_units;
    out_snapshot->waist_height = jungle_waist_height_units;
    out_snapshot->head_height = jungle_head_height_units;
    out_snapshot->canopy_height = jungle_canopy_height_units;
    out_snapshot->visibility_distance =
        82.0 * profile.grassland_weight +
        30.0 * profile.jungle_weight +
        116.0 * profile.beach_weight;
    out_snapshot->ambient_wetness =
        0.16 * profile.grassland_weight +
        0.72 * profile.jungle_weight +
        0.30 * profile.beach_weight +
        0.16 * profile.shoreline_space;
    out_snapshot->shoreline_space = profile.shoreline_space;
    out_snapshot->terrain_patch_side = patch_side;
    out_snapshot->terrain_patch_spacing = patch_spacing;
    out_snapshot->terrain_patch_center_x = engine->camera.position.x;
    out_snapshot->terrain_patch_center_z = engine->camera.position.z;
    out_snapshot->ground_material = jungle_ground_material_for_profile(profile);
    out_snapshot->ground_cover_material = jungle_ground_cover_material_for_profile(profile);
    out_snapshot->waist_material = jungle_waist_material_for_profile(profile);
    out_snapshot->head_material = jungle_head_material_for_profile(profile);
    out_snapshot->canopy_material = jungle_canopy_material_for_profile(profile);

    double patch_half_extent = ((double)patch_side - 1.0) * 0.5 * patch_spacing;

    for (uint32_t row = 0u; row < patch_side; row += 1u) {
        for (uint32_t column = 0u; column < patch_side; column += 1u) {
            uint32_t index = row * patch_side + column;
            double world_x = engine->camera.position.x - patch_half_extent +
                (double)column * patch_spacing;
            double world_z = engine->camera.position.z - patch_half_extent +
                (double)row * patch_spacing;
            jungle_biome_profile sample_profile = {0};
            float ground_cover = 0.0f;
            float waist = 0.0f;
            float head = 0.0f;
            float canopy = 0.0f;
            float wetness = 0.0f;
            double height = jungle_terrain_height_at(
                engine,
                world_x,
                world_z,
                &sample_profile
            );

            jungle_sample_layers(
                engine,
                world_x,
                world_z,
                height,
                sample_profile,
                &ground_cover,
                &waist,
                &head,
                &canopy,
                &wetness
            );

            out_snapshot->terrain_heights[index] = height;
            out_snapshot->terrain_ground_cover[index] = ground_cover;
            out_snapshot->terrain_waist[index] = waist;
            out_snapshot->terrain_head[index] = head;
            out_snapshot->terrain_canopy[index] = canopy;
            out_snapshot->terrain_wetness[index] = wetness;
        }
    }

    for (uint32_t index = patch_sample_count; index < JUNGLE_TERRAIN_PATCH_MAX_SAMPLES; index += 1u) {
        out_snapshot->terrain_heights[index] = 0.0;
        out_snapshot->terrain_ground_cover[index] = 0.0f;
        out_snapshot->terrain_waist[index] = 0.0f;
        out_snapshot->terrain_head[index] = 0.0f;
        out_snapshot->terrain_canopy[index] = 0.0f;
        out_snapshot->terrain_wetness[index] = 0.0f;
    }
}

const char *jungle_engine_version(void) {
    return "cycle-18-beach-biome";
}
