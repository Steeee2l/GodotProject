class_name HudStyle
extends RefCounted

# 필드 HUD 디자인 시스템의 단일 출처 — 2026-09-04부터 쉘터와 같은 언어(ShelterTheme,
# 이름 짓기 화면 기준)를 쓴다: 거의 검정 바탕, 무광 표면 카드, 테두리 선 없음,
# 굵은 제목 + 회색 설명, 민트 강조 하나, 둥근 큰 버튼, 알약 칩.
#
# 규칙:
#  - 색은 아래 토큰만. 금색은 재화 아이콘·보상 수치에만, 테두리·제목에는 쓰지 않는다.
#  - 패널은 card/toast/modal/chip/keycap 프리셋 중 하나로 시작한다.
#  - 등장/퇴장은 enter()/exit()를 쓴다. 툭 나타나는 패널이 없어야 한다.
#  - 폰트 크기는 TYPE_* 스케일에서 고른다. 굵기는 bold()(FontVariation embolden).
#  - ▸ ✓ ⚠ ▲ 같은 기호는 Pretendard에 없어 깨진다 — 글자·색으로 표현한다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SFX := preload("res://scripts/sfx_bank.gd")
# class_name 캐시(.godot)가 갱신되기 전에도 헤드리스 테스트가 돌도록 직접 preload.
const TOUCH_SCROLL := preload("res://scripts/hud/touch_scroll.gd")

# ── 색 토큰 ────────────────────────────────────────────────────
# 이름은 하위 호환을 위해 그대로 두고 값만 새 언어로 바꿨다.
const INK := Color(0.043, 0.059, 0.071, 0.94)          # 표준 패널 바탕(#0b0f12, 살짝 비침)
const INK_SOLID := Color(0.043, 0.059, 0.071, 0.985)   # 모달 바탕(불투명에 가깝게)
const INK_WELL := Color(0.078, 0.102, 0.118, 0.96)     # 패널 속 패널(#141a1e)
const SURFACE_RAISED := Color("#1b2227")               # 카드 안 카드 · 보조 버튼
const SURFACE_HOVER := Color("#222a30")
const LINE := Color("#243036")                         # 아주 옅은 구분선(꼭 필요할 때만)
const LINE_FOCUS := Color("#5fd3b8")                   # 강조(민트) — 선택/포커스
const LINE_GOLD := Color("#243036")                    # (하위 호환) 이제 골드 보더는 없다
const TEXT := Color("#eef2ee")                         # 본문
const TEXT_DIM := Color("#8d9a94")                     # 보조 설명
const TEXT_FAINT := Color("#5f6b67")                   # 힌트/각주
const ACCENT := Color("#5fd3b8")                       # 강조 하나(민트)
const ACCENT_INK := Color("#06120f")                   # 민트 위 글자
const GOLD := Color("#d8bd72")                         # 재화 아이콘·보상 수치에만
const GOLD_TEXT := Color("#eef2ee")                    # (하위 호환) 제목은 흰 굵은 글자
const GREEN := Color("#5fd3b8")                        # 긍정·진행 = 민트
const WARN := Color("#e3bd67")                         # 주의
const DANGER := Color("#e06c5c")                       # 위험·실패

# ── 형태 토큰 ──────────────────────────────────────────────────
const RADIUS_CHIP := 999
const RADIUS_CARD := 14
const RADIUS_MODAL := 20

const TYPE_HEADING := 16    # 섹션 제목·주 행동
const TYPE_BODY := 14       # 본문
const TYPE_CAPTION := 12    # 보조 라벨
const TYPE_FOOTNOTE := 11   # 각주·힌트
const TYPE_NUMBER := 20     # 강조 수치(탄약 등)
const TYPE_TITLE := 24      # 모달 제목

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


# ── 스크롤 영역 ────────────────────────────────────────────────


