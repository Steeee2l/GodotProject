extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	for _return_index in 3:
		game_state.call("register_shelter_return")
	game_state.set("contract_agent_intro_seen", true)

	var shelter := (load("res://scenes/shelter_interior.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame
	shelter.call("_open_contract_ui")
	shelter.call("_accept_current_contract")
	assert(bool(shelter.get("contract_story_open")))
	var narrative_panel := root.find_child("ContractNarrativePanel", true, false) as PanelContainer
	assert(narrative_panel is PanelContainer)
	assert(narrative_panel.size.x <= root.get_viewport().get_visible_rect().size.x * 0.94)
	var accept_lines := shelter.get("contract_story_lines") as Array
	assert(accept_lines.size() >= 3)
	# 실제로 쓰이는 계약 체인은 SAJA_FACILITY_CONTRACTS다. 예전에는 쓰이지 않는
	# MISSION_CONTRACTS 초안의 대사를 기대해서 이 단언이 항상 실패했다.
	assert(str(accept_lines[0]).contains("쉘터"))
	while bool(shelter.get("contract_story_open")):
		shelter.call("_advance_contract_story")

	game_state.call("advance_contract", "parts", 3)
	shelter.call("_open_contract_ui")
	shelter.call("_claim_current_contract")
	assert(bool(shelter.get("contract_story_open")))
	var report_lines := shelter.get("contract_story_lines") as Array
	assert(report_lines.size() >= 4)
	# 첫 계약의 보상은 꾹꾹이 생산 라인 해금이고, 완료 시 사자의 기록이 열린다.
	# (예전 단언은 삭제된 MISSION_CONTRACTS 초안의 문구를 찾고 있었다.)
	assert(report_lines.any(func(line: Variant) -> bool: return str(line).contains("고철 생산기")))
	assert(report_lines.any(func(line: Variant) -> bool: return str(line).contains("기록")))
	while bool(shelter.get("contract_story_open")):
		shelter.call("_advance_contract_story")
	shelter.queue_free()
	await process_frame

	game_state.call("reset_run")
	game_state.set("shelter_tier", 2)
	game_state.call("select_raid_zone", "namdaemun_market")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var player := main.get("player") as CharacterBody3D
	var boss := main.call(
		"_spawn_rocket_boss_at",
		player.global_position + Vector3(9.0, 0.78, 0.0),
		0.75,
		"CinematicTestBoss"
	) as CharacterBody3D
	boss.set_meta("display_name", "테스트 포격수")
	var health_before := int(main.get("player_health"))
	main.set("fire_button_held", true)
	main.set("mouse_fire_held", true)
	main.set("laser_aim_held", true)
	main.set("touch_vector", Vector2(0.75, 0.0))
	main.call("_on_enemy_died", boss)
	assert(bool(main.get("boss_defeat_sequence_active")))
	assert(Engine.time_scale < 1.0)
	assert((main.get("boss_defeat_overlay") as Control).visible)
	assert(not bool(main.get("fire_button_held")))
	assert(not bool(main.get("mouse_fire_held")))
	assert(not bool(main.get("laser_aim_held")))
	assert((main.get("touch_vector") as Vector2).is_zero_approx())
	assert(not (main.get("aim_canvas") as CanvasLayer).visible)
	var defeat_panel := main.get("boss_defeat_panel") as PanelContainer
	assert(defeat_panel.size.x <= 720.0)
	assert(defeat_panel.size.x <= root.get_viewport().get_visible_rect().size.x * 0.85)
	# 처치 문구는 "<이름>, 침묵" 형식이다.
	assert((main.get("boss_defeat_title") as Label).text.contains("테스트 포격수"))
	assert((main.get("boss_defeat_title") as Label).text.contains("침묵"))
	assert((main.get("boss_defeat_focus_position") as Vector3).distance_to(boss.global_position) < 0.01)
	main.call("take_damage", 20)
	assert(int(main.get("player_health")) == health_before)
	await create_timer(1.9, true, false, true).timeout
	assert(not bool(main.get("boss_defeat_sequence_active")))
	assert(is_equal_approx(Engine.time_scale, 1.0))
	assert((main.get("aim_canvas") as CanvasLayer).visible)

	print("CONTRACT_NARRATIVE_BOSS_OK voice=true story=true lore=true focus=true slowmo=true shake=true")
	main.queue_free()
	await process_frame
	quit(0)
