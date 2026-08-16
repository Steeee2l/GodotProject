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
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(1) == 21)
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(4) == 27)

	var stage_one_supply := LOOT_ECONOMY.simulate_stage_supply(1, 600, 1103)
	var stage_four_supply := LOOT_ECONOMY.simulate_stage_supply(4, 600, 2207)
	print("LOOT_SUPPLY_STAGE_1 ", stage_one_supply)
	print("LOOT_SUPPLY_STAGE_4 ", stage_four_supply)
	assert(float(stage_one_supply.get("average_weapons", 99.0)) < 0.45)
	assert(float(stage_one_supply.get("average_ammo", 0.0)) >= 40.0)
	assert(float(stage_one_supply.get("average_ammo", 999.0)) <= 65.0)
	assert(float(stage_one_supply.get("average_canned_food", 0.0)) >= 28.0)
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
	# stage 4 표본: 0.15 + 3x0.03 = 0.24 기대.
	# "적을 죽여도 무기가 안 나온다"는 유저 신고로 드랍률을 1.5배 올렸다
	# (0.10+0.02/스테이지 → 0.15+0.03/스테이지). 무기 드랍은 동반 탄약까지
	# 끌고 오므로 탄약 제작 폐지분을 메우는 축이기도 하다.
	assert(ranged_weapon_rate >= 0.21 and ranged_weapon_rate <= 0.27)
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
	# 스마트 탄약 도입으로 적 드랍에서 식량 비중이 소폭 내려가고(탄약이 그만큼
	# 차지) 방어구 판정은 그대로다. 창은 표본 요동(±1%p)까지 감안해 잡는다.
	# 무기 드랍률 상향(0.10→0.15)만큼 무기가 앞단에서 더 빠져나가므로 방어구·
	# 식량 비중은 각각 1%p 남짓 내려간다 — 기존 창 안에 그대로 들어온다.
	assert(any_enemy_drop_rate >= 0.71 and any_enemy_drop_rate <= 0.79)
	# 무기 드랍이 앞단에서 5%p 더 빠져나가면서 실측이 0.24 → 0.21로 내려왔다.
	# 하한을 0.19로 열어 표본 요동에 바닥이 닿지 않게 한다.
	assert(common_enemy_drop_rate >= 0.19 and common_enemy_drop_rate <= 0.30)
	assert(armor_enemy_drop_rate >= 0.20 and armor_enemy_drop_rate <= 0.28)

	# 처치 보장 드랍(2026-08 유저 요구: 모든 킬 = 무기 or 방어구 최소 1개).
	# roll_enemy_drop의 기존 분포는 그대로 두고(위 어서션 유지), 무기·방어구가
	# 안 나온 킬에 enemy_director가 이 fallback을 별도 픽업으로 얹는다.
	# fallback 자체는 항상 장비를 내놓아야 하고, 무기 비율은 55% 부근이어야 한다.
	# 40%에서 올렸다: 방어구는 이미 남아도는데 무기가 안 나온다는 신고가 이어져
	# fallback의 무게추를 무기 쪽으로 옮겼다.
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
	assert(guaranteed_weapon_rate >= 0.49 and guaranteed_weapon_rate <= 0.61)
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
	assert(registered_weapon_count <= 1)

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
