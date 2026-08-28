class_name RaidTutorial
extends RefCounted

## 첫 출정 액티브 튜토리얼 — 필드 체인(이동 → 조준 → 수색 → 가방 → 탈출).
##
## 쉘터 쪽(출정 제어반 → 브리핑)은 ActiveTutorial의 STEPS가 맡고, 필드 도착
## 직후부터는 이 모듈이 이어받는다. 철학은 같다: 읽는 안내가 아니라
## "가리키고 · 해보게 하고 · 실제 행동이 감지되면 넘어가는" 안내.
##
## ActiveTutorial과 다른 점 하나 — 대상이 Control이 아니라 월드(잔해·탈출 지점)일
## 수 있다. 그 경우 카메라 unproject로 화면에 골드 화살표 + 거리 칩을 띄우고,
## 화면 밖이면 가장자리에 붙여 방향만 가리킨다.
##
## host 패턴: main.gd가 attach → build만 부른다. 첫 출정이 아니면(기존 세이브 =
## shelter_return_serial ≥ 1 또는 rescued_workers > 0) build가 스스로 잠들어
## 아무것도 만들지 않는다. 완료는 GameState.tutorial_steps_done에 저장되어
## 죽어도 같은 스텝이 다시 뜨지 않는다.

const HudStyle := preload("res://scripts/hud/hud_style.gd")
const ACTIVE_TUTORIAL := preload("res://scripts/shelter/active_tutorial.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")

const LAYER_INDEX := 91
const POLL_INTERVAL := 0.25
const CARD_MAX_WIDTH := 300.0
const CHECK_SECONDS := 0.4
const ARROW_SIZE := 26.0
const EDGE_MARGIN := 42.0
const MOVE_REQUIRED_SECONDS := 1.0
const AIM_REQUIRED_SECONDS := 0.5
const EXTRACT_REACH_DISTANCE := 7.0

# 순서 = 체인. keys는 데스크톱 키캡 칩(모바일은 버튼 라벨이 곧 설명이라 생략).
const STEPS := [
	{
		"id": "sortie_move", "title": "첫 출정 — 이동",
		"text": "움직여 보세요. 서 있는 고양이부터 잡아먹힙니다.",
		"text_touch": "왼쪽 스틱으로 움직여 보세요.",
		"keys": ["W", "A", "S", "D"],
	},
	{
		"id": "sortie_aim", "title": "조준",
		"text": "우클릭을 누르고 있으면 조준합니다 — 무기는 조준할 때만 나옵니다.",
		"text_touch": "발사 버튼을 길게 눌러 조준하세요.",
		"keys": ["우클릭"],
	},
	{
		"id": "sortie_loot", "title": "수색",
		"text": "화살표의 잔해에 다가가 [F]를 길게 눌러 수색하세요.",
		"text_touch": "화살표의 잔해에 다가가 카드를 길게 눌러 수색하세요.",
		"keys": ["F"],
	},
	{
		"id": "sortie_bag", "title": "가방",
		"text": "방금 주운 것을 확인하세요. 가방이 차면 더 못 줍습니다.",
		"text_touch": "가방 버튼을 눌러 방금 주운 것을 확인하세요.",
		"keys": ["I"],
	},
	{
		"id": "sortie_extract", "title": "탈출",
		"text": "가방에 담은 것은 탈출해야 내 것이 됩니다. 화살표 방향의 탈출 지점으로 가세요.",
		"text_touch": "가방에 담은 것은 탈출해야 내 것이 됩니다. 화살표 방향의 탈출 지점으로 가세요.",
		"keys": ["TAB"],
	},
]

var host: Node
var built := false
var layer: CanvasLayer
var root: Control
var arrow: Control
var distance_chip: PanelContainer
var distance_label: Label
var card: PanelContainer
var card_title: Label
var card_text: Label
var key_row: HBoxContainer
var skip_button: Button
var check_label: Label

var active_step_id := ""
var poll_timer := 0.0
var arrow_phase := 0.0
var completing_cooldown := 0.0
var move_time := 0.0
var aim_time := 0.0
var notices: Dictionary = {}
# 이번 프레임의 포인터 대상(월드 좌표 or 컨트롤). null이면 카드만.
var pointer_world := Vector3.ZERO
var pointer_world_valid := false
var pointer_control: Control


func attach(owner_node: Node) -> void:
	host = owner_node


func is_chain_active() -> bool:
	return built and not _all_done()


