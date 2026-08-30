extends SceneTree

# 대개편 3단계(시뮬 재조정안) 스모크 테스트 — 헤드리스.
#   godot --headless --path . --script res://tests/enhancement_curve_smoke_test.gd
#
# ① 강화 비용 3구간 지수 — K2 누적(강화+돌파 고철) +30 ≈ 11.4M · +50 ≈ 213M · +99 ≈ 8.9B (±10%)
# ② T3 방어구 세트(3피스) +99 누적 ≈ 5.0B (±10%) · 방어구 기본 비용 400(T1 400 / T2 600 / T3 880)
# ③ 꾹꾹이 생산기 최대 Lv 8 — Lv8 비용 150M/캣닢 12M · 배율 1.9^7 · Lv9 없음
# ④ 오버클럭 비용 900×1.5^L / 캣닢 60×1.5^L — Lv20 2,992,730 / 199,515
# ⑤ 귀중품 존 가치 ×{1,2,4,10,25} — 존5 금니 480×25 = 12000 · 판 가치 캡도 같은 배율 · 환전 원장
# ⑥ 돌파 비용 — [개정 2026-08-29] 고철 단독({"scrap": 그 단계 강화비 ×3}), 인장·부품 요구 폐지
# ⑦ 돌파 정체성 보너스 판정 — +30 관통 +1 · +50 탄창 +25%/장전 −15% · +70 엘리트 배율 · +90 환급
#    방어구 +30 넉백 · +50 피격 후 가드 · +70 피로 · +90 시큐어 슬롯
# ⑧ 피해 곡선 — +50까지 기존 수렴 곡선 그대로, +99 ≈ ×2.1

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

var failures := 0
var sections_done: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _within(value: float, expected: float, tolerance: float) -> bool:
	return absf(value - expected) <= expected * tolerance


func _fmt(v: float) -> String:
	return str(game_state.call("format_compact_number", v))


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	_check_cost_curve()
	_check_armor_curve()
	_check_scratcher_bank()
	_check_overclock()
	_check_valuable_stage_value()
	_check_breakthrough_table()
	_check_breakthrough_perks()
	_check_damage_curve()

	_check(sections_done.size() == 8, "섹션 8개 전부 완료 (done=%s)" % str(sections_done))
	if failures == 0:
		print("ENHANCEMENT_CURVE_SMOKE_OK")
		quit(0)
	else:
		push_error("ENHANCEMENT_CURVE_SMOKE_FAILED failures=%d" % failures)
		quit(1)


# ── 누적 비용(실제 함수 호출; tmp/income_sim.gd와 같은 규약) ───────────
func _weapon_cumulative(weapon_id: String, target: int) -> Dictionary:
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	var acc := {"scrap": 0.0, "bt_scrap": 0.0, "seal": 0, "gear": 0, "alloy": 0, "basic": 0}
	breakthroughs.clear()
	for level in target:
		levels[weapon_id] = level
		if bool(game_state.call("is_breakthrough_required", "weapon", weapon_id)):
			var bt: Dictionary = game_state.call("get_breakthrough_cost", "weapon", weapon_id)
			acc["bt_scrap"] += float(bt.get("scrap", 0))
			acc["seal"] += int(bt.get("artisan_seal", 0))
			acc["gear"] += int(bt.get("precision_gear", 0))
			acc["alloy"] += int(bt.get("military_alloy", 0))
			breakthroughs["weapon:%s" % weapon_id] = level
		acc["scrap"] += float(game_state.call("get_weapon_enhancement_cost", weapon_id))
		var parts: Dictionary = game_state.call("get_weapon_enhancement_part_cost", weapon_id)
		for pid in parts.keys():
			if pid == "precision_gear":
				acc["gear"] += int(parts[pid])
			elif pid == "military_alloy":
				acc["alloy"] += int(parts[pid])
			else:
				acc["basic"] += int(parts[pid])
	levels[weapon_id] = 0
	breakthroughs.clear()
	return acc


