extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	if game_state.call("get_storage_grid_size") != Vector2i(6, 5):
		_fail("level 1 storage grid must be 5x6")
	if int(game_state.call("get_storage_capacity")) != 30:
		_fail("level 1 storage capacity must be 30 slots")
	if bool((game_state.call("deposit_storage_item", "weapon", "ak47", 1) as Dictionary).get("ok", false)):
		_fail("the actively equipped weapon must not be moved into storage")

	game_state.call("add_weapon", "mp5", 1)
	game_state.call("add_mod_component", "scope_lens", 2)
	var ammo_before := int(game_state.call("get_ammo_count", "762_fmj"))
	var ammo_result := game_state.call("deposit_storage_item", "ammo", "762_fmj", 30) as Dictionary
	if not bool(ammo_result.get("ok", false)):
		_fail("ammo could not be deposited")
	if int(game_state.call("get_ammo_count", "762_fmj")) != ammo_before - 30:
		_fail("deposit did not remove ammo from backpack")
	if not bool((game_state.call("deposit_storage_item", "weapon", "mp5", 1) as Dictionary).get("ok", false)):
		_fail("unequipped weapon could not be deposited")
	if not bool((game_state.call("deposit_storage_item", "component", "scope_lens", 2) as Dictionary).get("ok", false)):
		_fail("components could not be deposited")
	if int(game_state.call("get_storage_used_slots")) != 3:
		_fail("storage entries did not occupy the expected slots")

	var ammo_slot := -1
	for index in game_state.storage_inventory.size():
		var entry := game_state.storage_inventory[index] as Dictionary
		if str(entry.get("type", "")) == "ammo" and str(entry.get("id", "")) == "762_fmj":
			ammo_slot = index
			break
	if ammo_slot < 0:
		_fail("deposited ammo slot is missing")
	var withdraw_result := game_state.call("withdraw_storage_item", ammo_slot, 30) as Dictionary
	if not bool(withdraw_result.get("ok", false)):
		_fail("stored ammo could not be withdrawn")
	if int(game_state.call("get_ammo_count", "762_fmj")) != ammo_before:
		_fail("withdraw did not restore ammo to backpack")

	game_state.set("canned_food", 9)
	var food_result := game_state.call("deposit_storage_item", "food", "canned_food", 5) as Dictionary
	if not bool(food_result.get("ok", false)):
		_fail("canned food could not be deposited")
	if int(game_state.get("canned_food")) != 9:
		_fail("stored canned food must remain part of the shelter currency total")
	if int(game_state.call("get_backpack_storage_count", "food", "canned_food")) != 4:
		_fail("storage allocation must be excluded from carried canned food")
	if int(game_state.call("get_stored_storage_count", "food", "canned_food")) != 5:
		_fail("stored canned food allocation is missing")
	var food_slot := -1
	for index in game_state.storage_inventory.size():
		var entry := game_state.storage_inventory[index] as Dictionary
		if str(entry.get("type", "")) == "food":
			food_slot = index
			break
	if food_slot < 0:
		_fail("stored canned food slot is missing")
	if not bool((game_state.call("withdraw_storage_item", food_slot, 5) as Dictionary).get("ok", false)):
		_fail("stored canned food could not be withdrawn")
	if int(game_state.get("canned_food")) != 9:
		_fail("withdrawing canned food must not duplicate the currency total")

	game_state.set("scrap", 10_000)
	game_state.set("churu", 10)
	if not bool(game_state.call("try_upgrade_storage")):
		_fail("storage level 2 upgrade failed")
	if game_state.call("get_storage_grid_size") != Vector2i(7, 6):
		_fail("storage upgrade did not expand the grid")

	var storage := load("res://scenes/modules/shelter_storage_module.tscn").instantiate() as Node3D
	root.add_child(storage)
	await process_frame
	storage.call("interact")
	await process_frame
	var ui_layer := root.find_child("ShelterStorageUILayer", true, false) as CanvasLayer
	if ui_layer == null:
		_fail("storage interaction did not open its UI")
	var storage_grid := ui_layer.find_child("StorageGrid", true, false) as GridContainer
	if storage_grid == null or storage_grid.get_child_count() != 42:
		_fail("storage UI grid does not match upgraded capacity")
	var close := ui_layer.find_child("CloseButton", true, false) as Button
	if close == null or not close.text.is_empty():
		_fail("storage close control must be an icon-only button")
	var occupied_slot: Button
	for slot in storage_grid.get_children():
		var slot_button := slot as Button
		if slot_button != null and not slot_button.disabled:
			occupied_slot = slot_button
			break
	if occupied_slot == null:
		_fail("storage UI did not expose an occupied slot for withdrawal")
	occupied_slot.pressed.emit()
	await process_frame
	await process_frame
	var rebuilt_grid := ui_layer.find_child("StorageGrid", true, false) as GridContainer
	if rebuilt_grid == null or rebuilt_grid.get_child_count() != 42:
		_fail("storage UI did not rebuild safely after a slot signal")
	ui_layer.queue_free()

	var save_path := "res://.godot/shelter_storage_smoke.json"
	game_state.set("persistence_enabled", true)
	game_state.set("persistence_path", save_path)
	var saved_inventory: Array = (game_state.get("storage_inventory") as Array).duplicate(true)
	if not bool(game_state.call("save_persistent_state")):
		_fail("storage save failed")
	game_state.set("storage_level", 1)
	game_state.set("storage_inventory", [])
	if not bool(game_state.call("load_persistent_state")):
		_fail("storage load failed")
	if int(game_state.get("storage_level")) != 2 or game_state.get("storage_inventory") != saved_inventory:
		_fail("storage persistence did not restore level and contents")
	game_state.set("persistence_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("SHELTER_STORAGE_OK level=%d slots=%d used=%d" % [
		game_state.get("storage_level"),
		game_state.call("get_storage_capacity"),
		game_state.call("get_storage_used_slots"),
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
