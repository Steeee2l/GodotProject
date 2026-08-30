extends SceneTree

# 첫 출정 튜토리얼 + 필드 HUD 카드 프로브.
#   godot --headless --path . --script res://tests/first_sortie_tutorial_probe.gd
#
# [A] 필드 체인(RaidTutorial): 새 세이브 → 이동→조준→수색(실제 상호작용)→가방(실제 열기)
#     →탈출(실제 접근) 순으로 실제 이벤트로만 넘어가고, 완료가 저장되는지.
# [B] 기존 세이브(복귀 경험 있음) → 체인이 아예 만들어지지 않는지.
# [C] 임무 트래커 카드·상호작용 캡슐이 720×540에서 화면을 넘치지 않는지.
# [D] 쉘터 체인(ActiveTutorial): first_sortie_gate(출구 가리킴) → 브리핑 열림 → 완료 →
#     first_sortie_launch(구역 마커 → 출정 버튼) → 출정 개시 → 완료.

var failures := 0
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _sleep(seconds: float) -> void:
	await create_timer(seconds, true).timeout
	await process_frame


func _settle_barks(main_scene: Node) -> void:
	for _attempt in 12:
		if not bool(main_scene.call("is_bark_active")):
			return
		(main_scene.get("main_mission")).get("cinematic").call("skip")
		(main_scene.get("monologue")).call("cancel_bark")
		await _sleep(0.5)


