extends SceneTree

# 전리품 경제 스모크 테스트 — 2026-08 경제 코어(장비 제작 전용·영구 귀속) 기준.
#   · 무기·방어구는 어떤 드랍 경로(적·엘리트·보스·상자·낱개)에서도 0
#   · 빈 드랍이 늘지 않는다(일반 적 any ≈ 0.66, 부품·탄약·식량으로 메움)
#   · 새 품목: 설계도 조각(일반 6%·엘리트 확정·보스 2·봉인 상자 40%), 정밀 기어(엘리트 50%·
#     봉인 보급함), 군용 합금(보스 1~2·존4+ 봉인 보급함), 장인의 인장(보스 확정·엘리트 5%)
#   · 스마트 탄약·호환탄 회수 규칙은 종전 그대로

const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage_one_profile := LOOT_ECONOMY.get_stage_profile(1)
	var stage_four_profile := LOOT_ECONOMY.get_stage_profile(4)
	assert(_container_count(stage_one_profile) == 36)
	assert(_container_count(stage_four_profile) == 59)
	assert(int(stage_one_profile.get("weapon_rarity_cap", 0)) == 1)
	assert(int(stage_four_profile.get("weapon_rarity_cap", 0)) == 4)
	# 장비 캡은 0(무효) — 장비는 필드에 스폰되지 않는다.
	for stage_tier in range(1, 6):
		var profile := LOOT_ECONOMY.get_stage_profile(stage_tier)
		assert(int(profile.get("weapon_spawn_cap", 1)) == 0 and int(profile.get("enemy_weapon_spawn_cap", 1)) == 0)
		assert(is_equal_approx(float(profile.get("blueprint_shard_case_chance", 0.0)), 0.4))
	# 쉘터 연료 싱크가 사라져(통조림 = 플레이어 소모품) 확정 통조림 픽업을 약 60%로
	# 줄였다: 21/27 → 12/16.
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(1) == 12)
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(4) == 16)

	var stage_one_supply := LOOT_ECONOMY.simulate_stage_supply(1, 600, 1103)
	var stage_four_supply := LOOT_ECONOMY.simulate_stage_supply(4, 600, 2207)
	print("LOOT_SUPPLY_STAGE_1 ", stage_one_supply)
	print("LOOT_SUPPLY_STAGE_4 ", stage_four_supply)
	# 필드 컨테이너 무기 0 — 존1도 존4도.
	assert(is_zero_approx(float(stage_one_supply.get("average_weapons", 1.0))))
	assert(is_zero_approx(float(stage_four_supply.get("average_weapons", 1.0))))
	assert(float(stage_one_supply.get("average_ammo", 0.0)) >= 40.0)
	assert(float(stage_one_supply.get("average_ammo", 999.0)) <= 70.0)
	# 확정 픽업 12 + 컨테이너 통조림(옷 더미는 방어구 대신 소지품이 들어와 식량 비중이
	# 조금 줄었다) — 22 이상이면 "먹고 던질 만큼"이다.
	assert(float(stage_one_supply.get("average_canned_food", 0.0)) >= 22.0)
	assert(float(stage_one_supply.get("average_components", 0.0)) >= 10.0)
	assert(float(stage_one_supply.get("average_common_supply", 0.0)) >= 20.0)
	assert(float(stage_one_supply.get("common_supply_success_rate", 0.0)) >= 0.95)
	# 잠긴 장비 상자(존1 1개) 40% → 판당 조각 0.4 부근. 존4(장비 상자 5 + 봉인 5)는 더 많다.
	assert(float(stage_one_supply.get("average_blueprint_shards", 0.0)) >= 0.25, "존1 컨테이너 조각 ≥0.25 (실측 %.2f)" % float(stage_one_supply.get("average_blueprint_shards", 0.0)))
	assert(float(stage_four_supply.get("average_blueprint_shards", 0.0)) > float(stage_one_supply.get("average_blueprint_shards", 0.0)) * 3.0)
	assert(float(stage_four_supply.get("average_rare_components", 0.0)) > 0.0, "존4 봉인 보급함에서 희귀 부품")
	assert(is_zero_approx(float(stage_one_supply.get("average_high_tier_ammo", 1.0))))
	assert(float(stage_four_supply.get("average_high_tier_ammo", 0.0)) > 0.0)

	var random := RandomNumberGenerator.new()
	random.seed = 778899
	var secure_high_tier_ammo_found := false
	var secure_shard_found := false
	var secure_precision_found := false
	var secure_alloy_low_stage := false
	for stage_tier in range(1, 5):
		var profile := LOOT_ECONOMY.get_stage_profile(stage_tier)
		for _sample in 500:
			for definition in LOOT_ECONOMY.roll_container(
				"ammo_case",
				stage_tier,
				"street_mixed",
				random
			):
				var data := definition.get("data", {}) as Dictionary
				assert(int(data.get("ammo_tier", 1)) <= 2)
				# 장착 구경(기본 762)은 스테이지 티어 캡을 면제받는다 —
				# 플레이어가 이미 그 총을 들고 온 도시다.
				var equipped_caliber := str(data.get("ammo_id", "")) == "762_fmj"
				assert(
					equipped_caliber
					or int(data.get("ammo_tier", 1))
					<= int(profile.get("ammo_tier_cap", 1))
				)
			for definition in LOOT_ECONOMY.roll_container(
				"secure_cache",
				stage_tier,
				"street_mixed",
				random
			):
				var data := definition.get("data", {}) as Dictionary
				assert(str(definition.get("type", "")) not in ["weapon", "armor"], "봉인 보급함에 장비 없음")
				if str(definition.get("type", "")) == "ammo":
					assert(stage_tier >= 3)
					if int(data.get("ammo_tier", 1)) >= 3:
						secure_high_tier_ammo_found = true
				elif str(definition.get("type", "")) == "progression_item":
					assert(stage_tier >= 3)
					if str(data.get("item_id", "")).begins_with("blueprint_shard_"):
						secure_shard_found = true
				elif str(definition.get("type", "")) == "mod_component":
					var component_id := str(data.get("component_id", ""))
					if component_id == "precision_gear":
						secure_precision_found = true
					if component_id == "military_alloy" and stage_tier < 4:
						secure_alloy_low_stage = true
			for definition in LOOT_ECONOMY.roll_container(
				"weapon_case",
				stage_tier,
				"street_mixed",
				random
			):
				assert(str(definition.get("type", "")) not in ["weapon", "armor"], "잠긴 장비 상자에 장비 없음")
			for definition in LOOT_ECONOMY.roll_container("clothing_cache", stage_tier, "street_mixed", random):
				assert(str(definition.get("type", "")) != "armor", "옷 더미에 방어구 없음")
	assert(secure_high_tier_ammo_found)
	assert(secure_shard_found, "봉인 보급함 설계도 조각")
	assert(secure_precision_found, "봉인 보급함 정밀 기어")
	assert(not secure_alloy_low_stage, "군용 합금은 존4부터")

	var loose_gear_count := 0
	for sample_index in 600:
		var loose := LOOT_ECONOMY.roll_loose_loot(
			1,
			"street_mixed",
			random
		)
		if str(loose.get("type", "")) in ["weapon", "armor"]:
			loose_gear_count += 1
		assert(sample_index >= 0)
	assert(loose_gear_count == 0)

	# 적 처치 드랍 — 장비 0(근접·사수·맨손 회복 플래그 무관), 탄약 스택 2~12.
	var gear_drop_count := 0
	var ranged_sample_count := 5000
	for _sample in ranged_sample_count:
		var melee_drop := LOOT_ECONOMY.roll_enemy_drop(4, "melee", "baseball_bat", random)
		if str(melee_drop.get("type", "")) in ["weapon", "armor"]:
			gear_drop_count += 1
		var ranged_drop := LOOT_ECONOMY.roll_enemy_drop(4, "ranged", "ak47", random)
		if str(ranged_drop.get("type", "")) in ["weapon", "armor"]:
			gear_drop_count += 1
		if str(ranged_drop.get("type", "")) == "ammo":
			var ammo_amount := int((ranged_drop.get("data", {}) as Dictionary).get("amount", 0))
			# 2026-08-30 탄약 넉넉화: 낱개 8~16, 정상 스택(존4) 15~26.
			assert(ammo_amount >= 8 and ammo_amount <= 26)
		# 옛 "맨손 회복 무기 58%" — 장비가 영구 귀속이라 플래그가 켜져도 무기는 없다.
		var recovery_drop := LOOT_ECONOMY.roll_enemy_drop(1, "ranged", "m1911", random, true)
		if str(recovery_drop.get("type", "")) in ["weapon", "armor"]:
			gear_drop_count += 1
	assert(gear_drop_count == 0, "적 처치 드랍 장비 0 (실측 %d)" % gear_drop_count)

	# 스마트 탄약: 장착 무기(762)가 있으면 권총 적을 죽여도 탄약 드랍의
	# 다수가 내 구경으로 나온다 — 판 내 재무장 파워커브의 핵심.
	var smart_game_state := root.get_node("GameState")
	smart_game_state.set("has_ak", true)
	smart_game_state.set("equipped_ammo_id", "762_fmj")
	var matched_ammo_count := 0
	var ammo_drop_count := 0
	for _sample in 4000:
		var smart_drop := LOOT_ECONOMY.roll_enemy_drop(2, "ranged", "m1911", random)
		if str(smart_drop.get("type", "")) == "ammo":
			ammo_drop_count += 1
			if str((smart_drop.get("data", {}) as Dictionary).get("ammo_id", "")) == "762_fmj":
				matched_ammo_count += 1
	assert(ammo_drop_count > 100)
	var matched_rate := float(matched_ammo_count) / float(ammo_drop_count)
	# 매칭 확률 70→90%(2026-08-30) — 다수가 아니라 '거의 전부'여야 한다.
	assert(matched_rate >= 0.8, "장착 구경 매칭 탄약이 거의 전부여야 한다 (실측 %.2f)" % matched_rate)

	# 호환탄 회수량: 12~(20+2×min(스테이지,3)) — 2026-08-30 넉넉화.
	for recovery_stage in range(1, 6):
		var recovery_total := 0
		var recovery_cap := 20 + 2 * mini(recovery_stage, 3)
		for _sample in 2000:
			var recovery := LOOT_ECONOMY.roll_matched_ammo_recovery(recovery_stage, random)
			var recovery_amount := int((recovery.get("data", {}) as Dictionary).get("amount", 0))
			assert(recovery_amount >= 12 and recovery_amount <= recovery_cap)
			recovery_total += recovery_amount
		var recovery_average := float(recovery_total) / 2000.0
		var expected_average := (12.0 + float(recovery_cap)) * 0.5
		assert(absf(recovery_average - expected_average) <= 0.4)

	# 스마트 탄약 치환률: 일반 상자 75%.
	var case_ammo_count := 0
	var case_matched_count := 0
	for _sample in 4000:
		for definition in LOOT_ECONOMY.roll_container("weapon_case", 2, "street_mixed", random):
			if str(definition.get("type", "")) != "ammo":
				continue
			case_ammo_count += 1
			if str((definition.get("data", {}) as Dictionary).get("ammo_id", "")) == "762_fmj":
				case_matched_count += 1
	assert(case_ammo_count > 500)
	var case_matched_rate := float(case_matched_count) / float(case_ammo_count)
	assert(
		case_matched_rate >= 0.72,
		"일반 상자 탄약도 장착 구경 위주여야 한다 (실측 %.2f)" % case_matched_rate
	)

	# 일반 적 드랍 분포(존1 사수): 조각 6% + ordinary 64% × (탄약 26/통조림 30/구급약 8/부품 36).
	# 기대값: any = 0.06 + 0.94×0.64 ≈ 0.66, common(식량+부품) ≈ 0.94×0.64×0.66 ≈ 0.40,
	# 조각 ≈ 0.06, 장비 0. 빈 드랍은 옛 장비 22%가 빠졌어도 늘지 않았다(any ≈ 0.70 → 0.66).
	var common_enemy_drop_count := 0
	var any_enemy_drop_count := 0
	var shard_enemy_drop_count := 0
	var common_enemy_sample_count := 6000
	for _sample in common_enemy_sample_count:
		var common_drop := LOOT_ECONOMY.roll_enemy_drop(1, "ranged", "m1911", random)
		if common_drop.is_empty():
			continue
		any_enemy_drop_count += 1
		var drop_type := str(common_drop.get("type", ""))
		assert(drop_type not in ["weapon", "armor"])
		if drop_type in ["canned_food", "mod_component"]:
			common_enemy_drop_count += 1
		if drop_type == "progression_item" and str((common_drop.get("data", {}) as Dictionary).get("item_id", "")).begins_with("blueprint_shard_"):
			shard_enemy_drop_count += 1
	var any_enemy_drop_rate := float(any_enemy_drop_count) / float(common_enemy_sample_count)
	var common_enemy_drop_rate := float(common_enemy_drop_count) / float(common_enemy_sample_count)
	var shard_enemy_drop_rate := float(shard_enemy_drop_count) / float(common_enemy_sample_count)
	print("ENEMY_DROP_RATES any=%.3f common=%.3f shard=%.3f" % [
		any_enemy_drop_rate, common_enemy_drop_rate, shard_enemy_drop_rate,
	])
	assert(any_enemy_drop_rate >= 0.62 and any_enemy_drop_rate <= 0.70, "any 0.66 부근 (실측 %.3f)" % any_enemy_drop_rate)
	assert(common_enemy_drop_rate >= 0.35 and common_enemy_drop_rate <= 0.45, "common 0.40 부근 (실측 %.3f)" % common_enemy_drop_rate)
	assert(shard_enemy_drop_rate >= 0.04 and shard_enemy_drop_rate <= 0.08, "설계도 조각 6%% 부근 (실측 %.3f)" % shard_enemy_drop_rate)
	# 존1 조각은 그 존 가족(T1 방어구·M1911·MP5 — AK는 시작 보유라 제외)이어야 한다.
	var zone1_shards := {}
	for _sample in 3000:
		var drop := LOOT_ECONOMY.roll_enemy_drop(1, "ranged", "mp5", random)
		if str(drop.get("type", "")) != "progression_item":
			continue
		var recipe_id := str((drop.get("data", {}) as Dictionary).get("recipe_id", ""))
		zone1_shards[recipe_id] = true
	for recipe_id in zone1_shards.keys():
		assert((LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE[1] as Array).has(str(recipe_id)), "존1 조각은 존1 풀 (got %s)" % str(recipe_id))
	assert(not zone1_shards.has("ak47"), "시작 보유 AK 조각은 안 나온다(완성 제외)")
	assert(zone1_shards.size() >= 4, "존1 풀의 여러 레시피가 고르게 나온다 (got %s)" % str(zone1_shards.keys()))

	# 엘리트 확정: [조각, 탄약 2배, 고가치품, (50%) 정밀 기어, (5%) 인장]. 장비 0.
	var elite_gear_count := 0
	var elite_shard_count := 0
	var elite_precision_count := 0
	var elite_seal_count := 0
	var elite_samples := 2000
	for _sample in elite_samples:
		var shard_seen := false
		for entry in LOOT_ECONOMY.roll_elite_drop(1, "mp5", random):
			var tally: Dictionary = LOOT_ECONOMY._classify_gear_drop(entry as Dictionary)
			elite_gear_count += int(tally.get("weapon", 0)) + int(tally.get("armor", 0))
			elite_precision_count += int(tally.get("precision", 0))
			elite_seal_count += int(tally.get("seal", 0))
			if int(tally.get("shard", 0)) > 0:
				shard_seen = true
		if shard_seen:
			elite_shard_count += 1
	assert(elite_gear_count == 0, "엘리트 장비 0")
	assert(elite_shard_count == elite_samples, "엘리트 조각 확정 (실측 %d/%d)" % [elite_shard_count, elite_samples])
	var elite_precision_rate := float(elite_precision_count) / float(elite_samples)
	assert(elite_precision_rate >= 0.44 and elite_precision_rate <= 0.56, "엘리트 정밀 기어 50%% 부근 (실측 %.3f)" % elite_precision_rate)
	var elite_seal_rate := float(elite_seal_count) / float(elite_samples)
	assert(elite_seal_rate >= 0.03 and elite_seal_rate <= 0.075, "엘리트 인장 5%% 부근 (실측 %.3f)" % elite_seal_rate)
	# 보스 확정: 조각 2 + 군용 합금 1~2 + 인장 1.
	for boss_stage in [1, 3, 5]:
		var boss_drops: Array = LOOT_ECONOMY.roll_boss_drops(boss_stage, random)
		var boss_totals := {"weapon": 0, "armor": 0, "shard": 0, "precision": 0, "alloy": 0, "seal": 0}
		for entry in boss_drops:
			LOOT_ECONOMY._merge_gear_tally(boss_totals, LOOT_ECONOMY._classify_gear_drop(entry as Dictionary))
		assert(int(boss_totals["weapon"]) + int(boss_totals["armor"]) == 0, "존%d 보스 장비 0" % boss_stage)
		assert(int(boss_totals["shard"]) == 2, "존%d 보스 조각 2 (got %d)" % [boss_stage, int(boss_totals["shard"])])
		assert(int(boss_totals["alloy"]) >= 1 and int(boss_totals["alloy"]) <= 2, "존%d 보스 군용 합금 1~2" % boss_stage)
		assert(int(boss_totals["seal"]) == 1, "존%d 보스 인장 1" % boss_stage)

	# 판 단위 공급 밴드 — 존1·3·5 × 25킬 × 200판(엘리트·보스·봉인 상자 포함). 장비 0,
	# 조각은 판당 2개 이상(존1 T1 세트 9 + 권총·기관단총 6 = 15조각이 5~6판 안에), 인장 ≥1(보스).
	for supply_stage in [1, 3, 5]:
		var supply: Dictionary = LOOT_ECONOMY.simulate_gear_supply(supply_stage, 25, 200, 4242 + supply_stage, true)
		print("GEAR_SUPPLY_STAGE_%d %s" % [supply_stage, supply])
		assert(is_zero_approx(float(supply.get("weapons_per_run", 1.0))), "존%d 판당 무기 0" % supply_stage)
		assert(is_zero_approx(float(supply.get("armor_per_run", 1.0))), "존%d 판당 방어구 0" % supply_stage)
		assert(float(supply.get("shards_per_run", 0.0)) >= 2.0, "존%d 판당 조각 ≥2 (실측 %.2f)" % [supply_stage, float(supply.get("shards_per_run", 0.0))])
		assert(float(supply.get("artisan_seals_per_run", 0.0)) >= 1.0, "존%d 보스 인장 확정" % supply_stage)
		assert(float(supply.get("precision_gear_per_run", 0.0)) > 0.3, "존%d 정밀 기어 공급" % supply_stage)
		assert(float(supply.get("empty_kill_rate", 1.0)) <= 0.40, "존%d 빈 킬 ≤40%% (실측 %.2f)" % [supply_stage, float(supply.get("empty_kill_rate", 1.0))])

	# try_register_loot은 장비 정의를 출처 불문 거절한다(캡이 아니라 규칙).
	var game_state := root.get_node("GameState")
	game_state.call("reset_raid_supply_counters")
	var weapon_definition: Dictionary = LOOT_ECONOMY._materialize_item("mp5", 1, random)
	var armor_definition: Dictionary = LOOT_ECONOMY._materialize_item("scav_vest", 1, random)
	assert(not LOOT_ECONOMY.try_register_loot(game_state, weapon_definition, "field", 1))
	assert(not LOOT_ECONOMY.try_register_loot(game_state, weapon_definition, "enemy", 1, true))
	assert(not LOOT_ECONOMY.try_register_loot(game_state, armor_definition, "enemy", 1, true))
	assert(int(game_state.get("raid_weapon_drops_generated")) == 0)
	assert(int(game_state.get("raid_enemy_weapon_drops_generated")) == 0)
	var shard_definition: Dictionary = LOOT_ECONOMY.materialize_blueprint_shard(1, random)
	assert(str(shard_definition.get("type", "")) == "progression_item")
	assert(LOOT_ECONOMY.try_register_loot(game_state, shard_definition, "enemy", 1), "조각은 정상 등록")

	print(
		"LOOT_ECONOMY_OK stage1 weapons=%.2f ammo=%.1f common=%.1f value=%.0f shards=%.2f any=%.3f common_rate=%.3f shard_rate=%.3f"
		% [
			float(stage_one_supply.get("average_weapons", 0.0)),
			float(stage_one_supply.get("average_ammo", 0.0)),
			float(stage_one_supply.get("average_common_supply", 0.0)),
			float(stage_one_supply.get("average_value", 0.0)),
			float(stage_one_supply.get("average_blueprint_shards", 0.0)),
			any_enemy_drop_rate,
			common_enemy_drop_rate,
			shard_enemy_drop_rate,
		]
	)
	quit(0)


func _container_count(profile: Dictionary) -> int:
	var count := 0
	for value in (profile.get("container_counts", {}) as Dictionary).values():
		count += int(value)
	return count
