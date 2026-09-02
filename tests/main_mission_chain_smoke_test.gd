extends SceneTree

# 존별 메인 미션 체인 스모크 테스트.
#
# 검증 항목
#   ① 새 세이브의 종로에서 1→2→3단계가 순서대로 배치되는가
#   ② 세 단계를 끝낸 구역에서는 메인 미션이 사라지고 반복 사건이 대신 뜨는가
#   ③ 완주 안내가 다음 도시(남대문)를 가리키는가
#   ④ 세이브 왕복 뒤에도 진행도·선택 기록이 남는가
#   ⑤ 시네마틱 중에는 먼지가 피해를 입지 않는가

const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	# ① 종로 3단계를 순서대로 굴린다.
	for expected_stage_index in 3:
		var main_scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main_scene)
		await process_frame
		await physics_frame
		main_scene.process_mode = Node.PROCESS_MODE_DISABLED
		var chain: Object = main_scene.get("main_mission")
		var stage := chain.get("stage") as Dictionary
		var expected_stage := MAIN_MISSION_CATALOG.get_stage("jongno_outskirts", expected_stage_index)
		assert(int(chain.get("stage_index")) == expected_stage_index)
		assert(str(stage.get("id", "")) == str(expected_stage.get("id", "")))
		print("STAGE_%d id=%s type=%s points=%d" % [
			expected_stage_index,
			str(stage.get("id", "")),
			str(stage.get("type", "")),
			(chain.get("points") as Array).size(),
		])
		# 좌상단 목표 패널과 지도 마커가 이 단계를 말하고 있어야 한다.
		var step_text := str((main_scene.get("hud").jackpot_step_label as Label).text)
		assert(step_text == str(((chain.get("points") as Array)[0] as Dictionary).get("step_title", "")))
		var objective_label := main_scene.get("objective_label") as Label
		assert(objective_label.text.contains(step_text))
		var tactical_map := main_scene.get("tactical_map") as Control
		var marker_labels: Array[String] = []
		for marker_value in tactical_map.get("raid_markers") as Array:
			var marker := marker_value as Dictionary
			if str(marker.get("id", "")).begins_with("main_mission_"):
				marker_labels.append(str(marker.get("label", "")))
		assert(not marker_labels.is_empty())
		print("  MARKERS=%s" % ", ".join(marker_labels))
		print("  OBJECTIVE_PANEL=%s" % objective_label.text.replace("\n", " | "))

		# ⑤ 연출이 도는 동안 먼지는 무적이다(연출 보다가 죽는 사고 방지).
		if bool(main_scene.call("is_cinematic_active")):
			var health_before := int(main_scene.get("player_health"))
			main_scene.call("take_damage", 40)
			assert(int(main_scene.get("player_health")) == health_before)
			print("  CINEMATIC_INVULNERABLE ok (health %d)" % health_before)
		elif bool(main_scene.call("is_bark_active")):
			# 바크 모드 연출(인트로 등 대사뿐인 장면): 조작 잠금도 무적도 없다 — 대사는
			# 하단 자막으로 흐르고 먼지는 제 할 일을 한다(유저 신고 반영).
			assert(not bool(main_scene.get("monologue").get("queue") == null))
			print("  CINEMATIC_BARK ok (controls unlocked)")

		_walk_stage(main_scene, chain)
		assert(str(chain.get("state")) == "carried")
		var settle_result := main_scene.call("_settle_jackpot_cargo") as Dictionary
		print("  SETTLE=%s" % str(settle_result.get("summary", "")).replace("\n", " | "))
		assert(int(settle_result.get("xp", 0)) > 0)
		assert(int(game_state.call("get_main_mission_progress", "jongno_outskirts")) == expected_stage_index + 1)
		main_scene.queue_free()
		await process_frame
		await process_frame

	# ③ 완주 안내는 다음 도시를 가리킨다.
	assert(bool(game_state.call("is_zone_main_chain_complete", "jongno_outskirts")))
	# 사자는 밀린 이야기부터 순서대로 꺼낸다(구조 인원·화물 등). 앞의 것들을
	# 소비시키면서 구역 완주 안내가 실제로 큐에 올라오는지 확인한다.
	# 사자의 이야기 큐는 오프닝을 끝낸 세이브에서만 열린다.
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	var completion_event: Dictionary = {}
	for _drain in 12:
		var pending := game_state.call("get_pending_shelter_story_event") as Dictionary
		if pending.is_empty():
			break
		var pending_id := str(pending.get("id", ""))
		game_state.call("mark_shelter_story_event_seen", pending_id)
		if pending_id == "saja_main_chain_jongno_outskirts":
			completion_event = pending
			break
	assert(not completion_event.is_empty())
	var completion_text := "\n".join(completion_event.get("lines", []) as Array)
	print("SAJA_COMPLETION=%s" % completion_text.replace("\n", " | "))
	assert(completion_text.contains("남대문"))

	# ② 완주한 구역에서는 메인 미션이 안 뜨고 반복 사건이 자리를 대신한다.
	var repeat_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(repeat_scene)
	await process_frame
	await physics_frame
	repeat_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var repeat_chain: Object = repeat_scene.get("main_mission")
	assert((repeat_chain.get("stage") as Dictionary).is_empty())
	assert(str(repeat_chain.get("state")) == "none")
	assert(not (repeat_scene.get("hud").jackpot_hud as PanelContainer).visible)
	assert(str(repeat_scene.get("dynamic_incident_state")) == "active")
	print("COMPLETED_ZONE state=%s incident=%s" % [
		str(repeat_chain.get("state")),
		str(repeat_scene.get("dynamic_incident_state")),
	])
	# ⑥ 정산 XP 바가 레벨업에서 거꾸로 가지 않는가(유저 신고 B).
	var extraction: Object = repeat_scene.get("extraction")
	for probe in [
		{
			"name": "레벨업 없음",
			"result": {
				"old_level": 3, "new_level": 3, "old_xp": 40, "new_xp": 90,
				"old_required": 200, "new_required": 200, "levels_gained": 0,
			},
		},
		{
			"name": "레벨업 1회",
			"result": {
				"old_level": 3, "new_level": 4, "old_xp": 180, "new_xp": 30,
				"old_required": 200, "new_required": 320, "levels_gained": 1,
			},
		},
		{
			"name": "레벨업 2회",
			"result": {
				"old_level": 3, "new_level": 5, "old_xp": 180, "new_xp": 60,
				"old_required": 200, "new_required": 460, "levels_gained": 2,
			},
		},
	]:
		extraction.set("pending_extraction_xp_result", (probe as Dictionary)["result"])
		var plan := extraction.call("build_extraction_xp_bar_plan") as Array
		var trace: Array[String] = []
		var previous := 0.0
		var reversed_fill := false
		for step_value in plan:
			var step := step_value as Dictionary
			var kind := str(step.get("kind", ""))
			if kind == "levelup":
				trace.append("LVUP→%d" % int(step.get("level", 0)))
				continue
			var value := float(step.get("value", 0.0))
			trace.append("%s %.1f%%" % [kind, value])
			# 역주행 판정: 채우는 구간에서 값이 줄어들면 바가 거꾸로 간다.
			if kind == "fill" and value < previous - 0.01:
				reversed_fill = true
			previous = value
		print("XP_BAR[%s] %s" % [str((probe as Dictionary)["name"]), " → ".join(trace)])
		assert(not reversed_fill)
	repeat_scene.queue_free()
	await process_frame

	# ⑤ 방어형(defense) 단계 — 종로 체인에는 없는 골격이라 남대문 2단계로 확인한다.
	game_state.set("shelter_tier", 2)
	game_state.set("selected_raid_zone", "namdaemun_market")
	(game_state.get("main_mission_progress") as Dictionary)["namdaemun_market"] = 1
	var defense_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(defense_scene)
	await process_frame
	await physics_frame
	defense_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var defense_chain: Object = defense_scene.get("main_mission")
	assert(str((defense_chain.get("stage") as Dictionary).get("type", "")) == "defense")
	print("DEFENSE_STAGE id=%s duration=%s" % [
		str((defense_chain.get("stage") as Dictionary).get("id", "")),
		str(((defense_chain.get("points") as Array)[0] as Dictionary).get("defense_duration", 0.0)),
	])
	var defense_enemies_before := (defense_scene.get("enemies") as Array).size()
	_walk_stage(defense_scene, defense_chain)
	assert(str(defense_chain.get("state")) == "carried")
	print("DEFENSE_WAVES enemies %d → %d" % [
		defense_enemies_before, (defense_scene.get("enemies") as Array).size()
	])
	assert((defense_scene.get("enemies") as Array).size() > defense_enemies_before)
	var defense_settle := defense_scene.call("_settle_jackpot_cargo") as Dictionary
	print("DEFENSE_SETTLE=%s" % str(defense_settle.get("summary", "")).replace("\n", " | "))
	assert(int(game_state.call("get_main_mission_progress", "namdaemun_market")) == 2)
	defense_scene.queue_free()
	await process_frame
	game_state.set("selected_raid_zone", "jongno_outskirts")

	# ④ 세이브 왕복 — 진행도와 선택 기록이 살아남아야 한다.
	game_state.set("persistence_path", "user://main_mission_chain_probe.json")
	game_state.set("persistence_enabled", true)
	game_state.call("record_mission_choice", "probe_choice", "take")
	assert(bool(game_state.call("save_persistent_state")))
	var saved_progress: Dictionary = (game_state.get("main_mission_progress") as Dictionary).duplicate()
	(game_state.get("main_mission_progress") as Dictionary).clear()
	(game_state.get("mission_choices") as Dictionary).clear()
	assert(bool(game_state.call("load_persistent_state")))
	print("SAVE_ROUNDTRIP before=%s after=%s choice=%s" % [
		str(saved_progress),
		str(game_state.get("main_mission_progress")),
		str(game_state.call("get_mission_choice", "probe_choice")),
	])
	assert(int(game_state.call("get_main_mission_progress", "jongno_outskirts")) == 3)
	assert(str(game_state.call("get_mission_choice", "probe_choice")) == "take")

	# 구세이브 승격 — 잭팟 화물만 회수한 세이브는 종로 1단계 완주로 올라온다.
	(game_state.get("main_mission_progress") as Dictionary).clear()
	var legacy_ids: Array[String] = ["seoul_line3_relief_core"]
	game_state.set("recovered_story_cargo_ids", legacy_ids)
	game_state.call("_migrate_main_mission_progress")
	print("MIGRATION jongno=%d" % int(game_state.call("get_main_mission_progress", "jongno_outskirts")))
	assert(int(game_state.call("get_main_mission_progress", "jongno_outskirts")) == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://main_mission_chain_probe.json"))
	game_state.set("persistence_enabled", false)

	print("MAIN_MISSION_CHAIN_OK")
	quit(0)


func _walk_stage(main_scene: Node, chain: Object) -> void:
	# 현장 지점을 순서대로 끝낸다. 방어 단계는 버티기 시간을 즉시 채운다.
	for _guard in 8:
		if str(chain.get("state")) != "running":
			return
		var index := int(chain.get("point_index"))
		var sites := chain.get("point_sites") as Dictionary
		var site := sites.get(index, null) as Node3D
		if not is_instance_valid(site):
			return
		var interaction_type := str(site.get_meta("interaction_type", ""))
		print("  POINT %d type=%s label=%s" % [
			index, interaction_type, str(site.get_meta("display_name", ""))
		])
		main_scene.call("_complete_field_interaction", site)
		if bool(chain.get("defense_active")):
			# 먼저 웨이브 타이머를 소진시켜 실제로 적이 밀려오는지 확인한 뒤,
			# 버티기 시간을 채워 단계를 통과시킨다.
			chain.set("defense_wave_timer", 0.0)
			chain.call("update", 0.1)
			chain.set("defense_elapsed", float(chain.get("defense_duration")))
			chain.call("update", 0.1)
			print("  DEFENSE cleared waves=%d -> point_index=%d" % [
				int(chain.get("defense_waves_spawned")), int(chain.get("point_index"))
			])