func get_active_step_id() -> String:
	return active_step_id


func notify(event_id: String) -> void:
	if not built:
		return
	notices[event_id] = true
	poll_timer = 0.0


func build(parent: Node) -> void:
	# 첫 출정이 아니면(이미 복귀 경험이 있는 세이브) 아무것도 만들지 않는다.
	if not _first_sortie() or _all_done():
		return
	built = true
	layer = CanvasLayer.new()
	layer.name = "RaidTutorialLayer"
	layer.layer = LAYER_INDEX
	parent.add_child(layer)
	root = Control.new()
	root.name = "RaidTutorialRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_build_arrow()
	_build_card()
	_build_check()
	var ticker := Ticker.new()
	ticker.name = "Ticker"
	ticker.tick = update
	layer.add_child(ticker)
	_set_ui_visible(false)


func _build_arrow() -> void:
	arrow = ACTIVE_TUTORIAL.TutorialArrow.new()
	arrow.name = "RaidTutorialArrow"
	arrow.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	arrow.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arrow)
	distance_chip = PanelContainer.new()
	distance_chip.name = "DistanceChip"
	distance_chip.add_theme_stylebox_override("panel", HudStyle.chip(HudStyle.LINE_GOLD))
	distance_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(distance_chip)
	distance_label = HudStyle.label("", HudStyle.TYPE_FOOTNOTE, HudStyle.GOLD_TEXT)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_chip.add_child(distance_label)


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "RaidTutorialCard"
	var style := HudStyle.panel(HudStyle.INK, HudStyle.LINE_GOLD, HudStyle.RADIUS_CARD)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(card)
	var box := VBoxContainer.new()
	box.name = "RaidTutorialCardBox"
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var header := HBoxContainer.new()
	header.name = "RaidTutorialCardHeader"
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	card_title = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.GOLD_TEXT)
	card_title.name = "RaidTutorialTitle"
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(card_title)
	skip_button = Button.new()
	skip_button.name = "RaidTutorialSkipButton"
	skip_button.text = "건너뛰기"
	skip_button.tooltip_text = "이 안내만 건너뜁니다"
	skip_button.custom_minimum_size = Vector2(84, 44)
	HudStyle.style_button(skip_button, HudStyle.LINE)
	skip_button.add_theme_font_size_override("font_size", HudStyle.TYPE_FOOTNOTE)
	skip_button.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	skip_button.pressed.connect(func() -> void: _complete_active(true))
	header.add_child(skip_button)
	card_text = HudStyle.label("", HudStyle.TYPE_BODY, HudStyle.TEXT)
	card_text.name = "RaidTutorialText"
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.custom_minimum_size.x = CARD_MAX_WIDTH - 24.0
	card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(card_text)
	key_row = HBoxContainer.new()
	key_row.name = "RaidTutorialKeys"
	key_row.add_theme_constant_override("separation", 6)
	key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(key_row)


func _build_check() -> void:
	check_label = HudStyle.label("✓", 40, HudStyle.GOLD_TEXT)
	check_label.name = "RaidTutorialCheck"
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
	if not built or host == null or not is_instance_valid(host) or not is_instance_valid(layer):
		return
	arrow_phase += delta * 5.2
	if completing_cooldown > 0.0:
		completing_cooldown = maxf(0.0, completing_cooldown - delta)
		return
	_track_inputs(delta)
	poll_timer -= delta
	if poll_timer <= 0.0:
		poll_timer = POLL_INTERVAL
		_poll()
	if active_step_id.is_empty():
		_set_ui_visible(false)
		return
	if _blocked():
		_set_ui_visible(false)
		return
	_resolve_pointer()
	_set_ui_visible(true)
	_layout()


func _track_inputs(delta: float) -> void:
	# 완료 판정용 실제 입력 누적 — UI가 가려져 있어도 행동은 세어 준다.
	if host.get("player") == null:
		return
	match active_step_id:
		"sortie_move":
			var player := host.get("player") as Node3D
			if player is CharacterBody3D:
				var velocity := (player as CharacterBody3D).velocity
				velocity.y = 0.0
				if velocity.length() > 0.5:
					move_time += delta
		"sortie_aim":
			var aiming := (
				bool(host.get("laser_aim_held"))
				or bool(host.get("fire_button_held"))
				or float(host.get("aim_hold_time")) > 0.0
			)
			if aiming:
				aim_time += delta


