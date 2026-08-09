class_name RaidLossManager
extends RefCounted

const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")

const SCALAR_LOOT_KEYS := ["medkits", "canned_food", "churu", "raw_scrap", "raw_catnip"]
const INVENTORY_LOOT_KEYS := [
	"ammo_inventory",
	"mod_component_inventory",
	"progression_item_inventory",
	"weapon_mod_inventory",
	"weapon_inventory",
	"equipment_inventory",
]


static func build_death_corpse_loot() -> Dictionary:
	var equipment_totals := _equipment_total_counts(
		GameState.equipment_inventory,
		GameState.equipped_body_armor_id,
		GameState.equipped_head_armor_id,
		GameState.equipped_footwear_id
	)
	var loot := {
		"ammo_inventory": GameState.ammo_inventory.duplicate(true),
		"medkits": maxi(0, GameState.medkits),
		"canned_food": GameState.get_backpack_storage_count("food", "canned_food"),
		"churu": maxi(0, GameState.churu),
		"raw_scrap": maxi(0, GameState.raw_scrap),
		"raw_catnip": maxi(0, GameState.raw_catnip),
		"mod_component_inventory": GameState.mod_component_inventory.duplicate(true),
		"progression_item_inventory": GameState.progression_item_inventory.duplicate(true),
		"weapon_mod_inventory": GameState.weapon_mod_inventory.duplicate(true),
		"weapon_inventory": GameState.weapon_inventory.duplicate(true),
		"equipment_inventory": equipment_totals,
		"equipped_weapon_id": GameState.equipped_weapon_id,
		"equipped_weapon_mods": GameState.equipped_weapon_mods.duplicate(),
		"weapon_mod_loadouts": GameState.weapon_mod_loadouts.duplicate(true),
		"raid_special_cargo": GameState.raid_special_cargo.duplicate(true),
	}
	# 부작용 없음 — 탈출 결정 화면에서 "지금 확보 가치"를 미리 보여줄 때도 쓰므로
	# 여기서 시큐어 슬롯을 비우지 않는다. 실제 사망 처리(store_death_corpse)에서만 비운다.
	return loot


static func store_death_corpse(player_position: Vector3) -> Dictionary:
	var loot := build_death_corpse_loot()
	GameState.secure_dog_items.clear()
	if get_item_count(loot) <= 0:
		GameState.clear_pending_corpse_recovery()
		return loot
	GameState.set_pending_corpse_recovery({
		"map_seed": GameState.map_seed,
		"raid_zone": GameState.selected_raid_zone,
		"position": [player_position.x, player_position.y, player_position.z],
		"loot": loot,
	})
	return loot


static func get_item_count(loot: Dictionary) -> int:
	var total := 0
	for key in SCALAR_LOOT_KEYS:
		total += maxi(0, int(loot.get(key, 0)))
	for key in INVENTORY_LOOT_KEYS:
		var inventory := loot.get(key, {}) as Dictionary
		for amount in inventory.values():
			total += maxi(0, int(amount))
	if not (loot.get("raid_special_cargo", {}) as Dictionary).is_empty():
		total += 1
	return total


static func get_total_value(loot: Dictionary) -> int:
	var total := 0
	var inventory_specs := [
		["ammo_inventory", "ammo"],
		["mod_component_inventory", "component"],
		["progression_item_inventory", "progression"],
		["weapon_mod_inventory", "mod"],
		["weapon_inventory", "weapon"],
		["equipment_inventory", "equipment"],
	]
	for spec in inventory_specs:
		var inventory := loot.get(spec[0], {}) as Dictionary
		for item_id in inventory.keys():
			total += RAID_ITEM_ECONOMY.get_total_value(
				str(spec[1]),
				str(item_id),
				maxi(0, int(inventory.get(item_id, 0)))
			)
	for scalar in [
		["medkits", "medkit", "medkit"],
		["canned_food", "food", "canned_food"],
		["churu", "churu", "churu"],
		["raw_scrap", "raw_scrap", "raw_scrap"],
		["raw_catnip", "raw_catnip", "raw_catnip"],
	]:
		total += RAID_ITEM_ECONOMY.get_total_value(
			str(scalar[1]),
			str(scalar[2]),
			maxi(0, int(loot.get(scalar[0], 0)))
		)
	var special_cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not special_cargo.is_empty():
		total += RAID_ITEM_ECONOMY.get_total_value(
			"special_cargo",
			str(special_cargo.get("id", "sealed_subway_cargo")),
			1,
			special_cargo
		)
	return total


