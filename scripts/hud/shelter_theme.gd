class_name ShelterTheme
extends RefCounted

# 쉘터 UI 공용 디자인 언어(2026-09-04 유저: "닉네임 생성 화면 디자인이 굉장히 마음에
# 든다. 이 언어로 쉘터 UI 전면 검수"). character_naming.gd의 화면이 기준이다.
#
#   · 바탕은 거의 검정, 판은 한 단계 밝은 무광 표면. 금색 테두리 선은 쓰지 않는다.
#   · 글은 굵은 큰 제목 + 작은 회색 설명. 숫자는 크고 굵게(tabular).
#   · 강조색은 민트 하나(ACCENT). 재화 색은 아이콘에만.
#   · 버튼은 둥근 큰 한 덩어리: 주 버튼 = 민트 채움/어두운 글자, 보조 = 표면색 채움.
#   · 칩은 알약, 입력은 밑줄 하나, 진행 바는 얇고 둥글게.
#   · 여백은 넉넉히. 구분은 선 대신 여백과 표면 단차로.
#
# 쓰는 쪽은 여기 빌더만 조합한다 — 모듈마다 색·반지름을 따로 적지 않는다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const TOUCH_SCROLL := preload("res://scripts/hud/touch_scroll.gd")

# ── 색 ──
const BG := Color("#0b0f12")            # 모달·큰 판 바탕(거의 불투명)
const BG_DIM := Color(0.0, 0.0, 0.0, 0.72)  # 모달 뒤 딤
const SURFACE := Color("#141a1e")       # 카드
const SURFACE_RAISED := Color("#1b2227")  # 카드 안 카드 · 보조 버튼
const SURFACE_HOVER := Color("#222a30")
const HAIRLINE := Color("#243036")      # 아주 옅은 구분선(꼭 필요할 때만)
const TEXT := Color("#eef2ee")
const TEXT_DIM := Color("#8d9a94")
const TEXT_FAINT := Color("#5f6b67")
const ACCENT := Color("#5fd3b8")
const ACCENT_INK := Color("#06120f")    # 민트 위 글자
const ACCENT_SOFT := Color("#5fd3b8", 0.16)
const DANGER := Color("#e06c5c")
const WARN := Color("#e3bd67")
const GOLD := Color("#d8bd72")          # 재화 아이콘·보상에만

# ── 반지름 ──
const RADIUS_MODAL := 20
const RADIUS_CARD := 14
const RADIUS_BUTTON := 14
const RADIUS_PILL := 999

# ── 글자 크기 ──
const TYPE_TITLE := 26
const TYPE_SECTION := 16
const TYPE_BODY := 14
const TYPE_CAPTION := 12
const TYPE_EYEBROW := 12
const TYPE_NUMBER := 24
const TYPE_NUMBER_SMALL := 18

# ── 치수 ──
const BUTTON_HEIGHT := 52.0
const BUTTON_HEIGHT_SMALL := 40.0
const CHIP_HEIGHT := 32.0
const PROGRESS_HEIGHT := 6.0
const MODAL_PADDING := 28.0

static var _bold_font: FontVariation
static var _tabular_font: FontVariation
static var _bold_tabular_font: FontVariation


static func bold() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = FONT
		_bold_font.variation_embolden = 0.75
	return _bold_font


static func tabular() -> FontVariation:
	if _tabular_font == null:
		_tabular_font = FontVariation.new()
		_tabular_font.base_font = FONT
		_tabular_font.opentype_features = {"tnum": 1}
	return _tabular_font


static func bold_tabular() -> FontVariation:
	if _bold_tabular_font == null:
		_bold_tabular_font = FontVariation.new()
		_bold_tabular_font.base_font = FONT
		_bold_tabular_font.variation_embolden = 0.75
		_bold_tabular_font.opentype_features = {"tnum": 1}
	return _bold_tabular_font


# ── 스타일박스 ──


