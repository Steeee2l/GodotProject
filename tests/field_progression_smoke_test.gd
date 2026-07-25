extends SceneTree

const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	push_error("FIELD_PROGRESSION_SMOKE: %s" % message)
	quit(1)


func _run() -> void:
	for weapon_id in ["ak47", "mp5", "double_barrel"]:
		var weapon_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
		if weapon_texture == null or weapon_texture.get_width() < 512:
			_fail("weapon catalog art is missing for %s" % weapon_id)
			return
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("shelter_tier", 2)
	game_state.call("select_raid_zone", "namdaemun_market")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var boss_found := false
	var raid_boss: CharacterBody3D
	for enemy in (main.get("enemies") as Array):
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			_fail("raid boss spawned before the fatigue threshold")
			return
	main.set("fatigue", 50.0)
	main.call("_trigger_fatigue_boss_event")
	for enemy in (main.get("enemies") as Array):
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			boss_found = true
			raid_boss = enemy
			break
	if not boss_found:
		_fail("high-risk zone did not spawn its raid boss at the fatigue threshold")
		return
	if not raid_boss.is_in_group("rocket_boss") or int(raid_boss.call("get_rocket_magazine_ammo")) != 4:
		_fail("high-risk zone boss is not using the rocket boss controller")
		return

	var extraction_sites := main.get("extraction_sites") as Array
	if extraction_sites.size() != 3:
		_fail("expected three extraction beacons")
		return
	var field_interactions := main.get("field_interactions") as Array
	var salvage_count := 0
	var rescue_count := 0
	for point_value in field_interactions:
		var point := point_value as Node3D
		match str(point.get_meta("interaction_type", "")):
			"salvage":
				salvage_count += 1
				if str(point.get_meta("source_kind", "")) == "broken_sentry":
					var sentry_sprite := point.get_node_or_null("BrokenSentry") as Sprite3D
					if sentry_sprite == null or sentry_sprite.texture == null:
						_fail("broken sentry still uses a placeholder instead of sprite art")
						return
			"rescue":
				rescue_count += 1
				var cowering_resident := point.get_node_or_null("CoweringResident") as Sprite3D
				if cowering_resident == null or cowering_resident.texture == null:
					_fail("rescue point is missing the cowering resident sprite")
					return
	if salvage_count < 5 or rescue_count != 3:
		_fail("field salvage/rescue objectives were not populated")
		return

	var player := main.get("player") as Node3D
	var visibility_probe := StaticBody3D.new()
	var probe_collision := CollisionShape3D.new()
	var probe_shape := BoxShape3D.new()
	probe_shape.size = Vector3(2.0, 2.0, 2.0)
	probe_collision.shape = probe_shape
	visibility_probe.add_child(probe_collision)
	main.add_child(visibility_probe)
	var facing_direction: Vector3 = main.call("_get_current_facing_world_direction")
	visibility_probe.global_position = player.global_position + facing_direction * 6.0
	if not bool(main.call("_structure_touches_visibility_sector", visibility_probe)):
		_fail("structure in the forward reveal sector was not detected")
		return
	visibility_probe.global_position = player.global_position - facing_direction * 6.0
	if bool(main.call("_structure_touches_visibility_sector", visibility_probe)):
		_fail("structure behind the player incorrectly entered the forward reveal sector")
		return
	visibility_probe.queue_free()
	var aim_probe := StaticBody3D.new()
	aim_probe.name = "AimBuildingProbe"
	aim_probe.collision_layer = 1
	aim_probe.collision_mask = 0
	aim_probe.add_to_group("camera_occluder")
	var aim_shape := CollisionShape3D.new()
	var aim_box := BoxShape3D.new()
	aim_box.size = Vector3(1.5, 1.5, 1.5)
	aim_shape.shape = aim_box
	aim_probe.add_child(aim_shape)
	main.add_child(aim_probe)
	main.set("laser_aim_held", true)
	var clear_aim_direction := Vector3.ZERO
	for candidate_direction in [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3(1.0, 0.0, 1.0).normalized(),
		Vector3(-1.0, 0.0, 1.0).normalized(),
		Vector3(1.0, 0.0, -1.0).normalized(),
		Vector3(-1.0, 0.0, -1.0).normalized(),
	]:
		main.set("locked_aim_direction", candidate_direction)
		if main.call("_get_aimed_camera_occluder") == null:
			clear_aim_direction = candidate_direction
			break
	if clear_aim_direction == Vector3.ZERO:
		_fail("no clear direction remained for the aim transparency probe")
		return
	aim_probe.global_position = player.global_position + clear_aim_direction * 3.0 + Vector3.UP * 0.45
	await physics_frame
	main.set("locked_aim_direction", clear_aim_direction)
	var aimed_occluder := main.call("_get_aimed_camera_occluder") as Node3D
	if aimed_occluder != aim_probe:
		_fail("aim ray did not identify the building it touched (got %s)" % [aimed_occluder.name if aimed_occluder else "null"])
		return
	aim_probe.queue_free()
	main.set("laser_aim_held", false)
	var component_before := int(game_state.call("get_mod_component_count", "scope_lens"))
	var component_drop: Node3D = main.call(
		"_create_loot_pickup",
		"mod_component",
		player.global_position,
		{"component_id": "scope_lens", "amount": 1, "display_name": "스코프 렌즈"}
	)
	main.set("nearby_ammo_pickup", component_drop)
	main.call("_collect_nearby_ammo")
	if int(game_state.call("get_mod_component_count", "scope_lens")) != component_before + 1:
		_fail("mod component pickup was not stored")
		return

	main.set("fatigue", 100.0)
	if float(main.call("_get_fatigue_speed_multiplier")) >= 0.99:
		_fail("maximum fatigue did not reduce movement speed")
		return
	main.set("fatigue", 0.0)
	main.set("laser_aim_held", true)
	main.set("has_ak", true)
	main.call("_update_fatigue", 10.0, false)
	if float(main.get("fatigue")) < 0.89:
		_fail("holding aim did not accumulate fatigue")
		return
	main.set("laser_aim_held", false)
	main.call("_add_rescued_follower", player.global_position + Vector3(1, 0, 1))
	if (main.get("rescued_followers") as Array).size() != 1:
		_fail("rescued follower was not added")
		return
	if float(main.call("_get_escort_speed_multiplier")) >= 1.0:
		_fail("escort did not apply movement penalty")
		return
	var workers_before := int(game_state.get("rescued_workers"))
	if int(main.call("_commit_rescued_followers")) != 1:
		_fail("rescued follower was not committed on extraction")
		return
	if int(game_state.get("rescued_workers")) != workers_before + 1:
		_fail("shelter worker total was not updated")
		return

	print("FIELD_PROGRESSION_SMOKE: PASS")
	quit(0)
