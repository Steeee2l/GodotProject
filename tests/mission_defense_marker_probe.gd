extends SceneTree

# 메인 미션 "지금 어디로 가야 하는지"가 항상 지도에 남아 있는가 프로브.
#
# 유저 신고: "메인미션 진행이 안 되는데? 위치도 모르겠고."
# 원인은 방어(defense) 단계였다 — 제어반을 조작하는 순간 지점 마커가 지워지고
# 방어 단계는 새 마커를 걸지 않아, 사수 반경 밖으로 나가면 돌아갈 곳이 지도에도
# 세계에도 없었다.
#
# 검증 항목
#   ① 방어 시작 시 사수 지점 마커가 반경과 함께 지도에 남는가
#   ② 반경 밖에서 목표 문구가 거리·방향을 말하는가(좌상단 패널까지)
#   ③ 반경 안으로 돌아오면 사수 카운트가 다시 도는가
#   ④ 방어 성공 시 사수 마커·바닥 링이 걷히고 다음 지점 마커가 서는가
#   ⑤ 다른 역할(key/locked/recovery)도 진행 내내 마커가 최소 하나는 남는가
#   ⑥ 회수물을 든 뒤에도 탈출 목표 마커가 남는가


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("shelter_tier", 2)

	await _probe_defense_stage(game_state)
	await _probe_keyed_stage(game_state)

	print("DEFENSE_MARKER_PROBE OK")
	quit()


# ── 방어 단계 ──────────────────────────────────────────────────


func _probe_defense_stage(game_state: Node) -> void:
	game_state.set("selected_raid_zone", "namdaemun_market")
	(game_state.get("main_mission_progress") as Dictionary)["namdaemun_market"] = 1
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var chain: Object = scene.get("main_mission")
	var tactical_map: Control = scene.get("tactical_map")
	var player: Node3D = scene.get("player")
	assert(str((chain.get("stage") as Dictionary).get("type", "")) == "defense")
	print("STAGE id=%s" % str((chain.get("stage") as Dictionary).get("id", "")))

	# 조작 전 — 제어반 지점 마커가 서 있다.
	print("BEFORE markers=%s" % _marker_summary(tactical_map))
	assert(_mission_marker_count(tactical_map) >= 1)

	# ① 제어반 상호작용 → 방어 시작. 지점 마커는 지워지지만 사수 마커가 대신 선다.
	var site := (chain.get("point_sites") as Dictionary).get(0, null) as Node3D
	assert(is_instance_valid(site))
	scene.call("_complete_field_interaction", site)
	assert(bool(chain.get("defense_active")))
	var defense_position: Vector3 = chain.get("defense_position")
	var defense_marker := _find_marker(tactical_map, "main_mission_defense")
	print("DEFENSE_MARKER=%s" % str(defense_marker))
	assert(not defense_marker.is_empty())
	assert((defense_marker.get("position", Vector3.ZERO) as Vector3).distance_to(defense_position) < 0.01)
	# 상수는 체인 스크립트에서 직접 꺼낸다 — 이 프로브가 main_mission_chain을 preload하면
	# 오토로드(GameState)가 서기 전에 컴파일돼 첫 로드가 실패한다.
	var hold_radius := float(
		chain.get_script().get_script_constant_map()["DEFENSE_HOLD_RADIUS"]
	)
	assert(is_equal_approx(float(defense_marker.get("radius", 0.0)), hold_radius))
	assert(bool(defense_marker.get("discovered", false)))
	# 바닥 사수 구역 링도 실제로 깔렸는가(반경까지).
	var zone_ring: Node3D = chain.get("defense_zone_ring")
	assert(is_instance_valid(zone_ring))
	var zone_disc := zone_ring.get_node("Disc") as MeshInstance3D
	assert(is_equal_approx((zone_disc.mesh as CylinderMesh).top_radius, hold_radius))
	print("ZONE_RING pos=%s radius=%.1f" % [
		str(zone_ring.global_position.round()), (zone_disc.mesh as CylinderMesh).top_radius
	])

	# ② 반경 밖으로 나가면 목표 문구가 거리와 방향을 말한다.
	player.global_position = defense_position + Vector3(31.0, 0.0, 0.0)
	chain.call("update", 0.1)
	scene.call("_refresh_objective_panel")
	var outside_detail := str((scene.get("hud").jackpot_detail_label as Label).text)
	var objective_text := str((scene.get("objective_label") as Label).text)
	print("OUTSIDE_DETAIL=%s" % outside_detail)
	print("OUTSIDE_PANEL=%s" % objective_text.replace("\n", " | "))
	assert(outside_detail.contains("31m"))
	assert(outside_detail.contains("벗어났다"))
	assert(objective_text.contains(outside_detail))
	# 밖에 있는 동안엔 카운트가 멈춘다.
	var stalled_elapsed := float(chain.get("defense_elapsed"))
	chain.call("update", 0.4)
	assert(is_equal_approx(float(chain.get("defense_elapsed")), stalled_elapsed))

	# ③ 반경 안으로 복귀 → 카운트 재개.
	player.global_position = defense_position
	chain.call("update", 0.4)
	assert(float(chain.get("defense_elapsed")) > stalled_elapsed)
	var inside_detail := str((scene.get("hud").jackpot_detail_label as Label).text)
	print("INSIDE_DETAIL=%s" % inside_detail)
	assert(inside_detail.contains("자리 사수"))
	# 안쪽에서도 사수 마커는 그대로 있어야 한다(지도에서 사라지면 다시 길을 잃는다).
	assert(not _find_marker(tactical_map, "main_mission_defense").is_empty())

	# ④ 방어 성공 → 사수 마커·링 제거, 다음 지점(회수) 마커 등록.
	chain.set("defense_wave_timer", 0.0)
	chain.call("update", 0.1)
	chain.set("defense_elapsed", float(chain.get("defense_duration")))
	chain.call("update", 0.1)
	assert(not bool(chain.get("defense_active")))
	assert(_find_marker(tactical_map, "main_mission_defense").is_empty())
	assert(not is_instance_valid(chain.get("defense_zone_ring")))
	print("AFTER_DEFENSE markers=%s" % _marker_summary(tactical_map))
	assert(_mission_marker_count(tactical_map) >= 1)

	# ⑥ 회수물을 들면 지점 마커는 걷힌다 — 대신 탈출 목표가 서야 한다.
	var recovery_index := int(chain.get("point_index"))
	var recovery_site := (chain.get("point_sites") as Dictionary).get(recovery_index, null) as Node3D
	assert(is_instance_valid(recovery_site))
	scene.call("_complete_field_interaction", recovery_site)
	assert(str(chain.get("state")) == "carried")
	await process_frame
	print("CARRIED markers=%s" % _marker_summary(tactical_map))
	assert(not _find_marker(tactical_map, "main_mission_extraction").is_empty())
	# 다음 판으로 넘어가기 전에 회수물을 정산한다 — 안 그러면 다음 씬이 "운반 중"
	# 상태로 복원돼 단계 자체가 안 깔린다.
	var settle_summary := str(
		(scene.call("_settle_jackpot_cargo") as Dictionary).get("summary", "")
	)
	print("DEFENSE_SETTLE=%s" % settle_summary.split("\n", false)[0])

	scene.queue_free()
	await process_frame
	await process_frame


