class_name InteractionTargeting
extends RefCounted


static func rank_candidates(
	origin: Vector3,
	facing_direction: Vector3,
	candidates: Array[Node3D],
	facing_weight: float
) -> Array[Node3D]:
	var flat_facing := facing_direction
	flat_facing.y = 0.0
	flat_facing = flat_facing.normalized() if flat_facing.length_squared() > 0.01 else Vector3.FORWARD
	var ranked: Array[Dictionary] = []
	for point in candidates:
		if not is_instance_valid(point):
			continue
		var offset := point.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		var facing_dot := flat_facing.dot(offset.normalized()) if distance > 0.01 else 1.0
		ranked.append({
			"point": point,
			"score": distance - maxf(0.0, facing_dot) * facing_weight,
		})
	ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first["score"]) < float(second["score"])
	)
	var result: Array[Node3D] = []
	for entry in ranked:
		result.append(entry["point"] as Node3D)
	return result


static func get_action_label(interaction_type: String) -> String:
	match interaction_type:
		"extraction":
			return "쉘터로 탈출"
		"building_portal":
			return "건물 진입"
		"loot_container":
			return "내용물 수색"
		"salvage":
			return "부품 분해"
		"rescue":
			return "주민 구조"
		"corpse_recovery":
			return "분실 장비 회수"
		"mission_start":
			return "현장 임무 수락"
		"lore", "lore_clue":
			return "기록 조사"
		"jackpot_clue":
			return "단서 조사"
		"jackpot_power":
			return "비상 전력 복구"
		"jackpot_cargo":
			return "봉인 화물 회수"
		"incident":
			return "보급품 확보"
		_:
			return "상호작용"


static func build_prompt_state(
	interaction_type: String,
	display_name: String,
	hold_duration: float,
	locked_reason: String,
	reward_multiplier: float,
	rescued_count: int,
	candidate_count: int,
	next_name: String
) -> Dictionary:
	var action_label := get_action_label(interaction_type)
	var button_text := "[F] 길게 눌러 %s" % action_label
	var hints: PackedStringArray = []
	if not locked_reason.is_empty():
		button_text = "잠김 · %s" % locked_reason
		hints.append("필요 조건을 충족해야 합니다")
	elif interaction_type == "extraction":
		button_text = "[F] %s · 보상 ×%.2f · 주민 %d명" % [
			action_label,
			reward_multiplier,
			maxi(0, rescued_count),
		]
	else:
		hints.append("%.1f초 · 키를 놓으면 취소" % maxf(0.0, hold_duration))
	if candidate_count > 1:
		hints.append("주변 %d개 · [G] 다음: %s" % [candidate_count, next_name])
	return {
		"target_text": display_name,
		"button_text": button_text,
		"hint_text": "  |  ".join(hints),
		"disabled": not locked_reason.is_empty(),
		"show_progress": interaction_type != "extraction" and locked_reason.is_empty(),
		"can_hold": interaction_type != "extraction" and locked_reason.is_empty(),
	}
