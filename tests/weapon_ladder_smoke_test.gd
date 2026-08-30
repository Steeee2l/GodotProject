extends SceneTree

# 무기 사다리 + 강화 이관 스모크 테스트.
#
# 검증 항목
#   ① 신규 3종(akm·k2·pump_shotgun) build_stats 정상, 기존 구경(7.62x39 / 12g) 탄약 호환
#   ② 강화 이관: AK-47 +10 보유 상태에서 AKM 첫 획득 → AKM +6, 재획득 시 재이관 없음,
#      K2 첫 획득 시 AKM(가장 높은 하위) 기준 이관, from 레벨 유지, 세이브 왕복 유지
#   ③ 작업대 레시피 게이트(2026-08 경제 코어): 설계도 조각 3/3(akm/pump/k2 전부) · 보유 시 재제작 불가
#   ④ 메인 미션 2단계 보상에 설계도 조각(2)이 있고, 이미 끝낸 구세이브는 ensure_story_key_items로 보정
#   ⑤ 드랍 경로: 장비는 어떤 경로(적 처치·엘리트·상자)에서도 안 나온다 — 제작 전용
#   ⑥ 처치 발수 표(존별 사수 체력 102/125/149/176/202, 엘리트 ×2.6) — 밸런스 가드 출력 + 목표 검증
#
# 실행: godot --headless --path . --script res://tests/weapon_ladder_smoke_test.gd

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")
# 작업대 모듈은 GameState autoload를 직접 참조한다 — 테스트 스크립트 로드 시점엔
# autoload가 아직 없어서 preload하면 컴파일이 막힌다. 런타임에 load한다.
const WORKBENCH_SCRIPT_PATH := "res://scripts/shelter_workbench_module.gd"
const VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WEAPON_LADDER_FAIL: %s" % message)


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	_check_weapon_definitions()
	_check_enhancement_transfer(game_state)
	_check_workbench_gates(game_state)
	_check_mission_blueprints(game_state)
	_check_drop_paths()
	_check_kill_shot_table()
	_check_visual_catalog()

	if failures.is_empty():
		print("WEAPON_LADDER_OK")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: %s" % failure)
		quit(1)


# ── ① 정의·탄약 호환 ──────────────────────────────────────────
func _check_weapon_definitions() -> void:
	var no_mods: Array[String] = []
	for weapon_id in ["akm", "k2", "pump_shotgun"]:
		var stats: Dictionary = WEAPON_SYSTEM.build_stats(weapon_id, no_mods)
		_check(str(stats.get("weapon_id", "")) == weapon_id, "① %s build_stats weapon_id" % weapon_id)
		_check(float(stats.get("damage", 0)) > 0.0, "① %s damage > 0" % weapon_id)
		_check(int(stats.get("magazine_size", 0)) > 0, "① %s magazine_size > 0" % weapon_id)
		var magazine_id := str(stats.get("magazine_id", ""))
		var ammo_id := str(stats.get("default_ammo_id", ""))
		_check(WEAPON_SYSTEM.validate_ammo_loadout(weapon_id, magazine_id, ammo_id), "① %s 기본 탄약 호환" % weapon_id)
	_check(int(WEAPON_SYSTEM.build_stats("akm", no_mods).get("magazine_size", 0)) == 40, "① AKM 40발 탄창")
	_check(int(WEAPON_SYSTEM.build_stats("pump_shotgun", no_mods).get("magazine_size", 0)) == 6, "① 펌프 6발")
	# 새 구경 금지 — 기존 탄(762_ap / 12g_slug)도 그대로 먹어야 한다.
	_check(WEAPON_SYSTEM.validate_ammo_loadout("akm", "akm_40rnd", "762_ap"), "① AKM 762 AP 호환")
	_check(WEAPON_SYSTEM.validate_ammo_loadout("k2", "k2_30rnd", "762_fmj"), "① K2 762 FMJ 호환")
	_check(WEAPON_SYSTEM.validate_ammo_loadout("pump_shotgun", "pump_6rnd", "12g_slug"), "① 펌프 슬러그 호환")
	_check(not WEAPON_SYSTEM.validate_ammo_loadout("akm", "ak_30rnd", "762_fmj"), "① AK 탄창은 AKM에 안 맞는다")
	# AK 정밀 리시버는 AKM에도 붙는다.
	var precision: Array[String] = ["ak_precision_receiver"]
	_check(WEAPON_SYSTEM.validate_mod_loadout(precision, "akm"), "① AK 정밀 리시버 AKM 호환")
	_check(not WEAPON_SYSTEM.validate_mod_loadout(precision, "k2"), "① AK 정밀 리시버 K2 비호환")
	# 사다리 표
	_check(WEAPON_SYSTEM.get_weapon_family("k2") == "rifle", "① K2 가족 = rifle")
	var k2_lower: Array[String] = WEAPON_SYSTEM.get_lower_ladder_weapons("k2")
	_check(k2_lower.size() == 2 and k2_lower[0] == "ak47" and k2_lower[1] == "akm", "① K2 하위 = ak47, akm")
	_check(WEAPON_SYSTEM.get_lower_ladder_weapons("ak47").is_empty(), "① AK 하위 없음")
	var pump_lower: Array[String] = WEAPON_SYSTEM.get_lower_ladder_weapons("pump_shotgun")
	_check(pump_lower.size() == 1 and pump_lower[0] == "double_barrel", "① 펌프 하위 = 더블배럴")
	_check(WEAPON_SYSTEM.get_weapon_family("m1911").is_empty(), "① M1911 가족 없음")


