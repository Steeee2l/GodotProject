class_name RaidHud
extends RefCounted

# 출정 화면의 HUD 노드 소유자.
#
# main.gd에 448줄짜리 _build_weapon_hud()와 34개의 노드 변수가 흩어져 있었다.
# HUD 노드를 여기로 모으면 main은 '무엇을 보여줄지'만 말하면 된다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const HudStyle := preload("res://scripts/hud/hud_style.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const AMMO_762_TEXTURE := preload("res://assets/items/ammo_762.png")
const FATIGUE_MAX := 100.0
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")

var host: Node
const AIM_RETICLE_SCRIPT := preload("res://scripts/aim_reticle.gd")
const DYNAMIC_INCIDENT_DURATION := 150.0
const ROLL_COOLDOWN_INDICATOR_SCRIPT := preload("res://scripts/roll_cooldown_indicator.gd")
var raid_pressure_panel: PanelContainer
var raid_pressure_icon: TextureRect
var raid_pressure_title: Label
var raid_pressure_detail: Label
var raid_pressure_bar: ProgressBar
var dynamic_incident_hud: PanelContainer
var dynamic_incident_title: Label
var dynamic_incident_detail: Label
var dynamic_incident_progress: ProgressBar
var reinforcement_call_panel: PanelContainer
var reinforcement_call_title: Label
var reinforcement_call_detail: Label
var reinforcement_call_bar: ProgressBar
var extraction_result_panel: PanelContainer
var extraction_result_title: Label
var extraction_route_icon: TextureRect
var extraction_route_label: Label
var extraction_result_summary: Label
var extraction_stat_row: HBoxContainer
var extraction_reward_flow: HFlowContainer
var extraction_xp_bar: ProgressBar
var extraction_xp_label: Label
var extraction_level_choice_title: Label
var extraction_level_choice_row: HBoxContainer
var extraction_return_row: HBoxContainer
var extraction_return_hint: Label
var extraction_return_button: Button
var jackpot_hud: PanelContainer
var jackpot_step_label: Label
var jackpot_detail_label: Label
var jackpot_pressure_label: Label
var jackpot_progress: ProgressBar
var damage_feedback_canvas: CanvasLayer
var damage_vignette: ColorRect
var damage_vignette_material: ShaderMaterial
var damage_direction_indicator: TextureRect
var player_world_health_bar: Control
var player_world_health_fill: Panel
var player_health_fill_style: StyleBoxFlat
var roll_cooldown_indicator: Control
var reload_reticle_indicator: Control
var aim_direction_indicator: MeshInstance3D
var laser_beam: MeshInstance3D
var laser_beam_mesh: BoxMesh
var laser_endpoint: MeshInstance3D
var aim_canvas: CanvasLayer
var aim_reticle: Control
var ammo_notice: Label
var toast_stack: VBoxContainer
var combat_feedback: CombatFeedbackOverlay
var cover_chip: PanelContainer
var cover_chip_label: Label
var cover_chip_icon: TextureRect
var cover_chip_state := ""
var ammo_pickup_button: Button
var ammo_prompt_panel: PanelContainer
var dash_button: Button
var equipment_ammo_label: Label
var equipment_name_label: Label
var equipment_ammo_type_label: Label
var equipment_condition_label: Label
var equipment_panel: PanelContainer
var equipment_reload_bar: ProgressBar
var equipment_weapon_image: TextureRect
var fatigue_bar: ProgressBar
var fatigue_fill_style: StyleBoxFlat
var fatigue_panel: PanelContainer
var fatigue_status_label: Label
var field_interaction_action_card: PanelContainer
var field_interaction_action_detail_label: Label
var field_interaction_action_label: Label
var field_interaction_button: Button
var field_interaction_duration_label: Label
var field_interaction_icon: TextureRect
var field_interaction_key_label: Label
var field_interaction_key_panel: PanelContainer
var field_interaction_panel: PanelContainer
var field_interaction_progress: ProgressBar
var field_interaction_touch_held := false
var fire_button: Button
var inventory_ui: Control
var melee_button: Button


func attach(owner_node: Node) -> void:
	# 어떤 build_*/setup_* 보다 먼저 불러야 한다. 예전에는 host 설정이
	# build() 안에 있어서, 그보다 먼저 호출되는 setup_aim_feedback()에서
	# host가 null이었다.
	host = owner_node


