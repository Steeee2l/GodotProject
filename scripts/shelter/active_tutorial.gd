class_name ActiveTutorial
extends RefCounted
## 액티브 튜토리얼 — 읽는 안내가 아니라 "가리키고 · 해보게 하고 · 행동하면 넘어가는" 안내.
##
## 토스트/레슨 카드(1회성 플래그 10개)는 전부 읽기만 하는 안내였다. 여기서는 스텝 표(STEPS)의
## 조건이 맞는 순간 대상 컨트롤에 골드 림 펄스 + 화살표 + 한 줄 지시 카드를 붙이고, 플레이어가
## 실제 행동(주민 앉히기·훈련 구매·제작·판매·피버 충전·통조림 투척·성장 선택…)을 하면 ✓ 뒤
## 다음 스텝으로 넘어간다. 건너뛰기는 그 스텝만 완료 처리한다.
##
## host 패턴: 쉘터(shelter_interior.gd)와 필드(main.gd)가 각각 한 인스턴스를 들고 attach →
## build(zones)만 부른다. 이후는 자체 Ticker 노드가 update(delta)를 돌린다(정산 화면처럼
## 트리가 멈춘 동안에도 움직여야 해서 host의 _process에 기대지 않는다).
##
## 2단계 타깃: 스텝의 targets는 체인이다(예: 독 버튼 → 모달 안 카드). 뒤쪽(깊은) 타깃이
## 화면에 있으면 그쪽을 가리키고, 없으면 앞쪽(독 버튼)을 가리킨다. 모달이 열려 있는데 타깃이
## 모달 밖이면 UI를 숨긴다 — 딤 아래를 가리키는 화살표는 거짓말이다.
##
## 저장: GameState.tutorial_steps_done(세이브/로드/리셋). 설정(AccessibilitySettings)의
## active_tutorial_enabled 토글과 "안내 다시 보기"(전부 리셋)가 이 시스템을 끄고 되돌린다.

const SHELTER_REQUISITION := preload("res://scripts/shelter/requisition.gd")

# 시설 모달(60~90)보다 위, 일시정지(96)·피버 연출(96)·주홍 시네마틱(92)보다 아래.
const LAYER_INDEX := 91
const POLL_INTERVAL := 0.25
# 5초 동안 반응이 없으면 카드는 제목 칩으로 줄이고 포인터만 남긴다(방해 금지).
const CARD_COLLAPSE_SECONDS := 5.0
const CARD_MAX_WIDTH := 300.0
const CARD_ENTER_SECONDS := 0.18
const CHECK_SECONDS := 0.4
const ARROW_SIZE := 26.0
const ARROW_GAP := 6.0
const ARROW_BOUNCE := 4.0
const EDGE_MARGIN := 8.0
const TOUCH_MIN := 44.0

# 스텝 표. 순서 = 우선순위. zone: shelter | field | extraction.
# targets는 얕은 것 → 깊은 것 순(독 버튼 → 모달 안 요소). 해석 규칙은 _resolve_target 참조.
# overlay: "briefing"이면 출정 브리핑(raid_zone_ui)이 떠 있어도 차단하지 않는다.
const STEPS := [
	{
		# 첫 출정 ① — 배수관 출구(브리핑 진입점)를 가리킨다. 멀리 있으면 월드
		# 마커(3D 위치 투영)를, 가까이 오면 상호작용 버튼을 가리킨다.
		# 필드 도착 후는 RaidTutorial(이동→조준→수색→가방→탈출)이 이어받는다.
		"id": "first_sortie_gate", "zone": "shelter", "title": "첫 출정",
		"text": "쉘터의 물자는 전부 바깥에서 가져옵니다. 배수관 출구로 가서 작전 브리핑을 여세요.",
		"targets": ["pipe_exit"],
	},
	{
		# 첫 출정 ② — 브리핑 안: 구역 마커 → (선택 후) 출정 버튼 순으로 깊어진다.
		"id": "first_sortie_launch", "zone": "shelter", "title": "작전 브리핑",
		"text": "지도에서 구역을 고르고 출정 버튼을 누르세요. 탄약과 구급약은 자동 보급됩니다.",
		"targets": ["raid_briefing"], "overlay": "briefing",
	},
	{
		"id": "seat_worker", "zone": "shelter", "title": "쉘터 입문",
		"text": "운영 독에서 생산을 열고 주민을 좌석에 앉히세요. 앉은 주민이 고철을 만듭니다.",
		"targets": ["dock:scratcher_bank", "prefix:ResidentCard_"],
	},
	{
		"id": "read_goal", "zone": "shelter", "title": "다음 목표 읽기",
		"text": "이 카드가 쉘터의 다음 목표입니다. 탭해서 무엇이 얼마나 모자란지 확인하세요.",
		"targets": ["stats:goal"],
	},
	{
		"id": "train_magazine", "zone": "shelter", "title": "훈련장 — 탄약 운용",
		"text": "훈련은 통조림으로 삽니다. 주워 온 통조림을 부어 탄창 숙련을 올리세요. 장탄 수가 늘어납니다.",
		"targets": ["dock:training", "find:TrainingCard_magazine_drill"],
	},
	{
		# 2단계 강화 보드: 독 버튼 → 강화 카드 → [강화 +1] 버튼(WorkbenchEnhanceButton) 순으로 깊어진다.
		"id": "workbench_craft", "zone": "shelter", "title": "작업대 — 강화",
		"text": "첫 강화를 해보세요. 장비는 한 번 만들면 평생 내 것이고, 강화는 끝없이 올라갑니다.",
		"targets": ["dock:workbench", "find:WorkbenchEnhanceCard", "find:WorkbenchEnhanceButton"],
	},
	{
		"id": "merchant_sell", "zone": "shelter", "title": "상인 — 판매",
		"text": "행상인은 남는 탄약·부품을 고철로 사 줍니다(통조림은 훈련 재화라 안 삽니다). 판매 탭에서 하나 팔아 보세요.",
		"targets": ["merchant_notice", "interact:merchant", "find:MerchantSellTab", "merchant_sell_row"],
	},
	{
		"id": "fever_charge", "zone": "shelter", "title": "캣닢 피버",
		"text": "남는 캣닢을 부으면 게이지가 25%씩 찹니다. 네 번 채우면 쉘터 전체가 폭주합니다.",
		"targets": ["fever"],
	},
	{
		# 통조림 먹기 스텝은 폐지됐다(유저 확정: "통조림은 먹는거 아님").
		# 대신 통조림의 실제 용도 하나를 몸으로 익히게 한다 — 던져서 유인하기.
		# 데스크톱은 CanInfoButton, 터치는 CanThrowButton이 뜬다(둘 중 보이는 쪽).
		"id": "bag_throw", "zone": "field", "title": "통조림 — 던지기",
		"text": "통조림은 먹는 게 아니라 던지는 겁니다. 링 안을 노려 던지면 소리에 적이 몰려옵니다.",
		"targets": ["find:CanInfoButton", "find:CanThrowButton"],
	},
	{
		"id": "level_choice", "zone": "extraction", "title": "정산 — 성장 선택",
		"text": "이번 판의 성장 포인트는 이 화면에서만 씁니다. 카드 하나를 골라야 쉘터로 돌아갑니다.",
		"targets": ["extraction:choice"],
	},
	{
		"id": "salvage_notice", "zone": "shelter", "title": "잉여 장비 분해",
		"text": "남는 장비는 부품이 됩니다. 장착한 것 하나와 예비 하나만 남고 나머지는 자동으로 분해됩니다.",
		"targets": ["settlement:salvage"],
	},
	{
		"id": "train_supply", "zone": "shelter", "title": "훈련장 — 출정 보급",
		"text": "탄창 숙련 다음은 휴대와 보급입니다. 탄약 휴대는 필드에서 줍는 탄약량을 늘리고, 출정 보급은 시작 탄창을 늘립니다.",
		"targets": ["dock:training", "find:TrainingCard_ammo_carry", "find:TrainingCard_sortie_supply"],
	},
]