func _armor_cumulative(base_id: String, target: int) -> float:
	var levels: Dictionary = game_state.get("armor_enhancement_levels")
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	var total := 0.0
	breakthroughs.clear()
	for level in target:
		levels[base_id] = level
		if bool(game_state.call("is_breakthrough_required", "armor", base_id)):
			var bt: Dictionary = game_state.call("get_breakthrough_cost", "armor", base_id)
			total += float(bt.get("scrap", 0))
			breakthroughs["armor:%s" % base_id] = level
		total += float(game_state.call("get_armor_enhancement_cost", base_id))
	levels.erase(base_id)
	breakthroughs.clear()
	return total


# ── ① 무기 비용 3구간 ─────────────────────────────────────────
func _check_cost_curve() -> void:
	game_state.call("reset_run")
	# 구간 성장 함수 자체
	var growth45 := float(GAME_STATE_SCRIPT._segmented_growth(45, GAME_STATE_SCRIPT.WEAPON_ENHANCEMENT_SEGMENTS))
	_check(absf(growth45 - pow(1.28, 30.0) * pow(1.10, 15.0)) < growth45 * 1e-6, "① _segmented_growth(45) = 1.28^30×1.10^15")
	var growth75 := float(GAME_STATE_SCRIPT._segmented_growth(75, GAME_STATE_SCRIPT.WEAPON_ENHANCEMENT_SEGMENTS))
	_check(absf(growth75 - pow(1.28, 30.0) * pow(1.10, 30.0) * pow(1.055, 15.0)) < growth75 * 1e-6, "① _segmented_growth(75) 3구간 곱")
	_check(is_equal_approx(float(GAME_STATE_SCRIPT._segmented_growth(0, GAME_STATE_SCRIPT.WEAPON_ENHANCEMENT_SEGMENTS)), 1.0), "① level 0 → ×1")
	# +1~30은 예전 곡선과 동일(900×factor×1.28^L)
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	levels["ak47"] = 10
	_check(int(game_state.call("get_weapon_enhancement_cost", "ak47")) == roundi(900.0 * 1.55 * pow(1.28, 10.0)), "① +10 비용은 기존 곡선 그대로")
	levels["ak47"] = 60
	var cost60 := int(game_state.call("get_weapon_enhancement_cost", "ak47"))
	levels["ak47"] = 61
	var cost61 := int(game_state.call("get_weapon_enhancement_cost", "ak47"))
	_check(absf(float(cost61) / float(cost60) - 1.055) < 0.002, "① +61 구간 배율 1.055 (got %.4f)" % (float(cost61) / float(cost60)))
	levels["ak47"] = 0
	# K2 누적(강화+돌파 고철)
	var k2_30 := _weapon_cumulative("k2", 30)
	var k2_50 := _weapon_cumulative("k2", 50)
	var k2_99 := _weapon_cumulative("k2", 99)
	var total30: float = k2_30["scrap"] + k2_30["bt_scrap"]
	var total50: float = k2_50["scrap"] + k2_50["bt_scrap"]
	var total99: float = k2_99["scrap"] + k2_99["bt_scrap"]
	print("  K2 cumulative +30 %s | +50 %s | +99 %s (seal %d · gear %d · alloy %d · basic %d)" % [
		_fmt(total30), _fmt(total50), _fmt(total99), k2_99["seal"], k2_99["gear"], k2_99["alloy"], k2_99["basic"]])
	_check(_within(total30, 11.4e6, 0.10), "① K2 +30 누적 ≈ 11.4M (got %s)" % _fmt(total30))
	_check(_within(total50, 213e6, 0.10), "① K2 +50 누적 ≈ 213M (got %s)" % _fmt(total50))
	_check(_within(total99, 8.9e9, 0.10), "① K2 +99 누적 ≈ 8.9B (got %s)" % _fmt(total99))
	# [개정 2026-08-29] 강화는 고철 단독 — 부품 비용 함수는 어느 단계에서든 {}를 돌려준다.
	# (옛 "일반 3종×n + 기어" 표 어서션은 폐지된 현실이라 빈 딕셔너리 검증으로 바꿨다.)
	for probe_level in [10, 40, 80]:
		levels["ak47"] = int(probe_level)
		var parts: Dictionary = game_state.call("get_weapon_enhancement_part_cost", "ak47")
		_check(parts.is_empty(), "① +%d 강화 부품 비용 없음(고철 단독) (got %s)" % [int(probe_level) + 1, JSON.stringify(parts)])
	var armor_parts: Dictionary = game_state.call("get_armor_enhancement_part_cost", "military_vest")
	_check(armor_parts.is_empty(), "① 방어구 강화 부품 비용 없음(고철 단독)")
	levels["ak47"] = 0
	sections_done.append("①")


