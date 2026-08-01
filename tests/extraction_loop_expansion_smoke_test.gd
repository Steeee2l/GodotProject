extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	var preview := game_state.call("build_raid_loadout_manifest", "jongno_outskirts") as Dictionary
	assert(str(preview.get("weapon_id", "")) == "ak47")
	assert(int(preview.get("ammo_count", 0)) > 0)
	assert(int(preview.get("storage_capacity", 0)) == 30)
	var confirmed := game_state.call("confirm_raid_loadout", "jongno_outskirts") as Dictionary
	assert(str(confirmed.get("zone_id", "")) == "jongno_outskirts")
	assert(not (game_state.get("confirmed_raid_manifest") as Dictionary).is_empty())

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var enemies: Array = main_scene.get("enemies")
	assert(not enemies.is_empty())
	var enemy := enemies[0] as CharacterBody3D
	for enemy_candidate in enemies:
		if str((enemy_candidate as CharacterBody3D).get("enemy_kind")) != "melee":
			enemy = enemy_candidate as CharacterBody3D
			break
	var player := main_scene.get("player") as CharacterBody3D
	var extraction_sites: Array = main_scene.get("extraction_sites")
	assert(extraction_sites.size() >= 3)
	var entry_extraction := extraction_sites[0] as Node3D
	var entry_distance := entry_extraction.global_position.distance_to(player.global_position)
	assert(entry_distance >= 23.5)
	assert(bool(entry_extraction.get_meta("map_discovered", false)))
	assert(entry_extraction.get_node_or_null("SewerHatch") is Sprite3D)
	assert(bool((main_scene.get("discovered_extraction_indices") as Dictionary).get(0, false)))
	for index in extraction_sites.size():
		for other_index in range(index + 1, extraction_sites.size()):
			assert(
				(extraction_sites[index] as Node3D).global_position.distance_to(
					(extraction_sites[other_index] as Node3D).global_position
				) >= 31.5
			)
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 13.0)
	var facing_player := player.global_position - enemy.global_position
	facing_player.y = 0.0
	enemy.set("target", player)
	enemy.set("primary_player_target", player)
	enemy.set("facing_world_direction", facing_player.normalized())
	enemy.set("alerted", false)
	enemy.set("detection_awareness", 0.0)
	enemy.set("perception_state", "patrol")
	enemy.set("patrol_pause", 100.0)
	var vision_range := float(enemy.call("_get_vision_range"))
	assert(vision_range >= 19.0 and vision_range <= 23.0)
	var combat_lock_range := float(enemy.call("_get_combat_lock_range"))
	assert(combat_lock_range >= 20.0)
	assert(combat_lock_range >= float(enemy.call("_get_weapon_engagement_range")) * 0.9)
	assert(float(enemy.call("_get_search_break_distance")) >= combat_lock_range + 9.9)
	enemy.set("combat_state", "reloading")
	enemy.set("reload_elapsed", 0.0)
	enemy.set("reload_duration", 2.0)
	enemy.call("_update_reload", 0.1)
	var reload_chase_direction := player.global_position - enemy.global_position
	reload_chase_direction.y = 0.0
	assert((enemy.get("velocity") as Vector3).dot(reload_chase_direction.normalized()) > 0.0)
	enemy.set("combat_state", "normal")
	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.call("_physics_process", 0.16)
	assert(float(enemy.get("detection_awareness")) > 0.0)
	assert(not bool(enemy.get("alerted")))
	main_scene.call("_begin_space_hold")
	main_scene.call("_update_space_hold", 0.46)
	main_scene.call("_end_space_hold")
	assert(bool(main_scene.get("loafing")))
	assert(bool(player.get_meta("loafing_stealth", false)))
	main_scene.call("_begin_space_hold")
	assert(not bool(main_scene.get("loafing")))
	main_scene.call("_end_space_hold")
	main_scene.call("_set_loafing", true)
	assert(bool(player.get_meta("loafing_stealth", false)))
	enemy.set("detection_awareness", 0.65)
	var loaf_detected := bool(enemy.call(
		"_update_detection_awareness",
		0.4,
		13.0,
		true,
		vision_range
	))
	assert(not loaf_detected)
	assert(float(enemy.get("detection_awareness")) < 0.05)
	enemy.call("_become_alerted")
	enemy.set("combat_reaction_time", 0.0)
	enemy.set("lost_sight_time", 0.0)
	enemy.set("pursuit_time", 10.0)
	enemy.call("_physics_process", 0.4)
	assert(str(enemy.get("perception_state")) == "combat")
	enemy.call("_physics_process", 0.4)
	assert(str(enemy.get("perception_state")) == "search")
	assert(not bool(enemy.get("has_current_line_of_sight")))
	main_scene.call("_set_loafing", false)
	assert(not bool(player.get_meta("loafing_stealth", false)))
	enemy.call("_clear_alert")
	for step in 20:
		enemy.call("_physics_process", 0.16)
		if bool(enemy.get("alerted")):
			break
	assert(bool(enemy.get("alerted")))
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.call("_clear_alert")
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 10.0)
	facing_player = player.global_position - enemy.global_position
	facing_player.y = 0.0
	enemy.set("facing_world_direction", facing_player.normalized())
	enemy.set("detection_awareness", 0.0)
	enemy.set("perception_state", "patrol")
	for step in 2:
		enemy.call("_update_detection_awareness", 0.16, 10.0, true, vision_range)
	assert(str(enemy.get("perception_state")) == "suspicious")
	assert(not bool(enemy.get("alerted")))
	assert(float(enemy.get("detection_awareness")) < 1.0)
	var detection_indicator := enemy.get("detection_indicator") as Sprite3D
	assert(is_instance_valid(detection_indicator))
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.call("_update_detection_indicator")
	assert(detection_indicator.visible)
	var detected := bool(enemy.call(
		"_update_detection_awareness",
		3.0,
		10.0,
		true,
		vision_range
	))
	assert(detected)
	enemy.call("_become_alerted")
	assert(str(enemy.get("perception_state")) == "combat")
	assert(float(enemy.get("alert_marker_time")) > 0.0)
	assert(float(enemy.get("combat_reaction_time")) > 0.0)
	enemy.call("_update_detection_indicator")
	assert(detection_indicator.visible)
	enemy.set("perception_state", "combat")
	enemy.set("alert_marker_time", 0.0)
	enemy.set("has_current_line_of_sight", false)
	enemy.set("lost_sight_time", 5.0)
	enemy.call("_update_detection_indicator")
	assert(not detection_indicator.visible)
	enemy.global_position = (
		player.global_position
		+ Vector3(0.0, 0.0, float(enemy.call("_get_search_break_distance")) + 1.0)
	)
	enemy.set("last_known_position", player.global_position)
	enemy.set("pursuit_time", 10.0)
	enemy.set("combat_reaction_time", 0.0)
	enemy.set("alert_marker_time", 0.0)
	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.call("_physics_process", 0.16)
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED
	assert(str(enemy.get("perception_state")) == "search")
	enemy.call("_update_detection_indicator")
	assert(detection_indicator.visible)
	assert(detection_indicator.texture == enemy.call("_get_lost_target_texture"))
	enemy.call("_update_search_behavior", 0.1)
	assert(str(enemy.get("perception_state")) == "search")
	enemy.set("search_time_remaining", 0.05)
	enemy.call("_update_search_behavior", 0.1)
	assert(str(enemy.get("perception_state")) == "return")
	assert(not bool(enemy.get("alerted")))
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 0.75)
	enemy.set("facing_world_direction", Vector3.BACK)
	enemy.set("detection_awareness", 0.0)
	enemy.set("perception_state", "patrol")
	var initial_close_detection := bool(enemy.call(
		"_update_detection_awareness",
		0.01,
		0.75,
		true,
		vision_range
	))
	assert(not initial_close_detection)
	assert(float(enemy.get("detection_awareness")) > 0.0)
	assert(float(enemy.get("detection_awareness")) < 1.0)
	var completed_close_detection := bool(enemy.call(
		"_update_detection_awareness",
		0.8,
		0.75,
		true,
		vision_range
	))
	assert(completed_close_detection)
	assert(is_equal_approx(float(enemy.get("detection_awareness")), 1.0))
	enemy.call("_clear_alert")
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 5.0)
	enemy.set("facing_world_direction", Vector3.BACK)
	enemy.set("detection_awareness", 0.0)
	enemy.set("perception_state", "patrol")
	var proximity_detection := bool(enemy.call(
		"_update_detection_awareness",
		1.0,
		5.0,
		true,
		vision_range
	))
	assert(not proximity_detection)
	assert(is_zero_approx(float(enemy.get("detection_awareness"))))
	assert(str(enemy.get("perception_state")) == "patrol")
	enemy.call("_clear_alert")
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 1.0)
	enemy.set("detection_awareness", 0.0)
	var blocked_close_detection := bool(enemy.call(
		"_update_detection_awareness",
		0.5,
		1.0,
		false,
		vision_range
	))
	assert(not blocked_close_detection)
	assert(is_zero_approx(float(enemy.get("detection_awareness"))))
	var first_steering := enemy.call(
		"_steer_around_obstacles",
		Vector3(1.0, 0.0, 0.06)
	) as Vector3
	var second_steering := enemy.call(
		"_steer_around_obstacles",
		Vector3(1.0, 0.0, -0.06)
	) as Vector3
	assert(first_steering.dot(second_steering) > 0.98)
	enemy.call("_set_facing", "s")
	enemy.call("_set_facing_from_world_direction", Vector3.RIGHT)
	assert(str(enemy.get("facing")) == "s")
	enemy.set("pending_facing_since_msec", Time.get_ticks_msec() - 200)
	enemy.call("_set_facing_from_world_direction", Vector3.RIGHT)
	assert(str(enemy.get("facing")) == "se")
	var patrol_modes: Array[String] = []
	for patrol_enemy in enemies:
		if is_instance_valid(patrol_enemy):
			var patrol_mode := str(patrol_enemy.get("patrol_mode"))
			if not patrol_modes.has(patrol_mode):
				patrol_modes.append(patrol_mode)
			assert(not (patrol_enemy.get("patrol_route") as Array).is_empty())
	assert(patrol_modes.has("sentry"))
	assert(patrol_modes.has("route"))

	var market_counts := _sample_district_loot(main_scene, "market_lane", 600)
	var luxury_counts := _sample_district_loot(main_scene, "luxury_core", 600)
	assert(int(market_counts.get("canned_food", 0)) > int(luxury_counts.get("canned_food", 0)))
	assert(int(luxury_counts.get("armor", 0)) > int(market_counts.get("armor", 0)))
	var world := main_scene.get_node("World") as Node3D
	assert(not str(world.call("get_district_id", Vector3.ZERO)).is_empty())

	var subway_site := main_scene.get("basic_subway_mission_site") as Node3D
	assert(is_instance_valid(subway_site))
	main_scene.call("_complete_field_interaction", subway_site)
	assert(int(game_state.get("subway_story_stage")) == 1)
	assert(_has_mission(main_scene.get("basic_raid_missions"), "subway_boss"))
	main_scene.set("fatigue", 50.0)
	main_scene.call("_trigger_fatigue_boss_event")
	var story_boss: CharacterBody3D
	for candidate in main_scene.get("enemies"):
		if is_instance_valid(candidate) and bool(candidate.get_meta("raid_boss", false)):
			story_boss = candidate as CharacterBody3D
			break
	assert(is_instance_valid(story_boss))
	var main_tactical_map := main_scene.get("tactical_map") as Control
	assert(is_instance_valid(main_tactical_map))
	assert((main_tactical_map.get("boss_targets") as Array).has(story_boss))
	main_scene.call("_on_enemy_died", story_boss)
	assert(int(game_state.get("subway_story_stage")) == 2)
	assert((main_scene.get("completed_mission_titles") as Array).has("포격 신호의 주인 추적"))

	var tactical_map := load("res://scripts/tactical_map.gd").new() as Control
	var map_player := Node3D.new()
	root.add_child(map_player)
	root.add_child(tactical_map)
	var extraction_positions: Array[Vector3] = []
	var corpse_position := Vector3(24.0, 0.0, -18.0)
	tactical_map.call("setup", world, map_player, extraction_positions, corpse_position)
	assert(bool(tactical_map.get("corpse_recovery_available")))
	assert((tactical_map.get("corpse_recovery_position") as Vector3).is_equal_approx(corpse_position))
	tactical_map.call("clear_corpse_recovery")
	assert(not bool(tactical_map.get("corpse_recovery_available")))
	tactical_map.queue_free()
	map_player.queue_free()

	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	main_scene.queue_free()
	await process_frame

	var return_raid: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(return_raid)
	await process_frame
	await physics_frame
	return_raid.process_mode = Node.PROCESS_MODE_DISABLED
	assert(_has_mission(return_raid.get("basic_raid_missions"), "subway_return"))
	var return_site := return_raid.get("basic_subway_mission_site") as Node3D
	assert(is_instance_valid(return_site))
	assert(str(return_site.get_meta("basic_mission_id", "")) == "subway_return")
	return_raid.process_mode = Node.PROCESS_MODE_INHERIT
	return_raid.queue_free()
	await process_frame

	game_state.call("reset_run")
	var shelter := load("res://scenes/shelter_interior.tscn").instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame
	shelter.process_mode = Node.PROCESS_MODE_DISABLED
	shelter.call("_begin_space_hold")
	shelter.call("_update_space_hold", 0.46)
	shelter.call("_end_space_hold")
	assert(bool(shelter.get("loafing")))
	shelter.call("_begin_space_hold")
	assert(not bool(shelter.get("loafing")))
	shelter.call("_end_space_hold")
	assert(not bool(shelter.call("_raid_requires_unarmed_confirmation", "jongno_outskirts")))
	game_state.set("has_ak", false)
	game_state.set("equipped_weapon_id", "")
	assert(bool(shelter.call("_raid_requires_unarmed_confirmation", "jongno_outskirts")))
	shelter.call("_open_raid_zone_select")
	await process_frame
	var operations_map := root.find_child("SeoulOperationsMap", true, false) as TextureRect
	assert(is_instance_valid(operations_map))
	assert(operations_map.texture != null)
	assert(root.find_child("RaidZoneBriefingPanel", true, false) is PanelContainer)
	var raid_launch_button := root.find_child("RaidZoneLaunchButton", true, false) as Button
	assert(raid_launch_button is Button)
	for zone_id in game_state.get_raid_zone_ids():
		assert(root.find_child("RaidZoneMarker_%s" % zone_id, true, false) is Button)
	shelter.call("_select_raid_zone_preview", "namdaemun_market")
	assert(str(shelter.get("raid_zone_selected_id")) == "namdaemun_market")
	shelter.call("_select_raid_zone_preview", "jongno_outskirts")
	raid_launch_button.pressed.emit()
	await process_frame
	var loadout_layer := root.find_child("RaidLoadoutConfirmLayer", true, false) as CanvasLayer
	assert(is_instance_valid(loadout_layer))
	var unarmed_confirm := loadout_layer.find_child("ConfirmRaidLoadoutButton", true, false) as Button
	assert(unarmed_confirm is Button)
	assert(unarmed_confirm.text == "맨손으로 출정")
	assert(loadout_layer.find_child("RaidLoadoutConfirmPanel", true, false) is PanelContainer)
	shelter.call("_close_raid_zone_select")
	shelter.queue_free()
	await process_frame

	print("EXTRACTION_LOOP_EXPANSION_OK")
	quit(0)


func _sample_district_loot(main_scene: Node, district: String, sample_count: int) -> Dictionary:
	var counts := {}
	for sample_index in sample_count:
		var definition := main_scene.call(
			"_roll_district_loot_definition",
			district,
			sample_index
		) as Dictionary
		var loot_type := str(definition.get("type", ""))
		counts[loot_type] = int(counts.get(loot_type, 0)) + 1
	return counts


func _has_mission(missions: Array, mission_id: String) -> bool:
	for mission_value in missions:
		var mission := mission_value as Dictionary
		if str(mission.get("id", "")) == mission_id:
			return true
	return false
