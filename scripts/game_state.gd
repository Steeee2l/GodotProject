extends Node

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")

var map_seed: int = 47291
var raid_serial: int = 0
var player_health: int = 82
var player_level: int = 1
var player_xp: int = 0
var pending_level_choices: int = 0
var player_stat_levels: Dictionary = {
	"max_health": 0,
	"max_stamina": 0,
	"move_speed": 0,
	"recovery": 0,
	"toughness": 0,
	"fatigue_resistance": 0,
}
var training_levels: Dictionary = {
	"vitality": 0,
	"endurance": 0,
	"agility": 0,
	"recovery": 0,
	"fieldcraft": 0,
}
var magazine_ammo: int = 30
var reserve_ammo: int = 90
var has_ak: bool = true
var scrap: int = 80
var weapon_level: int = 1
var medkits: int = 0
var canned_food: int = 0
var catnip: float = 0.0
var churu: int = 0
var fatigue: float = 0.0
var rescued_workers: int = 0
var resident_cat_ids: Array[String] = []
var assigned_worker_ids: Array[String] = []
var assigned_catnip_worker_ids: Array[String] = []
var resident_traits: Dictionary = {}
var mod_component_inventory: Dictionary = {
	"rubber_gasket": 0,
	"scope_lens": 0,
	"magazine_spring": 0,
}
var weapon_mod_inventory: Dictionary = {
	"scope_2x": 0,
	"muffled_sock": 0,
	"sponge_pad": 0,
	"quick_mag": 0,
	"bell_bait": 0,
	"ak_precision_receiver": 0,
}
var weapon_inventory: Dictionary = {"ak47": 1}
var equipment_inventory: Dictionary = {
	"scav_vest": 0,
	"riot_vest": 0,
	"patched_helmet": 0,
	"tactical_helmet": 0,
	"patched_sneakers": 0,
	"tactical_boots": 0,
}
var equipped_body_armor_id: String = ""
var equipped_head_armor_id: String = ""
var equipped_footwear_id: String = ""
var returning_from_shelter: bool = false
var world_time_hours: float = 9.0
var equipped_weapon_id: String = "ak47"
var weapon_durability: float = 100.0
var equipped_weapon_mods: Array[String] = []
var weapon_mod_loadouts: Dictionary = {"ak47": []}
var equipped_magazine_id: String = "ak_30rnd"
var equipped_ammo_id: String = "762_fmj"
var ammo_inventory: Dictionary = {
	"9mm_fmj": 60,
	"45_fmj": 28,
	"762_fmj": 90,
	"12g_buckshot": 12,
}
var secure_dog_slots: int = 1
var secure_dog_items: Array[Dictionary] = []
var pending_corpse_recovery: Dictionary = {}
var corpse_recovery_attempt_active: bool = false
var shelter_workbench_level: int = 1
var shelter_tier: int = 1
var scratcher_bank_level: int = 1
var scratcher_multiplier: float = 1.0
var catnip_scraper_level: int = 1
var catnip_scraper_multiplier: float = 1.0
var storage_level: int = 1
var storage_inventory: Array[Dictionary] = []
var catnip_boost_end_time: int = 0
var shelter_last_progress_time: int = 0
var workbench_repair_active: bool = false
var workbench_repair_weapon_id: String = "ak47"
var shelter_offline_scrap_pending: int = 0
var shelter_offline_catnip_pending: float = 0.0
var shelter_offline_repair_pending: float = 0.0
var workbench_starter_parts_claimed: bool = false
var shelter_scrap_fraction: float = 0.0
var shelter_catnip_fraction: float = 0.0
var shelter_food_fraction: float = 0.0
var shelter_return_serial: int = 0
var merchant_last_roll_serial: int = -1
var merchant_status: String = "away"
var merchant_decline_count: int = 0
var weapon_enhancement_levels: Dictionary = {"ak47": 0}
var mod_enhancement_levels: Dictionary = {}
var artisan_pity: int = 0
var selected_raid_zone: String = "jongno_outskirts"
var persistence_enabled: bool = true
var persistence_path: String = SAVE_PATH

const SAVE_PATH := "user://shelter_progress_v2.json"
const MAX_WEAPON_ENHANCEMENT := 99
const ARTISAN_PITY_LIMIT := 10
const EQUIPMENT_DEFINITIONS := {
	"scav_vest": {
		"display_name": "누더기 방탄 조끼", "slot": "body", "damage_reduction": 0.12,
		"weight": 3.8, "icon": "armor",
		"texture_path": "res://assets/equipment/generated/scav_vest.png",
		"description": "얇은 철판을 덧댄 경량 조끼. 받는 피해를 12% 줄입니다.",
	},
	"riot_vest": {
		"display_name": "진압대 방탄 조끼", "slot": "body", "damage_reduction": 0.22,
		"weight": 6.2, "icon": "armor",
		"texture_path": "res://assets/equipment/generated/riot_vest.png",
		"description": "무겁지만 튼튼한 진압 장비. 받는 피해를 22% 줄입니다.",
	},
	"patched_helmet": {
		"display_name": "기워 붙인 헬멧", "slot": "head", "damage_reduction": 0.08,
		"weight": 1.4, "icon": "helmet",
		"texture_path": "res://assets/equipment/generated/patched_helmet.png",
		"description": "금이 간 안전모를 보강했습니다. 받는 피해를 8% 줄입니다.",
	},
	"tactical_helmet": {
		"display_name": "전술 방탄 헬멧", "slot": "head", "damage_reduction": 0.15,
		"weight": 2.1, "icon": "helmet",
		"texture_path": "res://assets/equipment/generated/tactical_helmet.png",
		"description": "군용 내피가 남아 있는 헬멧. 받는 피해를 15% 줄입니다.",
	},
	"patched_sneakers": {
		"display_name": "기워 붙인 운동화", "slot": "feet",
		"move_speed_bonus": 0.06, "stamina_cost_multiplier": 0.92,
		"weight": 0.7, "icon": "footwear",
		"texture_path": "res://assets/equipment/generated/patched_sneakers.png",
		"description": "가볍게 기워 발소리와 무게를 줄인 생존용 운동화입니다.",
	},
	"tactical_boots": {
		"display_name": "경량 전술화", "slot": "feet",
		"move_speed_bonus": 0.03, "stamina_cost_multiplier": 0.78,
		"weight": 1.4, "icon": "footwear",
		"texture_path": "res://assets/equipment/generated/tactical_boots.png",
		"description": "발목을 잡아주면서도 유연한 밑창을 사용한 경량 전술화입니다.",
	},
}
const PLAYER_LEVEL_REWARDS := {
	"max_health": {"title": "생존 체질", "description": "최대 체력 +8", "icon": "health"},
	"max_stamina": {"title": "지구력", "description": "최대 스태미나 +10", "icon": "stamina"},
	"move_speed": {"title": "민첩한 발", "description": "이동 속도 +2.5%", "icon": "speed"},
	"recovery": {"title": "호흡 조절", "description": "스태미나 회복 +7%", "icon": "recovery"},
	"toughness": {"title": "충격 적응", "description": "받는 피해 -2%", "icon": "armor"},
	"fatigue_resistance": {"title": "현장 적응", "description": "피로 획득 -5%", "icon": "fitness"},
}
const TRAINING_NODE_DEFS := {
	"vitality": {
		"title": "중량 훈련", "description": "랭크마다 최대 체력 +10", "icon": "health",
		"max_rank": 5, "base_cost": 2, "cost_step": 2, "requires": {},
	},
	"endurance": {
		"title": "유산소 훈련", "description": "랭크마다 최대 스태미나 +12", "icon": "stamina",
		"max_rank": 5, "base_cost": 2, "cost_step": 2, "requires": {},
	},
	"recovery": {
		"title": "회복 루틴", "description": "랭크마다 스태미나 회복 +8%", "icon": "recovery",
		"max_rank": 4, "base_cost": 4, "cost_step": 3, "requires": {"vitality": 2},
	},
	"agility": {
		"title": "풋워크", "description": "랭크마다 이동 속도 +2%", "icon": "speed",
		"max_rank": 4, "base_cost": 4, "cost_step": 3, "requires": {"endurance": 2},
	},
	"fieldcraft": {
		"title": "현장 체력", "description": "랭크마다 피로 획득 -7%", "icon": "fitness",
		"max_rank": 3, "base_cost": 8, "cost_step": 5, "requires": {"recovery": 2, "agility": 2},
	},
}
const RAID_ZONES := {
	"jongno_outskirts": {
		"name": "종로 외곽",
		"description": "낮은 위협도의 폐상가 지대. 통조림과 기초 부품을 확보하기 좋습니다.",
		"required_tier": 1,
		"threat": 0.15,
		"enemy_multiplier": 1.0,
		"boss": false,
		"reward": "통조림 · 기초 부품",
	},
	"namdaemun_market": {
		"name": "남대문 폐시장",
		"description": "무장 약탈자가 상가 통로를 점거한 중위험 구역입니다.",
		"required_tier": 2,
		"threat": 0.35,
		"enemy_multiplier": 1.25,
		"boss": true,
		"reward": "츄르 · 총기 부품",
	},
	"euljiro_depths": {
		"name": "을지로 지하구역",
		"description": "좁은 골목과 지하 통로가 이어지는 고위험 구역입니다.",
		"required_tier": 3,
		"threat": 0.55,
		"enemy_multiplier": 1.55,
		"boss": true,
		"reward": "고급 부품 · 츄르",
	},
	"yongsan_blockade": {
		"name": "용산 봉쇄선",
		"description": "군용 화기와 정예 병력이 남아 있는 봉쇄 구역입니다.",
		"required_tier": 4,
		"threat": 0.78,
		"enemy_multiplier": 1.9,
		"boss": true,
		"reward": "특수 모듈 · 츄르",
	},
	"namsan_core": {
		"name": "남산 오염 핵심부",
		"description": "서울에서 가장 위험한 심야 전투 구역입니다.",
		"required_tier": 5,
		"threat": 1.0,
		"enemy_multiplier": 2.3,
		"boss": true,
		"reward": "최상급 부품 · 대량 츄르",
	},
}

