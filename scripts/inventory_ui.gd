extends Control

signal open_state_changed(is_open: bool)
signal weapon_mods_changed
signal weapon_equipped(weapon_id: String)
signal weapon_unequipped
signal equipment_changed
signal item_discard_requested(item_type: String, item_id: String, amount: int)

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")

const SLOT_ORDER := ["sight", "muzzle", "stock", "magazine", "tactical", "special"]
const MOD_COMPONENTS := {
	"scope_2x": {"component": "scope_lens", "amount": 1, "scrap": 35},
	"muffled_sock": {"component": "rubber_gasket", "amount": 1, "scrap": 25},
	"sponge_pad": {"component": "rubber_gasket", "amount": 1, "scrap": 45},
	"quick_mag": {"component": "magazine_spring", "amount": 1, "scrap": 55},
	"bell_bait": {"component": "magazine_spring", "amount": 1, "scrap": 20},
	"ak_precision_receiver": {"component": "scope_lens", "amount": 2, "scrap": 160},
}
# 15칸짜리 가방에 분류 탭 여섯 개는 과했다. 게다가 component/progression/
# special_cargo는 어느 탭에도 안 걸려서, 필터를 켜면 화면에서 사라졌다.
#
# 이 게임에서 가방을 두고 다투는 건 결국 둘이다.
#   자원 — 쉘터를 돌리는 입력
#   장비 — 나를 강하게 만드는 것
# 탭을 그 축에 맞추면 분류가 곧 선택이 된다.
const BAG_FILTER_ORDER := ["all", "resource", "gear"]

# 자원 = 쉘터로 가져가는 것, 장비 = 지금 이 출정에서 쓰는 것.
const BAG_FILTER_RESOURCE_TYPES := ["resource", "progression", "special_cargo"]
const BAG_FILTER_GEAR_TYPES := ["weapon", "equipment", "mod", "component", "ammo"]

const BAG_FILTER_MIN_WIDTH := {
	"all": 62,
	"resource": 74,
	"gear": 74,
}
const BAG_FILTER_TITLES := {
	"all": "전체",
	"resource": "자원",
	"gear": "장비",
}
const BAG_FILTER_ICON := {
	"all": "",
	"resource": "",
	"gear": "",
}

var font_ref: Font
var weapon_texture: Texture2D
var ammo_texture: Texture2D
var component_textures: Dictionary = {}
var weapon_textures: Dictionary = {}
var game_state

var opened := false
var weapon_detail_open := false
var selected_item: Dictionary = {}

var modal: Control
var open_button: Button
var shell: HBoxContainer
var inventory_panel: Control
var weapon_panel: Control
var equipped_grid: GridContainer
var bag_grid: GridContainer
var bag_scroll: ScrollContainer
var bag_expand_button: Button
var secure_expand_button: Button
var scrap_label: Label
var inventory_feedback: Label
var weapon_title: Label
var weapon_preview: TextureRect
var weapon_stats: Label
var weapon_state_action_button: Button
var mod_slot_grid: GridContainer
var bag_slot_usage_label: Label
var item_detail_icon: TextureRect
var item_detail_title: Label
var item_detail_description: Label
var item_action_button: Button
var item_discard_button: Button
var item_detail_reason: Label
var bag_empty_hint: Label

var has_weapon_state := false
var magazine_state := 0
var reserve_state := 0
var weapon_name_state := "AK-47"
var magazine_size_state := 30
var durability_state := 100.0
var mod_names_state: Array[String] = []
var canned_food_state := 0
var stored_weapons_state := 0
var mod_components_state: Dictionary = {}
var rescued_workers_state := 0
var fatigue_state := 0.0
var bag_filter_buttons: Dictionary = {}
var bag_filter_button_tweens: Dictionary = {}
var bag_filter_hover_states: Dictionary = {}
var bag_filter_count_tweens: Dictionary = {}
var bag_filter_count_badge_tweens: Dictionary = {}
var bag_filter_button_counts: Dictionary = {}
var bag_filter_count_labels: Dictionary = {}
var bag_filter_count_badges: Dictionary = {}
var bag_filter_selection_tweens: Dictionary = {}
var bag_empty_hint_tween: Tween
var bag_filter: String = "all"
var feedback_tween: Tween
var visible_bag_items := 0
var responsive_compact := false
const BAG_GRID_COLUMNS := 5


func setup(
	font: Font,
	next_weapon_texture: Texture2D,
	next_ammo_texture: Texture2D,
	next_component_textures: Dictionary = {},
	next_weapon_textures: Dictionary = {}
) -> void:
	font_ref = font
	weapon_texture = next_weapon_texture
	ammo_texture = next_ammo_texture
	component_textures = next_component_textures
	weapon_textures = next_weapon_textures
	game_state = get_node_or_null("/root/GameState")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 4000
	_build_open_button()
	_build_modal()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	set_open(false)
	call_deferred("_apply_responsive_layout")


func set_weapon_texture(next_weapon_texture: Texture2D) -> void:
	weapon_texture = next_weapon_texture
	if weapon_preview:
		weapon_preview.texture = _weapon_preview_texture()


func update_state(
	has_weapon: bool,
	magazine: int,
	reserve: int,
	weapon_name: String = "AK-47",
	magazine_size: int = 30,
	durability: float = 100.0,
	mod_names: Array[String] = [],
	canned_food: int = 0,
	stored_weapons: int = 0,
	mod_components: Dictionary = {},
	rescued_workers: int = 0,
	fatigue: float = 0.0
) -> void:
	has_weapon_state = has_weapon
	magazine_state = magazine
	reserve_state = reserve
	weapon_name_state = weapon_name
	magazine_size_state = magazine_size
	durability_state = durability
	mod_names_state = mod_names
	canned_food_state = canned_food
	stored_weapons_state = stored_weapons
	mod_components_state = mod_components.duplicate(true)
	rescued_workers_state = rescued_workers
	fatigue_state = fatigue
	if opened:
		_refresh_contents()


func toggle() -> void:
	set_open(not opened)


var _suppress_open_button_signal := false


func set_open(value: bool) -> void:
	opened = value
	if opened:
		weapon_detail_open = false
		selected_item = {}
	if modal:
		modal.visible = opened
	if open_button:
		# 터치 입력 도중 버튼을 숨기면 pressed가 동기 재발화해 toggle이 중첩
		# 호출된다(쉘터에서 가방이 열리자마자 닫히던 원인). 가드로 끊는다.
		_suppress_open_button_signal = true
		open_button.visible = not opened
		_suppress_open_button_signal = false
	if opened:
		_refresh_contents()
	_apply_responsive_layout()
	open_state_changed.emit(opened)


func is_open() -> bool:
	return opened


func _build_open_button() -> void:
	open_button = Button.new()
	open_button.name = "InventoryButton"
	open_button.text = "가방"
	open_button.icon = UI_ICONS.get_icon("backpack", 40, Color("#dce9e1"))
	open_button.expand_icon = true
	open_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_button.tooltip_text = "가방 열기  [E]"
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.z_as_relative = false
	open_button.z_index = 4001
	open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_button.offset_left = -1
	open_button.offset_top = 0
	open_button.offset_right = 1
	open_button.offset_bottom = 0
	_apply_button_font(open_button, 14)
	if DisplayServer.is_touchscreen_available():
		# 모바일은 필드 액션 버튼과 같은 원형 문법 — 사각 상자는 '깨진 옵션 버튼'처럼 읽혔다.
		HudStyle.style_mobile_action(open_button, Color("#8ab7a0"), 26)
	else:
		open_button.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.027, 0.025, 0.94), Color("#8ab7a0"), 6))
		open_button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.075, 0.068, 0.98), Color("#d9c579"), 6))
	open_button.pressed.connect(func() -> void:
		if not _suppress_open_button_signal:
			toggle()
	)
	add_child(open_button)


func _build_modal() -> void:
	modal = Control.new()
	modal.name = "InventoryModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_as_relative = false
	modal.z_index = 4000
	add_child(modal)

	var dim := ColorRect.new()
	dim.name = "ModalDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.009, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)

	var safe_margin := _margin(16, 16, 16, 16)
	safe_margin.name = "InventorySafeMargin"
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(safe_margin)
	var center := CenterContainer.new()
	center.name = "InventoryCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(center)

	shell = HBoxContainer.new()
	shell.name = "InventoryShell"
	shell.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_theme_constant_override("separation", 12)
	center.add_child(shell)

	inventory_panel = _build_inventory_panel()
	weapon_panel = _build_weapon_panel()
	shell.add_child(inventory_panel)
	shell.add_child(weapon_panel)
	weapon_panel.visible = false


func _build_inventory_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CompactInventoryPanel"
	panel.custom_minimum_size = Vector2(320, 260)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.043, 0.049, 0.98), Color(0.66, 0.78, 0.73, 0.7), 8))
	var margin := _margin(16, 14, 16, 14)
	panel.add_child(margin)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "InventoryPanelScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var title := _label("인벤토리", 23, Color("#f0e8d0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _icon_text_button("닫기", "인벤토리 닫기 [Esc]", "close")
	close_button.custom_minimum_size = Vector2(62, 34)
	close_button.pressed.connect(func() -> void: set_open(false))
	header.add_child(close_button)

	box.add_child(_section("장비"))
	equipped_grid = GridContainer.new()
	equipped_grid.name = "EquipmentGrid"
	equipped_grid.columns = 2
	equipped_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_grid.add_theme_constant_override("h_separation", 6)
	equipped_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(equipped_grid)

	var bag_header := HBoxContainer.new()
	box.add_child(bag_header)
	var bag_title := _section("가방")
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_header.add_child(bag_title)
	bag_slot_usage_label = _label(
		"남은 슬롯 %d / %d" % [
			int(game_state.get_raid_bag_capacity()),
			int(game_state.get_raid_bag_capacity()),
		],
		12,
		Color("#b7c8c0")
	)
	bag_slot_usage_label.name = "BagSlotUsage"
	bag_slot_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bag_slot_usage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bag_header.add_child(bag_slot_usage_label)
	# 인크리멘탈 사다리: 가방 확장(고철)과 시큐어 슬롯(츄르)이 항상 눈앞에 있다.
	# "조금만 더 모으면 산다"가 파밍의 이유가 된다.
	bag_expand_button = _icon_text_button("＋칸", "가방 영구 확장", "backpack")
	bag_expand_button.name = "BagExpandButton"
	bag_expand_button.custom_minimum_size = Vector2(76, 30)
	bag_expand_button.pressed.connect(_on_bag_expand_pressed)
	bag_header.add_child(bag_expand_button)
	secure_expand_button = _icon_text_button("시큐어", "죽어도 지키는 칸 확장 (츄르)", "secure")
	secure_expand_button.name = "SecureExpandButton"
	secure_expand_button.custom_minimum_size = Vector2(86, 30)
	secure_expand_button.pressed.connect(_on_secure_expand_pressed)
	bag_header.add_child(secure_expand_button)

	inventory_feedback = _label("", 11, Color("#f2d27a"))
	inventory_feedback.visible = false
	inventory_feedback.add_theme_font_size_override("font_size", 11)
	inventory_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(inventory_feedback)

	box.add_child(_build_item_detail_panel())

	bag_scroll = ScrollContainer.new()
	bag_scroll.name = "BagScroll"
	bag_scroll.custom_minimum_size = Vector2(0, 110)
	bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(bag_scroll)
	bag_grid = GridContainer.new()
	bag_grid.name = "BagGrid"
	bag_grid.columns = BAG_GRID_COLUMNS
	bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	bag_scroll.add_child(bag_grid)

	bag_empty_hint = _label("가방에 보관 중인 아이템이 없습니다.", 11, Color("#8ca5a0"))
	bag_empty_hint.add_theme_font_size_override("font_size", 12)
	bag_empty_hint.add_theme_color_override("font_color", Color("#8eb0a5"))
	bag_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_empty_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_empty_hint.visible = false
	box.add_child(bag_empty_hint)

	return panel


