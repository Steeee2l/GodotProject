class_name ShelterOpsConsole
extends RefCounted
## 쉘터 운영 독(dock).
## 생산기·스크래핑 생산기·작업대·훈련대·창고를 3D 기물 없이 어디서든 여는 FM식 관리 진입점.
## 기계는 화면에서 사라졌고, 관리라는 행위만 UI로 남았다.
##
## 겉모습은 ShelterTheme(이름 짓기 화면의 언어)를 따른다 — 무광 표면 카드, 선 없는
## 둥근 모서리, 굵은 라벨 + 회색 배지, 강조는 민트 하나.

const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_THEME := preload("res://scripts/hud/shelter_theme.gd")
const SFX := preload("res://scripts/sfx_bank.gd")

const FACILITIES := [
	{"id": "scratcher_bank", "label": "생산", "icon": "scrap", "accent": Color("#f1cf68")},
	{"id": "catnip_scraper", "label": "스크래핑", "icon": "catnip", "accent": Color("#aeea78")},
	{"id": "workbench", "label": "제작", "icon": "craft", "accent": Color("#d8e4de")},
	{"id": "training", "label": "훈련", "icon": "fitness", "accent": Color("#9fc9d8")},
	{"id": "storage", "label": "창고", "icon": "secure", "accent": Color("#d8b46a")},
]

# 툴팁과 탭 사유 토스트가 같은 문구를 쓰도록 한곳에 둔다.
const FEVER_LOCKED_HINT := "잠김 · 스크래핑 생산기를 해금해야 합니다."

# 터치 없는 PC에서 세로+터치 분기를 검증하기 위한 프로브 전용 스위치.
static var force_touch_layout := false

# 글자가 아슬아슬하게 잘리지 않도록 폭 계산에 얹는 여유.
# 실측에서 2~5px이 모자라 "캣닢 피버 0%"가 "0"까지만 보였다.
const BUTTON_TEXT_SLACK := 6.0
# 레일이 아무리 길어져도 화면을 잡아먹지 않게 두는 상한.
const RAIL_MAX_WIDTH := 208.0
# 세로 탭바에서 글자가 안 들어가면 여기까지 줄여 본다.
const TAB_MIN_FONT_SIZE := 10
# 시설 버튼의 좌우 안쪽 여백(카드형 버튼).
const BUTTON_PAD_X := 14.0
# 배지 라벨이 차지하는 오른쪽 자리(글자는 오른끝 정렬이라 남는 폭은 비어 있다).
const BADGE_SPAN := 72.0
# 라벨과 배지 사이 최소 간격.
const BADGE_GAP := 10.0
# 독 안 요소 사이 간격.
const DOCK_SEPARATION := 6

var host: Node
var dock: VBoxContainer
var header_label: Label
# "대기 5" — 헤더 옆 회색 캡션. 대기 인원이 없으면 숨는다.
var header_idle_label: Label
var buttons_box: BoxContainer
var facility_buttons: Dictionary = {}
# 캣닢 피버 — 시설이 아니라 "사건"이라 시설 버튼 줄 아래 별도 카드로 둔다.
var fever_card: PanelContainer
var fever_button: Button
var fever_gauge: ProgressBar
# 카드 안 배치: 가로 레일에선 [제목·숫자 / 게이지 / 버튼] 세로 쌓기, 세로 탭바에선
# [제목·숫자·게이지 | 버튼] 한 줄 — 하단 탭바 위 높이를 예전(약 64px)만큼만 쓴다.
var fever_body: BoxContainer
var fever_title_label: Label
var fever_value_label: Label
# 배지 텍스트는 refresh()에서 계속 바뀐다("가능 12", "0/1"…). 마지막 레이아웃이
# 정한 조건을 들고 있다가, 글자가 바뀔 때마다 폭·글자 크기를 다시 맞춘다.
var rail_layout := true
var rail_base_width := 128.0
var rail_max_width := RAIL_MAX_WIDTH
var rail_font_size := SHELTER_THEME.TYPE_BODY
var rail_icon_width := 24.0
# 피버 중에는 남은 시간이 0.2초마다 바뀌어 글자 폭이 계속 흔들린다. 레일은
# 한번 넓어지면 그 방향(레이아웃이 다시 잡힐 때까지)으론 줄지 않게 해 덜컹임을 막는다.
var applied_rail_width := 128.0
var tab_slot_width := 0.0
var layout_ready := false
# 해금된 버튼이 새로 생기면 레일 높이·탭 폭이 달라진다 — 마지막 safe 여백을
# 들고 있다가 그 자리에서 레이아웃을 다시 잡는다.
var last_safe := Vector4.ZERO


