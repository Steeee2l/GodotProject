extends Control

signal open_state_changed(is_open: bool)

const UI_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
var world: Node3D
var player: Node3D
var extraction_positions: Array[Vector3] = []
var discovered_extraction_indices: Dictionary = {}
var sealed_extraction_indices: Dictionary = {}
var corpse_recovery_position := Vector3.INF
var corpse_recovery_available := false
var boss_targets: Array[Node3D] = []
var extraction_profiles: Array[Dictionary] = []
var raid_markers: Array[Dictionary] = []
var visited_cells: Dictionary = {}
var manual_marker_position := Vector3.INF
var current_bag_value := 0
var current_bag_slots := 0
var current_bag_capacity := 0
var current_risk_label := "위험 정보 확인 중"
var visit_update_timer := 0.0
var last_map_rect := Rect2()
var last_map_size := 0.0
var map_paused_tree := false
var tree_was_paused_before_map := false
var opened_at_msec := 0
var close_button: Button
# 마커 라벨은 그리는 자리에서 바로 찍지 않고 여기 모았다가 마지막에 한 번에
# 배치한다. "내 위치"와 "불명 격리 신호"가 정면 충돌해 둘 다 못 읽던 문제 때문.
var pending_labels: Array[Dictionary] = []

# 라벨이 겹칠 때 위아래로 시도해 볼 오프셋. 다 막히면 그 라벨은 접는다.
const LABEL_NUDGES: Array[float] = [0.0, -15.0, 15.0, -30.0, 30.0, -45.0, 45.0]
# 라벨 우선순위 — 숫자가 큰 쪽이 먼저 자리를 잡는다.
const LABEL_PRIORITY_NOTICE := 110
const LABEL_PRIORITY_PLAYER := 100
const LABEL_PRIORITY_BOSS := 80
const LABEL_PRIORITY_CORPSE := 70
const LABEL_PRIORITY_MANUAL := 60
const LABEL_PRIORITY_EVENT := 50
const LABEL_PRIORITY_HOTSPOT := 40
const LABEL_PRIORITY_EXTRACTION := 30


func setup(
	world_node: Node3D,
	player_node: Node3D,
	extraction_world_positions: Array[Vector3],
	recovery_position: Vector3 = Vector3.INF
) -> void:
	world = world_node
	player = player_node
	extraction_positions.assign(extraction_world_positions)
	discovered_extraction_indices.clear()
	extraction_profiles.clear()
	raid_markers.clear()
	visited_cells.clear()
	manual_marker_position = Vector3.INF
	set_corpse_recovery(recovery_position)
	_record_player_visit(true)


func set_raid_status(bag_value: int, used_slots: int, capacity: int, risk_label: String) -> void:
	current_bag_value = maxi(0, bag_value)
	current_bag_slots = maxi(0, used_slots)
	current_bag_capacity = maxi(0, capacity)
	current_risk_label = risk_label
	queue_redraw()


func set_corpse_recovery(world_position: Vector3) -> void:
	corpse_recovery_position = world_position
	corpse_recovery_available = world_position != Vector3.INF
	queue_redraw()


func clear_corpse_recovery() -> void:
	corpse_recovery_position = Vector3.INF
	corpse_recovery_available = false
	queue_redraw()


func register_boss(boss: Node3D) -> void:
	if not is_instance_valid(boss) or boss_targets.has(boss):
		return
	boss_targets.append(boss)
	queue_redraw()


func discover_extraction(index: int) -> void:
	if index < 0 or index >= extraction_positions.size():
		return
	discovered_extraction_indices[index] = true
	queue_redraw()


func seal_extraction(index: int) -> void:
	# 봉쇄된 탈출로는 지도에서 죽은 표시로 남는다. 사라지면 플레이어가
	# 그 경로를 계속 계획에 넣는다.
	if index < 0 or index >= extraction_positions.size():
		return
	sealed_extraction_indices[index] = true
	discovered_extraction_indices[index] = true
	queue_redraw()


