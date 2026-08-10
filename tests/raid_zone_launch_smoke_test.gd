extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	game_state.set("selected_raid_zone", "jongno_outskirts")

	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	current_scene = shelter
	await process_frame
	await physics_frame

	shelter.call("_open_raid_zone_select")
	await process_frame
	var launch_button := root.find_child("RaidZoneLaunchButton", true, false) as Button
	assert(is_instance_valid(launch_button))
	assert(not launch_button.disabled)
	launch_button.pressed.emit()

	# 씬 전환은 0.3초 페이드 트윈 뒤에 일어난다. 3프레임으로는 못 기다린다.
	for _frame in 45:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/main.tscn":
			break
	assert(is_instance_valid(current_scene))
	assert(current_scene.scene_file_path == "res://scenes/main.tscn")
	# main._ready가 진입 직후 플래그를 소비해 false로 되돌린다.
	assert(bool(game_state.get("returning_from_shelter")) == false)

	print("RAID_ZONE_LAUNCH_OK")
	quit(0)
