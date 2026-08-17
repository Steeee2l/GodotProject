class_name CatnipScraperModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const RESIDENT_PORTRAITS := preload("res://scripts/resident_portrait_catalog.gd")

@export var interaction_radius := 4.0

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("ScraperSprite") as Sprite3D

var ui_layer: CanvasLayer
var content: VBoxContainer
# 확장·농축은 스크롤 밖 고정 바에 산다 — 세로 실측 879px가 스크롤 아래에
# 잠겨 있어 "확장 기능이 없다"로 읽혔다.
var action_bar: VBoxContainer
# 창고·꾹꾹이 생산기와 같은 피드백 문법. _rebuild_ui()가 라벨을 새로 만들므로
# 마지막 문구를 따로 들고 있다가 재생성 뒤 다시 붙인다.
var feedback_label: Label
var pending_feedback := ""
var pending_feedback_ok := false


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("catnip_scraper")
	set_meta("module_kind", "catnip_scraper")


func get_interaction_prompt() -> String:
	return "스크래핑 생산기 · 통조림→캣닢 (주민 배치)"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	_open_ui()
	return "주민을 배치해 캣닢을 자동 생산합니다."


func set_interaction_focus(value: bool) -> void:
	if sprite:
		sprite.modulate = Color(0.92, 1.16, 0.9, 1.0) if value else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	# 새로 열 때는 지난 세션의 문구를 끌고 오지 않는다.
	pending_feedback = ""
	pending_feedback_ok = false
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CatnipScraperUILayer"
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
	dim.color = Color(0.004, 0.007, 0.006, 0.78)
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
	panel.name = "CatnipScraperPanel"
	# 화면에서 실제로 쓸 수 있는 폭을 절대 넘지 않는다 — 내부 위젯이 최소 폭을
	# 밀어 올리면 패널째로 화면 밖으로 나가 닫기 버튼을 못 누른다.
	var panel_width := minf(940.0, maxf(260.0, available_size.x - outer_margin * 2.0))
	var panel_height := minf(610.0, maxf(320.0, available_size.y - outer_margin * 2.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.019, 0.97), Color("#6fa66d")))
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
	# 목록만 스크롤하고 액션 줄은 바닥에 고정하기 위한 2단 껍데기.
	var shell := VBoxContainer.new()
	shell.name = "CatnipScraperShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "CatnipScraperScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(panel_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 내용 쪽 최소 폭은 스크롤·패널로 거꾸로 전파돼 패널을 화면 밖으로 밀어낸다.
	# 폭은 패널이 정하고 내용은 따라간다.
	content.custom_minimum_size.x = 0.0
	content.add_theme_constant_override("separation", 10 if viewport_size.y < 640.0 else 14)
	panel_scroll.add_child(content)
	action_bar = VBoxContainer.new()
	action_bar.name = "CatnipScraperActionBar"
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
	var header := VBoxContainer.new()
	header.name = "CatnipScraperHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	header.add_child(top_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	title_box.add_child(_label("스크래핑 캣닢 생산기  Lv.%d" % GameState.catnip_scraper_level, 24, Color("#d9efb0")))
	title_box.add_child(_label("캣닢 특화 주민이 부스터 자원을 생산합니다.", 13, Color("#94aa98")))
	var close := _close_button()
	close.pressed.connect(func(): ui_layer.queue_free())
	top_row.add_child(close)
	var wallet := HFlowContainer.new()
	wallet.name = "CatnipScraperWallet"
	wallet.add_theme_constant_override("h_separation", 8)
	wallet.add_theme_constant_override("v_separation", 6)
	header.add_child(wallet)
	wallet.add_child(_fit_chip_text(SHELTER_UI.make_currency_chip(
		"catnip",
		GameState.format_compact_number(GameState.catnip),
		compact,
		not narrow
	), "catnip"))
	wallet.add_child(_fit_chip_text(SHELTER_UI.make_currency_chip(
		"scrap",
		GameState.format_compact_number(GameState.scrap),
		compact,
		not narrow
	), "scrap"))
	var summary := GridContainer.new()
	summary.name = "CatnipScraperSummary"
	summary.columns = 1 if narrow else 2
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	content.add_child(summary)
	summary.add_child(_summary_card("초당 생산", GameState.format_compact_number(GameState.get_catnip_per_second()), "catnip", compact))
	summary.add_child(_summary_card(
		"작업자",
		"%d / %d명" % [GameState.get_active_catnip_workers(), GameState.get_catnip_worker_slots()],
		"resident",
		compact
	))

	# ── 좌석 + 벤치 구조 (꾹꾹이 생산기와 동일한 문법) ─────────────────
	var body := VBoxContainer.new()
	body.name = "CatnipScraperBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)

	var catnip_slots: int = GameState.get_catnip_worker_slots()
	body.add_child(_label("작업 좌석 · 앉은 고양이가 캣닢을 만듭니다", 14, Color("#dfe8dc")))
	var seat_row := HFlowContainer.new()
	seat_row.add_theme_constant_override("h_separation", 8)
	seat_row.add_theme_constant_override("v_separation", 8)
	body.add_child(seat_row)
	var assigned_ids: Array[String] = []
	for worker_id in GameState.assigned_catnip_worker_ids:
		assigned_ids.append(str(worker_id))
	for seat_index in catnip_slots:
		var seat_id := assigned_ids[seat_index] if seat_index < assigned_ids.size() else ""
		seat_row.add_child(_portrait_card(seat_id, true, catnip_slots))

	body.add_child(_label("대기 주민 · 눌러서 좌석에 앉히기", 13, Color("#94aa98")))
	if GameState.resident_cat_ids.is_empty():
		body.add_child(_empty_resident_state(
			"구출한 주민이 없습니다.",
			"캣닢 생산에 배치할 주민을 도시에서 구출하세요.",
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
				continue
			bench.add_child(_portrait_card(resident_id, false, catnip_slots))

	_rebuild_actions()


func _rebuild_actions() -> void:
	# 고정 하단 바 — 목록이 길어도 확장·농축은 늘 첫 화면에 남는다.
	if not is_instance_valid(action_bar):
		return
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	var narrow := get_viewport().get_visible_rect().size.x < 760.0
	# 좁은 화면에서 한 줄에 몰아넣으면 줄 최소 폭이 패널을 화면 밖으로 민다.
	var actions: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	actions.name = "CatnipScraperActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	action_bar.add_child(actions)
	var upgrade_cost := int(GameState.CATNIP_SCRAPER_UPGRADE_COSTS.get(GameState.catnip_scraper_level + 1, 0))
	var upgrade := _button(
		"최고 레벨"
		if upgrade_cost == 0 else "고철 x%s · Lv.%d 확장(좌석+1)" % [
			GameState.format_compact_number(upgrade_cost),
			GameState.catnip_scraper_level + 1,
		],
		"upgrade" if upgrade_cost == 0 else "scrap"
	)
	_stretch_action(upgrade)
	upgrade.disabled = upgrade_cost == 0 or GameState.scrap < upgrade_cost
	upgrade.pressed.connect(_upgrade)
	actions.add_child(upgrade)
	# 농축: 캣닢을 다시 캣닢 생산에 넣는 복리 사다리.
	var infusion_cost := GameState.get_infusion_cost()
	var infusion := _button(
		"농축 Lv.%d · 캣닢 %s → 생산 +8%%" % [
			GameState.catnip_infusion_level,
			GameState.format_compact_number(infusion_cost),
		],
		"catnip"
	)
	infusion.disabled = GameState.catnip < infusion_cost
	_stretch_action(infusion)
	infusion.pressed.connect(_upgrade_infusion)
	actions.add_child(infusion)
	var remaining: int = GameState.get_catnip_boost_remaining()
	# 안내 문구는 버튼 줄과 나란히 두면 폭을 잡아먹는다 — 아래 한 줄로 내린다.
	var boost_note := _label(
		"부스터 가동 중  %02d:%02d" % [remaining / 60, remaining % 60]
		if remaining > 0
		else "캣닢 %s = 생산 x10 부스터 (꾹꾹이 생산기에서 가동)" % GameState.format_compact_number(GameState.get_catnip_boost_cost()),
		12,
		Color("#cde79e")
	)
	boost_note.name = "CatnipBoostNote"
	boost_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_bar.add_child(boost_note)

	# 실패 사유를 적는 자리. 버튼이 고장 난 게 아니라 조건이 모자란 것이라고 말해 준다.
	feedback_label = _label("", 12, Color("#e6c779"))
	feedback_label.name = "CatnipScraperFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_bar.add_child(feedback_label)
	if not pending_feedback.is_empty():
		_apply_feedback_style(pending_feedback, pending_feedback_ok)


func _stretch_action(button: Button) -> void:
	# 긴 문구를 한 줄로 고집하면 버튼 최소 폭이 패널 폭을 넘긴다 — 줄바꿈으로
	# 폭 대신 높이를 쓴다.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _fit_chip_text(chip: PanelContainer, resource_id: String) -> PanelContainer:
	# 자원 칩 이름 라벨은 ELLIPSIS라 최소 폭이 1px이다 — 옆의 수치 라벨이
	# EXPAND_FILL로 남는 폭을 다 먹으면 이름이 통째로 사라진다(실측 폭 1px).
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


func _portrait_card(resident_id: String, is_seat: bool, slots: int) -> Button:
	# 초상화가 주인공인 세로 카드. 꾹꾹이 생산기와 같은 문법 — 배우면 어디서든 통한다.
	var button := Button.new()
	button.custom_minimum_size = Vector2(104, 128)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var bg := Color(0.03, 0.045, 0.034, 0.96)
	if resident_id.is_empty():
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
	var busy_elsewhere := not is_seat and GameState.assigned_worker_ids.has(resident_id)
	var seats_free := GameState.assigned_catnip_worker_ids.size() < slots
	button.name = "ResidentCard_%s" % resident_id
	button.icon = RESIDENT_PORTRAITS.get_portrait(int(trait_data.get("portrait_index", 0)))
	var border := Color("#7fc779") if is_seat else (
		Color("#5b789c") if busy_elsewhere else (Color("#c9ac5e") if seats_free else Color("#343a35"))
	)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.08), border.lightened(0.15)))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.05), Color("#cef08b")))
	button.add_theme_stylebox_override("disabled", _panel_style(bg.darkened(0.08), border.darkened(0.2)))
	if is_seat:
		button.text = "%s\n캣닢 x%.2f" % [display_name, float(trait_data.get("catnip", 1.0))]
	elif busy_elsewhere:
		button.text = "%s\n꾹꾹이 작업 중" % display_name
		button.disabled = true
	else:
		button.text = "%s\n캣닢 x%.2f" % [display_name, float(trait_data.get("catnip", 1.0))]
		button.disabled = not seats_free
	if not button.disabled:
		button.pressed.connect(func(): _toggle_worker(resident_id))
	button.tooltip_text = "%s · %s\n꾹꾹이 x%.2f · 캣닢 x%.2f · 식비 x%.2f\n%s" % [
		display_name,
		str(trait_data.get("name", "")),
		float(trait_data.get("kneading", 1.0)),
		float(trait_data.get("catnip", 1.0)),
		float(trait_data.get("appetite", 1.0)),
		"좌클릭: 좌석에서 일으키기" if is_seat else "좌클릭: 좌석에 앉히기",
	]
	return button


