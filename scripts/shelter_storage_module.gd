class_name ShelterStorageModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
# 쉘터 UI 공용 디자인 언어(이름 짓기 화면 기준) — 색·반지름·글자는 여기서만 가져온다.
const SHELTER_THEME := preload("res://scripts/hud/shelter_theme.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

const ITEM_NAMES := {
	"m1911": "M1911",
	"mp5": "MP5",
	"ak47": "AK-47",
	"double_barrel": "더블 배럴 산탄총",
	"akm": "AKM 개조형",
	"k2": "K2 전투소총",
	"pump_shotgun": "펌프 산탄총",
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
	"precision_gear": "정밀 기어",
	"military_alloy": "군용 합금",
	"artisan_seal": "장인의 인장",
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
	"rifle_blueprint": "소총 제작 청사진",
	"shotgun_blueprint": "산탄총 제작 청사진",
	"akm_blueprint": "AKM 개조 청사진",
	"pump_blueprint": "펌프 산탄총 청사진",
	"sealed_zone_keycard": "봉쇄구역 키카드",
	"namdaemun_depot_plans": "남대문 창고 설계도",
	"euljiro_grid_schematic": "을지로 배전 도면",
	"yongsan_control_key": "용산 통제 키",
}

const COMPONENT_TEXTURES := {
	"rubber_gasket": "res://assets/items/mod_components/rubber_gasket.png",
	"scope_lens": "res://assets/items/mod_components/scope_lens.png",
	"magazine_spring": "res://assets/items/mod_components/magazine_spring.png",
}

# 슬롯 버튼 반지름 — 카드(14)보다 한 단계 작다.
const SLOT_RADIUS := 10

@export var interaction_radius := 4.0

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("StorageSprite") as Sprite3D

var ui_layer: CanvasLayer
var content: VBoxContainer
var feedback_label: Label
# 목록 스크롤 높이를 패널 높이에서 역산한다 — 고정값(390)을 쓰면 가로 720 화면에서
# 패널이 화면 아래로 47px 삐져나갔다.
var panel_height_budget := 620.0


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
	return "창고를 열었습니다."


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

	var dim := SHELTER_THEME.dim_backdrop()
	modal.add_child(dim)
	ModalDismiss.install(ui_layer, dim, _close_ui)

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
	# 화면에서 실제로 쓸 수 있는 크기를 절대 넘지 않는다.
	var panel_width := minf(1120.0, maxf(280.0, available_size.x - outer_margin * 2.0))
	var height_room := maxf(320.0, available_size.y - outer_margin * 2.0)
	var panel_height := height_room if portrait else minf(720.0, height_room)
	panel_height_budget = panel_height
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	# 모달 판의 안쪽 여백은 스타일박스가 쥔다 — 작은 화면에선 조금 줄인다.
	var panel_style := SHELTER_THEME.modal_style()
	if viewport_size.y < 640.0:
		var inner_margin := 14.0
		panel_style.content_margin_left = inner_margin
		panel_style.content_margin_right = inner_margin
		panel_style.content_margin_top = inner_margin
		panel_style.content_margin_bottom = inner_margin
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	# 모달 표준 등장 — 툭 나타나지 않는다.
	SHELTER_THEME.enter(panel)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
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
	# 헤더: 민트 이름표 / 굵은 제목 / 회색 설명 ······ [고철·츄르 칩] [둥근 닫기]
	var header := SHELTER_THEME.modal_header(
		"쉘터 창고",
		"Lv.%d · 가방과 창고 사이에서 장비를 옮깁니다." % GameState.storage_level,
		_close_ui,
		"창고"
	)
	header.name = "StorageHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header)
	# 지갑 칩은 아이콘 + 수치만(이름은 툴팁) — 재화 표기 규칙.
	# HFlow는 헤더 안에서 최소 폭(칩 하나)만 받아 세로로 줄바꿈된다 — 한 줄로 나란히.
	var wallet := HBoxContainer.new()
	wallet.name = "StorageWallet"
	wallet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wallet.add_theme_constant_override("separation", 8)
	wallet.add_child(_currency_chip("scrap", GameState.format_compact_number(GameState.scrap)))
	wallet.add_child(_currency_chip("churu", GameState.format_compact_number(GameState.churu)))
	header.add_child(wallet)
	header.move_child(wallet, 1)
	var close := header.get_meta("close_button") as Button
	close.name = "CloseButton"
	# 닫기는 아이콘 하나(글자 없음) — 특수기호 대신 그린 아이콘을 쓴다.
	close.text = ""
	close.icon = UI_ICONS.get_icon("close", 20, SHELTER_THEME.TEXT)
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.tooltip_text = "닫기"

	# 귀중품은 쓸 데가 없다. 여기가 유일한 출구다.
	var valuable_total: int = GameState.get_valuable_total_value()
	if valuable_total > 0:
		var sell := SHELTER_THEME.secondary_button(
			"귀중품 전부 팔기 · 고철 +%s" % GameState.format_compact_number(valuable_total),
			true
		)
		sell.name = "SellValuablesButton"
		sell.pressed.connect(_sell_valuables, CONNECT_DEFERRED)
		content.add_child(sell)

	var summary := GridContainer.new()
	summary.name = "StorageSummary"
	summary.columns = 1 if viewport_size.x < 700.0 else 2
	summary.add_theme_constant_override("h_separation", 10)
	summary.add_theme_constant_override("v_separation", 10)
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
	# 목록 높이는 패널이 남긴 만큼만 — 헤더·요약·판매/확장 줄은 스크롤 밖 고정이라
	# 그 몫(가로 320 / 세로 두 칸 432)을 먼저 떼고 나눠 준다.
	var list_height := (
		clampf((panel_height_budget - 432.0) * 0.5, 130.0, 460.0)
		if narrow
		else clampf(panel_height_budget - 320.0, 130.0, 460.0)
	)
	body.add_child(_build_backpack_panel(narrow, list_height))
	body.add_child(_build_storage_panel(narrow, compact, list_height))

	feedback_label = _label("", SHELTER_THEME.TYPE_CAPTION, SHELTER_THEME.TEXT_DIM)
	feedback_label.name = "StorageFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(feedback_label)


func _build_backpack_panel(narrow: bool, list_height: float) -> Control:
	var panel := SHELTER_THEME.card()
	panel.name = "BackpackItemsPanel"
	panel.custom_minimum_size = Vector2(0 if narrow else 330, 180 if narrow else 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	var backpack_count := 0
	for entry in _get_backpack_entries():
		backpack_count += int(entry.get("count", 0))
	# 예전엔 가운데 스페이서가 EXPAND_FILL로 남는 폭을 다 먹어, 양옆 라벨이
	# 폭 1px로 찌그러지고 ELLIPSIS 때문에 글자가 통째로 사라졌다.
	title_row.add_child(_section_title("가방"))
	title_row.add_child(_section_value("%d개" % backpack_count, 56.0))

	var scroll := SHELTER_THEME.scroll()
	scroll.name = "BackpackItemScroll"
	scroll.custom_minimum_size.y = list_height
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
		var empty := _label("보관 가능한 소지품이 없습니다.", SHELTER_THEME.TYPE_BODY - 1, SHELTER_THEME.TEXT_FAINT)
		empty.custom_minimum_size.y = 72
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list.add_child(empty)
	else:
		for entry in entries:
			list.add_child(_backpack_item_button(entry))
	return panel


func _build_storage_panel(narrow: bool, compact: bool, list_height: float) -> Control:
	# 창고가 가득 차면 판 테두리가 민트로 켜진다 — 더 못 넣는다는 걸 색이 먼저 말한다.
	var storage_full := GameState.get_storage_used_slots() >= GameState.get_storage_capacity()
	var panel := SHELTER_THEME.card(false, storage_full)
	panel.name = "StorageGridPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	# 스페이서가 폭을 다 먹어 "창고"/"0 / 30 슬롯"이 1px로 사라지던 자리.
	title_row.add_child(_section_title("창고"))
	title_row.add_child(_section_value(
		"%d / %d 슬롯" % [GameState.get_storage_used_slots(), GameState.get_storage_capacity()],
		94.0
	))

	var scroll := SHELTER_THEME.scroll()
	scroll.name = "StorageGridScroll"
	scroll.custom_minimum_size.y = list_height
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
	button.text = "%s\n보유 %d · 보관" % [_item_name(item_id), count]
	button.icon = _item_texture(item_type, item_id, 42)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 42)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_CAPTION)
	button.add_theme_color_override("font_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_hover_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_pressed_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_focus_color", SHELTER_THEME.TEXT)
	_apply_slot_styles(button)
	button.pressed.connect(_deposit_item.bind(item_type, item_id))
	return button


