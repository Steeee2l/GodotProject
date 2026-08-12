extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)

	var shelter_scene := load("res://scenes/shelter_interior.tscn") as PackedScene
	var first_shelter := shelter_scene.instantiate() as Node3D
	root.add_child(first_shelter)
	await process_frame
	await physics_frame
	var initial_modules := first_shelter.get_node("StageOneModules") as Node3D
	assert(initial_modules.get_node_or_null("PlayerBed") != null)
	assert(str(first_shelter.call("_build_offline_status_text", {})).is_empty())
	# 창고는 시작부터 열려 있다(전리품 보관 학습). 나머지는 계약/복귀로 해금.
	assert(initial_modules.get_node_or_null("ShelterStorage") != null)
	for locked_node_name in [
		"WeaponWorkbench",
		"ScratcherBank",
		"CatnipScraper",
		"SurvivalTrainingFacility",
	]:
		assert(initial_modules.get_node_or_null(locked_node_name) == null)
	assert(get_nodes_in_group("shelter_contract_agent").size() == 1)
	assert(get_nodes_in_group("shelter_merchant").is_empty())
	assert(root.find_child("ContractNarrativePanel", true, false) is PanelContainer)
	# 타자기 연출 때문에 한 줄에 입력이 2번(전체 표시→다음) 들 수 있다.
	for _advance_index in 24:
		if not bool(first_shelter.get("contract_story_open")):
			break
		first_shelter.call("_advance_contract_story")
	assert(not bool(first_shelter.get("contract_story_open")))
	assert(bool(game_state.get("saja_intro_seen")))
	# 스토리 모달이 닫혀야(다음 프레임 그룹 해제) 하단 액션 버튼이 다시 보인다.
	await process_frame
	await process_frame
	var shelter_medkit_button := root.find_child("ShelterMedkitButton", true, false) as Button
	assert(shelter_medkit_button != null)
	assert(shelter_medkit_button.visible)
	assert(shelter_medkit_button.text.contains("SHIFT"))
	game_state.set("player_health", 50)
	game_state.set("medkits", 1)
	first_shelter.call("_update_shelter_medkit_button")
	first_shelter.call("_use_shelter_medkit")
	assert(int(game_state.get("player_health")) == 88)
	assert(int(game_state.get("medkits")) == 0)
	# 운영 독: 시설 5종 버튼이 항상 떠 있고 잠금 상태를 보여준다.
	var ops_dock := root.find_child("ShelterOpsDock", true, false) as VBoxContainer
	assert(ops_dock != null)
	assert(ops_dock.get_node_or_null("OpsButton_scratcher_bank") is Button)
	assert((ops_dock.get_node("OpsButton_scratcher_bank") as Button).text.contains("잠김"))
	first_shelter.queue_free()
	await process_frame

	game_state.call("register_shelter_return")
	assert(bool(game_state.call("roll_merchant_visit", 0.0)))
	assert(str(game_state.get("merchant_status")) == "waiting")
	game_state.set("merchant_status", "away")
	assert(bool(game_state.call("is_contract_agent_available")))
	assert(bool(game_state.call("is_shelter_facility_unlocked", "storage")))
	assert(bool(game_state.call("is_shelter_facility_unlocked", "training")))
	assert(not bool(game_state.call("is_shelter_facility_unlocked", "scratcher_bank")))

	var progressed_shelter := shelter_scene.instantiate() as Node3D
	root.add_child(progressed_shelter)
	await process_frame
	await physics_frame
	var progressed_modules := progressed_shelter.get_node("StageOneModules") as Node3D
	assert(progressed_modules.get_node_or_null("ShelterStorage") != null)
	assert(progressed_modules.get_node_or_null("SurvivalTrainingFacility") != null)
	assert(progressed_modules.get_node_or_null("ScratcherBank") == null)
	assert(get_nodes_in_group("shelter_contract_agent").size() == 1)
	assert(get_nodes_in_group("shelter_iron_trainer").size() == 1)
	assert(root.find_child("ContractNarrativePanel", true, false) is PanelContainer)
	for _advance_index in 24:
		if not bool(progressed_shelter.get("contract_story_open")):
			break
		progressed_shelter.call("_advance_contract_story")
	assert(bool(game_state.get("saja_second_run_intro_seen")))
	var iron_accept := game_state.call("accept_current_iron_mission") as Dictionary
	assert(bool(iron_accept.get("ok", false)))
	game_state.call("advance_contract", "kills", 8)
	var iron_state := game_state.call("get_iron_mission_state") as Dictionary
	assert(str(iron_state.get("status", "")) == "complete")
	var iron_claim := game_state.call("claim_current_iron_mission_reward") as Dictionary
	assert(bool(iron_claim.get("ok", false)))
	assert(int((game_state.get("training_levels") as Dictionary).get("vitality", 0)) == 1)

	var accept_result := game_state.call("accept_current_contract") as Dictionary
	assert(bool(accept_result.get("ok", false)))
	game_state.call("advance_contract", "parts", 3)
	var claim_result := game_state.call("claim_current_contract_reward") as Dictionary
	assert(bool(claim_result.get("facility_unlocked", false)))
	assert(str(claim_result.get("facility_id", "")) == "scratcher_bank")
	progressed_shelter.call("_refresh_unlocked_facilities")
	assert(
		str(progressed_shelter.call("_build_offline_status_text", {}))
		== "쉘터에 복귀했습니다. 생산기에 주민을 배치할 수 있습니다."
	)
	assert(progressed_modules.get_node_or_null("ScratcherBank") != null)
	# 기계는 로직 노드다 — 씬 기물이 아니라 운영 독이 여는 UI만 남는다.
	var scratcher_logic := progressed_modules.get_node("ScratcherBank")
	assert(scratcher_logic.get_child_count() == 0)
	assert(not scratcher_logic.is_in_group("shelter_module"))
	var facility_logic := progressed_shelter.get("facility_logic") as Dictionary
	assert(facility_logic.get("scratcher_bank") == scratcher_logic)

	progressed_shelter.call("_unlock_all_facilities_debug")
	assert(progressed_modules.get_node_or_null("WeaponWorkbench") != null)
	assert(progressed_modules.get_node_or_null("CatnipScraper") != null)
	var residents_before := int(game_state.get("rescued_workers"))
	assert(bool(progressed_shelter.call("_add_debug_resident")))
	assert(int(game_state.get("rescued_workers")) == residents_before + 1)
	var resident_story := game_state.call("get_pending_shelter_story_event") as Dictionary
	assert(str(resident_story.get("id", "")).begins_with("saja_resident_"))
	game_state.call("mark_shelter_story_event_seen", str(resident_story.get("id", "")))
	game_state.call("register_boss_defeat")
	var boss_story := game_state.call("get_pending_shelter_story_event") as Dictionary
	assert(str(boss_story.get("id", "")).begins_with("saja_boss_"))
	game_state.call("mark_shelter_story_event_seen", str(boss_story.get("id", "")))
	game_state.set("recovered_story_cargo_ids", ["cargo_signal_01"])
	var juhong_story := game_state.call("get_pending_juhong_event") as Dictionary
	assert(str(juhong_story.get("speaker", "")) == "주홍")
	progressed_shelter.call("_setup_juhong_story_character")
	await process_frame
	assert(get_nodes_in_group("shelter_story_visitor").size() == 1)

	print("SHELTER_UNLOCK_FLOW_OK saja=story+facilities iron=training juhong=story_event")
	quit(0)
