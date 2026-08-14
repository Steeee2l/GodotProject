extends CanvasLayer

signal settings_changed

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SAVE_PATH := "user://accessibility.cfg"

var ui_scale := 1.0
var combat_text_scale := 1.0
var camera_shake_scale := 0.75
var hit_flash_scale := 0.72
var vignette_scale := 0.7
var minimum_brightness := 0.16
var aim_assist_strength := 0.65
var auto_reload := true
var vibration_enabled := true
var battery_saver := false

var backdrop: ColorRect
var panel: PanelContainer
var panel_center: CenterContainer
var was_tree_paused := false


func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		if key == KEY_F10:
			toggle()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE and is_open():
			close()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open():
		return
	was_tree_paused = get_tree().paused
	backdrop.visible = true
	panel_center.visible = true
	get_tree().paused = true
	_apply_layout()


func close() -> void:
	if not is_open():
		return
	backdrop.visible = false
	panel_center.visible = false
	get_tree().paused = was_tree_paused
	_save_settings()
	_apply_layout()


func is_open() -> bool:
	return is_instance_valid(panel_center) and panel_center.visible


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	add_child(backdrop)
	panel_center = CenterContainer.new()
	panel_center.name = "SettingsCenter"
	panel_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_center.visible = false
	add_child(panel_center)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel_center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	margin.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)
	var icon := TextureRect.new()
	icon.texture = UI_ICONS.get_icon("settings", 36, Color("#d8c47c"))
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("표시 및 조작 설정", 24, Color("#eee5ce")))
	var header_hint := _label("자동 저장 · F10으로 열기", 12, Color("#91a49c"))
	titles.add_child(header_hint)
	var close_button := Button.new()
	close_button.icon = UI_ICONS.get_icon("close", 26, Color("#e8ebe7"))
	close_button.custom_minimum_size = Vector2(52, 46)
	close_button.tooltip_text = "설정 닫기"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	shell.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	_add_slider(content, "UI 크기", "메뉴와 HUD 전체 크기", 0.8, 1.4, 0.05, ui_scale, func(value: float) -> void: ui_scale = value)
	_add_slider(content, "전투 알림 크기", "피해량과 전투 경고 글자", 0.8, 1.4, 0.05, combat_text_scale, func(value: float) -> void: combat_text_scale = value)
	_add_slider(content, "화면 흔들림", "피격·암살·보스 연출", 0.0, 1.0, 0.05, camera_shake_scale, func(value: float) -> void: camera_shake_scale = value)
	_add_slider(content, "피격 번쩍임", "캐릭터와 화면의 순간 섬광", 0.0, 1.0, 0.05, hit_flash_scale, func(value: float) -> void: hit_flash_scale = value)
	_add_slider(content, "화면 가장자리 효과", "피격 시 붉은 비네팅 강도", 0.0, 1.0, 0.05, vignette_scale, func(value: float) -> void: vignette_scale = value)
	_add_slider(content, "최소 밝기", "밤과 실내의 가장 어두운 정도", 0.0, 0.5, 0.05, minimum_brightness, func(value: float) -> void: minimum_brightness = value)
	_add_slider(content, "조준 보정", "모바일과 패드의 원뿔 조준 보정", 0.0, 1.0, 0.05, aim_assist_strength, func(value: float) -> void: aim_assist_strength = value)
	_add_toggle(content, "탄약이 있으면 자동 재장전", auto_reload, func(value: bool) -> void: auto_reload = value)
	_add_toggle(content, "모바일 햅틱", vibration_enabled, func(value: bool) -> void: vibration_enabled = value)
	_add_toggle(content, "모바일 저전력 모드", battery_saver, func(value: bool) -> void: battery_saver = value)
	var footer := _label("색상만으로 상태를 구분하지 않으며 아이콘과 문자를 함께 표시합니다.", 12, Color("#8fa59b"))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)
	# 모바일 우상단 진입 버튼은 화면 정리를 위해 만들지 않는다(F10으로 진입).


func _add_slider(parent: VBoxContainer, title: String, description: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.custom_minimum_size.x = 185
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	text_box.add_child(_label(title, 14, Color("#d8ded9")))
	text_box.add_child(_label(description, 11, Color("#81938c")))
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(190, 34)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(next_value: float) -> void:
		callback.call(next_value)
		settings_changed.emit()
	)
	row.add_child(slider)


func _add_toggle(parent: VBoxContainer, title: String, value: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = value
	toggle.add_theme_font_override("font", FONT)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.toggled.connect(func(enabled: bool) -> void:
		callback.call(enabled)
		settings_changed.emit()
	)
	parent.add_child(toggle)


func _label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	# 예전에는 position을 직접 계산해서, 컨테이너 최소 크기가 요청 크기보다
	# 커지면 패널이 화면 왼쪽 위로 밀려 잘렸다. 배치는 CenterContainer에 맡긴다.
	var panel_size := Vector2(
		clampf(viewport_size.x - safe.x - safe.z - 24.0, 260.0, 620.0),
		clampf(viewport_size.y - safe.y - safe.w - 24.0, 200.0, 700.0)
	)
	panel.custom_minimum_size = panel_size
	panel.size = panel_size


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.034, 0.033, 0.99)
	style.border_color = Color("#758d82")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.68)
	style.shadow_size = 14
	return style


func _save_settings() -> void:
	var config := ConfigFile.new()
	for property_name in ["ui_scale", "combat_text_scale", "camera_shake_scale", "hit_flash_scale", "vignette_scale", "minimum_brightness", "aim_assist_strength", "auto_reload", "vibration_enabled", "battery_saver"]:
		config.set_value("accessibility", property_name, get(property_name))
	config.save(SAVE_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for property_name in ["ui_scale", "combat_text_scale", "camera_shake_scale", "hit_flash_scale", "vignette_scale", "minimum_brightness", "aim_assist_strength", "auto_reload", "vibration_enabled", "battery_saver"]:
		if config.has_section_key("accessibility", property_name):
			set(property_name, config.get_value("accessibility", property_name, get(property_name)))
