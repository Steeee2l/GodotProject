class_name ShelterRequisition
extends RefCounted

# ── 쉘터 "다음 목표" ──────────────────────────────────────────
# 쉘터 티어 확장은 고철 + 츄르 (+ 티어 3부터 서사 키 1개)로만 오른다.
# 츄르와 키는 출정에서만 나오므로 "나가야 쉘터가 큰다"는 허기는 이미 있었다.
# 문제는 그 요구가 쉘터 화면에서 안 읽힌다는 것 — 이 모듈은 데이터를 더하지
# 않고, 이미 있는 요구를 한 줄로 읽히게 만드는 일만 한다.
#
# 규칙:
#   · 데이터는 GameState.SHELTER_UPGRADE_COSTS 하나에서만 읽는다(복제 금지).
#   · 요구 품목은 가방 칸을 먹지 않는다(progression 타입 = 0칸).
#   · 러버밴딩 없음 — 플레이어 상태를 보고 요구를 바꾸지 않는다.
#   · UI에 "보급 요구" 같은 시스템 용어를 내보내지 않는다. 사람 말로 "다음 목표".
#
# 모든 진입점은 static — 호출부는 preload 후 바로 부른다. 상태를 갖지 않는다.

const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")

const MAX_SHELTER_TIER := 5

# ── 존별 장비 목표 ────────────────────────────────────────────
# "이 존에 무엇을 갖추고 가야 하나"를 한 줄로. 세트는 그 존 가족(ARMOR_FAMILIES)
# 3종의 보유/장착 n/3, 무기는 무기 사다리 설계의 존별 권장 강화(종로 AK+5 /
# 남대문 AK+10 / 을지로 AKM+15 / 용산 AKM+20 / 남산 K2+25 — "그 존 사수를 3발에")
# 대비 장착 무기. 러버밴딩 없음: 목표는 존 티어에서만 나오고 플레이어 상태는
# 충족 여부 표시에만 쓴다. 데이터 복제 금지 — 가족·사다리는 원본 상수를 읽는다.
const ZONE_WEAPON_GOALS := {
	1: ["ak47", 5],
	2: ["ak47", 10],
	3: ["akm", 15],
	4: ["akm", 20],
	5: ["k2", 25],
}
const WEAPON_SHORT_NAMES := {
	"ak47": "AK", "akm": "AKM", "k2": "K2",
	"double_barrel": "더블배럴", "pump_shotgun": "펌프",
	"m1911": "M1911", "mp5": "MP5",
}
const GEAR_GOAL_OK_COLOR := Color("#72d6a0")
const GEAR_GOAL_MISSING_COLOR := Color("#e36f55")

# 요구 품목 표시명. 키 아이템의 이름은 ITEM_CATALOG(loot_economy)와 같아야 한다.
const REQUIREMENT_LABELS := {
	"scrap": "고철",
	"churu": "츄르",
	"namdaemun_depot_plans": "남대문 창고 설계도",
	"euljiro_grid_schematic": "을지로 배전 도면",
	"yongsan_control_key": "용산 통제 키",
}

# "어디서 구하는가" — 긴 판(스탯 패널 툴팁·정산)과 짧은 판(한 줄 문구) 둘 다 둔다.
# 세로 모달 폭에서 목표 줄이 2줄을 넘으면 짧은 판조차 생략된다.
const SOURCE_HINTS := {
	"scrap": {"long": "쉘터 생산 · 귀중품 환전 · 상인 판매", "short": "생산·환전·판매"},
	"churu": {"long": "보스 처치 · 사자 계약 보상 · 귀환 의뢰(3회마다)", "short": "보스 처치·사자 계약"},
}


# ── 목표 ───────────────────────────────────────────────────────


