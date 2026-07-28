class_name LootEconomy
extends RefCounted

const STAGE_PROFILES := {
	1: {
		"name": "초반 생존 구역",
		"weapon_rarity_cap": 1,
		"ammo_tier_cap": 1,
		"field_value_cap": 2600,
		"enemy_value_cap": 1200,
		"total_value_cap": 3800,
		"weapon_spawn_cap": 1,
		"enemy_drop_cap": 18,
		"raid_kill_cap": 40,
		"weapon_case_chance": 0.16,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 4,
			"toolbox": 6,
			"clothing_cache": 4,
			"weapon_case": 1,
		},
	},
	2: {
		"name": "중간 파밍 구역",
		"weapon_rarity_cap": 2,
		"ammo_tier_cap": 2,
		"field_value_cap": 3800,
		"enemy_value_cap": 1800,
		"total_value_cap": 5600,
		"weapon_spawn_cap": 2,
		"enemy_drop_cap": 22,
		"raid_kill_cap": 55,
		"weapon_case_chance": 0.24,
		"container_counts": {
			"street_cache": 15,
			"ammo_case": 5,
			"toolbox": 7,
			"clothing_cache": 5,
			"weapon_case": 2,
			"secure_cache": 1,
		},
	},
	3: {
		"name": "고위험 파밍 구역",
		"weapon_rarity_cap": 3,
		"ammo_tier_cap": 3,
		"field_value_cap": 6000,
		"enemy_value_cap": 2800,
		"total_value_cap": 8800,
		"weapon_spawn_cap": 3,
		"enemy_drop_cap": 28,
		"raid_kill_cap": 70,
		"weapon_case_chance": 0.34,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 7,
			"toolbox": 8,
			"clothing_cache": 5,
			"weapon_case": 3,
			"secure_cache": 4,
		},
	},
	4: {
		"name": "봉인 고위험 구역",
		"weapon_rarity_cap": 4,
		"ammo_tier_cap": 4,
		"field_value_cap": 9000,
		"enemy_value_cap": 4200,
		"total_value_cap": 13200,
		"weapon_spawn_cap": 5,
		"enemy_drop_cap": 34,
		"raid_kill_cap": 85,
		"weapon_case_chance": 0.42,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 8,
			"toolbox": 9,
			"clothing_cache": 6,
			"weapon_case": 5,
			"secure_cache": 5,
		},
	},
}

const CONTAINER_DEFINITIONS := {
	"street_cache": {
		"display_name": "버려진 보급 가방",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.22,
		"entries": [
			["canned_food", 46.0],
			["medkit", 15.0],
			["rubber_gasket", 13.0],
			["scope_lens", 10.0],
			["magazine_spring", 16.0],
		],
	},
	"ammo_case": {
		"display_name": "탄약 상자",
		"roll_min": 2,
		"roll_max": 3,
		"empty_chance": 0.15,
		"entries": [
			["ammo_9mm_fmj", 27.0],
			["ammo_45_fmj", 23.0],
			["ammo_12g_buckshot", 18.0],
			["ammo_762_fmj", 20.0],
		],
	},
	"toolbox": {
		"display_name": "폐공구함",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.12,
		"entries": [
			["rubber_gasket", 34.0],
			["scope_lens", 25.0],
			["magazine_spring", 31.0],
			["medkit", 10.0],
		],
	},
	"clothing_cache": {
		"display_name": "버려진 의류 더미",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.24,
		"entries": [
			["canned_food", 38.0],
			["medkit", 18.0],
			["scav_vest", 15.0],
			["patched_helmet", 12.0],
			["patched_sneakers", 17.0],
			["riot_vest", 4.0],
			["tactical_helmet", 3.0],
			["tactical_boots", 4.0],
		],
	},
	"weapon_case": {
		"display_name": "잠긴 무기 상자",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.22,
		"entries": [
			["magazine_spring", 38.0],
			["scope_lens", 24.0],
			["ammo_9mm_fmj", 16.0],
			["ammo_45_fmj", 12.0],
			["ammo_762_fmj", 10.0],
		],
	},
	"secure_cache": {
		"display_name": "봉인 보급함",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.32,
		"minimum_stage": 3,
		"entries": [
			["scope_lens", 18.0],
			["magazine_spring", 16.0],
			["ammo_9mm_ap", 13.0],
			["ammo_45_ap", 13.0],
			["ammo_12g_slug", 13.0],
			["ammo_762_ap", 9.0],
			["riot_vest", 7.0],
			["tactical_helmet", 6.0],
			["tactical_boots", 5.0],
			["rifle_blueprint", 3.2],
			["shotgun_blueprint", 3.2],
			["sealed_zone_keycard", 1.4],
		],
	},
}

