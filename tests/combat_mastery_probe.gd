extends SceneTree

# 전투 숙련도 패키지 프로브(헤드리스) — 공격 예고 · 약점(헤드샷) · 엄폐 · DPS 불변.
#   ① 척탄병 와인드업 0.9s 동안 예고 노드(착탄 원+포물선) 존재, 착탄 원 반경 = 폭발 반경,
#      예고 중 원 밖으로 이동하면 피해 0 / 머물면 피해 > 0
#   ② 사수 첫 발 0.35s 전 조준선 노드(엘리트 0.25s), 고위협 와인드업 연장분만큼 쿨다운 차감
#      (탄창을 다 비우는 점사는 쿨다운 분기를 안 타므로 장전 선행으로 갚는지도 본다)
#   ②' 근접 돌진 예고 — 와인드업 0.5s 동안 바닥 화살표, 쿨다운은 그만큼 짧아짐
#   ③ 헤드샷 판정 y 경계(상단 28%) · 피해 ×2.2(비엘리트 경무장)/×1.6(상위 무장)/×1.35(엘리트) · 팝 색(주황) · 보스 포이즈 ×1.5
#   ④ 모바일 정조준 상승 — 정지 0.5s 후 조준 높이 0.5→0.86, 브래킷이 머리로(화면 y 감소)
#   ⑤ 엄폐 v2 — 3상태(open/covered/peeking): covered는 총알 완전 차단(×0.55 폐지),
#      조준=내밈(피해 정상), 사격 후 0.5s 노출, 폭발은 차단 안 됨, HUD 칩 3단
#   ⑥ 적 DPS 총량 불변 — 예고 전(legacy) / 후 타이밍을 같은 시드로 60s(게임 시간) 병렬 시뮬, ±10%
#
# 실행: godot --headless --path . --script tests/combat_mastery_probe.gd

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BOSS_SCRIPT := preload("res://scripts/rocket_boss.gd")
const BULLET_SCRIPT := preload("res://scripts/bullet_projectile.gd")
const GRENADE_SCRIPT := preload("res://scripts/enemy_grenade.gd")
const TELEGRAPH := preload("res://scripts/raid/telegraph_fx.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const DUMMY_SOURCE := """
extends CharacterBody3D
var damage_taken := 0
var hits := 0
func take_hostile_hit(amount: int, _hit_direction: Vector3, _attacker = null, _source_position = null) -> void:
	damage_taken += amount
	hits += 1
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
		push_error("COMBAT_MASTERY_PROBE_TIMEOUT")
		quit(2)
	)
	dummy_script = GDScript.new()
	dummy_script.source_code = DUMMY_SOURCE
	dummy_script.reload()
	var accessibility := root.get_node("AccessibilitySettings")
	accessibility.set("damage_numbers_enabled", true)
	Engine.max_physics_steps_per_frame = 64

	var arena := Node3D.new()
	arena.name = "MasteryArena"
	root.add_child(arena)
	await process_frame
	await physics_frame

	await _probe_grenadier_telegraph(arena)
	await _probe_aim_line(arena)
	await _probe_melee_telegraph(arena)
	await _probe_headshot(arena)
	await _probe_boss_headshot_poise(arena)
	await _probe_dps_parity(arena)
	arena.queue_free()
	await process_frame
	await _probe_main_scene()

	if failures.is_empty():
		print("COMBAT_MASTERY_PROBE_OK")
		quit(0)
	else:
		print("COMBAT_MASTERY_PROBE_FAILED %d" % failures.size())
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


func _make_enemy(
	parent: Node,
	kind: String,
	world_position: Vector3,
	threat: float,
	weapon_id: String,
	target: CharacterBody3D,
	alert_now := true
) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "Probe_%s" % kind
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = world_position
	parent.add_child(enemy)
	enemy.call("configure", kind, target, {}, threat, weapon_id)
	enemy.call("set_player_visibility_factor", 1.0)
	if alert_now:
		_force_alert(enemy)
	return enemy


func _force_alert(enemy: CharacterBody3D) -> void:
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("combat_reaction_time", 0.0)
	enemy.set("pursuit_time", 100.0)
	enemy.set("perception_state", "combat")
	enemy.set("attack_cooldown", 0.0)
	enemy.set("grenade_cooldown", 0.0)
	enemy.set("opening_shot_pending", false)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _count_children_with_script(parent: Node, script: Script) -> int:
	# 같은 이름의 자식은 "@클래스@id"로 바뀌므로 이름 대신 스크립트로 센다.
	var count := 0
	for child in parent.get_children():
		if child.get_script() == script:
			count += 1
	return count


func _latest_damage_number(parent: Node) -> Label3D:
	for index in range(parent.get_child_count() - 1, -1, -1):
		var child := parent.get_child(index)
		if child is Label3D and child.name == "DamageNumber" and child.visible:
			return child as Label3D
	return null


# ── ① 척탄병 예고 ───────────────────────────────────────────────