const WORKBENCH_UPGRADE_COSTS := {2: 180, 3: 420, 4: 900, 5: 1800}
const SCRATCHER_UPGRADE_COSTS := {2: 120, 3: 320, 4: 850, 5: 1600}
const CATNIP_SCRAPER_UPGRADE_COSTS := {2: 160, 3: 420, 4: 1050, 5: 2200}
const STORAGE_GRID_BY_LEVEL := {
	1: Vector2i(6, 5),
	2: Vector2i(7, 6),
	3: Vector2i(8, 7),
	4: Vector2i(9, 8),
	5: Vector2i(10, 9),
}
const STORAGE_UPGRADE_COSTS := {
	2: {"scrap": 180, "churu": 0},
	3: {"scrap": 480, "churu": 1},
	4: {"scrap": 1200, "churu": 2},
	5: {"scrap": 2800, "churu": 4},
}
const SHELTER_CAPACITY_BY_TIER := {1: 5, 2: 10, 3: 20, 4: 35, 5: 50}
const KNEADING_SLOTS_BY_TIER := {1: 3, 2: 6, 3: 10, 4: 15, 5: 20}
const CATNIP_SLOTS_BY_TIER := {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
const SHELTER_UPGRADE_COSTS := {
	2: {"scrap": 1200, "churu": 1},
	3: {"scrap": 6000, "churu": 2},
	4: {"scrap": 30000, "churu": 4},
	5: {"scrap": 160000, "churu": 8},
}
const CATNIP_BOOST_COST := 25.0
const CATNIP_BOOST_DURATION_SECONDS := 600
const CATNIP_BOOST_MULTIPLIER := 10.0
const BASE_SCRAP_PER_WORKER_HOUR := 72.0
const BASE_CATNIP_PER_WORKER_HOUR := 3.0
const WORKER_HOURS_PER_CANNED_FOOD := 6.0
const RESIDENT_TRAIT_PRESETS := [
	{"name": "말랑 앞발", "kneading": 1.15, "catnip": 1.00},
	{"name": "초록 코", "kneading": 1.00, "catnip": 1.20},
	{"name": "야무진 발톱", "kneading": 1.08, "catnip": 1.08},
	{"name": "밤샘 체질", "kneading": 1.05, "catnip": 1.10},
	{"name": "평범한 주민", "kneading": 1.00, "catnip": 1.00},
]
const RESIDENT_NAME_POOL: Array[String] = [
	"보리", "두부", "호두", "감자", "밤이", "구름", "탄이", "콩이",
	"모카", "치즈", "소금", "후추", "달이", "별이", "봄이", "여름",
	"가을", "겨울", "라떼", "쿠키", "설탕", "참깨", "들깨", "누룽지",
	"만두", "찹쌀", "팥이", "토리", "마루", "나비", "복실", "몽이",
	"뭉치", "초코", "우유", "크림", "연탄", "까미", "백설", "자두",
	"앵두", "매실", "도담", "다온", "하루", "새벽", "노을", "이슬",
	"단추", "양말", "꼬리", "수박", "참외", "호박", "미소", "단비",
]
const RESIDENT_PORTRAIT_COUNT := 5


func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if str(argument).begins_with("res://tests/"):
			persistence_enabled = false
			break
	load_persistent_state()
	if raid_serial == 0:
		randomize_map()
	process_shelter_progress()


func randomize_map() -> void:
	raid_serial += 1
	var previous_seed := map_seed
	var time_mix := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	var candidate := absi(time_mix ^ (raid_serial * 104729) ^ (previous_seed * 31)) % 2_000_000_000
	if candidate == previous_seed:
		candidate = (candidate + 104729) % 2_000_000_000
	map_seed = candidate


func start_new_raid() -> void:
	process_shelter_progress()
	var corpse_zone := str(pending_corpse_recovery.get("raid_zone", ""))
	var corpse_seed := int(pending_corpse_recovery.get("map_seed", 0))
	if not pending_corpse_recovery.is_empty() and corpse_zone == selected_raid_zone and corpse_seed != 0:
		raid_serial += 1
		map_seed = corpse_seed
		corpse_recovery_attempt_active = true
	else:
		randomize_map()
		corpse_recovery_attempt_active = false
	world_time_hours = 9.0
	fatigue = 0.0
	save_persistent_state()


func set_pending_corpse_recovery(data: Dictionary) -> void:
	pending_corpse_recovery = data.duplicate(true)
	corpse_recovery_attempt_active = false


func clear_pending_corpse_recovery() -> void:
	pending_corpse_recovery.clear()
	corpse_recovery_attempt_active = false


func finish_corpse_recovery_attempt() -> void:
	if corpse_recovery_attempt_active:
		clear_pending_corpse_recovery()


func register_shelter_return() -> void:
	shelter_return_serial += 1
	save_persistent_state()


func get_raid_zone(zone_id: String = "") -> Dictionary:
	var resolved_id := selected_raid_zone if zone_id.is_empty() else zone_id
	return (RAID_ZONES.get(resolved_id, RAID_ZONES["jongno_outskirts"]) as Dictionary).duplicate(true)


func get_raid_zone_ids() -> Array[String]:
	var result: Array[String] = []
	for zone_id in RAID_ZONES.keys():
		result.append(str(zone_id))
	result.sort_custom(func(a: String, b: String) -> bool:
		return int((RAID_ZONES[a] as Dictionary).get("required_tier", 1)) < int((RAID_ZONES[b] as Dictionary).get("required_tier", 1))
	)
	return result


func is_raid_zone_unlocked(zone_id: String) -> bool:
	if not RAID_ZONES.has(zone_id):
		return false
	return shelter_tier >= int((RAID_ZONES[zone_id] as Dictionary).get("required_tier", 1))


func select_raid_zone(zone_id: String) -> bool:
	if not is_raid_zone_unlocked(zone_id):
		return false
	selected_raid_zone = zone_id
	save_persistent_state()
	return true


func roll_merchant_visit(chance: float = 0.38) -> bool:
	if merchant_status == "inside" or merchant_status == "waiting":
		return true
	if shelter_return_serial <= 0 or merchant_last_roll_serial == shelter_return_serial:
		return false
	merchant_last_roll_serial = shelter_return_serial
	var random := RandomNumberGenerator.new()
	random.seed = int(map_seed) ^ (shelter_return_serial * 982451653) ^ 0x4D455243
	if random.randf() <= clampf(chance, 0.0, 1.0):
		merchant_status = "waiting"
		return true
	return false


func accept_merchant_visit() -> void:
	merchant_status = "inside"


func decline_merchant_visit() -> void:
	merchant_status = "away"
	merchant_decline_count += 1


func store_secure_item(item: Dictionary) -> bool:
	if secure_dog_items.size() >= secure_dog_slots:
		return false
	secure_dog_items.append(item.duplicate(true))
	return true


func upgrade_secure_dog() -> bool:
	if secure_dog_slots >= 6:
		return false
	secure_dog_slots += 1
	return true


func get_storage_grid_size() -> Vector2i:
	return STORAGE_GRID_BY_LEVEL.get(storage_level, STORAGE_GRID_BY_LEVEL[1])


func get_storage_capacity() -> int:
	var grid_size := get_storage_grid_size()
	return grid_size.x * grid_size.y


func get_storage_used_slots() -> int:
	_normalize_storage_inventory()
	return storage_inventory.size()


func get_storage_upgrade_cost() -> Dictionary:
	return (STORAGE_UPGRADE_COSTS.get(storage_level + 1, {}) as Dictionary).duplicate(true)


func try_upgrade_storage() -> bool:
	var next_level := storage_level + 1
	var cost := STORAGE_UPGRADE_COSTS.get(next_level, {}) as Dictionary
	if cost.is_empty():
		return false
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	if scrap < scrap_cost or churu < churu_cost:
		return false
	scrap -= scrap_cost
	churu -= churu_cost
	storage_level = next_level
	save_persistent_state()
	return true


func get_backpack_storage_count(item_type: String, item_id: String) -> int:
	match item_type:
		"weapon":
			var count := int(weapon_inventory.get(item_id, 0))
			if has_ak and equipped_weapon_id == item_id:
				count -= 1
			return maxi(0, count)
		"equipment":
			return get_equipment_count(item_id)
		"ammo":
			return get_ammo_count(item_id)
		"component":
			return get_mod_component_count(item_id)
		"mod":
			return get_weapon_mod_count(item_id)
		"medkit":
			return medkits
		"food":
			return canned_food
	return 0


func deposit_storage_item(item_type: String, item_id: String, amount: int = 1) -> Dictionary:
	_normalize_storage_inventory()
	var available := get_backpack_storage_count(item_type, item_id)
	var moved := mini(maxi(amount, 0), available)
	if moved <= 0:
		return {"ok": false, "reason": "보관할 수 있는 소지품이 없습니다."}
	var stack_limit := _get_storage_stack_limit(item_type)
	var free_units := 0
	for entry in storage_inventory:
		if str(entry.get("type", "")) == item_type and str(entry.get("id", "")) == item_id:
			free_units += maxi(0, stack_limit - int(entry.get("count", 0)))
	free_units += maxi(0, get_storage_capacity() - storage_inventory.size()) * stack_limit
	if free_units < moved:
		return {"ok": false, "reason": "창고에 빈 슬롯이 부족합니다."}
	if not _remove_backpack_storage_item(item_type, item_id, moved):
		return {"ok": false, "reason": "소지품을 창고로 옮기지 못했습니다."}
	var remaining := moved
	for entry in storage_inventory:
		if str(entry.get("type", "")) != item_type or str(entry.get("id", "")) != item_id:
			continue
		var room := maxi(0, stack_limit - int(entry.get("count", 0)))
		var added := mini(room, remaining)
		entry["count"] = int(entry.get("count", 0)) + added
		remaining -= added
		if remaining <= 0:
			break
	while remaining > 0:
		var added := mini(stack_limit, remaining)
		storage_inventory.append({"type": item_type, "id": item_id, "count": added})
		remaining -= added
	save_persistent_state()
	return {"ok": true, "moved": moved}


func withdraw_storage_item(slot_index: int, amount: int = 1) -> Dictionary:
	_normalize_storage_inventory()
	if slot_index < 0 or slot_index >= storage_inventory.size():
		return {"ok": false, "reason": "선택한 창고 슬롯이 비어 있습니다."}
	var entry := storage_inventory[slot_index]
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var moved := mini(maxi(amount, 1), int(entry.get("count", 0)))
	if moved <= 0:
		return {"ok": false, "reason": "선택한 창고 슬롯이 비어 있습니다."}
	_add_backpack_storage_item(item_type, item_id, moved)
	entry["count"] = int(entry.get("count", 0)) - moved
	if int(entry.get("count", 0)) <= 0:
		storage_inventory.remove_at(slot_index)
	save_persistent_state()
	return {"ok": true, "moved": moved, "type": item_type, "id": item_id}


func _get_storage_stack_limit(item_type: String) -> int:
	match item_type:
		"ammo":
			return 120
		"component":
			return 10
		"mod":
			return 5
		"medkit":
			return 5
		"food":
			return 20
	return 1


func _remove_backpack_storage_item(item_type: String, item_id: String, amount: int) -> bool:
	if get_backpack_storage_count(item_type, item_id) < amount:
		return false
	match item_type:
		"weapon":
			weapon_inventory[item_id] = maxi(0, int(weapon_inventory.get(item_id, 0)) - amount)
		"equipment":
			equipment_inventory[item_id] = maxi(0, get_equipment_count(item_id) - amount)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) - amount)
		"component":
			mod_component_inventory[item_id] = maxi(0, get_mod_component_count(item_id) - amount)
		"mod":
			weapon_mod_inventory[item_id] = maxi(0, get_weapon_mod_count(item_id) - amount)
		"medkit":
			medkits = maxi(0, medkits - amount)
		"food":
			canned_food = maxi(0, canned_food - amount)
		_:
			return false
	return true