var host: Node
var zones: Array[String] = []
var layer: CanvasLayer
var root: Control
var arrow: TutorialArrow
var card: PanelContainer
var card_title: Label
var card_text: Label
var skip_button: Button
var check_label: Label
# 컨테이너(HFlow 등) 대상은 자식을 더하면 레이아웃이 깨져 림 펄스를 못 붙인다 — 대신 테두리 헤일로.
var halo: Panel
# 월드 좌표(배수관 출구) 위에 띄우는 투영 프록시 — 컨트롤이 없는 3D 지점도
# 같은 화살표/림 문법으로 가리키기 위한 빈 Control. 매 프레임 위치를 갱신한다.
var world_marker: Control

var active_step_id := ""
var active_target: Control
var poll_timer := 0.0
var idle_time := 0.0
var card_collapsed := false
# ✓ 연출 중 — 다음 스텝이 바로 겹쳐 뜨지 않게 잠깐 쉰다.
var completing_cooldown := 0.0
# ✓가 도는 동안은 포인터를 숨겨도 레이어는 켜 둔다.
var check_playing := false
var arrow_phase := 0.0
var snapshots: Dictionary = {}
# host가 notify()로 밀어 넣는 행동 사실(판매 1회·통조림 투척 등).
var notices: Dictionary = {}
var goal_row_connected := false
# 스텝이 한 번이라도 활성화된 적 있는지(세션). 정산 카드처럼 "닫히면 완료"인 스텝에 쓴다.
var seen_this_session: Dictionary = {}


func attach(owner_node: Node) -> void:
	host = owner_node


func build(parent: Node, zone_list: Array) -> void:
	# 한 host에 여러 존이 걸릴 수 있다(필드 main은 field + extraction).
	zones.clear()
	for zone in zone_list:
		zones.append(str(zone))
	layer = CanvasLayer.new()
	layer.name = "ActiveTutorialLayer"
	layer.layer = LAYER_INDEX
	# 정산 화면은 트리를 멈춘 채 뜬다 — 거기서도 포인터가 움직여야 한다.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	root = Control.new()
	root.name = "ActiveTutorialRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_build_pointer()
	_build_halo()
	_build_card()
	_build_check()
	_build_world_marker()
	var ticker := TutorialTicker.new()
	ticker.name = "Ticker"
	ticker.tick = update
	layer.add_child(ticker)
	_set_ui_visible(false)


func _build_pointer() -> void:
	arrow = TutorialArrow.new()
	arrow.name = "TutorialArrow"
	arrow.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	arrow.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arrow)


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "TutorialCard"
	var style := HudStyle.panel(HudStyle.INK, HudStyle.LINE_GOLD, HudStyle.RADIUS_CARD)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# 축소된 카드를 탭하면 다시 펼친다(데스크톱 클릭 · 에뮬레이트 터치).
	card.gui_input.connect(func(event: InputEvent) -> void:
		var pressed := (
			(event is InputEventMouseButton and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		)
		if pressed:
			_expand_card()
	)
	root.add_child(card)
	var box := VBoxContainer.new()
	box.name = "TutorialCardBox"
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var header := HBoxContainer.new()
	header.name = "TutorialCardHeader"
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	card_title = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.GOLD_TEXT)
	card_title.name = "TutorialTitle"
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(card_title)
	skip_button = Button.new()
	skip_button.name = "TutorialSkipButton"
	skip_button.text = "건너뛰기 ›"
	skip_button.tooltip_text = "이 안내만 건너뜁니다"
	# 카드의 주인공은 본문 — 건너뛰기는 조용한 텍스트 링크로(유저: 버튼이 너무
	# 크다). 터치 오차만 감안해 높이 32는 남긴다.
	skip_button.custom_minimum_size = Vector2(0, 32)
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_override("font", HudStyle.FONT)
	skip_button.add_theme_font_size_override("font_size", HudStyle.TYPE_FOOTNOTE)
	skip_button.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	skip_button.add_theme_color_override("font_hover_color", HudStyle.GOLD_TEXT)
	skip_button.add_theme_color_override("font_pressed_color", HudStyle.GOLD_TEXT)
	skip_button.pressed.connect(func() -> void: _complete_active(true))
	header.add_child(skip_button)
	card_text = HudStyle.label("", HudStyle.TYPE_BODY, HudStyle.TEXT)
	card_text.name = "TutorialText"
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.custom_minimum_size.x = CARD_MAX_WIDTH - 24.0
	card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(card_text)