static func get_next_goal() -> Dictionary:
	# 현재 티어 기준 다음 확장 목표. 최종 티어면 빈 딕셔너리.
	var next_tier: int = GameState.shelter_tier + 1
	if next_tier > MAX_SHELTER_TIER:
		return {}
	var cost := GameState.SHELTER_UPGRADE_COSTS.get(next_tier, {}) as Dictionary
	if cost.is_empty():
		return {}
	var requirements: Array[Dictionary] = []
	var scrap_need := int(cost.get("scrap", 0))
	if scrap_need > 0:
		requirements.append(_build_requirement("scrap", GameState.scrap, scrap_need))
	var churu_need := int(cost.get("churu", 0))
	if churu_need > 0:
		requirements.append(_build_requirement("churu", GameState.churu, churu_need))
	var key_item := str(cost.get("key_item", ""))
	if not key_item.is_empty():
		requirements.append(
			_build_requirement(key_item, GameState.get_progression_item_count(key_item), 1)
		)
	var all_met := true
	for requirement in requirements:
		if not bool(requirement.get("ok", false)):
			all_met = false
			break
	return {
		"tier": next_tier,
		"title": "Tier %d 확장" % next_tier,
		"unlock_hint": _unlock_hint_for_tier(next_tier),
		"requirements": requirements,
		"all_met": all_met,
	}


static func is_final_tier() -> bool:
	return GameState.shelter_tier >= MAX_SHELTER_TIER


static func get_final_tier_text() -> String:
	return "최종 티어 · 쉘터 확장 완료"


static func _build_requirement(id: String, have: int, need: int) -> Dictionary:
	var hints := _hints_for(id)
	return {
		"id": id,
		"label": str(REQUIREMENT_LABELS.get(id, id)),
		"have": maxi(0, have),
		"need": maxi(0, need),
		"ok": have >= need,
		"hint": str(hints.get("long", "")),
		"hint_short": str(hints.get("short", "")),
		"is_key": is_key_item(id),
	}


static func _hints_for(id: String) -> Dictionary:
	if SOURCE_HINTS.has(id):
		return SOURCE_HINTS[id] as Dictionary
	if is_key_item(id):
		var source := get_key_item_source(id)
		if source.is_empty():
			return {"long": "메인 미션 보상", "short": "메인 미션"}
		var zone_name := str(GameState.get_raid_zone(str(source.get("zone_id", ""))).get("name", ""))
		return {
			"long": "%s 메인 미션 ‘%s’ 완료 보상" % [zone_name, str(source.get("stage_title", ""))],
			"short": "%s 메인 미션" % zone_name,
		}
	return {"long": "", "short": ""}


static func _unlock_hint_for_tier(tier: int) -> String:
	# 확장이 뭘 바꾸는지 — 다음 티어로 열리는 출정 구역이 있으면 그것부터.
	for zone_id in GameState.get_raid_zone_ids():
		var zone: Dictionary = GameState.get_raid_zone(str(zone_id))
		if int(zone.get("required_tier", 1)) == tier:
			return "%s 해금" % str(zone.get("name", ""))
	return "수용·생산 슬롯 확장"


# ── 키 아이템 ──────────────────────────────────────────────────


static func is_key_item(item_id: String) -> bool:
	for tier in GameState.SHELTER_UPGRADE_COSTS.keys():
		if str((GameState.SHELTER_UPGRADE_COSTS[tier] as Dictionary).get("key_item", "")) == item_id:
			return true
	return false


static func get_key_item_tier(item_id: String) -> int:
	# 이 키가 여는 쉘터 티어. 키가 아니면 0.
	for tier in GameState.SHELTER_UPGRADE_COSTS.keys():
		if str((GameState.SHELTER_UPGRADE_COSTS[tier] as Dictionary).get("key_item", "")) == item_id:
			return int(tier)
	return 0


