extends SceneTree

# 대개편 1단계(경제 코어) 스모크 테스트 — 헤드리스.
#   godot --headless --path . --script res://tests/gear_overhaul_smoke_test.gd
#
# ① 드랍 1000킬(존1~5 · 엘리트 · 보스 · 봉인 상자) 무기/방어구 0
# ② 사망 후 장비 전부 유지(장착+보유 무기·방어구·부착물·강화·조각), 재료·탄약·귀중품만 손실,
#    시체 전리품에 장비 없음
# ③ 설계도 3조각 → 제작 가능, 2조각은 잠금, 보유 시 재제작 불가("제작됨 · 영구 보유")
# ④ +9 → +10 강화 뒤 돌파 게이트(강화 막힘) · try_breakthrough가 인장·정밀 기어·고철×3을 소모,
#    +50 돌파는 군용 합금 추가 · +31/+61 희귀 부품 단계
# ⑤ 방어구 강화 효과(×1.2@+10 · 수렴 1.6)와 피스 합산 상한 0.70 · 비용 곡선 · 이관 60%
# ⑥ 구세이브 통짜 청사진 → 조각 3 환산(가방·창고) · 세이브 v13 왕복
# ⑦ 장비 가방 칸 0 · 버리기 보호 · 존 장비 목표 문구

const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
# raid_loss_manager·requisition·작업대는 GameState autoload를 직접 참조한다 — 테스트
# 스크립트 로드 시점엔 autoload가 없어서 preload하면 컴파일이 막힌다. 런타임에 load한다.
const RAID_LOSS_MANAGER_PATH := "res://scripts/raid_loss_manager.gd"
const SHELTER_REQUISITION_PATH := "res://scripts/shelter/requisition.gd"
const WORKBENCH_SCRIPT_PATH := "res://scripts/shelter_workbench_module.gd"

var failures := 0
# 섹션이 스크립트 에러로 중간에 끊기면 _check가 안 돌아 "실패 0"으로 통과해 버린다 —
# 각 섹션 끝에서 완료 표시를 남기고 마지막에 7개 전부인지 본다.
var sections_done: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	_check_no_gear_drops(game_state)
	_check_death_keeps_gear(game_state)
	_check_crafting_gate(game_state)
	_check_breakthrough(game_state)
	_check_armor_enhancement(game_state)
	_check_legacy_migration(game_state)
	_check_slots_and_texts(game_state)
	_check(sections_done.size() == 7, "모든 섹션 완주 (done=%s)" % str(sections_done))

	if failures > 0:
		push_error("GEAR_OVERHAUL_FAILED failures=%d" % failures)
		quit(1)
		return
	print("GEAR_OVERHAUL_OK")
	quit(0)


# ── ① 드랍 1000킬 장비 0 ─────────────────────────────────────────
func _check_no_gear_drops(game_state: Node) -> void:
	game_state.call("reset_run")
	var random := RandomNumberGenerator.new()
	random.seed = 20260821
	var gear := 0
	var kills := 0
	var shards := 0
	for stage in range(1, 6):
		for _kill in 200:
			kills += 1
			var melee := random.randf() < 0.3
			var drop: Dictionary = LOOT_ECONOMY.roll_enemy_drop(
				stage, "melee" if melee else "ranged", "baseball_bat" if melee else "akm", random, random.randf() < 0.5
			)
			var tally: Dictionary = LOOT_ECONOMY._classify_gear_drop(drop)
			gear += int(tally.get("weapon", 0)) + int(tally.get("armor", 0))
			shards += int(tally.get("shard", 0))
		for entry in LOOT_ECONOMY.roll_elite_drop(stage, "akm", random):
			var tally: Dictionary = LOOT_ECONOMY._classify_gear_drop(entry as Dictionary)
			gear += int(tally.get("weapon", 0)) + int(tally.get("armor", 0))
		for entry in LOOT_ECONOMY.roll_boss_drops(stage, random):
			var tally: Dictionary = LOOT_ECONOMY._classify_gear_drop(entry as Dictionary)
			gear += int(tally.get("weapon", 0)) + int(tally.get("armor", 0))
		for container_type in ["weapon_case", "secure_cache", "clothing_cache", "street_cache"]:
			for _sample in 30:
				for entry in LOOT_ECONOMY.roll_container(container_type, stage, "luxury_core", random, true):
					var tally: Dictionary = LOOT_ECONOMY._classify_gear_drop(entry as Dictionary)
					gear += int(tally.get("weapon", 0)) + int(tally.get("armor", 0))
	_check(kills == 1000, "① 1000킬 굴림")
	_check(gear == 0, "① 무기/방어구 드랍 0 (got %d)" % gear)
	_check(shards > 30, "① 설계도 조각은 나온다 (got %d)" % shards)
	# 존5 조각 풀에 K2가 있다(get_gear_stage_for_zone은 5까지 센다).
	var namsan: Dictionary = game_state.get_raid_zone("namsan_core")
	_check(int(LOOT_ECONOMY.get_gear_stage_for_zone(namsan)) == 5, "① 남산 장비 단계 5")
	var k2_seen := false
	for _sample in 200:
		if str(LOOT_ECONOMY.roll_blueprint_shard_recipe(5, random)) == "k2":
			k2_seen = true
			break
	_check(k2_seen, "① 존5 조각 풀에 K2")
	# 완성 제외: K2를 보유하면 존5 풀은 아래 존(존4 T3)으로 내려간다.
	game_state.call("add_weapon", "k2", 1)
	var fallback_seen := false
	for _sample in 50:
		var recipe_id := str(LOOT_ECONOMY.roll_blueprint_shard_recipe(5, random))
		_check(recipe_id != "k2", "① 보유 중인 K2 조각은 안 나온다")
		if (LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE[4] as Array).has(recipe_id):
			fallback_seen = true
	_check(fallback_seen, "① 완성 존은 아래 존 미완성으로 대체")
	sections_done.append("①")
	game_state.call("reset_run")