func set_extraction_profiles(profiles: Array[Dictionary]) -> void:
	extraction_profiles.assign(profiles)
	queue_redraw()


func register_raid_marker(
	marker_id: String,
	world_position: Vector3,
	marker_type: String,
	label: String,
	discovered: bool = false,
	radius: float = 0.0
) -> void:
	# radius(월드 단위)는 선택 항목이다. 0보다 크면 마커 둘레에 반투명 원을 그린다 —
	# "그 자리를 지켜라"류 목표가 어디까지가 안쪽인지 지도에서 보이게 하기 위한 것.
	# 기존 호출은 인자를 안 주므로 0.0 = 원 없음, 동작 불변.
	if marker_id.is_empty():
		return
	for marker in raid_markers:
		if str(marker.get("id", "")) != marker_id:
			continue
		marker["position"] = world_position
		marker["type"] = marker_type
		marker["label"] = label
		marker["discovered"] = discovered
		marker["radius"] = maxf(0.0, radius)
		queue_redraw()
		return
	raid_markers.append({
		"id": marker_id,
		"position": world_position,
		"type": marker_type,
		"label": label,
		"discovered": discovered,
		"radius": maxf(0.0, radius),
	})
	queue_redraw()


func discover_raid_marker(marker_id: String) -> void:
	for marker in raid_markers:
		if str(marker.get("id", "")) == marker_id:
			marker["discovered"] = true
			queue_redraw()
			return


func remove_raid_marker(marker_id: String) -> void:
	for marker in raid_markers.duplicate():
		if str(marker.get("id", "")) == marker_id:
			raid_markers.erase(marker)
	queue_redraw()


func is_extraction_discovered(index: int) -> bool:
	return bool(discovered_extraction_indices.get(index, false))


func _ready() -> void:
	name = "TacticalMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button = Button.new()
	close_button.name = "MapCloseButton"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -78.0
	close_button.offset_top = 18.0
	close_button.offset_right = -18.0
	close_button.offset_bottom = 78.0
	close_button.icon = UI_ICONS.get_icon("close", 30, Color("#e7ece8"))
	close_button.expand_icon = true
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "지도 닫기"
	close_button.add_theme_stylebox_override("normal", _map_button_style(
		Color(0.035, 0.046, 0.045, 0.98),
		Color("#6e837b")
	))
	close_button.add_theme_stylebox_override("hover", _map_button_style(
		Color(0.07, 0.083, 0.078, 1.0),
		Color("#d3bd79")
	))
	close_button.add_theme_stylebox_override("pressed", _map_button_style(
		Color(0.095, 0.079, 0.044, 1.0),
		Color("#f0cf72")
	))
	close_button.pressed.connect(close)
	add_child(close_button)
	if not get_viewport().size_changed.is_connected(_apply_safe_layout):
		get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_safe_layout()


func _apply_safe_layout() -> void:
	if not is_instance_valid(close_button):
		return
	var safe := UISafeArea.get_margins(get_viewport().get_visible_rect().size)
	close_button.offset_left = -78.0 - safe.z
	close_button.offset_top = 18.0 + safe.y
	close_button.offset_right = -18.0 - safe.z
	close_button.offset_bottom = 78.0 + safe.y


func toggle() -> void:
	if visible:
		close()
		return
	visible = true
	# 전투 중 수시로 여닫는 전면 모달 — 툭 나타나지 않게 표준 등장 모션.
	HudStyle.enter_modal(self)
	opened_at_msec = Time.get_ticks_msec()
	tree_was_paused_before_map = get_tree().paused
	if not tree_was_paused_before_map:
		get_tree().paused = true
		map_paused_tree = true
	open_state_changed.emit(true)
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	if map_paused_tree:
		get_tree().paused = tree_was_paused_before_map
	map_paused_tree = false
	open_state_changed.emit(false)


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible or Time.get_ticks_msec() - opened_at_msec < 180:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		if key in [KEY_TAB, KEY_ESCAPE]:
			close()
			get_viewport().set_input_as_handled()
		return
	# 닫기 버튼을 터치로 누르면 아무 일도 안 나던 문제(유저 신고). Button은
	# InputEventScreenTouch를 처리하지 않고, Godot의 마우스 에뮬레이션은 첫
	# 손가락만 따라간다 — 조이스틱을 잡은 손가락이 아직 눌린 채면 두 번째
	# 손가락의 탭은 에뮬레이션도 GUI 포커스도 못 받아 통째로 사라진다.
	# 그래서 닫기 판정을 GUI가 아니라 여기(_input)에서 직접 한다.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if _is_close_button_point((event as InputEventScreenTouch).position):
			close()
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if map_paused_tree and is_instance_valid(get_tree()):
		get_tree().paused = tree_was_paused_before_map


