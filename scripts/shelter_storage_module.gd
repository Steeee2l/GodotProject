class_name ShelterStorageModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

const ITEM_NAMES := {
	"m1911": "M1911",
	"mp5": "MP5",
	"ak47": "AK-47",
	"double_barrel": "더블 배럴 산탄총",
	"9mm_fmj": "9mm 보통탄",
	"9mm_ap": "9mm 철갑탄",
	"45_fmj": ".45 ACP 보통탄",
	"45_ap": ".45 ACP 철갑탄",
	"762_fmj": "7.62mm 보통탄",
	"762_ap": "7.62mm 철갑탄",
	"12g_buckshot": "12게이지 벅샷",
	"12g_slug": "12게이지 슬러그",
	"rubber_gasket": "고무 패킹",
	"scope_lens": "스코프 렌즈",
	"magazine_spring": "탄창 스프링",
	"scope_2x": "폐점포 2x 스코프",
	"muffled_sock": "소리 방지용 양말",
	"sponge_pad": "스펀지 턱받이",
	"quick_mag": "테이프 듀얼 탄창",
	"bell_bait": "딸랑이 방울",
	"ak_precision_receiver": "AK 정밀 리시버",
	"scav_vest": "누더기 방탄 조끼",
	"riot_vest": "진압대 방탄 조끼",
	"patched_helmet": "기워 붙인 헬멧",
	"tactical_helmet": "전술 방탄 헬멧",
	"patched_sneakers": "기워 붙인 운동화",
	"tactical_boots": "경량 전술화",
	"medkit": "구급약",
	"canned_food": "통조림",
}

const COMPONENT_TEXTURES := {
	"rubber_gasket": "res://assets/items/mod_components/rubber_gasket.png",
	"scope_lens": "res://assets/items/mod_components/scope_lens.png",
	"magazine_spring": "res://assets/items/mod_components/magazine_spring.png",
}

@export var interaction_radius := 4.0

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("StorageSprite") as Sprite3D

var ui_layer: CanvasLayer
var content: VBoxContainer
var feedback_label: Label


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("shelter_storage")
	set_meta("module_kind", "storage")
	if sprite != null:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.region_enabled = false
		sprite.no_depth_test = false
		sprite.render_priority = 12


func get_interaction_prompt() -> String:
	return "창고 · 전리품 보관/판매"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	_open_ui()
	return "보관함을 열었습니다."


func set_interaction_focus(value: bool) -> void:
	if sprite:
		sprite.modulate = Color(1.08, 1.12, 1.18, 1.0) if value else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "ShelterStorageUILayer"
	ui_layer.layer = 84
	ui_layer.add_to_group("shelter_modal_ui")
	var ui_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	ui_parent.add_child(ui_layer)

	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.008, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)

	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	var available_size := Vector2(
		viewport_size.x - safe.x - safe.z,
		viewport_size.y - safe.y - safe.w
	)
	var outer_margin := 8 if viewport_size.y < 640.0 else 20
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", roundi(outer_margin + safe.x))
	safe_margin.add_theme_constant_override("margin_top", roundi(outer_margin + safe.y))
	safe_margin.add_theme_constant_override("margin_right", roundi(outer_margin + safe.z))
	safe_margin.add_theme_constant_override("margin_bottom", roundi(outer_margin + safe.w))
	modal.add_child(safe_margin)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ShelterStoragePanel"
	# 세로 화면은 720 상한을 풀어 위아래를 꽉 쓴다 — 스크롤을 줄이는 게 우선.
	var portrait := viewport_size.y > viewport_size.x
	panel.custom_minimum_size = Vector2(
		minf(1120.0, available_size.x - outer_margin * 2.0),
		(available_size.y - outer_margin * 2.0) if portrait else minf(720.0, available_size.y - outer_margin * 2.0)
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.012, 0.019, 0.021, 0.98), Color("#6c8f89"), 2, 6)
	)
	center.add_child(panel)
	# 모달 표준 등장 — 툭 나타나지 않는다.
	HudStyle.enter_modal(panel)

	var margin := MarginContainer.new()
	var inner_margin := 10 if viewport_size.y < 640.0 else 18
	margin.add_theme_constant_override("margin_left", inner_margin)
	margin.add_theme_constant_override("margin_top", inner_margin)
	margin.add_theme_constant_override("margin_right", inner_margin)
	margin.add_theme_constant_override("margin_bottom", inner_margin)
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_rebuild_ui()


