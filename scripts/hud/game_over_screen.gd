class_name GameOverScreen
extends RefCounted

# 사망 결과 화면.
#
# main.gd에서 370줄을 떼어냈다. 이 화면이 쓰는 상태는 전부 여기 있고,
# 바깥에서는 build() / present() / apply_layout() 세 개만 부른다.
#
# 2026-09-05 재도색 — 이름 짓기 화면의 디자인 언어(HudStyle). 붉은 테두리·경보
# 아이콘 판을 걷어내고, 거의 검정 판 위에 붉은 eyebrow("사망") + 굵은 제목 +
# 회색 원인 한 줄, 큰 숫자 stat 카드, 교훈은 표면 카드, 남긴 휴대품은 알약 칩,
# 하단에 민트 주 버튼 하나.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
const HudStyle := preload("res://scripts/hud/hud_style.gd")

var host: Node
var canvas: CanvasLayer
var fade: ColorRect
var panel: PanelContainer
var title_label: Label
var cause_label: Label
var survival_value: Label
var kills_value: Label
var damage_value: Label
var loss_label: Label
var loss_count_label: Label
var loss_value_label: Label
var loss_grid: HFlowContainer
var lesson_card: PanelContainer
var lesson_label: Label
var continue_button: Button
var continue_label: Label
var ready_to_continue := false
var continue_started := false


func build(host_node: Node) -> void:
	host = host_node
	canvas = CanvasLayer.new()
	canvas.name = "GameOverCanvas"
	canvas.layer = 180
	canvas.visible = false
	host.add_child(canvas)
	fade = ColorRect.new()
	fade.name = "GameOverFade"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	panel = PanelContainer.new()
	panel.name = "GameOverPanel"
	# 세로 화면(캔버스 폭 720)에서 딱 맞아 떨어지면 그림자가 잘린다. 여백을 남긴다.
	var over_viewport: Vector2 = canvas.get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(720.0, over_viewport.x - 24.0), 500)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 거의 검정 판, 테두리 없음, 큰 그림자 — 붉은 기운은 eyebrow 글자 하나뿐.
	panel.add_theme_stylebox_override("panel", HudStyle.modal())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := VBoxContainer.new()
	header.name = "GameOverHeader"
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	var eyebrow := HudStyle.label("사망", HudStyle.TYPE_CAPTION, HudStyle.DANGER, true)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(eyebrow)
	title_label = HudStyle.label("작전 실패", 30, HudStyle.TEXT, true)
	title_label.name = "GameOverLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)
	cause_label = HudStyle.label("치명상 원인 확인 중", HudStyle.TYPE_BODY, HudStyle.TEXT_DIM)
	cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(cause_label)

	var stats_row := HBoxContainer.new()
	stats_row.name = "GameOverStats"
	stats_row.add_theme_constant_override("separation", 10)
	box.add_child(stats_row)
	kills_value = _add_stat_card(stats_row, "처치")
	survival_value = _add_stat_card(stats_row, "생존 시간")
	damage_value = _add_stat_card(stats_row, "가한 피해")
	loss_value_label = _add_stat_card(stats_row, "손실 가치")

	# 교훈 — 표면 카드 안의 본문 글자. 교훈이 없으면 카드째 숨긴다.
	lesson_card = _surface_card()
	lesson_card.name = "GameOverLessonCard"
	lesson_card.visible = false
	box.add_child(lesson_card)
	lesson_label = HudStyle.label("", HudStyle.TYPE_BODY, HudStyle.TEXT)
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lesson_card.add_child(lesson_label)

	var loss_heading := HBoxContainer.new()
	loss_heading.add_theme_constant_override("separation", 8)
	box.add_child(loss_heading)
	var loss_title := HudStyle.label("현장에 남긴 휴대품", HudStyle.TYPE_HEADING, HudStyle.TEXT, true)
	loss_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loss_heading.add_child(loss_title)
	loss_count_label = HudStyle.label("0종", HudStyle.TYPE_CAPTION, HudStyle.TEXT_DIM)
	loss_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loss_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loss_heading.add_child(loss_count_label)
	var loss_scroll := HudStyle.make_scroll()
	loss_scroll.custom_minimum_size.y = 76
	loss_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(loss_scroll)
	loss_grid = HFlowContainer.new()
	loss_grid.name = "GameOverLossGrid"
	loss_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loss_grid.add_theme_constant_override("h_separation", 8)
	loss_grid.add_theme_constant_override("v_separation", 8)
	loss_scroll.add_child(loss_grid)

	var recovery_banner := _surface_card()
	recovery_banner.name = "GameOverRecoveryBanner"
	box.add_child(recovery_banner)
	loss_label = HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.TEXT_DIM)
	loss_label.name = "GameOverLossLabel"
	loss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loss_label.text = "장비(무기·방어구·부착물)는 전부 남고 가방의 재료·탄약·귀중품만 잃습니다. 다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다."
	recovery_banner.add_child(loss_label)

	var footer := VBoxContainer.new()
	footer.name = "GameOverFooter"
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	continue_button = Button.new()
	continue_button.name = "GameOverContinueButton"
	continue_button.text = "쉘터로"
	continue_button.custom_minimum_size = Vector2(0, 52)
	HudStyle.style_button(continue_button, HudStyle.ACCENT, true)
	continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(continue_button)
	continue_label = HudStyle.label("SPACE 또는 화면 터치  ·  쉘터로 복귀", HudStyle.TYPE_CAPTION, HudStyle.TEXT_FAINT)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(continue_label)


