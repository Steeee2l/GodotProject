extends SceneTree

# 무기 사다리 스크린샷 프로브(창 필요 — --headless 금지).
#   1) weapon_ladder_workbench.png : 작업대 weapons 탭 — AKM·펌프·K2 행(잠금/해금 상태)
#   2) weapon_ladder_field_akm.png : 필드에서 손에 든 AKM(임시 틴트) + HUD 무기 그림
#
#   godot --path . --script res://tests/weapon_ladder_visual_capture.gd

const WORKBENCH_OUTPUT := "res://test-output/weapon_ladder_workbench.png"
const FIELD_OUTPUT := "res://test-output/weapon_ladder_field_akm.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("WEAPON_LADDER_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("complete_opening_and_prepare_shelter")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("shelter_tier", 5)
	game_state.set("shelter_workbench_level", 5)
	game_state.set("scrap", 420000)
	game_state.set("catnip", 30000)
	game_state.call("add_mod_component", "scope_lens", 4)
	game_state.call("add_mod_component", "magazine_spring", 4)
	game_state.call("add_mod_component", "rubber_gasket", 4)
	# AKM·펌프 청사진은 있고 용산 키는 없다 — 해금/잠금 두 상태가 한 화면에.
	game_state.call("add_progression_item", "akm_blueprint", 1)
	game_state.call("add_progression_item", "pump_blueprint", 1)
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	levels["double_barrel"] = 5

	# ── 샷 1: 작업대 weapons 탭 ──
	var shelter := load("res://scenes/shelter_interior.tscn").instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame
	await create_timer(0.6, true, false, true).timeout
	var workbenches := get_nodes_in_group("shelter_workbench")
	if workbenches.is_empty():
		push_error("작업대를 찾지 못했습니다.")
		quit(1)
		return
	var workbench := workbenches[0] as Node
	workbench.call("interact")
	await process_frame
	workbench.set("selected_category", "weapons")
	workbench.set("selected_recipe_id", "akm")
	workbench.call("_rebuild_ui")
	for _frame in 8:
		await process_frame
	# 레시피 목록을 끝까지 내려 AKM·더블배럴·펌프·K2 행이 한 화면에 들어오게 한다.
	var recipe_scroll := root.find_child("WorkbenchRecipeScroll", true, false) as ScrollContainer
	if recipe_scroll != null:
		recipe_scroll.scroll_vertical = 100000
	for _frame in 4:
		await process_frame
	await _capture(WORKBENCH_OUTPUT)
	# 작업대 모달은 current_scene이 없을 때 root에 직접 붙는다 — 쉘터와 함께 닫지
	# 않으면 다음 필드 컷을 덮는다.
	for modal in get_nodes_in_group("shelter_modal_ui"):
		(modal as Node).queue_free()
	shelter.queue_free()
	await process_frame
	await process_frame

	# ── 샷 2: 필드 — AKM을 들고 있는 나비 ──
	game_state.call("add_weapon", "akm", 1)
	game_state.call("equip_weapon", "akm")
	game_state.set("magazine_ammo", 40)
	game_state.set("has_ak", true)
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("world_time_hours", 12.0)
	await create_timer(0.8, true, false, true).timeout
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while (
		main_mission != null
		and bool(main_mission.call("is_cinematic_active"))
		and skip_guard < 20
	):
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.25, true, false, true).timeout
	await create_timer(0.6, true, false, true).timeout
	# 동쪽을 보게 해 총이 몸 앞으로 나오게 하고, 독백 패널은 총을 가리니 숨긴다.
	main_scene.set("facing", "e")
	await create_timer(0.4, true, false, true).timeout
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	for monologue in root.find_children("*", "", true, false):
		var script: Variant = (monologue as Node).get_script()
		if script != null and str(script.resource_path).ends_with("field_monologue.gd"):
			(monologue as CanvasItem).visible = false
	var camera := main_scene.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= 0.3
	for _frame in 6:
		await process_frame
	print("FIELD equipped=%s tex=%s" % [
		str(main_scene.get("equipped_weapon_id")),
		str((main_scene.get("weapon_sprite") as Node3D) != null),
	])
	await _capture(FIELD_OUTPUT)
	quit(0)


func _capture(path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("WEAPON_LADDER_CAPTURE_OK ", ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [path, error_string(error)])