func _add_backpack_storage_item(item_type: String, item_id: String, amount: int) -> void:
	match item_type:
		"weapon":
			add_weapon(item_id, amount)
		"equipment":
			add_equipment(item_id, amount)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) + amount)
		"component":
			add_mod_component(item_id, amount)
		"mod":
			add_weapon_mod(item_id, amount)
		"medkit":
			medkits += amount
		"food":
			canned_food += amount


func _normalize_storage_inventory() -> void:
	var normalized: Array[Dictionary] = []
	for value in storage_inventory:
		if not (value is Dictionary):
			continue
		var entry := (value as Dictionary).duplicate(true)
		var item_type := str(entry.get("type", ""))
		var item_id := str(entry.get("id", ""))
		var count := maxi(0, int(entry.get("count", 0)))
		if item_type.is_empty() or item_id.is_empty() or count <= 0:
			continue
		normalized.append({"type": item_type, "id": item_id, "count": count})
	storage_inventory = normalized


func get_ammo_count(ammo_id: String) -> int:
	return int(ammo_inventory.get(ammo_id, 0))


func set_ammo_count(ammo_id: String, amount: int) -> void:
	ammo_inventory[ammo_id] = maxi(0, amount)
	if ammo_id == equipped_ammo_id:
		reserve_ammo = int(ammo_inventory[ammo_id])


func add_weapon(weapon_id: String, amount: int = 1) -> void:
	weapon_inventory[weapon_id] = maxi(0, int(weapon_inventory.get(weapon_id, 0)) + amount)
	if not weapon_mod_loadouts.has(weapon_id):
		weapon_mod_loadouts[weapon_id] = []


func get_equipment_definition(equipment_id: String) -> Dictionary:
	return (EQUIPMENT_DEFINITIONS.get(equipment_id, {}) as Dictionary).duplicate(true)


func get_equipment_count(equipment_id: String) -> int:
	return int(equipment_inventory.get(equipment_id, 0))


func add_equipment(equipment_id: String, amount: int = 1) -> bool:
	if not EQUIPMENT_DEFINITIONS.has(equipment_id) or amount <= 0:
		return false
	equipment_inventory[equipment_id] = get_equipment_count(equipment_id) + amount
	return true


func get_equipped_equipment(slot: String) -> String:
	match slot:
		"head":
			return equipped_head_armor_id
		"feet":
			return equipped_footwear_id
		_:
			return equipped_body_armor_id


