extends SceneTree

# 액티브 튜토리얼 필드/정산 프로브 — main.gd host 경로.
#   ① 체력 < 70% + 통조림 보유 → 가방 버튼을 가리키는 bag_eat 스텝 · 가방 열면 통조림 타일로 이동 ·
#      먹기 → 완료
#   ② 정산 화면(트리 정지) + 성장 선택 대기 → level_choice 스텝이 첫 카드를 가리킴 · 선택 → 완료
#   godot --headless --path . --script res://tests/active_tutorial_field_probe.gd

var failures := 0


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
	# 미션 바크는 잇따라 올 수 있다 — 멎을 때까지 접는다(보류 규칙 자체가 검증 대상은 아니다).
	for _attempt in 12:
		if not bool(main_scene.call("is_bark_active")):
			return
		(main_scene.get("main_mission")).get("cinematic").call("skip")
		(main_scene.get("monologue")).call("cancel_bark")
		await _sleep(0.5)


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("canned_food", 2)
	game_state.set("player_health", 40)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", true)
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var tutorial = main_scene.get("active_tutorial")
	_check(tutorial != null, "필드가 액티브 튜토리얼을 들고 있다")
	_check(main_scene.get_node_or_null("ActiveTutorialLayer") != null, "필드에 튜토리얼 레이어가 붙었다")
	# 적이 경계 상태면 보류 — 프로브는 적을 치운다.
	for enemy in main_scene.get("enemies") as Array:
		if is_instance_valid(enemy):
			enemy.set("alerted", false)
	main_scene.set("player_health", 40)
	# 출정 시작 바크(미션 대사)가 흐르는 동안은 보류가 맞다 — 프로브는 바크를 접고 본다.
	await _settle_barks(main_scene)
	_check(not bool(main_scene.call("is_bark_active")), "바크 종료")
	await _sleep(0.8)
	print("[1] 가방 — 먹기")
	_check(str(tutorial.call("get_active_step_id")) == "bag_eat", "활성 스텝 = bag_eat (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var target := tutorial.call("get_active_target") as Control
	_check(target != null and target.name == "InventoryButton", "대상 = 가방 버튼 (실제: %s)" % (target.name if target else "<null>"))
	main_scene.call("_toggle_inventory")
	await _settle_barks(main_scene)
	await _sleep(0.8)
	target = tutorial.call("get_active_target") as Control
	_check(target != null and str(target.name).begins_with("BagItem_canned_food"), "가방 열면 통조림 타일로 이동 (실제: %s)" % (target.name if target else "<null>"))
	main_scene.call("_on_inventory_item_use_requested", "food", "canned_food")
	await _sleep(0.4)
	_check(bool(game_state.call("is_tutorial_step_done", "bag_eat")), "통조림 먹기 → bag_eat 완료")
	main_scene.call("_toggle_inventory")
	await _sleep(0.6)

	print("[2] 정산 — 성장 선택")
	game_state.set("pending_level_choices", 1)
	var hud = main_scene.get("hud")
	(hud.get("extraction_result_panel") as Control).visible = true
	main_scene.call("_show_level_reward_choices")
	paused = true
	await _sleep(0.8)
	_check(str(tutorial.call("get_active_step_id")) == "level_choice", "활성 스텝 = level_choice (실제: %s)" % str(tutorial.call("get_active_step_id")))
	target = tutorial.call("get_active_target") as Control
	var row := hud.get("extraction_level_choice_row") as Control
	_check(target != null and row != null and row.get_child_count() > 0 and target == row.get_child(0), "대상 = 첫 성장 카드")
	var layer := main_scene.get_node_or_null("ActiveTutorialLayer") as CanvasLayer
	_check(layer != null and layer.visible, "정지된 트리에서도 레이어가 보인다")
	if target != null:
		(target as BaseButton).pressed.emit()
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "level_choice")), "성장 선택 → level_choice 완료")
	paused = false
	main_scene.queue_free()
	await process_frame
	print("active_tutorial_field_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