func _surface_card() -> PanelContainer:
	# 판 속 무광 표면 카드(반지름 14, 테두리 없음).
	var card := PanelContainer.new()
	var style := HudStyle.flat(HudStyle.INK_WELL, HudStyle.RADIUS_CARD)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _add_stat_card(parent: HBoxContainer, caption: String) -> Label:
	# 작은 회색 설명 + 큰 굵은 tabular 숫자. 아이콘·색 테두리 없음.
	var card := _surface_card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var caption_label := HudStyle.label(caption, HudStyle.TYPE_CAPTION, HudStyle.TEXT_DIM)
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)
	var value_label := HudStyle.number("-", 22, HudStyle.TEXT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(value_label)
	return value_label


func populate_loss_icons(loot: Dictionary) -> void:
	for child in loss_grid.get_children():
		child.free()
	var entries: Array[Dictionary] = []
	for weapon_id in (loot.get("weapon_inventory", {}) as Dictionary):
		var count := int((loot.get("weapon_inventory", {}) as Dictionary).get(weapon_id, 0))
		if count > 0:
			entries.append({"name": _get_loot_weapon_name(str(weapon_id)), "count": count, "texture": WEAPON_VISUAL_CATALOG.get_weapon_texture(str(weapon_id))})
	for equipment_id in (loot.get("equipment_inventory", {}) as Dictionary):
		var count := int((loot.get("equipment_inventory", {}) as Dictionary).get(equipment_id, 0))
		if count > 0:
			var definition := GameState.get_equipment_definition(str(equipment_id))
			var texture := load(str(definition.get("texture_path", ""))) as Texture2D
			entries.append({"name": str(definition.get("display_name", equipment_id)), "count": count, "texture": texture})
	var simple := [
		["ammo_inventory", "탄약", "ammo"],
		["mod_component_inventory", "부품", "parts"],
		["weapon_mod_inventory", "부착물", "mod"],
	]
	for spec in simple:
		var count := 0
		for amount in (loot.get(spec[0], {}) as Dictionary).values():
			count += int(amount)
		if count > 0:
			entries.append({"name": spec[1], "count": count, "texture": UI_ICONS.get_icon(spec[2], 64)})
	for spec in [["medkits", "구급약", "medkit"], ["canned_food", "통조림", "food"], ["churu", "츄르", "churu"]]:
		var count := int(loot.get(spec[0], 0))
		if count > 0:
			entries.append({"name": spec[1], "count": count, "texture": UI_ICONS.get_icon(spec[2], 64)})
	var lost_cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not lost_cargo.is_empty():
		entries.append({
			"name": str(lost_cargo.get("title", "봉인된 지하철 화물")),
			"count": 1,
			"texture": SUBWAY_SEALED_CARGO_TEXTURE,
		})
	if entries.is_empty():
		var empty := HudStyle.label("분실한 휴대품이 없습니다.", HudStyle.TYPE_BODY, HudStyle.TEXT_DIM)
		empty.custom_minimum_size = Vector2(240, 32)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loss_grid.add_child(empty)
		loss_count_label.text = "없음"
		return
	loss_count_label.text = "%d종" % entries.size()
	for entry in entries:
		# 알약 칩: 작은 아이콘 + 이름 + 개수(tabular).
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", HudStyle.chip())
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.tooltip_text = str(entry.get("name", "휴대품"))
		loss_grid.add_child(chip)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.texture = entry.get("texture") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_label := HudStyle.label(str(entry.get("name", "휴대품")), HudStyle.TYPE_CAPTION + 1, HudStyle.TEXT)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		var count_label := Label.new()
		count_label.text = "x%d" % int(entry.get("count", 0))
		count_label.add_theme_font_override("font", HudStyle.bold_tabular())
		count_label.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION + 1)
		count_label.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(count_label)



