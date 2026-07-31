extends SceneTree

const LOOT_SWAP_UI := preload("res://scripts/loot_swap_ui.gd")
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")


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
    state.set_ammo_count("762_fmj", 60)
    assert(int(state.get_raid_bag_used_slots()) == 1, "Sixty rifle rounds must stack into one slot.")
    state.set_ammo_count("762_fmj", 61)
    assert(int(state.get_raid_bag_used_slots()) == 2, "The sixty-first rifle round must open a second slot.")
    state.set_ammo_count("762_fmj", 60)

    state.add_weapon("mp5", 1)
    assert(int(state.get_raid_bag_used_slots()) == 9, "An unequipped MP5 must occupy eight slots.")
    state.medkits = 2
    state.canned_food = 4
    state.churu = 2
    state.add_mod_component("scope_lens", 3)
    state.add_progression_item("rifle_blueprint", 1)
    state.add_mod_component("rubber_gasket", 3)
    assert(int(state.get_raid_bag_used_slots()) == 15)
    assert(not state.can_add_raid_item("weapon", "m1911", 1), "A full bag must reject a six-slot pistol.")

    assert(int(state.remove_raid_bag_item("food", "canned_food", 4)) == 4)
    assert(int(state.get_raid_bag_used_slots()) == 14)
    assert(state.can_add_raid_item("ammo", "762_fmj", 1), "Freeing one slot must allow the next ammo stack.")

    state.weapon_inventory.clear()
    state.ammo_inventory.clear()
    state.mod_component_inventory.clear()
    state.progression_item_inventory.clear()
    state.medkits = 0
    state.canned_food = 0
    state.churu = 0
    var cargo := {
        "id": "seoul_line3_relief_core",
        "title": "서울 지하선 3번 보급 코어",
        "slot_size": 6,
    }
    assert(state.try_take_story_cargo(cargo))
    assert(int(state.get_raid_bag_used_slots()) == 6)

    var ui := LOOT_SWAP_UI.new()
    root.add_child(ui)
    ui.setup(FONT)
    ui.open({
        "title": "서울 지하선 3번 보급 코어",
        "description": "살아서 탈출해야 열 수 있는 봉인 화물",
        "texture": load("res://assets/events/subway_sealed_cargo_v2.png"),
        "required_slots": 6,
    }, [{
        "type": "ammo",
        "id": "762_fmj",
        "title": "7.62mm FMJ 탄환",
        "count": 60,
        "slot_cost": 1,
        "drop_amount": 60,
        "texture": null,
    }], 15, 15)
    assert(ui.visible)
    assert(ui.capacity_cells.get_child_count() == 15)
    assert(ui.claim_button.disabled)
    assert(ui.candidate_detail.text.contains("6칸"))

    print("RAID_BAG_CAPACITY_OK")
    quit(0)
