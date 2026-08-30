extends SceneTree

# 가방 무제한(2026-08-30) 스모크 — 칸·용량·만재 판정은 전부 폐지됐다.
# 이 파일은 "무엇을 얼마나 넣어도 들어간다"와, 남은 예외(특별 화물 1개 규칙,
# amount<=0 거부)와, 칸을 대체한 훈련 효과(탄약 획득 배율)를 검증한다.


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

	# ① 무엇을 얼마나 들든 can_add는 true — 만재 판정 자체가 없다.
	assert(state.can_add_raid_item("component", "scope_lens", 9999),
		"Unlimited bag must accept any component amount.")
	assert(state.can_add_raid_item("ammo", "762_fmj", 100000),
		"Unlimited bag must accept any ammo amount.")
	assert(state.can_add_raid_item("food", "canned_food", 500),
		"Unlimited bag must accept any food amount.")
	assert(state.can_add_raid_item("weapon", "m1911", 3),
		"Unlimited bag must accept weapons.")
	var big_batch: Array[Dictionary] = [
		{"type": "ammo", "id": "9mm_fmj", "amount": 5000},
		{"type": "component", "id": "magazine_spring", "amount": 300},
	]
	assert(state.can_add_raid_items(big_batch),
		"Batch pickups must always pass — no slot math remains.")

	# ② try_add도 무제한으로 성공하고, 잔고가 정확히 쌓인다.
	assert(state.try_add_raid_item("component", "rubber_gasket", 500),
		"Adding 500 components must succeed.")
	assert(int(state.get_mod_component_count("rubber_gasket")) == 500,
		"Component balance must be exactly 500.")
	assert(state.try_add_raid_item("ammo", "762_fmj", 50000),
		"Adding 50000 rounds must succeed.")
	assert(int(state.get_ammo_count("762_fmj")) == 50000,
		"Ammo balance must be exactly 50000.")

	# ③ amount<=0 만은 거부한다 — 0개 획득은 버그다.
	assert(not state.can_add_raid_item("component", "scope_lens", 0),
		"Zero-amount pickups must be rejected.")
	assert(not state.can_add_raid_item("ammo", "762_fmj", -5),
		"Negative-amount pickups must be rejected.")

	# ④ 특별 화물 — 유일하게 남은 제한: 동시에 하나만(중복 화물 방지, 만재 검사가 아니다).
	var cargo := {
		"id": "seoul_line3_relief_core",
		"title": "Seoul Line 3 Relief Core",
	}
	assert(state.can_add_raid_item("special_cargo", str(cargo.id), 1),
		"An empty cargo hold must accept story cargo.")
	assert(state.try_take_story_cargo(cargo))
	assert(not state.can_add_raid_item("special_cargo", "another_cargo", 1),
		"A second story cargo must be rejected while one is carried.")
	var completed: Dictionary = state.complete_story_cargo()
	assert(str(completed.get("id", "")) == "seoul_line3_relief_core")
	assert(state.can_add_raid_item("special_cargo", "another_cargo", 1),
		"After completing the cargo, a new one must be acceptable again.")

	# ⑤ 탄약 휴대 훈련 — 칸당 발수 대신 필드 획득량 배율(+15%/랭크)이 됐다.
	state.training_levels["ammo_carry"] = 0
	assert(is_equal_approx(float(state.get_ammo_pickup_multiplier()), 1.0),
		"Rank 0 must give the 1.0 baseline pickup multiplier.")
	state.training_levels["ammo_carry"] = 2
	assert(is_equal_approx(float(state.get_ammo_pickup_multiplier()), 1.3),
		"Rank 2 must give 1.0 + 0.15 x 2 = 1.3.")
	state.training_levels["ammo_carry"] = 0

	# ⑥ 폐지된 칸 계산 API는 흔적도 없어야 한다 — 되살아나면 여기서 잡는다.
	assert(not state.has_method("get_raid_bag_capacity"),
		"get_raid_bag_capacity was abolished with the slot system.")
	assert(not state.has_method("get_raid_bag_used_slots"),
		"get_raid_bag_used_slots was abolished with the slot system.")
	assert(not state.has_method("get_raid_item_slot_cost"),
		"get_raid_item_slot_cost was abolished with the slot system.")
	assert(not state.has_method("get_ammo_rounds_per_slot"),
		"get_ammo_rounds_per_slot was abolished with the slot system.")

	# 뒷정리 — 다른 테스트가 이어 돌아도 흔적이 없게.
	state.mod_component_inventory.clear()
	state.ammo_inventory.clear()
	state.raid_special_cargo.clear()

	print("RAID_BAG_CAPACITY_OK")
	quit(0)
