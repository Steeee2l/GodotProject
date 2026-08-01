extends SceneTree

const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")


func _init() -> void:
	assert(RAID_ITEM_ECONOMY.get_total_value("food", "canned_food", 4) == 140)
	assert(RAID_ITEM_ECONOMY.get_total_value("ammo", "762_fmj", 5) > 0)
	assert(RAID_ITEM_ECONOMY.is_protected("progression", "rifle_blueprint"))
	assert(RAID_ITEM_ECONOMY.is_protected("special_cargo", "sealed_subway_cargo"))
	assert(not RAID_ITEM_ECONOMY.is_protected("component", "scope_lens"))
	quit()
