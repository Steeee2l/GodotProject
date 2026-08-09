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

	var health_before := int(main_scene.get("player_health"))
	main_scene.call("_begin_extraction")
	assert(bool(main_scene.get("extraction_transition_active")))
	assert(paused, "The raid must pause as soon as extraction succeeds.")
	assert(
		(main_scene.get("hud").extraction_result_panel as Control).process_mode
		== Node.PROCESS_MODE_WHEN_PAUSED
	)

	main_scene.call("take_damage", health_before + 100)
	main_scene.call("take_hit", health_before + 100, Vector3.RIGHT)
	assert(int(main_scene.get("player_health")) == health_before)
	assert(not bool(main_scene.get("player_death_sequence_active")))

	paused = false
	main_scene.queue_free()
	await process_frame
	print("EXTRACTION_COMBAT_LOCK_OK health=%d" % health_before)
	quit(0)
