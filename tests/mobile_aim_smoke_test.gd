extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var medkit_button := main_scene.get_node("HUD/MedkitButton") as Button
	assert(medkit_button.visible, "The lower-left medkit slot must remain visible on desktop HUDs.")
	assert(medkit_button.text.contains("SHIFT"))

	var player := main_scene.get("player") as CharacterBody3D
	var enemies: Array[CharacterBody3D] = main_scene.get("enemies")
	assert(player != null)
	assert(not enemies.is_empty())
	var target := enemies[0]
	for enemy_index in range(1, enemies.size()):
		enemies[enemy_index].queue_free()
	await process_frame

	var open_direction := Vector3.RIGHT
	for candidate in [
		Vector3.RIGHT,
		Vector3.FORWARD,
		Vector3.LEFT,
		Vector3.BACK,
		Vector3(1.0, 0.0, 1.0).normalized(),
		Vector3(1.0, 0.0, -1.0).normalized(),
		Vector3(-1.0, 0.0, 1.0).normalized(),
		Vector3(-1.0, 0.0, -1.0).normalized(),
	]:
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0.0, 0.45, 0.0),
			player.global_position + candidate * 4.0 + Vector3(0.0, 0.45, 0.0),
			1
		)
		query.exclude = [player.get_rid()]
		if player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			open_direction = candidate
			break

	target.global_position = player.global_position + open_direction * 4.0
	target.force_update_transform()
	target.call("set_player_visibility_factor", 1.0)
	await physics_frame

	var perpendicular := Vector3(-open_direction.z, 0.0, open_direction.x)
	var slightly_offset_input := (open_direction + perpendicular * 0.18).normalized()
	main_scene.call("_on_mobile_flashlight_toggled", true)
	main_scene.call("_update_mobile_aim_direction", slightly_offset_input)
	var assisted_direction := main_scene.get("locked_aim_direction") as Vector3
	assert(assisted_direction.dot(open_direction) > 0.99)

	target.call("set_player_visibility_factor", 0.0)
	var free_direction := -open_direction
	main_scene.call("_update_mobile_aim_direction", free_direction)
	var updated_direction := main_scene.get("locked_aim_direction") as Vector3
	assert(updated_direction.dot(free_direction) > 0.99)
	assert(updated_direction.dot(assisted_direction) < -0.99)

	main_scene.call("_on_mobile_flashlight_toggled", false)
	assert(not bool(main_scene.get("laser_aim_held")))
	print("MOBILE_AIM_OK tracking=true assist=true free_turn=true")
	main_scene.queue_free()
	await process_frame
	quit(0)
