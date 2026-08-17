class_name ShelterWorkbenchModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const AMMO_TEXTURE := preload("res://assets/items/ammo_762.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")

# 제작대는 "만드는 곳"이지 "재료를 찍어내는 곳"이 아니다. 원자재 3종(렌즈·패킹·
# 스프링)과 탄약은 필드에서만 나온다 — 고철만 있으면 무엇이든 나오던 시절엔
# 출정이 심부름이 되고, 도시를 뒤질 이유가 사라졌다(유저 요구).
const RECIPES := {
	"armor": [
		{
			"id": "craft_scav_vest",
			"name": "누더기 방탄 조끼",
			"desc": "철판을 덧대 꿰맨 생존자 계열 경량 조끼. 첫 방어구로 충분합니다.",
			"cost": {"scrap": 4000, "rubber_gasket": 1, "canned_food": 4},
			"result": {"equipment": "scav_vest", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "craft_patched_sneakers",
			"name": "기워 붙인 운동화",
			"desc": "밑창을 갈아 끼운 생존자 계열 신발. 발소리와 냄새를 줄입니다.",
			"cost": {"scrap": 3000, "rubber_gasket": 1, "canned_food": 3},
			"result": {"equipment": "patched_sneakers", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "craft_riot_vest",
			"name": "진압대 방탄 조끼",
			"desc": "진압 계열 중량 조끼. 튼튼한 대신 실루엣이 커집니다.",
			"cost": {"scrap": 14000, "catnip": 800, "rubber_gasket": 2, "canned_food": 8},
			"result": {"equipment": "riot_vest", "amount": 1},
			"required_tier": 2,
			"required_workbench": 2,
		},
		{
			"id": "craft_tactical_helmet",
			"name": "전술 방탄 헬멧",
			"desc": "진압 계열 헬멧. 내피를 새로 짜 넣어야 해 작업대 숙련이 필요합니다.",
			"cost": {"scrap": 22000, "magazine_spring": 1, "rubber_gasket": 1, "canned_food": 10},
			"result": {"equipment": "tactical_helmet", "amount": 1},
			"required_tier": 2,
			"required_workbench": 3,
		},
		{
			"id": "craft_military_vest",
			"name": "군납 방탄복",
			"desc": "봉쇄선 규격을 흉내 낸 최상급 방탄복. 쉘터가 다 커야 손을 댈 수 있습니다.",
			"cost": {
				"scrap": 70000, "catnip": 5000, "scope_lens": 1,
				"rubber_gasket": 3, "canned_food": 22,
			},
			"result": {"equipment": "military_vest", "amount": 1},
			"required_tier": 4,
			"required_workbench": 4,
		},
	],
	"mods": [
		{
			"id": "scope_2x",
			"name": "폐점포 2x 스코프",
			"desc": "스코프 렌즈를 조립한 완성 조준경입니다.",
			"cost": {"scrap": 1800, "catnip": 600, "scope_lens": 1},
			"result": {"weapon_mod": "scope_2x", "amount": 1},
		},
		{
			"id": "muffled_sock",
			"name": "소리 방지용 양말",
			"desc": "고무 패킹으로 고정한 임시 소음기입니다.",
			"cost": {"scrap": 1500, "rubber_gasket": 1},
			"result": {"weapon_mod": "muffled_sock", "amount": 1},
		},
		{
			"id": "sponge_pad",
			"name": "스펀지 턱받이",
			"desc": "반동 회복을 돕는 완성 개머리판 패드입니다.",
			"cost": {"scrap": 2400, "rubber_gasket": 1},
			"result": {"weapon_mod": "sponge_pad", "amount": 1},
		},
		{
			"id": "quick_mag",
			"name": "테이프 듀얼 탄창",
			"desc": "탄창 스프링을 사용한 빠른 교체용 탄창입니다.",
			"cost": {"scrap": 3200, "catnip": 800, "magazine_spring": 1},
			"result": {"weapon_mod": "quick_mag", "amount": 1},
		},
		{
			"id": "bell_bait",
			"name": "딸랑이 방울",
			"desc": "적의 주의를 유도하는 전술 보조공구입니다.",
			"cost": {"scrap": 1200, "magazine_spring": 1},
			"result": {"weapon_mod": "bell_bait", "amount": 1},
		},
		{
			"id": "ak_precision_receiver",
			"name": "AK 정밀 단발 리시버",
			"desc": "AK의 발사 특성을 바꾸는 특수 전술 모듈입니다.",
			"cost": {"scrap": 25000, "scope_lens": 2},
			"result": {"weapon_mod": "ak_precision_receiver", "amount": 1},
			"required_workbench": 5,
		},
	],
	"weapons": [
		{
			"id": "m1911",
			"name": "M1911 솜방망이",
			"desc": "초반 거지런과 최후의 보루용 권총.",
			"cost": {"scrap": 8000, "canned_food": 5, "rubber_gasket": 1},
			"result": {"weapon": "m1911", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "mp5",
			"name": "MP5 하악이",
			"desc": "기동전과 좀비 소탕에 강한 기관단총.",
			"cost": {"scrap": 20000, "catnip": 1500, "canned_food": 10, "magazine_spring": 2, "rubber_gasket": 1},
			"result": {"weapon": "mp5", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "ak47",
			"name": "AK-47 캣라시니코프",
			"desc": "강한 반동과 총성을 감수하고 화력을 얻는 소총.",
			"cost": {"scrap": 55000, "catnip": 4200, "canned_food": 18, "scope_lens": 1, "magazine_spring": 2},
			"result": {"weapon": "ak47", "amount": 1},
			"required_tier": 3,
			"required_blueprint": "rifle_blueprint",
		},
		{
			"id": "double_barrel",
			"name": "더블배럴 참치 헌터",
			"desc": "장전 중 무방비가 되지만 초근접 저지력이 강한 산탄총.",
			"cost": {"scrap": 45000, "catnip": 3400, "canned_food": 15, "rubber_gasket": 3, "magazine_spring": 2},
			"result": {"weapon": "double_barrel", "amount": 1},
			"required_tier": 3,
			"required_blueprint": "shotgun_blueprint",
		},
	],
	"supplies": [
		{
			"id": "repair_kit",
			"name": "임시 총기 수리",
			"desc": "장착 총기의 내구도를 즉시 조금 회복합니다.",
			"cost": {"scrap": 1500, "rubber_gasket": 1},
			"result": {"repair": 18.0},
		},
		{
			"id": "auto_repair",
			"name": "자동 수리 맡기기",
			"desc": "장착 총기를 작업대에 맡겨 쉘터에 없는 동안에도 내구도를 자동 회복합니다.",
			"cost": {},
			"result": {"auto_repair": true},
		},
		{
			"id": "workbench_upgrade",
			"name": "작업대 시설 확장",
			"desc": "작업대 레벨을 높여 상위 총기와 특수 전술 모듈 제작을 해금합니다.",
			"cost": {},
			"result": {"workbench_upgrade": true},
		},
	],
	"artisan": [
		{
			"id": "artisan_roll",
			"name": "장인 고양이의 야간 제작",
			"desc": "통조림과 고철을 맡겨 현재 쉘터 Tier에서 제작 가능한 무기 하나를 받습니다. 10회 안에는 최고 등급이 확정됩니다.",
			"cost": {},
			"result": {"artisan": true},
		},
	],
	"enhance": [
		{
			"id": "enhance_equipped",
			"name": "장착 무기 영구 강화",
			"desc": "장착 중인 무기에 고철을 투자해 +99까지 피해와 안정성을 영구 강화합니다.",
			"cost": {},
			"result": {"enhance": true},
		},
	],
}

const CATEGORY_NAMES := {
	"armor": "방어구",
	"weapons": "무기",
	"mods": "개조품",
	"supplies": "보급",
	"artisan": "장인 제작",
	"enhance": "+99 강화",
}
const CATEGORY_ICONS := {
	"armor": "armor",
	"weapons": "weapon",
	"mods": "mod",
	"supplies": "repair",
	"artisan": "craft",
	"enhance": "upgrade",
}
const CATEGORY_ORDER := ["armor", "weapons", "mods", "supplies", "artisan", "enhance"]
# 레시피 행 상태 색 — 초록=지금 만들 수 있음, 주황=재료만 모자람, 회색=아직 잠김.
const STATE_COLOR_READY := Color("#8fe0a6")
const STATE_COLOR_SHORT := Color("#e2a35e")
const STATE_COLOR_LOCKED := Color("#7e8a86")

@export var interaction_radius := 3.9

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("WorkbenchSprite") as Sprite3D

var has_focus := false
var ui_layer: CanvasLayer
var selected_category := "armor"
var selected_recipe_id := "craft_scav_vest"
var recipe_list: VBoxContainer
var detail_box: VBoxContainer
# 제작 버튼은 상세 스크롤 밖 고정 바에 산다 — 스크롤 아래에 숨으면(세로 실측
# 168px 초과) 유저는 만들 방법이 없다고 읽는다.
var detail_action_bar: VBoxContainer
var resource_value_labels: Dictionary = {}
# 제작 직후 상세 패널에 잠깐 띄우는 성공 피드백(리빌드에서 살아남도록 상태로 보관).
var craft_feedback_text := ""
var craft_feedback_until_msec := 0


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("shelter_workbench")
	set_meta("module_kind", "workbench")
	if sprite != null:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.region_enabled = false
		sprite.no_depth_test = false
		sprite.render_priority = 12


func get_interaction_prompt() -> String:
	# 이름만으로는 무엇을 만드는지 모른다. 기능을 한 줄로 말한다.
	return "작업대 · 방어구·무기 제작 · +99 강화"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	GameState.claim_workbench_starter_parts()
	_open_ui()
	return "작업대 제작 메뉴를 열었습니다."


func set_interaction_focus(value: bool) -> void:
	has_focus = value
	if sprite:
		sprite.modulate = Color(1.15, 1.12, 0.9, 1.0) if has_focus else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "WorkbenchUILayer"
	# 다른 시설 모달(80~90)과 같은 대역 — HUD 액세서리 위에 확실히 얹힌다.
	ui_layer.layer = 84
	# 가방(inventory_ui)이 열릴 때 이 그룹을 보고 시설 모달을 닫는다.
	ui_layer.add_to_group("shelter_modal_ui")
	var ui_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	ui_parent.add_child(ui_layer)
	_rebuild_ui()


func _rebuild_ui() -> void:
	if not is_instance_valid(ui_layer):
		return
	for child in ui_layer.get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.008, 0.011, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(dim)
	ModalDismiss.install(ui_layer, dim, func() -> void:
		if is_instance_valid(ui_layer):
			ui_layer.queue_free()
	)

	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	var available_size := Vector2(
		viewport_size.x - safe.x - safe.z,
		viewport_size.y - safe.y - safe.w
	)
	var safe_center_offset := Vector2((safe.x - safe.z) * 0.5, (safe.y - safe.w) * 0.5)
	var compact := viewport_size.x < 900.0 or viewport_size.y < 650.0
	var stacked := viewport_size.x < 760.0
	var panel_width := minf(1240.0, maxf(300.0, available_size.x - (20.0 if compact else 40.0)))
	# 세로 화면은 780 상한을 풀어 화면을 위아래로 꽉 쓴다 — 안 그러면
	# 아래 1/3을 버려 놓고 목록·상세가 제 살 깎으며 스크롤된다.
	var height_room := maxf(340.0, available_size.y - (16.0 if compact else 40.0))
	var panel_height := height_room if stacked else minf(780.0, height_room)
	var root := PanelContainer.new()
	root.name = "WorkbenchPanel"
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -panel_width * 0.5 + safe_center_offset.x
	root.offset_top = -panel_height * 0.5 + safe_center_offset.y
	root.offset_right = panel_width * 0.5 + safe_center_offset.x
	root.offset_bottom = panel_height * 0.5 + safe_center_offset.y
	root.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.023, 0.027, 0.95), Color("#8ac2a7"), 2, 10))
	ui_layer.add_child(root)
	# 모달 표준 등장.
	HudStyle.enter_modal(root)

	var inner_margin := 12 if compact else 22
	var margin := _margin(inner_margin, inner_margin, inner_margin, inner_margin)
	root.add_child(margin)
	var main := VBoxContainer.new()
	main.name = "WorkbenchContent"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10 if compact else 14)
	margin.add_child(main)

	main.add_child(_build_header())
	main.add_child(_build_flow_strip())
	main.add_child(_build_tabs())

	var body: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	body.name = "WorkbenchBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if compact else 16)
	main.add_child(body)

	body.add_child(_build_recipe_list())
	body.add_child(_build_detail_panel())
	_refresh_recipe_list()
	_refresh_detail_panel()