func attach(owner_node: Node) -> void:
	host = owner_node


func build_dock(hud_layer: CanvasLayer) -> void:
	dock = VBoxContainer.new()
	dock.name = "ShelterOpsDock"
	dock.add_theme_constant_override("separation", DOCK_SEPARATION)
	dock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_layer.add_child(dock)

	# 헤더 — 배경 없는 민트 이름표. 대기 인원은 옆에 회색 캡션으로.
	var header := HBoxContainer.new()
	header.name = "OpsHeader"
	header.add_theme_constant_override("separation", 8)
	header.custom_minimum_size = Vector2(0, 24)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(header)
	var header_pad := SHELTER_THEME.spacer(0.0)
	header_pad.custom_minimum_size = Vector2(4, 0)
	header.add_child(header_pad)
	header_label = SHELTER_THEME.label(
		"쉘터 운영", SHELTER_THEME.TYPE_EYEBROW, SHELTER_THEME.ACCENT, true
	)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(header_label)
	header_idle_label = SHELTER_THEME.caption("")
	header_idle_label.add_theme_font_override("font", SHELTER_THEME.tabular())
	header_idle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_idle_label.visible = false
	header.add_child(header_idle_label)

	# 버튼 줄은 방향에 따라 세로 레일(가로 화면) ↔ 가로 탭바(세로 화면)로 변신.
	buttons_box = BoxContainer.new()
	buttons_box.name = "OpsButtons"
	buttons_box.vertical = true
	buttons_box.add_theme_constant_override("separation", DOCK_SEPARATION)
	dock.add_child(buttons_box)

	for entry in FACILITIES:
		var facility_id := str(entry["id"])
		var button := Button.new()
		button.name = "OpsButton_%s" % facility_id
		button.custom_minimum_size = Vector2(128, SHELTER_THEME.BUTTON_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_BODY)
		button.add_theme_constant_override("h_separation", 10)
		# 재화 아이콘(고철·캣닢)은 대형 생성 PNG다 — 원본 크기로 들어오면
		# 버튼 최소 크기가 폭발하므로 반드시 아이콘 폭을 못 박는다.
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.clip_text = true
		_style_facility_button(button, false)
		_make_badge(button)
		button.pressed.connect(_play_tap)
		if not DisplayServer.is_touchscreen_available():
			button.pressed.connect(open_facility.bind(facility_id))
		buttons_box.add_child(button)
		facility_buttons[facility_id] = button
	_build_fever_card()
	refresh()


func _build_fever_card() -> void:
	# 캣닢을 부어 게이지를 채우고, 꽉 차면 쉘터 전체가 취한다.
	var card := SHELTER_THEME.card(true)
	card.name = "CatnipFeverCard"
	fever_card = card
	var card_style := SHELTER_THEME.card_style(true)
	card_style.content_margin_left = BUTTON_PAD_X
	card_style.content_margin_right = BUTTON_PAD_X
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", card_style)
	dock.add_child(card)

	fever_body = BoxContainer.new()
	fever_body.vertical = true
	fever_body.add_theme_constant_override("separation", 8)
	card.add_child(fever_body)

	var info := VBoxContainer.new()
	info.name = "FeverInfo"
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fever_body.add_child(info)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	fever_title_label = SHELTER_THEME.label(
		"캣닢 피버", SHELTER_THEME.TYPE_BODY, SHELTER_THEME.TEXT, true
	)
	fever_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fever_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(fever_title_label)
	fever_value_label = SHELTER_THEME.number(
		"0%", SHELTER_THEME.TYPE_NUMBER_SMALL, SHELTER_THEME.ACCENT
	)
	fever_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fever_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(fever_value_label)
	fever_gauge = SHELTER_THEME.progress(0.0, 100.0)
	fever_gauge.name = "CatnipFeverGauge"
	info.add_child(fever_gauge)

	fever_button = Button.new()
	fever_button.name = "CatnipFeverButton"
	fever_button.text = "캣닢 붓기"
	SHELTER_THEME.style_primary(fever_button)
	# 주 버튼이지만 카드 안에서는 작게(40) — style_primary가 올린 52를 되돌린다.
	fever_button.custom_minimum_size = Vector2(0, SHELTER_THEME.BUTTON_HEIGHT_SMALL)
	fever_button.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_BODY)
	# 주 버튼은 글자 한 덩어리 — 아이콘은 없다(가운데 정렬 아이콘이 글자를 덮었다).
	fever_button.clip_text = true
	fever_button.pressed.connect(_play_tap)
	if not DisplayServer.is_touchscreen_available():
		fever_button.pressed.connect(charge_fever)
	fever_body.add_child(fever_button)
	_set_fever_card_stacked(true)