func _fresh_save() -> void:
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	game_state.set("merchant_intro_seen", true)
	# bag_throw(쉘터 튜토리얼의 필드 스텝)가 끼어들지 않게 통조림 0.
	game_state.set("canned_food", 0)


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", true)
	_fresh_save()

	# ── [A] 필드 체인 ────────────────────────────────────────────
	print("[A] 첫 출정 필드 체인")
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var tutorial = main_scene.get("raid_tutorial")
	_check(tutorial != null, "필드가 raid_tutorial을 들고 있다")
	_check(main_scene.get_node_or_null("RaidTutorialLayer") != null, "새 세이브 → 튜토리얼 레이어 생성")
	_check(bool(tutorial.call("is_chain_active")), "체인 활성")
	for enemy in main_scene.get("enemies") as Array:
		if is_instance_valid(enemy):
			enemy.set("alerted", false)
	await _settle_barks(main_scene)
	await _sleep(0.6)

	# ① 이동 — 실제 속도 감지로 완료.
	_check(str(tutorial.call("get_active_step_id")) == "sortie_move", "스텝① = sortie_move (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var player := main_scene.get("player") as CharacterBody3D
	player.velocity = Vector3(3.0, 0.0, 0.0)
	tutorial.call("_track_inputs", 1.5)
	tutorial.set("poll_timer", 0.0)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "sortie_move")), "이동 입력 → sortie_move 완료 저장")

	# ② 조준 — laser_aim_held 감지로 완료.
	await _sleep(0.4)
	_check(str(tutorial.call("get_active_step_id")) == "sortie_aim", "스텝② = sortie_aim (실제: %s)" % str(tutorial.call("get_active_step_id")))
	main_scene.set("laser_aim_held", true)
	tutorial.call("_track_inputs", 1.0)
	main_scene.set("laser_aim_held", false)
	tutorial.set("poll_timer", 0.0)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "sortie_aim")), "조준 입력 → sortie_aim 완료 저장")

	# ③ 수색 — 실제 상호작용 완료 이벤트로.
	await _sleep(0.4)
	_check(str(tutorial.call("get_active_step_id")) == "sortie_loot", "스텝③ = sortie_loot (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var loot_point: Node3D
	for point_value in main_scene.get("field_interactions") as Array:
		var point := point_value as Node3D
		if point != null and is_instance_valid(point) and str(point.get_meta("interaction_type", "")) == "loot_container":
			loot_point = point
			break
	_check(loot_point != null, "필드에 루팅 오브젝트가 있다")
	if loot_point != null:
		# 포인터가 월드 대상을 향하는지(화살표 + 거리 칩 경로).
		player.global_position = loot_point.global_position + Vector3(1.1, 0.0, 0.4)
		await _sleep(0.4)
		tutorial.call("_resolve_pointer")
		_check(bool(tutorial.get("pointer_world_valid")), "수색 스텝 포인터 = 월드 대상")
		main_scene.call("_complete_field_interaction", loot_point)
	tutorial.set("poll_timer", 0.0)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "sortie_loot")), "상호작용 완료 → sortie_loot 완료 저장")
	# 전리품 교체 모달은 가방 무제한화(2026-08-30)로 폐지 — 닫을 창이 없다.
	await _sleep(0.3)

	# ④ 가방 — 실제 인벤토리 열기로.
	await _sleep(0.3)
	_check(str(tutorial.call("get_active_step_id")) == "sortie_bag", "스텝④ = sortie_bag (실제: %s)" % str(tutorial.call("get_active_step_id")))
	if not bool(main_scene.call("_is_inventory_open")):
		main_scene.call("_toggle_inventory")
	tutorial.set("poll_timer", 0.0)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "sortie_bag")), "가방 열기 → sortie_bag 완료 저장")
	if bool(main_scene.call("_is_inventory_open")):
		main_scene.call("_toggle_inventory")
	await _sleep(0.4)

	# ⑤ 탈출 — 실제 접근으로.
	_check(str(tutorial.call("get_active_step_id")) == "sortie_extract", "스텝⑤ = sortie_extract (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var sites := main_scene.get("extraction_sites") as Array
	_check(not sites.is_empty(), "탈출 지점이 있다")
	if not sites.is_empty():
		player.global_position = (sites[0] as Node3D).global_position + Vector3(2.0, 0.0, 0.0)
	tutorial.set("poll_timer", 0.0)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "sortie_extract")), "탈출 지점 접근 → sortie_extract 완료 저장")
	_check(not bool(tutorial.call("is_chain_active")), "전 스텝 완료 → 체인 종료")

	# ── [C] HUD 카드 720×540 ────────────────────────────────────
	print("[C] 임무 트래커 · 상호작용 캡슐 — 720×540")
	root.size = Vector2i(720, 540)
	await process_frame
	main_scene.call("_apply_hud_layout")
	main_scene.call("_refresh_objective_panel")
	await process_frame
	# 스트레치(canvas_items)라 UI 좌표계는 창 크기가 아니라 캔버스 가시 영역이다.
	var viewport_rect := root.get_visible_rect()
	print("  window=%s canvas=%s" % [root.size, viewport_rect])
	var objective_panel := main_scene.get("objective_panel") as Control
	_check(objective_panel != null and objective_panel.visible, "트래커 카드 표시")
	if objective_panel != null:
		var card_rect := objective_panel.get_global_rect()
		print("  tracker rect=%s min=%s" % [card_rect, objective_panel.get_combined_minimum_size()])
		_check(card_rect.size.x <= 302.0, "트래커 폭 ≤ 300 (실제: %.0f)" % card_rect.size.x)
		_check(viewport_rect.encloses(card_rect), "트래커가 화면 안")
		_check(objective_panel.get_combined_minimum_size().x <= card_rect.size.x + 1.0, "트래커 내용이 카드 폭 안")
	var tracker = main_scene.get("mission_tracker")
	_check(tracker != null and (tracker.get("title_label") as Label) != null and not str((tracker.get("title_label") as Label).text).is_empty(), "트래커 제목 채워짐")
	# 상호작용 캡슐 — 남은 상호작용 지점 하나 옆으로.
	var prompt_point: Node3D
	for point_value in main_scene.get("field_interactions") as Array:
		var point := point_value as Node3D
		if point != null and is_instance_valid(point) and not bool(point.get_meta("completed", false)):
			prompt_point = point
			break
	if prompt_point != null:
		player.global_position = prompt_point.global_position + Vector3(1.0, 0.0, 0.3)
		await _sleep(0.4)
		main_scene.call("_apply_hud_layout")
		await process_frame
		var hud = main_scene.get("hud")
		var prompt := hud.get("field_interaction_panel") as Control
		if prompt != null and prompt.visible:
			var prompt_rect := prompt.get_global_rect()
			print("  prompt rect=%s min=%s" % [prompt_rect, prompt.get_combined_minimum_size()])
			_check(viewport_rect.grow(2.0).encloses(prompt_rect), "상호작용 캡슐이 화면 안")
			_check(prompt_rect.size.x <= 402.0, "상호작용 캡슐 폭 ≤ 400 (실제: %.0f)" % prompt_rect.size.x)
			_check(not str((hud.get("field_interaction_action_label") as Label).text).is_empty(), "동사 라벨 채워짐")
			_check((hud.get("field_interaction_progress") as Control) != null, "홀드 링 게이지 존재")
		else:
			print("  (상호작용 지점 근접 실패 — 캡슐 표시 생략)")
	main_scene.queue_free()
	await process_frame
	await process_frame

	# ── [B] 기존 세이브 스킵 ─────────────────────────────────────
	print("[B] 기존 세이브 스킵")
	_fresh_save()
	game_state.set("shelter_return_serial", 3)
	game_state.set("tutorial_steps_done", [])
	var veteran_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(veteran_scene)
	await process_frame
	await physics_frame
	_check(veteran_scene.get_node_or_null("RaidTutorialLayer") == null, "복귀 경험 세이브 → 체인 미생성")
	veteran_scene.queue_free()
	await process_frame
	await process_frame

	# ── [D] 쉘터 체인 ────────────────────────────────────────────
	print("[D] 쉘터 first_sortie_gate → first_sortie_launch")
	_fresh_save()
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	for _frame in 6:
		await process_frame
	game_state.call("consume_milestone_unlocks")
	var shelter_tutorial = shelter.get("active_tutorial")
	_check(shelter_tutorial != null, "쉘터가 액티브 튜토리얼을 들고 있다")
	await _sleep(0.8)
	_check(str(shelter_tutorial.call("get_active_step_id")) == "first_sortie_gate", "쉘터 스텝① = first_sortie_gate (실제: %s)" % str(shelter_tutorial.call("get_active_step_id")))
	var gate_target := shelter_tutorial.call("get_active_target") as Control
	_check(gate_target != null and str(gate_target.name) == "TutorialWorldMarker", "멀리서는 월드 마커를 가리킨다 (실제: %s)" % (str(gate_target.name) if gate_target != null else "<null>"))
	# 출구 근처로 — 상호작용 버튼으로 갈아탄다.
	var shelter_player := shelter.get("player") as Node3D
	var pipe: Vector3 = shelter.call("_pipe_position")
	shelter_player.position = Vector3(pipe.x - 0.6, shelter_player.position.y, pipe.z + 0.4)
	await _sleep(0.6)
	if str(shelter.get("current_station")) == "pipe_exit":
		var near_target := shelter_tutorial.call("get_active_target") as Control
		_check(near_target == shelter.get("interact_button"), "출구 근처 → 상호작용 버튼을 가리킨다")
	else:
		print("  (스테이션 감지 안 됨: %s — 버튼 전환 검증 생략)" % str(shelter.get("current_station")))
	shelter.call("_open_raid_zone_select")
	await _sleep(0.6)
	_check(bool(game_state.call("is_tutorial_step_done", "first_sortie_gate")), "브리핑 열림 → first_sortie_gate 완료")
	await _sleep(0.5)
	_check(str(shelter_tutorial.call("get_active_step_id")) == "first_sortie_launch", "쉘터 스텝② = first_sortie_launch (실제: %s)" % str(shelter_tutorial.call("get_active_step_id")))
	var briefing_target := shelter_tutorial.call("get_active_target") as Control
	_check(briefing_target != null, "브리핑 안 대상(구역 마커/출정 버튼)을 가리킨다")
	var launch_button := shelter.get("raid_zone_launch_button") as Button
	if launch_button != null and not str(shelter.get("raid_zone_selected_id")).is_empty():
		print("  (구역 자동 선택됨: %s)" % str(shelter.get("raid_zone_selected_id")))
	shelter.set("raid_launch_in_progress", true)
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "first_sortie_launch")), "출정 개시 → first_sortie_launch 완료")
	shelter.set("raid_launch_in_progress", false)
	shelter.call("_close_raid_zone_select")
	shelter.queue_free()
	await process_frame

	print("first_sortie_tutorial_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
