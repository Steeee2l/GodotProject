class_name GameOverScreen
extends RefCounted

# 사망 결과 화면.
#
# main.gd에서 370줄을 떼어냈다. 이 화면이 쓰는 상태는 전부 여기 있고,
# 바깥에서는 build() / present() / apply_layout() 세 개만 부른다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
const HudStyle := preload("res://scripts/hud/hud_style.gd")

var canvas: CanvasLayer
var fade: ColorRect
var panel: PanelContainer
var title_label: Label
var cause_label: Label
var survival_value: Label
var kills_value: Label
var damage_value: Label
var loss_label: Label
var loss_count_label: Label
var loss_value_label: Label
var loss_grid: HFlowContainer
var continue_label: Label
var ready_to_continue := false
var continue_started := false


func build(host: Node) -> void:
	canvas = CanvasLayer.new()
	canvas.name = "GameOverCanvas"
	canvas.layer = 180
	canvas.visible = false
	host.add_child(canvas)
	fade = ColorRect.new()
	fade.name = "GameOverFade"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	panel = PanelContainer.new()
	panel.name = "GameOverPanel"
	# 세로 화면(캔버스 폭 720)에서 딱 맞아 떨어지면 테두리가 잘린다. 여백을 남긴다.
	var over_viewport: Vector2 = canvas.get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(720.0, over_viewport.x - 24.0), 500)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#0b1111")
	panel_style.border_color = Color("#a86f5d")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0, 0, 0, 0.72)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.name = "GameOverHeader"
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	var alert_plate := PanelContainer.new()
	alert_plate.custom_minimum_size = Vector2(64, 64)
	alert_plate.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#241716"), Color("#bd6f59"), 7)
	)
	header.add_child(alert_plate)
	var alert_icon := TextureRect.new()
	alert_icon.texture = UI_ICONS.get_icon("alert", 42, Color("#e58a70"))
	alert_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alert_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alert_plate.add_child(alert_icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)
	var eyebrow := Label.new()
	eyebrow.text = "서울 외곽 탐사 · 종료"
	eyebrow.add_theme_font_override("font", FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color("#c88973"))
	title_box.add_child(eyebrow)
	title_label = Label.new()
	title_label.name = "GameOverLabel"
	title_label.text = "작전 실패"
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color("#f0e5ce"))
	title_box.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "생존자가 전투 불능 상태가 되었습니다."
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#91a49d"))
	title_box.add_child(subtitle)
	var recovery_chip := PanelContainer.new()
	recovery_chip.custom_minimum_size = Vector2(150, 54)
	recovery_chip.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#121c1a"), Color("#55796c"), 7)
	)
	header.add_child(recovery_chip)
	var recovery_chip_label := Label.new()
	recovery_chip_label.text = "회수 기회\n1회"
	recovery_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recovery_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recovery_chip_label.add_theme_font_override("font", FONT)
	recovery_chip_label.add_theme_font_size_override("font_size", 14)
	recovery_chip_label.add_theme_color_override("font_color", Color("#9bd2b8"))
	recovery_chip.add_child(recovery_chip_label)

	var divider := HSeparator.new()
	divider.modulate = Color(0.45, 0.54, 0.49, 0.55)
	box.add_child(divider)
	var cause_panel := PanelContainer.new()
	cause_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#1b1312"), Color("#8e5547"), 6)
	)
	box.add_child(cause_panel)
	var cause_margin := MarginContainer.new()
	cause_margin.add_theme_constant_override("margin_left", 12)
	cause_margin.add_theme_constant_override("margin_top", 8)
	cause_margin.add_theme_constant_override("margin_right", 12)
	cause_margin.add_theme_constant_override("margin_bottom", 8)
	cause_panel.add_child(cause_margin)
	cause_label = Label.new()
	cause_label.text = "치명상 원인 확인 중"
	cause_label.add_theme_font_override("font", FONT)
	cause_label.add_theme_font_size_override("font_size", 14)
	cause_label.add_theme_color_override("font_color", Color("#e7b5a5"))
	cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cause_margin.add_child(cause_label)
	var stats_row := HBoxContainer.new()
	stats_row.name = "GameOverStats"
	stats_row.add_theme_constant_override("separation", 10)
	box.add_child(stats_row)
	survival_value = _add_stat_card(
		stats_row, "time", "생존 시간", Color("#d9bd72")
	)
	kills_value = _add_stat_card(
		stats_row, "weapon", "처치", Color("#df866e")
	)
	damage_value = _add_stat_card(
		stats_row, "health", "가한 피해", Color("#8ac5ad")
	)

	var loss_heading := HBoxContainer.new()
	loss_heading.add_theme_constant_override("separation", 8)
	box.add_child(loss_heading)
	var loss_heading_icon := TextureRect.new()
	loss_heading_icon.texture = UI_ICONS.get_icon("backpack", 26, Color("#d9c08b"))
	loss_heading_icon.custom_minimum_size = Vector2(26, 26)
	loss_heading_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loss_heading_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	loss_heading.add_child(loss_heading_icon)
	var loss_title := Label.new()
	loss_title.text = "현장에 남긴 휴대품"
	loss_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_title.add_theme_font_override("font", FONT)
	loss_title.add_theme_font_size_override("font_size", 18)
	loss_title.add_theme_color_override("font_color", Color("#e0c99d"))
	loss_heading.add_child(loss_title)
	loss_count_label = Label.new()
	loss_count_label.text = "0종"
	loss_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_count_label.add_theme_font_override("font", FONT)
	loss_count_label.add_theme_font_size_override("font_size", 13)
	loss_count_label.add_theme_color_override("font_color", Color("#91a49d"))
	loss_heading.add_child(loss_count_label)
	loss_value_label = Label.new()
	loss_value_label.text = "가치 0"
	loss_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_value_label.add_theme_font_override("font", FONT)
	loss_value_label.add_theme_font_size_override("font_size", 13)
	loss_value_label.add_theme_color_override("font_color", Color("#d7b96d"))
	loss_heading.add_child(loss_value_label)
	var loss_frame := PanelContainer.new()
	loss_frame.custom_minimum_size.y = 112
	loss_frame.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#080d0d"), Color("#30453e"), 6)
	)
	box.add_child(loss_frame)
	var loss_margin := MarginContainer.new()
	loss_margin.add_theme_constant_override("margin_left", 10)
	loss_margin.add_theme_constant_override("margin_top", 8)
	loss_margin.add_theme_constant_override("margin_right", 10)
	loss_margin.add_theme_constant_override("margin_bottom", 8)
	loss_frame.add_child(loss_margin)
	var loss_scroll := ScrollContainer.new()
	loss_scroll.custom_minimum_size.y = 94
	loss_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	loss_margin.add_child(loss_scroll)
	loss_grid = HFlowContainer.new()
	loss_grid.name = "GameOverLossGrid"
	loss_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_grid.add_theme_constant_override("h_separation", 8)
	loss_grid.add_theme_constant_override("v_separation", 8)
	loss_scroll.add_child(loss_grid)

	var recovery_banner := PanelContainer.new()
	recovery_banner.name = "GameOverRecoveryBanner"
	recovery_banner.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#111b19"), Color("#55796c"), 6)
	)
	box.add_child(recovery_banner)
	var recovery_margin := MarginContainer.new()
	recovery_margin.add_theme_constant_override("margin_left", 12)
	recovery_margin.add_theme_constant_override("margin_top", 8)
	recovery_margin.add_theme_constant_override("margin_right", 12)
	recovery_margin.add_theme_constant_override("margin_bottom", 8)
	recovery_banner.add_child(recovery_margin)
	var recovery_row := HBoxContainer.new()
	recovery_row.add_theme_constant_override("separation", 10)
	recovery_margin.add_child(recovery_row)
	var recovery_icon := TextureRect.new()
	recovery_icon.texture = UI_ICONS.get_icon("secure", 34, Color("#8ec9ad"))
	recovery_icon.custom_minimum_size = Vector2(34, 34)
	recovery_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recovery_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	recovery_row.add_child(recovery_icon)
	loss_label = Label.new()
	loss_label.name = "GameOverLossLabel"
	loss_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loss_label.add_theme_font_override("font", FONT)
	loss_label.add_theme_font_size_override("font_size", 14)
	loss_label.add_theme_color_override("font_color", Color("#b8cdc3"))
	loss_label.text = "다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다."
	recovery_row.add_child(loss_label)

	var continue_separator := HSeparator.new()
	continue_separator.modulate = Color(0.45, 0.54, 0.49, 0.42)
	box.add_child(continue_separator)
	continue_label = Label.new()
	continue_label.text = "SPACE / 화면 터치  ·  쉘터로 복귀"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_override("font", FONT)
	continue_label.add_theme_font_size_override("font_size", 15)
	continue_label.add_theme_color_override("font_color", Color("#a9c8ba"))
	box.add_child(continue_label)