func _toggle_worker(resident_id: String) -> void:
	GameState.toggle_catnip_worker_assignment(resident_id)
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_rebuild_ui()


func _upgrade() -> void:
	# GameState는 성공 여부만 돌려준다 — 사유는 같은 조건을 모듈에서 다시 읽어 만든다.
	var next_level: int = GameState.catnip_scraper_level + 1
	var cost := int(GameState.CATNIP_SCRAPER_UPGRADE_COSTS.get(next_level, 0))
	if cost <= 0:
		_set_feedback("이미 최고 레벨입니다.", false)
		return
	if GameState.scrap < cost:
		_set_feedback(
			"고철이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.scrap),
			false
		)
		return
	if not GameState.try_upgrade_catnip_scraper():
		_set_feedback("확장 조건을 만족하지 못했습니다.", false)
		return
	GameState.save_persistent_state()
	_set_feedback("Lv.%d 확장 완료 · 작업 좌석 +1" % GameState.catnip_scraper_level, true)
	_rebuild_ui()


func _upgrade_infusion() -> void:
	var cost := GameState.get_infusion_cost()
	if GameState.catnip < cost:
		_set_feedback(
			"캣닢이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.catnip),
			false
		)
		return
	if not GameState.try_upgrade_catnip_infusion():
		_set_feedback("농축 조건을 만족하지 못했습니다.", false)
		return
	_set_feedback("농축 Lv.%d · 캣닢 생산 +8%%" % GameState.catnip_infusion_level, true)
	_rebuild_ui()