func _set_fever_card_stacked(stacked: bool) -> void:
	# 가로 레일: 세로 쌓기. 세로 탭바: 한 줄(정보 | 버튼).
	if fever_body == null or fever_button == null:
		return
	fever_body.vertical = stacked
	if stacked:
		fever_button.size_flags_horizontal = Control.SIZE_FILL
		fever_button.size_flags_vertical = Control.SIZE_FILL
		fever_button.custom_minimum_size = Vector2(0, SHELTER_THEME.BUTTON_HEIGHT_SMALL)
	else:
		fever_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		fever_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_fit_fever_button_row()


func _fit_fever_button_row() -> void:
	# 한 줄 배치에서 버튼은 글자만큼만(최소 112) 차지한다 — 나머지는 게이지 몫.
	if fever_button == null or fever_body == null or fever_body.vertical:
		return
	fever_button.custom_minimum_size = Vector2(
		maxf(112.0, _button_needed_width(fever_button)), SHELTER_THEME.BUTTON_HEIGHT_SMALL
	)


func _button_style(background: Color) -> StyleBoxFlat:
	var style := SHELTER_THEME.flat(background, SHELTER_THEME.RADIUS_BUTTON)
	style.content_margin_left = BUTTON_PAD_X
	style.content_margin_right = BUTTON_PAD_X
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _style_facility_button(button: Button, locked: bool) -> void:
	# SURFACE 카드형 버튼. 테두리 선 없음. 시설 accent는 아이콘 틴트에만 쓴다.
	# 잠긴 시설은 글자를 흐리고 표면을 어둡게(지금은 숨기지만 규약은 지킨다).
	if button.get_meta("locked_style", -1) == int(locked):
		return
	button.set_meta("locked_style", int(locked))
	var text_color: Color = SHELTER_THEME.TEXT_FAINT if locked else SHELTER_THEME.TEXT
	var surface: Color = SHELTER_THEME.SURFACE.darkened(0.35) if locked else SHELTER_THEME.SURFACE
	var hover: Color = surface if locked else SHELTER_THEME.SURFACE_HOVER
	button.add_theme_font_override("font", SHELTER_THEME.bold())
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", SHELTER_THEME.TEXT_FAINT)
	button.add_theme_stylebox_override("normal", _button_style(surface))
	button.add_theme_stylebox_override("hover", _button_style(hover))
	button.add_theme_stylebox_override("pressed", _button_style(hover))
	button.add_theme_stylebox_override("focus", _button_style(surface))
	button.add_theme_stylebox_override("disabled", _button_style(surface.darkened(0.2)))
	button.focus_mode = Control.FOCUS_NONE


func _make_badge(button: Button) -> Label:
	# 배지("0/4", "가능 2")는 라벨과 분리된 회색 캡션 — 버튼 위에 얹는 자식 라벨.
	var badge := SHELTER_THEME.caption("")
	badge.name = "Badge"
	badge.add_theme_font_override("font", SHELTER_THEME.tabular())
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.clip_text = false
	badge.visible = false
	button.add_child(badge)
	button.set_meta("badge_label", badge)
	_place_badge(badge, true)
	return badge


func _badge_of(button: Button) -> Label:
	# get_meta의 기본값 null은 '없음' 경고를 내므로 has_meta로 먼저 거른다.
	if button == null or not button.has_meta("badge_label"):
		return null
	return button.get_meta("badge_label") as Label


func _place_badge(badge: Label, rail: bool) -> void:
	if badge == null:
		return
	if rail:
		# 오른쪽 세로 중앙, 안쪽 여백만큼 들여서.
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.5
		badge.anchor_bottom = 0.5
		badge.offset_left = -(BADGE_SPAN + BUTTON_PAD_X)
		badge.offset_right = -BUTTON_PAD_X
		badge.offset_top = -10.0
		badge.offset_bottom = 10.0
		badge.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_CAPTION)
	else:
		# 세로 탭(아이콘 위·글자 아래)에서는 우상단 모서리에 작게.
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_left = -(BADGE_SPAN + 8.0)
		badge.offset_right = -8.0
		badge.offset_top = 6.0
		badge.offset_bottom = 24.0
		badge.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_CAPTION - 1)


