extends SceneTree

# 영어 로케일 UI 검수용 캡처(창 필요). 2026-09-06.
# 로케일을 en으로 바꾼 뒤 쉘터·작업대·창고·가방 화면을 찍는다 —
# 번역이 붙었는지, 영어가 길어져 버튼·칩이 깨지지 않는지 눈으로 본다.
#   locale_en_shelter.png    : 쉘터 기본 화면(운영 독)
#   locale_en_workbench.png  : 제작(작업대) 모달
#   locale_en_storage.png    : 창고 모달
#   locale_en_scratcher.png  : 꾹꾹이 생산기 모달
#   locale_en_settings.png   : 설정 화면(언어 선택 포함)
#   locale_en_bag.png        : 가방(인벤토리)
# 실행: godot --path . --script res://tests/locale_english_capture.gd

const OUTPUT_DIR := "res://test-output/locale_en"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	TranslationServer.set_locale("en")
	print("locale=", TranslationServer.get_locale(), " sample=", tr("작업대"))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	var shots := [
		["shelter", ""],
		["workbench", "facility:workbench"],
		["storage", "facility:storage"],
		["scratcher", "facility:scratcher_bank"],
		["settings", "settings"],
		["bag", "bag"],
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
		var tutorial_script: GDScript = load("res://scripts/shelter/active_tutorial.gd")
		var done_ids: Array[String] = []
		for step in tutorial_script.STEPS as Array:
			done_ids.append(str((step as Dictionary).get("id", "")))
		game_state.set("tutorial_steps_done", done_ids)
		game_state.call("try_add_rescued_workers", 5)
		game_state.call("_ensure_resident_records")
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
		if action.begins_with("facility:"):
			var facility_id := action.trim_prefix("facility:")
			var logic: Dictionary = shelter.get("facility_logic")
			var module: Node = logic.get(facility_id) as Node
			if module != null:
				module.call("interact")
			else:
				print("  MISSING facility module %s" % facility_id)
		elif action == "settings":
			root.get_node("AccessibilitySettings").call("open")
		elif action == "bag":
			var bag: Node = shelter.get("inventory_ui")
			if bag != null:
				bag.call("set_open", true)
			else:
				print("  MISSING inventory_ui")
		await _wait(0.9)
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/locale_en_%s.png" % [OUTPUT_DIR, shot_name]
		if image.save_png(path) == OK:
			print("  SHOT %s" % ProjectSettings.globalize_path(path))
		if action == "settings":
			root.get_node("AccessibilitySettings").call("close")
		shelter.queue_free()
		for child in root.get_children():
			if not baseline.has(child) and child != shelter:
				child.queue_free()
		await process_frame
		await process_frame
	TranslationServer.set_locale("ko")
	print("LOCALE_ENGLISH_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
