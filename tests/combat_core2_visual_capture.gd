extends SceneTree

# 전투 코어 2차 스크린샷 프로브(창 필요 — --headless 금지).
#   1) combat_core2_squad_clear.png    : 소탕 토스트 + 골드 펄스(스쿼드 전멸 직후)
#   2) combat_core2_cleared_map.png    : 전술 지도 — 소탕 구역 옅은 청록 원
#   3) combat_core2_damage_numbers.png : 피해 숫자(몸)·헤드샷 주황·"막힘" 라벨 동시 가독
#
# 실행: godot --path . --script tests/combat_core2_visual_capture.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const CLEAR_OUTPUT := "res://test-output/combat_core2_squad_clear.png"
const MAP_OUTPUT := "res://test-output/combat_core2_cleared_map.png"
const NUMBERS_OUTPUT := "res://test-output/combat_core2_damage_numbers.png"

var main_scene: Node
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_CORE2_CAPTURE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("selected_raid_zone", "jongno_outskirts")
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
	var world_map := main_scene.get_node("World")
	if world_map.has_method("set_collision_debug_enabled"):
		world_map.call("set_collision_debug_enabled", false)

	await _capture_squad_clear_and_map()
	await _capture_damage_numbers()
	quit(0)


# ── 샷 1·2: 소탕 토스트+골드 펄스 → 전술 지도 청록 원 ─────────────

func _capture_squad_clear_and_map() -> void:
	var director = main_scene.get("enemy_director")
	var enemies := main_scene.get("enemies") as Array
	# 가장 작은 스쿼드를 골라 그 근처로 이동한다(펄스·토스트가 전투 장면 위에 뜨게).
	var squads: Dictionary = {}
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		var squad_raw = enemy.get("squad_id")
		if squad_raw == null or int(squad_raw) < 0:
			continue
		if not squads.has(int(squad_raw)):
			squads[int(squad_raw)] = []
		(squads[int(squad_raw)] as Array).append(enemy)
	var target_squad_id := -1
	for squad_id in squads:
		if target_squad_id < 0 or (squads[squad_id] as Array).size() < (squads[target_squad_id] as Array).size():
			target_squad_id = squad_id
	if target_squad_id < 0:
		push_error("샷1: 소탕할 스쿼드가 없습니다.")
		return
	var members := (squads[target_squad_id] as Array).duplicate()
	var anchor: Vector3 = (members[0] as Node3D).global_position
	player.global_position = anchor + Vector3(5.0, 0.0, 5.0)
	player.force_update_transform()
	await create_timer(1.0, true, false, true).timeout
	# 마지막 한 명까지 정리 — 소탕 연출(토스트+펄스+지도 마커)이 울린다.
	for member in members:
		if is_instance_valid(member) and not bool(member.get("dying")):
			member.call("take_hit", 999999, Vector3(0.0, 0.0, 1.0))
			await process_frame
	# 골드 펄스는 0.1s 상승 → 0.5s 감쇠. 상승 직후 정점 부근에서 찍는다.
	await create_timer(0.12, true, false, true).timeout
	_capture(CLEAR_OUTPUT, "cleared=%d" % int(director.get("run_squads_cleared")))
	await create_timer(0.8, true, false, true).timeout
	# 전술 지도 — 소탕 구역 청록 원. 내 위치 핀이 원·라벨을 가리지 않게 왼쪽 아래로
	# 빠진다(소탕 라벨은 마커 오른쪽에 그려진다).
	var clear_site := player.global_position
	player.global_position += Vector3(-30.0, 0.0, 14.0)
	player.force_update_transform()
	await create_timer(0.5, true, false, true).timeout
	var tactical_map = main_scene.get("tactical_map")
	tactical_map.call("toggle")
	await create_timer(0.4, true, false, true).timeout
	_capture(MAP_OUTPUT, "markers=%d" % (tactical_map.get("raid_markers") as Array).size())
	tactical_map.call("close")
	await create_timer(0.3, true, false, true).timeout
	# 피해 숫자 컷은 소탕 현장(트인 도로)으로 되돌아가 찍는다.
	player.global_position = clear_site
	player.force_update_transform()
	await create_timer(0.8, true, false, true).timeout


# ── 샷 3: 피해 숫자 3종(몸·헤드샷 주황·막힘) ──────────────────────

