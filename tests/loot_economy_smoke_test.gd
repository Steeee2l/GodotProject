extends SceneTree

const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage_one_profile := LOOT_ECONOMY.get_stage_profile(1)
	var stage_four_profile := LOOT_ECONOMY.get_stage_profile(4)
	assert(_container_count(stage_one_profile) == 51)
	assert(_container_count(stage_four_profile) == 79)
	assert(int(stage_one_profile.get("weapon_rarity_cap", 0)) == 1)
	assert(int(stage_four_profile.get("weapon_rarity_cap", 0)) == 4)
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(1) == 20)
	assert(LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(4) == 26)

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
				assert(
					int(data.get("ammo_tier", 1))
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
			assert(ammo_amount >= 3 and ammo_amount <= 8)
	assert(melee_weapon_count == 0)
	var ranged_weapon_rate := float(ranged_weapon_count) / float(ranged_sample_count)
	assert(ranged_weapon_rate >= 0.065 and ranged_weapon_rate <= 0.095)
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

	var common_enemy_drop_count := 0
	var any_enemy_drop_count := 0
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
	var any_enemy_drop_rate := float(any_enemy_drop_count) / float(common_enemy_sample_count)
	var common_enemy_drop_rate := float(common_enemy_drop_count) / float(common_enemy_sample_count)
	assert(any_enemy_drop_rate >= 0.61 and any_enemy_drop_rate <= 0.67)
	assert(common_enemy_drop_rate >= 0.36 and common_enemy_drop_rate <= 0.44)

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
