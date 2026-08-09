class_name CatnipScraperModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const RESIDENT_PORTRAITS := preload("res://scripts/resident_portrait_catalog.gd")

@export var interaction_radius := 4.0

@onready var sprite: Sprite3D = $ScraperSprite

var ui_layer: CanvasLayer
var content: VBoxContainer


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("catnip_scraper")
	set_meta("module_kind", "catnip_scraper")


func get_interaction_prompt() -> String:
	return "스크래핑 캣닢 생산기"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	_open_ui()
	return "주민을 배치해 캣닢을 자동 생산합니다."


func set_interaction_focus(value: bool) -> void:
	if sprite:
		sprite.modulate = Color(0.92, 1.16, 0.9, 1.0) if value else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CatnipScraperUILayer"
	ui_layer.layer = 80
	ui_layer.add_to_group("shelter_modal_ui")
	var ui_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	ui_parent.add_child(ui_layer)
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.006, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	var available_size := Vector2(
		viewport_size.x - safe.x - safe.z,
		viewport_size.y - safe.y - safe.w
	)
	var outer_margin := 10 if viewport_size.y < 640.0 else 22
	safe_margin.add_theme_constant_override("margin_left", roundi(outer_margin + safe.x))
	safe_margin.add_theme_constant_override("margin_top", roundi(outer_margin + safe.y))
	safe_margin.add_theme_constant_override("margin_right", roundi(outer_margin + safe.z))
	safe_margin.add_theme_constant_override("margin_bottom", roundi(outer_margin + safe.w))
	modal.add_child(safe_margin)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "CatnipScraperPanel"
	panel.custom_minimum_size = Vector2(
		minf(940.0, available_size.x - outer_margin * 2.0),
		minf(610.0, available_size.y - outer_margin * 2.0)
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.019, 0.97), Color("#6fa66d")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	var inner_margin := 12 if viewport_size.y < 640.0 else 20
	margin.add_theme_constant_override("margin_left", inner_margin)
	margin.add_theme_constant_override("margin_top", inner_margin)
	margin.add_theme_constant_override("margin_right", inner_margin)
	margin.add_theme_constant_override("margin_bottom", inner_margin)
	panel.add_child(margin)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "CatnipScraperScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(panel_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = maxf(300.0, panel.custom_minimum_size.x - inner_margin * 2.0 - 12.0)
	content.add_theme_constant_override("separation", 10 if viewport_size.y < 640.0 else 14)
	panel_scroll.add_child(content)
	_rebuild_ui()