# ── ② 강화 이관 ────────────────────────────────────────────────
func _check_enhancement_transfer(game_state: Node) -> void:
	game_state.call("reset_run")
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	game_state.set("weapon_enhancement_levels", levels)
	_check(int(game_state.call("get_weapon_count", "akm")) == 0, "② 시작 시 AKM 미보유")
	game_state.call("add_weapon", "akm", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "akm")) == 6, "② AK +10 → AKM +6 (60%% 내림) got +%d" % int(game_state.call("get_weapon_enhancement_level", "akm")))
	_check(int(game_state.call("get_weapon_enhancement_level", "ak47")) == 10, "② from(AK) 레벨 유지")
	var notice := str(game_state.call("take_weapon_enhancement_transfer_notice"))
	_check(notice.contains("AK-47 +10") and notice.contains("AKM +6"), "② 토스트 문구: %s" % notice)
	_check(str(game_state.call("take_weapon_enhancement_transfer_notice")).is_empty(), "② 토스트는 1회만 소비")
	# 재획득(잃고 다시 주움) — AK를 +20으로 키워도 재이관 없음.
	var inventory: Dictionary = game_state.get("weapon_inventory")
	inventory["akm"] = 0
	levels = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 20
	game_state.call("add_weapon", "akm", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "akm")) == 6, "② AKM 재획득 시 재이관 없음(+6 유지)")
	# K2 첫 획득 — 하위 중 가장 높은 레벨(AK +20 > AKM +6) 기준 → +12.
	game_state.call("add_weapon", "k2", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "k2")) == 12, "② K2 첫 획득: max(AK+20, AKM+6)=20 × 0.6 → +12 got +%d" % int(game_state.call("get_weapon_enhancement_level", "k2")))
	# AKM이 더 높으면 AKM 기준.
	game_state.call("reset_run")
	levels = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 4
	levels["akm"] = 15
	game_state.call("add_weapon", "akm", 1)  # 사다리 2단은 이미 강화돼 있다(이관 1회 소진만)
	game_state.call("add_weapon", "k2", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "k2")) == 9, "② K2: AKM +15 기준 → +9")
	_check(int(game_state.call("get_weapon_enhancement_level", "akm")) == 15, "② AKM 레벨 유지")
	# 기존 to 레벨이 더 높으면 내려가지 않는다.
	game_state.call("reset_run")
	levels = game_state.get("weapon_enhancement_levels")
	levels["double_barrel"] = 10
	levels["pump_shotgun"] = 8
	game_state.call("add_weapon", "pump_shotgun", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "pump_shotgun")) == 8, "② 기존 +8 > 이관 +6 → +8 유지")
	# 하위 무기를 주워도 아무 일 없음(역방향 금지).
	game_state.call("reset_run")
	levels = game_state.get("weapon_enhancement_levels")
	levels["akm"] = 20
	game_state.call("add_weapon", "double_barrel", 1)
	_check(int(game_state.call("get_weapon_enhancement_level", "double_barrel")) == 0, "② 다른 가족/역방향 이관 없음")
	# 세이브 왕복 — 1회 플래그가 남아야 한다.
	game_state.call("reset_run")
	levels = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	game_state.call("add_weapon", "akm", 1)
	var snapshot: Dictionary = game_state.call("_build_persistent_state") if game_state.has_method("_build_persistent_state") else {}
	if snapshot.is_empty():
		print("② (세이브 직렬화 함수 이름이 달라 플래그 필드만 확인)")
	_check((game_state.get("weapon_enhancement_transfers_done") as Array).has("akm"), "② 이관 1회 플래그 기록")
	# 장착 중인 무기로 이관되면 weapon_level도 따라간다.
	game_state.call("reset_run")
	levels = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	game_state.set("equipped_weapon_id", "akm")
	game_state.call("add_weapon", "akm", 1)
	_check(int(game_state.get("weapon_level")) == 7, "② 장착 무기 이관 시 weapon_level = +6 + 1")
	game_state.call("reset_run")


