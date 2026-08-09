extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	push_error("THREAT_EXTRACTION_SMOKE: %s" % message)
	quit(1)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if main.get_node_or_null("HUD/ThreatMeter") != null:
		_fail("obsolete disturbance meter is still visible")
		return
	var extraction_site: Node3D = main.get("extraction_site")
	var extraction_sites := main.get("extraction_sites") as Array
	if extraction_sites.size() != 3:
		_fail("three randomized sewer extraction sites were not created")
		return
	if not is_instance_valid(extraction_site) or extraction_site.get_node_or_null("ExtractionBeacon") == null:
		_fail("lit sewer extraction beacon was not created")
		return
	if extraction_site.get_node_or_null("SewerEntrance") != null:
		_fail("placeholder sewer art should not be visible yet")
		return
	var tactical_map: Control = main.get("tactical_map")
	if not is_instance_valid(tactical_map):
		_fail("tactical map was not created")
		return
	tactical_map.call("toggle")
	if not tactical_map.visible:
		_fail("tactical map did not open")
		return
	tactical_map.call("close")

	var companion: CharacterBody3D = main.get("companion")
	if bool(main.get("companion_active")):
		_fail("companion should not be active at raid start")
		return
	if companion.visible or companion.collision_layer != 0:
		_fail("companion should be hidden and non-colliding until story activation")
		return

	var ranged_enemy: CharacterBody3D
	for enemy_value in main.get("enemies"):
		var enemy := enemy_value as CharacterBody3D
		if is_instance_valid(enemy) and str(enemy.get("enemy_kind")) != "melee":
			ranged_enemy = enemy
			break
	if ranged_enemy == null:
		_fail("no ranged enemy available for reload test")
		return
	ranged_enemy.set("magazine_ammo", 0)
	ranged_enemy.call("_start_reload")
	if str(ranged_enemy.get("combat_state")) != "reloading":
		_fail("enemy reload state did not start")
		return
	var reload_indicator: Sprite3D = ranged_enemy.get("reload_indicator")
	if not is_instance_valid(reload_indicator) or not reload_indicator.visible:
		_fail("enemy circular reload indicator is not visible")
		return

	var perception: CanvasLayer = main.get("perception_system")
	if perception.has_method("emit_enemy_gunshot") or ranged_enemy.has_method("hear_sound"):
		_fail("obsolete gunshot attraction API is still available")
		return
	main.set("magazine_ammo", 0)
	main.set("melee_attack_cooldown", 0.0)
	var empty_click := InputEventMouseButton.new()
	empty_click.button_index = MOUSE_BUTTON_LEFT
	empty_click.pressed = true
	main.call("_handle_combat_mouse_button", empty_click)
	var bat_overlay: Sprite2D = main.get("melee_bat_overlay")
	if not is_instance_valid(bat_overlay) or not bat_overlay.visible:
		_fail("empty-magazine left click did not show the baseball bat")
		return

	ranged_enemy.set("combat_state", "normal")
	ranged_enemy.set("alerted", true)
	if not bool(ranged_enemy.call("start_reinforcement_call", 0.05)):
		_fail("enemy reinforcement call did not start")
		return
	var call_indicator: Sprite3D = ranged_enemy.get("reinforcement_call_indicator")
	if not is_instance_valid(call_indicator) or not call_indicator.visible:
		_fail("enemy loudspeaker call indicator is not visible")
		return
	main.get("enemy_director").set("active_reinforcement_caller", ranged_enemy)
	var enemy_count_before := (main.get("enemies") as Array).size()
	ranged_enemy.call("_update_reinforcement_call", 1.1)
	if (main.get("enemies") as Array).size() < enemy_count_before + 6:
		_fail("completed enemy call did not spawn reinforcements")
		return

	print("THREAT_EXTRACTION_SMOKE: PASS")
	quit(0)
