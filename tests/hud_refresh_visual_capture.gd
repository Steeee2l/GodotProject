extends SceneTree

# HUD 갱신 캡처 프로브(창 필요 — --headless 금지). 2026-09-02.
#   hud_health_segments_hit.png : 피격 직후 세그먼트 체력바 + 파편
#   hud_toast_tiers.png         : 굵은 알림 + 조용한 한 줄
#   incident_edge_ping.png      : 돌발 사건 화면 밖 가장자리 화살표
#   incident_site_marker.png    : 돌발 사건 현장 원형 마커 + 라벨
#   shelter_dialogue_portrait.png : 쉘터 대화 초상화(상반신 크롭, 프레임 밖)
# 실행: godot --path . --script res://tests/hud_refresh_visual_capture.gd

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		push_error("HUD_REFRESH_CAPTURE_TIMEOUT")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for _frame in 12:
		await process_frame
	main_scene.set("world_time_hours", 12.0)
	var chain: Object = main_scene.get("main_mission")
	var cine: Object = chain.get("cinematic")
	var guard := 0
	await _wait(1.0)
	while bool(cine.get("running")) and guard < 40:
		cine.call("skip")
		await _wait(0.25)
		guard += 1
	await _wait(0.6)

	main_scene.call("take_hit", 35, Vector3.RIGHT, "bullet")
	await _wait(0.12)
	await _capture("hud_health_segments_hit")

	var hud: Object = main_scene.get("hud")
	hud.call("push_toast", "정예 처치! 확정 전리품이 떨어졌다", Color("#f2bd55"), 4.0)
	hud.call("push_toast_minor", "+12 7.62mm   보유 150", Color("#d8bd72"), 3.0)
	await _wait(0.3)
	await _capture("hud_toast_tiers")

	var incidents: Object = main_scene.get("incidents")
	var world: Node = main_scene.get_node("World")
	incidents.call("_spawn_dynamic_convoy_incident", world)
	await _wait(0.5)
	print("INCIDENT state=%s" % str(main_scene.get("dynamic_incident_state")))
	await _capture("incident_edge_ping")
	var site: Node3D = main_scene.get("dynamic_incident_site") as Node3D
	if is_instance_valid(site):
		var player := main_scene.get_node("Player") as Node3D
		player.global_position = site.global_position + Vector3(4.0, 0.0, 4.0)
		# 축하 팝(0.5s) 뒤 상단 띠로 수축한 상태를 담는다.
		await _wait(1.5)
		await _capture("incident_site_marker")
	main_scene.queue_free()
	for _frame in 6:
		await process_frame

	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _wait(1.2)
	if not bool(shelter.get("contract_story_open")):
		var portrait: Texture2D = null
		var agent: Node = shelter.get("contract_agent") as Node
		if is_instance_valid(agent) and agent.has_method("get_portrait_texture"):
			portrait = agent.call("get_portrait_texture") as Texture2D
		if portrait == null:
			# 새 게임엔 사자가 아직 없다 — 초상화 렌더 확인용으로 사자 스프라이트를 직접 쓴다.
			portrait = load("res://assets/characters/saja/down_idle-frame-0.png") as Texture2D
		print("SHELTER portrait=%s" % str(portrait != null))
		shelter.call(
			"_open_contract_story",
			"사자의 이야기",
			["이름이 뭐야.", "먼지. 적어 둔다. 오늘부터 여기 사람이다."] as Array[String],
			"사자",
			portrait
		)
	await _wait(0.8)
	await _capture("shelter_dialogue_portrait")
	# 행상인 초상화(시트에서 잘라 온 AtlasTexture) — 사자와 같은 크기로 나와야 한다.
	# 타자기가 도는 중엔 첫 입력이 '전부 표시'로 소비된다 — 닫힐 때까지 넘긴다.
	var close_guard := 0
	while bool(shelter.get("contract_story_open")) and close_guard < 12:
		shelter.call("_advance_contract_story")
		close_guard += 1
		await _wait(0.15)
	await _wait(0.3)
	shelter.call(
		"_open_contract_story",
		"떠돌이 행상인의 첫 인사",
		["처음 보는 얼굴이다냥. 나는 봉쇄선 바깥을 돌며 장사하는 행상인이다냥."] as Array[String],
		"행상인",
		shelter.call("_merchant_face_texture")
	)
	await _wait(0.8)
	await _capture("shelter_dialogue_merchant")
	print("HUD_REFRESH_VISUAL_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout


func _capture(capture_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
