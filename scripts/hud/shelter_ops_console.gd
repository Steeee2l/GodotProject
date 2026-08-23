class_name ShelterOpsConsole
extends RefCounted
## 쉘터 운영 독(dock).
## 생산기·스크래핑 생산기·작업대·훈련대·창고를 3D 기물 없이 어디서든 여는 FM식 관리 진입점.
## 기계는 화면에서 사라졌고, 관리라는 행위만 UI로 남았다.

const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

const FACILITIES := [
	{"id": "scratcher_bank", "label": "생산", "icon": "scrap", "accent": Color("#f1cf68")},
	{"id": "catnip_scraper", "label": "스크래핑", "icon": "catnip", "accent": Color("#aeea78")},
	{"id": "workbench", "label": "제작", "icon": "craft", "accent": Color("#d8e4de")},
	{"id": "training", "label": "훈련", "icon": "fitness", "accent": Color("#9fc9d8")},
	{"id": "storage", "label": "창고", "icon": "secure", "accent": Color("#d8b46a")},
	# 영입소는 3D 기물이 없다 — 이 버튼이 유일한 진입점이다(쉘터 UI-first).
	{"id": "recruit", "label": "영입", "icon": "resident", "accent": Color("#9fc9d8")},
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

var host: Node
var dock: VBoxContainer
var header_label: Label
var buttons_box: BoxContainer
var facility_buttons: Dictionary = {}
# 캣닢 피버 — 시설이 아니라 "사건"이라 시설 버튼 줄 아래 별도 카드로 둔다.
var fever_card: PanelContainer
var fever_button: Button
var fever_gauge: ProgressBar
# 배지 텍스트는 refresh()에서 계속 바뀐다("가능 12", "0/1"…). 마지막 레이아웃이
# 정한 조건을 들고 있다가, 글자가 바뀔 때마다 폭·글자 크기를 다시 맞춘다.
var rail_layout := true
var rail_base_width := 128.0
var rail_max_width := RAIL_MAX_WIDTH
var rail_font_size := HudStyle.TYPE_CAPTION
var rail_icon_width := 24.0
# 피버 중에는 남은 시간이 0.2초마다 바뀌어 글자 폭이 계속 흔들린다. 레일은
# 한번 넓어지면 그 방향(레이아웃이 다시 잡힐 때까지)으론 줄지 않게 해 덜컹임을 막는다.
var applied_rail_width := 128.0
var tab_slot_width := 0.0
var layout_ready := false


func attach(owner_node: Node) -> void:
	host = owner_node


func build_dock(hud_layer: CanvasLayer) -> void:
	dock = VBoxContainer.new()
	dock.name = "ShelterOpsDock"
	dock.add_theme_constant_override("separation", 5)
	dock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_layer.add_child(dock)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", HudStyle.chip(HudStyle.LINE))
	dock.add_child(header)
	header_label = HudStyle.label("쉘터 운영", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_DIM)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(header_label)

	# 버튼 줄은 방향에 따라 세로 레일(가로 화면) ↔ 가로 탭바(세로 화면)로 변신.
	buttons_box = BoxContainer.new()
	buttons_box.name = "OpsButtons"
	buttons_box.vertical = true
	buttons_box.add_theme_constant_override("separation", 5)
	dock.add_child(buttons_box)

	for entry in FACILITIES:
		var facility_id := str(entry["id"])
		var button := Button.new()
		button.name = "OpsButton_%s" % facility_id
		button.custom_minimum_size = Vector2(128, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION)
		button.add_theme_constant_override("h_separation", 8)
		# 재화 아이콘(고철·캣닢)은 대형 생성 PNG다 — 원본 크기로 들어오면
		# 버튼 최소 크기가 폭발하므로 반드시 아이콘 폭을 못 박는다.
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.clip_text = true
		HudStyle.style_button(button, entry["accent"] as Color)
		if not DisplayServer.is_touchscreen_available():
			button.pressed.connect(open_facility.bind(facility_id))
		buttons_box.add_child(button)
		facility_buttons[facility_id] = button
	_build_fever_card()
	refresh()


func _build_fever_card() -> void:
	# 캣닢을 부어 게이지를 채우고, 꽉 차면 쉘터 전체가 취한다.
	var card := PanelContainer.new()
	card.name = "CatnipFeverCard"
	fever_card = card
	card.add_theme_stylebox_override("panel", HudStyle.chip(Color("#7fb069")))
	dock.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	fever_button = Button.new()
	fever_button.name = "CatnipFeverButton"
	fever_button.custom_minimum_size = Vector2(128, 40)
	fever_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fever_button.add_theme_font_override("font", FONT)
	fever_button.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION)
	fever_button.add_theme_constant_override("h_separation", 8)
	fever_button.expand_icon = true
	# expand_icon을 켰으면 폭 상한은 필수다 — 대형 재화 PNG가 버튼을 찢는다.
	fever_button.add_theme_constant_override("icon_max_width", 22)
	fever_button.clip_text = true
	HudStyle.style_button(fever_button, Color("#aeea78"))
	if not DisplayServer.is_touchscreen_available():
		fever_button.pressed.connect(charge_fever)
	box.add_child(fever_button)
	fever_gauge = ProgressBar.new()
	fever_gauge.name = "CatnipFeverGauge"
	fever_gauge.custom_minimum_size = Vector2(0, 8)
	fever_gauge.show_percentage = false
	fever_gauge.min_value = 0.0
	fever_gauge.max_value = 100.0
	fever_gauge.value = 0.0
	fever_gauge.add_theme_stylebox_override("background", HudStyle.panel(HudStyle.INK, HudStyle.LINE, 3))
	fever_gauge.add_theme_stylebox_override("fill", HudStyle.panel(Color("#aeea78"), Color("#d8f5a8"), 3))
	box.add_child(fever_gauge)


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
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var portrait := viewport_size.y > viewport_size.x
	if portrait and (DisplayServer.is_touchscreen_available() or force_touch_layout):
		# 세로 모바일: 우상단 세로 레일은 엄지가 못 닿는다 — 하단 컨트롤 바로
		# 위의 가로 탭바로 내려온다. 관리의 주 진입점은 손이 닿는 곳에 있어야 한다.
		buttons_box.vertical = false
		buttons_box.add_theme_constant_override("separation", 6)
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
		# 탭 하나가 실제로 갖는 폭 — 여기에 글자가 들어가도록 글자 크기를 정한다.
		var tab_slots := float(maxi(1, facility_buttons.size()))
		tab_slot_width = (
			viewport_size.x - 20.0 - safe.x - safe.z - 6.0 * (tab_slots - 1.0)
		) / tab_slots
		rail_layout = false
		if fever_button != null:
			# 세로에서는 독이 화면 폭을 다 쓴다 — 128 고정 최소 폭은 필요 없다.
			fever_button.custom_minimum_size.x = 0.0
		dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE, true)
		dock.offset_left = 10.0 + safe.x
		dock.offset_right = -10.0 - safe.z
		# 하단 조이스틱·상호작용 버튼 줄(약 210px) 위에 얹는다.
		# 하단 조이스틱·상호작용 줄과 우하단 무기 카드 중 더 높이 올라온 쪽
		# 위에 얹는다. 카드가 바닥 196px에 붙는 터치 기기에서 탭바가 카드를
		# 덮던 문제(실기기 신고)를 여기서 끊는다.
		dock.offset_bottom = -maxf(218.0 + safe.w, _weapon_card_reserved_height(viewport_size, safe))
		# 피버 카드(버튼+게이지 약 52px)가 아래로 밀려 잘리지 않도록 높이를 넓힌다.
		dock.offset_top = dock.offset_bottom - 174.0
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
		var header_height := 30.0
		# 피버 카드 실측 높이를 쓴다. 58 고정값이 실제(64)보다 작아 레일이
		# 계산보다 길어지며 무기 카드를 6px 침범했다.
		var fever_height := 0.0
		if fever_card != null and fever_card.visible:
			fever_height = maxf(64.0, fever_card.get_global_rect().size.y) + 6.0
		var separation := 5.0
		var slots := float(maxi(1, facility_buttons.size()))
		var button_height := clampf(
			(available_height - header_height - fever_height - separation * (slots + 1.0)) / slots,
			26.0,
			52.0
		)
		var base_rail_width := 128.0 if viewport_size.y >= 560.0 else 112.0
		rail_layout = true
		rail_base_width = base_rail_width
		rail_max_width = minf(RAIL_MAX_WIDTH, viewport_size.x * 0.3)
		rail_icon_width = 24.0 if button_height >= 44.0 else 18.0
		rail_font_size = (
			HudStyle.TYPE_CAPTION if button_height >= 42.0 else HudStyle.TYPE_FOOTNOTE
		)
		# 글자가 실제로 들어가는 폭으로 레일을 넓힌다. 128 고정이라 가로에서
		# "캣닢 피버 0%"의 끝 글자가 2px 잘려 나갔다.
		applied_rail_width = base_rail_width
		var rail_width := _required_rail_width(base_rail_width)
		buttons_box.vertical = true
		buttons_box.add_theme_constant_override("separation", roundi(separation))
		for facility_id in facility_buttons:
			var button := facility_buttons[facility_id] as Button
			button.custom_minimum_size = Vector2(rail_width, button_height)
			button.size_flags_horizontal = Control.SIZE_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("h_separation", 8)
			button.add_theme_constant_override("icon_max_width", roundi(rail_icon_width))
			button.add_theme_font_size_override("font_size", rail_font_size)
		if fever_button != null:
			fever_button.custom_minimum_size.x = rail_width
		# 가방 버튼(우상단) 아래에 세로 레일로 붙는다. 시야 중앙은 비워 둔다.
		dock.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
		dock.offset_right = -14.0 - safe.z
		# 컨테이너의 실제 최소 폭이 rail_width를 덮어쓴다(패널 여백 포함 144px).
		# offset만 rail_width로 잡아 두면 독이 오른쪽으로 16px 삐져나가 마지막
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
	# style_button이 나중에 폰트를 14로 덮어쓰는 것 같은 어긋남을 놓친다.
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
	var text_width := font.get_string_size(
		button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, used_size
	).x
	return text_width + reserved + BUTTON_TEXT_SLACK