func _poll() -> void:
	if not _enabled():
		if not active_step_id.is_empty():
			_deactivate()
		return
	if not active_step_id.is_empty():
		if GameState.is_tutorial_step_done(active_step_id):
			_deactivate()
			return
		if _complete_met(active_step_id):
			_complete_active(false)
		return
	# 다음 미완료 스텝을 순서대로 집는다. 조건상 무의미한 스텝(무기 없음 등)은
	# 조용히 완료 처리하고 넘어간다.
	for step_value in STEPS:
		var step := step_value as Dictionary
		var step_id := str(step.get("id", ""))
		if GameState.is_tutorial_step_done(step_id):
			continue
		if _should_auto_skip(step_id):
			GameState.mark_tutorial_step_done(step_id)
			continue
		_activate(step)
		return


func _should_auto_skip(step_id: String) -> bool:
	match step_id:
		"sortie_aim":
			return not bool(host.get("has_ak"))
		"sortie_extract":
			return (host.get("extraction_sites") as Array).is_empty()
	return false


func _activate(step: Dictionary) -> void:
	active_step_id = str(step.get("id", ""))
	notices.clear()
	move_time = 0.0
	aim_time = 0.0
	var touch := DisplayServer.is_touchscreen_available()
	card_title.text = str(step.get("title", ""))
	card_text.text = str(step.get("text_touch" if touch else "text", ""))
	_fill_key_row(step.get("keys", []) as Array, touch)
	card.modulate.a = 0.0
	poll_timer = 0.0


func _fill_key_row(keys: Array, touch: bool) -> void:
	for child in key_row.get_children():
		key_row.remove_child(child)
		child.queue_free()
	key_row.visible = not touch and not keys.is_empty()
	if not key_row.visible:
		return
	for key_value in keys:
		var keycap := PanelContainer.new()
		var style := HudStyle.keycap()
		style.content_margin_left = 7.0
		style.content_margin_right = 7.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		keycap.add_theme_stylebox_override("panel", style)
		keycap.custom_minimum_size = Vector2(24.0, 20.0)
		keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_label := HudStyle.label(str(key_value), HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keycap.add_child(key_label)
		key_row.add_child(keycap)


func _deactivate() -> void:
	active_step_id = ""
	pointer_control = null
	pointer_world_valid = false
	_set_ui_visible(false)


func _complete_active(skipped: bool) -> void:
	if active_step_id.is_empty():
		return
	GameState.mark_tutorial_step_done(active_step_id)
	var check_center := Vector2.ZERO
	var show_check := not skipped and is_instance_valid(layer) and layer.visible
	if show_check:
		check_center = (
			arrow.get_global_rect().get_center()
			if arrow.visible
			else card.get_global_rect().get_center()
		)
	_deactivate()
	completing_cooldown = CHECK_SECONDS + 0.1 if show_check else 0.15
	poll_timer = 0.0
	if show_check:
		_play_check(check_center)


func _play_check(center: Vector2) -> void:
	if not is_instance_valid(layer):
		return
	layer.visible = true
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
		if active_step_id.is_empty() and is_instance_valid(layer):
			layer.visible = false
	)


# ── 완료 조건 ────────────────────────────────────────────────────


func _complete_met(step_id: String) -> bool:
	match step_id:
		"sortie_move":
			return move_time >= MOVE_REQUIRED_SECONDS
		"sortie_aim":
			return aim_time >= AIM_REQUIRED_SECONDS
		"sortie_loot":
			return notices.has("interaction_done")
		"sortie_bag":
			return _inventory_open()
		"sortie_extract":
			if bool(host.get("extraction_transition_active")):
				return true
			var site := _nearest_extraction_site()
			if site == null:
				return true
			var player := host.get("player") as Node3D
			return (
				player != null
				and player.global_position.distance_to(site.global_position) <= EXTRACT_REACH_DISTANCE
			)
	return false


# ── 포인터 대상 ──────────────────────────────────────────────────


func _resolve_pointer() -> void:
	pointer_control = null
	pointer_world_valid = false
	match active_step_id:
		"sortie_aim":
			if DisplayServer.is_touchscreen_available():
				var hud_owner = host.get("hud")
				if hud_owner != null:
					pointer_control = _visible_control(hud_owner.get("fire_button"))
		"sortie_loot":
			var target := _nearest_loot_target()
			if target != null:
				pointer_world = target.global_position
				pointer_world_valid = true
		"sortie_bag":
			var hud = host.get("hud")
			var inventory := hud.get("inventory_ui") as Node if hud != null else null
			if inventory != null:
				pointer_control = _visible_control(inventory.get_node_or_null("InventoryButton"))
		"sortie_extract":
			var site := _nearest_extraction_site()
			if site != null:
				pointer_world = site.global_position
				pointer_world_valid = true


