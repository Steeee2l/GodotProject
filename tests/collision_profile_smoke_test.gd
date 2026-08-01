extends SceneTree

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")


func _init() -> void:
	_assert_layer_contract()
	_assert_vehicle_profile()
	_assert_road_cover_profiles()
	_assert_table_profile()
	print("collision_profile_smoke_test: PASS")
	quit()


func _assert_layer_contract() -> void:
	assert(
		COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		!= COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	)
	assert(
		COLLISION_PROFILES.PLAYER_MOVEMENT_MASK
		& COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	)
	assert(
		COLLISION_PROFILES.PROJECTILE_MASK
		& COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	)


func _assert_vehicle_profile() -> void:
	var base_size := Vector3(4.2, 1.4, 1.9)
	var profile := COLLISION_PROFILES.get_profile("vehicle_standard", base_size)
	var movement_size: Vector3 = profile["movement_size"]
	var projectile_size: Vector3 = profile["projectile_size"]
	assert(movement_size.x < base_size.x)
	assert(movement_size.z < base_size.z)
	assert(projectile_size.x > movement_size.x)
	assert(projectile_size.y > movement_size.y)


func _assert_table_profile() -> void:
	var base_size := Vector3(2.4, 1.1, 1.0)
	var profile := COLLISION_PROFILES.get_profile("furniture_table", base_size)
	var movement_size: Vector3 = profile["movement_size"]
	var projectile_size: Vector3 = profile["projectile_size"]
	assert(movement_size.z <= base_size.z * 0.8)
	assert(projectile_size.y >= 1.0)


func _assert_road_cover_profiles() -> void:
	for profile_id in ["road_barricade", "rubble_wall"]:
		var base_size := Vector3(1.1, 1.4, 5.0)
		var profile := COLLISION_PROFILES.get_profile(profile_id, base_size)
		var movement_size: Vector3 = profile["movement_size"]
		var projectile_size: Vector3 = profile["projectile_size"]
		assert(movement_size.x >= base_size.x * 0.95)
		assert(movement_size.z >= base_size.z * 0.95)
		assert(projectile_size.x >= movement_size.x)
		assert(projectile_size.z >= movement_size.z)