func _build_item_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SelectedItemDetail"
	panel.custom_minimum_size = Vector2(0, 132)
	panel.clip_contents = false
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.025, 0.029, 0.96), Color(0.43, 0.58, 0.52, 0.58), 7))
	var margin := _margin(10, 8, 10, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	item_detail_icon = TextureRect.new()
	item_detail_icon.custom_minimum_size = Vector2(60, 60)
	item_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(item_detail_icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.clip_contents = false
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	item_detail_title = _label("가방", 14, Color("#e8e0c7"))
	item_detail_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	item_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(item_detail_title)
	item_detail_description = _label("가방 슬롯에는 아이콘과 수량만 표시됩니다.", 11, Color("#9aaba4"))
	item_detail_description.custom_minimum_size = Vector2(0, 64)
	item_detail_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_detail_description.max_lines_visible = 6
	item_detail_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(item_detail_description)
	item_detail_reason = _label("", 10, Color("#ffc77f"))
	item_detail_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_detail_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_detail_reason.max_lines_visible = 2
	item_detail_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_detail_reason.visible = false
	text_box.add_child(item_detail_reason)
	var action_box := VBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 5)
	row.add_child(action_box)
	item_action_button = _icon_text_button("", "", "all")
	item_action_button.custom_minimum_size = Vector2(86, 36)
	item_action_button.visible = false
	item_action_button.pressed.connect(_on_selected_item_action)
	action_box.add_child(item_action_button)
	item_discard_button = _icon_text_button("버리기", "close", "all")
	item_discard_button.custom_minimum_size = Vector2(86, 36)
	item_discard_button.add_theme_color_override("font_color", Color("#f0b09a"))
	item_discard_button.add_theme_color_override("icon_normal_color", Color("#f0b09a"))
	item_discard_button.visible = false
	item_discard_button.pressed.connect(_on_selected_item_discard)
	action_box.add_child(item_discard_button)
	return panel


func _build_weapon_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "WeaponDetailPanel"
	panel.custom_minimum_size = Vector2(320, 260)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.035, 0.04, 0.98), Color(0.69, 0.62, 0.4, 0.68), 8))
	var margin := _margin(18, 14, 18, 16)
	panel.add_child(margin)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "WeaponPanelScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	panel_scroll.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	weapon_title = _label("총기 상세", 22, Color("#f0e8cf"))
	weapon_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(weapon_title)
	weapon_state_action_button = _icon_text_button("장착 해제", "현재 무기를 가방으로 내립니다.", "close")
	weapon_state_action_button.custom_minimum_size = Vector2(94, 34)
	weapon_state_action_button.pressed.connect(_request_weapon_unequip)
	header.add_child(weapon_state_action_button)
	var detail_close := _icon_text_button("접기", "총기 상세 접기", "close")
	detail_close.custom_minimum_size = Vector2(62, 34)
	detail_close.pressed.connect(_hide_weapon_detail)
	header.add_child(detail_close)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 112)
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.019, 0.022, 0.9), Color(0.5, 0.55, 0.52, 0.35), 7))
	box.add_child(preview_panel)
	var preview_margin := _margin(12, 10, 12, 10)
	preview_panel.add_child(preview_margin)
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 14)
	preview_margin.add_child(preview)
	weapon_preview = TextureRect.new()
	weapon_preview.custom_minimum_size = Vector2(150, 86)
	weapon_preview.texture = _weapon_preview_texture()
	weapon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(weapon_preview)
	weapon_stats = _label("", 12, Color("#d4ddd6"))
	weapon_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(weapon_stats)

	box.add_child(_section("부착 슬롯"))
	var help := _label(
		"완성 부착물만 가방에서 장착할 수 있습니다. 제작 재료는 쉘터 작업대에서 완성품 제작에 사용합니다.",
		11,
		Color("#8fa59b")
	)
	box.add_child(help)
	mod_slot_grid = GridContainer.new()
	mod_slot_grid.name = "AttachmentSlots"
	mod_slot_grid.columns = 2
	mod_slot_grid.add_theme_constant_override("h_separation", 10)
	mod_slot_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(mod_slot_grid)

	var footer := _label("변경된 부품과 방어 수치는 즉시 전투 능력에 반영됩니다.", 11, Color("#c9b96e"))
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(footer)
	return panel


func _build_bag_filter_bar() -> Control:
	var row := HFlowContainer.new()
	row.name = "BagFilterBar"
	row.add_theme_constant_override("separation", 6)
	for filter_id in BAG_FILTER_ORDER:
		var filter_name := _get_filter_display_name(str(filter_id))
		var button := _icon_text_button("", "%s만 보기" % filter_name, _filter_icon_name(filter_id))
		button.name = "BagFilter_%s" % filter_id
		button.toggle_mode = true
		button.scale = Vector2.ONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bag_filter_hover_states[button] = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.button_pressed = filter_id == bag_filter
		button.pressed.connect(_on_bag_filter_pressed.bind(filter_id))
		button.button_down.connect(_on_bag_filter_button_down.bind(button))
		button.button_up.connect(_on_bag_filter_button_up.bind(button))
		button.mouse_entered.connect(_on_bag_filter_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_bag_filter_button_hover.bind(button, false))
		button.custom_minimum_size = Vector2(54, 34)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.size_flags_vertical = Control.SIZE_EXPAND
		row.add_child(button)
		bag_filter_buttons[filter_id] = button

		var count_badge := PanelContainer.new()
		count_badge.name = "BagFilterCountBadge_%s" % filter_id
		count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		count_badge.offset_left = -30
		count_badge.offset_top = 3
		count_badge.offset_right = -6
		count_badge.offset_bottom = 19
		count_badge.custom_minimum_size = Vector2(22, 14)
		count_badge.visible = false
		var badge_margin := MarginContainer.new()
		badge_margin.add_theme_constant_override("margin_left", 3)
		badge_margin.add_theme_constant_override("margin_top", 1)
		badge_margin.add_theme_constant_override("margin_right", 3)
		badge_margin.add_theme_constant_override("margin_bottom", 1)
		count_badge.add_child(badge_margin)
		var count_label := Label.new()
		count_label.name = "BagFilterCount_%s" % filter_id
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.add_theme_font_override("font", font_ref)
		count_label.add_theme_font_size_override("font_size", 9)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.text = _format_bag_filter_count(0)
		count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
		badge_margin.add_child(count_label)
		button.add_child(count_badge)
		bag_filter_count_badges[filter_id] = count_badge
		bag_filter_count_labels[filter_id] = count_label

	return row


func _on_bag_filter_pressed(filter_id: String) -> void:
	if filter_id != bag_filter:
		var previous_button: Variant = bag_filter_buttons.get(bag_filter, null)
		bag_filter = filter_id
		_refresh_contents()
		if previous_button is Button:
			_animate_bag_filter_selection_flash(previous_button as Button, false)
		var current_button: Variant = bag_filter_buttons.get(bag_filter, null)
		if current_button is Button:
			_animate_bag_filter_selection_flash(current_button as Button, true)
	else:
		_refresh_bag_filter_buttons()


func _on_bag_filter_button_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	bag_filter_hover_states[button] = hovered
	_animate_bag_filter_button_scale(button, Vector2(1.03, 1.03) if hovered else Vector2.ONE)