func _build_halo() -> void:
	halo = Panel.new()
	halo.name = "TutorialHalo"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = HudFx.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(HudStyle.RADIUS_CARD)
	halo.add_theme_stylebox_override("panel", style)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.visible = false
	root.add_child(halo)


func _build_world_marker() -> void:
	world_marker = Control.new()
	world_marker.name = "TutorialWorldMarker"
	world_marker.size = Vector2(44, 44)
	world_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(world_marker)


func _update_world_marker() -> void:
	# 배수관 출구의 3D 위치를 화면에 투영해 프록시 컨트롤을 그 위에 놓는다.
	if world_marker == null or not is_instance_valid(world_marker):
		return
	if host == null or not host.has_method("_pipe_exit_station"):
		return
	var camera := host.get_viewport().get_camera_3d()
	if camera == null:
		return
	var station := host.call("_pipe_exit_station") as Dictionary
	var ground := station.get("position", Vector2.ZERO) as Vector2
	var anchor := Vector3(ground.x, 1.0, ground.y)
	var screen_point := camera.unproject_position(anchor)
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var behind := camera.is_position_behind(anchor)
	var on_screen := not behind and Rect2(
		Vector2(60.0, 96.0), viewport_size - Vector2(120.0, 192.0)
	).has_point(screen_point)
	if behind:
		screen_point = viewport_size * 0.5 + (viewport_size * 0.5 - screen_point)
	screen_point.x = clampf(screen_point.x, 60.0, viewport_size.x - 60.0)
	screen_point.y = clampf(screen_point.y, 96.0, viewport_size.y - 96.0)
	world_marker.position = screen_point - world_marker.size * 0.5
	# 대상이 화면 밖이면 가장자리에 빈 네모(림 펄스)를 그리지 않는다 —
	# 화살표가 방향을 가리키는 걸로 충분하고, 네모는 실제 위치가 보일 때만.
	var rim := world_marker.get_node_or_null("RimPulseFx")
	if rim != null:
		rim.visible = on_screen


func _build_check() -> void:
	check_label = HudStyle.label("✓", 40, HudStyle.GOLD_TEXT)
	check_label.name = "TutorialCheck"
	check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	check_label.add_theme_constant_override("outline_size", 6)
	check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_label.size = Vector2(56, 56)
	check_label.visible = false
	root.add_child(check_label)


# ── 엔진 ─────────────────────────────────────────────────────────


func update(delta: float) -> void:
	if host == null or not is_instance_valid(host) or not is_instance_valid(layer):
		return
	arrow_phase += delta * 5.2
	if completing_cooldown > 0.0:
		completing_cooldown = maxf(0.0, completing_cooldown - delta)
		return
	_update_world_marker()
	poll_timer -= delta
	if poll_timer <= 0.0:
		poll_timer = POLL_INTERVAL
		_poll()
	if active_step_id.is_empty():
		_set_ui_visible(false)
		return
	var step := get_step(active_step_id)
	if _blocked_for(step):
		_set_ui_visible(false)
		return
	# 타깃은 모달이 열리고 닫히며 매 순간 바뀐다(독 버튼 ↔ 모달 안 카드).
	var target := _resolve_chain(step)
	if target != active_target:
		_switch_target(target)
	if active_target == null:
		_set_ui_visible(false)
		return
	if _modal_open() and not _in_modal(active_target):
		_set_ui_visible(false)
		return
	if not arrow.visible:
		_set_ui_visible(true)
	idle_time += delta
	if not card_collapsed and idle_time >= CARD_COLLAPSE_SECONDS:
		_collapse_card()
	_layout_pointer()


func _poll() -> void:
	if not _enabled():
		if not active_step_id.is_empty():
			_deactivate()
		return
	if not active_step_id.is_empty():
		# 밖에서 완료 처리됐으면(리셋·디버그) 조용히 내린다.
		if GameState.is_tutorial_step_done(active_step_id):
			_deactivate()
			return
		var active := get_step(active_step_id)
		if _complete_met(active):
			_complete_active(false)
		return
	for step_value in STEPS:
		var step := step_value as Dictionary
		if not zones.has(str(step.get("zone", ""))):
			continue
		var step_id := str(step.get("id", ""))
		if GameState.is_tutorial_step_done(step_id):
			continue
		if _blocked_for(step) or not _trigger_met(step):
			continue
		var target := _resolve_chain(step)
		if target == null:
			continue
		if _modal_open() and not _in_modal(target):
			continue
		_activate(step, target)
		return


func _activate(step: Dictionary, target: Control) -> void:
	active_step_id = str(step.get("id", ""))
	seen_this_session[active_step_id] = true
	_take_snapshot(active_step_id)
	# 완료는 "안내가 뜬 뒤의 행동"이어야 한다 — 뜨기 전에 쌓인 행동 사실은 버린다.
	notices.clear()
	card_title.text = str(step.get("title", ""))
	card_text.text = str(step.get("text", ""))
	card_collapsed = false
	card_text.visible = true
	skip_button.visible = true
	idle_time = 0.0
	_switch_target(target)
	_set_ui_visible(true)
	_layout_pointer()
	card.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.96, 0.96)
	var tween := card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if active_step_id == "read_goal":
		_connect_goal_row()


