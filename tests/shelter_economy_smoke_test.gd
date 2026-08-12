extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("scrap", 500)
	game_state.set("canned_food", 20)
	game_state.set("rescued_workers", 4)
	game_state.call("_ensure_resident_records")
	var resident_ids := game_state.get("resident_cat_ids") as Array
	var resident_names: Array[String] = []
	for resident_id_value in resident_ids:
		var resident_id := str(resident_id_value)
		var resident_record := game_state.call("get_resident_trait", resident_id) as Dictionary
		var display_name := str(resident_record.get("display_name", ""))
		if display_name.is_empty() or display_name.begins_with("resident_"):
			_fail("resident display name was not generated")
		if resident_names.has(display_name):
			_fail("resident display names must be unique")
		resident_names.append(display_name)
		if int(resident_record.get("portrait_index", -1)) < 0:
			_fail("resident portrait variant was not generated")
	for resident_index in range(3):
		game_state.call("assign_worker_to_scratcher", resident_ids[resident_index])
	game_state.call("assign_worker_to_catnip", resident_ids[3])
	game_state.set("weapon_durability", 42.0)
	game_state.set("shelter_last_progress_time", int(Time.get_unix_time_from_system()) - 7200)
	game_state.set("workbench_repair_active", true)
	# 생산은 원자재(가동 연료)를 태워야 돈다 — 출정과 쉘터를 묶는 관문.
	game_state.set("raw_scrap", 100_000)
	game_state.set("raw_catnip", 100_000)
	var shelter := load("res://scenes/shelter_interior.tscn").instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame
	var stats := shelter.get("stats_label") as Label
	if stats == null:
		_fail("shelter resource stats label is missing")
	var inventory_button := shelter.find_child("InventoryButton", true, false) as Button
	if inventory_button == null or inventory_button.icon == null:
		_fail("shelter inventory button is missing or has no backpack icon")
	var currency_labels := shelter.get("shelter_currency_labels") as Dictionary
	for resource_data in [
		["scrap", "고철"],
		["catnip", "캣닢"],
		["food", "통조림"],
		["churu", "츄르"],
	]:
		var resource_id := str(resource_data[0])
		var resource_name := str(resource_data[1])
		if not currency_labels.has(resource_id):
			_fail("shelter resource value is missing for %s" % resource_name)
			return
		# 재화 칩 라벨은 압축 숫자만 담는다. 이름은 아이콘·툴팁이 맡는다.
		var resource_label := currency_labels[resource_id] as Label
		if resource_label == null or resource_label.text.strip_edges().is_empty():
			_fail("shelter resource value is unreadable for %s" % resource_name)
			return
		var resource_icon := shelter.find_child("%sIcon" % resource_name, true, false) as TextureRect
		if resource_icon == null or resource_icon.texture == null:
			_fail("shelter resource icon is missing for %s" % resource_name)
			return
	var resident_nodes := get_nodes_in_group("shelter_resident")
	if resident_nodes.size() != 4:
		_fail("rescued residents were not instantiated in the shelter")
	if shelter.find_child("PlayerBed", true, false) == null:
		_fail("the single player bed is missing")
	if shelter.find_children("BedModule*", "Node3D", true, false).size() > 0:
		_fail("obsolete resident beds are still present")
	# 바닥 슬롯 플레이트(장식)는 제거됐다. 워커는 _scratcher/_catnip_work_position
	# 좌표로 직접 이동하므로, 슬롯 수는 좌표 함수가 유효한지로만 확인한다.
	if int(game_state.call("get_scratcher_worker_slots")) <= 0:
		_fail("scratcher worker slots collapsed to zero")
	if int(game_state.call("get_catnip_worker_slots")) <= 0:
		_fail("catnip worker slots collapsed to zero")
	var working_residents := 0
	var worker_scrap_rate_total := 0.0
	for resident in resident_nodes:
		if bool(resident.get_meta("assigned_to_scratcher", false)):
			working_residents += 1
			var working_resident_id := str(resident.get_meta("resident_id", ""))
			worker_scrap_rate_total += float(
				game_state.call(
					"get_worker_production_per_second",
					working_resident_id,
					"kneading"
				)
			)
			var resident_sprite := resident.get_node_or_null("ResidentSprite") as AnimatedSprite3D
			if resident_sprite == null or resident_sprite.animation != "kneading_ne":
				_fail("assigned scratcher worker is not playing the kneading animation")
			if resident_sprite.sprite_frames.get_frame_count("kneading_ne") != 6:
				_fail("kneading animation does not contain all six supplied frames")
			var work_indicator := resident.get_node_or_null("WorkIndicator") as Label3D
			if (
				work_indicator == null
				or not work_indicator.text.contains("고철")
				or not work_indicator.text.contains("/s")
			):
				_fail("scratcher worker does not display its live production rate")
	if working_residents != int(game_state.call("get_active_scratcher_workers")):
		_fail("visible scratcher workers do not match assigned worker data")
	if not is_equal_approx(
		worker_scrap_rate_total,
		float(game_state.call("get_scrap_per_second"))
	):
		_fail("per-worker scrap feedback does not add up to the real production rate")
	var catnip_workers := 0
	var worker_catnip_rate_total := 0.0
	for resident in resident_nodes:
		if str(resident.get_meta("assignment_kind", "")) == "catnip":
			catnip_workers += 1
			var catnip_resident_id := str(resident.get_meta("resident_id", ""))
			var resident_catnip_rate := float(game_state.call(
				"get_worker_production_per_second",
				catnip_resident_id,
				"catnip"
			))
			worker_catnip_rate_total += resident_catnip_rate
			if (
				resident_catnip_rate < 1.0
				or not is_equal_approx(resident_catnip_rate, roundf(resident_catnip_rate))
			):
				_fail("catnip workers must produce whole units at a minimum rate of one per second")
			var work_indicator := resident.get_node_or_null("WorkIndicator") as Label3D
			if (
				work_indicator == null
				or not work_indicator.text.contains("캣닢")
				or not work_indicator.text.contains("/s")
			):
				_fail("catnip worker does not display its live production rate")
			resident.call("emit_production_feedback_now")
			var production_gain := resident.find_child(
				"ProductionGain",
				false,
				false
			) as Label3D
			if production_gain == null:
				_fail("catnip worker did not emit a floating production number")
			elif (
				production_gain.font_size < 40
				or float(production_gain.get_meta("rise_height", 0.0)) < 1.0
				or production_gain.text.contains(".")
			):
				_fail("floating production number must be large, animated, and integer-only")
			else:
				var initial_gain_y := production_gain.position.y
				await create_timer(0.2).timeout
				if (
					not is_instance_valid(production_gain)
					or production_gain.position.y <= initial_gain_y + 0.05
					or production_gain.scale.x <= 0.8
				):
					_fail("floating production number does not pop and rise")
	if catnip_workers != 1 or int(game_state.call("get_active_catnip_workers")) != 1:
		_fail("visible catnip worker does not match assigned worker data")
	if not is_equal_approx(
		worker_catnip_rate_total,
		float(game_state.call("get_catnip_per_second"))
	):
		_fail("per-worker catnip feedback does not add up to the real production rate")

	if int(game_state.get("scrap")) <= 500:
		_fail("scratcher bank did not produce offline scrap")
	if float(game_state.get("weapon_durability")) <= 42.0:
		_fail("workbench did not repair weapon offline")
	if float(game_state.get("catnip")) <= 0.0:
		_fail("catnip scraper did not produce offline catnip")
	var live_scrap_before := int(game_state.get("scrap"))
	game_state.call("tick_shelter_live", 60.0)
	if int(game_state.get("scrap")) <= live_scrap_before:
		_fail("live shelter worker tick did not add scrap")
	# 통조림이 떨어지면 생산 라인이 멈춘다("생산 중단 · 통조림 필요").
	game_state.set("canned_food", 0)
	game_state.set("shelter_food_fraction", 0.0)
	var unfed_scrap_before := int(game_state.get("scrap"))
	game_state.call("tick_shelter_live", 3600.0)
	if int(game_state.get("scrap")) > unfed_scrap_before + 1:
		_fail("shelter workers must stop producing without canned food")
	game_state.set("canned_food", 20)

	var workbench := get_nodes_in_group("shelter_workbench")[0] as Node
	workbench.call("interact")
	await process_frame
	var workbench_layer := root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	if workbench_layer == null:
		_fail("workbench did not create an interaction layer")
	_assert_compact_close_button(workbench_layer, "workbench")
	var workbench_panel := workbench_layer.find_child("WorkbenchPanel", true, false) as PanelContainer
	var workbench_body := workbench_layer.find_child("WorkbenchBody", true, false) as BoxContainer
	var workbench_recipe_panel := workbench_layer.find_child("WorkbenchRecipePanel", true, false) as PanelContainer
	var workbench_detail_scroll := workbench_layer.find_child("WorkbenchDetailScroll", true, false) as ScrollContainer
	if (
		workbench_panel == null
		or workbench_body == null
		or workbench_recipe_panel == null
		or workbench_detail_scroll == null
	):
		_fail("workbench responsive panel structure is missing")
	var workbench_resource_strip := workbench_layer.find_child("WorkbenchResourceStrip", true, false) as HFlowContainer
	if workbench_resource_strip == null:
		_fail("workbench icon resource strip is missing")
	for resource_id in ["scrap", "canned_food", "scope_lens", "rubber_gasket", "magazine_spring"]:
		_assert_resource_icon(workbench_resource_strip, str(resource_id), "workbench")
	var workbench_viewport_size := workbench.get_viewport().get_visible_rect().size
	if (
		workbench_panel.size.x > workbench_viewport_size.x
		or workbench_panel.size.y > workbench_viewport_size.y
		or workbench_recipe_panel.size.x < 260.0
	):
		_fail("workbench panel exceeds or collapses inside the viewport")
	workbench.set("selected_category", "ammo")
	workbench.set("selected_recipe_id", "762_fmj_pack")
	workbench.call("_rebuild_ui")
	await process_frame
	var ammo_title := workbench_layer.find_child("WorkbenchRecipeTitle", true, false) as Label
	var ammo_tab := workbench_layer.find_child("WorkbenchTab_ammo", true, false) as Button
	var ammo_detail_scroll := workbench_layer.find_child("WorkbenchDetailScroll", true, false) as ScrollContainer
	if (
		ammo_title == null
		or ammo_title.autowrap_mode != TextServer.AUTOWRAP_OFF
		or ammo_tab == null
		or not ammo_tab.button_pressed
		or ammo_detail_scroll == null
		or ammo_detail_scroll.size.y < 120.0
	):
		_fail("ammo selection breaks the workbench detail layout")
	if (
		_find_button_with_text(workbench_layer, "시간제 수리") != null
		or _find_button_with_text(workbench_layer, "업그레이드") != null
	):
		_fail("workbench header still contains ambiguous icon actions")
	var supply_recipes := workbench.call("_recipes_for_category", "supplies") as Array
	var supply_recipe_ids: Array[String] = []
	var auto_repair_recipe: Dictionary
	for recipe_value in supply_recipes:
		var supply_recipe := recipe_value as Dictionary
		var supply_recipe_id := str(supply_recipe.get("id", ""))
		supply_recipe_ids.append(supply_recipe_id)
		if supply_recipe_id == "auto_repair":
			auto_repair_recipe = supply_recipe
	if not supply_recipe_ids.has("auto_repair") or not supply_recipe_ids.has("workbench_upgrade"):
		_fail("workbench maintenance actions are missing from the supplies category")
	game_state.set("workbench_repair_active", false)
	game_state.set("weapon_durability", 50.0)
	workbench.call("_craft", auto_repair_recipe)
	if not bool(game_state.get("workbench_repair_active")):
		_fail("workbench automatic repair action did not start")
	var workbench_resource_row := workbench_layer.find_child("ResourceCost_scrap", true, false) as HBoxContainer
	if workbench_resource_row == null:
		_fail("workbench resource cost row is missing")
	var workbench_resource_name := workbench_resource_row.get_node_or_null("ResourceName") as Label
	var workbench_resource_amount := workbench_resource_row.get_node_or_null("ResourceAmount") as Label
	if (
		workbench_resource_name == null
		or workbench_resource_amount == null
		or workbench_resource_name.autowrap_mode != TextServer.AUTOWRAP_OFF
		or workbench_resource_amount.autowrap_mode != TextServer.AUTOWRAP_OFF
		or workbench_resource_amount.custom_minimum_size.x < 100.0
	):
		_fail("workbench resource costs can collapse into vertical text")
	workbench_layer.queue_free()
	await process_frame

	var training_module := get_nodes_in_group("training_facility")[0] as Node
	training_module.call("interact")
	await process_frame
	var training_panel := root.find_child("TrainingPanel", true, false) as PanelContainer
	var training_resource := root.find_child("TrainingResourceLabel", true, false) as Label
	var training_scroll := root.find_child("TrainingTreeScroll", true, false) as ScrollContainer
	if training_panel == null or training_resource == null or training_scroll == null:
		_fail("training facility responsive panel structure is missing")
	_assert_resource_icon(training_panel, "food", "training facility")
	_assert_compact_close_button(training_panel, "training facility")
	if training_resource.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_fail("training facility resource count can collapse into vertical text")
	var training_viewport_size := training_module.get_viewport().get_visible_rect().size
	if training_panel.size.x > training_viewport_size.x or training_panel.size.y > training_viewport_size.y:
		_fail("training facility panel exceeds the viewport")
	var training_cards := training_panel.find_children("TrainingCard_*", "Button", true, false)
	if training_cards.size() < 5:
		_fail("training facility must expose all five permanent upgrade cards")
	var training_layer := training_module.get("ui_layer") as CanvasLayer
	if is_instance_valid(training_layer):
		training_layer.queue_free()
	await process_frame

	var bank := get_nodes_in_group("scratcher_bank")[0] as Node
	bank.call("interact")
	await process_frame
	var bank_panel := root.find_child("ScratcherBankPanel", true, false) as Control
	var bank_body := root.find_child("ScratcherBankBody", true, false) as BoxContainer
	if bank_panel == null or bank_body == null:
		_fail("scratcher bank responsive panel structure is missing")
	_assert_resource_icon(bank_panel, "scrap", "scratcher bank")
	_assert_resource_icon(bank_panel, "catnip", "scratcher bank")
	var bank_summary := bank_panel.find_child("ScratcherBankSummary", true, false) as GridContainer
	if bank_summary == null or bank_summary.get_child_count() != 3:
		_fail("scratcher bank summary must contain only three decision-critical values")
	if _find_label_with_text(bank_panel, "보유 자원") != null:
		_fail("scratcher bank still duplicates its wallet as a text block")
	_assert_compact_close_button(bank_panel, "scratcher bank")
	if _find_button_with_text(bank_panel, "진행 정산") != null:
		_fail("scratcher bank still exposes the redundant settlement action")
	_assert_resident_card(
		bank_panel.find_child("ResidentCard_%s" % str(resident_ids[0]), true, false) as Button,
		str(resident_ids[0]),
		str((game_state.call("get_resident_trait", str(resident_ids[0])) as Dictionary).get("display_name", ""))
	)
	var bank_viewport_size := bank.get_viewport().get_visible_rect().size
	if bank_panel.size.x > bank_viewport_size.x or bank_panel.size.y > bank_viewport_size.y:
		_fail("scratcher bank panel exceeds the viewport: panel=%s viewport=%s" % [bank_panel.size, bank_viewport_size])
	var assigned_ids := game_state.get("assigned_worker_ids") as Array
	if assigned_ids.is_empty():
		_fail("worker assignment data was unexpectedly empty")
	var toggled_resident_id := str(assigned_ids[0])
	bank.call("_toggle_worker", toggled_resident_id)
	await physics_frame
	var toggled_resident: Node
	for resident in resident_nodes:
		if str(resident.get_meta("resident_id", "")) == toggled_resident_id:
			toggled_resident = resident
			break
	if toggled_resident == null or bool(toggled_resident.get_meta("assigned_to_scratcher", true)):
		_fail("resident did not leave the scratcher after unassignment")
	var bank_layer := bank.get("ui_layer") as CanvasLayer
	if is_instance_valid(bank_layer):
		bank_layer.queue_free()
	await process_frame
	var catnip_module := get_nodes_in_group("catnip_scraper")[0] as Node
	catnip_module.call("interact")
	await process_frame
	var catnip_panel := root.find_child("CatnipScraperPanel", true, false) as Control
	var catnip_body := root.find_child("CatnipScraperBody", true, false) as BoxContainer
	if catnip_panel == null or catnip_body == null:
		_fail("catnip scraper responsive panel structure is missing")
	_assert_resource_icon(catnip_panel, "catnip", "catnip scraper")
	_assert_resource_icon(catnip_panel, "scrap", "catnip scraper")
	var catnip_summary := catnip_panel.find_child("CatnipScraperSummary", true, false) as GridContainer
	if catnip_summary == null or catnip_summary.get_child_count() != 2:
		_fail("catnip scraper summary must contain only production and worker values")
	_assert_compact_close_button(catnip_panel, "catnip scraper")
	if _find_button_with_text(catnip_panel, "진행 정산") != null:
		_fail("catnip scraper still exposes the redundant settlement action")
	_assert_resident_card(
		catnip_panel.find_child("ResidentCard_%s" % str(resident_ids[3]), true, false) as Button,
		str(resident_ids[3]),
		str((game_state.call("get_resident_trait", str(resident_ids[3])) as Dictionary).get("display_name", ""))
	)
	var catnip_viewport_size := catnip_module.get_viewport().get_visible_rect().size
	if catnip_panel.size.x > catnip_viewport_size.x or catnip_panel.size.y > catnip_viewport_size.y:
		_fail("catnip scraper panel exceeds the viewport: panel=%s viewport=%s" % [catnip_panel.size, catnip_viewport_size])

	(game_state.get("resident_cat_ids") as Array).clear()
	(game_state.get("resident_traits") as Dictionary).clear()
	(game_state.get("assigned_worker_ids") as Array).clear()
	(game_state.get("assigned_catnip_worker_ids") as Array).clear()
	game_state.set("rescued_workers", 0)
	catnip_module.call("_rebuild_ui")
	await process_frame
	var catnip_empty := root.find_child("CatnipEmptyState", true, false) as Control
	_assert_empty_state(catnip_empty, "catnip scraper")
	var catnip_layer := catnip_module.get("ui_layer") as CanvasLayer
	if is_instance_valid(catnip_layer):
		catnip_layer.queue_free()
	await process_frame

	bank.call("interact")
	await process_frame
	var bank_empty := root.find_child("ScratcherEmptyState", true, false) as Control
	_assert_empty_state(bank_empty, "scratcher bank")
	var empty_bank_layer := bank.get("ui_layer") as CanvasLayer
	if is_instance_valid(empty_bank_layer):
		empty_bank_layer.queue_free()
	await process_frame
	game_state.set("rescued_workers", 4)
	game_state.call("_ensure_resident_records")
	# 복원 상태에서 시설이 잠겨 있으면 생산률이 0이라 강화 비교가 무의미해진다.
	game_state.call("unlock_all_shelter_facilities")
	var restored_resident_ids := game_state.get("resident_cat_ids") as Array
	if restored_resident_ids.is_empty():
		_fail("restored save must keep at least one resident")
	game_state.call("assign_worker_to_catnip", str(restored_resident_ids[0]))
	if int(game_state.call("get_active_catnip_workers")) < 1:
		_fail("catnip worker assignment failed after restore")

	var before_level := int(game_state.get("scratcher_bank_level"))
	var upgraded := bool(game_state.call("try_upgrade_scratcher_bank"))
	if not upgraded or int(game_state.get("scratcher_bank_level")) != before_level + 1:
		_fail("scratcher bank upgrade failed")
	game_state.set(
		"scrap",
		int(game_state.CATNIP_SCRAPER_UPGRADE_COSTS.get(int(game_state.get("catnip_scraper_level")) + 1, 0))
	)
	var catnip_level_before := int(game_state.get("catnip_scraper_level"))
	var catnip_rate_before := float(game_state.call("get_catnip_per_hour"))
	if not bool(game_state.call("try_upgrade_catnip_scraper")):
		_fail("catnip scraper upgrade failed")
	if int(game_state.get("catnip_scraper_level")) != catnip_level_before + 1:
		_fail("catnip scraper level did not increase")
	if float(game_state.call("get_catnip_per_hour")) <= catnip_rate_before:
		_fail("catnip scraper upgrade did not improve production")

	game_state.set("catnip", game_state.CATNIP_BOOST_COST)
	if not bool(game_state.call("activate_catnip_boost")) or float(game_state.call("get_production_multiplier")) != 10.0:
		_fail("catnip production boost failed")
	var tier_cost := game_state.call("get_shelter_upgrade_cost") as Dictionary
	game_state.set("scrap", int(tier_cost.get("scrap", 0)))
	game_state.set("churu", int(tier_cost.get("churu", 0)))
	if not bool(game_state.call("try_upgrade_shelter_tier")):
		_fail("shelter tier upgrade failed")
	if int(game_state.call("get_resident_capacity")) != 10 or int(game_state.call("get_scratcher_worker_slots")) != 6 or int(game_state.call("get_catnip_worker_slots")) != 2:
		_fail("tier 2 capacity table is inconsistent")

	print("SHELTER_ECONOMY_OK scrap=%d catnip=%d durability=%.1f workers=%d" % [
		game_state.get("scrap"),
		game_state.get("catnip"),
		game_state.get("weapon_durability"),
		game_state.call("get_active_scratcher_workers"),
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _assert_compact_close_button(scope: Node, context: String) -> void:
	var close := scope.find_child("CloseButton", true, false) as Button
	if close == null:
		_fail("%s close button is missing" % context)
		return
	if not close.text.is_empty() or close.custom_minimum_size.x > 44.0 or close.custom_minimum_size.y > 44.0:
		_fail("%s close button must be a compact icon-only control" % context)


func _find_button_with_text(scope: Node, text: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text:
			return button
	return null


func _find_label_with_text(scope: Node, text: String) -> Label:
	for node in scope.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text == text:
			return label
	return null


func _assert_resource_icon(scope: Node, resource_id: String, context: String) -> void:
	var icon := scope.find_child("ResourceIcon_%s" % resource_id, true, false) as TextureRect
	if icon == null or icon.texture == null:
		_fail("%s does not show the %s resource icon" % [context, resource_id])


func _assert_resident_card(card: Button, resident_id: String, display_name: String) -> void:
	if card == null or card.icon == null:
		_fail("resident card is missing its cropped portrait")
		return
	if card.icon.get_size().x != 72 or card.icon.get_size().y != 72:
		_fail("resident portrait must use the cropped 72px face texture")
		return
	if card.text.contains(resident_id) or not card.text.contains(display_name):
		_fail("resident card must show the cat name instead of its internal id")


func _assert_empty_state(empty_state: Control, context: String) -> void:
	if empty_state == null:
		_fail("%s empty resident state is missing" % context)
		return
	var title := empty_state.find_child("EmptyStateTitle", true, false) as Label
	if title == null or title.text != "구출한 주민이 없습니다.":
		_fail("%s empty resident title is incorrect" % context)
		return
	if title.autowrap_mode != TextServer.AUTOWRAP_OFF or title.get_combined_minimum_size().x < 120.0:
		_fail("%s empty resident title can collapse into vertical text" % context)