func _play_tap() -> void:
	SFX.play("ui_tap")


func charge_fever() -> void:
	if host == null or bool(host.call("_ui_blocks_player")):
		return
	# 시설 버튼(open_facility)과 같은 규약: 잠겨 있어도 탭은 받고 사유를 토스트로
	# 돌려준다. disabled로 막으면 모바일에서 눌러도 아무 일이 없어 이유가 사라진다.
	if not GameState.is_shelter_facility_unlocked("catnip_scraper"):
		host.call("_show_status", FEVER_LOCKED_HINT)
		return
	host.call("_charge_catnip_fever")
	refresh()


func apply_layout(safe: Vector4) -> void:
	if dock == null:
		return
	last_safe = safe
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var portrait := viewport_size.y > viewport_size.x
	var separation := float(DOCK_SEPARATION)
	var header_height := 24.0
	if portrait and (DisplayServer.is_touchscreen_available() or force_touch_layout):
		# 세로 모바일: 우상단 세로 레일은 엄지가 못 닿는다 — 하단 컨트롤 바로
		# 위의 가로 탭바로 내려온다. 관리의 주 진입점은 손이 닿는 곳에 있어야 한다.
		buttons_box.vertical = false
		buttons_box.add_theme_constant_override("separation", DOCK_SEPARATION)
		for facility_id in facility_buttons:
			var button := facility_buttons[facility_id] as Button
			button.custom_minimum_size = Vector2(0, 84)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			# 아이콘을 가운데 정렬하면 아이콘이 글자 '위'로 쌓여 가로 폭을 먹지
			# 않는다. 왼쪽 정렬일 땐 아이콘(28)+간격(8)이 글자 자리를 빼앗아
			# "스크래핑 0/1"이 5px 모자랐다.
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("h_separation", 0)
			button.add_theme_constant_override("icon_max_width", 28)
			_place_badge(_badge_of(button), false)
		# 탭 하나가 실제로 갖는 폭 — 여기에 글자가 들어가도록 글자 크기를 정한다.
		# 잠긴 시설은 숨어 있으므로 '보이는 버튼 수'로 나눈다(컨테이너도 숨은
		# 자식엔 자리를 주지 않는다) — 고정 6칸으로 나누면 남는 칸이 생긴다.
		var tab_slots := float(maxi(1, _visible_button_count()))
		tab_slot_width = (
			viewport_size.x - 20.0 - safe.x - safe.z - separation * (tab_slots - 1.0)
		) / tab_slots
		rail_layout = false
		# 세로에서는 독이 화면 폭을 다 쓴다 — 128 고정 최소 폭은 필요 없고,
		# 피버 카드는 한 줄로 눕힌다.
		if fever_card != null:
			fever_card.custom_minimum_size.x = 0.0
		_set_fever_card_stacked(false)
		dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE, true)
		dock.offset_left = 10.0 + safe.x
		dock.offset_right = -10.0 - safe.z
		# 하단 조이스틱·상호작용 버튼 줄(약 210px) 위에 얹는다.
		# 하단 조이스틱·상호작용 줄과 우하단 무기 카드 중 더 높이 올라온 쪽
		# 위에 얹는다. 카드가 바닥 196px에 붙는 터치 기기에서 탭바가 카드를
		# 덮던 문제(실기기 신고)를 여기서 끊는다.
		dock.offset_bottom = -maxf(218.0 + safe.w, _weapon_card_reserved_height(viewport_size, safe))
		# 피버 카드가 아래로 밀려 잘리지 않도록 높이를 넓힌다(실측 최소 높이).
		# 카드가 숨어 있으면(스크래핑 미해금) 그만큼 독도 낮아진다 — 안 그러면
		# 탭바가 빈 자리 위로 떠서 엄지에서 멀어진다.
		var fever_span := 0.0
		if fever_card != null and fever_card.visible:
			fever_span = fever_card.get_combined_minimum_size().y + separation
		dock.offset_top = dock.offset_bottom - (header_height + separation + 84.0 + fever_span)
	else:
		# 가로(특히 모바일 가로)는 세로 공간이 귀하다. 레일이 고정 높이면
		# 우하단 무기 카드와 겹치고 스크롤이 생겼다 — 남는 높이에 맞춰
		# 버튼 높이를 압축해 '항상 한 화면에' 들어가게 한다.
		var top_margin := 176.0 + safe.y
		# 우하단 무기 카드 자리를 비워 둔다. 터치 기기에서는 이 카드가
		# 하단 조작 줄을 피해 바닥에서 196px 위에 붙으므로(PC는 16px),
		# 예약 높이도 그만큼 커야 한다 — 실기기에서 겹친 원인.
		# 카드 실물이 있으면 그 위치를 그대로 믿는다(수치 추정은 어긋난다).
		var reserved_bottom := _weapon_card_reserved_height(viewport_size, safe)
		var available_height := maxf(180.0, viewport_size.y - top_margin - reserved_bottom)
		_set_fever_card_stacked(true)
		# 피버 카드 실측 최소 높이를 쓴다(고정값은 실제와 어긋나 무기 카드를 침범했다).
		var fever_height := 0.0
		if fever_card != null and fever_card.visible:
			fever_height = fever_card.get_combined_minimum_size().y + separation
		# 잠긴 시설은 숨어 있다 — 남은 높이는 '보이는 버튼'끼리 나눠 갖는다.
		var slots := float(maxi(1, _visible_button_count()))
		var button_height := clampf(
			(available_height - header_height - fever_height - separation * (slots + 1.0)) / slots,
			26.0,
			SHELTER_THEME.BUTTON_HEIGHT
		)
		var base_rail_width := 128.0 if viewport_size.y >= 560.0 else 112.0
		rail_layout = true
		rail_base_width = base_rail_width
		rail_max_width = minf(RAIL_MAX_WIDTH, viewport_size.x * 0.3)
		rail_icon_width = 24.0 if button_height >= 44.0 else 18.0
		rail_font_size = (
			SHELTER_THEME.TYPE_BODY if button_height >= 42.0 else SHELTER_THEME.TYPE_CAPTION
		)
		for facility_id in facility_buttons:
			var button := facility_buttons[facility_id] as Button
			button.size_flags_horizontal = Control.SIZE_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("h_separation", 10)
			button.add_theme_constant_override("icon_max_width", roundi(rail_icon_width))
			button.add_theme_font_size_override("font_size", rail_font_size)
			_place_badge(_badge_of(button), true)
		# 글자가 실제로 들어가는 폭으로 레일을 넓힌다. 128 고정이라 가로에서
		# "캣닢 피버 0%"의 끝 글자가 2px 잘려 나갔다.
		applied_rail_width = base_rail_width
		var rail_width := _required_rail_width(base_rail_width)
		buttons_box.vertical = true
		buttons_box.add_theme_constant_override("separation", DOCK_SEPARATION)
		for facility_id in facility_buttons:
			(facility_buttons[facility_id] as Button).custom_minimum_size = Vector2(rail_width, button_height)
		if fever_card != null:
			fever_card.custom_minimum_size.x = rail_width
		# 가방 버튼(우상단) 아래에 세로 레일로 붙는다. 시야 중앙은 비워 둔다.
		dock.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
		dock.offset_right = -14.0 - safe.z
		# 컨테이너의 실제 최소 폭이 rail_width를 덮어쓴다(패널 여백 포함).
		# offset만 rail_width로 잡아 두면 독이 오른쪽으로 삐져나가 마지막
		# 버튼 끝이 화면 밖(노치 아래)으로 밀린다 — 실측으로 확인한 지점.
		var rail_span := maxf(rail_width, dock.get_combined_minimum_size().x)
		dock.offset_left = dock.offset_right - rail_span
		# 컨테이너의 실제 최소 높이가 내 계산을 덮어쓴다(자식 min size 합).
		# 계산값 대신 실측 최소 높이로 바닥을 맞춰야 무기 카드를 안 넘는다.
		var min_height := maxf(
			dock.get_combined_minimum_size().y,
			header_height + fever_height + (button_height + separation) * slots + separation
		)
		var bottom_limit := viewport_size.y - reserved_bottom
		var placed_top := minf(top_margin, bottom_limit - min_height)
		# 가방 버튼(우상단) 아래를 침범하지는 않는다.
		dock.offset_top = maxf(150.0 + safe.y, placed_top)
		dock.offset_bottom = dock.offset_top + min_height
	layout_ready = true
	_sync_text_fit()


