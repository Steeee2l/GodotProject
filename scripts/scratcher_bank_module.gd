class_name ScratcherBankModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const RESIDENT_PORTRAITS := preload("res://scripts/resident_portrait_catalog.gd")

@export var interaction_radius := 4.0

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("BankSprite") as Sprite3D

var has_focus := false
var ui_layer: CanvasLayer
var content: VBoxContainer


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("scratcher_bank")
	set_meta("module_kind", "scratcher_bank")


func get_interaction_prompt() -> String:
	return "꾹꾹이 생산기 · 통조림→고철 (주민 배치)"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	_open_ui()
	return "주민의 특성에 따라 고철을 자동 생산합니다."


func set_interaction_focus(value: bool) -> void:
	has_focus = value
	if sprite:
		sprite.modulate = Color(1.14, 1.1, 0.88, 1.0) if has_focus else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "ScratcherBankUILayer"
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
	dim.color = Color(0.004, 0.006, 0.008, 0.78)
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
	panel.name = "ScratcherBankPanel"
	panel.custom_minimum_size = Vector2(
		minf(960.0, available_size.x - outer_margin * 2.0),
		minf(620.0, available_size.y - outer_margin * 2.0)
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.023, 0.02, 0.96), Color("#c29c5b")))
	center.add_child(panel)
	# 모달 표준 등장 — 툭 나타나지 않는다.
	HudStyle.enter_modal(panel)
	var margin := MarginContainer.new()
	var inner_margin := 12 if viewport_size.y < 640.0 else 20
	margin.add_theme_constant_override("margin_left", inner_margin)
	margin.add_theme_constant_override("margin_top", inner_margin)
	margin.add_theme_constant_override("margin_right", inner_margin)
	margin.add_theme_constant_override("margin_bottom", inner_margin)
	panel.add_child(margin)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "ScratcherBankScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(panel_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = maxf(300.0, panel.custom_minimum_size.x - inner_margin * 2.0 - 12.0)
	content.add_theme_constant_override("separation", 10 if viewport_size.y < 640.0 else 16)
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
	header.name = "ScratcherBankHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	title_box.add_child(_label("꾹꾹이 고철 생산기  Lv.%d" % GameState.scratcher_bank_level, 24, Color("#f4ddb2")))
	title_box.add_child(_label("주민을 배치하면 고철이 자동 생산됩니다.", 13, Color("#9eaa9f")))
	var close := _close_button()
	close.pressed.connect(func(): ui_layer.queue_free())
	top_row.add_child(close)
	var wallet := HFlowContainer.new()
	wallet.name = "ScratcherBankWallet"
	wallet.add_theme_constant_override("h_separation", 8)
	wallet.add_theme_constant_override("v_separation", 6)
	header.add_child(wallet)
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"scrap",
		GameState.format_compact_number(GameState.scrap),
		compact,
		not narrow
	))
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"catnip",
		GameState.format_compact_number(GameState.catnip),
		compact,
		not narrow
	))
	var workers: int = GameState.get_active_scratcher_workers()
	var slots: int = GameState.get_scratcher_worker_slots()
	var summary := GridContainer.new()
	summary.name = "ScratcherBankSummary"
	summary.columns = 1 if narrow else 3
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	summary.add_child(_summary_card("시간당", GameState.format_compact_number(GameState.get_scrap_per_hour()), "scrap", compact))
	summary.add_child(_summary_card("작업자", "%d / %d명" % [workers, slots], "resident", compact))
	summary.add_child(_summary_card("생산 배율", "x%.0f" % GameState.get_production_multiplier(), "catnip", compact))

	# ── 좌석 + 벤치 구조 ─────────────────────────────────────────
	# "기계에 고양이를 앉힌다"가 한눈에 읽히게: 위에는 기계의 작업 좌석(슬롯 수만큼,
	# 앉은 고양이 초상화), 아래에는 대기 주민 벤치. 벤치의 고양이를 누르면 좌석에
	# 앉고, 좌석의 고양이를 누르면 일어난다. 두 열 텍스트 카드보다 훨씬 직관적이다.
	var body := VBoxContainer.new()
	body.name = "ScratcherBankBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)

	body.add_child(_label("작업 좌석 · 앉은 고양이가 고철을 만듭니다", 14, Color("#e3decf")))
	var seat_row := HFlowContainer.new()
	seat_row.add_theme_constant_override("h_separation", 8)
	seat_row.add_theme_constant_override("v_separation", 8)
	body.add_child(seat_row)
	var assigned_ids: Array[String] = []
	for worker_id in GameState.assigned_worker_ids:
		assigned_ids.append(str(worker_id))
	for seat_index in slots:
		var seat_id := assigned_ids[seat_index] if seat_index < assigned_ids.size() else ""
		seat_row.add_child(_portrait_card(seat_id, true, slots))

	body.add_child(_label("대기 주민 · 눌러서 좌석에 앉히기 (우클릭: 특성 재굴림)", 13, Color("#9eaa9f")))
	if GameState.resident_cat_ids.is_empty():
		body.add_child(_empty_resident_state(
			"구출한 주민이 없습니다.",
			"도시에서 주민을 구출해 함께 탈출하면 배치할 수 있습니다.",
			compact
		))
	else:
		var bench_scroll := ScrollContainer.new()
		bench_scroll.custom_minimum_size = Vector2(0, 150)
		bench_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bench_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(bench_scroll)
		var bench := HFlowContainer.new()
		bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench.add_theme_constant_override("h_separation", 8)
		bench.add_theme_constant_override("v_separation", 8)
		bench_scroll.add_child(bench)
		for resident_variant in GameState.resident_cat_ids:
			var resident_id := str(resident_variant)
			if assigned_ids.has(resident_id):
				continue  # 이미 좌석에 앉아 있다.
			bench.add_child(_portrait_card(resident_id, false, slots))

	# 생산 설정은 아래 한 줄로. 별도 열을 차지할 만큼의 내용이 아니다.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	var boost_remaining: int = GameState.get_catnip_boost_remaining()
	var boost := _button(
		"가동 중  %02d:%02d" % [boost_remaining / 60, boost_remaining % 60]
		if boost_remaining > 0
		else "캣닢 x%s · 10분 생산 x10" % GameState.format_compact_number(GameState.get_catnip_boost_cost()),
		"catnip"
	)
	boost.disabled = boost_remaining > 0 or GameState.catnip < GameState.get_catnip_boost_cost()
	boost.custom_minimum_size = Vector2(0, 40)
	boost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost.pressed.connect(_activate_boost)
	actions.add_child(boost)
	var upgrade_cost := int(GameState.SCRATCHER_UPGRADE_COSTS.get(GameState.scratcher_bank_level + 1, 0))
	var upgrade := _button(
		"최고 레벨"
		if upgrade_cost == 0 else "고철 x%s · Lv.%d 확장(좌석+1)" % [
			GameState.format_compact_number(upgrade_cost),
			GameState.scratcher_bank_level + 1,
		],
		"upgrade" if upgrade_cost == 0 else "scrap"
	)
	upgrade.disabled = upgrade_cost == 0 or GameState.scrap < upgrade_cost
	upgrade.custom_minimum_size = Vector2(0, 40)
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.pressed.connect(_upgrade)
	actions.add_child(upgrade)
	# 오버클럭: 고철을 다시 생산에 넣는 복리 사다리. "항상 다음에 살 것"을 만든다.
	var overclock_cost := GameState.get_overclock_cost()
	var overclock := _button(
		"오버클럭 Lv.%d · 고철 %s → 시간당 +8%%" % [
			GameState.scratcher_overclock_level,
			GameState.format_compact_number(overclock_cost),
		],
		"upgrade"
	)
	overclock.disabled = GameState.scrap < overclock_cost
	overclock.custom_minimum_size = Vector2(0, 40)
	overclock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overclock.pressed.connect(func() -> void:
		if GameState.try_upgrade_scratcher_overclock():
			_rebuild_ui()
	)
	actions.add_child(overclock)


