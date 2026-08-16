extends SceneTree

# 연료 게이트: 쉘터 생산이 출정에서 가져온 통조림(단일 연료)에 묶여 있는지 검증한다.

var failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		push_error("GameState 오토로드를 찾을 수 없습니다.")
		quit(1)
		return

	game_state.persistence_enabled = false
	game_state.reset_run()

	# 생산 라인을 돌릴 수 있는 최소 조건을 만든다.
	game_state.rescued_workers = 2
	game_state._ensure_resident_records()
	game_state.shelter_facility_unlocks["scratcher_bank"] = true
	game_state.shelter_facility_unlocks["catnip_scraper"] = true
	# Array[String] 프로퍼티라 무타입 배열 리터럴은 대입되지 않는다.
	var scratcher_crew: Array[String] = [str(game_state.resident_cat_ids[0])]
	var catnip_crew: Array[String] = [str(game_state.resident_cat_ids[1])]
	game_state.assigned_worker_ids = scratcher_crew
	game_state.assigned_catnip_worker_ids = catnip_crew

	# 1) 통조림이 없으면 생산이 멈춘다.
	game_state.canned_food = 0
	var scrap_before: int = game_state.scrap
	game_state.tick_shelter_live(60.0)
	_check(
		game_state.scrap == scrap_before,
		"통조림이 없는데 고철이 생산됨 (%d -> %d)" % [scrap_before, game_state.scrap]
	)
	_check(
		game_state.get_shelter_stall_reason() == "no_food",
		"정지 사유가 no_food가 아님: %s" % game_state.get_shelter_stall_reason()
	)

	# 2) 통조림이 있으면 생산되고, 통조림이 실제로 줄어든다.
	game_state.canned_food = 100
	game_state.shelter_scrap_fraction = 0.0
	game_state.shelter_catnip_fraction = 0.0
	game_state.shelter_food_fraction = 0.0
	var food_before: int = game_state.canned_food
	scrap_before = game_state.scrap
	var catnip_before: int = game_state.catnip
	game_state.tick_shelter_live(3600.0 * 8.0)
	_check(
		game_state.scrap > scrap_before,
		"연료가 충분한데 고철이 생산되지 않음 (%d -> %d)" % [scrap_before, game_state.scrap]
	)
	_check(
		game_state.catnip > catnip_before,
		"연료가 충분한데 캣닢이 생산되지 않음 (%d -> %d)" % [catnip_before, game_state.catnip]
	)
	_check(
		game_state.canned_food < food_before,
		"생산했는데 통조림이 소비되지 않음 (%d -> %d)" % [food_before, game_state.canned_food]
	)

	# 3) 잔여 가동시간은 통조림 재고에 비례한다.
	game_state.canned_food = 10
	var runtime_small: float = game_state.get_shelter_runtime_seconds()
	game_state.canned_food = 100
	var runtime_large: float = game_state.get_shelter_runtime_seconds()
	_check(
		runtime_small > 0.0 and runtime_large > runtime_small * 5.0,
		"잔여 가동시간이 통조림 재고를 따르지 않음: %.1f / %.1f" % [runtime_small, runtime_large]
	)

	# 4) 캣닢 출정 급여는 폐지됐다(유저: "너무 별로야"). 캣닢의 출구는 이제
	# 고철 생산기 확장 재료와 「캣닢 피버」 둘이다.
	# 4-a) 생산기 확장은 고철만으로는 안 된다 — 캣닢이 필수 재료다.
	game_state.scratcher_bank_level = 1
	game_state.scrap = int(game_state.SCRATCHER_UPGRADE_COSTS.get(2, 0))
	game_state.catnip = 0
	_check(
		not game_state.try_upgrade_scratcher_bank(),
		"캣닢 없이 고철만으로 생산기가 확장됨"
	)
	game_state.catnip = int(game_state.SCRATCHER_UPGRADE_CATNIP_COSTS.get(2, 0))
	_check(game_state.try_upgrade_scratcher_bank(), "고철+캣닢을 다 냈는데 확장 실패")
	_check(game_state.catnip == 0, "확장이 캣닢을 소비하지 않음")

	# 4-b) 캣닢 피버: 부으면 게이지가 차고, 만충이면 발동하고, 시간이 지나면 끝난다.
	game_state.catnip_fever_gauge = 0.0
	game_state.catnip_fever_active = false
	var fever_cost: int = game_state.get_catnip_fever_charge_cost()
	game_state.catnip = 0
	_check(
		not bool((game_state.try_charge_catnip_fever() as Dictionary).get("ok", false)),
		"캣닢이 없는데 피버 게이지가 충전됨"
	)
	# 만충까지 필요한 횟수만큼 지갑을 채운다(단계당 25%, 총 4회).
	var charge_steps: int = ceili(
		game_state.CATNIP_FEVER_GAUGE_MAX / game_state.CATNIP_FEVER_CHARGE_STEP
	)
	game_state.catnip = fever_cost * charge_steps
	for step in charge_steps:
		var charge: Dictionary = game_state.try_charge_catnip_fever()
		_check(bool(charge.get("ok", false)), "피버 충전 %d회차 실패" % (step + 1))
	_check(game_state.catnip_fever_active, "게이지가 만충인데 피버가 발동하지 않음")
	_check(game_state.catnip == 0, "피버 충전이 캣닢을 소비하지 않음")
	var fever_scrap_rate: float = game_state.get_scrap_per_hour()
	var fever_catnip_rate: float = game_state.get_catnip_per_second()
	game_state.catnip_fever_active = false
	_check(
		is_equal_approx(
			fever_scrap_rate,
			game_state.get_scrap_per_hour() * game_state.get_catnip_fever_multiplier()
		),
		"피버가 고철 생산 배율에 반영되지 않음"
	)
	_check(
		is_equal_approx(
			fever_catnip_rate,
			game_state.get_catnip_per_second() * game_state.get_catnip_fever_multiplier()
		),
		"피버가 착즙 생산 배율에 반영되지 않음"
	)
	game_state.catnip_fever_active = true
	game_state.catnip_fever_gauge = game_state.CATNIP_FEVER_GAUGE_MAX
	_check(
		not game_state.tick_catnip_fever(game_state.get_catnip_fever_duration() * 0.5),
		"피버가 절반 시점에 이미 종료됨"
	)
	_check(
		game_state.tick_catnip_fever(game_state.get_catnip_fever_duration()),
		"지속시간이 다 지났는데 피버가 끝나지 않음"
	)
	_check(not game_state.catnip_fever_active, "피버 종료 후에도 활성 상태가 남음")
	game_state.register_shelter_return()

	# 6) 츄르 버프는 가방 용량을 실제로 늘리고, 복귀 시 사라진다.
	game_state.churu = 5
	var base_capacity: int = game_state.get_raid_bag_capacity()
	_check(game_state.try_activate_churu_buff("big_pockets"), "츄르 버프 적용 실패")
	_check(
		game_state.get_raid_bag_capacity() == base_capacity + 4,
		"츄르 버프가 가방 용량에 반영되지 않음"
	)
	game_state.clear_churu_buffs()
	_check(
		game_state.get_raid_bag_capacity() == base_capacity,
		"츄르 버프가 복귀 후에도 남아 있음"
	)

	# 7) 주민 특성은 서열이 아니라 트레이드오프여야 한다.
	var has_specialist := false
	for preset in game_state.RESIDENT_TRAIT_PRESETS:
		var kneading := float((preset as Dictionary).get("kneading", 1.0))
		var catnip := float((preset as Dictionary).get("catnip", 1.0))
		if (kneading > 1.2 and catnip < 0.9) or (catnip > 1.2 and kneading < 0.9):
			has_specialist = true
		_check(
			(preset as Dictionary).has("appetite"),
			"특성 %s 에 appetite가 없음" % (preset as Dictionary).get("name", "?")
		)
	_check(has_specialist, "한쪽에 특화되고 다른 쪽이 약한 특성이 없음 (선택이 아니라 서열)")

	# 8) 식비는 인원수가 아니라 식욕 합계를 따른다.
	game_state.assigned_worker_ids = scratcher_crew
	game_state.assigned_catnip_worker_ids = catnip_crew
	var appetite: float = game_state.get_total_worker_appetite()
	_check(appetite > 0.0, "배치된 주민의 식욕 합계가 0")

	# 8-b) 복귀 = 정산. 통조림은 쉘터로, 재료·부착물·진행품·여분 장비는 창고로,
	# 귀중품은 고철로 바뀌고, 탄약·구급약만 다음 출정을 위해 가방에 남는다.
	game_state.reset_run()
	game_state.unlock_all_shelter_facilities()
	game_state.canned_food = 12
	game_state.medkits = 2
	game_state.set_ammo_count("762_fmj", 60)
	game_state.mod_component_inventory = {"rubber_gasket": 4, "scope_lens": 0, "magazine_spring": 0}
	game_state.progression_item_inventory = {
		"rifle_blueprint": 1, "shotgun_blueprint": 0, "sealed_zone_keycard": 0
	}
	game_state.valuable_inventory = {"silver_spoon": 2}
	var settlement_scrap_before: int = game_state.scrap
	game_state.register_shelter_return(true)
	var settlement: Dictionary = game_state.consume_return_settlement()
	_check(
		game_state.get_backpack_storage_count("food", "canned_food") == 0,
		"복귀했는데 통조림이 아직 가방 칸을 먹고 있음"
	)
	_check(
		game_state.canned_food == 12 and game_state.shelter_food_reserve == 12,
		"통조림이 쉘터 재고로 편입되지 않음 (%d / 선반 %d)" % [
			game_state.canned_food, game_state.shelter_food_reserve
		]
	)
	_check(
		game_state.get_backpack_storage_count("component", "rubber_gasket") == 0
		and game_state.get_stored_storage_count("component", "rubber_gasket") == 4,
		"제작 재료가 창고로 귀속되지 않음"
	)
	# 청사진은 창고에 있어도 '보유'로 판정돼야 제작 게이트가 안 잠긴다.
	_check(
		game_state.get_stored_storage_count("progression", "rifle_blueprint") == 1
		and game_state.get_progression_item_count("rifle_blueprint") == 1,
		"창고에 넣은 청사진이 보유 판정에서 사라짐"
	)
	_check(
		game_state.scrap > settlement_scrap_before
		and int(settlement.get("valuable_count", 0)) == 2,
		"귀중품이 복귀 정산에서 고철로 환전되지 않음"
	)
	_check(
		game_state.get_ammo_count("762_fmj") == 60 and game_state.medkits == 2,
		"다음 출정 준비물(탄약·구급약)까지 가방에서 빠져나감"
	)

	# 9) 시체는 시간이 지나면 약탈당하고 끝내 사라진다.
	game_state.shelter_return_serial = 10
	game_state.set_pending_corpse_recovery({
		"map_seed": 1, "raid_zone": "jongno_outskirts", "position": [0, 0, 0],
		"loot": {"medkits": 10, "canned_food": 10},
	})
	_check(game_state.get_corpse_intact_ratio() == 1.0, "방금 남긴 시체가 온전하지 않음")
	game_state.shelter_return_serial = 13
	var decay: Dictionary = game_state.apply_corpse_decay()
	_check(
		str(decay.get("status", "")) == "decayed",
		"3회 경과 후 부패 상태가 아님: %s" % decay.get("status", "")
	)
	_check(
		int((game_state.pending_corpse_recovery.get("loot", {}) as Dictionary).get("medkits", 99)) < 10,
		"부패했는데 전리품이 줄지 않음"
	)
	game_state.shelter_return_serial = 20
	var lost: Dictionary = game_state.apply_corpse_decay()
	_check(str(lost.get("status", "")) == "lost", "한참 지났는데 시체가 사라지지 않음")
	_check(game_state.pending_corpse_recovery.is_empty(), "소실 후에도 시체 기록이 남음")

	# 10) 문턱 해금은 조건을 넘을 때 한 번만 발생한다.
	game_state.unlocked_milestones.clear()
	game_state.rescued_workers = 3
	var first: Array = game_state.check_milestone_unlocks()
	_check(first.size() > 0, "주민 3명 조건에서 해금이 발생하지 않음")
	var second: Array = game_state.check_milestone_unlocks()
	_check(second.is_empty(), "같은 문턱이 두 번 해금됨")
	_check(game_state.is_milestone_unlocked("shelter_line"), "shelter_line 마일스톤이 기록되지 않음")

	if failures.is_empty():
		print("shelter_fuel_gate_smoke_test: PASS")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: %s" % failure)
		printerr("shelter_fuel_gate_smoke_test: %d건 실패" % failures.size())
		quit(1)