func build(owner_node: Node) -> void:
	host = owner_node
	var font := load("res://assets/fonts/Pretendard-Regular.otf") as Font
	var touch_enabled := DisplayServer.is_touchscreen_available()
	ammo_prompt_panel = PanelContainer.new()
	ammo_prompt_panel.name = "AmmoPickupPrompt"
	ammo_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_prompt_panel.offset_left = -170
	ammo_prompt_panel.offset_top = -198
	ammo_prompt_panel.offset_right = 170
	ammo_prompt_panel.offset_bottom = -144
	ammo_prompt_panel.add_theme_stylebox_override("panel", HudStyle.panel(HudStyle.INK, Color("#b8a66d")))
	ammo_prompt_panel.visible = false
	host.get_node("HUD").add_child(ammo_prompt_panel)
	ammo_pickup_button = Button.new()
	# 최소 폭 330을 박아 두면 패널이 아무리 좁게 잡혀도 이 폭까지 다시 부풀어
	# 우하단 구급약 버튼을 밀고 들어간다(실측 35x44 겹침). 폭은 패널이 정한다.
	ammo_pickup_button.custom_minimum_size = Vector2(0, 48)
	ammo_pickup_button.clip_text = true
	ammo_pickup_button.text = "7.62mm 탄약 획득" if DisplayServer.is_touchscreen_available() else "7.62mm 탄약 획득  [F]"
	ammo_pickup_button.icon = AMMO_762_TEXTURE
	ammo_pickup_button.expand_icon = true
	ammo_pickup_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ammo_pickup_button.focus_mode = Control.FOCUS_NONE
	ammo_pickup_button.add_theme_font_override("font", font)
	ammo_pickup_button.add_theme_font_size_override("font_size", 15)
	ammo_pickup_button.pressed.connect(Callable(host, "_collect_nearby_ammo"))
	ammo_prompt_panel.add_child(ammo_pickup_button)

	field_interaction_panel = PanelContainer.new()
	field_interaction_panel.name = "FieldInteractionPrompt"
	field_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	field_interaction_panel.offset_left = -220
	field_interaction_panel.offset_top = -334
	field_interaction_panel.offset_right = 220
	field_interaction_panel.offset_bottom = -210
	var field_panel_style := HudStyle.panel(
		HudStyle.INK,
		Color("#79a994"),
		7
	)
	field_panel_style.content_margin_left = 12.0
	field_panel_style.content_margin_right = 12.0
	field_panel_style.content_margin_top = 9.0
	field_panel_style.content_margin_bottom = 9.0
	field_interaction_panel.add_theme_stylebox_override("panel", field_panel_style)
	field_interaction_panel.visible = false
	host.get_node("HUD").add_child(field_interaction_panel)
	var field_box := VBoxContainer.new()
	field_box.name = "VBoxContainer"
	field_box.add_theme_constant_override("separation", 4)
	field_interaction_panel.add_child(field_box)
	# 예전에는 대상 이름 / 행동 / 상세 / 소요시간 / 안내 다섯 줄을 동시에 띄웠다.
	# "F를 눌러 분해"를 말하는 데 여섯 줄이 필요할 이유가 없다. 한 줄로 합치고,
	# 상세줄은 정말 할 말이 있을 때(잠김 사유·탈출 배율)만 자리를 쓴다.
	field_interaction_action_card = PanelContainer.new()
	field_interaction_action_card.name = "ActionCard"
	field_interaction_action_card.custom_minimum_size = Vector2(0.0, 52.0)
	field_interaction_action_card.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK_WELL, Color("#38584b"), 7)
	)
	field_box.add_child(field_interaction_action_card)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 9)
	field_interaction_action_card.add_child(action_row)

	# 터치에서는 카드 전체가 버튼이라 키캡이 가리킬 키가 없다. 데스크톱에서만 남긴다.
	field_interaction_key_panel = PanelContainer.new()
	field_interaction_key_panel.name = "Keycap"
	field_interaction_key_panel.visible = not DisplayServer.is_touchscreen_available()
	field_interaction_key_panel.custom_minimum_size = Vector2(40.0, 40.0)
	field_interaction_key_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#17231f"), Color("#8bc5a8"), 5)
	)
	action_row.add_child(field_interaction_key_panel)
	field_interaction_key_label = Label.new()
	field_interaction_key_label.text = "길게" if DisplayServer.is_touchscreen_available() else "F"
	field_interaction_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field_interaction_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	field_interaction_key_label.add_theme_font_override("font", font)
	field_interaction_key_label.add_theme_font_size_override(
		"font_size",
		10 if DisplayServer.is_touchscreen_available() else 18
	)
	field_interaction_key_label.add_theme_color_override("font_color", Color("#e9f5ee"))
	field_interaction_key_panel.add_child(field_interaction_key_label)

	field_interaction_icon = TextureRect.new()
	field_interaction_icon.name = "ActionIcon"
	field_interaction_icon.custom_minimum_size = Vector2(28.0, 28.0)
	field_interaction_icon.texture = UI_ICONS.get_icon("interact", 28, Color("#b9dec9"))
	field_interaction_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field_interaction_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	field_interaction_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(field_interaction_icon)

	var action_copy := VBoxContainer.new()
	action_copy.name = "ActionCopy"
	action_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_copy.add_theme_constant_override("separation", 0)
	action_row.add_child(action_copy)
	field_interaction_action_label = Label.new()
	field_interaction_action_label.name = "ActionLabel"
	field_interaction_action_label.text = "상호작용"
	field_interaction_action_label.add_theme_font_override("font", font)
	field_interaction_action_label.add_theme_font_size_override("font_size", 16)
	field_interaction_action_label.add_theme_color_override("font_color", Color("#edf5f0"))
	action_copy.add_child(field_interaction_action_label)
	field_interaction_action_detail_label = Label.new()
	field_interaction_action_detail_label.name = "ActionDetailLabel"
	field_interaction_action_detail_label.text = "길게 눌러 진행"
	field_interaction_action_detail_label.add_theme_font_override("font", font)
	field_interaction_action_detail_label.add_theme_font_size_override("font_size", 11)
	field_interaction_action_detail_label.add_theme_color_override("font_color", Color("#8fa79b"))
	field_interaction_action_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_copy.add_child(field_interaction_action_detail_label)

	field_interaction_duration_label = Label.new()
	field_interaction_duration_label.name = "DurationLabel"
	field_interaction_duration_label.text = "1.0초"
	field_interaction_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field_interaction_duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	field_interaction_duration_label.custom_minimum_size = Vector2(58.0, 0.0)
	field_interaction_duration_label.add_theme_font_override("font", font)
	field_interaction_duration_label.add_theme_font_size_override("font_size", 12)
	field_interaction_duration_label.add_theme_color_override("font_color", Color("#91b7a6"))
	action_row.add_child(field_interaction_duration_label)

	field_interaction_button = Button.new()
	field_interaction_button.name = "Button"
	field_interaction_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field_interaction_button.text = ""
	field_interaction_button.focus_mode = Control.FOCUS_NONE
	field_interaction_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var action_button_normal := StyleBoxFlat.new()
	action_button_normal.bg_color = Color.TRANSPARENT
	field_interaction_button.add_theme_stylebox_override("normal", action_button_normal)
	field_interaction_button.add_theme_stylebox_override("disabled", action_button_normal)
	field_interaction_button.add_theme_stylebox_override(
		"hover",
		HudStyle.panel(Color(0.35, 0.68, 0.54, 0.08), Color(0.55, 0.78, 0.66, 0.45), 7)
	)
	field_interaction_button.add_theme_stylebox_override(
		"pressed",
		HudStyle.panel(Color(0.35, 0.68, 0.54, 0.15), Color("#9cd0b4"), 7)
	)
	field_interaction_button.button_down.connect(func() -> void:
		field_interaction_touch_held = true
		if is_instance_valid(host.nearby_field_interaction) and str(host.nearby_field_interaction.get_meta("interaction_type", "")) == "extraction":
			host._begin_extraction()
	)
	field_interaction_button.button_up.connect(func() -> void: field_interaction_touch_held = false)
	field_interaction_action_card.add_child(field_interaction_button)
	field_interaction_button.move_to_front()

	field_interaction_progress = ProgressBar.new()
	field_interaction_progress.custom_minimum_size = Vector2(0.0, 6.0)
	field_interaction_progress.show_percentage = false
	field_interaction_progress.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#101917"), Color("#263b33"), 3)
	)
	field_interaction_progress.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#76c79e"), Color("#bce9cc"), 3)
	)
	field_interaction_progress.name = "ProgressBar"
	field_box.add_child(field_interaction_progress)
	host._setup_stealth_takedown_prompt(font)

	fatigue_panel = PanelContainer.new()
	fatigue_panel.name = "FatiguePanel"
	fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fatigue_panel.offset_left = 18
	fatigue_panel.offset_top = 214
	fatigue_panel.offset_right = 280
	fatigue_panel.offset_bottom = 276
	fatigue_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK, Color("#60766a"), 7)
	)
	host.get_node("HUD").add_child(fatigue_panel)
	var fatigue_margin := MarginContainer.new()
	fatigue_margin.add_theme_constant_override("margin_left", 10)
	fatigue_margin.add_theme_constant_override("margin_top", 7)
	fatigue_margin.add_theme_constant_override("margin_right", 10)
	fatigue_margin.add_theme_constant_override("margin_bottom", 7)
	fatigue_panel.add_child(fatigue_margin)
	var fatigue_row := HBoxContainer.new()
	fatigue_row.add_theme_constant_override("separation", 9)
	fatigue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fatigue_margin.add_child(fatigue_row)
	var fatigue_icon := TextureRect.new()
	fatigue_icon.name = "FatigueIcon"
	fatigue_icon.custom_minimum_size = Vector2(28, 28)
	fatigue_icon.texture = UI_ICONS.get_icon("stamina", 32, Color("#e3c069"))
	fatigue_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fatigue_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fatigue_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_row.add_child(fatigue_icon)
	var fatigue_box := VBoxContainer.new()
	fatigue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fatigue_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_box.add_theme_constant_override("separation", 3)
	fatigue_row.add_child(fatigue_box)
	# 유저가 이게 뭔지 모른다는 피드백. "피로도" 라벨을 왼쪽에, 상태/퍼센트를
	# 오른쪽에 두고 그 아래 바를 붙인다. 정렬이 분명해진다.
	var fatigue_header := HBoxContainer.new()
	fatigue_header.add_theme_constant_override("separation", 6)
	fatigue_box.add_child(fatigue_header)
	var fatigue_name := Label.new()
	fatigue_name.text = "피로도"
	fatigue_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fatigue_name.add_theme_font_override("font", font)
	fatigue_name.add_theme_font_size_override("font_size", 12)
	fatigue_name.add_theme_color_override("font_color", Color("#9fb4a9"))
	fatigue_header.add_child(fatigue_name)
	fatigue_status_label = Label.new()
	fatigue_status_label.text = "0%"
	fatigue_status_label.add_theme_font_override("font", font)
	fatigue_status_label.add_theme_font_size_override("font_size", 12)
	fatigue_status_label.add_theme_color_override("font_color", Color("#8fc7a8"))
	fatigue_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fatigue_header.add_child(fatigue_status_label)
	fatigue_bar = ProgressBar.new()
	fatigue_bar.custom_minimum_size = Vector2(190, 7)
	fatigue_bar.max_value = FATIGUE_MAX
	fatigue_bar.show_percentage = false
	fatigue_bar.add_theme_stylebox_override("background", HudStyle.panel(Color("#17201d"), Color("#32443c"), 4))
	fatigue_fill_style = HudStyle.panel(Color("#78b993"), Color("#a7d6b9"), 4)
	fatigue_bar.add_theme_stylebox_override("fill", fatigue_fill_style)
	fatigue_box.add_child(fatigue_bar)

	equipment_panel = PanelContainer.new()
	equipment_panel.name = "EquipmentPanel"
	equipment_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 아주 컴팩트하게: 작은 총 그림 + [이름·탄약명 / 잔탄] 2줄. 높이 56px.
	equipment_panel.offset_left = -224
	equipment_panel.offset_top = -180
	equipment_panel.offset_right = -20
	equipment_panel.offset_bottom = -124
	equipment_panel.add_theme_stylebox_override("panel", HudStyle.panel(HudStyle.INK, Color("#8da997"), 7))
	equipment_panel.visible = false
	host.get_node("HUD").add_child(equipment_panel)
	var equipment_margin := MarginContainer.new()
	equipment_margin.add_theme_constant_override("margin_left", 10)
	equipment_margin.add_theme_constant_override("margin_top", 6)
	equipment_margin.add_theme_constant_override("margin_right", 12)
	equipment_margin.add_theme_constant_override("margin_bottom", 6)
	equipment_panel.add_child(equipment_margin)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 10)
	equipment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment_margin.add_child(equipment_row)
	# 총 그림. 출정 중 무기가 바뀌므로 즉시 식별 수단으로 남긴다. 내구도는 색으로.
	equipment_weapon_image = TextureRect.new()
	equipment_weapon_image.custom_minimum_size = Vector2(52, 36)
	equipment_weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_weapon_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equipment_row.add_child(equipment_weapon_image)
	var weapon_text_box := VBoxContainer.new()
	weapon_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weapon_text_box.add_theme_constant_override("separation", 1)
	equipment_row.add_child(weapon_text_box)
	# 1줄: 총 이름(왼쪽) + 탄약명(오른쪽, 흐리게).
	var weapon_header := HBoxContainer.new()
	weapon_header.add_theme_constant_override("separation", 6)
	weapon_text_box.add_child(weapon_header)
	equipment_name_label = Label.new()
	equipment_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_name_label.clip_text = true
	equipment_name_label.add_theme_font_override("font", font)
	equipment_name_label.add_theme_font_size_override("font_size", 12)
	equipment_name_label.add_theme_color_override("font_color", Color("#c6d4cb"))
	weapon_header.add_child(equipment_name_label)
	equipment_ammo_type_label = Label.new()
	equipment_ammo_type_label.add_theme_font_override("font", font)
	equipment_ammo_type_label.add_theme_font_size_override("font_size", 11)
	equipment_ammo_type_label.add_theme_color_override("font_color", Color("#8fa39a"))
	equipment_ammo_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_header.add_child(equipment_ammo_type_label)
	# 2줄: 잔탄 / 탄창 · 예비탄.
	equipment_ammo_label = Label.new()
	equipment_ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_ammo_label.add_theme_font_override("font", font)
	equipment_ammo_label.add_theme_font_size_override("font_size", 19)
	equipment_ammo_label.add_theme_color_override("font_color", HudStyle.GOLD_TEXT)
	weapon_text_box.add_child(equipment_ammo_label)
	equipment_reload_bar = ProgressBar.new()
	equipment_reload_bar.custom_minimum_size = Vector2(0, 5)
	equipment_reload_bar.max_value = 1.0
	equipment_reload_bar.show_percentage = false
	equipment_reload_bar.add_theme_stylebox_override("background", HudStyle.panel(Color("#171d1b"), Color("#3e4944"), 4))
	equipment_reload_bar.add_theme_stylebox_override("fill", HudStyle.panel(Color("#d6b653"), Color("#f0d77d"), 4))
	weapon_text_box.add_child(equipment_reload_bar)

	fire_button = Button.new()
	fire_button.name = "FireButton"
	fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.offset_left = -108
	fire_button.offset_top = -104
	fire_button.offset_right = -28
	fire_button.offset_bottom = -24
	fire_button.text = "발사"
	fire_button.icon = UI_ICONS.get_icon("weapon", 36, Color("#ffd29a"))
	fire_button.tooltip_text = "AK-47 발사"
	fire_button.z_index = 90
	# 주 행동은 유일하게 '채워진' 원 — 화면에서 제일 먼저 읽혀야 한다.
	HudStyle.style_mobile_action(fire_button, Color("#e08a58"), 38, true, HudStyle.TYPE_HEADING)
	if not touch_enabled:
		fire_button.button_down.connect(Callable(host, "_on_fire_button_down"))
		fire_button.button_up.connect(Callable(host, "_on_fire_button_up"))
	fire_button.visible = false
	host.get_node("HUD").add_child(fire_button)

	melee_button = Button.new()
	melee_button.name = "MeleeButton"
	melee_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	melee_button.offset_left = -198
	melee_button.offset_top = -104
	melee_button.offset_right = -118
	melee_button.offset_bottom = -24
	melee_button.text = "근접"
	melee_button.icon = UI_ICONS.get_icon("melee", 34, Color("#dbe9df"))
	melee_button.tooltip_text = "야구 방망이 휘두르기"
	melee_button.z_index = 90
	HudStyle.style_mobile_action(melee_button, HudStyle.LINE_FOCUS, 36, false, HudStyle.TYPE_BODY)
	if not touch_enabled:
		melee_button.pressed.connect(Callable(host, "_on_melee_button_pressed"))
	melee_button.visible = touch_enabled
	host.get_node("HUD").add_child(melee_button)

	dash_button = Button.new()
	dash_button.name = "DashButton"
	dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_button.offset_left = -288
	dash_button.offset_top = -104
	dash_button.offset_right = -208
	dash_button.offset_bottom = -24
	dash_button.text = "회피"
	dash_button.icon = UI_ICONS.get_icon("dash", 34, HudStyle.TEXT)
	dash_button.tooltip_text = "구르기 회피"
	dash_button.z_index = 90
	HudStyle.style_mobile_action(dash_button, Color("#82a8b8"), 36, false, HudStyle.TYPE_BODY)
	if not touch_enabled:
		dash_button.pressed.connect(Callable(host, "_on_dash_button_pressed"))
	dash_button.visible = touch_enabled
	host.get_node("HUD").add_child(dash_button)

	host._build_mobile_utility_buttons(font)

	ammo_notice = Label.new()
	ammo_notice.name = "AmmoNotice"
	ammo_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_notice.offset_left = -170
	ammo_notice.offset_top = -292
	ammo_notice.offset_right = 170
	ammo_notice.offset_bottom = -234
	ammo_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_notice.add_theme_font_override("font", font)
	ammo_notice.add_theme_font_size_override("font_size", 16)
	ammo_notice.add_theme_color_override("font_color", HudStyle.GOLD_TEXT)
	ammo_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ammo_notice.add_theme_constant_override("outline_size", 5)
	ammo_notice.visible = false
	host.get_node("HUD").add_child(ammo_notice)
	_build_toast_stack()
	combat_feedback = CombatFeedbackOverlay.new()
	combat_feedback.name = "CombatFeedbackOverlay"
	host.get_node("HUD").add_child(combat_feedback)

	inventory_ui = INVENTORY_UI_SCRIPT.new()
	inventory_ui.name = "InventoryUI"
	host.get_node("HUD").add_child(inventory_ui)
	inventory_ui.call("setup", font, WEAPON_VISUAL_CATALOG.get_weapon_texture(host.equipped_weapon_id), AMMO_762_TEXTURE, {
		"rubber_gasket": RUBBER_GASKET_TEXTURE,
		"scope_lens": SCOPE_LENS_TEXTURE,
		"magazine_spring": MAGAZINE_SPRING_TEXTURE,
	}, WEAPON_VISUAL_CATALOG.get_inventory_textures())
	inventory_ui.connect("open_state_changed", Callable(host, "_on_inventory_open_state_changed"))
	inventory_ui.connect("weapon_mods_changed", Callable(host, "_on_inventory_weapon_mods_changed"))
	inventory_ui.connect("weapon_equipped", Callable(host, "_on_inventory_weapon_equipped"))
	inventory_ui.connect("weapon_unequipped", Callable(host, "_on_inventory_weapon_unequipped"))
	inventory_ui.connect("equipment_changed", Callable(host, "_on_inventory_equipment_changed"))
	inventory_ui.connect("item_discard_requested", Callable(host, "_on_inventory_item_discard_requested"))
	inventory_ui.connect("item_use_requested", Callable(host, "_on_inventory_item_use_requested"))
	host._update_equipment_ui()
	_watch_prompt_layout(ammo_prompt_panel)
	_watch_prompt_layout(field_interaction_panel)
	_watch_prompt_layout(equipment_panel)
	_queue_bottom_prompt_bounds()