func _get_loot_weapon_name(weapon_id: String) -> String:
	match weapon_id:
		"m1911": return "M1911"
		"mp5": return "MP5"
		"double_barrel": return "Shotgun"
		"pump_shotgun": return "Pump"
		"akm": return "AKM"
		"k2": return "K2"
		"baseball_bat": return "Bat"
		_: return "AK-47"



func present(result: Dictionary) -> void:
	# 사망 시점의 결과를 한 번에 채운다. 예전에는 이 열 줄이
	# _begin_player_death_sequence 안에 흩어져 있었다.
	canvas.visible = true
	title_label.text = "작전 실패"
	survival_value.text = str(result.get("survival_time", "00:00"))
	kills_value.text = "%d" % int(result.get("kills", 0))
	damage_value.text = str(result.get("damage_text", "0"))
	var cause := "치명상 · %s  /  %s" % [
		result.get("source_name", "?"),
		result.get("weapon_name", "?"),
	]
	var blocked := int(result.get("blocked", 0))
	if blocked > 0:
		cause += "  ·  방어구가 마지막 공격에서 %d 방어" % blocked
	cause_label.text = cause
	# 교훈 문장은 원인 줄에 붙이지 않고 표면 카드에 따로 앉힌다.
	var lesson := str(result.get("lesson", ""))
	lesson_label.text = lesson
	lesson_card.visible = not lesson.is_empty()
	loss_value_label.text = str(result.get("loss_value_text", "0"))
	# 영구 귀속(2026-08) — 장비는 시체로 가지 않는다. 잃는 건 가방의 재료·탄약·귀중품뿐.
	loss_label.text = "가방의 재료·탄약·귀중품은 현장에, 장비(무기·방어구·부착물)는 전부 손에 남았습니다. 다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다."
	populate_loss_icons(result.get("loot", {}) as Dictionary)
	ready_to_continue = false
	continue_started = false


func _on_continue_pressed() -> void:
	# 화면 어디를 눌러도 host의 _input이 먼저 받아 복귀시킨다. 버튼은 그 경로가
	# 막힌 경우의 안전망 — 같은 함수를 부른다(can_continue 가드는 그쪽에 있다).
	if host != null and host.has_method("_continue_after_death"):
		host.call("_continue_after_death")


func apply_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	panel.custom_minimum_size = Vector2(
		minf(viewport_size.x - 40.0, 760.0),
		minf(viewport_size.y - 40.0, 500.0)
	)


func can_continue() -> bool:
	return ready_to_continue and not continue_started


func mark_continue_started() -> void:
	continue_started = true
