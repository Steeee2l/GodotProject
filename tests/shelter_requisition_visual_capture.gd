extends SceneTree

# 쉘터 "다음 목표" 카드 + 운영 독 + 출정 브리핑 시각 확인 캡처.
# 창 모드로만 돌린다(--headless 금지).
#   godot --path . --script res://tests/shelter_requisition_visual_capture.gd
#
# 뽑는 컷:
#   1) 목표 카드 — 미충족(고철 12K/30K · 츄르 0/1), 세로 720x1280
#   2) 목표 카드 — 전부 충족(골드 보더 · "지금 확장 가능!"), 세로
#   3) 운영 독 — 생산·창고 2개만 해금(잠긴 버튼이 아예 없다), 가로
#   4) 출정 브리핑 — 칩 행 재디자인, 가로
#   5) 출정 브리핑 — 같은 구조가 세로에서 랩핑되는지

const OUTPUT_DIR := "res://test-output"
const DOCK_FACILITIES := [
	"scratcher_bank", "catnip_scraper", "workbench", "training", "storage",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")

	# 1) 목표 카드 — 미충족(세로)
	await _resize(Vector2i(720, 1280))
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 12000)
	game_state.set("churu", 0)
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _idle(10)
	shelter.call("_update_stats")
	await _idle(30)
	_print_card(shelter, "PENDING")
	await _capture("shelter_goal_card_pending_portrait")

	# 2) 목표 카드 — 전부 충족(골드)
	game_state.set("scrap", 30000)
	game_state.set("churu", 1)
	shelter.call("_update_stats")
	await _idle(30)
	_print_card(shelter, "ALL_MET")
	await _capture("shelter_goal_card_all_met_portrait")

	# 4) 브리핑(세로) — 칩 랩핑 확인. 지도 모달은 열 때 방향을 보고 구성된다.
	shelter.call("_open_raid_zone_select")
	await _idle(8)
	shelter.call("_select_raid_zone_preview", "jongno_outskirts")
	await _idle(6)
	_print_briefing()
	await _capture("raid_briefing_portrait")
	shelter.call("_close_raid_zone_select")
	await _idle(4)
	shelter.queue_free()
	await _idle(4)

	# 3) 운영 독 — 생산·창고만 해금(가로)
	await _resize(Vector2i(1280, 720))
	game_state.call("reset_run")
	game_state.set("shelter_tier", 1)
	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _idle(10)
	var flags := game_state.get("shelter_facility_unlocks") as Dictionary
	flags["bed"] = true
	for facility_id in DOCK_FACILITIES:
		flags[facility_id] = facility_id in ["scratcher_bank", "storage"]
	shelter.call("_update_stats")
	shelter.call("_apply_shelter_safe_layout")
	await _idle(8)
	var console = shelter.get("ops_console")
	var buttons := console.get("facility_buttons") as Dictionary
	var visible_ids: Array = []
	for facility_id in buttons:
		if (buttons[facility_id] as Button).visible:
			visible_ids.append(str(facility_id))
	visible_ids.sort()
	print("DOCK_VISIBLE=%s FEVER=%s" % [
		str(visible_ids), str((console.get("fever_card") as Control).visible),
	])
	await _capture("shelter_ops_dock_two_unlocked")

	# 5) 브리핑(가로)
	game_state.call("unlock_all_shelter_facilities")
	shelter.call("_open_raid_zone_select")
	await _idle(8)
	shelter.call("_select_raid_zone_preview", "namdaemun_market")
	await _idle(6)
	_print_briefing()
	await _capture("raid_briefing_landscape")
	shelter.queue_free()
	await _idle(2)
	quit(0)


func _print_card(shelter: Node, label: String) -> void:
	var title := shelter.get("shelter_goal_title_label") as Label
	var reward := shelter.get("shelter_goal_reward_label") as Label
	var rows := shelter.get("shelter_goal_rows_box") as VBoxContainer
	var pieces: Array[String] = []
	for row in rows.get_children():
		# 이름·수치 라벨은 행 VBox 안의 HBox에 산다 — 재귀 탐색으로 집는다.
		var value := row.find_child("GoalReqValue", true, false) as Label
		var name_label := row.find_child("GoalReqName", true, false) as Label
		var bar := row.get_node_or_null("GoalReqBar") as ProgressBar
		pieces.append("%s %s (%.0f%%)" % [
			name_label.text if name_label != null else "?",
			value.text if value != null else "?",
			bar.value,
		])
	print("CARD[%s] %s | %s | %s" % [label, title.text, reward.text, " · ".join(pieces)])


func _print_briefing() -> void:
	for container_name in ["RaidZoneLootChips", "RaidZoneLoadoutChips", "RaidZoneGearChips"]:
		var container := root.find_child(container_name, true, false) as Control
		if container == null:
			print("%s=<missing>" % container_name)
			continue
		var texts: Array[String] = []
		for chip in container.get_children():
			var label := _first_label(chip)
			if label != null:
				texts.append(label.text)
		print("%s=%s" % [container_name, " | ".join(texts)])
	var description := root.find_child("RaidZoneBriefingPanel", true, false)
	if description != null:
		print("GOAL_LINE_REMOVED=%s" % str(root.find_child("RaidZoneGoalLine", true, false) == null))


func _first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child as Label
		var nested := _first_label(child)
		if nested != null:
			return nested
	return null


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


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
