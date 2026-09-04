class_name CharacterNaming
extends CanvasLayer

# 캐릭터 이름 짓기(2026-09-03 유저: "오프닝 끝나고 쉘터로 내려갈 때 암전된 뒤
# 캐릭터 이미지와 함께 닉네임을 적는 플로우. 토스 같은 앱이 떠오르게. 첫인상이라
# 가장 중요").
#
# 한 화면에 질문 하나. 큰 글씨, 밑줄 입력창, 하단 큰 버튼. 장식은 없다.
# 흐름: 암전 → 초상화가 떠오른다 → 질문·입력창·버튼이 차례로 올라온다 →
# 이름 확정 → 이름만 크게 남는 확인 화면 → 다시 암전 → finished(name).
#
# 쓰는 쪽: var naming := CharacterNaming.run(host); var name = await naming.finished

signal finished(chosen_name: String)

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const PORTRAIT_TEXTURE := preload("res://assets/characters/cat_8way/down_idle_0.png")
const LAYER := 250
const MAX_LENGTH := 8
const SUGGESTIONS := ["먼지", "재", "그을음", "안개"]
const BACKGROUND := Color(0.016, 0.02, 0.024, 1.0)
const TEXT := Color("#eef2ee")
const TEXT_DIM := Color("#8d9a94")
const ACCENT := Color("#5fd3b8")
const DANGER := Color("#e06c5c")
const INPUT_LINE := Color("#3a4744")

var root: Control
var column: VBoxContainer
var portrait_frame: PanelContainer
var title_label: Label
var subtitle_label: Label
var input_row: Control
var name_input: LineEdit
var counter_label: Label
var helper_label: Label
var chips_row: HBoxContainer
var confirm_button: Button
var confirm_label: Label
var confirmed := false
var bold_font: FontVariation


static func run(host: Node) -> CanvasLayer:
	# class_name 전역 캐시가 없는 헤드리스 실행에서도 돌게 스크립트를 직접 연다.
	var naming_script: GDScript = load("res://scripts/character_naming.gd")
	var naming: CanvasLayer = naming_script.new()
	naming.name = "CharacterNaming"
	naming.layer = LAYER
	host.add_child(naming)
	naming._build()
	naming._enter()
	return naming


