class_name WeaponVisualCatalog
extends RefCounted


const CATALOG := {
	"m1911": {
		"display_name": "M1911",
		"texture_path": "res://assets/weapons/catalog/generated/m1911.png",
		"world_pixel_size": 0.00068,
	},
	"ak47": {
		"display_name": "AK-47",
		"texture_path": "res://assets/weapons/catalog/generated/ak47.png",
		"world_pixel_size": 0.001,
	},
	"mp5": {
		"display_name": "MP5",
		"texture_path": "res://assets/weapons/catalog/generated/mp5.png",
		"world_pixel_size": 0.0009,
	},
	"double_barrel": {
		"display_name": "더블배럴 산탄총",
		"texture_path": "res://assets/weapons/catalog/generated/double_barrel.png",
		"world_pixel_size": 0.0009,
	},
	"baseball_bat": {
		"display_name": "야구 방망이",
		"texture_path": "res://assets/weapons/catalog/generated/baseball_bat.png",
		"world_pixel_size": 0.00058,
	},
	"rocket_launcher": {
		"display_name": "로켓런처",
		"texture_path": "res://assets/weapons/catalog/generated/rocket_launcher.png",
		"world_pixel_size": 0.001,
	},
}

const FUTURE_CATALOG := {
	"rifle_bullpup": "res://assets/weapons/catalog/rifle_bullpup.png",
	"rifle_ar_platform": "res://assets/weapons/catalog/rifle_ar_platform.png",
	"smg_uzi": "res://assets/weapons/catalog/smg_uzi.png",
	"rifle_ak_grenadier": "res://assets/weapons/catalog/rifle_ak_grenadier.png",
	"smg_compact": "res://assets/weapons/catalog/smg_compact.png",
	"rifle_coil_mod": "res://assets/weapons/catalog/rifle_coil_mod.png",
	"shotgun_tactical": "res://assets/weapons/catalog/shotgun_tactical.png",
}


static func has_weapon_texture(weapon_id: String) -> bool:
	return CATALOG.has(weapon_id)


static func get_weapon_texture(weapon_id: String) -> Texture2D:
	var entry: Dictionary = CATALOG.get(weapon_id, {})
	var texture_path := str(entry.get("texture_path", ""))
	if texture_path.is_empty():
		return null
	return load(texture_path) as Texture2D


static func get_world_pixel_size(weapon_id: String, fallback: float = 0.0042) -> float:
	var entry: Dictionary = CATALOG.get(weapon_id, {})
	return float(entry.get("world_pixel_size", fallback))


static func get_inventory_textures() -> Dictionary:
	var textures := {}
	for weapon_id in CATALOG:
		textures[weapon_id] = get_weapon_texture(weapon_id)
	return textures