func _button_needed_width(button: Button, font_size := -1) -> float:
	# 버튼이 글자를 다 보여주려면 필요한 폭. 폰트 크기·좌우 여백·아이콘 폭·아이콘
	# 간격을 '버튼에 실제로 걸려 있는 값'에서 읽는다 — 상수로 적어 두면
	# 스타일러가 나중에 폰트를 덮어쓰는 것 같은 어긋남을 놓친다.
	if button == null:
		return 0.0
	var font: Font = button.get_theme_font("font")
	var used_size := font_size if font_size > 0 else button.get_theme_font_size("font_size")
	if font == null or used_size <= 0:
		return 0.0
	var reserved := 0.0
	var style: StyleBox = button.get_theme_stylebox("normal")
	if style != null:
		reserved += style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	if button.icon != null:
		reserved += float(button.get_theme_constant("icon_max_width"))
		reserved += float(button.get_theme_constant("h_separation"))
	# 레일에서는 오른쪽 배지가 라벨과 같은 줄에 앉는다 — 그 폭도 자리를 받는다.
	if rail_layout and button.has_meta("badge_label"):
		var badge := button.get_meta("badge_label") as Label
		if badge != null and badge.visible and not badge.text.is_empty():
			reserved += _label_text_width(badge) + BADGE_GAP
	var text_width := font.get_string_size(
		button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, used_size
	).x
	return text_width + reserved + BUTTON_TEXT_SLACK


