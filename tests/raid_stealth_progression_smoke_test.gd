extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var missions: Array[Dictionary] = main_scene.get("basic_raid_missions")
	assert(missions.size() == 2)
	var objective_panel := main_scene.get("objective_panel") as PanelContainer
	var objective_label := main_scene.get("objective_label") as Label
	assert(objective_panel.visible)
	assert(objective_label.text.contains("기초 부품 확보"))
	assert(objective_label.text.contains("지하철역 입구 조사"))
	assert(objective_label.text.contains("목적"))
	assert(objective_label.text.contains("보상"))

	var lore_clues: Array[Node3D] = main_scene.get("lore_clues")
	assert(lore_clues.size() == 6)
	var player := main_scene.get("player") as CharacterBody3D
	for lore_point in lore_clues:
		assert(is_instance_valid(lore_point))
		assert(lore_point.global_position.distance_to(player.global_position) >= 24.0)
		assert(lore_point.get_node_or_null("LoreNoticeBoard") is Sprite3D)
	main_scene.call("_complete_field_interaction", lore_clues[0])
	var lore_layer := main_scene.get("lore_ui_layer") as CanvasLayer
	assert(is_instance_valid(lore_layer) and lore_layer.visible)
	assert(not (main_scene.get("lore_title_label") as Label).text.is_empty())
	assert(int(main_scene.get("lore_clues_discovered")) == 1)
	main_scene.call("_close_lore_reader")
	assert(not lore_layer.visible)

	main_scene.call("_advance_basic_mission", "parts", 2)
	assert(bool(missions[0].get("completed", false)))
	assert(int(main_scene.get("completed_mission_xp")) == 90)

	var subway_site := main_scene.get("basic_subway_mission_site") as Node3D
	assert(is_instance_valid(subway_site))
	main_scene.call("_complete_field_interaction", subway_site)
	assert(bool(missions[1].get("completed", false)))
	assert(int(main_scene.get("completed_mission_xp")) == 210)

	main_scene.set("fatigue", 50.0)
	main_scene.call("_trigger_fatigue_boss_event")
	assert(bool(main_scene.get("fatigue_boss_event_triggered")))
	var found_boss := false
	for enemy in main_scene.get("enemies"):
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			found_boss = true
			assert(str(enemy.get_meta("display_name", "")).contains("묘르"))
			var tactical_map := main_scene.get("tactical_map") as Control
			assert((tactical_map.get("boss_targets") as Array).has(enemy))
			break
	assert(found_boss)

	main_scene.call("_show_extraction_result", 0)
	var summary := main_scene.get("extraction_result_summary") as Label
	assert(summary.text.contains("기초 부품 확보"))
	assert(summary.text.contains("지하철역 입구 조사"))
	assert(summary.text.contains("임무 XP +210"))

	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	main_scene.queue_free()
	await process_frame
	print("RAID_STEALTH_PROGRESSION_OK")
	quit(0)