func _notification(what: int) -> void:
	# 안드로이드 뒤로가기 = 지도 닫기.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close()


func _process(delta: float) -> void:
	visit_update_timer -= delta
	if visit_update_timer <= 0.0:
		visit_update_timer = 0.25
		_record_player_visit(false)
	if visible:
		queue_redraw()


func _is_close_button_point(point: Vector2) -> bool:
	if not is_instance_valid(close_button) or not close_button.visible:
		return false
	# 손가락은 픽셀 단위로 정확하지 않다 — 버튼 테두리 바깥 14px까지 닫기로 친다.
	return close_button.get_rect().grow(14.0).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	# 닫기 버튼을 '터치'로 누르면 아무 일도 안 나던 문제(유저 신고).
	# Button은 InputEventScreenTouch를 처리하지 않고, 마우스 에뮬레이션은 첫
	# 손가락만 따라간다 — 조이스틱을 잡았던 손가락이 걸려 있으면 탭이 통째로
	# 사라진다. 그래서 닫기 판정을 지도 본체가 직접 한다. 표식 찍기보다 먼저.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if _is_close_button_point((event as InputEventScreenTouch).position):
			close()
			accept_event()
			return
	if last_map_rect.size.x <= 0.0 or last_map_size <= 0.0:
		return
	var pointer_position := Vector2.ZERO
	var should_mark := false
	var should_clear := false
	if event is InputEventMouseButton and event.pressed:
		pointer_position = event.position
		should_mark = event.button_index == MOUSE_BUTTON_LEFT
		should_clear = event.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventScreenTouch and event.pressed:
		pointer_position = event.position
		# 터치엔 우클릭이 없다 — 기존 표식 근처를 다시 탭하면 삭제(토글).
		if (
			manual_marker_position != Vector3.INF
			and _world_position_to_map_point(
				manual_marker_position, last_map_rect, last_map_size
			).distance_to(pointer_position) < 34.0
		):
			should_clear = true
		else:
			should_mark = true
	# 닫기 버튼 자리에는 표식을 찍지 않는다 — 닫으려다 표식만 남던 오조작 방지.
	if (should_mark or should_clear) and _is_close_button_point(pointer_position):
		return
	if should_clear:
		manual_marker_position = Vector3.INF
		queue_redraw()
		accept_event()
		return
	if should_mark:
		var world_position := _map_point_to_world_position(pointer_position, last_map_rect, last_map_size)
		if world_position != Vector3.INF:
			manual_marker_position = world_position
			queue_redraw()
			accept_event()


func _record_player_visit(force: bool) -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	if not world.has_method("get_map_snapshot_data"):
		return
	var data: Dictionary = world.call("get_map_snapshot_data")
	var grid_size := maxi(1, int(data.get("grid_size", 22)))
	var map_size := maxf(1.0, float(data.get("map_size", grid_size * 20.0)))
	var cell_size := map_size / float(grid_size)
	var half_map := map_size * 0.5
	var center_x := clampi(floori((player.global_position.x + half_map) / cell_size), 0, grid_size - 1)
	var center_z := clampi(floori((player.global_position.z + half_map) / cell_size), 0, grid_size - 1)
	var changed := false
	for z_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var cell := Vector2i(center_x + x_offset, center_z + z_offset)
			if cell.x < 0 or cell.y < 0 or cell.x >= grid_size or cell.y >= grid_size:
				continue
			if not visited_cells.has(cell):
				visited_cells[cell] = true
				changed = true
	if force or changed:
		queue_redraw()


