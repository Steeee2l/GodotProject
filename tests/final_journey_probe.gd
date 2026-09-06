extends SceneTree

# 마지막 출정·엔딩 프로브(헤드리스).
#   ① 해금 — 남산 체인 완주만으로는 안 열린다. 사자의 고백을 확인해야 열린다.
#   ② 고백 대사가 "혼자는 못 가겠어."로 끝나고, 확인 시 final_raid_unlocked
#   ③ 마지막 출정 판 — 별도 미션 데이터(namsan_final_walk) + 사자 동행 소환
#   ④ 여정 — 사자 잡담 말풍선이 뜬다(전투 중엔 다른 줄)
#   ⑤ 엔딩 — 마지막 지점 → 문 앞 연출 → 엔딩 화면 + ending_seen 저장
#   ⑥ 복귀 — 엔딩 화면을 닫으면 final_raid_run이 꺼지고 평소 탈출 정산으로 넘어간다
#   ⑦ 후일담 — 클리어 뒤 쉘터에서 사자 후일담 이벤트, 그 뒤 잡담이 'after' 단계로
#
# 실행: godot --headless --path . --script tests/final_journey_probe.gd
#
# 규약: 프레임 대기가 아니라 실시간 타이머(create_timer(..., true, false, true))로
# 기다린다 — 이 PC는 500fps라 프레임 수로 시간을 재면 어긋난다.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROBE_FAIL: " + message)


func _run() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		push_error("FINAL_JOURNEY_PROBE_TIMEOUT")
		quit(2)
	)
	Engine.max_physics_steps_per_frame = 64
	# 세이브 오염 방지 — 프로브는 디스크에 쓰지 않는다.
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("returning_from_shelter", false)

	_probe_unlock(game_state)
	await _probe_final_run(game_state)
	_probe_epilogue(game_state)

	if failures.is_empty():
		print("FINAL_JOURNEY_PROBE_OK")
		quit(0)
	else:
		print("FINAL_JOURNEY_PROBE_FAILED %d" % failures.size())
		for failure in failures:
			print("  - " + failure)
		quit(1)


# ── ①② 해금 ───────────────────────────────────────────────────


