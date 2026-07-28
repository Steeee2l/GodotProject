extends Node

const INVENTORY_UI := preload("res://scripts/inventory_ui.gd")
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree_root := get_tree().root
	var state := tree_root.get_node_or_null("GameState")
	if state == null:
		state = load("res://scripts/game_state.gd").new()
		state.name = "GameState"
		tree_root.add_child(state)
	state.set("persistence_enabled", false)
	state.set("weapon_inventory", {"ak47": 1, "mp5": 1})
	state.set("equipped_weapon_id", "ak47")
	state.set("has_ak", true)
	state.set("magazine_ammo", 24)
	state.call("set_ammo_count", "762_fmj", 95)
	var ui := INVENTORY_UI.new()
	add_child(ui)
	ui.setup(FONT, null, null, {})
	ui.weapon_equipped.connect(func(weapon_id: String) -> void: state.call("equip_weapon", weapon_id))
	ui.weapon_unequipped.connect(func() -> void: state.call("unequip_weapon"))
	ui.update_state(true, 24, 95, "AK-47 \"캣라시니코프\"", 30, 100.0)
	ui.set_open(true)
	assert(ui.z_index >= 4000, "Inventory must render above the rest of the HUD.")
	assert(ui.inventory_panel.custom_minimum_size.x <= 560.0, "The default inventory panel must remain compact.")
	assert(not ui.weapon_panel.visible, "Weapon detail must stay hidden until the weapon is selected.")
	assert(ui.equipped_grid.get_child_count() == 4, "Primary, body, head, and footwear equipment slots should be visible.")
	assert(ui.bag_grid.get_child_count() == 15, "The bag must always render all 15 physical slots, including empty slots.")
	assert(ui.bag_slot_usage_label.text.ends_with("/ 15칸"), "The bag header must expose used slots against total capacity.")
	for equipment in ui.equipped_grid.get_children():
		assert(((equipment as Control).size_flags_horizontal & Control.SIZE_EXPAND) != 0, "Equipment slots must share the full panel width.")
		assert(not (equipment as Button).text.contains("하수구"), "Extraction objectives do not belong in equipment.")
		assert((equipment as Button).text.is_empty(), "Equipment slot labels must not overlap centered icons.")
	for empty_slot_name in ["몸 방어구", "머리 방어구", "신발"]:
		var empty_slot := ui.equipped_grid.get_node("Equipment_%s" % empty_slot_name) as Button
		assert(empty_slot != null, "Every empty equipment category needs a dedicated slot.")
		assert(empty_slot.icon == null, "Empty equipment slots must use text only.")
		assert(empty_slot.get_child_count() == 1 and (empty_slot.get_child(0) as Label).text == empty_slot_name, "Empty equipment slots must show their category name.")
	for bag_item in ui.bag_grid.get_children():
		assert(((bag_item as Control).size_flags_horizontal & Control.SIZE_EXPAND) != 0, "Bag slots must share the full panel width.")
		if bag_item is Button:
			assert((bag_item as Button).text.is_empty(), "Bag slots must show only an icon and quantity badge.")
			if str((bag_item as Button).name).begins_with("BagItem_"):
				assert((bag_item as Button).icon != null, "Every occupied bag slot must have an item icon.")

	ui._show_weapon_detail()
	assert(ui.weapon_panel.visible, "Selecting the equipped weapon must open its detail panel.")
	assert(ui.weapon_stats.text.contains("24 / 30"), "Weapon detail must show current rounds against magazine capacity.")
	assert(ui.weapon_stats.text.contains("완전 탄창 3개 + 낱탄 5발"), "Weapon detail must translate reserve rounds into magazines and loose rounds.")
	assert(ui.bag_grid.get_node_or_null("BagItem_ak47") == null, "The equipped weapon must not also appear as a bag copy.")
	assert(ui.bag_grid.get_node_or_null("BagItem_mp5") is Button, "Unequipped owned weapons must remain selectable in the bag.")
	assert(ui.weapon_panel.get_node_or_null("OwnedModList") == null, "Weapon details must not duplicate the bag attachment list.")
	await get_tree().process_frame
	var shell_minimum := ui.shell.get_combined_minimum_size()
	assert(ui.shell.get_combined_minimum_size().x <= 1040.0, "The expanded inventory must fit the 1280-wide game viewport: %s" % shell_minimum)
	assert(ui.shell.get_combined_minimum_size().y <= 640.0, "The inventory must fit the 720-high game viewport: %s" % shell_minimum)
	if ui.responsive_compact:
		assert(not ui.inventory_panel.visible and ui.weapon_panel.visible, "Compact layouts must show one panel at a time.")
	else:
		assert(
			ui.inventory_panel.get_global_rect().end.x <= ui.weapon_panel.get_global_rect().position.x,
			"Inventory and weapon detail panels must never overlap."
		)
	var equipped_mods: Array = state.get("equipped_weapon_mods")
	equipped_mods.clear()
	var components: Dictionary = state.get("mod_component_inventory")
	components["scope_lens"] = 1
	var finished_mods: Dictionary = state.get("weapon_mod_inventory")
	finished_mods["scope_2x"] = 1
	state.set("scrap", 0)
	ui._refresh_contents()
	var scope_card := ui.bag_grid.get_node("BagItem_scope_2x") as Button
	assert(scope_card != null, "Owned attachments must be represented in the bag grid.")
	scope_card.pressed.emit()
	assert(ui.item_detail_title.text.contains("스코프"), "Selecting a bag item must reveal its details outside the slot.")
	assert((state.get("equipped_weapon_mods") as Array).has("scope_2x"), "One click on an owned attachment must equip it while weapon details are open.")
	assert(int(state.call("get_weapon_mod_count", "scope_2x")) == 0, "Equipping must remove the finished attachment from the bag.")
	assert(int(state.call("get_mod_component_count", "scope_lens")) == 1, "Equipping must not consume raw crafting materials.")

	ui._unequip_mod("scope_2x")
	assert(not (state.get("equipped_weapon_mods") as Array).has("scope_2x"), "Clicking an equipped attachment must remove it.")
	assert(int(state.call("get_weapon_mod_count", "scope_2x")) == 1, "Unequipping must return the finished attachment to the bag.")
	ui._unequip_mod("scope_2x")
	assert(int(state.call("get_weapon_mod_count", "scope_2x")) == 1, "Repeated unequip events must not duplicate attachments.")

	state.call("add_equipment", "scav_vest", 1)
	ui._refresh_contents()
	var armor_card := ui.bag_grid.get_node("BagItem_scav_vest") as Button
	assert(armor_card != null, "Looted armor must appear in the bag as an equippable item.")
	armor_card.pressed.emit()
	assert(ui.item_detail_description.text.contains("피해 감소 12%"), "Armor details must show the applied damage reduction stat.")
	ui.item_action_button.pressed.emit()
	assert(str(state.get("equipped_body_armor_id")) == "scav_vest", "The armor action must equip the selected body armor.")
	assert(int(state.call("get_equipment_count", "scav_vest")) == 0, "Equipped armor must leave the bag inventory.")
	ui._select_equipped_equipment("body")
	ui.item_action_button.pressed.emit()
	assert(str(state.get("equipped_body_armor_id")).is_empty(), "The equipped armor slot must support unequip.")
	assert(int(state.call("get_equipment_count", "scav_vest")) == 1, "Unequipped armor must return to the bag.")

	state.call("add_equipment", "patched_sneakers", 1)
	ui._refresh_contents()
	var footwear_card := ui.bag_grid.get_node("BagItem_patched_sneakers") as Button
	assert(footwear_card != null, "Looted footwear must appear in the bag.")
	footwear_card.pressed.emit()
	assert(ui.item_detail_description.text.contains("이동 속도 +6%"), "Footwear details must show movement speed.")
	assert(ui.item_detail_description.text.contains("대시 스태미나 소모 -8%"), "Footwear details must show stamina cost reduction.")
	ui.item_action_button.pressed.emit()
	assert(str(state.get("equipped_footwear_id")) == "patched_sneakers", "Footwear must equip into the feet slot.")
	assert(is_equal_approx(float(state.call("get_move_speed_multiplier")), 1.06), "Equipped lightweight footwear must increase movement speed.")
	assert(is_equal_approx(float(state.call("get_stamina_cost_multiplier")), 0.92), "Equipped lightweight footwear must reduce dash stamina cost.")

	ui._hide_weapon_detail()
	ui._refresh_contents()
	var mp5_card := ui.bag_grid.get_node("BagItem_mp5") as Button
	mp5_card.pressed.emit()
	assert(ui.item_action_button.text == "장착", "A stored weapon must present one clear equip action.")
	ui.item_action_button.pressed.emit()
	assert(str(state.get("equipped_weapon_id")) == "mp5" and bool(state.get("has_ak")), "Equipping a bag weapon must replace the active weapon.")
	ui.update_state(true, 0, int(state.call("get_ammo_count", "9mm_fmj")), "MP5", 30, 100.0)
	ui._show_weapon_detail()
	assert(ui.weapon_state_action_button.visible, "The equipped weapon detail must expose an unequip action.")
	ui.weapon_state_action_button.pressed.emit()
	assert(not bool(state.get("has_ak")), "Unequipping must move the active weapon back into storage state.")
	ui.update_state(false, 0, int(state.call("get_ammo_count", "9mm_fmj")), "MP5", 30, 100.0)
	ui._refresh_contents()
	assert(ui.bag_grid.get_node_or_null("BagItem_mp5") is Button, "An unequipped weapon must reappear in the bag.")

	print("INVENTORY_UI_SMOKE: PASS")
	get_tree().quit()