# ── ② 방어구 ─────────────────────────────────────────────────
func _check_armor_curve() -> void:
	game_state.call("reset_run")
	_check(int(game_state.call("get_armor_enhancement_cost", "scav_vest")) == 400, "② T1 +0→+1 400")
	_check(int(game_state.call("get_armor_enhancement_cost", "riot_vest")) == 600, "② T2 ×1.5 = 600")
	_check(int(game_state.call("get_armor_enhancement_cost", "military_vest")) == 880, "② T3 ×2.2 = 880")
	var set_total := 0.0
	for base_id in ["military_vest", "military_helmet", "assault_boots"]:
		set_total += _armor_cumulative(base_id, 99)
	print("  T3 set +99 cumulative %s" % _fmt(set_total))
	_check(_within(set_total, 5.0e9, 0.10), "② T3 세트 +99 누적 ≈ 5.0B (got %s)" % _fmt(set_total))
	var piece30 := _armor_cumulative("military_vest", 30)
	_check(piece30 < 4.0e6, "② T3 한 피스 +30 누적 < 4M (got %s)" % _fmt(piece30))
	sections_done.append("②")


# ── ③ 생산기 Lv8 ────────────────────────────────────────────
func _check_scratcher_bank() -> void:
	game_state.call("reset_run")
	_check(int(GAME_STATE_SCRIPT.SCRATCHER_BANK_MAX_LEVEL) == 8, "③ 최대 Lv 8")
	# 확장 비용은 고철 단독(캣닢 비용 폐지, 2026-08-28 — 캣닢은 피버 전용).
	_check(int(GAME_STATE_SCRIPT.SCRATCHER_UPGRADE_COSTS.get(8, 0)) == 150_000_000, "③ Lv8 비용 150M")
	_check(int(GAME_STATE_SCRIPT.SCRATCHER_UPGRADE_COSTS.get(6, 0)) == 6_000_000 and int(GAME_STATE_SCRIPT.SCRATCHER_UPGRADE_COSTS.get(7, 0)) == 30_000_000, "③ Lv6 6M · Lv7 30M")
	game_state.set("scrap", 10_000_000_000)
	game_state.set("catnip", 1_000_000_000)
	var upgrades := 0
	while bool(game_state.call("try_upgrade_scratcher_bank")):
		upgrades += 1
	_check(upgrades == 7 and int(game_state.get("scratcher_bank_level")) == 8, "③ Lv1→Lv8 7회 확장 뒤 멈춤 (level=%d)" % int(game_state.get("scratcher_bank_level")))
	_check(is_equal_approx(float(game_state.get("scratcher_multiplier")), pow(1.9, 7.0)), "③ Lv8 배율 1.9^7 ≈ ×%.1f" % pow(1.9, 7.0))
	# 좌석 수는 24 → 400으로 열렸다(인크리멘탈 수용량 개편). 수입 곡선을 지키는 것은
	# 이제 좌석 수가 아니라 '유효 배치수'다 — 크라우딩을 통과한 값이 예전 24와 같아야 한다.
	_check(int(GAME_STATE_SCRIPT.KNEADING_SLOTS_BY_TIER.get(5, 0)) == 400, "③ 티어 5 좌석 400")
	var effective_t5 := float(game_state.call("get_line_effective_workers", 400))
	_check(
		absf(effective_t5 - 24.0) <= 1.5,
		"③ 티어 5 유효 배치수 ≈ 24 (실측 %.2f)" % effective_t5
	)
	# 세이브 왕복에서 Lv8이 5로 깎이지 않는다
	var snapshot: Dictionary = game_state.call("build_persistent_snapshot") if game_state.has_method("build_persistent_snapshot") else {}
	if not snapshot.is_empty():
		game_state.set("scratcher_bank_level", 1)
		game_state.call("apply_persistent_snapshot", snapshot)
		_check(int(game_state.get("scratcher_bank_level")) == 8, "③ 세이브 왕복 Lv8 유지")
	sections_done.append("③")


