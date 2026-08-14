extends SceneTree

# 장비 레벨 시스템: ID 접미사("@N") 해석, 스탯 성장, 인벤토리/장착 호환,
# 드랍 레벨이 도시 티어를 따라가는지 검증한다.

const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	# ── ID 해석 ──
	assert(int(game_state.call("get_equipment_level", "scav_vest")) == 1)
	assert(int(game_state.call("get_equipment_level", "scav_vest@3")) == 3)
	assert(str(game_state.call("make_equipment_id", "scav_vest", 1)) == "scav_vest")
	assert(str(game_state.call("make_equipment_id", "scav_vest", 4)) == "scav_vest@4")

	# ── 스탯 성장 ──
	var base_def: Dictionary = game_state.call("get_equipment_definition", "scav_vest")
	var lv3_def: Dictionary = game_state.call("get_equipment_definition", "scav_vest@3")
	assert(not lv3_def.is_empty())
	assert(int(lv3_def.get("level", 0)) == 3)
	assert(str(lv3_def.get("base_id", "")) == "scav_vest")
	assert(
		float(lv3_def.get("damage_reduction", 0.0))
		> float(base_def.get("damage_reduction", 0.0))
	)
	assert(str(lv3_def.get("display_name", "")).contains("Lv.3"))
	# 부위당 피해 감소 상한 0.5
	var lv5_riot: Dictionary = game_state.call("get_equipment_definition", "riot_vest@5")
	assert(float(lv5_riot.get("damage_reduction", 0.0)) <= 0.5 + 0.0001)
	# 신발은 이동/스태미나가 성장한다
	var lv3_boots: Dictionary = game_state.call("get_equipment_definition", "tactical_boots@3")
	assert(
		float(lv3_boots.get("move_speed_bonus", 0.0))
		> float((game_state.call("get_equipment_definition", "tactical_boots") as Dictionary).get("move_speed_bonus", 0.0))
	)
	assert(
		float(lv3_boots.get("stamina_cost_multiplier", 1.0))
		< float((game_state.call("get_equipment_definition", "tactical_boots") as Dictionary).get("stamina_cost_multiplier", 1.0))
	)

	# ── 점수 비교: 같은 장비라도 레벨이 높으면 좋다 (equip_if_upgrade의 기반) ──
	assert(
		float(game_state.call("get_equipment_score", "patched_sneakers@3"))
		> float(game_state.call("get_equipment_score", "patched_sneakers"))
	)

	# ── 인벤토리/장착 호환 ──
	assert(bool(game_state.call("add_equipment", "scav_vest@3", 1)))
	assert(int(game_state.call("get_equipment_count", "scav_vest@3")) == 1)
	assert(bool(game_state.call("equip_equipment", "scav_vest@3")))
	assert(str(game_state.call("get_equipped_equipment", "body")) == "scav_vest@3")
	assert(int(game_state.call("get_equipment_count", "scav_vest@3")) == 0)
	# 존재하지 않는 기본 ID는 여전히 거부
	assert(not bool(game_state.call("add_equipment", "no_such_gear@2", 1)))
	# 레벨 장비 장착이 피해 배율에 실제로 반영된다
	var damage_multiplier := float(game_state.call("get_equipment_damage_multiplier"))
	var lv3_reduction := float(lv3_def.get("damage_reduction", 0.0))
	assert(absf(damage_multiplier - (1.0 - lv3_reduction)) < 0.001)

	# ── 주운 장비가 더 좋으면 자동 장착 ──
	assert(bool(game_state.call("add_equipment", "scav_vest@5", 1)))
	var upgrade_result: Dictionary = game_state.call("equip_if_upgrade", "scav_vest@5")
	assert(bool(upgrade_result.get("equipped", false)))
	assert(str(game_state.call("get_equipped_equipment", "body")) == "scav_vest@5")

	# ── 드랍 레벨 분포: 어느 티어든 1~5가 다 나오되 가중치가 티어를 따른다 ──
	var random := RandomNumberGenerator.new()
	random.seed = 20260814
	var tier1_counts: Dictionary = {}
	var tier4_counts: Dictionary = {}
	var tier1_sum := 0
	var tier4_sum := 0
	const SAMPLES := 2000
	for _attempt in SAMPLES:
		var tier1_item: Dictionary = LOOT_ECONOMY._materialize_item("patched_sneakers", 1, random)
		var tier4_item: Dictionary = LOOT_ECONOMY._materialize_item("tactical_boots", 4, random)
		var tier1_id := str((tier1_item.get("data", {}) as Dictionary).get("equipment_id", ""))
		var tier4_id := str((tier4_item.get("data", {}) as Dictionary).get("equipment_id", ""))
		var tier1_level := int(game_state.call("get_equipment_level", tier1_id))
		var tier4_level := int(game_state.call("get_equipment_level", tier4_id))
		tier1_counts[tier1_level] = int(tier1_counts.get(tier1_level, 0)) + 1
		tier4_counts[tier4_level] = int(tier4_counts.get(tier4_level, 0)) + 1
		tier1_sum += tier1_level
		tier4_sum += tier4_level
	print("tier1_levels=", tier1_counts, " tier4_levels=", tier4_counts)
	# 종로(티어1)에서도 상위 레벨 잭팟이 존재한다 — 풀이 넓어야 갈아 끼우는 맛이 산다
	assert(int(tier1_counts.get(1, 0)) > SAMPLES / 2)  # 최빈값은 Lv1
	assert(int(tier1_counts.get(3, 0)) > 0)  # Lv3 잭팟 존재
	assert(tier1_counts.size() >= 3)
	# 티어4는 분포 전체가 위로 밀리고(평균 비교), 아래 레벨도 소량 섞인다
	assert(float(tier4_sum) / float(SAMPLES) > float(tier1_sum) / float(SAMPLES) + 1.5)
	assert(int(tier4_counts.get(4, 0)) > int(tier4_counts.get(1, 0)))
	assert(tier4_counts.size() >= 4)

	print("EQUIPMENT_LEVEL_SMOKE_TEST_PASSED")
	quit(0)
