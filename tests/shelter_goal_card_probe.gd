extends SceneTree

# 쉘터 UI 신고 2건 프로브 — 헤드리스.
#   godot --headless --path . --script res://tests/shelter_goal_card_probe.gd
#
# ① 다음 목표 카드: 행 수 = 요구 수, 진행 바 값, 헤더/보상 캡션, 확장 버튼 중복 제거
# ② 전부 충족: 헤더 "지금 확장 가능!", 보더 금색
# ③ 운영 독: 미해금 버튼 visible=false, 해금 refresh 후 visible=true + 팝 연출
# ④ 세로 탭바: 보이는 버튼 수만큼 칸을 나눈다(고정 6칸 가정 금지)
# ⑤ 액티브 튜토리얼: 해금 전 dock 스텝이 숨은 버튼을 가리키지 않는다
# ⑥ 카드 탭 = 확장(원탭 방지 무장 → 두 번째 탭 실행). 확장은 씬을 리로드하므로 맨 끝.

const DOCK_FACILITIES := [
	"scratcher_bank", "catnip_scraper", "workbench", "training", "storage", "recruit",
]

var failures := 0
var shelter: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 12000)
	game_state.set("churu", 0)
	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _idle(8)

	# ① 카드 구조
	var requisition := load("res://scripts/shelter/requisition.gd")
	var card := shelter.get("shelter_goal_card") as PanelContainer
	_check(is_instance_valid(card), "① 목표 카드 존재")
	var rows_box := shelter.get("shelter_goal_rows_box") as VBoxContainer
	var goal: Dictionary = requisition.get_next_goal()
	var requirement_count := (goal.get("requirements", []) as Array).size()
	_check(rows_box.get_child_count() == requirement_count,
		"① 행 수 = 요구 수 (%d/%d)" % [rows_box.get_child_count(), requirement_count])
	var title := shelter.get("shelter_goal_title_label") as Label
	var reward := shelter.get("shelter_goal_reward_label") as Label
	print("  ① TITLE=%s / REWARD=%s" % [title.text, reward.text])
	_check(title.text == "다음 목표 — Tier 2 확장", "① 헤더 제목")
	_check(reward.text == "남대문 폐시장 해금", "① 보상 캡션")
	# 예전 확장 버튼 줄("Tier 2 확장 → …해금")은 카드 헤더에 흡수돼 사라졌다.
	_check(shelter.get("shelter_upgrade_button") == null, "① 중복 확장 버튼 줄 제거")
	await _idle(30)
	var scrap_row := rows_box.get_node_or_null("GoalReq_scrap")
	var churu_row := rows_box.get_node_or_null("GoalReq_churu")
	_check(scrap_row != null and churu_row != null, "① 요구마다 한 행")
	var scrap_bar := scrap_row.get_node("GoalReqBar") as ProgressBar
	var churu_bar := churu_row.get_node("GoalReqBar") as ProgressBar
	print("  ① SCRAP=%s %.1f%% / CHURU=%s %.1f%%" % [
		(scrap_row.find_child("GoalReqValue", true, false) as Label).text, scrap_bar.value,
		(churu_row.find_child("GoalReqValue", true, false) as Label).text, churu_bar.value,
	])
	_check((scrap_row.find_child("GoalReqValue", true, false) as Label).text == "12K/30K", "① 고철 수치")
	_check(absf(scrap_bar.value - 40.0) < 1.5, "① 고철 12K/30K → 진행 바 40%")
	_check(churu_bar.value <= 0.5, "① 츄르 0/1 → 0%")
	# 획득 경로 힌트 줄은 삭제됐다(유저: 굳이 없어도 된다) — 행은 이름·수치·바만.
	_check(scrap_row.get_node_or_null("GoalReqHint") == null, "① 힌트 캡션 줄 없음")

	# 값이 오르면 바가 따라 흐르고, 충족되는 순간 ✓가 뜬다
	game_state.set("scrap", 30000)
	shelter.call("_update_stats")
	# 진행 바는 0.3s 시간 기반 트윈 — 헤드리스 프레임은 실시간보다 빨라
	# 프레임 수 대기로는 트윈이 안 끝난다. 실시간으로 기다린다.
	await create_timer(0.5).timeout
	_check(absf(scrap_bar.value - 100.0) < 1.5, "① 충족 후 바가 가득 (%.1f)" % scrap_bar.value)
	_check((scrap_row.find_child("GoalReqCheck", true, false) as Label).modulate.a > 0.5, "① 충족 행에 ✓ 표시")

	# ② 전부 충족 → 금색
	game_state.set("churu", 1)
	shelter.call("_update_stats")
	await _idle(4)
	_check(title.text == "지금 확장 가능!", "② 헤더 문구 (got %s)" % title.text)
	_check(bool(shelter.get("shelter_goal_all_met")), "② all_met 플래그")
	var card_style := shelter.get("shelter_goal_card_style") as StyleBoxFlat
	print("  ② BORDER=%s width=%d" % [card_style.border_color.to_html(), card_style.border_width_top])
	_check(card_style.border_color.r > 0.6 and card_style.border_color.b < card_style.border_color.r,
		"② 보더 금색")
	_check(card_style.border_width_top == 2, "② 충족 시 보더 두께 2")
	shelter.queue_free()
	shelter = null
	await _idle(4)

	# ③ 운영 독 — 잠긴 시설은 아예 없다
	game_state.call("reset_run")
	game_state.set("shelter_tier", 1)
	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _idle(8)
	# 씬 ready가 진행 마일스톤을 동기화하므로, 잠금 상태는 그 뒤에 못 박는다.
	_set_unlocks(game_state, ["scratcher_bank", "storage"])
	var console = shelter.get("ops_console")
	console.call("refresh")
	await _idle(2)
	var buttons := console.get("facility_buttons") as Dictionary
	print("  ③ VISIBLE=%s" % str(_visible_ids(buttons)))
	_check(_visible_ids(buttons) == ["scratcher_bank", "storage"],
		"③ 해금된 2개만 보인다 (got %s)" % str(_visible_ids(buttons)))
	var fever_card := console.get("fever_card") as PanelContainer
	_check(not fever_card.visible, "③ 스크래핑 미해금 → 캣닢 피버 카드 숨김")
	# 해금되는 순간에만 팝으로 등장한다(refresh가 이전 가시성과 비교).
	game_state.call("unlock_shelter_facility", "training")
	console.call("refresh")
	var training_button := buttons["training"] as Button
	_check(training_button.visible, "③ 해금 refresh 후 visible=true")
	_check(training_button.modulate.a < 0.99 and training_button.scale.x < 0.99,
		"③ 팝 등장 연출 시작 (a=%.2f scale=%.2f)" % [training_button.modulate.a, training_button.scale.x])
	# pop_in(0.2s)도 시간 기반 트윈 — 실시간 대기.
	await create_timer(0.45).timeout
	_check(training_button.modulate.a > 0.98 and absf(training_button.scale.x - 1.0) < 0.02,
		"③ 팝이 끝나면 원래 크기·불투명")
	console.call("refresh")
	_check(training_button.modulate.a > 0.98, "③ 재갱신으로는 다시 튀지 않는다")

	# ④ 세로 탭바 — 보이는 버튼 수로 칸을 나눈다
	console.set("force_touch_layout", true)
	await _resize(Vector2i(720, 1280))
	shelter.call("_apply_shelter_safe_layout")
	await _idle(3)
	var visible_count := _visible_ids(buttons).size()
	var slot_width := float(console.get("tab_slot_width"))
	var expected := (720.0 - 20.0 - 6.0 * float(visible_count - 1)) / float(visible_count)
	print("  ④ VISIBLE=%d SLOT=%.1f EXPECTED=%.1f" % [visible_count, slot_width, expected])
	_check(visible_count == 3, "④ 해금 3개(생산·창고·훈련)")
	_check(absf(slot_width - expected) < 1.0, "④ 탭 폭 = 보이는 버튼 수 기준")
	_check(not bool(console.get("rail_layout")), "④ 세로에서는 탭바 레이아웃")

	# ⑤ 튜토리얼 dock 타깃이 숨은 버튼을 가리키지 않는다
	var tutorial = shelter.get("active_tutorial")
	if tutorial != null:
		_check(tutorial.call("_resolve_target", "dock:workbench") == null,
			"⑤ 미해금 작업대는 튜토리얼 타깃이 안 된다")
		_check(tutorial.call("_resolve_target", "dock:scratcher_bank") != null,
			"⑤ 해금된 생산은 타깃이 된다")
		_check(tutorial.call("_resolve_target", "fever") == null,
			"⑤ 미해금 피버도 타깃이 안 된다")
		_check(tutorial.call("_resolve_target", "stats:goal") != null,
			"⑤ 목표 카드는 여전히 튜토리얼 타깃(이름 변경 반영)")
	else:
		print("  ⑤ SKIP (active_tutorial 없음)")

	# ⑥ 카드 탭 = 확장. 확장은 씬을 리로드하므로 마지막에 한다.
	await _resize(Vector2i(1280, 720))
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 60000)
	game_state.set("churu", 3)
	shelter.call("_update_stats")
	await _idle(2)
	root.get_tree().current_scene = shelter
	# 새 게임이라 사자 계약 서사가 자동으로 떠 있다(shelter_modal_ui 그룹) —
	# 모달이 열린 동안 카드 탭이 막히는 건 의도된 동작이므로 닫고 진행한다.
	for modal_node in root.get_tree().get_nodes_in_group("shelter_modal_ui"):
		modal_node.remove_from_group("shelter_modal_ui")
		modal_node.queue_free()
	shelter.set("contract_story_open", false)
	await _idle(2)
	_check(not bool(shelter.call("_ui_blocks_player")), "⑥ 서사를 닫으면 차단 해제")
	shelter.call("_activate_shelter_goal_card")
	_check(int(game_state.get("shelter_tier")) == 1, "⑥ 첫 탭은 무장만 — 바로 확장하지 않는다")
	shelter.call("_activate_shelter_goal_card")
	_check(int(game_state.get("shelter_tier")) == 2,
		"⑥ 두 번째 탭 → 확장 실행 (tier=%d)" % int(game_state.get("shelter_tier")))

	if failures > 0:
		push_error("SHELTER_GOAL_CARD_FAIL failures=%d" % failures)
		quit(1)
		return
	print("SHELTER_GOAL_CARD_OK")
	quit(0)


func _visible_ids(buttons: Dictionary) -> Array:
	var ids: Array = []
	for facility_id in buttons:
		if (buttons[facility_id] as Button).visible:
			ids.append(str(facility_id))
	ids.sort()
	return ids


func _set_unlocks(game_state: Node, unlocked: Array) -> void:
	var flags := game_state.get("shelter_facility_unlocks") as Dictionary
	flags["bed"] = true
	for facility_id in DOCK_FACILITIES:
		flags[facility_id] = unlocked.has(facility_id)


func _resize(size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		root.size = size
	else:
		DisplayServer.window_set_size(size)
		root.size = size
	await process_frame
	await process_frame


func _idle(frames: int) -> void:
	for _frame in frames:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
		return
	failures += 1
	push_error("  FAIL %s" % label)
