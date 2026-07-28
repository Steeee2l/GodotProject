extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	var shelter_scene := load("res://scenes/shelter_interior.tscn") as PackedScene
	var first_shelter := shelter_scene.instantiate() as Node3D
	root.add_child(first_shelter)
	await process_frame
	await physics_frame
	var initial_modules := first_shelter.get_node("StageOneModules") as Node3D
	assert(initial_modules.get_node_or_null("PlayerBed") != null)
	for locked_node_name in [
		"WeaponWorkbench",
		"ScratcherBank",
		"CatnipScraper",
		"ShelterStorage",
		"SurvivalTrainingFacility",
	]:
		assert(initial_modules.get_node_or_null(locked_node_name) == null)
	assert(get_nodes_in_group("shelter_contract_agent").is_empty())
	assert(get_nodes_in_group("shelter_merchant").is_empty())
	first_shelter.queue_free()
	await process_frame

	game_state.call("register_shelter_return")
	assert(bool(game_state.call("roll_merchant_visit", 0.0)))
	assert(str(game_state.get("merchant_status")) == "waiting")
	game_state.set("merchant_status", "away")
	game_state.call("register_shelter_return")
	game_state.call("register_shelter_return")
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
	assert(root.find_child("ContractAgentArrivalPanel", true, false) is PanelContainer)
	for _line_index in 4:
		progressed_shelter.call("_advance_contract_agent_intro")
	assert(bool(game_state.get("contract_agent_intro_seen")))

	var accept_result := game_state.call("accept_current_contract") as Dictionary
	assert(bool(accept_result.get("ok", false)))
	game_state.call("advance_contract", "parts", 3)
	var claim_result := game_state.call("claim_current_contract_reward") as Dictionary
	assert(bool(claim_result.get("facility_unlocked", false)))
	assert(str(claim_result.get("facility_id", "")) == "scratcher_bank")
	progressed_shelter.call("_refresh_unlocked_facilities")
	assert(progressed_modules.get_node_or_null("ScratcherBank") != null)
	assert(progressed_modules.get_node_or_null("ScratcherConveyor") != null)

	progressed_shelter.call("_unlock_all_facilities_debug")
	assert(progressed_modules.get_node_or_null("WeaponWorkbench") != null)
	assert(progressed_modules.get_node_or_null("CatnipScraper") != null)
	var residents_before := int(game_state.get("rescued_workers"))
	assert(bool(progressed_shelter.call("_add_debug_resident")))
	assert(int(game_state.get("rescued_workers")) == residents_before + 1)

	print("SHELTER_UNLOCK_FLOW_OK initial=bed merchant=run1 trainer=run3 contracts=facilities debug=8,9")
	quit(0)
