extends SceneTree

# 잉여 장비 분해(귀환 정산) 스모크 테스트 — 헤드리스.
#   godot --headless --path . --script res://tests/armor_salvage_smoke_test.gd
#
# ① 가방 T1 조끼 3·헬멧 2·T2 조끼 1(장착 T1 조끼), AK 2정(장착 1)
#    → 장착 조끼 유지 + 예비 최고(T2 조끼) 보존, T1 조끼 3·헬멧 1·AK 1 분해 = 5점 → 부품 5개
#    (부품 종류는 패킹→스프링→렌즈 순환)
# ② 상위 레벨 예비가 최고 — scav_vest@3 1 + scav_vest 2 → @3 보존, 2 분해
# ③ 창고 포함 — 창고 T2 헬멧 1 + 가방 T1 헬멧 2 → 창고 T2 보존, 가방 T1 2 분해
# ④ 장착 가능한 상위 장비는 절대 분해되지 않는다 — 장착 T1, 예비 T3 1 + T2 2 → T3 보존, T2 2 분해(부품 4)
# ⑤ 사다리 밖 기종(MP5) 중복은 건드리지 않는다 / 두 번째 분해는 0
# ⑥ settle_shelter_return_inventory 통합 — 보고서 키 + 부품이 창고로 입고

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	# ① 기본 시나리오(유저 프로브 그대로)
	_reset_gear(game_state)
	game_state.call("add_equipment", "scav_vest", 4)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "patched_helmet", 2)
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.set("weapon_inventory", {"ak47": 2})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	var report: Dictionary = game_state.call("salvage_surplus_equipment")
	print("  ① REPORT=%s" % JSON.stringify(report))
	_check(int(report.get("items", 0)) == 5, "① 분해 5점 (got %d)" % int(report.get("items", 0)))
	_check(int(report.get("armor_items", 0)) == 4 and int(report.get("weapon_items", 0)) == 1, "① 방어구 4 · 무기 1")
	_check(int(report.get("components", 0)) == 5, "① 부품 5개 (T1×4 + AK 1단) (got %d)" % int(report.get("components", 0)))
	_check(str(game_state.get("equipped_body_armor_id")) == "scav_vest", "① 장착 조끼 유지")
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 0, "① 예비 T1 조끼 전부 분해")
	_check(int(game_state.call("get_equipment_count", "riot_vest")) == 1, "① 예비 최고(T2 조끼) 보존")
	_check(int(game_state.call("get_equipment_count", "patched_helmet")) == 1, "① 헬멧 1 보존")
	_check(int(game_state.call("get_weapon_count", "ak47")) == 1, "① AK 2정 → 1정(장착분)")
	_check(str(game_state.get("equipped_weapon_id")) == "ak47" and bool(game_state.get("has_ak")), "① 장착 AK 유지")
	var parts := game_state.get("mod_component_inventory") as Dictionary
	_check(
		int(parts.get("rubber_gasket", 0)) == 2 and int(parts.get("magazine_spring", 0)) == 2 and int(parts.get("scope_lens", 0)) == 1,
		"① 부품 순환 패킹 2 · 스프링 2 · 렌즈 1 (got %s)" % JSON.stringify(parts)
	)

	# ② 상위 레벨 예비가 최고
	_reset_gear(game_state)
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("equip_equipment", "riot_vest")
	game_state.call("add_equipment", "scav_vest@3", 1)
	game_state.call("add_equipment", "scav_vest", 2)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 2 and int(report.get("components", 0)) == 2, "② T1 조끼 2 분해 → 부품 2")
	_check(int(game_state.call("get_equipment_count", "scav_vest@3")) == 1, "② scav_vest@3 보존")
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 0, "② 레벨 1 조끼 분해")

	# ③ 창고 포함
	_reset_gear(game_state)
	(game_state.get("storage_inventory") as Array).append({"type": "equipment", "id": "tactical_helmet", "count": 1})
	game_state.call("add_equipment", "patched_helmet", 2)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 2 and int(report.get("components", 0)) == 2, "③ 가방 T1 헬멧 2 분해")
	_check(int(game_state.call("get_stored_storage_count", "equipment", "tactical_helmet")) == 1, "③ 창고 T2 헬멧 보존")
	_check(int(game_state.call("get_equipment_count", "patched_helmet")) == 0, "③ 가방 T1 헬멧 0")
	# 창고 쪽 중복도 분해된다(창고 T1 운동화 3 → 1 남김, 가방에 없음)
	_reset_gear(game_state)
	(game_state.get("storage_inventory") as Array).append({"type": "equipment", "id": "patched_sneakers", "count": 3})
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 2, "③ 창고 운동화 3 → 2 분해")
	_check(int(game_state.call("get_stored_storage_count", "equipment", "patched_sneakers")) == 1, "③ 창고 운동화 1 보존")

	# ④ 장착 가능한 상위 장비는 절대 분해되지 않는다
	_reset_gear(game_state)
	game_state.call("add_equipment", "scav_vest", 1)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "military_vest", 1)
	game_state.call("add_equipment", "riot_vest", 2)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(game_state.call("get_equipment_count", "military_vest")) == 1, "④ T3 예비 보존")
	_check(int(game_state.call("get_equipment_count", "riot_vest")) == 0, "④ T2 2벌 분해")
	_check(int(report.get("items", 0)) == 2 and int(report.get("components", 0)) == 4, "④ T2×2 → 부품 4 (got %d/%d)" % [int(report.get("items", 0)), int(report.get("components", 0))])
	_check(str(game_state.get("equipped_body_armor_id")) == "scav_vest", "④ 장착 T1은 건드리지 않음")
	# 세 슬롯 전부: 각 슬롯에서 예비 최고 1개씩만 남는다
	_reset_gear(game_state)
	for equipment_id in ["scav_vest", "riot_vest", "patched_helmet", "tactical_helmet", "patched_sneakers", "tactical_boots"]:
		game_state.call("add_equipment", equipment_id, 1)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 3, "④ 슬롯별 최고 1개씩 보존, 3점 분해 (got %d)" % int(report.get("items", 0)))
	_check(
		int(game_state.call("get_equipment_count", "riot_vest")) == 1
		and int(game_state.call("get_equipment_count", "tactical_helmet")) == 1
		and int(game_state.call("get_equipment_count", "tactical_boots")) == 1,
		"④ 각 슬롯 T2 보존"
	)

	# ⑤ 사다리 밖 기종 중복은 건드리지 않는다 / 두 번째 분해는 0
	_reset_gear(game_state)
	game_state.set("weapon_inventory", {"ak47": 1, "mp5": 3, "double_barrel": 2, "akm": 2})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	report = game_state.call("salvage_surplus_equipment")
	_check(int(game_state.call("get_weapon_count", "mp5")) == 3, "⑤ MP5 3정 유지(사다리 밖)")
	_check(int(game_state.call("get_weapon_count", "double_barrel")) == 1, "⑤ 더블배럴 2 → 1")
	_check(int(game_state.call("get_weapon_count", "akm")) == 1, "⑤ AKM 2 → 1")
	_check(int(report.get("items", 0)) == 2 and int(report.get("components", 0)) == 3, "⑤ 더블배럴 1단(1) + AKM 2단(2) = 부품 3 (got %d)" % int(report.get("components", 0)))
	var second: Dictionary = game_state.call("salvage_surplus_equipment")
	_check(int(second.get("items", 0)) == 0 and int(second.get("components", 0)) == 0, "⑤ 두 번째 분해는 0")

	# ⑥ settle_shelter_return_inventory 통합
	_reset_gear(game_state)
	game_state.call("add_equipment", "scav_vest", 4)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "patched_helmet", 2)
	game_state.set("weapon_inventory", {"ak47": 1})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	var settlement: Dictionary = game_state.call("settle_shelter_return_inventory")
	print("  ⑥ SETTLE=%s" % JSON.stringify(settlement))
	_check(int(settlement.get("salvaged_items", 0)) == 3, "⑥ 정산 보고 잉여 3점 (got %d)" % int(settlement.get("salvaged_items", 0)))
	_check(int(settlement.get("salvaged_components", 0)) == 3, "⑥ 정산 보고 부품 3개")
	var stored_parts := 0
	for component_id in ["rubber_gasket", "magazine_spring", "scope_lens"]:
		stored_parts += int(game_state.call("get_stored_storage_count", "component", component_id))
	_check(stored_parts == 3, "⑥ 분해 부품이 창고로 입고 (got %d)" % stored_parts)
	_check(int(game_state.call("get_stored_storage_count", "equipment", "scav_vest")) == 1, "⑥ 예비 조끼 1 창고로")
	_check(int(game_state.call("get_stored_storage_count", "equipment", "patched_helmet")) == 1, "⑥ 헬멧 1 창고로")
	_check(str(game_state.get("equipped_body_armor_id")) == "scav_vest", "⑥ 장착 유지")

	if failures > 0:
		push_error("ARMOR_SALVAGE_FAILED failures=%d" % failures)
		quit(1)
		return
	print("ARMOR_SALVAGE_OK")
	quit(0)


func _reset_gear(game_state: Node) -> void:
	game_state.set("equipment_inventory", {})
	# storage_inventory는 Array[Dictionary] 타입이라 set([])이 안 먹는다 — 비운다.
	(game_state.get("storage_inventory") as Array).clear()
	game_state.set("mod_component_inventory", {"rubber_gasket": 0, "scope_lens": 0, "magazine_spring": 0})
	game_state.set("equipped_body_armor_id", "")
	game_state.set("equipped_head_armor_id", "")
	game_state.set("equipped_footwear_id", "")
	game_state.set("weapon_inventory", {"ak47": 1})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	game_state.set("valuable_inventory", {})


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)
