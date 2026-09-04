class_name ScratcherBankModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const SHELTER_THEME := preload("res://scripts/hud/shelter_theme.gd")
const RESIDENT_PORTRAITS := preload("res://scripts/resident_portrait_catalog.gd")

@export var interaction_radius := 4.0

# 좌석이 400칸, 대기 주민이 900명이면 카드를 그 수만큼 만드는 순간 모달이 멈춘다.
# 앞에서부터 이만큼만 그리고 나머지는 요약 카드 한 장이 대신한다.
const SEAT_CARD_RENDER_LIMIT := 36
const BENCH_CARD_RENDER_LIMIT := 36
# 좌석·대기 카드 한 장의 크기. 초상화(72px)가 주인공이고 아래 두 줄이 붙는다.
const PORTRAIT_CARD_SIZE := Vector2(108, 140)

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
	# 쉘터 공용 디자인 언어(ShelterTheme) — 딤 + 거의 검정 둥근 판, 보더 없음.
	var dim := SHELTER_THEME.dim_backdrop()
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
	var short_screen := viewport_size.y < 640.0
	var outer_margin := 10 if short_screen else 22
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
	var panel_height := minf(640.0, maxf(320.0, available_size.y - outer_margin * 2.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	# 판 자체가 안쪽 여백을 가진다(modal_style의 content margin). 낮은 화면에선 줄인다.
	var panel_style := SHELTER_THEME.modal_style()
	if short_screen or panel_width < 420.0:
		panel_style.content_margin_left = 16.0
		panel_style.content_margin_right = 16.0
		panel_style.content_margin_top = 14.0
		panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	# 모달 표준 등장 — 툭 나타나지 않는다.
	SHELTER_THEME.enter(panel)
	# 목록만 스크롤하고 액션 줄은 바닥에 고정하기 위한 2단 껍데기.
	var shell := VBoxContainer.new()
	shell.name = "ScratcherBankShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 12)
	panel.add_child(shell)
	var panel_scroll := SHELTER_THEME.scroll()
	panel_scroll.name = "ScratcherBankScroll"
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(panel_scroll)
	# 스크롤 바가 카드 오른쪽 모서리에 붙지 않게 숨 쉴 틈을 준다.
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", 10)
	panel_scroll.add_child(content_margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 내용 쪽에서 최소 폭을 못 박으면 그 값이 스크롤·패널로 거꾸로 전파돼
	# 패널을 화면 밖으로 밀어낸다. 폭은 패널이 정하고 내용은 따라간다.
	content.custom_minimum_size.x = 0.0
	content.add_theme_constant_override("separation", 12 if short_screen else 18)
	content_margin.add_child(content)
	action_bar = VBoxContainer.new()
	action_bar.name = "ScratcherBankActionBar"
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	action_bar.add_theme_constant_override("separation", 8)
	shell.add_child(action_bar)
	_rebuild_ui()


func _rebuild_ui() -> void:
	GameState._ensure_resident_records()
	for child in content.get_children():
		child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 1040.0 or viewport_size.y < 680.0
	var header := VBoxContainer.new()
	header.name = "ScratcherBankHeader"
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	# [생산기 / 꾹꾹이 고철 생산기 [Lv.N] / 설명]  ······  [둥근 닫기]
	header.add_child(_modal_header(
		"꾹꾹이 고철 생산기",
		"주민을 배치하면 고철이 자동 생산됩니다.",
		"Lv.%d" % GameState.scratcher_bank_level
	))
	var wallet := HFlowContainer.new()
	wallet.name = "ScratcherBankWallet"
	wallet.add_theme_constant_override("h_separation", 8)
	wallet.add_theme_constant_override("v_separation", 6)
	header.add_child(wallet)
	# 지갑 칩은 아이콘 + 수치만(이름은 툴팁) — 재화 표기 규칙.
	# 캣닢 칩은 뺐다 — 이 모달에 캣닢을 쓰는 기능이 더는 없다(피버 전용).
	wallet.add_child(_wallet_chip("scrap", GameState.format_compact_number(GameState.scrap)))
	var workers: int = GameState.get_active_scratcher_workers()
	var slots: int = GameState.get_scratcher_worker_slots()
	var summary := GridContainer.new()
	summary.name = "ScratcherBankSummary"
	# 세로 720px에서도 요약 카드는 한 줄에 둔다 — 세로로 쌓으면 좌석이 액션 바 밑으로 밀린다.
	summary.columns = 1 if viewport_size.x < 520.0 else 3
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("h_separation", 10)
	summary.add_theme_constant_override("v_separation", 10)
	content.add_child(summary)
	summary.add_child(_summary_card("시간당", GameState.format_compact_number(GameState.get_scrap_per_hour()), "scrap", compact))
	summary.add_child(_summary_card("작업자", "%d / %d명" % [workers, slots], "resident", compact))
	# 세 번째 칸은 오버클럭 누적 배율 — 부스터가 사라진 자리에서 "사다리를 오르면
	# 이 숫자가 큰다"를 보여 준다.
	summary.add_child(_summary_card(
		"오버클럭",
		"+%d%%" % (GameState.scratcher_overclock_level * 8),
		"upgrade",
		compact
	))

	# ── 좌석 + 벤치 구조 ─────────────────────────────────────────
	# "기계에 고양이를 앉힌다"가 한눈에 읽히게: 위에는 기계의 작업 좌석(슬롯 수만큼,
	# 앉은 고양이 초상화), 아래에는 대기 주민 벤치. 벤치의 고양이를 누르면 좌석에
	# 앉고, 좌석의 고양이를 누르면 일어난다. 두 열 텍스트 카드보다 훨씬 직관적이다.
	var body := VBoxContainer.new()
	body.name = "ScratcherBankBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)

	body.add_child(_seat_header(
		"작업 좌석",
		SHELTER_THEME.TEXT,
		_assign_all_workers,
		_clear_all_workers
	))
	# 좌석 목록도 스크롤 안에 산다 — 좌석이 400칸이면 벤치를 화면 밖으로 밀어낸다.
	var seat_scroll := SHELTER_THEME.scroll()
	seat_scroll.name = "ScratcherSeatScroll"
	seat_scroll.custom_minimum_size = Vector2(0, 150)
	seat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(seat_scroll)
	var seat_row := HFlowContainer.new()
	seat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_row.add_theme_constant_override("h_separation", 10)
	seat_row.add_theme_constant_override("v_separation", 10)
	seat_scroll.add_child(seat_row)
	var assigned_ids: Array[String] = []
	var assigned_set: Dictionary = {}
	for worker_id in GameState.assigned_worker_ids:
		assigned_ids.append(str(worker_id))
		assigned_set[str(worker_id)] = true
	var rendered_seats := mini(slots, SEAT_CARD_RENDER_LIMIT)
	for seat_index in rendered_seats:
		var seat_id := assigned_ids[seat_index] if seat_index < assigned_ids.size() else ""
		seat_row.add_child(_portrait_card(seat_id, true, slots))
	if slots > rendered_seats:
		seat_row.add_child(_overflow_card(
			"그 외 %d석" % (slots - rendered_seats),
			"앉은 고양이 %s" % GameState.format_compact_number(
				maxi(0, assigned_ids.size() - rendered_seats)
			)
		))

	var bench_hint := SHELTER_THEME.caption(
		"눌러서 좌석에 앉히기"
		if DisplayServer.is_touchscreen_available()
		else "눌러서 앉히기 · 우클릭 특성 재굴림"
	)
	body.add_child(SHELTER_THEME.section_header("대기 주민", bench_hint))
	if GameState.resident_cat_ids.is_empty():
		body.add_child(_empty_resident_state(
			"구출한 주민이 없습니다.",
			"도시에서 구출해 오거나, 시간이 지나면 소문을 듣고 찾아옵니다.",
			compact
		))
	else:
		var bench_scroll := SHELTER_THEME.scroll()
		bench_scroll.custom_minimum_size = Vector2(0, 150)
		bench_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(bench_scroll)
		var bench := HFlowContainer.new()
		bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench.add_theme_constant_override("h_separation", 10)
		bench.add_theme_constant_override("v_separation", 10)
		bench_scroll.add_child(bench)
		var bench_shown := 0
		var bench_hidden := 0
		for resident_variant in GameState.resident_cat_ids:
			var resident_id := str(resident_variant)
			if assigned_set.has(resident_id):
				continue  # 이미 좌석에 앉아 있다.
			if bench_shown >= BENCH_CARD_RENDER_LIMIT:
				bench_hidden += 1
				continue
			bench.add_child(_portrait_card(resident_id, false, slots))
			bench_shown += 1
		if bench_hidden > 0:
			bench.add_child(_overflow_card(
				"그 외 %s명" % GameState.format_compact_number(bench_hidden),
				"전원 배치로 한 번에"
			))

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
	actions.add_theme_constant_override("separation", 10)
	action_bar.add_child(actions)
	# 인크리멘탈 사다리 두 개만 남긴다 — 캣닢 부스터는 바깥 캣닢 피버가 그 역할이라
	# 뺐고(유저 지시), 비용은 전부 고철 재투자다. "무엇이 얼마나 좋아지는가"를
	# 버튼이 직접 말한다. 주 버튼(민트) = 확장, 보조(표면색) = 오버클럭.
	var upgrade_cost := int(GameState.SCRATCHER_UPGRADE_COSTS.get(GameState.scratcher_bank_level + 1, 0))
	var upgrade := Button.new()
	upgrade.text = (
		"최고 레벨"
		if upgrade_cost == 0 else "좌석 +1 확장\n고철 %s · 생산 ×1.9" % (
			GameState.format_compact_number(upgrade_cost)
		)
	)
	SHELTER_THEME.style_primary(upgrade)
	upgrade.tooltip_text = "확장 Lv.%d → Lv.%d" % [
		GameState.scratcher_bank_level, GameState.scratcher_bank_level + 1,
	]
	upgrade.disabled = upgrade_cost == 0 or GameState.scrap < upgrade_cost
	_stretch_action(upgrade)
	upgrade.pressed.connect(_upgrade)
	actions.add_child(upgrade)
	# 오버클럭: 고철을 다시 생산에 넣는 복리 사다리. "항상 다음에 살 것"을 만든다.
	var overclock_cost := GameState.get_overclock_cost()
	var overclock := Button.new()
	overclock.text = "오버클럭 Lv.%d\n고철 %s · 시간당 +8%%" % [
		GameState.scratcher_overclock_level + 1,
		GameState.format_compact_number(overclock_cost),
	]
	SHELTER_THEME.style_secondary(overclock)
	overclock.tooltip_text = "오버클럭 Lv.%d → Lv.%d" % [
		GameState.scratcher_overclock_level, GameState.scratcher_overclock_level + 1,
	]
	overclock.disabled = GameState.scrap < overclock_cost
	_stretch_action(overclock)
	overclock.pressed.connect(_upgrade_overclock)
	actions.add_child(overclock)

	# 실패 사유를 적는 자리. 버튼이 고장 난 게 아니라 조건이 모자란 것이라고 말해 준다.
	feedback_label = SHELTER_THEME.caption("", SHELTER_THEME.TEXT_DIM)
	feedback_label.name = "ScratcherBankFeedback"
	feedback_label.custom_minimum_size.y = 20
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_bar.add_child(feedback_label)
	if not pending_feedback.is_empty():
		_apply_feedback_style(pending_feedback, pending_feedback_ok)


func _stretch_action(button: Button) -> void:
	# 두 줄 문구(굵은 행동 + 비용 줄)를 담는 큰 버튼. 한 줄로 고집하면 버튼 최소 폭이
	# 패널 폭을 넘긴다 — 줄바꿈을 허용해 폭 대신 높이를 쓴다.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _modal_header(title_text: String, subtitle_text: String, level_text: String) -> HBoxContainer:
	# ShelterTheme.modal_header 규격에 레벨 알약 칩을 제목 옆에 얹은 것.
	var header := SHELTER_THEME.modal_header(title_text, subtitle_text, Callable(), "생산기")
	var close := header.get_meta("close_button") as Button
	close.name = "CloseButton"
	# 글자 × 대신 아이콘 — 특수기호 금지 규칙, 그리고 닫기는 아이콘 하나로 충분하다.
	close.text = ""
	close.icon = UI_ICONS.get_icon("close", 22, SHELTER_THEME.TEXT)
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.expand_icon = false
	close.add_theme_constant_override("icon_max_width", 18)
	close.tooltip_text = "닫기"
	close.pressed.connect(func() -> void:
		if is_instance_valid(ui_layer):
			ui_layer.queue_free()
	)
	var column := header.get_child(0) as VBoxContainer
	var title_label := column.get_child(1) as Label
	column.remove_child(title_label)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	# 제목이 줄바꿈으로 폭을 밀어 올리지 않게 — 자기 글자 폭만큼만 차지하고, 아주
	# 좁은 화면에서만 말줄임. (ELLIPSIS 라벨의 최소 폭은 1px이라 폭을 못 박아야 한다.)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var title_font := title_label.get_theme_font("font")
	var title_width := ceilf(title_font.get_string_size(
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_label.get_theme_font_size("font_size")
	).x) + 4.0
	var title_room := maxf(140.0, get_viewport().get_visible_rect().size.x - 320.0)
	title_label.custom_minimum_size.x = minf(title_width, title_room)
	title_row.add_child(title_label)
	var level_chip := SHELTER_THEME.chip(level_text, null, SHELTER_THEME.ACCENT, true)
	level_chip.name = "LevelChip"
	level_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(level_chip)
	column.add_child(title_row)
	column.move_child(title_row, 1)
	return header


func _wallet_chip(currency_id: String, value_text: String) -> PanelContainer:
	# 알약 칩: 재화 아이콘 + 수치. 이름은 툴팁. 테스트·튜토리얼이 찾는
	# ResourceIcon_/ResourceValue_ 이름 규약은 그대로 지킨다.
	var chip := SHELTER_THEME.chip(
		value_text,
		UI_ICONS.get_icon(currency_id, 42, SHELTER_UI.get_currency_color(currency_id)),
		SHELTER_THEME.TEXT
	)
	chip.name = "ResourceChip_%s" % currency_id
	chip.tooltip_text = str(SHELTER_UI.CURRENCY_NAMES.get(currency_id, currency_id))
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	for node in chip.find_children("*", "TextureRect", true, false):
		node.name = "ResourceIcon_%s" % currency_id
	var value_label := chip.get_meta("label") as Label
	if value_label != null:
		value_label.name = "ResourceValue_%s" % currency_id
	return chip


func _portrait_card(resident_id: String, is_seat: bool, slots: int) -> Button:
	# 초상화가 주인공인 세로 카드. 좌석(위)과 벤치(아래)가 같은 카드를 쓰므로
	# "고양이를 옮겨 앉힌다"는 감각이 유지된다. 좌석 카드는 민트 테두리, 벤치 카드는
	# 한 단계 밝은 표면 — 보더 색으로 상태를 말하던 옛 문법은 버린다.
	var button := Button.new()
	button.custom_minimum_size = PORTRAIT_CARD_SIZE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_CAPTION)
	button.add_theme_color_override("font_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_hover_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_pressed_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_focus_color", SHELTER_THEME.TEXT)
	button.add_theme_color_override("font_disabled_color", SHELTER_THEME.TEXT_FAINT)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.focus_mode = Control.FOCUS_NONE
	if resident_id.is_empty():
		# 빈 좌석: 실루엣 + 흐린 글자. 여기 앉힐 수 있다는 자리 표시.
		button.name = "SeatEmpty"
		button.icon = UI_ICONS.get_icon("resident", 56, SHELTER_THEME.TEXT_FAINT)
		button.text = "빈 좌석"
		button.disabled = true
		_apply_card_styles(button, false, false)
		return button
	var trait_data: Dictionary = GameState.get_resident_trait(resident_id)
	var display_name := str(trait_data.get("display_name", "이름 없는 주민"))
	var busy_elsewhere := not is_seat and GameState.assigned_catnip_worker_ids.has(resident_id)
	var seats_free := GameState.assigned_worker_ids.size() < slots
	button.name = "ResidentCard_%s" % resident_id
	button.icon = RESIDENT_PORTRAITS.get_portrait(int(trait_data.get("portrait_index", 0)))
	_apply_card_styles(button, not is_seat, is_seat)
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
	var quirk_line: String = GameState.get_resident_trait_quirk(resident_id)
	button.tooltip_text = "%s · %s\n꾹꾹이 x%.2f · 캣닢 x%.2f%s\n%s\n우클릭: 특성 재굴림 · 츄르 %s" % [
		display_name,
		str(trait_data.get("name", "")),
		float(trait_data.get("kneading", 1.0)),
		float(trait_data.get("catnip", 1.0)),
		"" if quirk_line.is_empty() else "\n" + quirk_line,
		"좌클릭: 좌석에서 일으키기" if is_seat else "좌클릭: 좌석에 앉히기",
		GameState.format_compact_number(GameState.get_resident_reroll_cost(resident_id)),
	]
	return button


func _apply_card_styles(button: Button, raised: bool, accent_border: bool) -> void:
	# 카드 버튼의 네 상태를 ShelterTheme 카드 스타일로. 초상화가 카드 폭을 꽉 채우게
	# 안쪽 여백은 카드 기본보다 조금 좁힌다.
	var normal := SHELTER_THEME.card_style(raised, accent_border)
	var hover := SHELTER_THEME.card_style(raised, accent_border)
	hover.bg_color = SHELTER_THEME.SURFACE_HOVER
	var pressed := SHELTER_THEME.card_style(raised, accent_border)
	pressed.bg_color = SHELTER_THEME.SURFACE
	if accent_border:
		pressed.border_color = SHELTER_THEME.ACCENT
	var disabled := SHELTER_THEME.card_style(raised, false)
	disabled.bg_color = Color(disabled.bg_color, 0.6)
	for style in [normal, hover, pressed, disabled]:
		(style as StyleBoxFlat).content_margin_left = 10.0
		(style as StyleBoxFlat).content_margin_right = 10.0
		(style as StyleBoxFlat).content_margin_top = 12.0
		(style as StyleBoxFlat).content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", disabled)


func _seat_header(title: String, _color: Color, assign_all: Callable, clear_all: Callable) -> Control:
	# 제목 줄 오른쪽에 일괄 배치·해제. 좌석이 400칸이면 한 장씩 누르게 두는 건
	# UI가 아니라 벌이다.
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 6)
	var assign_button := SHELTER_THEME.secondary_button("전원 배치", true)
	assign_button.name = "AssignAllButton"
	assign_button.custom_minimum_size.x = 84.0
	assign_button.pressed.connect(assign_all)
	trailing.add_child(assign_button)
	var clear_button := SHELTER_THEME.secondary_button("전원 해제", true)
	clear_button.name = "ClearAllButton"
	clear_button.custom_minimum_size.x = 84.0
	clear_button.pressed.connect(clear_all)
	trailing.add_child(clear_button)
	var row := SHELTER_THEME.section_header(title, trailing)
	row.name = "SeatHeaderRow"
	return row


func _overflow_card(title: String, subtitle: String) -> Control:
	# 카드를 다 그리지 않았다는 사실을 숨기지 않는다 — "그 외 N석"이 그 자리를 지킨다.
	var panel := SHELTER_THEME.card()
	panel.name = "SeatOverflowCard"
	panel.custom_minimum_size = PORTRAIT_CARD_SIZE
	var center := CenterContainer.new()
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	center.add_child(box)
	var title_label := SHELTER_THEME.label(title, SHELTER_THEME.TYPE_BODY, SHELTER_THEME.TEXT, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var subtitle_label := SHELTER_THEME.caption(subtitle)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(subtitle_label)
	return panel


func _assign_all_workers() -> void:
	var added: int = GameState.assign_all_workers_to_scratcher()
	if added <= 0:
		_set_feedback("좌석에 앉힐 대기 주민이 없습니다.", false)
		return
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_set_feedback("주민 %s명을 좌석에 앉혔습니다." % GameState.format_compact_number(added), true)
	_rebuild_ui()


func _clear_all_workers() -> void:
	var removed: int = GameState.unassign_all_workers_from_scratcher()
	if removed <= 0:
		_set_feedback("좌석에 앉아 있는 주민이 없습니다.", false)
		return
	GameState.save_persistent_state()
	get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", false)
	_set_feedback("주민 %s명을 좌석에서 일으켰습니다." % GameState.format_compact_number(removed), true)
	_rebuild_ui()


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
	# 비용은 고철 단독(캣닢은 피버 전용으로 이관, 2026-08-28).
	var next_level: int = GameState.scratcher_bank_level + 1
	var cost := int(GameState.SCRATCHER_UPGRADE_COSTS.get(next_level, 0))
	if cost <= 0:
		_set_feedback("이미 최고 레벨입니다.", false)
		return
	if GameState.scrap < cost:
		_set_feedback(
			"고철이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.scrap),
			false
		)
		return
	if not GameState.try_upgrade_scratcher_bank():
		_set_feedback("확장 조건을 만족하지 못했습니다.", false)
		return
	GameState.save_persistent_state()
	_set_feedback("Lv.%d 확장 완료 · 작업 좌석 +1" % GameState.scratcher_bank_level, true)
	_rebuild_ui()


func _upgrade_overclock() -> void:
	var cost := GameState.get_overclock_cost()
	if GameState.scrap < cost:
		_set_feedback(
			"고철이 %s 부족합니다." % GameState.format_compact_number(cost - GameState.scrap),
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
		SHELTER_THEME.ACCENT if success else SHELTER_THEME.DANGER
	)


func _button(text: String, icon_name := "") -> Button:
	# 보조 버튼(표면색 채움). 아이콘은 왼쪽에 작게.
	var button := SHELTER_THEME.secondary_button(text)
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, SHELTER_THEME.TEXT)
		# 재화 아이콘(고철·캣닢)은 대형 생성 PNG다. 폭 상한을 안 걸면
		# 세로 여백이 남는 순간 아이콘이 버튼 전체로 부풀어 레이아웃이
		# 무너진다(모바일 세로에서 실제 발생). 상한을 못 박는다.
		button.add_theme_constant_override("icon_max_width", 26)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = false
	return button


func _close_button() -> Button:
	var button := SHELTER_THEME.close_button()
	button.name = "CloseButton"
	button.text = ""
	button.icon = UI_ICONS.get_icon("close", 22, SHELTER_THEME.TEXT)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 18)
	button.tooltip_text = "닫기"
	return button