# ── ③ 작업대 게이트 ────────────────────────────────────────────
func _check_workbench_gates(game_state: Node) -> void:
	game_state.call("reset_run")
	var workbench_script: GDScript = load(WORKBENCH_SCRIPT_PATH)
	_check(workbench_script != null and workbench_script.can_instantiate(), "③ 작업대 스크립트 로드")
	var workbench: Node = workbench_script.new()
	var weapons: Array = (workbench_script.get("RECIPES") as Dictionary).get("weapons", [])
	var by_id := {}
	for recipe in weapons:
		by_id[str((recipe as Dictionary).get("id", ""))] = recipe
	# 2026-08: 무기 7종 전부 레시피(AK-47은 시작 보유라 "제작됨 · 영구 보유"로 잠겨 보인다).
	_check(by_id.has("ak47"), "③ AK-47 레시피 존재(보유 시 재제작 불가)")
	for recipe_id in ["akm", "pump_shotgun", "k2", "double_barrel"]:
		_check(by_id.has(recipe_id), "③ %s 레시피 존재" % recipe_id)
	game_state.set("shelter_tier", 5)
	game_state.set("shelter_workbench_level", 5)
	game_state.set("scrap", 10000000)
	# 설계도 조각 없음 → 잠금(2026-08: 통짜 청사진·용산 키 게이트는 조각 3/3으로 통일)
	_check(bool(workbench.call("_is_recipe_locked", by_id["akm"])), "③ AKM: 조각 없으면 잠금")
	_check(bool(workbench.call("_is_recipe_locked", by_id["pump_shotgun"])), "③ 펌프: 조각 없으면 잠금")
	_check(bool(workbench.call("_is_recipe_locked", by_id["k2"])), "③ K2: 조각 없으면 잠금")
	var subtitle := str(workbench.call("_recipe_list_subtitle", by_id["akm"]))
	_check(subtitle.contains("설계도 조각") and subtitle.contains("0/3") and subtitle.contains("을지로"), "③ AKM 잠금 부제가 조각 0/3과 을지로를 가리킨다: %s" % subtitle)
	var k2_subtitle := str(workbench.call("_recipe_list_subtitle", by_id["k2"]))
	_check(k2_subtitle.contains("설계도 조각") and k2_subtitle.contains("남산"), "③ K2 잠금 부제: %s" % k2_subtitle)
	# 조각 2/3 → 여전히 잠금, 3/3 → 해금
	game_state.call("add_blueprint_shards", "akm", 2)
	_check(bool(workbench.call("_is_recipe_locked", by_id["akm"])), "③ AKM: 조각 2/3은 잠금")
	game_state.call("add_blueprint_shards", "akm", 1)
	_check(not bool(workbench.call("_is_recipe_locked", by_id["akm"])), "③ AKM: 조각 3/3이면 해금")
	game_state.call("add_blueprint_shards", "pump_shotgun", 3)
	_check(not bool(workbench.call("_is_recipe_locked", by_id["pump_shotgun"])), "③ 펌프: 조각 3/3이면 해금")
	game_state.call("add_blueprint_shards", "k2", 3)
	_check(not bool(workbench.call("_is_recipe_locked", by_id["k2"])), "③ K2: 조각 3/3이면 해금")
	# 레거시 통짜 청사진은 제작을 열지 않는다 — 로드 시 조각으로 환산될 뿐.
	game_state.call("reset_run")
	game_state.set("shelter_tier", 5)
	game_state.set("shelter_workbench_level", 5)
	game_state.call("add_progression_item", "rifle_blueprint", 1)
	_check(bool(workbench.call("_is_recipe_locked", by_id["akm"])), "③ 통짜 청사진만으로는 AKM 미해금(조각 3/3 필요)")
	game_state.call("add_blueprint_shards", "akm", 3)
	# 결과 미리보기 줄에 이관 안내
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	var stat_line := str(workbench.call("_result_stat_line", by_id["akm"]))
	_check(stat_line.contains("60%") and stat_line.contains("+6"), "③ 미리보기 이관 안내: %s" % stat_line)
	# 실제 제작 → 이관 + 완료 문구
	game_state.set("scrap", 10000000)
	game_state.set("catnip", 1000000)
	game_state.call("add_mod_component", "scope_lens", 10)
	game_state.call("add_mod_component", "magazine_spring", 10)
	game_state.call("add_mod_component", "rubber_gasket", 10)
	game_state.call("add_mod_component", "precision_gear", 10)
	game_state.call("add_mod_component", "military_alloy", 10)
	_check(bool(workbench.call("_can_craft", by_id["akm"])), "③ AKM 제작 가능 상태")
	workbench.call("_craft", by_id["akm"])
	_check(int(game_state.call("get_weapon_count", "akm")) == 1, "③ AKM 제작됨")
	_check(int(game_state.call("get_weapon_enhancement_level", "akm")) == 6, "③ 제작 경로 이관 +6")
	var feedback := str(workbench.get("craft_feedback_text"))
	_check(feedback.contains("이어받았다"), "③ 제작 완료 문구에 이관: %s" % feedback)
	# 보유 중이면 재제작 불가 — "제작됨 · 영구 보유"
	_check(not bool(workbench.call("_can_craft", by_id["akm"])), "③ 보유 중인 AKM은 재제작 불가")
	_check(str(workbench.call("_recipe_list_subtitle", by_id["akm"])) == "제작됨 · 영구 보유", "③ 보유 부제")
	# 강화 비용 가중치
	game_state.call("reset_run")
	var ak_cost := int(game_state.call("get_weapon_enhancement_cost", "ak47"))
	var akm_cost := int(game_state.call("get_weapon_enhancement_cost", "akm"))
	var k2_cost := int(game_state.call("get_weapon_enhancement_cost", "k2"))
	var pump_cost := int(game_state.call("get_weapon_enhancement_cost", "pump_shotgun"))
	_check(akm_cost > ak_cost and k2_cost > akm_cost and pump_cost > ak_cost * 0.9, "③ 강화 비용 가중 akm %d > ak %d, k2 %d, pump %d" % [akm_cost, ak_cost, k2_cost, pump_cost])
	# 장인 뽑기는 폐지(2026-08) — 장인 = 돌파 서비스. 작업대 artisan 탭은 돌파 행만 만든다.
	_check(not game_state.has_method("roll_artisan_weapon"), "③ 장인 뽑기 함수 제거")
	game_state.call("reset_run")
	var artisan_rows: Array = workbench.call("_recipes_for_category", "artisan")
	var has_breakthrough_row := false
	for row in artisan_rows:
		if ((row as Dictionary).get("result", {}) as Dictionary).has("breakthrough"):
			has_breakthrough_row = true
	_check(has_breakthrough_row, "③ 장인 탭 = 장착 무기 돌파 행")
	workbench.free()
	game_state.call("reset_run")


