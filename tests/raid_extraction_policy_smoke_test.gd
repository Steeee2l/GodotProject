extends SceneTree

const RAID_EXTRACTION_POLICY := preload("res://scripts/raid_extraction_policy.gd")


func _init() -> void:
	var safe_route := RAID_EXTRACTION_POLICY.get_route(0)
	assert(str(safe_route.get("title")) == "안전 귀환로")
	assert(is_equal_approx(float(safe_route.get("reward_multiplier")), 1.0))

	var safe_bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(0, 4, true, 8, 123)
	assert(int(safe_bonus.get("food")) == 0)
	assert(int(safe_bonus.get("component_count")) == 0)

	var detour_bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(1, 2, true, 8, 123)
	var danger_bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(2, 2, true, 8, 123)
	assert(int(detour_bonus.get("food")) > 0)
	assert(int(danger_bonus.get("food")) > int(detour_bonus.get("food")))
	assert(int(danger_bonus.get("medkits")) == 1)
	assert(int(danger_bonus.get("component_count")) > 0)
	assert(str(danger_bonus.get("summary")).contains("경로 보급"))
	print("raid_extraction_policy_smoke_test: PASS")
	quit()