static func make_scroll() -> ScrollContainer:
	# 모든 UI 스크롤 영역은 이걸로 만든다. 손가락 드래그(스와이프) 스크롤이
	# 자동으로 붙는다 — 상세는 TouchScroll 참조.
	var container := ScrollContainer.new()
	var bar := container.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", flat(Color(0, 0, 0, 0), 3))
	bar.add_theme_stylebox_override("grabber", flat(Color(TEXT_FAINT, 0.5), 3))
	bar.add_theme_stylebox_override("grabber_highlight", flat(Color(TEXT_DIM, 0.7), 3))
	bar.add_theme_stylebox_override("grabber_pressed", flat(ACCENT, 3))
	return TOUCH_SCROLL.install(container)


# ── 패널 프리셋 ────────────────────────────────────────────────


static func flat(background: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


static func style_mobile_action(
	button: Button, accent: Color, icon_limit := 30, filled := false, label_size := TYPE_CAPTION
) -> Button:
	# 모바일 원형 액션 버튼 — 아이콘 위, 라벨 아래, 완전한 원. 표면색 원에 민트 채움(filled).
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_limit)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("h_separation", 0)
	button.clip_text = true
	button.add_theme_font_override("font", bold())
	button.add_theme_font_size_override("font_size", label_size)
	var text_color := ACCENT_INK if filled else TEXT
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	var normal_bg := accent if filled else Color(INK_WELL.r, INK_WELL.g, INK_WELL.b, 0.92)
	button.add_theme_stylebox_override("normal", flat(normal_bg, 999))
	button.add_theme_stylebox_override("hover", flat(normal_bg.lightened(0.06), 999))
	button.add_theme_stylebox_override("pressed", flat(normal_bg.darkened(0.14), 999))
	button.add_theme_stylebox_override("focus", flat(normal_bg, 999))
	button.add_theme_stylebox_override("disabled", flat(Color(normal_bg, 0.45), 999))
	return button


static func panel(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	# (하위 호환) 자유 조합. 보더 인자는 무시한다 — 새 언어엔 테두리 선이 없다.
	# 강조 테두리가 정말 필요하면 accent_panel()을 쓴다.
	var style := flat(background, maxi(radius, 6))
	style.border_color = border
	return style


static func accent_panel(background: Color, accent: Color = ACCENT, radius: int = RADIUS_CARD) -> StyleBoxFlat:
	# 선택·강조 카드 — 민트 2px 테두리.
	var style := flat(background, radius)
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(2)
	return style


static func card(focused := false) -> StyleBoxFlat:
	# 필드 HUD의 표준 카드: 상호작용 프롬프트, 상태 패널, 무기 정보.
	var style := accent_panel(INK, ACCENT, RADIUS_CARD) if focused else flat(INK, RADIUS_CARD)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func toast() -> StyleBoxFlat:
	# 잠깐 떴다 사라지는 알림.
	var style := flat(INK, RADIUS_CARD)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func modal(_gold := false) -> StyleBoxFlat:
	# 화면을 멈추는 큰 판: 정산, 사망, 지도, 시설. 거의 검정, 보더 없음, 큰 그림자.
	var style := flat(INK_SOLID, RADIUS_MODAL)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 32
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style


static func chip(accent: Color = LINE, active := false) -> StyleBoxFlat:
	# 재화 칩·태그·작은 배지 — 알약. active면 민트 채움.
	var style := flat(accent if active else SURFACE_RAISED, RADIUS_CHIP)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 6.0
	return style


static func keycap() -> StyleBoxFlat:
	# 키 안내([F], [TAB]) 전용 — 표면색 작은 알약.
	var style := flat(SURFACE_RAISED, 8)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 3.0
	return style


static func label(text: String, size: int, color: Color, is_bold := false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", bold() if is_bold else FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func number(text: String, size: int = TYPE_NUMBER, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", bold_tabular())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


# ── 버튼 프리셋 ────────────────────────────────────────────────
# primary = 민트 채움/어두운 글자(주 행동 하나), 아니면 표면색 채움/흰 글자.


static func style_button(button: Button, accent: Color = LINE_FOCUS, primary := false) -> Button:
	# 공용 스타일을 입는 모든 버튼은 같은 탭 클릭음을 낸다(UI 버스, 중복 연결 방지).
	if not button.pressed.is_connected(_play_button_tap):
		button.pressed.connect(_play_button_tap)
	button.add_theme_font_override("font", bold())
	button.add_theme_font_size_override("font_size", TYPE_HEADING if primary else TYPE_BODY)
	var fill := accent if primary else SURFACE_RAISED
	var text_color := ACCENT_INK if primary else TEXT
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.55) if primary else TEXT_FAINT)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color := fill
		match state:
			"hover":
				color = fill.lightened(0.06)
			"pressed":
				color = fill.darkened(0.14)
			"disabled":
				color = Color(fill, 0.35) if primary else Color(fill, 0.6)
		var style := flat(color, RADIUS_CARD)
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		button.add_theme_stylebox_override(state, style)
	return button


