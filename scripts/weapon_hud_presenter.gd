class_name WeaponHudPresenter
extends RefCounted

const READY_COLOR := Color("#f1ce70")
const LOW_COLOR := Color("#f0a454")
const EMPTY_COLOR := Color("#ef756f")
const RESERVE_COLOR := Color("#c5d0c9")
const MUTED_COLOR := Color("#8b9992")


static func build_state(
	has_weapon: bool,
	current_ammo: int,
	magazine_size: int,
	reserve_ammo: int,
	reloading: bool,
	reload_remaining: float,
	ammo_name: String
) -> Dictionary:
	var safe_magazine_size := maxi(1, magazine_size)
	var safe_current_ammo := maxi(0, current_ammo)
	var safe_reserve_ammo := maxi(0, reserve_ammo)
	var low_threshold := maxi(1, ceili(float(safe_magazine_size) * 0.2))
	var status_text := "사격 준비"
	var ammo_color := READY_COLOR
	if not has_weapon:
		status_text = "무기 없음"
		ammo_color = MUTED_COLOR
	elif reloading:
		status_text = "재장전 %.1f초" % maxf(0.0, reload_remaining)
	elif safe_current_ammo <= 0:
		status_text = "탄창 비움"
		ammo_color = EMPTY_COLOR
	elif safe_current_ammo <= low_threshold:
		status_text = "탄창 부족"
		ammo_color = LOW_COLOR

	# 출정 HUD는 탄창과 예비탄을 한 줄로 합쳐 쓴다. 두 라벨을 따로 두면
	# 같은 정보가 두 번 자리를 차지한다. 건물 내부 HUD는 기존 키를 그대로 쓴다.
	var combined_text := "-- / --"
	if has_weapon:
		combined_text = "%02d / %02d  ·  %d" % [
			safe_current_ammo,
			safe_magazine_size,
			safe_reserve_ammo,
		]
	# 평상시 "사격 준비 · 사용 탄환 7.62mm"는 읽을 이유가 없는 문장이다.
	# 재장전·부족·비움처럼 실제로 손을 움직여야 할 때만 자리를 준다.
	var notable := (not has_weapon) or reloading or safe_current_ammo <= low_threshold
	return {
		"ammo_text": "%02d / %02d" % [safe_current_ammo, safe_magazine_size] if has_weapon else "-- / --",
		"ammo_combined_text": combined_text,
		"reserve_text": "예비 %d발" % safe_reserve_ammo if has_weapon else "예비 없음",
		"status_text": status_text,
		"condition_text": "%s · 사용 탄환  %s" % [status_text, ammo_name] if has_weapon else "가방을 열어 보유 무기를 선택하고 장착하세요.",
		"condition_notable": notable,
		"ammo_color": ammo_color,
		"reserve_color": EMPTY_COLOR if has_weapon and safe_reserve_ammo <= 0 else RESERVE_COLOR,
		"is_low": has_weapon and safe_current_ammo > 0 and safe_current_ammo <= low_threshold,
		"is_empty": has_weapon and safe_current_ammo <= 0,
	}


static func build_interior_line(
	current_health: int,
	max_health: int,
	state: Dictionary
) -> String:
	return "체력  %d/%d     탄약  %s     %s · %s" % [
		maxi(0, current_health),
		maxi(1, max_health),
		str(state.get("ammo_text", "-- / --")),
		str(state.get("reserve_text", "예비 없음")),
		str(state.get("status_text", "무기 없음")),
	]