# ── ④ 오버클럭 ───────────────────────────────────────────────
func _check_overclock() -> void:
	game_state.call("reset_run")
	game_state.set("scratcher_overclock_level", 20)
	var cost := int(game_state.call("get_overclock_cost"))
	_check(cost == roundi(900.0 * pow(1.5, 20.0) / 10.0) * 10, "④ 오버클럭 Lv20 비용 900×1.5^20 = %d" % cost)
	_check(cost == 2_992_730, "④ Lv20 고철 2,992,730 (got %d)" % cost)
	game_state.set("scratcher_overclock_level", 0)
	_check(int(game_state.call("get_overclock_cost")) == 900, "④ Lv0 900")
	# 오버클럭은 고철 단독이다(캣닢 비용 폐지, 2026-08-28) — 캣닢 없이도 산다.
	game_state.set("scrap", 900)
	game_state.set("catnip", 0)
	_check(bool(game_state.call("try_upgrade_scratcher_overclock")), "④ 캣닢 0으로도 오버클럭 구매")
	_check(int(game_state.get("scrap")) == 0, "④ 고철만 소모")
	sections_done.append("④")


# ── ⑤ 귀중품 존 가치 ─────────────────────────────────────────
func _check_valuable_stage_value() -> void:
	game_state.call("reset_run")
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var expected := {1: 1.0, 2: 2.0, 3: 4.0, 4: 10.0, 5: 25.0}
	for stage in expected.keys():
		var definition: Dictionary = LOOT_ECONOMY._materialize_item("gold_tooth", int(stage), random)
		var data: Dictionary = definition.get("data", {})
		_check(int(data.get("base_value", 0)) == roundi(480.0 * float(expected[stage])), "⑤ 존%d 금니 가치 480×%s = %d" % [int(stage), str(expected[stage]), int(data.get("base_value", 0))])
	var stage5: Dictionary = LOOT_ECONOMY._materialize_item("gold_tooth", 5, random)
	_check(int(LOOT_ECONOMY.get_definition_value(stage5)) == 12000, "⑤ 존5 total_value 12000")
	# 판 가치 캡도 같은 배율 — 존5 귀중품 하나가 캡에 막히지 않는다
	_check(int(LOOT_ECONOMY.get_stage_value_cap(5, "field_value_cap")) == 17000 * 25, "⑤ 존5 field_value_cap ×25")
	_check(int(LOOT_ECONOMY.get_stage_value_cap(1, "field_value_cap")) == 3600, "⑤ 존1 캡 그대로")
	game_state.call("reset_raid_supply_counters")
	_check(bool(LOOT_ECONOMY.try_register_loot(game_state, stage5, "field", 5)), "⑤ 존5 귀중품 등록(캡 통과)")
	# 환전 원장 — 존4 출정에서 주운 금니는 ×10으로 환전된다
	game_state.call("reset_run")
	game_state.set("selected_raid_zone", "sealed_zone")
	var zone_ids: Array = game_state.call("get_raid_zone_ids")
	var stage4_zone := ""
	for zone_id in zone_ids:
		if int((game_state.call("get_raid_zone", str(zone_id)) as Dictionary).get("stage_tier", 1)) == 4:
			stage4_zone = str(zone_id)
	if stage4_zone.is_empty():
		_check(false, "⑤ 존4 구역 id를 찾지 못함")
	else:
		game_state.set("selected_raid_zone", stage4_zone)
		_check(int(game_state.call("get_current_raid_stage_tier")) == 4, "⑤ 현재 출정 존 티어 4 (%s)" % stage4_zone)
		_check(bool(game_state.call("try_add_raid_item", "valuable", "gold_tooth", 2)), "⑤ 존4에서 금니 2개 획득")
		_check(int(game_state.call("get_valuable_total_value")) == 480 * 10 * 2, "⑤ 환전 가치 480×10×2 = %d" % int(game_state.call("get_valuable_total_value")))
		game_state.call("remove_raid_bag_item", "valuable", "gold_tooth", 1)
		_check(int(game_state.call("get_valuable_total_value")) == 480 * 10, "⑤ 1개 버리면 원장도 절반")
		var scrap_before := int(game_state.get("scrap"))
		var sold: Dictionary = game_state.call("sell_all_valuables")
		_check(int(sold.get("scrap", 0)) == 4800 and int(game_state.get("scrap")) == scrap_before + 4800, "⑤ 환전 4800 고철")
		_check((game_state.get("valuable_value_ledger") as Dictionary).is_empty(), "⑤ 환전 후 원장 비움")
	# 구세이브(원장 없음)는 카탈로그 값으로 환산
	game_state.call("reset_run")
	(game_state.get("valuable_inventory") as Dictionary)["gold_tooth"] = 3
	_check(int(game_state.call("get_valuable_total_value")) == 480 * 3, "⑤ 원장 없는 귀중품 = 카탈로그×개수")
	game_state.call("reset_run")
	sections_done.append("⑤")


