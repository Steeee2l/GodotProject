extends SceneTree

# 메인 미션 체인 시각 확인용 캡처. 창 모드로만 돌린다(--headless 금지).
#   godot --path . --script res://tests/main_mission_chain_visual_capture.gd
#
# 뽑는 컷:
#   1) 종로 2단계 목표 마커(전술 지도)
#   2) 종로 3단계 목표 마커(전술 지도)
#   3) 시네마틱 대사창(레터박스 + 초상화 + 타자기)
#   4) 회수 기록 이미지 컷
#   5) 구역 완주 안내(필드 알림)

const OUTPUT_DIR := "res://test-output"
const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)

	for capture in [
		{"stage": 1, "name": "main_mission_stage2_marker"},
		{"stage": 2, "name": "main_mission_stage3_marker"},
	]:
		var stage_index := int((capture as Dictionary)["stage"])
		game_state.call("reset_run")
		(game_state.get("main_mission_progress") as Dictionary)["jongno_outskirts"] = stage_index
		(game_state.get("seen_field_cinematics") as Array).clear()
		var main_scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main_scene)
		for _frame in 12:
			await process_frame
		var chain: Object = main_scene.get("main_mission")
		print("CAPTURE stage_index=%d id=%s" % [
			int(chain.get("stage_index")),
			str((chain.get("stage") as Dictionary).get("id", "")),
		])
		# 첫 컷은 시네마틱 대사창(1단계 캡처 루프에서만 한 번).
		if stage_index == 1:
			# 인트로는 대기 → 카메라 포커스 → 섬광 → 대사 순서라 몇 초 걸린다.
			# 프레임 수로 세면 안 된다 — 이 프로브는 수백 fps로 돈다. 벽시계로 잰다.
			var cine: Object = chain.get("cinematic")
			await _wait_for_dialogue(cine, 12.0)
			print("  CINE running=%s step=%d dialogue=%s" % [
				str(cine.get("running")),
				int(cine.get("_step_index")),
				str(is_instance_valid(cine.get("dialogue_panel") as Control)),
			])
			await _capture("main_mission_cinematic_dialogue")
			chain.get("cinematic").call("skip")
			for _frame in 20:
				await process_frame
		# 전술 지도를 열어 목표 마커를 담는다.
		var tactical_map := main_scene.get("tactical_map") as Control
		if not bool(tactical_map.call("is_open")):
			tactical_map.call("toggle")
		for _frame in 10:
			await process_frame
		await _capture(str((capture as Dictionary)["name"]))
		if tactical_map.has_method("close"):
			tactical_map.call("close")
		for _frame in 6:
			await process_frame
		# 이미지 컷(회수 기록 화면)은 3단계 캡처에서 한 번.
		if stage_index == 2:
			# 이 구역의 인트로 연출이 아직 돌고 있으면 먼저 걷어낸다 — 연출이
			# 겹치면 새 재생은 그대로 버려진다(겹침 방지 규칙).
			var running_cine: Object = chain.get("cinematic")
			while bool(running_cine.get("running")):
				running_cine.call("skip")
				await _wait_seconds(0.2)
			chain.get("cinematic").call("play", [
				{
					"type": "image_cut",
					"texture": load("res://assets/events/subway_manifest_terminal_v2.png"),
					"title": "최종 송출 로그",
					"lines": [
						"마지막 송출은 대피 안내가 아니었다.",
						"아나운서는 주소 스물일곱 개를 천천히, 두 번 읽었다.",
						"목록 옆 여백에 연필로 눌러 쓴 글자. ‘문 열어 둠.’",
					],
				},
			])
			await _wait_seconds(1.5)
			await _capture("main_mission_image_cut")
			chain.get("cinematic").call("skip")
			for _frame in 20:
				await process_frame
			# 구역 완주 안내 문구를 필드 알림으로 띄워 담는다.
			main_scene.call(
				"_show_field_notice", chain.call("get_zone_completion_text", "jongno_outskirts")
			)
			for _frame in 12:
				await process_frame
			await _capture("main_mission_zone_completion_notice")
		main_scene.queue_free()
		for _frame in 6:
			await process_frame

	print("MAIN_MISSION_VISUAL_CAPTURE_OK")
	quit(0)


func _wait_seconds(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout


func _wait_for_dialogue(cine: Object, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if is_instance_valid(cine.get("dialogue_panel") as Control):
			# 타자기가 몇 글자 흐른 뒤에 담아야 화면이 비어 보이지 않는다.
			await _wait_seconds(0.9)
			return
		await _wait_seconds(0.1)
		elapsed += 0.1


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
