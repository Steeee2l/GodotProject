extends SceneTree

# 마지막 출정 화면 캡처(창 필요 — --headless 금지).
#   1) final_raid_briefing.png : 쉘터 출정 브리핑의 '사자를 데리고 나간다' 버튼
#   2) final_raid_confirm.png  : 되돌릴 수 없다는 확인 창
#   3) final_journey_field.png : 필드에서 사자를 데리고 가는 판(이름표·말풍선)
#   4) ending_screen.png       : 엔딩 화면 한 장
#
# 실행: godot --path . --script tests/final_journey_visual_capture.gd

const BRIEFING_OUTPUT := "res://test-output/final_raid_briefing.png"
const CONFIRM_OUTPUT := "res://test-output/final_raid_confirm.png"
const FIELD_OUTPUT := "res://test-output/final_journey_field.png"
const ENDING_OUTPUT := "res://test-output/ending_screen.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		push_error("FINAL_JOURNEY_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("returning_from_shelter", false)
	game_state.set("shelter_tier", 5)
	var progress := {}
	for zone_id in [
		"jongno_outskirts", "namdaemun_market", "euljiro_depths", "yongsan_blockade", "namsan_core",
	]:
		progress[zone_id] = 3
	game_state.set("main_mission_progress", progress)
	game_state.set("final_raid_unlocked", true)
	game_state.set("ending_seen", false)
	game_state.set("companion_enabled", false)
	game_state.call("add_progression_item", "sealed_zone_keycard", 1)
	# 서사 모달이 브리핑을 가리지 않게 미리 다 본 것으로 둔다(캡처 규약).
	var seen_zones: Array[String] = [
		"jongno_outskirts", "namdaemun_market", "euljiro_depths", "yongsan_blockade", "namsan_core",
	]
	game_state.set("saja_seen_main_mission_zones", seen_zones)
	for flag in [
		"saja_intro_seen", "juhong_intro_seen", "saja_second_run_intro_seen",
		"merchant_intro_seen", "contract_agent_intro_seen", "saja_epilogue_seen",
		"workbench_lesson_seen",
	]:
		game_state.set(str(flag), true)
	game_state.set("saja_chatter_serial_seen", 9999)
	game_state.set("shelter_return_serial", 9999)

	await _capture_shelter(game_state)
	await _capture_field(game_state)

	print("FINAL_JOURNEY_CAPTURE_OK")
	quit(0)


func _capture_shelter(game_state: Node) -> void:
	var packed: PackedScene = load("res://scenes/shelter_interior.tscn")
	var shelter: Node = packed.instantiate()
	root.add_child(shelter)
	await process_frame
	await create_timer(1.4, true, false, true).timeout
	# 서사 모달이 떠 있으면 먼저 치운다(프로브 규약).
	game_state.call("mark_shelter_story_event_seen", "saja_main_chain_namsan_core")
	await create_timer(0.4, true, false, true).timeout
	shelter.call("_open_raid_zone_select")
	await create_timer(0.6, true, false, true).timeout
	shelter.call("_select_raid_zone_preview", "namsan_core")
	await create_timer(0.6, true, false, true).timeout
	_capture(BRIEFING_OUTPUT, "final button visible=%s" % str(
		shelter.get("raid_zone_final_button") != null
		and (shelter.get("raid_zone_final_button") as Control).visible
	))
	shelter.call("_open_final_raid_confirm")
	await create_timer(0.7, true, false, true).timeout
	_capture(CONFIRM_OUTPUT)
	shelter.call("_close_final_raid_confirm")
	shelter.call("_close_raid_zone_select")
	shelter.queue_free()
	await create_timer(0.5, true, false, true).timeout


func _capture_field(game_state: Node) -> void:
	game_state.set("selected_raid_zone", "namsan_core")
	game_state.set("final_raid_run", true)
	game_state.set("raid_special_cargo", {})
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	await create_timer(1.0, true, false, true).timeout
	var main_mission = main_scene.get("main_mission")
	var journey = main_scene.get("final_journey")
	var companion = main_scene.get("companion_system")
	var skip_guard := 0
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 25:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.25, true, false, true).timeout
	await create_timer(0.6, true, false, true).timeout
	# 사자를 플레이어 옆에 붙이고 한마디 시킨다.
	var saja = companion.get("saja")
	if saja != null:
		(saja as Node3D).global_position = (
			(main_scene.get_node("Player") as Node3D).global_position + Vector3(1.6, 0.0, 1.2)
		)
	companion.call("saja_bark", "관제탑 지나서 위로 가면 된다며.")
	await create_timer(0.8, true, false, true).timeout
	_capture(FIELD_OUTPUT, "saja=%s" % str(companion.call("is_saja_alive")))

	# 엔딩 화면 — 연출은 건너뛰고 화면만 띄운다.
	journey.call("_show_ending_screen")
	await create_timer(1.0, true, false, true).timeout
	_capture(ENDING_OUTPUT, "ending_seen=%s" % str(game_state.get("ending_seen")))
	paused = false


func _capture(path: String, note: String = "") -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("캡처 실패 %s (%d)" % [path, error])
	else:
		print("CAPTURED %s %s" % [path, note])