func _probe_unlock(game_state: Node) -> void:
	game_state.set("final_raid_unlocked", false)
	game_state.set("ending_seen", false)
	game_state.set("saja_epilogue_seen", false)
	var progress := {}
	for zone_id in ["jongno_outskirts", "namdaemun_market", "euljiro_depths", "yongsan_blockade"]:
		progress[zone_id] = 3
	game_state.set("main_mission_progress", progress)
	_assert(
		not bool(game_state.call("is_final_raid_available")),
		"① 남산을 안 끝냈으면 마지막 출정이 열리면 안 됩니다."
	)

	# 남산까지 완주 — 그래도 고백을 안 봤으면 아직 닫혀 있어야 한다.
	progress["namsan_core"] = 3
	game_state.set("main_mission_progress", progress)
	_assert(
		not bool(game_state.call("is_final_raid_available")),
		"① 고백을 보기 전에는 마지막 출정이 열리면 안 됩니다."
	)

	# ② 고백 대사 확인 — 앞 구역 안내는 이미 본 것으로 두고 남산만 남긴다.
	var seen_zones: Array[String] = [
		"jongno_outskirts", "namdaemun_market", "euljiro_depths", "yongsan_blockade",
	]
	game_state.set("saja_seen_main_mission_zones", seen_zones)
	game_state.set("survived_return_count", 5)
	game_state.set("saja_intro_seen", true)
	game_state.set("juhong_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	var event: Dictionary = game_state.call("get_pending_shelter_story_event")
	_assert(
		str(event.get("id", "")) == "saja_main_chain_namsan_core",
		"② 남산 완주 뒤 첫 복귀에 사자의 고백이 떠야 합니다 (실제: %s)" % str(event.get("id", ""))
	)
	var lines := event.get("lines", []) as Array
	_assert(
		not lines.is_empty() and str(lines[lines.size() - 1]) == "혼자는 못 가겠어.",
		"② 고백은 '혼자는 못 가겠어.'로 끝나야 합니다."
	)
	game_state.call("mark_shelter_story_event_seen", "saja_main_chain_namsan_core")
	_assert(bool(game_state.get("final_raid_unlocked")), "② 고백 확인 시 final_raid_unlocked여야 합니다.")
	_assert(bool(game_state.call("is_final_raid_available")), "② 이제 마지막 출정이 열려야 합니다.")


# ── ③~⑥ 필드 ──────────────────────────────────────────────────


func _probe_final_run(game_state: Node) -> void:
	game_state.set("selected_raid_zone", "namsan_core")
	game_state.set("final_raid_run", true)
	game_state.set("raid_special_cargo", {})
	# 주홍은 이번 검증에서 제외 — 사자 동행만 본다.
	game_state.set("companion_enabled", false)

	var main_scene := await _spawn_main(game_state)
	if main_scene == null:
		_assert(false, "③ 필드 씬을 세우지 못했습니다.")
		return
	var main_mission = main_scene.get("main_mission")
	var journey = main_scene.get("final_journey")
	var companion = main_scene.get("companion_system")

	# ③ 별도 미션 데이터 + 사자 동행.
	var stage := main_mission.get("stage") as Dictionary
	_assert(
		str(stage.get("id", "")) == "namsan_final_walk",
		"③ 마지막 출정은 namsan_final_walk 데이터를 써야 합니다 (실제: %s)" % str(stage.get("id", ""))
	)
	_assert(bool(stage.get("ending", false)), "③ 마지막 단계에 ending 플래그가 있어야 합니다.")
	_assert(
		(main_mission.get("points") as Array).size() == 3,
		"③ 마지막 출정 지점은 3개여야 합니다(회수물 없음)."
	)
	_assert(int(main_mission.get("stage_index")) == -1, "③ 체인 진행도를 올리지 않는 판이어야 합니다.")
	_assert(bool(companion.call("is_saja_alive")), "③ 사자가 필드에 소환돼야 합니다.")
	_assert(bool(journey.call("is_active")), "③ FinalJourney가 시작돼 있어야 합니다.")

	# ④ 여정 잡담 — 타이머를 당겨 한 줄 흘린다.
	journey.set("chatter_timer", 0.01)
	journey.call("update", 0.05)
	var saja = companion.get("saja")
	_assert(
		saja != null and saja.get_node_or_null("FieldSpeechBubble") != null,
		"④ 길에서 사자의 말풍선이 떠야 합니다."
	)

	# ⑤ 지점 셋을 차례로 밟는다 → 마지막에서 엔딩.
	var points := main_mission.get("points") as Array
	main_mission.call("_finish_point", 0, points[0])
	await create_timer(0.3, true, false, true).timeout
	main_mission.call("_finish_point", 1, points[1])
	await create_timer(0.3, true, false, true).timeout
	main_mission.call("_finish_point", 2, points[2])
	await create_timer(0.4, true, false, true).timeout

	var cinematic = journey.get("cinematic")
	_assert(bool(cinematic.call("is_running")), "⑤ 문 앞 연출이 돌아야 합니다.")
	_assert(
		bool(main_mission.call("is_cinematic_active")),
		"⑤ 문 앞 연출 중에는 조작 잠금(is_cinematic_active)이 켜져야 합니다."
	)
	# 연출을 건너뛰어 끝까지 보낸다.
	var guard := 0
	while bool(cinematic.call("is_running")) and guard < 40:
		cinematic.call("skip")
		guard += 1
		await create_timer(0.15, true, false, true).timeout
	var ending_screen = journey.get("ending_screen")
	_assert(bool(ending_screen.call("is_open")), "⑤ 연출이 끝나면 엔딩 화면이 떠야 합니다.")
	_assert(bool(game_state.get("ending_seen")), "⑤ 엔딩 시점에 ending_seen이 켜져야 합니다.")

	# ⑥ 복귀 — 엔딩 화면을 닫으면 마지막 출정 깃발이 내려가고 탈출 정산으로 넘어간다.
	ending_screen.call("close")
	await create_timer(0.3, true, false, true).timeout
	_assert(not bool(game_state.get("final_raid_run")), "⑥ 복귀 시 final_raid_run이 꺼져야 합니다.")
	_assert(
		bool(main_scene.get("extraction_transition_active")),
		"⑥ 엔딩 뒤에는 평소 탈출 정산으로 넘어가야 합니다(전리품·XP 보존)."
	)
	paused = false
	main_scene.queue_free()
	await create_timer(0.3, true, false, true).timeout


# ── ⑦ 후일담 ──────────────────────────────────────────────────


func _probe_epilogue(game_state: Node) -> void:
	game_state.set("saja_epilogue_seen", false)
	var event: Dictionary = game_state.call("get_pending_shelter_story_event")
	_assert(
		str(event.get("id", "")) == "saja_epilogue",
		"⑦ 클리어 뒤 첫 복귀에 사자 후일담이 떠야 합니다 (실제: %s)" % str(event.get("id", ""))
	)
	game_state.call("mark_shelter_story_event_seen", "saja_epilogue")
	_assert(bool(game_state.get("saja_epilogue_seen")), "⑦ 후일담은 한 번만 떠야 합니다.")
	var again: Dictionary = game_state.call("get_pending_shelter_story_event")
	_assert(str(again.get("id", "")) != "saja_epilogue", "⑦ 후일담이 두 번 뜨면 안 됩니다.")
	# 클리어 뒤 잡담은 'after' 단계를 쓴다 — 같은 사람인데 말끝이 달라진다.
	game_state.set("saja_chatter_serial_seen", -1)
	game_state.set("shelter_return_serial", 9)
	var chatter: Dictionary = game_state.call("_build_saja_chatter_event")
	_assert(
		str(chatter.get("id", "")).begins_with("saja_chatter_after_"),
		"⑦ 클리어 뒤 사자 잡담은 after 단계여야 합니다 (실제: %s)" % str(chatter.get("id", ""))
	)


func _spawn_main(game_state: Node) -> Node:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	await create_timer(0.4, true, false, true).timeout
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 사자 서사/시네마틱 모달 먼저 닫기(프로브 규약) — 마지막 출정도 인트로가 있다.
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while main_mission != null and bool(main_mission.call("is_cinematic_active")) and skip_guard < 25:
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.2, true, false, true).timeout
	await physics_frame
	return main_scene