const ITEM_CATALOG := {
	"canned_food": {
		"loot_type": "canned_food",
		"display_name": "통조림",
		"base_value": 35,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"medkit": {
		"loot_type": "medkit",
		"display_name": "구급약",
		"base_value": 120,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"rubber_gasket": {
		"loot_type": "mod_component",
		"component_id": "rubber_gasket",
		"display_name": "소음기용 고무 패킹",
		"base_value": 85,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"scope_lens": {
		"loot_type": "mod_component",
		"component_id": "scope_lens",
		"display_name": "스코프 렌즈",
		"base_value": 110,
		"slot_size": 1,
		"rarity_tier": 2,
		"minimum_stage": 1,
	},
	"magazine_spring": {
		"loot_type": "mod_component",
		"component_id": "magazine_spring",
		"display_name": "탄창 스프링",
		"base_value": 95,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"rifle_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "rifle_blueprint",
		"display_name": "소총 제작 청사진",
		"base_value": 1800,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"shotgun_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "shotgun_blueprint",
		"display_name": "산탄총 제작 청사진",
		"base_value": 1600,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"sealed_zone_keycard": {
		"loot_type": "progression_item",
		"progression_item_id": "sealed_zone_keycard",
		"display_name": "봉인구역 키카드",
		"base_value": 3200,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 3,
	},
	"m1911": {
		"loot_type": "weapon",
		"weapon_id": "m1911",
		"display_name": "M1911",
		"base_value": 480,
		"slot_size": 6,
		"rarity_tier": 1,
		"minimum_stage": 1,
		"weight": 12.0,
	},
	"mp5": {
		"loot_type": "weapon",
		"weapon_id": "mp5",
		"display_name": "MP5",
		"base_value": 1200,
		"slot_size": 8,
		"rarity_tier": 2,
		"minimum_stage": 2,
		"weight": 7.0,
	},
	"double_barrel": {
		"loot_type": "weapon",
		"weapon_id": "double_barrel",
		"display_name": "더블배럴 산탄총",
		"base_value": 1050,
		"slot_size": 8,
		"rarity_tier": 2,
		"minimum_stage": 2,
		"weight": 6.0,
	},
	"ak47": {
		"loot_type": "weapon",
		"weapon_id": "ak47",
		"display_name": "AK-47",
		"base_value": 2400,
		"slot_size": 10,
		"rarity_tier": 3,
		"minimum_stage": 3,
		"weight": 3.0,
	},
	"ammo_9mm_fmj": {
		"loot_type": "ammo",
		"ammo_id": "9mm_fmj",
		"display_name": "9mm 보통탄",
		"base_value": 3,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_45_fmj": {
		"loot_type": "ammo",
		"ammo_id": "45_fmj",
		"display_name": ".45 ACP 보통탄",
		"base_value": 4,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_12g_buckshot": {
		"loot_type": "ammo",
		"ammo_id": "12g_buckshot",
		"display_name": "12게이지 벅샷",
		"base_value": 7,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_762_fmj": {
		"loot_type": "ammo",
		"ammo_id": "762_fmj",
		"display_name": "7.62mm 보통탄",
		"base_value": 6,
		"slot_size": 1,
		"ammo_tier": 2,
		"rarity_tier": 2,
		"minimum_stage": 2,
	},
	"ammo_9mm_ap": {
		"loot_type": "ammo",
		"ammo_id": "9mm_ap",
		"display_name": "9mm AP탄",
		"base_value": 14,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_45_ap": {
		"loot_type": "ammo",
		"ammo_id": "45_ap",
		"display_name": ".45 ACP 철갑탄",
		"base_value": 16,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_12g_slug": {
		"loot_type": "ammo",
		"ammo_id": "12g_slug",
		"display_name": "12게이지 슬러그",
		"base_value": 18,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_762_ap": {
		"loot_type": "ammo",
		"ammo_id": "762_ap",
		"display_name": "7.62mm AP탄",
		"base_value": 24,
		"slot_size": 1,
		"ammo_tier": 4,
		"rarity_tier": 4,
		"minimum_stage": 4,
	},
	"scav_vest": {
		"loot_type": "armor",
		"equipment_id": "scav_vest",
		"display_name": "누더기 방탄 조끼",
		"base_value": 260,
		"slot_size": 4,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"patched_helmet": {
		"loot_type": "armor",
		"equipment_id": "patched_helmet",
		"display_name": "덧댄 철판 헬멧",
		"base_value": 220,
		"slot_size": 3,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"patched_sneakers": {
		"loot_type": "armor",
		"equipment_id": "patched_sneakers",
		"display_name": "누더기 운동화",
		"base_value": 180,
		"slot_size": 2,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"riot_vest": {
		"loot_type": "armor",
		"equipment_id": "riot_vest",
		"display_name": "진압 방탄 조끼",
		"base_value": 850,
		"slot_size": 5,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"tactical_helmet": {
		"loot_type": "armor",
		"equipment_id": "tactical_helmet",
		"display_name": "전술 헬멧",
		"base_value": 720,
		"slot_size": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"tactical_boots": {
		"loot_type": "armor",
		"equipment_id": "tactical_boots",
		"display_name": "전술 부츠",
		"base_value": 620,
		"slot_size": 2,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
}

const DISTRICT_BIASES := {
	"market_lane": {"canned_food": 1.8, "medkit": 1.15},
	"luxury_core": {
		"scav_vest": 1.5,
		"patched_helmet": 1.5,
		"riot_vest": 2.1,
		"tactical_helmet": 2.1,
	},
	"multi_family": {"canned_food": 1.45, "medkit": 1.25},
	"business_corner": {"scope_lens": 1.5, "magazine_spring": 1.35},
	"residential_buffer": {"canned_food": 1.5, "medkit": 1.35},
	"open_space_edge": {
		"rubber_gasket": 1.35,
		"scope_lens": 1.35,
		"magazine_spring": 1.35,
	},
}


static func get_stage_for_zone(zone_data: Dictionary) -> int:
	return clampi(
		int(zone_data.get("stage_tier", zone_data.get("required_tier", 1))),
		1,
		4
	)


static func get_stage_profile(stage_tier: int) -> Dictionary:
	return (STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary).duplicate(true)


static func get_container_display_name(container_type: String) -> String:
	var definition := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	return str(definition.get("display_name", "보급품"))


static func build_container_plan(stage_tier: int, random: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	var counts := profile.get("container_counts", {}) as Dictionary
	for container_type_value in counts.keys():
		var container_type := str(container_type_value)
		for _index in maxi(0, int(counts[container_type_value])):
			result.append(container_type)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var held := result[index]
		result[index] = result[swap_index]
		result[swap_index] = held
	return result


static func roll_container(
	container_type: String,
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> Array[Dictionary]:
	var stage := clampi(stage_tier, 1, 4)
	var container := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	if container.is_empty() or stage < int(container.get("minimum_stage", 1)):
		return []
	var profile := STAGE_PROFILES[stage] as Dictionary
	var results: Array[Dictionary] = []
	var roll_count := random.randi_range(
		int(container.get("roll_min", 1)),
		int(container.get("roll_max", 1))
	)
	if container_type == "weapon_case":
		if random.randf() <= float(profile.get("weapon_case_chance", 0.0)):
			var weapon_id := _roll_weapon_id(stage, random)
			if not weapon_id.is_empty():
				results.append(_materialize_item(weapon_id, stage, random))
				roll_count = maxi(0, roll_count - 1)
	for _roll_index in roll_count:
		if random.randf() < float(container.get("empty_chance", 0.0)):
			continue
		var item_id := _roll_weighted_item(
			container.get("entries", []) as Array,
			stage,
			district,
			random
		)
		if not item_id.is_empty():
			results.append(_materialize_item(item_id, stage, random))
	return results


static func roll_loose_loot(
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> Dictionary:
	var container_type := "street_cache"
	match district:
		"luxury_core":
			container_type = "clothing_cache"
		"business_corner", "open_space_edge":
			container_type = "toolbox"
	var results := roll_container(container_type, stage_tier, district, random)
	if results.is_empty():
		return _materialize_item("canned_food", stage_tier, random)
	return results[0]


static func roll_enemy_drop(
	stage_tier: int,
	enemy_kind: String,
	enemy_weapon_id: String,
	random: RandomNumberGenerator,
	unarmed_recovery: bool = false
) -> Dictionary:
	var stage := clampi(stage_tier, 1, 4)
	var weapon_drop_chance := (
		0.58
		if unarmed_recovery
		else get_enemy_weapon_drop_chance(stage)
	)
	if (
		enemy_kind != "melee"
		and enemy_weapon_id != "baseball_bat"
		and random.randf() < weapon_drop_chance
	):
		var weapon_definition := _find_weapon_definition(enemy_weapon_id)
		if not weapon_definition.is_empty() and _item_allowed(weapon_definition, stage):
			return _materialize_item(enemy_weapon_id, stage, random)
	var ordinary_drop_chance := 0.62 + float(stage - 1) * 0.03
	if random.randf() > ordinary_drop_chance:
		return {}
	var roll := random.randf()
	if enemy_kind != "melee":
		if roll < 0.20:
			var ammo_item_id := _enemy_ammo_item_id(enemy_weapon_id, stage, random)
			if not ammo_item_id.is_empty():
				return _materialize_item(ammo_item_id, stage, random, true)
		if roll < 0.52:
			return _materialize_item("canned_food", stage, random)
		if roll < 0.60:
			return _materialize_item("medkit", stage, random)
		if roll < 0.92:
			return _materialize_item(
				_roll_basic_component_id(stage, random),
				stage,
				random
			)
	elif roll < 0.45:
		return _materialize_item("canned_food", stage, random)
	elif roll < 0.55:
		return _materialize_item("medkit", stage, random)
	elif roll < 0.92:
		return _materialize_item(
			_roll_basic_component_id(stage, random),
			stage,
			random
		)
	var armor_pool := ["scav_vest", "patched_helmet", "patched_sneakers"]
	if stage >= 3 and random.randf() < 0.22:
		armor_pool = ["riot_vest", "tactical_helmet", "tactical_boots"]
	return _materialize_item(
		armor_pool[random.randi_range(0, armor_pool.size() - 1)],
		stage,
		random
	)


static func get_enemy_weapon_drop_chance(stage_tier: int) -> float:
	return 0.05 + float(clampi(stage_tier, 1, 4) - 1) * 0.01


static func get_definition_value(definition: Dictionary) -> int:
	var data := definition.get("data", {}) as Dictionary
	return maxi(
		0,
		int(data.get(
			"total_value",
			int(data.get("base_value", 0)) * maxi(1, int(data.get("amount", 1)))
		))
	)


static func try_register_loot(
	game_state: Node,
	definition: Dictionary,
	source: String,
	stage_tier: int,
	ignore_caps: bool = false
) -> bool:
	if definition.is_empty():
		return false
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	var value := get_definition_value(definition)
	var loot_type := str(definition.get("type", ""))
	if not ignore_caps:
		if (
			loot_type == "weapon"
			and int(game_state.get("raid_weapon_drops_generated"))
			>= int(profile.get("weapon_spawn_cap", 1))
		):
			return false
		if (
			source == "enemy"
			and int(game_state.get("raid_enemy_drops_generated"))
			>= int(profile.get("enemy_drop_cap", 1))
		):
			return false
		var source_value := int(game_state.get("raid_field_loot_value_generated"))
		var source_cap := int(profile.get("field_value_cap", 0))
		if source == "enemy":
			source_value = int(game_state.get("raid_enemy_loot_value_generated"))
			source_cap = int(profile.get("enemy_value_cap", 0))
		if source_value + value > source_cap:
			return false
		if (
			int(game_state.get("raid_total_loot_value_generated")) + value
			> int(profile.get("total_value_cap", 0))
		):
			return false
	game_state.set(
		"raid_total_loot_value_generated",
		int(game_state.get("raid_total_loot_value_generated")) + value
	)
	if source == "enemy":
		game_state.set(
			"raid_enemy_loot_value_generated",
			int(game_state.get("raid_enemy_loot_value_generated")) + value
		)
		game_state.set(
			"raid_enemy_drops_generated",
			int(game_state.get("raid_enemy_drops_generated")) + 1
		)
	else:
		game_state.set(
			"raid_field_loot_value_generated",
			int(game_state.get("raid_field_loot_value_generated")) + value
		)
	if loot_type == "weapon":
		game_state.set(
			"raid_weapon_drops_generated",
			int(game_state.get("raid_weapon_drops_generated")) + 1
		)
	return true


static func simulate_stage_supply(stage_tier: int, run_count: int, seed_value: int = 7331) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var total_weapons := 0
	var total_ammo := 0
	var total_value := 0
	var total_high_tier_ammo := 0
	var total_canned_food := 0
	var total_components := 0
	var runs_with_common_supply := 0
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	for _run_index in maxi(1, run_count):
		var run_value := 0
		var run_weapon_count := 0
		var run_common_supply := 0
		for container_type in build_container_plan(stage_tier, random):
			for definition in roll_container(container_type, stage_tier, "street_mixed", random):
				var value := get_definition_value(definition)
				if run_value + value > int(profile.get("field_value_cap", 0)):
					continue
				if (
					str(definition.get("type", "")) == "weapon"
					and run_weapon_count >= int(profile.get("weapon_spawn_cap", 1))
				):
					continue
				run_value += value
				var data := definition.get("data", {}) as Dictionary
				match str(definition.get("type", "")):
					"weapon":
						run_weapon_count += 1
						total_weapons += 1
					"ammo":
						total_ammo += int(data.get("amount", 0))
						if int(data.get("ammo_tier", 1)) >= 3:
							total_high_tier_ammo += int(data.get("amount", 0))
					"canned_food":
						var amount := int(data.get("amount", 1))
						total_canned_food += amount
						run_common_supply += amount
					"mod_component":
						var amount := int(data.get("amount", 1))
						total_components += amount
						run_common_supply += amount
		if run_common_supply >= 12:
			runs_with_common_supply += 1
		total_value += run_value
	var divisor := float(maxi(1, run_count))
	return {
		"average_weapons": float(total_weapons) / divisor,
		"average_ammo": float(total_ammo) / divisor,
		"average_value": float(total_value) / divisor,
		"average_high_tier_ammo": float(total_high_tier_ammo) / divisor,
		"average_canned_food": float(total_canned_food) / divisor,
		"average_components": float(total_components) / divisor,
		"average_common_supply": float(total_canned_food + total_components) / divisor,
		"common_supply_success_rate": float(runs_with_common_supply) / divisor,
	}


static func _roll_weapon_id(stage_tier: int, random: RandomNumberGenerator) -> String:
	var weighted: Array = []
	for item_id_value in ["m1911", "mp5", "double_barrel", "ak47"]:
		var item_id := str(item_id_value)
		var definition := ITEM_CATALOG[item_id] as Dictionary
		if _item_allowed(definition, stage_tier):
			weighted.append([item_id, float(definition.get("weight", 1.0))])
	return _weighted_pick(weighted, random)


static func _roll_weighted_item(
	entries: Array,
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> String:
	var eligible: Array = []
	var biases := DISTRICT_BIASES.get(district, {}) as Dictionary
	for entry_value in entries:
		var entry := entry_value as Array
		if entry.size() < 2:
			continue
		var item_id := str(entry[0])
		if not ITEM_CATALOG.has(item_id):
			continue
		var definition := ITEM_CATALOG[item_id] as Dictionary
		if not _item_allowed(definition, stage_tier):
			continue
		var weight := float(entry[1]) * float(biases.get(item_id, 1.0))
		if weight > 0.0:
			eligible.append([item_id, weight])
	return _weighted_pick(eligible, random)


static func _weighted_pick(entries: Array, random: RandomNumberGenerator) -> String:
	var total_weight := 0.0
	for entry_value in entries:
		var entry := entry_value as Array
		total_weight += float(entry[1])
	if total_weight <= 0.0:
		return ""
	var roll := random.randf() * total_weight
	for entry_value in entries:
		var entry := entry_value as Array
		roll -= float(entry[1])
		if roll <= 0.0:
			return str(entry[0])
	return str((entries.back() as Array)[0])


static func _item_allowed(definition: Dictionary, stage_tier: int) -> bool:
	var stage := clampi(stage_tier, 1, 4)
	var profile := STAGE_PROFILES[stage] as Dictionary
	if stage < int(definition.get("minimum_stage", 1)):
		return false
	if (
		str(definition.get("loot_type", "")) == "weapon"
		and int(definition.get("rarity_tier", 1))
		> int(profile.get("weapon_rarity_cap", 1))
	):
		return false
	if (
		str(definition.get("loot_type", "")) == "ammo"
		and int(definition.get("ammo_tier", 1))
		> int(profile.get("ammo_tier_cap", 1))
	):
		return false
	return true


static func _materialize_item(
	item_id: String,
	stage_tier: int,
	random: RandomNumberGenerator,
	enemy_stack: bool = false
) -> Dictionary:
	if not ITEM_CATALOG.has(item_id):
		return {}
	var catalog := (ITEM_CATALOG[item_id] as Dictionary).duplicate(true)
	var loot_type := str(catalog.get("loot_type", ""))
	var amount := 1
	if loot_type == "ammo":
		amount = _roll_ammo_amount(
			stage_tier,
			int(catalog.get("ammo_tier", 1)),
			random,
			enemy_stack
		)
	var data := catalog.duplicate(true)
	data.erase("loot_type")
	data.erase("weight")
	data["amount"] = amount
	data["item_id"] = item_id
	data["stage_tier"] = clampi(stage_tier, 1, 4)
	data["total_value"] = int(data.get("base_value", 0)) * amount
	data["value_per_slot"] = float(data["total_value"]) / float(maxi(1, int(data.get("slot_size", 1))))
	return {"type": loot_type, "data": data}


static func _roll_ammo_amount(
	stage_tier: int,
	ammo_tier: int,
	random: RandomNumberGenerator,
	enemy_stack: bool
) -> int:
	if enemy_stack:
		return random.randi_range(3, 8)
	if ammo_tier >= 3:
		return random.randi_range(2, 5) if stage_tier == 3 else random.randi_range(3, 6)
	match clampi(stage_tier, 1, 4):
		1:
			return random.randi_range(4, 7)
		2:
			return random.randi_range(4, 8)
		3:
			return random.randi_range(5, 10)
		_:
			return random.randi_range(6, 12)


static func _enemy_ammo_item_id(
	enemy_weapon_id: String,
	stage_tier: int,
	random: RandomNumberGenerator
) -> String:
	var ordinary_id := ""
	var high_tier_id := ""
	match enemy_weapon_id:
		"m1911":
			ordinary_id = "ammo_45_fmj"
			high_tier_id = "ammo_45_ap"
		"mp5":
			ordinary_id = "ammo_9mm_fmj"
			high_tier_id = "ammo_9mm_ap"
		"double_barrel":
			ordinary_id = "ammo_12g_buckshot"
			high_tier_id = "ammo_12g_slug"
		"ak47":
			ordinary_id = "ammo_762_fmj"
			high_tier_id = "ammo_762_ap"
		_:
			return ""
	var ap_chance := 0.0
	if stage_tier == 3:
		ap_chance = 0.035
	elif stage_tier >= 4:
		ap_chance = 0.07
	if ap_chance > 0.0 and random.randf() < ap_chance:
		var high_definition := ITEM_CATALOG.get(high_tier_id, {}) as Dictionary
		if not high_definition.is_empty() and _item_allowed(high_definition, stage_tier):
			return high_tier_id
	var ordinary_definition := ITEM_CATALOG.get(ordinary_id, {}) as Dictionary
	if ordinary_definition.is_empty() or not _item_allowed(ordinary_definition, stage_tier):
		return ""
	return ordinary_id


static func _roll_basic_component_id(
	stage_tier: int,
	random: RandomNumberGenerator
) -> String:
	var components := ["rubber_gasket", "magazine_spring"]
	if stage_tier >= 2:
		components.append("scope_lens")
	return components[random.randi_range(0, components.size() - 1)]


static func _find_weapon_definition(weapon_id: String) -> Dictionary:
	var definition := ITEM_CATALOG.get(weapon_id, {}) as Dictionary
	if str(definition.get("loot_type", "")) != "weapon":
		return {}
	return definition
