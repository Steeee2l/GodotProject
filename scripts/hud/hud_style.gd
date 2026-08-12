class_name HudStyle
extends RefCounted

# HUD 디자인 시스템의 단일 출처.
#
# 예전에는 화면마다 배경색·보더·라운딩·폰트 크기를 손으로 조금씩 다르게
# 찍었다. 그 미세한 어긋남이 쌓이면 "만들다 만" 인상이 된다. 여기의 토큰과
# 프리셋만 쓰면 어떤 화면을 열어도 같은 손이 만든 것처럼 보인다.
#
# 규칙:
#  - 색은 아래 토큰만. 새 색이 필요하면 여기 추가하고 이름을 붙인다.
#  - 패널은 card/toast/modal/chip/keycap 프리셋 중 하나로 시작한다.
#  - 등장/퇴장은 enter()/exit()를 쓴다. 툭 나타나는 패널이 없어야 한다.
#  - 폰트 크기는 TYPE_* 스케일에서 고른다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

# ── 색 토큰 ────────────────────────────────────────────────────
const INK := Color(0.014, 0.021, 0.022, 0.96)          # 표준 패널 바탕
const INK_SOLID := Color(0.018, 0.024, 0.025, 0.985)   # 모달 바탕(불투명에 가깝게)
const INK_WELL := Color(0.045, 0.061, 0.061, 0.96)     # 패널 속 패널(카드 안 카드)
const LINE := Color("#3f574c")                         # 기본 보더
const LINE_FOCUS := Color("#79a994")                   # 강조 보더(활성/포커스)
const LINE_GOLD := Color("#8f7950")                    # 골드 계열 보더(모달·보상)
const TEXT := Color("#e9f1ec")                         # 본문
const TEXT_DIM := Color("#93a89d")                     # 보조 설명
const TEXT_FAINT := Color("#6d7f76")                   # 힌트/각주
const GOLD := Color("#d8bd72")                         # 보상·강조 아이콘
const GOLD_TEXT := Color("#ead69c")                    # 타이틀 골드
const GREEN := Color("#7fc79e")                        # 긍정·진행
const WARN := Color("#e3bd67")                         # 주의
const DANGER := Color("#e06c5c")                       # 위험·실패

# ── 형태 토큰 ──────────────────────────────────────────────────
const RADIUS_CHIP := 5
const RADIUS_CARD := 7
const RADIUS_MODAL := 10

# ── 타이포 스케일 ──────────────────────────────────────────────
const TYPE_TITLE := 24      # 모달 제목
const TYPE_HEADING := 16    # 섹션 제목·주 행동
const TYPE_BODY := 14       # 본문
const TYPE_CAPTION := 12    # 보조 라벨
const TYPE_FOOTNOTE := 11   # 각주·힌트
const TYPE_NUMBER := 20     # 강조 수치(탄약 등)


# ── 패널 프리셋 ────────────────────────────────────────────────


static func style_mobile_action(
	button: Button, accent: Color, icon_limit := 30, filled := false, label_size := TYPE_CAPTION
) -> Button:
	# 모바일 원형 액션 버튼 — 아이콘 위, 라벨 아래, 완전한 원.
	# 반경 999는 어느 크기에서도 원으로 수렴한다(크기는 레이아웃이 정한다).
	# 필드 우하단의 모든 터치 버튼은 이 프리셋 하나만 쓴다. 모양이 하나여야
	# 손가락이 외운다.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_limit)
	# 아이콘과 라벨을 원 중앙에 나란히. TOP 정렬은 아이콘이 원 테두리
	# 꼭대기에 붙고 라벨만 중앙에 남아 '따로 노는' 모양이 된다.
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("h_separation", 5)
	button.clip_text = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", label_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	var normal_bg := Color(
		lerpf(INK.r, accent.r, 0.22),
		lerpf(INK.g, accent.g, 0.22),
		lerpf(INK.b, accent.b, 0.22),
		0.94
	) if filled else Color(INK.r, INK.g, INK.b, 0.9)
	var normal := panel(normal_bg, Color(accent, 0.66), 999)
	normal.set_border_width_all(2)
	var hover := panel(normal_bg.lightened(0.04), Color(accent, 0.85), 999)
	hover.set_border_width_all(2)
	var pressed := panel(
		Color(accent.r * 0.42, accent.g * 0.42, accent.b * 0.42, 0.96),
		accent,
		999
	)
	pressed.set_border_width_all(2)
	var disabled := panel(Color(INK.r, INK.g, INK.b, 0.55), Color(accent, 0.2), 999)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	return button


