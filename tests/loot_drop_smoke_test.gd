extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	assert(bool(main_scene.get("has_ak")))
	assert(main_scene.get("ak_pickup") == null)
	assert(bool(game_state.get("has_ak")))
	var initial_pickups := main_scene.get("ammo_pickups") as Array
	assert(initial_pickups.size() == 20)
	for pickup in initial_pickups:
		assert(str(pickup.get_meta("loot_type", "")) == "canned_food")
		assert(bool(pickup.get_meta("guaranteed_field_supply", false)))
	assert((main_scene.get("field_loot_containers") as Array).size() == 29)
	var opened_container := (main_scene.get("field_loot_containers") as Array)[0] as Node3D
	main_scene.call("_complete_field_interaction", opened_container)
	await process_frame
	assert(is_instance_valid(opened_container))
	assert(bool(opened_container.get_meta("opened", false)))
	assert(not opened_container.is_in_group("field_interaction"))
	assert(not (main_scene.get("field_loot_containers") as Array).has(opened_container))
	var opened_sprite := opened_container.get_node("ContainerSprite") as Sprite3D
	assert(opened_sprite.modulate.a < 0.7)
	assert(opened_container.get_node_or_null("ContainerTypeIcon") != null)
	var field_scrap_before := int(game_state.get("scrap"))

	var player := main_scene.get("player") as Node3D
	var food_before := int(game_state.get("canned_food"))
	var food_pickup: Node3D = main_scene.call(
		"_create_loot_pickup",
		"canned_food",
		player.global_position,
		{"amount": 2, "display_name": "통조림"}
	)
	main_scene.set("nearby_ammo_pickup", food_pickup)
	main_scene.call("_collect_nearby_ammo")
	assert(int(game_state.get("canned_food")) == food_before + 2)

	var mp5_before := int(game_state.call("get_weapon_count", "mp5"))
	var weapon_pickup: Node3D = main_scene.call(
		"_create_loot_pickup",
		"weapon",
		player.global_position,
		{"amount": 1, "weapon_id": "mp5", "display_name": "MP5"}
	)
	var weapon_sprite := weapon_pickup.get_node("LootSprite") as Sprite3D
	var weapon_long_edge := maxf(
		weapon_sprite.texture.get_width() * weapon_sprite.pixel_size,
		weapon_sprite.texture.get_height() * weapon_sprite.pixel_size
	)
	assert(weapon_long_edge <= 1.11)
	main_scene.set("nearby_ammo_pickup", weapon_pickup)
	main_scene.call("_collect_nearby_ammo")
	assert(int(game_state.call("get_weapon_count", "mp5")) == mp5_before + 1)
	assert(int(game_state.call("remove_raid_bag_item", "weapon", "mp5", 1)) == 1)

	var armor_before := int(game_state.call("get_equipment_count", "scav_vest"))
	var armor_pickup: Node3D = main_scene.call(
		"_create_loot_pickup",
		"armor",
		player.global_position,
		{"amount": 1, "equipment_id": "scav_vest", "display_name": "누더기 방탄 조끼"}
	)
	main_scene.set("nearby_ammo_pickup", armor_pickup)
	main_scene.call("_collect_nearby_ammo")
	assert(int(game_state.call("get_equipment_count", "scav_vest")) == armor_before + 1)
	var churu_before := int(game_state.get("churu"))
	var churu_pickup: Node3D = main_scene.call(
		"_create_loot_pickup",
		"churu",
		player.global_position,
		{"amount": 1, "display_name": "희귀 츄르"}
	)
	main_scene.set("nearby_ammo_pickup", churu_pickup)
	main_scene.call("_collect_nearby_ammo")
	assert(int(game_state.get("churu")) == churu_before + 1)

	var enemies := main_scene.get("enemies") as Array
	var pickup_count_before := (main_scene.get("ammo_pickups") as Array).size()
	var random_drop: Node3D = null
	for _attempt in 40:
		random_drop = main_scene.call("_spawn_enemy_loot", enemies[0])
		if is_instance_valid(random_drop):
			break
	assert(is_instance_valid(random_drop))
	assert((main_scene.get("ammo_pickups") as Array).size() == pickup_count_before + 1)
	assert(["ammo", "canned_food", "churu", "medkit", "mod_component", "weapon", "armor"].has(str(random_drop.get_meta("loot_type"))))

	var boss_pickup_count_before := (main_scene.get("ammo_pickups") as Array).size()
	enemies[0].set_meta("raid_boss", true)
	main_scene.call("_spawn_enemy_loot", enemies[0])
	enemies[0].set_meta("raid_boss", false)
	var boss_pickups := (main_scene.get("ammo_pickups") as Array).slice(boss_pickup_count_before)
	assert(boss_pickups.size() == 2)
	var boss_drop_types := boss_pickups.map(func(pickup: Node3D) -> String: return str(pickup.get_meta("loot_type")))
	assert(boss_drop_types.has("churu"))
	assert(boss_drop_types.has("mod_component"))
	assert(int(game_state.get("scrap")) == field_scrap_before, "Field pickups and enemy drops must never grant shelter scrap.")

	print("LOOT_DROP_OK start_weapon=ak47 food=%d mp5=%d random=%s" % [
		game_state.get("canned_food"),
		game_state.call("get_weapon_count", "mp5"),
		random_drop.get_meta("loot_type"),
	])
	quit(0)
