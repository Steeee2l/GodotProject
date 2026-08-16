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
var value_summary_label: Label
var item_grid: GridContainer
var claim_button: Button
var auto_discard_button: Button
var feedback_label: Label
var candidate_data: Dictionary = {}
var lowest_value_entry: Dictionary = {}
var dismiss_relay: Node


func setup(font: Font) -> void:
	font_ref = font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 4050
	# 모달이 떠 있는 동안 트리를 멈추므로, 모달 자신(과 하위 트윈·버튼)은
	# 일시정지와 무관하게 동작해야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	# 고민하는 동안 적이 때려죽이던 문제 — 교체 화면은 게임을 멈춘 채 연다.
	get_tree().paused = true
	# ESC·안드로이드 뒤로가기. 모달이 닫힌 뒤에도 ESC를 삼키지 않도록
	# 열려 있는 동안만 장착한다. (딤 탭 닫기는 _build_ui에서 상시 연결)
	if dismiss_relay == null or not is_instance_valid(dismiss_relay):
		dismiss_relay = ModalDismiss.install(self, null, close)


func close() -> void:
	visible = false
	candidate_data.clear()
	get_tree().paused = false
	if is_instance_valid(dismiss_relay):
		dismiss_relay.queue_free()
	dismiss_relay = null
	closed.emit()


func _exit_tree() -> void:
	# 모달이 열린 채 씬이 바뀌어도 게임이 멈춘 채 남지 않게.
	if visible and is_inside_tree():
		get_tree().paused = false


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	# 딤(패널 바깥) 탭 = 닫기 — ModalDismiss와 같은 판정(뗄 때).
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		var released: bool = (
			(event is InputEventMouseButton and not event.pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
			or (event is InputEventScreenTouch and not event.pressed)
		)
		if released:
			close()
	)

	panel = PanelContainer.new()
	panel.name = "LootSwapPanel"
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.025, 0.03, 0.032, 0.99), Color("#d19a4d"), 8)
	)
	add_child(panel)
	# 모달 표준 등장.
	HudStyle.enter_modal(panel)

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
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)
	var title := _label("전리품 교체", 27, Color("#f1d287"))
	title_box.add_child(title)
	# 이 화면이 왜 떴는지 한 줄로 — 처음 보는 유저의 혼란을 줄인다.
	var subtitle := _label(
		"가방이 가득 — 버릴 것을 골라 새 전리품과 교체하세요", 14, Color("#9eb5aa")
	)
	title_box.add_child(subtitle)
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
	candidate_icon.custom_minimum_size = Vector2(64, 76)
	candidate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candidate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	candidate_row.add_child(candidate_icon)
	var candidate_copy := VBoxContainer.new()
	candidate_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	candidate_row.add_child(candidate_copy)
	# "새 전리품" 배지 — 이 카드가 '지금 주우려는 것'임을 못 박는다.
	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#2a2113"), Color("#e5ad54"), 4)
	)
	var badge_label := _label("새 전리품", 11, Color("#eec87c"))
	badge.add_child(badge_label)
	candidate_copy.add_child(badge)
	candidate_title = _label("", 21, Color("#f3dfad"))
	candidate_copy.add_child(candidate_title)
	candidate_detail = _label("", 14, Color("#c6b991"))
	candidate_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_copy.add_child(candidate_detail)
	claim_button = Button.new()
	claim_button.custom_minimum_size = Vector2(118, 58)
	claim_button.text = "획득"
	claim_button.icon = UI_ICONS.get_icon("backpack", 28, Color("#1b211d"))
	claim_button.expand_icon = true
	claim_button.focus_mode = Control.FOCUS_NONE
	claim_button.add_theme_font_override("font", font_ref)
	claim_button.add_theme_font_size_override("font_size", 15)
	claim_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#d5a451"), Color("#f3cf7a"), 6)
	)
	claim_button.add_theme_color_override("font_color", Color("#161813"))
	claim_button.pressed.connect(func() -> void: claim_requested.emit())
	candidate_row.add_child(claim_button)

	value_summary_label = _label("교체 후 가치 변화", 14, Color("#9eb5aa"))
	content.add_child(value_summary_label)

	# 캡션 스타일 — 버튼처럼 보여 눌러 보게 만들던 문구를 안내 문장으로 낮춘다.
	var section := _label("아래 휴대품을 탭하면 바닥에 내려놓습니다", 12, Color("#8fa79b"))
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
	auto_discard_button = Button.new()
	auto_discard_button.text = "가치가 가장 낮은 물건 정리"
	auto_discard_button.icon = UI_ICONS.get_icon("down", 24, Color("#e6c77c"))
	auto_discard_button.expand_icon = true
	auto_discard_button.focus_mode = Control.FOCUS_NONE
	auto_discard_button.add_theme_font_override("font", font_ref)
	auto_discard_button.add_theme_font_size_override("font_size", 14)
	auto_discard_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#17130d"), Color("#9c7845"), 6)
	)
	auto_discard_button.pressed.connect(_discard_lowest_value_entry)
	content.add_child(auto_discard_button)

	feedback_label = _label("", 13, Color("#ff9d82"))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(feedback_label)


