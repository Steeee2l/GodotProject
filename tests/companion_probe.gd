extends SceneTree

# 주홍 동행 프로브(헤드리스) — 해금·소환·추종·표적 우선순위·쌍방 소생·판당 1회.
#   ① 해금 전 미소환 → juhong_intro 확인 시 companion_unlocked
#   ② 토글 off 미소환 → on 소환
#   ③ 리시 추종 — 플레이어 순간이동 후 접근(걷기 또는 2.5s 끼임 재배치)
#   ④ 표적 우선순위 — ①플레이어 공격자 ②자신 공격자 ③최근접
#   ⑤ 플레이어 다운 30s(축소) 만료 → 기존 사망 흐름 진입
#   ⑥ 주홍 다운 → companion_revive 상호작용 → HP 40%
#   ⑦ 주홍 2차 다운 — 판당 1회 제한(소생 지점 없음) → 출혈 만료 → 그 판 이탈
#   ⑧ (새 판) 플레이어 다운 → 주홍 4s 채널(축소) → HP 40% 소생
#   ⑨ 플레이어 소생 판당 1회 — 2차 다운은 곧장 사망 흐름
#
# 실행: godot --headless --path . --script tests/companion_probe.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROBE_FAIL: " + message)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _run() -> void:
	create_timer(220.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMPANION_PROBE_TIMEOUT")
		quit(2)
	)
	Engine.max_physics_steps_per_frame = 64
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("returning_from_shelter", false)

	await _probe_unlock_and_field(game_state)
	await _probe_player_revive(game_state)

	if failures.is_empty():
		print("COMPANION_PROBE_OK")
		quit(0)
	else:
		print("COMPANION_PROBE_FAILED %d" % failures.size())
		for failure in failures:
			print("  - " + failure)
		quit(1)


func _spawn_main(game_state: Node) -> Node:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 사자 서사/시네마틱 모달 먼저 닫기(프로브 규약).
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 20:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.2, true, false, true).timeout
	await physics_frame
	return main_scene


func _clear_field_enemies(main_scene: Node) -> void:
	for enemy in main_scene.get("enemies").duplicate():
		if is_instance_valid(enemy):
			(enemy as Node).queue_free()
	main_scene.get("enemies").clear()


func _make_probe_enemy(
	main_scene: Node,
	world_position: Vector3,
	target_body: CharacterBody3D
) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = world_position
	main_scene.add_child(enemy)
	enemy.call("configure", "ranged", target_body, {}, 0.3, "m1911")
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("perception_state", "combat")
	# 프로브 표적 규약 — 물리 정지 + 체력 고정.
	enemy.set_physics_process(false)
	enemy.set("health", 100000)
	enemy.set("max_health", 100000)
	# 어그로 40% 룰이 프로브의 표적 배치를 흔들지 않게 이미 굴린 것으로 표시.
	enemy.set_meta("juhong_aggro_rolled", true)
	main_scene.get("enemies").append(enemy)
	return enemy


# ── ①~⑦: 해금/소환/추종/우선순위/만료/주홍 소생 ─────────────────────

