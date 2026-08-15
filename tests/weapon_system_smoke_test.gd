extends SceneTree

class DummyTarget:
	extends Node
	var hits := 0

	func take_hit(_damage: int, _direction: Vector3) -> void:
		hits += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var weapon_system: Script = load("res://scripts/weapon_system.gd")
	assert(weapon_system.WEAPONS.size() == 4)
	assert(weapon_system.MODS.size() == 11)
	assert(weapon_system.MAGAZINES.size() == 4)
	assert(weapon_system.AMMO_TYPES.size() == 8)
	var no_mods: Array[String] = []
	var test_mods: Array[String] = ["laser_pointer", "muffled_sock", "quick_mag"]
	var base_ak: Dictionary = weapon_system.build_stats("ak47", no_mods)
	var modified_ak: Dictionary = weapon_system.build_stats("ak47", test_mods)
	assert(float(modified_ak["base_spread_deg"]) < float(base_ak["base_spread_deg"]))
	assert(float(modified_ak["sound_radius"]) < float(base_ak["sound_radius"]))
	assert(float(modified_ak["reload_time"]) < float(base_ak["reload_time"]))
	assert(weapon_system.validate_mod_loadout(test_mods))
	var duplicate_slot_mods: Array[String] = ["laser_pointer", "laser_pointer"]
	assert(not weapon_system.validate_mod_loadout(duplicate_slot_mods))
	var scoped_mods: Array[String] = ["scope_4x", "ak_precision_receiver"]
	var scoped_ak: Dictionary = weapon_system.build_stats("ak47", scoped_mods)
	assert(float(scoped_ak["scope_zoom"]) == 4.0)
	assert(float(scoped_ak["scope_shift"]) == 10.0)
	assert(not bool(scoped_ak["automatic"]))
	assert(weapon_system.validate_mod_loadout(scoped_mods, "ak47"))
	assert(not weapon_system.validate_mod_loadout(scoped_mods, "mp5"))
	assert(weapon_system.validate_ammo_loadout("ak47", "ak_30rnd", "762_fmj"))
	assert(weapon_system.validate_ammo_loadout("ak47", "ak_30rnd", "762_ap"))
	assert(not weapon_system.validate_ammo_loadout("ak47", "mp5_30rnd", "9mm_fmj"))

	# 로컬 세이브(스탯·방어구)가 로드된 채 돌면 피해 수치 검증이 환경 의존이 된다.
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	assert(main_scene.get("hud").aim_direction_indicator != null)
	assert(main_scene.get("hud").laser_beam != null)
	assert(main_scene.get("hud").aim_reticle != null)
	assert((main_scene.get("laser_glow_layers") as Array).size() == 3)
	assert(main_scene.get("hud").laser_endpoint != null)
	var equipped_weapon_sprite := main_scene.get("weapon_sprite") as AnimatedSprite3D
	var visual_catalog: Script = load("res://scripts/weapon_visual_catalog.gd")
	assert(is_equal_approx(
		equipped_weapon_sprite.pixel_size,
		visual_catalog.get_world_pixel_size("ak47")
	))
	main_scene.call("_set_facing", "w")
	main_scene.call("_update_weapon_pose")
	main_scene.call("_update_building_overlays")
	var equipped_weapon_overlay := main_scene.get("weapon_overlay") as Sprite2D
	var survivor_overlay := main_scene.get("survivor_overlay") as Sprite2D
	assert(equipped_weapon_sprite.animation == "idle_e")
	assert(equipped_weapon_sprite.flip_h)
	assert(equipped_weapon_overlay.flip_h)
	assert(equipped_weapon_overlay.z_index > survivor_overlay.z_index)
	equipped_weapon_sprite.play("fire_w")
	main_scene.call("_set_facing", "e")
	assert(equipped_weapon_sprite.animation == "fire_e")
	equipped_weapon_sprite.play("idle_e")
	main_scene.call("_set_facing", "n")
	main_scene.call("_update_weapon_pose")
	main_scene.call("_update_building_overlays")
	assert(equipped_weapon_sprite.animation == "idle_n")
	assert(equipped_weapon_overlay.z_index < survivor_overlay.z_index)
	assert(main_scene.get("hud").player_world_health_bar != null)
	var compact_health_bar := main_scene.get("hud").player_world_health_bar as Control
	assert(compact_health_bar.size == Vector2(48, 7))
	assert(compact_health_bar.get_node_or_null("Background") is Panel)
	assert(compact_health_bar.get_node_or_null("Fill") is Panel)
	assert(main_scene.get("hud").damage_vignette_material != null)
	var health_before_hit := int(main_scene.get("player_health"))
	main_scene.call("take_hit", 5, Vector3.RIGHT)
	assert(int(main_scene.get("player_health")) == health_before_hit - 5)
	assert(float(main_scene.get("player_hit_stun_time")) > 0.0)
	assert((main_scene.get("recoil_velocity") as Vector3).x > 0.0)
	# 옛 AK 픽업 플로우(_equip_ak47)는 죽은 코드로 제거됐다 — 무장 상태만 부여.
	main_scene.set("has_ak", true)
	var equipped_mods := main_scene.get("equipped_weapon_mods") as Array
	if not equipped_mods.has("scope_2x"):
		equipped_mods.append("scope_2x")
	main_scene.call("_refresh_weapon_stats")
	assert((main_scene.get("equipped_weapon_mods") as Array).has("scope_2x"))
	var left_press := InputEventMouseButton.new()
	left_press.button_index = MOUSE_BUTTON_LEFT
	left_press.pressed = true
	main_scene.set("laser_aim_held", false)
	main_scene.set("melee_attack_cooldown", 0.0)
	main_scene.call("_input", left_press)
	assert(float(main_scene.get("melee_attack_cooldown")) > 0.0)
	assert(not bool(main_scene.get("mouse_fire_held")))
	main_scene.call("_finish_melee_attack")
	main_scene.set("laser_aim_held", true)
	main_scene.set("magazine_ammo", 30)
	main_scene.set("fire_cooldown", 0.0)
	main_scene.call("_input", left_press)
	assert(int(main_scene.get("magazine_ammo")) == 29)
	assert(bool(main_scene.get("mouse_fire_held")))
	var left_release := InputEventMouseButton.new()
	left_release.button_index = MOUSE_BUTTON_LEFT
	left_release.pressed = false
	main_scene.call("_input", left_release)
	assert(not bool(main_scene.get("mouse_fire_held")))
	main_scene.set("laser_aim_held", true)
	main_scene.set("magazine_ammo", 0)
	# 근접 폴백은 예비탄까지 없을 때만 나온다(예비탄이 있으면 재장전이 우선).
	main_scene.set("reserve_ammo", 0)
	main_scene.set("melee_attack_cooldown", 0.0)
	main_scene.call("_input", left_press)
	assert(float(main_scene.get("melee_attack_cooldown")) > 0.0)
	assert(not bool(main_scene.get("mouse_fire_held")))
	var bat_overlay := main_scene.get("melee_bat_overlay") as Sprite2D
	assert(bat_overlay.visible)
	assert(bat_overlay.scale.x < 0.05)
	var melee_fan := main_scene.get("melee_fan_indicator") as MeshInstance3D
	assert(melee_fan != null)
	assert(melee_fan.visible)
	assert(melee_fan.mesh.get_surface_count() == 2)
	assert((main_scene.get("survivor") as AnimatedSprite3D).animation.begins_with("melee_"))
	main_scene.call("_finish_melee_attack")
	main_scene.set("laser_aim_held", true)
	main_scene.set("locked_aim_direction", Vector3.RIGHT)
	main_scene.call("_update_scope_camera", 0.5)
	assert((main_scene.get("scope_camera_offset") as Vector3).length() > 4.0)
	assert((main_scene.get("camera") as Camera3D).size < 28.0)
	main_scene.set("laser_aim_held", false)
	main_scene.set("magazine_ammo", 30)
	main_scene.set("weapon_durability", 100.0)
	main_scene.set("fire_cooldown", 0.0)
	main_scene.call("_fire_ak47")
	assert(int(main_scene.get("magazine_ammo")) == 29)
	assert(float(main_scene.get("weapon_durability")) < 100.0)

	main_scene.set("weapon_spread_deg", float(base_ak["base_spread_deg"]))
	main_scene.call("_update_weapon_ballistics", 0.5, true)
	assert(float(main_scene.get("weapon_spread_deg")) > float(base_ak["base_spread_deg"]))

	main_scene.set("recoil_velocity", Vector3.ZERO)
	main_scene.set("loafing", false)
	main_scene.call("_apply_weapon_recoil", Vector3.RIGHT)
	var standing_recoil := (main_scene.get("recoil_velocity") as Vector3).length()
	main_scene.set("recoil_velocity", Vector3.ZERO)
	main_scene.set("loafing", true)
	main_scene.call("_apply_weapon_recoil", Vector3.RIGHT)
	var loaf_recoil := (main_scene.get("recoil_velocity") as Vector3).length()
	assert(loaf_recoil < standing_recoil)

	# 식빵 자세 중에는 장전이 금지된다 — 반동 검사에서 켠 loafing을 되돌린다.
	main_scene.set("loafing", false)
	main_scene.set("magazine_ammo", 0)
	main_scene.set("reserve_ammo", 30)
	main_scene.call("_reload_ak47")
	assert(main_scene.get("weapon_reloading"))
	main_scene.call("_update_weapon_ballistics", 3.0, false)
	assert(not main_scene.get("weapon_reloading"))
	assert(int(main_scene.get("magazine_ammo")) == 30)

	var bullet_script: Script = load("res://scripts/bullet_projectile.gd")
	var visual_bullet: Area3D = bullet_script.new()
	visual_bullet.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(visual_bullet)
	assert(visual_bullet.get_node_or_null("ProjectileGlow0") != null)
	assert(visual_bullet.get_node_or_null("ProjectileGlow2") != null)
	assert(visual_bullet.get_node_or_null("NeonTrail") is GPUParticles3D)
	visual_bullet.free()
	var bullet: Node = bullet_script.new()
	bullet.set("penetrations_remaining", 1)
	var first_target := DummyTarget.new()
	var second_target := DummyTarget.new()
	assert(bool(bullet.call("_apply_hit", first_target)))
	assert(not bool(bullet.call("_apply_hit", second_target)))
	assert(first_target.hits == 1 and second_target.hits == 1)
	first_target.free()
	second_target.free()
	bullet.free()
	main_scene.queue_free()
	await process_frame

	print("WEAPON_SYSTEM_OK weapons=%d mods=%d standing_recoil=%.3f loaf_recoil=%.3f" % [
		weapon_system.WEAPONS.size(),
		weapon_system.MODS.size(),
		standing_recoil,
		loaf_recoil,
	])
	quit(0)
