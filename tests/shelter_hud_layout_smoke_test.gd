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
	# 상호작용 안내가 대시·구급약 버튼과 겹쳐(감사 2026-08) 터치 레이아웃에서만
	# 버튼 줄 위로 올렸다 — 데스크톱 값(-60.0 - safe.w)은 그대로다.
	assert(source.contains("(-154.0 - safe.w) if DisplayServer.is_touchscreen_available() else (-60.0 - safe.w)"))
	# 상태 토스트는 status_label(맨몸 텍스트)에서 status_panel(패널) 래핑으로 바뀌었다.
	# 고정 y=24가 스탯 패널·행상인 알림과 3중으로 겹쳐서, 상단 스택 아래로 쌓게 바꿨다.
	assert(source.contains("status_panel.offset_top = top_stack_bottom + 10.0"))
	assert(source.contains("interact_button.offset_right = -36.0 - safe.z"))
	assert(source.contains("shelter_medkit_button.offset_left = medkit_left + safe.x"))
	assert(source.contains("panel.custom_minimum_size = Vector2(370, 0)"))
	assert(not source.contains("panel.size = Vector2(370, 220)"))
	print("shelter_hud_layout_smoke_test: PASS")
	quit()
