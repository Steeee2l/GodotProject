extends SceneTree

# 엘리트 캡처 프로브(창 필요 — --headless 금지). 2026-09-03.
#   elite_field.png : 플레이어 옆에 선 엘리트 — 큰 덩치·붉은 이름표·경계 진입 대사
# 실행: godot --path . --script res://tests/elite_visual_capture.gd

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("ELITE_CAPTURE_TIMEOUT")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for _frame in 12:
		await process_frame
	main_scene.set("world_time_hours", 12.0)
	var chain: Object = main_scene.get("main_mission")
	var cine: Object = chain.get("cinematic")
	await _wait(1.0)
	var guard := 0
	while bool(cine.get("running")) and guard < 40:
		cine.call("skip")
		await _wait(0.25)
		guard += 1
	var player := main_scene.get_node("Player") as Node3D
	var elite: Node3D = null
	var regular: Node3D = null
	for raw_enemy in main_scene.get("enemies") as Array:
		var enemy := raw_enemy as Node3D
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get_meta("elite", false)) and elite == null:
			elite = enemy
		elif regular == null and not bool(enemy.get_meta("elite", false)):
			regular = enemy
	if elite == null:
		push_error("엘리트 없음")
		quit(1)
		return
	var chatter: Object = main_scene.get("enemy_chatter")
	chatter.call("update", 0.35)
	for _frame in 3:
		elite.global_position = player.global_position + Vector3(3.2, 0.0, -1.0)
		if regular != null:
			regular.global_position = player.global_position + Vector3(-3.2, 0.0, -1.0)
		await process_frame
	elite.set("alerted", true)
	chatter.call("update", 0.35)
	for _frame in 3:
		elite.global_position = player.global_position + Vector3(3.2, 0.0, -1.0)
		if regular != null:
			regular.global_position = player.global_position + Vector3(-3.2, 0.0, -1.0)
		await process_frame
	await _wait(0.25)
	elite.global_position = player.global_position + Vector3(3.2, 0.0, -1.0)
	if regular != null:
		regular.global_position = player.global_position + Vector3(-3.2, 0.0, -1.0)
	# 은신 안개가 프레임마다 가시성을 덮어쓴다 — 마지막 프레임에 강제로 밝힌다.
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED
	elite.call("set_player_visibility_factor", 1.0)
	if regular != null:
		regular.call("set_player_visibility_factor", 1.0)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/elite_field.png" % OUTPUT_DIR
	if image.save_png(path) == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	print("ELITE_VISUAL_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
