extends SceneTree

# 피격 피드백 스크린샷 프로브(창 필요 — --headless 금지).
#   1) hit_feedback_hit_moment.png  : 피격 순간(붉은 비네트 + 방향 호 + 체력바 흰 잔상)
#   2) hit_feedback_low_health.png  : 저체력 상시 비네트(펄스가 다 빠진 뒤)

const HIT_OUTPUT := "res://test-output/hit_feedback_hit_moment.png"
const LOW_HEALTH_OUTPUT := "res://test-output/hit_feedback_low_health.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("HIT_FEEDBACK_CAPTURE_TIMEOUT")
		quit(2)
	)
	var accessibility := root.get_node("AccessibilitySettings")
	# 기본값 그대로가 아니라 최대치로 찍는다 — 연출이 화면에서 어떻게 읽히는지 본다.
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
	main_scene.set("world_time_hours", 12.0)
	# 필드 진입 시네마틱은 카메라도 잡고 피해도 무시한다 — 먼저 넘긴다.
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
	await create_timer(0.8, true, false, true).timeout
	# 주변 적의 사격이 캡처 타이밍에 끼어들지 않게 플레이어 피격 판정을 끈다.
	(main_scene.get_node("Player") as CharacterBody3D).collision_layer = 0

	var max_health := int(game_state.call("get_max_health"))

	# ── 샷 1: 피격 순간 ──────────────────────────────────────
	# 체력을 70%에서 시작해 한 방 크게 맞는다 — 흰 잔상이 남을 폭이 생긴다.
	main_scene.set("player_health", roundi(float(max_health) * 0.7))
	game_state.set("player_health", roundi(float(max_health) * 0.7))
	await create_timer(0.5, true, false, true).timeout
	# 시네마틱이 아직 살아 있으면 take_damage가 통째로 무시된다 — 확실히 꺼질 때까지 기다린다.
	var wait_guard := 0
	while (
		main_mission != null
		and bool(main_mission.call("is_cinematic_active"))
		and wait_guard < 40
	):
		main_mission.get("cinematic").call("skip")
		wait_guard += 1
		await create_timer(0.25, true, false, true).timeout
	var health_before := int(main_scene.get("player_health"))
	main_scene.call("take_hit", roundi(float(max_health) * 0.22), Vector3.RIGHT, "bullet")
	print("HIT_APPLIED %d -> %d" % [health_before, int(main_scene.get("player_health"))])
	# 비네트 강도는 물리 프레임(_update_player_combat_feedback)에서 셰이더에
	# 들어가고, get_texture()는 직전 렌더 프레임을 돌려준다 — 물리 한 틱 뒤에
	# 그려진 프레임을 잡아야 한다. 펄스는 0.25초에 걸쳐 감쇠하므로 아직 진하다.
	await physics_frame
	await process_frame
	await process_frame
	_capture(HIT_OUTPUT)

	# ── 샷 2: 저체력 상시 비네트 ─────────────────────────────
	# 체력 8%로 떨어뜨리고 피격 펄스가 완전히 빠질 때까지 기다린다 —
	# 화면에 남는 붉은 기운은 전부 '저체력' 신호다.
	main_scene.set("player_health", maxi(1, roundi(float(max_health) * 0.08)))
	game_state.set("player_health", maxi(1, roundi(float(max_health) * 0.08)))
	await create_timer(1.2, true, false, true).timeout
	await process_frame
	_capture(LOW_HEALTH_OUTPUT)

	quit(0)


func _capture(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK ", ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
