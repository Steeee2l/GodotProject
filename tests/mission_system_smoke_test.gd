extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	_verify_mission_distribution(main_scene)
	_verify_compact_objective_ui(main_scene)
	_verify_detection_scope(main_scene)
	_verify_defense_completion_gate(main_scene)
	_verify_completion_paths(main_scene)
	_verify_reward_fallbacks(main_scene, game_state)
	_verify_failure_path(main_scene)

	print("MISSION_SYSTEM_OK types=6 ui=compact detection=scoped flows=6 rewards=safe failure=true")
	main_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _verify_mission_distribution(main_scene: Node) -> void:
	var found_types: Dictionary = {}
	for site_value in main_scene.get("field_missions").field_mission_sites:
		var site := site_value as Node3D
		found_types[str(site.get_meta("type", ""))] = true
	for mission_type in ["defense", "eliminate", "collect", "stealth", "investigate", "stealth_reach"]:
		assert(found_types.has(mission_type), "Missing guaranteed mission type: %s" % mission_type)


func _verify_compact_objective_ui(main_scene: Node) -> void:
	main_scene.call("_refresh_objective_panel")
	var objective_label := main_scene.get("objective_label") as Label
	assert(objective_label.text.contains("기초 부품 확보"))
	assert(objective_label.text.contains("지하철역 입구 조사"))
	assert(objective_label.text.count("\n") <= 1)


func _verify_detection_scope(main_scene: Node) -> void:
	var site := _make_active_site(main_scene, "stealth", 701, {
		"duration": 10.0,
		"guard_count": 1,
		"detection_grace": 1.5,
		"silence_required": true,
	})
	var enemy := (main_scene.get("enemies") as Array)[0] as CharacterBody3D
	enemy.set("alerted", true)
	enemy.set("has_current_line_of_sight", true)
	enemy.set_meta("field_mission_id", 999)
	assert(not bool(main_scene.call("_is_player_detected_for_field_mission")))
	enemy.set_meta("field_mission_id", int(site.get_meta("mission_id", 0)))
	assert(bool(main_scene.call("_is_player_detected_for_field_mission")))
	enemy.set("alerted", false)
	enemy.set("has_current_line_of_sight", false)
	main_scene.call("_fail_field_mission", "검증 종료")


func _verify_defense_completion_gate(main_scene: Node) -> void:
	var site := _make_active_site(main_scene, "defense", 702, {
		"duration": 1.0,
		"enemy_count": 2,
	})
	main_scene.set("field_mission_elapsed", 1.0)
	main_scene.set("field_mission_spawned_enemies", 0)
	main_scene.call("_update_defense_mission", 0.0, 0.0)
	assert(main_scene.get("active_field_mission") == site)
	main_scene.set("field_mission_spawned_enemies", 2)
	main_scene.call("_update_defense_mission", 0.0, 0.0)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))
	assert(str(site.get_meta("status", "")) == "completed")