func _on_bag_filter_button_down(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_animate_bag_filter_button_scale(button, Vector2(0.96, 0.96))


func _on_bag_filter_button_up(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var is_hovered := bool(bag_filter_hover_states.get(button, false))
	_animate_bag_filter_button_scale(button, Vector2(1.03, 1.03) if is_hovered else Vector2.ONE)


func _animate_bag_filter_button_scale(button: Button, target_scale: Vector2) -> void:
	var old_tween: Variant = bag_filter_button_tweens.get(button, null)
	if old_tween is Tween and is_instance_valid(old_tween):
		old_tween.kill()
	var tween := create_tween()
	tween.tween_property(button, "scale", target_scale, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bag_filter_button_tweens[button] = tween


func _animate_bag_filter_selection_flash(button: Button, selected: bool) -> void:
	if not is_instance_valid(button):
		return
	var old_tween: Variant = bag_filter_selection_tweens.get(button, null)
	if old_tween is Tween and is_instance_valid(old_tween):
		old_tween.kill()
	var flash_target := Color(1.08, 1.08, 1.08, 1.0) if selected else Color(1.0, 1.0, 1.0, 1.0)
	var settle := Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.94, 0.94, 0.94, 1.0)
	var tween := create_tween()
	button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property(button, "self_modulate", flash_target, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "self_modulate", settle, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bag_filter_selection_tweens[button] = tween
func _get_filter_display_name(filter_id: String) -> String:
	if not BAG_FILTER_TITLES.has(filter_id):
		return "전체"
	return str(BAG_FILTER_TITLES[filter_id])


func _should_show_bag_item(item: Dictionary) -> bool:
	return int(item.get("quantity", 0)) > 0


func _bag_filter_matches_item(filter_id: String, item_type: String) -> bool:
	if filter_id == "all":
		return true
	if filter_id == "resource":
		return BAG_FILTER_RESOURCE_TYPES.has(str(item_type))
	if filter_id == "gear":
		return BAG_FILTER_GEAR_TYPES.has(str(item_type))
	return str(item_type) == filter_id


func _bag_filter_button_label(filter_id: String) -> String:
	var title := _get_filter_display_name(filter_id)
	var icon := str(BAG_FILTER_ICON.get(filter_id, ""))
	var base := icon + " " + title if icon != "" else title
	return base


func _format_bag_filter_count(count: int) -> String:
	if count <= 0:
		return "0"
	if count > 99:
		return "99+"
	return str(count)


func _refresh_bag_filter_buttons() -> void:
	for filter_id in BAG_FILTER_ORDER:
		var button: Variant = bag_filter_buttons.get(filter_id, null)
		if button is Button:
			var count := _count_bag_items_for_filter(str(filter_id))
			var prev_count := int(bag_filter_button_counts.get(filter_id, -1))
			(button as Button).text = ""
			(button as Button).tooltip_text = "%s만 보기" % _get_filter_display_name(str(filter_id))
			var count_label: Variant = bag_filter_count_labels.get(filter_id, null)
			var count_badge: Variant = bag_filter_count_badges.get(filter_id, null)
			if count_label is Label:
				count_label.text = _format_bag_filter_count(count)
			if count_badge is Control:
				var was_visible: bool = (count_badge as Control).visible
				if count > 0:
					if not was_visible:
						_set_bag_filter_count_badge_visibility(button as Button, filter_id, true)
					else:
						var active_badge_tween: Variant = bag_filter_count_badge_tweens.get(button, null)
						if active_badge_tween is Tween and is_instance_valid(active_badge_tween):
							active_badge_tween.kill()
						count_badge.scale = Vector2.ONE
						count_badge.modulate.a = 1.0
				else:
					if was_visible:
						_set_bag_filter_count_badge_visibility(button as Button, filter_id, false)
			if prev_count != -1 and prev_count != count and count > 0:
				_animate_bag_filter_count_update(button as Button, filter_id, prev_count, count)
			bag_filter_button_counts[filter_id] = count
			(button as Button).button_pressed = str(filter_id) == bag_filter
			_refresh_bag_filter_button_style(button as Button, filter_id)


func _set_bag_filter_count_badge_visibility(button: Button, filter_id: String, show: bool) -> void:
	if not is_instance_valid(button):
		return
	var count_badge: Variant = bag_filter_count_badges.get(filter_id, null)
	var count_label: Variant = bag_filter_count_labels.get(filter_id, null)
	if not (count_badge is Control):
		return
	var old_tween: Variant = bag_filter_count_badge_tweens.get(button, null)
	if old_tween is Tween and is_instance_valid(old_tween):
		old_tween.kill()
	var tween := create_tween()
	if show:
		count_badge.visible = true
		count_badge.scale = Vector2.ZERO
		count_badge.modulate.a = 0.0
		if count_label is Label:
			count_label.scale = Vector2.ONE
		tween.tween_property(count_badge, "scale", Vector2(1.12, 1.12), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(count_badge, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(count_badge, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(count_badge, "modulate:a", 1.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(count_badge, "scale", Vector2(0.35, 0.35), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(count_badge, "modulate:a", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(Callable(count_badge, "set_visible").bind(false))
		if count_label is Label:
			count_label.scale = Vector2.ONE
			tween.parallel().tween_property(count_label, "scale", Vector2(0.85, 0.85), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(count_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bag_filter_count_badge_tweens[button] = tween


func _animate_bag_filter_count_update(button: Button, filter_id: String, _old_count: int, _new_count: int) -> void:
	if not is_instance_valid(button):
		return
	var old_tween: Variant = bag_filter_count_tweens.get(button, null)
	if old_tween is Tween and is_instance_valid(old_tween):
		old_tween.kill()
	var count_label: Variant = bag_filter_count_labels.get(filter_id, null)
	var count_badge: Variant = bag_filter_count_badges.get(filter_id, null)
	var pulse_target := Vector2(1.03, 1.03)
	var settled_scale := Vector2(1.03, 1.03) if bool(bag_filter_hover_states.get(button, false)) else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(button, "scale", pulse_target, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", settled_scale, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bag_filter_count_tweens[button] = tween
	if count_badge is Control:
		count_badge.scale = Vector2.ONE
		var count_badge_tween := create_tween()
		count_badge_tween.tween_property(count_badge, "scale", Vector2(1.2, 1.2), 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		count_badge_tween.parallel().tween_property(count_badge, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if count_label is Label:
		var count_tween := create_tween()
		count_tween.tween_property(count_label, "scale", Vector2(1.12, 1.12), 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		count_tween.parallel().tween_property(count_label, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _refresh_bag_filter_button_style(button: Button, filter_id: Variant) -> void:
	var current_filter := str(filter_id)
	var is_active := str(current_filter) == bag_filter
	var base_color := _bag_filter_base_color(current_filter)
	var active_color := _bag_filter_active_color(current_filter)
	if is_active:
		button.add_theme_stylebox_override("normal", _panel_style(_lighten_color(active_color, 0.04), Color("#f5e3ae"), 6, 2))
		button.add_theme_stylebox_override("hover", _panel_style(_lighten_color(active_color, 0.1), Color("#ffefbf"), 6, 2))
		button.add_theme_stylebox_override("pressed", _panel_style(_darken_color(active_color, 0.1), Color("#e4c96f"), 6, 2))
		button.add_theme_stylebox_override("focus", _panel_style(_lighten_color(active_color, 0.08), Color("#ffe6a8"), 6, 2))
		button.add_theme_color_override("font_color", Color("#21170d"))
	else:
		button.add_theme_stylebox_override("normal", _panel_style(base_color, Color("#7e8e88"), 6, 2))
		button.add_theme_stylebox_override("hover", _panel_style(_lighten_color(base_color, 0.08), Color("#c4bea4"), 6, 2))
		button.add_theme_stylebox_override("pressed", _panel_style(_darken_color(base_color, 0.08), Color("#8a9586"), 6, 2))
		button.add_theme_stylebox_override("focus", _panel_style(_lighten_color(base_color, 0.05), Color("#b1bcae"), 6, 2))
		button.add_theme_color_override("font_color", Color("#dde7e1"))
	_refresh_bag_filter_count_badge_style(current_filter, is_active)


func _refresh_bag_filter_count_badge_style(filter_id: String, is_active: bool) -> void:
	var badge: Variant = bag_filter_count_badges.get(filter_id, null)
	var count_label: Variant = bag_filter_count_labels.get(filter_id, null)
	if not (badge is PanelContainer):
		return
	var filter_color := _bag_filter_active_color(filter_id) if is_active else _bag_filter_base_color(filter_id)
	var bg_color := _lighten_color(filter_color, 0.35) if is_active else _darken_color(filter_color, 0.02)
	var border_color := Color(1, 1, 1, 0.95) if is_active else Color(1, 1, 1, 0.35)
	var border_width := 2 if is_active else 1
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = bg_color
	badge_style.border_color = border_color
	badge_style.set_border_width_all(border_width)
	badge_style.set_corner_radius_all(999)
	badge_style.content_margin_left = 3
	badge_style.content_margin_right = 3
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", badge_style)
	if count_label is Label:
		count_label.add_theme_color_override("font_color", Color("#ffffff" if is_active else "#f0f4ff"))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.52) if is_active else Color(0, 0, 0, 0.24))
		count_label.add_theme_constant_override("outline_size", 2 if is_active else 1)
		if is_active:
			count_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			count_label.modulate = Color(0.88, 0.94, 1.0, 0.95)


func _bag_filter_base_color(filter_id: String) -> Color:
	match filter_id:
		"all":
			return Color("#3a4751")
		"ammo":
			return Color("#2f4a60")
		"resource":
			return Color("#35584f")
		"weapon":
			return Color("#5a3f50")
		"equipment":
			return Color("#3f5b55")
		"mod":
			return Color("#4a4d69")
		_:
			return Color("#3e4955")


func _bag_filter_active_color(filter_id: String) -> Color:
	match filter_id:
		"all":
			return Color("#5a738a")
		"ammo":
			return Color("#4b7ba3")
		"resource":
			return Color("#4f8d70")
		"weapon":
			return Color("#7f5b72")
		"equipment":
			return Color("#5f8b7c")
		"mod":
			return Color("#68658a")
		_:
			return Color("#5d7080")


func _lighten_color(color: Color, amount: float) -> Color:
	return Color(
		minf(color.r + amount, 1.0),
		minf(color.g + amount, 1.0),
		minf(color.b + amount, 1.0),
		color.a
	)


func _darken_color(color: Color, amount: float) -> Color:
	return Color(
		maxf(color.r - amount, 0.0),
		maxf(color.g - amount, 0.0),
		maxf(color.b - amount, 0.0),
		color.a
	)


func _count_bag_items_for_filter(filter_id: String) -> int:
	if game_state == null:
		return 0
	var count := 0
	if _bag_filter_matches_item(filter_id, "ammo"):
		for ammo_id in game_state.ammo_inventory:
			if int(game_state.ammo_inventory.get(ammo_id, 0)) > 0:
				count += 1
	if game_state.get_backpack_storage_count("food", "canned_food") > 0 and _bag_filter_matches_item(filter_id, "resource"):
		count += 1
	if int(game_state.medkits) > 0 and _bag_filter_matches_item(filter_id, "resource"):
		count += 1
	if int(game_state.churu) > 0 and _bag_filter_matches_item(filter_id, "resource"):
		count += 1
	var weapon_ids: Array = game_state.weapon_inventory.keys()
	weapon_ids.sort()
	for weapon_id_variant in weapon_ids:
		var weapon_id := str(weapon_id_variant)
		var quantity: int = int(game_state.get_weapon_count(weapon_id))
		if quantity <= 0:
			continue
		if _bag_filter_matches_item(filter_id, "weapon"):
			count += 1
	if _bag_filter_matches_item(filter_id, "equipment"):
		var equipment_ids: Array = game_state.equipment_inventory.keys()
		for equipped_id in [
			game_state.equipped_body_armor_id,
			game_state.equipped_head_armor_id,
			game_state.equipped_footwear_id,
		]:
			if not str(equipped_id).is_empty() and not equipment_ids.has(equipped_id):
				equipment_ids.append(equipped_id)
		for equipment_id in equipment_ids:
			var display_count := int(game_state.get_equipment_count(str(equipment_id)))
			if str(equipment_id) in [
				str(game_state.equipped_body_armor_id),
				str(game_state.equipped_head_armor_id),
				str(game_state.equipped_footwear_id),
			]:
				display_count += 1
			if display_count > 0:
				count += 1
	if _bag_filter_matches_item(filter_id, "mod"):
		for component_id_variant in game_state.mod_component_inventory:
			if int(game_state.get_mod_component_count(str(component_id_variant))) > 0:
				count += 1
		for mod_id_variant in MOD_COMPONENTS:
			if int(game_state.get_weapon_mod_count(str(mod_id_variant))) > 0:
				count += 1
	return count


func _show_inventory_feedback(message: String, color: Color = Color("#f2d27a")) -> void:
	if inventory_feedback == null:
		return
	inventory_feedback.visible = true
	inventory_feedback.text = message
	inventory_feedback.add_theme_color_override("font_color", color)
	inventory_feedback.modulate.a = 1.0
	if feedback_tween:
		feedback_tween.kill()
	feedback_tween = null
	if get_tree():
		feedback_tween = get_tree().create_tween()
		feedback_tween.tween_property(inventory_feedback, "modulate:a", 0.0, 1.2)


func _refresh_contents() -> void:
	if equipped_grid == null:
		return
	_clear(equipped_grid)
	_clear(bag_grid)
	_clear(mod_slot_grid)
	visible_bag_items = 0

	equipped_grid.add_child(_equipment_button("주무기", weapon_texture, has_weapon_state, _show_weapon_detail))
	var body_id := str(game_state.equipped_body_armor_id)
	var head_id := str(game_state.equipped_head_armor_id)
	var footwear_id := str(game_state.equipped_footwear_id)
	equipped_grid.add_child(_equipment_button(
		_equipped_equipment_label("body", "몸 방어구"),
		_equipment_texture(body_id, 48),
		not body_id.is_empty(),
		func() -> void: _select_equipped_equipment("body")
	))
	equipped_grid.add_child(_equipment_button(
		_equipped_equipment_label("head", "머리 방어구"),
		_equipment_texture(head_id, 48),
		not head_id.is_empty(),
		func() -> void: _select_equipped_equipment("head")
	))
	equipped_grid.add_child(_equipment_button(
		_equipped_equipment_label("feet", "신발"),
		_equipment_texture(footwear_id, 48),
		not footwear_id.is_empty(),
		func() -> void: _select_equipped_equipment("feet")
	))

	var ammo_names := {
		"9mm_fmj": "9mm FMJ 탄환",
		"45_fmj": ".45 ACP FMJ 탄환",
		"762_fmj": "7.62mm FMJ 탄환",
		"12g_buckshot": "12게이지 벅샷",
	}
	var ammo_ids: Array = game_state.ammo_inventory.keys()
	ammo_ids.sort()
	for ammo_id_value in ammo_ids:
		var ammo_id := str(ammo_id_value)
		var ammo_count := int(game_state.ammo_inventory.get(ammo_id, 0))
		_add_bag_item({
			"id": ammo_id,
			"type": "ammo",
			"title": str(ammo_names.get(ammo_id, ammo_id)),
			"description": "총기에 장전하는 소모 탄약입니다. 무기 구경과 맞아야 사용할 수 있습니다.",
			"quantity": ammo_count,
			"texture": ammo_texture if ammo_id == "762_fmj" else UI_ICONS.get_icon(
				"ammo",
				64,
				Color("#d9c16d")
			),
		})
	_add_bag_item({
		"id": "canned_food",
		"type": "resource",
		"title": "통조림",
		"description": "레이드에서 확보하는 핵심 식량이자 쉘터 노동 자원입니다.",
		"quantity": game_state.get_backpack_storage_count("food", "canned_food"),
		"texture": UI_ICONS.get_icon("food", 64, Color("#e6b65c")),
	})
	_add_bag_item({
		"id": "medkit",
		"type": "resource",
		"title": "구급약",
		"description": "전투 중 체력을 회복하는 응급 치료품입니다. SHIFT 또는 모바일 치료 버튼으로 사용합니다.",
		"quantity": int(game_state.medkits),
		"texture": UI_ICONS.get_icon("medkit", 64, Color("#dce8df")),
	})
	_add_bag_item({
		"id": "churu",
		"type": "resource",
		"title": "츄르",
		"description": "희귀 구역과 보스에게서 확보하는 쉘터 확장 재화입니다.",
		"quantity": int(game_state.churu),
		"texture": UI_ICONS.get_icon("churu", 64, Color("#e7b561")),
	})

	var weapon_ids: Array = game_state.weapon_inventory.keys()
	weapon_ids.sort()
	for weapon_id_variant in weapon_ids:
		var weapon_id := str(weapon_id_variant)
		var count: int = int(game_state.get_weapon_count(weapon_id))
		var weapon_equipped: bool = (
			has_weapon_state and weapon_id == str(game_state.equipped_weapon_id)
		)
		# 장착 중인 1정은 위의 장비 슬롯이 이미 보여준다. 가방 목록에 또 나오면
		# 자리를 차지하는 것처럼 읽히므로 뺀다. 같은 무기 2정째부터는 가방 몫이다.
		if weapon_equipped:
			count -= 1
		if count <= 0:
			continue
		var definition := WEAPON_SYSTEM.get_weapon(weapon_id)
		_add_bag_item({
			"id": weapon_id,
			"type": "weapon",
			"title": str(definition.get("display_name", weapon_id)),
			"description": "가방에 보관 중인 무기입니다. 선택 후 장착하면 현재 주무기와 교체됩니다.",
			"quantity": count,
			"equipped": false,
			"texture": weapon_textures.get(weapon_id) as Texture2D,
		})

	# 장착 중인 방어구는 위의 장비 슬롯이 보여준다. 가방 목록에는 예비(미장착)
	# 수량만 나온다 — 장착품이 가방 자리를 차지하는 것처럼 보이던 혼선을 없앤다.
	var equipment_ids: Array = game_state.equipment_inventory.keys()
	equipment_ids.sort()
	for equipment_id_variant in equipment_ids:
		var equipment_id := str(equipment_id_variant)
		var equipment_count := int(game_state.get_equipment_count(equipment_id))
		if equipment_count <= 0:
			continue
		var equipment_definition: Dictionary = game_state.get_equipment_definition(equipment_id)
		_add_bag_item({
			"id": equipment_id,
			"type": "equipment",
			"title": str(equipment_definition.get("display_name", equipment_id)),
			"description": str(equipment_definition.get("description", "")),
			"quantity": equipment_count,
			"equipped": false,
			"texture": _equipment_texture(equipment_id, 64),
		})

	var component_ids: Array = game_state.mod_component_inventory.keys()
	component_ids.sort()
	for component_id_variant in component_ids:
		var component_id := str(component_id_variant)
		var component_count := int(game_state.get_mod_component_count(component_id))
		if component_count <= 0:
			continue
		_add_bag_item({
			"id": component_id,
			"type": "component",
			"title": _component_name(component_id),
			"description": _component_description(component_id),
			"quantity": component_count,
			"texture": component_textures.get(component_id) as Texture2D,
		})

	var progression_item_ids: Array = game_state.progression_item_inventory.keys()
	progression_item_ids.sort()
	for progression_item_id_value in progression_item_ids:
		var progression_item_id := str(progression_item_id_value)
		var progression_item_count: int = int(
			game_state.get_progression_item_count(progression_item_id)
		)
		if progression_item_count <= 0:
			continue
		_add_bag_item({
			"id": progression_item_id,
			"type": "progression",
			"title": _progression_item_name(progression_item_id),
			"description": _progression_item_description(progression_item_id),
			"quantity": progression_item_count,
			"texture": UI_ICONS.get_icon(
				"secure" if progression_item_id == "sealed_zone_keycard" else "craft",
				64,
				Color("#e7c96f")
			),
		})

	var mod_ids: Array = MOD_COMPONENTS.keys()
	mod_ids.sort()
	for mod_id_variant in mod_ids:
		var mod_id := str(mod_id_variant)
		var cost: Dictionary = MOD_COMPONENTS[mod_id]
		var component_id := str(cost["component"])
		var available: int = int(game_state.get_weapon_mod_count(mod_id))
		if available <= 0:
			continue
		_add_bag_item({
			"id": mod_id,
			"type": "mod",
			"title": _mod_name(mod_id),
			"description": _mod_description(mod_id),
			"quantity": available,
			"texture": component_textures.get(component_id) as Texture2D,
		})

	if not game_state.raid_special_cargo.is_empty():
		var cargo := game_state.raid_special_cargo as Dictionary
		_add_bag_item({
			"id": str(cargo.get("id", "sealed_subway_cargo")),
			"type": "special_cargo",
			"title": str(cargo.get("title", "봉인된 지하철 화물")),
			"description": str(cargo.get(
				"description",
				"인간 격리구역에서 회수한 대형 화물입니다. 탈출해야 내용물을 확인할 수 있습니다."
			)),
			"quantity": 1,
			"texture": UI_ICONS.get_icon("secure", 64, Color("#f0ad55")),
		})

	var occupied_slots := int(game_state.get_raid_bag_used_slots())
	var bag_capacity := int(game_state.get_raid_bag_capacity())
	var empty_slots := maxi(0, bag_capacity - occupied_slots)
	for index in range(empty_slots):
		bag_grid.add_child(_empty_slot())
	if bag_slot_usage_label:
		bag_slot_usage_label.text = "남은 슬롯 %d / %d" % [empty_slots, bag_capacity]
		bag_slot_usage_label.add_theme_color_override(
			"font_color",
			Color("#ff9595") if occupied_slots >= bag_capacity else Color("#b7c8c0")
		)
	if bag_expand_button:
		var bag_cost := int(game_state.get_bag_upgrade_cost())
		if bag_cost <= 0:
			bag_expand_button.visible = false
		else:
			bag_expand_button.visible = true
			bag_expand_button.text = "＋1칸 %s" % game_state.format_compact_number(bag_cost)
			bag_expand_button.disabled = int(game_state.scrap) < bag_cost
			bag_expand_button.tooltip_text = "가방 영구 +1칸 · 고철 %s" % game_state.format_compact_number(bag_cost)
	if secure_expand_button:
		var secure_cost := int(game_state.get_secure_upgrade_cost())
		if secure_cost <= 0:
			secure_expand_button.visible = false
		else:
			secure_expand_button.visible = true
			secure_expand_button.text = "시큐어 츄르%d" % secure_cost
			secure_expand_button.disabled = int(game_state.churu) < secure_cost
			secure_expand_button.tooltip_text = "죽어도 지키는 칸 +1 (%d/3) · 츄르 %d" % [
				int(game_state.secure_dog_slots), secure_cost
			]

	if scrap_label:
		scrap_label.text = "쉘터 고철 %d" % int(game_state.scrap if game_state else 0)
	if weapon_detail_open and has_weapon_state:
		_refresh_weapon_detail()
	_refresh_item_detail()
	_update_bag_empty_hint()
	_apply_responsive_layout()


func _add_bag_item(item: Dictionary) -> void:
	if not _should_show_bag_item(item):
		return
	bag_grid.add_child(_bag_item_button(item))
	visible_bag_items += 1


func _update_bag_empty_hint() -> void:
	if bag_empty_hint == null:
		return
	if bag_empty_hint_tween is Tween and is_instance_valid(bag_empty_hint_tween):
		bag_empty_hint_tween.kill()
	bag_empty_hint_tween = null
	bag_empty_hint.visible = false
	bag_empty_hint.text = ""

func _show_weapon_detail() -> void:
	if not has_weapon_state:
		_select_empty_equipment_slot("주무기")
		return
	weapon_detail_open = true
	selected_item = {
		"id": game_state.equipped_weapon_id,
		"type": "weapon",
		"title": weapon_name_state,
		"description": "현재 장착 중인 총기입니다. 오른쪽에서 부착 상태를 확인할 수 있습니다.",
		"quantity": 1,
		"texture": weapon_texture,
	}
	weapon_panel.visible = true
	_refresh_weapon_detail()
	_refresh_item_detail()
	_apply_responsive_layout()


func _equipped_equipment_label(slot: String, fallback: String) -> String:
	var equipment_id := str(game_state.get_equipped_equipment(slot))
	if equipment_id.is_empty():
		return fallback
	var definition: Dictionary = game_state.get_equipment_definition(equipment_id)
	return str(definition.get("display_name", fallback))


func _select_equipped_equipment(slot: String) -> void:
	var equipment_id := str(game_state.get_equipped_equipment(slot))
	if equipment_id.is_empty():
		var empty_slot_names := {
			"body": "몸 방어구",
			"head": "머리 방어구",
			"feet": "신발",
		}
		_select_empty_equipment_slot(str(empty_slot_names.get(slot, "장비")))
		return
	var definition: Dictionary = game_state.get_equipment_definition(equipment_id)
	selected_item = {
		"id": equipment_id,
		"type": "equipment",
		"title": str(definition.get("display_name", equipment_id)),
		"description": str(definition.get("description", "")),
		"quantity": 1,
		"equipped": true,
		"texture": _equipment_texture(equipment_id, 64),
	}
	_refresh_item_detail()
	_show_inventory_feedback("%s 선택" % str(selected_item.get("title", "장비")), Color("#d9c579"))


func _select_empty_equipment_slot(slot_name: String) -> void:
	selected_item = {
		"id": "empty_%s" % slot_name,
		"type": "empty_slot",
		"title": slot_name,
		"description": "현재 장착된 장비가 없습니다. 가방의 아이템을 선택해 장착할 수 있습니다.",
		"quantity": 0,
		"texture": UI_ICONS.get_icon(_equipment_icon_name(slot_name), 64, Color("#71877c")),
	}
	_refresh_item_detail()
	_show_inventory_feedback("%s 슬롯은 비어 있습니다." % slot_name, Color("#9eb8ad"))


func _hide_weapon_detail() -> void:
	weapon_detail_open = false
	if weapon_panel:
		weapon_panel.visible = false
	_apply_responsive_layout()


func _refresh_weapon_detail() -> void:
	if weapon_title == null:
		return
	var stats := WEAPON_SYSTEM.build_stats(
		game_state.equipped_weapon_id,
		game_state.equipped_weapon_mods,
		game_state.get_weapon_enhancement_level(game_state.equipped_weapon_id),
		game_state.mod_enhancement_levels
	)
	weapon_title.text = "%s  +%d" % [weapon_name_state, game_state.get_weapon_enhancement_level(game_state.equipped_weapon_id)]
	weapon_preview.texture = _weapon_preview_texture()
	var full_magazines := floori(float(reserve_state) / float(maxi(1, magazine_size_state)))
	var loose_rounds := reserve_state % maxi(1, magazine_size_state)
	weapon_stats.text = "현재 탄창 %02d / %02d\n예비 %03d발  ·  완전 탄창 %d개 + 낱탄 %d발\n내구도 %.1f%%  ·  탄퍼짐 %.1f°\n피해 %d  ·  반동 %.2f  ·  장전 %.1fs" % [
		magazine_state,
		magazine_size_state,
		reserve_state,
		full_magazines,
		loose_rounds,
		durability_state,
		float(stats.get("base_spread_deg", 0.0)),
		int(stats.get("damage", 0)),
		float(stats.get("recoil_kick", 0.0)),
		float(stats.get("reload_time", 0.0)),
	]
	if weapon_state_action_button:
		weapon_state_action_button.visible = has_weapon_state
	_clear(mod_slot_grid)
	for slot in SLOT_ORDER:
		mod_slot_grid.add_child(_build_mod_slot_button(slot))


func _select_item(item: Dictionary) -> void:
	selected_item = item.duplicate(true)
	_refresh_item_detail()


func _on_bag_item_pressed(item: Dictionary) -> void:
	_select_item(item)
	_update_bag_selection_visual(str(item.get("id", "")))
	_show_inventory_feedback("%s 선택" % str(item.get("title", "아이템")), Color("#d9c579"))
	if not weapon_detail_open or str(item.get("type", "")) != "mod":
		return
	var mod_id := str(item.get("id", ""))
	if int(item.get("quantity", 0)) <= 0:
		return
	var definition := WEAPON_SYSTEM.get_mod(mod_id)
	var installed := _get_mod_in_slot(str(definition.get("slot", "")))
	if installed != mod_id:
		call_deferred("_install_mod", mod_id)


func _update_bag_selection_visual(selected_id: String) -> void:
	if bag_grid == null:
		return
	for child in bag_grid.get_children():
		if child is Button and str(child.name).begins_with("BagItem_"):
			(child as Button).set_pressed_no_signal(
				str(child.name) == "BagItem_%s" % selected_id
			)


func _refresh_item_detail() -> void:
	if item_detail_title == null:
		return
	item_action_button.visible = false
	item_action_button.disabled = false
	item_discard_button.visible = false
	item_discard_button.disabled = false
	if item_detail_reason:
		item_detail_reason.text = ""
		item_detail_reason.visible = false
	if selected_item.is_empty():
		item_detail_icon.texture = UI_ICONS.get_icon("backpack", 72, Color("#71877c"))
		item_detail_title.text = "가방"
		item_detail_description.text = "아이템을 누르면 여기서 살펴본다."
		return

	item_detail_icon.texture = _item_texture(selected_item)
	item_detail_title.text = str(selected_item.get("title", ""))
	item_detail_description.text = str(selected_item.get("description", ""))
	var item_type := str(selected_item.get("type", ""))
	if item_type == "weapon":
		var weapon_id := str(selected_item.get("id", ""))
		var is_equipped: bool = has_weapon_state and weapon_id == str(game_state.equipped_weapon_id)
		if is_equipped:
			item_detail_description.text = "현재 장착 중인 주무기입니다. 해제하면 가방으로 돌아갑니다."
			item_action_button.text = "해제"
			item_action_button.icon = UI_ICONS.get_icon("close", 28, Color("#e4d09a"))
			item_action_button.visible = true
		else:
			item_detail_description.text += "  ·  장착하면 현재 주무기와 교체됩니다."
			item_action_button.text = "장착"
			item_action_button.icon = UI_ICONS.get_icon("upgrade", 28, Color("#bce6ca"))
			item_action_button.visible = true
	elif item_type == "mod":
		var mod_id := str(selected_item.get("id", ""))
		var definition := WEAPON_SYSTEM.get_mod(mod_id)
		var slot := str(definition.get("slot", ""))
		var installed := _get_mod_in_slot(slot)
		var has_quantity := int(selected_item.get("quantity", 0)) > 0
		var available: int = int(game_state.get_weapon_mod_count(mod_id))
		item_detail_description.text = "%s  ·  %s 슬롯  ·  완성 부착물 %d개 보유" % [
			_mod_description(mod_id),
			_slot_name(slot),
			available,
		]
		item_action_button.text = "해제" if installed == mod_id else ("교체" if not installed.is_empty() else "장착")
		item_action_button.icon = UI_ICONS.get_icon("close" if installed == mod_id else "mod", 28, Color("#e1d39a"))
		item_action_button.visible = true
		var check := _get_mod_install_check(mod_id)
		var can_install := bool(check.get("can_install", false))
		item_action_button.disabled = installed != mod_id and (not has_quantity or not can_install)
		if item_action_button.disabled:
			var reason_text := ""
			if installed != mod_id and not has_quantity:
				reason_text = "수량이 부족합니다."
			else:
				reason_text = str(check.get("reason", ""))
			if not reason_text.is_empty() and item_detail_reason:
				item_detail_reason.text = reason_text
				item_detail_reason.visible = true
	elif item_type == "component":
		var item_id := str(selected_item.get("id", ""))
		item_detail_title.text = "제작 재료 · %s" % _component_name(item_id)
		item_detail_description.text = (
			"%s\n\n제작 재료 · 총기에 직접 장착할 수 없습니다.\n"
			+ "쉘터 작업대에서 완성 부착물을 제작할 때 사용합니다.\n"
			+ "보유 수량 %d개"
		) % [_component_description(item_id), int(selected_item.get("quantity", 0))]
	elif item_type == "ammo":
		item_detail_description.text = "%s\n보유 수량 %d발" % [
			str(selected_item.get("description", "총기용 탄약입니다.")),
			int(selected_item.get("quantity", 0)),
		]
	elif item_type == "resource":
		item_detail_description.text = "%s\n보유 수량 %d개" % [
			str(selected_item.get("description", "레이드에서 사용하는 자원입니다.")),
			int(selected_item.get("quantity", 0)),
		]
	elif item_type == "churu":
		item_detail_description.text = "%s\n보유 수량 %d개" % [
			str(selected_item.get("description", "희귀 재화입니다.")),
			int(selected_item.get("quantity", 0)),
		]
	elif item_type == "special_cargo":
		item_detail_description.text = "%s\n특수 화물 · 탈출 시 정산" % str(
			selected_item.get("description", "봉인된 대형 화물입니다.")
		)
	elif item_type == "progression":
		item_detail_description.text = "%s\n보유 수량 %d개" % [
			str(selected_item.get("description", "진행에 필요한 중요 아이템입니다.")),
			int(selected_item.get("quantity", 0)),
		]
	elif item_type == "equipment":
		var equipment_id := str(selected_item.get("id", ""))
		var equipment_definition: Dictionary = game_state.get_equipment_definition(equipment_id)
		var equipment_slot := str(equipment_definition.get("slot", "body"))
		var equipped_id := str(game_state.get_equipped_equipment(equipment_slot))
		var equipment_detail_lines: Array[String] = [
			str(equipment_definition.get("description", "생존 장비입니다.")),
			_format_equipment_stats(equipment_definition),
		]
		var comparison := _format_equipment_comparison(equipment_id, equipment_definition)
		if not comparison.is_empty():
			equipment_detail_lines.append(comparison)
		item_detail_description.text = "\n".join(equipment_detail_lines)
		item_action_button.text = "해제" if equipped_id == equipment_id else "장착"
		var equipment_icon := str(equipment_definition.get("icon", "armor"))
		item_action_button.icon = UI_ICONS.get_icon("close" if equipped_id == equipment_id else equipment_icon, 28, Color("#bce6ca"))
		item_action_button.visible = true

	_configure_discard_button(item_type)


func _configure_discard_button(item_type: String) -> void:
	if item_discard_button == null or item_type == "empty_slot":
		return
	var item_id := str(selected_item.get("id", ""))
	item_discard_button.visible = true
	item_discard_button.text = "버리기"
	item_discard_button.icon = UI_ICONS.get_icon("close", 24, Color("#f0b09a"))
	var protected_item: bool = RAID_ITEM_ECONOMY.is_protected(item_type, item_id)
	var equipped_item: bool = bool(selected_item.get("equipped", false))
	if item_type == "weapon":
		equipped_item = has_weapon_state and item_id == str(game_state.equipped_weapon_id)
	elif item_type == "equipment":
		var definition: Dictionary = game_state.get_equipment_definition(item_id)
		var slot := str(definition.get("slot", "body"))
		equipped_item = str(game_state.get_equipped_equipment(slot)) == item_id
	item_discard_button.disabled = protected_item or equipped_item
	if item_discard_button.disabled and item_detail_reason:
		item_detail_reason.text = (
			"중요 임무 물품은 버릴 수 없습니다."
			if protected_item
			else "장착을 해제한 뒤 버릴 수 있습니다."
		)
		item_detail_reason.visible = true


func _on_selected_item_discard() -> void:
	if selected_item.is_empty() or item_discard_button.disabled:
		return
	var item_type := str(selected_item.get("type", ""))
	var item_id := str(selected_item.get("id", ""))
	var discard_type: String = item_type
	if item_type == "resource":
		discard_type = str({
			"canned_food": "food",
			"medkit": "medkit",
			"churu": "churu",
		}.get(item_id, ""))
	if discard_type.is_empty():
		apply_discard_result(false, "버릴 수 없는 아이템입니다.")
		return
	var quantity := maxi(1, int(selected_item.get("quantity", 1)))
	var amount: int = mini(quantity, int(game_state.get_raid_item_stack_limit(discard_type)))
	item_discard_requested.emit(discard_type, item_id, amount)


func apply_discard_result(success: bool, message: String) -> void:
	if success:
		selected_item = {}
		weapon_detail_open = false
		_refresh_contents()
	_show_inventory_feedback(
		message,
		Color("#e7c26e") if success else Color("#ff9d8f")
	)


func _on_selected_item_action() -> void:
	if selected_item.is_empty():
		return
	var item_type := str(selected_item.get("type", ""))
	var item_id := str(selected_item.get("id", ""))
	if item_type == "weapon":
		if has_weapon_state and item_id == game_state.equipped_weapon_id:
			_request_weapon_unequip()
		else:
			weapon_equipped.emit(item_id)
			if game_state.equipped_weapon_id == item_id and bool(game_state.has_ak):
				_show_inventory_feedback("%s 장착" % str(selected_item.get("title", item_id)), Color("#a3ff92"))
				selected_item = {}
				weapon_detail_open = false
				_refresh_contents()
	elif item_type == "mod":
		var definition := WEAPON_SYSTEM.get_mod(item_id)
		var installed := _get_mod_in_slot(str(definition.get("slot", "")))
		if installed == item_id:
			_unequip_mod(item_id)
		else:
			_install_mod(item_id)
	elif item_type == "equipment":
		var definition: Dictionary = game_state.get_equipment_definition(item_id)
		var slot := str(definition.get("slot", "body"))
		if str(game_state.get_equipped_equipment(slot)) == item_id:
			if game_state.unequip_equipment(slot):
				_show_inventory_feedback("%s 해제" % str(definition.get("display_name", item_id)), Color("#d9c579"))
			else:
				_show_inventory_feedback("가방이 가득 찼습니다 · 가방을 비운 뒤 해제하세요", Color("#ee806c"))
		else:
			game_state.equip_equipment(item_id)
			_show_inventory_feedback("%s 장착" % str(definition.get("display_name", item_id)), Color("#a3ff92"))
		game_state.save_persistent_state()
		equipment_changed.emit()
		selected_item = {}
		_refresh_contents()


func _format_equipment_stats(definition: Dictionary) -> String:
	var stats: Array[String] = []
	var slot := str(definition.get("slot", "body"))
	stats.append("[%s]" % _equipment_slot_display_name(slot))
	var reduction_percent := roundi(float(definition.get("damage_reduction", 0.0)) * 100.0)
	if reduction_percent > 0:
		stats.append("받는 피해 -%d%%" % reduction_percent)
	var move_speed_percent := roundi(float(definition.get("move_speed_bonus", 0.0)) * 100.0)
	if move_speed_percent != 0:
		stats.append("이동 속도 %s%d%%" % ["+" if move_speed_percent > 0 else "", move_speed_percent])
	var stamina_cost_percent := roundi((float(definition.get("stamina_cost_multiplier", 1.0)) - 1.0) * 100.0)
	if stamina_cost_percent != 0:
		stats.append("대시 스태미나 %s%d%%" % ["+" if stamina_cost_percent > 0 else "", stamina_cost_percent])
	# 트레이드오프 — 좋은 것만 보여주면 선택이 아니라 사다리다.
	var visibility_percent := roundi((float(definition.get("visibility_multiplier", 1.0)) - 1.0) * 100.0)
	if visibility_percent != 0:
		stats.append("피탐지 %s%d%%" % ["+" if visibility_percent > 0 else "", visibility_percent])
	var scent_percent := roundi((float(definition.get("scent_multiplier", 1.0)) - 1.0) * 100.0)
	if scent_percent != 0:
		stats.append("냄새 흔적 %s%d%%" % ["+" if scent_percent > 0 else "", scent_percent])
	return "  ·  ".join(stats)


func _format_equipment_comparison(equipment_id: String, definition: Dictionary) -> String:
	var slot := str(definition.get("slot", "body"))
	var equipped_id := str(game_state.get_equipped_equipment(slot))
	if equipped_id == equipment_id:
		return "현재 장착 중"
	if equipped_id.is_empty():
		return "현재 비어 있는 %s 슬롯에 장착 가능" % _equipment_slot_display_name(slot)

	var equipped_definition: Dictionary = game_state.get_equipment_definition(equipped_id)
	var differences: Array[String] = []
	var damage_difference := roundi(
		(float(definition.get("damage_reduction", 0.0))
		- float(equipped_definition.get("damage_reduction", 0.0))) * 100.0
	)
	if damage_difference != 0:
		differences.append("피해 감소 %s%d%%p" % ["+" if damage_difference > 0 else "", damage_difference])
	var speed_difference := roundi(
		(float(definition.get("move_speed_bonus", 0.0))
		- float(equipped_definition.get("move_speed_bonus", 0.0))) * 100.0
	)
	if speed_difference != 0:
		differences.append("이동 속도 %s%d%%p" % ["+" if speed_difference > 0 else "", speed_difference])
	var stamina_difference := roundi(
		(float(equipped_definition.get("stamina_cost_multiplier", 1.0))
		- float(definition.get("stamina_cost_multiplier", 1.0))) * 100.0
	)
	if stamina_difference != 0:
		differences.append("스태미나 효율 %s%d%%p" % ["+" if stamina_difference > 0 else "", stamina_difference])
	if differences.is_empty():
		return "현재 %s와 동일한 기본 성능" % str(equipped_definition.get("display_name", "장비"))
	return "현재 %s 대비  %s" % [
		str(equipped_definition.get("display_name", "장비")),
		"  ·  ".join(differences),
	]


func _equipment_slot_display_name(slot: String) -> String:
	return str({
		"body": "몸 방어구",
		"head": "머리 방어구",
		"feet": "신발",
	}.get(slot, "장비"))


func _on_bag_expand_pressed() -> void:
	var cost := int(game_state.get_bag_upgrade_cost())
	if game_state.try_upgrade_bag_capacity():
		_show_inventory_feedback(
			"가방 +1칸 · 고철 -%s (총 %d칸)" % [
				game_state.format_compact_number(cost),
				int(game_state.get_raid_bag_capacity()),
			],
			Color("#a3ff92")
		)
		_refresh_contents()
	else:
		_show_inventory_feedback("고철이 부족합니다", Color("#ee806c"))


func _on_secure_expand_pressed() -> void:
	if game_state.try_upgrade_secure_dog():
		_show_inventory_feedback(
			"시큐어 슬롯 +1 · 죽어도 %d칸은 지킨다" % int(game_state.secure_dog_slots),
			Color("#a3ff92")
		)
		_refresh_contents()
	else:
		_show_inventory_feedback("츄르가 부족합니다", Color("#ee806c"))


func _request_weapon_unequip() -> void:
	if not has_weapon_state:
		return
	weapon_unequipped.emit()
	if not bool(game_state.has_ak):
		has_weapon_state = false
		weapon_detail_open = false
		selected_item = {}
		_show_inventory_feedback("주무기를 가방에 보관했습니다.", Color("#d9c579"))
		_refresh_contents()
	else:
		# unequip이 거부됐다 = 가방에 그 1정이 들어갈 자리가 없다.
		_show_inventory_feedback("가방이 가득 찼습니다 · 가방을 비운 뒤 해제하세요", Color("#ee806c"))


func _build_mod_slot_button(slot: String) -> Button:
	var installed := _get_mod_in_slot(slot)
	var text := "%s\n비어 있음" % _slot_name(slot)
	if not installed.is_empty():
		text = "%s\n%s\n클릭: 해제" % [_slot_name(slot), _mod_name(installed)]
	var button := _tile_button(text, not installed.is_empty())
	button.name = "ModSlot_%s" % slot
	button.custom_minimum_size = Vector2(216, 72)
	button.icon = _mod_icon(installed) if not installed.is_empty() else _slot_icon(slot)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not installed.is_empty():
		button.pressed.connect(func() -> void: call_deferred("_unequip_mod", installed))
	return button


func _can_install_mod(mod_id: String) -> bool:
	return bool(_get_mod_install_check(mod_id).get("can_install", false))


func _get_mod_install_check(mod_id: String) -> Dictionary:
	var result: Dictionary = _get_mod_compatibility_check(mod_id)
	if not bool(result.get("can_install", false)):
		return result
	var available_mods: int = int(game_state.get_weapon_mod_count(mod_id))
	if available_mods < 1:
		result["can_install"] = false
		result["reason"] = "완성 부착물이 없습니다. 제작 재료는 쉘터 작업대에서 먼저 제작해야 합니다."
		return result
	result["reason"] = "설치 가능"
	return result


func _get_mod_compatibility_check(mod_id: String) -> Dictionary:
	var result: Dictionary = {"can_install": false, "reason": ""}
	if not MOD_COMPONENTS.has(mod_id):
		result["reason"] = "모듈 정보가 없습니다."
		return result
	if not has_weapon_state or str(game_state.equipped_weapon_id).is_empty():
		result["reason"] = "먼저 주무기를 장착하세요."
		return result
	var definition: Dictionary = WEAPON_SYSTEM.get_mod(mod_id)
	if definition.is_empty():
		result["reason"] = "알 수 없는 모듈입니다."
		return result
	var slot: String = str(definition.get("slot", ""))
	var next_mods: Array[String] = []
	next_mods.assign(game_state.equipped_weapon_mods)
	var currently_installed: String = _get_mod_in_slot(slot)
	if not currently_installed.is_empty():
		next_mods.erase(currently_installed)
	next_mods.append(mod_id)
	if slot == "special" and game_state.shelter_workbench_level < 5:
		result["reason"] = "작업대 레벨 5가 필요합니다."
		return result
	if not WEAPON_SYSTEM.validate_mod_loadout(next_mods, game_state.equipped_weapon_id):
		result["reason"] = "슬롯 충돌 또는 장착 불가 부품입니다."
		return result
	result["can_install"] = true
	result["reason"] = "설치 가능"
	return result

func _install_mod(mod_id: String) -> void:
	var check := _get_mod_install_check(mod_id)
	if not bool(check.get("can_install", false)):
		_show_inventory_feedback("장착 실패: %s" % str(check.get("reason", "")), Color("#ff9f9f"))
		return
	var definition := WEAPON_SYSTEM.get_mod(mod_id)
	var slot := str(definition.get("slot", ""))
	var currently_installed := _get_mod_in_slot(slot)
	if not currently_installed.is_empty():
		game_state.add_weapon_mod(currently_installed, 1)
		game_state.equipped_weapon_mods.erase(currently_installed)
	game_state.add_weapon_mod(mod_id, -1)
	game_state.equipped_weapon_mods.append(mod_id)
	game_state.save_equipped_weapon_loadout()
	_show_inventory_feedback("%s 장착" % _mod_name(mod_id), Color("#a3ff92"))
	weapon_mods_changed.emit()
	_refresh_contents()

func _unequip_mod(mod_id: String) -> void:
	if not game_state.equipped_weapon_mods.has(mod_id):
		return
	game_state.add_weapon_mod(mod_id, 1)
	game_state.equipped_weapon_mods.erase(mod_id)
	game_state.save_equipped_weapon_loadout()
	_show_inventory_feedback("%s 해제" % _mod_name(mod_id), Color("#f5c96a"))
	weapon_mods_changed.emit()
	_refresh_contents()


func _get_mod_in_slot(slot: String) -> String:
	for mod_id in game_state.equipped_weapon_mods:
		var definition := WEAPON_SYSTEM.get_mod(str(mod_id))
		if str(definition.get("slot", "")) == slot:
			return str(mod_id)
	return ""


func _equipment_button(slot_name: String, texture: Texture2D, active: bool, callback: Callable = Callable()) -> Button:
	var button := _tile_button("", active)
	button.name = "Equipment_%s" % slot_name
	button.custom_minimum_size = Vector2(132, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = slot_name
	button.icon = (texture if texture != null else UI_ICONS.get_icon(_equipment_icon_name(slot_name), 38, Color("#8fa49a"))) if active else null
	button.expand_icon = active
	button.add_theme_constant_override("icon_max_width", 42)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if active else Control.PRESET_FULL_RECT)
	label.offset_left = 6
	label.offset_top = -24 if active else 4
	label.offset_right = -6
	label.offset_bottom = -4
	label.text = slot_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", font_ref)
	label.add_theme_font_size_override("font_size", 10 if active else 13)
	label.add_theme_color_override("font_color", Color("#dbe4de") if active else Color("#819087"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	button.add_child(label)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _apply_responsive_layout() -> void:
	if inventory_panel == null or weapon_panel == null or shell == null:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var safe := UISafeArea.get_margins(viewport_size)

	var ui_scale := clampf((minf(viewport_size.x / 780.0, viewport_size.y / 1360.0) if viewport_size.y > viewport_size.x else minf(viewport_size.x / 1360.0, viewport_size.y / 780.0)), 0.65, 1.25)
	responsive_compact = viewport_size.x < 1100.0

	if open_button:
		var open_margin := clampf(viewport_size.x * 0.02, 8.0, 18.0)
		var touch := DisplayServer.is_touchscreen_available()
		# 모바일은 원형이라 정사각으로 잡는다.
		var open_h := clampf(minf(46.0 * ui_scale, viewport_size.y * 0.08), 32.0, 48.0) if not touch else clampf(60.0 * ui_scale, 52.0, 68.0)
		var open_w := clampf(minf(118.0 * ui_scale, viewport_size.x * 0.11), 78.0, 118.0) if not touch else open_h
		open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		open_button.offset_left = -safe.z - open_margin - open_w
		open_button.offset_top = safe.y + open_margin + clampf(94.0 * ui_scale, 68.0, 106.0)
		open_button.offset_right = -safe.z - open_margin
		open_button.offset_bottom = open_button.offset_top + open_h
		if not touch:
			open_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if responsive_compact else HORIZONTAL_ALIGNMENT_LEFT
			open_button.add_theme_font_size_override("font_size", 14 if viewport_size.x >= 760 else 11)
		open_button.text = "가방"

	var safe_width := clampf(viewport_size.x - safe.x - safe.z - 24.0, 300.0, 1600.0)
	# 예전에는 최소 340으로 올려 잡아서, 가로 모드 폰처럼 낮은 화면에서는
	# 패널이 화면보다 커져 레이아웃이 무너졌다. 실제 가용 높이를 넘지 않는다.
	var available_height := maxf(160.0, viewport_size.y - safe.y - safe.w - 26.0)
	var safe_height := minf(clampf(available_height, 240.0, 1200.0), available_height)
	var panel_width := clampf(460.0 * ui_scale, 320.0, 540.0)
	if responsive_compact:
		panel_width = clampf(minf(500.0, safe_width - 20.0), 300.0, 520.0)

	var panel_height := minf(clampf(safe_height * 0.94, 260.0, 730.0), safe_height)
	var panel_margin := clampf(minf(16.0, viewport_size.x * 0.020), 8.0, 16.0)
	var showing_weapon := weapon_detail_open and has_weapon_state
	if modal:
		modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var safe_margin := modal.get_node_or_null("InventorySafeMargin") as MarginContainer
		if safe_margin:
			safe_margin.add_theme_constant_override("margin_left", roundi(12.0 + safe.x))
			safe_margin.add_theme_constant_override("margin_top", roundi(12.0 + safe.y))
			safe_margin.add_theme_constant_override("margin_right", roundi(12.0 + safe.z))
			safe_margin.add_theme_constant_override("margin_bottom", roundi(12.0 + safe.w))
		inventory_panel.custom_minimum_size = Vector2(panel_width, panel_height)
		weapon_panel.custom_minimum_size = Vector2(panel_width, panel_height)
		var visible_panel_count := 2 if showing_weapon and not responsive_compact else 1
		var shell_width := panel_width * visible_panel_count
		if visible_panel_count > 1:
			shell_width += 10.0
		shell.custom_minimum_size = Vector2(minf(shell_width, minf(1040.0, safe_width - panel_margin * 2.0)), panel_height)
		modal.position = Vector2.ZERO

	shell.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_theme_constant_override("separation", 10 if not responsive_compact else 0)

	inventory_panel.visible = not (responsive_compact and showing_weapon)
	weapon_panel.visible = showing_weapon

	if inventory_panel.visible and inventory_panel.custom_minimum_size.x < 300.0:
		inventory_panel.custom_minimum_size.x = 300.0
	if weapon_panel.visible and weapon_panel.custom_minimum_size.x < 300.0:
		weapon_panel.custom_minimum_size.x = 300.0
	if inventory_panel:
		var content := inventory_panel.get_node_or_null("MarginContainer") as Control
		if content:
			content.add_theme_constant_override("margin_left", 12 if not responsive_compact else 10)
			content.add_theme_constant_override("margin_top", 10 if not responsive_compact else 8)
			content.add_theme_constant_override("margin_right", 12 if not responsive_compact else 10)
			content.add_theme_constant_override("margin_bottom", 10 if not responsive_compact else 8)

	if bag_scroll:
		# 이중 스크롤 함정: 바깥 패널 스크롤 안에서는 EXPAND_FILL이 무력해서
		# 가방 영역이 최소 110px(1.5줄)로 잘리고 패널 아래엔 죽은 여백이 남았다.
		# 가방을 제외한 섹션들의 자연 높이를 재고, 남는 공간을 전부 가방에 준다.
		var sections_box := bag_scroll.get_parent() as Control
		if sections_box:
			var other_content_height := (
				sections_box.get_combined_minimum_size().y
				- bag_scroll.custom_minimum_size.y
			)
			var inner_available := panel_height - 28.0 - 24.0
			bag_scroll.custom_minimum_size.y = clampf(
				inner_available - other_content_height,
				110.0,
				640.0
			)
	if bag_grid:
		var slot_min := 82.0
		var gap := 6.0
		bag_grid.columns = BAG_GRID_COLUMNS
		if panel_width < (slot_min * BAG_GRID_COLUMNS + gap * (BAG_GRID_COLUMNS - 1)):
			bag_grid.columns = 4
		if panel_width < (slot_min * 4.0 + gap * 3.0):
			bag_grid.columns = 3
		if panel_width < (slot_min * 3.0 + gap * 2.0):
			bag_grid.columns = 2
	if equipped_grid:
		equipped_grid.columns = 2 if panel_width >= 290.0 else 1
		equipped_grid.custom_minimum_size = Vector2(0, 0)
		equipped_grid.add_theme_constant_override("h_separation", 6)
		equipped_grid.add_theme_constant_override("v_separation", 6)
	if mod_slot_grid:
		mod_slot_grid.columns = 2 if panel_width >= 420.0 else 1
		for child in mod_slot_grid.get_children():
			if child is Control:
				(child as Control).custom_minimum_size.x = 0.0 if mod_slot_grid.columns == 1 else 216.0


func _bag_item_button(item: Dictionary) -> Button:
	var quantity := int(item.get("quantity", 0))
	var item_type := str(item.get("type", ""))
	var item_id := str(item.get("id", ""))
	var has_quantity := quantity > 0
	var button := _tile_button("", has_quantity)
	button.disabled = not has_quantity
	button.name = "BagItem_%s" % str(item.get("id", "item"))
	button.toggle_mode = true
	button.button_pressed = (
		not selected_item.is_empty()
		and str(selected_item.get("id", "")) == item_id
		and str(selected_item.get("type", "")) == item_type
	)
	button.custom_minimum_size = Vector2(82, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "%s  x%d" % [str(item.get("title", "")), quantity]
	if not has_quantity:
		button.tooltip_text += " (보유하지 않음)"
	elif item_type == "component":
		button.tooltip_text += " · 제작 재료 (직접 장착 불가)"
	elif item_type == "mod" and not _can_install_mod(item_id):
		var check: Dictionary = _get_mod_install_check(item_id)
		button.tooltip_text += " · %s" % str(check.get("reason", "장착 불가"))
	button.icon = _item_texture(item)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_quantity:
		button.pressed.connect(func() -> void: _on_bag_item_pressed(item))
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -45
	badge.offset_top = -24
	badge.offset_right = -6
	badge.offset_bottom = -4
	badge.text = "x%d" % quantity
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_font_override("font", font_ref)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color("#f2e7c5") if quantity > 0 else Color("#68736e"))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.add_theme_constant_override("outline_size", 4)
	button.add_child(badge)
	if item_type == "component":
		var material_badge := Label.new()
		material_badge.name = "CraftingMaterialBadge"
		material_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		material_badge.offset_left = 5
		material_badge.offset_top = 4
		material_badge.offset_right = 43
		material_badge.offset_bottom = 24
		material_badge.text = "재료"
		material_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		material_badge.add_theme_font_override("font", font_ref)
		material_badge.add_theme_font_size_override("font_size", 9)
		material_badge.add_theme_color_override("font_color", Color("#171a17"))
		material_badge.add_theme_color_override("font_outline_color", Color("#79d4bd"))
		material_badge.add_theme_constant_override("outline_size", 6)
		button.add_child(material_badge)
	if item_type == "equipment" and has_quantity and not bool(item.get("equipped", false)):
		var equipment_definition: Dictionary = game_state.get_equipment_definition(item_id)
		var equipment_level := int(equipment_definition.get("level", 1))
		if equipment_level > 1:
			var level_badge := Label.new()
			level_badge.name = "EquipmentLevelBadge"
			level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			level_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
			level_badge.offset_left = 5
			level_badge.offset_top = 4
			level_badge.offset_right = 43
			level_badge.offset_bottom = 24
			level_badge.text = "Lv%d" % equipment_level
			level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			level_badge.add_theme_font_override("font", font_ref)
			level_badge.add_theme_font_size_override("font_size", 10)
			level_badge.add_theme_color_override(
				"font_color", Color("#ffd98a") if equipment_level >= 4 else Color("#cfe3d6")
			)
			level_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			level_badge.add_theme_constant_override("outline_size", 5)
			button.add_child(level_badge)
		# 지금 낀 것보다 좋으면 ▲ — 리스트만 훑어도 갈아 낄 게 보인다.
		var equipment_slot := str(equipment_definition.get("slot", "body"))
		var equipped_in_slot := str(game_state.get_equipped_equipment(equipment_slot))
		var equipped_score := (
			float(game_state.get_equipment_score(equipped_in_slot))
			if not equipped_in_slot.is_empty()
			else -1.0
		)
		if float(game_state.get_equipment_score(item_id)) > equipped_score:
			var upgrade_badge := Label.new()
			upgrade_badge.name = "EquipmentUpgradeBadge"
			upgrade_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			upgrade_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			upgrade_badge.offset_left = -26
			upgrade_badge.offset_top = 3
			upgrade_badge.offset_right = -5
			upgrade_badge.offset_bottom = 23
			upgrade_badge.text = "▲"
			upgrade_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			upgrade_badge.add_theme_font_override("font", font_ref)
			upgrade_badge.add_theme_font_size_override("font_size", 12)
			upgrade_badge.add_theme_color_override("font_color", Color("#8ef2a0"))
			upgrade_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			upgrade_badge.add_theme_constant_override("outline_size", 5)
			button.add_child(upgrade_badge)
	if bool(item.get("equipped", false)):
		var equipped_badge := Label.new()
		equipped_badge.name = "EquippedBadge"
		equipped_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		equipped_badge.offset_left = 6
		equipped_badge.offset_top = 5
		equipped_badge.offset_right = 29
		equipped_badge.offset_bottom = 28
		equipped_badge.text = "E"
		equipped_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equipped_badge.add_theme_font_override("font", font_ref)
		equipped_badge.add_theme_font_size_override("font_size", 13)
		equipped_badge.add_theme_color_override("font_color", Color("#171a17"))
		equipped_badge.add_theme_color_override("font_outline_color", Color("#e9cf76"))
		equipped_badge.add_theme_constant_override("outline_size", 7)
		button.add_child(equipped_badge)
	return button


func _empty_slot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EmptyBagSlot"
	panel.custom_minimum_size = Vector2(82, 74)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.031, 0.036, 0.6), Color(0.46, 0.52, 0.5, 0.25), 7))
	return panel


func _tile_button(text: String, active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_apply_button_font(button, 11)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.052, 0.061, 0.069, 0.82), Color(0.72, 0.8, 0.77, 0.48 if active else 0.2), 7))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.085, 0.1, 0.105, 0.96), Color("#d9c579"), 7, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.12, 0.1, 0.06, 0.98), Color("#e0b75f"), 7, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.025, 0.03, 0.034, 0.58), Color(0.38, 0.42, 0.4, 0.2), 7))
	return button


func _icon_text_button(text: String, tooltip: String, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, Color("#dce6df"))
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_font(button, 12)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.07, 0.08, 0.084, 0.94), Color(0.55, 0.64, 0.61, 0.55), 6))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.13, 0.105, 0.06, 0.98), Color("#d9c579"), 6))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.035, 0.04, 0.044, 0.65), Color(0.38, 0.42, 0.4, 0.22), 6))
	return button