func _probe_grenadier_telegraph(arena: Node3D) -> void:
	TELEGRAPH.reset_counters()
	var dodge_dummy := _make_dummy(arena, Vector3(0.0, 0.78, 0.0))
	var dodge_enemy := _make_enemy(arena, "grenadier", Vector3(12.0, 0.7, 0.0), 0.3, "", dodge_dummy)
	var stay_dummy := _make_dummy(arena, Vector3(60.0, 0.78, 0.0))
	var stay_enemy := _make_enemy(arena, "grenadier", Vector3(72.0, 0.7, 0.0), 0.3, "", stay_dummy)
	var windup_started := await _wait_until(
		func() -> bool: return str(dodge_enemy.get("combat_state")) == "grenade_windup" and str(stay_enemy.get("combat_state")) == "grenade_windup",
		4.0
	)
	_assert(windup_started, "① 척탄병 둘 다 4초 안에 투척 와인드업에 들어가야 합니다.")
	var windup_timer := float(dodge_enemy.get("state_timer"))
	_assert(windup_timer >= 0.86 and windup_timer <= 0.9001, "① 투척 와인드업은 0.9s여야 합니다: %.3f" % windup_timer)
	var telegraph_count := int(dodge_enemy.call("get_active_telegraph_count"))
	_assert(telegraph_count >= 2, "① 와인드업 중 예고 노드(착탄 원+포물선)가 있어야 합니다: %d" % telegraph_count)
	var circles: Array[Node3D] = TELEGRAPH.get_active_nodes(TELEGRAPH.KIND_LANDING)
	var arcs: Array[Node3D] = TELEGRAPH.get_active_nodes(TELEGRAPH.KIND_ARC)
	_assert(circles.size() >= 2 and arcs.size() >= 2, "① 착탄 원 %d·포물선 %d — 적 2명분이 떠야 합니다." % [circles.size(), arcs.size()])
	var circle_radius := -1.0
	var circle_near_target := false
	for circle in circles:
		circle_radius = float(circle.get_meta("radius", -1.0))
		var flat := Vector3(circle.global_position.x, 0.0, circle.global_position.z)
		if flat.distance_to(Vector3(0.0, 0.0, 0.0)) < 0.6 or flat.distance_to(Vector3(60.0, 0.0, 0.0)) < 0.6:
			circle_near_target = true
	_assert(is_equal_approx(circle_radius, float(ENEMY_SCRIPT.GRENADE_BLAST_RADIUS)) and is_equal_approx(circle_radius, 3.15), "① 착탄 원 반경은 실제 폭발 반경(3.15)이어야 합니다: %.2f" % circle_radius)
	_assert(circle_near_target, "① 착탄 원은 표적 위치에 떠야 합니다.")
	var grenade_windup_sound := str(root.get_node("SfxBank") != null)
	# 예고 중 이동 → 원 밖(반경 3.15 + 여유)으로.
	dodge_dummy.global_position = Vector3(0.0, 0.78, 6.0)
	dodge_dummy.force_update_transform()
	# 와인드업 중반에도 예고가 살아 있어야 한다.
	await create_timer(0.45).timeout
	_assert(str(dodge_enemy.get("combat_state")) == "grenade_windup", "① 0.45s 뒤에도 아직 와인드업이어야 합니다: %s" % str(dodge_enemy.get("combat_state")))
	_assert(int(dodge_enemy.call("get_active_telegraph_count")) >= 2, "① 와인드업 중반에도 예고가 떠 있어야 합니다.")
	var thrown := await _wait_until(
		func() -> bool: return _count_children_with_script(arena, GRENADE_SCRIPT) >= 2,
		2.0
	)
	if not thrown:
		var names := PackedStringArray()
		for child in arena.get_children():
			names.append(str(child.name))
		print("PROBE_GRENADIER_DEBUG dodge_state=%s stay_state=%s dodge_cd=%.2f stay_cd=%.2f children=%s" % [
			str(dodge_enemy.get("combat_state")), str(stay_enemy.get("combat_state")),
			float(dodge_enemy.get("grenade_cooldown")), float(stay_enemy.get("grenade_cooldown")), ", ".join(names),
		])
	_assert(thrown, "① 와인드업이 끝나면 수류탄 2개가 던져져야 합니다.")
	# 수류탄 비행(0.88)+신관(2.45) 뒤 폭발.
	var exploded := await _wait_until(
		func() -> bool:
			var all_done := true
			var any := false
			for child in arena.get_children():
				if child.get_script() == GRENADE_SCRIPT:
					any = true
					if not bool(child.get("exploded")):
						all_done = false
			return any and all_done,
		6.0
	)
	_assert(exploded, "① 수류탄은 6초 안에 폭발해야 합니다.")
	_assert(int(dodge_dummy.get("damage_taken")) == 0, "① 예고 중 원 밖으로 나간 표적은 피해 0이어야 합니다: %d" % int(dodge_dummy.get("damage_taken")))
	_assert(int(stay_dummy.get("damage_taken")) > 0, "① 원 안에 머문 표적은 피해를 받아야 합니다: %d" % int(stay_dummy.get("damage_taken")))
	# 예고는 폭발 전(와인드업+비행)에 거둬진다.
	_assert(int(dodge_enemy.call("get_active_telegraph_count")) == 0, "① 폭발 후 예고 노드가 남아 있으면 안 됩니다.")
	print("PROBE_GRENADIER_OK windup=%.2f radius=%.2f dodge_damage=%d stay_damage=%d sfx=%s" % [
		windup_timer, circle_radius, int(dodge_dummy.get("damage_taken")), int(stay_dummy.get("damage_taken")), grenade_windup_sound,
	])
	for node in [dodge_enemy, stay_enemy, dodge_dummy, stay_dummy]:
		node.queue_free()
	await process_frame


# ── ② 사수 조준선 예고 ──────────────────────────────────────────