func _verify_completion_paths(main_scene: Node) -> void:
	var player := main_scene.get("player") as CharacterBody3D

	_make_active_site(main_scene, "eliminate", 703, {"target_count": 2, "enemy_count": 2})
	main_scene.set("field_mission_kills", 2)
	main_scene.call("_update_eliminate_mission")
	assert(not is_instance_valid(main_scene.get("active_field_mission")))

	_make_active_site(main_scene, "collect", 704, {"target_count": 2, "enemy_count": 0})
	for index in 2:
		var collectible := Node3D.new()
		collectible.name = "TestCollectible%d" % index
		main_scene.add_child(collectible)
		collectible.global_position = player.global_position
		(main_scene.get("active_mission_collectibles") as Array).append(collectible)
	main_scene.call("_update_collect_mission")
	assert(not is_instance_valid(main_scene.get("active_field_mission")))

	_make_active_site(main_scene, "stealth", 705, {
		"duration": 1.0,
		"guard_count": 0,
		"detection_grace": 1.5,
		"silence_required": true,
	})
	main_scene.set("field_mission_runtime", 2.0)
	main_scene.call("_update_stealth_mission", 1.1, 0.0)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))

	_make_active_site(main_scene, "investigate", 706, {
		"target_count": 2,
		"investigate_duration": 0.1,
		"guard_count": 0,
		"silence_required": false,
	})
	main_scene.set("field_mission_runtime", 2.0)
	for index in 2:
		var clue := Node3D.new()
		clue.name = "TestClue%d" % index
		main_scene.add_child(clue)
		clue.global_position = player.global_position + Vector3(float(index) * 0.1, 0.0, 0.0)
		(main_scene.get("active_mission_collectibles") as Array).append(clue)
	main_scene.call("_update_investigation_mission", 0.2)
	main_scene.call("_update_investigation_mission", 0.2)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))

	_make_active_site(main_scene, "stealth_reach", 707, {
		"guard_count": 0,
		"detection_grace": 1.5,
		"silence_required": true,
	})
	main_scene.set("field_mission_runtime", 2.0)
	var target := Node3D.new()
	target.name = "TestReachTarget"
	main_scene.add_child(target)
	target.global_position = player.global_position
	(main_scene.get("active_mission_collectibles") as Array).append(target)
	main_scene.call("_update_stealth_reach_mission", 0.1)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))


func _verify_reward_fallbacks(main_scene: Node, game_state: Node) -> void:
	game_state.set("equipped_weapon_id", "")
	game_state.set("equipped_ammo_id", "")
	var ammo_before := int(game_state.call("get_ammo_count", "9mm_fmj"))
	var component_before := _component_total(game_state.get("mod_component_inventory") as Dictionary)
	main_scene.call("_grant_field_mission_reward", {"ammo": 7, "component": 2})
	assert(int(game_state.call("get_ammo_count", "9mm_fmj")) == ammo_before + 7)
	assert(not (game_state.get("ammo_inventory") as Dictionary).has(""))
	assert(_component_total(game_state.get("mod_component_inventory") as Dictionary) == component_before + 2)


func _verify_failure_path(main_scene: Node) -> void:
	var site := _make_active_site(main_scene, "collect", 708, {"target_count": 1, "enemy_count": 0})
	var player := main_scene.get("player") as CharacterBody3D
	player.global_position = site.global_position + Vector3(80.0, 0.0, 0.0)
	main_scene.call("_update_field_missions", 0.1)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))
	assert(str(site.get_meta("status", "")) == "failed")


func _make_active_site(main_scene: Node, mission_type: String, mission_id: int, values: Dictionary) -> Node3D:
	var site := Node3D.new()
	site.name = "MissionFlowTest_%d" % mission_id
	main_scene.add_child(site)
	site.global_position = (main_scene.get("player") as CharacterBody3D).global_position
	site.set_meta("mission_id", mission_id)
	site.set_meta("type", mission_type)
	site.set_meta("title", "검증 임무")
	site.set_meta("description", "검증")
	site.set_meta("reward", {})
	site.set_meta("status", "active")
	site.set_meta("marker_material", StandardMaterial3D.new())
	site.set_meta("active_boundary_material", StandardMaterial3D.new())
	for key in values:
		site.set_meta(str(key), values[key])
	main_scene.set("active_field_mission", site)
	main_scene.set("field_mission_phase", "active")
	main_scene.set("field_mission_runtime", 0.0)
	main_scene.set("field_mission_elapsed", 0.0)
	main_scene.set("field_mission_spawned_enemies", 0)
	main_scene.set("field_mission_kills", 0)
	main_scene.set("field_mission_collected", 0)
	main_scene.set("field_mission_detection_time", 0.0)
	main_scene.set("field_mission_noise_breached", false)
	main_scene.set("active_mission_collectibles", [])
	return site


func _component_total(inventory: Dictionary) -> int:
	var total := 0
	for value in inventory.values():
		total += maxi(0, int(value))
	return total
