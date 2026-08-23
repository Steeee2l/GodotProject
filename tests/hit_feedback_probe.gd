extends SceneTree

# 피격 피드백 프로브 — "적 총알에 맞을 때 경직이 불편하다"(유저 신고)의 회귀 방어.
# 경직(이동 입력 잠금)과 피격 히트스톱을 없앤 대신 화면 피드백을 확실히 한
# 교체가 실제 씬(main.tscn)에서 유지되는지 검증한다.
#   ① 피격 직후에도 이동 입력이 그대로 반영된다(진행 방향 전진 > 0)
#   ② 연속 5발을 맞는 동안에도 이동이 이어진다(비피격 대비 90% 이상)
#   ③ 총알 넉백은 옛 값(1.35)의 30% 이하, 폭발·근접만 큰 넉백을 남긴다
#   ④ 붉은 비네트는 상한(0.8)을 넘지 않고 0.3초 안에 감쇠한다
#   ⑤ 히트스톱은 피격에 걸리지 않고 '처치'에만 걸린다
#   ⑥ 접근성 '피격 화면 효과' 0%면 붉은 화면 효과가 아예 뜨지 않는다

const KILL_IMPACT := preload("res://scripts/kill_impact.gd")
# 교체 전 총알 넉백 세기. ③의 기준선(30%)은 이 값에서 온다.
const LEGACY_BULLET_KNOCKBACK := 1.35
# 이동 계측 구간(물리 프레임 수). 짧으면 지형 충돌 한 번에 결과가 흔들린다.
const MOVE_SAMPLE_FRAMES := 45

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("HIT_FEEDBACK_PROBE_TIMEOUT")
		quit(2)
	)
	var accessibility := root.get_node("AccessibilitySettings")
	# 배율을 1.0으로 고정해 비네트 강도를 결정적으로 만든다.
	accessibility.set("camera_shake_scale", 1.0)
	accessibility.set("hit_flash_scale", 1.0)
	accessibility.set("vignette_scale", 1.0)
	accessibility.set("hit_feedback_intensity", 1.0)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	# 프로브 도중 죽어 사망 슬로모가 끼어들지 않게 체력을 크게 잡는다
	# (저체력 상시 비네트도 이때는 0이라 ④ 측정이 깨끗하다).
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 필드 진입 시네마틱 중에는 take_damage가 통째로 무시된다 — 먼저 넘긴다.
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
	await create_timer(0.4, true, false, true).timeout
	# 주변 적의 유탄·사격이 계측에 섞이지 않게 플레이어 피격 판정을 끈다
	# (프로브는 take_hit을 직접 부른다).
	var player := main_scene.get_node("Player") as CharacterBody3D
	player.collision_layer = 0

	await _probe_movement_during_hits(main_scene, player)
	await _probe_knockback_by_kind(main_scene, game_state)
	await _probe_vignette(main_scene, accessibility)
	await _probe_hit_stop(main_scene)
	await _probe_accessibility_off(main_scene, accessibility)

	if failures.is_empty():
		print("HIT_FEEDBACK_PROBE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("HIT_FEEDBACK_PROBE_FAILED (%d)" % failures.size())
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK  %s" % message)
	else:
		failures.append(message)
		print("  FAIL %s" % message)


# 이동 입력을 켠 채 지정한 프레임 수만큼 굴리고, 진행 방향으로 나아간 거리를 잰다.
# 매 프레임 hit_frames에 있는 인덱스에서 앞쪽(진행 반대 방향)에서 총알을 맞는다.
func _run_movement_leg(
	main_scene: Node,
	player: CharacterBody3D,
	hit_frames: Array
) -> float:
	# 계측 구간마다 같은 조건에서 출발한다 — 피로도는 속도 배율에 직접 걸린다.
	main_scene.set("fatigue", 0.0)
	main_scene.set("recoil_velocity", Vector3.ZERO)
	main_scene.set("player_health", 9999)
	root.get_node("GameState").set("player_health", 9999)
	# 모바일 스틱 입력 경로(touch_vector)를 쓴다 — 헤드리스에서 키 입력보다 확실하다.
	main_scene.set("touch_vector", Vector2(1.0, 0.0))
	await physics_frame
	var start_position: Vector3 = player.global_position
	var forward := Vector3(1.0, 0.0, -1.0).normalized()
	for frame_index in MOVE_SAMPLE_FRAMES:
		if hit_frames.has(frame_index):
			# 진행 방향 정면에서 오는 총알 — 넉백이 이동을 거스르는 최악 조건.
			main_scene.call("take_hit", 3, -forward, "bullet")
		await physics_frame
	main_scene.set("touch_vector", Vector2.ZERO)
	var travelled: Vector3 = player.global_position - start_position
	travelled.y = 0.0
	return travelled.dot(forward)


func _probe_movement_during_hits(main_scene: Node, player: CharacterBody3D) -> void:
	print("① ② 피격 중 이동 유지")
	# ① 피격 바로 다음 프레임에 이동 입력이 살아 있는지.
	main_scene.set("fatigue", 0.0)
	main_scene.set("recoil_velocity", Vector3.ZERO)
	main_scene.set("touch_vector", Vector2(1.0, 0.0))
	await physics_frame
	var forward := Vector3(1.0, 0.0, -1.0).normalized()
	var before: Vector3 = player.global_position
	# 옆에서 오는 총알 — 넉백이 전진 성분에 섞이지 않게 한다.
	main_scene.call("take_hit", 3, forward.cross(Vector3.UP), "bullet")
	await physics_frame
	var advance := (player.global_position - before)
	advance.y = 0.0
	main_scene.set("touch_vector", Vector2.ZERO)
	_check(
		advance.dot(forward) > 0.0,
		"① 피격 직후 프레임에도 전진한다 (전진 %.4f m)" % advance.dot(forward)
	)
	_check(
		float(main_scene.get("player_hit_react_time")) > 0.0,
		"① 피격 반응 창은 남되(연출용) 이동은 막지 않는다"
	)

	# ② 연속 5발을 맞는 동안의 총 이동 거리 vs 안 맞을 때.
	var clean_distance: float = await _run_movement_leg(main_scene, player, [])
	var hit_frames := [4, 8, 12, 16, 20]
	var hit_distance: float = await _run_movement_leg(main_scene, player, hit_frames)
	var ratio := hit_distance / maxf(0.001, clean_distance)
	_check(
		ratio >= 0.9,
		"② 연속 5발 피격 중 이동 유지 %.1f%% (비피격 %.2f m → 피격 %.2f m)"
		% [ratio * 100.0, clean_distance, hit_distance]
	)


func _probe_knockback_by_kind(main_scene: Node, game_state: Node) -> void:
	print("③ 종류별 넉백")
	var armor_multiplier := float(game_state.call("get_armor_knockback_multiplier"))
	var direction := Vector3.RIGHT
	var measured := {}
	for kind in ["bullet", "melee", "blast"]:
		main_scene.set("recoil_velocity", Vector3.ZERO)
		main_scene.set("player_health", 9999)
		game_state.set("player_health", 9999)
		main_scene.call("take_hit", 5, direction, kind)
		measured[kind] = (main_scene.get("recoil_velocity") as Vector3).length()
		await physics_frame
	main_scene.set("recoil_velocity", Vector3.ZERO)
	var legacy := LEGACY_BULLET_KNOCKBACK * armor_multiplier
	_check(
		float(measured["bullet"]) <= legacy * 0.3,
		"③ 총알 넉백 %.3f ≤ 옛 값의 30%% (%.3f)" % [measured["bullet"], legacy * 0.3]
	)
	_check(
		float(measured["melee"]) > float(measured["bullet"]) * 2.0,
		"③ 근접 넉백은 남는다 %.3f" % measured["melee"]
	)
	_check(
		float(measured["blast"]) > float(measured["melee"]),
		"③ 폭발 넉백이 가장 크다 %.3f" % measured["blast"]
	)


func _probe_vignette(main_scene: Node, accessibility: Node) -> void:
	print("④ 붉은 비네트 상한·감쇠")
	var hud = main_scene.get("hud")
	var material: ShaderMaterial = hud.get("damage_vignette_material")
	_check(material != null, "④ 비네트 머티리얼 존재")
	if material == null:
		return
	accessibility.set("hit_feedback_intensity", 1.0)
	accessibility.set("vignette_scale", 1.0)
	main_scene.set("player_health", 9999)
	root.get_node("GameState").set("player_health", 9999)
	# 연타 — 누적으로 화면이 새빨개지지 않아야 한다.
	var peak := 0.0
	for shot in 8:
		main_scene.call("take_hit", 12, Vector3.RIGHT, "bullet")
		await physics_frame
		peak = maxf(peak, float(material.get_shader_parameter("intensity")))
	# 상한은 main.HIT_VIGNETTE_MAX와 같은 값 — 연타로 화면이 새빨개지지 않게 자른다.
	var cap := 0.8
	_check(peak > 0.4, "④ 피격 시 비네트가 확실히 튄다 (최대 %.3f)" % peak)
	_check(peak <= cap + 0.001, "④ 비네트 상한 %.2f 이하 유지 (최대 %.3f)" % [cap, peak])
	# 마지막 피격에서 0.3초(게임 시간) 지나면 사실상 0.
	var elapsed := 0.0
	while elapsed < 0.3:
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		await physics_frame
	var decayed := float(material.get_shader_parameter("intensity"))
	_check(decayed <= 0.02, "④ 0.3초 안에 감쇠 (%.4f)" % decayed)


func _probe_hit_stop(main_scene: Node) -> void:
	print("⑤ 히트스톱은 처치에만")
	Engine.time_scale = 1.0
	main_scene.set("player_health", 9999)
	root.get_node("GameState").set("player_health", 9999)
	main_scene.call("take_hit", 40, Vector3.RIGHT, "blast")
	var scale_after_hit := Engine.time_scale
	_check(
		is_equal_approx(scale_after_hit, 1.0),
		"⑤ 피격에는 히트스톱이 걸리지 않는다 (time_scale %.3f)" % scale_after_hit
	)
	main_scene.set("recoil_velocity", Vector3.ZERO)
	# 처치 히트스톱은 그대로 살아 있어야 한다 — 그건 기분 좋은 연출이다.
	KILL_IMPACT.trigger_kill_hit_stop(false)
	var scale_after_kill := Engine.time_scale
	_check(
		scale_after_kill < 0.5,
		"⑤ 처치에는 히트스톱이 걸린다 (time_scale %.3f)" % scale_after_kill
	)
	await create_timer(0.4, true, false, true).timeout
	_check(
		is_equal_approx(Engine.time_scale, 1.0),
		"⑤ 처치 히트스톱은 복원된다 (time_scale %.3f)" % Engine.time_scale
	)


func _probe_accessibility_off(main_scene: Node, accessibility: Node) -> void:
	print("⑥ 접근성 '피격 화면 효과' 0%")
	var hud = main_scene.get("hud")
	var material: ShaderMaterial = hud.get("damage_vignette_material")
	var arrow: CanvasItem = hud.get("damage_direction_indicator")
	accessibility.set("hit_feedback_intensity", 0.0)
	main_scene.set("player_health", 9999)
	root.get_node("GameState").set("player_health", 9999)
	main_scene.call("take_hit", 30, Vector3.RIGHT, "bullet")
	await physics_frame
	await physics_frame
	_check(
		is_zero_approx(float(material.get_shader_parameter("intensity"))),
		"⑥ 붉은 비네트가 뜨지 않는다 (%.4f)" % material.get_shader_parameter("intensity")
	)
	_check(
		is_zero_approx(arrow.modulate.a),
		"⑥ 방향 호도 뜨지 않는다 (%.4f)" % arrow.modulate.a
	)
	_check(
		float(main_scene.get("camera_shake_strength")) <= 0.001,
		"⑥ 피격 흔들림도 0 (%.4f)" % main_scene.get("camera_shake_strength")
	)
	accessibility.set("hit_feedback_intensity", 1.0)
	main_scene.set("recoil_velocity", Vector3.ZERO)