func _required_rail_width(base_width: float) -> float:
	var needed := base_width
	for facility_id in facility_buttons:
		needed = maxf(needed, _button_needed_width(facility_buttons[facility_id] as Button))
	needed = maxf(needed, _button_needed_width(fever_button))
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
		if fever_button != null:
			fever_button.custom_minimum_size.x = rail_width
		dock.offset_left = dock.offset_right - maxf(
			rail_width, dock.get_combined_minimum_size().x
		)
		return
	# 세로 탭바는 폭을 화면이 정한다 — 칸을 넓힐 수 없으니 글자를 한 단계씩 줄인다.
	if tab_slot_width <= 0.0:
		return
	var font_size := HudStyle.TYPE_BODY
	while font_size > TAB_MIN_FONT_SIZE and _widest_tab_width(font_size) > tab_slot_width:
		font_size -= 1
	for facility_id in facility_buttons:
		(facility_buttons[facility_id] as Button).add_theme_font_size_override(
			"font_size", font_size
		)


func _widest_tab_width(font_size: int) -> float:
	var widest := 0.0
	for facility_id in facility_buttons:
		widest = maxf(
			widest, _button_needed_width(facility_buttons[facility_id] as Button, font_size)
		)
	return widest


func _weapon_card_reserved_height(viewport_size: Vector2, safe: Vector4) -> float:
	# 우하단 무기 카드가 차지하는 '바닥으로부터의 높이' + 숨돌릴 여백.
	# 실물 노드가 있으면 실제 rect로 계산한다 — 터치/데스크톱에서 카드가
	# 붙는 높이가 다르고(196 vs 16), 수치를 두 곳에 적으면 반드시 어긋난다.
	var card := host.get_node_or_null("ShelterHUD/ShelterWeaponCard") as Control
	if card != null and card.visible:
		var card_rect := card.get_global_rect()
		if card_rect.size.y > 1.0:
			# 카드 위 30px은 비운다 — 피버 게이지가 마지막에 자라도 안 닿게.
			return maxf(96.0, viewport_size.y - card_rect.position.y + 30.0) + safe.w
	var touch_layout := DisplayServer.is_touchscreen_available() or force_touch_layout
	return (196.0 if touch_layout else 16.0) + 82.0 + safe.w