func equip_equipment(equipment_id: String) -> bool:
	var definition := get_equipment_definition(equipment_id)
	if definition.is_empty() or get_equipment_count(equipment_id) <= 0:
		return false
	var slot := str(definition.get("slot", ""))
	if not ["body", "head", "feet"].has(slot):
		return false
	var previous := get_equipped_equipment(slot)
	if previous == equipment_id:
		return true
	equipment_inventory[equipment_id] = get_equipment_count(equipment_id) - 1
	if not previous.is_empty():
		equipment_inventory[previous] = get_equipment_count(previous) + 1
	match slot:
		"head":
			equipped_head_armor_id = equipment_id
		"feet":
			equipped_footwear_id = equipment_id
		_:
			equipped_body_armor_id = equipment_id
	return true


func unequip_equipment(slot: String) -> bool:
	var equipped_id := get_equipped_equipment(slot)
	if equipped_id.is_empty():
		return false
	equipment_inventory[equipped_id] = get_equipment_count(equipped_id) + 1
	match slot:
		"head":
			equipped_head_armor_id = ""
		"feet":
			equipped_footwear_id = ""
		_:
			equipped_body_armor_id = ""
	return true


func get_equipment_damage_multiplier() -> float:
	var reduction := 0.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if equipment_id.is_empty():
			continue
		var definition := get_equipment_definition(equipment_id)
		reduction += float(definition.get("damage_reduction", 0.0))
	return clampf(1.0 - reduction, 0.5, 1.0)


func save_equipped_weapon_loadout() -> void:
	if equipped_weapon_id.is_empty():
		return
	weapon_mod_loadouts[equipped_weapon_id] = equipped_weapon_mods.duplicate()


func equip_weapon(weapon_id: String) -> bool:
	if get_weapon_count(weapon_id) <= 0:
		return false
	if weapon_id == equipped_weapon_id:
		has_ak = true
		return true
	save_equipped_weapon_loadout()
	equipped_weapon_id = weapon_id
	equipped_weapon_mods = _to_string_array(weapon_mod_loadouts.get(weapon_id, []))
	var definition := WEAPON_SYSTEM.get_weapon(weapon_id)
	equipped_magazine_id = str(definition.get("magazine_id", ""))
	equipped_ammo_id = str(definition.get("default_ammo_id", ""))
	magazine_ammo = 0
	reserve_ammo = get_ammo_count(equipped_ammo_id)
	has_ak = true
	return true


func unequip_weapon() -> bool:
	if not has_ak:
		return false
	save_equipped_weapon_loadout()
	has_ak = false
	return true


func add_mod_component(component_id: String, amount: int = 1) -> void:
	mod_component_inventory[component_id] = maxi(
		0,
		int(mod_component_inventory.get(component_id, 0)) + amount
	)


func claim_workbench_starter_parts() -> bool:
	if workbench_starter_parts_claimed:
		return false
	workbench_starter_parts_claimed = true
	add_weapon("m1911", 1)
	add_weapon("mp5", 1)
	add_mod_component("rubber_gasket", 2)
	add_mod_component("scope_lens", 2)
	add_mod_component("magazine_spring", 2)
	return true


func get_mod_component_count(component_id: String) -> int:
	return int(mod_component_inventory.get(component_id, 0))


func add_weapon_mod(mod_id: String, amount: int = 1) -> void:
	weapon_mod_inventory[mod_id] = maxi(
		0,
		int(weapon_mod_inventory.get(mod_id, 0)) + amount
	)


func get_weapon_mod_count(mod_id: String) -> int:
	return int(weapon_mod_inventory.get(mod_id, 0))


func get_supported_worker_count() -> int:
	_ensure_resident_records()
	return resident_cat_ids.size()


func get_resident_capacity() -> int:
	return int(SHELTER_CAPACITY_BY_TIER.get(shelter_tier, 5))


func get_available_resident_slots() -> int:
	_ensure_resident_records()
	return maxi(0, get_resident_capacity() - resident_cat_ids.size())


func try_add_rescued_workers(amount: int) -> int:
	var accepted := mini(maxi(amount, 0), get_available_resident_slots())
	if accepted <= 0:
		return 0
	rescued_workers += accepted
	_ensure_resident_records()
	return accepted


func get_scratcher_worker_slots() -> int:
	return int(KNEADING_SLOTS_BY_TIER.get(shelter_tier, 3))


func get_catnip_worker_slots() -> int:
	return int(CATNIP_SLOTS_BY_TIER.get(shelter_tier, 1))


func get_active_scratcher_workers() -> int:
	_ensure_resident_records()
	_sanitize_assigned_workers()
	return mini(assigned_worker_ids.size(), get_scratcher_worker_slots())


func get_active_catnip_workers() -> int:
	_ensure_resident_records()
	_sanitize_assigned_workers()
	return mini(assigned_catnip_worker_ids.size(), get_catnip_worker_slots())


func get_resident_trait(worker_id: String) -> Dictionary:
	_ensure_resident_records()
	return (resident_traits.get(worker_id, RESIDENT_TRAIT_PRESETS[4]) as Dictionary).duplicate(true)


func get_resident_trait_label(worker_id: String) -> String:
	var trait_data := get_resident_trait(worker_id)
	return "%s · 꾹꾹이 +%d%% · 캣닢 +%d%%" % [
		str(trait_data.get("name", "평범한 주민")),
		roundi((float(trait_data.get("kneading", 1.0)) - 1.0) * 100.0),
		roundi((float(trait_data.get("catnip", 1.0)) - 1.0) * 100.0),
	]


func get_kneading_efficiency_total() -> float:
	var total := 0.0
	for worker_id in assigned_worker_ids:
		total += float(get_resident_trait(worker_id).get("kneading", 1.0))
	return total


func get_catnip_efficiency_total() -> float:
	var total := 0.0
	for worker_id in assigned_catnip_worker_ids:
		total += float(get_resident_trait(worker_id).get("catnip", 1.0))
	return total


func get_worker_production_per_second(worker_id: String, production_kind: String) -> float:
	if canned_food <= 0:
		return 0.0
	var trait_data := get_resident_trait(worker_id)
	match production_kind:
		"scratcher", "kneading":
			if not assigned_worker_ids.has(worker_id):
				return 0.0
			return (
				float(trait_data.get("kneading", 1.0))
				* BASE_SCRAP_PER_WORKER_HOUR
				* scratcher_multiplier
				* get_production_multiplier()
				/ 3600.0
			)
		"catnip":
			if not assigned_catnip_worker_ids.has(worker_id):
				return 0.0
			return (
				float(trait_data.get("catnip", 1.0))
				* BASE_CATNIP_PER_WORKER_HOUR
				* catnip_scraper_multiplier
				/ 3600.0
			)
	return 0.0


func get_catnip_boost_remaining() -> int:
	return maxi(0, catnip_boost_end_time - int(Time.get_unix_time_from_system()))


func is_catnip_boost_active() -> bool:
	return get_catnip_boost_remaining() > 0


func get_production_multiplier() -> float:
	return CATNIP_BOOST_MULTIPLIER if is_catnip_boost_active() else 1.0


func activate_catnip_boost() -> bool:
	process_shelter_progress()
	if catnip < CATNIP_BOOST_COST:
		return false
	catnip -= CATNIP_BOOST_COST
	catnip_boost_end_time = int(Time.get_unix_time_from_system()) + CATNIP_BOOST_DURATION_SECONDS
	return true


func get_scrap_per_hour() -> float:
	return get_base_scrap_per_hour() * get_production_multiplier()


func get_base_scrap_per_hour() -> float:
	if get_active_scratcher_workers() > 0 and canned_food <= 0:
		return 0.0
	return get_kneading_efficiency_total() * BASE_SCRAP_PER_WORKER_HOUR * scratcher_multiplier


func get_scrap_per_second() -> float:
	return get_scrap_per_hour() / 3600.0


func get_catnip_per_hour() -> float:
	if get_active_catnip_workers() > 0 and canned_food <= 0:
		return 0.0
	return get_catnip_efficiency_total() * BASE_CATNIP_PER_WORKER_HOUR * catnip_scraper_multiplier


func get_catnip_per_second() -> float:
	return get_catnip_per_hour() / 3600.0


