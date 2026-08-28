extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	game_state.set("scrap", 500)
	game_state.set("canned_food", 200)
	# 훈련 지불처는 쉘터 통조림 재고다(가방 통조림은 투척용).
	game_state.set("shelter_canned_food", 500)
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
	# 이 테스트는 2시간치 오프라인 정산을 태우므로 자연 유입(티어×0.5/h + 인원×0.02/h)이
	# 주민을 한둘 더 데려온다. 고정 4명이 아니라 "명단 전원이 세워졌는가"를 본다
	# (명단이 시각화 상한을 넘으면 상한까지).
	var expected_residents := mini(
		(game_state.get("resident_cat_ids") as Array).size(),
		int(shelter.call("_visible_resident_limit"))
	)
	var resident_nodes := get_nodes_in_group("shelter_resident")
	if resident_nodes.size() != expected_residents or expected_residents < 4:
		_fail("rescued residents were not instantiated in the shelter (%d/%d)" % [
			resident_nodes.size(), expected_residents
		])
	# 침대는 폐지됐다 — 복귀 자체가 완전 회복이다.
	if shelter.find_child("PlayerBed", true, false) != null:
		_fail("the obsolete player bed is still present")
	if shelter.find_children("BedModule*", "Node3D", true, false).size() > 0:
		_fail("obsolete resident beds are still present")
	# 바닥 슬롯 플레이트(장식)는 제거됐다. 워커는 _scratcher/_catnip_work_position
	# 좌표로 직접 이동하므로, 슬롯 수는 좌표 함수가 유효한지로만 확인한다.
	if int(game_state.call("get_scratcher_worker_slots")) <= 0:
		_fail("scratcher worker slots collapsed to zero")
	if int(game_state.call("get_catnip_worker_slots")) <= 0:
		_fail("catnip worker slots collapsed to zero")
	var working_residents := 0
	# 작업조 전원이 kneading_ne 한 장을 돌리면 100마리가 타일 무늬로 읽힌다.
	# 일부(약 30%)는 작업 구역을 바라보고 서 있게 흩어 놨으므로, 여기서는
	# "전원이 꾹꾹이"가 아니라 "과반이 꾹꾹이 + 나머지도 작업 포즈"를 본다.
	var kneading_residents := 0
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
			if resident_sprite == null:
				_fail("assigned scratcher worker has no sprite")
				continue
			var worker_animation := str(resident_sprite.animation)
			if worker_animation == "kneading_ne":
				kneading_residents += 1
			elif not worker_animation.begins_with("idle_"):
				_fail("assigned scratcher worker is not playing a work pose (%s)" % worker_animation)
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
	# "배정하면 꾹꾹이를 한다"는 여전히 화면이 말해야 한다 — 과반은 꾹꾹이 포즈.
	if working_residents > 0 and kneading_residents * 2 < working_residents:
		_fail("most assigned scratcher workers should show the kneading pose (%d/%d)" % [
			kneading_residents, working_residents
		])
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
	# 쉘터 연료 개념 폐지: 통조림이 0이어도 주민이 배치돼 있으면 라인은 계속 돈다
	# (통조림은 플레이어 소모품일 뿐, 주민 식비가 아니다). 예전 "통조림 없으면 정지"
	# 어서션을 뒤집었다.
	game_state.set("canned_food", 0)
	var unfed_scrap_before := int(game_state.get("scrap"))
	game_state.call("tick_shelter_live", 3600.0)
	if int(game_state.get("scrap")) <= unfed_scrap_before:
		_fail("shelter workers must keep producing with zero canned food (fuel gate removed)")
	if str(game_state.call("get_shelter_stall_reason")) != "":
		_fail("shelter must not report a stall reason while workers are assigned")
	# 오프라인 정산은 '자리 비운 시간' 상한(SHELTER_OFFLINE_MAX_SECONDS)까지만 쳐준다 —
	# 연료가 사라진 자리에 시간 상한이 들어왔다. 20시간 비워도 8시간치만 들어온다.
	var offline_scrap_before := int(game_state.get("scrap"))
	game_state.set("shelter_scrap_fraction", 0.0)
	game_state.set("shelter_last_progress_time", int(Time.get_unix_time_from_system()) - 20 * 3600)
	var offline_result := game_state.call("process_shelter_progress") as Dictionary
	var offline_gain := int(game_state.get("scrap")) - offline_scrap_before
	var capped_expected := int(floor(float(game_state.call("get_base_scrap_per_hour")) * 8.0))
	if int(offline_result.get("elapsed", 0)) != int(game_state.SHELTER_OFFLINE_MAX_SECONDS):
		_fail("offline settlement must clamp elapsed time to SHELTER_OFFLINE_MAX_SECONDS")
	if offline_gain <= 0 or offline_gain > capped_expected + 1:
		_fail("offline scrap must be capped at 8 hours of production (got %d, cap %d)" % [offline_gain, capped_expected])
	# 특성 오프라인 규칙 — 연료(식비) 폐지로 사라진 대식가/소식가의 트레이드오프를
	# '자리 비움' 규칙으로 대체했다. 대식가만 배치하면 오프라인 생산 0, 소식가는
	# 8h 상한 대신 16h까지 쌓인다. 특성이 없는 주민은 종전 계산과 같다.
	var trait_assigned := game_state.get("assigned_worker_ids") as Array
	if not trait_assigned.is_empty():
		var probe_id := str(trait_assigned[0])
		var traits_dict := game_state.get("resident_traits") as Dictionary
		var saved_traits := traits_dict.duplicate(true)
		var saved_assigned := trait_assigned.duplicate()
		trait_assigned.clear()
		trait_assigned.append(probe_id)
		var glutton := (traits_dict[probe_id] as Dictionary).duplicate(true)
		for key in game_state.RESIDENT_TRAIT_PRESETS[5]:
			glutton[key] = game_state.RESIDENT_TRAIT_PRESETS[5][key]
		traits_dict[probe_id] = glutton
		game_state.set("shelter_scrap_fraction", 0.0)
		var glutton_before := int(game_state.get("scrap"))
		game_state.set("shelter_last_progress_time", int(Time.get_unix_time_from_system()) - 10 * 3600)
		game_state.call("process_shelter_progress")
		if int(game_state.get("scrap")) != glutton_before:
			_fail("대식가 must not produce while the player is away (offline factor 0)")
		var frugal := (traits_dict[probe_id] as Dictionary).duplicate(true)
		frugal.erase("offline")
		for key in game_state.RESIDENT_TRAIT_PRESETS[6]:
			frugal[key] = game_state.RESIDENT_TRAIT_PRESETS[6][key]
		traits_dict[probe_id] = frugal
		game_state.set("shelter_scrap_fraction", 0.0)
		var frugal_before := int(game_state.get("scrap"))
		game_state.set("shelter_last_progress_time", int(Time.get_unix_time_from_system()) - 30 * 3600)
		game_state.call("process_shelter_progress")
		var frugal_gain := int(game_state.get("scrap")) - frugal_before
		var frugal_expected := int(floor(float(game_state.call("get_base_scrap_per_hour")) * 16.0))
		if frugal_gain < frugal_expected - 1 or frugal_gain > frugal_expected + 1:
			_fail("소식가 must accrue 16 hours offline (got %d, expected %d)" % [frugal_gain, frugal_expected])
		traits_dict.clear()
		for key in saved_traits:
			traits_dict[key] = saved_traits[key]
		trait_assigned.clear()
		for id in saved_assigned:
			trait_assigned.append(id)
	game_state.set("canned_food", 20)

	var workbench := get_nodes_in_group("shelter_workbench")[0] as Node
	workbench.call("interact")
	await process_frame
	var workbench_layer := root.find_child("WorkbenchUILayer", true, false) as CanvasLayer
	if workbench_layer == null:
		_fail("workbench did not create an interaction layer")
	_assert_compact_close_button(workbench_layer, "workbench")
	# 2026-08 2단계: 작업대의 기본 탭은 '강화 보드'(보유 장비 목록 · 강화 카드 · 재료 · 고정 액션 바).
	# 옛 목록+상세 구조는 제작/개조·보급 탭으로 옮겨 갔으므로 그쪽은 아래에서 탭을 바꿔 검사한다.
	var workbench_panel := workbench_layer.find_child("WorkbenchPanel", true, false) as PanelContainer
	var enhance_board := workbench_layer.find_child("WorkbenchEnhanceBoard", true, false) as BoxContainer
	var gear_list := workbench_layer.find_child("WorkbenchGearList", true, false) as BoxContainer
	var enhance_card := workbench_layer.find_child("WorkbenchEnhanceCard", true, false) as PanelContainer
	var enhance_button := workbench_layer.find_child("WorkbenchEnhanceButton", true, false) as Button
	var enhance_max_button := workbench_layer.find_child("WorkbenchEnhanceMaxButton", true, false) as Button
	var materials_panel := workbench_layer.find_child("WorkbenchMaterialsPanel", true, false) as Control
	if (
		workbench_panel == null
		or enhance_board == null
		or gear_list == null
		or enhance_card == null
		or enhance_button == null
		or enhance_max_button == null
		or materials_panel == null
	):
		_fail("workbench enhance board structure is missing")
	if gear_list.find_child("WorkbenchGearRow_ak47", true, false) == null:
		_fail("workbench enhance board must list the owned AK-47")
	if enhance_button.custom_minimum_size.y < 44.0 or enhance_max_button.custom_minimum_size.y < 44.0:
		_fail("workbench enhance actions must be touch-sized (>= 44px)")
	for resource_id in ["magazine_spring", "rubber_gasket", "scope_lens", "precision_gear", "military_alloy", "artisan_seal"]:
		_assert_resource_icon(materials_panel, str(resource_id), "workbench materials")
	var workbench_viewport_size := workbench.get_viewport().get_visible_rect().size
	if workbench_panel.size.x > workbench_viewport_size.x or workbench_panel.size.y > workbench_viewport_size.y:
		_fail("workbench enhance board panel exceeds the viewport")
	# 제작 탭(옛 레시피 목록 + 상세 + 고정 제작 버튼) — 옛 카테고리 이름으로 잡아도 탭으로 접힌다.
	workbench.set("selected_category", "armor")
	workbench.set("selected_recipe_id", "craft_scav_vest")
	workbench.call("_rebuild_ui")
	await process_frame
	var workbench_body := workbench_layer.find_child("WorkbenchBody", true, false) as BoxContainer
	var workbench_recipe_panel := workbench_layer.find_child("WorkbenchRecipePanel", true, false) as PanelContainer
	var workbench_detail_scroll := workbench_layer.find_child("WorkbenchDetailScroll", true, false) as ScrollContainer
	if (
		workbench_body == null
		or workbench_recipe_panel == null
		or workbench_detail_scroll == null
	):
		_fail("workbench responsive panel structure is missing")
	var workbench_resource_strip := workbench_layer.find_child("WorkbenchResourceStrip", true, false) as HFlowContainer
	if workbench_resource_strip == null:
		_fail("workbench icon resource strip is missing")
	# 통조림은 제작 재료에서 빠졌다(플레이어 소모품) — 자원 띠에 없어야 한다.
	for resource_id in ["scrap", "scope_lens", "rubber_gasket", "magazine_spring"]:
		_assert_resource_icon(workbench_resource_strip, str(resource_id), "workbench")
	if workbench_resource_strip.find_child("ResourceIcon_canned_food", true, false) != null:
		_fail("workbench resource strip must not list canned food any more")
	workbench_panel = workbench_layer.find_child("WorkbenchPanel", true, false) as PanelContainer
	if (
		workbench_panel == null
		or workbench_panel.size.x > workbench_viewport_size.x
		or workbench_panel.size.y > workbench_viewport_size.y
		or workbench_recipe_panel.size.x < 260.0
	):
		_fail("workbench panel exceeds or collapses inside the viewport")
	# 탄약 제작은 폐지됐다(탄약은 필드 루팅 + 상인 구매 전용). 대신 신설된
	# 방어구 카테고리로 같은 레이아웃 불변식을 검사한다.
	if workbench.RECIPES.has("ammo") or workbench.RECIPES.has("parts"):
		_fail("workbench must no longer craft ammo or raw parts")
	var armor_title := workbench_layer.find_child("WorkbenchRecipeTitle", true, false) as Label
	# 2단계: 방어구·무기 탭은 '제작' 탭 하나로 합쳐졌다(WorkbenchTab_craft).
	var armor_tab := workbench_layer.find_child("WorkbenchTab_craft", true, false) as Button
	var armor_detail_scroll := workbench_layer.find_child("WorkbenchDetailScroll", true, false) as ScrollContainer
	if (
		armor_title == null
		or armor_title.autowrap_mode != TextServer.AUTOWRAP_OFF
		or armor_tab == null
		or not armor_tab.button_pressed
		or armor_detail_scroll == null
		or armor_detail_scroll.size.y < 120.0
	):
		_fail("armor selection breaks the workbench detail layout")
	# 결과물 미리보기(이름 + 핵심 스탯 1줄)는 제작 버튼 위에 항상 있어야 한다.
	var result_preview := workbench_layer.find_child("WorkbenchResultPreview", true, false) as PanelContainer
	var preview_stats := workbench_layer.find_child("ResultPreviewStats", true, false) as Label
	if result_preview == null or preview_stats == null or not preview_stats.text.contains("피해감소"):
		_fail("armor recipes must preview their damage reduction before crafting")
	# 제작대는 창고 재료도 보유로 친다 — 가방 0개 + 창고 2개면 "2"가 보여야 한다.
	game_state.set("mod_component_inventory", {"rubber_gasket": 0, "scope_lens": 0, "magazine_spring": 0})
	(game_state.get("storage_inventory") as Array).append({
		"type": "component", "id": "rubber_gasket", "count": 2
	})
	if int(workbench.call("_owned_resource", "rubber_gasket")) != 2:
		_fail("workbench must count storage components as owned materials")
	workbench.call("_consume_resource", "rubber_gasket", 1)
	if int(game_state.call("get_stored_storage_count", "component", "rubber_gasket")) != 1:
		_fail("workbench must draw missing materials straight from storage")
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
	# 재료 행은 이름 아래 "가방 N + 창고 M" 출처 줄을 갖게 되어 이름표가
	# VBox 안으로 한 단계 들어갔다 — 직계 자식 조회 대신 재귀 탐색.
	var workbench_resource_name := workbench_resource_row.find_child("ResourceName", true, false) as Label
	var workbench_resource_amount := workbench_resource_row.find_child("ResourceAmount", true, false) as Label
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
	# 훈련 화폐는 통조림이다(유저 확정: 고철 투자가 아니라 통조림 소비).
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
	# 캣닢 칩은 사라졌다 — 이 모달에 캣닢 기능이 없다(부스터 폐지, 피버 전용).
	if bank_panel.find_child("ResourceValue_catnip", true, false) != null:
		_fail("scratcher bank must not show a catnip wallet chip any more")
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

	game_state.set("catnip", int(game_state.call("get_catnip_boost_cost")))
	if not bool(game_state.call("activate_catnip_boost")) or float(game_state.call("get_production_multiplier")) != 10.0:
		_fail("catnip production boost failed")
	var tier_cost := game_state.call("get_shelter_upgrade_cost") as Dictionary
	game_state.set("scrap", int(tier_cost.get("scrap", 0)))
	game_state.set("churu", int(tier_cost.get("churu", 0)))
	if not bool(game_state.call("try_upgrade_shelter_tier")):
		_fail("shelter tier upgrade failed")
	# 티어 2 표는 인크리멘탈 개편으로 5/10/20/35/50 → 8/30/100/300/900이 됐다.
	# 좌석도 함께 열렸고(꾹꾹이 14 · 스크래핑 6), 수입은 배치 체감이 눌러 준다.
	if int(game_state.call("get_resident_capacity")) != 30 or int(game_state.call("get_scratcher_worker_slots")) != 14 or int(game_state.call("get_catnip_worker_slots")) != 6:
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