static func get_key_item_source(item_id: String) -> Dictionary:
	# 키를 주는 메인 미션 단계 = CHAINS에서 reward.progression_items에 이 id가 있는 단계.
	# 출처를 여기 따로 적지 않는다 — 카탈로그가 유일한 진실이다.
	for zone_id in MAIN_MISSION_CATALOG.ZONE_ORDER:
		var total := MAIN_MISSION_CATALOG.get_stage_count(zone_id)
		for stage_index in total:
			var stage := MAIN_MISSION_CATALOG.get_stage(zone_id, stage_index)
			var items := (stage.get("reward", {}) as Dictionary).get("progression_items", {}) as Dictionary
			if items.has(item_id):
				return {
					"zone_id": zone_id,
					"stage_index": stage_index,
					"stage_title": str(stage.get("title", "")),
				}
	return {}


static func describe_key_item_grant(item_id: String) -> String:
	# 키를 받는 순간의 한 줄 — 정산 요약·시네마틱 뒤에 붙는다.
	var tier := get_key_item_tier(item_id)
	if tier <= 0:
		return ""
	return "%s 획득 · 쉘터 Tier %d 확장에 필요한 설계도" % [
		str(REQUIREMENT_LABELS.get(item_id, item_id)), tier,
	]


static func ensure_story_key_items() -> Array[String]:
	# 안전망: 체인 3단계를 이미 끝낸 세이브(키 도입 전 클리어) 또는 키를 시체와 함께
	# 잃은 세이브에 키를 보정 지급한다. 지급 자체는 GameState가 한다(로드 경로에서도
	# 같은 함수가 돈다) — 여기서는 호출부가 한 곳만 알면 되도록 위임만.
	return GameState.ensure_story_key_items()


# ── 문구 ───────────────────────────────────────────────────────


static func build_goal_segments(goal: Dictionary, only_missing := false) -> Array[Dictionary]:
	# UI가 색을 입힐 수 있게 조각으로 준다.
	#   {text, state: "head"|"ok"|"missing"|"hint", hint}
	# hint는 미충족 항목 뒤에만 붙는다 — 충족한 건 어디서 구하는지 말할 이유가 없다.
	var segments: Array[Dictionary] = []
	if goal.is_empty():
		return segments
	segments.append({
		"text": "다음 → %s" % str(goal.get("title", "")),
		"state": "head",
		"hint": "",
	})
	for requirement in goal.get("requirements", []) as Array:
		var item := requirement as Dictionary
		var ok := bool(item.get("ok", false))
		if ok and only_missing:
			continue
		segments.append({
			"text": format_requirement(item),
			"state": "ok" if ok else "missing",
			"hint": "" if ok else str(item.get("hint_short", "")),
		})
	return segments


static func format_requirement(requirement: Dictionary) -> String:
	var id := str(requirement.get("id", ""))
	var label := str(requirement.get("label", id))
	var have := int(requirement.get("have", 0))
	var need := int(requirement.get("need", 0))
	var ok := bool(requirement.get("ok", false))
	if bool(requirement.get("is_key", false)):
		# 키는 개수보다 이름이 정보다. "남대문 창고 설계도 ✓" / "남대문 창고 설계도 없음".
		return "%s ✓" % label if ok else "%s 없음" % label
	if id == "scrap":
		if ok:
			return "고철 %s ✓" % GameState.format_compact_number(need)
		return "고철 %s/%s" % [
			GameState.format_compact_number(have), GameState.format_compact_number(need),
		]
	return "%s %d/%d%s" % [label, mini(have, need), need, " ✓" if ok else ""]


static func format_goal_line(goal: Dictionary, with_hints := true, only_missing := false) -> String:
	# `다음 → Tier 2 확장 · 고철 30K ✓ · 츄르 0/1 — 보스 처치·사자 계약`
	if goal.is_empty():
		return get_final_tier_text() if is_final_tier() else ""
	var parts: Array[String] = []
	for segment in build_goal_segments(goal, only_missing):
		var text := str(segment.get("text", ""))
		var hint := str(segment.get("hint", ""))
		if with_hints and not hint.is_empty():
			text += " — %s" % hint
		parts.append(text)
	return " · ".join(parts)