func refresh() -> void:
	if dock == null or host == null:
		return
	var idle_count := _idle_resident_count()
	header_label.text = "쉘터 운영" if idle_count <= 0 else "쉘터 운영 · 대기 %d" % idle_count
	for entry in FACILITIES:
		var facility_id := str(entry["id"])
		var button := facility_buttons.get(facility_id) as Button
		if button == null:
			continue
		var unlocked: bool = GameState.is_shelter_facility_unlocked(facility_id)
		var accent := entry["accent"] as Color
		var badge := _facility_badge(facility_id)
		button.text = str(entry["label"]) if badge.is_empty() else "%s  %s" % [entry["label"], badge]
		button.icon = UI_ICONS.get_icon(
			str(entry["icon"]),
			24,
			accent if unlocked else HudStyle.TEXT_FAINT
		)
		button.modulate = Color.WHITE if unlocked else Color(0.62, 0.66, 0.64, 0.78)
		button.tooltip_text = (
			GameState.get_shelter_facility_name(facility_id)
			if unlocked
			else "잠김 · %s" % str(host.LOCKED_FACILITY_HINTS.get(facility_id, "계약으로 해금"))
		)
	_refresh_fever_card()
	# 글자가 바뀐 뒤에 폭을 다시 맞춘다 — 배지가 붙는 순간 끝 글자가 잘리던 문제.
	_sync_text_fit()


