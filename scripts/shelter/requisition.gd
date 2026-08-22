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

const MAX_SHELTER_TIER := 5

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
