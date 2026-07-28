extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("returning_from_shelter", true)
	var main_scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main_scene)
	await process_frame

	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	var camera_rig := main_scene.get_node("CameraRig") as Node3D
	var player := main_scene.get_node("Player") as CharacterBody3D
	var expected_camera_focus := Vector3(player.position.x, 0.0, player.position.z)
	assert(
		camera_rig.position.distance_to(expected_camera_focus) < 0.01,
		"A shelter departure must snap the camera to the player before the first visible frame."
	)
	var entry_fade := main_scene.get("extraction_fade") as ColorRect
	assert(is_instance_valid(entry_fade) and entry_fade.color.a > 0.8)
	var found_long_road_patrol := false
	for enemy_value in main_scene.get("enemies"):
		var enemy := enemy_value as CharacterBody3D
		if not is_instance_valid(enemy) or str(enemy.get("patrol_mode")) != "road_route":
			continue
		var patrol_route := enemy.get("patrol_route") as Array
		var route_span := 0.0
		for first_point in patrol_route:
			for second_point in patrol_route:
				var first_vector: Vector3 = first_point
				var second_vector: Vector3 = second_point
				route_span = maxf(route_span, first_vector.distance_to(second_vector))
		if route_span >= 100.0:
			found_long_road_patrol = true
			break
	assert(found_long_road_patrol, "At least one normal raid squad must receive a long road patrol.")
	await physics_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	var bottom_center := Vector2(viewport_size.x * 0.5, viewport_size.y)
	var bottom_ray_origin := camera.project_ray_origin(bottom_center)
	assert(bottom_ray_origin.y > 0.5)
	print("CAMERA_GROUND_COVERAGE_OK bottom_ray_y=%.3f" % bottom_ray_origin.y)
	quit(0)