# ── ⑥ 돌파 비용 — 고철 단독 ───────────────────────────────────
# [개정 2026-08-29] 인장·정밀 기어·합금 요구 폐지(유저: 고철만으로 신나게). 옛 재료
# 표(인장 L/10 등) 어서션은 그 현실에 맞게 "{"scrap": 강화비 ×3} 단독"으로 바꿨다.
func _check_breakthrough_table() -> void:
	game_state.call("reset_run")
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	var armor_levels: Dictionary = game_state.get("armor_enhancement_levels")
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	print("BREAKTHROUGH_COST (scrap only)")
	for level in [10, 50, 90]:
		breakthroughs.clear()
		levels["k2"] = int(level)
		var cost: Dictionary = game_state.call("get_breakthrough_cost", "weapon", "k2")
		print("  weapon +%d: %s" % [int(level), JSON.stringify(cost)])
		_check(cost.keys() == ["scrap"], "⑥ 무기 +%d 돌파 비용은 고철 단독 (got %s)" % [int(level), JSON.stringify(cost)])
		_check(int(cost.get("scrap", 0)) == int(game_state.call("get_weapon_enhancement_cost", "k2")) * 3, "⑥ 무기 +%d 돌파 고철 ×3" % int(level))
	levels["k2"] = 0
	for level in [10, 50, 90]:
		breakthroughs.clear()
		armor_levels["military_vest"] = int(level)
		var cost: Dictionary = game_state.call("get_breakthrough_cost", "armor", "military_vest")
		print("  armor  +%d: %s" % [int(level), JSON.stringify(cost)])
		_check(cost.keys() == ["scrap"], "⑥ 방어구 +%d 돌파 비용은 고철 단독 (got %s)" % [int(level), JSON.stringify(cost)])
		_check(int(cost.get("scrap", 0)) == int(game_state.call("get_armor_enhancement_cost", "military_vest")) * 3, "⑥ 방어구 +%d 돌파 고철 ×3" % int(level))
	armor_levels.erase("military_vest")
	breakthroughs.clear()
	# 돌파 관문이 아니면 빈 비용
	levels["k2"] = 37
	_check((game_state.call("get_breakthrough_cost", "weapon", "k2") as Dictionary).is_empty(), "⑥ 관문 아님(+37) → 빈 비용")
	# 소모는 고철만 — 인장·부품 재고는 그대로 남는다.
	levels["k2"] = 50
	game_state.call("add_weapon", "k2", 1)
	levels["k2"] = 50
	game_state.set("scrap", 100_000_000_000)
	game_state.call("add_progression_item", "artisan_seal", 5)
	game_state.call("add_mod_component", "precision_gear", 10)
	game_state.call("add_mod_component", "military_alloy", 2)
	var scrap_before := int(game_state.get("scrap"))
	var expected_scrap := int((game_state.call("get_breakthrough_cost", "weapon", "k2") as Dictionary).get("scrap", 0))
	_check(bool(game_state.call("try_breakthrough", "weapon", "k2")), "⑥ +50 돌파 성공(고철 단독)")
	_check(int(game_state.get("scrap")) == scrap_before - expected_scrap, "⑥ 고철 ×3만 차감")
	_check(int(game_state.call("get_progression_item_count", "artisan_seal")) == 5 and int(game_state.call("get_owned_component_total", "precision_gear")) == 10 and int(game_state.call("get_owned_component_total", "military_alloy")) == 2, "⑥ 인장·부품은 소모되지 않음")
	game_state.call("reset_run")
	sections_done.append("⑥")


