extends SceneTree

# 첫 출정 튜토리얼 카드 · 임무 트래커 카드 · 상호작용 캡슐 시각 캡처.
# 창 모드로만 돌린다(--headless 금지).
#   godot --path . --script res://tests/first_sortie_hud_visual_capture.gd
#
# 컷:
#   1) hud_tutorial_card         — 첫 출정 카드(sortie_move, 키캡 칩)
#   2) hud_tutorial_world_arrow  — 수색 스텝: 월드 화살표 + 거리 칩
#   3) hud_mission_tracker       — 좌상단 임무 트래커 카드(제목/목표/체크 행)
#   4) hud_interaction_card      — 상호작용 캡슐(키캡 링 게이지 진행 중)
#   5) shelter_first_sortie_gate — 쉘터: 출구 월드 마커 + 카드
#   6) shelter_first_sortie_brief — 쉘터: 브리핑 안 출정 안내

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _wait_seconds(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout


func _capture(capture_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])


func _settle(main_scene: Node) -> void:
	for _attempt in 12:
		if not bool(main_scene.call("is_bark_active")):
			break
		(main_scene.get("main_mission")).get("cinematic").call("skip")
		(main_scene.get("monologue")).call("cancel_bark")
		await _wait_seconds(0.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		push_error("FIRST_SORTIE_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("merchant_intro_seen", true)
	game_state.set("canned_food", 0)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", true)

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for _frame in 12:
		await process_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	for enemy in main_scene.get("enemies") as Array:
		if is_instance_valid(enemy):
			enemy.set("alerted", false)
	await _settle(main_scene)
	await _wait_seconds(0.8)
	var tutorial = main_scene.get("raid_tutorial")
	print("STEP=%s" % str(tutorial.call("get_active_step_id")))
	await _capture("hud_tutorial_card")

	# 수색 스텝으로 — 월드 화살표 + 거리 칩.
	game_state.call("mark_tutorial_step_done", "sortie_move")
	game_state.call("mark_tutorial_step_done", "sortie_aim")
	await _wait_seconds(0.7)
	print("STEP=%s" % str(tutorial.call("get_active_step_id")))
	await _capture("hud_tutorial_world_arrow")

	# 트래커 + 상호작용 캡슐 — 튜토리얼은 끝난 상태로.
	for step_id in ["sortie_loot", "sortie_bag", "sortie_extract"]:
		game_state.call("mark_tutorial_step_done", step_id)
	await _wait_seconds(0.5)
	main_scene.call("_refresh_objective_panel")
	await _wait_seconds(0.3)
	await _capture("hud_mission_tracker")

	var player := main_scene.get("player") as Node3D
	var loot_point: Node3D
	for point_value in main_scene.get("field_interactions") as Array:
		var point := point_value as Node3D
		if point != null and is_instance_valid(point) and str(point.get_meta("interaction_type", "")) == "loot_container":
			loot_point = point
			break
	if loot_point != null:
		loot_point.set_meta("hold_duration", 3.0)
		player.global_position = loot_point.global_position + Vector3(1.0, 0.0, 0.3)
		await _wait_seconds(0.5)
		main_scene.set("field_interaction_keyboard_held", true)
		await _wait_seconds(1.2)
		await _capture("hud_interaction_card")
		main_scene.set("field_interaction_keyboard_held", false)
	main_scene.queue_free()
	await process_frame
	await process_frame

	# 쉘터 — first_sortie_gate(월드 마커) / first_sortie_launch(브리핑).
	game_state.set("tutorial_steps_done", [])
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	for _frame in 8:
		await process_frame
	game_state.call("consume_milestone_unlocks")
	await _wait_seconds(0.9)
	var shelter_tutorial = shelter.get("active_tutorial")
	print("SHELTER_STEP=%s" % str(shelter_tutorial.call("get_active_step_id")))
	await _capture("shelter_first_sortie_gate")
	shelter.call("_open_raid_zone_select")
	await _wait_seconds(0.9)
	print("SHELTER_STEP=%s" % str(shelter_tutorial.call("get_active_step_id")))
	await _capture("shelter_first_sortie_brief")
	shelter.call("_close_raid_zone_select")
	shelter.queue_free()
	await process_frame

	print("FIRST_SORTIE_HUD_VISUAL_CAPTURE_OK")
	quit(0)