static func panel(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	# (하위 호환) 자유 조합. 새 코드는 아래 프리셋을 쓴다.
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


static func card(focused := false) -> StyleBoxFlat:
	# 필드 HUD의 표준 카드: 상호작용 프롬프트, 상태 패널, 무기 정보.
	var style := panel(INK, LINE_FOCUS if focused else LINE, RADIUS_CARD)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


static func toast() -> StyleBoxFlat:
	# 잠깐 떴다 사라지는 알림.
	var style := panel(INK, LINE, RADIUS_CARD)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func modal(gold := false) -> StyleBoxFlat:
	# 화면을 멈추는 큰 패널: 정산, 사망, 지도, 시설.
	var style := StyleBoxFlat.new()
	style.bg_color = INK_SOLID
	style.border_color = LINE_GOLD if gold else LINE_FOCUS
	style.set_border_width_all(2)
	style.set_corner_radius_all(RADIUS_MODAL)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 18
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style


static func chip(accent: Color = LINE) -> StyleBoxFlat:
	# 재화 칩·태그·작은 배지.
	var style := panel(INK_WELL, accent, RADIUS_CHIP)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func keycap() -> StyleBoxFlat:
	# 키 안내([F], [TAB]) 전용.
	var style := panel(Color("#17231f"), Color("#8bc5a8"), RADIUS_CHIP)
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	return style


static func raised_panel(
	background: Color, border: Color, radius: int = 8, shadow: float = 18.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = roundi(shadow)
	return style


static func label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


# ── 버튼 프리셋 ────────────────────────────────────────────────
# 6개 파일이 제각각 버튼 공장을 갖고 있었다(폰트 14/15/16 혼재, pressed/disabled
# 누락 제각각). 여기 하나로 통일한다: 4상태 전부 정의, 폰트는 HEADING(주 행동)
# 또는 BODY(보조 행동).


static func style_button(button: Button, accent: Color = LINE_FOCUS, primary := false) -> Button:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", TYPE_HEADING if primary else TYPE_BODY)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", GOLD_TEXT)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	button.focus_mode = Control.FOCUS_NONE
	var base := INK_WELL if primary else INK
	var normal := panel(base, accent.darkened(0.25), RADIUS_CARD)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := panel(base.lightened(0.06), accent, RADIUS_CARD)
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 7.0
	hover.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("hover", hover)
	var pressed := panel(base.darkened(0.15), GOLD, RADIUS_CARD)
	pressed.content_margin_left = 12.0
	pressed.content_margin_right = 12.0
	pressed.content_margin_top = 8.0
	pressed.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := panel(Color(base.r, base.g, base.b, base.a * 0.6), accent.darkened(0.55), RADIUS_CARD)
	disabled.content_margin_left = 12.0
	disabled.content_margin_right = 12.0
	disabled.content_margin_top = 7.0
	disabled.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("disabled", disabled)
	return button


static func close_button(icon: Texture2D) -> Button:
	# 다섯 파일이 각자 만들던 40×40 닫기 버튼의 단일 출처.
	var button := Button.new()
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.tooltip_text = "닫기"
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_button(button, LINE)
	return button


# ── 모션 ──────────────────────────────────────────────────────
# 모든 패널의 등장·퇴장은 같은 리듬을 탄다: 0.16초, 아래에서 6px 떠오르며 페이드.
# "툭" 나타나는 UI가 하나도 없게 하는 것이 완성도의 절반이다.


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
	# 컨테이너(CenterContainer 등) 안의 모달용: position은 컨테이너가 덮어쓰므로
	# 페이드 + 미세 스케일로 떠오른다. 툭 나타나는 팝업을 없애는 표준 등장.
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.965, 0.965)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