static func describe_progress_after_pickup(item_id: String) -> String:
	# 필드에서 요구 품목을 얻은 직후(수량이 이미 더해진 뒤) 부른다.
	# 요구 품목이 아니면 "" — 호출부는 빈 문자열이면 토스트를 띄우지 않는다.
	var goal := get_next_goal()
	if goal.is_empty():
		return ""
	for requirement in goal.get("requirements", []) as Array:
		var item := requirement as Dictionary
		if str(item.get("id", "")) != item_id:
			continue
		var label := str(item.get("label", item_id))
		var have := int(item.get("have", 0))
		var need := int(item.get("need", 0))
		if bool(item.get("ok", false)):
			var text := "쉘터 목표 · %s %d/%d 달성" % [label, need, need]
			if bool(goal.get("all_met", false)):
				text += " · %s 가능" % str(goal.get("title", ""))
			return text
		return "쉘터 목표 · %s %d/%d" % [label, have, need]
	return ""


static func get_settlement_line() -> String:
	# 귀환 정산 카드·탈출 정산 화면의 마지막 줄.
	#   `Tier 2 확장 가능!` / `다음 목표까지 츄르 1개 · 보스 처치·사자 계약`
	var goal := get_next_goal()
	if goal.is_empty():
		return ""
	if bool(goal.get("all_met", false)):
		return "%s 가능!" % str(goal.get("title", ""))
	var gaps: Array[String] = []
	var single_hint := ""
	for requirement in goal.get("requirements", []) as Array:
		var item := requirement as Dictionary
		if bool(item.get("ok", false)):
			continue
		var gap := int(item.get("need", 0)) - int(item.get("have", 0))
		var id := str(item.get("id", ""))
		if bool(item.get("is_key", false)):
			gaps.append(str(item.get("label", id)))
		elif id == "scrap":
			gaps.append("고철 %s" % GameState.format_compact_number(gap))
		else:
			gaps.append("%s %d개" % [str(item.get("label", id)), gap])
		single_hint = str(item.get("hint_short", ""))
	if gaps.is_empty():
		return ""
	var line := "다음 목표까지 %s" % " · ".join(gaps)
	# 모자란 게 하나뿐일 때만 출처를 붙인다 — 둘 이상이면 줄이 길어져 안 읽힌다.
	if gaps.size() == 1 and not single_hint.is_empty():
		line += " · %s" % single_hint
	return line


static func get_upgrade_block_reason() -> String:
	# 확장 버튼이 거부됐을 때의 사유. 키가 없으면 어디서 구하는지까지.
	if is_final_tier():
		return "쉘터가 이미 최고 Tier(%d)입니다." % MAX_SHELTER_TIER
	var goal := get_next_goal()
	for requirement in goal.get("requirements", []) as Array:
		var item := requirement as Dictionary
		if bool(item.get("ok", false)):
			continue
		var id := str(item.get("id", ""))
		var gap := int(item.get("need", 0)) - int(item.get("have", 0))
		if bool(item.get("is_key", false)):
			return "확장 불가 · %s 필요 — %s" % [str(item.get("label", id)), str(item.get("hint", ""))]
		if id == "scrap":
			return "확장 불가 · 고철 %s 부족" % GameState.format_compact_number(gap)
		return "확장 불가 · %s %d개 부족" % [str(item.get("label", id)), gap]
	return ""


static func get_goal_zone_ids() -> Array[String]:
	# 미충족 요구 품목이 나오는 출정 구역 — 브리핑 지도에 "목표" 칩을 붙일 곳.
	# 츄르 → 보스가 있는 해금 구역, 키 → 그 키를 주는 메인 미션의 구역. 고철은 어디서나.
	var zone_ids: Array[String] = []
	var goal := get_next_goal()
	if goal.is_empty():
		return zone_ids
	for requirement in goal.get("requirements", []) as Array:
		var item := requirement as Dictionary
		if bool(item.get("ok", false)):
			continue
		var id := str(item.get("id", ""))
		if id == "churu":
			for zone_id in GameState.get_raid_zone_ids():
				var zone: Dictionary = GameState.get_raid_zone(str(zone_id))
				if bool(zone.get("boss", false)) and GameState.is_raid_zone_unlocked(str(zone_id)):
					if not zone_ids.has(str(zone_id)):
						zone_ids.append(str(zone_id))
		elif bool(item.get("is_key", false)):
			var source_zone := str(get_key_item_source(id).get("zone_id", ""))
			if not source_zone.is_empty() and not zone_ids.has(source_zone):
				zone_ids.append(source_zone)
	return zone_ids


