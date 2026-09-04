extends SceneTree

# 쉘터 UI 전면 검수용 캡처(창 필요). 2026-09-04.
# 화면마다 쉘터를 새로 띄워(모달 닫기 경로에 의존하지 않게) 캡처한다.
#   shelter_ui_base.png            : 기본 화면(스탯 패널·운영 독·무기 카드)
#   shelter_ui_stats_expanded.png  : 스탯 패널 펼침
#   shelter_ui_scratcher.png       : 생산(스크래처 뱅크) 모달
#   shelter_ui_catnip.png          : 스크래핑(캣닢) 모달
#   shelter_ui_workbench.png       : 제작(작업대) 모달
#   shelter_ui_training.png        : 훈련 모달
#   shelter_ui_storage.png         : 창고 모달
#   shelter_ui_contract.png        : 사자 계약 화면
#   shelter_ui_merchant.png        : 행상인 가방
#   shelter_ui_briefing.png        : 출정 브리핑
# 실행: godot --path . --script res://tests/shelter_ui_audit_capture.gd

const OUTPUT_DIR := "res://test-output/shelter_ui"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	var shots := [
		["base", ""],
		["stats_expanded", "stats"],
		["scratcher", "facility:scratcher_bank"],
		["catnip", "facility:catnip_scraper"],
		["workbench", "facility:workbench"],
		["training", "facility:training"],
		["storage", "facility:storage"],
		["contract", "_open_contract_ui"],
		["merchant", "_open_merchant_shop"],
		["briefing", "_open_raid_zone_select"],
	]
	for shot in shots:
		var shot_name := str(shot[0])
		var action := str(shot[1])
		game_state.call("reset_run")
		game_state.set("opening_completed", true)
		game_state.set("contract_agent_intro_seen", true)
		game_state.set("saja_intro_seen", true)
		game_state.set("scrap", 48000)
		game_state.set("catnip", 120)
		game_state.set("churu", 3)
		game_state.set("shelter_canned_food", 24)
		game_state.call("unlock_all_shelter_facilities")
		# 액티브 튜토리얼이 모달을 가로채지 않게 전 단계를 완료 처리한다.
		var tutorial_script: GDScript = load("res://scripts/shelter/active_tutorial.gd")
		var done_ids: Array[String] = []
		for step in tutorial_script.STEPS as Array:
			done_ids.append(str((step as Dictionary).get("id", "")))
		game_state.set("tutorial_steps_done", done_ids)
		game_state.call("try_add_rescued_workers", 5)
		game_state.call("_ensure_resident_records")
		# 모듈 모달은 루트에 직접 레이어를 얹는다 — 샷마다 루트의 새 자식을 전부 치운다.
		var baseline: Array[Node] = []
		for child in root.get_children():
			baseline.append(child)
		var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
		root.add_child(shelter)
		await _wait(1.6)
		var guard := 0
		while bool(shelter.get("contract_story_open")) and guard < 30:
			shelter.call("_advance_contract_story")
			guard += 1
			await _wait(0.12)
		if action == "stats":
			shelter.call("_set_stats_panel_expanded", true)
		elif action.begins_with("facility:"):
			var facility_id := action.trim_prefix("facility:")
			var logic: Dictionary = shelter.get("facility_logic")
			var module: Node = logic.get(facility_id) as Node
			if module != null:
				module.call("interact")
			else:
				print("  MISSING facility module %s" % facility_id)
		elif not action.is_empty() and shelter.has_method(action):
			shelter.call(action)
		await _wait(0.8)
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/shelter_ui_%s.png" % [OUTPUT_DIR, shot_name]
		if image.save_png(path) == OK:
			print("  SHOT %s" % ProjectSettings.globalize_path(path))
		shelter.queue_free()
		for child in root.get_children():
			if not baseline.has(child) and child != shelter:
				child.queue_free()
		await process_frame
		await process_frame
	print("SHELTER_UI_AUDIT_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
