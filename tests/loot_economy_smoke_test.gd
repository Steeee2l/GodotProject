extends SceneTree

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
	# 쉘터 연료 싱크가 사라져(통조림 = 플레이어 소모품) 확정 통조림 픽업을 약 60%로
	# 줄였다: 21/27 → 12/16.
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(1) == 12)
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(4) == 16)

	var stage_one_supply := LOOT_ECONOMY.simulate_stage_supply(1, 600, 1103)
	var stage_four_supply := LOOT_ECONOMY.simulate_stage_supply(4, 600, 2207)
	print("LOOT_SUPPLY_STAGE_1 ", stage_one_supply)
	print("LOOT_SUPPLY_STAGE_4 ", stage_four_supply)
	assert(float(stage_one_supply.get("average_weapons", 99.0)) < 0.45)
	assert(float(stage_one_supply.get("average_ammo", 0.0)) >= 40.0)
	assert(float(stage_one_supply.get("average_ammo", 999.0)) <= 65.0)
	# 확정 픽업 축소(21→12) 뒤 실측 평균 28.1(컨테이너 드랍 포함) — 기대값을 24로 내려
	# 난수 여유를 둔다. 연료 싱크가 없으니 "많이"가 아니라 "먹고 던질 만큼"이 목표다.
	assert(float(stage_one_supply.get("average_canned_food", 0.0)) >= 24.0)
	assert(float(stage_one_supply.get("average_components", 0.0)) >= 10.0)
	assert(float(stage_one_supply.get("average_common_supply", 0.0)) >= 20.0)
	assert(float(stage_one_supply.get("common_supply_success_rate", 0.0)) >= 0.95)
	assert(
		float(stage_four_supply.get("average_weapons", 0.0))
		> float(stage_one_supply.get("average_weapons", 0.0)) * 4.0
	)
	assert(is_zero_approx(float(stage_one_supply.get("average_high_tier_ammo", 1.0))))
	assert(float(stage_four_supply.get("average_high_tier_ammo", 0.0)) > 0.0)

	var random := RandomNumberGenerator.new()
	random.seed = 778899
	var secure_high_tier_ammo_found := false
	var secure_progression_item_found := false
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
				if str(definition.get("type", "")) == "ammo":
					assert(stage_tier >= 3)
					if int(data.get("ammo_tier", 1)) >= 3:
						secure_high_tier_ammo_found = true
				elif str(definition.get("type", "")) == "progression_item":
					assert(stage_tier >= 3)
					secure_progression_item_found = true
			for definition in LOOT_ECONOMY.roll_container(
				"weapon_case",
				stage_tier,
				"street_mixed",
				random
			):
				if str(definition.get("type", "")) != "weapon":
					continue
				var data := definition.get("data", {}) as Dictionary
				assert(
					int(data.get("rarity_tier", 1))
					<= int(profile.get("weapon_rarity_cap", 1))
				)
	assert(secure_high_tier_ammo_found)
	assert(secure_progression_item_found)

	var loose_weapon_count := 0
	for sample_index in 600:
		var loose := LOOT_ECONOMY.roll_loose_loot(
			1,
			"street_mixed",
			random
		)
		if str(loose.get("type", "")) == "weapon":
			loose_weapon_count += 1
		assert(sample_index >= 0)
	assert(loose_weapon_count == 0)

	var melee_weapon_count := 0
	var ranged_weapon_count := 0
	var ranged_sample_count := 5000
	for _sample in ranged_sample_count:
		var melee_drop := LOOT_ECONOMY.roll_enemy_drop(
			4,
			"melee",
			"baseball_bat",
			random
		)
		if str(melee_drop.get("type", "")) == "weapon":
			melee_weapon_count += 1
		var ranged_drop := LOOT_ECONOMY.roll_enemy_drop(
			4,
			"ranged",
			"ak47",
			random
		)
		if str(ranged_drop.get("type", "")) == "weapon":
			ranged_weapon_count += 1
		if str(ranged_drop.get("type", "")) == "ammo":
			var ammo_amount := int((ranged_drop.get("data", {}) as Dictionary).get("amount", 0))
			# 스마트 탄약: 장착 구경 매칭 드랍은 정상 스택(최대 12발)까지 나온다.
			assert(ammo_amount >= 2 and ammo_amount <= 12)
	assert(melee_weapon_count == 0)
	var ranged_weapon_rate := float(ranged_weapon_count) / float(ranged_sample_count)
	# 2026-08 장비 드랍 재설계: 든 총 10% 고정(존 티어 무관, ENEMY_CARRIED_WEAPON_DROP_CHANCE).
	# 예전 0.15+0.03/스테이지(stage 4 = 0.24)는 "매 킬 장비 보장 fallback"과 함께
	# 25킬 판에 장비 ~25개를 만들었다. 무기는 귀환 정산에서 사다리 중복만 분해된다.
	assert(ranged_weapon_rate >= 0.08 and ranged_weapon_rate <= 0.12, "든 총 드랍률 10%% 부근 (실측 %.3f)" % ranged_weapon_rate)
	var recovery_weapon_count := 0
	var recovery_sample_count := 2000
	for _sample in recovery_sample_count:
		var recovery_drop := LOOT_ECONOMY.roll_enemy_drop(
			1,
			"ranged",
			"m1911",
			random,
			true
		)
		if str(recovery_drop.get("type", "")) == "weapon":
			recovery_weapon_count += 1
	var recovery_weapon_rate := float(recovery_weapon_count) / float(recovery_sample_count)
	assert(recovery_weapon_rate >= 0.54 and recovery_weapon_rate <= 0.62)

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
	assert(matched_rate >= 0.55, "장착 구경 매칭 탄약이 다수여야 한다 (실측 %.2f)" % matched_rate)

	# 호환탄 회수량 상향: (4~7)+스테이지 → 6~(10+min(스테이지,3)).
	# 제작대의 탄약 레시피가 폐지돼 필드 회수가 사실상 유일한 보급선이 됐다.
	# 킬당 회수가 탄창 하나에도 못 미쳐 "쏠수록 가난해진다"는 신고를 받았다.
	# 상한이 3스테이지에서 멈추는 건 후반 수급선(고티어 탄·무기 동반 탄약)이
	# 이미 두꺼워서다 — 실측 킬당 4.2~5.9발(목표 4~6발).
	for recovery_stage in range(1, 6):
		var recovery_total := 0
		var recovery_cap := 10 + mini(recovery_stage, 3)
		for _sample in 2000:
			var recovery := LOOT_ECONOMY.roll_matched_ammo_recovery(recovery_stage, random)
			var recovery_amount := int((recovery.get("data", {}) as Dictionary).get("amount", 0))
			assert(recovery_amount >= 6 and recovery_amount <= recovery_cap)
			recovery_total += recovery_amount
		var recovery_average := float(recovery_total) / 2000.0
		# 기대 평균 = (6 + 상한) / 2.
		var expected_average := (6.0 + float(recovery_cap)) * 0.5
		assert(absf(recovery_average - expected_average) <= 0.4)

	# 스마트 탄약 치환률: 일반 상자 55% → 75%. 상자에서 나온 탄의 절반이 못 쓰는
	# 구경이면 "주웠는데 못 쏜다"만 반복돼 가방 압박만 커진다(유저 신고).
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

	var common_enemy_drop_count := 0
	var any_enemy_drop_count := 0
	var armor_enemy_drop_count := 0
	var common_enemy_sample_count := 5000
	for _sample in common_enemy_sample_count:
		var common_drop := LOOT_ECONOMY.roll_enemy_drop(
			1,
			"ranged",
			"m1911",
			random
		)
		if common_drop.is_empty():
			continue
		any_enemy_drop_count += 1
		if str(common_drop.get("type", "")) in ["canned_food", "mod_component"]:
			common_enemy_drop_count += 1
		if str(common_drop.get("type", "")) == "armor":
			armor_enemy_drop_count += 1
	var any_enemy_drop_rate := float(any_enemy_drop_count) / float(common_enemy_sample_count)
	var common_enemy_drop_rate := float(common_enemy_drop_count) / float(common_enemy_sample_count)
	var armor_enemy_drop_rate := float(armor_enemy_drop_count) / float(common_enemy_sample_count)
	# 방어구 드랍을 파밍 루프의 심장으로 끌어올렸다. 처치할 때마다 갈아 끼울
	# 기회가 규칙적으로 돌아오도록 전용 판정을 둔 결과, 전체 드랍률과 방어구
	# 비중이 함께 올라간다.
	print("ENEMY_DROP_RATES any=%.3f common=%.3f armor=%.3f" % [
		any_enemy_drop_rate, common_enemy_drop_rate, armor_enemy_drop_rate,
	])
	# 2026-08 장비 드랍 재설계: 일반 적 = 입고 있던 방어구 12% / 든 총 10% / 그 외
	# 기존 탄약·식량·부품 분포(ordinary 62%). 기대값(stage 1): any = 0.22 + 0.78×0.62
	# = 0.70, common(식량+부품) = 0.78×0.62×0.66 = 0.32, 방어구 = 0.12.
	# 예전 창(any 0.71~0.79 · armor 0.20~0.28)은 "매 킬 장비 보장"과 함께 25킬 판에
	# 방어구 ~20개를 만들던 수치다. 표본 요동(±1.5%p)을 감안해 창을 잡는다.
	assert(any_enemy_drop_rate >= 0.67 and any_enemy_drop_rate <= 0.74, "any 0.70 부근 (실측 %.3f)" % any_enemy_drop_rate)
	assert(common_enemy_drop_rate >= 0.28 and common_enemy_drop_rate <= 0.36, "common 0.32 부근 (실측 %.3f)" % common_enemy_drop_rate)
	assert(armor_enemy_drop_rate >= 0.10 and armor_enemy_drop_rate <= 0.14, "입고 있던 방어구 12%% 부근 (실측 %.3f)" % armor_enemy_drop_rate)
	# 근접 적은 방어구 12%만 — 무기 0(위 melee_weapon_count), 방어구는 같은 12%.
	var melee_armor_count := 0
	for _sample in 5000:
		if str(LOOT_ECONOMY.roll_enemy_drop(1, "melee", "baseball_bat", random).get("type", "")) == "armor":
			melee_armor_count += 1
	var melee_armor_rate := float(melee_armor_count) / 5000.0
	assert(melee_armor_rate >= 0.10 and melee_armor_rate <= 0.14, "근접 적 방어구 12%% 부근 (실측 %.3f)" % melee_armor_rate)

	# 장비 공급 밴드 — 존1·3·5 × 25킬 × 200판(엘리트 1~2·옷 상자·봉인 보급함 포함).
	# 목표: 판당 일반 적 방어구 3~4개 부근, 같은 존 2회차 안에 그 존 세트 3종 ≥70%.
	# 재설계 전 실측: 판당 방어구 21.7/22.6/23.9(존1/3/5) — 슬롯 3개에 20벌.
	for supply_stage in [1, 3, 5]:
		var supply: Dictionary = LOOT_ECONOMY.simulate_enemy_equipment_supply(supply_stage, 25, 200, 4242 + supply_stage, true)
		print("EQUIPMENT_SUPPLY_STAGE_%d %s" % [supply_stage, supply])
		var enemy_armor := float(supply.get("armor_from_enemies_per_run", 0.0)) + float(supply.get("elite_armor_per_run", 0.0))
		assert(enemy_armor >= 2.5 and enemy_armor <= 4.5, "존%d 판당 적 방어구 3~4 부근 (실측 %.2f)" % [supply_stage, enemy_armor])
		assert(float(supply.get("armor_per_run", 0.0)) <= 12.0, "존%d 상자 포함 방어구 과잉 아님 (실측 %.2f)" % [supply_stage, float(supply.get("armor_per_run", 0.0))])
		assert(float(supply.get("set_complete_2runs", 0.0)) >= 0.70, "존%d 2판 세트 완성 ≥70%% (실측 %.3f)" % [supply_stage, float(supply.get("set_complete_2runs", 0.0))])
		assert(float(supply.get("weapons_per_run", 0.0)) >= 2.0 and float(supply.get("weapons_per_run", 0.0)) <= 5.0, "존%d 판당 무기 2~5 (실측 %.2f)" % [supply_stage, float(supply.get("weapons_per_run", 0.0))])
		if supply_stage < 5:
			# 엘리트·보스의 추가 방어구는 한 단계 위 가족(존 가족+1). 최상위 존(T3)은 같은 가족.
			assert(is_equal_approx(float(supply.get("elite_tier_up_share", 0.0)), 1.0), "존%d 엘리트 방어구는 상위 가족" % supply_stage)
			assert(is_equal_approx(float(supply.get("boss_tier_up_share", 0.0)), 1.0), "존%d 보스 방어구는 상위 가족" % supply_stage)
	# 엘리트 추가 방어구 확률 30% · 보스 확정 상위 가족.
	var elite_armor_count := 0
	for _sample in 2000:
		for entry in LOOT_ECONOMY.roll_elite_drop(1, "mp5", random):
			if str((entry as Dictionary).get("type", "")) == "armor":
				elite_armor_count += 1
				var elite_armor_id := str(((entry as Dictionary).get("data", {}) as Dictionary).get("equipment_id", "")).split("@")[0]
				assert(["riot_vest", "tactical_helmet", "tactical_boots"].has(elite_armor_id), "존1 엘리트 방어구는 T2 (got %s)" % elite_armor_id)
	var elite_armor_rate := float(elite_armor_count) / 2000.0
	assert(elite_armor_rate >= 0.26 and elite_armor_rate <= 0.34, "엘리트 상위 방어구 30%% 부근 (실측 %.3f)" % elite_armor_rate)
	for boss_stage in [1, 3, 5]:
		var boss_armor: Dictionary = LOOT_ECONOMY.roll_boss_armor_drop(boss_stage, random)
		assert(str(boss_armor.get("type", "")) == "armor", "보스 확정 방어구")
		var boss_family := mini(LOOT_ECONOMY.armor_family_index_for_stage(boss_stage) + 1, 2)
		var boss_armor_id := str((boss_armor.get("data", {}) as Dictionary).get("equipment_id", "")).split("@")[0]
		assert((LOOT_ECONOMY.ARMOR_FAMILIES[boss_family] as Array).has(boss_armor_id), "존%d 보스 방어구는 상위 가족(상한 T3) (got %s)" % [boss_stage, boss_armor_id])

	# roll_guaranteed_equipment_drop — "확정 장비 1개" 굴림(무기 22%/방어구 78%).
	# 2026-08 장비 드랍 재설계로 enemy_director의 매 킬 fallback에서는 뺐다(모든 킬 =
	# 장비 1개가 25킬 판에 방어구 ~20개를 만든 진범). 함수는 유틸로 남았으니 분포만
	# 그대로 지킨다 — 아래 어서션은 "fallback이 매 킬 얹힌다"를 뜻하지 않는다.
	var guaranteed_weapon_count := 0
	var guaranteed_sample_count := 2000
	for _sample in guaranteed_sample_count:
		var guaranteed := LOOT_ECONOMY.roll_guaranteed_equipment_drop(
			4, "ranged", "ak47", random
		)
		assert(str(guaranteed.get("type", "")) in ["weapon", "armor"])
		if str(guaranteed.get("type", "")) == "weapon":
			guaranteed_weapon_count += 1
	var guaranteed_weapon_rate := (
		float(guaranteed_weapon_count) / float(guaranteed_sample_count)
	)
	assert(guaranteed_weapon_rate >= 0.17 and guaranteed_weapon_rate <= 0.27)
	# 적이 들고 있던 총은 존 등급과 무관하게 떨어져야 한다 — 1스테이지
	# (weapon_rarity_cap 1, minimum_stage 게이트)에서도 MP5·AK·산탄총이
	# fallback으로 나와야 한다. 예전엔 여기서 전부 방어구로 치환됐다.
	for high_tier_weapon_id in ["mp5", "ak47", "double_barrel"]:
		var carried_weapon_seen := false
		for _sample in 400:
			var carried := LOOT_ECONOMY.roll_guaranteed_equipment_drop(
				1, "ranged", high_tier_weapon_id, random
			)
			if str(carried.get("type", "")) == "weapon":
				assert(str((carried.get("data", {}) as Dictionary).get("weapon_id", "")) == high_tier_weapon_id)
				carried_weapon_seen = true
				break
		assert(carried_weapon_seen, "1스테이지에서도 적이 든 %s는 떨어져야 한다" % high_tier_weapon_id)
	# 그 총의 동반 탄약도 ammo_tier_cap을 타지 않아야 한다 — 1스테이지
	# (cap 1)에서 AK가 떨어지면 7.62(tier 2)가 막혀 "탄 없는 총"만 남았다.
	var low_stage_companion := LOOT_ECONOMY.roll_weapon_companion_ammo("ak47", 1, random)
	assert(str(low_stage_companion.get("type", "")) == "ammo")
	assert(str((low_stage_companion.get("data", {}) as Dictionary).get("ammo_id", "")).begins_with("762"))
	# 근접(배트) 적은 무기 fallback이 성립하지 않으니 방어구 확정이어야 한다.
	for _sample in 200:
		var melee_guaranteed := LOOT_ECONOMY.roll_guaranteed_equipment_drop(
			1, "melee", "baseball_bat", random
		)
		assert(str(melee_guaranteed.get("type", "")) == "armor")
	# 총 드랍 동반 탄약(2026-08 유저 요구): 떨어진 총 구경의 탄이 정상 스택으로 나온다.
	var companion := LOOT_ECONOMY.roll_weapon_companion_ammo("ak47", 2, random)
	assert(str(companion.get("type", "")) == "ammo")
	assert(str((companion.get("data", {}) as Dictionary).get("ammo_id", "")).begins_with("762"))
	assert(int((companion.get("data", {}) as Dictionary).get("amount", 0)) >= 2)

	var game_state := root.get_node("GameState")
	game_state.call("reset_raid_supply_counters")
	var weapon_definition := LOOT_ECONOMY.roll_container(
		"weapon_case",
		1,
		"street_mixed",
		_seeded_random(7)
	)
	var registered_weapon_count := 0
	for definition in weapon_definition:
		if (
			str(definition.get("type", "")) == "weapon"
			and LOOT_ECONOMY.try_register_loot(game_state, definition, "field", 1)
		):
			registered_weapon_count += 1
	# 필드 컨테이너 무기 캡(weapon_spawn_cap, 1스테이지 4)은 적 드랍 캡과
	# 분리됐다 — 예전엔 카운터를 공유해서 무기 상자 몇 개만 열어도 그 판의
	# 적 무기 드랍이 통째로 막혔다.
	assert(registered_weapon_count <= 4)
	assert(int(game_state.get("raid_enemy_weapon_drops_generated")) == 0)

	print(
		"LOOT_ECONOMY_OK stage1 weapons=%.2f ammo=%.1f common=%.1f value=%.0f stage4 weapons=%.2f enemy_weapon_rate=%.3f common_enemy_rate=%.3f recovery_rate=%.3f"
		% [
			float(stage_one_supply.get("average_weapons", 0.0)),
			float(stage_one_supply.get("average_ammo", 0.0)),
			float(stage_one_supply.get("average_common_supply", 0.0)),
			float(stage_one_supply.get("average_value", 0.0)),
			float(stage_four_supply.get("average_weapons", 0.0)),
			ranged_weapon_rate,
			common_enemy_drop_rate,
			recovery_weapon_rate,
		]
	)
	quit(0)


func _container_count(profile: Dictionary) -> int:
	var count := 0
	for value in (profile.get("container_counts", {}) as Dictionary).values():
		count += int(value)
	return count


func _seeded_random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random
