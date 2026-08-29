extends SceneTree

# 물리 엄폐 v2 프로브(헤드리스) — 3상태 기계(open/covered/peeking) + 완전 차단.
#   ① 플레이어 covered → 엄폐물 방향 총알 피해 0 + 차단 카운트 증가
#   ② 조준(우클릭) 유지 → peeking → 피해 정상
#   ③ 사격 후 0.5s 노출 → 타이머가 끝나면 다시 차단
#   ④ 폭발(blast)은 차단 안 됨(엄폐 캠핑의 카운터)
#   ⑤ 적 covered → 정면 탄 차단, 측면 45°는 정상 피해(각 잡기)
#   ⑥ 적 windup(내밈) 중엔 정면도 정상 피격 — 예고선이 곧 쏠 타이밍
#   ⑦ 웅크림 스프라이트 스케일(y 0.8) + 웅크린 동안 헤드샷 존 무효
#
# 실행: godot --headless --path . --script tests/cover_v2_probe.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const COVER_SYSTEM := preload("res://scripts/raid/cover_system.gd")
const DUMMY_SOURCE := """
extends CharacterBody3D
var damage_taken := 0
func take_hostile_hit(amount: int, _hit_direction: Vector3, _attacker = null, _source_position = null) -> void:
	damage_taken += amount
func get_faction_id() -> String:
	return "probe_dummy"
"""

var failures: Array[String] = []
var dummy_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROBE_FAIL: " + message)


func _run() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		push_error("COVER_V2_PROBE_TIMEOUT")
		quit(2)
	)
	dummy_script = GDScript.new()
	dummy_script.source_code = DUMMY_SOURCE
	dummy_script.reload()
	var accessibility := root.get_node("AccessibilitySettings")
	accessibility.set("damage_numbers_enabled", true)
	Engine.max_physics_steps_per_frame = 64

	await _probe_enemy_cover()
	await _probe_player_cover()

	if failures.is_empty():
		print("COVER_V2_PROBE_OK")
		quit(0)
	else:
		print("COVER_V2_PROBE_FAILED %d" % failures.size())
		for failure in failures:
			print("  - " + failure)
		quit(1)


# ── 헬퍼 ─────────────────────────────────────────────────────────

func _make_dummy(parent: Node, world_position: Vector3) -> CharacterBody3D:
	var dummy := CharacterBody3D.new()
	dummy.name = "Dummy"
	dummy.set_script(dummy_script)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.3
	collision.shape = shape
	dummy.add_child(collision)
	dummy.collision_layer = COLLISION_PROFILES.PLAYER_LAYER
	dummy.collision_mask = 0
	parent.add_child(dummy)
	dummy.global_position = world_position
	return dummy


func _build_low_cover(parent: Node, ground_center: Vector3, size: Vector3) -> StaticBody3D:
	# procedural_map._configure_profiled_collision과 같은 구조 — 부모 기물에
	# projectile_collision_world_size 메타 + 자식 ProjectileBlocker(WORLD_PROJECTILE_LAYER).
	var body := StaticBody3D.new()
	body.name = "ProbeLowCover"
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	body.collision_mask = 0
	body.set_meta("projectile_collision_world_size", size)
	parent.add_child(body)
	body.global_position = ground_center
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


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


# ── ⑤⑥⑦ 적 엄폐 ─────────────────────────────────────────────────