# ── 하단 프롬프트 예약 영역 ─────────────────────────────────────
# 필드 프롬프트(탄약 획득 · 상호작용)는 화면 중앙 하단에 뜨는데, 그 자리는
# 우하단 무기 카드/구급약·줍기 버튼 줄과 정면으로 부딪힌다. 실측(720x1280)에서
# FieldInteractionPrompt ↔ EquipmentPanel 57x46, AmmoPickupPrompt ↔ MedkitButton
# 35x44px이 겹쳐 "즉시" 글자와 진행 바 오른쪽이 잘려 나갔다.
#
# 폭을 숫자로 박으면 화면 비율이 바뀔 때마다 다시 겹친다. 우하단 위젯의 실제
# rect로 예약 영역을 잡는다 — shelter_ops_console._weapon_card_reserved_height와
# 같은 문법이다. main._apply_hud_layout이 프롬프트를 중앙 기준으로 다시 잡으면
# 그 뒤(같은 프레임 끝)에 한 번 더 보정한다.
const BOTTOM_RIGHT_RESERVED_NODES := [
	"EquipmentPanel", "FireButton", "MeleeButton", "DashButton",
	"CanThrowButton", "ContextButton", "MedkitButton", "ReloadButton",
	"CanInfoButton",
]
const BOTTOM_LEFT_RESERVED_NODES := ["TouchStick"]
const PROMPT_RESERVED_GAP := 10.0
const PROMPT_MIN_WIDTH := 190.0

var _prompt_bounds_pending := false


func _watch_prompt_layout(node: Control) -> void:
	if node == null:
		return
	if not node.item_rect_changed.is_connected(_queue_bottom_prompt_bounds):
		node.item_rect_changed.connect(_queue_bottom_prompt_bounds)
	if not node.visibility_changed.is_connected(_queue_bottom_prompt_bounds):
		node.visibility_changed.connect(_queue_bottom_prompt_bounds)


func _queue_bottom_prompt_bounds() -> void:
	# 한 프레임에 신호가 몇 번 오든 보정은 한 번. 지연 호출이라 우하단 위젯이
	# 전부 최종 위치를 잡은 뒤에 실행된다(main은 프롬프트를 먼저, 무기 카드를
	# 나중에 배치한다 — 같은 프레임 안에서 읽으면 한 박자 늦은 rect를 본다).
	if _prompt_bounds_pending or host == null:
		return
	_prompt_bounds_pending = true
	apply_bottom_prompt_bounds.call_deferred()