func _storage_slot_button(slot_index: int, entry: Dictionary, cell_size: int) -> Button:
	var button := Button.new()
	button.name = "StorageSlot_%02d" % slot_index
	button.custom_minimum_size = Vector2(cell_size, cell_size)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", SHELTER_THEME.tabular())
	button.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_CAPTION - 1)
	button.add_theme_color_override("font_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_hover_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_pressed_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_focus_color", SHELTER_THEME.TEXT)
	_apply_slot_styles(button)
	if entry.is_empty():
		button.disabled = true
		button.icon = UI_ICONS.get_icon("all", 24, Color(SHELTER_THEME.TEXT_FAINT, 0.35))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return button
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var count := int(entry.get("count", 0))
	button.icon = _item_texture(item_type, item_id, 40)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 40)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "x%d" % count
	button.tooltip_text = "%s x%d\n꺼내기" % [_item_name(item_id), count]
	button.pressed.connect(_withdraw_slot.bind(slot_index))
	return button


func _apply_slot_styles(button: Button) -> void:
	# 슬롯·소지품 버튼: SURFACE_RAISED 둥근 사각, 호버는 한 단계 밝게, 누르면 민트 테두리.
	# 빈 슬롯(disabled)은 바탕만 옅게 남긴다.
	button.add_theme_stylebox_override("normal", _slot_style(SHELTER_THEME.SURFACE_RAISED))
	button.add_theme_stylebox_override("hover", _slot_style(SHELTER_THEME.SURFACE_HOVER))
	button.add_theme_stylebox_override("pressed", _slot_style(SHELTER_THEME.SURFACE_HOVER, true))
	button.add_theme_stylebox_override("focus", _slot_style(SHELTER_THEME.SURFACE_RAISED))
	button.add_theme_stylebox_override("disabled", _slot_style(Color(SHELTER_THEME.SURFACE_RAISED, 0.45)))


