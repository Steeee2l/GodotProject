extends SceneTree

# 이름 짓기 화면 캡처(창 필요 — --headless 금지). 2026-09-03.
#   naming_empty.png   : 처음 뜬 화면(버튼 잠김)
#   naming_typed.png   : 이름 입력 뒤(버튼 열림, 도움말 바뀜)
#   naming_confirm.png : 확정 화면(이름만 크게)
# 실행: godot --path . --script res://tests/naming_visual_capture.gd

const OUTPUT_DIR := "res://test-output"
const NAMING_PATH := "res://scripts/character_naming.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	var host := Node.new()
	root.add_child(host)
	var naming: CanvasLayer = (load(NAMING_PATH) as GDScript).run(host)
	await _wait(2.6)
	await _capture("naming_empty")
	var input := naming.get("name_input") as LineEdit
	input.text = "그을음"
	naming.call("_on_text_changed", input.text)
	await _wait(0.2)
	await _capture("naming_typed")
	(naming.get("confirm_button") as Button).pressed.emit()
	await _wait(1.1)
	await _capture("naming_confirm")
	game_state.set("player_name", "먼지")
	print("NAMING_VISUAL_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	if image.save_png(path) == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
