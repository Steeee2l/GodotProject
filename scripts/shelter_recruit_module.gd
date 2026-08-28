class_name ShelterRecruitModule
extends Node3D
## 주민 영입소.
## 쉘터 수용량이 티어마다 3배 이상 늘었는데 획득 경로가 출정 후송(판당 1~2)뿐이면
## 그 수용량은 영원히 숫자로만 남는다. 여기서 고철·캣닢을 태워 고양이를 부른다 —
## "소문을 듣고 모인다"가 인크리멘탈의 성장 레버가 된다.
## 3D 기물은 없다. 운영 독의 버튼과 이 모달로만 존재한다(쉘터 UI-first 규약).

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")

# 한 번에 부를 수 있는 최대 인원. 900명 수용량을 한 마리씩 누르게 두면 그건 UI가 아니다.
const BULK_RECRUIT_COUNT := 10

@export var interaction_radius := 4.0

var ui_layer: CanvasLayer
var content: VBoxContainer
var action_bar: VBoxContainer
var feedback_label: Label
var pending_feedback := ""
var pending_feedback_ok := false


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("shelter_recruit")
	set_meta("module_kind", "recruit")


func get_interaction_prompt() -> String:
	return "주민 영입소 · 고철과 캣닢으로 고양이를 부른다"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	_open_ui()
	return "소문을 듣고 고양이가 모입니다."


func set_interaction_focus(_value: bool) -> void:
	pass


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	pending_feedback = ""
	pending_feedback_ok = false
	ui_layer = CanvasLayer.new()
	ui_layer.name = "ShelterRecruitUILayer"
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
	ModalDismiss.install(ui_layer, dim, func() -> void:
		if is_instance_valid(ui_layer):
			ui_layer.queue_free()
	)
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
	panel.name = "ShelterRecruitPanel"
	var panel_width := minf(760.0, maxf(260.0, available_size.x - outer_margin * 2.0))
	var panel_height := minf(560.0, maxf(300.0, available_size.y - outer_margin * 2.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.018, 0.023, 0.024, 0.96), Color("#8fb3c4"))
	)
	center.add_child(panel)
	HudStyle.enter_modal(panel)
	var margin := MarginContainer.new()
	var inner_margin := 12 if viewport_size.y < 640.0 else 20
	margin.add_theme_constant_override("margin_left", inner_margin)
	margin.add_theme_constant_override("margin_top", inner_margin)
	margin.add_theme_constant_override("margin_right", inner_margin)
	margin.add_theme_constant_override("margin_bottom", inner_margin)
	panel.add_child(margin)
	# 목록만 스크롤하고 액션 줄은 바닥에 고정 — 다른 시설 모달과 같은 규약.
	var shell := VBoxContainer.new()
	shell.name = "ShelterRecruitShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)
	var panel_scroll := HudStyle.make_scroll()
	panel_scroll.name = "ShelterRecruitScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(panel_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = 0.0
	content.add_theme_constant_override("separation", 10 if viewport_size.y < 640.0 else 16)
	panel_scroll.add_child(content)
	action_bar = VBoxContainer.new()
	action_bar.name = "ShelterRecruitActionBar"
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	action_bar.add_theme_constant_override("separation", 6)
	shell.add_child(action_bar)
	_rebuild_ui()


func _rebuild_ui() -> void:
	GameState._ensure_resident_records()
	for child in content.get_children():
		child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 760.0
	var compact := viewport_size.x < 1040.0 or viewport_size.y < 680.0

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	content.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	title_box.add_child(_label("주민 영입소", 24, Color("#dcecf2")))
	title_box.add_child(_label(
		"고철과 캣닢을 내걸면 소문을 듣고 고양이가 찾아옵니다.", 13, Color("#93a6a2")
	))
	var close := _close_button()
	close.pressed.connect(func(): ui_layer.queue_free())
	top_row.add_child(close)

	var wallet := HFlowContainer.new()
	wallet.name = "RecruitWallet"
	wallet.add_theme_constant_override("h_separation", 8)
	wallet.add_theme_constant_override("v_separation", 6)
	content.add_child(wallet)
	# 지갑 칩은 아이콘 + 수치만(이름은 툴팁) — 재화 표기 규칙.
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"scrap", GameState.format_compact_number(GameState.scrap), compact
	))
	wallet.add_child(SHELTER_UI.make_currency_chip(
		"catnip", GameState.format_compact_number(GameState.catnip), compact
	))

	var residents: int = GameState.resident_cat_ids.size()
	var capacity: int = GameState.get_resident_capacity()
	var summary := GridContainer.new()
	summary.name = "RecruitSummary"
	summary.columns = 1 if narrow else 3
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	summary.add_child(_summary_card("주민", "%d / %d명" % [residents, capacity], "resident", compact))
	summary.add_child(_summary_card(
		"자연 유입",
		"%.1f명/시간" % GameState.get_resident_drift_per_hour(),
		"resident",
		compact
	))
	var cost: Dictionary = GameState.get_resident_recruit_cost()
	summary.add_child(_summary_card(
		"다음 한 마리",
		"고철 %s · 캣닢 %s" % [
			GameState.format_compact_number(int(cost.get("scrap", 0))),
			GameState.format_compact_number(int(cost.get("catnip", 0))),
		],
		"scrap",
		compact
	))

	var body := VBoxContainer.new()
	body.name = "RecruitBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	body.add_child(_label(
		"영입 비용은 지금 티어 구간을 채울수록 오릅니다. 쉘터를 확장하면 새 구간의 "
		+ "첫 고양이는 다시 싸집니다 — 확장할수록 다시 빠글빠글해집니다.",
		13,
		Color("#a7b7b2")
	))
	body.add_child(_label(
		"생산 라인이 도는 동안에는 값을 치르지 않아도 고양이가 조금씩 합류합니다. "
		+ "자리를 비운 동안에도 최대 8시간까지 쌓입니다.",
		13,
		Color("#8d9e99")
	))
	if capacity - residents <= 0:
		body.add_child(_label(
			"수용량이 가득 찼습니다. 쉘터를 확장해야 더 받을 수 있습니다.",
			13,
			Color("#e6c779")
		))
	_rebuild_actions()