func apply_bottom_prompt_bounds() -> void:
	_prompt_bounds_pending = false
	if host == null or not host.is_inside_tree():
		return
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var safe: Vector4 = UI_SAFE_AREA.get_margins(viewport_size)
	var side_margin := maxf(maxf(safe.x, safe.z), clampf(viewport_size.x * 0.02, 10.0, 26.0))
	for panel_value in [ammo_prompt_panel, field_interaction_panel]:
		var panel := panel_value as PanelContainer
		if panel == null or not is_instance_valid(panel):
			continue
		var rect: Rect2 = panel.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		# 앵커 원점을 rect에서 역산한다 — 프리셋(CENTER_BOTTOM)이 바뀌어도 안전.
		var origin_x: float = rect.position.x - panel.offset_left
		var right_limit := minf(
			viewport_size.x - side_margin,
			_bottom_reserved_edge(
				BOTTOM_RIGHT_RESERVED_NODES, rect, true, viewport_size.x
			) - PROMPT_RESERVED_GAP
		)
		var left_limit := maxf(
			side_margin,
			_bottom_reserved_edge(BOTTOM_LEFT_RESERVED_NODES, rect, false, 0.0)
			+ PROMPT_RESERVED_GAP
		)
		if rect.end.x <= right_limit + 0.5 and rect.position.x >= left_limit - 0.5:
			continue  # 안 겹치면 main이 잡은 중앙 배치를 그대로 존중한다.
		var min_width := maxf(PROMPT_MIN_WIDTH, panel.get_combined_minimum_size().x)
		var new_width := minf(rect.size.x, maxf(min_width, right_limit - left_limit))
		var new_right := right_limit
		var new_left := new_right - new_width
		if new_left < left_limit:
			new_left = left_limit
			new_right = new_left + new_width
		panel.offset_left = new_left - origin_x
		panel.offset_right = new_right - origin_x


func _bottom_reserved_edge(
	node_names: Array, band: Rect2, from_right: bool, fallback: float
) -> float:
	# band(프롬프트가 놓인 세로 구간)와 실제로 겹치는 위젯만 센다. 가로 화면에서
	# 버튼 줄이 프롬프트보다 아래로 내려가면 폭을 깎을 이유가 없다.
	var edge := fallback
	if host == null:
		return edge
	var hud_root := host.get_node_or_null("HUD")
	if hud_root == null:
		return edge
	for node_name in node_names:
		var widget := hud_root.get_node_or_null(str(node_name)) as Control
		if widget == null or not widget.is_visible_in_tree():
			continue
		var widget_rect: Rect2 = widget.get_global_rect()
		if widget_rect.size.x <= 1.0 or widget_rect.size.y <= 1.0:
			continue
		if widget_rect.position.y >= band.end.y or widget_rect.end.y <= band.position.y:
			continue
		edge = minf(edge, widget_rect.position.x) if from_right else maxf(edge, widget_rect.end.x)
	return edge


func hide_field_combat_hud() -> void:
	# 정산 화면 위로 긴장도 패널·증원 배너·조준 십자선·무기 카드가 그대로 겹쳐
	# 그려지던 문제. 정산은 '판이 끝난 화면'이니 전투 HUD는 전부 내린다.
	for panel in [
		raid_pressure_panel, dynamic_incident_hud, reinforcement_call_panel,
		jackpot_hud, ammo_prompt_panel, field_interaction_panel, equipment_panel,
		fatigue_panel, ammo_notice, toast_stack, fire_button, melee_button,
		dash_button, combat_feedback,
	]:
		if panel != null and is_instance_valid(panel):
			(panel as CanvasItem).visible = false
	for canvas in [aim_canvas, damage_feedback_canvas]:
		if canvas != null and is_instance_valid(canvas):
			(canvas as CanvasLayer).visible = false
	# main이 소유한 우하단 버튼 줄과 조이스틱도 같이 내린다(정산 중에는 조작이 없다).
	if host == null:
		return
	var hud_root := host.get_node_or_null("HUD")
	if hud_root == null:
		return
	for node_name in [
		"TouchStick", "CanThrowButton", "ContextButton", "MedkitButton",
		"ReloadButton", "CanInfoButton", "MapButton",
	]:
		var widget := hud_root.get_node_or_null(str(node_name)) as CanvasItem
		if widget != null:
			widget.visible = false


# ── 토스트 스택 ─────────────────────────────────────────────────
# 획득·장착·안내 알림의 단일 창구. 슬롯 하나(ammo_notice)를 모두가 나눠 쓰며
# 서로 덮어쓰던 문제를 끝낸다: 최대 3장이 스택으로 쌓이고, 각자 수명을 갖고,
# 같은 메시지는 ×N으로 합쳐진다. 등장·퇴장 전부 HudStyle 모션 문법을 탄다 —
# 툭 나타나는 알림은 없다.
const TOAST_LIMIT := 3


func _build_toast_stack() -> void:
	toast_stack = VBoxContainer.new()
	toast_stack.name = "ToastStack"
	toast_stack.alignment = BoxContainer.ALIGNMENT_END
	toast_stack.add_theme_constant_override("separation", 6)
	toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_stack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_stack.offset_left = -240
	toast_stack.offset_right = 240
	toast_stack.offset_top = -560
	toast_stack.offset_bottom = -300
	host.get_node("HUD").add_child(toast_stack)


