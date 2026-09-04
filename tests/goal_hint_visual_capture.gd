extends SceneTree

# 목표 카드 안내 캡처(창 필요). 2026-09-03.
#   goal_card_hint.png : 카드 탭 뒤 카드 아래 한 줄 안내 + 하수구 행상인 표식
# 실행: godot --path . --script res://tests/goal_hint_visual_capture.gd

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _wait(1.2)
	var guard := 0
	while bool(shelter.get("contract_story_open")) and guard < 12:
		shelter.call("_advance_contract_story")
		guard += 1
		await _wait(0.15)
	if shelter.has_method("_build_merchant_waiting_marker"):
		shelter.call("_build_merchant_waiting_marker")
	var tutorial = shelter.get("active_tutorial")
	if tutorial != null and tutorial.has_method("_on_goal_tapped"):
		tutorial.call("_on_goal_tapped")
	else:
		shelter.call("_show_goal_card_hint", "고철 · 츄르를 모아 Tier 2로 확장하세요.")
	await _wait(0.5)
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/goal_card_hint.png" % OUTPUT_DIR
	if image.save_png(path) == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	print("GOAL_HINT_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