static func style_pill(button: Button, active := false, accent: Color = ACCENT) -> Button:
	# 알약 탭/토글.
	if not button.pressed.is_connected(_play_button_tap):
		button.pressed.connect(_play_button_tap)
	button.add_theme_font_override("font", bold() if active else FONT)
	button.add_theme_font_size_override("font_size", TYPE_CAPTION + 1)
	var color := ACCENT_INK if active else TEXT
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	button.add_theme_stylebox_override("normal", chip(accent, active))
	var hover := chip(accent, active)
	hover.bg_color = accent.lightened(0.08) if active else SURFACE_HOVER
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", chip(accent, active))
	button.add_theme_stylebox_override("disabled", chip(LINE, false))
	button.focus_mode = Control.FOCUS_NONE
	return button


static func _play_button_tap() -> void:
	SFX.play("ui_tap")


static func close_button(icon: Texture2D) -> Button:
	# 둥근 40×40 닫기 버튼의 단일 출처.
	var button := Button.new()
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.tooltip_text = "닫기"
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not button.pressed.is_connected(_play_button_tap):
		button.pressed.connect(_play_button_tap)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", flat(SURFACE_RAISED, 999))
	button.add_theme_stylebox_override("hover", flat(SURFACE_HOVER, 999))
	button.add_theme_stylebox_override("pressed", flat(INK_WELL, 999))
	button.add_theme_stylebox_override("focus", flat(SURFACE_RAISED, 999))
	button.add_theme_stylebox_override("disabled", flat(Color(SURFACE_RAISED, 0.5), 999))
	return button


# ── 모션 ──────────────────────────────────────────────────────
# 모든 패널의 등장·퇴장은 같은 리듬을 탄다: 0.16초, 아래에서 6px 떠오르며 페이드.


static func enter(control: Control, from_offset := Vector2(0.0, 6.0)) -> void:
	if not is_instance_valid(control):
		return
	control.visible = true
	control.modulate.a = 0.0
	var origin := control.position
	control.position = origin + from_offset
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "position", origin, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func enter_modal(panel: Control) -> void:
	# 컨테이너 안의 모달용: 페이드 + 미세 스케일로 떠오른다.
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.965, 0.965)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func pop_in(control: Control, duration := 0.2) -> void:
	# 이미 자리를 잡은 컨테이너 안에서 '새로 생긴' 요소용 — 스케일 + 페이드만.
	if not is_instance_valid(control):
		return
	control.visible = true
	if not control.is_inside_tree():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return
	var extent := control.size
	if extent.x <= 1.0 or extent.y <= 1.0:
		extent = control.get_combined_minimum_size()
	control.pivot_offset = extent * 0.5
	control.modulate.a = 0.0
	control.scale = Vector2(0.85, 0.85)
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func exit(control: Control, and_free := false) -> void:
	if not is_instance_valid(control):
		return
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	if and_free:
		tween.tween_callback(control.queue_free)
	else:
		tween.tween_callback(func() -> void:
			control.visible = false
			control.modulate.a = 1.0
		)