func tick_shelter_live(delta: float) -> int:
	var safe_delta := maxf(delta, 0.0)
	var scrap_rate := get_scrap_per_second()
	var catnip_rate := get_catnip_per_second()
	var work_delta := _consume_worker_food_for_duration(safe_delta)
	var gain := scrap_rate * work_delta
	var catnip_gain := catnip_rate * work_delta
	shelter_scrap_fraction += gain
	shelter_catnip_fraction += catnip_gain
	if shelter_catnip_fraction >= 0.01:
		catnip += shelter_catnip_fraction
		shelter_catnip_fraction = 0.0
	var whole := int(floor(shelter_scrap_fraction))
	if whole <= 0:
		return 0
	shelter_scrap_fraction -= float(whole)
	scrap += whole
	return whole


func _ensure_resident_records() -> void:
	while resident_cat_ids.size() < rescued_workers:
		var next_index := resident_cat_ids.size() + 1
		var resident_id := "resident_%03d" % next_index
		resident_cat_ids.append(resident_id)
		var new_record: Dictionary = RESIDENT_TRAIT_PRESETS[
			(next_index - 1) % RESIDENT_TRAIT_PRESETS.size()
		].duplicate(true)
		resident_traits[resident_id] = _ensure_resident_identity(resident_id, new_record)
	if resident_cat_ids.size() > rescued_workers:
		resident_cat_ids.resize(rescued_workers)
	for resident_id in resident_cat_ids:
		var record: Dictionary
		if resident_traits.has(resident_id):
			record = (resident_traits[resident_id] as Dictionary).duplicate(true)
		else:
			var resident_index := maxi(0, int(resident_id.trim_prefix("resident_")) - 1)
			record = RESIDENT_TRAIT_PRESETS[resident_index % RESIDENT_TRAIT_PRESETS.size()].duplicate(true)
		resident_traits[resident_id] = _ensure_resident_identity(resident_id, record)
	_sanitize_assigned_workers()


func _ensure_resident_identity(resident_id: String, record: Dictionary) -> Dictionary:
	if str(record.get("display_name", "")).is_empty():
		var used_names: Array[String] = []
		for resident_value in resident_traits.values():
			var resident_record := resident_value as Dictionary
			var used_name := str(resident_record.get("display_name", ""))
			if not used_name.is_empty():
				used_names.append(used_name)
		var start_index := posmod(hash("%s:%d" % [resident_id, map_seed]), RESIDENT_NAME_POOL.size())
		var selected_name := ""
		for offset in RESIDENT_NAME_POOL.size():
			var candidate := RESIDENT_NAME_POOL[(start_index + offset) % RESIDENT_NAME_POOL.size()]
			if not used_names.has(candidate):
				selected_name = candidate
				break
		if selected_name.is_empty():
			selected_name = "%s %02d" % [
				RESIDENT_NAME_POOL[start_index],
				resident_cat_ids.find(resident_id) + 1,
			]
		record["display_name"] = selected_name
	if not record.has("portrait_index"):
		record["portrait_index"] = posmod(
			hash("portrait:%s:%d" % [resident_id, map_seed]),
			RESIDENT_PORTRAIT_COUNT
		)
	return record


func _sanitize_assigned_workers() -> void:
	var cleaned: Array[String] = []
	for worker_id in assigned_worker_ids:
		if cleaned.size() >= get_scratcher_worker_slots():
			break
		if resident_cat_ids.has(worker_id) and not cleaned.has(worker_id):
			cleaned.append(worker_id)
	assigned_worker_ids = cleaned
	var cleaned_catnip: Array[String] = []
	for worker_id in assigned_catnip_worker_ids:
		if cleaned_catnip.size() >= get_catnip_worker_slots():
			break
		if resident_cat_ids.has(worker_id) and not cleaned.has(worker_id) and not cleaned_catnip.has(worker_id):
			cleaned_catnip.append(worker_id)
	assigned_catnip_worker_ids = cleaned_catnip


func assign_worker_to_scratcher(worker_id: String) -> bool:
	_ensure_resident_records()
	if not resident_cat_ids.has(worker_id):
		return false
	if assigned_worker_ids.has(worker_id):
		return true
	if assigned_worker_ids.size() >= get_scratcher_worker_slots():
		return false
	assigned_catnip_worker_ids.erase(worker_id)
	assigned_worker_ids.append(worker_id)
	return true


func unassign_worker_from_scratcher(worker_id: String) -> void:
	assigned_worker_ids.erase(worker_id)


func toggle_worker_assignment(worker_id: String) -> bool:
	if assigned_worker_ids.has(worker_id):
		unassign_worker_from_scratcher(worker_id)
		return false
	return assign_worker_to_scratcher(worker_id)


func assign_worker_to_catnip(worker_id: String) -> bool:
	_ensure_resident_records()
	if not resident_cat_ids.has(worker_id):
		return false
	if assigned_catnip_worker_ids.has(worker_id):
		return true
	if assigned_catnip_worker_ids.size() >= get_catnip_worker_slots():
		return false
	assigned_worker_ids.erase(worker_id)
	assigned_catnip_worker_ids.append(worker_id)
	return true


func unassign_worker_from_catnip(worker_id: String) -> void:
	assigned_catnip_worker_ids.erase(worker_id)


func toggle_catnip_worker_assignment(worker_id: String) -> bool:
	if assigned_catnip_worker_ids.has(worker_id):
		unassign_worker_from_catnip(worker_id)
		return false
	return assign_worker_to_catnip(worker_id)


func get_workbench_repair_per_hour() -> float:
	var base_rate := 18.0
	if shelter_workbench_level >= 3:
		base_rate *= 1.2
	if shelter_workbench_level >= 5:
		base_rate *= 1.18
	return base_rate


func process_shelter_progress() -> Dictionary:
	_ensure_resident_records()
	var now := int(Time.get_unix_time_from_system())
	if shelter_last_progress_time <= 0:
		shelter_last_progress_time = now
		return {"scrap": 0, "catnip": 0.0, "repair": 0.0, "elapsed": 0}
	var progress_start := shelter_last_progress_time
	var elapsed := maxi(0, now - shelter_last_progress_time)
	shelter_last_progress_time = now
	var base_scrap_rate := get_base_scrap_per_hour()
	var catnip_rate := get_catnip_per_hour()
	var work_seconds := _consume_worker_food_for_duration(float(elapsed))
	var base_scrap_gain := base_scrap_rate * work_seconds / 3600.0
	var boosted_seconds := mini(roundi(work_seconds), maxi(0, mini(now, catnip_boost_end_time) - progress_start))
	var boosted_extra := base_scrap_rate * float(boosted_seconds) / 3600.0 * (CATNIP_BOOST_MULTIPLIER - 1.0)
	shelter_scrap_fraction += base_scrap_gain + boosted_extra
	var scrap_gain := int(floor(shelter_scrap_fraction))
	shelter_scrap_fraction -= float(scrap_gain)
	var catnip_gain := catnip_rate * work_seconds / 3600.0
	catnip += catnip_gain
	var repair_gain := 0.0
	if workbench_repair_active and weapon_durability < 100.0:
		repair_gain = get_workbench_repair_per_hour() * float(elapsed) / 3600.0
		var before := weapon_durability
		weapon_durability = minf(100.0, weapon_durability + repair_gain)
		repair_gain = weapon_durability - before
		if weapon_durability >= 100.0:
			workbench_repair_active = false
	if scrap_gain > 0:
		scrap += scrap_gain
	shelter_offline_scrap_pending += scrap_gain
	shelter_offline_catnip_pending += catnip_gain
	shelter_offline_repair_pending += repair_gain
	return {"scrap": scrap_gain, "catnip": catnip_gain, "repair": repair_gain, "elapsed": elapsed}


func _consume_worker_food_for_duration(requested_seconds: float) -> float:
	var worker_count := get_active_scratcher_workers() + get_active_catnip_workers()
	if worker_count <= 0 or requested_seconds <= 0.0:
		return maxf(requested_seconds, 0.0)
	if canned_food <= 0:
		return 0.0
	var food_per_second := float(worker_count) / (WORKER_HOURS_PER_CANNED_FOOD * 3600.0)
	var available_food := float(canned_food) - shelter_food_fraction
	var work_seconds := minf(requested_seconds, available_food / food_per_second)
	shelter_food_fraction += work_seconds * food_per_second
	var consumed := mini(canned_food, int(floor(shelter_food_fraction)))
	if consumed > 0:
		canned_food -= consumed
		shelter_food_fraction -= float(consumed)
	return work_seconds