func _probe_aim_line(arena: Node3D) -> void:
	var normal_dummy := _make_dummy(arena, Vector3(120.0, 0.78, 0.0))
	var normal_enemy := _make_enemy(arena, "ranged", Vector3(130.0, 0.7, 0.0), 0.3, "m1911", normal_dummy)
	var elite_dummy := _make_dummy(arena, Vector3(180.0, 0.78, 0.0))
	var elite_enemy := _make_enemy(arena, "ranged", Vector3(190.0, 0.7, 0.0), 0.3, "mp5", elite_dummy)
	elite_enemy.call("promote_to_elite", "프로브 정예")
	# 고위협 사수는 ak47(탄창 12) — m1911(탄창 6)은 점사 한 번에 탄창이 비어
	# 쿨다운 분기를 아예 안 타므로 '쿨다운 차감'을 잴 수 없다. 그 경로는 아래
	# drain 레인에서 '장전 선행으로 갚는가'로 따로 본다.
	var hot_dummy := _make_dummy(arena, Vector3(240.0, 0.78, 0.0))
	var hot_enemy := _make_enemy(arena, "ranged", Vector3(250.0, 0.7, 0.0), 0.9, "ak47", hot_dummy)
	var started := await _wait_until(
		func() -> bool:
			return (
				str(normal_enemy.get("combat_state")) == "ranged_windup"
				and str(elite_enemy.get("combat_state")) == "ranged_windup"
				and str(hot_enemy.get("combat_state")) == "ranged_windup"
			),
		4.0
	)
	_assert(started, "② 사수 셋이 4초 안에 점사 와인드업에 들어가야 합니다.")
	# 고위협(0.9): 기본 와인드업 0.206 < 예고 0.35 → 0.35까지 연장, 연장분 0.144.
	var hot_extension := float(hot_enemy.get("ranged_windup_extension"))
	_assert(absf(hot_extension - 0.144) < 0.01, "② 위협 0.9 사수의 와인드업 연장분은 0.144여야 합니다: %.3f" % hot_extension)
	var hot_windup := float(hot_enemy.get("state_timer"))
	_assert(absf(hot_windup - 0.35) < 0.02, "② 연장된 와인드업은 0.35s여야 합니다: %.3f" % hot_windup)
	var normal_extension := float(normal_enemy.get("ranged_windup_extension"))
	_assert(is_zero_approx(normal_extension), "② 위협 0.3 사수(기본 0.362s)는 연장이 없어야 합니다: %.3f" % normal_extension)
	var lines_shown := await _wait_until(
		func() -> bool: return bool(normal_enemy.get("aim_line_shown")) and bool(elite_enemy.get("aim_line_shown")) and bool(hot_enemy.get("aim_line_shown")),
		1.0
	)
	_assert(lines_shown, "② 와인드업 중 조준선이 셋 다 떠야 합니다.")
	var normal_remaining := float(normal_enemy.get("last_aim_line_remaining"))
	var elite_remaining := float(elite_enemy.get("last_aim_line_remaining"))
	var hot_remaining := float(hot_enemy.get("last_aim_line_remaining"))
	_assert(normal_remaining <= 0.3501 and normal_remaining >= 0.30, "② 일반 사수 조준선은 첫 발 0.35s 전(한 프레임 오차)에 떠야 합니다: %.3f" % normal_remaining)
	_assert(elite_remaining <= 0.2501 and elite_remaining >= 0.20, "② 엘리트 조준선은 첫 발 0.25s 전에 떠야 합니다: %.3f" % elite_remaining)
	_assert(hot_remaining <= 0.3501 and hot_remaining >= 0.30, "② 고위협 사수도 연장 덕에 0.35s 전 조준선이 떠야 합니다: %.3f" % hot_remaining)
	var aim_nodes := TELEGRAPH.get_active_count(TELEGRAPH.KIND_AIM_LINE)
	_assert(aim_nodes >= 1, "② 조준선 예고 노드가 떠 있어야 합니다: %d" % aim_nodes)
	# 점사가 끝난 순간 적용된 쿨다운 = 기본 쿨다운 − 연장분(적이 last_burst_cooldown에 기록).
	var hot_cooldown_old := float(hot_enemy.call("_get_weapon_burst_cooldown"))
	var hot_fired := await _wait_until(
		func() -> bool: return str(hot_enemy.get("combat_state")) == "pistol_burst",
		1.0
	)
	_assert(hot_fired, "② 와인드업 뒤 점사가 시작돼야 합니다.")
	var hot_cooldown_applied := await _wait_until(
		func() -> bool: return float(hot_enemy.get("last_burst_cooldown")) >= 0.0,
		5.0
	)
	if not hot_cooldown_applied:
		print("PROBE_AIM_LINE_TRACE state=%s mag=%d rem=%d timer=%.3f cd=%.3f los=%s" % [
			str(hot_enemy.get("combat_state")), int(hot_enemy.get("magazine_ammo")),
			int(hot_enemy.get("burst_shots_remaining")), float(hot_enemy.get("state_timer")),
			float(hot_enemy.get("attack_cooldown")), str(hot_enemy.get("has_current_line_of_sight")),
		])
	_assert(hot_cooldown_applied, "② 점사가 끝나면 쿨다운이 적용돼야 합니다.")
	var cooldown_applied := float(hot_enemy.get("last_burst_cooldown"))
	var expected := hot_cooldown_old - 0.144
	_assert(absf(cooldown_applied - expected) < 0.002, "② 점사 후 쿨다운은 기본 %.3f − 연장 0.144 = %.3f여야 합니다: %.3f" % [hot_cooldown_old, expected, cooldown_applied])
	# 탄창을 다 비우는 점사 — 쿨다운 분기를 안 타는 대신 장전을 그만큼 앞당겨 갚는다.
	var drain_dummy := _make_dummy(arena, Vector3(300.0, 0.78, -60.0))
	var drain_enemy := _make_enemy(arena, "ranged", Vector3(310.0, 0.7, -60.0), 0.9, "m1911", drain_dummy)
	var drained := await _wait_until(
		func() -> bool: return float(drain_enemy.get("last_windup_compensation")) >= 0.0,
		6.0
	)
	_assert(drained, "② 탄창을 비우는 점사도 연장분을 되돌려줘야 합니다(보상이 기록되지 않음).")
	var drain_compensation := float(drain_enemy.get("last_windup_compensation"))
	_assert(
		absf(drain_compensation - 0.144) < 0.01,
		"② m1911 고위협은 장전을 0.144s 앞당겨 연장분을 갚아야 합니다: %.3f" % drain_compensation
	)
	_assert(
		str(drain_enemy.get("combat_state")) == "reloading" or float(drain_enemy.get("reload_elapsed")) > 0.0,
		"② 보상은 장전 진행도(reload_elapsed) 선행으로 들어가야 합니다."
	)
	print("PROBE_AIM_LINE_OK normal=%.3f elite=%.3f hot=%.3f ext=%.3f cooldown=%.3f drain_comp=%.3f" % [
		normal_remaining, elite_remaining, hot_remaining, hot_extension, cooldown_applied, drain_compensation,
	])
	for node in [normal_enemy, elite_enemy, hot_enemy, drain_enemy, normal_dummy, elite_dummy, hot_dummy, drain_dummy]:
		node.queue_free()
	await process_frame
	await physics_frame


