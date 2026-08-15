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


const SCREEN_RIGHT_AXIS_SCALE := 1.4142135623730951  # 1 / (1/√2)
const SCREEN_UP_AXIS_SCALE := 2.449489742783178      # 1 / (1/√6)

# 월드 +Z가 화면에 맺히는 각도. 세로로 놓인 아트의 기준 각도다.
const SCREEN_ANGLE_FOR_WORLD_Z_DEG := 210.0


static func screen_angle_to_world_yaw(screen_degrees: float) -> float:
	# 반환값은 "긴 축이 Z인 상자"에 그대로 넣을 수 있는 yaw(도)다.
	var alpha := deg_to_rad(screen_degrees)
	var sin_a := sin(alpha)
	var cos_a := cos(alpha)
	var axis_x := cos_a * SCREEN_RIGHT_AXIS_SCALE - sin_a * SCREEN_UP_AXIS_SCALE
	var axis_z := -sin_a * SCREEN_UP_AXIS_SCALE - cos_a * SCREEN_RIGHT_AXIS_SCALE
	var phi := atan2(axis_z, axis_x)
	# Godot의 yaw는 +Z를 (sin ψ, 0, cos ψ)로 보낸다. φ = 90° - ψ.
	return rad_to_deg(PI * 0.5 - phi)


static func sprite_tilt_to_collision_yaw(sprite_screen_rotation_degrees: float) -> float:
	# 스프라이트를 화면에서 기울인 만큼 충돌 상자를 월드에서 돌린다.
	# 기울기가 0이면 yaw도 0이 되어 아트의 원래 축과 정확히 일치한다.
	return screen_angle_to_world_yaw(
		SCREEN_ANGLE_FOR_WORLD_Z_DEG + sprite_screen_rotation_degrees
	)