func consume_offline_progress_notice() -> Dictionary:
	var notice := {
		"scrap": shelter_offline_scrap_pending,
		"catnip": shelter_offline_catnip_pending,
		"repair": shelter_offline_repair_pending,
	}
	shelter_offline_scrap_pending = 0
	shelter_offline_catnip_pending = 0.0
	shelter_offline_repair_pending = 0.0
	return notice


func get_shelter_upgrade_cost() -> Dictionary:
	return (SHELTER_UPGRADE_COSTS.get(shelter_tier + 1, {}) as Dictionary).duplicate(true)


func try_upgrade_shelter_tier() -> bool:
	var next_tier := shelter_tier + 1
	if next_tier > 5:
		return false
	var cost := SHELTER_UPGRADE_COSTS.get(next_tier, {}) as Dictionary
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	if scrap < scrap_cost or churu < churu_cost:
		return false
	scrap -= scrap_cost
	churu -= churu_cost
	shelter_tier = next_tier
	_sanitize_assigned_workers()
	save_persistent_state()
	return true


func get_workbench_slot_limit() -> int:
	if shelter_workbench_level >= 5:
		return 6
	if shelter_workbench_level >= 3:
		return 5
	return 4


func get_workbench_upgrade_cost() -> Dictionary:
	var next_level := shelter_workbench_level + 1
	if next_level > 5:
		return {}
	return {"scrap": int(WORKBENCH_UPGRADE_COSTS.get(next_level, 0))}


func can_mod_weapon(weapon_id: String) -> bool:
	if shelter_workbench_level >= 3:
		return true
	return ["m1911", "mp5"].has(weapon_id)