# ── ②' 근접 돌진 예고 ───────────────────────────────────────────

func _probe_melee_telegraph(arena: Node3D) -> void:
	var dummy := _make_dummy(arena, Vector3(500.0, 0.78, 0.0))
	var enemy := _make_enemy(arena, "melee", Vector3(501.0, 0.7, 0.0), 0.5, "", dummy)
	var winding := await _wait_until(
		func() -> bool: return str(enemy.get("combat_state")) == "melee_windup",
		5.0
	)
	_assert(winding, "②' 근접 적이 5초 안에 돌진 와인드업에 들어가야 합니다: %s" % str(enemy.get("combat_state")))
	# state_timer·attack_cooldown은 프레임마다 감소하므로 관측값은 설정값보다 한두
	# 프레임(≤0.04s) 낮게 잡힌다 — 상한은 딱 맞추고 하한만 그만큼 여유를 준다.
	var windup := float(enemy.get("state_timer"))
	_assert(windup > 0.45 and windup <= 0.5001, "②' 근접 와인드업(예고 시간)은 0.5s여야 합니다: %.3f" % windup)
	var arrows := TELEGRAPH.get_active_count(TELEGRAPH.KIND_DASH_ARROW)
	_assert(arrows >= 1, "②' 와인드업 중 바닥 돌진 화살표가 떠야 합니다: %d" % arrows)
	_assert(int(enemy.call("get_active_telegraph_count")) >= 1, "②' 적이 예고 노드를 들고 있어야 합니다.")
	# 늘린 0.04만큼 쿨다운이 짧아졌는지 — 위협 0.5에서 1.16→0.78 보간 = 0.97(예전 1.01).
	var cooldown := float(enemy.get("attack_cooldown"))
	_assert(cooldown > 0.92 and cooldown <= 0.9701, "②' 돌진 쿨다운은 예전 1.01에서 0.04 줄어든 0.97이어야 합니다: %.3f" % cooldown)
	print("PROBE_MELEE_TELEGRAPH_OK windup=%.2f arrows=%d cooldown=%.3f" % [windup, arrows, cooldown])
	for node in [enemy, dummy]:
		node.queue_free()
	await process_frame
	await physics_frame


# ── ③ 헤드샷 ─────────────────────────────────────────────────────

func _fire_probe_bullet(arena: Node3D, shooter: Node3D, enemy: CharacterBody3D, damage: int, settings: Dictionary) -> void:
	var bullet := Area3D.new()
	bullet.name = "ProbeBullet"
	bullet.set_script(BULLET_SCRIPT)
	bullet.set("direction", Vector3(0.0, 0.0, 1.0))
	bullet.set("source_body", shooter)
	bullet.set("damage", damage)
	bullet.set("hostile", false)
	bullet.set("critical_chance", 0.0)
	for key in settings.keys():
		bullet.set(key, settings[key])
	bullet.position = enemy.global_position + Vector3(0.0, 0.0, -1.6)
	arena.add_child(bullet)


