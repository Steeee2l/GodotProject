extends SceneTree

# 액티브 튜토리얼 잔여 스텝 실검증 — 실제 쉘터 씬에서 끝까지 돌린다.
#   창 모드(스크린샷 4컷+레이아웃 2컷): godot --path . --script res://tests/active_tutorial_steps_probe.gd
#   헤드리스(검증만):                   godot --headless --path . --script res://tests/active_tutorial_steps_probe.gd
#
# ① salvage_notice  복귀 정산 카드(분해 줄) → 라벨 포인터 → [확인]으로 닫으면 완료
# ② merchant_sell   상인 알림 패널 → (관 근처) 상호작용 버튼 → 입장 카드 동안 숨김 → 수락 →
#                   (상인 근처) 거래 버튼 → 상점 → 판매 탭 → 판매 행 → 판매 1회 → 완료
# ③ fever_charge    피버 버튼 → 충전 1회(게이지 +25%) → 완료
# ④ workbench_craft 독 작업대 버튼 → 모달 열면 WorkbenchEnhanceCard/WorkbenchEnhanceButton → 강화 1회 → 완료
# ⑤ 세로 720x1280 · 가로 1555x720 — 작업대 모달 안 포인터의 카드/화살표가 화면 안·대상과 겹침 없음

const OUTPUT_DIR := "res://test-output"

var shelter: Node
var game_state: Node
var tutorial: RefCounted
var layer: CanvasLayer
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _wait(frames: int) -> void:
	for _index in frames:
		await process_frame


func _sleep(seconds: float) -> void:
	# 스텝 폴링(0.25s)·✓ 연출(0.4s)은 실시간 기준 — 시간을 기다린다.
	await create_timer(seconds, true).timeout
	await process_frame


func _step() -> String:
	return str(tutorial.call("get_active_step_id"))


func _target() -> Control:
	return tutorial.call("get_active_target") as Control