func _label_text_width(label: Label) -> float:
	if label == null:
		return 0.0
	var font: Font = label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if font == null or size <= 0:
		return 0.0
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _fever_card_needed_width() -> float:
	# 카드가 제목·숫자·버튼 글자를 다 보여주려면 필요한 폭(세로 쌓기 기준).
	if fever_card == null:
		return 0.0
	var reserved := 0.0
	var style: StyleBox = fever_card.get_theme_stylebox("panel")
	if style != null:
		reserved += style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	var info_width := _label_text_width(fever_title_label) + 8.0 + _label_text_width(fever_value_label)
	var button_width := _button_needed_width(fever_button)
	return maxf(info_width + BUTTON_TEXT_SLACK, button_width) + reserved


func _visible_button_count() -> int:
	var count := 0
	for facility_id in facility_buttons:
		if (facility_buttons[facility_id] as Button).visible:
			count += 1
	return count


func _required_rail_width(base_width: float) -> float:
	var needed := base_width
	# 숨은 버튼의 글자 폭은 세지 않는다 — 안 보이는 배지가 레일을 넓히면
	# 화면만 잡아먹는다.
	for facility_id in facility_buttons:
		var button := facility_buttons[facility_id] as Button
		if button.visible:
			needed = maxf(needed, _button_needed_width(button))
	if fever_card != null and fever_card.visible:
		needed = maxf(needed, _fever_card_needed_width())
	# 4px 단위로 올림 — 글자 한두 픽셀 차이로 레일이 떨리지 않게.
	needed = ceilf(needed * 0.25) * 4.0
	return clampf(needed, base_width, maxf(base_width, rail_max_width))


func _sync_text_fit() -> void:
	# 배지 글자는 refresh()마다 길어졌다 짧아졌다 한다("가능 12", "만재"…).
	# 레이아웃을 다시 돌리지 않고 폭·글자 크기만 그때그때 맞춰 준다.
	if dock == null or not layout_ready:
		return
	if rail_layout:
		applied_rail_width = maxf(applied_rail_width, _required_rail_width(rail_base_width))
		var rail_width := applied_rail_width
		for facility_id in facility_buttons:
			(facility_buttons[facility_id] as Button).custom_minimum_size.x = rail_width
		if fever_card != null:
			fever_card.custom_minimum_size.x = rail_width
		dock.offset_left = dock.offset_right - maxf(
			rail_width, dock.get_combined_minimum_size().x
		)
		return
	# 세로 탭바는 폭을 화면이 정한다 — 칸을 넓힐 수 없으니 글자를 한 단계씩 줄인다.
	_fit_fever_button_row()
	if tab_slot_width <= 0.0:
		return
	var font_size := SHELTER_THEME.TYPE_BODY
	while font_size > TAB_MIN_FONT_SIZE and _widest_tab_width(font_size) > tab_slot_width:
		font_size -= 1
	for facility_id in facility_buttons:
		(facility_buttons[facility_id] as Button).add_theme_font_size_override(
			"font_size", font_size
		)