func _empty_resident_state(title: String, description: String, compact: bool) -> Control:
	var panel := SHELTER_THEME.card()
	panel.name = "ScratcherEmptyState"
	panel.custom_minimum_size = Vector2(0, 138 if compact else 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	icon.texture = UI_ICONS.get_icon("resident", 48, SHELTER_THEME.TEXT_FAINT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title_label := SHELTER_THEME.label(title, SHELTER_THEME.TYPE_BODY, SHELTER_THEME.TEXT, true)
	title_label.name = "EmptyStateTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var description_label := SHELTER_THEME.caption(description)
	description_label.name = "EmptyStateDescription"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(description_label)
	return panel


func _summary_card(title: String, value: String, icon_name: String, compact: bool) -> Control:
	# 작은 설명 + 큰 굵은 숫자, 보더 없음. 재화 색은 아이콘에만.
	var icon_color := SHELTER_THEME.TEXT_DIM
	if SHELTER_UI.CURRENCY_COLORS.has(icon_name):
		icon_color = SHELTER_UI.get_currency_color(icon_name)
	var panel := SHELTER_THEME.stat_card(title, value, UI_ICONS.get_icon(icon_name, 36, icon_color))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := panel.get_meta("value_label") as Label
	if value_label != null:
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# ELLIPSIS 라벨의 최소 폭은 1px이다 — 최소 폭을 안 주면 칸이 좁아질 때
		# 글자가 통째로 사라진다.
		value_label.custom_minimum_size.x = 62.0
		if compact:
			value_label.add_theme_font_size_override("font_size", SHELTER_THEME.TYPE_NUMBER_SMALL - 2)
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := SHELTER_THEME.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
