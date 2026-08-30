extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("map_seed", 47291)
	game_state.set("raid_danger", 1.0)
	game_state.call("start_new_raid")
	assert(is_zero_approx(float(game_state.get("raid_danger"))), "A shelter departure must begin with zero raid danger.")
	var first_seed := int(game_state.get("map_seed"))
	game_state.call("start_new_raid")
	var second_seed := int(game_state.get("map_seed"))
	assert(first_seed != second_seed, "Every shelter departure must generate a new raid seed.")
	assert(int(game_state.get("raid_serial")) == 2)

	var map_script := load("res://scripts/procedural_map.gd") as Script
	var first_city := map_script.new() as Node3D
	first_city.set("map_seed", first_seed)
	root.add_child(first_city)
	await process_frame
	var first_signature := _layout_signature(first_city)
	first_city.queue_free()
	await process_frame

	var second_city := map_script.new() as Node3D
	second_city.set("map_seed", second_seed)
	root.add_child(second_city)
	await process_frame
	var second_signature := _layout_signature(second_city)
	assert(first_signature != second_signature, "Different raid seeds must produce different city structures.")
	assert(str(second_city.call("get_sector_label", Vector3.ZERO)).contains("-"))
	var long_patrol_route := second_city.call(
		"get_long_road_patrol_route",
		second_city.call("get_shelter_exit_position"),
		17,
		[]
	) as Array
	assert(long_patrol_route.size() >= 5, "Road patrols need enough waypoints for a visible long route.")
	var patrol_span := 0.0
	for first_point in long_patrol_route:
		for second_point in long_patrol_route:
			patrol_span = maxf(patrol_span, (first_point as Vector3).distance_to(second_point as Vector3))
	assert(patrol_span >= 100.0, "Road patrol routes must cover a substantial stretch of road.")

	var tactical_map := load("res://scripts/tactical_map.gd").new() as Control
	var map_player := Node3D.new()
	root.add_child(map_player)
	var extraction_positions: Array[Vector3] = [Vector3(30, 0, 30), Vector3(-30, 0, 20)]
	tactical_map.call("setup", second_city, map_player, extraction_positions)
	assert(not bool(tactical_map.call("is_extraction_discovered", 0)))
	tactical_map.call("discover_extraction", 0)
	assert(bool(tactical_map.call("is_extraction_discovered", 0)))
	assert(not bool(tactical_map.call("is_extraction_discovered", 1)))
	var map_rect := Rect2(Vector2(100, 80), Vector2(800, 480))
	var map_size := float(second_city.call("get_map_snapshot_data")["map_size"])
	var center := tactical_map.call("_world_position_to_map_point", Vector3.ZERO, map_rect, map_size) as Vector2
	assert(center.distance_to(map_rect.get_center()) < 0.01)
	var screen_right := tactical_map.call("_world_position_to_map_point", Vector3(20, 0, -20), map_rect, map_size) as Vector2
	var screen_down := tactical_map.call("_world_position_to_map_point", Vector3(20, 0, 20), map_rect, map_size) as Vector2
	assert(screen_right.x > center.x and absf(screen_right.y - center.y) < 0.01)
	assert(screen_down.y > center.y and absf(screen_down.x - center.x) < 0.01)

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("map_layer.layer = 170"), "Tactical map must render above combat HUD layers.")
	var callback_start := main_source.find("func _on_tactical_map_open_state_changed")
	var callback_end := main_source.find("\nfunc ", callback_start + 1)
	var callback_source := main_source.substr(callback_start, callback_end - callback_start)
	assert(
		callback_source.contains("_update_combat_overlay_visibility()"),
		"Opening or closing the tactical map must refresh aim and world-health overlays."
	)

	print("RAID_MAP_NAVIGATION_SMOKE: PASS seeds=%d/%d patrol_span=%.1f" % [first_seed, second_seed, patrol_span])
	tactical_map.free()
	map_player.queue_free()
	second_city.queue_free()
	await process_frame
	quit(0)


func _layout_signature(city: Node3D) -> String:
	var vertical: Array = city.get("vertical_roads")
	var horizontal: Array = city.get("horizontal_roads")
	var buildings: Array = (city.get("building_cells") as Dictionary).keys()
	buildings.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return "%s|%s|%s" % [vertical, horizontal, buildings]
