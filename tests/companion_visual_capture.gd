extends SceneTree

# 주홍 동행 스크린샷 프로브(창 필요 — --headless 금지).
#   1) companion_field_combat.png : 주홍 동행 전투 — 청록 엄폐 호 + 이름표 + HUD 칩
#   2) companion_down_revive.png  : 주홍 다운 + [F] 소생 링 게이지
#   3) companion_player_down.png  : 플레이어 다운 — 데세츄레이션 + 출혈 비네트 + 채널 게이지
#
# 실행: godot --path . --script tests/companion_visual_capture.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const COMBAT_OUTPUT := "res://test-output/companion_field_combat.png"
const REVIVE_OUTPUT := "res://test-output/companion_down_revive.png"
const PLAYER_DOWN_OUTPUT := "res://test-output/companion_player_down.png"

var main_scene: Node
var player: CharacterBody3D
var companion
var juhong


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMPANION_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("returning_from_shelter", false)
	game_state.set("juhong_intro_seen", true)
	game_state.set("companion_unlocked", true)
	game_state.set("companion_enabled", true)
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
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 20:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.25, true, false, true).timeout
	await create_timer(0.5, true, false, true).timeout
	player = main_scene.get_node("Player") as CharacterBody3D
	companion = main_scene.get("companion_system")
	juhong = companion.get("juhong")
	if juhong == null:
		push_error("주홍이 소환되지 않았습니다.")
		quit(1)
		return
	juhong.set("health", 160)
	juhong.set("max_health", 160)
	var world_map := main_scene.get_node("World")
	if world_map.has_method("set_collision_debug_enabled"):
		world_map.call("set_collision_debug_enabled", false)
	# 기존 필드 적 제거 — 연출을 프로브가 통제한다.
	for enemy in main_scene.get("enemies").duplicate():
		if is_instance_valid(enemy):
			(enemy as Node).queue_free()
	main_scene.get("enemies").clear()
	await physics_frame

	await _capture_field_combat()
	await _capture_down_revive()
	await _capture_player_down()
	quit(0)


func _find_cover_spot() -> Dictionary:
	var cover_system = main_scene.get("cover_system")
	var world := main_scene.get_node("World")
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
		var source := Vector3(center.x, 0.7, center.z) - normal * 7.0
		if bool(cover_system.call("is_covered_from", source)):
			return {"center": Vector3(center.x, 0.0, center.z), "normal": normal, "depth": depth}
	return {}


func _capture_field_combat() -> void:
	var spot := _find_cover_spot()
	if spot.is_empty():
		push_error("엄폐 기하를 만족하는 도로 커버를 찾지 못했습니다.")
		return
	var center: Vector3 = spot["center"]
	var normal: Vector3 = spot["normal"]
	var depth: float = spot["depth"]
	# 주홍은 엄폐물 뒤(플레이어 옆), 적은 건너편 7m.
	var juhong_body := juhong as Node3D
	juhong_body.global_position = player.global_position + Vector3(normal.z, 0.0, -normal.x) * 1.6
	juhong_body.force_update_transform()
	var enemy := CharacterBody3D.new()
	enemy.name = "CaptureEnemy"
	enemy.set_script(ENEMY_SCRIPT)
	main_scene.add_child(enemy)
	enemy.global_position = center - normal * (depth * 0.5 + 6.5) + Vector3(0, 0.7, 0)
	enemy.call("configure", "ranged", player, {}, 0.3, "m1911")
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("perception_state", "combat")
	enemy.set("attack_cooldown", 999.0)
	enemy.set_physics_process(false)
	enemy.set_meta("juhong_aggro_rolled", true)
	main_scene.get("enemies").append(enemy)
	# 주홍은 이 샷 동안 포즈 고정(스트레이프로 엄폐 자리를 벗어나지 않게).
	juhong.set_physics_process(false)
	# 카메라가 자리 잡게 잠깐 굴린다.
	await create_timer(1.4, true, false, true).timeout
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	# 엄폐·웅크림·칩을 강제로 확정한다(스캔 타이밍에 기대지 않는다).
	juhong.set("combat_target", enemy)
	juhong.set("state", "combat")
	juhong.set("peek_time", 0.0)
	juhong.call("_update_cover", 1.0)
	juhong.call("_apply_crouch_visual", bool(juhong.call("is_cover_crouching")))
	companion.call("update", 0.016)
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	var old_size := camera.size
	camera.size = old_size * 0.5
	await create_timer(0.3, true, false, true).timeout
	_capture(COMBAT_OUTPUT, "cover_active=%s state=%s" % [
		str(juhong.get("cover_active")), str(juhong.get("state")),
	])
	camera.size = old_size
	enemy.queue_free()
	main_scene.get("enemies").clear()
	juhong.set("combat_target", null)
	juhong.set_physics_process(true)
	main_scene.set_process(true)
	main_scene.set_physics_process(true)
	await process_frame


func _capture_down_revive() -> void:
	var juhong_body := juhong as Node3D
	juhong_body.global_position = player.global_position + Vector3(1.2, 0.0, 0.6)
	juhong_body.force_update_transform()
	juhong.call("take_hostile_hit", 100000, Vector3.RIGHT, null, Vector3.INF, "blast")
	# 상호작용 후보가 자리 잡을 시간을 준 뒤 홀드를 시작한다(첫 프레임의
	# 후보 교체가 keyboard_held를 리셋하기 때문).
	await create_timer(0.4, true, false, true).timeout
	# [F] 홀드 — 링 게이지가 절반쯤 찬 순간을 찍는다.
	main_scene.set("field_interaction_keyboard_held", true)
	await create_timer(1.4, true, false, true).timeout
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	var old_size := camera.size
	camera.size = old_size * 0.5
	await process_frame
	await process_frame
	_capture(REVIVE_OUTPUT, "downed=%s hold=%.2f" % [
		str(juhong.get("downed")), float(main_scene.get("field_interaction_hold_time")),
	])
	camera.size = old_size
	# 홀드를 끝까지 채워 소생시킨다(다음 샷에 주홍이 필요하다).
	var started := Time.get_ticks_msec()
	while bool(juhong.get("downed")) and Time.get_ticks_msec() - started < 6000:
		await physics_frame
	main_scene.set("field_interaction_keyboard_held", false)
	await process_frame


func _capture_player_down() -> void:
	if bool(juhong.get("downed")) or bool(juhong.get("retreated")):
		push_error("샷3: 주홍이 살아 있어야 합니다.")
		return
	var juhong_body := juhong as Node3D
	juhong_body.global_position = player.global_position + Vector3(5.0, 0.0, 4.0)
	juhong_body.force_update_transform()
	main_scene.set("player_health", 20)
	main_scene.call("take_damage", 9999)
	if not bool(companion.call("is_player_downed")):
		push_error("샷3: 플레이어 다운 상태로 들어가지 못했습니다.")
		return
	# 주홍이 달려오는 동안 — 데세츄레이션 + 비네트 + 안내 게이지가 뜬 화면.
	await create_timer(0.9, true, false, true).timeout
	_capture(PLAYER_DOWN_OUTPUT, "downed=%s remaining=%.1f" % [
		str(companion.call("is_player_downed")),
		float(companion.get("player_down_remaining")),
	])
	# 소생까지 기다렸다가 종료(상태를 어지럽히지 않는다).
	var started := Time.get_ticks_msec()
	while bool(companion.call("is_player_downed")) and Time.get_ticks_msec() - started < 12000:
		await physics_frame


func _capture(path: String, note: String = "") -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK %s %s" % [ProjectSettings.globalize_path(path), note])
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