func _build_flow_strip() -> Control:
	# 제작대의 한 문장 요약: 재료 → 부품 → 개조품 → 무기. 탭 구조만으로는
	# "스프링을 주워서 뭘 하는가"의 순서가 안 보였다. 현재 탭 단계를 밝게 켠다.
	var strip := HBoxContainer.new()
	strip.name = "WorkbenchFlowStrip"
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	var narrow := get_viewport().get_visible_rect().size.x < 760.0
	# 부품·탄약은 이제 필드에서만 나온다. 흐름의 첫 칸이 "제작"이 아니라
	# "필드 수집"이어야 유저가 원자재를 찾아 헤매지 않는다.
	var steps := [
		["필드 수집" if narrow else "필드에서 부품 수집", ""],
		["→", ""],
		["방어구·무기", "armor"],
		["→", ""],
		["개조품", "mods"],
		["→", ""],
		["+99 강화" if narrow else "장착 후 +99 강화", "enhance"],
	]
	for step in steps:
		var text := str(step[0])
		var step_tab := str(step[1])
		var lit: bool = not step_tab.is_empty() and step_tab == selected_category
		var label := _label(
			text,
			12,
			Color("#f0d98e") if lit else (Color("#57675f") if text == "→" else Color("#8fa398"))
		)
		# HBox에서 autowrap 라벨의 최소 폭은 '한 글자'다 — 스트립 전체가
		# 세로로 한 글자씩 꺾여 내려가는 참사를 만든다.
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		strip.add_child(label)
	return strip