func _probe_unlock_and_field(game_state: Node) -> void:
	# ① 해금 전 미소환.
	game_state.set("juhong_intro_seen", false)
	game_state.set("companion_unlocked", false)
	game_state.set("companion_enabled", true)
	_assert(not bool(game_state.call("is_companion_raid_active")), "① 해금 전엔 동행 비활성이어야 합니다.")
	var main_scene := await _spawn_main(game_state)
	var companion = main_scene.get("companion_system")
	_assert(companion.get("juhong") == null, "① 해금 전에는 주홍이 소환되지 않아야 합니다.")

	# ① 이벤트 확인 → 해금(game_state가 juhong_intro 확인 시 자동으로 켠다).
	game_state.call("mark_shelter_story_event_seen", "juhong_intro")
	_assert(bool(game_state.get("companion_unlocked")), "① juhong_intro 확인 시 companion_unlocked=true여야 합니다.")
	_assert(bool(game_state.get("juhong_intro_seen")), "① juhong_intro_seen이 켜져야 합니다.")

	# ② 토글 off 미소환 → on 소환.
	game_state.set("companion_enabled", false)
	companion.call("spawn_if_active")
	_assert(companion.get("juhong") == null, "② 동행 토글 off면 소환되지 않아야 합니다.")
	game_state.set("companion_enabled", true)
	companion.call("spawn_if_active")
	var juhong = companion.get("juhong")
	_assert(juhong != null and is_instance_valid(juhong), "② 해금+토글 on이면 소환돼야 합니다.")
	if juhong == null:
		main_scene.queue_free()
		await process_frame
		return
	juhong.set("health", 100000)
	juhong.set("max_health", 100000)
	_clear_field_enemies(main_scene)

	# ③ 리시 추종 — 플레이어 순간이동 후 접근(걷기 or 끼임 재배치).
	var player := main_scene.get("player") as CharacterBody3D
	var world := main_scene.get_node("World")
	var far_position: Vector3 = world.call(
		"find_nearest_physically_open_position",
		player.global_position + Vector3(16.0, 0.0, 12.0),
		0.62,
		[player.get_rid()]
	)
	player.global_position = Vector3(far_position.x, 0.78, far_position.z)
	player.force_update_transform()
	var approached := await _wait_until(func() -> bool:
		return (juhong as Node3D).global_position.distance_to(player.global_position) <= 3.4
	, 14.0)
	_assert(approached, "③ 순간이동한 플레이어에게 14초 안에 접근해야 합니다(리시 추종): %.1fm" % (juhong as Node3D).global_position.distance_to(player.global_position))

	# ④ 표적 우선순위.
	var juhong_position: Vector3 = (juhong as Node3D).global_position
	var dummy := CharacterBody3D.new()
	dummy.name = "PriorityDummy"
	main_scene.add_child(dummy)
	dummy.global_position = juhong_position + Vector3(0.0, 0.7, -6.0)
	var enemy_far := _make_probe_enemy(main_scene, juhong_position + Vector3(8.0, 0.7, 0.0), player)
	var enemy_near := _make_probe_enemy(main_scene, juhong_position + Vector3(3.0, 0.7, 0.0), player)
	enemy_near.set("target", dummy)
	var picked = juhong.call("select_combat_target")
	_assert(picked == enemy_far, "④-1 플레이어를 공격 중인 적이 최우선이어야 합니다(거리 무관).")
	enemy_far.set("target", dummy)
	enemy_near.set("target", juhong)
	picked = juhong.call("select_combat_target")
	_assert(picked == enemy_near, "④-2 다음 순위는 주홍 자신을 공격하는 적입니다.")
	enemy_near.set("target", dummy)
	picked = juhong.call("select_combat_target")
	_assert(picked == enemy_near, "④-3 그 외에는 최근접 경계 적입니다.")
	enemy_far.queue_free()
	enemy_near.queue_free()
	main_scene.get("enemies").clear()
	dummy.queue_free()
	await physics_frame

	# ⑤ 플레이어 다운 만료(0.6s 축소) → 기존 사망 흐름 진입.
	companion.set("player_down_seconds", 0.6)
	(juhong as Node3D).global_position = player.global_position + Vector3(60.0, 0.0, 60.0)
	main_scene.set("player_health", 30)
	game_state.set("player_health", 30)
	main_scene.call("take_damage", 99999)
	_assert(bool(companion.call("is_player_downed")), "⑤ 주홍 생존 시 사망 대신 다운 상태여야 합니다.")
	_assert(not bool(main_scene.get("player_death_sequence_active")), "⑤ 다운 진입 순간엔 사망 시퀀스가 아니어야 합니다.")
	var died := await _wait_until(func() -> bool:
		return bool(main_scene.get("player_death_sequence_active"))
	, 8.0)
	_assert(died, "⑤ 다운 시간 만료 시 기존 사망 흐름으로 진입해야 합니다.")
	_assert(not bool(companion.call("is_player_downed")), "⑤ 만료 후 다운 상태는 해제돼야 합니다.")
	Engine.time_scale = 1.0

	# ⑥ 주홍 다운 → [F] 소생(companion_revive 상호작용) → HP 40%.
	juhong.set("health", 160)
	juhong.set("max_health", 160)
	juhong.call("take_hostile_hit", 100000, Vector3.RIGHT, null, Vector3.INF, "blast")
	_assert(bool(juhong.get("downed")), "⑥ 체력 0이면 다운돼야 합니다.")
	_assert(absf(float(juhong.get("down_remaining")) - 45.0) < 0.5, "⑥ 출혈 카운트는 45초: %.1f" % float(juhong.get("down_remaining")))
	var revive_point = companion.get("revive_point")
	_assert(revive_point != null and is_instance_valid(revive_point), "⑥ 다운 시 소생 상호작용 지점이 생겨야 합니다.")
	if revive_point != null and is_instance_valid(revive_point):
		_assert(str((revive_point as Node).get_meta("interaction_type", "")) == "companion_revive", "⑥ 상호작용 타입은 companion_revive여야 합니다.")
		main_scene.call("_complete_field_interaction", revive_point)
	_assert(not bool(juhong.get("downed")), "⑥ 소생 후 다운이 풀려야 합니다.")
	_assert(int(juhong.get("health")) == roundi(160 * 0.4), "⑥ 소생 체력은 40%%(64): %d" % int(juhong.get("health")))

	# ⑦ 판당 1회 — 2차 다운엔 소생 지점이 없고, 출혈 만료 시 그 판 이탈.
	juhong.call("take_hostile_hit", 100000, Vector3.RIGHT, null, Vector3.INF, "blast")
	_assert(bool(juhong.get("downed")), "⑦ 2차 다운도 다운 상태로 들어갑니다.")
	_assert(companion.get("revive_point") == null, "⑦ 판당 1회 — 2차 다운엔 소생 지점이 없어야 합니다.")
	juhong.set("down_remaining", 0.3)
	var left := await _wait_until(func() -> bool:
		return bool(juhong.get("retreated"))
	, 5.0)
	_assert(left, "⑦ 출혈 만료 시 그 판에서 이탈해야 합니다.")
	_assert(not (juhong as Node3D).visible, "⑦ 이탈한 주홍은 보이지 않아야 합니다(영구 사망 아님).")

	print("PROBE_UNLOCK_FIELD_OK")
	main_scene.queue_free()
	await process_frame