func _deactivate() -> void:
	_switch_target(null)
	active_step_id = ""
	_set_ui_visible(false)


func _complete_active(skipped: bool) -> void:
	if active_step_id.is_empty():
		return
	var finished_id := active_step_id
	GameState.mark_tutorial_step_done(finished_id)
	var check_center := Vector2.ZERO
	if is_instance_valid(active_target):
		check_center = active_target.get_global_rect().get_center()
	var show_check := not skipped and is_instance_valid(active_target) and layer.visible and arrow.visible
	check_playing = show_check
	_deactivate()
	# 다음 스텝이 같은 프레임에 올라타지 않게 잠깐 쉰다(✓가 읽힐 시간).
	completing_cooldown = CHECK_SECONDS + 0.1 if show_check else 0.15
	poll_timer = 0.0
	if show_check:
		_play_check(check_center)


func _play_check(center: Vector2) -> void:
	check_label.visible = true
	check_label.position = center - check_label.size * 0.5
	check_label.pivot_offset = check_label.size * 0.5
	check_label.modulate.a = 1.0
	check_label.scale = Vector2(0.5, 0.5)
	var tween := check_label.create_tween()
	tween.tween_property(check_label, "scale", Vector2(1.15, 1.15), CHECK_SECONDS * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(check_label, "modulate:a", 0.0, CHECK_SECONDS * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		check_label.visible = false
		check_playing = false
		if active_step_id.is_empty() and is_instance_valid(layer):
			layer.visible = false
	)


func notify(event_id: String) -> void:
	# host가 "판매 1회", "통조림 던짐" 같은 행동 사실을 밀어 넣는 입구.
	notices[event_id] = true
	poll_timer = 0.0


func get_step(step_id: String) -> Dictionary:
	for step_value in STEPS:
		if str((step_value as Dictionary).get("id", "")) == step_id:
			return step_value as Dictionary
	return {}


func get_active_step_id() -> String:
	return active_step_id


func get_active_target() -> Control:
	return active_target


func handle_touch(screen_position: Vector2) -> bool:
	# host의 _input이 조이스틱·독보다 먼저 부른다 — 건너뛰기/목표 줄 탭은 여기서 먹는다.
	if active_step_id.is_empty() or not is_instance_valid(layer) or not layer.visible or not card.visible:
		return false
	if skip_button.visible and skip_button.get_global_rect().has_point(screen_position):
		_complete_active(true)
		return true
	if card_collapsed and card.get_global_rect().has_point(screen_position):
		_expand_card()
		return true
	if (
		active_step_id == "read_goal"
		and is_instance_valid(active_target)
		and active_target.get_global_rect().grow(6.0).has_point(screen_position)
	):
		_on_goal_tapped()
		return true
	return false


# ── 트리거 / 완료 조건 ───────────────────────────────────────────


func _first_sortie() -> bool:
	# 아직 한 번도 복귀한 적 없는 세이브만 — 기존 유저(복귀·주민 보유)는 스킵.
	return (
		GameState.opening_completed
		and GameState.shelter_return_serial <= 0
		and GameState.rescued_workers <= 0
	)


func _trigger_met(step: Dictionary) -> bool:
	match str(step.get("id", "")):
		"first_sortie_gate":
			return _first_sortie() and not bool(host.get("raid_zone_ui_open"))
		"first_sortie_launch":
			return _first_sortie() and bool(host.get("raid_zone_ui_open"))
		"seat_worker":
			return (
				GameState.shelter_return_serial >= 1
				and GameState.is_shelter_facility_unlocked("scratcher_bank")
				and GameState.resident_cat_ids.size() >= 1
				and _assigned_worker_count() <= 0
			)
		"read_goal":
			return GameState.shelter_return_serial >= 1
		"train_magazine":
			return (
				GameState.is_shelter_facility_unlocked("training")
				and GameState.get_training_rank("magazine_drill") <= 0
				and GameState.shelter_canned_food >= GameState.get_training_cost("magazine_drill")
			)
		"workbench_craft":
			return (
				GameState.is_shelter_facility_unlocked("workbench")
				and _mod_component_total() >= 1
				and GameState.scrap >= 4300
			)
		"merchant_sell":
			return (
				GameState.merchant_status in ["waiting", "inside"]
				and _has_sellable_goods()
			)
		"fever_charge":
			return (
				GameState.is_shelter_facility_unlocked("catnip_scraper")
				and not GameState.catnip_fever_active
				and GameState.catnip >= GameState.get_catnip_fever_charge_cost()
			)
		"bag_throw":
			# 던질 것이 있고(3개 이상), 아직 아무도 나를 못 본 상태에서 적이 둘 이상
			# 있을 때 — 유인이 실제로 이득인 순간에만 가리킨다.
			if GameState.canned_food < 3:
				return false
			var enemy_list = host.get("enemies")
			if not (enemy_list is Array):
				return false
			var idle_enemies := 0
			for enemy in enemy_list as Array:
				if not is_instance_valid(enemy) or bool(enemy.get("dying")):
					continue
				if bool(enemy.get("alerted")):
					return false
				idle_enemies += 1
			return idle_enemies >= 2
		"level_choice":
			return GameState.pending_level_choices > 0 and _extraction_panel_visible()
		"salvage_notice":
			return _resolve_target("settlement:salvage") != null
		"train_supply":
			return (
				GameState.is_shelter_facility_unlocked("training")
				and GameState.get_training_rank("magazine_drill") >= 1
				and GameState.get_training_rank("sortie_supply") <= 0
				and GameState.get_training_rank("ammo_carry") <= 0
				and GameState.shelter_canned_food >= GameState.get_training_cost("ammo_carry")
			)
	return false


func _complete_met(step: Dictionary) -> bool:
	match str(step.get("id", "")):
		"first_sortie_gate":
			return bool(host.get("raid_zone_ui_open"))
		"first_sortie_launch":
			return bool(host.get("raid_launch_in_progress"))
		"seat_worker":
			return _assigned_worker_count() >= 1
		"read_goal":
			return notices.has("goal_tapped")
		"train_magazine":
			return GameState.get_training_rank("magazine_drill") >= 1
		"workbench_craft":
			return (
				_equipment_total() > int(snapshots.get("equipment_total", 0))
				or _enhancement_total() > int(snapshots.get("enhancement_total", 0))
			)
		"merchant_sell":
			return notices.has("merchant_sold")
		"fever_charge":
			return (
				GameState.catnip_fever_active
				or GameState.catnip_fever_gauge > float(snapshots.get("fever_gauge", 0.0)) + 0.01
			)
		"bag_throw":
			return notices.has("can_thrown")
		"level_choice":
			return GameState.pending_level_choices < int(snapshots.get("pending_level_choices", 0))
		"salvage_notice":
			# 카드가 닫히면(확인) 완료 — 정산 카드가 사라진 뒤에는 더 가리킬 것이 없다.
			return _resolve_target("settlement:salvage") == null
		"train_supply":
			return (
				GameState.get_training_rank("ammo_carry") >= 1
				or GameState.get_training_rank("sortie_supply") >= 1
			)
	return false


func _take_snapshot(step_id: String) -> void:
	snapshots.clear()
	match step_id:
		"workbench_craft":
			snapshots["equipment_total"] = _equipment_total()
			snapshots["enhancement_total"] = _enhancement_total()
		"fever_charge":
			snapshots["fever_gauge"] = GameState.catnip_fever_gauge
		"level_choice":
			snapshots["pending_level_choices"] = GameState.pending_level_choices


func _assigned_worker_count() -> int:
	return GameState.assigned_worker_ids.size() + GameState.assigned_catnip_worker_ids.size()


func _mod_component_total() -> int:
	var total := 0
	for amount in GameState.mod_component_inventory.values():
		total += maxi(0, int(amount))
	return total


func _equipment_total() -> int:
	var total := 0
	for amount in GameState.equipment_inventory.values():
		total += maxi(0, int(amount))
	return total


func _enhancement_total() -> int:
	# 강화 합계 — 무기·파츠에 방어구(+99 보드)도 더한다. 보드에서 무엇을 올리든 완료.
	var total := 0
	for level in GameState.weapon_enhancement_levels.values():
		total += maxi(0, int(level))
	for level in GameState.armor_enhancement_levels.values():
		total += maxi(0, int(level))
	for level in GameState.mod_enhancement_levels.values():
		total += maxi(0, int(level))
	return total


func _has_sellable_goods() -> bool:
	# 상인 매입 목록(MERCHANT_SELL_GOODS)에 있는 것 중 하나라도 들고 있으면 판매 가능.
	# 통조림은 목록에서 빠졌다(훈련 재화) — 더 이상 여기서 세지 않는다.
	for good_value in GameState.MERCHANT_SELL_GOODS:
		var good := good_value as Dictionary
		var good_id := str(good.get("id", ""))
		var amount := int(good.get("amount", 1))
		match str(good.get("type", "")):
			"ammo":
				if int(GameState.ammo_inventory.get(good_id, 0)) >= amount:
					return true
			"component":
				if int(GameState.mod_component_inventory.get(good_id, 0)) >= amount:
					return true
	return false


# ── 타깃 해석 ─────────────────────────────────────────────────────


func _resolve_chain(step: Dictionary) -> Control:
	# 깊은 타깃(모달 안)부터 본다. 화면에 있으면 그쪽, 없으면 얕은 타깃(독 버튼).
	var targets := step.get("targets", []) as Array
	for index in range(targets.size() - 1, -1, -1):
		var control := _resolve_target(str(targets[index]))
		if control != null and _on_screen(control):
			return control
	return null


func _resolve_target(spec: String) -> Control:
	var parts := spec.split(":", true, 1)
	var kind := str(parts[0])
	var arg := str(parts[1]) if parts.size() > 1 else ""
	match kind:
		"pipe_exit":
			# 첫 출정 ① — 출구 근처면 상호작용 버튼, 멀면 월드 투영 마커.
			if bool(host.get("raid_zone_ui_open")):
				return null
			if str(host.get("current_station")) == "pipe_exit":
				var interact := _visible_control(host.get("interact_button"))
				if interact != null:
					return interact
			if not host.has_method("_pipe_exit_station"):
				return null
			# 마커는 튜토리얼 레이어 안에 산다 — 레이어가 꺼져 있어도(비활성 상태)
			# 대상으로 인정해야 스텝이 켜질 수 있다. 가시성 검사는 건너뛴다.
			if world_marker != null and is_instance_valid(world_marker):
				return world_marker
			return null
		"raid_briefing":
			# 첫 출정 ② — 구역 미선택이면 해금된 지도 마커, 선택했으면 출정 버튼.
			if not bool(host.get("raid_zone_ui_open")):
				return null
			if str(host.get("raid_zone_selected_id")).is_empty():
				var markers_value = host.get("raid_zone_map_markers")
				if markers_value is Dictionary:
					for zone_id in markers_value as Dictionary:
						if not GameState.is_raid_zone_unlocked(str(zone_id)):
							continue
						var marker := _visible_control((markers_value as Dictionary)[zone_id])
						if marker != null:
							return marker
				return null
			var launch := host.get("raid_zone_launch_button") as Button
			if launch == null or not is_instance_valid(launch) or launch.disabled:
				return null
			return _visible_control(launch)
		"dock":
			var console = host.get("ops_console")
			if console == null:
				return null
			var buttons := console.get("facility_buttons") as Dictionary
			return _visible_control(buttons.get(arg))
		"fever":
			var console = host.get("ops_console")
			if console == null:
				return null
			return _visible_control(console.get("fever_button"))
		"stats:goal", "stats":
			return _visible_control(host.get("shelter_goal_card"))
		"bag":
			var inventory := _inventory_ui()
			if inventory == null or bool(inventory.call("is_open")):
				return null
			return _visible_control(inventory.get_node_or_null("InventoryButton"))
		"find":
			return _visible_control(host.get_tree().root.find_child(arg, true, false))
		"prefix":
			return _find_prefixed_in_modals(arg)
		"interact":
			var station := str(host.get("current_station"))
			if arg == "merchant" and not station.begins_with("merchant"):
				return null
			return _visible_control(host.get("interact_button"))
		"merchant_notice":
			return _visible_control(host.get("merchant_notice_panel"))
		"merchant_sell_row":
			if not bool(host.get("merchant_ui_open")) or str(host.get("merchant_shop_mode")) != "sell":
				return null
			return _find_prefixed(host.get("merchant_ui_layer") as Node, "MerchantGood_")
		"extraction":
			var hud = host.get("hud")
			if hud == null or not _extraction_panel_visible():
				return null
			var row := hud.get("extraction_level_choice_row") as Control
			if row == null or not row.is_visible_in_tree() or row.get_child_count() <= 0:
				return null
			return _visible_control(row.get_child(0))
		"settlement":
			var settlement := host.get("return_settlement_layer") as Node
			if settlement == null or not is_instance_valid(settlement):
				return null
			if arg == "salvage":
				return _find_label_containing(settlement, "분해")
			return _visible_control(settlement.find_child("ReturnSettlementConfirmButton", true, false))
	return null


func _visible_control(value: Variant) -> Control:
	var control := value as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		return null
	if not control.is_visible_in_tree():
		return null
	return control


func _on_screen(control: Control) -> bool:
	var rect := control.get_global_rect()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return false
	var viewport_rect := Rect2(Vector2.ZERO, host.get_viewport().get_visible_rect().size)
	if not viewport_rect.intersects(rect):
		return false
	# 스크롤 안에 숨어 있으면 아직 '화면에 있는' 게 아니다 — 스크롤 영역과 겹쳐야 한다.
	var scroll := _find_ancestor_scroll(control)
	if scroll != null and not scroll.get_global_rect().intersects(rect):
		return false
	return true


func _find_ancestor_scroll(node: Node) -> ScrollContainer:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is ScrollContainer:
			return cursor as ScrollContainer
		cursor = cursor.get_parent()
	return null


func _find_prefixed_in_modals(prefix: String) -> Control:
	for modal in host.get_tree().get_nodes_in_group("shelter_modal_ui"):
		var found := _find_prefixed(modal, prefix)
		if found != null:
			return found
	return null


func _find_prefixed(node: Node, prefix: String) -> Control:
	# 이름 접두사로 첫 '누를 수 있는' 컨트롤을 찾는다(빈 좌석·비활성 카드는 건너뜀).
	if node == null or not is_instance_valid(node):
		return null
	if node is Control and str(node.name).begins_with(prefix):
		var control := node as Control
		var usable := control.is_visible_in_tree()
		if control is BaseButton:
			usable = usable and not (control as BaseButton).disabled
		if usable:
			return control
	for child in node.get_children():
		var found := _find_prefixed(child, prefix)
		if found != null:
			return found
	return null


func _find_label_containing(node: Node, needle: String) -> Control:
	if node == null or not is_instance_valid(node):
		return null
	if node is Label and str((node as Label).text).contains(needle) and (node as Label).is_visible_in_tree():
		return node as Control
	for child in node.get_children():
		var found := _find_label_containing(child, needle)
		if found != null:
			return found
	return null


func _inventory_ui() -> Node:
	var direct := host.get("inventory_ui") as Node
	if direct != null:
		return direct
	var hud = host.get("hud")
	if hud != null:
		return hud.get("inventory_ui") as Node
	return null


func _extraction_panel_visible() -> bool:
	var hud = host.get("hud")
	if hud == null:
		return false
	var panel := hud.get("extraction_result_panel") as Control
	return panel != null and is_instance_valid(panel) and panel.is_visible_in_tree()


# ── 차단 / 모달 규칙 ─────────────────────────────────────────────


func _enabled() -> bool:
	return bool(AccessibilitySettings.get("active_tutorial_enabled"))


func _blocked_for(step: Dictionary) -> bool:
	var zone := str(step.get("zone", ""))
	var tree := host.get_tree()
	if tree == null:
		return true
	match zone:
		"shelter":
			if tree.paused:
				return true
			# 서사·브리핑·계약 UI·시네마틱 위에는 올라타지 않는다.
			# 단 overlay: "briefing" 스텝(첫 출정 안내)은 브리핑 자체가 무대다.
			var allow_briefing := str(step.get("overlay", "")) == "briefing"
			if bool(host.get("contract_story_open")) or bool(host.get("contract_ui_open")):
				return true
			if bool(host.get("raid_zone_ui_open")) and not allow_briefing:
				return true
			# 피버 발동 연출·주홍 시네마틱·해금 배너가 떠 있는 동안은 가리키지 않는다.
			for layer_name in ["CatnipFeverLayer", "JuhongCinematicLayer", "MilestoneUnlockLayer"]:
				if host.get_node_or_null(layer_name) != null:
					return true
			return false
		"field":
			if tree.paused:
				return true
			return _field_busy()
		"extraction":
			# 정산 화면은 트리를 멈추고 뜬다 — 여기선 일시정지가 차단 사유가 아니다.
			return not _extraction_panel_visible()
	return true


func _field_busy() -> bool:
	if bool(host.get("player_death_sequence_active")) or bool(host.get("boss_defeat_sequence_active")):
		return true
	if bool(host.get("extraction_transition_active")):
		return true
	if host.has_method("is_cinematic_active") and bool(host.call("is_cinematic_active")):
		return true
	if host.has_method("is_bark_active") and bool(host.call("is_bark_active")):
		return true
	if host.has_method("_is_tactical_map_open") and bool(host.call("_is_tactical_map_open")):
		return true
	var reader = host.get("lore_reader")
	if reader != null and bool(reader.call("is_open")):
		return true
	var loot = host.get("loot_system")
	if loot != null and bool(loot.call("is_loot_swap_open")):
		return true
	# 전투 중(경계 상태의 적이 하나라도)에는 보류 — 안내가 목숨보다 급하지 않다.
	var director = host.get("enemy_director")
	if director != null and int(director.call("count_alerted_enemies")) > 0:
		return true
	return false


func _modal_open() -> bool:
	if host.has_method("_ui_blocks_player"):
		return bool(host.call("_ui_blocks_player"))
	var inventory := _inventory_ui()
	return inventory != null and bool(inventory.call("is_open"))


func _in_modal(control: Control) -> bool:
	var cursor: Node = control
	while cursor != null:
		if cursor is CanvasLayer and (cursor as CanvasLayer).layer >= 60:
			return true
		if cursor.is_in_group("shelter_modal_ui") or str(cursor.name) in ["InventoryUI", "MerchantShopLayer"]:
			return true
		cursor = cursor.get_parent()
	return false


# ── 포인터 / 카드 배치 ───────────────────────────────────────────


func _switch_target(target: Control) -> void:
	if is_instance_valid(active_target) and active_target != target:
		HudFx.detach_rim_pulse(active_target)
	active_target = target
	if is_instance_valid(halo):
		halo.visible = false
	if is_instance_valid(active_target):
		if _rim_allowed(active_target):
			HudFx.attach_rim_pulse(active_target, HudFx.GOLD, 7.0)
		_scroll_into_view(active_target)
		idle_time = 0.0
		if card_collapsed:
			_expand_card()


func _rim_allowed(control: Control) -> bool:
	# Box/Flow/Grid 컨테이너는 자식(림 ColorRect)을 줄에 세워 버린다. PanelContainer는 괜찮다.
	return not (control is BoxContainer or control is FlowContainer or control is GridContainer)


func _scroll_into_view(control: Control) -> void:
	var scroll := _find_ancestor_scroll(control)
	if scroll != null:
		scroll.ensure_control_visible(control)


func _set_ui_visible(value: bool) -> void:
	if not is_instance_valid(layer):
		return
	# 포인터(화살표·카드·헤일로)만 끈다 — ✓ 연출이 도는 동안 레이어는 살아 있어야 보인다.
	layer.visible = value or check_playing
	arrow.visible = value
	card.visible = value
	if not value and is_instance_valid(halo):
		halo.visible = false


func _collapse_card() -> void:
	card_collapsed = true
	card_text.visible = false
	skip_button.visible = false


func _expand_card() -> void:
	card_collapsed = false
	card_text.visible = true
	skip_button.visible = true
	idle_time = 0.0


func _layout_pointer() -> void:
	if not is_instance_valid(active_target):
		return
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var safe: Vector4 = UISafeArea.get_margins(viewport_size)
	var target_rect := active_target.get_global_rect()
	# 스크롤 영역 밖으로 나간 부분은 보이지 않으니 보이는 부분만 가리킨다.
	var scroll := _find_ancestor_scroll(active_target)
	if scroll != null:
		target_rect = target_rect.intersection(scroll.get_global_rect())
	var center := target_rect.get_center()
	# 화살표 방향 자동: 우측 대상 → 왼쪽에서, 하단 탭바 → 위에서, 좌측 → 오른쪽에서.
	var side := "top"
	if center.y > viewport_size.y * 0.66:
		side = "top"
	elif center.x > viewport_size.x * 0.58:
		side = "left"
	elif center.x < viewport_size.x * 0.42:
		side = "right"
	elif target_rect.position.y < 120.0 + safe.y:
		side = "bottom"
	var bounce := sin(arrow_phase) * ARROW_BOUNCE
	var arrow_position := Vector2.ZERO
	match side:
		"top":
			arrow.direction = Vector2.DOWN
			arrow_position = Vector2(center.x - ARROW_SIZE * 0.5, target_rect.position.y - ARROW_GAP - ARROW_SIZE + bounce)
		"bottom":
			arrow.direction = Vector2.UP
			arrow_position = Vector2(center.x - ARROW_SIZE * 0.5, target_rect.end.y + ARROW_GAP - bounce)
		"left":
			arrow.direction = Vector2.RIGHT
			arrow_position = Vector2(target_rect.position.x - ARROW_GAP - ARROW_SIZE + bounce, center.y - ARROW_SIZE * 0.5)
		"right":
			arrow.direction = Vector2.LEFT
			arrow_position = Vector2(target_rect.end.x + ARROW_GAP - bounce, center.y - ARROW_SIZE * 0.5)
	arrow.position = arrow_position
	arrow.queue_redraw()
	if not _rim_allowed(active_target):
		halo.visible = true
		halo.position = target_rect.position - Vector2(4.0, 3.0)
		halo.size = target_rect.size + Vector2(8.0, 6.0)
		halo.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(arrow_phase * 0.8))
	else:
		halo.visible = false
	# 카드는 화살표 너머, 대상과 겹치지 않게. 화면 안으로 클램프.
	var card_width := minf(CARD_MAX_WIDTH, viewport_size.x - safe.x - safe.z - EDGE_MARGIN * 2.0)
	card_text.custom_minimum_size.x = maxf(120.0, card_width - 24.0)
	card.size = Vector2(card_width, 0.0)
	card.reset_size()
	var card_size := Vector2(card_width, maxf(card.size.y, card.get_combined_minimum_size().y))
	var card_position := _card_position_for(side, target_rect, card_size)
	card_position = _clamp_to_screen(card_position, card_size, viewport_size, safe)
	var card_rect := Rect2(card_position, card_size)
	if card_rect.intersects(target_rect):
		# 겹치면 반대편으로 한 번 뒤집는다.
		var flipped: String = str({"top": "bottom", "bottom": "top", "left": "right", "right": "left"}[side])
		var alternative := _clamp_to_screen(_card_position_for(flipped, target_rect, card_size), card_size, viewport_size, safe)
		if not Rect2(alternative, card_size).intersects(target_rect):
			card_position = alternative
			card_rect = Rect2(card_position, card_size)
	# 상태 토스트(상단 중앙)와 겹치면 그 아래로 내린다.
	var toast := host.get("status_panel") as Control
	if toast != null and is_instance_valid(toast) and toast.visible and toast.modulate.a > 0.05:
		var toast_rect := toast.get_global_rect()
		if card_rect.intersects(toast_rect) and not Rect2(Vector2(card_position.x, toast_rect.end.y + 6.0), card_size).intersects(target_rect):
			card_position.y = toast_rect.end.y + 6.0
			card_position = _clamp_to_screen(card_position, card_size, viewport_size, safe)
	card.position = card_position
	card.pivot_offset = card_size * 0.5


