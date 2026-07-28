extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	var shortcut := root.get_node("ShelterDebugShortcut")
	var mobile_reset_button := shortcut.get("reset_button") as Button
	var reset_confirmation := shortcut.get("reset_confirmation") as Control
	if mobile_reset_button == null or mobile_reset_button.text != "↻  초기화":
		_fail("mobile reset button was not created")
	if reset_confirmation == null:
		_fail("mobile reset confirmation was not created")
	shortcut.call("_show_reset_confirmation")
	if not reset_confirmation.visible:
		_fail("mobile reset confirmation did not open")
	shortcut.call("_hide_reset_confirmation")
	if reset_confirmation.visible:
		_fail("mobile reset confirmation did not close")
	var test_save_path := "res://test-output/opening_sequence_smoke_save.json"
	var absolute_test_save := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_test_save)
	game_state.set("persistence_path", test_save_path)
	game_state.set("persistence_enabled", true)
	game_state.set("scrap", 999_999)
	game_state.set("resident_cat_ids", ["test_resident"])
	if not bool(game_state.call("reset_all_progress_for_opening")):
		_fail("progress reset failed")
	if bool(game_state.get("opening_completed")):
		_fail("progress reset must return the game to the opening")
	if int(game_state.call("get_ammo_count", "762_fmj")) != 300:
		_fail("opening loadout must include ten spare AK magazines")
	if int(game_state.get("scrap")) != 80 or not (game_state.get("resident_cat_ids") as Array).is_empty():
		_fail("progress reset left economy or resident data behind")
	if not FileAccess.file_exists(test_save_path):
		_fail("progress reset did not write a clean replacement save")
	var test_save := FileAccess.open(test_save_path, FileAccess.READ)
	var saved_data := JSON.parse_string(test_save.get_as_text()) as Dictionary
	test_save.close()
	if bool(saved_data.get("opening_completed", true)):
		_fail("clean save did not preserve the pending opening state")
	game_state.set("persistence_enabled", false)

	var scene := load("res://scenes/opening_sequence.tscn") as PackedScene
	if scene == null:
		_fail("opening scene could not be loaded")
	var opening := scene.instantiate() as Node3D
	root.add_child(opening)
	await process_frame
	await physics_frame
	if opening.get("player") == null:
		_fail("opening player was not created")
	if opening.get("camera") == null:
		_fail("opening camera was not created")
	var opening_player := opening.get("player") as CharacterBody3D
	var opening_camera := opening.get("camera") as Camera3D
	var player_screen_position := opening_camera.unproject_position(opening_player.global_position)
	var viewport_center := opening.get_viewport().get_visible_rect().size * 0.5
	if player_screen_position.distance_to(viewport_center) > 8.0:
		_fail(
			"opening camera does not frame the player at screen center: %s vs %s"
			% [player_screen_position, viewport_center]
		)
	var original_player_position := opening_player.position
	opening_player.position += Vector3(2.5, 0, -4.0)
	opening.call("_update_camera", 1.0 / 60.0)
	player_screen_position = opening_camera.unproject_position(opening_player.global_position)
	if player_screen_position.distance_to(viewport_center) > 8.0:
		_fail("opening camera loses screen center while the player moves")
	opening_player.position = original_player_position
	opening.call("_update_camera", 1.0 / 60.0)
	var staged_enemies := opening.get("enemies") as Array
	if staged_enemies.size() != 2:
		_fail("opening reveal must stage two enemies")
	var nearest_staged_enemy := INF
	for staged_enemy in staged_enemies:
		nearest_staged_enemy = minf(
			nearest_staged_enemy,
			opening_player.global_position.distance_to((staged_enemy as Node3D).global_position)
		)
	if nearest_staged_enemy < 35.0:
		_fail("opening enemies are staged too close to the player")
	var sewer_exit := opening.get("sewer_exit") as Node3D
	if sewer_exit == null:
		_fail("tutorial extraction point was not created")
	var sewer_sprite := sewer_exit.get_child(0) as Sprite3D
	if (
		sewer_sprite == null
		or sewer_sprite.texture == null
		or not sewer_sprite.texture.resource_path.ends_with("opening_sewer_exit_v2.png")
	):
		_fail("integrated asphalt sewer asset is not assigned")
	if str(opening.get("phase")) != "intro_walk":
		_fail("opening must begin with the automatic bridge walk")
	var opening_environment := opening.get_node_or_null("OpeningEnvironment") as WorldEnvironment
	if opening_environment == null or opening_environment.environment == null:
		_fail("opening night environment is missing")
	if opening_environment.environment.fog_enabled:
		_fail("opening atmospheric fog must remain disabled")
	var bridge_deck := opening.get_node_or_null("BridgeDeck") as MeshInstance3D
	if bridge_deck == null or not (bridge_deck.mesh is PlaneMesh):
		_fail("opening bridge deck is missing")
	if (bridge_deck.mesh as PlaneMesh).size.y < 100.0:
		_fail("opening bridge was not extended")
	var wrecks: Array[Node] = []
	for wreck_node in get_nodes_in_group("opening_wreck"):
		if wreck_node is Node and opening.is_ancestor_of(wreck_node):
			wrecks.append(wreck_node)
	if wrecks.size() < 4:
		_fail("opening wreck set is incomplete")
	for wreck in wrecks:
		var wreck_sprite := (wreck as Node).find_child("*", true, false) as Sprite3D
		if wreck_sprite == null or wreck_sprite.position.y < 0.85:
			_fail("opening wreck sprite can clip into the bridge deck")
	if opening.get("visibility_material") == null or opening.get("visibility_rect") == null:
		_fail("opening gameplay visibility mask is missing")
	if opening.get("mobile_controls_root") == null:
		_fail("opening mobile controls were not built")
	for mobile_button_name in ["mobile_dash_button", "mobile_aim_button", "mobile_fire_button", "mobile_interact_button"]:
		if opening.get(mobile_button_name) == null:
			_fail("opening mobile action is missing: %s" % mobile_button_name)
	if opening.get("weapon_hud_panel") == null or opening.get("magazine_label") == null:
		_fail("opening weapon HUD is incomplete")

	opening.call("_start_tutorial_move")
	await process_frame
	if str(opening.get("phase")) != "tutorial_move":
		_fail("movement tutorial could not be entered")
	var objective_panel := opening.get("objective_panel") as Control
	if objective_panel == null or not objective_panel.visible:
		_fail("tutorial objective panel is missing")
	var visibility_rect := opening.get("visibility_rect") as ColorRect
	if visibility_rect == null or not visibility_rect.visible:
		_fail("gameplay visibility did not activate with player control")
	opening.set("touch_enabled", true)
	opening.call("_update_hud")
	var mobile_controls := opening.get("mobile_controls_root") as Control
	if mobile_controls == null or not mobile_controls.visible:
		_fail("mobile tutorial controls cannot be shown")
	opening.call("_start_tutorial_dash")
	opening.set("mobile_move_vector", Vector2.UP)
	opening.call("_try_dash")
	if not bool(opening.get("roll_active")):
		_fail("mobile dash input did not start a roll")
	opening.set("roll_active", false)
	opening.call("_start_tutorial_combat")
	if bool(opening.get("tutorial_enemies_activated")):
		_fail("tutorial enemies activated before the player approached")
	opening.set("aim_held", true)
	opening.call("_update_visibility_fog")
	var visibility_material := opening.get("visibility_material") as ShaderMaterial
	var short_side := minf(
		opening.get_viewport().get_visible_rect().size.x,
		opening.get_viewport().get_visible_rect().size.y
	)
	if float(visibility_material.get_shader_parameter("outer_radius")) < short_side * 0.78:
		_fail("opening aim visibility does not reach far enough ahead")
	opening.call("_update_camera", 1.0)
	if opening_camera.size < 27.0:
		_fail("opening camera does not pull back far enough while aiming")
	opening.call("_try_fire")
	if int(opening.get("magazine_ammo")) != 29:
		_fail("mobile fire input did not consume a round")
	var tutorial_enemies := opening.get("enemies") as Array
	var stale_enemy_projectile := Area3D.new()
	stale_enemy_projectile.set_script(preload("res://scripts/bullet_projectile.gd"))
	stale_enemy_projectile.set("source_body", tutorial_enemies[0])
	stale_enemy_projectile.set("hostile", true)
	opening.add_child(stale_enemy_projectile)
	stale_enemy_projectile.set_physics_process(false)
	if not stale_enemy_projectile.is_in_group("projectile"):
		_fail("tutorial projectile was not registered for cleanup")
	opening.call("_on_tutorial_enemy_died", tutorial_enemies[0])
	if not stale_enemy_projectile.is_queued_for_deletion():
		_fail("defeated enemy left a hostile projectile active")
	var health_before_kill_grace := int(opening.get("player_health"))
	opening.call("take_damage", 999)
	if int(opening.get("player_health")) != health_before_kill_grace:
		_fail("delayed damage after a mobile tutorial kill was not ignored")
	opening.set("tutorial_damage_grace_until_msec", 0)
	opening.set("player_health", 1)
	opening.call("take_damage", 999)
	if bool(opening.get("restarting")):
		_fail("opening restarted before the final-kill race could resolve")
	if not bool(opening.get("death_resolution_pending")):
		_fail("tutorial death did not enter deferred race resolution")
	opening.call("_on_tutorial_enemy_died", tutorial_enemies[1])
	await physics_frame
	await process_frame
	if bool(opening.get("restarting")):
		_fail("same-frame final kill still restarted the opening")
	if bool(opening.get("death_resolution_pending")):
		_fail("final-kill race resolution did not finish")
	if int(opening.get("player_health")) < 1:
		_fail("same-frame final kill did not preserve the tutorial player")
	opening.set("touch_enabled", false)

	game_state.call("complete_opening_and_prepare_shelter")
	if not bool(game_state.get("opening_completed")):
		_fail("opening completion flag was not recorded")
	if int(game_state.call("get_ammo_count", "762_fmj")) < 300:
		_fail("opening completion did not preserve the starter ammunition")
	opening.queue_free()
	await process_frame
	DirAccess.remove_absolute(absolute_test_save)
	print("Opening sequence smoke test passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
