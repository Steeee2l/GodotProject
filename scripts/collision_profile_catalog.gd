class_name CollisionProfileCatalog
extends RefCounted

# Actors keep the legacy layers so interaction areas remain compatible.
# World movement and projectile blockers are intentionally separate.
const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const PLAYER_PROJECTILE_LAYER := 4
const ENEMY_PROJECTILE_LAYER := 8
const COMPANION_LAYER := 16
const WORLD_MOVEMENT_LAYER := 32
const WORLD_PROJECTILE_LAYER := 64

const PLAYER_MOVEMENT_MASK := WORLD_MOVEMENT_LAYER | ENEMY_LAYER
const ENEMY_MOVEMENT_MASK := WORLD_MOVEMENT_LAYER | PLAYER_LAYER | ENEMY_LAYER
const PROJECTILE_MASK := PLAYER_LAYER | ENEMY_LAYER | WORLD_PROJECTILE_LAYER
const WORLD_ONLY_SIGHT_MASK := WORLD_PROJECTILE_LAYER

const PROFILES := {
	"vehicle_standard": {
		"movement_scale": Vector3(0.94, 1.0, 0.92),
		"movement_height": 0.78,
		"projectile_scale": Vector3(1.0, 1.0, 1.0),
		"projectile_min_height": 1.15,
	},
	"vehicle_heavy": {
		"movement_scale": Vector3(0.96, 1.0, 0.94),
		"movement_height": 0.92,
		"projectile_scale": Vector3(1.0, 1.0, 1.0),
		"projectile_min_height": 1.45,
	},
	"road_barricade": {
		"movement_scale": Vector3(0.96, 1.0, 0.96),
		"movement_height": 0.72,
		"projectile_scale": Vector3(1.0, 1.0, 1.0),
		"projectile_min_height": 1.18,
	},
	"rubble_wall": {
		"movement_scale": Vector3(0.96, 1.0, 0.96),
		"movement_height": 0.70,
		"projectile_scale": Vector3(1.0, 1.0, 1.0),
		"projectile_min_height": 1.32,
	},
	"street_cluster": {
		"movement_scale": Vector3(0.84, 1.0, 0.82),
		"movement_height": 0.74,
		"projectile_scale": Vector3(0.94, 1.0, 0.94),
		"projectile_min_height": 1.25,
	},
	"handcart": {
		"movement_scale": Vector3(0.82, 1.0, 0.78),
		"movement_height": 0.62,
		"projectile_scale": Vector3(0.92, 1.0, 0.90),
		"projectile_min_height": 1.05,
	},
	"furniture_table": {
		"movement_scale": Vector3(0.82, 1.0, 0.78),
		"movement_height": 0.72,
		"projectile_scale": Vector3(0.94, 1.0, 0.92),
		"projectile_min_height": 1.05,
	},
	"furniture_solid": {
		"movement_scale": Vector3(0.90, 1.0, 0.88),
		"movement_height": 0.82,
		"projectile_scale": Vector3(0.98, 1.0, 0.98),
		"projectile_min_height": 1.20,
	},
	"thin_wall": {
		"movement_scale": Vector3(1.0, 1.0, 1.0),
		"movement_height_scale": 1.0,
		"projectile_scale": Vector3(1.04, 1.0, 1.04),
		"projectile_min_height": 1.0,
	},
	"building": {
		"movement_scale": Vector3(1.0, 1.0, 1.0),
		"movement_height": 1.15,
		"projectile_scale": Vector3(1.0, 1.0, 1.0),
		"projectile_min_height": 3.0,
	},
}


static func get_profile(profile_id: String, base_size: Vector3) -> Dictionary:
	var definition: Dictionary = PROFILES.get(profile_id, PROFILES["furniture_solid"])
	var movement_scale: Vector3 = definition.get("movement_scale", Vector3.ONE)
	var projectile_scale: Vector3 = definition.get("projectile_scale", Vector3.ONE)
	var movement_height := float(definition.get(
		"movement_height",
		base_size.y * float(definition.get("movement_height_scale", 1.0))
	))
	var projectile_height := maxf(
		base_size.y * projectile_scale.y,
		float(definition.get("projectile_min_height", base_size.y))
	)
	return {
		"profile_id": profile_id,
		"movement_size": Vector3(
			maxf(0.18, base_size.x * movement_scale.x),
			maxf(0.18, minf(base_size.y, movement_height)),
			maxf(0.18, base_size.z * movement_scale.z)
		),
		"projectile_size": Vector3(
			maxf(0.12, base_size.x * projectile_scale.x),
			maxf(0.28, projectile_height),
			maxf(0.12, base_size.z * projectile_scale.z)
		),
	}


# screen_angle_to_world_yaw / sprite_tilt_to_collision_yaw 는 제거했다.
# 차량·엄폐물 스프라이트는 전부 BILLBOARD_ENABLED 라 셰이더가 노드 basis 를 카메라
# basis 로 갈아끼운다 — 스프라이트의 화면 회전은 애초에 그려지지 않는데, 그 값으로
# 충돌 상자의 yaw 를 돌리고 있었다. 그림과 충돌이 어긋나던 근본 원인이다.
# 이제 접지 사각형은 scripts/vehicle_footprint.gd 가 아트에서 직접 유도하고,
# 충돌 상자는 축정렬(yaw = 0) 상태로 x/z 크기만 바꿔 맞춘다.