func _worker_slot(index: int, active_workers: int, slots: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(168, 72)
	var active := index < active_workers
	var unlocked := index < slots
	var bg := Color(0.035, 0.04, 0.033, 0.92)
	var border := Color("#80b887") if active else (Color("#635847") if unlocked else Color("#333333"))
	panel.add_theme_stylebox_override("panel", _panel_style(bg, border))
	var label := _label(
		"작업 중" if active else ("대기 슬롯" if unlocked else "잠김"),
		15,
		Color("#dff0c2") if active else Color("#8f978f")
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _portrait_card(resident_id: String, is_seat: bool, slots: int) -> Button:
	# 초상화가 주인공인 세로 카드. 좌석(위)과 벤치(아래)가 같은 카드를 쓰므로
	# "고양이를 옮겨 앉힌다"는 감각이 유지된다.
	var button := Button.new()
	button.custom_minimum_size = Vector2(104, 128)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var bg := Color(0.035, 0.04, 0.033, 0.92)
	if resident_id.is_empty():
		# 빈 좌석: 여기 앉힐 수 있다는 자리 표시.
		button.name = "SeatEmpty"
		button.icon = UI_ICONS.get_icon("resident", 56, Color("#4c554f"))
		button.text = "빈 좌석"
		button.disabled = true
		button.add_theme_stylebox_override("normal", _panel_style(bg, Color("#3c463f")))
		button.add_theme_stylebox_override("disabled", _panel_style(bg, Color("#3c463f")))
		button.add_theme_color_override("font_disabled_color", Color("#6d7a72"))
		return button
	var trait_data: Dictionary = GameState.get_resident_trait(resident_id)
	var display_name := str(trait_data.get("display_name", "이름 없는 주민"))
	var busy_elsewhere := not is_seat and GameState.assigned_catnip_worker_ids.has(resident_id)
	var seats_free := GameState.assigned_worker_ids.size() < slots
	button.name = "ResidentCard_%s" % resident_id
	button.icon = RESIDENT_PORTRAITS.get_portrait(int(trait_data.get("portrait_index", 0)))
	var border := Color("#80b887") if is_seat else (
		Color("#5b789c") if busy_elsewhere else (Color("#c9ac5e") if seats_free else Color("#635847"))
	)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.08), border.lightened(0.15)))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.05), Color("#f0d16f")))
	button.add_theme_stylebox_override("disabled", _panel_style(bg.darkened(0.08), border.darkened(0.2)))
	if is_seat:
		button.text = "%s\n꾹꾹이 x%.2f" % [display_name, float(trait_data.get("kneading", 1.0))]
	elif busy_elsewhere:
		button.text = "%s\n캣닢 작업 중" % display_name
		button.disabled = true
	else:
		button.text = "%s\n꾹꾹이 x%.2f" % [display_name, float(trait_data.get("kneading", 1.0))]
		button.disabled = not seats_free
	if not button.disabled:
		button.pressed.connect(func(): _toggle_worker(resident_id))
	# 우클릭 = 캣닢으로 특성 재굴림. 상세 수치는 툴팁이 전부 말한다.
	button.gui_input.connect(func(event: InputEvent) -> void:
		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		):
			_reroll_worker(resident_id)
	)
	button.tooltip_text = "%s · %s\n꾹꾹이 x%.2f · 캣닢 x%.2f · 식비 x%.2f\n%s\n우클릭: 특성 재굴림 · 츄르 %s" % [
		display_name,
		str(trait_data.get("name", "")),
		float(trait_data.get("kneading", 1.0)),
		float(trait_data.get("catnip", 1.0)),
		float(trait_data.get("appetite", 1.0)),
		"좌클릭: 좌석에서 일으키기" if is_seat else "좌클릭: 좌석에 앉히기",
		GameState.format_compact_number(GameState.get_resident_reroll_cost(resident_id)),
	]
	return button


