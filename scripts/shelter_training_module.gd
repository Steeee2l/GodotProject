class_name ShelterTrainingModule
extends Node3D

const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
# 쉘터 UI 공용 디자인 언어(이름 짓기 화면 기준) — 색·반지름·글자는 여기서만 가져온다.
const SHELTER_THEME := preload("res://scripts/hud/shelter_theme.gd")

# 요약 카드 아이콘 색 — 재화·능력치 색은 아이콘에만 쓴다(글자는 흰색 한 가지).
const SUMMARY_ICON_COLORS := {
	"health": Color("#e87668"),
	"stamina": Color("#e4ca6c"),
	"speed": Color("#77c5a1"),
	"fitness": Color("#8db5d1"),
}

@export var interaction_radius := 4.1

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("TrainingSprite") as Sprite3D

var ui_layer: CanvasLayer
var content: VBoxContainer
var status_label: Label
# _rebuild_ui()가 상태 라벨을 새로 만들기 때문에 마지막 문구를 따로 들고 있다가
# 재생성 뒤 다시 붙인다 — 그러지 않으면 성공 문구가 한 프레임 만에 사라진다.
var pending_status := ""
var pending_status_ok := false
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
	return "통조림을 소비해 플레이어 능력을 영구 강화합니다."


func set_interaction_focus(value: bool) -> void:
	if sprite:
		sprite.modulate = Color(1.08, 1.08, 0.88, 1.0) if value else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	# 새로 열 때는 지난 세션의 문구를 끌고 오지 않는다.
	pending_status = ""
	pending_status_ok = false
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
	var dim := SHELTER_THEME.dim_backdrop()
	modal.add_child(dim)
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
	# 화면에서 실제로 쓸 수 있는 크기를 넘지 않는다 — 내부 위젯이 최소 폭을
	# 밀어 올리면 패널째로 화면 밖으로 나간다.
	# 세로 화면은 780 상한을 풀어 위아래를 꽉 쓴다 — 훈련 카드가 스크롤 아래로
	# 숨던 205px을 화면 안으로 끌어올린다.
	var panel_height_room := maxf(320.0, available_size.y - 32.0)
	panel.custom_minimum_size = Vector2(
		minf(1120.0, maxf(280.0, available_size.x - 32.0)),
		panel_height_room if viewport_size.y > viewport_size.x else minf(780.0, panel_height_room)
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 모달 판의 안쪽 여백은 스타일박스가 쥔다 — 작은 화면에선 조금 줄인다.
	var panel_style := SHELTER_THEME.modal_style()
	if compact_layout:
		var inner_margin := 16.0
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
	content.add_theme_constant_override("separation", 12 if compact_layout else 16)
	panel.add_child(content)
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
	# 헤더: 민트 이름표 / 굵은 제목 / 회색 설명 ······ [통조림 칩] [둥근 닫기]
	var on_close := func() -> void:
		if is_instance_valid(ui_layer):
			ui_layer.queue_free()
	var header := SHELTER_THEME.modal_header(
		"영구 강화",
		"출정에서 모아 온 통조림을 소비해 능력을 영구히 올립니다.",
		on_close,
		"훈련장"
	)
	header.name = "TrainingHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(header)
	# 훈련 화폐는 통조림이다(유저 확정). 지갑 칩도 쉘터 통조림 재고를 보여 준다 —
	# 가방 통조림(투척용)이 아니라 훈련에 실제로 쓸 수 있는 수량이어야 한다.
	# 지갑 칩은 아이콘 + 수치만 — 통조림 아이콘 옆에 "통조림"이라고 또 쓰지 않는다.
	var resource_panel := _currency_chip("food", GameState.format_compact_number(GameState.shelter_canned_food))
	resource_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var resource_value := resource_panel.get_meta("label") as Label
	if resource_value != null:
		resource_value.name = "TrainingResourceLabel"
	header.add_child(resource_panel)
	header.move_child(resource_panel, 1)
	var close := header.get_meta("close_button") as Button
	close.name = "CloseButton"
	# 닫기는 아이콘 하나(글자 없음) — 특수기호 대신 그린 아이콘을 쓴다.
	close.text = ""
	close.icon = UI_ICONS.get_icon("close", 20, SHELTER_THEME.TEXT)
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.tooltip_text = "닫기"

	var summary := GridContainer.new()
	summary.columns = 2 if narrow_layout or compact_layout else 4
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 10)
	summary.add_theme_constant_override("v_separation", 10)
	content.add_child(summary)
	_add_summary_chip(summary, "health", "최대 체력", "%d" % GameState.get_max_health(), SUMMARY_ICON_COLORS["health"])
	_add_summary_chip(summary, "stamina", "스태미나", "%d" % roundi(GameState.get_max_stamina()), SUMMARY_ICON_COLORS["stamina"])
	_add_summary_chip(summary, "speed", "이동 배율", "x%.2f" % GameState.get_move_speed_multiplier(), SUMMARY_ICON_COLORS["speed"])
	_add_summary_chip(summary, "fitness", "반동 제어", "x%.2f" % GameState.get_recoil_control_multiplier(), SUMMARY_ICON_COLORS["fitness"])

	var section_hint := SHELTER_THEME.caption("카드를 눌러 즉시 훈련")
	section_hint.name = "TrainingSectionHint"
	section_hint.custom_minimum_size = Vector2(150, 0)
	section_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	section_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	section_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	section_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var section_row := SHELTER_THEME.section_header("훈련 과목", section_hint)
	content.add_child(section_row)
	var scroll := SHELTER_THEME.scroll()
	scroll.name = "TrainingTreeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	content.add_child(scroll)
	var tree := GridContainer.new()
	tree.name = "TrainingTreeGrid"
	tree.columns = 1 if narrow_layout else 2
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.add_theme_constant_override("h_separation", 12)
	tree.add_theme_constant_override("v_separation", 12)
	scroll.add_child(tree)
	_add_training_card(tree, "vitality")
	_add_training_card(tree, "recovery")
	_add_training_card(tree, "endurance")
	_add_training_card(tree, "agility")
	_add_training_card(tree, "fieldcraft")
	# 가방 확장 카드는 가방 무제한화(2026-08-30)로 폐지됐다.
	# 탄약 운용 훈련 4종 — 정의는 GameState.TRAINING_NODE_DEFS가 쥔다.
	_add_training_card(tree, "magazine_drill")
	_add_training_card(tree, "quick_hands")
	_add_training_card(tree, "ammo_carry")
	_add_training_card(tree, "sortie_supply")
	status_label = SHELTER_THEME.caption("")
	status_label.name = "TrainingStatus"
	status_label.custom_minimum_size.y = 18
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	if not pending_status.is_empty():
		_apply_status_style(pending_status, pending_status_ok)


