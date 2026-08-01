extends SceneTree


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/shelter_interior.gd")
	for legacy_assignment in [
		"prompt_label.position =",
		"status_label.position =",
		"interact_button.position =",
		"dash_button.position =",
		"shelter_medkit_button.position =",
	]:
		assert(not source.contains(legacy_assignment))
	assert(source.contains("prompt_label.offset_bottom = -60.0 - safe.w"))
	assert(source.contains("status_label.offset_top = 24.0 + safe.y"))
	assert(source.contains("interact_button.offset_right = -36.0 - safe.z"))
	assert(source.contains("shelter_medkit_button.offset_left = medkit_left + safe.x"))
	assert(source.contains("panel.custom_minimum_size = Vector2(370, 0)"))
	assert(not source.contains("panel.size = Vector2(370, 220)"))
	print("shelter_hud_layout_smoke_test: PASS")
	quit()