func _card_position_for(side: String, target_rect: Rect2, card_size: Vector2) -> Vector2:
	var center := target_rect.get_center()
	match side:
		"top":
			return Vector2(center.x - card_size.x * 0.5, target_rect.position.y - ARROW_GAP - ARROW_SIZE - 6.0 - card_size.y)
		"bottom":
			return Vector2(center.x - card_size.x * 0.5, target_rect.end.y + ARROW_GAP + ARROW_SIZE + 6.0)
		"left":
			return Vector2(target_rect.position.x - ARROW_GAP - ARROW_SIZE - 8.0 - card_size.x, center.y - card_size.y * 0.5)
		"right":
			return Vector2(target_rect.end.x + ARROW_GAP + ARROW_SIZE + 8.0, center.y - card_size.y * 0.5)
	return Vector2.ZERO


func _clamp_to_screen(position: Vector2, size: Vector2, viewport_size: Vector2, safe: Vector4) -> Vector2:
	var min_x := safe.x + EDGE_MARGIN
	var max_x := viewport_size.x - safe.z - EDGE_MARGIN - size.x
	var min_y := safe.y + EDGE_MARGIN
	var max_y := viewport_size.y - safe.w - EDGE_MARGIN - size.y
	return Vector2(clampf(position.x, min_x, maxf(min_x, max_x)), clampf(position.y, min_y, maxf(min_y, max_y)))


