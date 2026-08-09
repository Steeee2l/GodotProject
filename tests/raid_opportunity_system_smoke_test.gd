extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var hotspots: Array = main_scene.get("raid_hotspots")
	assert(hotspots.size() == 3)
	var hotspot_types: Array[String] = []
	for hotspot_value in hotspots:
		var hotspot := hotspot_value as Node3D
		assert(is_instance_valid(hotspot))
		assert(str(hotspot.get_meta("interaction_type", "")) == "high_value_cache")
		assert(hotspot.get_node_or_null("HotspotSprite") is Sprite3D)
		assert(hotspot.get_node_or_null("HotspotBeacon") is Sprite3D)
		hotspot_types.append(str(hotspot.get_meta("hotspot_type", "")))
	assert(hotspot_types.has("military"))
	assert(hotspot_types.has("pharmacy"))
	assert(hotspot_types.has("sealed_parts"))

	var pressure_panel := main_scene.get("hud").raid_pressure_panel as PanelContainer
	var pressure_bar := main_scene.get("hud").raid_pressure_bar as ProgressBar
	assert(is_instance_valid(pressure_panel))
	assert(is_instance_valid(pressure_bar))
	assert(not pressure_panel.visible)
	assert(pressure_panel.find_child("PressureIcon", true, false) is TextureRect)
	var initial_enemy_count := (main_scene.get("enemies") as Array).size()
	main_scene.call("_apply_raid_pressure_level", 2)
	main_scene.call("_refresh_raid_pressure_hud")
	assert(int(main_scene.get("raid_pressure_level")) == 2)
	assert(is_equal_approx(float(main_scene.get("raid_reward_multiplier")), 1.35))
	assert((main_scene.get("hud").jackpot_pressure_label as Label).text == "추적")
	assert((main_scene.get("enemies") as Array).size() > initial_enemy_count)

	var extraction_sites: Array = main_scene.get("extraction_sites")
	assert(extraction_sites.size() == 3)
	for index in extraction_sites.size():
		var site := extraction_sites[index] as Node3D
		assert(
			is_equal_approx(
				float(site.get_meta("reward_multiplier", 0.0)),
				[1.0, 1.2, 1.4][index]
			)
		)
		assert(not str(site.get_meta("route_title", "")).is_empty())
	var tactical_map := main_scene.get("tactical_map") as Control
	assert(is_instance_valid(tactical_map))
	assert((tactical_map.get("extraction_profiles") as Array).size() == 3)
	assert((tactical_map.get("raid_markers") as Array).size() >= 4)

	var jackpot_clue := main_scene.get("jackpot").jackpot_clue_site as Node3D
	assert(is_instance_valid(jackpot_clue))
	assert(jackpot_clue.get_node_or_null("JackpotPropSprite") is Sprite3D)
	var jackpot_hud := main_scene.get("hud").jackpot_hud as PanelContainer
	assert(is_instance_valid(jackpot_hud))
	assert(jackpot_hud.size.y <= 70.0)
	assert((main_scene.get("hud").jackpot_detail_label as Label).text.contains("TAB"))
	main_scene.call("_complete_field_interaction", jackpot_clue)
	assert(str(main_scene.get("jackpot").jackpot_state) == "power")
	var jackpot_power := main_scene.get("jackpot").jackpot_power_site as Node3D
	assert(is_instance_valid(jackpot_power))
	main_scene.call("_complete_field_interaction", jackpot_power)
	assert(str(main_scene.get("jackpot").jackpot_state) == "alarm")
	var jackpot_enemy_count := (main_scene.get("enemies") as Array).size()
	main_scene.call("_update_jackpot_event", 1.0)
	assert((main_scene.get("enemies") as Array).size() > jackpot_enemy_count)
	var jackpot_cargo := main_scene.get("jackpot").jackpot_cargo_site as Node3D
	assert(is_instance_valid(jackpot_cargo))
	main_scene.call("_complete_field_interaction", jackpot_cargo)
	assert(str(main_scene.get("jackpot").jackpot_state) == "carried")
	assert(not (game_state.get("raid_special_cargo") as Dictionary).is_empty())
	assert(int(game_state.call("get_raid_bag_used_slots")) <= 15)
	assert(is_instance_valid(main_scene.get("jackpot").jackpot_carried_sprite as Sprite3D))
	var cargo_result := main_scene.call("_settle_jackpot_cargo") as Dictionary
	assert(str(cargo_result.get("summary", "")).contains("3번 보급 코어"))
	assert(str(cargo_result.get("summary", "")).contains("세계 기록"))

	var world := main_scene.get_node("World") as Node3D
	main_scene.call("_spawn_dynamic_convoy_incident", world)
	assert(str(main_scene.get("dynamic_incident_state")) == "active")
	var incident_site := main_scene.get("dynamic_incident_site") as Node3D
	assert(is_instance_valid(incident_site))
	assert(incident_site.get_node_or_null("ConvoyWreck") is Sprite3D)
	assert((main_scene.get("hud").dynamic_incident_hud as PanelContainer).visible)
	var incident_factions: Array[String] = []
	var raider_survivors: Array[CharacterBody3D] = []
	var feral_survivors: Array[CharacterBody3D] = []
	for enemy_value in main_scene.get("enemies"):
		var enemy := enemy_value as CharacterBody3D
		if not bool(enemy.get_meta("dynamic_incident", false)):
			continue
		var faction_id := str(enemy.call("get_faction_id"))
		if not incident_factions.has(faction_id):
			incident_factions.append(faction_id)
		if faction_id == "raider":
			raider_survivors.append(enemy)
		elif faction_id == "feral":
			feral_survivors.append(enemy)
	assert(incident_factions.has("raider"))
	assert(incident_factions.has("feral"))
	assert(not raider_survivors.is_empty())
	assert(not feral_survivors.is_empty())
	var resistance_target := raider_survivors[0]
	var health_before := int(resistance_target.get("health"))
	resistance_target.call("take_hostile_hit", 50, Vector3.RIGHT, feral_survivors[0])
	var faction_damage_taken := health_before - int(resistance_target.get("health"))
	assert(faction_damage_taken == 21)
	for feral in feral_survivors:
		feral.queue_free()
	await process_frame
	main_scene.call("_update_faction_conflicts", 0.81)
	assert(str(main_scene.get("dynamic_incident_winning_faction")) == "raider")
	for raider in raider_survivors:
		assert(bool(raider.get_meta("dynamic_incident_guard", false)))
		var patrol_origin: Vector3 = raider.get("patrol_origin")
		assert(patrol_origin.distance_to(incident_site.global_position) <= 8.0)

	main_scene.call("_complete_field_interaction", incident_site)
	assert(str(main_scene.get("dynamic_incident_state")) == "claimed")
	assert(not (main_scene.get("hud").dynamic_incident_hud as PanelContainer).visible)

	main_scene.get("extraction").set("selected_extraction_index", 2)
	main_scene.get("extraction").set("selected_extraction_multiplier", 1.4)
	main_scene.set("raid_hotspots_opened", 2)
	var food_before := int(game_state.get("canned_food"))
	var bonus := main_scene.call("_grant_extraction_route_bonus") as Dictionary
	assert(int(game_state.get("canned_food")) > food_before)
	assert(str(bonus.get("summary", "")).contains("경로 보급"))

	print("RAID_OPPORTUNITY_SYSTEM_OK")
	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	main_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)
