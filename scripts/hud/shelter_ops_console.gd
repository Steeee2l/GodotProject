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

var host: Node
var dock: VBoxContainer
var header_label: Label
var facility_buttons: Dictionary = {}


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
		dock.add_child(button)
		facility_buttons[facility_id] = button
	refresh()


func apply_layout(safe: Vector4) -> void:
	if dock == null:
		return
	# 가방 버튼(우상단) 아래에 세로 레일로 붙는다. 시야 중앙은 비워 둔다.
	dock.offset_right = -14.0 - safe.z
	dock.offset_left = dock.offset_right - 128.0
	dock.offset_top = 176.0 + safe.y
	dock.offset_bottom = dock.offset_top + 320.0


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
	return ""


func _idle_resident_count() -> int:
	GameState._ensure_resident_records()
	var busy := GameState.assigned_worker_ids.size() + GameState.assigned_catnip_worker_ids.size()
	return maxi(0, GameState.resident_cat_ids.size() - busy)