func push_toast(message: String, accent: Color = HudStyle.GOLD, duration: float = 2.2) -> void:
	if toast_stack == null or message.is_empty():
		return
	# 같은 메시지 연타는 마지막 장에 ×N으로 합치고 수명을 새로 준다.
	if toast_stack.get_child_count() > 0:
		var last := toast_stack.get_child(toast_stack.get_child_count() - 1) as PanelContainer
		if is_instance_valid(last) and str(last.get_meta("base_text", "")) == message:
			var repeat := int(last.get_meta("repeat_count", 1)) + 1
			last.set_meta("repeat_count", repeat)
			var last_label := last.get_meta("label") as Label
			if is_instance_valid(last_label):
				last_label.text = "%s   ×%d" % [message, repeat]
			var old_life = last.get_meta("life_tween")
			if old_life is Tween and (old_life as Tween).is_valid():
				(old_life as Tween).kill()
			_start_toast_life(last, duration)
			return
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := HudStyle.panel(
		Color(HudStyle.INK.r, HudStyle.INK.g, HudStyle.INK.b, 0.94),
		Color(accent, 0.62),
		HudStyle.RADIUS_CARD
	)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 8.0
	toast.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HudStyle.FONT)
	label.add_theme_font_size_override("font_size", HudStyle.TYPE_BODY)
	label.add_theme_color_override("font_color", accent.lerp(HudStyle.TEXT, 0.45))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if message.length() > 34:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 430.0
	toast.add_child(label)
	toast.set_meta("base_text", message)
	toast.set_meta("repeat_count", 1)
	toast.set_meta("label", label)
	toast_stack.add_child(toast)
	# 새 장이 등장할 때만 아주 작게 "톡"(같은 메시지 ×N 합치기는 조용히).
	SFX.play("toast_pop")
	# 넘치면 가장 오래된 장부터 빠르게 물러난다.
	while toast_stack.get_child_count() > TOAST_LIMIT:
		var oldest := toast_stack.get_child(0) as Control
		if is_instance_valid(oldest):
			toast_stack.remove_child(oldest)
			oldest.queue_free()
	# 등장: 페이드 + 미세 스케일 (스택 안이라 position 트윈 대신 scale).
	toast.call_deferred("set_pivot_offset", Vector2(240.0, 16.0))
	toast.modulate.a = 0.0
	toast.scale = Vector2(0.96, 0.96)
	var enter_tween := toast.create_tween()
	enter_tween.set_parallel(true)
	enter_tween.tween_property(toast, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	enter_tween.tween_property(toast, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_toast_life(toast, duration)


func _start_toast_life(toast: PanelContainer, duration: float) -> void:
	var life := toast.create_tween()
	toast.set_meta("life_tween", life)
	life.tween_interval(maxf(0.6, duration))
	life.tween_property(toast, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	life.parallel().tween_property(toast, "scale", Vector2(0.97, 0.97), 0.22)
	life.tween_callback(toast.queue_free)


func build_raid_opportunity_hud() -> void:
	raid_pressure_panel = PanelContainer.new()
	raid_pressure_panel.name = "RaidPressurePanel"
	raid_pressure_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	raid_pressure_panel.offset_left = -220.0
	raid_pressure_panel.offset_top = 18.0
	raid_pressure_panel.offset_right = 220.0
	raid_pressure_panel.offset_bottom = 92.0
	raid_pressure_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK, Color("#6f8179"), 7)
	)
	raid_pressure_panel.z_index = 82
	raid_pressure_panel.visible = false
	host.get_node("HUD").add_child(raid_pressure_panel)
	var pressure_margin := MarginContainer.new()
	pressure_margin.add_theme_constant_override("margin_left", 12)
	pressure_margin.add_theme_constant_override("margin_top", 9)
	pressure_margin.add_theme_constant_override("margin_right", 12)
	pressure_margin.add_theme_constant_override("margin_bottom", 9)
	raid_pressure_panel.add_child(pressure_margin)
	var pressure_row := HBoxContainer.new()
	pressure_row.add_theme_constant_override("separation", 10)
	pressure_margin.add_child(pressure_row)
	raid_pressure_icon = TextureRect.new()
	raid_pressure_icon.name = "PressureIcon"
	raid_pressure_icon.custom_minimum_size = Vector2(42, 42)
	raid_pressure_icon.texture = UI_ICONS.get_icon("alert", 44, Color("#92b7a4"))
	raid_pressure_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	raid_pressure_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pressure_row.add_child(raid_pressure_icon)
	var pressure_copy := VBoxContainer.new()
	pressure_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pressure_copy.add_theme_constant_override("separation", 2)
	pressure_row.add_child(pressure_copy)
	raid_pressure_title = Label.new()
	raid_pressure_title.name = "PressureTitle"
	raid_pressure_title.add_theme_font_override("font", FONT)
	raid_pressure_title.add_theme_font_size_override("font_size", 16)
	raid_pressure_title.add_theme_color_override("font_color", Color("#e4ebe6"))
	pressure_copy.add_child(raid_pressure_title)
	raid_pressure_detail = Label.new()
	raid_pressure_detail.name = "PressureDetail"
	raid_pressure_detail.add_theme_font_override("font", FONT)
	raid_pressure_detail.add_theme_font_size_override("font_size", 13)
	raid_pressure_detail.add_theme_color_override("font_color", Color("#a7b8af"))
	pressure_copy.add_child(raid_pressure_detail)
	raid_pressure_bar = ProgressBar.new()
	raid_pressure_bar.name = "PressureProgress"
	raid_pressure_bar.custom_minimum_size = Vector2(126, 14)
	raid_pressure_bar.min_value = 0.0
	# 단계 판정과 같은 표(레이드 이벤트 디렉터)를 쓴다. 예전 로컬 사본(540)은
	# 디렉터의 560과 어긋나 게이지 끝과 최고 단계 진입점이 달랐다.
	raid_pressure_bar.max_value = RaidEventDirector.LEVEL_THRESHOLDS.back()
	raid_pressure_bar.show_percentage = false
	raid_pressure_bar.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#111817"), Color("#40504a"), 7)
	)
	raid_pressure_bar.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#6fa88b"), Color("#9bc8af"), 7)
	)
	pressure_row.add_child(raid_pressure_bar)

	dynamic_incident_hud = PanelContainer.new()
	dynamic_incident_hud.name = "DynamicIncidentPanel"
	dynamic_incident_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dynamic_incident_hud.offset_left = -245.0
	dynamic_incident_hud.offset_top = 102.0
	dynamic_incident_hud.offset_right = 245.0
	dynamic_incident_hud.offset_bottom = 178.0
	dynamic_incident_hud.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color(0.035, 0.025, 0.022, 0.97), Color("#d56e4f"), 7)
	)
	dynamic_incident_hud.z_index = 83
	dynamic_incident_hud.visible = false
	host.get_node("HUD").add_child(dynamic_incident_hud)
	var incident_margin := MarginContainer.new()
	incident_margin.add_theme_constant_override("margin_left", 12)
	incident_margin.add_theme_constant_override("margin_top", 9)
	incident_margin.add_theme_constant_override("margin_right", 12)
	incident_margin.add_theme_constant_override("margin_bottom", 9)
	dynamic_incident_hud.add_child(incident_margin)
	var incident_row := HBoxContainer.new()
	incident_row.add_theme_constant_override("separation", 10)
	incident_margin.add_child(incident_row)
	var incident_icon := TextureRect.new()
	incident_icon.name = "IncidentIcon"
	incident_icon.custom_minimum_size = Vector2(46, 46)
	incident_icon.texture = UI_ICONS.get_icon("alert", 48, Color("#f08a62"))
	incident_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	incident_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	incident_row.add_child(incident_icon)
	var incident_copy := VBoxContainer.new()
	incident_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	incident_copy.add_theme_constant_override("separation", 2)
	incident_row.add_child(incident_copy)
	dynamic_incident_title = Label.new()
	dynamic_incident_title.name = "IncidentTitle"
	dynamic_incident_title.text = "돌발 사건 · 약탈대 충돌"
	dynamic_incident_title.add_theme_font_override("font", FONT)
	dynamic_incident_title.add_theme_font_size_override("font_size", 17)
	dynamic_incident_title.add_theme_color_override("font_color", Color("#ffd2ba"))
	incident_copy.add_child(dynamic_incident_title)
	dynamic_incident_detail = Label.new()
	dynamic_incident_detail.name = "IncidentDetail"
	dynamic_incident_detail.add_theme_font_override("font", FONT)
	dynamic_incident_detail.add_theme_font_size_override("font_size", 13)
	dynamic_incident_detail.add_theme_color_override("font_color", Color("#d9b4a4"))
	incident_copy.add_child(dynamic_incident_detail)
	dynamic_incident_progress = ProgressBar.new()
	dynamic_incident_progress.name = "IncidentProgress"
	dynamic_incident_progress.custom_minimum_size = Vector2(112, 14)
	dynamic_incident_progress.min_value = 0.0
	dynamic_incident_progress.max_value = DYNAMIC_INCIDENT_DURATION
	dynamic_incident_progress.show_percentage = false
	dynamic_incident_progress.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#1b1210"), Color("#5c3a31"), 7)
	)
	dynamic_incident_progress.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#d85f3f"), Color("#ff9b74"), 7)
	)
	incident_row.add_child(dynamic_incident_progress)

	# 증원 호출 예고 배너 — 적이 무전을 잡는 순간 뜨고 남은 시간이 게이지로
	# 줄어든다. "이 안에 저 녀석을 죽이면 증원이 안 온다"를 화면 하나로 말한다
	# (유저: "경보가 울리면 게이지바로 충분한 시간을 주고, 다 죽이면 증원 취소").
	# 배치는 main._layout_center_top_banners의 중앙 상단 스택이 잡는다.
	reinforcement_call_panel = PanelContainer.new()
	reinforcement_call_panel.name = "ReinforcementCallPanel"
	reinforcement_call_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	reinforcement_call_panel.offset_left = -235.0
	reinforcement_call_panel.offset_top = 18.0
	reinforcement_call_panel.offset_right = 235.0
	reinforcement_call_panel.offset_bottom = 92.0
	reinforcement_call_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color(0.09, 0.016, 0.014, 0.97), Color("#ff5a45"), 7)
	)
	reinforcement_call_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reinforcement_call_panel.z_index = 85
	reinforcement_call_panel.visible = false
	host.get_node("HUD").add_child(reinforcement_call_panel)
	var call_margin := MarginContainer.new()
	call_margin.add_theme_constant_override("margin_left", 12)
	call_margin.add_theme_constant_override("margin_top", 9)
	call_margin.add_theme_constant_override("margin_right", 12)
	call_margin.add_theme_constant_override("margin_bottom", 9)
	reinforcement_call_panel.add_child(call_margin)
	var call_row := HBoxContainer.new()
	call_row.add_theme_constant_override("separation", 10)
	call_margin.add_child(call_row)
	var call_icon := TextureRect.new()
	call_icon.name = "ReinforcementCallIcon"
	call_icon.custom_minimum_size = Vector2(46, 46)
	call_icon.texture = UI_ICONS.get_icon("alert", 48, Color("#ff7a5f"))
	call_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	call_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	call_row.add_child(call_icon)
	var call_copy := VBoxContainer.new()
	call_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_copy.add_theme_constant_override("separation", 2)
	call_row.add_child(call_copy)
	reinforcement_call_title = Label.new()
	reinforcement_call_title.name = "ReinforcementCallTitle"
	reinforcement_call_title.text = "적이 증원을 요청 중입니다!"
	reinforcement_call_title.add_theme_font_override("font", FONT)
	reinforcement_call_title.add_theme_font_size_override("font_size", 18)
	reinforcement_call_title.add_theme_color_override("font_color", Color("#ffd0c2"))
	call_copy.add_child(reinforcement_call_title)
	reinforcement_call_detail = Label.new()
	reinforcement_call_detail.name = "ReinforcementCallDetail"
	reinforcement_call_detail.text = "!! 표식의 적을 처치해 저지하라"
	reinforcement_call_detail.add_theme_font_override("font", FONT)
	reinforcement_call_detail.add_theme_font_size_override("font_size", 13)
	reinforcement_call_detail.add_theme_color_override("font_color", Color("#e5a898"))
	call_copy.add_child(reinforcement_call_detail)
	reinforcement_call_bar = ProgressBar.new()
	reinforcement_call_bar.name = "ReinforcementCallProgress"
	reinforcement_call_bar.custom_minimum_size = Vector2(118, 14)
	reinforcement_call_bar.min_value = 0.0
	reinforcement_call_bar.max_value = 1.0
	reinforcement_call_bar.value = 1.0
	reinforcement_call_bar.show_percentage = false
	reinforcement_call_bar.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#1d0d0b"), Color("#5f2a22"), 7)
	)
	reinforcement_call_bar.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#ff5f43"), Color("#ffa287"), 7)
	)
	call_row.add_child(reinforcement_call_bar)