func _filter_icon_name(filter_id: String) -> String:
	match filter_id:
		"ammo": return "ammo"
		"resource": return "food"
		"weapon": return "weapon"
		"equipment": return "armor"
		"mod": return "mod"
	return "all"


func _equipment_icon_name(slot_name: String) -> String:
	match slot_name:
		"Weapon", "주무기", "보조무기": return "weapon"
		"Armor", "몸 방어구": return "armor"
		"Helmet", "머리 방어구": return "helmet"
		"Footwear", "신발": return "footwear"
		"Backpack", "가방": return "backpack"
		"Secure", "보안 슬롯": return "secure"
		"Accessory", "장신구": return "accessory"
	return "all"


func _item_texture(item: Dictionary) -> Texture2D:
	var texture := item.get("texture") as Texture2D
	if texture != null:
		return texture
	match str(item.get("type", "")):
		"ammo": return UI_ICONS.get_icon("ammo", 64, Color("#d9c16f"))
		"resource": return UI_ICONS.get_icon("food", 64, Color("#e6b65c"))
		"weapon": return UI_ICONS.get_icon("weapon", 64, Color("#c6d2cc"))
		"equipment":
			return _equipment_texture(str(item.get("id", "")), 64)
		"component":
			var component_texture := component_textures.get(str(item.get("id", ""))) as Texture2D
			return component_texture if component_texture != null else UI_ICONS.get_icon("parts", 64, Color("#8fd3c4"))
		"mod": return UI_ICONS.get_icon("mod", 64, Color("#8fd3c4"))
	return UI_ICONS.get_icon("all", 64, Color("#8fa49a"))


