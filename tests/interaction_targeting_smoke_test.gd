extends SceneTree

const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")


func _init() -> void:
	var forward_target := Node3D.new()
	forward_target.position = Vector3(0.0, 0.0, -2.4)
	var side_target := Node3D.new()
	side_target.position = Vector3(1.8, 0.0, 0.0)
	root.add_child(forward_target)
	root.add_child(side_target)
	# _init 시점에는 아직 노드가 트리에 실제로 붙지 않아 global_position이
	# 무효였다. rank_candidates가 전부 원점으로 읽어서 순위 검증이 항상
	# 실패하고 있었다. 한 프레임 기다린 뒤에 판정한다.
	await process_frame
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
		""
	)
	assert(prompt.get("target_text") == "파손 차량")
	# button_text / hint_text는 아무도 읽지 않아 제거했다. 프롬프트는 이제
	# "행동 · 대상" 한 줄이고, 보조 문구는 main.gd가 상황을 보고 직접 만든다.
	assert(not prompt.has("button_text"))
	assert(not prompt.has("hint_text"))
	assert(bool(prompt.get("can_hold")))
	assert(bool(prompt.get("show_progress")))
	print("interaction_targeting_smoke_test: PASS")
	quit()
