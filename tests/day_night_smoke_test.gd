extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	assert(game_state != null)
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("select_raid_zone", "jongno_outskirts")
	game_state.set("world_time_hours", 23.5)
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	assert(float(main_scene.get("night_intensity")) > 0.9)
	var enemies: Array = main_scene.get("enemies")
	assert(enemies.size() == 24)
	var initial_squad_counts := {}
	for initial_enemy in enemies:
		var squad_id := int(initial_enemy.get("squad_id"))
		initial_squad_counts[squad_id] = int(initial_squad_counts.get(squad_id, 0)) + 1
	var pair_squads := 0
	var solo_squads := 0
	for squad_count in initial_squad_counts.values():
		assert(int(squad_count) in [1, 2])
		if int(squad_count) == 2:
			pair_squads += 1
		else:
			solo_squads += 1
	assert(solo_squads > 0)
	assert(solo_squads + pair_squads == initial_squad_counts.size())
	var initial_spawn_distances: Array[float] = []
	for initial_enemy in enemies:
		initial_spawn_distances.append(
			(initial_enemy as Node3D).global_position.distance_to(
				(main_scene.get("player") as Node3D).global_position
			)
		)
	assert(initial_spawn_distances.min() >= 28.0)
	assert(initial_spawn_distances.min() < 55.0)
	assert(initial_spawn_distances.max() > 100.0)
	var visibility_material: ShaderMaterial = main_scene.get("visibility_material")
	var night_aim_radius := float(visibility_material.get_shader_parameter("inner_radius"))
	assert(night_aim_radius >= 150.0 and night_aim_radius < 220.0)
	assert(float(visibility_material.get_shader_parameter("near_radius")) < 80.0)
	main_scene.set("reinforcement_timer", 0.0)
	main_scene.call("_update_enemy_pressure", 1.0)
	await process_frame
	enemies = main_scene.get("enemies")
	assert(enemies.size() >= 26 and enemies.size() <= 27)
	var enemy: Node = enemies[0]
	assert(enemy.get_node_or_null("VisionFan") == null)
	enemy.call("set_environment_visibility", 0.0)
	var daylight_enemy_vision := float(enemy.call("_get_vision_range"))
	enemy.call("set_environment_visibility", 1.0)
	var night_enemy_vision := float(enemy.call("_get_vision_range"))
	assert(daylight_enemy_vision >= 16.0 and daylight_enemy_vision <= 25.0)
	assert(night_enemy_vision >= 10.0 and night_enemy_vision <= 18.0)
	assert(night_enemy_vision < daylight_enemy_vision)
	assert(is_equal_approx(float(enemy.get("detection_range_multiplier")), 1.0))
	assert(is_equal_approx(float(enemy.get("detection_half_angle_degrees")), 60.0))
	enemy.set("facing_world_direction", Vector3.FORWARD)
	assert(enemy.call(
		"_is_position_inside_vision_fan",
		(enemy as Node3D).global_position + Vector3.FORWARD * 5.0,
		10.0
	))
	assert(not enemy.call(
		"_is_position_inside_vision_fan",
		(enemy as Node3D).global_position + Vector3.BACK * 5.0,
		10.0
	))
	var enemy_sprite := enemy.get_node("EnemySprite") as AnimatedSprite3D
	assert(is_equal_approx(enemy_sprite.pixel_size, 0.0092))
	for direction_name in ["n", "ne", "e", "se", "s", "sw", "w", "nw"]:
		assert(enemy_sprite.sprite_frames.has_animation("idle_%s" % direction_name))
		assert(enemy_sprite.sprite_frames.has_animation("walk_%s" % direction_name))
		assert(enemy_sprite.sprite_frames.get_frame_count("walk_%s" % direction_name) == 4)
	enemy.call("_set_motion_state", "idle")
	enemy.call("_set_facing", "w")
	assert(enemy_sprite.animation == "idle_w")
	assert(not enemy_sprite.flip_h)
	enemy.call("_become_alerted")
	assert(enemy.get("alerted"))
	assert(not enemy.get_node("ThreatMarker").visible)
	enemy.set("last_known_position", (enemy as Node3D).global_position + Vector3(5.0, 0.0, 0.0))
	enemy.call("_pursue_last_known_position")
	assert((enemy as CharacterBody3D).velocity.length() > 0.1)
	enemy.call("_clear_alert")
	assert(is_zero_approx(float(enemy.get("detection_awareness"))))
	enemy.call("receive_reinforcement_order", (enemy as Node3D).global_position + Vector3(3.0, 0.0, 0.0))
	assert(enemy.get("alerted"))
	assert(not enemy.get_node("ThreatMarker").visible)
	var enemy_visible_position := (enemy as Node3D).global_position
	enemy.set_meta("smoothed_player_visibility", 1.0)
	enemy.set_meta("player_visibility_hold", 0.32)
	(enemy as Node3D).global_position = enemy_visible_position + Vector3(10000.0, 0.0, 10000.0)
	main_scene.call("_update_enemy_visibility", 0.016)
	assert(enemy.visible)
	assert(float(enemy.get("player_visibility_factor")) > 0.95)
	for visibility_step in 180:
		main_scene.call("_update_enemy_visibility", 0.016)
	assert(not enemy.visible)
	(enemy as Node3D).global_position = enemy_visible_position
	enemy.set_meta("smoothed_player_visibility", 1.0)
	enemy.set_meta("player_visibility_hold", 0.32)
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.visible = true

	var close_enemy_position := (main_scene.get("player") as Node3D).global_position + Vector3(3.5, 0.0, 0.0)
	(enemy as Node3D).global_position = close_enemy_position
	var cover_blocker := StaticBody3D.new()
	# 적 시야 레이는 WORLD_ONLY_SIGHT_MASK(64)만 본다. 레이어 1(플레이어)은 통과.
	cover_blocker.collision_layer = 64
	cover_blocker.position = (main_scene.get("player") as Node3D).global_position + Vector3(1.75, 0.0, 0.0)
	var cover_collision := CollisionShape3D.new()
	var cover_shape := BoxShape3D.new()
	cover_shape.size = Vector3(0.7, 1.5, 3.0)
	cover_collision.position.y = 0.75
	cover_collision.shape = cover_shape
	cover_blocker.add_child(cover_collision)
	main_scene.add_child(cover_blocker)
	await physics_frame
	assert(not bool(enemy.call("_has_line_of_sight")))
	assert(float(main_scene.call("_enemy_player_visibility_factor", enemy, 104.0, 134.0)) > 0.95)
	cover_blocker.queue_free()
	await physics_frame
	enemy.call("set_player_visibility_factor", 1.0)
	var mobile_input_direction := Vector3(1.0, 0.0, 0.03).normalized()
	var exact_enemy_direction := (
		(enemy as Node3D).global_position
		- (main_scene.get("player") as Node3D).global_position
	).normalized()
	var assisted_direction: Vector3 = main_scene.call(
		"_get_mobile_aim_assist_direction",
		mobile_input_direction
	)
	assert(assisted_direction.dot(exact_enemy_direction) > 0.99)
	main_scene.call("_update_mobile_aim_direction", mobile_input_direction)
	assert((main_scene.get("locked_aim_direction") as Vector3).dot(exact_enemy_direction) > 0.99)
	(enemy as Node3D).global_position = enemy_visible_position

	var pistol_enemy: Node
	var ranged_weapon_ids: Array[String] = []
	for candidate in enemies:
		if candidate.get("enemy_kind") == "pistol":
			ranged_weapon_ids.append(str(candidate.get("weapon_id")))
			if candidate.get("weapon_id") == "mp5":
				pistol_enemy = candidate
	assert(pistol_enemy != null)
	assert(ranged_weapon_ids.has("m1911"))
	assert(ranged_weapon_ids.has("mp5"))
	assert(ranged_weapon_ids.has("ak47"))
	assert(ranged_weapon_ids.size() >= 8)
	var expected_enemy_magazines := {
		"m1911": 6,
		"mp5": 14,
		"ak47": 12,
		"double_barrel": 2,
	}
	for candidate in enemies:
		var candidate_weapon_id := str(candidate.get("weapon_id"))
		if expected_enemy_magazines.has(candidate_weapon_id):
			assert(
				int(candidate.get("magazine_size"))
				== int(expected_enemy_magazines[candidate_weapon_id])
			)
	assert(pistol_enemy.get_node_or_null("EquippedWeapon_mp5") is Sprite3D)
	pistol_enemy.call("set_threat_level", 1.0)
	pistol_enemy.set("attack_cooldown", 0.0)
	pistol_enemy.call("_update_pistol", Vector3(1.0, 0.0, 0.0), 8.0, 0.1)
	assert(pistol_enemy.get("combat_state") == "pistol_burst")
	var expected_burst_size := int(pistol_enemy.call("_get_weapon_burst_size"))
	assert(expected_burst_size == int(pistol_enemy.get("magazine_size")))
	assert(int(pistol_enemy.get("burst_shots_remaining")) == expected_burst_size - 1)

	var perception := main_scene.get("perception_system") as CanvasLayer
	assert(perception != null)
	assert(not perception.has_method("emit_player_gunshot"))
	assert(not perception.has_method("emit_enemy_gunshot"))
	assert(not enemy.has_method("hear_sound"))

	var grenadier: Node
	for candidate in enemies:
		if str(candidate.get("enemy_kind")) == "grenadier":
			grenadier = candidate
			break
	assert(grenadier != null)
	grenadier.set("target", main_scene.get("player"))
	grenadier.set("pending_attack_direction", Vector3.FORWARD)
	grenadier.set("grenade_target_position", (main_scene.get("player") as Node3D).global_position)
	var main_child_count_before_grenade := main_scene.get_child_count()
	grenadier.call("_throw_grenade")
	assert(main_scene.get_child_count() == main_child_count_before_grenade + 1)
	var spawned_grenade := main_scene.get_child(main_scene.get_child_count() - 1)
	assert(spawned_grenade.get_script() == load("res://scripts/enemy_grenade.gd"))
	spawned_grenade.queue_free()
	var bat_sprite: Sprite3D = main_scene.get("melee_bat_sprite")
	assert(bat_sprite != null and bat_sprite.texture != null)
	main_scene.call("_play_bat_swing", Vector3(1.0, 0.0, 0.0))
	assert((main_scene.get("melee_bat_overlay") as Sprite2D).visible)
	assert(main_scene.get("hud").melee_button != null)
	assert(main_scene.get("mobile_context_button") is Button)
	assert(main_scene.get("mobile_reload_button") is Button)
	assert(main_scene.get("mobile_flashlight_button") is Button)
	assert(main_scene.get("mobile_map_button") is Button)
	var tactical_map := main_scene.get("tactical_map") as Control
	var map_close_button := tactical_map.find_child("MapCloseButton", true, false) as Button
	assert(map_close_button is Button)
	assert(tactical_map.is_connected(
		"open_state_changed",
		Callable(main_scene, "_on_tactical_map_open_state_changed")
	))
	main_scene.call("_on_mobile_map_pressed")
	assert(bool(tactical_map.call("is_open")))
	var mobile_map_button := main_scene.get("mobile_map_button") as Button
	mobile_map_button.visible = true
	await process_frame
	var map_close_touch := InputEventScreenTouch.new()
	map_close_touch.index = 70
	map_close_touch.position = mobile_map_button.get_global_rect().get_center()
	map_close_touch.pressed = true
	assert(main_scene.call("_handle_mobile_action_touch", map_close_touch))
	assert(not bool(tactical_map.call("is_open")))
	main_scene.call("_on_mobile_map_pressed")
	assert(bool(tactical_map.call("is_open")))
	map_close_button.pressed.emit()
	assert(not bool(tactical_map.call("is_open")))
	var fire_button := main_scene.get("hud").fire_button as Button
	var dash_button := main_scene.get("hud").dash_button as Button
	fire_button.visible = true
	dash_button.visible = true
	await process_frame
	main_scene.set("touch_id", 71)
	main_scene.set("touch_vector", Vector2(0.8, 0.0))
	main_scene.set("fire_cooldown", 0.0)
	main_scene.set("magazine_ammo", 24)
	var fire_touch := InputEventScreenTouch.new()
	fire_touch.index = 72
	fire_touch.position = fire_button.get_global_rect().get_center()
	fire_touch.pressed = true
	assert(main_scene.call("_handle_mobile_action_touch", fire_touch))
	assert(main_scene.get("fire_button_held"))
	assert(int(main_scene.get("fire_touch_id")) == 72)
	assert((main_scene.get("touch_vector") as Vector2).is_equal_approx(Vector2(0.8, 0.0)))
	var fire_release := InputEventScreenTouch.new()
	fire_release.index = 72
	fire_release.position = fire_touch.position
	fire_release.pressed = false
	assert(main_scene.call("_handle_mobile_action_touch", fire_release))
	assert(not main_scene.get("fire_button_held"))
	assert(int(main_scene.get("touch_id")) == 71)
	main_scene.set("roll_active", false)
	main_scene.set("roll_stamina", 36.0)
	var dash_touch := InputEventScreenTouch.new()
	dash_touch.index = 73
	dash_touch.position = dash_button.get_global_rect().get_center()
	dash_touch.pressed = true
	assert(main_scene.call("_handle_mobile_action_touch", dash_touch))
	assert(main_scene.get("roll_active"))
	assert((main_scene.get("touch_vector") as Vector2).is_equal_approx(Vector2(0.8, 0.0)))
	main_scene.set("roll_active", false)
	main_scene.set("touch_id", -1)
	main_scene.set("touch_vector", Vector2.ZERO)
	main_scene.call("_on_mobile_flashlight_toggled", true)
	assert(bool(main_scene.get("laser_aim_held")))
	main_scene.call("_update_mobile_aim_direction", Vector3(-1.0, 0.0, 0.0))
	assert((main_scene.get("locked_aim_direction") as Vector3).dot(Vector3.LEFT) > 0.7)
	var fatigue_before_flashlight := float(main_scene.get("fatigue"))
	main_scene.call("_update_fatigue", 1.0, false)
	assert(float(main_scene.get("fatigue")) > fatigue_before_flashlight)
	main_scene.call("_on_mobile_flashlight_toggled", false)
	assert(not bool(main_scene.get("laser_aim_held")))
	main_scene.set("magazine_ammo", 24)
	main_scene.set("reserve_ammo", 95)
	main_scene.call("_update_equipment_ui")
	assert((main_scene.get("hud").equipment_ammo_label as Label).text.contains("24 / 30"))
	assert((main_scene.get("hud").equipment_reserve_ammo_label as Label).text.contains("예비 95발"))

	pistol_enemy.set("magazine_ammo", 0)
	pistol_enemy.call("_start_reload")
	assert(pistol_enemy.get("combat_state") == "reloading")
	assert((pistol_enemy.get("reload_indicator") as Sprite3D).visible)
	pistol_enemy.set("combat_state", "normal")
	pistol_enemy.set("alerted", true)
	assert(pistol_enemy.call("start_reinforcement_call", 0.05))
	assert((pistol_enemy.get("reinforcement_call_indicator") as Sprite3D).visible)
	main_scene.get("enemy_director").set("active_reinforcement_caller", pistol_enemy)
	var enemy_count_before_call := enemies.size()
	pistol_enemy.call("_update_reinforcement_call", 1.1)
	assert((main_scene.get("enemies") as Array).size() >= enemy_count_before_call + 6)

	enemy.set("facing_world_direction", Vector3(1.0, 0.0, 0.0))
	var backstab_position := (enemy as Node3D).global_position - Vector3(1.0, 0.0, 0.0)
	assert(bool(enemy.call("is_backstab_from", backstab_position)))
	enemy.call("take_melee_hit", 38, Vector3(1.0, 0.0, 0.0), true)
	assert(enemy.get("backstab_stunned"))
	assert(int(enemy.get("health")) == 0)
	print("COMBAT_ALERT_SMOKE_OK threat=%.2f enemies=%d burst=%d" % [
		main_scene.get("night_intensity"),
		enemies.size(),
		pistol_enemy.get("burst_shots_remaining"),
	])
	quit(0)