func _refresh(candidate: Dictionary, entries: Array[Dictionary], used: int, capacity: int) -> void:
	for child in capacity_cells.get_children():
		child.queue_free()
	var required := maxi(0, int(candidate.get("required_slots", 1)))
	for index in capacity:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(10, 22)
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
	var total_value := int(candidate.get("total_value", 0))
	var value_per_slot := int(round(float(candidate.get("value_per_slot", 0.0))))
	candidate_detail.text = "%s\n가방 %d칸 · 가치 %d · 칸당 %d" % [
		str(candidate.get("description", "")),
		maxi(1, int(candidate.get("display_slots", required))),
		total_value,
		value_per_slot,
	]
	claim_button.disabled = used + required > capacity
	claim_button.text = "바로 획득" if not claim_button.disabled else "%d칸 부족" % (used + required - capacity)

	for child in item_grid.get_children():
		child.queue_free()
	lowest_value_entry.clear()
	var bag_value := 0
	var lowest_value_per_slot := INF
	for entry in entries:
		bag_value += int(entry.get("total_value", 0))
		if not bool(entry.get("protected", false)):
			var entry_value_per_slot := float(entry.get("value_per_slot", 0.0))
			if entry_value_per_slot < lowest_value_per_slot:
				lowest_value_per_slot = entry_value_per_slot
				lowest_value_entry = entry.duplicate(true)
		item_grid.add_child(_entry_button(entry))
	var value_delta := total_value
	if claim_button.disabled and not lowest_value_entry.is_empty():
		value_delta -= int(lowest_value_entry.get("drop_value", 0))
	value_summary_label.text = "현재 가방 가치 %d  ·  교체 예상 %s%d" % [
		bag_value,
		"+" if value_delta >= 0 else "",
		value_delta,
	]
	value_summary_label.add_theme_color_override(
		"font_color",
		Color("#81d7aa") if value_delta >= 0 else Color("#ff9d82")
	)
	auto_discard_button.visible = claim_button.disabled and not lowest_value_entry.is_empty()
	if auto_discard_button.visible:
		auto_discard_button.text = "낮은 가치 물품 정리 · %s" % str(
			lowest_value_entry.get("title", "휴대품")
		)
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
	var protected := bool(entry.get("protected", false))
	button.text = "%s  x%d%s\n%d칸 · 가치 %d · 칸당 %d" % [
		str(entry.get("title", entry.get("id", "아이템"))),
		int(entry.get("count", 0)),
		"  [보호]" if protected else "",
		int(entry.get("slot_cost", 1)),
		int(entry.get("total_value", 0)),
		int(round(float(entry.get("value_per_slot", 0.0)))),
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
	button.disabled = protected
	button.tooltip_text = (
		"중요 물품은 전리품 교체 중 버릴 수 없습니다."
		if protected
		else "%s\n탭하면 %d개를 바닥에 내려놓습니다." % [
			str(entry.get("description", "")),
			int(entry.get("drop_amount", 1)),
		]
	)
	button.pressed.connect(func() -> void: discard_requested.emit(entry))
	return button


func _discard_lowest_value_entry() -> void:
	if lowest_value_entry.is_empty():
		return
	discard_requested.emit(lowest_value_entry)


func show_feedback(message: String) -> void:
	feedback_label.text = message


func _apply_layout() -> void:
	if panel == null:
		return
	var viewport := get_viewport_rect().size
	var width := minf(920.0, maxf(320.0, viewport.x - 24.0))
	var height := minf(680.0, maxf(420.0, viewport.y - 24.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_right = width * 0.5
	panel.offset_bottom = height * 0.5
	item_grid.columns = 1 if width < 720.0 else 2


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