func _rebuild_ui() -> void:
	GameState._ensure_resident_records()
	for child in content.get_children():
		child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 760.0
	var compact := viewport_size.x < 1040.0 or viewport_size.y < 680.0
	var header := VBoxContainer.new()
	header.name = "CatnipScraperHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	title_box.add_child(_label("스크래핑 캣닢 생산기  Lv.%d" % GameState.catnip_scraper_level, 26, Color("#d9efb0")))
	title_box.add_child(_label("캣닢 특화 주민이 부스터 자원을 생산합니다.", 13, Color("#94aa98")))
	var close := _close_button()
	close.pressed.connect(func(): ui_layer.queue_free())
	top_row.add_child(close)
	var wallet := HFlowContainer.new()
	wallet.name = "CatnipScraperWallet"
	wallet.add_theme_constant_override("h_separation", 8)
	wallet.add_theme_constant_override("v_separation", 6)
	header.add_child(wallet)
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"catnip",
		GameState.format_compact_number(GameState.catnip),
		compact,
		not narrow
	))
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"scrap",
		GameState.format_compact_number(GameState.scrap),
		compact,
		not narrow
	))
	var summary := GridContainer.new()
	summary.name = "CatnipScraperSummary"
	summary.columns = 1 if narrow else 2
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	summary.add_child(_summary_card("초당 생산", GameState.format_compact_number(GameState.get_catnip_per_second()), "catnip", compact))
	summary.add_child(_summary_card(
		"작업자",
		"%d / %d명" % [GameState.get_active_catnip_workers(), GameState.get_catnip_worker_slots()],
		"resident",
		compact
	))

	var body: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	body.name = "CatnipScraperBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var resident_panel := PanelContainer.new()
	resident_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resident_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resident_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.024, 0.036, 0.027, 0.92), Color("#45614a")))
	body.add_child(resident_panel)
	var resident_margin := MarginContainer.new()
	resident_margin.add_theme_constant_override("margin_left", 12)
	resident_margin.add_theme_constant_override("margin_top", 10)
	resident_margin.add_theme_constant_override("margin_right", 12)
	resident_margin.add_theme_constant_override("margin_bottom", 10)
	resident_panel.add_child(resident_margin)
	var resident_box := VBoxContainer.new()
	resident_box.add_theme_constant_override("separation", 8)
	resident_margin.add_child(resident_box)
	resident_box.add_child(_label("주민 배치", 16, Color("#dfe8dc")))
	if GameState.resident_cat_ids.is_empty():
		resident_box.add_child(_empty_resident_state(
			"구출한 주민이 없습니다.",
			"캣닢 생산에 배치할 주민을 도시에서 구출하세요.",
			compact
		))
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 152 if compact and not narrow else 220)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		resident_box.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 1 if narrow else 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 9)
		grid.add_theme_constant_override("v_separation", 9)
		scroll.add_child(grid)
		for resident_index in GameState.resident_cat_ids.size():
			grid.add_child(_resident_button(str(GameState.resident_cat_ids[resident_index])))

	var operations := PanelContainer.new()
	operations.custom_minimum_size = Vector2(0 if narrow else (230 if compact else 246), 0)
	operations.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.041, 0.03, 0.94), Color("#50664f")))
	body.add_child(operations)
	var operations_margin := MarginContainer.new()
	operations_margin.add_theme_constant_override("margin_left", 14)
	operations_margin.add_theme_constant_override("margin_top", 12)
	operations_margin.add_theme_constant_override("margin_right", 14)
	operations_margin.add_theme_constant_override("margin_bottom", 12)
	operations.add_child(operations_margin)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	operations_margin.add_child(footer)
	footer.add_child(_label("생산 설정", 16, Color("#d9efb0")))
	var upgrade_cost := int(GameState.CATNIP_SCRAPER_UPGRADE_COSTS.get(GameState.catnip_scraper_level + 1, 0))
	var upgrade := _button(
		"최고 레벨"
		if upgrade_cost == 0 else "x%s  ·  Lv.%d 확장" % [
			GameState.format_compact_number(upgrade_cost),
			GameState.catnip_scraper_level + 1,
		],
		"upgrade" if upgrade_cost == 0 else "scrap"
	)
	upgrade.custom_minimum_size = Vector2(0, 38)
	upgrade.disabled = upgrade_cost == 0 or GameState.scrap < upgrade_cost
	upgrade.pressed.connect(_upgrade)
	footer.add_child(upgrade)
	var conversion := HBoxContainer.new()
	conversion.name = "CatnipBoosterRelation"
	conversion.add_theme_constant_override("separation", 8)
	footer.add_child(conversion)
	conversion.add_child(SHELTER_UI.make_currency_chip("catnip", "25", compact, false))
	var boost_text := _label("고철 x10 · 10분", 13, Color("#cde79e"))
	boost_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	conversion.add_child(boost_text)
	var remaining: int = GameState.get_catnip_boost_remaining()
	if remaining > 0:
		footer.add_child(_label("가동 중  %02d:%02d" % [remaining / 60, remaining % 60], 14, Color("#cde79e")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var action_hint := _label("주민 카드를 눌러 배치하거나 해제", 11, Color("#789080"))
	action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(action_hint)


func _resident_button(resident_id: String) -> Button:
	var button := Button.new()
	button.name = "ResidentCard_%s" % resident_id
	button.custom_minimum_size = Vector2(260, 82)
	var active := GameState.assigned_catnip_worker_ids.has(resident_id)
	var available := active or GameState.assigned_catnip_worker_ids.size() < GameState.get_catnip_worker_slots()
	var trait_data: Dictionary = GameState.get_resident_trait(resident_id)
	var border := Color("#7fc779") if active else (Color("#60735c") if available else Color("#343a35"))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.03, 0.045, 0.034, 0.96), border))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.05, 0.075, 0.052, 0.98), Color("#b8dc83")))
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.icon = RESIDENT_PORTRAITS.get_portrait(int(trait_data.get("portrait_index", 0)))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not available
	button.text = "%s · %s\n%s  ·  캣닢 x%.2f  식비 x%.2f" % [
		trait_data.get("display_name", "이름 없는 주민"),
		trait_data.get("name", "평범한 주민"),
		"스크래핑 중" if active else "대기",
		trait_data.get("catnip", 1.0),
		trait_data.get("appetite", 1.0),
	]
	button.pressed.connect(func(): _toggle_worker(resident_id))
	return button


func _toggle_worker(resident_id: String) -> void:
	GameState.toggle_catnip_worker_assignment(resident_id)
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_rebuild_ui()


func _upgrade() -> void:
	if GameState.try_upgrade_catnip_scraper():
		GameState.save_persistent_state()
		_rebuild_ui()


func _button(text: String, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, Color("#dce8df"))
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.05, 0.068, 0.052, 0.96), Color("#617565")))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.08, 0.115, 0.075, 0.98), Color("#a7d683")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.06, 0.095, 0.06, 0.98), Color("#cef08b")))
	return button


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce8df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _empty_resident_state(title: String, description: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CatnipEmptyState"
	panel.custom_minimum_size = Vector2(0, 138 if compact else 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.027, 0.019, 0.78), Color("#314939")))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	center.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.texture = UI_ICONS.get_icon("resident", 48, Color("#67806d"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var title_label := _label(title, 15, Color("#b5c6b8"))
	title_label.name = "EmptyStateTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var description_label := _label(description, 11, Color("#708575"))
	description_label.name = "EmptyStateDescription"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(description_label)
	return panel


func _summary_card(title: String, value: String, icon_name: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 52 if compact else 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.043, 0.032, 0.92), Color("#425a49")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var icon := TextureRect.new()
	var icon_size := 28 if compact else 32
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.texture = UI_ICONS.get_icon(icon_name, 36, Color("#9ec99b"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)
	var title_label := _label(title, 10 if compact else 11, Color("#87998c"))
	var value_label := _label(value, 13 if compact else 15, Color("#e0e9df"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title_label)
	box.add_child(value_label)
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
