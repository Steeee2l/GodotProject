class_name ShelterOpsConsole
extends RefCounted
## 쉘터 운영 독(dock).
## 생산기·착즙기·제작대·훈련대·창고를 3D 기물 없이 어디서든 여는 FM식 관리 진입점.
## 기계는 화면에서 사라졌고, 관리라는 행위만 UI로 남았다.

const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

const FACILITIES := [
	{"id": "scratcher_bank", "label": "생산", "icon": "scrap", "accent": Color("#f1cf68")},
	{"id": "catnip_scraper", "label": "착즙", "icon": "catnip", "accent": Color("#aeea78")},
	{"id": "workbench", "label": "제작", "icon": "craft", "accent": Color("#d8e4de")},
	{"id": "training", "label": "훈련", "icon": "fitness", "accent": Color("#9fc9d8")},
	{"id": "storage", "label": "창고", "icon": "secure", "accent": Color("#d8b46a")},
]

# 터치 없는 PC에서 세로+터치 분기를 검증하기 위한 프로브 전용 스위치.
static var force_touch_layout := false

var host: Node
var dock: VBoxContainer
var header_label: Label
var buttons_box: BoxContainer
var facility_buttons: Dictionary = {}
# 캣닢 피버 — 시설이 아니라 "사건"이라 시설 버튼 줄 아래 별도 카드로 둔다.
var fever_button: Button
var fever_gauge: ProgressBar


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
			button.add_theme_constant_override("icon_max_width", 28)
		dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE, true)
		dock.offset_left = 10.0 + safe.x
		dock.offset_right = -10.0 - safe.z
		# 하단 조이스틱·상호작용 버튼 줄(약 210px) 위에 얹는다.
		dock.offset_bottom = -218.0 - safe.w
		# 피버 카드(버튼+게이지 약 52px)가 아래로 밀려 잘리지 않도록 높이를 넓힌다.
		dock.offset_top = dock.offset_bottom - 174.0
	else:
		buttons_box.vertical = true
		buttons_box.add_theme_constant_override("separation", 5)
		for facility_id in facility_buttons:
			var button := facility_buttons[facility_id] as Button
			button.custom_minimum_size = Vector2(128, 52)
			button.size_flags_horizontal = Control.SIZE_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("icon_max_width", 24)
		# 가방 버튼(우상단) 아래에 세로 레일로 붙는다. 시야 중앙은 비워 둔다.
		dock.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
		dock.offset_right = -14.0 - safe.z
		dock.offset_left = dock.offset_right - 128.0
		dock.offset_top = 176.0 + safe.y
		dock.offset_bottom = dock.offset_top + 412.0


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


func _refresh_fever_card() -> void:
	if fever_button == null or fever_gauge == null:
		return
	var unlocked: bool = GameState.is_shelter_facility_unlocked("catnip_scraper")
	fever_gauge.value = GameState.get_catnip_fever_ratio() * 100.0
	if GameState.catnip_fever_active:
		fever_button.text = "피버! %.0fx  %.0f초" % [
			GameState.get_catnip_fever_multiplier(),
			GameState.get_catnip_fever_remaining_seconds(),
		]
		fever_button.disabled = true
		fever_button.tooltip_text = "캣닢 피버 진행 중 — 모든 생산이 폭주합니다."
	else:
		var cost: int = GameState.get_catnip_fever_charge_cost()
		fever_button.text = "캣닢 피버 %d%%" % roundi(GameState.get_catnip_fever_ratio() * 100.0)
		fever_button.disabled = not unlocked or GameState.catnip < cost
		fever_button.tooltip_text = (
			"잠김 · 착즙기를 해금해야 합니다."
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
	fever_button.modulate = Color.WHITE if unlocked else Color(0.62, 0.66, 0.64, 0.78)


func open_facility(facility_id: String) -> void:
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
