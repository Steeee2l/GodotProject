extends SceneTree

const BUILDING_SCENE := preload("res://scenes/building_interior.tscn")
const ENTRANCE_SCENE := preload("res://scenes/modules/building_entrance_portal.tscn")
var BuildingRunState: Node

class TestGameState:
	extends Node
	var map_seed := 47291
	var player_health := 82
	var magazine_ammo := 30
	var reserve_ammo := 90
	var equipped_weapon_id := "ak47"
	var has_ak := true
	var equipped_weapon_mods: Array[String] = []
	var equipped_ammo_id := "762_fmj"
	var weapon_level := 1
	var ammo_inventory := {"762_fmj": 90}
	var scrap := 80
	var mod_component_inventory := {
		"rubber_gasket": 0,
		"scope_lens": 0,
		"magazine_spring": 0,
	}
	func get_ammo_count(ammo_id: String) -> int:
		return int(ammo_inventory.get(ammo_id, 0))
	func set_ammo_count(ammo_id: String, amount: int) -> void:
		ammo_inventory[ammo_id] = amount


func _initialize() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		game_state = TestGameState.new()
		game_state.name = "GameState"
		root.add_child(game_state)
	BuildingRunState = root.get_node_or_null("BuildingRunState")
	if BuildingRunState == null:
		BuildingRunState = preload("res://scripts/building_run_state.gd").new()
		BuildingRunState.name = "BuildingRunState"
		root.add_child(BuildingRunState)
	BuildingRunState.begin_run(
		"smoke_test_tower",
		829173,
		"res://scenes/main.tscn",
		Vector3(3, 0.78, 4),
		5
	)
	var interior := BUILDING_SCENE.instantiate()
	root.add_child(interior)
	await process_frame
	await process_frame
	_assert(interior.get_node_or_null("Floor01Modules") != null, "1층 모듈 루트가 생성되어야 합니다.")
	_assert(get_nodes_in_group("building_room_module").size() >= 7, "한 층은 넓은 사무실 구역 7개 이상으로 구성되어야 합니다.")
	var floor_root := interior.get_node("Floor01Modules")
	_assert(interior.get_node_or_null("AimGuideLaserCore") != null, "Building aim laser must exist.")
	_assert(interior.get_node_or_null("HUD/FireButton") != null, "Mobile building HUD must have a fire button.")
	_assert(interior.get_node_or_null("HUD/MeleeButton") != null, "Mobile building HUD must have a melee button.")
	_assert(interior.get_node_or_null("HUD/DashButton") != null, "Mobile building HUD must have a dash button.")
	_assert(interior.get_node_or_null("HUD/ReloadButton") != null, "Mobile building HUD must have a reload button.")
	_assert(interior.get_node_or_null("HUD/FlashlightButton") != null, "Mobile building HUD must have a flashlight toggle.")
	interior.call("_on_flashlight_toggled", true)
	_assert(bool(interior.get("laser_aim_held")), "Mobile building flashlight must hold the right-click aim state.")
	interior.call("_on_flashlight_toggled", false)
	_assert((floor_root.get_meta("room_connections", []) as Array).size() >= 6, "사무실 구역들이 좁은 복도로 연결되어야 합니다.")
	_assert(get_nodes_in_group("building_floor_tile").size() >= 140, "사무실과 복도 바닥은 실제 격자 타일 모듈로 구성되어야 합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/office_carpet_tile_v1.png"), "이미지 생성 사무실 타일이 필요합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/corridor_floor_tile_v1.png"), "이미지 생성 복도 타일이 필요합니다.")
	_assert(get_nodes_in_group("building_loot_module").size() >= 4, "전리품 모듈이 생성되어야 합니다.")
	_assert(get_nodes_in_group("building_transition_module").size() >= 2, "출구와 벽면 엘리베이터가 생성되어야 합니다.")
	_assert(get_nodes_in_group("building_elevator_module").size() >= 1, "계단 대신 이미지형 벽면 엘리베이터가 필요합니다.")
	_assert(get_nodes_in_group("building_elevator_module").size() == 1, "각 층에는 층 선택형 엘리베이터가 하나만 있어야 합니다.")
	_assert(get_nodes_in_group("building_furniture_module").size() >= 4, "이미지형 사무실 가구 모듈이 배치되어야 합니다.")
	_assert(get_nodes_in_group("building_collision_debug").size() >= 2, "가구 충돌 영역을 확인할 빨간 디버그 표시가 필요합니다.")
	_assert(interior.get_node_or_null("VisibilityFog") != null, "필드와 동일한 시야 안개 레이어가 실내에도 필요합니다.")
	_assert(interior.get_node_or_null("BuildingPlayer/EquippedWeapon") != null, "필드에서 장착한 총기 이미지가 실내 플레이어에게도 유지되어야 합니다.")
	_assert(interior.get_node_or_null("HUD/ElevatorFloorMenu") != null, "한 개의 엘리베이터에서 층을 선택할 UI가 필요합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/modules/office_workstation_cluster_v1.png"), "생성된 사무실 가구 이미지가 필요합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/modules/wall_elevator_front_v2.png"), "벽 투영형 엘리베이터 이미지가 필요합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/modules/server_rack_cluster_v1.png"), "서버랙 이미지 모듈이 필요합니다.")
	_assert(ResourceLoader.exists("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png"), "실내 루팅 이미지가 필요합니다.")
	for transition in get_nodes_in_group("building_transition_module"):
		_assert(not str(transition.get_meta("transition_kind", "")).begins_with("stairs"), "건물 내부 이동 수단에 계단이 남아 있으면 안 됩니다.")
	var entrance := ENTRANCE_SCENE.instantiate()
	root.add_child(entrance)
	await process_frame
	_assert(entrance.is_in_group("building_entrance_portal"), "필드 건물에 부착할 입구 포탈 모듈이 필요합니다.")
	var first_seed: int = int(BuildingRunState.call("get_floor_seed", 2))
	_assert(first_seed == BuildingRunState.get_floor_seed(2), "층별 시드는 재진입해도 같아야 합니다.")
	BuildingRunState.mark_loot_collected(2, "test_loot")
	_assert(BuildingRunState.is_loot_collected(2, "test_loot"), "수집한 전리품 상태가 층별로 보존되어야 합니다.")
	interior.call("_load_floor", 2, "from_below")
	await process_frame
	await process_frame
	_assert(interior.get_node_or_null("Floor02Modules") != null, "엘리베이터/계단 전환 시 2층 모듈이 생성되어야 합니다.")
	_assert(int(BuildingRunState.current_floor) == 2, "현재 층 상태가 전환 결과를 따라야 합니다.")
	_assert(get_nodes_in_group("building_elevator_module").size() == 1, "2층에서도 층 선택형 엘리베이터는 하나만 있어야 합니다.")
	interior.call("_show_elevator_menu")
	_assert(bool(interior.get_node("HUD/ElevatorFloorMenu").visible), "엘리베이터 상호작용 시 층 선택 버튼이 표시되어야 합니다.")
	interior.get_node("HUD/ElevatorFloorMenu").visible = false
	for loot in get_nodes_in_group("building_loot_module"):
		_assert(loot.get_node_or_null("GeneratedLootVisual") != null, "루팅 오브젝트는 박스 메시가 아닌 이미지여야 합니다.")
		var loot_visual := loot.get_node("GeneratedLootVisual") as Sprite3D
		if str(loot.get_meta("loot_type", "")) == "component":
			# 텍스처 다이어트(size_limit) 이후 pixel_size 는 텍스처 폭에 따라 달라진다 — 월드 폭(≤1.0m)으로 검증.
			_assert(loot_visual.pixel_size * float(loot_visual.texture.get_width()) <= 1.0, "총기 부품 이미지는 탄약 상자보다 작고 현실적인 크기여야 합니다.")
	var ammo_before := int(game_state.magazine_ammo)
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	left_click.position = Vector2(920, 260)
	interior.call("_input", left_click)
	_assert(int(game_state.magazine_ammo) == ammo_before, "필드와 동일하게 좌클릭 단독 입력은 근접 공격이어야 합니다.")
	_assert(bool(interior.get("melee_attack_active")), "필드와 동일한 스윙 상태기(예비동작→타격)가 시작되어야 합니다.")
	# 필드와 동일하게 스윙 중에는 사격이 잠긴다 — 스윙을 끝내고 조준 사격을 검증한다.
	interior.call("_update_melee_attack", 0.6)
	_assert(not bool(interior.get("melee_attack_active")), "스윙은 0.5초 뒤 종료되어야 합니다.")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = left_click.position
	interior.call("_input", right_click)
	interior.call("_update_aim_laser")
	_assert(bool(interior.get_node("AimGuideLaserCore").visible), "Right-click aim must show the field-style laser guide.")
	interior.call("_input", left_click)
	_assert(int(game_state.magazine_ammo) == ammo_before - 1, "필드와 동일하게 우클릭 조준 중 좌클릭으로 사격해야 합니다.")
	interior.set("weapon_reloading", true)
	interior.get_node("BuildingPlayer").velocity = Vector3.ZERO
	Input.action_press("ui_right")
	interior.call("_physics_process", 0.016)
	Input.action_release("ui_right")
	_assert(interior.get_node("BuildingPlayer").velocity.length_squared() > 0.01, "Reloading must allow reduced-speed movement just like the field.")
	interior.set("weapon_reloading", false)
	interior.call("_try_start_roll")
	_assert(bool(interior.get("roll_active")), "실내에서도 필드와 같은 대시를 사용할 수 있어야 합니다.")
	var spawned_enemies: Array = interior.get("enemies")
	_assert(not spawned_enemies.is_empty(), "Building floor must spawn enemies for combat validation.")
	for spawned_enemy in spawned_enemies:
		_assert(str(spawned_enemy.get("enemy_kind")) == "ranged", "Building enemies must use ranged combat instead of melee combat.")
		_assert(str(spawned_enemy.get("weapon_id")) in ["m1911", "mp5", "ak47", "double_barrel"], "Every building enemy must visibly carry a firearm.")
	if not spawned_enemies.is_empty():
		var test_enemy: CharacterBody3D = spawned_enemies[0]
		_assert(int(test_enemy.get("max_health")) >= 80, "Enemy health must use the global baseline (lowered so geared players can sweep early zones, while high-threat zones scale up steeply).")
		test_enemy.call("take_hit", 1, Vector3.RIGHT, false)
		_assert(bool(test_enemy.get("alerted")), "The first hit must immediately alert the enemy.")
		_assert(float(test_enemy.get("pursuit_time")) >= 8.0, "A hit enemy must immediately pursue and fight back.")
	print("BUILDING_INTERIOR_SMOKE_OK rooms=", get_nodes_in_group("building_room_module").size(), " floor_seed=", first_seed)
	interior.free()
	entrance.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
