extends Node

const SHELTER_SCENE_PATH := "res://scenes/shelter_interior.tscn"
const OPENING_SCENE_PATH := "res://scenes/opening_sequence.tscn"
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var reset_layer: CanvasLayer
var reset_button: Button
var reset_confirmation: Control


func _ready() -> void:
	_build_mobile_reset_ui()


func is_shelter_shortcut(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var key := event.keycode if event.keycode != 0 else event.physical_keycode
	return key == KEY_1


func is_full_reset_shortcut(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var key := event.keycode if event.keycode != 0 else event.physical_keycode
	return key == KEY_0 or key == KEY_KP_0


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if is_full_reset_shortcut(key_event):
		# 키 하나로 확인 없이 세이브를 지우면 안 된다. 모바일 버튼과 같은
		# 확인 다이얼로그를 거친다.
		get_viewport().set_input_as_handled()
		_show_reset_confirmation()
		return
	if not is_shelter_shortcut(key_event):
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == SHELTER_SCENE_PATH:
		return
	get_viewport().set_input_as_handled()
	get_tree().call_deferred("change_scene_to_file", SHELTER_SCENE_PATH)


func _build_mobile_reset_ui() -> void:
	reset_layer = CanvasLayer.new()
	reset_layer.name = "MobileResetLayer"
	reset_layer.layer = 4090
	add_child(reset_layer)

	reset_button = Button.new()
	reset_button.name = "MobileResetButton"
	reset_button.text = "↻  초기화"
	# 좌상단은 쉘터 스탯 패널 자리다. 예전에는 (16,16)에 그대로 얹어서
	# 제목을 덮었다. 비어 있는 상단 중앙으로 옮기고 크기도 줄인다.
	reset_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	reset_button.size = Vector2(96, 38)
	reset_button.position = Vector2(-48, 10)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_override("font", FONT)
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.add_theme_color_override("font_color", Color("#f1d9d5"))
	reset_button.add_theme_color_override("font_hover_color", Color.WHITE)
	reset_button.add_theme_stylebox_override(
		"normal",
		_make_style(Color(0.035, 0.045, 0.047, 0.92), Color(0.69, 0.35, 0.31, 0.9), 2, 6)
	)
	reset_button.add_theme_stylebox_override(
		"hover",
		_make_style(Color(0.11, 0.06, 0.055, 0.96), Color("#e47c6d"), 2, 6)
	)
	reset_button.add_theme_stylebox_override(
		"pressed",
		_make_style(Color(0.18, 0.055, 0.05, 0.98), Color("#ff9b8c"), 2, 6)
	)
	reset_button.pressed.connect(_show_reset_confirmation)
	reset_layer.add_child(reset_button)
	reset_button.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

	reset_confirmation = _create_reset_confirmation()
	reset_layer.add_child(reset_confirmation)


func _create_reset_confirmation() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "ResetConfirmation"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 244)
	panel.add_theme_stylebox_override(
		"panel",
		_make_style(Color(0.018, 0.025, 0.026, 0.98), Color("#bd6257"), 2, 7)
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "처음부터 시작할까요?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f3ded9"))
	column.add_child(title)

	var description := Label.new()
	description.text = "주민, 창고, 재화, 장비와 모든 진행 데이터가 삭제됩니다.\n삭제한 데이터는 되돌릴 수 없습니다."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", FONT)
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color("#b9c5c1"))
	column.add_child(description)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = "취소"
	cancel_button.custom_minimum_size = Vector2(132, 52)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.add_theme_font_override("font", FONT)
	cancel_button.add_theme_font_size_override("font_size", 18)
	cancel_button.add_theme_stylebox_override(
		"normal",
		_make_style(Color("#121a1b"), Color("#526661"), 1, 6)
	)
	cancel_button.pressed.connect(_hide_reset_confirmation)
	actions.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.text = "전체 초기화"
	confirm_button.custom_minimum_size = Vector2(146, 52)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.add_theme_font_override("font", FONT)
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.add_theme_color_override("font_color", Color.WHITE)
	confirm_button.add_theme_stylebox_override(
		"normal",
		_make_style(Color("#9d4038"), Color("#ee8b7d"), 2, 6)
	)
	confirm_button.add_theme_stylebox_override(
		"pressed",
		_make_style(Color("#692822"), Color("#ffab9f"), 2, 6)
	)
	confirm_button.pressed.connect(_perform_full_reset)
	actions.add_child(confirm_button)
	return overlay


func _show_reset_confirmation() -> void:
	if reset_confirmation == null:
		return
	reset_confirmation.visible = true


func _hide_reset_confirmation() -> void:
	if reset_confirmation == null:
		return
	reset_confirmation.visible = false


func _perform_full_reset() -> void:
	if reset_button != null:
		reset_button.disabled = true
	_hide_reset_confirmation()
	GameState.reset_all_progress_for_opening()
	get_tree().call_deferred("change_scene_to_file", OPENING_SCENE_PATH)
	if reset_button != null:
		reset_button.disabled = false


func _make_style(color: Color, border_color: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