func _probe_enemy_cover() -> void:
	var arena := Node3D.new()
	arena.name = "CoverArena"
	root.add_child(arena)
	await process_frame
	await physics_frame

	# 배치: 표적(플레이어 대역) z=-10 ← 엄폐물 z=-1 ← 적 z=0. 교전 거리 10(6~16 안).
	var front_dummy := _make_dummy(arena, Vector3(0.0, 0.78, -10.0))
	var side_dummy := _make_dummy(arena, Vector3(10.0, 0.78, 0.0))
	var cover := _build_low_cover(arena, Vector3(0.0, 0.0, -1.0), Vector3(2.6, 1.2, 0.6))
	var enemy := CharacterBody3D.new()
	enemy.name = "ProbeRanged"
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = Vector3(0.0, 0.7, 0.0)
	arena.add_child(enemy)
	enemy.call("configure", "ranged", front_dummy, {}, 0.3, "m1911")
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("perception_state", "combat")
	# 프로브 표적 규약 — 물리 정지 + 체력 고정(heavy_gear_probe의 교훈).
	enemy.set_physics_process(false)
	enemy.set("health", 100000)
	enemy.set("max_health", 100000)
	await physics_frame
	await physics_frame

	# 기하 성립 → cover_active.
	enemy.call("refresh_cover_state")
	_assert(bool(enemy.get("cover_active")), "⑤ 표적 6~16m + 엄폐물 1.2u 이내의 ranged는 엄폐 상태여야 합니다.")
	_assert(not bool(enemy.call("is_cover_peeking")), "⑤ combat_state normal은 내밈이 아닙니다.")

	# ⑦ 웅크림 — 시각 갱신 후 스프라이트 y 스케일 0.8(트윈 0.12s는 실시간 대기).
	enemy.call("_update_cover_visuals")
	await create_timer(0.3, true, false, true).timeout
	var sprite := enemy.get("sprite") as AnimatedSprite3D
	_assert(sprite != null and absf(sprite.scale.y - 0.8) < 0.02, "⑦ 웅크림 스프라이트 y 스케일 0.8: %.3f" % (sprite.scale.y if sprite != null else -1.0))
	var arc := enemy.get("cover_arc") as Node3D
	_assert(arc != null and arc.visible, "⑦ 웅크린 적 발밑에 붉은 호가 보여야 합니다.")

	# ⑤ 정면 탄 차단 — 피해 0 + 차단 카운트.
	var health_before := int(enemy.get("health"))
	var blocked_before := int(enemy.get("cover_shots_blocked"))
	enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "normal", front_dummy)
	_assert(int(enemy.get("health")) == health_before, "⑤ 정면(엄폐물 건너편) 탄은 차단돼야 합니다: %d" % (health_before - int(enemy.get("health"))))
	_assert(int(enemy.get("cover_shots_blocked")) == blocked_before + 1, "⑤ 적 차단 카운트가 늘어야 합니다.")
	# 정면 10발 전부 차단(밸런스 가드 — 완전 차단은 각도 문제라는 전제 확인).
	for shot_index in 9:
		enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "normal", front_dummy)
	_assert(int(enemy.get("health")) == health_before, "⑤ 정면 사격 10발 전부 차단돼야 합니다.")
	_assert(int(enemy.get("cover_shots_blocked")) == blocked_before + 10, "⑤ 차단 카운트 10: %d" % (int(enemy.get("cover_shots_blocked")) - blocked_before))

	# ⑤ 측면 45°+ (엄폐물이 안 가리는 방향)는 정상 피해.
	health_before = int(enemy.get("health"))
	enemy.call("take_projectile_hit", 50, Vector3(-1.0, 0.0, 0.0), false, 1.65, "normal", side_dummy)
	_assert(health_before - int(enemy.get("health")) == 50, "⑤ 측면 사격은 정상 피해(50): %d" % (health_before - int(enemy.get("health"))))

	# ⑦ 웅크린 동안 헤드샷 존 무효 — 측면에서 "head"를 맞혀도 몸 판정(×1.6 없음).
	health_before = int(enemy.get("health"))
	enemy.call("take_projectile_hit", 50, Vector3(-1.0, 0.0, 0.0), false, 1.65, "head", side_dummy)
	_assert(health_before - int(enemy.get("health")) == 50, "⑦ 웅크린 적에게 헤드샷 배율(×1.6)이 붙으면 안 됩니다: %d" % (health_before - int(enemy.get("health"))))
	_assert(not bool(enemy.get("last_hit_was_headshot")), "⑦ 웅크린 동안 헤드샷 판정 자체가 무효여야 합니다.")

	# ⑥ windup(내밈) 중엔 정면도 정상 피격 + 헤드샷 유효.
	enemy.set("combat_state", "ranged_windup")
	_assert(bool(enemy.call("is_cover_peeking")), "⑥ ranged_windup은 내밈이어야 합니다.")
	health_before = int(enemy.get("health"))
	enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "normal", front_dummy)
	_assert(health_before - int(enemy.get("health")) == 50, "⑥ 내밈 중 정면 탄은 정상 피해(50): %d" % (health_before - int(enemy.get("health"))))
	# 피격은 경직(stagger)으로 내밈을 끊는다 — "내민 순간을 쏘면 도로 숨는다"가 의도.
	# 다음 검증을 위해 다시 내밈 상태로 되돌린다.
	enemy.set("combat_state", "ranged_windup")
	health_before = int(enemy.get("health"))
	enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "head", front_dummy)
	# 정밀 헤드샷(전투 코어 2차) — 비엘리트 m1911 사수는 ×2.2가 됐다.
	_assert(health_before - int(enemy.get("health")) == roundi(50 * 2.2), "⑥ 내밈 중 헤드샷은 ×2.2(110): %d" % (health_before - int(enemy.get("health"))))
	# 내밈 시각 — 스프라이트 원복(웅크림 해제).
	enemy.set("combat_state", "ranged_windup")
	enemy.call("_update_cover_visuals")
	await create_timer(0.3, true, false, true).timeout
	_assert(absf(sprite.scale.y - 1.0) < 0.02, "⑥ 내밈 중 스프라이트가 원복(1.0)돼야 합니다: %.3f" % sprite.scale.y)
	_assert(not (enemy.get("cover_arc") as Node3D).visible, "⑥ 내밈 중 붉은 호는 꺼져야 합니다.")
	enemy.set("combat_state", "normal")

	# 근접·척탄병은 엄폐 상태를 시도하지 않는다.
	var melee := CharacterBody3D.new()
	melee.set_script(ENEMY_SCRIPT)
	melee.position = Vector3(0.0, 0.7, 0.2)
	arena.add_child(melee)
	melee.call("configure", "melee", front_dummy, {}, 0.3, "")
	melee.set("alerted", true)
	melee.set_physics_process(false)
	await physics_frame
	melee.call("refresh_cover_state")
	_assert(not bool(melee.get("cover_active")), "⑤ 근접 돌격조는 엄폐 상태를 갖지 않습니다.")

	print("PROBE_ENEMY_COVER_OK blocked=%d" % int(enemy.get("cover_shots_blocked")))
	arena.queue_free()
	await process_frame


