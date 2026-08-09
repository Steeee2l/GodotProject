extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var state := root.get_node("GameState")
    state.set("persistence_enabled", false)
    state.weapon_inventory.clear()
    state.equipment_inventory.clear()
    state.ammo_inventory.clear()
    state.mod_component_inventory.clear()
    state.progression_item_inventory.clear()
    state.weapon_mod_inventory.clear()
    state.storage_inventory.clear()
    state.raid_special_cargo.clear()
    state.has_ak = false
    state.equipped_weapon_id = ""
    state.medkits = 0
    state.canned_food = 0
    state.churu = 0

    assert(int(state.get_raid_bag_capacity()) == 15)
    state.set_ammo_count("762_fmj", 600)
    assert(int(state.get_raid_bag_used_slots()) == 1, "One ammo type must stay in one bag slot.")
    state.canned_food = 250
    assert(int(state.get_raid_bag_used_slots()) == 2, "Canned food must stay in one bag slot.")
    state.add_weapon("mp5", 3)
    assert(int(state.get_raid_bag_used_slots()) == 5, "Each unequipped weapon must use one slot.")
    state.add_equipment("scav_vest", 2)
    assert(int(state.get_raid_bag_used_slots()) == 7, "Each equipment item must use one slot.")
    state.add_mod_component("scope_lens", 999)
    assert(int(state.get_raid_bag_used_slots()) == 8, "One component type must stay in one slot.")

    state.weapon_inventory.clear()
    state.ammo_inventory.clear()
    state.equipment_inventory.clear()
    state.canned_food = 0
    state.mod_component_inventory.clear()
    state.add_weapon("mp5", 14)
    state.set_ammo_count("762_fmj", 600)
    assert(int(state.get_raid_bag_used_slots()) == 15)
    assert(not state.can_add_raid_item("weapon", "m1911", 1), "A full bag must reject another weapon.")
    assert(state.can_add_raid_item("ammo", "762_fmj", 30), "An existing ammo stack must accept more rounds.")
    assert(not state.can_add_raid_item("ammo", "9mm_fmj", 1), "A new ammo type needs a free slot.")

    assert(int(state.remove_raid_bag_item("weapon", "mp5", 1)) == 1)
    assert(int(state.get_raid_bag_used_slots()) == 14)
    assert(state.can_add_raid_item("ammo", "9mm_fmj", 1), "Freeing one slot must allow a new stack.")
    # can_add_raid_items takes Array[Dictionary]; an untyped literal is rejected.
    var same_stack_batch: Array[Dictionary] = [
        {"type": "ammo", "id": "9mm_fmj", "amount": 30},
        {"type": "ammo", "id": "9mm_fmj", "amount": 30},
    ]
    assert(state.can_add_raid_items(same_stack_batch),
        "Repeated items in one loot container must share one new slot.")
    var mixed_stack_batch: Array[Dictionary] = [
        {"type": "ammo", "id": "9mm_fmj", "amount": 30},
        {"type": "component", "id": "magazine_spring", "amount": 1},
    ]
    assert(not state.can_add_raid_items(mixed_stack_batch),
        "Different new stacks in one loot container need separate free slots.")

    state.weapon_inventory.clear()
    state.ammo_inventory.clear()
    state.mod_component_inventory.clear()
    state.progression_item_inventory.clear()
    state.medkits = 0
    state.canned_food = 0
    state.churu = 0
    var cargo := {
        "id": "seoul_line3_relief_core",
        "title": "Seoul Line 3 Relief Core",
    }
    assert(state.try_take_story_cargo(cargo))
    assert(int(state.get_raid_bag_used_slots()) == 1)
    assert(not state.can_add_raid_item("special_cargo", "another_cargo", 1))
    assert(int(state.remove_raid_bag_item("special_cargo", "seoul_line3_relief_core", 1)) == 1)
    assert(int(state.get_raid_bag_used_slots()) == 0)

    print("RAID_BAG_CAPACITY_OK")
    quit(0)