func _add_stat_card(
	parent: HBoxContainer,
	icon_name: String,
	caption: String,
	accent: Color
) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 72
	card.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#111817"), accent.darkened(0.42), 6)
	)
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UI_ICONS.get_icon(icon_name, 32, accent)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_override("font", FONT)
	caption_label.add_theme_font_size_override("font_size", 12)
	caption_label.add_theme_color_override("font_color", Color("#82968e"))
	labels.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = "-"
	value_label.add_theme_font_override("font", FONT)
	value_label.add_theme_font_size_override("font_size", 23)
	value_label.add_theme_color_override("font_color", accent)
	labels.add_child(value_label)
	return value_label


func populate_loss_icons(loot: Dictionary) -> void:
	for child in loss_grid.get_children():
		child.free()
	var entries: Array[Dictionary] = []
	for weapon_id in (loot.get("weapon_inventory", {}) as Dictionary):
		var count := int((loot.get("weapon_inventory", {}) as Dictionary).get(weapon_id, 0))
		if count > 0:
			entries.append({"name": _get_loot_weapon_name(str(weapon_id)), "count": count, "texture": WEAPON_VISUAL_CATALOG.get_weapon_texture(str(weapon_id))})
	for equipment_id in (loot.get("equipment_inventory", {}) as Dictionary):
		var count := int((loot.get("equipment_inventory", {}) as Dictionary).get(equipment_id, 0))
		if count > 0:
			var definition := GameState.get_equipment_definition(str(equipment_id))
			var texture := load(str(definition.get("texture_path", ""))) as Texture2D
			entries.append({"name": str(definition.get("display_name", equipment_id)), "count": count, "texture": texture})
	var simple := [
		["ammo_inventory", "탄약", "ammo"],
		["mod_component_inventory", "부품", "parts"],
		["weapon_mod_inventory", "부착물", "mod"],
	]
	for spec in simple:
		var count := 0
		for amount in (loot.get(spec[0], {}) as Dictionary).values():
			count += int(amount)
		if count > 0:
			entries.append({"name": spec[1], "count": count, "texture": UI_ICONS.get_icon(spec[2], 64)})
	for spec in [["medkits", "구급약", "medkit"], ["canned_food", "통조림", "food"], ["churu", "츄르", "churu"]]:
		var count := int(loot.get(spec[0], 0))
		if count > 0:
			entries.append({"name": spec[1], "count": count, "texture": UI_ICONS.get_icon(spec[2], 64)})
	var lost_cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not lost_cargo.is_empty():
		entries.append({
			"name": str(lost_cargo.get("title", "봉인된 지하철 화물")),
			"count": 1,
			"texture": SUBWAY_SEALED_CARGO_TEXTURE,
		})
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "분실한 휴대품이 없습니다."
		empty.custom_minimum_size = Vector2(240, 78)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color("#81948d"))
		loss_grid.add_child(empty)
		loss_count_label.text = "없음"
		return
	loss_count_label.text = "%d종" % entries.size()
	for entry in entries:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(106, 90)
		card.add_theme_stylebox_override(
			"panel",
			HudStyle.panel(Color("#111817"), Color("#344a42"), 5)
		)
		loss_grid.add_child(card)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 7)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 7)
		margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 2)
		margin.add_child(content)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture = entry.get("texture") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = str(entry.get("name", "휴대품"))
		content.add_child(icon)
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 4)
		content.add_child(item_row)
		var name_label := Label.new()
		name_label.text = str(entry.get("name", "휴대품"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color("#b7c6c0"))
		item_row.add_child(name_label)
		var count_label := Label.new()
		count_label.text = "x%d" % int(entry.get("count", 0))
		count_label.add_theme_font_override("font", FONT)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color("#d9bd72"))
		item_row.add_child(count_label)



