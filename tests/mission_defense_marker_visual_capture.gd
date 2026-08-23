extends SceneTree

# 방어 단계 "사수 지점이 어디인지" 시각 확인용 캡처. 창 모드로만 돌린다(--headless 금지).
#   godot --path . --script res://tests/mission_defense_marker_visual_capture.gd
#
# 뽑는 컷:
#   1) 방어 중 전술 지도 — 사수 지점 마커 + 사수 반경 원
#   2) 필드 — 바닥 사수 구역 링(반경 밖이라 붉게) + 좌상단 목표 패널의 거리·방향

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("DEFENSE_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("shelter_tier", 2)
	game_state.set("selected_raid_zone", "namdaemun_market")
	(game_state.get("main_mission_progress") as Dictionary)["namdaemun_market"] = 1

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for _frame in 12:
		await process_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	var chain: Object = main_scene.get("main_mission")
	# 진입 연출이 카메라를 쥐고 있으면 엉뚱한 곳을 찍는다 — 먼저 걷어낸다.
	var guard := 0
	while bool(chain.call("is_cinematic_active")) and guard < 20:
		chain.get("cinematic").call("skip")
		guard += 1
		await _wait_seconds(0.2)
	await _wait_seconds(0.4)

	# 제어반을 조작해 방어를 시작시킨다.
	var site := (chain.get("point_sites") as Dictionary).get(0, null) as Node3D
	main_scene.call("_complete_field_interaction", site)
	var defense_position: Vector3 = chain.get("defense_position")
	print("DEFENSE started at %s active=%s" % [
		str(defense_position.round()), str(chain.get("defense_active"))
	])

	# 반경(9m) 밖으로 나가 "거리 안내 + 붉은 링" 상태를 만든다.
	var player := main_scene.get("player") as Node3D
	player.global_position = defense_position + Vector3(10.4, 0.0, 1.2)
	# 진입 바크가 화면 가운데를 가린다 — 흘러가길 기다렸다 담는다.
	await _wait_seconds(4.5)
	print("DETAIL=%s" % str((main_scene.get("hud").jackpot_detail_label as Label).text))
	print("PANEL=%s" % str((main_scene.get("objective_label") as Label).text).replace("\n", " | "))

	# 컷 2(필드) 먼저 — 지도를 열면 트리가 멈춰 링 점멸이 굳는다.
	await _capture("main_mission_defense_zone_field")

	# 지도 컷은 조금 떨어져서 — 내 위치 마커가 사수 구역 원을 덮지 않게.
	player.global_position = defense_position + Vector3(26.0, 0.0, 20.0)
	await _wait_seconds(0.5)
	var tactical_map := main_scene.get("tactical_map") as Control
	if not bool(tactical_map.call("is_open")):
		tactical_map.call("toggle")
	for _frame in 10:
		await process_frame
	await _capture("main_mission_defense_map")
	tactical_map.call("close")

	print("MISSION_DEFENSE_VISUAL_CAPTURE_OK")
	quit(0)


func _wait_seconds(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