static func fill_secure_slots_from_loot(loot: Dictionary) -> void:
	GameState.secure_dog_items.clear()
	var candidates := [
		{"key": "churu", "type": "currency", "id": "churu"},
		{"key": "weapon_mod_inventory", "type": "mod", "id": ""},
		{"key": "mod_component_inventory", "type": "component", "id": ""},
		{"key": "medkits", "type": "consumable", "id": "medkit"},
	]
	for candidate in candidates:
		if GameState.secure_dog_items.size() >= GameState.secure_dog_slots:
			break
		var key := str(candidate.key)
		if loot.get(key) is Dictionary:
			var inventory := loot.get(key) as Dictionary
			for item_id in inventory.keys():
				if int(inventory[item_id]) <= 0:
					continue
				GameState.store_secure_item({
					"type": candidate.type,
					"id": str(item_id),
					"amount": 1,
				})
				inventory[item_id] = int(inventory[item_id]) - 1
				break
		elif int(loot.get(key, 0)) > 0:
			GameState.store_secure_item({
				"type": candidate.type,
				"id": candidate.id,
				"amount": 1,
			})
			loot[key] = int(loot[key]) - 1


static func restore_secure_items_after_death() -> void:
	for item in GameState.secure_dog_items:
		var item_type := str(item.get("type", ""))
		var item_id := str(item.get("id", ""))
		var amount := maxi(1, int(item.get("amount", 1)))
		match item_type:
			"currency":
				if item_id == "churu":
					GameState.churu += amount
			"consumable":
				if item_id == "medkit":
					GameState.medkits += amount
			"component":
				GameState.add_mod_component(item_id, amount)
			"mod":
				GameState.add_weapon_mod(item_id, amount)
	GameState.secure_dog_items.clear()


static func format_loss_summary(loot: Dictionary) -> String:
	if get_item_count(loot) <= 0:
		return "분실한 휴대품 없음"
	var gear_entries: Array[String] = []
	for weapon_id_value in (loot.get("weapon_inventory", {}) as Dictionary).keys():
		var weapon_amount := maxi(0, int((loot.get("weapon_inventory", {}) as Dictionary).get(weapon_id_value, 0)))
		if weapon_amount <= 0:
			continue
		var weapon_definition := WEAPON_SYSTEM.get_weapon(str(weapon_id_value))
		gear_entries.append("%s x%d" % [weapon_definition.get("display_name", weapon_id_value), weapon_amount])
	for equipment_id_value in (loot.get("equipment_inventory", {}) as Dictionary).keys():
		var equipment_amount := maxi(0, int((loot.get("equipment_inventory", {}) as Dictionary).get(equipment_id_value, 0)))
		if equipment_amount <= 0:
			continue
		var equipment_definition := GameState.get_equipment_definition(str(equipment_id_value))
		gear_entries.append("%s x%d" % [equipment_definition.get("display_name", equipment_id_value), equipment_amount])

	var supply_entries: Array[String] = []
	var ammo_count := _dictionary_count(loot.get("ammo_inventory", {}) as Dictionary)
	var component_count := _dictionary_count(loot.get("mod_component_inventory", {}) as Dictionary)
	var mod_count := _dictionary_count(loot.get("weapon_mod_inventory", {}) as Dictionary)
	var progression_count := _dictionary_count(loot.get("progression_item_inventory", {}) as Dictionary)
	if ammo_count > 0:
		supply_entries.append("탄약 %d발" % ammo_count)
	for scalar in [
		["medkits", "구급약"],
		["canned_food", "통조림"],
		["churu", "츄르"],
		["raw_scrap", "고철 조각"],
		["raw_catnip", "캣닢 잎"],
	]:
		var amount := maxi(0, int(loot.get(scalar[0], 0)))
		if amount > 0:
			supply_entries.append("%s %d개" % [scalar[1], amount])
	if component_count + mod_count > 0:
		supply_entries.append("부품 %d개" % (component_count + mod_count))
	if progression_count > 0:
		supply_entries.append("청사진·키카드 %d개" % progression_count)
	var cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not cargo.is_empty():
		supply_entries.append("대형 화물 · %s" % cargo.get("title", "봉인된 지하철 화물"))

	var lines: Array[String] = ["분실한 장비 및 소모품"]
	if not gear_entries.is_empty():
		lines.append("장비 · %s" % "  /  ".join(gear_entries))
	if not supply_entries.is_empty():
		lines.append("휴대품 · %s" % "  /  ".join(supply_entries))
	lines.append("다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다.")
	return "\n".join(lines)


static func _equipment_total_counts(
	inventory: Dictionary,
	body_id: String,
	head_id: String,
	footwear_id: String
) -> Dictionary:
	var totals := inventory.duplicate(true)
	for equipped_id in [body_id, head_id, footwear_id]:
		if equipped_id.is_empty():
			continue
		totals[equipped_id] = int(totals.get(equipped_id, 0)) + 1
	return totals


static func _dictionary_count(inventory: Dictionary) -> int:
	var total := 0
	for amount in inventory.values():
		total += maxi(0, int(amount))
	return total
