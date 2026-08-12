class_name EnemyAlertOverlay
extends Control

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var player: Node3D
var camera: Camera3D


func setup(player_node: Node3D, active_camera: Camera3D) -> void:
	player = player_node
	camera = active_camera


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 480


func _process(_delta: float) -> void:
	queue_redraw()


const ALERT_RANGE := 26.0

func _draw() -> void:
	# 모바일 한정 — 데스크톱은 시야가 넓어 마커가 소음이 된다.
	if not DisplayServer.is_touchscreen_available():
		return
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var safe_rect := viewport_rect.grow(-48.0)
	# 방향 기준은 화면 중앙이 아니라 플레이어의 화면 위치다.
	var center := camera.unproject_position(player.global_position)
	var drawn_sectors := {}
	for node in get_tree().get_nodes_in_group("raid_enemy"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var enemy := node as Node3D
		if bool(enemy.get("dying")) or not bool(enemy.get("alerted")):
			continue
		# 정확도의 핵심 두 가지: ① 나를 노리는 적만(세력 간 교전으로 경계된 적 제외),
		# ② 실제 위협 거리 안의 적만. 예전엔 50m 밖 무관한 적도 떠서
		# "가 보면 아무도 없는" 마커가 됐다.
		if enemy.get("target") != player:
			continue
		var to_enemy: Vector3 = enemy.global_position - player.global_position
		to_enemy.y = 0.0
		if to_enemy.length() > ALERT_RANGE:
			continue
		var world_point := enemy.global_position + Vector3(0.0, 1.7, 0.0)
		var screen_point := camera.unproject_position(world_point)
		var behind := camera.is_position_behind(world_point)
		var player_visibility := float(enemy.get("player_visibility_factor"))
		var on_screen := safe_rect.has_point(screen_point) and not behind and player_visibility > 0.08
		if on_screen:
			continue
		var direction := screen_point - center
		if behind:
			direction = -direction
		if direction.length_squared() < 0.01:
			direction = Vector2.UP
		var normalized_direction := direction.normalized()
		var sector_key := roundi(atan2(normalized_direction.y, normalized_direction.x) / deg_to_rad(22.5))
		if drawn_sectors.has(sector_key):
			continue
		drawn_sectors[sector_key] = true
		var marker_position := _edge_position(center, normalized_direction, safe_rect)
		_draw_alert_marker(marker_position, normalized_direction)


func _edge_position(center: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var half_size := bounds.size * 0.5
	var scale_x := half_size.x / maxf(absf(direction.x), 0.001)
	var scale_y := half_size.y / maxf(absf(direction.y), 0.001)
	return center + direction * minf(scale_x, scale_y)


func _draw_alert_marker(position: Vector2, direction: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var radius := 20.0 + pulse * 3.0
	draw_circle(position, radius + 7.0, Color(0.12, 0.008, 0.005, 0.62))
	draw_circle(position, radius, Color(0.96, 0.18, 0.08, 0.92))
	draw_arc(position, radius + 4.0, 0.0, TAU, 32, Color(1.0, 0.72, 0.32, 0.82), 2.0)
	draw_string(FONT, position + Vector2(-5.0, 8.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 10.0, 27, Color.WHITE)
	var inward := -direction
	var side := Vector2(-inward.y, inward.x)
	var arrow_tip := position + inward * (radius + 16.0)
	var arrow_points := PackedVector2Array([
		arrow_tip,
		position + inward * (radius + 4.0) + side * 7.0,
		position + inward * (radius + 4.0) - side * 7.0,
	])
	draw_colored_polygon(arrow_points, Color("#ffd06a"))