func set_reinforcement_call_progress(remaining: float, duration: float) -> void:
	# 남은 시간을 게이지 + 초 단위 숫자로. 게이지는 '줄어드는' 방향이다.
	if reinforcement_call_bar == null:
		return
	reinforcement_call_bar.max_value = maxf(0.01, duration)
	reinforcement_call_bar.value = clampf(remaining, 0.0, maxf(0.01, duration))
	if reinforcement_call_detail:
		reinforcement_call_detail.text = "%0.1f초 · !! 표식의 적을 처치해 저지하라" % maxf(0.0, remaining)


func add_result_stat(icon_name: String, value: String, caption: String, accent: Color = HudStyle.GOLD) -> void:
	# 정산 스탯 타일: 아이콘 + 큰 숫자 + 작은 라벨. 텍스트 줄보다 성과가 한눈에 온다.
	if extraction_stat_row == null:
		return
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", HudStyle.panel(HudStyle.INK_WELL, HudStyle.LINE, 7))
	extraction_stat_row.add_child(tile)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.texture = UI_ICONS.get_icon(icon_name, 26, accent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var value_label := HudStyle.label(value, HudStyle.TYPE_NUMBER, HudStyle.TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	var caption_label := HudStyle.label(caption, HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_DIM)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption_label)


func add_result_reward_chip(icon_name: String, text: String, accent: Color = HudStyle.GOLD) -> void:
	# 보상 칩: "+95 XP", "고철 +1.3K" 같은 획득 항목 하나가 칩 하나.
	if extraction_reward_flow == null:
		return
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", HudStyle.chip(accent.darkened(0.3)))
	extraction_reward_flow.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.texture = UI_ICONS.get_icon(icon_name, 16, accent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(HudStyle.label(text, HudStyle.TYPE_CAPTION, HudStyle.TEXT))
	# 칩이 하나씩 톡톡 떨어져 붙는다 — 보상이 쌓이는 감각을 만든다.
	chip.modulate.a = 0.0
	chip.pivot_offset = Vector2(60.0, 14.0)
	chip.scale = Vector2(0.88, 0.88)
	var order := maxi(0, extraction_reward_flow.get_child_count() - 1)
	var chip_tween := chip.create_tween()
	chip_tween.tween_interval(0.09 * float(order))
	chip_tween.set_parallel(true)
	chip_tween.tween_property(chip, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	chip_tween.tween_property(chip, "scale", Vector2.ONE, 0.26).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func clear_result_visuals() -> void:
	for container in [extraction_stat_row, extraction_reward_flow]:
		if container == null:
			continue
		for child in container.get_children():
			child.queue_free()


func build_extraction_progress_ui() -> void:
	extraction_result_panel = PanelContainer.new()
	extraction_result_panel.name = "ExtractionResultPanel"
	extraction_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 내용(요약 ~9줄 + 경로 카드 + XP 바)에 맞는 크기. 예전 900×510은 절반이
	# 빈 여백이었다. 세로 화면에서는 폭이 자동으로 더 줄어든다.
	var result_viewport := host.get_viewport().get_visible_rect().size
	var result_half_w := minf(390.0, (result_viewport.x - 24.0) * 0.5)
	extraction_result_panel.offset_left = -result_half_w
	extraction_result_panel.offset_top = -196
	extraction_result_panel.offset_right = result_half_w
	extraction_result_panel.offset_bottom = 196
	extraction_result_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK_SOLID, Color("#d0b35d"), 7)
	)
	extraction_result_panel.z_index = 502
	extraction_result_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	extraction_result_panel.visible = false
	host.get_node("HUD").add_child(extraction_result_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	extraction_result_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	extraction_result_title = Label.new()
	extraction_result_title.text = "탈출 성공"
	extraction_result_title.add_theme_font_override("font", FONT)
	extraction_result_title.add_theme_font_size_override("font_size", 34)
	extraction_result_title.add_theme_color_override("font_color", HudStyle.GOLD_TEXT)
	content.add_child(extraction_result_title)
	var route_card := PanelContainer.new()
	route_card.name = "ExtractionRouteCard"
	route_card.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(Color("#0e1615"), Color("#52655e"), 7)
	)
	content.add_child(route_card)
	var route_margin := MarginContainer.new()
	route_margin.add_theme_constant_override("margin_left", 12)
	route_margin.add_theme_constant_override("margin_top", 8)
	route_margin.add_theme_constant_override("margin_right", 12)
	route_margin.add_theme_constant_override("margin_bottom", 8)
	route_card.add_child(route_margin)
	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 10)
	route_margin.add_child(route_row)
	extraction_route_icon = TextureRect.new()
	extraction_route_icon.name = "RouteIcon"
	extraction_route_icon.custom_minimum_size = Vector2(42, 42)
	extraction_route_icon.texture = UI_ICONS.get_icon("raid", 44, Color("#d9b44a"))
	extraction_route_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	extraction_route_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	route_row.add_child(extraction_route_icon)
	extraction_route_label = Label.new()
	extraction_route_label.name = "RouteLabel"
	extraction_route_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extraction_route_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extraction_route_label.add_theme_font_override("font", FONT)
	extraction_route_label.add_theme_font_size_override("font_size", 17)
	extraction_route_label.add_theme_color_override("font_color", Color("#e4e1d3"))
	route_row.add_child(extraction_route_label)
	# 성과는 숫자 타일로, 보상은 칩으로 — 텍스트 여덟 줄 대신 한눈에 읽히는 정산.
	extraction_stat_row = HBoxContainer.new()
	extraction_stat_row.name = "ExtractionStatRow"
	extraction_stat_row.add_theme_constant_override("separation", 10)
	content.add_child(extraction_stat_row)
	extraction_reward_flow = HFlowContainer.new()
	extraction_reward_flow.name = "ExtractionRewardFlow"
	extraction_reward_flow.add_theme_constant_override("h_separation", 8)
	extraction_reward_flow.add_theme_constant_override("v_separation", 6)
	content.add_child(extraction_reward_flow)
	extraction_result_summary = Label.new()
	extraction_result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extraction_result_summary.add_theme_font_override("font", FONT)
	extraction_result_summary.add_theme_font_size_override("font_size", HudStyle.TYPE_BODY)
	extraction_result_summary.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	content.add_child(extraction_result_summary)
	extraction_xp_bar = ProgressBar.new()
	extraction_xp_bar.custom_minimum_size = Vector2(0, 24)
	extraction_xp_bar.min_value = 0
	extraction_xp_bar.max_value = 100
	extraction_xp_bar.show_percentage = false
	extraction_xp_bar.add_theme_stylebox_override("background", HudStyle.panel(Color("#141a19"), Color("#53635e"), 7))
	extraction_xp_bar.add_theme_stylebox_override("fill", HudStyle.panel(Color("#68c89b"), Color("#9ae2bd"), 7))
	content.add_child(extraction_xp_bar)
	extraction_xp_label = Label.new()
	extraction_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	extraction_xp_label.add_theme_font_override("font", FONT)
	extraction_xp_label.add_theme_font_size_override("font_size", 16)
	extraction_xp_label.add_theme_color_override("font_color", Color("#a9bcb2"))
	content.add_child(extraction_xp_label)
	extraction_level_choice_title = Label.new()
	# 영문 제목은 이 게임 어디에도 없다. 이 칸이 무엇인지 한국어로 말한다.
	extraction_level_choice_title.text = "이번 판으로 성장한 것"
	extraction_level_choice_title.add_theme_font_override("font", FONT)
	extraction_level_choice_title.add_theme_font_size_override("font_size", 21)
	extraction_level_choice_title.add_theme_color_override("font_color", Color("#e8d18a"))
	extraction_level_choice_title.visible = false
	content.add_child(extraction_level_choice_title)
	extraction_level_choice_row = HBoxContainer.new()
	extraction_level_choice_row.add_theme_constant_override("separation", 12)
	extraction_level_choice_row.visible = false
	content.add_child(extraction_level_choice_row)
	# "탭하면 쉘터로 복귀"가 요약 라벨(y≈707)에 섞여 레벨업 선택 UI(y≈815)보다
	# 위에 있었다. 화면이 시키는 순서와 실제 순서가 거꾸로였다는 뜻이다.
	# 나가는 안내와 나가는 버튼은 성장 선택 아래, 마지막 줄에 둔다.
	extraction_return_row = HBoxContainer.new()
	extraction_return_row.name = "ExtractionReturnRow"
	extraction_return_row.add_theme_constant_override("separation", 12)
	content.add_child(extraction_return_row)
	extraction_return_hint = Label.new()
	extraction_return_hint.name = "ReturnHint"
	extraction_return_hint.text = "탭하면 쉘터로 복귀"
	extraction_return_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extraction_return_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extraction_return_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extraction_return_hint.add_theme_font_override("font", FONT)
	extraction_return_hint.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION)
	extraction_return_hint.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	extraction_return_row.add_child(extraction_return_hint)
	extraction_return_button = Button.new()
	extraction_return_button.name = "ExtractionReturnButton"
	extraction_return_button.text = "쉘터로 돌아가기"
	# 가로 720px 높이에서는 이 줄이 패널 밖으로 14px 삐져나갔다 — 낮은 화면에서만
	# 줄여서 담는다. 나가는 버튼이 화면 밖에 있으면 아무 의미가 없다.
	var short_viewport := host.get_viewport().get_visible_rect().size.y < 800.0
	extraction_return_button.custom_minimum_size = Vector2(
		176 if short_viewport else 196, 36 if short_viewport else 46
	)
	extraction_return_button.focus_mode = Control.FOCUS_NONE
	extraction_return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	extraction_return_button.add_theme_font_override("font", FONT)
	extraction_return_button.add_theme_font_size_override("font_size", HudStyle.TYPE_BODY)
	extraction_return_button.add_theme_color_override("font_color", Color("#f0e6c4"))
	extraction_return_button.add_theme_stylebox_override(
		"normal", HudStyle.panel(Color("#1b2119"), Color("#9c8646"), 7)
	)
	extraction_return_button.add_theme_stylebox_override(
		"hover", HudStyle.panel(Color("#26301f"), Color("#e0c46f"), 7)
	)
	extraction_return_button.add_theme_stylebox_override(
		"pressed", HudStyle.panel(Color("#333d27"), Color("#f0d77d"), 7)
	)
	extraction_return_row.add_child(extraction_return_button)