func _build() -> void:
	bold_font = FontVariation.new()
	bold_font.base_font = FONT
	bold_font.variation_embolden = 0.75

	root = Control.new()
	root.name = "NamingRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var margin := MarginContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var column_width := clampf(viewport_size.x - 56.0, 280.0, 440.0)
	margin.custom_minimum_size = Vector2(column_width, minf(viewport_size.y - 40.0, 560.0))
	center.add_child(margin)
	column = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	# 초상화 — 둥근 사각 안에 상반신만.
	var portrait_holder := CenterContainer.new()
	column.add_child(portrait_holder)
	portrait_frame = PanelContainer.new()
	portrait_frame.name = "Portrait"
	portrait_frame.clip_contents = true
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.08, 0.085, 1.0)
	frame_style.set_corner_radius_all(44)
	frame_style.border_color = Color(ACCENT, 0.35)
	frame_style.set_border_width_all(2)
	frame_style.shadow_color = Color(ACCENT, 0.16)
	frame_style.shadow_size = 28
	frame_style.content_margin_left = 0.0
	frame_style.content_margin_right = 0.0
	frame_style.content_margin_top = 0.0
	frame_style.content_margin_bottom = 0.0
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	var frame_size := 128.0
	portrait_frame.custom_minimum_size = Vector2(frame_size, frame_size)
	portrait_holder.add_child(portrait_frame)
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(frame_size, frame_size)
	portrait_frame.add_child(clip)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := PORTRAIT_TEXTURE.get_size()
	var zoom := 1.7
	var drawn := texture_size * (frame_size * zoom / maxf(1.0, texture_size.x))
	portrait.size = drawn
	portrait.position = Vector2((frame_size - drawn.x) * 0.5, frame_size * 0.1 - drawn.y * 0.08)
	clip.add_child(portrait)

	_spacer(16)
	var eyebrow := _make_label("생존자 등록", 12, ACCENT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_constant_override("line_spacing", 0)
	column.add_child(eyebrow)
	_spacer(8)
	title_label = _make_label("어떤 이름으로\n불러 드릴까요?", 30, TEXT, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	_spacer(8)
	subtitle_label = _make_label("쉘터 사람들이 이 이름으로 부릅니다.\n나중에 바꿀 수 없어요.", 14, TEXT_DIM)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle_label)
	_spacer(22)

	# 입력창 — 밑줄 하나. 오른쪽에 글자 수.
	input_row = Control.new()
	input_row.custom_minimum_size = Vector2(0, 54)
	column.add_child(input_row)
	name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "먼지"
	name_input.max_length = MAX_LENGTH
	name_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_input.offset_right = -56.0
	name_input.add_theme_font_override("font", bold_font)
	name_input.add_theme_font_size_override("font_size", 28)
	name_input.add_theme_color_override("font_color", TEXT)
	name_input.add_theme_color_override("font_placeholder_color", Color(TEXT_DIM, 0.5))
	name_input.add_theme_color_override("caret_color", ACCENT)
	name_input.add_theme_color_override("selection_color", Color(ACCENT, 0.3))
	name_input.caret_blink = true
	name_input.context_menu_enabled = false
	name_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0, 0, 0, 0)
	input_style.border_color = INPUT_LINE
	input_style.border_width_bottom = 2
	input_style.content_margin_left = 2.0
	input_style.content_margin_bottom = 8.0
	input_style.content_margin_top = 6.0
	name_input.add_theme_stylebox_override("normal", input_style)
	var focus_style := input_style.duplicate() as StyleBoxFlat
	focus_style.border_color = ACCENT
	name_input.add_theme_stylebox_override("focus", focus_style)
	name_input.add_theme_stylebox_override("read_only", input_style)
	name_input.text_changed.connect(_on_text_changed)
	name_input.text_submitted.connect(func(_text: String) -> void: _confirm())
	input_row.add_child(name_input)
	counter_label = _make_label("0/%d" % MAX_LENGTH, 13, TEXT_DIM)
	counter_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	counter_label.offset_left = -50.0
	counter_label.offset_right = 0.0
	counter_label.offset_top = -10.0
	counter_label.offset_bottom = 10.0
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_row.add_child(counter_label)
	_spacer(8)
	helper_label = _make_label("한글, 영문, 숫자 1~8자", 13, TEXT_DIM)
	column.add_child(helper_label)
	_spacer(14)

	# 추천 이름 — 손가락 하나로 끝낼 수 있게.
	chips_row = HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 8)
	column.add_child(chips_row)
	for suggestion in SUGGESTIONS:
		var chip := Button.new()
		chip.text = str(suggestion)
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 34)
		chip.add_theme_font_override("font", FONT)
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color", TEXT)
		chip.add_theme_color_override("font_hover_color", TEXT)
		chip.add_theme_color_override("font_pressed_color", TEXT)
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = Color(0.09, 0.115, 0.12, 1.0)
		chip_style.set_corner_radius_all(17)
		chip_style.content_margin_left = 14.0
		chip_style.content_margin_right = 14.0
		chip.add_theme_stylebox_override("normal", chip_style)
		var chip_hover := chip_style.duplicate() as StyleBoxFlat
		chip_hover.bg_color = Color(0.13, 0.17, 0.175, 1.0)
		chip.add_theme_stylebox_override("hover", chip_hover)
		chip.add_theme_stylebox_override("pressed", chip_hover)
		chip.add_theme_stylebox_override("focus", chip_style)
		chip.pressed.connect(func() -> void:
			name_input.text = str(suggestion)
			name_input.caret_column = name_input.text.length()
			_on_text_changed(name_input.text)
			name_input.grab_focus()
		)
		chips_row.add_child(chip)

	var expander := Control.new()
	expander.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(expander)

	# 하단 큰 버튼.
	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "이 이름으로 시작하기"
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.add_theme_font_override("font", bold_font)
	confirm_button.add_theme_font_size_override("font_size", 17)
	confirm_button.add_theme_color_override("font_color", Color(0.03, 0.05, 0.05, 1.0))
	confirm_button.add_theme_color_override("font_hover_color", Color(0.03, 0.05, 0.05, 1.0))
	confirm_button.add_theme_color_override("font_pressed_color", Color(0.03, 0.05, 0.05, 1.0))
	confirm_button.add_theme_color_override("font_disabled_color", Color(0.03, 0.05, 0.05, 0.7))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = ACCENT
	button_style.set_corner_radius_all(14)
	confirm_button.add_theme_stylebox_override("normal", button_style)
	var button_hover := button_style.duplicate() as StyleBoxFlat
	button_hover.bg_color = ACCENT.lightened(0.08)
	confirm_button.add_theme_stylebox_override("hover", button_hover)
	var button_pressed := button_style.duplicate() as StyleBoxFlat
	button_pressed.bg_color = ACCENT.darkened(0.12)
	confirm_button.add_theme_stylebox_override("pressed", button_pressed)
	var button_disabled := button_style.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Color(ACCENT, 0.28)
	confirm_button.add_theme_stylebox_override("disabled", button_disabled)
	confirm_button.add_theme_stylebox_override("focus", button_style)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_confirm)
	column.add_child(confirm_button)
	_spacer(10)