func _slot_style(background: Color, accent_border := false) -> StyleBoxFlat:
	var style := SHELTER_THEME.flat(
		background,
		SLOT_RADIUS,
		Color(SHELTER_THEME.ACCENT, 0.8) if accent_border else Color(0, 0, 0, 0),
		2 if accent_border else 0
	)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _upgrade_card() -> Control:
	var cost := GameState.get_storage_upgrade_cost()
	if cost.is_empty():
		return _summary_card("확장", "최대 등급", "upgrade")
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	# 확장 카드: 왼쪽에 설명 + 비용 칩, 오른쪽에 주 버튼 하나.
	var panel := SHELTER_THEME.card()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	column.add_child(SHELTER_THEME.caption("확장 비용"))
	var costs := HFlowContainer.new()
	costs.add_theme_constant_override("h_separation", 6)
	costs.add_theme_constant_override("v_separation", 6)
	column.add_child(costs)
	var scrap_chip := _currency_chip("scrap", GameState.format_compact_number(scrap_cost))
	scrap_chip.name = "CostChip_scrap"
	if GameState.scrap < scrap_cost:
		(scrap_chip.get_meta("label") as Label).add_theme_color_override("font_color", SHELTER_THEME.DANGER)
	costs.add_child(scrap_chip)
	if churu_cost > 0:
		var churu_chip := _currency_chip("churu", str(churu_cost))
		churu_chip.name = "CostChip_churu"
		if GameState.churu < churu_cost:
			(churu_chip.get_meta("label") as Label).add_theme_color_override("font_color", SHELTER_THEME.DANGER)
		costs.add_child(churu_chip)
	var button := SHELTER_THEME.primary_button("Lv.%d 확장" % (GameState.storage_level + 1))
	button.name = "StorageUpgradeButton"
	button.custom_minimum_size = Vector2(116, SHELTER_THEME.BUTTON_HEIGHT_SMALL + 4.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = GameState.scrap < scrap_cost or GameState.churu < churu_cost
	button.pressed.connect(_upgrade_storage)
	row.add_child(button)
	return panel


func _summary_card(title: String, value: String, icon_name: String) -> Control:
	var card := SHELTER_THEME.stat_card(
		title,
		value,
		UI_ICONS.get_icon(icon_name, 34, SHELTER_THEME.TEXT_DIM)
	)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := card.get_meta("value_label") as Label
	if value_label != null:
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# ELLIPSIS 라벨은 최소 폭이 1px이라 못 박지 않으면 글자째 사라진다.
		value_label.custom_minimum_size.x = 76.0
	return card


func _section_title(text: String, color := SHELTER_THEME.TEXT) -> Label:
	# 남는 폭은 제목이 가져간다 — 값 라벨은 제 글자 폭만 쓴다.
	var label := SHELTER_THEME.label(text, SHELTER_THEME.TYPE_SECTION, color, true)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 48.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _section_value(text: String, min_width: float) -> Label:
	var label := SHELTER_THEME.number(text, SHELTER_THEME.TYPE_CAPTION + 1, SHELTER_THEME.TEXT_DIM)
	label.custom_minimum_size.x = min_width
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _currency_chip(currency_id: String, value_text: String) -> PanelContainer:
	# 재화 표기 규칙(유저 확정): 아이콘이 이름이다. 칩엔 아이콘 + "xN"만 적고
	# 이름은 툴팁이 말한다. 노드 이름(ResourceChip_/ResourceIcon_/ResourceValue_)은
	# 프로브가 찾는 규약이라 그대로 둔다.
	var chip := SHELTER_THEME.chip(
		"x%s" % value_text,
		UI_ICONS.get_icon(currency_id, 42, SHELTER_UI.get_currency_color(currency_id))
	)
	chip.name = "ResourceChip_%s" % currency_id
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = "%s x%s" % [str(SHELTER_UI.CURRENCY_NAMES.get(currency_id, currency_id)), value_text]
	var row := chip.get_child(0)
	if row != null and row.get_child_count() > 0 and row.get_child(0) is TextureRect:
		(row.get_child(0) as TextureRect).name = "ResourceIcon_%s" % currency_id
	var value_label := chip.get_meta("label") as Label
	if value_label != null:
		value_label.name = "ResourceValue_%s" % currency_id
	return chip


func _get_backpack_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_dictionary_entries(entries, "weapon", GameState.weapon_inventory)
	_append_dictionary_entries(entries, "equipment", GameState.equipment_inventory)
	_append_dictionary_entries(entries, "ammo", GameState.ammo_inventory)
	_append_dictionary_entries(entries, "component", GameState.mod_component_inventory)
	_append_dictionary_entries(entries, "mod", GameState.weapon_mod_inventory)
	# 청사진·키카드도 복귀 정산으로 창고에 들어간다 — 목록에서 보이고 꺼낼 수 있어야 한다.
	_append_dictionary_entries(entries, "progression", GameState.progression_item_inventory)
	if GameState.medkits > 0:
		entries.append({"type": "medkit", "id": "medkit", "count": GameState.medkits})
	# 통조림은 창고에 넣지 않는다 — 필드에선 투척 소모품이고, 귀환 정산이 쉘터
	# 훈련 재고로 옮긴다(창고를 거칠 이유가 없다).
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
		SHELTER_THEME.ACCENT if success else SHELTER_THEME.DANGER
	)


func _item_name(item_id: String) -> String:
	# 레벨 장비("scav_vest@3")는 정의 조회가 "이름 Lv.3"까지 만들어 준다.
	var equipment_definition: Dictionary = GameState.get_equipment_definition(item_id)
	if not equipment_definition.is_empty():
		return str(equipment_definition.get("display_name", item_id))
	if ITEM_NAMES.has(item_id):
		return str(ITEM_NAMES[item_id])
	# 설계도 조각 등 새 진행 아이템은 카탈로그 이름으로.
	var catalog_name := str((GameState.LOOT_ECONOMY.ITEM_CATALOG.get(item_id, {}) as Dictionary).get("display_name", ""))
	return catalog_name if not catalog_name.is_empty() else item_id.replace("_", " ").capitalize()


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
		"progression":
			icon_name = "secure" if item_id == "sealed_zone_keycard" else "craft"
	return UI_ICONS.get_icon(icon_name, size, SHELTER_THEME.GOLD)


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


func _close_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	# 한 줄 라벨(줄바꿈 없음, 넘치면 말줄임) — 목록·피드백처럼 높이가 고정된 자리용.
	var label := SHELTER_THEME.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
