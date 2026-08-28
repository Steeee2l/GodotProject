extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("scrap", 2_000_000)
	game_state.set("canned_food", 200)
	# 훈련 비용은 고철이 아니라 쉘터 통조림 재고다(유저 확정: "훈련은 통조림").
	game_state.set("shelter_canned_food", 500)
	game_state.set("churu", 99)
	var base_health := int(game_state.call("get_max_health"))
	var xp_result := game_state.call("add_raid_experience", game_state.call("get_raid_experience_reward", 4, 0)) as Dictionary
	if int(xp_result.get("levels_gained", 0)) != 1 or int(game_state.get("pending_level_choices")) != 1:
		_fail("raid experience did not create a level reward choice")
	if not bool(game_state.call("apply_level_reward", "max_health")):
		_fail("level reward could not be applied")
	if int(game_state.call("get_max_health")) != base_health + 8:
		_fail("maximum health level reward was not reflected")
	if not bool((game_state.call("try_upgrade_training", "vitality") as Dictionary).get("ok", false)):
		_fail("vitality training rank 1 could not be purchased")
	if not bool((game_state.call("try_upgrade_training", "vitality") as Dictionary).get("ok", false)):
		_fail("vitality training rank 2 could not be purchased")
	if not bool((game_state.call("try_upgrade_training", "recovery") as Dictionary).get("ok", false)):
		_fail("recovery training prerequisite did not unlock")

	var initial_level := int(game_state.call("get_weapon_enhancement_level", "ak47"))
	if not bool(game_state.call("try_enhance_weapon", "ak47")):
		_fail("weapon enhancement could not be purchased")
	if int(game_state.call("get_weapon_enhancement_level", "ak47")) != initial_level + 1:
		_fail("weapon enhancement level did not persist in state")
	var equipped_mods: Array[String] = ["scope_2x"]
	game_state.set("equipped_weapon_mods", equipped_mods)
	if not bool(game_state.call("try_enhance_mod", "scope_2x")):
		_fail("equipped attachment enhancement could not be purchased")
	if int(game_state.call("get_mod_enhancement_level", "scope_2x")) != 1:
		_fail("attachment enhancement level did not persist in state")

	# 장인 뽑기(roll_artisan_weapon)는 2026-08 경제 코어로 폐지됐다 — 장인 = 돌파 서비스.
	# 대신 돌파 게이트를 확인한다: +10에서 강화가 막히고 try_breakthrough로 열린다.
	(game_state.get("weapon_enhancement_levels") as Dictionary)["ak47"] = 10
	if bool(game_state.call("try_enhance_weapon", "ak47")):
		_fail("+10 weapon must require a breakthrough before enhancing")
	game_state.call("add_progression_item", "artisan_seal", 1)
	# 대개편 3단계: +10 돌파 정밀 기어 (L/10)×2 = 2개.
	game_state.call("add_mod_component", "precision_gear", 2)
	if not bool(game_state.call("try_breakthrough", "weapon", "ak47")):
		_fail("breakthrough with seal + gear + scrap must succeed")
	if not bool(game_state.call("try_enhance_weapon", "ak47")):
		_fail("enhancement must reopen after breakthrough")
	if game_state.has_method("roll_artisan_weapon"):
		_fail("artisan weapon roll must be removed")

	if bool(game_state.call("is_raid_zone_unlocked", "namsan_core")):
		_fail("tier 5 zone should be locked at tier 1")
	game_state.set("shelter_tier", 5)
	if bool(game_state.call("is_raid_zone_unlocked", "namsan_core")):
		_fail("sealed zone should remain locked without its keycard")
	game_state.call("add_progression_item", "sealed_zone_keycard", 1)
	if not bool(game_state.call("is_raid_zone_unlocked", "namsan_core")):
		_fail("tier 5 zone did not unlock with its keycard")
	if not bool(game_state.call("select_raid_zone", "namsan_core")):
		_fail("unlocked raid zone could not be selected")

	var shelter := load("res://scenes/shelter_interior.tscn").instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame
	var module_root := shelter.get_node_or_null("StageOneModules")
	if module_root == null:
		_fail("shelter module root is missing")
	if module_root.get_node_or_null("SurvivalTrainingFacility") == null:
		_fail("shelter training facility module is missing")
	var training := module_root.get_node("SurvivalTrainingFacility") as Node
	training.call("interact")
	await process_frame
	await process_frame
	var training_layer := root.find_child("TrainingFacilityUILayer", true, false) as CanvasLayer
	var training_close := training_layer.find_child("CloseButton", true, false) as Button
	if training_close == null or not training_close.text.is_empty() or training_close.custom_minimum_size.x > 44.0:
		_fail("training facility close control is not a compact icon button")
	var training_hint := training_layer.find_child("TrainingSectionHint", true, false) as Label
	if (
		training_hint == null
		or training_hint.autowrap_mode != TextServer.AUTOWRAP_OFF
		or training_hint.size.x < 145.0
		or training_hint.size.y > 40.0
	):
		_fail("training section hint collapsed into a vertical text column")
	var training_scroll := training_layer.find_child("TrainingTreeScroll", true, false) as ScrollContainer
	var training_tree := training_layer.find_child("TrainingTreeGrid", true, false) as GridContainer
	if training_scroll == null or training_scroll.size.y < 240.0:
		_fail("training card viewport has insufficient height")
	# 탄약 운용 4종 + 가방 확장(인벤토리에서 이사, 2026-08-28)이 더해져 10장이다.
	if training_tree == null or training_tree.get_child_count() != 10:
		_fail("training tree must show all ten upgrade cards")
	for node_id in [
		"vitality", "recovery", "endurance", "agility", "fieldcraft",
		"magazine_drill", "quick_hands", "ammo_carry", "sortie_supply",
	]:
		var training_card := training_layer.find_child("TrainingCard_%s" % node_id, true, false) as Button
		var training_description := training_layer.find_child(
			"TrainingCardDescription_%s" % node_id,
			true,
			false
		) as Label
		if (
			training_card == null
			or training_card.size.x < 300.0
			or training_card.size.y < 110.0
			or training_description == null
			or training_description.size.x < 180.0
		):
			_fail("training upgrade card layout collapsed for %s" % node_id)
	training_layer.queue_free()
	await process_frame
	shelter.call("_open_raid_zone_select")
	await process_frame
	var raid_layer := root.find_child("RaidZoneSelectLayer", true, false) as CanvasLayer
	var raid_close := raid_layer.find_child("CloseButton", true, false) as Button
	if raid_close == null or not raid_close.text.is_empty() or raid_close.custom_minimum_size.x > 44.0:
		_fail("raid zone close control is not a compact icon button")
	shelter.call("_close_raid_zone_select")
	await process_frame
	# 침대는 폐지됐다(복귀 자체가 완전 회복) — shelter_economy 테스트와 같은 기대값.
	# 예전 "정확히 1개" 어서션은 스테일이라 HEAD에서 이 테스트가 깨져 있었다.
	var player_bed_count := 0
	for child in module_root.get_children():
		if child.name == "PlayerBed":
			player_bed_count += 1
	if player_bed_count != 0:
		_fail("the obsolete player bed is still present in the shelter")

	var test_save_path := "res://.godot/shelter_progression_smoke.json"
	game_state.set("persistence_enabled", true)
	game_state.set("persistence_path", test_save_path)
	game_state.set("scrap", 123456)
	game_state.set("catnip", 78)
	var saved_player_level := int(game_state.get("player_level"))
	var saved_training_levels := (game_state.get("training_levels") as Dictionary).duplicate(true)
	if not bool(game_state.call("save_persistent_state")):
		_fail("persistent shelter save could not be written")
	game_state.set("scrap", 1)
	game_state.set("catnip", 0)
	game_state.set("player_level", 1)
	game_state.set("training_levels", {})
	if not bool(game_state.call("load_persistent_state")):
		_fail("persistent shelter save could not be loaded")
	if int(game_state.get("scrap")) != 123456 or int(game_state.get("catnip")) != 78:
		_fail("persistent shelter save did not restore resource values")
	if int(game_state.get("player_level")) != saved_player_level or game_state.get("training_levels") != saved_training_levels:
		_fail("persistent progression save did not restore player and training levels")
	game_state.set("persistence_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	print("SHELTER_PROGRESSION_OK level=%d zone=%s player_beds=%d" % [
		game_state.call("get_weapon_enhancement_level", "ak47"),
		game_state.get("selected_raid_zone"),
		player_bed_count,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
