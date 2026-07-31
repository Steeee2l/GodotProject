extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene := packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	var player := main_scene.get("player") as CharacterBody3D
	var enemies := main_scene.get("enemies") as Array
	assert(not enemies.is_empty())
	var target := enemies[0] as CharacterBody3D
	for index in enemies.size():
		var enemy := enemies[index] as CharacterBody3D
		enemy.set_physics_process(false)
		enemy.global_position = (
			player.global_position + Vector3(24.0 + float(index) * 2.0, 0.0, 0.0)
		)
	target.global_position = player.global_position + Vector3(1.25, 0.0, 0.0)
	target.set("alerted", true)
	target.set("detection_awareness", 1.0)
	target.set("perception_state", "combat")
	await physics_frame

	main_scene.call("_update_stealth_takedown_prompt")
	assert(not bool((main_scene.get("stealth_takedown_prompt") as Control).visible))
	assert(not bool(target.call(
		"can_receive_stealth_takedown",
		player.global_position,
		2.0
	)))

	target.set("alerted", false)
	target.set("detection_awareness", 0.2)
	target.set("perception_state", "suspicious")
	main_scene.call("_update_stealth_takedown_prompt")
	assert(main_scene.get("nearby_stealth_takedown_target") == target)
	assert(bool((main_scene.get("stealth_takedown_prompt") as Control).visible))
	assert(not bool((main_scene.get("stealth_takedown_key_label") as Label).visible))
	assert((main_scene.get("stealth_takedown_input_icon") as TextureRect).texture != null)
	main_scene.set("laser_aim_held", true)
	main_scene.set("has_ak", true)
	main_scene.set("magazine_ammo", 30)
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	main_scene.call("_handle_combat_mouse_button", left_click)
	assert(int(target.get("health")) == 0)
	assert(bool(target.get("backstab_stunned")))
	assert(not bool((main_scene.get("stealth_takedown_prompt") as Control).visible))
	assert(not bool(main_scene.get("mouse_fire_held")))
	assert(float(main_scene.get("camera_shake_time")) > 0.0)
	assert(Engine.time_scale < 1.0)
	assert(main_scene.get_node_or_null("StealthImpactFlash") != null)

	await create_timer(0.18, true, false, true).timeout
	assert(is_equal_approx(Engine.time_scale, 1.0))
	await create_timer(0.3, true, false, true).timeout
	assert(not is_instance_valid(target) or bool(target.get("dying")))
	print("STEALTH_TAKEDOWN_OK range=2.0 prompt=mouse_icon aiming=true slowmo=true fatal=true")
	quit(0)