func set_extraction_return_state(pending_choices: int) -> void:
	# 성장 선택이 남아 있으면 버튼을 죽이지 않는다 — 눌렀을 때 이유를 말해 준다.
	# 비활성 버튼은 "고장났다"로 읽히고, 이 화면은 성장 포인트가 잠기는 유일한
	# 길목이라 침묵하면 안 된다.
	if extraction_return_hint == null or extraction_return_button == null:
		return
	extraction_return_hint.modulate.a = 1.0
	if pending_choices > 0:
		extraction_return_hint.text = (
			"위에서 성장을 %d개 더 골라야 나갈 수 있습니다." % pending_choices
		)
		extraction_return_hint.add_theme_color_override("font_color", Color("#e8d18a"))
		extraction_return_button.text = "성장 선택 후 복귀"
	else:
		extraction_return_hint.text = "화면을 탭하거나 오른쪽 버튼으로 쉘터에 돌아갑니다."
		extraction_return_hint.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
		extraction_return_button.text = "쉘터로 돌아가기"


func flash_extraction_return_warning(pending_choices: int) -> void:
	if extraction_return_hint == null:
		return
	extraction_return_hint.text = "먼저 성장을 고르세요 · 남은 선택 %d개" % maxi(1, pending_choices)
	extraction_return_hint.add_theme_color_override("font_color", Color("#ffb27a"))
	var flash := extraction_return_hint.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for _pulse in 2:
		flash.tween_property(extraction_return_hint, "modulate:a", 0.25, 0.1)
		flash.tween_property(extraction_return_hint, "modulate:a", 1.0, 0.16)




# 상단 중앙 메인 임무 배너. 이름의 'jackpot'은 봉인 화물 사건 시절의 잔재다 —
# 지금은 MainMissionChain이 구역별 3단계 미션 전부를 이 패널로 말한다.
# 노드 이름/필드명을 바꾸면 스모크 테스트와 배너 정렬 경로가 함께 흔들려 그대로 둔다.
func build_jackpot_hud() -> void:
	jackpot_hud = PanelContainer.new()
	jackpot_hud.name = "JackpotEventPanel"
	jackpot_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	jackpot_hud.offset_left = -215.0
	jackpot_hud.offset_top = 16.0
	jackpot_hud.offset_right = 215.0
	jackpot_hud.offset_bottom = 80.0
	jackpot_hud.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK, Color("#9c7842"), 7)
	)
	jackpot_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jackpot_hud.z_index = 84
	host.get_node("HUD").add_child(jackpot_hud)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	jackpot_hud.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.name = "EventIcon"
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = UI_ICONS.get_icon("secure", 38, Color("#e7b860"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	jackpot_step_label = Label.new()
	jackpot_step_label.add_theme_font_override("font", FONT)
	jackpot_step_label.add_theme_font_size_override("font_size", 15)
	jackpot_step_label.add_theme_color_override("font_color", Color("#f0d18a"))
	jackpot_step_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(jackpot_step_label)
	jackpot_detail_label = Label.new()
	jackpot_detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	jackpot_detail_label.max_lines_visible = 1
	jackpot_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	jackpot_detail_label.add_theme_font_override("font", FONT)
	jackpot_detail_label.add_theme_font_size_override("font_size", 12)
	jackpot_detail_label.add_theme_color_override("font_color", Color("#b7c3bd"))
	copy.add_child(jackpot_detail_label)
	var status := VBoxContainer.new()
	status.custom_minimum_size = Vector2(70, 0)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 4)
	row.add_child(status)
	jackpot_pressure_label = Label.new()
	jackpot_pressure_label.text = "정찰"
	jackpot_pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	jackpot_pressure_label.add_theme_font_override("font", FONT)
	jackpot_pressure_label.add_theme_font_size_override("font_size", 11)
	jackpot_pressure_label.add_theme_color_override("font_color", Color("#8db8a3"))
	status.add_child(jackpot_pressure_label)
	jackpot_progress = ProgressBar.new()
	jackpot_progress.custom_minimum_size = Vector2(70, 7)
	jackpot_progress.min_value = 0
	jackpot_progress.max_value = 4
	jackpot_progress.show_percentage = false
	jackpot_progress.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#121817"), Color("#4b5a54"), 7)
	)
	jackpot_progress.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#c88737"), Color("#f0bd61"), 7)
	)
	status.add_child(jackpot_progress)