func _draw() -> void:
	var viewport_size := size
	# 딤이 0.91이라 아래 필드 HUD(layer 130)가 그대로 비쳐 보였다. 지도는 전면
	# 모달이다 — 여는 순간 필드 화면은 완전히 덮는다(등장 페이드는 modulate가 맡는다).
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.004, 0.007, 0.008, 1.0))
	pending_labels.clear()
	if not is_instance_valid(world):
		return
	var panel_size := Vector2(minf(1040.0, viewport_size.x - 64.0), minf(720.0, viewport_size.y - 54.0))
	var panel_rect := Rect2((viewport_size - panel_size) * 0.5, panel_size)
	draw_style_box(_panel_style(), panel_rect)
	draw_string(UI_FONT, panel_rect.position + Vector2(28, 40), "현장 전술 지도", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#e4e1d3"))
	# 부제는 개발 메모("이동한 구역만 기록 · 탭: 개인 표식")가 그대로 남아 있었다.
	# 플레이어에게 하는 말로 고쳐 쓴다.
	var map_hint := (
		"가 본 곳만 지도에 남는다 · 탭하면 표식, 다시 탭하면 삭제 · 보는 동안 전투는 멈춘다"
		if DisplayServer.is_touchscreen_available()
		else "가 본 곳만 지도에 남는다 · 클릭하면 표식, 우클릭하면 삭제 · 보는 동안 전투는 멈춘다"
	)
	# 세로 화면에서는 패널이 좁다 — 문장을 자르는 대신 글자를 한 단계씩 줄여 담는다.
	var hint_size := 14
	var hint_limit := panel_rect.size.x - 56.0
	while (
		hint_size > 10
		and UI_FONT.get_string_size(map_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x > hint_limit
	):
		hint_size -= 1
	draw_string(UI_FONT, panel_rect.position + Vector2(28, 65), map_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color("#aebbb4"))

	var data: Dictionary = world.call("get_map_snapshot_data")
	var grid_size := int(data.get("grid_size", 22))
	var map_size := float(data.get("map_size", grid_size * 20.0))
	var map_rect := Rect2(panel_rect.position + Vector2(52, 78), panel_rect.size - Vector2(104, 142))
	last_map_rect = map_rect
	last_map_size = map_size
	var map_center := map_rect.get_center()
	var map_boundary := PackedVector2Array([
		map_center + Vector2(0, -map_rect.size.y * 0.49),
		map_center + Vector2(map_rect.size.x * 0.49, 0),
		map_center + Vector2(0, map_rect.size.y * 0.49),
		map_center + Vector2(-map_rect.size.x * 0.49, 0),
	])
	draw_colored_polygon(map_boundary, Color("#171d1c"))
	var vertical_roads: Array = data.get("vertical_roads", [])
	var horizontal_roads: Array = data.get("horizontal_roads", [])
	var river_columns: Array = data.get("river_columns", [])
	for z in grid_size:
		for x in grid_size:
			var cell_polygon := _cell_polygon(x, z, grid_size, map_rect)
			var is_visited := visited_cells.has(Vector2i(x, z))
			var fill_color := Color("#151918")
			if z < river_columns.size() and int(river_columns[z]) == x:
				fill_color = Color("#234653") if is_visited else Color("#12242a")
			elif vertical_roads.has(x) or horizontal_roads.has(z):
				fill_color = Color("#474d4b") if is_visited else Color("#202523")
			elif is_visited:
				fill_color = Color("#252c2a")
			draw_colored_polygon(cell_polygon, fill_color)
			if is_visited:
				draw_polyline(_closed_polygon(cell_polygon), Color(0.44, 0.5, 0.47, 0.16), 1.0)

	for cell_value in data.get("building_cells", []):
		var cell: Vector2i = cell_value
		if not visited_cells.has(cell):
			continue
		var building_polygon := _shrink_polygon(_cell_polygon(cell.x, cell.y, grid_size, map_rect), 0.76)
		draw_colored_polygon(building_polygon, Color("#101514"))
		draw_polyline(_closed_polygon(building_polygon), Color("#69726d"), 1.2)

	var marker_size := clampf(map_rect.size.x / float(grid_size) * 0.86, 15.0, 28.0)
	var player_center := Vector2.ZERO
	if is_instance_valid(player):
		player_center = _world_position_to_map_point(player.global_position, map_rect, map_size)
	var nearest_extraction := Vector2.ZERO
	var nearest_distance := INF
	for extraction_index in extraction_positions.size():
		if not is_extraction_discovered(extraction_index):
			continue
		var extraction_position := extraction_positions[extraction_index]
		var extraction_center := _world_position_to_map_point(extraction_position, map_rect, map_size)
		var profile := (
			extraction_profiles[extraction_index]
			if extraction_index < extraction_profiles.size()
			else {}
		) as Dictionary
		var route_color: Color = profile.get("color", Color("#dcb64b"))
		var route_multiplier := float(profile.get("multiplier", 1.0))
		if is_instance_valid(player):
			var distance := player.global_position.distance_to(extraction_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_extraction = extraction_center
		draw_circle(
			extraction_center,
			marker_size * 0.72,
			Color(route_color.r, route_color.g, route_color.b, 0.18)
		)
		draw_circle(extraction_center, marker_size * 0.48, route_color, false, 3.0)
		draw_line(
			extraction_center + Vector2(0, -marker_size * 0.35),
			extraction_center + Vector2(0, marker_size * 0.28),
			route_color.lightened(0.24),
			2.0
		)
		draw_circle(extraction_center, 2.5, route_color.lightened(0.32))
		_queue_label(
			extraction_center + Vector2(marker_size * 0.62, marker_size * 0.18),
			"×%.2f" % route_multiplier,
			13,
			route_color.lightened(0.18),
			LABEL_PRIORITY_EXTRACTION,
			74.0
		)

	for marker in raid_markers:
		if not bool(marker.get("discovered", false)):
			continue
		var marker_center := _world_position_to_map_point(
			marker.get("position", Vector3.ZERO),
			map_rect,
			map_size
		)
		var marker_type := str(marker.get("type", "hotspot"))
		var marker_color := Color("#65d5ca")
		if marker_type == "incident":
			marker_color = Color("#ef7252")
		elif marker_type == "jackpot":
			marker_color = Color("#f0ad4f")
		var marker_pulse := 0.5 + 0.5 * sin(
			Time.get_ticks_msec() * (0.011 if marker_type == "incident" else 0.006)
		)
		# 사수 반경 같은 '구역' 마커는 월드 반경을 그대로 깐다. 이 지도는 아이소메트릭
		# 이라 화면 원을 그리면 실제 구역과 어긋난다 — 월드에서 원을 샘플링해 투영한다.
		var world_radius := float(marker.get("radius", 0.0))
		if world_radius > 0.0 and map_size > 0.0:
			var zone_center: Vector3 = marker.get("position", Vector3.ZERO)
			var zone_polygon := PackedVector2Array()
			for step in 32:
				var angle := TAU * float(step) / 32.0
				zone_polygon.append(_world_position_to_map_point(
					zone_center + Vector3(cos(angle), 0.0, sin(angle)) * world_radius,
					map_rect,
					map_size
				))
			draw_colored_polygon(
				zone_polygon,
				Color(marker_color.r, marker_color.g, marker_color.b, 0.13)
			)
			draw_polyline(
				_closed_polygon(zone_polygon),
				Color(marker_color.r, marker_color.g, marker_color.b, 0.55 + marker_pulse * 0.3),
				2.0
			)
		var marker_radius := marker_size * (0.42 + marker_pulse * 0.08)
		draw_circle(
			marker_center,
			marker_radius * 1.55,
			Color(marker_color.r, marker_color.g, marker_color.b, 0.14)
		)
		var diamond := PackedVector2Array([
			marker_center + Vector2(0, -marker_radius),
			marker_center + Vector2(marker_radius, 0),
			marker_center + Vector2(0, marker_radius),
			marker_center + Vector2(-marker_radius, 0),
		])
		draw_colored_polygon(
			diamond,
			Color(
				marker_color.r,
				marker_color.g,
				marker_color.b,
				0.78 if marker_type in ["incident", "jackpot"] else 0.42
			)
		)
		draw_polyline(_closed_polygon(diamond), marker_color.lightened(0.18), 2.0)
		draw_circle(marker_center, marker_radius * 0.22, Color("#f5f0d5"))
		_queue_label(
			marker_center + Vector2(marker_radius + 6.0, -marker_radius * 0.3),
			str(marker.get("label", "고가치 지점")),
			13,
			marker_color.lightened(0.2),
			(
				LABEL_PRIORITY_EVENT
				if marker_type in ["incident", "jackpot"]
				else LABEL_PRIORITY_HOTSPOT
			),
			150.0
		)

	if corpse_recovery_available:
		var corpse_center := _world_position_to_map_point(
			corpse_recovery_position,
			map_rect,
			map_size
		)
		var corpse_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		draw_circle(
			corpse_center,
			marker_size * (0.72 + corpse_pulse * 0.16),
			Color(0.95, 0.35, 0.12, 0.18)
		)
		draw_circle(corpse_center, marker_size * 0.5, Color("#ef8b45"), false, 3.0)
		draw_line(
			corpse_center + Vector2(-marker_size * 0.28, -marker_size * 0.28),
			corpse_center + Vector2(marker_size * 0.28, marker_size * 0.28),
			Color("#ffd0a2"),
			3.0
		)
		draw_line(
			corpse_center + Vector2(marker_size * 0.28, -marker_size * 0.28),
			corpse_center + Vector2(-marker_size * 0.28, marker_size * 0.28),
			Color("#ffd0a2"),
			3.0
		)
		_queue_label(
			corpse_center + Vector2(marker_size * 0.7, -marker_size * 0.55),
			"분실 장비",
			15,
			Color("#ffd0a2"),
			LABEL_PRIORITY_CORPSE,
			110.0
		)

	if manual_marker_position != Vector3.INF:
		var manual_center := _world_position_to_map_point(manual_marker_position, map_rect, map_size)
		var manual_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
		var manual_radius := marker_size * (0.48 + manual_pulse * 0.08)
		draw_circle(manual_center, manual_radius * 1.65, Color(0.95, 0.79, 0.32, 0.14))
		draw_circle(manual_center, manual_radius, Color("#f2cb62"), false, 3.0)
		draw_circle(manual_center, 3.0, Color("#fff2bf"))
		_queue_label(
			manual_center + Vector2(manual_radius + 7.0, 4.0),
			"개인 표식",
			13,
			Color("#f2d481"),
			LABEL_PRIORITY_MANUAL,
			90.0
		)

	for boss in boss_targets.duplicate():
		if not is_instance_valid(boss) or bool(boss.get("dying")):
			boss_targets.erase(boss)
			continue
		var boss_center := _world_position_to_map_point(
			boss.global_position,
			map_rect,
			map_size
		)
		var boss_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.013)
		var boss_radius := marker_size * (0.72 + boss_pulse * 0.18)
		draw_circle(boss_center, boss_radius, Color(1.0, 0.14, 0.08, 0.18))
		draw_circle(boss_center, marker_size * 0.5, Color("#ff5747"), false, 3.0)
		var diamond := PackedVector2Array([
			boss_center + Vector2(0, -marker_size * 0.42),
			boss_center + Vector2(marker_size * 0.36, 0),
			boss_center + Vector2(0, marker_size * 0.42),
			boss_center + Vector2(-marker_size * 0.36, 0),
		])
		draw_colored_polygon(diamond, Color("#ff6a52"))
		draw_polyline(_closed_polygon(diamond), Color("#fff0d2"), 2.0)
		_queue_label(
			boss_center + Vector2(marker_size * 0.68, -marker_size * 0.52),
			str(boss.get_meta("display_name", "위험 개체")),
			15,
			Color("#ffc4a8"),
			LABEL_PRIORITY_BOSS,
			160.0
		)

	if is_instance_valid(player):
		if nearest_distance < INF:
			draw_line(player_center, nearest_extraction, Color(0.87, 0.73, 0.3, 0.34), 2.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		var outer_radius := marker_size + 5.0 + pulse * 6.0
		var inner_radius := maxf(8.0, marker_size * 0.42)
		draw_circle(player_center, outer_radius, Color(0.25, 1.0, 0.78, 0.16))
		draw_circle(player_center, outer_radius, Color.WHITE, false, 4.0)
		draw_circle(player_center, outer_radius - 3.0, Color("#5dffd0"), false, 2.0)
		draw_circle(player_center, inner_radius, Color("#07110f"))
		draw_circle(player_center, inner_radius * 0.72, Color("#65ffd2"))
		_draw_player_heading(player_center, marker_size * 1.35, map_rect)
		var sector := str(world.call("get_sector_label", player.global_position))
		var label_position := player_center + Vector2(outer_radius + 7.0, -outer_radius * 0.45)
		_queue_label(
			label_position,
			"내 위치  %s" % sector,
			17,
			Color.WHITE,
			LABEL_PRIORITY_PLAYER
		)
		# 가방이 넘치면 그 자리에서 루팅이 막힌다 — 만재는 경고색으로 말한다.
		var bag_full := current_bag_slots >= current_bag_capacity
		var footer := "현재 %s   ·   %s %d/%d칸   ·   회수 가치 %s   ·   %s" % [
			sector,
			"가방 만재" if bag_full else "가방",
			current_bag_slots,
			current_bag_capacity,
			_compact_number(current_bag_value),
			current_risk_label,
		]
		if nearest_distance < INF:
			footer += "   ·   발견 탈출구 %.0fm" % nearest_distance
		draw_string(
			UI_FONT,
			panel_rect.position + Vector2(28, panel_rect.size.y - 22),
			footer,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("#ff9595") if bag_full else Color("#d7d4b9")
		)
	if discovered_extraction_indices.is_empty():
		_queue_label(
			map_rect.get_center() + Vector2(-170, 6),
			"탈출구 미발견 · 직접 시야로 찾아야 합니다",
			17,
			Color("#d9c579"),
			LABEL_PRIORITY_NOTICE,
			340.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	draw_polyline(_closed_polygon(map_boundary), Color("#7c8982"), 2.0)
	_draw_queued_labels(panel_rect.grow(-16.0))


func _queue_label(
	baseline: Vector2,
	text: String,
	font_size: int,
	color: Color,
	priority: int,
	clip_width: float = -1.0,
	alignment: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	if text.is_empty():
		return
	pending_labels.append({
		"baseline": baseline,
		"text": text,
		"size": font_size,
		"color": color,
		"priority": priority,
		"clip": clip_width,
		"alignment": alignment,
	})


func _draw_queued_labels(bounds: Rect2) -> void:
	# 마커 라벨을 그리던 자리에서 바로 찍으면 "내 위치"와 사건 라벨이 같은 픽셀에
	# 겹쳐 둘 다 못 읽는다. 중요한 라벨부터 자리를 잡고, 겹치면 위아래로 조금씩
	# 밀어 본다. 끝까지 자리가 없으면 그 라벨은 접는다 — 마커 아이콘은 그대로 남는다.
	if pending_labels.is_empty():
		return
	pending_labels.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["priority"]) > int(right["priority"])
	)
	var taken: Array[Rect2] = []
	for entry in pending_labels:
		var font_size := int(entry["size"])
		var text := str(entry["text"])
		var clip := float(entry["clip"])
		var alignment := int(entry["alignment"])
		var measured := UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box_width := measured.x
		if clip > 0.0:
			# 왼쪽 정렬은 실제 글자 폭까지만, 가운데 정렬은 지정한 상자 폭 전체를 쓴다.
			box_width = clip if alignment != HORIZONTAL_ALIGNMENT_LEFT else minf(measured.x, clip)
		var ascent := UI_FONT.get_ascent(font_size)
		var line_height := UI_FONT.get_height(font_size)
		var origin: Vector2 = entry["baseline"]
		var placed := Vector2.INF
		for nudge in LABEL_NUDGES:
			var candidate := Vector2(
				clampf(origin.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - box_width)),
				clampf(origin.y + nudge, bounds.position.y + ascent, bounds.end.y)
			)
			var rect := Rect2(
				candidate.x, candidate.y - ascent, box_width, line_height
			).grow_individual(2.0, 1.0, 2.0, 1.0)
			var free := true
			for occupied in taken:
				if occupied.intersects(rect):
					free = false
					break
			if free:
				taken.append(rect)
				placed = candidate
				break
		if placed == Vector2.INF:
			continue
		draw_string(
			UI_FONT, placed, text, alignment, clip, font_size, entry["color"] as Color
		)
	pending_labels.clear()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.034, 0.034, 0.98)
	style.border_color = Color(0.35, 0.38, 0.36, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _map_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _world_position_to_map_point(world_position: Vector3, map_rect: Rect2, map_size: float) -> Vector2:
	var half_map := map_size * 0.5
	var normalized := Vector2(
		clampf((world_position.x + half_map) / map_size, 0.0, 1.0),
		clampf((world_position.z + half_map) / map_size, 0.0, 1.0)
	)
	return _normalized_to_isometric(normalized, map_rect)


func _map_point_to_world_position(point: Vector2, map_rect: Rect2, map_size: float) -> Vector3:
	var center := map_rect.get_center()
	var iso_x := (point.x - center.x) / maxf(1.0, map_rect.size.x * 0.49)
	var iso_y := (point.y - center.y) / maxf(1.0, map_rect.size.y * 0.49)
	var normalized_x := (iso_x + iso_y + 1.0) * 0.5
	var normalized_z := (iso_y + 1.0 - iso_x) * 0.5
	if normalized_x < 0.0 or normalized_x > 1.0 or normalized_z < 0.0 or normalized_z > 1.0:
		return Vector3.INF
	var half_map := map_size * 0.5
	return Vector3(normalized_x * map_size - half_map, 0.0, normalized_z * map_size - half_map)


func _compact_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


func _draw_player_heading(center: Vector2, length: float, map_rect: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var forward_3d: Vector3 = player.get_meta("tactical_heading", -player.global_transform.basis.z)
	var direction := Vector2(
		forward_3d.x - forward_3d.z,
		(forward_3d.x + forward_3d.z) * (map_rect.size.y / map_rect.size.x)
	)
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var tip := center + direction * length
	var side := Vector2(-direction.y, direction.x)
	var back := center + direction * (length * 0.25)
	var points := PackedVector2Array([
		tip,
		back + side * length * 0.32,
		back - side * length * 0.32,
	])
	draw_colored_polygon(points, Color("#8fffd0"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("#06100e"), 2.0)


func _normalized_to_isometric(normalized: Vector2, map_rect: Rect2) -> Vector2:
	var center := map_rect.get_center()
	return center + Vector2(
		(normalized.x - normalized.y) * map_rect.size.x * 0.49,
		(normalized.x + normalized.y - 1.0) * map_rect.size.y * 0.49
	)


func _cell_polygon(x: int, z: int, grid_size: int, map_rect: Rect2) -> PackedVector2Array:
	var inverse_grid := 1.0 / float(grid_size)
	return PackedVector2Array([
		_normalized_to_isometric(Vector2(x, z) * inverse_grid, map_rect),
		_normalized_to_isometric(Vector2(x + 1, z) * inverse_grid, map_rect),
		_normalized_to_isometric(Vector2(x + 1, z + 1) * inverse_grid, map_rect),
		_normalized_to_isometric(Vector2(x, z + 1) * inverse_grid, map_rect),
	])


func _shrink_polygon(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point in points:
		result.append(center.lerp(point, factor))
	return result


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
