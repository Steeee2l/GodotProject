extends SceneTree

# 중장비 시각 캡처(창 모드 전용) — 눈 확인용 2컷.
#   godot --path . --script res://tests/heavy_gear_visual_capture.gd
#
# ① heavy_gear_workbench   작업대 제작 탭 — '중장비' 섹션 + 지뢰 레시피 상세
# ② heavy_gear_field       필드 — 감시포탑 배치 + 무장된 지뢰(청록 링)

const OUTPUT_DIR := "res://test-output"

var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _wait(frames: int) -> void:
	for _index in frames:
		await process_frame


func _sleep(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
	await process_frame


func _capture(capture_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])


func _run() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		push_error("HEAVY_GEAR_CAPTURE_TIMEOUT")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	game_state.set("merchant_status", "away")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("scrap", 50000)
	game_state.call("add_mod_component", "magazine_spring", 4)
	game_state.call("add_mod_component", "rubber_gasket", 4)
	game_state.call("add_mod_component", "scope_lens", 2)
	game_state.call("add_mod_component", "precision_gear", 1)
	game_state.call("add_mod_component", "military_alloy", 1)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", false)

	# ── ① 작업대 제작 탭 — 중장비 섹션 ──────────────────────────
	print("[1] 작업대 중장비 섹션")
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _wait(6)
	for _advance_index in 24:
		if not bool(shelter.get("contract_story_open")):
			break
		shelter.call("_advance_contract_story")
	await _wait(4)
	game_state.call("consume_milestone_unlocks")
	for layer_name in ["MilestoneUnlockLayer", "ReturnSettlementLayer"]:
		var stray := shelter.get_node_or_null(layer_name)
		if stray != null:
			stray.queue_free()
	await _sleep(0.5)
	var workbench_nodes := get_nodes_in_group("shelter_workbench")
	if workbench_nodes.is_empty():
		push_error("작업대 모듈 없음")
		quit(1)
		return
	var workbench := workbench_nodes[0] as Node
	workbench.set("selected_recipe_id", "craft_field_mine")
	workbench.call("interact")
	await _sleep(0.6)
	var layer := root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	var craft_tab := layer.find_child("WorkbenchTab_craft", true, false) as Button
	craft_tab.pressed.emit()
	await _sleep(0.5)
	layer = root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	# 중장비 섹션이 화면에 들어오게 목록을 스크롤한다.
	var scroll := layer.find_child("WorkbenchRecipeScroll", true, false) as ScrollContainer
	var heavy_row := layer.find_child("WorkbenchRecipeRow_craft_field_mine", true, false) as Control
	if scroll != null and heavy_row != null:
		scroll.ensure_control_visible(heavy_row)
	await _sleep(0.4)
	await _capture("heavy_gear_workbench")
	var workbench_layer := root.find_child("WorkbenchUILayer", true, false)
	if workbench_layer != null:
		workbench_layer.queue_free()
	shelter.queue_free()
	await _wait(3)

	# ── ② 필드 — 포탑 + 무장 지뢰 ───────────────────────────────
	print("[2] 필드 포탑+지뢰")
	game_state.call("add_heavy_gear", "field_mine", 3)
	game_state.call("add_heavy_gear", "salvage_turret", 1)
	game_state.call("add_heavy_gear", "rocket_launcher", 1)
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	await _sleep(0.6)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 오프닝 필드 시네마틱(스포트라이트 비네트)이 장면을 가린다 — 뜰 때까지
	# 기다렸다가 끝까지 스킵한다(단계가 여러 개라 반복).
	# 바크 모드는 is_cinematic_active가 false라 상태로는 못 읽는다 — 그냥 걷어낸다.
	var chain: Object = main_scene.get("main_mission")
	await _sleep(0.8)
	for _skip_index in 6:
		if chain != null and chain.get("cinematic") != null:
			(chain.get("cinematic") as Object).call("skip")
		await _sleep(0.25)
	var player := main_scene.get_node("Player") as CharacterBody3D
	var deployables = main_scene.get("deployables")
	game_state.call("consume_heavy_gear", "salvage_turret", 1)
	deployables.call("place_turret", player.global_position + Vector3(2.6, 0.0, 1.2))
	game_state.call("consume_heavy_gear", "field_mine", 1)
	deployables.call("throw_mine", player.global_position + Vector3(-2.2, 0.0, 2.0))
	# 조준 링 배지도 함께 — T 조준을 연 상태(지뢰 선택)를 담는다.
	var can_throw = main_scene.get("can_throw")
	can_throw.set("selected_kind", "field_mine")
	can_throw.call("toggle_aim")
	# 지뢰가 무장(비행 0.42 + 1.0s)될 때까지 실시간 대기.
	await _sleep(1.8)
	# 대기 중 새 바크 단계가 떴으면 한 번 더 걷어낸다.
	for _late_skip_index in 4:
		if chain != null and chain.get("cinematic") != null:
			(chain.get("cinematic") as Object).call("skip")
		await _sleep(0.25)
	await _capture("heavy_gear_field")
	main_scene.queue_free()
	await _wait(2)
	print("heavy_gear_visual_capture: DONE")
	quit(0)
