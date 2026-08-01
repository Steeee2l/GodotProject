extends SceneTree

const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui_safe_area.gd")
	assert(source.contains("if not DisplayServer.is_touchscreen_available():"))
	assert(source.contains("DisplayServer.window_get_current_screen()"))
	assert(source.contains("safe_rect.position - screen_position"))
	assert(source.contains("viewport_size.x * 0.18"))
	print("ui_safe_area_smoke_test: PASS")
	quit()