# ── 존별 장비 목표 ────────────────────────────────────────────


static func get_zone_gear_goal(zone_id: String) -> Dictionary:
	# 그 존 가족 세트 3종 보유/장착(n/3) + 권장 무기 강화 대비 장착 무기.
	#   {zone_id, stage, set_label "T1", set_ids, pieces[{id, owned, equipped}],
	#    set_owned, set_equipped, set_ok, weapon_id, weapon_level,
	#    equipped_weapon_id, equipped_level, weapon_rung_ok, weapon_ok, all_ok, text}
	if zone_id.is_empty() or not GameState.RAID_ZONES.has(zone_id):
		return {}
	var zone: Dictionary = GameState.get_raid_zone(zone_id)
	var stage := clampi(int(zone.get("stage_tier", zone.get("required_tier", 1))), 1, 5)
	var family_index: int = LOOT_ECONOMY.armor_family_index_for_stage(stage)
	var set_ids: Array = LOOT_ECONOMY.ARMOR_FAMILIES[family_index]
	var pieces: Array[Dictionary] = []
	var owned_count := 0
	var equipped_count := 0
	for base_id_value in set_ids:
		var base_id := str(base_id_value)
		var equipped := _is_armor_base_equipped(base_id)
		var owned := equipped or _owned_armor_base_count(base_id) > 0
		pieces.append({"id": base_id, "owned": owned, "equipped": equipped})
		if owned:
			owned_count += 1
		if equipped:
			equipped_count += 1
	var weapon_goal: Array = ZONE_WEAPON_GOALS.get(stage, ZONE_WEAPON_GOALS[1])
	var goal_weapon_id := str(weapon_goal[0])
	var goal_level := int(weapon_goal[1])
	var equipped_weapon_id := str(GameState.equipped_weapon_id) if bool(GameState.has_ak) else ""
	var equipped_level := 0
	if not equipped_weapon_id.is_empty():
		equipped_level = GameState.get_weapon_enhancement_level(equipped_weapon_id)
	# 사다리 단(rung)은 가족을 가리지 않고 비교한다 — 을지로 권장이 AKM(2단)이면
	# 펌프 산탄총(2단)도 같은 단으로 친다. 사다리 밖 기종(M1911·MP5)은 -1.
	var weapon_rung_ok := (
		not equipped_weapon_id.is_empty()
		and _ladder_rank(equipped_weapon_id) >= _ladder_rank(goal_weapon_id)
	)
	var weapon_ok := weapon_rung_ok and equipped_level >= goal_level
	var goal := {
		"zone_id": zone_id,
		"stage": stage,
		"family_index": family_index,
		"set_label": "T%d" % (family_index + 1),
		"set_ids": set_ids.duplicate(),
		"pieces": pieces,
		"set_owned": owned_count,
		"set_equipped": equipped_count,
		"set_ok": owned_count >= set_ids.size(),
		"weapon_id": goal_weapon_id,
		"weapon_level": goal_level,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_level": equipped_level,
		"weapon_rung_ok": weapon_rung_ok,
		"weapon_ok": weapon_ok,
	}
	goal["all_ok"] = bool(goal["set_ok"]) and weapon_ok
	goal["text"] = format_zone_gear_goal_line(goal)
	return goal


