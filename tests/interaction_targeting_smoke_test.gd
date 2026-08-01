extends SceneTree

const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")


func _init() -> void:
	var forward_target := Node3D.new()
	forward_target.position = Vector3(0.0, 0.0, -2.4)
	var side_target := Node3D.new()
	side_target.position = Vector3(1.8, 0.0, 0.0)
	root.add_child(forward_target)
	root.add_child(side_target)
	var candidates: Array[Node3D] = [side_target, forward_target]
	var ranked := INTERACTION_TARGETING.rank_candidates(
		Vector3.ZERO,
		Vector3.FORWARD,
		candidates,
		1.35
	)
	assert(ranked[0] == forward_target)
	assert(INTERACTION_TARGETING.get_action_label("salvage") == "부품 분해")
	var prompt := INTERACTION_TARGETING.build_prompt_state(
		"salvage",
		"파손 차량",
		2.4,
		"",
		1.0,
		0,
		2,
		"보급 가방"
	)
	assert(prompt.get("target_text") == "파손 차량")
	assert(str(prompt.get("button_text")).contains("부품 분해"))
	assert(str(prompt.get("hint_text")).contains("키를 놓으면 취소"))
	assert(str(prompt.get("hint_text")).contains("보급 가방"))
	assert(bool(prompt.get("can_hold")))
	print("interaction_targeting_smoke_test: PASS")
	quit()