# ── ② 사망 후 장비 전부 유지 ─────────────────────────────────────
func _check_death_keeps_gear(game_state: Node) -> void:
	game_state.call("reset_run")
	game_state.call("add_weapon", "mp5", 1)
	game_state.call("add_weapon", "akm", 1)
	game_state.call("add_equipment", "scav_vest", 1)
	game_state.call("equip_equipment", "scav_vest")
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("add_weapon_mod", "scope_2x", 1)
	var mods: Array[String] = ["scope_2x"]
	game_state.set("equipped_weapon_mods", mods)
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 12
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 4
	game_state.call("add_blueprint_shards", "mp5", 2)
	game_state.call("add_progression_item", "artisan_seal", 1)
	game_state.call("add_mod_component", "scope_lens", 3)
	game_state.call("add_mod_component", "precision_gear", 2)
	game_state.call("set_ammo_count", "762_fmj", 120)
	game_state.set("medkits", 2)
	game_state.set("canned_food", 5)
	(game_state.get("valuable_inventory") as Dictionary)["gold_tooth"] = 1
	var loss_manager: GDScript = load(RAID_LOSS_MANAGER_PATH)
	var corpse: Dictionary = loss_manager.build_death_corpse_loot()
	_check((corpse.get("weapon_inventory", {}) as Dictionary).is_empty(), "② 시체에 무기 없음")
	_check((corpse.get("equipment_inventory", {}) as Dictionary).is_empty(), "② 시체에 방어구 없음")
	_check((corpse.get("weapon_mod_inventory", {}) as Dictionary).is_empty(), "② 시체에 부착물 없음")
	_check((corpse.get("progression_item_inventory", {}) as Dictionary).is_empty(), "② 시체에 조각·인장 없음")
	_check(int((corpse.get("mod_component_inventory", {}) as Dictionary).get("scope_lens", 0)) == 3, "② 시체에 부품(재료)")
	_check(int((corpse.get("ammo_inventory", {}) as Dictionary).get("762_fmj", 0)) == 120, "② 시체에 탄약")
	game_state.call("clear_carried_raid_inventory_after_death")
	_check(int(game_state.call("get_weapon_count", "ak47")) == 1 and int(game_state.call("get_weapon_count", "mp5")) == 1 and int(game_state.call("get_weapon_count", "akm")) == 1, "② 무기 전부 유지(장착+보유)")
	_check(bool(game_state.get("has_ak")) and str(game_state.get("equipped_weapon_id")) == "ak47", "② 장착 상태 유지")
	_check(str(game_state.get("equipped_body_armor_id")) == "scav_vest", "② 장착 방어구 유지")
	_check(int(game_state.call("get_equipment_count", "riot_vest")) == 1, "② 보유 방어구 유지")
	_check(int(game_state.call("get_weapon_mod_count", "scope_2x")) == 1 and (game_state.get("equipped_weapon_mods") as Array).has("scope_2x"), "② 부착물 유지")
	_check(int(game_state.call("get_weapon_enhancement_level", "ak47")) == 12 and int(game_state.call("get_armor_enhancement_level", "scav_vest")) == 4, "② 강화 유지")
	_check(int(game_state.call("get_blueprint_shard_count", "mp5")) == 2 and int(game_state.call("get_progression_item_count", "artisan_seal")) == 1, "② 조각·인장 유지(0칸 쉘터 자산)")
	_check(int(game_state.call("get_mod_component_count", "scope_lens")) == 0 and int(game_state.call("get_mod_component_count", "precision_gear")) == 0, "② 부품(희귀 포함)은 잃는다")
	_check(int(game_state.call("get_ammo_count", "762_fmj")) == 0 and int(game_state.get("medkits")) == 0 and int(game_state.get("canned_food")) == 0, "② 탄약·구급약·통조림 손실")
	_check((game_state.get("valuable_inventory") as Dictionary).is_empty(), "② 귀중품 손실")
	var summary := str(loss_manager.format_loss_summary(corpse))
	_check(summary.contains("전부 손에 남았습니다"), "② 손실 요약 문구: %s" % summary.split("\n")[summary.split("\n").size() - 2])
	# 판 포기도 같은 규칙
	game_state.call("add_weapon", "double_barrel", 1)
	game_state.call("apply_raid_abandonment")
	_check(int(game_state.call("get_weapon_count", "double_barrel")) == 1, "② 판 포기에도 무기 유지")
	game_state.call("consume_abandonment_notice")
	sections_done.append("②")
	game_state.call("reset_run")


