extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	# storage_inventory는 Array[Dictionary] 타입 프로퍼티다 — 무타입 배열 리터럴을
	# set()으로 넣으면 대입 자체가 조용히 무시돼 창고가 빈 채로 남는다(그래서 이
	# 테스트는 그동안 인출 실패를 창고 버그로 오인하며 멈춰 있었다).
	var seeded_storage: Array[Dictionary] = [
		{"type": "ammo", "id": "762_fmj", "count": 50},
		{"type": "medkit", "id": "medkit", "count": 2},
	]
	game_state.set("storage_inventory", seeded_storage)
	(game_state.get("ammo_inventory") as Dictionary)["762_fmj"] = 0
	game_state.set("medkits", 0)

	var ammo_result := game_state.call(
		"withdraw_storage_item_by_type",
		"ammo",
		"762_fmj",
		30
	) as Dictionary
	assert(bool(ammo_result.get("ok", false)))
	assert(int(ammo_result.get("moved", 0)) == 30)
	assert(int((game_state.get("ammo_inventory") as Dictionary).get("762_fmj", 0)) == 30)

	var medkit_result := game_state.call(
		"withdraw_storage_item_by_type",
		"medkit",
		"medkit",
		2
	) as Dictionary
	assert(bool(medkit_result.get("ok", false)))
	assert(int(game_state.get("medkits")) == 2)

	var food_storage: Array[Dictionary] = [
		{"type": "food", "id": "canned_food", "count": 5},
	]
	game_state.set("storage_inventory", food_storage)
	game_state.set("canned_food", 5)
	(game_state.get("mod_component_inventory") as Dictionary)["scope_lens"] = 4
	game_state.set("medkits", 3)
	game_state.call("clear_carried_raid_inventory_after_death")
	assert(int(game_state.call("get_stored_storage_count", "food", "canned_food")) == 5)
	assert(int(game_state.get("canned_food")) == 5)
	assert(int(game_state.call("get_mod_component_count", "scope_lens")) == 0)
	assert(int(game_state.get("medkits")) == 0)
	print("RAID_PREPARATION_SMOKE: PASS")
	quit(0)
