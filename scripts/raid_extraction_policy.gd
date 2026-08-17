class_name RaidExtractionPolicy
extends RefCounted

const ROUTES := [
	{
		# 세 선택지의 용어를 "탈출로"로 통일한다(귀환로/탈출로 혼용 폐지).
		"title": "안전 탈출로",
		"reward_multiplier": 1.0,
		"color": Color("#d9b44a"),
	},
	{
		"title": "우회 탈출로",
		"reward_multiplier": 1.2,
		"color": Color("#5fc9b4"),
	},
	{
		"title": "고위험 탈출로",
		"reward_multiplier": 1.4,
		"color": Color("#a887e2"),
	},
]

const COMPONENT_IDS := ["rubber_gasket", "scope_lens", "magazine_spring"]
const COMPONENT_NAMES := {
	"rubber_gasket": "고무 패킹",
	"scope_lens": "스코프 렌즈",
	"magazine_spring": "탄창 스프링",
}


static func get_route(index: int) -> Dictionary:
	return (ROUTES[clampi(index, 0, ROUTES.size() - 1)] as Dictionary).duplicate(true)


static func calculate_route_bonus(
	route_index: int,
	hotspots_opened: int,
	incident_claimed: bool,
	run_kills: int,
	map_seed: int
) -> Dictionary:
	if route_index <= 0:
		return {
			"food": 0,
			"medkits": 0,
			"component_id": "",
			"component_count": 0,
			"summary": "안전 탈출로 · 추가 보급 없음",
		}
	var activity_score := maxi(
		1,
		maxi(0, hotspots_opened)
		+ (1 if incident_claimed else 0)
		+ mini(2, floori(float(maxi(0, run_kills)) / 4.0))
	)
	var food_bonus := activity_score
	var component_bonus := 1 if activity_score >= 2 else 0
	var medkit_bonus := 0
	if route_index >= 2:
		food_bonus = activity_score * 2
		component_bonus = 1 + (1 if activity_score >= 3 else 0)
		medkit_bonus = 1
	var component_id := str(COMPONENT_IDS[posmod(
		map_seed + run_kills + hotspots_opened,
		COMPONENT_IDS.size()
	)])
	var parts := ["통조림 +%d" % food_bonus]
	if component_bonus > 0:
		parts.append("%s +%d" % [
			str(COMPONENT_NAMES.get(component_id, "정비 부품")),
			component_bonus,
		])
	if medkit_bonus > 0:
		parts.append("구급약 +%d" % medkit_bonus)
	return {
		"food": food_bonus,
		"medkits": medkit_bonus,
		"component_id": component_id,
		"component_count": component_bonus,
		"summary": "경로 보급 · %s" % " · ".join(parts),
	}
