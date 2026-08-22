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
	assert(bool(game_state.get("has_ak")))
	var initial_pickups := main_scene.get("loot_system").ammo_pickups as Array
	# 첫 판 온보딩 전리품 뭉치가 섞여 있을 수 있다. 이 테스트가 검증하려는 것은
	# "보장 통조림 보급"이므로 그 집합만 골라 센다. 21개였던 것이 12개로 줄었다 —
	# 쉘터 연료 싱크가 사라져(통조림 = 플레이어 소모품) 확정 픽업을 약 60%로 낮췄다.
	var guaranteed_pickups: Array = []
	for pickup in initial_pickups:
		if bool(pickup.get_meta("guaranteed_field_supply", false)):
			guaranteed_pickups.append(pickup)
	assert(guaranteed_pickups.size() == 12)
	for pickup in guaranteed_pickups:
		assert(str(pickup.get_meta("loot_type", "")) == "canned_food")
	# 1단계 컨테이너 36개 = 기존 29 + 생활권 7 (원자재 컨테이너는 v12에서 폐지).
	assert((main_scene.get("field_loot_containers") as Array).size() == 36)
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

	# 빈 몸통 슬롯에 방탄 조끼를 주우면, 파밍 손맛을 위해 그 자리에서 장착된다.
	# 가방에 쌓이는 대신 바로 몸에 걸쳐지므로 소유 수(가방+착용)로 확인한다.
	var owned_scav_before := (
		int(game_state.call("get_equipment_count", "scav_vest"))
		+ (1 if str(game_state.get("equipped_body_armor_id")) == "scav_vest" else 0)
	)
	var armor_pickup: Node3D = main_scene.call(
		"_create_loot_pickup",
		"armor",
		player.global_position,
		{"amount": 1, "equipment_id": "scav_vest", "display_name": "누더기 방탄 조끼"}
	)
	main_scene.set("nearby_ammo_pickup", armor_pickup)
	main_scene.call("_collect_nearby_ammo")
	assert(str(game_state.get("equipped_body_armor_id")) == "scav_vest")
	var owned_scav_after := (
		int(game_state.call("get_equipment_count", "scav_vest"))
		+ (1 if str(game_state.get("equipped_body_armor_id")) == "scav_vest" else 0)
	)
	assert(owned_scav_after == owned_scav_before + 1)
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
	var pickup_count_before := (main_scene.get("loot_system").ammo_pickups as Array).size()
	var random_drop: Node3D = null
	for _attempt in 40:
		random_drop = main_scene.call("_spawn_enemy_loot", enemies[0])
		if is_instance_valid(random_drop):
			break
	assert(is_instance_valid(random_drop))
	# 호환탄 회수(45%)가 본 드랍과 별개로 얹힐 수 있어 정확히 +1이 아니다.
	assert((main_scene.get("loot_system").ammo_pickups as Array).size() >= pickup_count_before + 1)
	# 2026-08 경제 코어: 장비(weapon/armor)는 적 드랍에서 절대 안 나온다 — 목록에서 뺐다.
	# 설계도 조각(progression_item)이 새로 들어온다.
	assert(["ammo", "canned_food", "churu", "medkit", "mod_component", "progression_item"].has(str(random_drop.get_meta("loot_type"))))

	var boss_pickup_count_before := (main_scene.get("loot_system").ammo_pickups as Array).size()
	enemies[0].set_meta("raid_boss", true)
	main_scene.call("_spawn_enemy_loot", enemies[0])
	enemies[0].set_meta("raid_boss", false)
	var boss_pickups := (main_scene.get("loot_system").ammo_pickups as Array).slice(boss_pickup_count_before)
	# 츄르 + 부품 + 확정 호환탄 번들 + 설계도 조각(2) + 군용 합금 + 장인의 인장 = 6.
	# (2026-08 경제 코어: 보스는 장비 대신 조각 2·군용 합금 1~2·인장 1을 확정으로 남긴다.
	#  방어구는 필드에서 절대 안 나온다 — 작업대 제작 전용.)
	assert(boss_pickups.size() == 6, "boss pickups = 6 (got %d)" % boss_pickups.size())
	var boss_drop_types := boss_pickups.map(func(pickup: Node3D) -> String: return str(pickup.get_meta("loot_type")))
	assert(boss_drop_types.has("churu"))
	assert(boss_drop_types.has("mod_component"))
	assert(boss_drop_types.has("ammo"), "보스는 장착 구경 탄약을 확정으로 남겨야 한다")
	assert(not boss_drop_types.has("armor") and not boss_drop_types.has("weapon"), "보스도 장비는 떨구지 않는다")
	var boss_shard_seen := false
	var boss_seal_seen := false
	var boss_alloy_seen := false
	for pickup in boss_pickups:
		if str(pickup.get_meta("loot_type")) == "progression_item":
			var progression_id := str(pickup.get_meta("progression_item_id", ""))
			if progression_id.begins_with("blueprint_shard_"):
				boss_shard_seen = true
				assert(int(pickup.get_meta("amount", 0)) == 2, "보스 조각은 2개 번들")
			elif progression_id == "artisan_seal":
				boss_seal_seen = true
		elif str(pickup.get_meta("loot_type")) == "mod_component" and str(pickup.get_meta("component_id", "")) == "military_alloy":
			boss_alloy_seen = true
	assert(boss_shard_seen and boss_seal_seen and boss_alloy_seen, "보스 확정: 조각·인장·군용 합금")
	assert(int(game_state.get("scrap")) == field_scrap_before, "Field pickups and enemy drops must never grant shelter scrap.")

	print("LOOT_DROP_OK start_weapon=ak47 food=%d mp5=%d random=%s" % [
		game_state.get("canned_food"),
		game_state.call("get_weapon_count", "mp5"),
		random_drop.get_meta("loot_type"),
	])
	quit(0)
