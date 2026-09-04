extends SceneTree

# 엘리트 프로브(2026-09-03).
#   ① 카탈로그: 단계 1~5 모두 요청 수만큼 겹치지 않는 이름을 뽑는다
#   ② 필드: 엘리트가 카탈로그 이름·붉은 이름표·큰 덩치·배율 스탯으로 서 있고 호위 분대가 붙는다
#   ③ 상황 대사: 경계 진입(engage)에서 엘리트가 자기 대사를, 피격(hit)에서 말풍선이 뜬다

const ELITE_CATALOG := preload("res://scripts/raid/elite_catalog.gd")
const SPEECH_BUBBLE := preload("res://scripts/raid/speech_bubble.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("ELITE|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("ELITE_PROBE_TIMEOUT")
		quit(2)
	)
	# ── ① 카탈로그 ──
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for tier in range(1, 6):
		var count: int = ELITE_CATALOG.get_count(tier)
		var picked: Array[Dictionary] = ELITE_CATALOG.pick_profiles(tier, count, random)
		var names: Array[String] = []
		for profile in picked:
			names.append(str(profile.get("name", "")))
		var unique := true
		for index in names.size():
			if names.find(names[index]) != index or names[index].is_empty():
				unique = false
		_check(picked.size() == count and unique, "① 단계 %d: %d명 고유 이름 %s" % [tier, count, str(names)])

	# ── ② 필드 배치 ──
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var enemies: Array = main_scene.get("enemies") as Array
	var elites: Array[Node3D] = []
	var regular_scale := 1.0
	for raw_enemy in enemies:
		var enemy := raw_enemy as Node3D
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get_meta("elite", false)):
			elites.append(enemy)
		elif regular_scale == 1.0:
			regular_scale = (enemy.get("sprite") as Node3D).scale.x
	var director = main_scene.get("enemy_director")
	var expected: int = director.get_initial_elite_count(int(director._zone_stage_tier()))
	_check(elites.size() == expected, "② 엘리트 수 %d(기대 %d)" % [elites.size(), expected])
	if not elites.is_empty():
		var elite := elites[0]
		var display_name := str(elite.get_meta("display_name", ""))
		_check(not display_name.is_empty() and display_name != "약탈자 정예 · 무장 강탈자", "② 카탈로그 이름(%s)" % display_name)
		var label := elite.get_node_or_null("EliteNameLabel") as Label3D
		_check(label != null and label.text == display_name, "② 머리 위 이름표가 이름을 단다")
		if label != null:
			_check(label.modulate.r > 0.9 and label.modulate.g < 0.4, "② 이름표가 붉다(%s)" % label.modulate.to_html(false))
		var elite_scale := (elite.get("sprite") as Node3D).scale.x
		_check(elite_scale > regular_scale * 1.15, "② 덩치가 크다(%.2f vs %.2f)" % [elite_scale, regular_scale])
		_check(float(elite.get("elite_damage_multiplier")) >= 1.6, "② 피해 배율 %.2f" % float(elite.get("elite_damage_multiplier")))
		var squad_id := int(elite.get("squad_id"))
		var escorts := 0
		for raw_enemy in enemies:
			var enemy := raw_enemy as Node3D
			if is_instance_valid(enemy) and enemy != elite and int(enemy.get("squad_id")) == squad_id and squad_id >= 0:
				escorts += 1
		_check(escorts >= 1, "② 호위 분대가 붙는다(%d, squad %d)" % [escorts, squad_id])
		var barks: Dictionary = elite.get_meta("elite_barks", {}) as Dictionary
		_check(not (barks.get("engage", []) as Array).is_empty(), "② 엘리트 전용 대사가 실려 있다")

		# ── ③ 상황 대사 ──
		var player := main_scene.get("player") as Node3D
		var chatter = main_scene.get("enemy_chatter")
		elite.global_position = player.global_position + Vector3(6.0, 0.0, 0.0)
		# 스캔이 현재 상태를 한 번 기록한 뒤 경계 진입을 일으킨다.
		chatter.call("update", 0.35)
		await process_frame
		elite.set("alerted", true)
		chatter.call("update", 0.35)
		await process_frame
		var bubble := elite.get_node_or_null(SPEECH_BUBBLE.BUBBLE_NAME) as Label3D
		var engage_lines: Array = barks.get("engage", []) as Array
		_check(bubble != null and engage_lines.has(bubble.text), "③ 경계 진입에 엘리트 자기 대사(%s)" % (bubble.text if bubble != null else "없음"))
		# 피격 — 전역·화자 간격을 비우고 직접 알린다.
		chatter.set("context_bark_timer", 0.0)
		chatter.set("context_speaker_cooldowns", {})
		chatter.call("notify", "hit", elite)
		await process_frame
		bubble = elite.get_node_or_null(SPEECH_BUBBLE.BUBBLE_NAME) as Label3D
		var hit_lines: Array = barks.get("hit", []) as Array
		_check(bubble != null and hit_lines.has(bubble.text), "③ 피격에 엘리트 대사(%s)" % (bubble.text if bubble != null else "없음"))
		# 일반 적 동료 사망 → 근처 교전 적이 외친다.
		var mourner: Node3D = null
		for raw_enemy in enemies:
			var enemy := raw_enemy as Node3D
			if is_instance_valid(enemy) and enemy != elite and not bool(enemy.get_meta("elite", false)):
				mourner = enemy
				break
		if mourner != null:
			mourner.global_position = player.global_position + Vector3(-5.0, 0.0, 0.0)
			mourner.set("alerted", true)
			chatter.set("context_bark_timer", 0.0)
			var spoke := false
			for attempt in 12:
				# 순찰 AI가 프레임마다 자리를 옮긴다 — 시도마다 둘을 다시 붙여 세운다.
				elite.global_position = player.global_position + Vector3(6.0, 0.0, 0.0)
				mourner.global_position = player.global_position + Vector3(-5.0, 0.0, 0.0)
				chatter.set("context_speaker_cooldowns", {})
				chatter.call("notify", "ally_down", elite)
				await process_frame
				var mourner_bubble := mourner.get_node_or_null(SPEECH_BUBBLE.BUBBLE_NAME) as Label3D
				if mourner_bubble != null:
					spoke = true
					break
				chatter.set("context_bark_timer", 0.0)
			_check(spoke, "③ 동료 사망에 근처 적이 외친다")

	if failures.is_empty():
		print("ELITE_PROBE_OK")
		quit(0)
		return
	for failure in failures:
		print("ELITE|FAIL|%s" % failure)
	push_error("ELITE_PROBE_FAIL %d" % failures.size())
	quit(1)
