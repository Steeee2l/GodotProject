extends SceneTree

# 쉘터 "다음 목표" 줄 시각 확인 캡처. 창 모드로만 돌린다(--headless 금지).
#   godot --path . --script res://tests/shelter_requisition_visual_capture.gd
#
# 뽑는 컷:
#   1) 쉘터 스탯 패널 목표 줄 — 미충족(빨강) 상태(Tier 1, 고철 12K, 츄르 0)
#   2) 출정 브리핑의 목표 줄 + 지도 "목표" 칩(Tier 2, 츄르 0/2·키 없음)

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")

	# 1) 스탯 패널 — Tier 1, 고철 12K/30K, 츄르 0/1 → 둘 다 빨강
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 12000)
	game_state.set("churu", 0)
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	for _frame in 8:
		await process_frame
	shelter.call("_set_stats_panel_expanded", true)
	shelter.call("_update_stats")
	for _frame in 4:
		await process_frame
	var goal_row := shelter.get_node_or_null("ShelterHUD/ShelterStatsPanel") as Control
	print("STATS_PANEL=%s" % str(is_instance_valid(goal_row)))
	var pieces: Array[String] = []
	var row: Control = shelter.get("shelter_goal_row")
	if is_instance_valid(row):
		for child in row.get_children():
			pieces.append(str((child as Label).text))
	print("GOAL_ROW_PIECES=%s" % "".join(pieces))
	await _capture("shelter_goal_line_stats_panel")

	# 2) 브리핑 — Tier 2, 고철 150K ✓, 츄르 0/2, 키 없음 → 남대문에 "목표" 칩
	game_state.set("shelter_tier", 2)
	game_state.set("scrap", 150000)
	game_state.set("churu", 0)
	(game_state.get("progression_item_inventory") as Dictionary)["namdaemun_depot_plans"] = 0
	shelter.call("_update_stats")
	shelter.call("_open_raid_zone_select")
	for _frame in 6:
		await process_frame
	shelter.call("_select_raid_zone_preview", "namdaemun_market")
	for _frame in 4:
		await process_frame
	var goal_label := root.find_child("RaidZoneGoalLine", true, false) as Label
	print("BRIEFING_GOAL=%s" % (str(goal_label.text).replace("\n", " | ") if is_instance_valid(goal_label) else "<missing>"))
	var chip := root.find_child("GoalChip", true, false)
	print("GOAL_CHIP=%s" % str(is_instance_valid(chip)))
	await _capture("shelter_goal_line_briefing")
	shelter.queue_free()
	await process_frame
	quit(0)


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