func _spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	column.add_child(spacer)


func _make_label(text: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", bold_font if bold else FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _enter() -> void:
	# 초상화가 먼저, 글·입력창·버튼이 짧은 간격으로 겹쳐 올라온다. 하나씩 차례로
	# 켜면 3초가 걸려 '화면'이 아니라 '로딩'으로 읽힌다 — 전체 1.3초 안에 끝낸다.
	var staged: Array[Control] = [title_label, subtitle_label, input_row, helper_label, chips_row, confirm_button]
	for control in staged:
		control.modulate.a = 0.0
	portrait_frame.modulate.a = 0.0
	portrait_frame.pivot_offset = portrait_frame.custom_minimum_size * 0.5
	portrait_frame.scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(portrait_frame, "modulate:a", 1.0, 0.4).set_delay(0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(portrait_frame, "scale", Vector2.ONE, 0.5).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := 0.55
	for control in staged:
		var target: Control = control
		tween.tween_property(target, "modulate:a", 1.0, 0.26).set_delay(delay).set_trans(Tween.TRANS_SINE)
		delay += 0.07
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(name_input):
			name_input.grab_focus()
	)


func _on_text_changed(text: String) -> void:
	var trimmed := text.strip_edges()
	counter_label.text = "%d/%d" % [text.length(), MAX_LENGTH]
	var valid := is_valid_name(trimmed)
	confirm_button.disabled = not valid
	if trimmed.is_empty():
		helper_label.text = "한글, 영문, 숫자 1~8자"
		helper_label.add_theme_color_override("font_color", TEXT_DIM)
	elif not valid:
		helper_label.text = "한글, 영문, 숫자만 쓸 수 있어요"
		helper_label.add_theme_color_override("font_color", DANGER)
	else:
		helper_label.text = "%s. 좋은 이름이에요." % trimmed
		helper_label.add_theme_color_override("font_color", ACCENT)


static func is_valid_name(candidate: String) -> bool:
	if candidate.is_empty() or candidate.length() > MAX_LENGTH:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[가-힣A-Za-z0-9]+$")
	return pattern.search(candidate) != null


func _confirm() -> void:
	if confirmed:
		return
	var chosen := name_input.text.strip_edges()
	if not is_valid_name(chosen):
		return
	confirmed = true
	name_input.editable = false
	confirm_button.disabled = true
	# 자동로드를 직접 부르지 않는다 — 테스트가 이 스크립트를 먼저 preload하면
	# GameState 식별자가 아직 없어 컴파일이 깨진다.
	var game_state := get_tree().root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("set_player_name", chosen)
	# 확인 화면 — 이름만 남긴다. 화면이 잠깐 조용해지는 게 이 순간의 무게다.
	var fade_out := create_tween()
	for control in [title_label, subtitle_label, input_row, helper_label, chips_row, confirm_button]:
		fade_out.parallel().tween_property(control, "modulate:a", 0.0, 0.22)
	fade_out.chain().tween_callback(func() -> void:
		for control in [title_label, subtitle_label, input_row, helper_label, chips_row, confirm_button]:
			control.visible = false
		_show_confirmation(chosen)
	)


func _show_confirmation(chosen: String) -> void:
	_spacer(26)
	confirm_label = _make_label(chosen, 40, TEXT, true)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.modulate.a = 0.0
	column.add_child(confirm_label)
	column.move_child(confirm_label, 3)
	var line := _make_label("다리 끝의 문이 열립니다.", 15, TEXT_DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.modulate.a = 0.0
	column.add_child(line)
	column.move_child(line, 4)
	var tween := create_tween()
	tween.tween_property(confirm_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.25)
	tween.tween_property(line, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.25)
	tween.tween_property(root, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		finished.emit(chosen)
		queue_free()
	)