func _equipment_texture(equipment_id: String, fallback_size: int = 64) -> Texture2D:
	if game_state != null and not equipment_id.is_empty():
		var definition: Dictionary = game_state.get_equipment_definition(equipment_id)
		var texture_path := str(definition.get("texture_path", ""))
		if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
			var texture := load(texture_path) as Texture2D
			if texture != null:
				return texture
		var slot := str(definition.get("slot", "body"))
		var icon_name := "armor"
		if slot == "head":
			icon_name = "helmet"
		elif slot == "feet":
			icon_name = "footwear"
		return UI_ICONS.get_icon(icon_name, fallback_size, Color("#b8c8be"))
	return UI_ICONS.get_icon("armor", fallback_size, Color("#71877c"))


func _weapon_preview_texture() -> Texture2D:
	if weapon_texture != null:
		return weapon_texture
	return UI_ICONS.get_icon("weapon", 96, Color("#c9d5ce"))


func _section(text: String) -> Label:
	var label := _label(text, 14, Color("#d9ded8"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font_ref)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _apply_button_font(button: Button, size: int) -> void:
	button.add_theme_font_override("font", font_ref)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color("#e4e9e3"))
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.74, 0.72, 0.46))


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _slot_name(slot: String) -> String:
	match slot:
		"sight":
			return "조준경"
		"muzzle":
			return "소염기"
		"stock":
			return "개머리판"
		"magazine":
			return "탄창"
		"tactical":
			return "전술"
		"special":
			return "특수 모듈"
	return slot


