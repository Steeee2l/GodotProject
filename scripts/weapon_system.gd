class_name WeaponSystem
extends RefCounted

const DEFAULT_WEAPON_ID := "ak47"

const WEAPONS := {
	"m1911": {
		"display_name": "M1911 \"솜방망이\"",
		"category": "권총",
		"ammo_type": "45_acp",
		"magazine_id": "m1911_7rnd",
		"default_ammo_id": "45_fmj",
		"magazine_size": 7,
		"damage": 34,
		"pellet_count": 1,
		"fire_interval": 0.22,
		"automatic": false,
		"base_spread_deg": 1.3,
		"max_spread_deg": 8.0,
		"spread_per_shot_deg": 1.1,
		"spread_recovery_deg": 7.5,
		"moving_spread_multiplier": 1.35,
		"injured_spread_multiplier": 1.3,
		"loaf_spread_multiplier": 0.85,
		"recoil_kick": 0.22,
		"loaf_recoil_multiplier": 0.75,
		"player_knockback": 0.04,
		"penetration_count": 0,
		"durability_loss": 0.045,
		"reload_time": 1.35,
		"sound_radius": 36.0,
		"mouth_carry_fire": true,
	},
	"mp5": {
		"display_name": "MP5 \"하악이\"",
		"category": "기관단총",
		"ammo_type": "9mm",
		"magazine_id": "mp5_30rnd",
		"default_ammo_id": "9mm_fmj",
		"magazine_size": 30,
		"damage": 18,
		"pellet_count": 1,
		"fire_interval": 0.075,
		"automatic": true,
		"base_spread_deg": 1.8,
		"max_spread_deg": 10.0,
		"spread_per_shot_deg": 0.42,
		"spread_recovery_deg": 9.0,
		"moving_spread_multiplier": 1.15,
		"injured_spread_multiplier": 1.3,
		"loaf_spread_multiplier": 0.72,
		"recoil_kick": 0.16,
		"loaf_recoil_multiplier": 0.65,
		"player_knockback": 0.025,
		"penetration_count": 0,
		"durability_loss": 0.038,
		"reload_time": 1.7,
		"sound_radius": 43.0,
		"roll_ready": true,
	},
	"ak47": {
		"display_name": "AK-47 \"캣라시니코프\"",
		"category": "소총",
		"ammo_type": "762x39",
		"magazine_id": "ak_30rnd",
		"default_ammo_id": "762_fmj",
		"magazine_size": 30,
		# 30으로 상향(24였다). MP5가 DPS·반동·명중·재장전 전부에서 앞서 시작 무기가
		# 하위호환이었다. AK는 "적은 발수, 묵직한 한 방 + 사거리/관통" 정체성으로 간다.
		# 존1 중심 명중 기준 4발 → 3발 킬.
		"damage": 30,
		"pellet_count": 1,
		"fire_interval": 0.12,
		"automatic": true,
		"base_spread_deg": 2.4,
		"max_spread_deg": 14.0,
		"spread_per_shot_deg": 1.25,
		"spread_recovery_deg": 5.2,
		"moving_spread_multiplier": 1.8,
		"injured_spread_multiplier": 1.4,
		"loaf_spread_multiplier": 0.45,
		"recoil_kick": 0.72,
		"loaf_recoil_multiplier": 0.28,
		"player_knockback": 0.18,
		"penetration_count": 1,
		"durability_loss": 0.065,
		"reload_time": 2.15,
		"sound_radius": 52.0,
	},
	"double_barrel": {
		"display_name": "Double-Barrel \"참치 헌터\"",
		"category": "산탄총",
		"ammo_type": "12g",
		"magazine_id": "double_barrel_chamber",
		"default_ammo_id": "12g_buckshot",
		"magazine_size": 2,
		"damage": 18,
		"pellet_count": 8,
		"fire_interval": 0.58,
		"automatic": false,
		"base_spread_deg": 7.0,
		"max_spread_deg": 18.0,
		"spread_per_shot_deg": 4.5,
		"spread_recovery_deg": 4.0,
		"moving_spread_multiplier": 1.5,
		"injured_spread_multiplier": 1.45,
		"loaf_spread_multiplier": 0.7,
		"recoil_kick": 1.4,
		"loaf_recoil_multiplier": 0.55,
		"player_knockback": 0.85,
		"penetration_count": 0,
		"durability_loss": 0.12,
		"reload_time": 2.8,
		"sound_radius": 58.0,
	},
}

