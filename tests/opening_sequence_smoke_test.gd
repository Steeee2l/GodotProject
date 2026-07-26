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
	if (opening.get("enemies") as Array).size() != 2:
		_fail("opening reveal must stage two enemies")
	if opening.get("sewer_exit") == null:
		_fail("tutorial extraction point was not created")
	if str(opening.get("phase")) != "intro_walk":
		_fail("opening must begin with the automatic bridge walk")

	opening.call("_start_tutorial_move")
	await process_frame
	if str(opening.get("phase")) != "tutorial_move":
		_fail("movement tutorial could not be entered")
	var objective_panel := opening.get("objective_panel") as Control
	if objective_panel == null or not objective_panel.visible:
		_fail("tutorial objective panel is missing")

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