func _rebuild_actions() -> void:
	if not is_instance_valid(action_bar):
		return
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 760.0
	var actions: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	actions.name = "RecruitActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	action_bar.add_child(actions)
	var cost: Dictionary = GameState.get_resident_recruit_cost()
	var scrap_cost := int(cost.get("scrap", 0))
	var catnip_cost := int(cost.get("catnip", 0))
	var room_left: int = GameState.get_resident_capacity() - GameState.resident_cat_ids.size()
	var one := _button("고철 %s · 캣닢 %s · 한 마리 부르기" % [
		GameState.format_compact_number(scrap_cost),
		GameState.format_compact_number(catnip_cost),
	], "resident")
	one.name = "RecruitOneButton"
	one.disabled = room_left <= 0
	_stretch_action(one)
	one.pressed.connect(func(): _recruit(1))
	actions.add_child(one)
	var bulk := _button("최대 %d마리 한 번에" % BULK_RECRUIT_COUNT, "resident")
	bulk.name = "RecruitBulkButton"
	bulk.disabled = room_left <= 0
	_stretch_action(bulk)
	bulk.pressed.connect(func(): _recruit(BULK_RECRUIT_COUNT))
	actions.add_child(bulk)
	feedback_label = _label("", 12, Color("#e6c779"))
	feedback_label.name = "RecruitFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_bar.add_child(feedback_label)
	if not pending_feedback.is_empty():
		_apply_feedback_style(pending_feedback, pending_feedback_ok)


func _recruit(count: int) -> void:
	var joined := 0
	var scrap_spent := 0
	var catnip_spent := 0
	var last_reason := ""
	for _index in maxi(1, count):
		var result: Dictionary = GameState.try_recruit_resident()
		if not bool(result.get("ok", false)):
			last_reason = str(result.get("reason", ""))
			break
		joined += 1
		var paid: Dictionary = result.get("cost", {}) as Dictionary
		scrap_spent += int(paid.get("scrap", 0))
		catnip_spent += int(paid.get("catnip", 0))
	if joined <= 0:
		match last_reason:
			"capacity":
				_set_feedback("수용량이 가득 찼습니다. 쉘터를 확장하세요.", false)
			"scrap":
				_set_feedback("고철이 부족합니다.", false)
			"catnip":
				_set_feedback("캣닢이 부족합니다.", false)
			_:
				_set_feedback("지금은 영입할 수 없습니다.", false)
		_rebuild_ui()
		return
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	get_tree().call_group("shelter_resident_host", "_update_stats")
	_set_feedback("고양이 %d마리가 합류했습니다. (고철 %s · 캣닢 %s)" % [
		joined,
		GameState.format_compact_number(scrap_spent),
		GameState.format_compact_number(catnip_spent),
	], true)
	_rebuild_ui()


func _stretch_action(button: Button) -> void:
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _set_feedback(message: String, success: bool) -> void:
	pending_feedback = message
	pending_feedback_ok = success
	_apply_feedback_style(message, success)


func _apply_feedback_style(message: String, success: bool) -> void:
	if not is_instance_valid(feedback_label):
		return
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color", Color("#9de0b1") if success else Color("#f09a8a")
	)


func _summary_card(title: String, value: String, icon_name: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 52 if compact else 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.035, 0.041, 0.043, 0.92), Color("#46545c"))
	)
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
	icon.texture = UI_ICONS.get_icon(icon_name, 36, Color("#9fc9d8"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)
	var title_label := _label(title, 10 if compact else 11, Color("#8e9b9b"))
	var value_label := _label(value, 13 if compact else 15, Color("#e4dfd1"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ELLIPSIS 라벨의 최소 폭은 1px이다 — 못 박지 않으면 칸이 좁아질 때 글자가 사라진다.
	title_label.custom_minimum_size.x = 48.0
	value_label.custom_minimum_size.x = 62.0
	box.add_child(title_label)
	box.add_child(value_label)
	return panel


func _button(text: String, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, HudStyle.TEXT)
		# 대형 생성 PNG라 폭 상한을 안 걸면 아이콘이 버튼 전체로 부푼다.
		button.add_theme_constant_override("icon_max_width", 26)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = false
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