func try_upgrade_workbench() -> bool:
	var next_level := shelter_workbench_level + 1
	if next_level > 5:
		return false
	var cost := int(WORKBENCH_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	shelter_workbench_level = next_level
	return true


func try_upgrade_scratcher_bank() -> bool:
	var next_level := scratcher_bank_level + 1
	if next_level > 5:
		return false
	var cost := int(SCRATCHER_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	scratcher_bank_level = next_level
	scratcher_multiplier = pow(2.2, float(scratcher_bank_level - 1))
	return true


func try_upgrade_catnip_scraper() -> bool:
	var next_level := catnip_scraper_level + 1
	if next_level > 5:
		return false
	var cost := int(CATNIP_SCRAPER_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	catnip_scraper_level = next_level
	catnip_scraper_multiplier = pow(1.8, float(catnip_scraper_level - 1))
	return true


func get_weapon_count(weapon_id: String) -> int:
	return int(weapon_inventory.get(weapon_id, 0))


func get_weapon_enhancement_level(weapon_id: String) -> int:
	return clampi(int(weapon_enhancement_levels.get(weapon_id, 0)), 0, MAX_WEAPON_ENHANCEMENT)


func get_weapon_enhancement_cost(weapon_id: String) -> int:
	var level := get_weapon_enhancement_level(weapon_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return 0
	var weapon_factor := 1.0
	match weapon_id:
		"mp5": weapon_factor = 1.2
		"ak47": weapon_factor = 1.55
		"double_barrel": weapon_factor = 1.4
	return maxi(25, roundi(55.0 * weapon_factor * pow(1.082, float(level))))


func try_enhance_weapon(weapon_id: String) -> bool:
	if get_weapon_count(weapon_id) <= 0:
		return false
	var level := get_weapon_enhancement_level(weapon_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return false
	var cost := get_weapon_enhancement_cost(weapon_id)
	if scrap < cost:
		return false
	scrap -= cost
	weapon_enhancement_levels[weapon_id] = level + 1
	if weapon_id == equipped_weapon_id:
		weapon_level = level + 2
	save_persistent_state()
	return true


func get_mod_enhancement_level(mod_id: String) -> int:
	return clampi(int(mod_enhancement_levels.get(mod_id, 0)), 0, MAX_WEAPON_ENHANCEMENT)


func get_mod_enhancement_cost(mod_id: String) -> int:
	var level := get_mod_enhancement_level(mod_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return 0
	return maxi(20, roundi(38.0 * pow(1.078, float(level))))


func try_enhance_mod(mod_id: String) -> bool:
	if not equipped_weapon_mods.has(mod_id):
		return false
	var level := get_mod_enhancement_level(mod_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return false
	var cost := get_mod_enhancement_cost(mod_id)
	if scrap < cost:
		return false
	scrap -= cost
	mod_enhancement_levels[mod_id] = level + 1
	save_persistent_state()
	return true


func get_artisan_roll_cost() -> Dictionary:
	return {
		"scrap": 180 + maxi(0, shelter_tier - 1) * 85,
		"canned_food": 2 + int(floor(float(shelter_tier - 1) / 2.0)),
	}


func roll_artisan_weapon() -> Dictionary:
	var cost := get_artisan_roll_cost()
	if scrap < int(cost["scrap"]) or canned_food < int(cost["canned_food"]):
		return {}
	scrap -= int(cost["scrap"])
	canned_food -= int(cost["canned_food"])
	artisan_pity += 1
	var pool: Array[String] = ["m1911", "mp5"]
	if shelter_tier >= 2:
		pool.append("ak47")
	if shelter_tier >= 3:
		pool.append("double_barrel")
	var guaranteed := artisan_pity >= ARTISAN_PITY_LIMIT
	var result_id := pool[pool.size() - 1] if guaranteed else pool[randi() % pool.size()]
	if guaranteed:
		artisan_pity = 0
	add_weapon(result_id, 1)
	if not weapon_enhancement_levels.has(result_id):
		weapon_enhancement_levels[result_id] = 0
	var result := {
		"weapon_id": result_id,
		"guaranteed": guaranteed,
		"pity": artisan_pity,
	}
	save_persistent_state()
	return result


func get_xp_required(level: int = player_level) -> int:
	var level_index := maxi(0, level - 1)
	return 100 + level_index * 55 + roundi(pow(float(level_index), 1.28) * 18.0)


func get_raid_experience_reward(kills: int, boss_kills: int = 0) -> int:
	return 35 + maxi(0, kills) * 22 + maxi(0, boss_kills) * 120


func add_raid_experience(amount: int) -> Dictionary:
	var gained := maxi(0, amount)
	var old_level := player_level
	var old_xp := player_xp
	var old_required := get_xp_required(player_level)
	player_xp += gained
	var levels_gained := 0
	while player_xp >= get_xp_required(player_level):
		player_xp -= get_xp_required(player_level)
		player_level += 1
		levels_gained += 1
	pending_level_choices += levels_gained
	save_persistent_state()
	return {
		"gained": gained,
		"old_level": old_level,
		"old_xp": old_xp,
		"old_required": old_required,
		"new_level": player_level,
		"new_xp": player_xp,
		"new_required": get_xp_required(player_level),
		"levels_gained": levels_gained,
	}


func get_level_reward_choices(seed_value: int) -> Array[String]:
	var options: Array[String] = []
	for stat_id in PLAYER_LEVEL_REWARDS.keys():
		options.append(str(stat_id))
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + player_level * 7919 + pending_level_choices * 101
	for index in range(options.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary := options[index]
		options[index] = options[swap_index]
		options[swap_index] = temporary
	var choices: Array[String] = []
	for index in mini(3, options.size()):
		choices.append(options[index])
	return choices


func get_level_reward_definition(stat_id: String) -> Dictionary:
	return (PLAYER_LEVEL_REWARDS.get(stat_id, {}) as Dictionary).duplicate(true)


func apply_level_reward(stat_id: String) -> bool:
	if pending_level_choices <= 0 or not PLAYER_LEVEL_REWARDS.has(stat_id):
		return false
	player_stat_levels[stat_id] = int(player_stat_levels.get(stat_id, 0)) + 1
	pending_level_choices -= 1
	if stat_id == "max_health":
		player_health = mini(get_max_health(), player_health + 8)
	save_persistent_state()
	return true


func get_max_health() -> int:
	return 100 + int(player_stat_levels.get("max_health", 0)) * 8 + int(training_levels.get("vitality", 0)) * 10


func get_max_stamina() -> float:
	return 100.0 + float(player_stat_levels.get("max_stamina", 0)) * 10.0 + float(training_levels.get("endurance", 0)) * 12.0


func get_move_speed_multiplier() -> float:
	var progression_multiplier := 1.0 + float(player_stat_levels.get("move_speed", 0)) * 0.025 + float(training_levels.get("agility", 0)) * 0.02
	var equipment_bonus := 0.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			equipment_bonus += float(get_equipment_definition(equipment_id).get("move_speed_bonus", 0.0))
	return progression_multiplier * (1.0 + equipment_bonus)


func get_stamina_cost_multiplier() -> float:
	var multiplier := 1.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			multiplier *= float(get_equipment_definition(equipment_id).get("stamina_cost_multiplier", 1.0))
	return clampf(multiplier, 0.5, 1.5)


func get_stamina_recovery_multiplier() -> float:
	return 1.0 + float(player_stat_levels.get("recovery", 0)) * 0.07 + float(training_levels.get("recovery", 0)) * 0.08


func get_damage_taken_multiplier() -> float:
	var toughness_multiplier := maxf(0.68, 1.0 - float(player_stat_levels.get("toughness", 0)) * 0.02)
	return toughness_multiplier * get_equipment_damage_multiplier()


func get_fatigue_gain_multiplier() -> float:
	var reduction := float(player_stat_levels.get("fatigue_resistance", 0)) * 0.05
	reduction += float(training_levels.get("fieldcraft", 0)) * 0.07
	return maxf(0.45, 1.0 - reduction)


func get_training_definition(node_id: String) -> Dictionary:
	return (TRAINING_NODE_DEFS.get(node_id, {}) as Dictionary).duplicate(true)


func get_training_rank(node_id: String) -> int:
	return int(training_levels.get(node_id, 0))


func get_training_cost(node_id: String) -> int:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return 0
	var rank := get_training_rank(node_id)
	return int(definition.get("base_cost", 1)) + rank * int(definition.get("cost_step", 1))


func get_training_requirements_met(node_id: String) -> bool:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return false
	var requirements := definition.get("requires", {}) as Dictionary
	for required_id in requirements.keys():
		if get_training_rank(str(required_id)) < int(requirements[required_id]):
			return false
	return true


func try_upgrade_training(node_id: String) -> Dictionary:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown"}
	var rank := get_training_rank(node_id)
	if rank >= int(definition.get("max_rank", 1)):
		return {"ok": false, "reason": "max_rank"}
	if not get_training_requirements_met(node_id):
		return {"ok": false, "reason": "prerequisite"}
	var cost := get_training_cost(node_id)
	if canned_food < cost:
		return {"ok": false, "reason": "canned_food", "cost": cost}
	canned_food -= cost
	training_levels[node_id] = rank + 1
	if node_id == "vitality":
		player_health = mini(get_max_health(), player_health + 10)
	save_persistent_state()
	return {"ok": true, "rank": rank + 1, "cost": cost}


func save_persistent_state() -> bool:
	if not persistence_enabled:
		return false
	save_equipped_weapon_loadout()
	var data := {
		"version": 4,
		"map_seed": map_seed,
		"raid_serial": raid_serial,
		"player_health": player_health,
		"player_level": player_level,
		"player_xp": player_xp,
		"pending_level_choices": pending_level_choices,
		"player_stat_levels": player_stat_levels,
		"training_levels": training_levels,
		"magazine_ammo": magazine_ammo,
		"scrap": scrap,
		"medkits": medkits,
		"canned_food": canned_food,
		"catnip": catnip,
		"churu": churu,
		"fatigue": fatigue,
		"rescued_workers": rescued_workers,
		"resident_cat_ids": resident_cat_ids,
		"assigned_worker_ids": assigned_worker_ids,
		"assigned_catnip_worker_ids": assigned_catnip_worker_ids,
		"resident_traits": resident_traits,
		"mod_component_inventory": mod_component_inventory,
		"weapon_mod_inventory": weapon_mod_inventory,
		"weapon_inventory": weapon_inventory,
		"equipment_inventory": equipment_inventory,
		"equipped_body_armor_id": equipped_body_armor_id,
		"equipped_head_armor_id": equipped_head_armor_id,
		"equipped_footwear_id": equipped_footwear_id,
		"weapon_enhancement_levels": weapon_enhancement_levels,
		"mod_enhancement_levels": mod_enhancement_levels,
		"equipped_weapon_id": equipped_weapon_id,
		"weapon_durability": weapon_durability,
		"equipped_weapon_mods": equipped_weapon_mods,
		"weapon_mod_loadouts": weapon_mod_loadouts,
		"equipped_magazine_id": equipped_magazine_id,
		"equipped_ammo_id": equipped_ammo_id,
		"ammo_inventory": ammo_inventory,
		"pending_corpse_recovery": pending_corpse_recovery,
		"corpse_recovery_attempt_active": corpse_recovery_attempt_active,
		"shelter_workbench_level": shelter_workbench_level,
		"shelter_tier": shelter_tier,
		"scratcher_bank_level": scratcher_bank_level,
		"scratcher_multiplier": scratcher_multiplier,
		"catnip_scraper_level": catnip_scraper_level,
		"catnip_scraper_multiplier": catnip_scraper_multiplier,
		"storage_level": storage_level,
		"storage_inventory": storage_inventory,
		"catnip_boost_end_time": catnip_boost_end_time,
		"shelter_last_progress_time": shelter_last_progress_time,
		"workbench_repair_active": workbench_repair_active,
		"workbench_repair_weapon_id": workbench_repair_weapon_id,
		"workbench_starter_parts_claimed": workbench_starter_parts_claimed,
		"shelter_scrap_fraction": shelter_scrap_fraction,
		"shelter_catnip_fraction": shelter_catnip_fraction,
		"shelter_food_fraction": shelter_food_fraction,
		"shelter_return_serial": shelter_return_serial,
		"merchant_last_roll_serial": merchant_last_roll_serial,
		"merchant_status": merchant_status,
		"merchant_decline_count": merchant_decline_count,
		"artisan_pity": artisan_pity,
		"selected_raid_zone": selected_raid_zone,
	}
	var file := FileAccess.open(persistence_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_persistent_state() -> bool:
	if not persistence_enabled:
		return false
	if not FileAccess.file_exists(persistence_path):
		return false
	var file := FileAccess.open(persistence_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	var data := parsed as Dictionary
	map_seed = int(data.get("map_seed", map_seed))
	raid_serial = int(data.get("raid_serial", raid_serial))
	player_health = int(data.get("player_health", player_health))
	player_level = maxi(1, int(data.get("player_level", player_level)))
	player_xp = maxi(0, int(data.get("player_xp", player_xp)))
	pending_level_choices = maxi(0, int(data.get("pending_level_choices", pending_level_choices)))
	player_stat_levels = (data.get("player_stat_levels", player_stat_levels) as Dictionary).duplicate(true)
	training_levels = (data.get("training_levels", training_levels) as Dictionary).duplicate(true)
	for stat_id in PLAYER_LEVEL_REWARDS.keys():
		if not player_stat_levels.has(stat_id):
			player_stat_levels[stat_id] = 0
		else:
			player_stat_levels[stat_id] = int(player_stat_levels[stat_id])
	for training_id in TRAINING_NODE_DEFS.keys():
		if not training_levels.has(training_id):
			training_levels[training_id] = 0
		else:
			training_levels[training_id] = int(training_levels[training_id])
	magazine_ammo = int(data.get("magazine_ammo", magazine_ammo))
	scrap = int(data.get("scrap", scrap))
	medkits = int(data.get("medkits", medkits))
	canned_food = int(data.get("canned_food", canned_food))
	catnip = float(data.get("catnip", catnip))
	churu = int(data.get("churu", churu))
	fatigue = float(data.get("fatigue", fatigue))
	rescued_workers = int(data.get("rescued_workers", rescued_workers))
	resident_cat_ids = _to_string_array(data.get("resident_cat_ids", []))
	assigned_worker_ids = _to_string_array(data.get("assigned_worker_ids", []))
	assigned_catnip_worker_ids = _to_string_array(data.get("assigned_catnip_worker_ids", []))
	resident_traits = (data.get("resident_traits", {}) as Dictionary).duplicate(true)
	mod_component_inventory = (data.get("mod_component_inventory", mod_component_inventory) as Dictionary).duplicate(true)
	weapon_mod_inventory = (data.get("weapon_mod_inventory", weapon_mod_inventory) as Dictionary).duplicate(true)
	for mod_id in WEAPON_SYSTEM.MODS.keys():
		if not weapon_mod_inventory.has(mod_id):
			weapon_mod_inventory[mod_id] = 0
	weapon_inventory = (data.get("weapon_inventory", weapon_inventory) as Dictionary).duplicate(true)
	equipment_inventory = (data.get("equipment_inventory", equipment_inventory) as Dictionary).duplicate(true)
	for equipment_id in EQUIPMENT_DEFINITIONS:
		if not equipment_inventory.has(equipment_id):
			equipment_inventory[equipment_id] = 0
	equipped_body_armor_id = str(data.get("equipped_body_armor_id", equipped_body_armor_id))
	equipped_head_armor_id = str(data.get("equipped_head_armor_id", equipped_head_armor_id))
	equipped_footwear_id = str(data.get("equipped_footwear_id", equipped_footwear_id))
	weapon_enhancement_levels = (data.get("weapon_enhancement_levels", weapon_enhancement_levels) as Dictionary).duplicate(true)
	mod_enhancement_levels = (data.get("mod_enhancement_levels", mod_enhancement_levels) as Dictionary).duplicate(true)
	equipped_weapon_id = str(data.get("equipped_weapon_id", equipped_weapon_id))
	weapon_durability = float(data.get("weapon_durability", weapon_durability))
	equipped_weapon_mods = _to_string_array(data.get("equipped_weapon_mods", []))
	weapon_mod_loadouts = (data.get("weapon_mod_loadouts", {}) as Dictionary).duplicate(true)
	if not weapon_mod_loadouts.has(equipped_weapon_id):
		weapon_mod_loadouts[equipped_weapon_id] = equipped_weapon_mods.duplicate()
	equipped_magazine_id = str(data.get("equipped_magazine_id", equipped_magazine_id))
	equipped_ammo_id = str(data.get("equipped_ammo_id", equipped_ammo_id))
	ammo_inventory = (data.get("ammo_inventory", ammo_inventory) as Dictionary).duplicate(true)
	pending_corpse_recovery = (data.get("pending_corpse_recovery", {}) as Dictionary).duplicate(true)
	corpse_recovery_attempt_active = bool(data.get("corpse_recovery_attempt_active", false))
	shelter_workbench_level = clampi(int(data.get("shelter_workbench_level", shelter_workbench_level)), 1, 5)
	shelter_tier = clampi(int(data.get("shelter_tier", shelter_tier)), 1, 5)
	scratcher_bank_level = clampi(int(data.get("scratcher_bank_level", scratcher_bank_level)), 1, 5)
	scratcher_multiplier = float(data.get("scratcher_multiplier", scratcher_multiplier))
	catnip_scraper_level = clampi(int(data.get("catnip_scraper_level", catnip_scraper_level)), 1, 5)
	catnip_scraper_multiplier = float(data.get("catnip_scraper_multiplier", pow(1.8, float(catnip_scraper_level - 1))))
	storage_level = clampi(int(data.get("storage_level", storage_level)), 1, 5)
	storage_inventory = _to_dictionary_array(data.get("storage_inventory", []))
	_normalize_storage_inventory()
	catnip_boost_end_time = int(data.get("catnip_boost_end_time", catnip_boost_end_time))
	shelter_last_progress_time = int(data.get("shelter_last_progress_time", shelter_last_progress_time))
	workbench_repair_active = bool(data.get("workbench_repair_active", workbench_repair_active))
	workbench_repair_weapon_id = str(data.get("workbench_repair_weapon_id", workbench_repair_weapon_id))
	workbench_starter_parts_claimed = bool(data.get("workbench_starter_parts_claimed", workbench_starter_parts_claimed))
	shelter_scrap_fraction = float(data.get("shelter_scrap_fraction", shelter_scrap_fraction))
	shelter_catnip_fraction = float(data.get("shelter_catnip_fraction", shelter_catnip_fraction))
	shelter_food_fraction = float(data.get("shelter_food_fraction", shelter_food_fraction))
	shelter_return_serial = int(data.get("shelter_return_serial", shelter_return_serial))
	merchant_last_roll_serial = int(data.get("merchant_last_roll_serial", merchant_last_roll_serial))
	merchant_status = str(data.get("merchant_status", merchant_status))
	merchant_decline_count = int(data.get("merchant_decline_count", merchant_decline_count))
	artisan_pity = clampi(int(data.get("artisan_pity", artisan_pity)), 0, ARTISAN_PITY_LIMIT - 1)
	selected_raid_zone = str(data.get("selected_raid_zone", selected_raid_zone))
	if not RAID_ZONES.has(selected_raid_zone) or not is_raid_zone_unlocked(selected_raid_zone):
		selected_raid_zone = "jongno_outskirts"
	_ensure_resident_records()
	player_health = clampi(player_health, 0, get_max_health())
	reserve_ammo = get_ammo_count(equipped_ammo_id)
	return true


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_persistent_state()


func reset_run() -> void:
	player_health = 82
	player_level = 1
	player_xp = 0
	pending_level_choices = 0
	player_stat_levels = {
		"max_health": 0,
		"max_stamina": 0,
		"move_speed": 0,
		"recovery": 0,
		"toughness": 0,
		"fatigue_resistance": 0,
	}
	training_levels = {
		"vitality": 0,
		"endurance": 0,
		"agility": 0,
		"recovery": 0,
		"fieldcraft": 0,
	}
	raid_serial = 0
	magazine_ammo = 30
	reserve_ammo = 90
	has_ak = true
	scrap = 80
	weapon_level = 1
	medkits = 0
	canned_food = 0
	catnip = 0.0
	churu = 0
	fatigue = 0.0
	rescued_workers = 0
	resident_cat_ids.clear()
	assigned_worker_ids.clear()
	assigned_catnip_worker_ids.clear()
	resident_traits.clear()
	mod_component_inventory = {
		"rubber_gasket": 0,
		"scope_lens": 0,
		"magazine_spring": 0,
	}
	weapon_mod_inventory = {
		"scope_2x": 0,
		"muffled_sock": 0,
		"sponge_pad": 0,
		"quick_mag": 0,
		"bell_bait": 0,
		"ak_precision_receiver": 0,
	}
	weapon_inventory = {"ak47": 1}
	equipment_inventory = {
		"scav_vest": 0,
		"riot_vest": 0,
		"patched_helmet": 0,
		"tactical_helmet": 0,
		"patched_sneakers": 0,
		"tactical_boots": 0,
	}
	equipped_body_armor_id = ""
	equipped_head_armor_id = ""
	equipped_footwear_id = ""
	returning_from_shelter = false
	world_time_hours = 9.0
	equipped_weapon_id = "ak47"
	weapon_durability = 100.0
	equipped_weapon_mods.clear()
	weapon_mod_loadouts = {"ak47": []}
	equipped_magazine_id = "ak_30rnd"
	equipped_ammo_id = "762_fmj"
	ammo_inventory = {
		"9mm_fmj": 60,
		"45_fmj": 28,
		"762_fmj": 90,
		"12g_buckshot": 12,
	}
	secure_dog_slots = 1
	secure_dog_items.clear()
	pending_corpse_recovery.clear()
	corpse_recovery_attempt_active = false
	shelter_workbench_level = 1
	shelter_tier = 1
	scratcher_bank_level = 1
	scratcher_multiplier = 1.0
	catnip_scraper_level = 1
	catnip_scraper_multiplier = 1.0
	storage_level = 1
	storage_inventory.clear()
	catnip_boost_end_time = 0
	shelter_last_progress_time = 0
	workbench_repair_active = false
	workbench_repair_weapon_id = "ak47"
	shelter_offline_scrap_pending = 0
	shelter_offline_catnip_pending = 0.0
	shelter_offline_repair_pending = 0.0
	workbench_starter_parts_claimed = false
	shelter_scrap_fraction = 0.0
	shelter_catnip_fraction = 0.0
	shelter_food_fraction = 0.0
	workbench_starter_parts_claimed = false
	shelter_return_serial = 0
	merchant_last_roll_serial = -1
	merchant_status = "away"
	merchant_decline_count = 0
	weapon_enhancement_levels = {"ak47": 0}
	mod_enhancement_levels.clear()
	artisan_pity = 0
	selected_raid_zone = "jongno_outskirts"