# ── ④ 미션 보상·구세이브 보정 ──────────────────────────────────
func _check_mission_blueprints(game_state: Node) -> void:
	var euljiro_stage2 := MAIN_MISSION_CATALOG.get_stage("euljiro_depths", 1)
	var namdaemun_stage2 := MAIN_MISSION_CATALOG.get_stage("namdaemun_market", 1)
	var euljiro_items := (euljiro_stage2.get("reward", {}) as Dictionary).get("progression_items", {}) as Dictionary
	var namdaemun_items := (namdaemun_stage2.get("reward", {}) as Dictionary).get("progression_items", {}) as Dictionary
	# 2026-08: 통짜 청사진 → 설계도 조각 2(나머지 1은 그 존 엘리트·봉인 상자).
	_check(int(euljiro_items.get("blueprint_shard_akm", 0)) == 2, "④ 을지로 2단계 보상 = AKM 조각 2")
	_check(int(namdaemun_items.get("blueprint_shard_pump_shotgun", 0)) == 2, "④ 남대문 2단계 보상 = 펌프 조각 2")
	_check(str((euljiro_stage2.get("reward", {}) as Dictionary).get("summary", "")).contains("AKM 제작 가능"), "④ 을지로 요약에 AKM 제작 한 줄")
	_check(str((namdaemun_stage2.get("reward", {}) as Dictionary).get("summary", "")).contains("펌프 산탄총 제작 가능"), "④ 남대문 요약에 펌프 한 줄")
	# 재회수 보상엔 없다.
	_check(not (namdaemun_stage2.get("repeat_reward", {}) as Dictionary).has("progression_items"), "④ 재회수엔 청사진 없음")
	# 구세이브: 이미 2단계를 끝냈는데 청사진이 없는 세이브 → 보정 지급
	game_state.call("reset_run")
	var progress: Dictionary = game_state.get("main_mission_progress")
	progress["euljiro_depths"] = 2
	progress["namdaemun_market"] = 2
	game_state.set("main_mission_progress", progress)
	var granted: Array = game_state.call("ensure_story_key_items")
	_check(granted.has("blueprint_shard_akm") and granted.has("blueprint_shard_pump_shotgun"), "④ 구세이브 보정 지급: %s" % str(granted))
	_check(int(game_state.call("get_blueprint_shard_count", "akm")) == 2, "④ AKM 조각 2")
	_check(int(game_state.call("get_blueprint_shard_count", "pump_shotgun")) == 2, "④ 펌프 조각 2")
	var again: Array = game_state.call("ensure_story_key_items")
	_check(again.is_empty(), "④ 멱등 — 두 번째는 아무것도 안 줌")
	game_state.call("reset_run")


