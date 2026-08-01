extends SceneTree

const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")


func _init() -> void:
	var loot := {
		"ammo_inventory": {"762_fmj": 12},
		"medkits": 2,
		"canned_food": 3,
		"churu": 0,
		"mod_component_inventory": {"scope_lens": 1},
		"progression_item_inventory": {},
		"weapon_mod_inventory": {},
		"weapon_inventory": {"ak47": 1},
		"equipment_inventory": {},
		"raid_special_cargo": {},
	}
	assert(RAID_LOSS_MANAGER.get_item_count(loot) == 19)
	assert(RAID_LOSS_MANAGER.get_total_value(loot) > 0)
	assert(RAID_LOSS_MANAGER.format_loss_summary(loot).contains("통조림 3개"))
	print("raid_loss_manager_smoke_test: PASS")
	quit()
