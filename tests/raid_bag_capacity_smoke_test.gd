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

    # 기본 12칸 + 확장 사다리. 레벨을 0으로 고정해 기준을 검증한다.
    state.bag_capacity_level = 0
    assert(int(state.get_raid_bag_capacity()) == 12)
    # 인크리멘탈 사다리: 고철로 +1칸, 비용은 점증한다.
    state.scrap = 100000
    var first_cost: int = state.get_bag_upgrade_cost()
    assert(first_cost > 0)
    assert(state.try_upgrade_bag_capacity())
    assert(int(state.get_raid_bag_capacity()) == 13)
    assert(int(state.get_bag_upgrade_cost()) > first_cost)
    state.bag_capacity_level = 0
    state.scrap = 0
    # 탄약은 칸당 발수 상한(기본 240, '탄약 휴대' 훈련으로 +25%/랭크)이 생겼다 —
    # 600발이면 3칸, 240발 이하면 예전처럼 1칸. 훈련이 의미를 가지려면 상한이 필요했다.
    state.training_levels["ammo_carry"] = 0
    state.set_ammo_count("762_fmj", 600)
    assert(int(state.get_raid_bag_used_slots()) == 3, "600 rounds = 3 slots at 240 rounds per slot.")
    state.training_levels["ammo_carry"] = 2
    assert(int(state.get_ammo_rounds_per_slot()) == 360, "ammo_carry rank 2 must give 240 x 1.5 rounds per slot.")
    assert(int(state.get_raid_bag_used_slots()) == 2, "600 rounds at 360 per slot = 2 slots.")
    state.training_levels["ammo_carry"] = 0
    state.set_ammo_count("762_fmj", 240)
    assert(int(state.get_raid_bag_used_slots()) == 1, "Up to 240 rounds of one ammo type stay in one bag slot.")
    state.canned_food = 250
    assert(int(state.get_raid_bag_used_slots()) == 2, "Canned food must stay in one bag slot.")
    state.add_weapon("mp5", 3)
    # 첫 획득 무기는 기본 탄약 2탄창이 따라온다 — 슬롯 산수만 보는 테스트라 비운다.
    state.set_ammo_count("9mm_fmj", 0)
    # 2026-08 경제 코어: 무기·방어구는 영구 귀속 장비라 가방 칸 0(장착 교체용으로만 보인다).
    # 예전 "무기 1정 = 1칸 / 장비 1개 = 1칸" 어서션은 그 규칙과 함께 폐지됐다.
    assert(int(state.get_raid_item_slot_cost("weapon", "mp5", 3)) == 0, "Weapons take no bag slots.")
    assert(int(state.get_raid_bag_used_slots()) == 2, "Unequipped weapons must not use bag slots.")
    state.add_equipment("scav_vest", 2)
    assert(int(state.get_raid_item_slot_cost("equipment", "scav_vest", 2)) == 0, "Equipment takes no bag slots.")
    assert(int(state.get_raid_bag_used_slots()) == 2, "Equipment must not use bag slots.")
    state.add_mod_component("scope_lens", 3)
    # 재료 1개 = 1칸 — 부품 3개면 3칸이다.
    assert(int(state.get_raid_bag_used_slots()) == 5, "Each component unit must use one bag slot.")

    state.weapon_inventory.clear()
    state.ammo_inventory.clear()
    state.equipment_inventory.clear()
    state.canned_food = 0
    state.mod_component_inventory.clear()
    # 만재 12칸 — 무기는 0칸이라 부품 11개 + 탄약 1칸으로 채운다(옛 MP5 11정 시나리오 대체).
    state.add_mod_component("rubber_gasket", 11)
    state.set_ammo_count("9mm_fmj", 0)
    # 칸당 240발 상한 아래(200발)라 1칸 — 12칸 만재 시나리오는 그대로 성립한다.
    state.set_ammo_count("762_fmj", 200)
    assert(int(state.get_raid_bag_used_slots()) == 12)
    assert(state.can_add_raid_item("weapon", "m1911", 1), "Weapons (0 slots) always fit even in a full bag.")
    assert(not state.can_add_raid_item("component", "scope_lens", 1), "A full bag must reject another component.")
    assert(state.can_add_raid_item("ammo", "762_fmj", 30), "An existing ammo stack must accept more rounds.")
    assert(not state.can_add_raid_item("ammo", "762_fmj", 60), "Rounds past the per-slot cap need a free slot.")
    assert(not state.can_add_raid_item("ammo", "9mm_fmj", 1), "A new ammo type needs a free slot.")

    assert(int(state.remove_raid_bag_item("component", "rubber_gasket", 1)) == 1)
    assert(int(state.get_raid_bag_used_slots()) == 11)
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
    # 메인 미션 회수물은 가방과 무관하다(유저 신고) — 칸 0, 만재여도 먹힌다.
    state.add_mod_component("rubber_gasket", 12)
    state.set_ammo_count("9mm_fmj", 0)
    assert(int(state.get_raid_bag_used_slots()) == 12, "bag is full before taking story cargo")
    assert(state.can_add_raid_item("special_cargo", str(cargo.id), 1), "Story cargo ignores a full bag.")
    assert(state.try_take_story_cargo(cargo))
    assert(int(state.get_raid_bag_used_slots()) == 12, "Story cargo must not use a bag slot.")
    assert(not state.can_add_raid_item("special_cargo", "another_cargo", 1))
    state.mod_component_inventory.clear()
    state.ammo_inventory.clear()
    assert(int(state.get_raid_bag_used_slots()) == 0)
    assert(int(state.remove_raid_bag_item("special_cargo", "seoul_line3_relief_core", 1)) == 1)
    assert(int(state.get_raid_bag_used_slots()) == 0)

    print("RAID_BAG_CAPACITY_OK")
    quit(0)