# ── ⑦ 돌파 보너스 ─────────────────────────────────────────────
func _check_breakthrough_perks() -> void:
	game_state.call("reset_run")
	var levels: Dictionary = game_state.get("weapon_enhancement_levels")
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	var no_mods: Array[String] = []
	game_state.call("add_weapon", "k2", 1)
	game_state.set("equipped_weapon_id", "k2")
	# +29: 보너스 없음
	levels["k2"] = 29
	_check((game_state.call("get_breakthrough_perks", "weapon", "k2") as Array).is_empty(), "⑦ +29 보너스 없음")
	# +30 도달했지만 돌파 전: 아직 없음 / 돌파 기록 후: 관통
	levels["k2"] = 30
	breakthroughs.clear()
	_check((game_state.call("get_breakthrough_perks", "weapon", "k2") as Array).is_empty(), "⑦ +30 돌파 전 보너스 없음")
	breakthroughs["weapon:k2"] = 30
	var perks30: Array = game_state.call("get_breakthrough_perks", "weapon", "k2")
	_check(perks30 == ["pierce"], "⑦ +30 돌파 → 관통 (got %s)" % str(perks30))
	var base_stats: Dictionary = WEAPON_SYSTEM.build_stats("k2", no_mods, 30)
	var stats30: Dictionary = game_state.call("build_player_weapon_stats", "k2", no_mods, 30, {})
	_check(int(stats30.get("penetration_count", 0)) == int(base_stats.get("penetration_count", 0)) + 1, "⑦ +30 관통 +1 (%d → %d)" % [int(base_stats.get("penetration_count", 0)), int(stats30.get("penetration_count", 0))])
	_check(int(stats30.get("magazine_size", 0)) == int(base_stats.get("magazine_size", 0)), "⑦ +30에는 탄창 보너스 없음")
	# +51(돌파 기록 없어도 레벨이 50을 넘었으면 돌파한 것): 관통 + 탄창
	levels["k2"] = 51
	breakthroughs.clear()
	var perks51: Array = game_state.call("get_breakthrough_perks", "weapon", "k2")
	_check(perks51 == ["pierce", "magazine"], "⑦ +51 → 관통·탄창 (got %s)" % str(perks51))
	var base51: Dictionary = WEAPON_SYSTEM.build_stats("k2", no_mods, 51)
	var stats51: Dictionary = game_state.call("build_player_weapon_stats", "k2", no_mods, 51, {})
	_check(int(stats51.get("magazine_size", 0)) == int(ceil(float(base51.get("magazine_size", 0)) * 1.25)), "⑦ +50 탄창 +25%% (%d → %d)" % [int(base51.get("magazine_size", 0)), int(stats51.get("magazine_size", 0))])
	_check(absf(float(stats51.get("reload_time", 0.0)) - float(base51.get("reload_time", 0.0)) * float(game_state.call("get_reload_time_multiplier")) * 0.85) < 0.001, "⑦ +50 장전 −15%")
	_check(is_equal_approx(float(stats51.get("elite_damage_multiplier", 0.0)), 1.0) and is_equal_approx(float(game_state.call("get_player_elite_damage_multiplier")), 1.0), "⑦ +51 엘리트 배율 아직 1.0")
	# +71: 엘리트 +20%
	levels["k2"] = 71
	var stats71: Dictionary = game_state.call("build_player_weapon_stats", "k2", no_mods, 71, {})
	_check(is_equal_approx(float(stats71.get("elite_damage_multiplier", 0.0)), 1.2) and is_equal_approx(float(game_state.call("get_player_elite_damage_multiplier")), 1.2), "⑦ +70 엘리트·보스 피해 ×1.2")
	_check(float(stats71.get("durability_loss", 1.0)) > 0.0 and is_zero_approx(float(stats71.get("kill_ammo_refund", 1.0))), "⑦ +71 환급·내구 0은 아직")
	# +91: 환급 10% · 내구 0
	levels["k2"] = 91
	var stats91: Dictionary = game_state.call("build_player_weapon_stats", "k2", no_mods, 91, {})
	_check(is_equal_approx(float(stats91.get("kill_ammo_refund", 0.0)), 0.10) and is_zero_approx(float(stats91.get("durability_loss", 1.0))), "⑦ +90 처치 환급 10% · 내구 소모 0")
	_check((stats91.get("breakthrough_perks", []) as Array).size() == 4, "⑦ +91 보너스 4개 전부")
	_check(str(game_state.call("describe_breakthrough_perk", "weapon", 30)).contains("관통") and str(game_state.call("describe_breakthrough_perk", "armor", 90)).contains("시큐어"), "⑦ describe_breakthrough_perk 문구")
	_check(str(game_state.call("describe_breakthrough_perk", "weapon", 40)).is_empty(), "⑦ 표에 없는 단계는 빈 문자열")
	levels["k2"] = 0
	# 방어구 — 몸 +30 넉백 · +50 가드 · +70 이동 속도 · +90 시큐어
	game_state.call("reset_run")
	var armor_levels: Dictionary = game_state.get("armor_enhancement_levels")
	game_state.call("add_equipment", "military_vest", 1)
	game_state.call("add_equipment", "military_helmet", 1)
	game_state.set("equipped_body_armor_id", "military_vest")
	game_state.set("equipped_head_armor_id", "military_helmet")
	_check(is_equal_approx(float(game_state.call("get_armor_knockback_multiplier")), 1.0), "⑦ 방어구 +0 넉백 배율 1.0")
	armor_levels["military_helmet"] = 35
	_check(is_equal_approx(float(game_state.call("get_armor_knockback_multiplier")), 1.0), "⑦ 머리 +35는 넉백 저항 없음(몸 전용)")
	armor_levels["military_vest"] = 35
	_check(is_equal_approx(float(game_state.call("get_armor_knockback_multiplier")), 0.5), "⑦ 몸 +35 → 넉백 저항 50%")
	var speed_base := float(game_state.call("get_move_speed_multiplier"))
	armor_levels["military_helmet"] = 71
	_check(absf(float(game_state.call("get_move_speed_multiplier")) - speed_base * 1.04) < 0.001, "⑦ 방어구 +70 이동 속도 +4%")
	# 피격 후 가드: +50 이상이면 1.5s 안의 두 번째 피격이 −20%
	game_state.set("last_player_hit_msec", -100000)
	var first := int(game_state.call("apply_post_hit_guard", 100))
	var second := int(game_state.call("apply_post_hit_guard", 100))
	_check(first == 100 and second == 80, "⑦ 방어구 +50 피격 후 1.5s 추가 피해 −20%% (%d → %d)" % [first, second])
	game_state.set("last_player_hit_msec", -100000)
	armor_levels["military_helmet"] = 49
	armor_levels["military_vest"] = 49
	game_state.call("apply_post_hit_guard", 100)
	_check(int(game_state.call("apply_post_hit_guard", 100)) == 100, "⑦ +49는 가드 없음")
	# 시큐어 슬롯
	var secure_base := int(game_state.call("get_secure_slot_count"))
	armor_levels["military_vest"] = 91
	_check(int(game_state.call("get_secure_slot_count")) == secure_base + 1, "⑦ 방어구 +90 시큐어 슬롯 +1 (%d → %d)" % [secure_base, int(game_state.call("get_secure_slot_count"))])
	(game_state.get("secure_dog_items") as Array).clear()
	for i in secure_base + 1:
		_check(bool(game_state.call("store_secure_item", {"type": "currency", "id": "churu", "amount": 1})), "⑦ 시큐어 %d번째 칸 저장" % (i + 1))
	_check(not bool(game_state.call("store_secure_item", {"type": "currency", "id": "churu", "amount": 1})), "⑦ 시큐어 초과 저장 거절")
	game_state.call("reset_run")
	sections_done.append("⑦")


