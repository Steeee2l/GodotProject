extends SceneTree

# 작업대 '강화 보드'(대개편 2단계) 프로브 — 레이아웃 5컷 + 연타·일괄·돌파 동작.
#   창 모드(스크린샷):  godot --path . --script res://tests/workbench_board_probe.gd
#   헤드리스(검증만):    godot --headless --path . --script res://tests/workbench_board_probe.gd
#
# 컷(res://test-output):
#   ① workbench_board_enhance_landscape   강화 탭 기본(AK 선택, 1280x720, 2열 보드)
#   ② workbench_board_enhance_portrait    세로 720x1280(상단 칩 목록 · 카드 · 고정 액션 바)
#   ③ workbench_board_gate                돌파 관문(+10 미돌파 → 붉은 [돌파 · 고철 xN])
#   ④ workbench_board_locked              미제작 장비(K2 조각 1/3) 카드
#   ⑤ workbench_board_craft_tab           제작 탭(장비 16종 + 하단 보급품 3종 · 제작됨/조각 n/3)
#   ⑥ workbench_board_breakthrough_glitch 돌파 성공 직후(글리치 펄스 + 골드 플래시, 카드 유지)
# [2026-08-29 재개편] 탭은 강화/제작 둘뿐(개조·보급 폐지), 우측 재료 패널 삭제,
# 강화·돌파는 고철 단독 — 관련 어서션을 그 현실에 맞게 갱신했다.
# 동작(헤드리스 포함): [강화 +1] 길게 누름 연타(0.42s 뒤 0.11s 간격) · [가능한 만큼] 돌파 관문 정지 ·
# [돌파] 호출(try_breakthrough) · 모달 rect가 화면 안(세로/가로).

const OUTPUT_DIR := "res://test-output"

