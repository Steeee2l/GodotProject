extends Node

const SHELTER_SCENE := preload("res://scenes/shelter_interior.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree_root := get_tree().root
	var game_state := tree_root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var initial_state := game_state.call("get_contract_state") as Dictionary
	assert(str(initial_state.get("status", "")) == "available")
	assert(int(initial_state.get("total_count", 0)) >= 6)

	var shelter := SHELTER_SCENE.instantiate() as Node3D
	tree_root.add_child(shelter)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert(get_tree().get_nodes_in_group("shelter_contract_agent").size() == 1)
	var trainer := get_tree().get_nodes_in_group("shelter_contract_agent")[0] as Node3D
	var trainer_sprite := trainer.get_node("TrainerSprite") as AnimatedSprite3D
	assert(trainer_sprite.sprite_frames.get_frame_count("idle_down_left") == 4)
	var shelter_player := shelter.get_node("ShelterPlayer") as CharacterBody3D
	shelter_player.global_position = trainer.global_position
	shelter.call("_update_nearby_station")
	assert(str(shelter.get("current_station")) == "contract_agent")

	shelter.call("_open_contract_ui")
	await get_tree().process_frame
	assert(tree_root.find_child("ContractAgentPanel", true, false) is PanelContainer)
	shelter.call("_accept_current_contract")
	assert(str(game_state.get("contract_status")) == "active")
	var progress_result := game_state.call("advance_contract", "parts", 3) as Dictionary
	assert(bool(progress_result.get("completed", false)))
	assert(str(game_state.get("contract_status")) == "complete")
	var food_before := int(game_state.get("canned_food"))
	var report_result := game_state.call("claim_current_contract_reward") as Dictionary
	assert(bool(report_result.get("ok", false)))
	assert(int(game_state.get("canned_food")) > food_before)
	assert(not (game_state.get("unlocked_contract_lore") as Array).is_empty())
	assert(str(game_state.get("contract_status")) == "available")

	print("SHELTER_CONTRACT_OK trainer=true accepted=true reported=true lore=true")
	get_tree().quit(0)