func _widest_tab_width(font_size: int) -> float:
	var widest := 0.0
	for facility_id in facility_buttons:
		var button := facility_buttons[facility_id] as Button
		if button.visible:
			widest = maxf(widest, _button_needed_width(button, font_size))
	return widest


func _weapon_card_reserved_height(viewport_size: Vector2, safe: Vector4) -> float:
	# 우하단 무기 카드가 차지하는 '바닥으로부터의 높이' + 숨돌릴 여백.
	# 실물 노드가 있으면 실제 rect로 계산한다 — 터치/데스크톱에서 카드가
	# 붙는 높이가 다르고(196 vs 16), 수치를 두 곳에 적으면 반드시 어긋난다.
	# 우하단 상호작용 버튼("거래"·"잡담", 바닥 70 + 높이 72)은 상대가 다가올 때만
	# 나타난다 — 그때 레이아웃을 다시 잡지 않으므로 그 자리는 항상 비워 둔다.
	# 피버 카드가 커진 뒤(약 100px) 레일 끝이 이 버튼을 30px 덮었다.
	var interact_floor := 0.0
	if host.get("interact_button") is Control:
		interact_floor = 142.0 + 8.0 + safe.w
	var card := host.get_node_or_null("ShelterHUD/ShelterWeaponCard") as Control
	if card != null and card.visible:
		var card_rect := card.get_global_rect()
		if card_rect.size.y > 1.0:
			# 카드 위 30px은 비운다 — 피버 게이지가 마지막에 자라도 안 닿게.
			return maxf(interact_floor, maxf(96.0, viewport_size.y - card_rect.position.y + 30.0) + safe.w)
	var touch_layout := DisplayServer.is_touchscreen_available() or force_touch_layout
	return maxf(interact_floor, (196.0 if touch_layout else 16.0) + 82.0 + safe.w)


func refresh() -> void:
	if dock == null or host == null:
		return
	var idle_count := _idle_resident_count()
	header_label.text = "쉘터 운영"
	if header_idle_label != null:
		header_idle_label.text = "대기 %d" % idle_count
		header_idle_label.visible = idle_count > 0
	# 이번 refresh에서 '처음으로' 열린 것들 — 자리를 다시 잡은 뒤 팝으로 등장시킨다.
	var revealed: Array[Control] = []
	for entry in FACILITIES:
		var facility_id := str(entry["id"])
		var button := facility_buttons.get(facility_id) as Button
		if button == null:
			continue
		# 잠긴 시설은 회색 버튼으로 자리를 지키는 대신 아예 사라진다(유저 신고:
		# "오른쪽 비활성화된 버튼들 차라리 숨겨줘 — 해금될 때 생기면 되잖아").
		# 잠금 사유 툴팁·토스트도 함께 사라진다 — 다음에 뭐가 열리는지는 목표
		# 카드의 보상 캡션과 해금 배너가 말한다.
		var unlocked: bool = GameState.is_shelter_facility_unlocked(facility_id)
		var was_visible := button.visible
		button.visible = unlocked
		_style_facility_button(button, not unlocked)
		if not unlocked:
			continue
		if not was_visible:
			revealed.append(button)
		var badge := _facility_badge(facility_id)
		button.text = str(entry["label"])
		var badge_label := _badge_of(button)
		if badge_label != null:
			badge_label.text = badge
			badge_label.visible = not badge.is_empty()
		button.icon = UI_ICONS.get_icon(str(entry["icon"]), 24, entry["accent"] as Color)
		button.tooltip_text = GameState.get_shelter_facility_name(facility_id)
	_refresh_fever_card(revealed)
	if not revealed.is_empty() and layout_ready:
		# 버튼 하나가 늘면 레일 높이·탭 폭이 달라진다 — 자리를 먼저 잡고 연출한다.
		apply_layout(last_safe)
		for control in revealed:
			HudStyle.pop_in(control)
		return
	# 글자가 바뀐 뒤에 폭을 다시 맞춘다 — 배지가 붙는 순간 끝 글자가 잘리던 문제.
	_sync_text_fit()


