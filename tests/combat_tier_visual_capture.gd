extends SceneTree

# 전투 위계 캡처 프로브(창 필요 — --headless 금지). 2026-09-06.
#   combat_tiers_field.png : 일반 · 엘리트(덩치 1.24~1.34배, 두툼한 붉은 테두리
#   체력바) · 보스(덩치 ×1.33, 최상위 체력바)가 한 화면에 — 3계층 실루엣 검수.
# 실행: godot --path . --script res://tests/combat_tier_visual_capture.gd

const OUTPUT_DIR := "res://test-output"
const ROCKET_BOSS := preload("res://scripts/rocket_boss.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_TIER_CAPTURE_TIMEOUT")
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
	await _wait(1.0)
	var guard := 0
	while bool(cine.get("running")) and guard < 40:
		cine.call("skip")
		await _wait(0.25)
		guard += 1
	var player := main_scene.get_node("Player") as Node3D
	var elite: Node3D = null
	var regular: Node3D = null
	for raw_enemy in main_scene.get("enemies") as Array:
		var enemy := raw_enemy as Node3D
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get_meta("elite", false)) and elite == null:
			elite = enemy
		elif regular == null and not bool(enemy.get_meta("elite", false)):
			regular = enemy
	if elite == null or regular == null:
		push_error("엘리트/일반 적 없음")
		quit(1)
		return
	# 보스 — 플레이어 뒤편에 직접 세운다(스폰 트리거 없이 실루엣만 검수).
	var boss := CharacterBody3D.new()
	boss.set_script(ROCKET_BOSS)
	boss.call("configure_rocket_boss", player, 0.8)
	elite.get_parent().add_child(boss)
	var marker := Label3D.new()
	marker.name = "BossMarker"
	marker.text = "로켓 약탈대장"
	marker.position = Vector3(0.0, 4.3, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.render_priority = 127
	marker.font_size = 96
	marker.modulate = Color("#ff4b3a")
	marker.outline_size = 18
	boss.add_child(marker)
	# 체력을 살짝 깎아 채움/잔상 바가 배경과 구분되어 보이게. 보스는 마지막에만
	# 깎는다 — 미리 깎으면 대기 중에 교전을 시작해 화면이 로켓판이 된다.
	elite.call("take_hit", 60, Vector3.RIGHT)
	regular.call("take_hit", 20, Vector3.RIGHT)
	for _frame in 6:
		regular.global_position = player.global_position + Vector3(-3.4, 0.0, -0.8)
		elite.global_position = player.global_position + Vector3(3.4, 0.0, -0.8)
		boss.global_position = player.global_position + Vector3(0.0, 0.0, -3.4)
		await process_frame
	# 말풍선(엘리트 교전·피격 대사)이 자기 체력바를 가린다 — 사라질 때까지 대기.
	await _wait(3.2)
	boss.call("take_hit", roundi(float(boss.get("max_health")) * 0.25), Vector3.RIGHT)
	regular.global_position = player.global_position + Vector3(-3.4, 0.0, -0.8)
	elite.global_position = player.global_position + Vector3(3.4, 0.0, -0.8)
	boss.global_position = player.global_position + Vector3(0.0, 0.0, -3.4)
	# 은신 안개가 프레임마다 가시성을 덮어쓴다 — 마지막 프레임에 강제로 밝힌다.
	# 말풍선(FieldSpeechBubble)은 체력바를 가리니 캡처 직전 숨긴다.
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in [regular, elite, boss]:
		actor.call("set_player_visibility_factor", 1.0)
		var bubble := (actor as Node).get_node_or_null("FieldSpeechBubble") as Node3D
		if bubble != null:
			bubble.visible = false
	await process_frame
	await process_frame
	# 진단 — 화면상 바 위치 매핑(어느 바가 어디 찍히는지).
	var camera := root.get_camera_3d()
	if camera != null:
		for raw_enemy in (main_scene.get("enemies") as Array) + [boss]:
			var enemy_node := raw_enemy as Node3D
			if not is_instance_valid(enemy_node):
				continue
			var fill := enemy_node.get_node_or_null("HealthBarFill") as Sprite3D
			if fill == null or not fill.visible:
				continue
			var screen := camera.unproject_position(fill.global_position)
			print("  BAR %s kind=%s elite=%s screen=%s world=%s" % [
				enemy_node.name, str(enemy_node.get("enemy_kind")),
				str(enemy_node.get("elite")), str(screen.round()),
				str(enemy_node.global_position.round()),
			])
	var image := root.get_texture().get_image()
	var path := "%s/combat_tiers_field.png" % OUTPUT_DIR
	if image.save_png(path) == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	print(
		"COMBAT_TIER_CAPTURE_OK 일반스케일=%.2f 엘리트스케일=%.2f 보스px=%.4f 바계층=%s/%s/%s" % [
			1.0, float(elite.get("elite_sprite_scale")),
			float((boss.get("sprite") as AnimatedSprite3D).pixel_size),
			str(regular.get("health_bar_size_class")),
			str(elite.get("health_bar_size_class")),
			str(boss.get("health_bar_size_class")),
		]
	)
	quit(0)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