# ── 다른 역할(열쇠/잠긴 거점) ──────────────────────────────────


func _probe_keyed_stage(game_state: Node) -> void:
	game_state.set("selected_raid_zone", "jongno_outskirts")
	(game_state.get("main_mission_progress") as Dictionary)["jongno_outskirts"] = 2
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var chain: Object = scene.get("main_mission")
	var tactical_map: Control = scene.get("tactical_map")
	print("KEYED_STAGE id=%s type=%s" % [
		str((chain.get("stage") as Dictionary).get("id", "")),
		str((chain.get("stage") as Dictionary).get("type", "")),
	])
	assert(str((chain.get("stage") as Dictionary).get("type", "")) == "keyed")

	for _guard in 6:
		if str(chain.get("state")) != "running":
			break
		# 진행 도중 언제든 지도에는 목표가 최소 하나 남아 있어야 한다.
		print("  STEP %d markers=%s" % [int(chain.get("point_index")), _marker_summary(tactical_map)])
		assert(_mission_marker_count(tactical_map) >= 1)
		var index := int(chain.get("point_index"))
		var site := (chain.get("point_sites") as Dictionary).get(index, null) as Node3D
		if not is_instance_valid(site):
			break
		scene.call("_complete_field_interaction", site)
	assert(str(chain.get("state")) == "carried")
	await process_frame
	print("KEYED_CARRIED markers=%s" % _marker_summary(tactical_map))
	assert(_mission_marker_count(tactical_map) >= 1)
	scene.queue_free()
	await process_frame


# ── 헬퍼 ───────────────────────────────────────────────────────


func _find_marker(tactical_map: Control, marker_id: String) -> Dictionary:
	for marker_value in tactical_map.get("raid_markers") as Array:
		var marker := marker_value as Dictionary
		if str(marker.get("id", "")) == marker_id:
			return marker
	return {}


func _mission_marker_count(tactical_map: Control) -> int:
	var count := 0
	for marker_value in tactical_map.get("raid_markers") as Array:
		var marker := marker_value as Dictionary
		if str(marker.get("id", "")).begins_with("main_mission"):
			count += 1
	return count


func _marker_summary(tactical_map: Control) -> String:
	var parts: Array[String] = []
	for marker_value in tactical_map.get("raid_markers") as Array:
		var marker := marker_value as Dictionary
		if not str(marker.get("id", "")).begins_with("main_mission"):
			continue
		parts.append("%s(%s r=%.0f)" % [
			str(marker.get("id", "")),
			str(marker.get("label", "")),
			float(marker.get("radius", 0.0)),
		])
	return "[none]" if parts.is_empty() else ", ".join(parts)