func _probe_headshot(arena: Node3D) -> void:
	var shooter := _make_dummy(arena, Vector3(300.0, 0.78, -10.0))
	var enemy := _make_enemy(arena, "melee", Vector3(300.0, 0.7, 0.0), 0.3, "", shooter, false)
	enemy.set_physics_process(false)
	enemy.set("health", 100000)
	enemy.set("max_health", 100000)
	var height := float(enemy.call("get_world_height"))
	var feet_y := float(enemy.call("get_feet_world_y"))
	var head_zone := float(enemy.call("get_head_zone_ratio"))
	_assert(is_equal_approx(head_zone, 0.28), "③ 머리 영역은 상단 28%%여야 합니다: %.2f" % head_zone)
	_assert(is_equal_approx(height, 1.62), "③ 일반 적 월드 높이 1.62: %.2f" % height)
	_assert(is_equal_approx(feet_y, enemy.global_position.y - 0.7), "③ 발 위치는 캡슐 중심 −0.7")

	# (a) 모바일 경로: 조준 높이 비율 0.80 → 머리. 피해 = round(50×1.3(center)) ×1.6.
	var health_before := int(enemy.get("health"))
	_fire_probe_bullet(arena, shooter, enemy, 50, {"aim_height_ratio": 0.8})
	var hit_a := await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	_assert(hit_a, "③(a) 프로브 탄이 적을 맞혀야 합니다.")
	var damage_a := health_before - int(enemy.get("health"))
	_assert(bool(enemy.get("last_hit_was_headshot")), "③(a) 조준 높이 0.80은 헤드샷이어야 합니다.")
	# 정밀 헤드샷(전투 코어 2차) — 비엘리트 근접(배트)은 ×2.2.
	_assert(damage_a == roundi(roundi(50 * 1.3) * 2.2), "③(a) 헤드샷 피해는 65×2.2=143이어야 합니다: %d" % damage_a)
	var pop := _latest_damage_number(arena)
	_assert(pop != null, "③(a) 데미지 팝이 떠야 합니다.")
	if pop != null:
		var pop_color := Color(pop.modulate.r, pop.modulate.g, pop.modulate.b)
		var expected_color := Color("#ff8a2a")
		_assert(pop_color.is_equal_approx(expected_color) or (absf(pop_color.r - expected_color.r) < 0.02 and absf(pop_color.g - expected_color.g) < 0.02 and absf(pop_color.b - expected_color.b) < 0.02), "③(a) 헤드샷 팝은 주황(#ff8a2a)이어야 합니다: %s" % str(pop_color))
	# (b) 경계: 0.71 → 몸, 0.72 → 머리.
	health_before = int(enemy.get("health"))
	_fire_probe_bullet(arena, shooter, enemy, 50, {"aim_height_ratio": 0.71})
	await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	var damage_b := health_before - int(enemy.get("health"))
	_assert(not bool(enemy.get("last_hit_was_headshot")) and damage_b == 65, "③(b) 조준 높이 0.71은 몸(65)이어야 합니다: head=%s dmg=%d" % [str(enemy.get("last_hit_was_headshot")), damage_b])
	health_before = int(enemy.get("health"))
	_fire_probe_bullet(arena, shooter, enemy, 50, {"aim_height_ratio": 0.72})
	await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	var damage_c := health_before - int(enemy.get("health"))
	_assert(bool(enemy.get("last_hit_was_headshot")) and damage_c == 143, "③(b) 조준 높이 0.72(경계)는 머리(143)여야 합니다: head=%s dmg=%d" % [str(enemy.get("last_hit_was_headshot")), damage_c])
	# (c) 마우스 경로: 화면 레이가 적 수직축을 머리 높이(0.8)에서 지나면 머리, 실루엣 밖이면 몸.
	var ray_direction := Vector3(-1.0, -1.0, -1.0).normalized()
	var head_point := Vector3(enemy.global_position.x, feet_y + height * 0.8, enemy.global_position.z)
	health_before = int(enemy.get("health"))
	_fire_probe_bullet(arena, shooter, enemy, 50, {"aim_ray_origin": head_point - ray_direction * 20.0, "aim_ray_direction": ray_direction})
	await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	var damage_d := health_before - int(enemy.get("health"))
	_assert(bool(enemy.get("last_hit_was_headshot")) and damage_d == 143, "③(c) 마우스 레이가 머리 높이를 지나면 헤드샷이어야 합니다: head=%s dmg=%d" % [str(enemy.get("last_hit_was_headshot")), damage_d])
	var side := Vector3(1.0, 0.0, -1.0).normalized() * 0.9
	health_before = int(enemy.get("health"))
	_fire_probe_bullet(arena, shooter, enemy, 50, {"aim_ray_origin": head_point + side - ray_direction * 20.0, "aim_ray_direction": ray_direction})
	await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	var damage_e := health_before - int(enemy.get("health"))
	_assert(not bool(enemy.get("last_hit_was_headshot")) and damage_e == 65, "③(c) 커서가 실루엣(0.62u) 밖이면 몸이어야 합니다: head=%s dmg=%d" % [str(enemy.get("last_hit_was_headshot")), damage_e])
	_assert(int(enemy.get("headshots_taken")) == 3, "③ 헤드샷 집계 3회: %d" % int(enemy.get("headshots_taken")))
	# (d) 엘리트 ×1.35.
	var elite := _make_enemy(arena, "ranged", Vector3(300.0, 0.7, 20.0), 0.3, "mp5", shooter, false)
	elite.set_physics_process(false)
	elite.call("promote_to_elite", "프로브 정예")
	elite.set("health", 100000)
	elite.set("max_health", 100000)
	var elite_height := float(elite.call("get_world_height"))
	_assert(absf(elite_height - 1.62 * 1.18) < 0.001, "③(d) 엘리트 월드 높이는 스프라이트 배율(×1.18)을 따른다: %.3f" % elite_height)
	health_before = int(elite.get("health"))
	_fire_probe_bullet(arena, shooter, elite, 50, {"aim_height_ratio": 0.85})
	await _wait_until(func() -> bool: return int(elite.get("health")) < health_before, 1.0)
	var damage_f := health_before - int(elite.get("health"))
	_assert(bool(elite.get("last_hit_was_headshot")) and damage_f == roundi(65 * 1.35), "③(d) 엘리트 헤드샷은 65×1.35=88이어야 합니다: %d" % damage_f)
	# (e) 적탄(hostile)은 약점 판정 없음 — 헤드샷 집계가 늘지 않는다.
	var hostile_bullet := Area3D.new()
	hostile_bullet.set_script(BULLET_SCRIPT)
	hostile_bullet.set("direction", Vector3(0.0, 0.0, 1.0))
	hostile_bullet.set("hostile", true)
	hostile_bullet.set("aim_height_ratio", 0.9)
	hostile_bullet.set("damage", 10)
	hostile_bullet.set("source_body", shooter)
	hostile_bullet.position = enemy.global_position + Vector3(0.0, 0.0, -1.6)
	arena.add_child(hostile_bullet)
	health_before = int(enemy.get("health"))
	await _wait_until(func() -> bool: return int(enemy.get("health")) < health_before, 1.0)
	_assert(int(enemy.get("headshots_taken")) == 3, "③(e) 적탄은 헤드샷 판정을 받지 않는다: %d" % int(enemy.get("headshots_taken")))
	print("PROBE_HEADSHOT_OK head=%d body=%d boundary=%d ray=%d side=%d elite=%d" % [damage_a, damage_b, damage_c, damage_d, damage_e, damage_f])
	for node in [enemy, elite, shooter]:
		node.queue_free()
	await process_frame


func _probe_boss_headshot_poise(arena: Node3D) -> void:
	var shooter := _make_dummy(arena, Vector3(400.0, 0.78, -10.0))
	var boss := CharacterBody3D.new()
	boss.name = "ProbeBoss"
	boss.set_script(BOSS_SCRIPT)
	boss.position = Vector3(400.0, 0.7, 0.0)
	boss.call("configure_rocket_boss", shooter, 0.3)
	arena.add_child(boss)
	_assert(bool(boss.get_meta("raid_boss", false)), "③ 보스는 raid_boss 메타를 스스로 단다.")
	boss.set_physics_process(false)
	boss.set("health", 100000)
	boss.set("max_health", 100000)
	_assert(is_equal_approx(float(boss.call("get_world_height")), 2.1), "③ 보스 월드 높이 2.1")
	_assert(is_equal_approx(float(boss.call("get_head_zone_ratio")), 0.24), "③ 보스 머리 영역 24%")
	var health_before := int(boss.get("health"))
	boss.call("take_projectile_hit", 20, Vector3.BACK, false, 1.65, "head", null)
	var damage := health_before - int(boss.get("health"))
	_assert(damage == roundi(20 * 1.35), "③ 보스 헤드샷 피해 ×1.35 = 27: %d" % damage)
	var poise := float(boss.get("poise_damage_accumulated"))
	_assert(absf(poise - 27.0 * 1.5) < 0.01, "③ 보스 헤드샷 포이즈 누적 ×1.5 = 40.5: %.2f" % poise)
	boss.call("take_projectile_hit", 20, Vector3.BACK, false, 1.65, "center", null)
	var poise_after_body := float(boss.get("poise_damage_accumulated"))
	_assert(absf(poise_after_body - (40.5 + 20.0)) < 0.01, "③ 몸 명중은 포이즈 ×1.0: %.2f" % poise_after_body)
	print("PROBE_BOSS_HEADSHOT_OK damage=%d poise=%.1f" % [damage, poise])
	boss.queue_free()
	shooter.queue_free()
	await process_frame


