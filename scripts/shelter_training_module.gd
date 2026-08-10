class_name ShelterTrainingModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")

@export var interaction_radius := 4.1

@onready var sprite: Sprite3D = $TrainingSprite

var ui_layer: CanvasLayer
var content: VBoxContainer
var status_label: Label
var compact_layout := false
var narrow_layout := false


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("training_facility")
	set_meta("module_kind", "training")


func get_interaction_prompt() -> String:
	return "훈련장 · 통조림으로 능력치 강화"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	_open_ui()
	return "통조림을 투자해 플레이어 능력을 영구 강화합니다."


func set_interaction_focus(value: bool) -> void:
	if sprite:
		sprite.modulate = Color(1.08, 1.08, 0.88, 1.0) if value else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "TrainingFacilityUILayer"
	ui_layer.layer = 90
	ui_layer.add_to_group("shelter_modal_ui")
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(ui_layer)
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.006, 0.006, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	var available_size := Vector2(
		viewport_size.x - safe.x - safe.z,
		viewport_size.y - safe.y - safe.w
	)
	compact_layout = viewport_size.x < 1040.0 or viewport_size.y < 680.0
	narrow_layout = viewport_size.x < 760.0
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = safe.x
	center.offset_top = safe.y
	center.offset_right = -safe.z
	center.offset_bottom = -safe.w
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "TrainingPanel"
	panel.custom_minimum_size = Vector2(
		minf(1120.0, available_size.x - 32.0),
		minf(780.0, available_size.y - 32.0)
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.02, 0.019, 0.98), Color("#8fa164"), 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	var inner_margin := 12 if compact_layout else 24
	margin.add_theme_constant_override("margin_left", inner_margin)
	margin.add_theme_constant_override("margin_top", inner_margin)
	margin.add_theme_constant_override("margin_right", inner_margin)
	margin.add_theme_constant_override("margin_bottom", inner_margin)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10 if compact_layout else 14)
	margin.add_child(content)
	_rebuild_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ui_layer) or not ui_layer.is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		ui_layer.queue_free()
		get_viewport().set_input_as_handled()


