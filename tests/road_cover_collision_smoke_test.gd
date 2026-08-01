extends SceneTree

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_script: Script = load("res://scripts/procedural_map.gd")
	var projectile_script: Script = load("res://scripts/bullet_projectile.gd")
	var city: Node3D = map_script.new()
	city.set("map_seed", 42)
	root.add_child(city)
	await process_frame
	await physics_frame

	var covers: Array[Node] = []
	for child in city.get_children():
		if child.is_in_group("road_cover_obstacle"):
			covers.append(child)
	assert(covers.size() >= 4)

	for cover_node in covers:
		var cover := cover_node as StaticBody3D
		var collision := cover.get_node("CoverCollision") as CollisionShape3D
		var sprite := cover.get_node("CoverSprite") as Sprite3D
		var debug_mesh := cover.get_node("CoverCollisionDebug") as MeshInstance3D
		var projectile_collision := cover.get_node(
			"ProjectileBlocker/ProjectileCollision"
		) as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		var projectile_shape := projectile_collision.shape as BoxShape3D
		var cover_type := str(cover.get_meta("cover_type"))
		assert(cover.collision_layer == COLLISION_PROFILES.WORLD_MOVEMENT_LAYER)
		assert(sprite.texture != null)
		assert(sprite.pixel_size > 0.0)
		assert(is_equal_approx(sprite.position.x, collision.position.x))
		assert(is_equal_approx(sprite.position.z, collision.position.z))
		assert(is_equal_approx(debug_mesh.position.x, collision.position.x))
		assert(is_equal_approx(debug_mesh.position.z, collision.position.z))
		assert(debug_mesh.visible)
		var debug_plane := debug_mesh.mesh as PlaneMesh
		assert(debug_plane != null)
		assert(debug_plane.size.is_equal_approx(Vector2(shape.size.x, shape.size.z)))
		assert(projectile_shape.size.x >= shape.size.x)
		assert(projectile_shape.size.z >= shape.size.z)
		if cover_type.ends_with("axis_a"):
			assert(shape.size.z > shape.size.x)
		elif cover_type.ends_with("axis_b"):
			assert(shape.size.x > shape.size.z)

		var cross_axis := (
			Vector3(0.0, 0.0, 1.0)
			if shape.size.x >= shape.size.z
			else Vector3(1.0, 0.0, 0.0)
		)
		var cross_distance := minf(shape.size.x, shape.size.z) * 0.5 + 0.7
		var collision_center := collision.global_position
		var from := collision_center - cross_axis * cross_distance
		var to := collision_center + cross_axis * cross_distance
		var query := PhysicsRayQueryParameters3D.create(
			from,
			to,
			COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		)
		var hit := city.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		assert(hit.get("collider") == cover)

	var projectile: Area3D = projectile_script.new()
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	var target_cover := covers[0] as StaticBody3D
	var target_shape := (target_cover.get_node("CoverCollision") as CollisionShape3D).shape as BoxShape3D
	var projectile_direction := (
		Vector3(0.0, 0.0, 1.0)
		if target_shape.size.x >= target_shape.size.z
		else Vector3(1.0, 0.0, 0.0)
	)
	var projectile_distance := minf(target_shape.size.x, target_shape.size.z) * 0.5 + 0.7
	var target_center := (target_cover.get_node("CoverCollision") as CollisionShape3D).global_position
	var projectile_from := (
		target_center
		- projectile_direction * projectile_distance
	)
	var projectile_to := (
		target_center
		+ projectile_direction * projectile_distance
	)
	projectile.set("direction", projectile_direction)
	projectile.position = projectile_from
	city.add_child(projectile)
	await process_frame
	var exclusions: Array[RID] = []
	var swept_hit: Dictionary = projectile.call(
		"_find_swept_hit",
		projectile_from,
		projectile_to,
		exclusions
	)
	assert(not swept_hit.is_empty())
	var projectile_collider := swept_hit.get("collider") as Node
	assert(projectile_collider != null)
	assert(projectile_collider.is_in_group("projectile_blocker"))

	print("ROAD_COVER_COLLISION_OK covers=%d projectile_blocked=true" % covers.size())
	quit(0)