# ── ⑧ 피해 곡선 ───────────────────────────────────────────────
func _check_damage_curve() -> void:
	var no_mods: Array[String] = []
	var base := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 0).get("damage", 0))
	var d50 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 50).get("damage", 0)) / base
	var d70 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 70).get("damage", 0)) / base
	var d99 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 99).get("damage", 0)) / base
	var d25 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 25).get("damage", 0)) / base
	var d55 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 55).get("damage", 0)) / base
	print("  damage multiplier +25 ×%.2f · +50 ×%.2f · +55 ×%.2f · +70 ×%.2f · +99 ×%.2f" % [
		d25, d50, d55, d70, d99
	])
	# 천장 철거(2026-08-30) — +25까지는 존별 킬 타이밍 튜닝이 걸려 있어 옛
	# 곡선 그대로, 그 뒤부터 복리(+5%/단계)로 끝없이 오른다.
	var tuned25 := 1.30 + 0.60 * (1.0 - pow(0.94, 15.0))
	_check(absf(d25 - tuned25) < 0.001, "⑧ +25까지 튜닝 곡선 불변 (×%.3f)" % d25)
	_check(absf(d55 - tuned25 * pow(1.08, 30.0)) < 0.05, "⑧ +55 복리 (×%.2f)" % d55)
	_check(absf(d99 - tuned25 * pow(1.08, 74.0)) < 5.0, "⑧ +99 복리 (×%.1f)" % d99)
	# 예전의 수렴 천장(×2.1)으로 돌아가면 여기서 잡힌다.
	_check(d55 > 12.0, "⑧ +55는 최소 12배 (천장 회귀 방지, ×%.2f)" % d55)
	_check(d99 / d70 > 5.0, "⑧ +70 → +99 구간도 계속 불어난다")
	# 인크리멘탈다운 자릿수 — K2(기본 48) 기준 +70에 네 자리, +99에 다섯 자리.
	var k2_70 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 70).get("damage", 0))
	var k2_99 := float(WEAPON_SYSTEM.build_stats("k2", no_mods, 99).get("damage", 0))
	_check(k2_70 >= 1000.0, "⑧ K2 +70 피해 네 자리 (%d)" % roundi(k2_70))
	_check(k2_99 >= 10000.0, "⑧ K2 +99 피해 다섯 자리 (%d)" % roundi(k2_99))
	_check(roundi(float(WEAPON_SYSTEM.build_stats("ak47", no_mods).get("damage", 0))) == 30, "⑧ AK 기본 피해 30 불변")
	sections_done.append("⑧")
