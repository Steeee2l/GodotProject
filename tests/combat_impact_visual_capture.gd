extends SceneTree

# 전투 타격감 스크린샷 프로브(창 필요 — --headless 금지).
#   1) combat_impact_field_hits.png  : 데미지 팝 + 피격 화이트 플래시
#   2) combat_impact_elite_kill.png  : 엘리트 처치 순간(금색 팝·히트스톱 프레임)

const HITS_OUTPUT := "res://test-output/combat_impact_field_hits.png"
const ELITE_OUTPUT := "res://test-output/combat_impact_elite_kill.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_IMPACT_CAPTURE_TIMEOUT")
		quit(2)
	)
	var accessibility := root.get_node("AccessibilitySettings")
	accessibility.set("camera_shake_scale", 1.0)
	accessibility.set("hit_flash_scale", 1.0)
	accessibility.set("damage_numbers_enabled", true)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	# 화면이 밝은 한낮으로 고정해 플래시·숫자가 잘 보이게 한다.
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	await create_timer(0.8, true, false, true).timeout
	# 필드 진입 시네마틱이 카메라를 점유하면 캡처가 엉뚱한 곳을 찍는다 — 스킵.
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
	# 중앙 하단 독백 패널 등 HUD가 데미지 팝을 가리고, 독백은 냄새 시스템이
	# 계속 다시 띄운다 — 캡처 동안 HUD 레이어를 통째로 숨긴다(팝은 3D 노드라
	# 영향 없음, 시야 안개는 별도 레이어라 유지된다).
	(main_scene.get_node("HUD") as CanvasLayer).visible = false
	# 카메라 크기는 main이 매 프레임(프로세스+피직스) 목표값으로 되돌린다 —
	# 캡처 동안 main의 갱신을 멈추고(트윈·데미지 팝·적 노드는 계속 돈다)
	# 줌을 당겨 팝과 플래시가 읽히는 크기로 고정한다.
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= 0.5

	var player := main_scene.get_node("Player") as CharacterBody3D
	var enemies := main_scene.get("enemies") as Array
	if enemies.size() < 2:
		push_error("캡처용 적이 부족합니다.")
		quit(1)
		return
	var hit_enemy := enemies[0] as CharacterBody3D
	var elite_enemy := enemies[1] as CharacterBody3D

	# ── 샷 1: 연속 피격 — 데미지 팝 여러 개 + 화이트 플래시 ──
	hit_enemy.global_position = player.global_position + Vector3(2.7, 0.0, 1.3)
	# 적 자체 물리는 계속 돌아 플레이어 위로 달려들어 겹친다 — 캡처 동안 정지.
	hit_enemy.set_physics_process(false)
	# 원거리 컬링이 숨겨 둔 노드 — 컬링 갱신(main)이 멈춰 있으니 직접 켠다.
	hit_enemy.visible = true
	# 스텔스 가시성 갱신(main 물리)이 멈춰 있으므로 알파를 직접 켠다 —
	# 안 켜면 순간이동한 적이 alpha 0으로 남아 플래시가 화면에 안 보인다.
	hit_enemy.call("set_player_visibility_factor", 1.0)
	await create_timer(0.35, true, false, true).timeout
	hit_enemy.call("take_hit", 18, Vector3.RIGHT, false)
	await create_timer(0.14, true, false, true).timeout
	hit_enemy.call("take_hit", 24, Vector3.RIGHT, false, "center")
	await create_timer(0.14, true, false, true).timeout
	# 마지막 타는 캡처 직전 — 플래시(0.06초 유지)가 화면에 남아 있게 한다.
	hit_enemy.call("take_hit", 21, Vector3.BACK, false)
	# get_texture()는 직전 렌더 프레임을 돌려주므로, 타격이 반영된
	# 프레임이 그려진 뒤에 캡처해야 한다.
	await create_timer(0.04, true, false, true).timeout
	await process_frame
	_capture(HITS_OUTPUT)

	# ── 샷 2: 엘리트 처치 순간 — 금색 팝 + 히트스톱 프레임 ──
	elite_enemy.call("promote_to_elite", "약탈자 정예 · 무장 강탈자")
	elite_enemy.global_position = player.global_position + Vector3(-2.5, 0.0, 1.6)
	elite_enemy.set_physics_process(false)
	elite_enemy.visible = true
	elite_enemy.call("set_player_visibility_factor", 1.0)
	await create_timer(0.3, true, false, true).timeout
	elite_enemy.call("take_hit", 33, Vector3.LEFT, false)
	await create_timer(0.16, true, false, true).timeout
	elite_enemy.call("take_hit", 999999, Vector3.LEFT, false)
	await process_frame
	await process_frame
	await process_frame
	_capture(ELITE_OUTPUT)

	quit(0)


func _capture(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK ", ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