func _build_header() -> Control:
	resource_value_labels.clear()
	var header := VBoxContainer.new()
	header.name = "WorkbenchHeader"
	header.add_theme_constant_override("separation", 8)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.clip_contents = true
	top_row.add_child(title_box)
	var title := _label("제작 작업대  Lv.%d" % GameState.shelter_workbench_level, 30, Color("#f0e6c8"))
	title.name = "WorkbenchTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(title)
	title_box.add_child(_label("방어구·무기를 조립합니다. 재료는 가방과 창고에서 함께 씁니다.", 13, Color("#91a69d")))

	var close := _close_button()
	close.pressed.connect(func() -> void:
		if is_instance_valid(ui_layer):
			ui_layer.queue_free()
	)
	top_row.add_child(close)
	header.add_child(_build_resource_strip())
	return header


func _build_resource_strip() -> Control:
	var strip := HFlowContainer.new()
	strip.name = "WorkbenchResourceStrip"
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("h_separation", 7)
	strip.add_theme_constant_override("v_separation", 6)
	var compact := get_viewport().get_visible_rect().size.x < 1040.0
	for key in ["scrap", "catnip", "canned_food", "scope_lens", "rubber_gasket", "magazine_spring"]:
		var resource_key := str(key)
		# 좁은 화면에서 이름까지 넣으면 정작 수치가 잘려 "아이콘 x"만 남는다.
		# 컴팩트에선 아이콘이 이름을 대신하고 수치만 남긴다.
		var chip := SHELTER_UI.make_resource_chip(
			resource_key,
			_resource_name(resource_key),
			GameState.format_compact_number(_owned_resource(resource_key)),
			_resource_icon(resource_key),
			_resource_accent(resource_key),
			compact,
			not compact
		)
		_fit_chip_text(chip, resource_key)
		var value_label := chip.find_child("ResourceValue_%s" % resource_key, true, false) as Label
		if value_label != null:
			resource_value_labels[resource_key] = value_label
		strip.add_child(chip)
	return strip


func _build_tabs() -> Control:
	var tabs := GridContainer.new()
	var compact := get_viewport().get_visible_rect().size.x < 1040.0
	tabs.columns = 3 if compact else 6
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	for category in CATEGORY_ORDER:
		var tab := _button(str(CATEGORY_NAMES[category]), str(CATEGORY_ICONS[category]))
		tab.name = "WorkbenchTab_%s" % category
		tab.toggle_mode = true
		tab.button_pressed = selected_category == category
		tab.custom_minimum_size = Vector2(0, 40)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.clip_text = true
		tab.pressed.connect(func() -> void:
			selected_category = category
			var recipes: Array = _recipes_for_category(selected_category)
			if not recipes.is_empty():
				selected_recipe_id = str((recipes[0] as Dictionary).get("id", ""))
			_rebuild_ui()
		)
		tabs.add_child(tab)
	return tabs


func _build_recipe_list() -> Control:
	var panel := PanelContainer.new()
	panel.name = "WorkbenchRecipePanel"
	var viewport_size := get_viewport().get_visible_rect().size
	var stacked := viewport_size.x < 760.0
	# 세로 화면은 패널이 화면을 꽉 쓰므로 목록도 더 크게 잡는다.
	panel.custom_minimum_size = Vector2(0.0 if stacked else 330.0, 264.0 if stacked else 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_FILL if stacked else Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.043, 0.049, 0.86), Color("#456b61"), 1, 8))
	var margin := _margin(12, 12, 12, 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "WorkbenchRecipeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.name = "WorkbenchRecipeList"
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 8)
	scroll.add_child(recipe_list)
	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "WorkbenchDetailPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.021, 0.027, 0.032, 0.88), Color("#55776d"), 1, 8))
	var margin := _margin(22, 20, 22, 20)
	panel.add_child(margin)
	# 설명·재료만 스크롤하고 제작 버튼은 바닥에 고정한다.
	var shell := VBoxContainer.new()
	shell.name = "WorkbenchDetailShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.name = "WorkbenchDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	detail_box = VBoxContainer.new()
	detail_box.name = "WorkbenchDetailContent"
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 14)
	scroll.add_child(detail_box)
	detail_action_bar = VBoxContainer.new()
	detail_action_bar.name = "WorkbenchDetailActions"
	detail_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_action_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	detail_action_bar.add_theme_constant_override("separation", 6)
	shell.add_child(detail_action_bar)
	return panel


func _refresh_recipe_list() -> void:
	# UI가 열려 있지 않을 때도 _craft가 호출될 수 있다(프로브·자동화). 조용히 넘긴다.
	if not is_instance_valid(recipe_list):
		return
	_clear(recipe_list)
	var recipes: Array = _recipes_for_category(selected_category)
	for recipe_raw in recipes:
		var recipe: Dictionary = recipe_raw
		# 상태를 글자로만 말하면 목록을 한 줄씩 읽어야 한다. 색으로 먼저 말한다.
		var state_color := _recipe_state_color(recipe)
		var button := _button(
			"%s\n%s" % [str(recipe["name"]), _recipe_list_subtitle(recipe)],
			"",
			state_color
		)
		button.name = "WorkbenchRecipeRow_%s" % str(recipe["id"])
		button.add_theme_color_override("font_color", state_color)
		button.add_theme_color_override("font_hover_color", state_color.lightened(0.2))
		button.icon = _recipe_icon(recipe)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.clip_text = true
		button.toggle_mode = true
		button.button_pressed = str(recipe["id"]) == selected_recipe_id
		button.pressed.connect(func() -> void:
			selected_recipe_id = str(recipe["id"])
			_refresh_recipe_list()
			_refresh_detail_panel()
		)
		recipe_list.add_child(button)