func _mod_name(mod_id: String) -> String:
	match mod_id:
		"scope_2x":
			return "폐점포 2x 스코프"
		"muffled_sock":
			return "소리 방지용 양말"
		"sponge_pad":
			return "스펀지 턱받이"
		"quick_mag":
			return "테이프 듀얼 탄창"
		"bell_bait":
			return "딸랑이 방울"
		"ak_precision_receiver":
			return "AK 정밀 수신부"
	return mod_id


func _component_name(component_id: String) -> String:
	match component_id:
		"rubber_gasket":
			return "소음기용 고무 패킹"
		"scope_lens":
			return "스코프 렌즈"
		"magazine_spring":
			return "탄창 스프링"
	return component_id.replace("_", " ").capitalize()


func _component_description(component_id: String) -> String:
	match component_id:
		"rubber_gasket":
			return "소음기와 완충 개머리판의 제작 재료로 쓰는 탄성 부품입니다."
		"scope_lens":
			return "배율 조준경과 정밀 모듈의 제작 재료로 쓰는 광학 부품입니다."
		"magazine_spring":
			return "고속 탄창과 전술 부품의 제작 재료로 쓰는 기계 부품입니다."
	return "총기 부착물 제작에 쓰는 핵심 제작 재료입니다."


func _progression_item_name(item_id: String) -> String:
	match item_id:
		"rifle_blueprint":
			return "소총 제작 청사진"
		"shotgun_blueprint":
			return "산탄총 제작 청사진"
		"sealed_zone_keycard":
			return "봉인구역 키카드"
	return item_id