# ── ③ 제작 게이트 ─────────────────────────────────────────────────
func _check_crafting_gate(game_state: Node) -> void:
	game_state.call("reset_run")
	var workbench_script: GDScript = load(WORKBENCH_SCRIPT_PATH)
	var workbench: Node = workbench_script.new()
	var armor_recipes: Array = (workbench_script.get("RECIPES") as Dictionary).get("armor", [])
	var weapon_recipes: Array = (workbench_script.get("RECIPES") as Dictionary).get("weapons", [])
	_check(armor_recipes.size() == 9, "③ 방어구 레시피 9종 (got %d)" % armor_recipes.size())
	_check(weapon_recipes.size() == 7, "③ 무기 레시피 7종 (got %d)" % weapon_recipes.size())
	var by_id := {}
	for recipe in armor_recipes + weapon_recipes:
		by_id[str((recipe as Dictionary).get("id", ""))] = recipe
		_check(not str((recipe as Dictionary).get("gear_id", "")).is_empty(), "③ %s gear_id" % str((recipe as Dictionary).get("id", "")))
	_check(bool(workbench.call("_is_gear_recipe_owned", by_id["ak47"])), "③ 시작 AK는 보유 → 제작됨")
	_check(str(workbench.call("_recipe_list_subtitle", by_id["ak47"])) == "제작됨 · 영구 보유", "③ AK 부제 '제작됨 · 영구 보유'")
	game_state.set("scrap", 100000)
	game_state.call("add_mod_component", "rubber_gasket", 5)
	game_state.call("add_mod_component", "magazine_spring", 5)
	game_state.call("add_mod_component", "scope_lens", 5)
	var vest: Dictionary = by_id["craft_scav_vest"]
	_check(bool(workbench.call("_is_recipe_locked", vest)), "③ 조각 0/3 → 잠금")
	game_state.call("add_blueprint_shards", "scav_vest", 2)
	_check(bool(workbench.call("_is_recipe_locked", vest)) and not bool(workbench.call("_can_craft", vest)), "③ 조각 2/3 → 여전히 잠금")
	var subtitle := str(workbench.call("_recipe_list_subtitle", vest))
	_check(subtitle.contains("2/3") and subtitle.contains("종로"), "③ 잠금 부제가 2/3과 출처(종로)를 말한다: %s" % subtitle)
	game_state.call("add_blueprint_shards", "scav_vest", 1)
	_check(bool(game_state.call("is_blueprint_unlocked", "scav_vest")), "③ 3/3 해금")
	_check(bool(workbench.call("_can_craft", vest)), "③ 조각 3/3 + 재료 → 제작 가능")
	var scrap_before := int(game_state.get("scrap"))
	workbench.call("_craft", vest)
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 1, "③ 조끼 제작됨")
	_check(int(game_state.get("scrap")) == scrap_before - 4300, "③ 고철 4300 소모")
	_check(int(game_state.call("get_blueprint_shard_count", "scav_vest")) == 3, "③ 조각은 소모되지 않는 해금 토큰")
	_check(not bool(workbench.call("_can_craft", vest)), "③ 보유 중 → 재제작 불가")
	_check(str(workbench.call("_recipe_list_subtitle", vest)) == "제작됨 · 영구 보유", "③ 보유 부제")
	# 장착해도(가방 0) 여전히 보유
	game_state.call("equip_equipment", "scav_vest")
	_check(bool(game_state.call("is_gear_owned", "scav_vest")) and not bool(workbench.call("_can_craft", vest)), "③ 장착 중에도 보유 판정")
	# 창고에 넣어도 보유
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("deposit_storage_item", "equipment", "riot_vest", 1, false)
	_check(bool(game_state.call("is_gear_owned", "riot_vest")), "③ 창고 보관도 보유")
	# 무기: 조각 3/3 + 재료 → 제작, 보유 → 불가. 시작 부품 지급에 총이 없다.
	game_state.call("claim_workbench_starter_parts")
	_check(int(game_state.call("get_weapon_count", "m1911")) == 0 and int(game_state.call("get_weapon_count", "mp5")) == 0, "③ 시작 부품 지급에 무기 없음")
	game_state.call("add_blueprint_shards", "m1911", 3)
	_check(bool(workbench.call("_can_craft", by_id["m1911"])), "③ M1911 제작 가능")
	workbench.call("_craft", by_id["m1911"])
	_check(int(game_state.call("get_weapon_count", "m1911")) == 1 and not bool(workbench.call("_can_craft", by_id["m1911"])), "③ M1911 제작 후 재제작 불가")
	# 레시피 비용 표 출력(보고용)
	print("RECIPE_COST_TABLE")
	for recipe in armor_recipes + weapon_recipes:
		var r := recipe as Dictionary
		print("  %-22s tier%d wb%d cost=%s" % [str(r.get("id", "")), int(r.get("required_tier", 1)), int(r.get("required_workbench", 1)), JSON.stringify(r.get("cost", {}))])
	workbench.free()
	sections_done.append("③")
	game_state.call("reset_run")