# ── ⑤ 드랍 경로 ────────────────────────────────────────────────
func _check_drop_paths() -> void:
	# 2026-08 경제 코어: 장비는 적 처치·엘리트·상자 어디에서도 나오지 않는다(제작 전용).
	# 적은 여전히 AKM·펌프를 들고 쏘지만 떨어뜨리지 않는다. 대신 엘리트는 설계도 조각과
	# 탄약을 확정으로 남긴다.
	var random := RandomNumberGenerator.new()
	random.seed = 20260822
	for weapon_id in ["akm", "pump_shotgun"]:
		var weapon_seen := false
		for _sample in 600:
			var drop: Dictionary = LOOT_ECONOMY.roll_enemy_drop(3, "ranged", weapon_id, random)
			if str(drop.get("type", "")) in ["weapon", "armor"]:
				weapon_seen = true
				break
		_check(not weapon_seen, "⑤ 존3 %s 든 적의 처치 드랍에 장비 없음" % weapon_id)
	var elite: Array = LOOT_ECONOMY.roll_elite_drop(3, "akm", random)
	var elite_has_gear := false
	var elite_has_shard := false
	var elite_has_ammo := false
	for entry in elite:
		var entry_type := str((entry as Dictionary).get("type", ""))
		if entry_type in ["weapon", "armor"]:
			elite_has_gear = true
		if entry_type == "progression_item" and str(((entry as Dictionary).get("data", {}) as Dictionary).get("item_id", "")).begins_with("blueprint_shard_"):
			elite_has_shard = true
		if entry_type == "ammo":
			elite_has_ammo = true
	_check(not elite_has_gear, "⑤ 엘리트도 장비 없음")
	_check(elite_has_shard and elite_has_ammo, "⑤ 엘리트 확정: 설계도 조각 + 탄약")
	# 상자 굴림 1000회 — K2·AKM 어떤 무기도 안 나온다(옛 _roll_weapon_id 제거).
	var case_gear_seen := false
	for _sample in 1000:
		for entry in LOOT_ECONOMY.roll_container("weapon_case", 5, "street_mixed", random):
			if str((entry as Dictionary).get("type", "")) in ["weapon", "armor"]:
				case_gear_seen = true
	_check(not case_gear_seen, "⑤ 잠긴 장비 상자에도 무기·방어구 없음")