func _rebuild_ui() -> void:
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 1040.0
	var compact := viewport_size.y < 680.0
	var header := VBoxContainer.new()
	header.name = "StorageHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_row.add_child(title_box)
	title_box.add_child(_label("쉘터 창고  Lv.%d" % GameState.storage_level, 26 if not compact else 22, Color("#e7ddbd")))
	title_box.add_child(_label("가방과 보관함 사이에서 장비를 이동합니다.", 12, Color("#91a7a2")))
	var close := _icon_button("close", "닫기", Color("#dce7e4"))
	close.name = "CloseButton"
	close.pressed.connect(_close_ui)
	top_row.add_child(close)
	var wallet := HFlowContainer.new()
	wallet.name = "StorageWallet"
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
		"churu",
		GameState.format_compact_number(GameState.churu),
		compact,
		not narrow
	))

	# 귀중품은 쓸 데가 없다. 여기가 유일한 출구다.
	var valuable_total: int = GameState.get_valuable_total_value()
	if valuable_total > 0:
		var sell := Button.new()
		sell.name = "SellValuablesButton"
		sell.text = "귀중품 전부 팔기  ·  고철 +%s" % GameState.format_compact_number(valuable_total)
		sell.custom_minimum_size = Vector2(0, 42)
		sell.add_theme_font_override("font", FONT)
		sell.add_theme_font_size_override("font_size", 14)
		sell.add_theme_color_override("font_color", Color("#f0dda6"))
		sell.pressed.connect(_sell_valuables, CONNECT_DEFERRED)
		content.add_child(sell)

	var summary := GridContainer.new()
	summary.name = "StorageSummary"
	summary.columns = 1 if viewport_size.x < 700.0 else 2
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	summary.add_child(_summary_card(
		"사용 슬롯",
		"%d / %d" % [GameState.get_storage_used_slots(), GameState.get_storage_capacity()],
		"loot"
	))
	summary.add_child(_upgrade_card())

	var body: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	body.name = "StorageBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	body.add_child(_build_backpack_panel(narrow, compact))
	body.add_child(_build_storage_panel(narrow, compact))

	feedback_label = _label("", 12, Color("#e6c779"))
	feedback_label.name = "StorageFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(feedback_label)


func _build_backpack_panel(narrow: bool, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "BackpackItemsPanel"
	panel.custom_minimum_size = Vector2(0 if narrow else 330, 180 if narrow else 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.022, 0.031, 0.032, 0.94), Color("#405854"))
	)
	var margin := _margin(12, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	title_row.add_child(_label("가방", 16, Color("#d8e3df")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var backpack_count := 0
	for entry in _get_backpack_entries():
		backpack_count += int(entry.get("count", 0))
	title_row.add_child(_label("%d개" % backpack_count, 12, Color("#8ca29d")))

	var scroll := ScrollContainer.new()
	scroll.name = "BackpackItemScroll"
	scroll.custom_minimum_size.y = 142 if narrow else (250 if compact else 380)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var entries := _get_backpack_entries()
	if entries.is_empty():
		var empty := _label("보관 가능한 소지품이 없습니다.", 13, Color("#687a76"))
		empty.custom_minimum_size.y = 72
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list.add_child(empty)
	else:
		for entry in entries:
			list.add_child(_backpack_item_button(entry))
	return panel


func _build_storage_panel(narrow: bool, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "StorageGridPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.019, 0.027, 0.029, 0.96), Color("#4f6f69"))
	)
	var margin := _margin(12, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	title_row.add_child(_label("보관함", 16, Color("#e4d8b8")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	title_row.add_child(_label(
		"%d / %d 슬롯" % [GameState.get_storage_used_slots(), GameState.get_storage_capacity()],
		12,
		Color("#91a7a2")
	))

	var scroll := ScrollContainer.new()
	scroll.name = "StorageGridScroll"
	scroll.custom_minimum_size.y = 230 if narrow else (250 if compact else 390)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)

	var grid_size := GameState.get_storage_grid_size()
	var cell_size := 70 if compact else 78
	var grid := GridContainer.new()
	grid.name = "StorageGrid"
	grid.columns = grid_size.x
	grid.custom_minimum_size = Vector2(
		float(grid_size.x * (cell_size + 6)),
		float(grid_size.y * (cell_size + 6))
	)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	for slot_index in GameState.get_storage_capacity():
		var entry: Dictionary = {}
		if slot_index < GameState.storage_inventory.size():
			entry = (GameState.storage_inventory[slot_index] as Dictionary).duplicate(true)
		grid.add_child(_storage_slot_button(slot_index, entry, cell_size))
	return panel


func _backpack_item_button(entry: Dictionary) -> Button:
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var count := int(entry.get("count", 0))
	var button := Button.new()
	button.name = "Store_%s_%s" % [item_type, item_id]
	button.custom_minimum_size = Vector2(0, 58)
	button.text = "%s\n보유 %d  ·  보관" % [_item_name(item_id), count]
	button.icon = _item_texture(item_type, item_id, 42)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 42)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color(0.032, 0.044, 0.045, 0.98), Color("#405651"))
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color(0.054, 0.072, 0.069, 0.98), Color("#d0ad63"))
	)
	button.pressed.connect(_deposit_item.bind(item_type, item_id))
	return button


func _storage_slot_button(slot_index: int, entry: Dictionary, cell_size: int) -> Button:
	var button := Button.new()
	button.name = "StorageSlot_%02d" % slot_index
	button.custom_minimum_size = Vector2(cell_size, cell_size)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color(0.026, 0.036, 0.038, 0.98), Color("#354a46"), 1, 4)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color(0.06, 0.071, 0.063, 0.98), Color("#d1af63"), 2, 4)
	)
	if entry.is_empty():
		button.disabled = true
		button.icon = UI_ICONS.get_icon("all", 24, Color(0.28, 0.34, 0.33, 0.42))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return button
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var count := int(entry.get("count", 0))
	button.icon = _item_texture(item_type, item_id, 40)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 40)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "×%d" % count
	button.tooltip_text = "%s  ×%d\n꺼내기" % [_item_name(item_id), count]
	button.pressed.connect(_withdraw_slot.bind(slot_index))
	return button


