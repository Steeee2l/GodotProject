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
		"companion_revive":
			# 주홍 동행 — 쓰러진 주홍 [F] 홀드 소생(main._complete_field_interaction).
			return "주홍 소생"
		"corpse_recovery":
			return "분실 장비 회수"
		"mission_start":
			return "현장 임무 수락"
		"lore", "lore_clue":
			return "기록 조사"
		"main_mission_step":
			return "메인 임무 지점 조사"
		"main_mission_key":
			return "열쇠 확보"
		"main_mission_locked":
			return "잠긴 거점"
		"main_mission_defense":
			return "봉쇄 해제 시작"
		"main_mission_recovery":
			return "회수물 확보"
		"incident":
			return "보급품 확보"
		_:
			return "상호작용"


static func build_prompt_state(
	interaction_type: String,
	display_name: String,
	locked_reason: String
) -> Dictionary:
	# 예전에는 여기서 button_text / hint_text 문자열까지 조립했지만 읽는 곳이
	# 없었다. HUD가 "행동 · 대상" 한 줄로 합쳐지면서 소요시간·배율·후송 인원·
	# 후보 개수 인자도 전부 쓰이지 않게 되어 함께 걷어냈다.
	return {
		"target_text": display_name,
		"disabled": not locked_reason.is_empty(),
		"show_progress": interaction_type != "extraction" and locked_reason.is_empty(),
		"can_hold": interaction_type != "extraction" and locked_reason.is_empty(),
	}