# ── ⑥ DPS 총량 불변 ───────────────────────────────────────────────

func _probe_dps_parity(arena: Node3D) -> void:
	# 같은 시드·같은 배치로 예고 전(legacy)/후 타이밍을 60s(게임 시간) 동시에 돌린다.
	# 측정은 '발사한 공격의 총 피해 잠재량'(점사 탄×탄 피해, 투척×28, 근접 타격 피해)이라
	# 산탄 운에 안 흔들린다. 허용 오차 ±10%.
	var configs := [
		{"kind": "grenadier", "weapon": "", "threat": 0.3, "distance": 12.0},
		{"kind": "ranged", "weapon": "m1911", "threat": 0.9, "distance": 10.0},
		{"kind": "ranged", "weapon": "ak47", "threat": 0.8, "distance": 16.0},
		{"kind": "melee", "weapon": "", "threat": 0.5, "distance": 1.2},
	]
	var lanes: Array[Dictionary] = []
	var lane_index := 0
	for config in configs:
		for legacy in [false, true]:
			var base_x := 1000.0 + float(lane_index) * 120.0
			var dummy := _make_dummy(arena, Vector3(base_x, 0.78, 0.0))
			# 표적이 '정지'로 분류되면 사수가 측면 우회(_update_stationary_target_flank)를 돌며
			# 사격을 건너뛰는데, 그 분기는 인스턴스 id에 따라 갈려 A/B가 안 맞는다.
			# 속도 값만 줘서(실제 이동 없음) 정지 표적 분기를 피한다.
			dummy.velocity = Vector3(0.5, 0.0, 0.0)
			var enemy := _make_enemy(
				arena, str(config["kind"]), Vector3(base_x + float(config["distance"]), 0.7, 0.0),
				float(config["threat"]), str(config["weapon"]), dummy
			)
			# 이동을 잠가 교전 거리를 고정한다 — 스트레이프·추격 드리프트(RNG)로 A/B가
			# 갈리지 않게. 공격 주기만 비교한다.
			enemy.axis_lock_linear_x = true
			enemy.axis_lock_linear_z = true
			enemy.set("legacy_attack_timing", legacy)
			(enemy.get("weapon_random") as RandomNumberGenerator).seed = 4242
			var lane := {
				"config": config, "legacy": legacy, "enemy": enemy, "dummy": dummy,
				"shots": 0, "grenades": 0, "potential": 0,
			}
			lanes.append(lane)
			lane_index += 1
	var counter := func(node: Node) -> void:
		# 탄·수류탄은 source_body(던진 적)로 레인을 찾는다(수류탄은 add_child 뒤에 위치가 잡힌다).
		if not node is Node3D:
			return
		var source = node.get("source_body")
		if source == null:
			return
		for lane in lanes:
			if lane["enemy"] != source:
				continue
			# 같은 이름의 자식은 "@클래스@id"로 바뀌므로 스크립트로 본다.
			if node.get_script() == BULLET_SCRIPT:
				lane["shots"] = int(lane["shots"]) + 1
				lane["potential"] = int(lane["potential"]) + int(node.get("damage"))
			elif node.get_script() == GRENADE_SCRIPT:
				lane["grenades"] = int(lane["grenades"]) + 1
				lane["potential"] = int(lane["potential"]) + int(node.get("damage"))
			break
	arena.child_entered_tree.connect(counter)
	Engine.time_scale = 8.0
	await create_timer(60.0).timeout
	Engine.time_scale = 1.0
	arena.child_entered_tree.disconnect(counter)
	var summary := PackedStringArray()
	for pair_index in range(0, lanes.size(), 2):
		var new_lane := lanes[pair_index]
		var old_lane := lanes[pair_index + 1]
		var kind := str(new_lane["config"]["kind"])
		var new_total := int(new_lane["potential"])
		var old_total := int(old_lane["potential"])
		if kind == "melee":
			new_total = int((new_lane["dummy"] as Node).get("damage_taken"))
			old_total = int((old_lane["dummy"] as Node).get("damage_taken"))
		var ratio := float(new_total) / float(maxi(1, old_total))
		_assert(old_total > 0 and new_total > 0, "⑥ %s 60s 시뮬에서 공격이 나와야 합니다(new=%d old=%d)" % [kind, new_total, old_total])
		_assert(absf(ratio - 1.0) <= 0.10, "⑥ %s DPS 총량은 예고 전후 ±10%% 안이어야 합니다: new=%d old=%d (%.1f%%)" % [kind, new_total, old_total, (ratio - 1.0) * 100.0])
		summary.append("%s:new=%d/old=%d(%+.1f%%)" % [kind, new_total, old_total, (ratio - 1.0) * 100.0])
	# 전투 중 생성된 예고 노드가 풀 상한을 넘게 쌓이지 않았는지(풀링).
	var telegraph_nodes := root.get_tree().get_nodes_in_group("telegraph_fx") if root.get_tree() != null else []
	_assert(telegraph_nodes.size() <= TELEGRAPH.MAX_POOL_PER_KIND * 4 + 8, "⑥ 예고 노드는 풀링돼야 합니다(총 %d)" % telegraph_nodes.size())
	print("PROBE_DPS_PARITY_OK " + " ".join(summary) + " telegraph_nodes=%d" % telegraph_nodes.size())
	for lane in lanes:
		(lane["enemy"] as Node).queue_free()
		(lane["dummy"] as Node).queue_free()
	await process_frame