const MAGAZINES := {
	"m1911_7rnd": {"caliber": "45_acp", "capacity": 7, "weapons": ["m1911"]},
	"mp5_30rnd": {"caliber": "9mm", "capacity": 30, "weapons": ["mp5"]},
	"ak_30rnd": {"caliber": "762x39", "capacity": 30, "weapons": ["ak47"]},
	"double_barrel_chamber": {"caliber": "12g", "capacity": 2, "weapons": ["double_barrel"]},
}

const AMMO_TYPES := {
	"9mm_fmj": {"display_name": "9mm 보통탄", "caliber": "9mm", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"9mm_ap": {"display_name": "9mm AP탄", "caliber": "9mm", "damage_multiplier": 0.92, "penetration": 1, "tier": 3},
	"45_fmj": {"display_name": ".45 ACP 보통탄", "caliber": "45_acp", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"45_ap": {"display_name": ".45 ACP 철갑탄", "caliber": "45_acp", "damage_multiplier": 0.9, "penetration": 1, "tier": 3},
	"762_fmj": {"display_name": "7.62mm 보통탄", "caliber": "762x39", "damage_multiplier": 1.0, "penetration": 1, "tier": 2},
	"762_ap": {"display_name": "7.62mm AP탄", "caliber": "762x39", "damage_multiplier": 0.95, "penetration": 2, "tier": 4},
	"12g_buckshot": {"display_name": "12게이지 벅샷", "caliber": "12g", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"12g_slug": {"display_name": "12게이지 슬러그", "caliber": "12g", "damage_multiplier": 1.7, "penetration": 1, "tier": 3},
}

const MODS := {
	"laser_pointer": {
		"display_name": "레이저 포인터",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.65, "spread_recovery_deg": 1.2},
	},
	"scope_2x": {
		"display_name": "폐점포 2x 스코프",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.78, "spread_recovery_deg": 1.1},
		"overrides": {"scope_zoom": 2.0, "scope_shift": 5.5},
	},
	"scope_4x": {
		"display_name": "망원경 4x 스코프",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.62, "moving_spread_multiplier": 1.18},
		"overrides": {"scope_zoom": 4.0, "scope_shift": 10.0},
	},
	"muffled_sock": {
		"display_name": "소리 방지용 양말",
		"slot": "muzzle",
		"multipliers": {"sound_radius": 0.5, "durability_loss": 1.6},
	},
	"sponge_pad": {
		"display_name": "스펀지 턱받이",
		"slot": "stock",
		"multipliers": {"loaf_spread_multiplier": 0.6, "spread_recovery_deg": 1.15},
	},
	"quick_mag": {
		"display_name": "테이프 듀얼 탄창",
		"slot": "magazine",
		"multipliers": {"reload_time": 0.7, "movement_sound_multiplier": 1.1},
	},
	"bell_bait": {
		"display_name": "딸랑이 방울",
		"slot": "tactical",
		"multipliers": {"sound_radius": 1.2},
		"sound_decoy": true,
	},
	"m1911_last_stand_slide": {
		"display_name": "M1911 최후 저항 슬라이드",
		"slot": "special",
		"compatible_weapons": ["m1911"],
		"multipliers": {"damage": 1.18, "fire_interval": 0.86, "recoil_kick": 1.2},
	},
	"mp5_overdrive_bolt": {
		"display_name": "MP5 과급 노리쇠",
		"slot": "special",
		"compatible_weapons": ["mp5"],
		"multipliers": {"damage": 1.12, "fire_interval": 0.74, "spread_per_shot_deg": 1.3, "durability_loss": 1.65},
	},
	"ak_precision_receiver": {
		"display_name": "AK 정밀 단발 리시버",
		"slot": "special",
		"compatible_weapons": ["ak47"],
		"multipliers": {"damage": 1.15, "base_spread_deg": 0.42, "recoil_kick": 0.72},
		"overrides": {"automatic": false, "fire_interval": 0.28, "special_mechanic": "precision_semi_auto"},
	},
	"double_barrel_cluster_choke": {
		"display_name": "참치통 확산 초크",
		"slot": "special",
		"compatible_weapons": ["double_barrel"],
		"multipliers": {"damage": 0.82, "base_spread_deg": 0.8},
		"additives": {"pellet_count": 4},
		"overrides": {"special_mechanic": "cluster_blast"},
	},
}


static func get_weapon(weapon_id: String) -> Dictionary:
	var definition: Dictionary = WEAPONS.get(weapon_id, WEAPONS[DEFAULT_WEAPON_ID])
	return definition.duplicate(true)