func _refresh_fever_card(revealed: Array[Control] = []) -> void:
	if fever_button == null or fever_gauge == null:
		return
	var unlocked: bool = GameState.is_shelter_facility_unlocked("catnip_scraper")
	# 피버는 스크래핑 생산기에 딸린 사건이다 — 생산기가 없으면 카드도 없다.
	if fever_card != null:
		var was_visible := fever_card.visible
		fever_card.visible = unlocked
		if unlocked and not was_visible:
			revealed.append(fever_card)
	if not unlocked:
		return
	var cost: int = GameState.get_catnip_fever_charge_cost()
	var affordable := GameState.catnip >= cost
	fever_gauge.value = GameState.get_catnip_fever_ratio() * 100.0
	if GameState.catnip_fever_active:
		fever_title_label.text = "피버 %.0fx" % GameState.get_catnip_fever_multiplier()
		fever_value_label.text = "%.0f초" % GameState.get_catnip_fever_remaining_seconds()
		fever_button.text = "진행 중"
		# 진행 중에는 눌러도 할 일이 없다 — 입력을 막는 건 이 경우뿐이다.
		fever_button.disabled = true
		fever_button.tooltip_text = "캣닢 피버 진행 중 — 모든 생산이 폭주합니다."
	else:
		fever_title_label.text = "캣닢 피버"
		fever_value_label.text = "%d%%" % roundi(GameState.get_catnip_fever_ratio() * 100.0)
		fever_button.text = "캣닢 %s 붓기" % GameState.format_compact_number(cost)
		# 캣닢이 모자라도 탭은 받는다 — 사유는 host의 _charge_catnip_fever가
		# 토스트로 돌려준다(시설 버튼과 같은 방식).
		fever_button.disabled = false
		fever_button.tooltip_text = "캣닢 %s를 부어 게이지 %d%% 충전 · 만충 시 %.0f배 생산 %.0f초" % [
			GameState.format_compact_number(cost),
			roundi(GameState.CATNIP_FEVER_CHARGE_STEP),
			GameState.get_catnip_fever_multiplier(),
			GameState.get_catnip_fever_duration(),
		]
	# 눌리기는 해도 '지금은 못 쓰는' 상태라는 건 색으로 남겨 둔다.
	fever_button.modulate = (
		Color.WHITE
		if affordable or GameState.catnip_fever_active
		else Color(0.62, 0.66, 0.64, 0.78)
	)


func open_facility(facility_id: String) -> void:
	# 탭 한 번이 터치 라우터와 Button.pressed로 두 번 도착해도 안전하다 — 첫 호출이
	# 모달을 띄우는 순간 _ui_blocks_player()가 참이 되어 두 번째가 이 줄에서 걸린다.
	if host == null or bool(host.call("_ui_blocks_player")):
		return
	if not GameState.is_shelter_facility_unlocked(facility_id):
		host.call("_show_status", "잠김 · %s 후 이용할 수 있습니다." % str(
			host.LOCKED_FACILITY_HINTS.get(facility_id, "사자의 계약")
		))
		return
	var logic := host.get("facility_logic") as Dictionary
	var module := logic.get(facility_id) as Node
	if module == null:
		return
	host.call("_show_status", str(module.call("interact")))
	refresh()


func handle_touch(screen_position: Vector2) -> bool:
	if dock == null or not dock.visible:
		return false
	for facility_id in facility_buttons:
		var button := facility_buttons[facility_id] as Button
		if button.visible and button.get_global_rect().has_point(screen_position):
			open_facility(str(facility_id))
			return true
	if (
		fever_button != null
		and fever_button.visible
		and not fever_button.disabled
		and fever_button.get_global_rect().has_point(screen_position)
	):
		charge_fever()
		return true
	return false


func _facility_badge(facility_id: String) -> String:
	if not GameState.is_shelter_facility_unlocked(facility_id):
		return "잠김"
	match facility_id:
		"scratcher_bank":
			return "%d/%d" % [
				GameState.get_active_scratcher_workers(),
				GameState.get_scratcher_worker_slots(),
			]
		"catnip_scraper":
			return "%d/%d" % [
				GameState.get_active_catnip_workers(),
				GameState.get_catnip_worker_slots(),
			]
		"workbench":
			# 지금 만들 수 있는 게 있으면 알려준다 — 열어봐야 아는 정보는 죽은 정보다.
			var module := (host.get("facility_logic") as Dictionary).get("workbench") as Node
			if module != null:
				var craftable := int(module.call("get_craftable_count"))
				if craftable > 0:
					return "가능 %d" % craftable
		"storage":
			if GameState.get_storage_used_slots() >= GameState.get_storage_capacity():
				return "만재"
	return ""


func _idle_resident_count() -> int:
	GameState._ensure_resident_records()
	var busy := GameState.assigned_worker_ids.size() + GameState.assigned_catnip_worker_ids.size()
	return maxi(0, GameState.resident_cat_ids.size() - busy)
