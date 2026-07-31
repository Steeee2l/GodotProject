class_name LootSwapUI
extends Control

signal discard_requested(entry: Dictionary)
signal claim_requested
signal closed

const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

var font_ref: Font
var backdrop: ColorRect
var panel: PanelContainer
var capacity_cells: HBoxContainer
var capacity_label: Label
var candidate_icon: TextureRect
var candidate_title: Label
var candidate_detail: Label
var item_grid: GridContainer
var claim_button: Button
var feedback_label: Label
var candidate_data: Dictionary = {}


func setup(font: Font) -> void:
	font_ref = font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 4050
	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	visible = false
	call_deferred("_apply_layout")


func open(candidate: Dictionary, entries: Array[Dictionary], used: int, capacity: int) -> void:
	candidate_data = candidate.duplicate(true)
	visible = true
	feedback_label.text = ""
	_refresh(candidate, entries, used, capacity)
	_apply_layout()


func close() -> void:
	visible = false
	candidate_data.clear()
	closed.emit()


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = PanelContainer.new()
	panel.name = "LootSwapPanel"
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.025, 0.03, 0.032, 0.99), Color("#d19a4d"), 8)
	)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var title := _label("가방 정리", 27, Color("#f1d287"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(46, 42)
	close_button.icon = UI_ICONS.get_icon("close", 28, Color("#d8dfda"))
	close_button.tooltip_text = "닫기"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#101716"), Color("#62756d"), 6)
	)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var capacity_row := HBoxContainer.new()
	capacity_row.add_theme_constant_override("separation", 10)
	content.add_child(capacity_row)
	capacity_cells = HBoxContainer.new()
	capacity_cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_cells.add_theme_constant_override("separation", 3)
	capacity_row.add_child(capacity_cells)
	capacity_label = _label("0 / 15칸", 14, Color("#c8d3ce"))
	capacity_label.custom_minimum_size = Vector2(100, 28)
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capacity_row.add_child(capacity_label)

	var candidate_panel := PanelContainer.new()
	candidate_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#17130d"), Color("#e5ad54"), 7)
	)
	content.add_child(candidate_panel)
	var candidate_margin := MarginContainer.new()
	candidate_margin.add_theme_constant_override("margin_left", 14)
	candidate_margin.add_theme_constant_override("margin_top", 12)
	candidate_margin.add_theme_constant_override("margin_right", 14)
	candidate_margin.add_theme_constant_override("margin_bottom", 12)
	candidate_panel.add_child(candidate_margin)
	var candidate_row := HBoxContainer.new()
	candidate_row.add_theme_constant_override("separation", 14)
	candidate_margin.add_child(candidate_row)
	candidate_icon = TextureRect.new()
	candidate_icon.custom_minimum_size = Vector2(86, 86)
	candidate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candidate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	candidate_row.add_child(candidate_icon)
	var candidate_copy := VBoxContainer.new()
	candidate_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	candidate_row.add_child(candidate_copy)
	candidate_title = _label("", 21, Color("#f3dfad"))
	candidate_copy.add_child(candidate_title)
	candidate_detail = _label("", 14, Color("#c6b991"))
	candidate_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_copy.add_child(candidate_detail)
	claim_button = Button.new()
	claim_button.custom_minimum_size = Vector2(150, 58)
	claim_button.text = "획득"
	claim_button.icon = UI_ICONS.get_icon("backpack", 28, Color("#1b211d"))
	claim_button.expand_icon = true
	claim_button.focus_mode = Control.FOCUS_NONE
	claim_button.add_theme_font_override("font", font_ref)
	claim_button.add_theme_font_size_override("font_size", 17)
	claim_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#d5a451"), Color("#f3cf7a"), 6)
	)
	claim_button.add_theme_color_override("font_color", Color("#161813"))
	claim_button.pressed.connect(func() -> void: claim_requested.emit())
	candidate_row.add_child(claim_button)

	var section := _label("가방에서 내놓을 물건", 16, Color("#b8c8c0"))
	content.add_child(section)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	item_grid = GridContainer.new()
	item_grid.columns = 2
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(item_grid)

	feedback_label = _label("", 13, Color("#ff9d82"))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(feedback_label)


func _refresh(candidate: Dictionary, entries: Array[Dictionary], used: int, capacity: int) -> void:
	for child in capacity_cells.get_children():
		child.queue_free()
	var required := maxi(0, int(candidate.get("required_slots", 1)))
	for index in capacity:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(18, 22)
		var fill := Color("#456c5b") if index < used else Color("#151c1a")
		if index >= used and index < used + required:
			fill = Color("#d09245")
		cell.add_theme_stylebox_override("panel", _panel_style(fill, Color("#6f8178"), 3))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		capacity_cells.add_child(cell)
	capacity_label.text = "%d / %d칸" % [used, capacity]
	capacity_label.add_theme_color_override(
		"font_color",
		Color("#ff8f7e") if used + required > capacity else Color("#c8d3ce")
	)
	candidate_icon.texture = candidate.get("texture") as Texture2D
	candidate_title.text = str(candidate.get("title", "전리품"))
	candidate_detail.text = "%s\n가방 %d칸 필요" % [
		str(candidate.get("description", "")),
		required,
	]
	claim_button.disabled = used + required > capacity
	claim_button.text = "획득 가능" if not claim_button.disabled else "%d칸 부족" % (used + required - capacity)

	for child in item_grid.get_children():
		child.queue_free()
	for entry in entries:
		if str(entry.get("type", "")) in ["special_cargo", "mod"]:
			continue
		item_grid.add_child(_entry_button(entry))
	if item_grid.get_child_count() == 0:
		var empty := _label("내놓을 수 있는 휴대품이 없습니다.", 14, Color("#819188"))
		empty.custom_minimum_size = Vector2(0, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_grid.add_child(empty)


func _entry_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 82)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s  x%d\n%d칸 사용  ·  %d개 내놓기" % [
		str(entry.get("title", entry.get("id", "아이템"))),
		int(entry.get("count", 0)),
		int(entry.get("slot_cost", 1)),
		int(entry.get("drop_amount", 1)),
	]
	button.icon = entry.get("texture") as Texture2D
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font_ref)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#0d1312"), Color("#465951"), 6)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color("#18120e"), Color("#d09a4f"), 6)
	)
	button.pressed.connect(func() -> void: discard_requested.emit(entry))
	return button


func show_feedback(message: String) -> void:
	feedback_label.text = message


func _apply_layout() -> void:
	if panel == null:
		return
	var viewport := get_viewport_rect().size
	var width := clampf(viewport.x - 36.0, 520.0, 920.0)
	var height := clampf(viewport.y - 32.0, 480.0, 660.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_right = width * 0.5
	panel.offset_bottom = height * 0.5
	item_grid.columns = 1 if width < 700.0 else 2


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", font_ref)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