static func get_mod(mod_id: String) -> Dictionary:
	var definition: Dictionary = MODS.get(mod_id, {})
	return definition.duplicate(true)


static func build_stats(
	weapon_id: String,
	mod_ids: Array[String],
	enhancement_level: int = 0,
	mod_enhancement_levels: Dictionary = {}
) -> Dictionary:
	var stats := get_weapon(weapon_id)
	stats["weapon_id"] = weapon_id
	stats["movement_sound_multiplier"] = 1.0
	stats["scope_zoom"] = 1.0
	stats["scope_shift"] = 0.0
	var magazine := get_magazine(str(stats.get("magazine_id", "")))
	if not magazine.is_empty():
		stats["magazine_size"] = int(magazine.get("capacity", stats.get("magazine_size", 0)))
	var occupied_slots: Dictionary = {}
	for mod_id in mod_ids:
		var mod_definition := get_mod(mod_id)
		if mod_definition.is_empty():
			continue
		var compatible_weapons: Array = mod_definition.get("compatible_weapons", [])
		if not compatible_weapons.is_empty() and not compatible_weapons.has(weapon_id):
			continue
		var slot := str(mod_definition.get("slot", ""))
		if occupied_slots.has(slot):
			continue
		occupied_slots[slot] = mod_id
		var mod_level := clampi(int(mod_enhancement_levels.get(mod_id, 0)), 0, 99)
		var mod_power := 1.0 + float(mod_level) * 0.012
		var multipliers: Dictionary = mod_definition.get("multipliers", {})
		for stat_name in multipliers:
			var base_multiplier := float(multipliers[stat_name])
			var enhanced_multiplier := maxf(0.1, 1.0 + (base_multiplier - 1.0) * mod_power)
			stats[stat_name] = float(stats.get(stat_name, 1.0)) * enhanced_multiplier
		var additives: Dictionary = mod_definition.get("additives", {})
		for stat_name in additives:
			stats[stat_name] = float(stats.get(stat_name, 0.0)) + float(additives[stat_name]) * mod_power
		var overrides: Dictionary = mod_definition.get("overrides", {})
		for stat_name in overrides:
			stats[stat_name] = overrides[stat_name]
	var level := clampi(enhancement_level, 0, 99)
	if level > 0:
		stats["damage"] = float(stats.get("damage", 1.0)) * (1.0 + float(level) * 0.035)
		stats["base_spread_deg"] = float(stats.get("base_spread_deg", 2.0)) * maxf(0.72, 1.0 - float(level) * 0.003)
		stats["recoil"] = float(stats.get("recoil", 1.0)) * maxf(0.76, 1.0 - float(level) * 0.0025)
		stats["durability_loss"] = float(stats.get("durability_loss", 1.0)) * maxf(0.55, 1.0 - float(level) * 0.0045)
	stats["enhancement_level"] = level
	return stats


static func validate_mod_loadout(mod_ids: Array[String], weapon_id: String = "") -> bool:
	var occupied_slots: Dictionary = {}
	for mod_id in mod_ids:
		var definition := get_mod(mod_id)
		if definition.is_empty():
			return false
		var compatible_weapons: Array = definition.get("compatible_weapons", [])
		if not weapon_id.is_empty() and not compatible_weapons.is_empty() and not compatible_weapons.has(weapon_id):
			return false
		var slot := str(definition.get("slot", ""))
		if occupied_slots.has(slot):
			return false
		occupied_slots[slot] = true
	return true


static func get_magazine(magazine_id: String) -> Dictionary:
	var definition: Dictionary = MAGAZINES.get(magazine_id, {})
	return definition.duplicate(true)


static func get_ammo(ammo_id: String) -> Dictionary:
	var definition: Dictionary = AMMO_TYPES.get(ammo_id, {})
	return definition.duplicate(true)


static func is_magazine_compatible(weapon_id: String, magazine_id: String) -> bool:
	var magazine := get_magazine(magazine_id)
	return not magazine.is_empty() and (magazine.get("weapons", []) as Array).has(weapon_id)


static func is_ammo_compatible(magazine_id: String, ammo_id: String) -> bool:
	var magazine := get_magazine(magazine_id)
	var ammo := get_ammo(ammo_id)
	return (
		not magazine.is_empty()
		and not ammo.is_empty()
		and str(magazine.get("caliber", "")) == str(ammo.get("caliber", ""))
	)


static func validate_ammo_loadout(weapon_id: String, magazine_id: String, ammo_id: String) -> bool:
	return is_magazine_compatible(weapon_id, magazine_id) and is_ammo_compatible(magazine_id, ammo_id)