func _rebuild_ui() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var header := VBoxContainer.new()
	header.name = "TrainingHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_theme_constant_override("separation", 5)
	content.add_child(header)
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title := _label("생존 체력 훈련장", 24 if compact_layout else 30, Color("#e7d58f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(title)
	var resource_panel := SHELTER_UI.make_currency_chip(
		"food",
		GameState.format_compact_number(GameState.canned_food),
		compact_layout,
		not narrow_layout
	)
	resource_panel.custom_minimum_size.x = 104 if compact_layout else 148
	resource_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var resource_value := resource_panel.find_child("ResourceValue_food", true, false) as Label
	if resource_value != null:
		resource_value.name = "TrainingResourceLabel"
	top_row.add_child(resource_panel)
	var close := _close_button()
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: ui_layer.queue_free())
	top_row.add_child(close)
	var subtitle := _label(
		"레이드에서 확보한 통조림을 훈련에 투자해 영구 능력을 개방합니다.",
		14 if compact_layout else 15,
		Color("#9eafa6")
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(subtitle)

	var summary := GridContainer.new()
	summary.columns = 2 if narrow_layout or compact_layout else 4
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 10)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	_add_summary_chip(summary, "health", "최대 체력", "%d" % GameState.get_max_health(), Color("#e87668"))
	_add_summary_chip(summary, "stamina", "스태미나", "%d" % roundi(GameState.get_max_stamina()), Color("#e4ca6c"))
	_add_summary_chip(summary, "speed", "이동 배율", "x%.2f" % GameState.get_move_speed_multiplier(), Color("#77c5a1"))
	_add_summary_chip(summary, "fitness", "피로 획득", "x%.2f" % GameState.get_fatigue_gain_multiplier(), Color("#8db5d1"))

	var divider := HSeparator.new()
	content.add_child(divider)
	var section_row := HBoxContainer.new()
	section_row.add_theme_constant_override("separation", 8)
	content.add_child(section_row)
	var section_title := _label("영구 강화", 19 if compact_layout else 21, Color("#dce4dc"))
	section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_row.add_child(section_title)
	var section_hint := _label("카드를 눌러 즉시 훈련", 12, Color("#82958c"))
	section_hint.name = "TrainingSectionHint"
	section_hint.custom_minimum_size = Vector2(150, 0)
	section_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	section_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	section_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	section_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	section_row.add_child(section_hint)
	var scroll := ScrollContainer.new()
	scroll.name = "TrainingTreeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	content.add_child(scroll)
	var tree := GridContainer.new()
	tree.name = "TrainingTreeGrid"
	tree.columns = 1 if narrow_layout else 2
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.add_theme_constant_override("h_separation", 12)
	tree.add_theme_constant_override("v_separation", 10)
	scroll.add_child(tree)
	_add_training_card(tree, "vitality")
	_add_training_card(tree, "recovery")
	_add_training_card(tree, "endurance")
	_add_training_card(tree, "agility")
	_add_training_card(tree, "fieldcraft")
	status_label = _label("", 13, Color("#9db0a6"))
	status_label.name = "TrainingStatus"
	status_label.custom_minimum_size.y = 18
	content.add_child(status_label)


func _add_summary_chip(parent: Container, icon_name: String, title: String, value: String, color: Color) -> void:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 68 if compact_layout else 76)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _panel_style(Color("#101716"), Color(0.43, 0.52, 0.48, 0.45), 6))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture = UI_ICONS.get_icon(icon_name, 42, color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(_label(title, 13, Color("#92a39b")))
	text_box.add_child(_label(value, 20, Color("#e6ece7")))
	row.add_child(text_box)


func _add_training_card(parent: GridContainer, node_id: String) -> void:
	var definition := GameState.get_training_definition(node_id)
	var rank := GameState.get_training_rank(node_id)
	var max_rank := int(definition.get("max_rank", 1))
	var cost := GameState.get_training_cost(node_id)
	var requirements_met := GameState.get_training_requirements_met(node_id)
	var card := Button.new()
	card.name = "TrainingCard_%s" % node_id
	card.custom_minimum_size = Vector2(0, 118 if compact_layout else 132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.text = ""
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_font_override("font", FONT)
	card.add_theme_stylebox_override("normal", _panel_style(Color("#101514"), Color("#596760"), 7))
	card.add_theme_stylebox_override("hover", _panel_style(Color("#1b231d"), Color("#d6c36f"), 7))
	card.add_theme_stylebox_override("pressed", _panel_style(Color("#292a1c"), Color("#f0d77d"), 7))
	card.add_theme_stylebox_override("disabled", _panel_style(Color("#0b0f0e"), Color("#343d39"), 7))
	card.disabled = rank >= max_rank or not requirements_met
	card.pressed.connect(_upgrade_training.bind(node_id))
	parent.add_child(card)

	var card_body := HBoxContainer.new()
	card_body.name = "CardBody"
	card_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_body.offset_left = 14
	card_body.offset_top = 12
	card_body.offset_right = -14
	card_body.offset_bottom = -12
	card_body.add_theme_constant_override("separation", 14)
	card.add_child(card_body)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#161d1a"), Color(0.62, 0.55, 0.29, 0.62), 6)
	)
	card_body.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = UI_ICONS.get_icon(
		str(definition.get("icon", "fitness")),
		58,
		Color("#d9c874") if requirements_met else Color("#69746f")
	)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_panel.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	card_body.add_child(details)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 8)
	details.add_child(title_row)
	var title := _label(
		str(definition.get("title", node_id)),
		16 if compact_layout else 18,
		Color("#e5eadf") if requirements_met else Color("#7f8b85")
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	var rank_label := _label(
		"%d / %d" % [rank, max_rank],
		13 if compact_layout else 14,
		Color("#d8c674") if rank < max_rank else Color("#78b791")
	)
	rank_label.name = "Rank"
	rank_label.custom_minimum_size = Vector2(52, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(rank_label)

	var description := _label(
		str(definition.get("description", "")),
		12 if compact_layout else 13,
		Color("#9eaaa4") if requirements_met else Color("#65706b")
	)
	description.name = "TrainingCardDescription_%s" % node_id
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 6)
	details.add_child(action_row)
	var action_icon := TextureRect.new()
	action_icon.custom_minimum_size = Vector2(20, 20)
	action_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	action_row.add_child(action_icon)
	var action_label := _label("", 12 if compact_layout else 13, Color("#efbd66"))
	action_label.name = "Action"
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_row.add_child(action_label)
	if rank >= max_rank:
		action_icon.texture = UI_ICONS.get_icon("upgrade", 24, Color("#78b791"))
		action_label.text = "최대 강화 완료"
		action_label.add_theme_color_override("font_color", Color("#78b791"))
	elif not requirements_met:
		action_icon.texture = UI_ICONS.get_icon("alert", 24, Color("#7f8b85"))
		action_label.text = "선행 필요 · %s" % _training_requirement_text(definition)
		action_label.add_theme_color_override("font_color", Color("#7f8b85"))
	else:
		action_icon.texture = UI_ICONS.get_icon("food", 24, Color("#efbd66"))
		action_label.text = "x%d 필요" % cost
	_set_mouse_passthrough(card_body)


func _training_requirement_text(definition: Dictionary) -> String:
	var requirements := definition.get("requires", {}) as Dictionary
	var labels: Array[String] = []
	for required_id in requirements.keys():
		var required_definition := GameState.get_training_definition(str(required_id))
		labels.append(
			"%s %d단계" % [
				str(required_definition.get("title", required_id)),
				int(requirements[required_id]),
			]
		)
	return " · ".join(labels) if not labels.is_empty() else "기초 훈련"


func _set_mouse_passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_mouse_passthrough(child as Control)


func _upgrade_training(node_id: String) -> void:
	var result := GameState.try_upgrade_training(node_id)
	if bool(result.get("ok", false)):
		call_deferred("_rebuild_ui")
		return
	var reason := str(result.get("reason", ""))
	status_label.text = (
		"통조림이 부족합니다. 필요 수량: %d" % int(result.get("cost", 0))
		if reason == "canned_food"
		else "선행 강화를 먼저 완료해야 합니다."
	)


func _button(text: String, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, Color("#dce5df"))
		button.expand_icon = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#111716"), Color("#64766d"), 6))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#1b2420"), Color("#d9c579"), 6))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#29291b"), Color("#e2c66e"), 6))
	return button


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce5df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style