# ── ④⑤ 메인 씬: 모바일 정조준 상승 · 엄폐 ──────────────────────────

func _probe_main_scene() -> void:
	var game_state := root.get_node("GameState")
	var lesson_backup := {
		"telegraph_lesson_seen": game_state.get("telegraph_lesson_seen"),
		"headshot_lesson_seen": game_state.get("headshot_lesson_seen"),
		"cover_lesson_seen": game_state.get("cover_lesson_seen"),
	}
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
	var weapon_combat = main_scene.get("weapon_combat")
	var cover_system = main_scene.get("cover_system")
	var hud = main_scene.get("hud")
	_assert(cover_system != null, "⑤ main에 cover_system이 붙어 있어야 합니다.")
	_assert(hud.get("cover_chip") != null, "⑤ HUD 엄폐 칩이 만들어져야 합니다.")
	# 적 총알이 프로브 중 플레이어를 때려 상태를 흔들지 않게 한다.
	player.collision_layer = 0

	# ── ④ 모바일 정조준 상승 ──
	var enemies := main_scene.get("enemies") as Array
	_assert(enemies.size() >= 1, "④ 필드에 적이 있어야 합니다.")
	var target := enemies[0] as CharacterBody3D
	target.set_physics_process(false)
	target.global_position = player.global_position + Vector3(4.0, 0.0, 0.0)
	target.force_update_transform()
	target.call("set_player_visibility_factor", 1.0)
	weapon_combat.set("force_touch_aim_for_test", true)
	weapon_combat.set("mobile_assist_target", target)
	main_scene.set("fire_button_held", true)
	main_scene.set("magazine_ammo", 0)
	main_scene.set("reserve_ammo", 0)
	await create_timer(0.12).timeout
	await physics_frame
	_assert(not bool(weapon_combat.call("is_steady_aim_raised")), "④ 조준 직후에는 정조준 상승이 아니어야 합니다.")
	_assert(is_equal_approx(float(weapon_combat.call("get_mobile_aim_height_ratio")), 0.5), "④ 기본 조준 높이는 몸(0.5)")
	var overlay = hud.get("combat_feedback")
	var unraised_center := Vector2.ZERO
	if overlay != null:
		unraised_center = overlay.get("bracket_center")
		_assert(bool(overlay.get("bracket_visible")), "④ 모바일 조준 중 브래킷이 보여야 합니다.")
		_assert(not bool(overlay.get("bracket_raised")), "④ 상승 전 브래킷은 기본색이어야 합니다.")
	await create_timer(0.7).timeout
	_assert(bool(weapon_combat.call("is_steady_aim_raised")), "④ 정지 0.5s 조준 유지 후 정조준 상승이어야 합니다(steady=%.2f)" % float(weapon_combat.get("steady_aim_time")))
	_assert(is_equal_approx(float(weapon_combat.call("get_mobile_aim_height_ratio")), 0.86), "④ 상승 후 조준 높이는 머리(0.86)")
	if overlay != null:
		var raised_center: Vector2 = overlay.get("bracket_center")
		_assert(bool(overlay.get("bracket_raised")), "④ 상승 후 브래킷은 주황(raised)이어야 합니다.")
		_assert(raised_center.y < unraised_center.y - 4.0, "④ 상승 후 조준점(브래킷)이 화면 위(머리)로 올라가야 합니다: %.1f → %.1f" % [unraised_center.y, raised_center.y])
		print("PROBE_STEADY_AIM_OK ratio=0.86 bracket_y %.1f -> %.1f" % [unraised_center.y, raised_center.y])
	# 이동하면 풀린다.
	player.velocity = Vector3(3.0, 0.0, 0.0)
	weapon_combat.call("_update_steady_aim", 0.016)
	_assert(not bool(weapon_combat.call("is_steady_aim_raised")), "④ 이동하면 정조준 상승이 풀려야 합니다.")
	player.velocity = Vector3.ZERO
	main_scene.set("fire_button_held", false)
	weapon_combat.set("force_touch_aim_for_test", false)
	weapon_combat.set("mobile_assist_target", null)

	# ── ⑤ 엄폐 ──
	var world := main_scene.get_node("World")
	var covers: Array[Node] = []
	for child in world.get_children():
		if child.is_in_group("road_cover_obstacle") and child.has_node("CoverCollision"):
			covers.append(child)
	_assert(covers.size() >= 1, "⑤ 필드에 도로 커버가 있어야 합니다.")
	var found_cover := false
	var cover_report := ""
	for cover in covers:
		var collision := cover.get_node("CoverCollision") as CollisionShape3D
		var size: Vector3 = (collision.shape as BoxShape3D).size
		var center := collision.global_position
		var normal := Vector3(0.0, 0.0, 1.0) if size.x >= size.z else Vector3(1.0, 0.0, 0.0)
		var depth := size.z if size.x >= size.z else size.x
		var player_position := Vector3(center.x, 0.78, center.z) + normal * (depth * 0.5 + 0.7)
		var source_position := Vector3(center.x, 0.7, center.z) - normal * 7.0
		player.global_position = player_position
		player.force_update_transform()
		await physics_frame
		if not bool(cover_system.call("is_covered_from", source_position)):
			continue
		found_cover = true
		# 같은 쪽에서 오는 공격은 엄폐가 아니다.
		var same_side := Vector3(center.x, 0.7, center.z) + normal * 7.0
		_assert(not bool(cover_system.call("is_covered_from", same_side)), "⑤ 엄폐물과 같은 쪽의 공격원에는 엄폐가 아니어야 합니다.")
		# 1.2u보다 멀리 떨어지면 엄폐가 아니다.
		player.global_position = Vector3(center.x, 0.78, center.z) + normal * (depth * 0.5 + 2.4)
		player.force_update_transform()
		await physics_frame
		_assert(not bool(cover_system.call("is_covered_from", source_position)), "⑤ 엄폐물에서 2.4u 떨어지면 엄폐가 아니어야 합니다.")
		player.global_position = player_position
		player.force_update_transform()
		await physics_frame
		_assert(bool(cover_system.call("is_covered_from", source_position)), "⑤ 커버 뒤 0.7u로 돌아오면 다시 엄폐여야 합니다.")
		# ── 엄폐 v2: ×0.55 배율은 폐지 — covered 상태의 총알은 '완전 차단'이다. ──
		# (이유: 유저 진단 "수치 경감은 경험이 안 된다" → 덕코프식 상태 기계로 교체.)
		main_scene.set("laser_aim_held", false)
		main_scene.set("fire_button_held", false)
		main_scene.set("mouse_fire_held", false)
		cover_system.set("in_cover", true)
		cover_system.set("exposed_time", 0.0)
		_assert(str(cover_system.call("get_state")) == "covered", "⑤ 조준·사격이 없으면 covered: %s" % str(cover_system.call("get_state")))
		main_scene.set("player_health", 9999)
		var blocked_before := int(cover_system.get("shots_blocked_total"))
		main_scene.call("take_hostile_hit", 40, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) == 9999, "⑤ covered 중 엄폐물 방향 총알은 피해 0이어야 합니다: %d" % int(main_scene.get("player_health")))
		_assert(int(cover_system.get("shots_blocked_total")) == blocked_before + 1, "⑤ 차단 카운트가 늘어야 합니다.")
		_assert(int(main_scene.get("last_cover_blocked")) == 40, "⑤ 차단량 전액(40)이 기록돼야 합니다: %d" % int(main_scene.get("last_cover_blocked")))
		# 조준(우클릭) 유지 = peeking — 피해 정상.
		main_scene.set("laser_aim_held", true)
		_assert(str(cover_system.call("get_state")) == "peeking", "⑤ 조준 중엔 peeking: %s" % str(cover_system.call("get_state")))
		main_scene.call("take_hostile_hit", 40, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) < 9999, "⑤ peeking 중엔 피해가 정상이어야 합니다.")
		main_scene.set("laser_aim_held", false)
		# 사격 시 0.5s 노출(0.4→0.5) — 타이머가 끝나면 다시 covered.
		cover_system.set("in_cover", true)
		cover_system.call("notify_player_fired")
		_assert(bool(cover_system.call("is_exposed")), "⑤ 사격 직후 노출 상태여야 합니다.")
		_assert(absf(float(cover_system.get("exposed_time")) - 0.5) < 0.001, "⑤ 사격 노출은 0.5s여야 합니다: %.2f" % float(cover_system.get("exposed_time")))
		main_scene.set("player_health", 9999)
		main_scene.call("take_hostile_hit", 40, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) < 9999, "⑤ 사격 노출 중엔 피해가 정상이어야 합니다.")
		await create_timer(0.6).timeout
		cover_system.set("in_cover", true)
		_assert(not bool(cover_system.call("is_exposed")), "⑤ 0.5s 뒤 노출이 끝나야 합니다(%.2f)" % float(cover_system.get("exposed_time")))
		main_scene.set("player_health", 9999)
		main_scene.call("take_hostile_hit", 40, Vector3.RIGHT, null, source_position)
		_assert(int(main_scene.get("player_health")) == 9999, "⑤ 노출이 끝나면 다시 완전 차단이어야 합니다.")
		# 폭발(blast)은 차단하지 않는다 — 엄폐 캠핑의 카운터.
		main_scene.call("take_hostile_hit", 40, Vector3.RIGHT, null, source_position, "blast")
		_assert(int(main_scene.get("player_health")) < 9999, "⑤ 폭발 피해는 엄폐로 막히면 안 됩니다.")
		# HUD 칩 3단 — covered(방패 채움) / peeking(테두리+화살표) / 없음.
		cover_system.set("in_cover", true)
		cover_system.set("exposed_time", 0.0)
		main_scene.call("_update_cover_feedback")
		_assert(bool((hud.get("cover_chip") as Control).visible), "⑤ 엄폐 중 HUD 칩이 보여야 합니다.")
		_assert(str(hud.get("cover_chip_state")) == "covered", "⑤ 칩 상태 covered: %s" % str(hud.get("cover_chip_state")))
		cover_system.call("notify_player_fired")
		main_scene.call("_update_cover_feedback")
		_assert(str(hud.get("cover_chip_state")) == "peeking", "⑤ 사격 직후 칩은 '내밈': %s" % str(hud.get("cover_chip_state")))
		cover_system.set("exposed_time", 0.0)
		cover_report = "cover=%s depth=%.2f" % [str(cover.get_meta("cover_type", "")), depth]
		break
	_assert(found_cover, "⑤ 도로 커버 중 하나는 '낮은 레이 막힘 + 머리 레이 통과' 엄폐 기하를 만족해야 합니다.")
	print("PROBE_COVER_OK %s" % cover_report)

	# 레슨·통계 훅.
	var headshots_before := int(game_state.get("raid_headshots"))
	main_scene.call("notify_player_headshot", null, 10)
	_assert(int(game_state.get("raid_headshots")) == headshots_before + 1, "헤드샷 통계가 GameState.raid_headshots에 쌓여야 합니다.")
	_assert(bool(game_state.get("headshot_lesson_seen")), "첫 헤드샷 레슨 플래그가 켜져야 합니다.")
	main_scene.call("notify_enemy_telegraph", "grenade", null)
	_assert(bool(game_state.get("telegraph_lesson_seen")), "첫 예고 레슨 플래그가 켜져야 합니다.")
	# 테스트가 플레이어 저장을 더럽히지 않게 레슨 플래그를 되돌린다.
	for key in lesson_backup.keys():
		game_state.set(key, lesson_backup[key])
	game_state.call("save_persistent_state")
	main_scene.queue_free()
	await process_frame