func get_card_rect() -> Rect2:
	return card.get_global_rect() if is_instance_valid(card) else Rect2()


func get_arrow_rect() -> Rect2:
	return arrow.get_global_rect() if is_instance_valid(arrow) else Rect2()


# ── 목표 줄 탭(스텝 2) ───────────────────────────────────────────


func _connect_goal_row() -> void:
	if goal_row_connected:
		return
	# 목표 줄이 카드로 재디자인되면서 노드 이름이 바뀌었다(shelter_goal_card).
	var row := host.get("shelter_goal_card") as Control
	if row == null:
		return
	goal_row_connected = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(event: InputEvent) -> void:
		var pressed := (
			(event is InputEventMouseButton and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		)
		if pressed:
			_on_goal_tapped()
	)


func _on_goal_tapped() -> void:
	# 탭 = 목표 카드 열기. 줄에서 생략된 힌트(출처)까지 토스트로 펼친다.
	var goal: Dictionary = SHELTER_REQUISITION.get_next_goal()
	var text := ""
	if goal.is_empty():
		text = str(SHELTER_REQUISITION.get_final_tier_text())
	else:
		text = str(SHELTER_REQUISITION.format_goal_line(goal, true))
		var hints: Array[String] = []
		for requirement in goal.get("requirements", []) as Array:
			var item := requirement as Dictionary
			var hint := str(item.get("hint", ""))
			if not bool(item.get("ok", false)) and not hint.is_empty():
				hints.append("%s · %s" % [str(item.get("label", "")), hint])
		if not hints.is_empty():
			text += "  —  " + "  /  ".join(hints)
	if host.has_method("_show_status") and not text.is_empty():
		host.call("_show_status", text)
	notices["goal_tapped"] = true
	poll_timer = 0.0


# ── 내부 노드 ─────────────────────────────────────────────────────


class TutorialTicker:
	extends Node
	# RefCounted 모듈은 _process가 없다 — 레이어 밑에 붙어 매 프레임 update를 대신 부른다.
	var tick: Callable

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		if tick.is_valid():
			tick.call(delta)


class TutorialArrow:
	extends Control
	# 골드 화살촉. direction이 가리키는 쪽이 대상이다.
	var direction := Vector2.DOWN
	var color := Color("#f0d77d")

	func _draw() -> void:
		var half := size * 0.5
		var tip := half + direction * half.x * 0.95
		var back := half - direction * half.x * 0.55
		var side := Vector2(-direction.y, direction.x) * half.x * 0.62
		var points := PackedVector2Array([tip, back + side, back - side])
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		var inner := PackedVector2Array([
			tip - direction * 2.0,
			back + side * 0.78 + direction * 1.5,
			back - side * 0.78 + direction * 1.5,
		])
		draw_colored_polygon(inner, color)
		# 꼬리 — 화살이 어디서 오는지 한 번 더 말한다.
		draw_line(back, back - direction * half.x * 0.45, color, 3.0, true)