static func format_zone_gear_goal_line(goal: Dictionary) -> String:
	# `권장: T1 세트 2/3 · AK +3/5` — 단이 모자라면 `AKM +15 권장 · 현재 AK +12`.
	if goal.is_empty():
		return ""
	var set_part := "%s 세트 %d/%d" % [
		str(goal.get("set_label", "T1")),
		int(goal.get("set_owned", 0)),
		(goal.get("set_ids", []) as Array).size(),
	]
	var weapon_part := ""
	var goal_name := str(WEAPON_SHORT_NAMES.get(str(goal.get("weapon_id", "")), str(goal.get("weapon_id", ""))))
	var equipped_id := str(goal.get("equipped_weapon_id", ""))
	if bool(goal.get("weapon_rung_ok", false)):
		weapon_part = "%s +%d/%d" % [
			str(WEAPON_SHORT_NAMES.get(equipped_id, equipped_id)),
			int(goal.get("equipped_level", 0)),
			int(goal.get("weapon_level", 0)),
		]
	else:
		var current := "무기 없음"
		if not equipped_id.is_empty():
			current = "%s +%d" % [str(WEAPON_SHORT_NAMES.get(equipped_id, equipped_id)), int(goal.get("equipped_level", 0))]
		weapon_part = "%s +%d 권장 · 현재 %s" % [goal_name, int(goal.get("weapon_level", 0)), current]
	return "권장: %s · %s" % [set_part, weapon_part]


static func attach_zone_gear_goal_line(anchor: Label, zone_id: String, font: Font) -> Label:
	# 브리핑 존 카드의 장비 목표 줄. 호출부(shelter_interior)는 한 줄만 부른다 —
	# 라벨은 anchor(다음 목표 줄) 바로 뒤에 형제로 만들어 두고 이후엔 갱신만 한다.
	# 충족 초록 / 미충족 빨강.
	if not is_instance_valid(anchor):
		return null
	var parent := anchor.get_parent()
	if parent == null:
		return null
	var line := parent.get_node_or_null("RaidZoneGearGoalLine") as Label
	if line == null:
		line = Label.new()
		line.name = "RaidZoneGearGoalLine"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font != null:
			line.add_theme_font_override("font", font)
		line.add_theme_font_size_override("font_size", 13)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
		parent.move_child(line, anchor.get_index() + 1)
	var goal := get_zone_gear_goal(zone_id)
	var text := str(goal.get("text", ""))
	line.text = text
	line.add_theme_color_override(
		"font_color", GEAR_GOAL_OK_COLOR if bool(goal.get("all_ok", false)) else GEAR_GOAL_MISSING_COLOR
	)
	line.visible = not text.is_empty()
	return line


static func _ladder_rank(weapon_id: String) -> int:
	for family_id in WEAPON_SYSTEM.WEAPON_FAMILY_LADDER.keys():
		var ladder: Array = WEAPON_SYSTEM.WEAPON_FAMILY_LADDER[family_id]
		var index := ladder.find(weapon_id)
		if index >= 0:
			return index
	return -1


static func _is_armor_base_equipped(base_id: String) -> bool:
	for equipped_id in [
		GameState.equipped_body_armor_id,
		GameState.equipped_head_armor_id,
		GameState.equipped_footwear_id,
	]:
		if not str(equipped_id).is_empty() and str(GameState.split_equipment_id(str(equipped_id))[0]) == base_id:
			return true
	return false


static func _owned_armor_base_count(base_id: String) -> int:
	# 가방 + 창고. 레벨(@n)은 무시하고 기종만 본다.
	var total := 0
	for equipment_id_value in GameState.equipment_inventory.keys():
		var equipment_id := str(equipment_id_value)
		if str(GameState.split_equipment_id(equipment_id)[0]) == base_id:
			total += maxi(0, GameState.get_equipment_count(equipment_id))
	for entry in GameState.storage_inventory:
		if str(entry.get("type", "")) != "equipment":
			continue
		if str(GameState.split_equipment_id(str(entry.get("id", "")))[0]) == base_id:
			total += maxi(0, int(entry.get("count", 0)))
	return total