func _add_summary_chip(parent: Container, icon_name: String, title: String, value: String, color: Color) -> void:
	# 작은 설명 + 큰 굵은 숫자. 보더 없는 표면 카드.
	var card := SHELTER_THEME.stat_card(title, value, UI_ICONS.get_icon(icon_name, 42, color))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := card.get_meta("value_label") as Label
	if value_label != null:
		value_label.add_theme_font_size_override(
			"font_size",
			SHELTER_THEME.TYPE_NUMBER_SMALL if compact_layout else SHELTER_THEME.TYPE_NUMBER
		)
	parent.add_child(card)


func _add_training_card(parent: GridContainer, node_id: String) -> void:
	var definition := GameState.get_training_definition(node_id)
	var rank := GameState.get_training_rank(node_id)
	var max_rank := int(definition.get("max_rank", 1))
	var cost := GameState.get_training_cost(node_id)
	var requirements_met := GameState.get_training_requirements_met(node_id)
	var maxed := rank >= max_rank
	# 선행 미충족 카드는 글자 전체가 흐려진다 — 색이 먼저 말한다.
	var faded := not requirements_met and not maxed
	var card := Button.new()
	card.name = "TrainingCard_%s" % node_id
	card.custom_minimum_size = Vector2(0, 118 if compact_layout else 132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.text = ""
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", SHELTER_THEME.flat(SHELTER_THEME.SURFACE, SHELTER_THEME.RADIUS_CARD))
	card.add_theme_stylebox_override("hover", SHELTER_THEME.flat(SHELTER_THEME.SURFACE_HOVER, SHELTER_THEME.RADIUS_CARD))
	card.add_theme_stylebox_override("pressed", SHELTER_THEME.flat(SHELTER_THEME.SURFACE_HOVER, SHELTER_THEME.RADIUS_CARD))
	card.add_theme_stylebox_override("focus", SHELTER_THEME.flat(SHELTER_THEME.SURFACE, SHELTER_THEME.RADIUS_CARD))
	card.add_theme_stylebox_override("disabled", SHELTER_THEME.flat(SHELTER_THEME.SURFACE, SHELTER_THEME.RADIUS_CARD))
	card.disabled = maxed or not requirements_met
	card.pressed.connect(_upgrade_training.bind(node_id))
	parent.add_child(card)

	var card_body := HBoxContainer.new()
	card_body.name = "CardBody"
	card_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_body.offset_left = 16
	card_body.offset_top = 14
	card_body.offset_right = -16
	card_body.offset_bottom = -14
	card_body.add_theme_constant_override("separation", 14)
	card.add_child(card_body)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.add_theme_stylebox_override("panel", SHELTER_THEME.flat(SHELTER_THEME.SURFACE_RAISED, 12))
	card_body.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture = UI_ICONS.get_icon(
		str(definition.get("icon", "fitness")),
		58,
		SHELTER_THEME.TEXT_FAINT if faded else SHELTER_THEME.ACCENT
	)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var title := SHELTER_THEME.label(
		str(definition.get("title", node_id)),
		SHELTER_THEME.TYPE_SECTION if compact_layout else SHELTER_THEME.TYPE_NUMBER_SMALL,
		SHELTER_THEME.TEXT_FAINT if faded else SHELTER_THEME.TEXT,
		true
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ELLIPSIS 라벨의 최소 폭은 1px이다 — 등급 라벨에 밀려 제목이 사라지지 않게.
	title.custom_minimum_size.x = 96.0
	title_row.add_child(title)
	var rank_label := SHELTER_THEME.number(
		"%d / %d" % [rank, max_rank],
		SHELTER_THEME.TYPE_BODY,
		SHELTER_THEME.TEXT_FAINT if faded else (SHELTER_THEME.ACCENT if maxed else SHELTER_THEME.TEXT_DIM)
	)
	rank_label.name = "Rank"
	rank_label.custom_minimum_size = Vector2(52, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(rank_label)

	var description := SHELTER_THEME.label(
		_training_description_text(node_id, definition),
		SHELTER_THEME.TYPE_CAPTION if compact_layout else SHELTER_THEME.TYPE_BODY - 1,
		SHELTER_THEME.TEXT_FAINT if faded else SHELTER_THEME.TEXT_DIM
	)
	description.name = "TrainingCardDescription_%s" % node_id
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 6)
	details.add_child(action_row)
	if maxed:
		var done := SHELTER_THEME.caption("최고 단계", SHELTER_THEME.ACCENT)
		done.name = "Action"
		action_row.add_child(done)
	elif not requirements_met:
		var locked := SHELTER_THEME.caption(
			"선행 필요 · %s" % _training_requirement_text(definition),
			SHELTER_THEME.TEXT_FAINT
		)
		locked.name = "Action"
		locked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked.autowrap_mode = TextServer.AUTOWRAP_OFF
		locked.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		locked.custom_minimum_size.x = 88.0
		action_row.add_child(locked)
	else:
		# 비용은 알약 칩 — 아이콘이 이미 통조림이다. 그 옆에 "통조림"과 "필요"를
		# 또 쓰지 않는다. 재고가 모자라면 수치가 빨강으로 바뀐다(글보다 색이 먼저 읽힌다).
		var cost_chip := _currency_chip("food", GameState.format_compact_number(cost))
		cost_chip.name = "CostChip_food"
		var action_label := cost_chip.get_meta("label") as Label
		action_label.name = "Action"
		if GameState.shelter_canned_food < cost:
			action_label.add_theme_color_override("font_color", SHELTER_THEME.DANGER)
		action_row.add_child(cost_chip)
	# 재화 이름은 화면에서 뺐으니 카드 툴팁이 대신 말한다.
	card.tooltip_text = "%s · 훈련 비용 통조림 %s개 (보유 %s)" % [
		str(definition.get("title", node_id)),
		GameState.format_compact_number(cost),
		GameState.format_compact_number(GameState.shelter_canned_food),
	]
	_set_mouse_passthrough(card_body)


func _training_description_text(node_id: String, definition: Dictionary) -> String:
	# 탄약 운용 훈련은 "지금 장착 무기 기준으로 얼마나 달라지는가"를 숫자로 붙인다.
	var text := str(definition.get("description", ""))
	var weapon_id := str(GameState.equipped_weapon_id)
	var no_mods: Array[String] = []
	var stats: Dictionary = GameState.build_player_weapon_stats(
		weapon_id, no_mods, GameState.get_weapon_enhancement_level(weapon_id)
	)
	var rank := GameState.get_training_rank(node_id)
	match node_id:
		"magazine_drill":
			var base := int(stats.get("base_magazine_size", 0))
			var now := int(stats.get("magazine_size", base))
			if base > 0:
				text += " · 현재 장탄 %d → %d" % [base, now]
		"quick_hands":
			var base := float(stats.get("base_reload_time", 0.0))
			var now := float(stats.get("reload_time", base))
			if base > 0.0:
				text += " · 현재 장전 %.2fs → %.2fs" % [base, now]
		"ammo_carry":
			text += " · 현재 줍는 탄약 x%.2f" % GameState.get_ammo_pickup_multiplier()
		"sortie_supply":
			var magazine := int(stats.get("magazine_size", 0))
			if magazine > 0:
				text += " · 현재 %d탄창(%d발)" % [rank, rank * magazine]
	return text


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
	var definition := GameState.get_training_definition(node_id)
	var title := str(definition.get("title", node_id))
	var result := GameState.try_upgrade_training(node_id)
	if bool(result.get("ok", false)):
		# 성공도 조용하면 통조림만 줄어든 것처럼 보인다. 무엇이 몇 단계가 됐는지 남긴다.
		_set_status(
			"%s %d단계 훈련 완료 · 통조림 -%s" % [
				title,
				int(result.get("rank", 0)),
				GameState.format_compact_number(int(result.get("cost", 0))),
			],
			true
		)
		call_deferred("_rebuild_ui")
		return
	# 실패 사유를 GameState 반환값 그대로 갈라 준다 — "선행 필요"로 뭉뚱그리면
	# 최대 단계·통조림 부족을 구분할 수 없다.
	match str(result.get("reason", "")):
		"canned_food":
			var short: int = maxi(0, int(result.get("cost", 0)) - GameState.shelter_canned_food)
			_set_status("통조림이 %s개 부족합니다. (필요 %s개)" % [
				GameState.format_compact_number(short),
				GameState.format_compact_number(int(result.get("cost", 0))),
			], false)
		"prerequisite":
			_set_status(
				"선행 훈련이 필요합니다 · %s" % _training_requirement_text(definition),
				false
			)
		"max_rank":
			_set_status("%s 훈련은 이미 최대 단계입니다." % title, false)
		_:
			_set_status("훈련 정보를 찾을 수 없습니다.", false)


func _set_status(message: String, success: bool) -> void:
	# 문구는 UI 재생성 뒤에도 남아야 한다 — pending에 보관하고 라벨에도 즉시 반영.
	pending_status = message
	pending_status_ok = success
	_apply_status_style(message, success)


func _apply_status_style(message: String, success: bool) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	status_label.add_theme_color_override(
		"font_color",
		SHELTER_THEME.ACCENT if success else SHELTER_THEME.DANGER
	)


func _currency_chip(currency_id: String, value_text: String) -> PanelContainer:
	# 재화 표기 규칙(유저 확정): 아이콘이 이름이다. 칩엔 아이콘 + "xN"만 적고
	# 이름은 툴팁이 말한다. 노드 이름(ResourceChip_/ResourceIcon_/ResourceValue_)은
	# 프로브·튜토리얼이 찾는 규약이라 그대로 둔다.
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
