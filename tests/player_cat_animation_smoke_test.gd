extends SceneTree


const DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]


func _initialize() -> void:
	call_deferred("_run")


func _assert_cat_frames(sprite: AnimatedSprite3D, include_melee: bool = false) -> void:
	assert(sprite != null)
	assert(is_equal_approx(sprite.pixel_size, 0.0098))
	for direction in DIRECTIONS:
		for state in ["idle", "walk"]:
			var animation := "%s_%s" % [state, direction]
			assert(sprite.sprite_frames.has_animation(animation))
			assert(sprite.sprite_frames.get_frame_count(animation) == 4)
			var expected_fps := 4.0 if state == "idle" else 8.0
			assert(is_equal_approx(sprite.sprite_frames.get_animation_speed(animation), expected_fps))
		if include_melee:
			var melee_animation := "melee_%s" % direction
			assert(sprite.sprite_frames.has_animation(melee_animation))
			assert(sprite.sprite_frames.get_frame_count(melee_animation) == 4)
			assert(not sprite.sprite_frames.get_animation_loop(melee_animation))
			assert(is_equal_approx(sprite.sprite_frames.get_animation_speed(melee_animation), 8.0))


func _run() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var field_sprite := main_scene.get_node("Player/Survivor") as AnimatedSprite3D
	_assert_cat_frames(field_sprite, true)
	for direction in DIRECTIONS:
		main_scene.call("_set_facing", direction)
		assert(field_sprite.animation == "idle_%s" % direction)
		assert(not field_sprite.flip_h)
		var roll_animation := "roll_%s" % direction
		assert(field_sprite.sprite_frames.has_animation(roll_animation))
		assert(field_sprite.sprite_frames.get_frame_count(roll_animation) == 4)
		assert(not field_sprite.sprite_frames.get_animation_loop(roll_animation))
		assert(is_equal_approx(field_sprite.sprite_frames.get_animation_speed(roll_animation), 10.0))
	assert(main_scene.get("hud").roll_cooldown_indicator is Control)
	main_scene.call("_set_facing", "s")
	main_scene.call("_try_start_roll")
	assert(main_scene.get("roll_active"))
	assert(field_sprite.animation == "roll_s")
	main_scene.call("_update_roll", 0.06)
	assert(not (main_scene.get("roll_afterimages") as Array).is_empty())
	main_scene.call("_update_roll", 0.5)
	assert(not main_scene.get("roll_active"))
	assert(is_equal_approx(float(main_scene.get("roll_stamina")), 65.0))
	main_scene.call("_try_start_roll")
	assert(main_scene.get("roll_active"))
	main_scene.call("_update_roll", 0.01)
	var roll_velocity := (main_scene.get_node("Player") as CharacterBody3D).velocity.length()
	assert(roll_velocity > 34.0)
	main_scene.call("_finish_roll")
	main_scene.set("roll_stamina", 30.0)
	main_scene.call("_try_start_roll")
	assert(not main_scene.get("roll_active"))
	main_scene.set("roll_stamina", 30.0)
	main_scene.set("roll_active", false)
	main_scene.call("_physics_process", 1.0)
	assert(float(main_scene.get("roll_stamina")) > 55.0)
	main_scene.set("melee_attack_cooldown", 0.0)
	main_scene.call("_set_facing", "s")
	main_scene.call("_try_melee_attack")
	assert(bool(main_scene.get("melee_attack_active")))
	assert(field_sprite.animation == "melee_%s" % str(main_scene.get("facing")))
	var melee_fan := main_scene.get("melee_fan_indicator") as MeshInstance3D
	assert(melee_fan != null)
	assert(melee_fan.visible)
	assert(melee_fan.mesh.get_surface_count() == 2)
	var attack_direction := main_scene.get("melee_attack_direction") as Vector3
	assert(is_equal_approx(melee_fan.rotation.y, atan2(attack_direction.x, attack_direction.z)))
	main_scene.call("_update_melee_attack", 0.2)
	assert(bool(main_scene.get("melee_hit_resolved")))
	main_scene.call("_update_melee_attack", 0.4)
	assert(not bool(main_scene.get("melee_attack_active")))
	assert(field_sprite.animation == "idle_%s" % str(main_scene.get("facing")))
	main_scene.queue_free()
	await process_frame

	var shelter_scene: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter_scene)
	await process_frame
	var shelter_sprite := shelter_scene.get_node("ShelterPlayer/Survivor") as AnimatedSprite3D
	_assert_cat_frames(shelter_sprite)
	for direction in DIRECTIONS:
		var shelter_roll_animation := "roll_%s" % direction
		assert(shelter_sprite.sprite_frames.has_animation(shelter_roll_animation))
		assert(shelter_sprite.sprite_frames.get_frame_count(shelter_roll_animation) == 4)
		assert(not shelter_sprite.sprite_frames.get_animation_loop(shelter_roll_animation))
	assert(shelter_scene.get("roll_cooldown_indicator") is Control)
	shelter_scene.call("_try_start_roll")
	assert(shelter_scene.get("roll_active"))
	assert(shelter_sprite.animation == "roll_s")
	shelter_scene.call("_update_roll", 0.06)
	assert(not (shelter_scene.get("roll_afterimages") as Array).is_empty())
	shelter_scene.call("_update_roll", 0.5)
	assert(not shelter_scene.get("roll_active"))
	assert(is_equal_approx(float(shelter_scene.get("roll_stamina")), 65.0))
	shelter_scene.set("roll_stamina", 30.0)
	shelter_scene.call("_try_start_roll")
	assert(not shelter_scene.get("roll_active"))
	shelter_scene.call("_physics_process", 1.0)
	assert(float(shelter_scene.get("roll_stamina")) > 55.0)

	print("PLAYER_CAT_ANIMATION_OK base_animations=16 melee_animations=8 melee_frames=32 roll_animations=8 roll_frames=32 scenes=2")
	quit(0)