func _upgrade_card() -> Control:
	var cost := GameState.get_storage_upgrade_cost()
	if cost.is_empty():
		return _summary_card("확장", "최대 등급", "upgrade")
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.043, 0.039, 0.025, 0.96), Color("#806b38"))
	)
	var margin := _margin(8, 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	var button := Button.new()
	button.name = "StorageUpgradeButton"
	button.custom_minimum_size = Vector2(116, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "Lv.%d 확장" % (GameState.storage_level + 1)
	button.icon = UI_ICONS.get_icon("upgrade", 30, Color("#e0c16d"))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 13)
	button.disabled = GameState.scrap < scrap_cost or GameState.churu < churu_cost
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color(0.043, 0.039, 0.025, 0.96), Color("#806b38"))
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color(0.075, 0.063, 0.035, 0.98), Color("#d2b45d"), 2)
	)
	button.pressed.connect(_upgrade_storage)
	row.add_child(button)
	row.add_child(SHELTER_UI.make_currency_chip(
		"scrap",
		GameState.format_compact_number(scrap_cost),
		true,
		false
	))
	if churu_cost > 0:
		row.add_child(SHELTER_UI.make_currency_chip("churu", str(churu_cost), true, false))
	return panel


func _summary_card(title: String, value: String, icon_name: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.026, 0.037, 0.038, 0.94), Color("#405954"))
	)
	var margin := _margin(10, 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.texture = UI_ICONS.get_icon(icon_name, 34, Color("#b6cfc7"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 1)
	row.add_child(labels)
	labels.add_child(_label(title, 10, Color("#849994")))
	var value_label := _label(value, 14, Color("#e1e8e5"))
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	labels.add_child(value_label)
	return panel


func _get_backpack_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_dictionary_entries(entries, "weapon", GameState.weapon_inventory)
	_append_dictionary_entries(entries, "equipment", GameState.equipment_inventory)
	_append_dictionary_entries(entries, "ammo", GameState.ammo_inventory)
	_append_dictionary_entries(entries, "component", GameState.mod_component_inventory)
	_append_dictionary_entries(entries, "mod", GameState.weapon_mod_inventory)
	if GameState.medkits > 0:
		entries.append({"type": "medkit", "id": "medkit", "count": GameState.medkits})
	var carried_food := GameState.get_backpack_storage_count("food", "canned_food")
	if carried_food > 0:
		entries.append({"type": "food", "id": "canned_food", "count": carried_food})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return _item_name(str(a.get("id", ""))) < _item_name(str(b.get("id", ""))))
	return entries


func _append_dictionary_entries(target: Array[Dictionary], item_type: String, inventory: Dictionary) -> void:
	var item_ids := inventory.keys()
	item_ids.sort()
	for item_id_value in item_ids:
		var item_id := str(item_id_value)
		var count := GameState.get_backpack_storage_count(item_type, item_id)
		if count > 0:
			target.append({"type": item_type, "id": item_id, "count": count})


func _deposit_item(item_type: String, item_id: String) -> void:
	var available := GameState.get_backpack_storage_count(item_type, item_id)
	var amount := _transfer_amount(item_type, available)
	var result := GameState.deposit_storage_item(item_type, item_id, amount) as Dictionary
	if bool(result.get("ok", false)):
		call_deferred(
			"_rebuild_after_transfer",
			"%s %d개를 보관했습니다." % [_item_name(item_id), int(result.get("moved", 0))],
			true
		)
	else:
		_set_feedback(str(result.get("reason", "보관하지 못했습니다.")), false)


func _withdraw_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameState.storage_inventory.size():
		return
	var entry := GameState.storage_inventory[slot_index] as Dictionary
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var amount := _transfer_amount(item_type, int(entry.get("count", 0)))
	var result := GameState.withdraw_storage_item(slot_index, amount) as Dictionary
	if bool(result.get("ok", false)):
		call_deferred(
			"_rebuild_after_transfer",
			"%s %d개를 꺼냈습니다." % [_item_name(item_id), int(result.get("moved", 0))],
			true
		)
	else:
		_set_feedback(str(result.get("reason", "꺼내지 못했습니다.")), false)


func _upgrade_storage() -> void:
	if GameState.try_upgrade_storage():
		call_deferred(
			"_rebuild_after_transfer",
			"창고가 Lv.%d로 확장되었습니다." % GameState.storage_level,
			true
		)
	else:
		_set_feedback("창고 확장 재료가 부족합니다.", false)


func _rebuild_after_transfer(message: String, success: bool) -> void:
	if not is_inside_tree() or not is_instance_valid(content):
		return
	_rebuild_ui()
	_set_feedback(message, success)


func _transfer_amount(item_type: String, available: int) -> int:
	match item_type:
		"ammo":
			return mini(30, available)
		"food":
			return mini(5, available)
	return 1


func _set_feedback(message: String, success: bool) -> void:
	if feedback_label == null:
		return
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color",
		Color("#9de0b1") if success else Color("#f09a8a")
	)


