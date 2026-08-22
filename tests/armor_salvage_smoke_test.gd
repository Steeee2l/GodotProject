extends SceneTree

# 잉여 장비 분해(귀환 정산) 스모크 테스트 — 헤드리스.
#   godot --headless --path . --script res://tests/armor_salvage_smoke_test.gd
#
# 2026-08 경제 코어(장비 제작 전용·1개 영구 귀속) 이후 분해는 "구세이브 정리용"이다:
#   · 정확히 같은 id(레벨 접미사까지)의 중복만 1개 남기고 부품으로 — 장착분은 절대 안 건드림
#   · 다른 id(상위 가족·다른 레벨)는 각자의 영구 장비 — 손대지 않는다(옛 "슬롯별 최고
#     예비 1개만" 규칙은 제작한 T2를 T3 제작 뒤 녹여 버리므로 폐지)
#   · 무기는 전 기종 같은 id 2정 이상이면 1정 남김(사다리 밖 MP5도 — 전부 제작 전용 1정)
#   · 부품 수: 방어구 가족 T1 1 / T2 2 / T3 3, 무기 사다리 단계 1/2/3(밖 1), 패킹→스프링→렌즈 순환
#   · 정산(settle_shelter_return_inventory)은 여전히 부르지만 새 플레이에선 0점

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	# ① 구세이브 중복: 가방 T1 조끼 4(장착 1) · 헬멧 2 · T2 조끼 1, AK 2정(장착 1)
	#    → T1 조끼 예비 3 전부 분해(장착 중이라 예비는 잉여), 헬멧 1 분해, T2 조끼(다른 id) 보존,
	#      AK 1 분해 = 5점 → 부품 5개
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
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 0, "① 장착 중인 조끼의 예비는 전부 분해")
	_check(int(game_state.call("get_equipment_count", "riot_vest")) == 1, "① 다른 id(T2 조끼) 보존")
	_check(int(game_state.call("get_equipment_count", "patched_helmet")) == 1, "① 헬멧 1 보존")
	_check(int(game_state.call("get_weapon_count", "ak47")) == 1, "① AK 2정 → 1정(장착분)")
	_check(str(game_state.get("equipped_weapon_id")) == "ak47" and bool(game_state.get("has_ak")), "① 장착 AK 유지")
	var parts := game_state.get("mod_component_inventory") as Dictionary
	_check(
		int(parts.get("rubber_gasket", 0)) == 2 and int(parts.get("magazine_spring", 0)) == 2 and int(parts.get("scope_lens", 0)) == 1,
		"① 부품 순환 패킹 2 · 스프링 2 · 렌즈 1 (got %s)" % JSON.stringify(parts)
	)

	# ② 다른 레벨은 다른 영구 장비 — scav_vest@3 1 + scav_vest 2 → @3 보존, scav_vest 1 보존·1 분해
	_reset_gear(game_state)
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("equip_equipment", "riot_vest")
	game_state.call("add_equipment", "scav_vest@3", 1)
	game_state.call("add_equipment", "scav_vest", 2)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 1 and int(report.get("components", 0)) == 1, "② 같은 id 중복 1만 분해 → 부품 1 (got %d/%d)" % [int(report.get("items", 0)), int(report.get("components", 0))])
	_check(int(game_state.call("get_equipment_count", "scav_vest@3")) == 1, "② scav_vest@3 보존")
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 1, "② scav_vest 1 보존")

	# ③ 창고 포함 — 창고 T2 헬멧 1 + 가방 T1 헬멧 2 → T2 보존(다른 id), 가방 T1 1 분해
	_reset_gear(game_state)
	(game_state.get("storage_inventory") as Array).append({"type": "equipment", "id": "tactical_helmet", "count": 1})
	game_state.call("add_equipment", "patched_helmet", 2)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 1 and int(report.get("components", 0)) == 1, "③ 가방 T1 헬멧 2 → 1 분해")
	_check(int(game_state.call("get_stored_storage_count", "equipment", "tactical_helmet")) == 1, "③ 창고 T2 헬멧 보존")
	_check(int(game_state.call("get_equipment_count", "patched_helmet")) == 1, "③ 가방 T1 헬멧 1 보존")
	# 창고 쪽 중복도 분해된다(창고 T1 운동화 3 → 1 남김, 가방에 없음)
	_reset_gear(game_state)
	(game_state.get("storage_inventory") as Array).append({"type": "equipment", "id": "patched_sneakers", "count": 3})
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 2, "③ 창고 운동화 3 → 2 분해")
	_check(int(game_state.call("get_stored_storage_count", "equipment", "patched_sneakers")) == 1, "③ 창고 운동화 1 보존")

	# ④ 제작한 영구 장비는 절대 녹지 않는다 — 장착 T1, 예비 T3 1 + T2 1(각 1개) → 0점
	_reset_gear(game_state)
	game_state.call("add_equipment", "scav_vest", 1)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "military_vest", 1)
	game_state.call("add_equipment", "riot_vest", 1)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 0, "④ 서로 다른 영구 장비는 0점 (got %d)" % int(report.get("items", 0)))
	_check(int(game_state.call("get_equipment_count", "military_vest")) == 1 and int(game_state.call("get_equipment_count", "riot_vest")) == 1, "④ T2·T3 모두 보존")
	_check(str(game_state.get("equipped_body_armor_id")) == "scav_vest", "④ 장착 T1은 건드리지 않음")
	# 세 슬롯 전부 1개씩(9종) — 전부 보존
	_reset_gear(game_state)
	for equipment_id in ["scav_vest", "riot_vest", "patched_helmet", "tactical_helmet", "patched_sneakers", "tactical_boots"]:
		game_state.call("add_equipment", equipment_id, 1)
	report = game_state.call("salvage_surplus_equipment")
	_check(int(report.get("items", 0)) == 0, "④ 풀 세트 6종 각 1개 → 0점 (got %d)" % int(report.get("items", 0)))

	# ⑤ 무기 — 같은 id 중복만(MP5 3 → 1, 더블배럴 2 → 1, AKM 2 → 1) / 두 번째 분해는 0
	_reset_gear(game_state)
	game_state.set("weapon_inventory", {"ak47": 1, "mp5": 3, "double_barrel": 2, "akm": 2})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	report = game_state.call("salvage_surplus_equipment")
	_check(int(game_state.call("get_weapon_count", "mp5")) == 1, "⑤ MP5 3정 → 1정(전 기종 1정 영구)")
	_check(int(game_state.call("get_weapon_count", "double_barrel")) == 1, "⑤ 더블배럴 2 → 1")
	_check(int(game_state.call("get_weapon_count", "akm")) == 1, "⑤ AKM 2 → 1")
	_check(int(report.get("items", 0)) == 4 and int(report.get("components", 0)) == 5, "⑤ MP5 2(밖 1×2) + 더블배럴 1단(1) + AKM 2단(2) = 부품 5 (got %d/%d)" % [int(report.get("items", 0)), int(report.get("components", 0))])
	var second: Dictionary = game_state.call("salvage_surplus_equipment")
	_check(int(second.get("items", 0)) == 0 and int(second.get("components", 0)) == 0, "⑤ 두 번째 분해는 0")

	# ⑥ settle_shelter_return_inventory 통합 — 보고서 키 + 부품이 창고로, 장비는 몸에 그대로(창고 이동 없음)
	_reset_gear(game_state)
	game_state.call("add_equipment", "scav_vest", 4)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "patched_helmet", 2)
	game_state.set("weapon_inventory", {"ak47": 1})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	var settlement: Dictionary = game_state.call("settle_shelter_return_inventory")
	print("  ⑥ SETTLE=%s" % JSON.stringify(settlement))
	_check(int(settlement.get("salvaged_items", 0)) == 4, "⑥ 정산 보고 잉여 4점 (got %d)" % int(settlement.get("salvaged_items", 0)))
	_check(int(settlement.get("salvaged_components", 0)) == 4, "⑥ 정산 보고 부품 4개")
	var stored_parts := 0
	for component_id in ["rubber_gasket", "magazine_spring", "scope_lens"]:
		stored_parts += int(game_state.call("get_stored_storage_count", "component", component_id))
	_check(stored_parts == 4, "⑥ 분해 부품이 창고로 입고 (got %d)" % stored_parts)
	_check(int(game_state.call("get_stored_storage_count", "equipment", "patched_helmet")) == 0, "⑥ 장비는 창고로 옮기지 않는다(0칸 영구 귀속)")
	_check(int(game_state.call("get_equipment_count", "patched_helmet")) == 1, "⑥ 헬멧 1 가방(몸)에 그대로")
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
	game_state.set("mod_component_inventory", {"rubber_gasket": 0, "scope_lens": 0, "magazine_spring": 0, "precision_gear": 0, "military_alloy": 0})
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
