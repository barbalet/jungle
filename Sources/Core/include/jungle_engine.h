#ifndef JUNGLE_ENGINE_H
#define JUNGLE_ENGINE_H

#include "jungle_camera.h"

#include <stdbool.h>
#include <stdint.h>

#define JUNGLE_TERRAIN_PATCH_MAX_SIDE 33u
#define JUNGLE_TERRAIN_PATCH_MAX_SAMPLES \
    (JUNGLE_TERRAIN_PATCH_MAX_SIDE * JUNGLE_TERRAIN_PATCH_MAX_SIDE)

typedef struct jungle_engine jungle_engine;

typedef enum jungle_graphics_quality {
    JUNGLE_GRAPHICS_QUALITY_LOW = 0,
    JUNGLE_GRAPHICS_QUALITY_MEDIUM = 1,
    JUNGLE_GRAPHICS_QUALITY_HIGH = 2,
} jungle_graphics_quality;

typedef enum jungle_biome_selection {
    JUNGLE_BIOME_SELECTION_AUTOMATIC = 0,
    JUNGLE_BIOME_SELECTION_GRASSLAND = 1,
    JUNGLE_BIOME_SELECTION_JUNGLE = 2,
    JUNGLE_BIOME_SELECTION_BEACH = 3,
} jungle_biome_selection;

typedef enum jungle_biome_kind {
    JUNGLE_BIOME_KIND_GRASSLAND = 1,
    JUNGLE_BIOME_KIND_JUNGLE = 2,
    JUNGLE_BIOME_KIND_BEACH = 3,
} jungle_biome_kind;

typedef enum jungle_weather_kind {
    JUNGLE_WEATHER_KIND_CLEAR_BREEZE = 1,
    JUNGLE_WEATHER_KIND_HUMID_CANOPY = 2,
    JUNGLE_WEATHER_KIND_COASTAL_HAZE = 3,
} jungle_weather_kind;

typedef struct jungle_material_channel {
    float red;
    float green;
    float blue;
    float alpha;
    float motion;
    float wetness_response;
} jungle_material_channel;

typedef struct jungle_engine_config {
    uint64_t seed;
    double initial_camera_height;
    uint32_t graphics_quality;
    uint32_t initial_biome;
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
    double camera_floor_height;
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

    uint32_t biome_kind;
    uint32_t weather_kind;
    double biome_blend;
    double world_units_per_meter;
    double eye_height_units;
    double ground_cover_height;
    double waist_height;
    double head_height;
    double canopy_height;
    double visibility_distance;
    double ambient_wetness;
    double shoreline_space;

    uint32_t terrain_patch_side;
    double terrain_patch_spacing;
    double terrain_patch_center_x;
    double terrain_patch_center_z;

    jungle_material_channel ground_material;
    jungle_material_channel ground_cover_material;
    jungle_material_channel waist_material;
    jungle_material_channel head_material;
    jungle_material_channel canopy_material;

    double terrain_heights[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
    float terrain_ground_cover[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
    float terrain_waist[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
    float terrain_head[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
    float terrain_canopy[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
    float terrain_wetness[JUNGLE_TERRAIN_PATCH_MAX_SAMPLES];
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
