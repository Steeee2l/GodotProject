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

	# 4) 캣닢 급여는 한 판짜리 택1 — 소비되고, 중복 선택은 거부되고, 복귀 시 사라진다.
	# 가격은 생산 20분치로 스케일링되므로 현재 가격 기준으로 지갑을 채운다.
	game_state.catnip = int(game_state.get_catnip_field_buff_cost()) + 50
	var catnip_wallet: int = game_state.catnip
	_check(game_state.try_activate_catnip_field_buff("swift_paws"), "캣닢 급여 적용 실패")
	_check(game_state.catnip < catnip_wallet, "캣닢 급여가 캣닢을 소비하지 않음")
	_check(
		not game_state.try_activate_catnip_field_buff("keen_eyes"),
		"캣닢 급여가 택1 규칙을 어기고 중복 적용됨"
	)
	_check(
		game_state.get_move_speed_multiplier() > 1.11,
		"잰걸음 급여가 이동 속도에 반영되지 않음"
	)
	game_state.register_shelter_return()
	_check(
		game_state.active_catnip_buff == "",
		"캣닢 급여가 복귀 후에도 남아 있음"
	)

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
