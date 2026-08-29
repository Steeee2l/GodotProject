class_name RaidLossManager
extends RefCounted

const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")

const SCALAR_LOOT_KEYS := ["medkits", "canned_food", "churu"]
const INVENTORY_LOOT_KEYS := [
	"ammo_inventory",
	"mod_component_inventory",
	# 중장비(지뢰·포탑·로켓)는 탄약과 같은 소모품 계급 — 시체에 실리고 회수된다.
	# 시체에 중장비만 남아도 "회수할 것 없음"이 나오면 안 된다(get_item_count 합산).
	"heavy_gear_inventory",
	"progression_item_inventory",
	"weapon_mod_inventory",
	"weapon_inventory",
	"equipment_inventory",
]


static func build_death_corpse_loot() -> Dictionary:
	# ── 영구 귀속(2026-08 경제 코어) ──
	# 시체로 가는 것은 가방의 재료(부품)·탄약·구급약·통조림·츄르뿐이다(귀중품은
	# valuable_inventory에서 별도로 사라진다). 무기·방어구(장착+보유)·부착물·강화·
	# 설계도 조각·인장·키는 전부 손에 남는다 — 장비는 필드에서 절대 안 나오고 제작으로만
	# 생기므로, 시체에 실으면 "회수 실패 = 영구 손실"이 돼 규칙이 거짓이 된다.
	# (GameState.clear_carried_raid_inventory_after_death와 같은 판정 규칙 — 여기서
	#  빼 두지 않으면 시체 회수 시 같은 장비가 이중 지급된다.)
	var loot := {
		"ammo_inventory": GameState.ammo_inventory.duplicate(true),
		"medkits": maxi(0, GameState.medkits),
		"canned_food": GameState.get_backpack_storage_count("food", "canned_food"),
		"churu": maxi(0, GameState.churu),
		"mod_component_inventory": GameState.mod_component_inventory.duplicate(true),
		"heavy_gear_inventory": GameState.heavy_gear_inventory.duplicate(true),
		"progression_item_inventory": {},
		"weapon_mod_inventory": {},
		"weapon_inventory": {},
		"equipment_inventory": {},
		# 장비는 유지되므로 시체에는 "장착 중이던 무기" 정보가 없다.
		# (예전 세이브의 시체 기록에는 남아 있을 수 있고, 회수 코드는 그대로 처리한다.)
		"equipped_weapon_id": "",
		"equipped_weapon_mods": [],
		"weapon_mod_loadouts": {},
		"raid_special_cargo": GameState.raid_special_cargo.duplicate(true),
	}
	# 부작용 없음 — 탈출 결정 화면에서 "지금 확보 가치"를 미리 보여줄 때도 쓰므로
	# 여기서 시큐어 슬롯을 비우지 않는다. 실제 사망 처리(store_death_corpse)에서만 비운다.
	return loot


static func store_death_corpse(player_position: Vector3) -> Dictionary:
	var loot := build_death_corpse_loot()
	# 시큐어 슬롯 몫을 시체 전리품에서 빼내 확보한다. 츄르 > 개조 부품 > 구급약
	# 순으로 슬롯 수만큼. 죽어도 "그것만은 남는" 최소한의 보험이다.
	fill_secure_slots_from_loot(loot)
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
		["heavy_gear_inventory", "heavy"],
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
		# 슬롯 수는 단일 지점(방어구 돌파 +90 보너스 포함).
		if GameState.secure_dog_items.size() >= GameState.get_secure_slot_count():
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
	# 장비 줄은 구세이브의 시체 기록(영구 귀속 이전)에만 생긴다 — 새 시체엔 장비가 없다.
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
	]:
		var amount := maxi(0, int(loot.get(scalar[0], 0)))
		if amount > 0:
			supply_entries.append("%s %d개" % [scalar[1], amount])
	if component_count + mod_count > 0:
		supply_entries.append("부품 %d개" % (component_count + mod_count))
	var heavy_count := _dictionary_count(loot.get("heavy_gear_inventory", {}) as Dictionary)
	if heavy_count > 0:
		supply_entries.append("중장비 %d개" % heavy_count)
	if progression_count > 0:
		supply_entries.append("청사진·키카드 %d개" % progression_count)
	var cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not cargo.is_empty():
		supply_entries.append("대형 화물 · %s" % cargo.get("title", "봉인된 지하철 화물"))

	var lines: Array[String] = ["분실한 휴대품"]
	if not gear_entries.is_empty():
		lines.append("장비 · %s" % "  /  ".join(gear_entries))
	if not supply_entries.is_empty():
		lines.append("휴대품 · %s" % "  /  ".join(supply_entries))
	# 영구 귀속 — 장비(무기·방어구·부착물)는 시체 목록에 아예 안 들어온다.
	lines.append("장비(무기·방어구·부착물)는 전부 손에 남았습니다 — 잃은 건 가방의 재료·탄약·귀중품뿐입니다.")
	lines.append("다음 탐사에서 사망 지점의 가방을 한 번 회수할 수 있습니다.")
	return "\n".join(lines)


static func _dictionary_count(inventory: Dictionary) -> int:
	var total := 0
	for amount in inventory.values():
		total += maxi(0, int(amount))
	return total
