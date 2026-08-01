extends SceneTree

const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")


func _init() -> void:
	var opening_missions := FIELD_MISSION_CATALOG.build_basic_missions(0)
	assert(opening_missions.size() == 2)
	assert(str(opening_missions[0].get("id")) == "parts")
	assert(str(opening_missions[1].get("id")) == "subway")

	var boss_missions := FIELD_MISSION_CATALOG.build_basic_missions(1)
	assert(str(boss_missions[1].get("id")) == "subway_boss")

	var random := RandomNumberGenerator.new()
	random.seed = 91
	assert(str(FIELD_MISSION_CATALOG.pick_definition(0, random).get("type")) == "defense")
	assert(str(FIELD_MISSION_CATALOG.pick_definition(3, random).get("type")) == "stealth")
	assert(FIELD_MISSION_CATALOG.get_category("investigate") == "조사")

	var rules := FIELD_MISSION_CATALOG.build_rules("stealth", true, 42.0)
	assert(rules.contains("42m"))
	assert(rules.contains("총성"))
	assert(rules.contains("발각"))
	var reward_text := FIELD_MISSION_CATALOG.format_reward({"canned_food": 2, "ammo": 12})
	assert(reward_text.contains("통조림 2"))
	assert(reward_text.contains("탄약 12"))
	print("field_mission_catalog_smoke_test: PASS")
	quit()