func _refresh_detail_panel() -> void:
	if not is_instance_valid(detail_box):
		return
	_clear(detail_box)
	# 제작 버튼이 사는 고정 바. 없으면(구버전 트리) 상세 본문으로 되돌아간다.
	var action_host: VBoxContainer = detail_box
	if is_instance_valid(detail_action_bar):
		_clear(detail_action_bar)
		action_host = detail_action_bar
	var recipe := _selected_recipe()
	if recipe.is_empty():
		detail_box.add_child(_label("선택된 설계도가 없습니다.", 16, Color("#dfe6de")))
		return

	var title := _label(str(recipe["name"]), 30, Color("#f0e6c8"))
	title.name = "WorkbenchRecipeTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_box.add_child(title)
	var description := _label(str(recipe.get("desc", "")), 16, Color("#cdd8d0"))
	description.name = "WorkbenchRecipeDescription"
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(description)

	var icon_card := PanelContainer.new()
	icon_card.name = "WorkbenchResultCard"
	icon_card.custom_minimum_size = Vector2(170, 118)
	icon_card.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.082, 0.088, 0.8), Color("#8ac2a7"), 1, 8))
	var icon_margin := _margin(12, 10, 12, 10)
	icon_card.add_child(icon_margin)
	var icon_texture := TextureRect.new()
	icon_texture.texture = _recipe_icon(recipe)
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(icon_texture)
	detail_box.add_child(icon_card)

	detail_box.add_child(_section("필요 재료"))
	var cost_box := VBoxContainer.new()
	cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_box.add_theme_constant_override("separation", 6)
	detail_box.add_child(cost_box)
	var effective_cost := _effective_cost(recipe)
	for key in effective_cost.keys():
		var needed := int(effective_cost[key])
		var owned := _owned_resource(str(key))
		var color := Color("#bde5c9") if owned >= needed else Color("#e68576")
		cost_box.add_child(_resource_row(str(key), owned, needed, color))
	var required_tier := int(recipe.get("required_tier", 1))
	if GameState.shelter_tier < required_tier:
		cost_box.add_child(_label("쉘터 Tier %d에서 해금" % required_tier, 16, Color("#e68576")))
	if bool((recipe.get("result", {}) as Dictionary).get("artisan", false)):
		cost_box.add_child(_label("확정 천장 %d / %d" % [GameState.artisan_pity, GameState.ARTISAN_PITY_LIMIT], 16, Color("#d9c579")))
	if bool((recipe.get("result", {}) as Dictionary).get("enhance", false)):
		var level := GameState.get_weapon_enhancement_level(GameState.equipped_weapon_id)
		cost_box.add_child(_label("%s  +%d → +%d" % [GameState.equipped_weapon_id.to_upper(), level, mini(99, level + 1)], 16, Color("#d9c579")))

	detail_box.add_child(_section("결과물"))
	detail_box.add_child(_build_result_preview(recipe))

	var craft := _button(_craft_action_text(recipe), _craft_action_icon(recipe))
	craft.name = "WorkbenchCraftButton"
	craft.custom_minimum_size = Vector2(0, 48)
	craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft.disabled = not _can_craft(recipe)
	craft.pressed.connect(func() -> void:
		_craft(recipe)
	)
	action_host.add_child(craft)

	# 버튼이 죽어 있으면 이유를 말한다 — 회색 버튼만 보여주는 건 UX가 아니다.
	if craft.disabled:
		var reason := _recipe_list_subtitle(recipe)
		if not reason.is_empty():
			var reason_label := _label("잠긴 이유: %s" % reason, 14, Color("#e68576"))
			reason_label.name = "WorkbenchBlockedReason"
			action_host.add_child(reason_label)

	# 제작 직후 성공 피드백 — 리빌드 후에도 잠깐 남아 스르륵 사라진다.
	if not craft_feedback_text.is_empty() and Time.get_ticks_msec() < craft_feedback_until_msec:
		var feedback := _label(craft_feedback_text, 16, Color("#9fdcae"))
		feedback.name = "WorkbenchCraftFeedback"
		feedback.add_theme_font_size_override("font_size", 20)
		action_host.add_child(feedback)
		feedback.pivot_offset = Vector2(0.0, 12.0)
		feedback.scale = Vector2(0.94, 0.94)
		feedback.modulate.a = 0.0
		var tween := feedback.create_tween()
		tween.set_parallel(true)
		tween.tween_property(feedback, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		tween.tween_property(feedback, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(2.2)
		tween.chain().tween_property(feedback, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		# 결과 카드가 튀어오르고 초록빛이 번쩍 — "만들어졌다"를 몸으로 알린다.
		# 문자열 한 줄만으로는 제작 성공을 알아채기 어려웠다(유저 신고).
		if is_instance_valid(icon_card):
			icon_card.pivot_offset = icon_card.custom_minimum_size * 0.5
			var pop := icon_card.create_tween()
			pop.tween_property(icon_card, "scale", Vector2(1.16, 1.16), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.parallel().tween_property(icon_card, "modulate", Color(1.6, 2.1, 1.7, 1.0), 0.14)
			pop.tween_property(icon_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_SINE)
			pop.parallel().tween_property(icon_card, "modulate", Color.WHITE, 0.34)
		# 상단 재화 줄도 함께 깜빡여 "재료가 빠지고 결과가 들어왔다"를 잇는다.
		for key_value in resource_value_labels.keys():
			var resource_label := resource_value_labels[key_value] as Label
			if not is_instance_valid(resource_label):
				continue
			var flash := resource_label.create_tween()
			flash.tween_property(resource_label, "modulate", Color(1.5, 1.9, 1.5, 1.0), 0.12)
			flash.tween_property(resource_label, "modulate", Color.WHITE, 0.4)

func _selected_recipe() -> Dictionary:
	for recipe_raw in _recipes_for_category(selected_category):
		var recipe: Dictionary = recipe_raw
		if str(recipe.get("id", "")) == selected_recipe_id:
			return recipe
	return {}


func _recipes_for_category(category: String) -> Array:
	var recipes: Array = (RECIPES.get(category, []) as Array).duplicate(true)
	if category != "enhance":
		return recipes
	for mod_id in GameState.equipped_weapon_mods:
		var definition := WeaponSystem.get_mod(mod_id)
		if definition.is_empty():
			continue
		recipes.append({
			"id": "enhance_mod_%s" % mod_id,
			"name": "%s 영구 강화" % str(definition.get("display_name", mod_id)),
			"desc": "장착 파츠의 고유 보정치를 +99까지 영구 강화합니다.",
			"cost": {},
			"result": {"enhance_mod": mod_id},
		})
	return recipes


func _can_craft(recipe: Dictionary) -> bool:
	if GameState.shelter_tier < int(recipe.get("required_tier", 1)):
		return false
	if GameState.shelter_workbench_level < int(recipe.get("required_workbench", 1)):
		return false
	var required_blueprint := str(recipe.get("required_blueprint", ""))
	if (
		not required_blueprint.is_empty()
		and GameState.get_progression_item_count(required_blueprint) <= 0
	):
		return false
	for key in _effective_cost(recipe).keys():
		if _owned_resource(str(key)) < int(_effective_cost(recipe)[key]):
			return false
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return GameState.weapon_durability < 100.0 and not GameState.workbench_repair_active
	if bool(result.get("workbench_upgrade", false)):
		return GameState.shelter_workbench_level < 5
	if bool(result.get("enhance", false)):
		return GameState.get_weapon_enhancement_level(GameState.equipped_weapon_id) < GameState.MAX_WEAPON_ENHANCEMENT
	if result.has("enhance_mod"):
		var mod_id := str(result["enhance_mod"])
		return GameState.equipped_weapon_mods.has(mod_id) and GameState.get_mod_enhancement_level(mod_id) < GameState.MAX_WEAPON_ENHANCEMENT
	return true


func _craft(recipe: Dictionary) -> void:
	if not _can_craft(recipe):
		# 조용한 return은 버튼 고장으로 읽힌다 — 못 만드는 이유를 그대로 말한다.
		var blocked_reason := _recipe_list_subtitle(recipe)
		_set_craft_feedback(
			"제작 불가" if blocked_reason.is_empty() else "제작 불가 · %s" % blocked_reason
		)
		return
	var result: Dictionary = recipe.get("result", {})
	if bool(result.get("auto_repair", false)):
		GameState.workbench_repair_active = true
		GameState.workbench_repair_weapon_id = GameState.equipped_weapon_id
		GameState.save_persistent_state()
		_set_craft_feedback("정비 시작 — 다음 출정 복귀까지 수리됩니다")
		_refresh_after_change()
		return
	if bool(result.get("workbench_upgrade", false)):
		if GameState.try_upgrade_workbench():
			GameState.save_persistent_state()
			_set_craft_feedback("작업대 확장 완료 · Lv.%d" % GameState.shelter_workbench_level)
		else:
			# 예전엔 실패하면 아무 말도 없어서 버튼이 고장 난 것처럼 읽혔다.
			_set_craft_feedback(_workbench_upgrade_failure_reason())
		_refresh_after_change()
		return
	if bool(result.get("artisan", false)):
		var artisan_result := GameState.roll_artisan_weapon()
		if not artisan_result.is_empty():
			selected_recipe_id = "artisan_roll"
			_set_craft_feedback("장인의 손길 — 결과를 확인하세요")
		_refresh_after_change()
		return
	if bool(result.get("enhance", false)):
		# 반환 bool을 버리고 무조건 "강화 완료"를 찍던 버그 — 고철이 모자라
		# 아무 일도 안 일어난 판에서도 성공 문구가 나왔다.
		if GameState.try_enhance_weapon(GameState.equipped_weapon_id):
			_set_craft_feedback("강화 완료 · %s +%d" % [
				GameState.equipped_weapon_id.to_upper(),
				GameState.get_weapon_enhancement_level(GameState.equipped_weapon_id),
			])
		else:
			_set_craft_feedback(_weapon_enhance_failure_reason())
		_refresh_after_change()
		return
	if result.has("enhance_mod"):
		var enhance_mod_id := str(result["enhance_mod"])
		if GameState.try_enhance_mod(enhance_mod_id):
			_set_craft_feedback("파츠 강화 완료 · +%d" % GameState.get_mod_enhancement_level(enhance_mod_id))
		else:
			_set_craft_feedback(_mod_enhance_failure_reason(enhance_mod_id))
		_refresh_after_change()
		return
	var cost: Dictionary = _effective_cost(recipe)
	for key in cost.keys():
		_consume_resource(str(key), int(cost[key]))
	if result.has("component"):
		GameState.add_mod_component(str(result["component"]), int(result.get("amount", 1)))
	elif result.has("weapon_mod"):
		GameState.add_weapon_mod(str(result["weapon_mod"]), int(result.get("amount", 1)))
	elif result.has("ammo"):
		var ammo_id := str(result["ammo"])
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + int(result.get("amount", 1)))
	elif result.has("weapon"):
		GameState.add_weapon(str(result["weapon"]), int(result.get("amount", 1)))
	elif result.has("equipment"):
		# 제작품은 항상 기본 레벨(접미사 없음 = Lv.1)이다. 레벨 굴림은 필드 드랍의 몫.
		GameState.add_equipment(str(result["equipment"]), int(result.get("amount", 1)))
	elif result.has("canned_food"):
		GameState.canned_food += int(result["canned_food"])
	elif result.has("repair"):
		GameState.weapon_durability = minf(100.0, GameState.weapon_durability + float(result["repair"]))
	GameState.save_persistent_state()
	_set_craft_feedback("제작 완료 · %s" % str(recipe.get("name", "")))
	_refresh_after_change()


func _set_craft_feedback(message: String) -> void:
	craft_feedback_text = message
	craft_feedback_until_msec = Time.get_ticks_msec() + 3000


# ── 실패 사유 ────────────────────────────────────────────────
# GameState의 try_* 는 bool만 돌려준다. "왜 안 됐는지"는 같은 조건을 여기서
# 다시 읽어 만든다. 사유 없는 실패는 유저에게 버튼 고장으로 읽힌다.
func _shortage_text(key: String, cost: int) -> String:
	return "%s %s 부족" % [
		_resource_name(key),
		GameState.format_compact_number(maxi(0, cost - _owned_resource(key))),
	]


func _workbench_upgrade_failure_reason() -> String:
	if GameState.shelter_workbench_level >= 5:
		return "작업대가 이미 최고 레벨(Lv.5)입니다."
	var cost := GameState.get_workbench_upgrade_cost()
	for key in cost.keys():
		var need := int(cost[key])
		if _owned_resource(str(key)) < need:
			return "작업대 확장 불가 · %s" % _shortage_text(str(key), need)
	return "작업대를 지금 확장할 수 없습니다."


func _weapon_enhance_failure_reason() -> String:
	var weapon_id := str(GameState.equipped_weapon_id)
	if weapon_id.is_empty() or GameState.get_weapon_count(weapon_id) <= 0:
		return "강화 불가 · 장착한 무기가 없습니다."
	if GameState.get_weapon_enhancement_level(weapon_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
		return "강화 불가 · 이미 최고 강화 단계입니다."
	var cost := GameState.get_weapon_enhancement_cost(weapon_id)
	if GameState.scrap < cost:
		return "강화 불가 · %s" % _shortage_text("scrap", cost)
	return "강화에 실패했습니다."


func _mod_enhance_failure_reason(mod_id: String) -> String:
	if not GameState.equipped_weapon_mods.has(mod_id):
		return "파츠 강화 불가 · 해당 부착물을 장착하지 않았습니다."
	if GameState.get_mod_enhancement_level(mod_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
		return "파츠 강화 불가 · 이미 최고 강화 단계입니다."
	var cost := GameState.get_mod_enhancement_cost(mod_id)
	if GameState.scrap < cost:
		return "파츠 강화 불가 · %s" % _shortage_text("scrap", cost)
	return "파츠 강화에 실패했습니다."


func _largest_shortage_text(recipe: Dictionary) -> String:
	# "재료 부족"만으로는 무엇을 더 주워 와야 하는지 알 수 없다. 가장 많이
	# 모자란 재료 하나만 병기해 다음 출정의 목표로 만든다.
	var cost := _effective_cost(recipe)
	var worst_key := ""
	var worst_gap := 0
	for key in cost.keys():
		var gap := int(cost[key]) - _owned_resource(str(key))
		if gap > worst_gap:
			worst_gap = gap
			worst_key = str(key)
	if worst_key.is_empty():
		return ""
	return "%s %s 부족" % [
		_resource_name(worst_key), GameState.format_compact_number(worst_gap)
	]


func _blueprint_hint_text(blueprint_id: String) -> String:
	# 어느 청사진이 어디서 나오는지까지 말해 준다. 청사진은 봉인 보급함
	# 전용 드랍이라, 이걸 모르면 영원히 잠긴 줄로 읽힌다.
	var blueprint_name := str(
		(LOOT_ECONOMY.ITEM_CATALOG.get(blueprint_id, {}) as Dictionary).get("display_name", blueprint_id)
	)
	var source := "봉인 보급함"
	for container_id in LOOT_ECONOMY.CONTAINER_DEFINITIONS.keys():
		var table := LOOT_ECONOMY.CONTAINER_DEFINITIONS[container_id] as Dictionary
		var found := false
		for entry in (table.get("entries", []) as Array):
			if str((entry as Array)[0]) == blueprint_id:
				found = true
				break
		if found:
			source = str(table.get("display_name", source))
			break
	return "%s · %s에서 나옵니다" % [blueprint_name, source]


func get_craftable_count() -> int:
	# 운영 독 배지용 — 지금 당장 만들 수 있는 레시피 수.
	var count := 0
	for category in RECIPES.keys():
		for recipe_raw in _recipes_for_category(str(category)):
			if _can_craft(recipe_raw as Dictionary):
				count += 1
	return count


func _effective_cost(recipe: Dictionary) -> Dictionary:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("workbench_upgrade", false)):
		return GameState.get_workbench_upgrade_cost()
	if bool(result.get("artisan", false)):
		return GameState.get_artisan_roll_cost()
	if bool(result.get("enhance", false)):
		return {"scrap": GameState.get_weapon_enhancement_cost(GameState.equipped_weapon_id)}
	if result.has("enhance_mod"):
		return {"scrap": GameState.get_mod_enhancement_cost(str(result["enhance_mod"]))}
	return (recipe.get("cost", {}) as Dictionary).duplicate(true)


func _refresh_after_change() -> void:
	_refresh_header_resources()
	_refresh_recipe_list()
	_refresh_detail_panel()


func _refresh_header_resources() -> void:
	for key_value in resource_value_labels.keys():
		var key := str(key_value)
		var value_label := resource_value_labels.get(key) as Label
		if is_instance_valid(value_label):
			value_label.text = "x%s" % GameState.format_compact_number(_owned_resource(key))
			# 수치가 길어져도 ELLIPSIS로 잘리지 않게 최소 폭을 다시 잰다.
			var font := value_label.get_theme_font("font")
			if font != null:
				value_label.custom_minimum_size.x = ceilf(font.get_string_size(
					value_label.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					value_label.get_theme_font_size("font_size")
				).x) + 2.0


func _owned_resource(key: String) -> int:
	# 보유 = 가방 + 창고. 복귀 정산이 재료를 창고로 보내는데 제작대가 가방만
	# 본다면, 매번 창고에서 꺼내 오는 심부름이 제작의 전부가 된다(유저 요구).
	return _bag_resource(key) + _stored_resource(key)


func _bag_resource(key: String) -> int:
	match key:
		"scrap":
			return GameState.scrap
		"rubber_gasket", "scope_lens", "magazine_spring":
			return GameState.get_mod_component_count(key)
		"canned_food":
			# 통조림은 쉘터 전체 재고가 곧 보유량이다(창고 보관분도 이미 포함).
			return GameState.canned_food
		"catnip":
			return GameState.catnip
	return 0


func _stored_resource(key: String) -> int:
	match key:
		"rubber_gasket", "scope_lens", "magazine_spring":
			return GameState.get_stored_storage_count("component", key)
	return 0


func _consume_resource(key: String, amount: int) -> void:
	# 가방 몫을 먼저 태우고, 모자란 만큼만 창고에서 덜어낸다.
	var remaining := maxi(0, amount)
	match key:
		"scrap":
			GameState.scrap = maxi(0, GameState.scrap - remaining)
		"rubber_gasket", "scope_lens", "magazine_spring":
			var from_bag := mini(remaining, GameState.get_mod_component_count(key))
			if from_bag > 0:
				GameState.mod_component_inventory[key] = maxi(
					0, GameState.get_mod_component_count(key) - from_bag
				)
				remaining -= from_bag
			if remaining > 0:
				GameState.remove_stored_storage_item("component", key, remaining)
		"canned_food":
			GameState.canned_food = maxi(0, GameState.canned_food - remaining)
		"catnip":
			GameState.catnip = maxi(0, GameState.catnip - remaining)


func _is_recipe_locked(recipe: Dictionary) -> bool:
	# 잠금(티어·작업대·청사진)과 단순 재료 부족은 다른 상태다. 전자는 회색으로
	# "아직 네 차례가 아니다", 후자는 주황으로 "조금만 더 모으면 된다"를 말한다.
	if GameState.shelter_tier < int(recipe.get("required_tier", 1)):
		return true
	if GameState.shelter_workbench_level < int(recipe.get("required_workbench", 1)):
		return true
	var required_blueprint := str(recipe.get("required_blueprint", ""))
	return (
		not required_blueprint.is_empty()
		and GameState.get_progression_item_count(required_blueprint) <= 0
	)


func _recipe_state_color(recipe: Dictionary) -> Color:
	if _is_recipe_locked(recipe):
		return STATE_COLOR_LOCKED
	if _can_craft(recipe):
		return STATE_COLOR_READY
	return STATE_COLOR_SHORT


func _recipe_list_subtitle(recipe: Dictionary) -> String:
	var required_blueprint := str(recipe.get("required_blueprint", ""))
	if (
		not required_blueprint.is_empty()
		and GameState.get_progression_item_count(required_blueprint) <= 0
	):
		# 어느 청사진인지, 어디서 나오는지까지 말한다.
		return "청사진 필요 · %s" % _blueprint_hint_text(required_blueprint)
	var required_tier := int(recipe.get("required_tier", 1))
	if GameState.shelter_tier < required_tier:
		return "쉘터 Tier %d 필요" % required_tier
	var required_workbench := int(recipe.get("required_workbench", 1))
	if GameState.shelter_workbench_level < required_workbench:
		return "작업대 Lv.%d 필요" % required_workbench
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		if GameState.workbench_repair_active:
			return "수리 진행 중"
		return "수리 가능" if GameState.weapon_durability < 100.0 else "수리 불필요"
	# 강화 계열은 재료가 아니라 단계 상한에 걸리는 경우가 따로 있다.
	if bool(result.get("enhance", false)):
		if str(GameState.equipped_weapon_id).is_empty():
			return "장착한 무기 없음"
		if GameState.get_weapon_enhancement_level(GameState.equipped_weapon_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
			return "최고 강화 단계"
	if result.has("enhance_mod"):
		var subtitle_mod_id := str(result["enhance_mod"])
		if not GameState.equipped_weapon_mods.has(subtitle_mod_id):
			return "해당 부착물 미장착"
		if GameState.get_mod_enhancement_level(subtitle_mod_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
			return "최고 강화 단계"
	# "재료 부족"에는 가장 많이 모자란 재료 하나를 병기한다.
	var shortage := _largest_shortage_text(recipe)
	var short_label := "재료 부족" if shortage.is_empty() else "재료 부족 · %s" % shortage
	if bool(result.get("workbench_upgrade", false)):
		return "최고 레벨" if GameState.shelter_workbench_level >= 5 else ("확장 가능" if _can_craft(recipe) else short_label)
	return "제작 가능" if _can_craft(recipe) else short_label


func _result_text(recipe: Dictionary) -> String:
	var result: Dictionary = recipe.get("result", {})
	if result.has("component"):
		return "%s x%d" % [_resource_name(str(result["component"])), int(result.get("amount", 1))]
	if result.has("weapon_mod"):
		var mod_id := str(result["weapon_mod"])
		return "%s x%d" % [
			str(WeaponSystem.get_mod(mod_id).get("display_name", mod_id)),
			int(result.get("amount", 1)),
		]
	if result.has("ammo"):
		return "%s x%d" % [_resource_name(str(result["ammo"])), int(result.get("amount", 1))]
	if result.has("weapon"):
		return "%s x%d" % [_resource_name(str(result["weapon"])), int(result.get("amount", 1))]
	if result.has("equipment"):
		return "%s x%d" % [
			_equipment_display_name(str(result["equipment"])),
			int(result.get("amount", 1)),
		]
	if result.has("canned_food"):
		return "통조림 x%d" % int(result["canned_food"])
	if result.has("repair"):
		return "내구도 +%d%%" % int(result["repair"])
	if bool(result.get("auto_repair", false)):
		return (
			"수리 진행 중 · 시간당 %.0f%%"
			% GameState.get_workbench_repair_per_hour()
			if GameState.workbench_repair_active
			else "시간당 내구도 %.0f%% 회복" % GameState.get_workbench_repair_per_hour()
		)
	if bool(result.get("workbench_upgrade", false)):
		return (
			"최고 레벨"
			if GameState.shelter_workbench_level >= 5
			else "작업대 Lv.%d" % (GameState.shelter_workbench_level + 1)
		)
	if result.has("artisan"):
		return "현재 Tier 무기 1정"
	if result.has("enhance"):
		return "%s +1" % GameState.equipped_weapon_id.to_upper()
	if result.has("enhance_mod"):
		var mod_id := str(result["enhance_mod"])
		return "%s +%d" % [str(WeaponSystem.get_mod(mod_id).get("display_name", mod_id)), GameState.get_mod_enhancement_level(mod_id) + 1]
	return "-"


func _recipe_icon(recipe: Dictionary) -> Texture2D:
	var result: Dictionary = recipe.get("result", {})
	if result.has("weapon"):
		var weapon_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(str(result["weapon"]))
		return weapon_texture if weapon_texture != null else UI_ICONS.get_icon("weapon", 72, Color("#d5ddd8"))
	if result.has("ammo"):
		return AMMO_TEXTURE
	if result.has("component"):
		return _resource_icon(str(result["component"]))
	if result.has("equipment"):
		var equipment_texture := _equipment_texture(str(result["equipment"]))
		if equipment_texture != null:
			return equipment_texture
		return UI_ICONS.get_icon("armor", 72, Color("#a8c6bb"))
	if result.has("weapon_mod"):
		return UI_ICONS.get_icon("mod", 72, Color("#e2a962"))
	if result.has("canned_food"):
		return UI_ICONS.get_icon("food", 72, Color("#e6b65c"))
	if result.has("repair"):
		return UI_ICONS.get_icon("repair", 72, Color("#82c7ba"))
	if bool(result.get("auto_repair", false)):
		return UI_ICONS.get_icon("time", 72, Color("#82c7ba"))
	if bool(result.get("workbench_upgrade", false)):
		return UI_ICONS.get_icon("upgrade", 72, Color("#e2c06b"))
	if result.has("artisan"):
		return UI_ICONS.get_icon("craft", 72, Color("#e2c06b"))
	if result.has("enhance"):
		return UI_ICONS.get_icon("upgrade", 72, Color("#e2c06b"))
	if result.has("enhance_mod"):
		return UI_ICONS.get_icon("mod", 72, Color("#e2a962"))
	return UI_ICONS.get_icon("all", 72, Color("#8ca29a"))


func _craft_action_text(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return "수리 진행 중" if GameState.workbench_repair_active else "자동 수리 맡기기"
	if bool(result.get("workbench_upgrade", false)):
		return "최고 레벨" if GameState.shelter_workbench_level >= 5 else "시설 업그레이드"
	return "제작"


func _craft_action_icon(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return "time"
	if bool(result.get("workbench_upgrade", false)):
		return "upgrade"
	return "craft"


func _resource_icon(key: String) -> Texture2D:
	match key:
		"scope_lens": return SCOPE_LENS_TEXTURE
		"rubber_gasket": return RUBBER_GASKET_TEXTURE
		"magazine_spring": return MAGAZINE_SPRING_TEXTURE
		"762_fmj", "9mm_fmj", "12g_buckshot": return AMMO_TEXTURE
		"scrap": return UI_ICONS.get_icon("scrap", 48, Color("#b9c4c2"))
		"canned_food": return UI_ICONS.get_icon("food", 48, Color("#e6b65c"))
		"churu": return UI_ICONS.get_icon("churu", 48, Color("#e9a66e"))
	return UI_ICONS.get_icon("resource", 48, Color("#9ab4aa"))


func _resource_accent(key: String) -> Color:
	match key:
		"scrap": return Color("#b9c4c2")
		"canned_food": return Color("#efbd66")
		"scope_lens": return Color("#73c5db")
		"rubber_gasket": return Color("#c59b72")
		"magazine_spring": return Color("#d0b16b")
	return Color("#9ab4aa")


func _resource_row(key: String, owned: int, needed: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.name = "ResourceCost_%s" % key
	row.custom_minimum_size = Vector2(0, 38)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = _resource_icon(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_theme_constant_override("separation", 0)
	row.add_child(name_box)
	var name_label := _label(_resource_name(key), 16, Color("#d9ded8"))
	name_label.name = "ResourceName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_box.add_child(name_label)
	# 어디에 있는 재료인지 밝힌다 — "창고에 있는데 왜 못 만드나"를 없앤다.
	var stored := _stored_resource(key)
	if stored > 0:
		var source_label := _label(
			"가방 %s + 창고 %s" % [
				GameState.format_compact_number(_bag_resource(key)),
				GameState.format_compact_number(stored),
			],
			12,
			Color("#8ba49a")
		)
		source_label.name = "ResourceSource"
		source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_box.add_child(source_label)
	# 충족 여부는 체크 표시로 한눈에. 모자란 줄만 붉게 남는다.
	var amount_label := _label("%s / %s  %s" % [
		GameState.format_compact_number(owned),
		GameState.format_compact_number(needed),
		"✓" if owned >= needed else "✗",
	], 17, color)
	amount_label.name = "ResourceAmount"
	amount_label.custom_minimum_size = Vector2(132, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(amount_label)
	return row


func _equipment_display_name(equipment_id: String) -> String:
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	if definition.is_empty():
		return equipment_id
	return str(definition.get("display_name", equipment_id))


func _equipment_texture(equipment_id: String) -> Texture2D:
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	var path := str(definition.get("texture_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _equipment_stat_line(equipment_id: String) -> String:
	# 방어구는 숫자로 고르는 물건이다. 이름만 보여 주면 무엇이 나은지 모른다.
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	if definition.is_empty():
		return ""
	var parts: PackedStringArray = []
	if definition.has("damage_reduction"):
		parts.append("피해감소 %d%%" % roundi(float(definition["damage_reduction"]) * 100.0))
	if definition.has("move_speed_bonus"):
		parts.append("이동 +%d%%" % roundi(float(definition["move_speed_bonus"]) * 100.0))
	if definition.has("stamina_cost_multiplier"):
		parts.append(
			"스태미나 소모 -%d%%"
			% roundi((1.0 - float(definition["stamina_cost_multiplier"])) * 100.0)
		)
	if definition.has("visibility_multiplier"):
		parts.append("피탐지 +%d%%" % roundi((float(definition["visibility_multiplier"]) - 1.0) * 100.0))
	return " · ".join(parts)


func _build_result_preview(recipe: Dictionary) -> Control:
	# 제작 버튼 위 결과물 미리보기 — "뭘 만드는 건지"를 버튼 누르기 전에 본다.
	var card := PanelContainer.new()
	card.name = "WorkbenchResultPreview"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.05, 0.062, 0.068, 0.85), Color("#6f9c8b"), 1, 8)
	)
	var margin := _margin(12, 10, 12, 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.name = "ResultPreviewIcon"
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = _recipe_icon(recipe)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var name_label := _label(_result_text(recipe), 17, Color("#f0e6c8"))
	name_label.name = "ResultPreviewName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	var stat_line := _result_stat_line(recipe)
	if not stat_line.is_empty():
		var stat_label := _label(stat_line, 13, Color("#9fc4b4"))
		stat_label.name = "ResultPreviewStats"
		stat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_box.add_child(stat_label)
	return card


func _result_stat_line(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if result.has("equipment"):
		return _equipment_stat_line(str(result["equipment"]))
	if result.has("weapon"):
		var weapon := WeaponSystem.get_weapon(str(result["weapon"])) as Dictionary
		if weapon.is_empty():
			return ""
		var interval := maxf(0.01, float(weapon.get("fire_interval", 0.2)))
		return "피해 %d · 탄창 %d · 연사 %.1f/s" % [
			int(weapon.get("damage", 0)),
			int(weapon.get("magazine_size", 0)),
			1.0 / interval,
		]
	if result.has("weapon_mod"):
		var mod := WeaponSystem.get_mod(str(result["weapon_mod"])) as Dictionary
		return str(mod.get("slot", "")).to_upper() if not mod.is_empty() else ""
	return ""


func _resource_name(key: String) -> String:
	match key:
		"scrap":
			return "고철"
		"catnip":
			return "캣닢"
		"scope_lens":
			return "스코프 렌즈"
		"rubber_gasket":
			return "고무 패킹"
		"magazine_spring":
			return "탄창 스프링"
		"762_fmj":
			return "7.62mm 보통탄"
		"9mm_fmj":
			return "9mm 보통탄"
		"12g_buckshot":
			return "12게이지 벅샷"
		"m1911":
			return "M1911 솜방망이"
		"mp5":
			return "MP5 하악이"
		"ak47":
			return "AK-47 캣라시니코프"
		"double_barrel":
			return "더블배럴 참치 헌터"
		"canned_food":
			return "통조림"
	# 방어구 ID는 장비 정의가 이름을 안다(레벨 접미사까지 해석한다).
	var equipment_definition: Dictionary = GameState.get_equipment_definition(key)
	if not equipment_definition.is_empty():
		return str(equipment_definition.get("display_name", key))
	return key


func _button(text: String, icon_name := "", accent := HudStyle.LINE_FOCUS) -> Button:
	# 스타일은 디자인 시스템이 정한다. 여기서는 내용(텍스트·아이콘)만.
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 30, HudStyle.TEXT)
		# 대형 재화 PNG가 버튼 전체로 부풀지 않게 폭을 못 박는다.
		button.add_theme_constant_override("icon_max_width", 28)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return HudStyle.style_button(button, accent)


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce6df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _fit_chip_text(chip: PanelContainer, resource_id: String) -> PanelContainer:
	# 자원 칩 이름 라벨은 ELLIPSIS라 최소 폭이 1px이다 — 옆의 수치 라벨이
	# EXPAND_FILL로 남는 폭을 다 먹으면 이름("스코프 렌즈" 등)이 통째로 사라진다.
	for label_name in ["ResourceName_%s" % resource_id, "ResourceValue_%s" % resource_id]:
		var label := chip.find_child(label_name, true, false) as Label
		if label == null:
			continue
		var font := label.get_theme_font("font")
		if font == null:
			continue
		label.custom_minimum_size.x = ceilf(font.get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label.get_theme_font_size("font_size")
		).x) + 2.0
	return chip


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _section(text: String) -> Label:
	var label := _label(text, 16, Color("#d9ded8"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 9
	style.content_margin_top = 8
	style.content_margin_right = 9
	style.content_margin_bottom = 8
	return style