static func flat(background: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	return style


static func modal_style() -> StyleBoxFlat:
	var style := flat(BG, RADIUS_MODAL)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 32
	style.content_margin_left = MODAL_PADDING
	style.content_margin_right = MODAL_PADDING
	style.content_margin_top = MODAL_PADDING - 4.0
	style.content_margin_bottom = MODAL_PADDING - 4.0
	return style


static func card_style(raised := false, accent_border := false) -> StyleBoxFlat:
	var style := flat(SURFACE_RAISED if raised else SURFACE, RADIUS_CARD)
	if accent_border:
		style.border_color = Color(ACCENT, 0.7)
		style.set_border_width_all(2)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


static func pill_style(active := false, accent: Color = ACCENT) -> StyleBoxFlat:
	var style := flat(accent if active else SURFACE_RAISED, RADIUS_PILL)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 7.0
	return style


static func input_style(focused := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = ACCENT if focused else HAIRLINE.lightened(0.15)
	style.border_width_bottom = 2
	style.content_margin_left = 2.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 8.0
	return style


static func progress_styles() -> Dictionary:
	var track := flat(SURFACE_RAISED, 3)
	var fill := flat(ACCENT, 3)
	return {"background": track, "fill": fill}


# ── 텍스트 ──


static func label(text: String, size: int = TYPE_BODY, color: Color = TEXT, is_bold := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", bold() if is_bold else FONT)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func eyebrow(text: String, color: Color = ACCENT) -> Label:
	# 작은 강조 라벨 — "생존자 등록"처럼 화면의 이름표.
	return label(text, TYPE_EYEBROW, color)


static func title(text: String, size: int = TYPE_TITLE) -> Label:
	var node := label(text, size, TEXT, true)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func subtitle(text: String) -> Label:
	var node := label(text, TYPE_BODY, TEXT_DIM)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func number(text: String, size: int = TYPE_NUMBER, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", bold_tabular())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func caption(text: String, color: Color = TEXT_DIM) -> Label:
	return label(text, TYPE_CAPTION, color)


# ── 카드·컨테이너 ──


static func card(raised := false, accent_border := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(raised, accent_border))
	return panel


static func stat_card(caption_text: String, value_text: String, icon: Texture2D = null, accent: Color = TEXT) -> PanelContainer:
	# 작은 설명 + 큰 숫자. 아이콘은 왼쪽에 작게. 값 라벨은 meta "value_label"로 꺼낸다.
	var panel := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_rect)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(caption(caption_text))
	var value := number(value_text, TYPE_NUMBER_SMALL, accent)
	column.add_child(value)
	panel.set_meta("value_label", value)
	return panel


static func section_header(text: String, trailing: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var heading := label(text, TYPE_SECTION, TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	if trailing != null:
		row.add_child(trailing)
	return row


static func spacer(height: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(0, height)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


static func hairline() -> ColorRect:
	var line := ColorRect.new()
	line.color = HAIRLINE
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func scroll() -> ScrollContainer:
	var container := ScrollContainer.new()
	container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var bar := container.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", flat(Color(0, 0, 0, 0), 3))
	bar.add_theme_stylebox_override("grabber", flat(Color(TEXT_FAINT, 0.5), 3))
	bar.add_theme_stylebox_override("grabber_highlight", flat(Color(TEXT_DIM, 0.7), 3))
	bar.add_theme_stylebox_override("grabber_pressed", flat(ACCENT, 3))
	bar.custom_minimum_size = Vector2(6, 0)
	# 손가락 드래그 스크롤은 TouchScroll이 붙인다(HudStyle.make_scroll과 같은 규약).
	return TOUCH_SCROLL.install(container)


# ── 버튼 ──


static func style_primary(button: Button, accent: Color = ACCENT) -> Button:
	button.add_theme_font_override("font", bold())
	button.add_theme_font_size_override("font_size", TYPE_BODY + 1)
	button.add_theme_color_override("font_color", ACCENT_INK)
	button.add_theme_color_override("font_hover_color", ACCENT_INK)
	button.add_theme_color_override("font_pressed_color", ACCENT_INK)
	button.add_theme_color_override("font_focus_color", ACCENT_INK)
	button.add_theme_color_override("font_disabled_color", Color(ACCENT_INK, 0.7))
	button.add_theme_stylebox_override("normal", flat(accent, RADIUS_BUTTON))
	button.add_theme_stylebox_override("hover", flat(accent.lightened(0.08), RADIUS_BUTTON))
	button.add_theme_stylebox_override("pressed", flat(accent.darkened(0.14), RADIUS_BUTTON))
	button.add_theme_stylebox_override("focus", flat(accent, RADIUS_BUTTON))
	button.add_theme_stylebox_override("disabled", flat(Color(accent, 0.28), RADIUS_BUTTON))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	return button


static func style_secondary(button: Button, small := false) -> Button:
	button.add_theme_font_override("font", bold())
	button.add_theme_font_size_override("font_size", TYPE_BODY if not small else TYPE_CAPTION + 1)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	button.add_theme_stylebox_override("normal", flat(SURFACE_RAISED, RADIUS_BUTTON))
	button.add_theme_stylebox_override("hover", flat(SURFACE_HOVER, RADIUS_BUTTON))
	button.add_theme_stylebox_override("pressed", flat(SURFACE, RADIUS_BUTTON))
	button.add_theme_stylebox_override("focus", flat(SURFACE_RAISED, RADIUS_BUTTON))
	button.add_theme_stylebox_override("disabled", flat(Color(SURFACE_RAISED, 0.6), RADIUS_BUTTON))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, BUTTON_HEIGHT_SMALL if small else BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	return button


static func style_ghost(button: Button) -> Button:
	# 배경 없는 글자 버튼(취소·건너뛰기).
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", TYPE_BODY)
	button.add_theme_color_override("font_color", TEXT_DIM)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT_DIM)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, flat(Color(0, 0, 0, 0), RADIUS_BUTTON))
	button.focus_mode = Control.FOCUS_NONE
	return button


static func style_pill(button: Button, active := false, accent: Color = ACCENT) -> Button:
	button.add_theme_font_override("font", bold() if active else FONT)
	button.add_theme_font_size_override("font_size", TYPE_CAPTION + 1)
	var color := ACCENT_INK if active else TEXT
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	button.add_theme_stylebox_override("normal", pill_style(active, accent))
	var hover := pill_style(active, accent)
	hover.bg_color = accent.lightened(0.08) if active else SURFACE_HOVER
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", pill_style(active, accent))
	button.add_theme_stylebox_override("disabled", pill_style(false))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, CHIP_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	return button


static func primary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	return style_primary(button)


static func secondary_button(text: String, small := false) -> Button:
	var button := Button.new()
	button.text = text
	return style_secondary(button, small)


static func close_button() -> Button:
	# 둥근 40px 닫기. 글자 × 하나.
	var button := Button.new()
	button.text = "×"
	button.custom_minimum_size = Vector2(40, 40)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_stylebox_override("normal", flat(SURFACE_RAISED, RADIUS_PILL))
	button.add_theme_stylebox_override("hover", flat(SURFACE_HOVER, RADIUS_PILL))
	button.add_theme_stylebox_override("pressed", flat(SURFACE, RADIUS_PILL))
	button.add_theme_stylebox_override("focus", flat(SURFACE_RAISED, RADIUS_PILL))
	button.focus_mode = Control.FOCUS_NONE
	return button


# ── 진행 바·칩 ──


static func progress(value: float, max_value: float = 1.0, accent: Color = ACCENT) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(0.0001, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, PROGRESS_HEIGHT)
	bar.add_theme_stylebox_override("background", flat(SURFACE_RAISED, 3))
	bar.add_theme_stylebox_override("fill", flat(accent, 3))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func chip(text: String, icon: Texture2D = null, accent: Color = TEXT, active := false) -> PanelContainer:
	# 알약 칩(정보 표시용). 값 라벨은 meta "label".
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", pill_style(active, accent))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_rect)
	var text_label := Label.new()
	text_label.text = text
	text_label.add_theme_font_override("font", tabular())
	text_label.add_theme_font_size_override("font_size", TYPE_CAPTION + 1)
	text_label.add_theme_color_override("font_color", ACCENT_INK if active else TEXT)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_label)
	panel.set_meta("label", text_label)
	return panel


# ── 모달 껍데기 ──


static func dim_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = BG_DIM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	return backdrop


static func modal_panel(width: float, height: float) -> PanelContainer:
	# 화면 중앙의 큰 판. 호출부가 CanvasLayer에 딤과 함께 얹는다.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", modal_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	return panel


static func modal_header(title_text: String, subtitle_text: String, on_close: Callable, eyebrow_text := "") -> HBoxContainer:
	# [작은 이름표 / 큰 제목 / 회색 설명]  ······  [둥근 닫기]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	if not eyebrow_text.is_empty():
		column.add_child(eyebrow(eyebrow_text))
	column.add_child(title(title_text))
	if not subtitle_text.is_empty():
		column.add_child(subtitle(subtitle_text))
	var close := close_button()
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if on_close.is_valid():
		close.pressed.connect(on_close)
	row.add_child(close)
	row.set_meta("close_button", close)
	return row


static func enter(control: Control) -> void:
	# 등장: 살짝 아래에서 떠오르며 페이드. 이름 짓기 화면과 같은 리듬.
	if control == null:
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.98, 0.98)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
