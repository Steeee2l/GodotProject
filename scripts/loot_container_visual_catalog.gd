class_name LootContainerVisualCatalog
extends RefCounted

const DEFINITIONS := {
	"street_cache": {
		"texture_path": "res://assets/loot/containers/street_cache_v1.png",
		"world_width": 1.55,
		"world_height": 0.82,
		"open_duration": 0.55,
		"icon": "backpack",
	},
	"ammo_case": {
		"texture_path": "res://assets/loot/containers/ammo_case_v1.png",
		"world_width": 1.45,
		"world_height": 0.72,
		"open_duration": 0.85,
		"icon": "ammo",
	},
	"toolbox": {
		"texture_path": "res://assets/loot/containers/toolbox_v1.png",
		"world_width": 1.35,
		"world_height": 0.76,
		"open_duration": 1.05,
		"icon": "parts",
	},
	"clothing_cache": {
		"texture_path": "res://assets/loot/containers/clothing_cache_v1.png",
		"world_width": 1.62,
		"world_height": 0.74,
		"open_duration": 0.70,
		"icon": "armor",
	},
	"weapon_case": {
		"texture_path": "res://assets/loot/containers/weapon_case_v1.png",
		"world_width": 2.15,
		"world_height": 0.66,
		"open_duration": 1.45,
		"icon": "weapon",
	},
	"secure_cache": {
		"texture_path": "res://assets/loot/containers/secure_cache_v1.png",
		"world_width": 1.82,
		"world_height": 0.92,
		"open_duration": 2.10,
		"icon": "secure",
	},
}


static func get_definition(container_type: String) -> Dictionary:
	return (DEFINITIONS.get(container_type, DEFINITIONS["street_cache"]) as Dictionary).duplicate(true)


static func get_container_types() -> Array[String]:
	var result: Array[String] = []
	for container_type in DEFINITIONS.keys():
		result.append(str(container_type))
	return result