func _set_feedback(message: String, success: bool) -> void:
	# 문구는 UI 재생성 뒤에도 남아야 한다 — pending에 보관하고 라벨에도 즉시 반영.
	pending_feedback = message
	pending_feedback_ok = success
	_apply_feedback_style(message, success)


func _apply_feedback_style(message: String, success: bool) -> void:
	if not is_instance_valid(feedback_label):
		return
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color",
		Color("#9de0b1") if success else Color("#f09a8a")
	)


func _button(text: String, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, HudStyle.TEXT)
		# 대형 재화 PNG가 버튼 전체로 부풀지 않게 폭을 못 박는다.
		button.add_theme_constant_override("icon_max_width", 26)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return HudStyle.style_button(button, HudStyle.LINE_FOCUS)


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce8df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _empty_resident_state(title: String, description: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CatnipEmptyState"
	panel.custom_minimum_size = Vector2(0, 138 if compact else 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.027, 0.019, 0.78), Color("#314939")))
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
	icon.texture = UI_ICONS.get_icon("resident", 48, Color("#67806d"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var title_label := _label(title, 14, Color("#b5c6b8"))
	title_label.name = "EmptyStateTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var description_label := _label(description, 11, Color("#708575"))
	description_label.name = "EmptyStateDescription"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(description_label)
	return panel


func _summary_card(title: String, value: String, icon_name: String, compact: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 52 if compact else 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.043, 0.032, 0.92), Color("#425a49")))
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
	icon.texture = UI_ICONS.get_icon(icon_name, 36, Color("#9ec99b"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)
	var title_label := _label(title, 10 if compact else 11, Color("#87998c"))
	var value_label := _label(value, 13 if compact else 15, Color("#e0e9df"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ELLIPSIS 라벨의 최소 폭은 1px — 최소 폭을 안 주면 좁아질 때 글자가 사라진다.
	title_label.custom_minimum_size.x = 48.0
	value_label.custom_minimum_size.x = 62.0
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