func _visible_control(value: Variant) -> Control:
	var control := value as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		return null
	if not control.is_visible_in_tree():
		return null
	return control


func _nearest_loot_target() -> Node3D:
	var player := host.get("player") as Node3D
	if player == null:
		return null
	var nearest: Node3D
	var nearest_distance := INF
	for point_value in host.get("field_interactions") as Array:
		var point := point_value as Node3D
		if point == null or not is_instance_valid(point):
			continue
		if bool(point.get_meta("completed", false)):
			continue
		var interaction_type := str(point.get_meta("interaction_type", ""))
		if interaction_type not in ["loot_container", "salvage", "high_value_cache"]:
			continue
		if not str(point.get_meta("locked_reason", "")).is_empty():
			continue
		var distance := player.global_position.distance_to(point.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = point
	return nearest


func _nearest_extraction_site() -> Node3D:
	var player := host.get("player") as Node3D
	if player == null:
		return null
	var nearest: Node3D
	var nearest_distance := INF
	for site_value in host.get("extraction_sites") as Array:
		var site := site_value as Node3D
		if site == null or not is_instance_valid(site):
			continue
		var distance := player.global_position.distance_to(site.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = site
	return nearest


# ── 차단 규칙 ────────────────────────────────────────────────────


func _first_sortie() -> bool:
	return (
		GameState.opening_completed
		and GameState.shelter_return_serial <= 0
		and GameState.rescued_workers <= 0
	)


func _all_done() -> bool:
	for step_value in STEPS:
		if not GameState.is_tutorial_step_done(str((step_value as Dictionary).get("id", ""))):
			return false
	return true


func _enabled() -> bool:
	return bool(AccessibilitySettings.get("active_tutorial_enabled"))


func _inventory_open() -> bool:
	if host.has_method("_is_inventory_open"):
		return bool(host.call("_is_inventory_open"))
	return false


func _blocked() -> bool:
	var tree := host.get_tree()
	if tree == null or tree.paused:
		return true
	# 쉘터 튜토리얼(통조림 투척 등)이 이미 화면을 쓰고 있으면 양보한다.
	var shelter_tutorial = host.get("active_tutorial")
	if shelter_tutorial != null and not str(shelter_tutorial.call("get_active_step_id")).is_empty():
		return true
	if bool(host.get("player_death_sequence_active")) or bool(host.get("boss_defeat_sequence_active")):
		return true
	if bool(host.get("extraction_transition_active")):
		return true
	if host.has_method("is_cinematic_active") and bool(host.call("is_cinematic_active")):
		return true
	if host.has_method("is_bark_active") and bool(host.call("is_bark_active")):
		return true
	# 지도는 탈출 스텝에서 오히려 도움이 된다 — 그 스텝만 열어 둔 채 진행.
	if host.has_method("_is_tactical_map_open") and bool(host.call("_is_tactical_map_open")):
		if active_step_id != "sortie_extract":
			return true
	if _inventory_open() and active_step_id != "sortie_bag":
		return true
	var reader = host.get("lore_reader")
	if reader != null and bool(reader.call("is_open")):
		return true
	var loot = host.get("loot_system")
	if loot != null and bool(loot.call("is_loot_swap_open")):
		return true
	# 전투 중에는 보류 — 안내가 목숨보다 급하지 않다.
	var director = host.get("enemy_director")
	if director != null and int(director.call("count_alerted_enemies")) > 0:
		return true
	return false


# ── 배치 ─────────────────────────────────────────────────────────


func _set_ui_visible(value: bool) -> void:
	if not is_instance_valid(layer):
		return
	layer.visible = value or check_label.visible
	card.visible = value
	if not value:
		arrow.visible = false
		distance_chip.visible = false


func _layout() -> void:
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var safe: Vector4 = UI_SAFE_AREA.get_margins(viewport_size)
	# 카드: 상단 중앙(메인 임무 배너 아래). 폭 300 상한.
	var card_width := minf(CARD_MAX_WIDTH, viewport_size.x - safe.x - safe.z - 16.0)
	card_text.custom_minimum_size.x = maxf(120.0, card_width - 24.0)
	card.size = Vector2(card_width, 0.0)
	card.reset_size()
	var card_size := Vector2(card_width, maxf(card.size.y, card.get_combined_minimum_size().y))
	card.position = Vector2(
		(viewport_size.x - card_size.x) * 0.5,
		safe.y + 92.0
	)
	if card.modulate.a < 1.0:
		card.modulate.a = minf(1.0, card.modulate.a + 0.12)
	# 포인터.
	if pointer_control != null and is_instance_valid(pointer_control):
		_point_at_rect(pointer_control.get_global_rect())
		distance_chip.visible = false
	elif pointer_world_valid:
		_point_at_world(viewport_size)
	else:
		arrow.visible = false
		distance_chip.visible = false


func _point_at_rect(target_rect: Rect2) -> void:
	arrow.visible = true
	var bounce := sin(arrow_phase) * 4.0
	arrow.set("direction", Vector2.DOWN)
	arrow.position = Vector2(
		target_rect.get_center().x - ARROW_SIZE * 0.5,
		target_rect.position.y - 6.0 - ARROW_SIZE + bounce
	)
	arrow.queue_redraw()


func _point_at_world(viewport_size: Vector2) -> void:
	var camera := host.get_viewport().get_camera_3d()
	var player := host.get("player") as Node3D
	if camera == null:
		arrow.visible = false
		distance_chip.visible = false
		return
	var anchor := pointer_world + Vector3(0.0, 1.2, 0.0)
	var behind := camera.is_position_behind(anchor)
	var screen_point := camera.unproject_position(anchor)
	var center := viewport_size * 0.5
	if behind:
		screen_point = center + (center - screen_point)
	var margin_rect := Rect2(
		Vector2(EDGE_MARGIN, EDGE_MARGIN),
		viewport_size - Vector2(EDGE_MARGIN * 2.0, EDGE_MARGIN * 2.0)
	)
	var on_screen := not behind and margin_rect.has_point(screen_point)
	var direction := Vector2.DOWN
	var arrow_center := screen_point
	if on_screen:
		# 화면 안: 대상 위에서 아래로 콕콕 찍는 화살표.
		var bounce := sin(arrow_phase) * 4.0
		arrow_center = screen_point + Vector2(0.0, -34.0 + bounce)
		direction = Vector2.DOWN
	else:
		# 화면 밖: 가장자리에 붙여 대상 방향을 가리킨다.
		var to_target := (screen_point - center)
		if to_target.length_squared() < 1.0:
			to_target = Vector2.DOWN
		direction = to_target.normalized()
		var clamped := screen_point
		clamped.x = clampf(clamped.x, margin_rect.position.x, margin_rect.end.x)
		clamped.y = clampf(clamped.y, margin_rect.position.y, margin_rect.end.y)
		var pulse := sin(arrow_phase) * 4.0
		arrow_center = clamped - direction * pulse
	arrow.visible = true
	arrow.set("direction", direction)
	arrow.position = arrow_center - Vector2(ARROW_SIZE, ARROW_SIZE) * 0.5
	arrow.queue_redraw()
	# 거리 칩.
	if player != null:
		var distance := player.global_position.distance_to(pointer_world)
		distance_label.text = "%dm" % int(round(distance))
		distance_chip.visible = true
		distance_chip.reset_size()
		var chip_size := distance_chip.get_combined_minimum_size()
		var chip_position := arrow_center + Vector2(-chip_size.x * 0.5, ARROW_SIZE * 0.5 + 4.0)
		chip_position.x = clampf(chip_position.x, 4.0, viewport_size.x - chip_size.x - 4.0)
		chip_position.y = clampf(chip_position.y, 4.0, viewport_size.y - chip_size.y - 4.0)
		distance_chip.position = chip_position
	else:
		distance_chip.visible = false


func handle_touch(screen_position: Vector2) -> bool:
	# host의 _input이 조이스틱보다 먼저 부른다 — 건너뛰기 탭은 여기서 먹는다.
	if (
		active_step_id.is_empty()
		or not is_instance_valid(layer)
		or not layer.visible
		or not card.visible
	):
		return false
	if skip_button.visible and skip_button.get_global_rect().has_point(screen_position):
		_complete_active(true)
		return true
	return false


class Ticker:
	extends Node
	var tick: Callable

	func _process(delta: float) -> void:
		if tick.is_valid():
			tick.call(delta)