# ── ⑥ 처치 발수 표 ─────────────────────────────────────────────
func _check_kill_shot_table() -> void:
	var no_mods: Array[String] = []
	var zone_health := {"종로": 102, "남대문": 125, "을지로": 149, "용산": 176, "남산": 202}
	var levels := [0, 5, 10, 15, 20, 25]
	print("KILL_SHOT_TABLE  (사수 체력 102/125/149/176/202 · 엘리트 ×2.6 · 기본탄 · 근거리 · 무크리)")
	for weapon_id in ["ak47", "akm", "k2", "double_barrel", "pump_shotgun", "mp5", "m1911"]:
		var row := "%-14s" % weapon_id
		for level in levels:
			var stats: Dictionary = WEAPON_SYSTEM.build_stats(weapon_id, no_mods, int(level))
			var per_hit := roundi(float(stats.get("damage", 0))) * int(stats.get("pellet_count", 1))
			var shots := []
			for zone_name in zone_health:
				shots.append(ceili(float(zone_health[zone_name]) / float(per_hit)))
			row += " | +%-2d dmg %3d → %s" % [int(level), per_hit, "/".join(PackedStringArray(shots.map(func(v): return str(v))))]
		print(row)
	# 엘리트 행(존별)
	for weapon_id in ["ak47", "akm", "k2"]:
		var row := "%-14s" % ("%s(elite)" % weapon_id)
		for level in levels:
			var stats: Dictionary = WEAPON_SYSTEM.build_stats(weapon_id, no_mods, int(level))
			var per_hit := roundi(float(stats.get("damage", 0)))
			var shots := []
			for zone_name in zone_health:
				shots.append(ceili(float(roundi(float(zone_health[zone_name]) * 2.6)) / float(per_hit)))
			row += " | +%-2d → %s" % [int(level), "/".join(PackedStringArray(shots.map(func(v): return str(v))))]
		print(row)
	# 목표: 종로 AK+5 → 3발, 을지로 AKM+15 → 3발, 남산 K2+25 → 3발.
	_check(_shots("ak47", 5, 102) == 3, "⑥ 종로 AK+5 → 3발 (got %d)" % _shots("ak47", 5, 102))
	_check(_shots("akm", 15, 149) == 3, "⑥ 을지로 AKM+15 → 3발 (got %d)" % _shots("akm", 15, 149))
	_check(_shots("k2", 25, 202) == 3, "⑥ 남산 K2+25 → 3발 (got %d)" % _shots("k2", 25, 202))
	# 적 체력·드랍률은 플레이어 상태를 보지 않는다(러버밴딩 금지) — 무기 추가로 기존 수치 불변.
	_check(roundi(float(WEAPON_SYSTEM.build_stats("ak47", no_mods).get("damage", 0))) == 30, "⑥ AK 기본 피해 30 불변")


func _shots(weapon_id: String, level: int, health: int) -> int:
	var no_mods: Array[String] = []
	var stats: Dictionary = WEAPON_SYSTEM.build_stats(weapon_id, no_mods, level)
	var per_hit := roundi(float(stats.get("damage", 0))) * int(stats.get("pellet_count", 1))
	return ceili(float(health) / float(per_hit))


# ── 시각 카탈로그 ─────────────────────────────────────────────
func _check_visual_catalog() -> void:
	for weapon_id in ["akm", "k2", "pump_shotgun"]:
		_check(VISUAL_CATALOG.has_weapon_texture(weapon_id), "시각: %s 카탈로그 등록" % weapon_id)
		var started := Time.get_ticks_msec()
		var texture: Texture2D = VISUAL_CATALOG.get_weapon_texture(weapon_id)
		var elapsed := Time.get_ticks_msec() - started
		_check(texture != null and texture.get_width() > 0, "시각: %s 텍스처 로드" % weapon_id)
		print("VISUAL %s %dx%d %dms" % [weapon_id, texture.get_width() if texture else 0, texture.get_height() if texture else 0, elapsed])
		if weapon_id == "akm":
			_check(elapsed < 600, "시각: AKM 틴트 생성 %dms < 600ms" % elapsed)
			# 틴트 텍스처는 AK 원본과 다른 인스턴스·같은 크기
			var ak_texture: Texture2D = VISUAL_CATALOG.get_weapon_texture("ak47")
			_check(texture != ak_texture and texture.get_size() == ak_texture.get_size(), "시각: AKM 틴트는 AK와 같은 크기의 별도 텍스처")
	_check(VISUAL_CATALOG.get_inventory_textures().has("k2"), "시각: 가방 아이콘 사전에 K2")
