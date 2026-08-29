extends SceneTree

# 엄폐 v2 스크린샷 프로브(창 필요 — --headless 금지).
#   1) cover_v2_player_covered.png : 플레이어 covered — 청록 방패 호 + 웅크림 + HUD 칩
#   2) cover_v2_enemy_covered.png  : 적 covered — 발밑 붉은 호 + 웅크림
#   3) cover_v2_block_feedback.png : 차단 스파크 + "막힘" 라벨
#
# 실행: godot --path . --script tests/cover_v2_visual_capture.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const PLAYER_OUTPUT := "res://test-output/cover_v2_player_covered.png"
const ENEMY_OUTPUT := "res://test-output/cover_v2_enemy_covered.png"
const BLOCK_OUTPUT := "res://test-output/cover_v2_block_feedback.png"

var main_scene: Node
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("COVER_V2_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	await create_timer(0.8, true, false, true).timeout
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while (
		main_mission != null
		and bool(main_mission.call("is_cinematic_active"))
		and skip_guard < 20
	):
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.25, true, false, true).timeout
	await create_timer(0.6, true, false, true).timeout
	player = main_scene.get_node("Player") as CharacterBody3D
	player.collision_layer = 0
	# 충돌 디버그 풋프린트(기본 ON, priority 120)가 호·적 스프라이트를 덮는다 — 끈다.
	var world_map := main_scene.get_node("World")
	if world_map.has_method("set_collision_debug_enabled"):
		world_map.call("set_collision_debug_enabled", false)
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D

	# 엄폐 기하가 성립하는 도로 커버를 찾는다.
	var cover_system = main_scene.get("cover_system")
	var world := main_scene.get_node("World")
	var chosen_center := Vector3.INF
	var chosen_normal := Vector3.ZERO
	var chosen_depth := 0.0
	for child in world.get_children():
		if not child.is_in_group("road_cover_obstacle") or not child.has_node("CoverCollision"):
			continue
		var collision := child.get_node("CoverCollision") as CollisionShape3D
		var size: Vector3 = (collision.shape as BoxShape3D).size
		var center := collision.global_position
		var normal := Vector3(0.0, 0.0, 1.0) if size.x >= size.z else Vector3(1.0, 0.0, 0.0)
		var depth := size.z if size.x >= size.z else size.x
		player.global_position = Vector3(center.x, 0.78, center.z) + normal * (depth * 0.5 + 0.7)
		player.force_update_transform()
		await physics_frame
		var source_position := Vector3(center.x, 0.7, center.z) - normal * 7.0
		if bool(cover_system.call("is_covered_from", source_position)):
			chosen_center = Vector3(center.x, 0.0, center.z)
			chosen_normal = normal
			chosen_depth = depth
			break
	if chosen_center == Vector3.INF:
		push_error("엄폐 기하를 만족하는 도로 커버를 찾지 못했습니다.")
		quit(1)
		return
	var source_position := chosen_center + Vector3(0.0, 0.7, 0.0) - chosen_normal * 7.0

	# 카메라가 플레이어를 따라잡게 잠시 굴린 뒤 메인 갱신을 멈춘다.
	await create_timer(1.0, true, false, true).timeout
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= 0.62

	await _capture_player_covered(cover_system)
	await _capture_block_feedback(cover_system, source_position)
	await _capture_enemy_covered(cover_system)
	quit(0)


func _set_hud_visible(value: bool) -> void:
	(main_scene.get_node("HUD") as CanvasLayer).visible = value


# ── 샷 1: 플레이어 covered — 청록 호 + 웅크림 + 칩 ─────────────────

func _capture_player_covered(cover_system) -> void:
	_set_hud_visible(true)
	var hud_node = main_scene.get("hud")
	var toast_stack := hud_node.get("toast_stack") as Node
	if toast_stack != null:
		for toast in toast_stack.get_children():
			toast.queue_free()
		await process_frame
	main_scene.set("laser_aim_held", false)
	main_scene.set("fire_button_held", false)
	main_scene.set("mouse_fire_held", false)
	cover_system.set("in_cover", true)
	cover_system.set("exposed_time", 0.0)
	cover_system.call("_update_player_visuals")
	main_scene.call("_update_cover_feedback")
	await create_timer(0.3, true, false, true).timeout
	cover_system.call("_update_player_visuals")
	main_scene.call("_update_cover_feedback")
	await process_frame
	var survivor := main_scene.get("survivor") as AnimatedSprite3D
	var arc_pivot := cover_system.get("arc_pivot") as Node3D
	var arc_fill := cover_system.get("arc_fill") as Sprite3D
	print("ARC_DEBUG pivot=%s visible=%s fill_visible=%s fill_modulate=%s pivot_world=%s player=%s" % [
		str(arc_pivot), str(arc_pivot.visible if arc_pivot != null else false),
		str(arc_fill.visible if arc_fill != null else false),
		str(arc_fill.modulate if arc_fill != null else Color.BLACK),
		str(arc_pivot.global_position if arc_pivot != null else Vector3.INF),
		str(player.global_position),
	])
	_capture(PLAYER_OUTPUT, "state=%s squash=%.2f chip=%s" % [
		str(cover_system.call("get_state")),
		survivor.scale.y,
		str(hud_node.get("cover_chip_state")),
	])
	# 근접 확대 디버그 컷.
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	var old_size := camera.size
	camera.size = old_size * 0.35
	await process_frame
	await process_frame
	_capture("res://test-output/cover_v2_player_closeup.png", "closeup")
	camera.size = old_size
	await process_frame