var shelter: Node
var game_state: Node
var workbench: Node
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
	await create_timer(seconds, true).timeout
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	game_state.set("merchant_status", "away")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("shelter_tier", 3)
	game_state.set("shelter_workbench_level", 3)
	# 보유 장비: AK +22, AKM +13, 펌프 +4 / 진압 조끼 +9, 전술 헬멧 +6, 전술화 +2. K2는 조각 1/3(미제작).
	game_state.set("scrap", 412000)
	game_state.call("add_weapon", "akm", 1)
	game_state.call("add_weapon", "pump_shotgun", 1)
	var weapon_levels: Dictionary = game_state.get("weapon_enhancement_levels")
	weapon_levels["ak47"] = 22
	weapon_levels["akm"] = 13
	weapon_levels["pump_shotgun"] = 4
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	breakthroughs["weapon:ak47"] = 20
	breakthroughs["weapon:akm"] = 10
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("add_equipment", "tactical_helmet", 1)
	game_state.call("add_equipment", "tactical_boots", 1)
	var armor_levels: Dictionary = game_state.get("armor_enhancement_levels")
	armor_levels["riot_vest"] = 9
	armor_levels["tactical_helmet"] = 6
	armor_levels["tactical_boots"] = 2
	game_state.call("add_blueprint_shards", "k2", 1)
	game_state.call("add_blueprint_shards", "military_vest", 2)
	game_state.call("add_mod_component", "magazine_spring", 9)
	game_state.call("add_mod_component", "rubber_gasket", 7)
	game_state.call("add_mod_component", "scope_lens", 4)
	game_state.call("add_mod_component", "precision_gear", 3)
	game_state.call("add_progression_item", "artisan_seal", 1)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", false)

	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
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
	_check(workbench_nodes.size() >= 1, "작업대 모듈 존재")
	if workbench_nodes.is_empty():
		quit(1)
		return
	workbench = workbench_nodes[0] as Node
	print("  viewport=%s" % str(root.get_visible_rect().size))

	# ① 강화 탭 기본(AK 선택, 가로)
	print("[1] 강화 탭 기본 — 가로")
	workbench.call("interact")
	await _sleep(0.6)
	var layer := root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	_check(layer != null, "WorkbenchUILayer 생성")
	_check(str(workbench.get("enhance_selected_id")) == "ak47", "기본 선택 = 장착 AK-47 (실제: %s)" % str(workbench.get("enhance_selected_id")))
	var primary := layer.find_child("WorkbenchEnhanceButton", true, false) as Button
	var max_button := layer.find_child("WorkbenchEnhanceMaxButton", true, false) as Button
	_check(primary != null and max_button != null, "[강화 +1] · [가능한 만큼] 버튼 존재")
	_check(primary != null and primary.text.begins_with("강화 +1"), "주 버튼 문구 '강화 +1' (실제: %s)" % (primary.text if primary else ""))
	# 탭은 강화/제작 둘뿐 — 개조·보급 탭은 폐지됐다(2026-08-29).
	_check(layer.find_child("WorkbenchTab_enhance", true, false) != null and layer.find_child("WorkbenchTab_craft", true, false) != null, "탭 2개(강화/제작)")
	_check(layer.find_child("WorkbenchTab_supply", true, false) == null, "개조·보급 탭 없음(폐지)")
	var rows := 0
	for node in layer.find_children("WorkbenchGearRow_*", "Button", true, false):
		rows += 1
	_check(rows == 16, "보유 장비 목록 16행(보유 6 + 잠김 10) (실제: %d)" % rows)
	_check(layer.find_child("WorkbenchGearRow_ak47", true, false).get_node_or_null("RimPulseFx") != null, "선택 행 림 펄스")
	_check(layer.find_child("WorkbenchBreakthroughTrack", true, false) != null, "돌파 트랙 존재")
	# 우측 '재료 · 창고 합산' 패널은 폐지됐다 — 강화·돌파가 고철 단독이라 부품을 읽을 이유가 없다.
	_check(layer.find_child("WorkbenchMaterialsPanel", true, false) == null, "재료 패널 없음(폐지 · 2열 보드)")
	var dim := layer.find_child("WorkbenchDim", true, false) as ColorRect
	_check(dim != null and dim.material != null, "유리 배경 셰이더 부착")
	_log_modal_rect("landscape-1280x720")
	await _capture("workbench_board_enhance_landscape")

	# 연타 — 합성 마우스 누름(터치 에뮬레이트 경로와 동일)
	print("[2] [강화 +1] 길게 누름 연타")
	game_state.set("scrap", 50000000)
	var level_before := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	var center := primary.get_global_rect().get_center()
	_press_at(center, true)
	await _sleep(0.05)
	var level_after_tap := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	_check(level_after_tap == level_before + 1, "누르는 순간 +1 (%d → %d)" % [level_before, level_after_tap])
	await _sleep(0.2)
	print("  hold_active=%s draw_mode=%d primary_mode=%s" % [str(workbench.get("hold_active")), primary.get_draw_mode(), str(workbench.get("primary_mode"))])
	await _sleep(0.22 + 0.11 * 3 + 0.06)
	var level_after_hold := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	_check(level_after_hold >= level_after_tap + 3, "0.42s 뒤 0.11s 간격 연타 (%d → %d)" % [level_after_tap, level_after_hold])
	_press_at(center, false)
	await _sleep(0.3)
	var level_after_release := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	_check(level_after_release == level_after_hold or level_after_release == level_after_hold + 1, "떼면 멈춤 (%d → %d)" % [level_after_hold, level_after_release])
	_check(layer.find_child("WorkbenchEnhanceButton", true, false) == primary, "연타 중 버튼이 재생성되지 않음(제자리 갱신)")

	# [가능한 만큼] — 돌파 관문(+30)에서 멈춰야 한다
	print("[3] [가능한 만큼] — 관문 정지")
	game_state.set("scrap", 900000000)
	game_state.call("add_mod_component", "magazine_spring", 40)
	game_state.call("add_mod_component", "rubber_gasket", 40)
	game_state.call("add_mod_component", "scope_lens", 40)
	max_button.pressed.emit()
	await _sleep(0.3)
	var level_after_max := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	_check(level_after_max == 30, "+30 돌파 관문에서 멈춤 (실제: +%d)" % level_after_max)
	_check(bool(game_state.call("is_breakthrough_required", "weapon", "ak47")), "관문 상태(돌파 필요)")
	var toast := layer.find_child("WorkbenchToastLabel", true, false) as Label
	_check(toast != null and toast.text.contains("돌파 관문"), "토스트: 돌파 관문에서 멈춤 (실제: %s)" % (toast.text if toast else ""))
	# 고철 단독 개편 — 버튼은 "돌파 · x49.4K" 형식(고철 아이콘 + 수치).
	_check(primary.text.begins_with("돌파 · x"), "주 버튼이 [돌파 · x고철수치] (실제: %s)" % primary.text)
	_check(primary.icon != null, "돌파 버튼에 고철 아이콘")
	_check(max_button.disabled, "[가능한 만큼] 비활성(관문)")
	_log_modal_rect("landscape-gate")
	await _capture("workbench_board_gate")

	# 돌파 호출 — 고철 단독(2026-08-29: get_breakthrough_cost = {"scrap": 그 단계 강화비 ×3}).
	# 인장·정밀 기어·합금 소모 어서션은 폐지된 현실이라 고철 차감 검증으로 바꿨다.
	print("[4] [돌파] 호출")
	var gate_cost: Dictionary = game_state.call("get_breakthrough_cost", "weapon", "ak47")
	print("  breakthrough cost=%s" % JSON.stringify(gate_cost))
	_check(gate_cost.keys() == ["scrap"], "돌파 비용은 고철 단독 (실제: %s)" % JSON.stringify(gate_cost))
	var seals_before := int(game_state.call("get_progression_item_count", "artisan_seal"))
	var scrap_before := int(game_state.get("scrap"))
	primary.pressed.emit()
	# 돌파 성공 연출 — 카드 위 글리치 펄스(GlitchPulseFx, 0.3s 복원형) + 골드 플래시. 카드는 남아야 한다.
	await _sleep(0.08)
	var enhance_card := layer.find_child("WorkbenchEnhanceCard", true, false) as Control
	_check(enhance_card != null and enhance_card.get_node_or_null("GlitchPulseFx") != null, "돌파 직후 카드에 글리치 펄스 오버레이")
	_check(enhance_card != null and enhance_card.get_node_or_null("GoldFlash") != null, "돌파 직후 카드에 골드 플래시")
	await _capture("workbench_board_breakthrough_glitch")
	await _sleep(0.4)
	_check(enhance_card != null and is_instance_valid(enhance_card) and enhance_card.is_visible_in_tree() and enhance_card.get_node_or_null("GlitchPulseFx") == null, "0.3s 뒤 오버레이 제거 · 카드는 그대로 남음")
	_check(int(game_state.call("get_breakthrough_level_done", "weapon", "ak47")) == 30, "try_breakthrough 성공 → 돌파 기록 +30")
	_check(int(game_state.get("scrap")) == scrap_before - int(gate_cost.get("scrap", 0)), "고철 ×3 소모 (%d → %d)" % [scrap_before, int(game_state.get("scrap"))])
	_check(int(game_state.call("get_progression_item_count", "artisan_seal")) == seals_before, "인장은 소모되지 않음(고철 단독)")
	_check(primary.text.begins_with("강화 +1"), "돌파 뒤 주 버튼 복귀 '강화 +1' (실제: %s)" % primary.text)
	_check(toast != null and toast.text.contains("돌파 성공"), "토스트: 돌파 성공 (실제: %s)" % (toast.text if toast else ""))

	# 미제작 장비(K2 조각 1/3) 선택 → 제작 안내 카드
	print("[5] 미제작 장비 카드")
	var k2_row := layer.find_child("WorkbenchGearRow_k2", true, false) as Button
	if k2_row == null:
		var box := workbench.get("gear_list_box") as Node
		var box_children: PackedStringArray = []
		if box != null:
			for child in box.get_children():
				box_children.append("%s(%s, inside=%s, queued=%s)" % [child.name, child.get_class(), str(child.is_inside_tree()), str(child.is_queued_for_deletion())])
		print("  gear_list_box=%s inside=%s parent=%s children=%s" % [str(box), str(box.is_inside_tree()) if box else "-", str(box.get_parent()) if box else "-", ", ".join(box_children)])
		var found_list := layer.find_child("WorkbenchGearList", true, false)
		print("  same_list=%s entries=%d" % [str(found_list == box), (workbench.call("_gear_entries") as Array).size()])
		var row_names: PackedStringArray = []
		for node in layer.find_children("WorkbenchGearRow_*", "", true, false):
			row_names.append("%s(%s)" % [node.name, node.get_class()])
		print("  gear rows now: %s | list=%s" % [", ".join(row_names), str(layer.find_child("WorkbenchGearList", true, false))])
	_check(k2_row != null, "K2 잠김 행 존재")
	if k2_row == null:
		quit(1)
		return
	k2_row.pressed.emit()
	await _sleep(0.3)
	_check(str(workbench.get("enhance_selected_id")) == "k2", "K2 선택")
	var guide := layer.find_child("WorkbenchCraftGuide", true, false) as Label
	_check(guide != null and guide.text.contains("남산") and guide.text.contains("이어받아"), "출처 + 이관 예고 문장 (실제: %s)" % (guide.text if guide else ""))
	_check(primary.text.contains("조각 2개 더"), "[제작 · 조각 2개 더] (실제: %s)" % primary.text)
	_check(primary.disabled, "조각 부족 → 제작 비활성")
	await _capture("workbench_board_locked")

	# 방어구 선택 — 피해 감소 현재▲다음
	var vest_row := layer.find_child("WorkbenchGearRow_riot_vest", true, false) as Button
	if vest_row == null:
		var names: PackedStringArray = []
		for node in layer.find_children("WorkbenchGearRow_*", "Button", true, false):
			names.append(node.name)
		print("  gear rows now: %s" % ", ".join(names))
	_check(vest_row != null, "진압 조끼 행 존재")
	if vest_row != null:
		vest_row.pressed.emit()
	await _sleep(0.2)
	var stats := layer.find_child("WorkbenchEnhanceStats", true, false) as GridContainer
	var stat_text := ""
	if stats != null:
		for label in stats.find_children("*", "Label", true, false):
			stat_text += (label as Label).text + " "
	_check(stat_text.contains("피해 감소") and stat_text.contains("▲"), "방어구 스탯 4칸(피해 감소 ▲다음) (실제: %s)" % stat_text.strip_edges())

	# 제작 탭 — 장비 16종 + 하단 '보급품' 3종(수리·자동 수리·확장). 개조(mods)는 UI에서 폐지.
	print("[6] 제작 탭")
	(layer.find_child("WorkbenchTab_craft", true, false) as Button).pressed.emit()
	await _sleep(0.5)
	layer = root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	var recipe_rows := layer.find_children("WorkbenchRecipeRow_*", "Button", true, false)
	_check(recipe_rows.size() == 19, "제작 탭 19행(장비 16 + 보급품 3) (실제: %d)" % recipe_rows.size())
	var ak_row := layer.find_child("WorkbenchRecipeRow_ak47", true, false) as Button
	_check(ak_row != null and ak_row.text.contains("제작됨 · 영구 보유"), "보유 장비 '제작됨 · 영구 보유'")
	var k2_recipe_row := layer.find_child("WorkbenchRecipeRow_k2", true, false) as Button
	_check(k2_recipe_row != null and k2_recipe_row.text.contains("1/3"), "미보유 '조각 1/3' (실제: %s)" % (k2_recipe_row.text if k2_recipe_row else ""))
	_check(layer.find_child("WorkbenchCraftButton", true, false) != null, "제작 버튼(WorkbenchCraftButton) 존재")
	_check(layer.find_child("WorkbenchResourceStrip", true, false) != null, "재료 띠 존재")
	_check(layer.find_child("WorkbenchSupplySection", true, false) != null, "하단 '보급품' 섹션 라벨")
	_check(layer.find_child("WorkbenchRecipeRow_workbench_upgrade", true, false) != null, "보급품 섹션에 작업대 확장 행")
	# 개조(mods) 레시피는 어떤 탭에도 안 나온다(폐지 · 별도 재설계 예정).
	_check(layer.find_child("WorkbenchRecipeRow_scope_2x", true, false) == null, "개조품 행 없음(mods 폐지)")
	_log_modal_rect("landscape-craft")
	await _capture("workbench_board_craft_tab")

	# ② 세로 720x1280
	print("[7] 세로 720x1280")
	(layer.find_child("WorkbenchTab_enhance", true, false) as Button).pressed.emit()
	await _sleep(0.3)
	await _resize(Vector2i(720, 1280))
	shelter.call("_apply_shelter_safe_layout")
	workbench.call("_rebuild_ui")
	await _sleep(0.7)
	layer = root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	var gear_list := layer.find_child("WorkbenchGearList", true, false) as BoxContainer
	_check(gear_list is HBoxContainer, "세로: 목록이 가로 칩 스크롤")
	var actions := layer.find_child("WorkbenchEnhanceActions", true, false) as Control
	var card_scroll := layer.find_child("WorkbenchEnhanceScroll", true, false) as ScrollContainer
	_check(actions != null and card_scroll != null and actions.get_global_rect().position.y >= card_scroll.get_global_rect().end.y - 1.0, "세로: 액션 바가 스크롤 밖 하단 고정")
	primary = layer.find_child("WorkbenchEnhanceButton", true, false) as Button
	_check(primary != null and primary.size.y >= 44.0, "세로: 버튼 높이 ≥44 (%.0f)" % (primary.size.y if primary else 0.0))
	_log_modal_rect("portrait-720x1280")
	await _capture("workbench_board_enhance_portrait")

	# 가로 1555x720
	print("[8] 가로 1555x720")
	await _resize(Vector2i(1555, 720))
	shelter.call("_apply_shelter_safe_layout")
	workbench.call("_rebuild_ui")
	await _sleep(0.6)
	_log_modal_rect("landscape-1555x720")
	await _resize(Vector2i(1280, 720))
	await _wait(3)

	var final_layer := root.find_child("WorkbenchUILayer", true, false)
	if final_layer != null:
		final_layer.queue_free()
	shelter.queue_free()
	await _wait(2)
	print("workbench_board_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _press_at(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	# 루트 뷰포트에 직접 밀어 넣는다 — 헤드리스에서도 GUI 경로(버튼 button_down/up)를 탄다.
	root.push_input(event, true)


func _resize(size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		root.size = size
	else:
		DisplayServer.window_set_size(size)
		root.size = size
	await process_frame
	await process_frame


func _log_modal_rect(label: String) -> void:
	var layer := root.find_child("WorkbenchUILayer", true, false)
	var panel := layer.find_child("WorkbenchPanel", true, false) as Control if layer else null
	var viewport_size := root.get_visible_rect().size
	var rect := panel.get_global_rect() if panel else Rect2()
	print("  [%s] viewport=%s modal=%s" % [label, viewport_size, rect])
	_check(panel != null and Rect2(Vector2.ZERO, viewport_size).grow(1.0).encloses(rect), "%s 모달이 화면 안" % label)


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
