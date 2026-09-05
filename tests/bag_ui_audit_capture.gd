extends SceneTree

# 가방(인벤토리) UI 검수 캡처. 2026-09-05.
#   bag_ui_light.png    : 두어 칸만 든 가방 — 세로 여백이 남지 않는지
#   bag_ui_full.png     : 재료·부착물·장비·소모품을 채운 가방
#   bag_ui_selected.png : 아이템 하나를 고른 상태(상세 카드 + 행동 버튼)
# 실행: godot --path . --script res://tests/bag_ui_audit_capture.gd

const OUTPUT_DIR := "res://test-output/field_ui"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for shot_name in ["light", "full", "selected"]:
		var game_state := root.get_node("GameState")
		game_state.set("persistence_enabled", false)
		game_state.call("reset_run")
		game_state.set("opening_completed", true)
		if shot_name != "light":
			_fill_bag(game_state)
		var baseline: Array[Node] = []
		for child in root.get_children():
			baseline.append(child)
		var main_scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main_scene)
		for _frame in 12:
			await process_frame
		var chain: Object = main_scene.get("main_mission")
		var cine: Object = chain.get("cinematic")
		var guard := 0
		while bool(cine.get("running")) and guard < 40:
			cine.call("skip")
			await _wait(0.2)
			guard += 1
		await _wait(0.4)
		var hud = main_scene.get("hud")
		var inventory: Control = hud.inventory_ui
		inventory.call("toggle")
		await _wait(0.6)
		if shot_name == "selected":
			var grid: Control = inventory.get("bag_grid")
			for child in grid.get_children():
				var button := child as Button
				if button != null and not button.disabled:
					button.emit_signal("pressed")
					break
			await _wait(0.5)
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/bag_ui_%s.png" % [OUTPUT_DIR, shot_name]
		if image.save_png(path) == OK:
			print("  SHOT %s" % ProjectSettings.globalize_path(path))
		main_scene.queue_free()
		for child in root.get_children():
			if not baseline.has(child) and child != main_scene:
				child.queue_free()
		await process_frame
		await process_frame
	print("BAG_UI_AUDIT_CAPTURE_OK")
	quit(0)


func _fill_bag(game_state: Object) -> void:
	game_state.set("medkits", 3)
	game_state.set("churu", 12)
	var components: Dictionary = game_state.get("mod_component_inventory")
	for component_id in ["scrap_steel", "spring_kit", "optic_glass", "polymer_grip"]:
		components[component_id] = 4
	var mods: Dictionary = game_state.get("weapon_mod_inventory")
	for mod_id in ["red_dot", "muzzle_brake"]:
		mods[mod_id] = 1
	var equipment: Dictionary = game_state.get("equipment_inventory")
	for equipment_id in ["kevlar_vest", "riot_helmet"]:
		equipment[equipment_id] = 1


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
