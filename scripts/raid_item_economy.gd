class_name RaidItemEconomy
extends RefCounted

const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")

const FALLBACK_VALUES := {
	"churu": {"base_value": 1500, "slot_size": 1},
	"mod": {"base_value": 320, "slot_size": 1},
	"special_cargo": {"base_value": 5000, "slot_size": 6},
}


static func get_definition(
	item_type: String,
	item_id: String,
	special_data: Dictionary = {}
) -> Dictionary:
	if item_type == "special_cargo":
		return {
			"base_value": maxi(1, int(special_data.get("base_value", 5000))),
			"slot_size": maxi(1, int(special_data.get("slot_size", 6))),
		}
	var catalog_id := _catalog_id(item_type, item_id)
	if LOOT_ECONOMY.ITEM_CATALOG.has(catalog_id):
		return (LOOT_ECONOMY.ITEM_CATALOG[catalog_id] as Dictionary).duplicate(true)
	var fallback: Dictionary = FALLBACK_VALUES.get(
		item_type,
		{"base_value": 100, "slot_size": 1}
	) as Dictionary
	return fallback.duplicate(true)


static func get_total_value(
	item_type: String,
	item_id: String,
	amount: int,
	special_data: Dictionary = {}
) -> int:
	var definition := get_definition(item_type, item_id, special_data)
	return maxi(0, amount) * maxi(0, int(definition.get("base_value", 0)))


static func is_protected(item_type: String, item_id: String) -> bool:
	# 무기·방어구는 영구 귀속 장비(제작 전용·0칸)라 가방 교체 UI에서 버릴 대상이 아니다.
	if item_type in ["progression", "special_cargo", "weapon", "equipment"]:
		return true
	return item_id.contains("blueprint") or item_id.contains("keycard")


static func _catalog_id(item_type: String, item_id: String) -> String:
	match item_type:
		"ammo":
			return "ammo_%s" % item_id
		"food":
			return "canned_food"
		"medkit":
			return "medkit"
	return item_id
