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
# 확장·오버클럭·부스터는 스크롤 밖 고정 바에 산다 — 스크롤 아래에 숨으면
# 유저는 "확장 기능이 없다"고 읽는다(세로 실측 150px 초과).
var action_bar: VBoxContainer
# 창고 모듈과 같은 피드백 문법. _rebuild_ui()가 라벨을 새로 만들기 때문에
# 마지막 문구를 따로 들고 있다가 재생성 뒤 다시 붙인다.
var feedback_label: Label
var pending_feedback := ""
var pending_feedback_ok := false


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("scratcher_bank")
	set_meta("module_kind", "scratcher_bank")


func get_interaction_prompt() -> String:
	return "꾹꾹이 생산기 · 주민 배치로 고철 생산"


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
	# 새로 열 때는 지난 세션의 문구를 끌고 오지 않는다.
	pending_feedback = ""
	pending_feedback_ok = false
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
	panel.name = "ScratcherBankPanel"
	# 세로 화면에서 실제로 쓸 수 있는 폭. 내부 위젯이 이 값을 넘겨 최소 폭을 밀어
	# 올리면 패널이 통째로 화면 밖으로 나간다(실측 720 화면에 910px 패널 →
	# 닫기·오버클럭 버튼이 화면 밖). 내부는 이 폭 안에서만 논다.
	var panel_width := minf(960.0, maxf(260.0, available_size.x - outer_margin * 2.0))
	var panel_height := minf(620.0, maxf(320.0, available_size.y - outer_margin * 2.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
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
	# 목록만 스크롤하고 액션 줄은 바닥에 고정하기 위한 2단 껍데기.
	var shell := VBoxContainer.new()
	shell.name = "ScratcherBankShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)
	var panel_scroll := HudStyle.make_scroll()
	panel_scroll.name = "ScratcherBankScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(panel_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 내용 쪽에서 최소 폭을 못 박으면 그 값이 스크롤·패널로 거꾸로 전파돼
	# 패널을 화면 밖으로 밀어낸다. 폭은 패널이 정하고 내용은 따라간다.
	content.custom_minimum_size.x = 0.0
	content.add_theme_constant_override("separation", 10 if viewport_size.y < 640.0 else 16)
	panel_scroll.add_child(content)
	action_bar = VBoxContainer.new()
	action_bar.name = "ScratcherBankActionBar"
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
	wallet.add_child(_fit_chip_text(SHELTER_UI.make_currency_chip(
		"scrap",
		GameState.format_compact_number(GameState.scrap),
		compact,
		not narrow
	), "scrap"))
	wallet.add_child(_fit_chip_text(SHELTER_UI.make_currency_chip(
		"catnip",
		GameState.format_compact_number(GameState.catnip),
		compact,
		not narrow
	), "catnip"))
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

	body.add_child(_label(
		"대기 주민 · 눌러서 좌석에 앉히기"
		if DisplayServer.is_touchscreen_available()
		else "대기 주민 · 눌러서 좌석에 앉히기 (우클릭: 특성 재굴림)",
		13,
		Color("#9eaa9f")
	))
	if GameState.resident_cat_ids.is_empty():
		body.add_child(_empty_resident_state(
			"구출한 주민이 없습니다.",
			"도시에서 주민을 구출해 함께 탈출하면 배치할 수 있습니다.",
			compact
		))
	else:
		var bench_scroll := HudStyle.make_scroll()
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

	_rebuild_actions()


func _rebuild_actions() -> void:
	# 고정 하단 바 — 목록이 아무리 길어도 확장·오버클럭·부스터는 늘 보인다.
	if not is_instance_valid(action_bar):
		return
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 760.0
	# 좁은 화면에서 세 버튼을 한 줄에 밀어 넣으면 줄 전체 최소 폭이 패널을 밀어
	# 화면 밖으로 내보낸다. 세로에서는 쌓는다.
	var actions: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	actions.name = "ScratcherBankActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	action_bar.add_child(actions)
	var boost_remaining: int = GameState.get_catnip_boost_remaining()
	var boost := _button(
		"가동 중  %02d:%02d" % [boost_remaining / 60, boost_remaining % 60]
		if boost_remaining > 0
		else "캣닢 x%s · 10분 생산 x10" % GameState.format_compact_number(GameState.get_catnip_boost_cost()),
		"catnip"
	)
	boost.disabled = boost_remaining > 0 or GameState.catnip < GameState.get_catnip_boost_cost()
	_stretch_action(boost)
	boost.pressed.connect(_activate_boost)
	actions.add_child(boost)
	var upgrade_cost := int(GameState.SCRATCHER_UPGRADE_COSTS.get(GameState.scratcher_bank_level + 1, 0))
	var upgrade_catnip := int(
		GameState.SCRATCHER_UPGRADE_CATNIP_COSTS.get(GameState.scratcher_bank_level + 1, 0)
	)
	# 두 재화를 함께 보여 준다 — 고철만 보고 눌렀다 막히면 그건 UI의 잘못이다.
	var upgrade := _button(
		"최고 레벨"
		if upgrade_cost == 0 else "고철 x%s · 캣닢 x%s · Lv.%d 확장(좌석+1)" % [
			GameState.format_compact_number(upgrade_cost),
			GameState.format_compact_number(upgrade_catnip),
			GameState.scratcher_bank_level + 1,
		],
		"upgrade" if upgrade_cost == 0 else "scrap"
	)
	upgrade.disabled = (
		upgrade_cost == 0
		or GameState.scrap < upgrade_cost
		or GameState.catnip < upgrade_catnip
	)
	_stretch_action(upgrade)
	upgrade.pressed.connect(_upgrade)
	actions.add_child(upgrade)
	# 오버클럭: 고철을 다시 생산에 넣는 복리 사다리. "항상 다음에 살 것"을 만든다.
	var overclock_cost := GameState.get_overclock_cost()
	var overclock_catnip := GameState.get_overclock_catnip_cost()
	var overclock := _button(
		"오버클럭 Lv.%d · 고철 %s + 캣닢 %s → 시간당 +8%%" % [
			GameState.scratcher_overclock_level,
			GameState.format_compact_number(overclock_cost),
			GameState.format_compact_number(overclock_catnip),
		],
		"upgrade"
	)
	overclock.disabled = (
		GameState.scrap < overclock_cost or GameState.catnip < overclock_catnip
	)
	_stretch_action(overclock)
	overclock.pressed.connect(_upgrade_overclock)
	actions.add_child(overclock)

	# 실패 사유를 적는 자리. 버튼이 고장 난 게 아니라 조건이 모자란 것이라고 말해 준다.
	feedback_label = _label("", 12, Color("#e6c779"))
	feedback_label.name = "ScratcherBankFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_bar.add_child(feedback_label)
	if not pending_feedback.is_empty():
		_apply_feedback_style(pending_feedback, pending_feedback_ok)


func _stretch_action(button: Button) -> void:
	# 긴 문구를 한 줄로 고집하면 버튼 최소 폭이 패널 폭을 넘긴다 — 줄바꿈을 허용해
	# 폭 대신 높이를 쓴다.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _fit_chip_text(chip: PanelContainer, resource_id: String) -> PanelContainer:
	# 자원 칩 이름 라벨은 ELLIPSIS라 최소 폭이 1px이다 — 옆의 수치 라벨이
	# EXPAND_FILL로 남는 폭을 다 먹으면 이름이 통째로 사라진다(실측 폭 1px).
	# 두 라벨 모두 실제 글자 폭을 최소 폭으로 못 박는다.
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
	button.tooltip_text = "%s · %s\n꾹꾹이 x%.2f · 캣닢 x%.2f\n%s\n우클릭: 특성 재굴림 · 츄르 %s" % [
		display_name,
		str(trait_data.get("name", "")),
		float(trait_data.get("kneading", 1.0)),
		float(trait_data.get("catnip", 1.0)),
		"좌클릭: 좌석에서 일으키기" if is_seat else "좌클릭: 좌석에 앉히기",
		GameState.format_compact_number(GameState.get_resident_reroll_cost(resident_id)),
	]
	return button


func _reroll_worker(resident_id: String) -> void:
	var result: Dictionary = GameState.try_reroll_resident_trait(resident_id)
	if bool(result.get("ok", false)):
		get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
		var rolled: Dictionary = result.get("trait", {}) as Dictionary
		_set_feedback("특성 재굴림 완료 · %s" % str(rolled.get("name", "새 특성")), true)
		_rebuild_ui()
		return
	# 재굴림은 우클릭이라 더더욱 조용히 실패하면 안 된다 — 눌린 줄도 모른다.
	match str(result.get("reason", "")):
		"churu":
			_set_feedback(
				"츄르가 %d개 부족합니다." % maxi(0, int(result.get("cost", 0)) - GameState.churu),
				false
			)
		"no_candidates":
			_set_feedback("바꿀 수 있는 다른 특성이 없습니다.", false)
		_:
			_set_feedback("이 주민은 재굴림할 수 없습니다.", false)


func _toggle_worker(resident_id: String) -> void:
	GameState.toggle_worker_assignment(resident_id)
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_rebuild_ui()


func _upgrade() -> void:
	# GameState는 성공 여부만 돌려준다 — 사유는 같은 조건을 모듈에서 다시 읽어 만든다.
	var next_level: int = GameState.scratcher_bank_level + 1
	var cost := int(GameState.SCRATCHER_UPGRADE_COSTS.get(next_level, 0))
	var catnip_cost := int(GameState.SCRATCHER_UPGRADE_CATNIP_COSTS.get(next_level, 0))
	if cost <= 0:
		_set_feedback("이미 최고 레벨입니다.", false)
		return
	if GameState.scrap < cost:
		_set_feedback(
			"고철이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.scrap),
			false
		)
		return
	if GameState.catnip < catnip_cost:
		_set_feedback(
			"캣닢이 %s 부족합니다." % GameState.format_compact_number(catnip_cost - GameState.catnip),
			false
		)
		return
	if not GameState.try_upgrade_scratcher_bank():
		_set_feedback("확장 조건을 만족하지 못했습니다.", false)
		return
	GameState.save_persistent_state()
	_set_feedback("Lv.%d 확장 완료 · 작업 좌석 +1" % GameState.scratcher_bank_level, true)
	_rebuild_ui()


func _activate_boost() -> void:
	if GameState.get_catnip_boost_remaining() > 0:
		_set_feedback("부스터가 이미 가동 중입니다.", false)
		return
	var cost := GameState.get_catnip_boost_cost()
	if GameState.catnip < cost:
		_set_feedback(
			"캣닢이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.catnip),
			false
		)
		return
	if not GameState.activate_catnip_boost():
		_set_feedback("부스터를 가동하지 못했습니다.", false)
		return
	GameState.save_persistent_state()
	_set_feedback("부스터 가동 · 10분간 생산 x10", true)
	_rebuild_ui()


func _upgrade_overclock() -> void:
	var cost := GameState.get_overclock_cost()
	var catnip_cost := GameState.get_overclock_catnip_cost()
	if GameState.scrap < cost:
		_set_feedback(
			"고철이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.scrap),
			false
		)
		return
	if GameState.catnip < catnip_cost:
		_set_feedback(
			"캣닢이 %s 부족합니다." % GameState.format_compact_number(catnip_cost - GameState.catnip),
			false
		)
		return
	if not GameState.try_upgrade_scratcher_overclock():
		_set_feedback("오버클럭 조건을 만족하지 못했습니다.", false)
		return
	_set_feedback("오버클럭 Lv.%d · 시간당 +8%%" % GameState.scratcher_overclock_level, true)
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
		button.expand_icon = true
		# 재화 아이콘(고철·캣닢)은 대형 생성 PNG다. 폭 상한을 안 걸면
		# 세로 여백이 남는 순간 아이콘이 버튼 전체로 부풀어 레이아웃이
		# 무너진다(모바일 세로에서 실제 발생). 상한을 못 박는다.
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
	# ELLIPSIS 라벨의 최소 폭은 1px이다 — 최소 폭을 안 주면 칸이 좁아질 때
	# 글자가 통째로 사라진다.
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