# ── ⑧⑨: 플레이어 다운 → 주홍 소생 + 판당 1회 ────────────────────────

func _probe_player_revive(game_state: Node) -> void:
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("returning_from_shelter", false)
	game_state.set("juhong_intro_seen", true)
	game_state.set("companion_unlocked", true)
	game_state.set("companion_enabled", true)
	var main_scene := await _spawn_main(game_state)
	var companion = main_scene.get("companion_system")
	var juhong = companion.get("juhong")
	_assert(juhong != null and is_instance_valid(juhong), "⑧ 해금+토글 on이면 스폰 직후 소환돼야 합니다.")
	if juhong == null:
		main_scene.queue_free()
		await process_frame
		return
	_clear_field_enemies(main_scene)
	juhong.set("health", 100000)
	juhong.set("max_health", 100000)

	# ⑧ 다운 → 채널(0.5s 축소) → HP 40%.
	var player := main_scene.get("player") as CharacterBody3D
	companion.set("player_revive_channel_seconds", 0.5)
	(juhong as Node3D).global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	main_scene.set("player_health", 25)
	game_state.set("player_health", 25)
	main_scene.call("take_damage", 99999)
	_assert(bool(companion.call("is_player_downed")), "⑧ 주홍이 곁에 있으면 사망 대신 다운이어야 합니다.")
	_assert(not bool(main_scene.get("player_death_sequence_active")), "⑧ 다운 중엔 사망 시퀀스가 아니어야 합니다.")
	var expected_health := roundi(float(game_state.call("get_max_health")) * 0.4)
	var revived := await _wait_until(func() -> bool:
		return int(main_scene.get("player_health")) == expected_health
	, 8.0)
	_assert(revived, "⑧ 주홍 채널 완료 시 체력 40%%(%d)로 소생해야 합니다: %d" % [expected_health, int(main_scene.get("player_health"))])
	_assert(not bool(companion.call("is_player_downed")), "⑧ 소생 후 다운 상태가 풀려야 합니다.")
	_assert(not bool(main_scene.get("player_death_sequence_active")), "⑧ 소생했으면 사망 시퀀스가 아니어야 합니다.")

	# ⑨ 판당 1회 — 2차 다운은 곧장 기존 사망 흐름.
	main_scene.call("take_damage", 99999)
	_assert(not bool(companion.call("is_player_downed")), "⑨ 이미 소생을 받았으면 다시 다운되지 않습니다.")
	_assert(bool(main_scene.get("player_death_sequence_active")), "⑨ 2차 치명상은 기존 사망 흐름으로 직행해야 합니다.")
	Engine.time_scale = 1.0

	print("PROBE_PLAYER_REVIVE_OK")
	main_scene.queue_free()
	await process_frame