# ── 샷 3(순서상 두 번째): 차단 스파크 + "막힘" ─────────────────────

func _capture_block_feedback(cover_system, source_position: Vector3) -> void:
	_set_hud_visible(true)
	cover_system.set("in_cover", true)
	cover_system.set("exposed_time", 0.0)
	main_scene.set("player_health", 9999)
	main_scene.call("take_hostile_hit", 30, Vector3.RIGHT, null, source_position)
	# 라벨은 0.4s 페이드 — 뜨자마자 두어 프레임 안에 찍는다.
	await process_frame
	await process_frame
	_capture(BLOCK_OUTPUT, "blocked_total=%d health=%d" % [
		int(cover_system.get("shots_blocked_total")),
		int(main_scene.get("player_health")),
	])


# ── 샷 2(순서상 마지막): 적 covered — 붉은 호 + 웅크림 ─────────────

func _capture_enemy_covered(cover_system) -> void:
	_set_hud_visible(false)
	# 시야 안개가 6m 밖의 적을 가린다 — 이 샷은 적의 붉은 호가 주인공이라 끈다.
	var fog := main_scene.get_node_or_null("VisibilityFog") as CanvasLayer
	if fog != null:
		fog.visible = false
	# 같은 엄폐물을 사이에 두고 자리만 바꾼다: 적이 엄폐물 뒤(플레이어가 있던 자리),
	# 플레이어는 반대쪽 6.5m — 교전 거리 6~16 안에서 적 엄폐가 성립한다.
	var enemy_anchor := player.global_position
	var cover_body = cover_system.get("cover_body")
	var normal := Vector3.ZERO
	if is_instance_valid(cover_body):
		normal = (enemy_anchor - (cover_body as Node3D).global_position)
		normal.y = 0.0
		normal = normal.normalized() if normal.length_squared() > 0.01 else Vector3.FORWARD
	else:
		normal = Vector3.FORWARD
	player.global_position = enemy_anchor - normal * 7.2
	player.force_update_transform()
	# 카메라를 잠깐 다시 굴려 플레이어를 따라잡게 한다.
	main_scene.set_physics_process(true)
	main_scene.set_process(true)
	await create_timer(0.9, true, false, true).timeout
	main_scene.set_process(false)
	main_scene.set_physics_process(false)

	var enemy := CharacterBody3D.new()
	enemy.name = "CaptureCoverEnemy"
	enemy.set_script(ENEMY_SCRIPT)
	main_scene.add_child(enemy)
	enemy.global_position = enemy_anchor
	enemy.call("configure", "ranged", player, {}, 0.3, "m1911")
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("perception_state", "combat")
	enemy.set("pursuit_time", 100.0)
	# 내밈(windup)에 들어가지 않게 쿨다운을 잠그고, 자리 이탈도 잠근다.
	enemy.set("attack_cooldown", 999.0)
	enemy.axis_lock_linear_x = true
	enemy.axis_lock_linear_z = true
	var crouched := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 4000:
		if bool(enemy.get("cover_active")) and enemy.get("cover_arc") != null:
			crouched = true
			break
		await process_frame
	if not crouched:
		push_error("샷2: 적 엄폐 상태가 켜지지 않았습니다.")
	await create_timer(0.3, true, false, true).timeout
	var sprite := enemy.get("sprite") as AnimatedSprite3D
	# 적 호가 읽히게 이 샷은 더 당겨 찍는다.
	var shot_camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	var shot_old_size := shot_camera.size
	shot_camera.size = shot_old_size * 0.55
	await process_frame
	print("ENEMY_DEBUG pos=%s player=%s sprite_visible=%s modulate=%s scale=%s arc=%s" % [
		str(enemy.global_position), str(player.global_position),
		str(sprite.visible if sprite != null else false),
		str(sprite.modulate if sprite != null else Color.BLACK),
		str(sprite.scale if sprite != null else Vector3.ZERO),
		str((enemy.get("cover_arc") as Node3D).visible if enemy.get("cover_arc") != null else "null"),
	])
	_capture(ENEMY_OUTPUT, "cover_active=%s squash=%.2f" % [
		str(enemy.get("cover_active")),
		sprite.scale.y if sprite != null else -1.0,
	])
	enemy.queue_free()
	await process_frame


func _capture(path: String, note: String = "") -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK %s %s" % [ProjectSettings.globalize_path(path), note])
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