func _item_name(item_id: String) -> String:
	# 레벨 장비("scav_vest@3")는 정의 조회가 "이름 Lv.3"까지 만들어 준다.
	var equipment_definition: Dictionary = GameState.get_equipment_definition(item_id)
	if not equipment_definition.is_empty():
		return str(equipment_definition.get("display_name", item_id))
	return str(ITEM_NAMES.get(item_id, item_id.replace("_", " ").capitalize()))


func _item_texture(item_type: String, item_id: String, size: int) -> Texture2D:
	if item_type == "weapon":
		var weapon_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(item_id)
		if weapon_texture != null:
			return weapon_texture
	if item_type == "equipment":
		var definition := GameState.get_equipment_definition(item_id)
		var path := str(definition.get("texture_path", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			return load(path) as Texture2D
	if item_type == "component":
		var component_path := str(COMPONENT_TEXTURES.get(item_id, ""))
		if not component_path.is_empty() and ResourceLoader.exists(component_path):
			return load(component_path) as Texture2D
	if item_type == "ammo" and ResourceLoader.exists("res://assets/items/ammo_762.png"):
		return load("res://assets/items/ammo_762.png") as Texture2D
	var icon_name := "loot"
	match item_type:
		"ammo":
			icon_name = "ammo"
		"component", "mod":
			icon_name = "mod"
		"medkit":
			icon_name = "medkit"
		"food":
			icon_name = "food"
		"equipment":
			icon_name = "armor"
		"weapon":
			icon_name = "weapon"
	return UI_ICONS.get_icon(icon_name, size, Color("#d7c27d"))


var sell_valuables_armed_msec := 0


func _sell_valuables() -> void:
	# 전량 판매는 되돌릴 수 없다 — 첫 탭 무장, 4초 안의 두 번째 탭만 실행.
	if Time.get_ticks_msec() - sell_valuables_armed_msec > 4000:
		sell_valuables_armed_msec = Time.get_ticks_msec()
		_set_feedback("한 번 더 누르면 귀중품 전부를 고철 %s에 판다" % GameState.format_compact_number(
			GameState.get_valuable_total_value()
		), false)
		return
	sell_valuables_armed_msec = 0
	var result: Dictionary = GameState.sell_all_valuables()
	if int(result.get("count", 0)) > 0:
		_set_feedback("귀중품 %d점 판매 · 고철 +%s" % [
			int(result.get("count", 0)),
			GameState.format_compact_number(int(result.get("scrap", 0))),
		], true)
		_rebuild_ui()


func _icon_button(icon_name: String, tooltip: String, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(42, 42)
	button.icon = UI_ICONS.get_icon(icon_name, 24, color)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color(0.025, 0.034, 0.035, 0.96), Color("#50645f"))
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color(0.06, 0.075, 0.073, 0.98), Color("#b8d1c9"))
	)
	return button


func _close_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _margin(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_bottom", vertical)
	return margin


func _panel_style(
	background: Color,
	border: Color,
	border_width: int = 1,
	corner_radius: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style
