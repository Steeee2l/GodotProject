extends SceneTree

# 전투 코어 개편 2차 프로브(헤드리스) — 소탕=안전 · 종로 랜딩 완화 · 정밀 헤드샷 · 명중 셰이크.
#   ① 헤드샷 배율 표: 비엘리트 m1911/배트 ×2.2, 척탄병·AKM ×1.6, 엘리트 ×1.35(기존 유지)
#   ② 종로(stage_tier 1): 동시 교전 상한 3 · 수류탄병 0 · 무리 ≤3 · 첫 증원 +20s
#      타 존(stage_tier 2): 상한 6 · 수류탄병 스폰 정상
#   ③ 소탕 감지: 스쿼드 전멸 → 긴장도 +22−18=+4 · 소탕 앵커 등록 · 보너스 드랍 1회
#      · 토스트 · 지도 청록 원 · 증원 목적지 18m 회피
#   ④ 명중 마이크로 셰이크: 피해 비례 0.02~0.05 · 헤드샷 ×1.6 · 스로틀 90ms · 상한 0.2
#
# 실행: godot --headless --path . --script tests/combat_core2_probe.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
# enemy_director.gd는 GameState 오토로드 식별자를 쓰므로 --script 콜드 스타트에서
# preload가 깨진다(enemy.gd 주석의 같은 함정) — 상수는 값으로 박아 두고 검증한다.
const SQUAD_CLEAR_PRESSURE_RELIEF := 18.0
const SQUAD_CLEAR_ANCHOR_RADIUS := 18.0
const DUMMY_SOURCE := """
extends CharacterBody3D
func get_faction_id() -> String:
	return \"probe_dummy\"
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
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_CORE2_PROBE_TIMEOUT")
		quit(2)
	)
	dummy_script = GDScript.new()
	dummy_script.source_code = DUMMY_SOURCE
	dummy_script.reload()
	Engine.max_physics_steps_per_frame = 64

	await _probe_headshot_multiplier_table()
	await _probe_main_scene_suite()

	if failures.is_empty():
		print("COMBAT_CORE2_PROBE_OK")
		quit(0)
	else:
		print("COMBAT_CORE2_PROBE_FAILED %d" % failures.size())
		for failure in failures:
			print("  - " + failure)
		quit(1)


# ── 헬퍼 ─────────────────────────────────────────────────────────

func _make_dummy(parent: Node, world_position: Vector3) -> CharacterBody3D:
	var dummy := CharacterBody3D.new()
	dummy.name = "ProbeDummy"
	dummy.set_script(dummy_script)
	parent.add_child(dummy)
	dummy.global_position = world_position
	return dummy


func _make_probe_enemy(
	parent: Node,
	kind: String,
	world_position: Vector3,
	weapon_id: String,
	target: CharacterBody3D
) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "Probe_%s_%s" % [kind, weapon_id if not weapon_id.is_empty() else "bat"]
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = world_position
	parent.add_child(enemy)
	enemy.call("configure", kind, target, {}, 0.3, weapon_id)
	# 프로브 표적 규약 — 물리 정지 + 체력 고정.
	enemy.set_physics_process(false)
	enemy.set("health", 100000)
	enemy.set("max_health", 100000)
	return enemy


func _headshot_damage(enemy: CharacterBody3D, attacker: CharacterBody3D) -> int:
	var before := int(enemy.get("health"))
	enemy.call("take_projectile_hit", 50, Vector3(0.0, 0.0, 1.0), false, 1.65, "head", attacker)
	return before - int(enemy.get("health"))


# ── ① 헤드샷 배율 표 ─────────────────────────────────────────────

func _probe_headshot_multiplier_table() -> void:
	var arena := Node3D.new()
	arena.name = "HeadshotArena"
	root.add_child(arena)
	await process_frame
	await physics_frame
	var shooter := _make_dummy(arena, Vector3(0.0, 0.78, -10.0))

	# 표: [kind, weapon, elite, 배율, 라벨]
	var table := [
		["ranged", "m1911", false, 2.2, "비엘리트 권총병(m1911)"],
		["melee", "", false, 2.2, "비엘리트 근접(배트)"],
		["grenadier", "m1911", false, 1.6, "척탄병(권총을 들어도 ×1.6)"],
		["ranged", "akm", false, 1.6, "상위 무장 사수(AKM)"],
		["ranged", "mp5", false, 1.6, "상위 무장 사수(MP5)"],
		["ranged", "mp5", true, 1.35, "엘리트(기존 ×1.35 + 포이즈 보상 유지)"],
	]
	var lane := 0
	for row in table:
		var enemy := _make_probe_enemy(
			arena, str(row[0]), Vector3(float(lane) * 4.0, 0.7, 0.0), str(row[1]), shooter
		)
		if bool(row[2]):
			enemy.call("promote_to_elite", "프로브 정예")
			enemy.set("health", 100000)
			enemy.set("max_health", 100000)
		await physics_frame
		var expected_multiplier := float(row[3])
		var reported := float(enemy.call("get_headshot_damage_multiplier"))
		_assert(
			is_equal_approx(reported, expected_multiplier),
			"① %s 배율 %.2f 기대, 실제 %.2f" % [str(row[4]), expected_multiplier, reported]
		)
		var damage := _headshot_damage(enemy, shooter)
		var expected_damage := roundi(50.0 * expected_multiplier)
		_assert(
			damage == expected_damage,
			"① %s 헤드샷 피해 %d 기대, 실제 %d" % [str(row[4]), expected_damage, damage]
		)
		lane += 1
	print("PROBE_HEADSHOT_TABLE_OK rows=%d" % table.size())
	arena.queue_free()
	await process_frame


# ── ②③④ 메인 씬 묶음 ────────────────────────────────────────────

func _probe_main_scene_suite() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("selected_raid_zone", "jongno_outskirts")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 새 게임 프로브 규약 — 사자 서사(시네마틱) 모달 먼저 닫기.
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 20:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.2, true, false, true).timeout
	await physics_frame
	var player := main_scene.get("player") as CharacterBody3D
	var director = main_scene.get("enemy_director")
	var world := main_scene.get_node("World")

	await _probe_jongno_static_tuning(main_scene, director, world, game_state)
	await _probe_squad_clear(main_scene, director, player)
	await _probe_hit_shake(main_scene, player)

	main_scene.queue_free()
	await process_frame


# ── ② 종로 정적 튜닝 ─────────────────────────────────────────────

func _probe_jongno_static_tuning(main_scene: Node, director, world: Node, game_state: Node) -> void:
	# 동시 교전 상한 — 종로 3.
	_assert(
		int(director.call("get_max_concurrent_alerted")) == 3,
		"② 종로 동시 교전 상한은 3이어야 합니다: %d" % int(director.call("get_max_concurrent_alerted"))
	)
	# 초기 배치에 수류탄병 0 + 스쿼드 크기 ≤3.
	var enemies := main_scene.get("enemies") as Array
	var grenadier_count := 0
	var squad_sizes: Dictionary = {}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if str(enemy.get("enemy_kind")) == "grenadier":
			grenadier_count += 1
		var squad_raw = enemy.get("squad_id")
		if squad_raw != null and int(squad_raw) >= 0:
			squad_sizes[int(squad_raw)] = int(squad_sizes.get(int(squad_raw), 0)) + 1
	_assert(grenadier_count == 0, "② 종로 초기 배치에 수류탄병이 없어야 합니다: %d" % grenadier_count)
	var oversized := 0
	for squad_id in squad_sizes:
		if int(squad_sizes[squad_id]) > 3:
			oversized += 1
	_assert(oversized == 0, "② 종로 무리 크기 상한 3 초과 스쿼드: %d" % oversized)
	_assert(enemies.size() > 0, "② 초기 배치 적이 존재해야 합니다.")
	# 첫 증원 웨이브 +20s — 보충 타이머(기본 8)와 무전 쿨다운(기본 0)이 늦춰졌는가.
	_assert(
		float(main_scene.get("reinforcement_timer")) > 20.0,
		"② 종로 보충 타이머는 +20s(28에서 시작)여야 합니다: %.1f" % float(main_scene.get("reinforcement_timer"))
	)
	_assert(
		float(director.get("reinforcement_call_cooldown")) > 10.0,
		"② 종로 무전 증원 쿨다운은 20에서 시작해야 합니다: %.1f" % float(director.get("reinforcement_call_cooldown"))
	)
	# 스폰 관문 — 수류탄병이 섞인 4인 요청이 권총병 3인으로 잘린다.
	var player := main_scene.get("player") as CharacterBody3D
	var request: Array[String] = ["pistol", "grenadier", "melee", "grenadier"]
	var spawned = director.call(
		"_spawn_enemy_squad", world, player.global_position + Vector3(40.0, 0.78, 40.0), request, 0.2
	)
	_assert((spawned as Array).size() == 3, "② 종로 스쿼드는 3으로 잘려야 합니다: %d" % (spawned as Array).size())
	var spawned_grenadiers := 0
	for enemy in (spawned as Array):
		if str(enemy.get("enemy_kind")) == "grenadier":
			spawned_grenadiers += 1
	_assert(spawned_grenadiers == 0, "② 종로 스폰 관문이 수류탄병을 권총병으로 바꿔야 합니다: %d" % spawned_grenadiers)
	_cleanup_spawned(main_scene, spawned as Array)
	# 타 존(stage_tier 2) — 상한 6 + 수류탄병 정상 스폰. 존 데이터만 바꿔 확인한다.
	var jongno_data = main_scene.get("raid_zone_data")
	main_scene.set("raid_zone_data", (game_state.get("RAID_ZONES") as Dictionary)["namdaemun_market"])
	_assert(
		int(director.call("get_max_concurrent_alerted")) == int(director.get("MAX_CONCURRENT_ALERTED")),
		"② 타 존 동시 교전 상한은 MAX_CONCURRENT_ALERTED(%d) 유지: %d" % [int(director.get("MAX_CONCURRENT_ALERTED")), int(director.call("get_max_concurrent_alerted"))]
	)
	var other_request: Array[String] = ["grenadier"]
	var other_spawned = director.call(
		"_spawn_enemy_squad", world, player.global_position + Vector3(-40.0, 0.78, 40.0), other_request, 0.2
	)
	_assert(
		(other_spawned as Array).size() == 1
		and str((other_spawned as Array)[0].get("enemy_kind")) == "grenadier",
		"② 타 존에서는 수류탄병이 그대로 스폰돼야 합니다."
	)
	_cleanup_spawned(main_scene, other_spawned as Array)
	main_scene.set("raid_zone_data", jongno_data)
	print("PROBE_JONGNO_TUNING_OK enemies=%d squads=%d" % [enemies.size(), squad_sizes.size()])


func _cleanup_spawned(main_scene: Node, spawned: Array) -> void:
	var enemies := main_scene.get("enemies") as Array
	for enemy in spawned:
		enemies.erase(enemy)
		if is_instance_valid(enemy):
			(enemy as Node).queue_free()


# ── ③ 소탕 = 안전 ────────────────────────────────────────────────

func _probe_squad_clear(main_scene: Node, director, player: CharacterBody3D) -> void:
	var enemies := main_scene.get("enemies") as Array
	# squad_id ≥ 0 무리 중 가장 작은 것을 고른다.
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
	_assert(not squads.is_empty(), "③ 소탕 대상 스쿼드가 있어야 합니다.")
	if squads.is_empty():
		return
	var target_squad_id := -1
	for squad_id in squads:
		if target_squad_id < 0 or (squads[squad_id] as Array).size() < (squads[target_squad_id] as Array).size():
			target_squad_id = squad_id
	var members := squads[target_squad_id] as Array
	# 마지막 한 명만 남기고 정리한다.
	while members.size() > 1:
		var member = members.pop_back()
		member.call("take_hit", 999999, Vector3(0.0, 0.0, 1.0))
		await physics_frame
	_assert(
		int(director.get("run_squads_cleared")) == 0,
		"③ 마지막 생존자가 남아 있는 동안 소탕이 울리면 안 됩니다."
	)
	var last_member = members[0]
	var corpse_position: Vector3 = (last_member as Node3D).global_position
	var pressure_before := float(main_scene.get("raid_pressure_points"))
	var anchors_before := (director.get("cleared_squad_anchors") as Array).size()
	var loot_before := _count_loot_near(main_scene, corpse_position, 4.0)
	last_member.call("take_hit", 999999, Vector3(0.0, 0.0, 1.0))
	# died.emit은 동기 — 같은 프레임에 전부 정산돼 있어야 한다.
	_assert(
		int(director.get("run_squads_cleared")) == 1,
		"③ 스쿼드 전멸 시 소탕이 1회 울려야 합니다: %d" % int(director.get("run_squads_cleared"))
	)
	_assert(
		(director.get("cleared_squad_anchors") as Array).size() == anchors_before + 1,
		"③ 소탕 앵커가 등록돼야 합니다."
	)
	var pressure_delta := float(main_scene.get("raid_pressure_points")) - pressure_before
	var expected_delta: float = RAID_EVENT_DIRECTOR.PRESSURE_PER_KILL - SQUAD_CLEAR_PRESSURE_RELIEF
	_assert(
		absf(pressure_delta - expected_delta) < 0.01,
		"③ 소탕 킬의 긴장도 변화는 +22−18=+%.0f여야 합니다: %+.2f" % [expected_delta, pressure_delta]
	)
	var loot_after := _count_loot_near(main_scene, corpse_position, 4.0)
	_assert(
		loot_after > loot_before,
		"③ 소탕 보너스 드랍이 시체 주변에 생겨야 합니다: %d → %d" % [loot_before, loot_after]
	)
	# 토스트 — "소탕" 문구가 스택에 있어야 한다.
	var hud = main_scene.get("hud")
	var toast_found := _find_label_with_text(hud.get("toast_stack") as Node, "소탕")
	_assert(toast_found, "③ '구역 소탕' 토스트가 떠야 합니다.")
	# 지도 — cleared 타입 마커.
	var tactical_map = main_scene.get("tactical_map")
	var marker_found := false
	for marker in (tactical_map.get("raid_markers") as Array):
		if str((marker as Dictionary).get("id", "")).begins_with("squad_cleared_"):
			marker_found = str((marker as Dictionary).get("type", "")) == "cleared"
			break
	# 소탕 구역 지도 마커는 폐지됐다(2026-09-01 유저: "소탕 구역이 남을 필요는 없지").
	_assert(not marker_found, "③ 전술 지도에 cleared 마커가 남지 않아야 합니다(폐지).")
	# 증원 목적지 회피 — 앵커 26m 옆에서 자리를 뽑아도 18m 안은 나오지 않는다.
	var anchor: Vector3 = (director.get("cleared_squad_anchors") as Array).back()
	player.global_position = anchor + Vector3(26.0, 0.0, 0.0)
	player.force_update_transform()
	await physics_frame
	var valid_samples := 0
	var violations := 0
	for sample_index in 24:
		var candidate = director.call("_find_reinforcement_position")
		if candidate == Vector3.INF:
			continue
		valid_samples += 1
		if (candidate as Vector3).distance_to(anchor) < SQUAD_CLEAR_ANCHOR_RADIUS:
			violations += 1
	_assert(valid_samples > 0, "③ 증원 자리 표본이 하나는 나와야 합니다.")
	_assert(
		violations == 0,
		"③ 소탕 앵커 18m 안에 증원 자리가 잡히면 안 됩니다: %d/%d" % [violations, valid_samples]
	)
	print("PROBE_SQUAD_CLEAR_OK pressure_delta=%+.1f samples=%d" % [pressure_delta, valid_samples])


func _count_loot_near(main_scene: Node, center: Vector3, radius: float) -> int:
	var count := 0
	for child in main_scene.get_children():
		if not child is Node3D or not str(child.name).begins_with("Loot_"):
			continue
		var flat := (child as Node3D).global_position
		flat.y = center.y
		if flat.distance_to(center) <= radius:
			count += 1
	return count


func _find_label_with_text(node: Node, needle: String) -> bool:
	if node == null:
		return false
	if node is Label and needle in (node as Label).text:
		return true
	for child in node.get_children():
		if _find_label_with_text(child, needle):
			return true
	return false


# ── ④ 명중 마이크로 셰이크 ───────────────────────────────────────

func _probe_hit_shake(main_scene: Node, player: CharacterBody3D) -> void:
	# 셰이크 감쇠(_process)가 측정을 흔들지 않게 메인 갱신을 멈춘다.
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	var hit_position: Vector3 = player.global_position + Vector3(2.0, 0.5, 2.0)
	# (a) 피해 30 → MIN~MAX 사이 피해 비례(상수 기준 — 셰이크 재조정에 따라온다).
	var min_kick := float(main_scene.get("HIT_SHAKE_MIN_KICK"))
	var max_kick := float(main_scene.get("HIT_SHAKE_MAX_KICK"))
	var full_damage := float(main_scene.get("HIT_SHAKE_FULL_KICK_DAMAGE"))
	var emphasis := float(main_scene.get("HIT_SHAKE_EMPHASIS_SCALE"))
	var strength_cap := float(main_scene.get("HIT_SHAKE_STRENGTH_CAP"))
	var expected_a := lerpf(min_kick, max_kick, clampf(30.0 / full_damage, 0.0, 1.0))
	main_scene.set("camera_shake_strength", 0.0)
	main_scene.set("camera_shake_time", 0.0)
	main_scene.set("last_hit_shake_msec", 0)
	main_scene.call("notify_player_projectile_hit", hit_position, false, 30, "body", false)
	var strength := float(main_scene.get("camera_shake_strength"))
	_assert(absf(strength - expected_a) < 0.001, "④ 피해 30 명중 셰이크는 %.4f여야 합니다: %.4f" % [expected_a, strength])
	_assert(float(main_scene.get("camera_shake_time")) >= 0.09, "④ 명중 셰이크 지속 ≥0.09s")
	# (b) 스로틀 90ms — 같은 프레임 연속 명중은 가산되지 않는다.
	main_scene.call("notify_player_projectile_hit", hit_position, false, 30, "body", false)
	_assert(
		absf(float(main_scene.get("camera_shake_strength")) - strength) < 0.0001,
		"④ 90ms 안의 두 번째 명중은 스로틀돼야 합니다: %.4f" % float(main_scene.get("camera_shake_strength"))
	)
	# (c) 스로틀이 풀리면 가산 + 헤드샷 ×1.6 (0.035 + 0.035×1.6 = 0.091).
	# 스로틀은 실제 시계(Time.get_ticks_msec) 기준이다 — 헤드리스는 프레임이
	# 실시간보다 빨리 돌므로 create_timer가 아니라 실제 ms로 기다린다.
	await _wait_real_msec(150)
	main_scene.call("notify_player_projectile_hit", hit_position, false, 30, "head", false)
	var stacked := float(main_scene.get("camera_shake_strength"))
	var expected_c := minf(strength_cap, expected_a + expected_a * emphasis)
	_assert(absf(stacked - expected_c) < 0.001, "④ 헤드샷 명중은 ×%.1f 가산·상한(%.4f)이어야 합니다: %.4f" % [emphasis, expected_c, stacked])
	# (d) 총 상한 0.2 — 처치 셰이크(0.26)보다 항상 작다.
	await _wait_real_msec(150)
	main_scene.set("camera_shake_strength", 0.19)
	main_scene.call("notify_player_projectile_hit", hit_position, false, 60, "head", false)
	var capped := float(main_scene.get("camera_shake_strength"))
	# 이미 더 큰 셰이크(0.19)가 도는 중이면 깎지 않고(maxf), 명중 가산 상한은 처치 셰이크보다 작다.
	_assert(absf(capped - 0.19) < 0.001, "④ 이미 큰 셰이크(0.19)는 명중 가산이 깎지 않는다: %.4f" % capped)
	_assert(strength_cap < 0.26, "④ 명중 셰이크 상한(%.3f)은 처치 셰이크(0.26)보다 작아야 합니다." % strength_cap)
	# (e) 더 큰 셰이크(처치·피격)가 도는 중이면 깎지 않는다.
	await _wait_real_msec(150)
	main_scene.set("camera_shake_strength", 0.5)
	main_scene.call("notify_player_projectile_hit", hit_position, false, 30, "body", false)
	_assert(
		is_equal_approx(float(main_scene.get("camera_shake_strength")), 0.5),
		"④ 진행 중인 큰 셰이크를 명중 셰이크가 줄이면 안 됩니다: %.4f" % float(main_scene.get("camera_shake_strength"))
	)
	# (f) 피해 0(차단 등)은 셰이크 없음.
	await _wait_real_msec(150)
	main_scene.set("camera_shake_strength", 0.0)
	main_scene.call("notify_player_projectile_hit", hit_position, false, 0, "body", false)
	_assert(
		float(main_scene.get("camera_shake_strength")) == 0.0,
		"④ 피해 0 통지는 셰이크를 만들지 않습니다."
	)
	main_scene.set_process(true)
	main_scene.set_physics_process(true)
	print("PROBE_HIT_SHAKE_OK base=%.3f stacked=%.3f cap=%.3f" % [strength, stacked, capped])


func _wait_real_msec(milliseconds: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < milliseconds:
		await process_frame