func _target_name() -> String:
	var target := _target()
	return str(target.name) if target != null else "<null>"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	game_state.set("merchant_intro_seen", true)
	game_state.set("catnip_fever_lesson_seen", true)
	# 첫 복귀(serial 1 → 행상인이 관 앞에서 기다린다) · 시설 4종 해금 · 주민 1명.
	game_state.call("register_shelter_return", true)
	for facility_id in ["scratcher_bank", "training", "workbench", "catnip_scraper"]:
		game_state.call("unlock_shelter_facility", facility_id)
	game_state.call("try_add_rescued_workers", 1)
	game_state.call("consume_milestone_unlocks")
	# 앞선 스텝은 끝난 것으로 — 이 프로브는 잔여 4스텝만 본다.
	for done_id in ["seat_worker", "read_goal", "train_magazine"]:
		game_state.call("mark_tutorial_step_done", done_id)
	# 트리거를 순서대로 열기 위해 고철·캣닢은 0에서 시작. 통조림 3개 = 판매 가능 물건.
	game_state.set("scrap", 0)
	game_state.set("catnip", 0)
	game_state.set("canned_food", 3)
	# 복귀 정산에 '분해' 줄이 있어야 salvage_notice 카드가 뜬다.
	game_state.set("last_return_settlement", {"salvaged_items": 2, "salvaged_components": 4})
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", true)

	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _wait(6)
	game_state.call("consume_milestone_unlocks")
	var stray := shelter.get_node_or_null("MilestoneUnlockLayer")
	if stray != null:
		stray.queue_free()
	tutorial = shelter.get("active_tutorial")
	layer = shelter.get_node_or_null("ActiveTutorialLayer") as CanvasLayer
	_check(tutorial != null and layer != null, "쉘터가 액티브 튜토리얼을 들고 있다")
	print("  viewport=%s" % str(root.get_visible_rect().size))
	await _sleep(0.8)

	# ① salvage_notice — 정산 카드의 '분해' 줄
	print("[1] salvage_notice — 복귀 정산 카드")
	var settlement := shelter.get("return_settlement_layer") as CanvasLayer
	_check(settlement != null and is_instance_valid(settlement), "복귀 정산 카드가 떠 있다")
	_check(_step() == "salvage_notice", "활성 스텝 = salvage_notice (실제: %s)" % _step())
	var target := _target()
	_check(target is Label and str((target as Label).text).contains("분해"), "대상 = 정산 카드의 분해 줄 (실제: %s)" % _target_name())
	_check(layer.visible and (layer.find_child("TutorialArrow", true, false) as Control).visible, "포인터가 보인다(모달 안 대상)")
	_log_rects("salvage-card")
	await _capture("active_tutorial_step_salvage_notice")
	var confirm := root.find_child("ReturnSettlementConfirmButton", true, false) as Button
	_check(confirm != null, "정산 카드 [확인] 버튼 존재")
	if confirm != null:
		confirm.pressed.emit()
	await _sleep(0.5)
	_check(bool(game_state.call("is_tutorial_step_done", "salvage_notice")), "카드 확인(닫힘) → salvage_notice 완료")
	# 카드가 닫히면 서사/배너 후속이 열릴 수 있다 — 걷어 낸다.
	await _sleep(0.4)
	for _advance_index in 24:
		if not bool(shelter.get("contract_story_open")):
			break
		shelter.call("_advance_contract_story")
	await _wait(3)
	for layer_name in ["MilestoneUnlockLayer", "JuhongCinematicLayer"]:
		var extra := shelter.get_node_or_null(layer_name)
		if extra != null:
			extra.queue_free()
	await _sleep(0.8)

	# ② merchant_sell — 알림 → 상호작용 → 판매 탭 → 판매 행
	print("[2] merchant_sell — 상인 알림 → 상호작용 → 판매 탭 → 판매 행")
	_check(str(game_state.get("merchant_status")) == "waiting", "첫 복귀 = 행상인 대기 (실제: %s)" % str(game_state.get("merchant_status")))
	_check(_step() == "merchant_sell", "활성 스텝 = merchant_sell (실제: %s)" % _step())
	_check(_target_name() == "MerchantArrivalNotice", "대상 = 상인 도착 알림 패널 (실제: %s)" % _target_name())
	_log_rects("merchant-notice")
	# 관(파이프) 앞으로 순간이동 → 상호작용 버튼이 뜬다 → 포인터가 옮겨 간다.
	var player := shelter.get("player") as Node3D
	var pipe: Vector3 = shelter.call("_pipe_position")
	player.position = Vector3(pipe.x - 0.6, player.position.y, pipe.z + 0.4)
	await _sleep(0.6)
	_check(str(shelter.get("current_station")) == "merchant_waiting", "관 앞 → current_station = merchant_waiting (실제: %s)" % str(shelter.get("current_station")))
	_check(_target_name() == (shelter.get("interact_button") as Control).name, "대상 = 상호작용(대화) 버튼 (실제: %s)" % _target_name())
	await _capture("active_tutorial_step_merchant_interact")
	shelter.call("_interact")
	await _sleep(0.5)
	_check(bool(shelter.get("merchant_ui_open")) and root.find_child("MerchantArrivalCard", true, false) != null, "입장 카드가 열렸다")
	_check(not (layer.find_child("TutorialArrow", true, false) as Control).visible, "입장 카드(모달) 동안 포인터 숨김(딤 아래 가리키지 않음)")
	shelter.call("_accept_merchant")
	await _sleep(0.5)
	_check(str(game_state.get("merchant_status")) == "inside" and is_instance_valid(shelter.get("merchant")), "수락 → 행상인 입장")
	var merchant := shelter.get("merchant") as Node3D
	player.position = Vector3(merchant.position.x + 0.9, player.position.y, merchant.position.z + 0.6)
	await _sleep(0.6)
	_check(str(shelter.get("current_station")) == "merchant_shop", "상인 옆 → current_station = merchant_shop (실제: %s)" % str(shelter.get("current_station")))
	_check(_target_name() == (shelter.get("interact_button") as Control).name, "대상 = 거래 버튼 (실제: %s)" % _target_name())
	shelter.call("_interact")
	await _sleep(0.6)
	_check(root.find_child("MerchantShopLayer", true, false) != null and str(shelter.get("merchant_shop_mode")) == "buy", "상점 열림(구매 탭)")
	_check(_target_name() == "MerchantSellTab", "대상 = 판매 탭 (실제: %s)" % _target_name())
	_log_rects("merchant-sell-tab")
	var sell_tab := root.find_child("MerchantSellTab", true, false) as Button
	if sell_tab != null:
		sell_tab.pressed.emit()
	await _sleep(0.6)
	_check(str(shelter.get("merchant_shop_mode")) == "sell", "판매 탭으로 전환")
	var sell_row := _target()
	_check(sell_row != null and str(sell_row.name).begins_with("MerchantGood_"), "대상 = 판매 행 (실제: %s)" % _target_name())
	_check(sell_row != null and sell_row.get_node_or_null("RimPulseFx") != null, "판매 행에 림 펄스")
	_log_rects("merchant-sell-row")
	await _capture("active_tutorial_step_merchant_sell")
	var scrap_before := int(game_state.get("scrap"))
	if sell_row is BaseButton:
		(sell_row as BaseButton).pressed.emit()
	await _sleep(0.5)
	_check(int(game_state.get("scrap")) > scrap_before, "판매 1회 → 고철 증가 (%d → %d)" % [scrap_before, int(game_state.get("scrap"))])
	_check(bool(game_state.call("is_tutorial_step_done", "merchant_sell")), "merchant_sell 완료")
	shelter.call("_close_merchant_ui")
	await _sleep(0.9)

	# ③ fever_charge — 피버 버튼 → 충전 1회
	print("[3] fever_charge — 캣닢 피버")
	var fever_cost := int(game_state.call("get_catnip_fever_charge_cost"))
	game_state.set("catnip", fever_cost * 3)
	await _sleep(0.7)
	_check(_step() == "fever_charge", "활성 스텝 = fever_charge (실제: %s)" % _step())
	_check(_target_name() == "CatnipFeverButton", "대상 = 피버 버튼 (실제: %s)" % _target_name())
	_check(_target() != null and _target().get_node_or_null("RimPulseFx") != null, "피버 버튼에 림 펄스")
	_log_rects("fever-button")
	await _capture("active_tutorial_step_fever_charge")
	var gauge_before := float(game_state.get("catnip_fever_gauge"))
	var ops = shelter.get("ops_console")
	ops.call("charge_fever")
	await _sleep(0.5)
	_check(float(game_state.get("catnip_fever_gauge")) > gauge_before, "충전 1회 → 게이지 상승 (%.0f → %.0f)" % [gauge_before, float(game_state.get("catnip_fever_gauge"))])
	_check(bool(game_state.call("is_tutorial_step_done", "fever_charge")), "fever_charge 완료")
	await _sleep(0.9)

	# ④ workbench_craft — 독 작업대 → 강화 카드/버튼 → 강화 1회
	print("[4] workbench_craft — 작업대 강화 보드")
	game_state.set("scrap", 80000)
	for component_id in ["magazine_spring", "rubber_gasket", "scope_lens"]:
		game_state.call("add_mod_component", component_id, 6)
	await _sleep(0.7)
	_check(_step() == "workbench_craft", "활성 스텝 = workbench_craft (실제: %s)" % _step())
	_check(_target_name() == "OpsButton_workbench", "대상 = 운영 독 '작업대' 버튼 (실제: %s)" % _target_name())
	ops.call("open_facility", "workbench")
	await _sleep(0.8)
	var workbench_layer := root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	_check(workbench_layer != null, "작업대 모달 열림")
	_check(workbench_layer != null and workbench_layer.find_child("WorkbenchEnhanceCard", true, false) != null, "강화 카드(WorkbenchEnhanceCard) 존재 — 체인 2단")
	_check(_target_name() == "WorkbenchEnhanceButton", "대상 = [강화 +1] 버튼 (실제: %s)" % _target_name())
	_check(_target() != null and _target().get_node_or_null("RimPulseFx") != null, "[강화 +1]에 림 펄스")
	_log_rects("workbench-enhance-button")
	await _capture("active_tutorial_step_workbench_craft")
	var enhance_button := _target() as Button
	var level_before := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	if enhance_button != null:
		var center := enhance_button.get_global_rect().get_center()
		_press_at(center, true)
		await _sleep(0.05)
		_press_at(center, false)
	# ✓는 완료(폴링 0.25s 이내) 뒤 0.4초만 떠 있다 — 프레임마다 지켜보다 한 번이라도 보이면 된다.
	var check_label := layer.find_child("TutorialCheck", true, false) as Label
	var check_seen := false
	for _frame in 90:
		await process_frame
		if check_label != null and check_label.visible:
			check_seen = true
		if check_seen and bool(game_state.call("is_tutorial_step_done", "workbench_craft")):
			break
	_check(int(game_state.call("get_weapon_enhancement_level", "ak47")) == level_before + 1, "강화 1회 (+%d → +%d)" % [level_before, int(game_state.call("get_weapon_enhancement_level", "ak47"))])
	_check(bool(game_state.call("is_tutorial_step_done", "workbench_craft")), "workbench_craft 완료")
	_check(check_seen, "✓ 체크 연출")
	await _sleep(1.0)

	# ⑤ 세로/가로 — 작업대 모달 안 포인터(스텝을 되살려 같은 화면에서 잰다)
	print("[5] 세로 720x1280 / 가로 1555x720 — 모달 안 포인터")
	(game_state.get("tutorial_steps_done") as Array).erase("workbench_craft")
	var console_script := load("res://scripts/hud/shelter_ops_console.gd")
	console_script.set("force_touch_layout", true)
	var workbench_nodes := get_nodes_in_group("shelter_workbench")
	await _resize(Vector2i(720, 1280))
	shelter.call("_apply_shelter_safe_layout")
	if not workbench_nodes.is_empty():
		(workbench_nodes[0] as Node).call("_rebuild_ui")
	await _sleep(0.9)
	_check(_step() == "workbench_craft", "세로: workbench_craft 재활성 (실제: %s)" % _step())
	_check(_target_name() == "WorkbenchEnhanceButton", "세로: 대상 = [강화 +1] (실제: %s)" % _target_name())
	_check_layout("portrait-720x1280")
	await _capture("active_tutorial_steps_portrait")
	await _resize(Vector2i(1555, 720))
	shelter.call("_apply_shelter_safe_layout")
	if not workbench_nodes.is_empty():
		(workbench_nodes[0] as Node).call("_rebuild_ui")
	await _sleep(0.9)
	_check(_target_name() == "WorkbenchEnhanceButton", "가로: 대상 = [강화 +1] (실제: %s)" % _target_name())
	_check_layout("landscape-1555x720")
	await _capture("active_tutorial_steps_landscape_wide")
	console_script.set("force_touch_layout", false)
	await _resize(Vector2i(1280, 720))
	await _wait(4)

	var final_layer := root.find_child("WorkbenchUILayer", true, false)
	if final_layer != null:
		final_layer.queue_free()
	shelter.queue_free()
	await _wait(2)
	print("active_tutorial_steps_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _press_at(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event, true)


func _resize(size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		root.size = size
	else:
		DisplayServer.window_set_size(size)
		root.size = size
	await process_frame
	await process_frame


func _check_layout(label: String) -> void:
	var viewport_size := root.get_visible_rect().size
	var card_rect: Rect2 = tutorial.call("get_card_rect")
	var arrow_rect: Rect2 = tutorial.call("get_arrow_rect")
	var target := _target()
	var target_rect := target.get_global_rect() if target else Rect2()
	var screen := Rect2(Vector2.ZERO, viewport_size)
	print("  [%s] viewport=%s target=%s card=%s arrow=%s" % [label, viewport_size, target_rect, card_rect, arrow_rect])
	_check(screen.encloses(card_rect), "%s 카드가 화면 안" % label)
	_check(screen.encloses(arrow_rect), "%s 화살표가 화면 안" % label)
	_check(not card_rect.intersects(target_rect), "%s 카드와 대상이 겹치지 않음" % label)
	_check(not arrow_rect.intersects(target_rect.grow(-2.0)), "%s 화살표와 대상이 겹치지 않음" % label)
	_check(layer != null and layer.visible, "%s 레이어 보임" % label)


func _log_rects(label: String) -> void:
	var card_rect: Rect2 = tutorial.call("get_card_rect")
	var arrow_rect: Rect2 = tutorial.call("get_arrow_rect")
	var target := _target()
	print("  [%s] viewport=%s target=%s card=%s arrow=%s" % [label, root.get_visible_rect().size, target.get_global_rect() if target else Rect2(), card_rect, arrow_rect])
	if target != null:
		_check(not card_rect.intersects(target.get_global_rect()), "%s 카드와 대상 겹침 없음" % label)
		_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(card_rect), "%s 카드 화면 안" % label)


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