func _get_loot_weapon_name(weapon_id: String) -> String:
	match weapon_id:
		"m1911": return "M1911"
		"mp5": return "MP5"
		"double_barrel": return "Shotgun"
		"baseball_bat": return "Bat"
		_: return "AK-47"



func present(result: Dictionary) -> void:
	# 사망 시점의 결과를 한 번에 채운다. 예전에는 이 열 줄이
	# _begin_player_death_sequence 안에 흩어져 있었다.
	canvas.visible = true
	title_label.text = "작전 실패"
	survival_value.text = str(result.get("survival_time", "00:00"))
	kills_value.text = "%d" % int(result.get("kills", 0))
	damage_value.text = str(result.get("damage_text", "0"))
	var cause := "치명상 · %s  /  %s" % [
		result.get("source_name", "?"),
		result.get("weapon_name", "?"),
	]
	var blocked := int(result.get("blocked", 0))
	if blocked > 0:
		cause += "  ·  방어구가 마지막 공격에서 %d 방어" % blocked
	var lesson := str(result.get("lesson", ""))
	if not lesson.is_empty():
		cause += "\n%s" % lesson
	cause_label.text = cause
	loss_value_label.text = "회수 가치 %s" % result.get("loss_value_text", "0")
	loss_label.text = "휴대품은 현장에 남았습니다. 다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다."
	populate_loss_icons(result.get("loot", {}) as Dictionary)
	ready_to_continue = false
	continue_started = false


func apply_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	panel.custom_minimum_size = Vector2(
		minf(viewport_size.x - 40.0, 760.0),
		minf(viewport_size.y - 40.0, 500.0)
	)


func can_continue() -> bool:
	return ready_to_continue and not continue_started


func mark_continue_started() -> void:
	continue_started = true
