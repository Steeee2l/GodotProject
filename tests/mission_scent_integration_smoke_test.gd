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

	var guidance := main_scene.get("objective_scent_guidance") as Node
	var scent := main_scene.get("scent_system") as Node3D
	if not is_instance_valid(guidance) or not is_instance_valid(scent):
		_fail("main scene did not install the objective scent modules")
	if (guidance.get("registered_sites") as Dictionary).size() < 6:
		_fail("field objectives were not registered with scent guidance")
	guidance.call("update_guidance", 0.2)
	if (scent.get("guidance_groups") as Dictionary).is_empty():
		_fail("main scene did not generate a scent route to an objective")

	var player := main_scene.get("player") as Node3D
	var found_hidden_distant_marker := false
	for site_value in main_scene.get("field_mission_sites"):
		var site := site_value as Node3D
		if player.global_position.distance_to(site.global_position) <= 8.0:
			continue
		var marker := site.get_node_or_null("MissionBoundary") as Node3D
		var label := site.get_node_or_null("MissionMarkerLabel") as Node3D
		if is_instance_valid(marker) and is_instance_valid(label) and not marker.visible and not label.visible:
			found_hidden_distant_marker = true
			break
	if not found_hidden_distant_marker:
		_fail("distant mission markers were still exposed directly")

	scent.call("set_focus_active", true)
	scent.call("_process", 0.1)
	var visible_guidance := false
	for entry_value in (scent.get("trails") as Dictionary).values():
		var entry := entry_value as Dictionary
		var marker := entry.get("marker") as Sprite3D
		if str(entry.get("kind", "")) == "objective" and is_instance_valid(marker) and marker.visible:
			visible_guidance = true
			break
	if not visible_guidance:
		_fail("Q focus did not expose the local objective trail in the main scene")

	print("MISSION_SCENT_INTEGRATION_OK sites=%d" % (
		guidance.get("registered_sites") as Dictionary
	).size())
	main_scene.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