func _progression_item_description(item_id: String) -> String:
	match item_id:
		"rifle_blueprint":
			return "AK 계열 소총 제작법을 해금하는 희귀 청사진입니다."
		"shotgun_blueprint":
			return "고화력 산탄총 제작법을 해금하는 희귀 청사진입니다."
		"sealed_zone_keycard":
			return "Stage 4 봉인구역 진입에 필요한 보안 키카드입니다."
	return "상위 스테이지 진행에 사용하는 희귀 물품입니다."


func _mod_description(mod_id: String) -> String:
	match mod_id:
		"scope_2x":
			return "조준 시 시야와 중거리 집탄율을 개선합니다."
		"muffled_sock":
			return "총성을 줄이는 임시 소음기입니다."
		"sponge_pad":
			return "반동 회복과 거치 안정성을 높입니다."
		"quick_mag":
			return "재장전 시간을 줄이는 테이프 결합 탄창입니다."
		"bell_bait":
			return "총기 하단에 다는 전술용 방울입니다."
		"ak_precision_receiver":
			return "AK 단발 명중률을 크게 높이는 특수 모듈입니다."
	return "총기 성능을 변경하는 부착물입니다."


func _slot_icon(slot: String) -> ImageTexture:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := Color("#8fcdb2")
	match slot:
		"sight":
			color = Color("#64d4de")
		"muzzle":
			color = Color("#b8bdae")
		"stock":
			color = Color("#a7d27a")
		"magazine":
			color = Color("#d6c06f")
		"tactical":
			color = Color("#dca65b")
		"special":
			color = Color("#e28b5c")
	for y in range(9, 39):
		for x in range(9, 39):
			var distance := Vector2(x - 24, y - 24).length()
			if distance < 14.0 and distance > 8.0:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _mod_icon(mod_id: String) -> Texture2D:
	var cost: Dictionary = MOD_COMPONENTS.get(mod_id, {})
	var component_id := str(cost.get("component", ""))
	var texture := component_textures.get(component_id) as Texture2D
	if texture != null:
		return texture
	var definition := WEAPON_SYSTEM.get_mod(mod_id)
	return _slot_icon(str(definition.get("slot", "")))


func _panel_style(background: Color, border: Color, radius: int, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style
