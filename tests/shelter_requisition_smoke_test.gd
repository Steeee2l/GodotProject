extends SceneTree

# 쉘터 "다음 목표"(티어 확장 요구) 스모크 테스트 — 헤드리스.
#   godot --headless --path . --script res://tests/shelter_requisition_smoke_test.gd
#
# ① Tier 1, 고철 30K·츄르 0 → 고철 충족/츄르 0/1 미충족, 줄 문구
# ② 츄르 +1 → 전부 충족, 정산 줄 "Tier 2 확장 가능!"
# ③ Tier 2 → 목표에 키 포함, 키 없이 확장 거부(사유), 키 지급 후 허용(키는 소모 안 함)
# ④ 남대문 체인 3단계 정산 → 키 지급 + 요약에 안내 줄
# ⑤ 구세이브(체인 완료·키 없음) → ensure_story_key_items가 보정
# ⑥ Tier 5 → 빈 목표 / 최종 표기
# ⑦ 러버밴딩 없음 — 고철·츄르를 바꿔도 need는 그대로(비용표 고정)
# ⑧ 존별 장비 목표 → 브리핑 칩 2개(세트·무기)
# ⑨ 목표 카드 조각 — 행 수치/진행 비율/아이콘/색/재구성 지문

# GameState를 참조하는 스크립트는 preload하지 않는다 — --script 로드 시점엔 autoload가
# 아직 없어 컴파일이 실패한다. _run 안에서 load()로 받는다.
var SHELTER_REQUISITION: GDScript
var MAIN_MISSION_CHAIN: GDScript

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SHELTER_REQUISITION = load("res://scripts/shelter/requisition.gd")
	MAIN_MISSION_CHAIN = load("res://scripts/raid/main_mission_chain.gd")
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")

	# ① Tier 1 · 고철 30K · 츄르 0
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 30000)
	game_state.set("churu", 0)
	var goal: Dictionary = SHELTER_REQUISITION.get_next_goal()
	_check(int(goal.get("tier", 0)) == 2, "① tier=2 (got %s)" % str(goal.get("tier")))
	_check(str(goal.get("title", "")) == "Tier 2 확장", "① title")
	_check(str(goal.get("unlock_hint", "")) == "남대문 폐시장 해금", "① unlock_hint (got %s)" % str(goal.get("unlock_hint")))
	var reqs := goal.get("requirements", []) as Array
	_check(reqs.size() == 2, "① Tier 2 requirements = scrap+churu only (got %d)" % reqs.size())
	_check(_req(goal, "scrap").get("ok", false) == true, "① scrap ok")
	_check(_req(goal, "churu").get("ok", true) == false, "① churu not ok")
	_check(int(_req(goal, "churu").get("have", -1)) == 0 and int(_req(goal, "churu").get("need", -1)) == 1, "① churu 0/1")
	_check(not bool(goal.get("all_met", true)), "① all_met false")
	var line: String = SHELTER_REQUISITION.format_goal_line(goal)
	print("  ① LINE=%s" % line)
	_check(line == "다음 → Tier 2 확장 · 고철 30K ✓ · 츄르 0/1 — 보스 처치·사자 계약", "① line text")
	var settle_line: String = SHELTER_REQUISITION.get_settlement_line()
	print("  ① SETTLE=%s" % settle_line)
	_check(settle_line == "다음 목표까지 츄르 1개 · 보스 처치·사자 계약", "① settlement line")
	var segments: Array[Dictionary] = SHELTER_REQUISITION.build_goal_segments(goal)
	_check(segments.size() == 3 and str(segments[1].get("state")) == "ok" and str(segments[2].get("state")) == "missing", "① segments states")
	_check(str(segments[1].get("hint", "x")) == "" and str(segments[2].get("hint", "")) != "", "① hint only on missing")
	_check(SHELTER_REQUISITION.describe_progress_after_pickup("canned_food") == "", "① non-requirement pickup → empty")
	_check(SHELTER_REQUISITION.get_goal_zone_ids().is_empty(), "① tier1: no boss zone unlocked yet → no goal zones")
	# 고철만 모자랄 때의 줄
	game_state.set("scrap", 12000)
	var scrap_goal: Dictionary = SHELTER_REQUISITION.get_next_goal()
	var scrap_line: String = SHELTER_REQUISITION.format_goal_line(scrap_goal)
	print("  ① SCRAP_LINE=%s" % scrap_line)
	_check(scrap_line.contains("고철 12K/30K — 생산·환전·판매"), "① scrap missing line")
	_check(SHELTER_REQUISITION.get_settlement_line() == "다음 목표까지 고철 18K · 츄르 1개", "① two gaps → no hint (got %s)" % SHELTER_REQUISITION.get_settlement_line())
	_check(SHELTER_REQUISITION.get_upgrade_block_reason() == "확장 불가 · 고철 18K 부족", "① block reason scrap")
	game_state.set("scrap", 30000)

	# ② 츄르 +1 → 전부 충족
	game_state.set("churu", 1)
	var pickup_note: String = SHELTER_REQUISITION.describe_progress_after_pickup("churu")
	print("  ② PICKUP=%s" % pickup_note)
	_check(pickup_note == "쉘터 목표 · 츄르 1/1 달성 · Tier 2 확장 가능", "② pickup note")
	goal = SHELTER_REQUISITION.get_next_goal()
	_check(bool(goal.get("all_met", false)), "② all_met")
	_check(SHELTER_REQUISITION.get_settlement_line() == "Tier 2 확장 가능!", "② settlement line (got %s)" % SHELTER_REQUISITION.get_settlement_line())
	_check(SHELTER_REQUISITION.get_upgrade_block_reason() == "", "② no block reason")
	print("  ② LINE=%s" % SHELTER_REQUISITION.format_goal_line(goal))
	# 츄르 2개 요구일 때의 중간 진행 문구(티어 3 비용표)
	game_state.set("shelter_tier", 2)
	game_state.set("churu", 1)
	_check(SHELTER_REQUISITION.describe_progress_after_pickup("churu") == "쉘터 목표 · 츄르 1/2", "② mid progress 1/2 (got %s)" % SHELTER_REQUISITION.describe_progress_after_pickup("churu"))

	# ③ Tier 2 → 키 요구. 키 없이 거부, 키 지급 후 허용
	game_state.set("shelter_tier", 2)
	game_state.set("scrap", 150000)
	game_state.set("churu", 2)
	(game_state.get("progression_item_inventory") as Dictionary)["namdaemun_depot_plans"] = 0
	goal = SHELTER_REQUISITION.get_next_goal()
	var key_req := _req(goal, "namdaemun_depot_plans")
	_check(not key_req.is_empty(), "③ goal includes key_item")
	_check(bool(key_req.get("is_key", false)) and not bool(key_req.get("ok", true)), "③ key missing")
	# 시나리오 전면 개편(2026-08)으로 미션 제목이 바뀌었다 — 힌트는 stage title을 그대로 끼워 넣는다.
	_check(str(key_req.get("hint", "")) == "남대문 폐시장 메인 미션 ‘명단을 쓴 손’ 완료 보상", "③ key hint (got %s)" % str(key_req.get("hint")))
	_check(not bool(goal.get("all_met", true)), "③ all_met false without key")
	var line3: String = SHELTER_REQUISITION.format_goal_line(goal)
	print("  ③ LINE=%s" % line3)
	_check(line3.contains("남대문 창고 설계도 없음 — 남대문 폐시장 메인 미션"), "③ key segment text")
	_check(not bool(game_state.call("try_upgrade_shelter_tier")), "③ upgrade refused without key")
	_check(int(game_state.get("shelter_tier")) == 2 and int(game_state.get("scrap")) == 150000, "③ refusal keeps scrap/tier")
	var reason: String = SHELTER_REQUISITION.get_upgrade_block_reason()
	print("  ③ REASON=%s" % reason)
	_check(reason == "확장 불가 · 남대문 창고 설계도 필요 — 남대문 폐시장 메인 미션 ‘명단을 쓴 손’ 완료 보상", "③ block reason key")
	_check(SHELTER_REQUISITION.get_settlement_line() == "다음 목표까지 남대문 창고 설계도 · 남대문 폐시장 메인 미션", "③ settlement line key (got %s)" % SHELTER_REQUISITION.get_settlement_line())
	var goal_zones: Array[String] = SHELTER_REQUISITION.get_goal_zone_ids()
	_check(goal_zones.size() == 1 and goal_zones[0] == "namdaemun_market", "③ goal zone = namdaemun (got %s)" % str(goal_zones))
	game_state.call("add_progression_item", "namdaemun_depot_plans", 1)
	_check(SHELTER_REQUISITION.describe_progress_after_pickup("namdaemun_depot_plans") == "쉘터 목표 · 남대문 창고 설계도 1/1 달성 · Tier 3 확장 가능", "③ key pickup note (got %s)" % SHELTER_REQUISITION.describe_progress_after_pickup("namdaemun_depot_plans"))
	_check(bool(game_state.call("try_upgrade_shelter_tier")), "③ upgrade allowed with key")
	_check(int(game_state.get("shelter_tier")) == 3, "③ tier now 3")
	_check(int(game_state.call("get_progression_item_count", "namdaemun_depot_plans")) == 1, "③ key not consumed")
	# 가방 칸 0
	_check(int(game_state.call("get_raid_item_slot_cost", "progression", "namdaemun_depot_plans", 1)) == 0, "③ key takes 0 bag slots")
	# 소급 없음: Tier 3인 세이브의 다음 목표는 Tier 4 키(을지로)만 본다
	goal = SHELTER_REQUISITION.get_next_goal()
	_check(_req(goal, "namdaemun_depot_plans").is_empty() and not _req(goal, "euljiro_grid_schematic").is_empty(), "③ no retroactive key check")

	# ④ 남대문 체인 3단계 정산 → 키 지급
	game_state.call("reset_run")
	game_state.set("shelter_tier", 2)
	(game_state.get("progression_item_inventory") as Dictionary)["namdaemun_depot_plans"] = 0
	(game_state.get("main_mission_progress") as Dictionary)["namdaemun_market"] = 2
	game_state.set("raid_special_cargo", {"id": "namdaemun_guild_ledger", "title": "상인 조합 최종 장부"})
	var chain: Object = MAIN_MISSION_CHAIN.new()
	var settle_result: Dictionary = chain.call("settle")
	print("  ④ SETTLE=%s" % str(settle_result.get("summary", "")).replace("\n", " | "))
	_check(int(game_state.call("get_main_mission_progress", "namdaemun_market")) == 3, "④ chain complete")
	_check(int(game_state.call("get_progression_item_count", "namdaemun_depot_plans")) == 1, "④ key granted by stage 3 reward")
	_check(str(settle_result.get("summary", "")).contains("남대문 창고 설계도 획득 · 쉘터 Tier 3 확장에 필요한 설계도"), "④ summary has key grant line")
	# 재회수(repeat_reward)에는 키가 없다
	game_state.set("raid_special_cargo", {"id": "namdaemun_guild_ledger", "title": "상인 조합 최종 장부"})
	var repeat_chain: Object = MAIN_MISSION_CHAIN.new()
	repeat_chain.call("settle")
	_check(int(game_state.call("get_progression_item_count", "namdaemun_depot_plans")) == 1, "④ repeat recovery does not duplicate key")
	# 카탈로그: 3·4·5 키가 각각 남대문/을지로/용산 3단계에 있고, 다른 단계엔 없다
	for pair in [["namdaemun_market", "namdaemun_depot_plans"], ["euljiro_depths", "euljiro_grid_schematic"], ["yongsan_blockade", "yongsan_control_key"]]:
		var source: Dictionary = SHELTER_REQUISITION.get_key_item_source(str(pair[1]))
		_check(str(source.get("zone_id", "")) == str(pair[0]) and int(source.get("stage_index", -1)) == 2, "④ key source %s → %s stage 3" % [pair[1], pair[0]])
	_check(SHELTER_REQUISITION.get_key_item_source("rifle_blueprint").is_empty(), "④ non-key has no source")

	# ⑤ 구세이브: 체인 완료·키 없음 → 보정
	game_state.call("reset_run")
	(game_state.get("progression_item_inventory") as Dictionary)["namdaemun_depot_plans"] = 0
	(game_state.get("progression_item_inventory") as Dictionary)["euljiro_grid_schematic"] = 0
	(game_state.get("main_mission_progress") as Dictionary)["namdaemun_market"] = 3
	(game_state.get("main_mission_progress") as Dictionary)["euljiro_depths"] = 2  # 3단계 미완 → 키 없음
	var granted: Array[String] = SHELTER_REQUISITION.ensure_story_key_items()
	print("  ⑤ GRANTED=%s" % str(granted))
	# 무기 사다리 설계도 조각(남대문 2단계 → 펌프 조각 2, 을지로 2단계 → AKM 조각 2)도
	# 같은 경로로 보정된다 — 끝낸 단계의 보상만 들어오고, 을지로 3단계 키는 여전히 없다.
	# (2026-08 경제 코어: 통짜 청사진은 폐지, 보상은 blueprint_shard_*. 장인의 인장은
	#  소모 재화라 보정 대상이 아니다 — 남대문 3단계를 끝냈어도 granted에 없어야 한다.)
	_check(
		granted.has("namdaemun_depot_plans") and granted.has("blueprint_shard_pump_shotgun") and granted.has("blueprint_shard_akm")
		and not granted.has("artisan_seal") and granted.size() == 3,
		"⑤ only completed chain rewards are backfilled (got %s)" % str(granted)
	)
	_check(int(game_state.call("get_blueprint_shard_count", "pump_shotgun")) == 2, "⑤ 펌프 조각 2 보정")
	_check(int(game_state.call("get_progression_item_count", "namdaemun_depot_plans")) == 1, "⑤ backfilled key count 1")
	_check(int(game_state.call("get_progression_item_count", "euljiro_grid_schematic")) == 0, "⑤ incomplete chain not granted")
	_check((SHELTER_REQUISITION.ensure_story_key_items() as Array).is_empty(), "⑤ idempotent")

	# ⑥ Tier 5 → 빈 목표 / 최종 표기
	game_state.set("shelter_tier", 5)
	_check(SHELTER_REQUISITION.get_next_goal().is_empty(), "⑥ final tier → empty goal")
	_check(SHELTER_REQUISITION.format_goal_line({}) == "최종 티어 · 쉘터 확장 완료", "⑥ final text (got %s)" % SHELTER_REQUISITION.format_goal_line({}))
	_check(SHELTER_REQUISITION.get_settlement_line() == "", "⑥ no settlement line")
	_check(SHELTER_REQUISITION.describe_progress_after_pickup("churu") == "", "⑥ no pickup note")
	_check(SHELTER_REQUISITION.get_upgrade_block_reason() == "쉘터가 이미 최고 Tier(5)입니다.", "⑥ block reason final")

	# ⑦ 러버밴딩 없음 — 플레이어 상태와 무관하게 need는 비용표 그대로
	game_state.set("shelter_tier", 3)
	game_state.set("scrap", 0)
	game_state.set("churu", 0)
	var poor_need := int(_req(SHELTER_REQUISITION.get_next_goal(), "churu").get("need", -1))
	game_state.set("scrap", 99_000_000)
	game_state.set("churu", 99)
	var rich_need := int(_req(SHELTER_REQUISITION.get_next_goal(), "churu").get("need", -1))
	_check(poor_need == 4 and rich_need == 4, "⑦ need fixed by cost table (poor %d / rich %d)" % [poor_need, rich_need])

	# ⑧ 존별 장비 목표 — 그 존 세트 n/3 + 권장 무기 강화(종로 AK+5 … 남산 K2+25)
	game_state.call("reset_run")
	game_state.set("equipment_inventory", {})
	(game_state.get("storage_inventory") as Array).clear()
	game_state.set("equipped_body_armor_id", "")
	game_state.set("equipped_head_armor_id", "")
	game_state.set("equipped_footwear_id", "")
	game_state.set("weapon_inventory", {"ak47": 1})
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 3
	var gear: Dictionary = SHELTER_REQUISITION.get_zone_gear_goal("jongno_outskirts")
	print("  ⑧ JONGNO=%s" % str(gear.get("text", "")))
	_check(str(gear.get("set_label", "")) == "T1" and int(gear.get("set_owned", -1)) == 0, "⑧ 종로 = T1 세트 0/3")
	_check(str(gear.get("weapon_id", "")) == "ak47" and int(gear.get("weapon_level", 0)) == 5, "⑧ 종로 권장 AK+5")
	_check(str(gear.get("text", "")) == "권장: T1 세트 제작 0/3 · AK +3/5", "⑧ 문구 (got %s)" % str(gear.get("text", "")))
	_check(not bool(gear.get("all_ok", true)), "⑧ 미충족")
	# 세트: 장착 1 + 가방 1 + 창고 1 = 3/3 (레벨 @n은 기종으로 센다)
	game_state.call("add_equipment", "scav_vest", 1)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "patched_helmet@2", 1)
	(game_state.get("storage_inventory") as Array).append({"type": "equipment", "id": "patched_sneakers", "count": 1})
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 5
	gear = SHELTER_REQUISITION.get_zone_gear_goal("jongno_outskirts")
	print("  ⑧ JONGNO_OK=%s" % str(gear.get("text", "")))
	_check(int(gear.get("set_owned", -1)) == 3 and int(gear.get("set_equipped", -1)) == 1 and bool(gear.get("set_ok", false)), "⑧ 세트 3/3 (장착 1)")
	_check(bool(gear.get("weapon_ok", false)) and bool(gear.get("all_ok", false)), "⑧ AK+5 충족 → all_ok")
	_check(str(gear.get("text", "")) == "권장: T1 세트 제작 3/3 · AK +5/5", "⑧ 충족 문구 (got %s)" % str(gear.get("text", "")))
	# 을지로(존3): T2 세트, 권장 AKM+15 — AK+5로는 단이 모자라다(문구에 권장·현재)
	gear = SHELTER_REQUISITION.get_zone_gear_goal("euljiro_depths")
	print("  ⑧ EULJIRO=%s" % str(gear.get("text", "")))
	_check(str(gear.get("set_label", "")) == "T2" and int(gear.get("set_owned", -1)) == 0, "⑧ 을지로 = T2 세트 0/3")
	_check(str(gear.get("weapon_id", "")) == "akm" and int(gear.get("weapon_level", 0)) == 15 and not bool(gear.get("weapon_rung_ok", true)), "⑧ 을지로 권장 AKM+15, AK는 단 부족")
	_check(str(gear.get("text", "")) == "권장: T2 세트 제작 0/3 · AKM +15 권장 · 현재 AK +5", "⑧ 단 부족 문구 (got %s)" % str(gear.get("text", "")))
	# 같은 단의 다른 가족(펌프 산탄총 2단)도 단으로는 충족
	game_state.call("add_weapon", "pump_shotgun", 1)
	game_state.set("equipped_weapon_id", "pump_shotgun")
	(game_state.get("weapon_enhancement_levels") as Dictionary)["pump_shotgun"] = 15
	gear = SHELTER_REQUISITION.get_zone_gear_goal("euljiro_depths")
	_check(bool(gear.get("weapon_rung_ok", false)) and bool(gear.get("weapon_ok", false)), "⑧ 펌프 +15도 AKM+15 권장 충족")
	_check(str(gear.get("text", "")) == "권장: T2 세트 제작 0/3 · 펌프 +15/15", "⑧ 펌프 문구 (got %s)" % str(gear.get("text", "")))
	# 남산(존5) K2+25 / 용산 AKM+20 / 남대문 AK+10 — 러버밴딩 없음(플레이어 상태와 무관)
	_check(str(SHELTER_REQUISITION.get_zone_gear_goal("namsan_core").get("weapon_id", "")) == "k2" and int(SHELTER_REQUISITION.get_zone_gear_goal("namsan_core").get("weapon_level", 0)) == 25, "⑧ 남산 K2+25")
	_check(str(SHELTER_REQUISITION.get_zone_gear_goal("namsan_core").get("set_label", "")) == "T3", "⑧ 남산 T3 세트")
	_check(int(SHELTER_REQUISITION.get_zone_gear_goal("yongsan_blockade").get("weapon_level", 0)) == 20, "⑧ 용산 +20")
	_check(int(SHELTER_REQUISITION.get_zone_gear_goal("namdaemun_market").get("weapon_level", 0)) == 10, "⑧ 남대문 +10")
	_check(SHELTER_REQUISITION.get_zone_gear_goal("no_such_zone").is_empty(), "⑧ 모르는 존 → 빈 딕셔너리")
	# 브리핑 장비 목표는 라벨 한 줄(attach_zone_gear_goal_line)에서 칩 2개로 바뀌었다
	# — 브리핑이 "텍스트 위주"라는 신고에 따른 재디자인. 라벨 부착 함수는 삭제됐다.
	var gear_chips: Array[Dictionary] = SHELTER_REQUISITION.build_zone_gear_chips("euljiro_depths")
	_check(gear_chips.size() == 2, "⑧ 칩 2개(세트·무기)")
	_check(str(gear_chips[0].get("id", "")) == "set" and str(gear_chips[0].get("icon", "")) == "armor", "⑧ 세트 칩")
	_check(str(gear_chips[0].get("text", "")) == "T2 세트 0/3", "⑧ 세트 칩 문구 (got %s)" % str(gear_chips[0].get("text", "")))
	_check(str(gear_chips[1].get("id", "")) == "weapon" and str(gear_chips[1].get("icon", "")) == "weapon", "⑧ 무기 칩")
	# 펌프 +15 장착 상태(위에서 세팅) → 을지로 AKM+15 권장 충족
	_check(str(gear_chips[1].get("text", "")) == "펌프 +15/15" and bool(gear_chips[1].get("ok", false)), "⑧ 무기 칩 충족 (got %s)" % str(gear_chips[1].get("text", "")))
	game_state.set("equipped_weapon_id", "ak47")
	gear_chips = SHELTER_REQUISITION.build_zone_gear_chips("euljiro_depths")
	_check(str(gear_chips[1].get("text", "")) == "AKM +15 필요" and not bool(gear_chips[1].get("ok", true)), "⑧ 단 부족이면 기종부터 (got %s)" % str(gear_chips[1].get("text", "")))
	_check(str(gear_chips[1].get("tooltip", "")).contains("현재 AK +5"), "⑧ 이유는 툴팁으로 (got %s)" % str(gear_chips[1].get("tooltip", "")))
	_check(SHELTER_REQUISITION.build_zone_gear_chips("no_such_zone").is_empty(), "⑧ 모르는 존 → 칩 없음")

	# ⑨ 목표 카드 조각 — 카드가 행을 그리는 데 필요한 값(수치·비율·아이콘·색·지문)
	game_state.set("shelter_tier", 1)
	game_state.set("scrap", 12000)
	game_state.set("churu", 0)
	goal = SHELTER_REQUISITION.get_next_goal()
	var scrap_req := _req(goal, "scrap")
	var churu_req := _req(goal, "churu")
	_check(SHELTER_REQUISITION.format_requirement_value(scrap_req) == "12K/30K", "⑨ 고철 수치 (got %s)" % SHELTER_REQUISITION.format_requirement_value(scrap_req))
	_check(SHELTER_REQUISITION.format_requirement_value(churu_req) == "0/1", "⑨ 츄르 수치")
	_check(absf(SHELTER_REQUISITION.get_requirement_ratio(scrap_req) - 0.4) < 0.001, "⑨ 고철 비율 0.4")
	_check(SHELTER_REQUISITION.get_requirement_ratio(churu_req) == 0.0, "⑨ 츄르 비율 0")
	# 초과분은 잘라서 보여준다 — "45K/30K"는 정보가 아니라 소음이다.
	game_state.set("scrap", 45000)
	goal = SHELTER_REQUISITION.get_next_goal()
	_check(SHELTER_REQUISITION.format_requirement_value(_req(goal, "scrap")) == "30K/30K", "⑨ 초과분은 need로 캡")
	_check(SHELTER_REQUISITION.get_requirement_ratio(_req(goal, "scrap")) == 1.0, "⑨ 초과 비율 1.0")
	_check(SHELTER_REQUISITION.get_requirement_icon("scrap") == "scrap" and SHELTER_REQUISITION.get_requirement_icon("churu") == "churu", "⑨ 재화 아이콘")
	_check(SHELTER_REQUISITION.get_requirement_icon("namdaemun_depot_plans") == "lore", "⑨ 서사 키는 문서 아이콘")
	_check(SHELTER_REQUISITION.get_requirement_color("scrap") == Color("#c7d1ce"), "⑨ 고철 색은 스탯 패널 칩과 같다")
	# 지문은 '요구 목록'만 본다 — 수량이 바뀌어도 행을 다시 만들지 않는다.
	var signature_a: String = SHELTER_REQUISITION.get_goal_signature(goal)
	game_state.set("scrap", 1)
	var signature_b: String = SHELTER_REQUISITION.get_goal_signature(SHELTER_REQUISITION.get_next_goal())
	_check(signature_a == signature_b and signature_a == "2|scrap,churu", "⑨ 지문은 수량과 무관 (got %s / %s)" % [signature_a, signature_b])
	game_state.set("shelter_tier", 5)
	_check(SHELTER_REQUISITION.get_goal_signature(SHELTER_REQUISITION.get_next_goal()) == "final", "⑨ 최종 티어 지문")

	if failures > 0:
		push_error("SHELTER_REQUISITION_FAIL failures=%d" % failures)
		quit(1)
		return
	print("SHELTER_REQUISITION_OK")
	quit(0)


func _req(goal: Dictionary, id: String) -> Dictionary:
	for requirement in goal.get("requirements", []) as Array:
		if str((requirement as Dictionary).get("id", "")) == id:
			return requirement as Dictionary
	return {}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
		return
	failures += 1
	push_error("  FAIL %s" % label)