func _capture_damage_numbers() -> void:
	# 시야 안개가 숫자 대비를 낮추지 않게 끄고, 카메라를 당긴다.
	var fog := main_scene.get_node_or_null("VisibilityFog") as CanvasLayer
	if fog != null:
		fog.visible = false
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	await create_timer(0.6, true, false, true).timeout
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= 0.5

	var base := player.global_position
	# 몸 피해 표적(왼쪽) / 헤드샷 표적(오른쪽) / 엄폐 차단 표적(안쪽 + 낮은 엄폐물).
	# 엄폐는 교전 거리 6~16m + 표적 방향 1.2u 이내 엄폐물이 조건 — 배치를 맞춘다.
	# 몸 피해 표적은 트인 도로 쪽 — 건물 옆에 붙이면 숫자가 지붕에 가려 안 읽힌다(실측).
	var body_enemy := _spawn_capture_enemy(base + Vector3(-2.6, 0.0, 3.4), "mp5")
	var head_enemy := _spawn_capture_enemy(base + Vector3(3.4, 0.0, -1.6), "m1911")
	var covered_enemy := _spawn_capture_enemy(base + Vector3(0.4, 0.0, -7.5), "m1911")
	covered_enemy.set("alerted", true)
	covered_enemy.set("detection_awareness", 1.0)
	covered_enemy.set("perception_state", "combat")
	_build_low_cover(
		covered_enemy.global_position + Vector3(0.0, 0.0, 1.0),
		Vector3(2.4, 1.2, 0.6)
	)
	await physics_frame
	await physics_frame
	covered_enemy.call("refresh_cover_state")
	covered_enemy.call("_update_cover_visuals")
	await create_timer(0.3, true, false, true).timeout

	# 같은 프레임 묶음으로 세 종류를 띄운다 — 겹침·가독을 한 컷에서 본다.
	# 방향 = 탄의 진행 방향(플레이어 → 적). 엄폐 표적은 -z 쪽에 있다.
	body_enemy.call("take_projectile_hit", 40, Vector3(0.0, 0.0, 1.0), false, 1.65, "normal", player)
	body_enemy.call("take_projectile_hit", 26, Vector3(0.0, 0.0, 1.0), false, 1.65, "graze", player)
	head_enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "head", player)
	covered_enemy.call("take_projectile_hit", 40, Vector3(0.0, 0.0, -1.0), false, 1.65, "normal", player)
	# 숫자 팝이 몸 위로 떠오를 시간을 준다(0.15s) — 상승 초입이 가장 잘 읽힌다.
	await create_timer(0.15, true, false, true).timeout
	_capture(NUMBERS_OUTPUT, "body_hp=%d head_hp=%d covered_blocked=%d" % [
		int(body_enemy.get("health")),
		int(head_enemy.get("health")),
		int(covered_enemy.get("cover_shots_blocked")),
	])


func _spawn_capture_enemy(world_position: Vector3, weapon_id: String) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "CaptureEnemy_%s_%d" % [weapon_id, Time.get_ticks_usec()]
	enemy.set_script(ENEMY_SCRIPT)
	main_scene.add_child(enemy)
	enemy.global_position = Vector3(world_position.x, 0.7, world_position.z)
	enemy.call("configure", "ranged", player, {}, 0.3, weapon_id)
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.set_physics_process(false)
	enemy.set("health", 100000)
	enemy.set("max_health", 100000)
	enemy.set("attack_cooldown", 999.0)
	return enemy


func _build_low_cover(ground_center: Vector3, size: Vector3) -> StaticBody3D:
	# cover_v2_probe와 같은 구조 — 부모 기물 메타 + ProjectileBlocker 자식.
	var body := StaticBody3D.new()
	body.name = "CaptureLowCover"
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	body.collision_mask = 0
	body.set_meta("projectile_collision_world_size", size)
	main_scene.add_child(body)
	body.global_position = Vector3(ground_center.x, 0.0, ground_center.z)
	var blocker := StaticBody3D.new()
	blocker.name = "ProjectileBlocker"
	blocker.collision_layer = COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	blocker.collision_mask = 0
	blocker.add_to_group("projectile_blocker")
	body.add_child(blocker)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = Vector3(0.0, size.y * 0.5, 0.0)
	blocker.add_child(collision)
	return body


func _capture(path: String, note: String = "") -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK %s %s" % [ProjectSettings.globalize_path(path), note])
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