func _refresh_fever_card() -> void:
	if fever_button == null or fever_gauge == null:
		return
	var unlocked: bool = GameState.is_shelter_facility_unlocked("catnip_scraper")
	var cost: int = GameState.get_catnip_fever_charge_cost()
	var affordable := GameState.catnip >= cost
	fever_gauge.value = GameState.get_catnip_fever_ratio() * 100.0
	if GameState.catnip_fever_active:
		fever_button.text = "피버! %.0fx  %.0f초" % [
			GameState.get_catnip_fever_multiplier(),
			GameState.get_catnip_fever_remaining_seconds(),
		]
		# 진행 중에는 눌러도 할 일이 없다 — 입력을 막는 건 이 경우뿐이다.
		fever_button.disabled = true
		fever_button.tooltip_text = "캣닢 피버 진행 중 — 모든 생산이 폭주합니다."
	else:
		fever_button.text = "캣닢 피버 %d%%" % roundi(GameState.get_catnip_fever_ratio() * 100.0)
		# 잠김·캣닢 부족이어도 탭은 받는다. 사유는 charge_fever와 host의
		# _charge_catnip_fever가 토스트로 돌려준다(시설 버튼과 같은 방식).
		fever_button.disabled = false
		fever_button.tooltip_text = (
			FEVER_LOCKED_HINT
			if not unlocked
			else "캣닢 %s를 부어 게이지 %d%% 충전 · 만충 시 %.0f배 생산 %.0f초" % [
				GameState.format_compact_number(cost),
				roundi(GameState.CATNIP_FEVER_CHARGE_STEP),
				GameState.get_catnip_fever_multiplier(),
				GameState.get_catnip_fever_duration(),
			]
		)
	fever_button.icon = UI_ICONS.get_icon(
		"catnip", 22, Color("#aeea78") if unlocked else HudStyle.TEXT_FAINT
	)
	# 눌리기는 해도 '지금은 못 쓰는' 상태라는 건 색으로 남겨 둔다.
	fever_button.modulate = (
		Color.WHITE
		if unlocked and (affordable or GameState.catnip_fever_active)
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
		"recruit":
			# 남은 자리를 배지로 — 열어 봐야 아는 정보는 죽은 정보다.
			var room_left: int = GameState.get_available_resident_slots()
			if room_left <= 0:
				return "만실"
			return "+%s" % GameState.format_compact_number(room_left)
	return ""


func _idle_resident_count() -> int:
	GameState._ensure_resident_records()
	var busy := GameState.assigned_worker_ids.size() + GameState.assigned_catnip_worker_ids.size()
	return maxi(0, GameState.resident_cat_ids.size() - busy)