func setup_player_combat_feedback() -> void:
	damage_feedback_canvas = CanvasLayer.new()
	damage_feedback_canvas.name = "PlayerDamageFeedback"
	damage_feedback_canvas.layer = 129
	host.add_child(damage_feedback_canvas)

	damage_vignette = ColorRect.new()
	damage_vignette.name = "DamageVignette"
	damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float radial = smoothstep(0.28, 1.12, length(centered));
	float edge = max(radial, smoothstep(0.72, 1.0, max(abs(centered.x), abs(centered.y))));
	float pulse = edge * intensity;
	COLOR = vec4(0.72, 0.015, 0.01, pulse * 0.68);
}
"""
	damage_vignette_material = ShaderMaterial.new()
	damage_vignette_material.shader = vignette_shader
	damage_vignette_material.set_shader_parameter("intensity", 0.0)
	damage_vignette.material = damage_vignette_material
	damage_feedback_canvas.add_child(damage_vignette)
	# 문자 "▲"는 웹 기본 폰트에 글리프가 없어 깨진 네모로 떴다.
	# 폰트에 기대지 말고 직접 그린 화살표 텍스처를 쓴다.
	damage_direction_indicator = TextureRect.new()
	damage_direction_indicator.name = "DamageDirectionIndicator"
	damage_direction_indicator.texture = UI_ICONS.get_icon("up", 40, Color("#ff5a46"))
	damage_direction_indicator.custom_minimum_size = Vector2(40, 40)
	damage_direction_indicator.size = Vector2(40, 40)
	damage_direction_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	damage_direction_indicator.pivot_offset = Vector2(20, 20)
	damage_direction_indicator.modulate.a = 0.0
	damage_direction_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_feedback_canvas.add_child(damage_direction_indicator)

	player_world_health_bar = Control.new()
	player_world_health_bar.name = "PlayerWorldHealthBar"
	player_world_health_bar.custom_minimum_size = Vector2(48, 7)
	player_world_health_bar.size = Vector2(48, 7)
	player_world_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_background_panel := Panel.new()
	health_background_panel.name = "Background"
	health_background_panel.position = Vector2.ZERO
	health_background_panel.size = Vector2(48, 7)
	health_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color(0.018, 0.022, 0.024, 0.84)
	health_background.border_width_left = 1
	health_background.border_width_top = 1
	health_background.border_width_right = 1
	health_background.border_width_bottom = 1
	health_background.border_color = Color(0.82, 0.86, 0.8, 0.38)
	health_background.corner_radius_top_left = 4
	health_background.corner_radius_top_right = 4
	health_background.corner_radius_bottom_left = 4
	health_background.corner_radius_bottom_right = 4
	health_background.anti_aliasing = true
	health_background_panel.add_theme_stylebox_override("panel", health_background)
	player_world_health_bar.add_child(health_background_panel)
	player_world_health_fill = Panel.new()
	player_world_health_fill.name = "Fill"
	player_world_health_fill.position = Vector2(1, 1)
	player_world_health_fill.size = Vector2(46, 5)
	player_world_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_fill_style = StyleBoxFlat.new()
	player_health_fill_style.bg_color = Color(0.28, 0.86, 0.48, 0.96)
	player_health_fill_style.corner_radius_top_left = 3
	player_health_fill_style.corner_radius_top_right = 3
	player_health_fill_style.corner_radius_bottom_left = 3
	player_health_fill_style.corner_radius_bottom_right = 3
	player_health_fill_style.anti_aliasing = true
	player_world_health_fill.add_theme_stylebox_override("panel", player_health_fill_style)
	player_world_health_bar.add_child(player_world_health_fill)
	aim_canvas.add_child(player_world_health_bar)
	roll_cooldown_indicator = ROLL_COOLDOWN_INDICATOR_SCRIPT.new() as Control
	roll_cooldown_indicator.name = "RollCooldownIndicator"
	aim_canvas.add_child(roll_cooldown_indicator)
	reload_reticle_indicator = ROLL_COOLDOWN_INDICATOR_SCRIPT.new() as Control
	reload_reticle_indicator.name = "ReloadReticleIndicator"
	reload_reticle_indicator.scale = Vector2.ONE * 1.25
	aim_canvas.add_child(reload_reticle_indicator)
	build_cover_chip()


func build_cover_chip() -> void:
	# 엄폐 칩 — 플레이어 머리 위 체력바 아래에 작게. "엄폐"(방패) / 사격 노출 중 "노출".
	cover_chip = PanelContainer.new()
	cover_chip.name = "CoverChip"
	cover_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_chip.add_theme_stylebox_override("panel", HudStyle.chip(HudStyle.GREEN))
	cover_chip.visible = false
	cover_chip.z_index = 118
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_chip.add_child(row)
	cover_chip_icon = TextureRect.new()
	cover_chip_icon.texture = UI_ICONS.get_icon("armor", 14, HudStyle.GREEN)
	cover_chip_icon.custom_minimum_size = Vector2(14, 14)
	cover_chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cover_chip_icon)
	cover_chip_label = HudStyle.label("엄폐", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT)
	cover_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cover_chip_label)
	aim_canvas.add_child(cover_chip)


func update_cover_chip(in_cover: bool, exposed: bool, anchor: Vector2, visible_now: bool = true) -> void:
	if cover_chip == null:
		return
	var next_state := "" if not in_cover else ("exposed" if exposed else "covered")
	if next_state != cover_chip_state:
		cover_chip_state = next_state
		match next_state:
			"covered":
				cover_chip_label.text = "엄폐"
				cover_chip_label.add_theme_color_override("font_color", HudStyle.TEXT)
				cover_chip_icon.texture = UI_ICONS.get_icon("armor", 14, HudStyle.GREEN)
				cover_chip.add_theme_stylebox_override("panel", HudStyle.chip(HudStyle.GREEN))
			"exposed":
				cover_chip_label.text = "노출"
				cover_chip_label.add_theme_color_override("font_color", HudStyle.WARN)
				cover_chip_icon.texture = UI_ICONS.get_icon("armor", 14, HudStyle.WARN)
				cover_chip.add_theme_stylebox_override("panel", HudStyle.chip(HudStyle.WARN))
	cover_chip.visible = visible_now and not next_state.is_empty()
	if cover_chip.visible:
		cover_chip.position = anchor - Vector2(cover_chip.size.x * 0.5, 0.0)




func build_controls_lesson() -> void:
	# 첫 출정 1회, 데스크톱 전용 — 아무도 가르쳐 주지 않던 키들을 한 줄로.
	# (모바일 버튼은 라벨이 곧 설명이라 필요 없다.)
	if DisplayServer.is_touchscreen_available() or GameState.field_controls_lesson_seen:
		return
	GameState.field_controls_lesson_seen = true
	GameState.save_persistent_state()
	var panel := PanelContainer.new()
	panel.name = "FieldControlsLesson"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -352
	panel.offset_right = 352
	# 상호작용 카드(하단 -257~-173)와 정면으로 겹쳐 둘 다 못 읽혔다 — 그 위로 올린다.
	panel.offset_bottom = -266
	panel.offset_top = -322
	panel.add_theme_stylebox_override("panel", HudStyle.toast())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 120
	host.get_node("HUD").add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var font := HudStyle.FONT
	for pair in [
		["TAB", "지도"], ["R", "장전"], ["SHIFT", "구급약"],
		["E", "가방"], ["SPACE", "구르기"], ["T", "통조림 투척"], ["우클릭", "정조준"],
	]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		row.add_child(item)
		var keycap := PanelContainer.new()
		keycap.add_theme_stylebox_override("panel", HudStyle.keycap())
		item.add_child(keycap)
		var key_label := Label.new()
		key_label.text = str(pair[0])
		key_label.add_theme_font_override("font", font)
		key_label.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION)
		key_label.add_theme_color_override("font_color", HudStyle.TEXT)
		keycap.add_child(key_label)
		var caption := Label.new()
		caption.text = str(pair[1])
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_override("font", font)
		caption.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION)
		caption.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
		item.add_child(caption)
	HudStyle.enter(panel)
	var fade := panel.create_tween()
	fade.tween_interval(12.0)
	fade.tween_property(panel, "modulate:a", 0.0, 0.8)
	fade.tween_callback(panel.queue_free)


func setup_aim_feedback() -> void:
	aim_direction_indicator = MeshInstance3D.new()
	aim_direction_indicator.name = "AimDirectionIndicator"
	aim_direction_indicator.position = Vector3(0, -0.69, 0)
	aim_direction_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arrow_mesh: ImmediateMesh = host._create_aim_ring_arrow_mesh()
	var arrow_material := StandardMaterial3D.new()
	arrow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_material.albedo_color = Color(0.92, 0.76, 0.34, 0.42)
	arrow_material.no_depth_test = false
	arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arrow_mesh.surface_set_material(0, arrow_material)
	aim_direction_indicator.mesh = arrow_mesh
	host.player.add_child(aim_direction_indicator)

	var laser_widths := [0.072, 0.034, 0.010]
	var laser_colors := [
		Color(1.0, 0.02, 0.08, 0.10),
		Color(1.0, 0.04, 0.09, 0.32),
		Color(1.0, 0.72, 0.72, 0.96),
	]
	var laser_energies := [1.8, 3.8, 7.0]
	for layer_index in laser_widths.size():
		var mesh := BoxMesh.new()
		mesh.size = Vector3(laser_widths[layer_index], laser_widths[layer_index], 1.0)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = laser_colors[layer_index]
		material.emission_enabled = true
		material.emission = Color(1.0, 0.015, 0.055)
		material.emission_energy_multiplier = laser_energies[layer_index]
		material.no_depth_test = true
		mesh.material = material
		var layer := MeshInstance3D.new()
		layer.name = "AimGuideLaserGlow%d" % layer_index
		layer.mesh = mesh
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.visible = false
		host.add_child(layer)
		host.laser_glow_layers.append(layer)
		host.laser_glow_meshes.append(mesh)
		host.laser_glow_materials.append(material)
	laser_beam = host.laser_glow_layers[2]
	laser_beam.name = "AimGuideLaserCore"
	laser_beam_mesh = host.laser_glow_meshes[2]

	var endpoint_mesh := SphereMesh.new()
	endpoint_mesh.radius = 0.065
	endpoint_mesh.height = 0.13
	endpoint_mesh.radial_segments = 12
	endpoint_mesh.rings = 6
	var endpoint_material := StandardMaterial3D.new()
	endpoint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	endpoint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	endpoint_material.albedo_color = Color(1.0, 0.18, 0.22, 0.82)
	endpoint_material.emission_enabled = true
	endpoint_material.emission = Color(1.0, 0.025, 0.06)
	endpoint_material.emission_energy_multiplier = 6.0
	endpoint_material.no_depth_test = true
	endpoint_mesh.material = endpoint_material
	laser_endpoint = MeshInstance3D.new()
	laser_endpoint.name = "AimGuideLaserEndpoint"
	laser_endpoint.mesh = endpoint_mesh
	laser_endpoint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser_endpoint.visible = false
	host.add_child(laser_endpoint)

	aim_canvas = CanvasLayer.new()
	aim_canvas.name = "AimFeedbackHUD"
	aim_canvas.layer = 130
	host.add_child(aim_canvas)
	aim_reticle = AIM_RETICLE_SCRIPT.new()
	aim_reticle.name = "AimReticle"
	aim_canvas.add_child(aim_reticle)
	aim_reticle.visible = not DisplayServer.is_touchscreen_available()