func _reroll_worker(resident_id: String) -> void:
	var result: Dictionary = GameState.try_reroll_resident_trait(resident_id)
	if bool(result.get("ok", false)):
		get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
		_rebuild_ui()


func _toggle_worker(resident_id: String) -> void:
	GameState.toggle_worker_assignment(resident_id)
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_rebuild_ui()


func _upgrade() -> void:
	if GameState.try_upgrade_scratcher_bank():
		GameState.save_persistent_state()
		_rebuild_ui()


func _activate_boost() -> void:
	if GameState.activate_catnip_boost():
		GameState.save_persistent_state()
		_rebuild_ui()


func _button(text: String, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, HudStyle.TEXT)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return HudStyle.style_button(button, HudStyle.LINE_FOCUS)


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce6df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _empty_resident_state(title: String, description: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ScratcherEmptyState"
	panel.custom_minimum_size = Vector2(0, 138 if compact else 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.021, 0.76), Color("#35483e")))
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
	icon.texture = UI_ICONS.get_icon("resident", 48, Color("#667a70"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var title_label := _label(title, 14, Color("#b5c0ba"))
	title_label.name = "EmptyStateTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var description_label := _label(description, 11, Color("#718078"))
	description_label.name = "EmptyStateDescription"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(description_label)
	return panel


func _summary_card(title: String, value: String, icon_name: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 52 if compact else 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.041, 0.036, 0.92), Color("#46564d")))
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
	icon.texture = UI_ICONS.get_icon(icon_name, 36, Color("#d1b96f"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)
	var title_label := _label(title, 10 if compact else 11, Color("#8e9b92"))
	var value_label := _label(value, 13 if compact else 15, Color("#e4dfd1"))
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
