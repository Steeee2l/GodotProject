class_name WeaponRevealGate
extends RefCounted

# 무기는 조준할 때만 보인다.
#
# 왜 —
#   걸어만 다니는데 손에 총이 떠 있으면 이상하다(특히 오프닝의 다리 산책 구간).
#   그래서 "무기를 든 상태"가 아니라 "무기를 쓰는 순간"에만 그림을 보여준다.
#
# 규칙 —
#   보임  : 우클릭 정조준 / 마우스 사격 중, 모바일 조준·발사 버튼 홀드 중,
#           근접 스윙 애니메이션 동안, 재장전 중.
#   숨김  : 걷기·대기. 단 해제 직후 0.5s 는 그대로 두고(연사 사이 깜빡임 방지),
#           그 다음 0.15s 동안 서서히 사라진다.
#
#   숨기는 건 시각뿐이다 — 총구 화염·조준선·명중 판정·적 무기는 건드리지 않는다.
#   HUD 우하단 무기 카드도 정보 UI 라 그대로 둔다.

const LINGER_SECONDS := 0.5
const FADE_SECONDS := 0.15

var alpha := 0.0
var linger_remaining := 0.0
var revealed := false


func update(delta: float, requested: bool) -> float:
	revealed = requested
	if requested:
		linger_remaining = LINGER_SECONDS
		alpha = 1.0
		return alpha
	if linger_remaining > 0.0:
		linger_remaining = maxf(0.0, linger_remaining - delta)
		alpha = 1.0
		return alpha
	alpha = maxf(0.0, alpha - delta / FADE_SECONDS)
	return alpha


func reset(visible_now: bool = false) -> void:
	# 장면 전환·사망 처리에서 상태를 확실히 되돌린다.
	alpha = 1.0 if visible_now else 0.0
	linger_remaining = LINGER_SECONDS if visible_now else 0.0
	revealed = visible_now


func is_drawn() -> bool:
	return alpha > 0.01
