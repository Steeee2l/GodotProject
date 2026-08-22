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
	_check(str(key_req.get("hint", "")) == "남대문 폐시장 메인 미션 ‘상인 조합 금고’ 완료 보상", "③ key hint (got %s)" % str(key_req.get("hint")))
	_check(not bool(goal.get("all_met", true)), "③ all_met false without key")
	var line3: String = SHELTER_REQUISITION.format_goal_line(goal)
	print("  ③ LINE=%s" % line3)
	_check(line3.contains("남대문 창고 설계도 없음 — 남대문 폐시장 메인 미션"), "③ key segment text")
	_check(not bool(game_state.call("try_upgrade_shelter_tier")), "③ upgrade refused without key")
	_check(int(game_state.get("shelter_tier")) == 2 and int(game_state.get("scrap")) == 150000, "③ refusal keeps scrap/tier")
	var reason: String = SHELTER_REQUISITION.get_upgrade_block_reason()
	print("  ③ REASON=%s" % reason)
	_check(reason == "확장 불가 · 남대문 창고 설계도 필요 — 남대문 폐시장 메인 미션 ‘상인 조합 금고’ 완료 보상", "③ block reason key")
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
	# 무기 사다리 청사진(남대문 2단계 → pump_blueprint, 을지로 2단계 → akm_blueprint)도
	# 같은 경로로 보정된다 — 끝낸 단계의 보상만 들어오고, 을지로 3단계 키는 여전히 없다.
	_check(
		granted.has("namdaemun_depot_plans") and granted.has("pump_blueprint") and granted.has("akm_blueprint")
		and granted.size() == 3,
		"⑤ only completed chain rewards are backfilled (got %s)" % str(granted)
	)
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