# ── ④ 돌파 ───────────────────────────────────────────────────────
func _check_breakthrough(game_state: Node) -> void:
	game_state.call("reset_run")
	game_state.set("scrap", 100_000_000)
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 9
	_check(not bool(game_state.call("is_breakthrough_required", "weapon", "ak47")), "④ +9는 돌파 불필요")
	_check(bool(game_state.call("try_enhance_weapon", "ak47")), "④ +9 → +10 강화")
	_check(int(game_state.call("get_weapon_enhancement_level", "ak47")) == 10, "④ +10")
	_check(bool(game_state.call("is_breakthrough_required", "weapon", "ak47")), "④ +10에서 돌파 필요")
	_check(not bool(game_state.call("try_enhance_weapon", "ak47")), "④ 돌파 전 강화 막힘")
	var cost: Dictionary = game_state.call("get_breakthrough_cost", "weapon", "ak47")
	# 대개편 3단계: 정밀 기어 (L/10)×2 → +10은 2개 (인장 1, 합금 없음).
	_check(int(cost.get("artisan_seal", 0)) == 1 and int(cost.get("precision_gear", 0)) == 2 and not cost.has("military_alloy"), "④ +10 돌파 비용: 인장 1 · 정밀 기어 2 (got %s)" % JSON.stringify(cost))
	_check(int(cost.get("scrap", 0)) == int(game_state.call("get_weapon_enhancement_cost", "ak47")) * 3, "④ 돌파 고철 = 단계 비용 × 3")
	_check(not bool(game_state.call("try_breakthrough", "weapon", "ak47")), "④ 인장 없으면 돌파 실패")
	_check(str(game_state.call("get_breakthrough_block_reason", "weapon", "ak47")).contains("장인의 인장"), "④ 사유: 인장 부족")
	game_state.call("add_progression_item", "artisan_seal", 2)
	# 대개편 3단계: +10 돌파 기어 2개 — 가방 1 + 창고 2를 두고 가방 우선 소모(창고 1 남음)를 본다.
	game_state.call("add_mod_component", "precision_gear", 1)
	(game_state.get("storage_inventory") as Array).append({"type": "component", "id": "precision_gear", "count": 2})
	var scrap_before := int(game_state.get("scrap"))
	_check(bool(game_state.call("try_breakthrough", "weapon", "ak47")), "④ 인장+기어+고철 → 돌파 성공")
	_check(int(game_state.call("get_progression_item_count", "artisan_seal")) == 1, "④ 인장 1 소모")
	_check(int(game_state.call("get_owned_component_total", "precision_gear")) == 1 and int(game_state.call("get_mod_component_count", "precision_gear")) == 0, "④ 정밀 기어 2 소모(가방 우선, 창고 1 남음)")
	_check(int(game_state.get("scrap")) == scrap_before - int(cost.get("scrap", 0)), "④ 고철 소모")
	_check(not bool(game_state.call("is_breakthrough_required", "weapon", "ak47")), "④ 돌파 뒤 게이트 해제")
	_check(bool(game_state.call("try_enhance_weapon", "ak47")) and int(game_state.call("get_weapon_enhancement_level", "ak47")) == 11, "④ +11 강화 열림")
	_check(not bool(game_state.call("try_breakthrough", "weapon", "ak47")), "④ 돌파 단계 아니면 거절")
	# 대개편 3단계 돌파 재료: 인장 L/10 · 정밀 기어 (L/10)×2 · 군용 합금(+50~) (L−40)/5.
	# +50: 인장 5 · 기어 10 · 합금 2, +90: 인장 9 · 기어 18 · 합금 10.
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 50
	var cost50: Dictionary = game_state.call("get_breakthrough_cost", "weapon", "ak47")
	_check(int(cost50.get("artisan_seal", 0)) == 5 and int(cost50.get("precision_gear", 0)) == 10 and int(cost50.get("military_alloy", 0)) == 2, "④ +50 돌파: 인장 5 · 기어 10 · 합금 2 (got %s)" % JSON.stringify(cost50))
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 90
	var cost90: Dictionary = game_state.call("get_breakthrough_cost", "weapon", "ak47")
	_check(int(cost90.get("artisan_seal", 0)) == 9 and int(cost90.get("precision_gear", 0)) == 18 and int(cost90.get("military_alloy", 0)) == 10, "④ +90 돌파: 인장 9 · 기어 18 · 합금 10")
	# 강화 부품 단계(대개편 3단계): +31~80 정밀 기어 1, +81~ 기어 2. 군용 합금은 돌파 전용(강화에 없음).
	# 종류당 개수 +1~40 1 · +41~80 2 · +81~99 3.
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 29
	var parts30: Dictionary = game_state.call("get_weapon_enhancement_part_cost", "ak47")
	_check(not parts30.has("precision_gear") and not parts30.has("military_alloy"), "④ +30까지 일반 부품만")
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 30
	var parts31: Dictionary = game_state.call("get_weapon_enhancement_part_cost", "ak47")
	_check(int(parts31.get("precision_gear", 0)) == 1 and not parts31.has("military_alloy"), "④ +31부터 정밀 기어 1")
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 60
	var parts61: Dictionary = game_state.call("get_weapon_enhancement_part_cost", "ak47")
	_check(int(parts61.get("precision_gear", 0)) == 1 and not parts61.has("military_alloy") and int(parts61.get("magazine_spring", 0)) == 2, "④ +61 기어 1 · 합금 없음 · 일반 부품 종류당 2 (got %s)" % JSON.stringify(parts61))
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 80
	var parts81: Dictionary = game_state.call("get_weapon_enhancement_part_cost", "ak47")
	_check(int(parts81.get("precision_gear", 0)) == 2 and int(parts81.get("magazine_spring", 0)) == 3, "④ +81부터 기어 2 · 일반 종류당 3")
	# 방어구 돌파도 같은 규칙(+10 게이트)
	game_state.call("add_equipment", "scav_vest", 1)
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 10
	_check(not bool(game_state.call("try_enhance_armor", "scav_vest")), "④ 방어구 +10 돌파 게이트")
	game_state.call("add_mod_component", "precision_gear", 2)
	_check(bool(game_state.call("try_breakthrough", "armor", "scav_vest")), "④ 방어구 돌파 성공(마지막 인장 소모)")
	_check(int(game_state.call("get_progression_item_count", "artisan_seal")) == 0, "④ 인장 0")
	_check(bool(game_state.call("try_enhance_armor", "scav_vest")) and int(game_state.call("get_armor_enhancement_level", "scav_vest")) == 11, "④ 방어구 +11")
	# 수치 표(보고용)
	print("ENHANCEMENT_COST_TABLE")
	for level in [10, 30, 50, 99]:
		(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = level - 1
		(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = level - 1
		(game_state.get("armor_enhancement_levels") as Dictionary)["military_vest"] = level - 1
		print("  +%d weapon(ak47) scrap=%d parts=%s | armor T1 scrap=%d T3 scrap=%d parts=%s | armor_mult=%.3f" % [
			level,
			int(game_state.call("get_weapon_enhancement_cost", "ak47")),
			JSON.stringify(game_state.call("get_weapon_enhancement_part_cost", "ak47")),
			int(game_state.call("get_armor_enhancement_cost", "scav_vest")),
			int(game_state.call("get_armor_enhancement_cost", "military_vest")),
			JSON.stringify(game_state.call("get_armor_enhancement_part_cost", "scav_vest")),
			1.0 + 0.6 * (1.0 - pow(0.96, float(level))),
		])
	for level in [10, 20, 50, 90]:
		(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = level
		(game_state.get("gear_breakthroughs") as Dictionary).clear()
		print("  breakthrough +%d weapon(ak47) cost=%s" % [level, JSON.stringify(game_state.call("get_breakthrough_cost", "weapon", "ak47"))])
	sections_done.append("④")
	game_state.call("reset_run")


# ── ⑤ 방어구 강화 효과·상한·이관 ────────────────────────────────
func _check_armor_enhancement(game_state: Node) -> void:
	game_state.call("reset_run")
	_check(is_equal_approx(float(game_state.call("get_armor_enhancement_multiplier", "riot_vest")), 1.0), "⑤ +0 배율 1.0")
	(game_state.get("armor_enhancement_levels") as Dictionary)["riot_vest"] = 10
	var mult10 := float(game_state.call("get_armor_enhancement_multiplier", "riot_vest"))
	_check(absf(mult10 - (1.0 + 0.6 * (1.0 - pow(0.96, 10.0)))) < 0.0001, "⑤ +10 배율 ≈ 1.20 (got %.3f)" % mult10)
	game_state.call("add_equipment", "riot_vest", 1)
	game_state.call("equip_equipment", "riot_vest")
	var damage_mult := float(game_state.call("get_equipment_damage_multiplier"))
	_check(absf(damage_mult - (1.0 - 0.30 * mult10)) < 0.001, "⑤ 피해 배율 = 1 − 0.30×1.20 (got %.3f)" % damage_mult)
	_check(absf(float(game_state.call("get_equipment_effective_damage_reduction", "riot_vest")) - 0.30 * mult10) < 0.001, "⑤ 피스 실효 감소")
	# 레벨 접미사(@n)와 강화가 함께 곱해진다 — 키는 기본 id.
	game_state.call("add_equipment", "riot_vest@5", 1)
	game_state.call("equip_equipment", "riot_vest@5")
	_check(int(game_state.call("get_armor_enhancement_level", "riot_vest@5")) == 10, "⑤ @5도 같은 강화 키")
	# 상한 0.70: 군납 3종 +99 → 0.58×1.59 ≈ 0.92 → 0.70에서 멈춘다(배율 하한 0.30).
	for base_id in ["military_vest", "military_helmet", "assault_boots"]:
		game_state.call("add_equipment", base_id, 1)
		game_state.call("equip_equipment", base_id)
		(game_state.get("armor_enhancement_levels") as Dictionary)[base_id] = 99
	var capped := float(game_state.call("get_equipment_damage_multiplier"))
	_check(is_equal_approx(capped, 0.30), "⑤ 합산 상한 0.70 → 배율 0.30 (got %.3f)" % capped)
	_check(float(game_state.call("get_damage_taken_multiplier")) <= 0.30 + 0.0001, "⑤ 피해 계산 단일 함수 경유")
	# 비용 곡선 400×가족계수×1.26^L(+1~30; 대개편 3단계에서 기본 600 → 400, +31부터 3구간 지수)
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 0
	(game_state.get("armor_enhancement_levels") as Dictionary)["riot_vest"] = 0
	(game_state.get("armor_enhancement_levels") as Dictionary)["military_vest"] = 0
	_check(int(game_state.call("get_armor_enhancement_cost", "scav_vest")) == 400, "⑤ T1 +0→+1 400")
	_check(int(game_state.call("get_armor_enhancement_cost", "riot_vest")) == 600, "⑤ T2 ×1.5")
	_check(int(game_state.call("get_armor_enhancement_cost", "military_vest")) == 880, "⑤ T3 ×2.2")
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 10
	_check(int(game_state.call("get_armor_enhancement_cost", "scav_vest")) == roundi(400.0 * pow(1.26, 10.0)), "⑤ +10 비용 400×1.26^10")
	# 이관 60%: 누더기 조끼 +10 → 진압 조끼 첫 보유 +6, 1회만.
	game_state.call("reset_run")
	game_state.call("add_equipment", "scav_vest", 1)
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 10
	game_state.call("add_equipment", "riot_vest", 1)
	_check(int(game_state.call("get_armor_enhancement_level", "riot_vest")) == 6, "⑤ 방어구 이관 +10 → +6 (got %d)" % int(game_state.call("get_armor_enhancement_level", "riot_vest")))
	_check(str(game_state.call("take_armor_enhancement_transfer_notice")).contains("이어받았다"), "⑤ 이관 토스트")
	(game_state.get("equipment_inventory") as Dictionary)["riot_vest"] = 0
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 20
	game_state.call("add_equipment", "riot_vest", 1)
	_check(int(game_state.call("get_armor_enhancement_level", "riot_vest")) == 6, "⑤ 재획득 시 재이관 없음")
	game_state.call("add_equipment", "military_vest", 1)
	_check(int(game_state.call("get_armor_enhancement_level", "military_vest")) == 12, "⑤ T3 첫 보유: max(T1+20, T2+6)×0.6 → +12")
	# 신발 강화는 이동 보너스에 곱해진다.
	game_state.call("reset_run")
	game_state.call("add_equipment", "patched_sneakers", 1)
	game_state.call("equip_equipment", "patched_sneakers")
	var speed_base := float(game_state.call("get_move_speed_multiplier"))
	(game_state.get("armor_enhancement_levels") as Dictionary)["patched_sneakers"] = 30
	_check(float(game_state.call("get_move_speed_multiplier")) > speed_base, "⑤ 신발 강화 → 이동 보너스 증가")
	sections_done.append("⑤")
	game_state.call("reset_run")


# ── ⑥ 구세이브 청사진 → 조각 환산 ───────────────────────────────
func _check_legacy_migration(game_state: Node) -> void:
	game_state.call("reset_run")
	(game_state.get("progression_item_inventory") as Dictionary)["akm_blueprint"] = 1
	(game_state.get("progression_item_inventory") as Dictionary)["shotgun_blueprint"] = 1
	(game_state.get("storage_inventory") as Array).append({"type": "progression", "id": "pump_blueprint", "count": 1})
	game_state.call("add_blueprint_shards", "akm", 1)
	var converted: Array = game_state.call("_migrate_legacy_blueprints")
	_check(converted.has("akm") and converted.has("double_barrel") and converted.has("pump_shotgun"), "⑥ 환산 대상 3종 (got %s)" % str(converted))
	_check(int(game_state.call("get_blueprint_shard_count", "akm")) == 3, "⑥ AKM 조각 1 → 3(채움)")
	_check(int(game_state.call("get_blueprint_shard_count", "double_barrel")) == 3, "⑥ 산탄총 청사진 → 더블배럴 조각 3")
	_check(int(game_state.call("get_blueprint_shard_count", "pump_shotgun")) == 3, "⑥ 창고 펌프 청사진 → 조각 3")
	_check(int(game_state.call("get_progression_item_count", "akm_blueprint")) == 0 and int(game_state.call("get_progression_item_count", "pump_blueprint")) == 0, "⑥ 통짜 청사진 제거(가방·창고)")
	_check(bool(game_state.call("is_blueprint_unlocked", "akm")), "⑥ 환산 후 AKM 제작 해금")
	# 세이브 v13 왕복 — 방어구 강화·돌파·조각이 살아남는다. 구세이브(v12) JSON 로드도 환산된다.
	var test_save_path := "res://.godot/gear_overhaul_smoke.json"
	game_state.set("persistence_enabled", true)
	game_state.set("persistence_path", test_save_path)
	(game_state.get("armor_enhancement_levels") as Dictionary)["scav_vest"] = 7
	(game_state.get("gear_breakthroughs") as Dictionary)["weapon:ak47"] = 10
	game_state.call("add_progression_item", "artisan_seal", 2)
	_check(bool(game_state.call("save_persistent_state")), "⑥ 저장")
	(game_state.get("armor_enhancement_levels") as Dictionary).clear()
	(game_state.get("gear_breakthroughs") as Dictionary).clear()
	game_state.set("progression_item_inventory", {})
	_check(bool(game_state.call("load_persistent_state")), "⑥ 로드")
	_check(int(game_state.call("get_armor_enhancement_level", "scav_vest")) == 7, "⑥ 방어구 강화 왕복")
	_check(int(game_state.call("get_breakthrough_level_done", "weapon", "ak47")) == 10, "⑥ 돌파 기록 왕복")
	_check(int(game_state.call("get_progression_item_count", "artisan_seal")) == 2, "⑥ 인장 왕복")
	_check(int(game_state.call("get_blueprint_shard_count", "akm")) == 3, "⑥ 조각 왕복")
	# v12 형식의 구세이브 — 통짜 청사진·artisan_pity·장비 보유.
	var legacy := {
		"version": 12,
		"progression_item_inventory": {"rifle_blueprint": 1, "sealed_zone_keycard": 0},
		"storage_inventory": [{"type": "progression", "id": "shotgun_blueprint", "count": 2}],
		"weapon_inventory": {"ak47": 1, "mp5": 1},
		"equipment_inventory": {"scav_vest": 2, "riot_vest@3": 1},
		"artisan_pity": 7,
		"opening_completed": true,
	}
	var file := FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(bool(game_state.call("load_persistent_state")), "⑥ v12 로드")
	_check(int(game_state.call("get_blueprint_shard_count", "akm")) == 3, "⑥ v12 소총 청사진 → AKM 조각 3")
	_check(int(game_state.call("get_blueprint_shard_count", "double_barrel")) == 3, "⑥ v12 창고 산탄총 청사진 → 더블배럴 조각 3")
	_check(int(game_state.call("get_progression_item_count", "rifle_blueprint")) == 0 and int(game_state.call("get_progression_item_count", "shotgun_blueprint")) == 0, "⑥ v12 통짜 제거")
	_check(int(game_state.call("get_equipment_count", "scav_vest")) == 2 and int(game_state.call("get_equipment_count", "riot_vest@3")) == 1, "⑥ 구세이브 장비는 그대로 보유")
	_check(int(game_state.call("get_mod_component_count", "precision_gear")) == 0 and (game_state.get("mod_component_inventory") as Dictionary).has("military_alloy"), "⑥ 희귀 부품 키 기본값")
	game_state.set("persistence_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	sections_done.append("⑥")
	game_state.call("reset_run")


# ── ⑦ 버리기 보호 · 문구 ──────────────────────────────────────
# 칸 비용 단언은 가방 무제한화(2026-08-30)로 폐지 — 칸 자체가 없다.
func _check_slots_and_texts(game_state: Node) -> void:
	game_state.call("reset_run")
	_check(RAID_ITEM_ECONOMY.is_protected("weapon", "mp5") and RAID_ITEM_ECONOMY.is_protected("equipment", "scav_vest"), "⑦ 장비는 버리기 보호")
	# 상인 매대에 장비 없음
	for good in game_state.MERCHANT_SUNDRY_GOODS + game_state.MERCHANT_AMMO_GOODS + game_state.MERCHANT_SELL_GOODS:
		_check(str((good as Dictionary).get("type", "")) != "equipment", "⑦ 상인 매대 장비 없음: %s" % str((good as Dictionary).get("id", "")))
	# 존 장비 목표 문구 — "세트 제작 n/3"
	var requisition: GDScript = load(SHELTER_REQUISITION_PATH)
	var gear: Dictionary = requisition.get_zone_gear_goal("jongno_outskirts")
	_check(str(gear.get("text", "")).begins_with("권장: T1 세트 제작 0/3"), "⑦ 존 목표 문구: %s" % str(gear.get("text", "")))
	# 카탈로그: 새 품목 4종 + 조각 16종
	for item_id in ["precision_gear", "military_alloy", "artisan_seal"]:
		_check(LOOT_ECONOMY.ITEM_CATALOG.has(item_id), "⑦ 카탈로그 %s" % item_id)
	var shard_count := 0
	for item_id in LOOT_ECONOMY.ITEM_CATALOG.keys():
		if str(item_id).begins_with("blueprint_shard_"):
			shard_count += 1
	_check(shard_count == 16, "⑦ 설계도 조각 16종 (got %d)" % shard_count)
	for recipe_id in game_state.GEAR_WEAPON_RECIPE_IDS + game_state.GEAR_ARMOR_RECIPE_IDS:
		_check(LOOT_ECONOMY.ITEM_CATALOG.has(LOOT_ECONOMY.blueprint_shard_item_id(str(recipe_id))), "⑦ %s 조각 카탈로그" % str(recipe_id))
		var found := false
		for stage in LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE.keys():
			if (LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE[stage] as Array).has(str(recipe_id)):
				found = true
		_check(found, "⑦ %s 조각이 어느 존 풀엔가 있다" % str(recipe_id))
	sections_done.append("⑦")
	game_state.call("reset_run")
