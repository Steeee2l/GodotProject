extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var player := main_scene.get("player") as CharacterBody3D
	var mission_sites: Array[Node3D] = main_scene.get("field_mission_sites")
	var field_interactions: Array[Node3D] = main_scene.get("field_interactions")
	assert(player != null)
	assert(not mission_sites.is_empty())
	var initial_player_position := player.global_position
	for mission_site in mission_sites:
		assert(mission_site.global_position.distance_to(initial_player_position) >= 30.0)

	var site := mission_sites[0]
	site.set_meta("type", "defense")
	site.set_meta("title", "상호작용 임무 검사")
	site.set_meta("description", "준비 후 외곽에서 적이 접근해야 합니다.")
	site.set_meta("enemy_count", 7)
	site.set_meta("duration", 20.0)
	player.global_position = site.global_position
	player.force_update_transform()

	main_scene.call("_update_field_missions", 0.1)
	assert(not is_instance_valid(main_scene.get("active_field_mission")))
	assert(field_interactions.has(site))

	main_scene.call("_complete_field_interaction", site)
	assert(main_scene.get("active_field_mission") == site)
	assert(str(main_scene.get("field_mission_phase")) == "preparing")
	assert(is_equal_approx(float(main_scene.get("field_mission_prepare_timer")), 7.0))
	assert(int(main_scene.get("field_mission_spawned_enemies")) == 0)
	var objective_label := main_scene.get("objective_label") as Label
	assert(objective_label.text.count("\n") <= 3)
	assert(not objective_label.text.contains("실패 조건"))
	assert(not objective_label.text.contains("보상"))

	main_scene.call("_update_field_missions", 2.0)
	assert(str(main_scene.get("field_mission_phase")) == "preparing")
	assert(int(main_scene.get("field_mission_spawned_enemies")) == 0)
	assert(objective_label != null and objective_label.text.contains("시작까지"))

	main_scene.call("_update_field_missions", 5.1)
	assert(str(main_scene.get("field_mission_phase")) == "active")
	assert(int(main_scene.get("field_mission_spawned_enemies")) == 0)
	assert(objective_label.text.contains("다음 접근"))

	main_scene.call("_update_field_missions", 3.3)
	var spawned_count := int(main_scene.get("field_mission_spawned_enemies"))
	assert(spawned_count >= 2 and spawned_count <= 3)
	var first_wave_interval := float(main_scene.get("field_mission_wave_timer"))
	assert(is_equal_approx(first_wave_interval, 6.0))

	main_scene.call("_update_field_missions", first_wave_interval + 0.1)
	var escalated_count := int(main_scene.get("field_mission_spawned_enemies"))
	var escalated_interval := float(main_scene.get("field_mission_wave_timer"))
	assert(escalated_count > spawned_count)
	assert(escalated_interval < first_wave_interval)

	var mission_id := int(site.get_meta("mission_id", 0))
	var safe_spawn_count := 0
	for enemy_node in main_scene.get("enemies"):
		var enemy := enemy_node as CharacterBody3D
		if (
			is_instance_valid(enemy)
			and int(enemy.get_meta("field_mission_id", -1)) == mission_id
		):
			assert(enemy.global_position.distance_to(player.global_position) >= 18.0)
			safe_spawn_count += 1
	assert(safe_spawn_count == escalated_count)

	print(
		"FIELD_MISSION_START_OK interaction=true countdown=true waves=true escalation=true safe=true"
	)
	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	main_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)