# ── ①②③④ 플레이어 엄폐(메인 씬) ────────────────────────────────

func _probe_player_cover() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 20:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.2, true, false, true).timeout
	await physics_frame
	var player := main_scene.get("player") as CharacterBody3D
	var cover_system = main_scene.get("cover_system")
	player.collision_layer = 0

	# 필드 도로 커버 중 엄폐 기하가 성립하는 자리를 찾는다(combat_mastery_probe와 동일).
	var world := main_scene.get_node("World")
	var covers: Array[Node] = []
	for child in world.get_children():
		if child.is_in_group("road_cover_obstacle") and child.has_node("CoverCollision"):
			covers.append(child)
	_assert(covers.size() >= 1, "① 필드에 도로 커버가 있어야 합니다.")
	var found_cover := false
	for cover in covers:
		var collision := cover.get_node("CoverCollision") as CollisionShape3D
		var size: Vector3 = (collision.shape as BoxShape3D).size
		var center := collision.global_position
		var normal := Vector3(0.0, 0.0, 1.0) if size.x >= size.z else Vector3(1.0, 0.0, 0.0)
		var depth := size.z if size.x >= size.z else size.x
		player.global_position = Vector3(center.x, 0.78, center.z) + normal * (depth * 0.5 + 0.7)
		player.force_update_transform()
		await physics_frame
		var source_position := Vector3(center.x, 0.7, center.z) - normal * 7.0
		if not bool(cover_system.call("is_covered_from", source_position)):
			continue
		found_cover = true

		# ① covered → 완전 차단.
		main_scene.set("laser_aim_held", false)
		main_scene.set("fire_button_held", false)
		main_scene.set("mouse_fire_held", false)
		cover_system.set("in_cover", true)
		cover_system.set("exposed_time", 0.0)
		_assert(str(cover_system.call("get_state")) == "covered", "① 조준·사격이 없으면 covered: %s" % str(cover_system.call("get_state")))
		var blocked_before := int(cover_system.get("shots_blocked_total"))
		main_scene.set("player_health", 9999)
		main_scene.call("take_hostile_hit", 37, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) == 9999, "① covered 중 엄폐물 방향 총알은 피해 0이어야 합니다.")
		_assert(int(cover_system.get("shots_blocked_total")) == blocked_before + 1, "① 차단 카운트가 늘어야 합니다.")

		# ② 조준 → peeking → 피해 정상.
		main_scene.set("laser_aim_held", true)
		_assert(str(cover_system.call("get_state")) == "peeking", "② 조준 중엔 peeking: %s" % str(cover_system.call("get_state")))
		main_scene.call("take_hostile_hit", 37, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) < 9999, "② peeking 중엔 피해가 정상이어야 합니다.")
		main_scene.set("laser_aim_held", false)

		# ③ 사격 후 0.5s 노출 — 실시간 대기(트윈·타이머는 create_timer 실측).
		cover_system.set("in_cover", true)
		cover_system.call("notify_player_fired")
		_assert(absf(float(cover_system.get("exposed_time")) - 0.5) < 0.001, "③ 사격 노출은 0.5s: %.2f" % float(cover_system.get("exposed_time")))
		main_scene.set("player_health", 9999)
		main_scene.call("take_hostile_hit", 37, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) < 9999, "③ 사격 노출 중엔 피해가 정상이어야 합니다.")
		await create_timer(0.6, true, false, true).timeout
		cover_system.set("in_cover", true)
		_assert(not bool(cover_system.call("is_exposed")), "③ 0.5s 뒤 노출이 끝나야 합니다(%.2f)" % float(cover_system.get("exposed_time")))
		main_scene.set("player_health", 9999)
		main_scene.call("take_hostile_hit", 37, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) == 9999, "③ 노출이 끝나면 다시 완전 차단이어야 합니다.")

		# ④ 폭발·근접은 차단 안 됨.
		main_scene.call("take_hostile_hit", 37, Vector3.RIGHT, null, source_position, "blast")
		_assert(int(main_scene.get("player_health")) < 9999, "④ 폭발(blast)은 엄폐로 막히면 안 됩니다.")
		main_scene.set("player_health", 9999)
		cover_system.set("in_cover", true)
		main_scene.call("take_hostile_hit", 21, Vector3.RIGHT, null, source_position, "melee")
		_assert(int(main_scene.get("player_health")) < 9999, "④ 근접(melee)도 엄폐로 막히면 안 됩니다.")

		# 시각 상태 — 스캔이 상태를 되돌리지 않게 메인 물리 갱신을 잠시 멈춘다.
		main_scene.set_physics_process(false)
		cover_system.set("in_cover", true)
		cover_system.set("exposed_time", 0.0)
		cover_system.call("_update_player_visuals")
		await create_timer(0.3, true, false, true).timeout
		var survivor := main_scene.get("survivor") as AnimatedSprite3D
		_assert(survivor != null and absf(survivor.scale.y - 0.82) < 0.02, "① covered 중 플레이어 스쿼시 y 0.82: %.3f" % (survivor.scale.y if survivor != null else -1.0))
		var arc := cover_system.get("arc_pivot") as Node3D
		_assert(arc != null and arc.visible, "① covered 중 발밑 방패 호가 보여야 합니다.")
		_assert((cover_system.get("arc_fill") as Node3D).visible, "① covered 호는 채움이 보입니다.")
		main_scene.set("laser_aim_held", true)
		cover_system.call("_update_player_visuals")
		_assert(not (cover_system.get("arc_fill") as Node3D).visible, "② peeking 중 채움은 꺼지고 테두리만 남아야 합니다.")
		_assert((cover_system.get("arc_outline") as Node3D).visible, "② peeking 중 테두리 호는 보여야 합니다.")
		main_scene.set("laser_aim_held", false)
		main_scene.set_physics_process(true)
		break
	_assert(found_cover, "① 도로 커버 중 하나는 엄폐 기하를 만족해야 합니다.")
	print("PROBE_PLAYER_COVER_OK blocked_total=%d" % int(cover_system.get("shots_blocked_total")))
	main_scene.queue_free()
	await process_frame
