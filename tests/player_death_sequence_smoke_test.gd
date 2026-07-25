extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.set("run_kills", 3)
	main_scene.set("run_damage_dealt", 420)
	main_scene.call("_begin_player_death_sequence")
	assert(bool(main_scene.get("player_death_sequence_active")))
	assert(Engine.time_scale < 1.0)
	var label := main_scene.get("game_over_label") as Label
	assert(label != null)
	assert(label.text.contains("GAME OVER"))
	assert(label.text.contains("처치한 적"))
	var loss_label := main_scene.get("game_over_loss_label") as Label
	assert(loss_label != null)
	assert(loss_label.text.contains("분실한 장비 및 소모품"))
	assert(loss_label.text.contains("AK-47"))
	assert(loss_label.text.contains("탄약"))
	var corpse := game_state.get("pending_corpse_recovery") as Dictionary
	var corpse_loot := corpse.get("loot", {}) as Dictionary
	assert(int((corpse_loot.get("weapon_inventory", {}) as Dictionary).get("ak47", 0)) == 1)
	main_scene.call("_clear_carried_inventory_after_death")
	assert(not bool(game_state.get("has_ak")))
	assert(int(game_state.call("get_weapon_count", "ak47")) == 0)
	assert(str(game_state.get("equipped_weapon_id")).is_empty())
	Engine.time_scale = 1.0
	main_scene.queue_free()
	print("PLAYER_DEATH_SEQUENCE_OK")
	quit(0)
