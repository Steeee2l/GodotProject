extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const FLOOR_TEXTURE_PATH := "res://assets/interiors/shelter_floor_topdown_v3.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/shelter_wall_panel_v3.png"
const ESCAPE_PIPE_TEXTURE_PATH := "res://assets/interiors/shelter_escape_pipe_v1.png"
const BED_MODULE_SCENE := preload("res://scenes/modules/shelter_bed_module.tscn")
const WORKBENCH_MODULE_SCENE := preload("res://scenes/modules/shelter_workbench_module.tscn")
const SCRATCHER_BANK_MODULE_SCENE := preload("res://scenes/modules/scratcher_bank_module.tscn")
const CATNIP_SCRAPER_MODULE_SCENE := preload("res://scenes/modules/catnip_scraper_module.tscn")
const STORAGE_MODULE_SCENE := preload("res://scenes/modules/shelter_storage_module.tscn")
const TRAINING_MODULE_SCENE := preload("res://scenes/modules/shelter_training_module.tscn")
const SHELTER_RESIDENT_SCRIPT := preload("res://scripts/shelter_resident_cat.gd")
const SHELTER_MERCHANT_SCRIPT := preload("res://scripts/shelter_merchant.gd")
const MERCHANT_TEXTURE := preload("res://assets/characters/merchant_cat/merchant_down_left_idle.png")
const MOVE_SPEED := 4.6
const CAT_ANIMATION_ROOT := "res://assets/characters/cat_8way"
const CAT_ROLL_ANIMATION_ROOT := "res://assets/characters/cat_roll"
const ROLL_COOLDOWN_INDICATOR_SCRIPT := preload("res://scripts/roll_cooldown_indicator.gd")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const AMMO_TEXTURE := preload("res://assets/items/ammo_762.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const CAT_DIRECTION_STATES := {
	"n": "up",
	"ne": "up_right",
	"e": "right",
	"se": "down_right",
	"s": "down",
	"sw": "down_left",
	"w": "left",
	"nw": "up_left",
}
const CAT_FRAME_COUNT := 4
const ROLL_FRAME_COUNT := 4
const ROLL_DURATION := 0.46
const ROLL_STAMINA_MAX := 100.0
const ROLL_STAMINA_COST := 35.0
const ROLL_STAMINA_RECOVERY_PER_SECOND := 30.0
const ROLL_START_SPEED := 18.0
const ROLL_END_SPEED := 4.2
const ROLL_AFTERIMAGE_INTERVAL := 0.06
const ROOM_SIZE_BY_TIER := {
	1: Vector2(48.0, 28.0),
	2: Vector2(56.0, 32.0),
	3: Vector2(64.0, 36.0),
	4: Vector2(72.0, 40.0),
	5: Vector2(80.0, 44.0),
}
const BED_MODULE_PLATE_SIZE := Vector2(2.65, 3.45)
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const PIPE_EXIT_LABEL := "파이프를 타고 도시로 올라가기"
const MERCHANT_GOODS := [
	{
		"id": "762_fmj", "type": "ammo", "title": "7.62mm 보통탄 상자", "amount": 30,
		"buy_price": 42, "sell_cans": 2, "icon": "res://assets/items/ammo_762.png",
		"description": "AK 계열 총기에 사용하는 보통탄 30발입니다.",
	},
	{
		"id": "canned_food", "type": "food", "title": "밀봉 통조림", "amount": 1,
		"buy_price": 64, "sell_cans": 0, "icon": "",
		"description": "주민 노동과 쉘터 시설 운영에 필요한 기본 재화입니다.",
	},
	{
		"id": "scope_lens", "type": "component", "title": "스코프 렌즈", "amount": 1,
		"buy_price": 90, "sell_cans": 5, "icon": "res://assets/items/mod_components/scope_lens.png",
		"description": "조준경과 정밀 모듈 제작에 사용하는 온전한 렌즈입니다.",
	},
	{
		"id": "rubber_gasket", "type": "component", "title": "고무 패킹", "amount": 1,
		"buy_price": 58, "sell_cans": 3, "icon": "res://assets/items/mod_components/rubber_gasket.png",
		"description": "소음기와 반동 완충 부품 제작에 사용하는 패킹입니다.",
	},
	{
		"id": "magazine_spring", "type": "component", "title": "탄창 스프링", "amount": 1,
		"buy_price": 72, "sell_cans": 4, "icon": "res://assets/items/mod_components/magazine_spring.png",
		"description": "탄창과 전술 부품 제작에 사용하는 복원력 높은 스프링입니다.",
	},
]

var player: CharacterBody3D
var survivor: AnimatedSprite3D
var shelter_camera: Camera3D
var camera_focus := Vector3.ZERO
var facing := "s"
var motion_state := "idle"
var current_station := ""
var current_module: Node3D
var prompt_label: Label
var status_label: Label
var stats_label: Label
var shelter_currency_labels: Dictionary = {}
var scrap_gain_label: Label
var shelter_upgrade_button: Button
var interact_button: Button
var dash_button: Button
var roll_cooldown_indicator: Control
var touch_stick: Control
var touch_knob: Control
var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_vector := Vector2.ZERO
var roll_active := false
var roll_elapsed := 0.0
var roll_stamina := ROLL_STAMINA_MAX
var roll_afterimage_timer := 0.0
var roll_direction := Vector3.ZERO
var roll_afterimages: Array[Sprite3D] = []
var roll_audio_player: AudioStreamPlayer3D
var shelter_residents: Array[CharacterBody3D] = []
var merchant: Node3D
var merchant_waiting_marker: Node3D
var merchant_notice_panel: PanelContainer
var merchant_ui_layer: CanvasLayer
var merchant_shop_list: VBoxContainer
var merchant_shop_currency_labels: Dictionary = {}
var merchant_shop_message_label: Label
var merchant_buy_tab: Button
var merchant_sell_tab: Button
var merchant_shop_mode := "buy"
var merchant_ui_open := false
var shelter_stats_refresh_time := 0.0
var shelter_save_time := 0.0
var raid_zone_ui_layer: CanvasLayer
var raid_zone_ui_open := false
var raid_loadout_ui_layer: CanvasLayer
var raid_loadout_ui_open := false
var inventory_ui: Control


func _room_art_size() -> Vector2:
	var room_size: Vector2 = ROOM_SIZE_BY_TIER.get(GameState.shelter_tier, ROOM_SIZE_BY_TIER[1])
	return room_size


func _room_half_extents() -> Vector2:
	return _room_art_size() * 0.5


func _player_bounds() -> Vector2:
	return _room_half_extents() - Vector2(0.8, 0.8)


func _north_module_z() -> float:
	return -_room_half_extents().y + 0.76


func _player_bed_position() -> Vector3:
	return Vector3(-_room_half_extents().x + 1.95, 0.0, -5.4)


func _workbench_position() -> Vector3:
	return Vector3(-2.0, 0.0, _north_module_z())


func _scratcher_bank_position() -> Vector3:
	return Vector3(_room_half_extents().x - 11.0, 0.0, _north_module_z())


func _catnip_scraper_position() -> Vector3:
	return Vector3(-_room_half_extents().x + 8.0, 0.0, _north_module_z())


func _storage_position() -> Vector3:
	return Vector3(-9.4, 0.0, _north_module_z())


func _training_position() -> Vector3:
	return Vector3(5.2, 0.0, _north_module_z())


func _pipe_position() -> Vector3:
	return Vector3(_room_half_extents().x - 3.0, 0.0, _north_module_z() + 1.18)


func _merchant_inside_position() -> Vector3:
	var pipe := _pipe_position()
	return Vector3(pipe.x - 1.65, 0.78, pipe.z + 1.7)


func _pipe_exit_station() -> Dictionary:
	var pipe := _pipe_position()
	return {
		"position": Vector2(pipe.x, pipe.z),
		"label": PIPE_EXIT_LABEL,
		"radius": 2.2,
	}


func _resident_roam_bounds() -> Rect2:
	var half := _room_half_extents()
	var minimum := Vector2(-half.x + 4.8, -half.y + 6.0)
	var maximum := Vector2(half.x - 4.8, half.y - 3.0)
	return Rect2(minimum, maximum - minimum)


func _ready() -> void:
	add_to_group("shelter_resident_host")
	var offline_notice: Dictionary = GameState.process_shelter_progress()
	_build_room()
	_build_stage_one_modules()
	_build_player()
	roll_stamina = GameState.get_max_stamina()
	_build_shelter_residents()
	_build_roll_audio()
	_build_interface()
	_setup_merchant_visit()
	_update_stats()
	_show_status(_build_offline_status_text(offline_notice))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not roll_active:
		roll_stamina = minf(
			GameState.get_max_stamina(),
			roll_stamina + ROLL_STAMINA_RECOVERY_PER_SECOND * GameState.get_stamina_recovery_multiplier() * delta
		)
	if dash_button:
		dash_button.disabled = roll_active or roll_stamina < ROLL_STAMINA_COST
	var input_vector := Vector2.ZERO
	if not _ui_blocks_player():
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
		if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
		if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
		if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	input_vector = input_vector.limit_length(1.0)
	if not _ui_blocks_player() and touch_vector.length_squared() > input_vector.length_squared():
		input_vector = touch_vector
	var world_direction := Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y)
	if roll_active:
		_update_roll(delta)
	elif world_direction.length_squared() > 0.01:
		world_direction = world_direction.normalized()
		player.velocity = world_direction * MOVE_SPEED * GameState.get_move_speed_multiplier()
		_update_facing(input_vector)
		_set_motion_state("walk")
	else:
		player.velocity = Vector3.ZERO
		_set_motion_state("idle")
	player.move_and_slide()
	var bounds := _player_bounds()
	player.position.x = clampf(player.position.x, -bounds.x, bounds.x)
	player.position.z = clampf(player.position.z, -bounds.y, bounds.y)
	_update_camera(delta)
	_update_nearby_station()
	_update_roll_feedback()
	_update_live_shelter_income(delta)
	status_label.modulate.a = move_toward(status_label.modulate.a, 0.0, delta * 0.08)
	if scrap_gain_label:
		scrap_gain_label.modulate.a = move_toward(scrap_gain_label.modulate.a, 0.0, delta * 1.8)


func _build_room() -> void:
	var room_size := _room_art_size()
	var half := room_size * 0.5
	RenderingServer.set_default_clear_color(Color.BLACK)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color.BLACK
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("#53645d")
	environment_resource.ambient_light_energy = 0.72
	environment.environment = environment_resource
	add_child(environment)
	var outside_material := _material(Color.BLACK)
	outside_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_plane("BlackOutside", Vector3(0, -0.12, 0), Vector2(240, 240), outside_material, self)
	var floor_material: StandardMaterial3D
	if ResourceLoader.exists(FLOOR_TEXTURE_PATH):
		floor_material = _texture_material(load(FLOOR_TEXTURE_PATH) as Texture2D)
		floor_material.texture_repeat = true
		floor_material.uv1_scale = Vector3(room_size.x / 8.0, room_size.y / 8.0, 1.0)
	else:
		floor_material = _material(Color("#242c2a"))
	_add_plane("ShelterInteriorArt", Vector3(0, 0, 0), room_size, floor_material, self)
	var wall_material := _material(Color("#202a31"))
	if ResourceLoader.exists(WALL_TEXTURE_PATH):
		wall_material = _texture_material(load(WALL_TEXTURE_PATH) as Texture2D)
	_build_visible_walls(wall_material)
	_build_escape_pipe()
	_add_obstacle("NorthWallCollision", Vector3(0, 1.5, -half.y), Vector3(room_size.x, 3.0, 0.55))
	_add_obstacle("SouthWallCollision", Vector3(0, 1.5, half.y), Vector3(room_size.x, 3.0, 0.55))
	_add_obstacle("WestWallCollision", Vector3(-half.x, 1.5, 0), Vector3(0.55, 3.0, room_size.y))
	_add_obstacle("EastWallCollision", Vector3(half.x, 1.5, 0), Vector3(0.55, 3.0, room_size.y))
	shelter_camera = Camera3D.new()
	shelter_camera.name = "ShelterCamera"
	add_child(shelter_camera)
	shelter_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	shelter_camera.size = 27.0
	shelter_camera.position = Vector3(18.0, 18.0, 18.0)
	shelter_camera.look_at(Vector3.ZERO)
	shelter_camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -38, 0)
	light.light_energy = 0.95
	add_child(light)


func _build_visible_walls(wall_material: Material) -> void:
	var room_size := _room_art_size()
	var half := room_size * 0.5
	_add_segmented_wall("NorthWall", Vector3(0, 1.5, -half.y), Vector3(room_size.x, 3.0, 0.55), true, wall_material)
	_add_segmented_wall("WestWall", Vector3(-half.x, 1.5, 0), Vector3(0.55, 3.0, room_size.y), false, wall_material)
	var light_material := _emissive_material(Color("#55dce9"), 2.5)
	var north_light_count := maxi(3, floori((room_size.x - 4.0) / 6.0) + 1)
	for index in north_light_count:
		var x := lerpf(-half.x + 3.0, half.x - 3.0, float(index) / float(maxi(1, north_light_count - 1)))
		_add_visual_box("NorthLight", Vector3(x, 1.35, -half.y + 0.32), Vector3(1.45, 0.12, 0.08), light_material, self)
	var west_light_count := maxi(2, floori((room_size.y - 4.0) / 6.0) + 1)
	for index in west_light_count:
		var z := lerpf(-half.y + 3.0, half.y - 3.0, float(index) / float(maxi(1, west_light_count - 1)))
		_add_visual_box("WestLight", Vector3(-half.x + 0.32, 1.35, z), Vector3(0.08, 0.12, 1.45), light_material, self)


func _add_segmented_wall(prefix: String, position: Vector3, size: Vector3, along_x: bool, material: Material) -> void:
	var total := size.x if along_x else size.z
	var segment_count := ceili(total / 3.3)
	var segment_length := total / float(segment_count)
	for index in segment_count:
		var offset := -total * 0.5 + segment_length * (float(index) + 0.5)
		var segment_position := position
		var segment_size := size
		if along_x:
			segment_position.x += offset
			segment_size.x = segment_length - 0.035
		else:
			segment_position.z += offset
			segment_size.z = segment_length - 0.035
		_add_visual_box("%s%02d" % [prefix, index + 1], segment_position, segment_size, material, self)


func _build_escape_pipe() -> void:
	if not ResourceLoader.exists(ESCAPE_PIPE_TEXTURE_PATH):
		return
	var half := _room_half_extents()
	var pipe_station := _pipe_position()
	var pipe := Sprite3D.new()
	pipe.name = "EscapePipe"
	pipe.position = Vector3(pipe_station.x, 2.15, -half.y + 0.38)
	pipe.texture = load(ESCAPE_PIPE_TEXTURE_PATH) as Texture2D
	pipe.pixel_size = 0.0043
	pipe.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pipe.shaded = false
	pipe.transparent = true
	pipe.no_depth_test = true
	pipe.render_priority = 30
	pipe.add_to_group("shelter_exit_pipe")
	add_child(pipe)
	_add_obstacle("EscapePipeCollision", Vector3(pipe_station.x, 1.0, -half.y + 0.75), Vector3(1.65, 2.0, 1.05))


func _build_stage_one_modules() -> void:
	var module_root := Node3D.new()
	module_root.name = "StageOneModules"
	module_root.set_meta("stage", 1)
	module_root.set_meta("cat_capacity", GameState.get_resident_capacity())
	module_root.set_meta("module_grid_size", BED_MODULE_PLATE_SIZE)
	add_child(module_root)
	var bed_position := _player_bed_position()
	_build_module_plate(module_root, bed_position, 1, 90.0)
	var bed := BED_MODULE_SCENE.instantiate() as Node3D
	bed.name = "PlayerBed"
	bed.position = bed_position
	bed.rotation_degrees.y = 90.0
	bed.set("bed_index", 1)
	module_root.add_child(bed)
	var workbench := WORKBENCH_MODULE_SCENE.instantiate() as Node3D
	workbench.name = "WeaponWorkbench"
	workbench.position = _workbench_position()
	module_root.add_child(workbench)
	var bank := SCRATCHER_BANK_MODULE_SCENE.instantiate() as Node3D
	bank.name = "ScratcherBank"
	bank.position = _scratcher_bank_position()
	module_root.add_child(bank)
	var catnip_scraper := CATNIP_SCRAPER_MODULE_SCENE.instantiate() as Node3D
	catnip_scraper.name = "CatnipScraper"
	catnip_scraper.position = _catnip_scraper_position()
	module_root.add_child(catnip_scraper)
	var storage := STORAGE_MODULE_SCENE.instantiate() as Node3D
	storage.name = "ShelterStorage"
	storage.position = _storage_position()
	module_root.add_child(storage)
	var training := TRAINING_MODULE_SCENE.instantiate() as Node3D
	training.name = "SurvivalTrainingFacility"
	training.position = _training_position()
	module_root.add_child(training)
	_build_production_lines(module_root)


func _build_production_lines(module_root: Node3D) -> void:
	var scratcher_slots := GameState.get_scratcher_worker_slots()
	var scratcher_rows := ceili(float(scratcher_slots) / 2.0)
	_build_production_track(
		module_root,
		_scratcher_bank_position().x,
		_north_module_z() + 3.0,
		scratcher_rows,
		3.35,
		"scratcher"
	)
	for index in scratcher_slots:
		_build_production_slot(module_root, _scratcher_work_position(index), index, "scratcher")
	var catnip_slots := GameState.get_catnip_worker_slots()
	_build_production_track(
		module_root,
		_catnip_scraper_position().x,
		_north_module_z() + 3.0,
		catnip_slots,
		1.75,
		"catnip"
	)
	for index in catnip_slots:
		_build_production_slot(module_root, _catnip_work_position(index), index, "catnip")


func _build_production_track(parent: Node3D, x: float, first_z: float, rows: int, width: float, kind: String) -> void:
	if rows <= 0:
		return
	var length := 1.0 + float(rows - 1) * 1.35
	var center_z := first_z + float(rows - 1) * 0.675
	var track_root := Node3D.new()
	track_root.name = "CatnipConveyor" if kind == "catnip" else "ScratcherConveyor"
	track_root.position = Vector3(x, 0.008, center_z)
	parent.add_child(track_root)
	var base_color := Color("#14221b") if kind == "catnip" else Color("#252016")
	var rail_color := Color("#557e58") if kind == "catnip" else Color("#7e6b42")
	_add_plane("TrackBed", Vector3.ZERO, Vector2(width, length + 0.42), _material(base_color), track_root)
	var rail_material := _material(rail_color)
	_add_visual_box("LeftRail", Vector3(-width * 0.5, 0.02, 0), Vector3(0.07, 0.04, length + 0.42), rail_material, track_root)
	_add_visual_box("RightRail", Vector3(width * 0.5, 0.02, 0), Vector3(0.07, 0.04, length + 0.42), rail_material, track_root)
	for row in rows + 1:
		var cross_z := -length * 0.5 + float(row) * (length / float(maxi(1, rows)))
		_add_visual_box("CrossTie%02d" % row, Vector3(0, 0.018, cross_z), Vector3(width, 0.025, 0.055), rail_material, track_root)


func _build_production_slot(parent: Node3D, slot_position: Vector3, index: int, kind: String) -> void:
	var is_catnip := kind == "catnip"
	var plate_color := Color("#173026") if is_catnip else Color("#30291b")
	var edge_color := Color("#79b86b") if is_catnip else Color("#c2a358")
	var slot_name := "CatnipLineSlot" if is_catnip else "ScratcherLineSlot"
	var slot_root := Node3D.new()
	slot_root.name = "%s%02d" % [slot_name, index + 1]
	slot_root.position = Vector3(slot_position.x, 0.022, slot_position.z)
	slot_root.set_meta("production_kind", kind)
	slot_root.set_meta("slot_index", index)
	parent.add_child(slot_root)
	_add_plane("Plate", Vector3.ZERO, Vector2(1.35, 1.0), _material(plate_color), slot_root)
	var edge_material := _emissive_material(edge_color, 1.5)
	_add_visual_box("NorthEdge", Vector3(0, 0.018, -0.5), Vector3(1.35, 0.025, 0.035), edge_material, slot_root)
	_add_visual_box("SouthEdge", Vector3(0, 0.018, 0.5), Vector3(1.35, 0.025, 0.035), edge_material, slot_root)
	_add_visual_box("WestEdge", Vector3(-0.675, 0.018, 0), Vector3(0.035, 0.025, 1.0), edge_material, slot_root)
	_add_visual_box("EastEdge", Vector3(0.675, 0.018, 0), Vector3(0.035, 0.025, 1.0), edge_material, slot_root)
	var number := Label3D.new()
	number.text = "%02d" % (index + 1)
	number.position = Vector3(0.0, 0.035, 0.0)
	number.rotation_degrees.x = -90.0
	number.font = FONT
	number.font_size = 34
	number.pixel_size = 0.006
	number.modulate = Color(edge_color, 0.78)
	number.no_depth_test = true
	slot_root.add_child(number)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "ShelterPlayer"
	player.position = Vector3(0.0, 0.78, 1.5)
	camera_focus = Vector3(player.position.x, 0.0, player.position.z)
	if is_instance_valid(shelter_camera):
		shelter_camera.position = camera_focus + Vector3(18.0, 18.0, 18.0)
		shelter_camera.look_at(camera_focus)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.3
	collision.shape = shape
	player.add_child(collision)
	survivor = AnimatedSprite3D.new()
	survivor.name = "Survivor"
	survivor.position = Vector3(0, 0.3, 0)
	survivor.pixel_size = 0.0098
	survivor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	survivor.shaded = false
	survivor.transparent = true
	survivor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	survivor.no_depth_test = true
	survivor.render_priority = 127
	survivor.sprite_frames = _create_cat_frames()
	player.add_child(survivor)
	_play_directional_animation()


func _build_shelter_residents() -> void:
	GameState._ensure_resident_records()
	for resident_id in GameState.resident_cat_ids:
		_spawn_shelter_resident(resident_id)
	refresh_shelter_residents(true)


func _spawn_shelter_resident(resident_id: String) -> CharacterBody3D:
	for resident in shelter_residents:
		if is_instance_valid(resident) and str(resident.get_meta("resident_id", "")) == resident_id:
			return resident
	var resident := SHELTER_RESIDENT_SCRIPT.new() as CharacterBody3D
	var waiting_index := shelter_residents.size()
	resident.name = "ShelterResident_%s" % resident_id
	resident.call("configure", resident_id, _resident_wait_position(waiting_index))
	add_child(resident)
	resident.call("set_roam_bounds", _resident_roam_bounds())
	shelter_residents.append(resident)
	return resident


func _add_debug_resident() -> bool:
	var previous_ids := GameState.resident_cat_ids.duplicate()
	if GameState.try_add_rescued_workers(1) <= 0:
		_show_status("주민 수용 공간이 가득 찼습니다. 쉘터 Tier를 올려주세요.")
		return false
	GameState._ensure_resident_records()
	for resident_id in GameState.resident_cat_ids:
		if not previous_ids.has(resident_id):
			_spawn_shelter_resident(resident_id)
			break
	refresh_shelter_residents(true)
	GameState.save_persistent_state()
	_update_stats()
	_show_status("테스트 주민이 쉘터에 합류했습니다.  주민 %d/%d" % [
		GameState.resident_cat_ids.size(),
		GameState.get_resident_capacity(),
	])
	return true


func _setup_merchant_visit() -> void:
	GameState.roll_merchant_visit()
	match GameState.merchant_status:
		"waiting":
			_build_merchant_waiting_marker()
			_set_merchant_notice_visible(true)
		"inside":
			_spawn_merchant()
			_set_merchant_notice_visible(false)
		_:
			_set_merchant_notice_visible(false)


func _build_merchant_waiting_marker() -> void:
	if is_instance_valid(merchant_waiting_marker):
		return
	merchant_waiting_marker = Node3D.new()
	merchant_waiting_marker.name = "MerchantWaitingBubble"
	merchant_waiting_marker.position = _pipe_position()
	add_child(merchant_waiting_marker)

	var arrow := Label3D.new()
	arrow.name = "MerchantArrow"
	arrow.text = "▼"
	arrow.position = Vector3(0.0, 3.55, 0.0)
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.render_priority = 127
	arrow.font = FONT
	arrow.font_size = 72
	arrow.pixel_size = 0.006
	arrow.modulate = Color(0.96, 0.76, 0.28, 0.0)
	arrow.outline_modulate = Color(0.08, 0.055, 0.02, 0.96)
	arrow.outline_size = 14
	merchant_waiting_marker.add_child(arrow)
	var arrow_tween := arrow.create_tween().set_loops()
	arrow_tween.tween_property(arrow, "position:y", 2.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrow_tween.parallel().tween_property(arrow, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	arrow_tween.tween_property(arrow, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	arrow_tween.tween_property(arrow, "position:y", 3.55, 0.01)
	arrow_tween.tween_interval(0.34)

	var dialogue := Label3D.new()
	dialogue.name = "MerchantKnockLine"
	dialogue.text = "행상인이 기다리는 중"
	dialogue.position = Vector3(0.0, 4.0, 0.0)
	dialogue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dialogue.no_depth_test = true
	dialogue.render_priority = 127
	dialogue.font = FONT
	dialogue.font_size = 30
	dialogue.pixel_size = 0.0048
	dialogue.modulate = Color("#f5e6bd")
	dialogue.outline_modulate = Color(0.015, 0.02, 0.018, 0.96)
	dialogue.outline_size = 12
	merchant_waiting_marker.add_child(dialogue)

func _spawn_merchant() -> void:
	if is_instance_valid(merchant):
		return
	merchant = SHELTER_MERCHANT_SCRIPT.new() as Node3D
	merchant.position = _merchant_inside_position()
	add_child(merchant)


func _merchant_face_texture() -> AtlasTexture:
	var frame_width := float(MERCHANT_TEXTURE.get_width()) / 4.0
	var texture := AtlasTexture.new()
	texture.atlas = MERCHANT_TEXTURE
	texture.region = Rect2(frame_width * 0.20, 12.0, frame_width * 0.56, 112.0)
	return texture


func refresh_shelter_residents(snap := false) -> void:
	GameState._ensure_resident_records()
	var waiting_ids: Array[String] = []
	for resident_id in GameState.resident_cat_ids:
		if not GameState.assigned_worker_ids.has(resident_id) and not GameState.assigned_catnip_worker_ids.has(resident_id):
			waiting_ids.append(resident_id)
	for resident in shelter_residents:
		if not is_instance_valid(resident):
			continue
		resident.call("set_roam_bounds", _resident_roam_bounds())
		var resident_id := str(resident.get_meta("resident_id", ""))
		var kneading_index := GameState.assigned_worker_ids.find(resident_id)
		var catnip_index := GameState.assigned_catnip_worker_ids.find(resident_id)
		var assignment_kind := "waiting"
		var target := _resident_wait_position(waiting_ids.find(resident_id))
		var focus := target
		if kneading_index >= 0:
			assignment_kind = "kneading"
			target = _scratcher_work_position(kneading_index)
			focus = _scratcher_bank_position()
		elif catnip_index >= 0:
			assignment_kind = "catnip"
			target = _catnip_work_position(catnip_index)
			focus = _catnip_scraper_position()
		resident.call("set_work_assignment", assignment_kind, target, focus, snap)
		resident.call(
			"set_production_feedback",
			GameState.get_worker_production_per_second(resident_id, assignment_kind)
		)


func _refresh_resident_production_feedback() -> void:
	for resident in shelter_residents:
		if not is_instance_valid(resident):
			continue
		var resident_id := str(resident.get_meta("resident_id", ""))
		var assignment_kind := str(resident.get_meta("assignment_kind", "waiting"))
		resident.call(
			"set_production_feedback",
			GameState.get_worker_production_per_second(resident_id, assignment_kind)
		)


func _resident_wait_position(index: int) -> Vector3:
	var bounds := _resident_roam_bounds()
	var columns := maxi(3, ceili(sqrt(float(GameState.get_resident_capacity()))))
	var column := maxi(0, index) % columns
	var row := maxi(0, index) / columns
	var x_spacing := minf(2.4, (bounds.size.x - 2.0) / float(maxi(1, columns - 1)))
	var row_space := maxf(2.0, bounds.size.y - 2.0)
	return Vector3(
		bounds.position.x + 1.0 + float(column) * x_spacing,
		0.78,
		bounds.position.y + 1.0 + fmod(float(row) * 2.2, row_space)
	)


func _scratcher_work_position(index: int) -> Vector3:
	var station := _scratcher_bank_position()
	var column := maxi(0, index) % 2
	var row := maxi(0, index) / 2
	return Vector3(
		station.x - 0.85 + float(column) * 1.7,
		0.78,
		_north_module_z() + 3.0 + float(row) * 1.35
	)


func _catnip_work_position(index: int) -> Vector3:
	var station := _catnip_scraper_position()
	return Vector3(
		station.x,
		0.78,
		_north_module_z() + 3.0 + float(maxi(0, index)) * 1.35
	)


func _update_camera(delta: float) -> void:
	if not is_instance_valid(shelter_camera) or not is_instance_valid(player):
		return
	var desired_focus := Vector3(player.position.x, 0.0, player.position.z)
	var follow_weight := 1.0 - exp(-delta * 5.5)
	camera_focus = camera_focus.lerp(desired_focus, follow_weight)
	shelter_camera.position = camera_focus + Vector3(18.0, 18.0, 18.0)
	shelter_camera.look_at(camera_focus)


func _ui_blocks_player() -> bool:
	return (
		merchant_ui_open
		or raid_zone_ui_open
		or raid_loadout_ui_open
		or not get_tree().get_nodes_in_group("shelter_modal_ui").is_empty()
		or (inventory_ui != null and bool(inventory_ui.call("is_open")))
	)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	var theme := Theme.new()
	theme.default_font = FONT
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(370, 220)
	panel.theme = theme
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.023, 0.92), Color("#577a69")))
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 3)
	margin.add_child(stats_box)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_box.add_child(stats_label)
	var resource_grid := GridContainer.new()
	resource_grid.columns = 2
	resource_grid.add_theme_constant_override("h_separation", 14)
	resource_grid.add_theme_constant_override("v_separation", 2)
	stats_box.add_child(resource_grid)
	for resource_data in [
		["scrap", "고철", Color("#c7d1ce")],
		["catnip", "캣닢", Color("#a9db78")],
		["food", "통조림", Color("#e5b55b")],
		["churu", "츄르", Color("#d99b67")],
	]:
		var chip := _currency_chip(str(resource_data[0]), str(resource_data[1]), resource_data[2], 20, 150)
		resource_grid.add_child(chip)
		shelter_currency_labels[str(resource_data[0])] = chip.get_meta("value_label")
	shelter_upgrade_button = Button.new()
	shelter_upgrade_button.icon = UI_ICONS.get_icon("upgrade", 28, Color("#d8c47b"))
	shelter_upgrade_button.expand_icon = true
	shelter_upgrade_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shelter_upgrade_button.add_theme_font_override("font", FONT)
	shelter_upgrade_button.add_theme_font_size_override("font_size", 13)
	shelter_upgrade_button.pressed.connect(_upgrade_shelter_tier)
	stats_box.add_child(shelter_upgrade_button)
	scrap_gain_label = Label.new()
	scrap_gain_label.add_theme_font_override("font", FONT)
	scrap_gain_label.add_theme_font_size_override("font_size", 14)
	scrap_gain_label.add_theme_color_override("font_color", Color("#f0d16f"))
	scrap_gain_label.modulate.a = 0.0
	stats_box.add_child(scrap_gain_label)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-220, -112)
	prompt_label.size = Vector2(440, 52)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", FONT)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(prompt_label)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-270, 24)
	status_label.size = Vector2(540, 58)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#b7f0d4"))
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(status_label)
	_build_merchant_arrival_notice(canvas)
	interact_button = Button.new()
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-154, -142)
	interact_button.size = Vector2(118, 72)
	interact_button.text = "상호작용"
	interact_button.icon = UI_ICONS.get_icon("interact", 32, Color("#dce8e1"))
	interact_button.expand_icon = true
	interact_button.add_theme_font_override("font", FONT)
	interact_button.add_theme_font_size_override("font_size", 17)
	if not DisplayServer.is_touchscreen_available():
		interact_button.pressed.connect(_interact)
	canvas.add_child(interact_button)
	dash_button = Button.new()
	dash_button.name = "DashButton"
	dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_button.position = Vector2(-284, -142)
	dash_button.size = Vector2(118, 72)
	dash_button.text = "대시"
	dash_button.icon = UI_ICONS.get_icon("dash", 32, Color("#d8e5de"))
	dash_button.expand_icon = true
	dash_button.add_theme_font_override("font", FONT)
	dash_button.add_theme_font_size_override("font_size", 17)
	if not DisplayServer.is_touchscreen_available():
		dash_button.pressed.connect(_try_start_roll)
	dash_button.visible = DisplayServer.is_touchscreen_available()
	canvas.add_child(dash_button)
	inventory_ui = INVENTORY_UI_SCRIPT.new()
	inventory_ui.name = "InventoryUI"
	canvas.add_child(inventory_ui)
	inventory_ui.call("setup", FONT, WEAPON_VISUAL_CATALOG.get_weapon_texture(GameState.equipped_weapon_id), AMMO_TEXTURE, {
		"rubber_gasket": RUBBER_GASKET_TEXTURE,
		"scope_lens": SCOPE_LENS_TEXTURE,
		"magazine_spring": MAGAZINE_SPRING_TEXTURE,
	}, WEAPON_VISUAL_CATALOG.get_inventory_textures())
	inventory_ui.connect("open_state_changed", _on_inventory_open_state_changed)
	inventory_ui.connect("weapon_mods_changed", _on_inventory_weapon_mods_changed)
	inventory_ui.connect("weapon_equipped", _on_inventory_weapon_equipped)
	inventory_ui.connect("weapon_unequipped", _on_inventory_weapon_unequipped)
	inventory_ui.connect("equipment_changed", _on_inventory_equipment_changed)
	_refresh_inventory_state()
	roll_cooldown_indicator = ROLL_COOLDOWN_INDICATOR_SCRIPT.new() as Control
	roll_cooldown_indicator.name = "ShelterRollCooldownIndicator"
	canvas.add_child(roll_cooldown_indicator)
	_build_touch_stick(canvas)


func _build_merchant_arrival_notice(canvas: CanvasLayer) -> void:
	merchant_notice_panel = PanelContainer.new()
	merchant_notice_panel.name = "MerchantArrivalNotice"
	merchant_notice_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	merchant_notice_panel.offset_left = -406
	merchant_notice_panel.offset_top = 22
	merchant_notice_panel.offset_right = -24
	merchant_notice_panel.offset_bottom = 94
	merchant_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_notice_panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.018, 0.027, 0.026, 0.96), Color("#c9a65d"), 7)
	)
	canvas.add_child(merchant_notice_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	merchant_notice_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.texture = _merchant_face_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var text_box := VBoxContainer.new()
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title := Label.new()
	title.text = "하수구 방문자"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#efd58d"))
	text_box.add_child(title)
	var body := Label.new()
	body.text = "낯선 행상인이 문을 두드리고 있습니다."
	body.add_theme_font_override("font", FONT)
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("#c8d7cf"))
	text_box.add_child(body)
	merchant_notice_panel.visible = false


func _set_merchant_notice_visible(value: bool) -> void:
	if is_instance_valid(merchant_notice_panel):
		merchant_notice_panel.visible = value


func _open_merchant_arrival_dialog() -> void:
	if merchant_ui_open:
		return
	merchant_ui_open = true
	touch_vector = Vector2.ZERO
	roll_active = false
	_set_motion_state("idle")
	merchant_ui_layer = CanvasLayer.new()
	merchant_ui_layer.name = "MerchantArrivalLayer"
	merchant_ui_layer.layer = 60
	add_child(merchant_ui_layer)

	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	merchant_ui_layer.add_child(root_control)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.008, 0.01, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MerchantArrivalCard"
	panel.custom_minimum_size = Vector2(580, 286)
	panel.add_theme_stylebox_override("panel", _rounded_panel_style(Color(0.025, 0.034, 0.031, 0.99), Color("#c6a45c"), 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "낯선 방문자"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ead69c"))
	box.add_child(title)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(116, 116)
	portrait.texture = _merchant_face_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(portrait)
	var dialogue_box := VBoxContainer.new()
	dialogue_box.custom_minimum_size = Vector2(360, 116)
	dialogue_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dialogue_box.add_theme_constant_override("separation", 7)
	dialogue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(dialogue_box)
	var location := Label.new()
	location.text = "하수구 입구  ·  행상인"
	location.add_theme_font_override("font", FONT)
	location.add_theme_font_size_override("font_size", 13)
	location.add_theme_color_override("font_color", Color("#a8bcb1"))
	dialogue_box.add_child(location)
	var line := Label.new()
	line.text = "“문 좀 열어주실 수 있겠냥?”\n물건을 챙겨 온 행상인이 입장을 기다립니다."
	line.add_theme_font_override("font", FONT)
	line.add_theme_font_size_override("font_size", 17)
	line.add_theme_color_override("font_color", Color("#ebe5d4"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_box.add_child(line)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_END
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	var decline := _merchant_button("돌려보낸다", false, "close")
	decline.custom_minimum_size = Vector2(150, 44)
	decline.pressed.connect(_decline_merchant)
	choices.add_child(decline)
	var accept := _merchant_button("들어오게 한다", true, "resident")
	accept.custom_minimum_size = Vector2(150, 44)
	accept.pressed.connect(_accept_merchant)
	choices.add_child(accept)


func _accept_merchant() -> void:
	GameState.accept_merchant_visit()
	if is_instance_valid(merchant_waiting_marker):
		merchant_waiting_marker.queue_free()
	merchant_waiting_marker = null
	_set_merchant_notice_visible(false)
	_spawn_merchant()
	_close_merchant_ui()
	_show_status("행상인이 쉘터에 들어왔습니다. 말을 걸어 거래할 수 있습니다.")


func _decline_merchant() -> void:
	GameState.decline_merchant_visit()
	if is_instance_valid(merchant_waiting_marker):
		merchant_waiting_marker.queue_free()
	merchant_waiting_marker = null
	_set_merchant_notice_visible(false)
	_close_merchant_ui()
	_show_status("행상인을 돌려보냈습니다. 다음 복귀 때 다시 찾아올 수도 있습니다.")


func _open_merchant_shop() -> void:
	if merchant_ui_open:
		return
	merchant_ui_open = true
	touch_vector = Vector2.ZERO
	roll_active = false
	_set_motion_state("idle")
	merchant_shop_mode = "buy"
	merchant_ui_layer = CanvasLayer.new()
	merchant_ui_layer.name = "MerchantShopLayer"
	merchant_ui_layer.layer = 60
	add_child(merchant_ui_layer)

	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	merchant_ui_layer.add_child(root_control)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.009, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var panel := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var shop_width := minf(820.0, maxf(520.0, viewport_size.x - 28.0))
	var shop_height := minf(620.0, maxf(420.0, viewport_size.y - 28.0))
	panel.custom_minimum_size = Vector2(shop_width, shop_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.033, 0.031, 0.99), Color("#8f7950")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(74, 74)
	portrait.texture = _merchant_face_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(title_box)
	var title := Label.new()
	title.text = "떠돌이 행상인의 교환 가방"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#ead69c"))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "고철과 물자를 교환합니다. 가격은 한 묶음 기준입니다."
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#9baaa3"))
	title_box.add_child(subtitle)
	var currency_box := HBoxContainer.new()
	currency_box.add_theme_constant_override("separation", 12)
	header.add_child(currency_box)
	var scrap_chip := _currency_chip("scrap", "고철", Color("#d4d9d6"), 24, 112)
	var food_chip := _currency_chip("food", "통조림", Color("#e5b55b"), 24, 112)
	currency_box.add_child(scrap_chip)
	currency_box.add_child(food_chip)
	merchant_shop_currency_labels["scrap"] = scrap_chip.get_meta("value_label")
	merchant_shop_currency_labels["food"] = food_chip.get_meta("value_label")
	var close := _shelter_close_button()
	close.pressed.connect(_close_merchant_ui)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	merchant_buy_tab = _merchant_button("구매", true, "backpack")
	merchant_buy_tab.name = "MerchantBuyTab"
	merchant_buy_tab.pressed.connect(func() -> void: _set_merchant_shop_mode("buy"))
	_prepare_merchant_tab(merchant_buy_tab, "buy")
	tabs.add_child(merchant_buy_tab)
	merchant_sell_tab = _merchant_button("판매", false, "scrap")
	merchant_sell_tab.name = "MerchantSellTab"
	merchant_sell_tab.pressed.connect(func() -> void: _set_merchant_shop_mode("sell"))
	_prepare_merchant_tab(merchant_sell_tab, "sell")
	tabs.add_child(merchant_sell_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	merchant_shop_list = VBoxContainer.new()
	merchant_shop_list.custom_minimum_size.x = maxf(320.0, shop_width - 48.0)
	merchant_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	merchant_shop_list.add_theme_constant_override("separation", 8)
	scroll.add_child(merchant_shop_list)
	merchant_shop_message_label = Label.new()
	merchant_shop_message_label.custom_minimum_size.y = 30
	merchant_shop_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_shop_message_label.add_theme_font_override("font", FONT)
	merchant_shop_message_label.add_theme_font_size_override("font_size", 14)
	merchant_shop_message_label.add_theme_color_override("font_color", Color("#b8d9c9"))
	box.add_child(merchant_shop_message_label)
	_refresh_merchant_shop()


func _set_merchant_shop_mode(mode: String) -> void:
	merchant_shop_mode = mode
	merchant_shop_message_label.text = ""
	_refresh_merchant_shop()


func _refresh_merchant_shop() -> void:
	if merchant_shop_list == null:
		return
	for child in merchant_shop_list.get_children():
		merchant_shop_list.remove_child(child)
		child.queue_free()
	(merchant_shop_currency_labels.get("scrap") as Label).text = "고철  %d" % GameState.scrap
	(merchant_shop_currency_labels.get("food") as Label).text = "통조림  %d" % GameState.canned_food
	_update_merchant_tab_styles()
	var visible_good_count := 0
	for good_variant in MERCHANT_GOODS:
		var good: Dictionary = good_variant
		if merchant_shop_mode == "sell":
			var owned := _merchant_item_count(good)
			if owned <= 0 or int(good.get("sell_cans", 0)) <= 0:
				continue
		merchant_shop_list.add_child(_merchant_trade_row(good))
		visible_good_count += 1
	if visible_good_count == 0:
		var empty_label := Label.new()
		empty_label.name = "MerchantEmptyState"
		empty_label.custom_minimum_size = Vector2(0, 180)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.text = "판매할 수 있는 물품이 없습니다."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_override("font", FONT)
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color("#7f9088"))
		merchant_shop_list.add_child(empty_label)


func _prepare_merchant_tab(tab: Button, mode: String) -> void:
	tab.toggle_mode = true
	tab.custom_minimum_size = Vector2(150, 52)
	tab.set_meta("merchant_mode", mode)
	var indicator := ColorRect.new()
	indicator.name = "SelectedIndicator"
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	indicator.offset_left = 10
	indicator.offset_top = -4
	indicator.offset_right = -10
	indicator.offset_bottom = 0
	indicator.color = Color("#f0c96d")
	tab.add_child(indicator)


func _update_merchant_tab_styles() -> void:
	for tab in [merchant_buy_tab, merchant_sell_tab]:
		if tab == null:
			continue
		var mode := str(tab.get_meta("merchant_mode", ""))
		var selected := mode == merchant_shop_mode
		var accent_color := Color("#f0c96d") if mode == "buy" else Color("#85d3b0")
		tab.disabled = false
		tab.set_pressed_no_signal(selected)
		tab.text = ("구매" if mode == "buy" else "판매") + ("  선택됨" if selected else "")
		tab.icon = UI_ICONS.get_icon(
			"backpack" if mode == "buy" else "scrap",
			28,
			Color("#17201c") if selected else accent_color
		)
		tab.add_theme_color_override(
			"font_color",
			Color("#17201c") if selected else Color("#aebbb5")
		)
		tab.add_theme_color_override(
			"font_hover_color",
			Color("#f6efd9")
		)
		tab.add_theme_color_override(
			"font_pressed_color",
			Color("#17201c")
		)
		var selected_background := accent_color.darkened(0.12)
		var inactive_background := Color(0.025, 0.033, 0.032, 0.96)
		tab.add_theme_stylebox_override(
			"normal",
			_rounded_panel_style(
				selected_background if selected else inactive_background,
				accent_color if selected else Color("#46564f"),
				6
			)
		)
		tab.add_theme_stylebox_override(
			"pressed",
			_rounded_panel_style(selected_background, accent_color.lightened(0.16), 6)
		)
		tab.add_theme_stylebox_override(
			"hover",
			_rounded_panel_style(Color(0.095, 0.09, 0.055, 0.98), accent_color, 6)
		)
		tab.add_theme_stylebox_override(
			"hover_pressed",
			_rounded_panel_style(selected_background.lightened(0.04), accent_color.lightened(0.2), 6)
		)
		var indicator := tab.get_node_or_null("SelectedIndicator") as ColorRect
		if indicator:
			indicator.color = accent_color.lightened(0.12)
			indicator.visible = selected


func _merchant_trade_row(good: Dictionary) -> Button:
	var buying := merchant_shop_mode == "buy"
	var price := int(good["buy_price"] if buying else good.get("sell_cans", 0))
	var owned := _merchant_item_count(good)
	var action := "구매" if buying else "판매"
	var currency_icon := "scrap" if buying else "food"
	var currency_name := "고철" if buying else "통조림"
	var currency_color := Color("#d4d9d6") if buying else Color("#e5b55b")
	var can_trade := GameState.scrap >= price if buying else (price > 0 and owned >= int(good["amount"]))
	var button := _merchant_button("", false)
	button.name = "MerchantGood_%s" % str(good["id"])
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "%s %d개 %s" % [currency_name, price, action]
	button.add_theme_stylebox_override(
		"normal",
		_rounded_panel_style(Color(0.025, 0.033, 0.031, 0.97), Color("#50645b"), 6)
	)
	button.add_theme_stylebox_override(
		"hover",
		_rounded_panel_style(Color(0.085, 0.075, 0.045, 0.99), currency_color, 6)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_rounded_panel_style(Color(0.14, 0.11, 0.052, 1.0), currency_color.lightened(0.14), 6)
	)

	var row := HBoxContainer.new()
	row.name = "TradeRowContent"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 8
	row.offset_right = -12
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	button.add_child(row)

	var item_icon := TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.custom_minimum_size = Vector2(58, 58)
	var icon_path := str(good.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path) as Texture2D
	else:
		item_icon.texture = _merchant_good_fallback_icon(good)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(item_icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	var title := Label.new()
	title.text = "%s  ×%d" % [str(good["title"]), int(good["amount"])]
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#eee6d2"))
	details.add_child(title)
	var description := Label.new()
	description.text = str(good["description"])
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_font_override("font", FONT)
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color("#93a29b"))
	details.add_child(description)

	row.add_child(_merchant_trade_chip(
		"backpack",
		"보유",
		owned,
		Color("#a9bbb2"),
		"OwnedChip"
	))
	row.add_child(_merchant_trade_chip(
		currency_icon,
		"필요" if buying else "받음",
		price,
		currency_color if can_trade else Color("#d9786c"),
		"PriceChip"
	))
	var action_label := Label.new()
	action_label.name = "TradeAction"
	action_label.custom_minimum_size.x = 58
	action_label.text = "%s\n›" % action
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_font_override("font", FONT)
	action_label.add_theme_font_size_override("font_size", 14)
	action_label.add_theme_color_override(
		"font_color",
		currency_color if can_trade else Color("#6f7b75")
	)
	row.add_child(action_label)
	button.disabled = not can_trade
	button.pressed.connect(func() -> void: _trade_merchant_good(good, buying))
	return button


func _merchant_trade_chip(
	icon_name: String,
	caption: String,
	value: int,
	color: Color,
	node_name: String
) -> VBoxContainer:
	var chip := VBoxContainer.new()
	chip.name = node_name
	chip.custom_minimum_size.x = 88
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_override("font", FONT)
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.add_theme_color_override("font_color", Color("#84938c"))
	chip.add_child(caption_label)
	var value_row := HBoxContainer.new()
	value_row.alignment = BoxContainer.ALIGNMENT_CENTER
	value_row.add_theme_constant_override("separation", 5)
	chip.add_child(value_row)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % node_name
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture = UI_ICONS.get_icon(icon_name, 24, color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_row.add_child(icon)
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_override("font", FONT)
	value_label.add_theme_font_size_override("font_size", 17)
	value_label.add_theme_color_override("font_color", color)
	value_row.add_child(value_label)
	return chip


func _trade_merchant_good(good: Dictionary, buying: bool) -> void:
	var price := int(good["buy_price"] if buying else good.get("sell_cans", 0))
	var amount := int(good["amount"])
	if buying:
		if GameState.scrap < price:
			merchant_shop_message_label.text = "고철이 부족합니다."
			return
		GameState.scrap -= price
		_add_merchant_item(good, amount)
		merchant_shop_message_label.text = "%s을(를) 구매했습니다." % str(good["title"])
	else:
		if price <= 0:
			merchant_shop_message_label.text = "이 물건은 매입하지 않습니다."
			return
		if _merchant_item_count(good) < amount:
			merchant_shop_message_label.text = "판매할 물건이 부족합니다."
			return
		_add_merchant_item(good, -amount)
		GameState.canned_food += price
		merchant_shop_message_label.text = "%s을(를) 판매하고 통조림 %d개를 받았습니다." % [str(good["title"]), price]
	_update_stats()
	_refresh_merchant_shop()


func _merchant_item_count(good: Dictionary) -> int:
	match str(good["type"]):
		"ammo":
			return GameState.get_ammo_count(str(good["id"]))
		"food":
			return GameState.canned_food
		"component":
			return GameState.get_mod_component_count(str(good["id"]))
	return 0


func _add_merchant_item(good: Dictionary, amount: int) -> void:
	match str(good["type"]):
		"ammo":
			var ammo_id := str(good["id"])
			GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + amount)
		"food":
			GameState.canned_food = maxi(0, GameState.canned_food + amount)
		"component":
			GameState.add_mod_component(str(good["id"]), amount)


func _close_merchant_ui() -> void:
	merchant_ui_open = false
	if is_instance_valid(merchant_ui_layer):
		merchant_ui_layer.queue_free()
	merchant_ui_layer = null
	merchant_shop_list = null
	merchant_shop_currency_labels.clear()
	merchant_shop_message_label = null
	merchant_buy_tab = null
	merchant_sell_tab = null


func _merchant_good_fallback_icon(good: Dictionary) -> Texture2D:
	match str(good.get("type", "")):
		"ammo":
			return UI_ICONS.get_icon("ammo", 48, Color("#d7c16d"))
		"food":
			return UI_ICONS.get_icon("food", 48, Color("#e5b55b"))
		"component":
			return UI_ICONS.get_icon("mod", 48, Color("#84cbb9"))
	return UI_ICONS.get_icon("all", 48, Color("#aebdb5"))


func _currency_chip(icon_name: String, title: String, color: Color, icon_size: int, minimum_width: float) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.custom_minimum_size.x = minimum_width
	chip.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % title
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.texture = UI_ICONS.get_icon(icon_name, icon_size, color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var value_label := Label.new()
	value_label.name = "%sValue" % title
	value_label.text = title
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", FONT)
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", color)
	chip.add_child(value_label)
	chip.set_meta("value_label", value_label)
	return chip


func _merchant_button(text: String, accent: bool, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 28, Color("#e8dfcb"))
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#f0eadb"))
	var background := Color(0.12, 0.1, 0.055, 0.98) if accent else Color(0.055, 0.064, 0.062, 0.96)
	var border := Color("#d2ad5e") if accent else Color("#71857b")
	button.add_theme_stylebox_override("normal", _rounded_panel_style(background, border, 6))
	button.add_theme_stylebox_override("hover", _rounded_panel_style(Color(0.16, 0.13, 0.07, 1.0), Color("#f0cc77"), 6))
	button.add_theme_stylebox_override("disabled", _rounded_panel_style(Color(0.03, 0.035, 0.034, 0.72), Color(0.35, 0.4, 0.38, 0.3), 6))
	return button


func _shelter_close_button() -> Button:
	var button := _merchant_button("", false, "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(40, 40)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#e8dfcb"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _rounded_panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := _panel_style(background, border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_top = 9
	style.content_margin_right = 12
	style.content_margin_bottom = 9
	return style


func _build_touch_stick(canvas: CanvasLayer) -> void:
	touch_stick = Control.new()
	touch_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	touch_stick.position = Vector2(34, -160)
	touch_stick.size = Vector2(128, 128)
	touch_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(touch_stick)
	var ring := ColorRect.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.color = Color(0.35, 0.45, 0.42, 0.28)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_stick.add_child(ring)
	touch_knob = ColorRect.new()
	touch_knob.position = Vector2(40, 40)
	touch_knob.size = Vector2(48, 48)
	touch_knob.color = Color(0.65, 0.85, 0.75, 0.58)
	touch_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_stick.add_child(touch_knob)
	touch_stick.visible = DisplayServer.is_touchscreen_available()


func _update_nearby_station() -> void:
	if merchant_ui_open:
		interact_button.visible = false
		prompt_label.visible = false
		return
	var player_ground := Vector2(player.position.x, player.position.z)
	var nearest := ""
	var nearest_distance := INF
	var nearest_module: Node3D
	var exit_station := _pipe_exit_station()
	if GameState.merchant_status == "waiting":
		var waiting_distance := player_ground.distance_to(exit_station["position"])
		if waiting_distance <= float(exit_station["radius"]) + 0.35:
			nearest = "merchant_waiting"
			nearest_distance = -1.0
	if GameState.merchant_status == "inside" and is_instance_valid(merchant):
		var merchant_distance := player.global_position.distance_to(merchant.global_position)
		if merchant_distance <= 2.15 and merchant_distance < nearest_distance:
			nearest = "merchant_shop"
			nearest_distance = merchant_distance
	var exit_distance := player_ground.distance_to(exit_station["position"])
	if exit_distance <= float(exit_station["radius"]) and exit_distance < nearest_distance:
		nearest = "pipe_exit"
		nearest_distance = exit_distance
	for node in get_tree().get_nodes_in_group("shelter_module"):
		if not (node is Node3D):
			continue
		var module := node as Node3D
		var module_radius := float(module.call("get_interaction_radius")) if module.has_method("get_interaction_radius") else 1.5
		var module_distance := player.global_position.distance_to(module.global_position)
		if module_distance <= module_radius and module_distance < nearest_distance:
			nearest = "module"
			nearest_distance = module_distance
			nearest_module = module
	if current_module != nearest_module:
		if is_instance_valid(current_module) and current_module.has_method("set_interaction_focus"):
			current_module.call("set_interaction_focus", false)
		current_module = nearest_module
		if is_instance_valid(current_module) and current_module.has_method("set_interaction_focus"):
			current_module.call("set_interaction_focus", true)
	current_station = nearest
	interact_button.visible = not current_station.is_empty()
	prompt_label.visible = not current_station.is_empty()
	interact_button.text = "상호작용"
	interact_button.icon = UI_ICONS.get_icon("interact", 32, Color("#dce8e1"))
	if current_station.is_empty():
		prompt_label.text = ""
	elif current_station == "module" and is_instance_valid(current_module):
		prompt_label.text = "[E]  %s" % str(current_module.call("get_interaction_prompt"))
		interact_button.text = "사용"
		var module_kind := str(current_module.get_meta("module_kind", ""))
		var interaction_icon := "workbench"
		if module_kind == "catnip_scraper":
			interaction_icon = "catnip"
		elif module_kind == "scratcher_bank":
			interaction_icon = "scrap"
		elif module_kind == "training":
			interaction_icon = "fitness"
		elif module_kind == "storage":
			interaction_icon = "secure"
		interact_button.icon = UI_ICONS.get_icon(interaction_icon, 32, Color("#dce8e1"))
	elif current_station == "merchant_waiting":
		prompt_label.text = "[E]  누군가와 대화"
		interact_button.text = "대화"
		interact_button.icon = UI_ICONS.get_icon("resident", 32, Color("#e4c874"))
	elif current_station == "merchant_shop":
		prompt_label.text = "[E]  행상인과 거래하기"
		interact_button.text = "거래"
		interact_button.icon = UI_ICONS.get_icon("backpack", 32, Color("#e4c874"))
	else:
		prompt_label.text = "[E]  %s" % _pipe_exit_station()["label"]
		interact_button.text = "탐색"
		interact_button.icon = UI_ICONS.get_icon("upgrade", 32, Color("#dce8e1"))


func _interact() -> void:
	if merchant_ui_open:
		return
	match current_station:
		"module":
			if is_instance_valid(current_module) and current_module.has_method("interact"):
				_show_status(str(current_module.call("interact")))
		"pipe_exit":
			_open_raid_zone_select()
		"merchant_waiting":
			_open_merchant_arrival_dialog()
		"merchant_shop":
			_open_merchant_shop()
	_update_stats()


func _update_stats() -> void:
	GameState._ensure_resident_records()
	stats_label.text = "SHELTER 01  ·  Tier %d  ·  Lv.%d\n체력 %d/%d   주민 %d/%d\n꾹꾹이 %d/%d   스크래핑 %d/%d" % [
		GameState.shelter_tier,
		GameState.player_level,
		GameState.player_health,
		GameState.get_max_health(),
		GameState.rescued_workers,
		GameState.get_resident_capacity(),
		GameState.get_active_scratcher_workers(),
		GameState.get_scratcher_worker_slots(),
		GameState.get_active_catnip_workers(),
		GameState.get_catnip_worker_slots(),
	]
	if shelter_currency_labels.has("scrap"):
		(shelter_currency_labels["scrap"] as Label).text = "고철  %d" % GameState.scrap
		(shelter_currency_labels["catnip"] as Label).text = "캣닢  %.1f" % GameState.catnip
		(shelter_currency_labels["food"] as Label).text = "통조림  %d" % GameState.canned_food
		(shelter_currency_labels["churu"] as Label).text = "츄르  %d" % GameState.churu
	if shelter_upgrade_button:
		var cost := GameState.get_shelter_upgrade_cost()
		if cost.is_empty():
			shelter_upgrade_button.text = "쉘터 최고 Tier"
			shelter_upgrade_button.disabled = true
		else:
			var scrap_cost := int(cost.get("scrap", 0))
			var churu_cost := int(cost.get("churu", 0))
			shelter_upgrade_button.text = "Tier %d 확장  ·  고철 %d + 츄르 %d" % [GameState.shelter_tier + 1, scrap_cost, churu_cost]
			shelter_upgrade_button.disabled = GameState.scrap < scrap_cost or GameState.churu < churu_cost
func _refresh_inventory_state() -> void:
	if inventory_ui == null:
		return
	var weapon_id := str(GameState.equipped_weapon_id)
	var weapon_definition := WEAPON_SYSTEM.get_weapon(weapon_id)
	var stored_weapons := 0
	for count in GameState.weapon_inventory.values():
		stored_weapons += int(count)
	if bool(GameState.has_ak):
		stored_weapons = maxi(0, stored_weapons - 1)
	inventory_ui.call("set_weapon_texture", WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id))
	inventory_ui.call("update_state",
		bool(GameState.has_ak) and GameState.get_weapon_count(weapon_id) > 0,
		int(GameState.magazine_ammo),
		int(GameState.get_ammo_count(GameState.equipped_ammo_id)),
		str(weapon_definition.get("display_name", weapon_id.to_upper())),
		int(weapon_definition.get("magazine_size", 30)),
		float(GameState.weapon_durability),
		GameState.equipped_weapon_mods,
		int(GameState.canned_food),
		stored_weapons,
		GameState.mod_component_inventory,
		int(GameState.rescued_workers),
		float(GameState.fatigue)
	)


func _on_inventory_open_state_changed(is_open: bool) -> void:
	if is_open:
		_refresh_inventory_state()
		touch_vector = Vector2.ZERO
		player.velocity = Vector3.ZERO
		_set_motion_state("idle")


func _on_inventory_weapon_mods_changed() -> void:
	GameState.save_persistent_state()
	_refresh_inventory_state()


func _on_inventory_weapon_equipped(weapon_id: String) -> void:
	if bool(GameState.has_ak) and weapon_id == str(GameState.equipped_weapon_id):
		return
	var previous_ammo_id := str(GameState.equipped_ammo_id)
	if bool(GameState.has_ak) and int(GameState.magazine_ammo) > 0 and not previous_ammo_id.is_empty():
		GameState.set_ammo_count(previous_ammo_id, GameState.get_ammo_count(previous_ammo_id) + int(GameState.magazine_ammo))
	if not GameState.equip_weapon(weapon_id):
		return
	GameState.save_persistent_state()
	_refresh_inventory_state()


func _on_inventory_weapon_unequipped() -> void:
	if not bool(GameState.has_ak):
		return
	var ammo_id := str(GameState.equipped_ammo_id)
	if int(GameState.magazine_ammo) > 0 and not ammo_id.is_empty():
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + int(GameState.magazine_ammo))
	GameState.magazine_ammo = 0
	GameState.reserve_ammo = GameState.get_ammo_count(ammo_id)
	GameState.unequip_weapon()
	GameState.save_persistent_state()
	_refresh_inventory_state()


func _on_inventory_equipment_changed() -> void:
	GameState.save_persistent_state()
	_refresh_inventory_state()


func _upgrade_shelter_tier() -> void:
	if GameState.try_upgrade_shelter_tier():
		_show_status("쉘터 Tier %d 확장 완료 · 수용 %d · 꾹꾹이 %d · 스크래핑 %d" % [
			GameState.shelter_tier,
			GameState.get_resident_capacity(),
			GameState.get_scratcher_worker_slots(),
			GameState.get_catnip_worker_slots(),
		])
		GameState.save_persistent_state()
		get_tree().reload_current_scene()
		return
	_update_stats()


func _update_live_shelter_income(delta: float) -> void:
	var gained := GameState.tick_shelter_live(delta)
	shelter_save_time += delta
	if shelter_save_time >= 10.0:
		shelter_save_time = 0.0
		GameState.save_persistent_state()
	shelter_stats_refresh_time += delta
	if shelter_stats_refresh_time >= 0.5:
		shelter_stats_refresh_time = 0.0
		_update_stats()
		_refresh_resident_production_feedback()
	if gained > 0 and scrap_gain_label:
		scrap_gain_label.text = "+%d 고철   %.2f/s" % [gained, GameState.get_scrap_per_second()]
		scrap_gain_label.modulate.a = 1.0


func _open_raid_zone_select() -> void:
	if raid_zone_ui_open:
		return
	raid_zone_ui_open = true
	touch_vector = Vector2.ZERO
	player.velocity = Vector3.ZERO
	_set_motion_state("idle")
	raid_zone_ui_layer = CanvasLayer.new()
	raid_zone_ui_layer.name = "RaidZoneSelectLayer"
	raid_zone_ui_layer.layer = 70
	add_child(raid_zone_ui_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.009, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	raid_zone_ui_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raid_zone_ui_layer.add_child(center)
	var panel := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(900.0, maxf(500.0, viewport_size.x - 28.0))
	var panel_height := minf(650.0, maxf(380.0, viewport_size.y - 28.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.033, 0.031, 0.99), Color("#8f7950")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "도시 탐색 구역 선택"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ead69c"))
	header.add_child(title)
	var close := _shelter_close_button()
	close.pressed.connect(_close_raid_zone_select)
	header.add_child(close)
	var subtitle := Label.new()
	subtitle.text = "쉘터 Tier가 오르면 더 위험한 서울 구역과 보스 보상이 해금됩니다."
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#aebdb5"))
	box.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = maxf(320.0, panel_width - 56.0)
	list.add_theme_constant_override("separation", 9)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for zone_id in GameState.get_raid_zone_ids():
		list.add_child(_build_raid_zone_row(zone_id))


func _build_raid_zone_row(zone_id: String) -> Control:
	var zone := GameState.get_raid_zone(zone_id)
	var unlocked := GameState.is_raid_zone_unlocked(zone_id)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _panel_style(
		Color(0.055, 0.063, 0.061, 0.94) if unlocked else Color(0.025, 0.028, 0.03, 0.72),
		Color("#667e70") if unlocked else Color(0.34, 0.36, 0.36, 0.45)
	))
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 12)
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	var zone_icon := TextureRect.new()
	zone_icon.custom_minimum_size = Vector2(56, 56)
	zone_icon.texture = UI_ICONS.get_icon("raid", 56, Color("#d3b86b") if unlocked else Color("#5f6964"))
	zone_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zone_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(zone_icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info)
	var name_label := Label.new()
	name_label.text = "%s  ·  위협 %d%%" % [str(zone.get("name", zone_id)), roundi(float(zone.get("threat", 0.0)) * 100.0)]
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color("#f0e6c8") if unlocked else Color("#737b77"))
	info.add_child(name_label)
	var description := Label.new()
	description.text = str(zone.get("description", ""))
	description.add_theme_font_override("font", FONT)
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color("#b7c8bf") if unlocked else Color("#676d69"))
	info.add_child(description)
	var reward := Label.new()
	reward.text = "주요 보상: %s" % str(zone.get("reward", "-"))
	reward.add_theme_font_override("font", FONT)
	reward.add_theme_font_size_override("font_size", 13)
	reward.add_theme_color_override("font_color", Color("#d3b86b") if unlocked else Color("#67645b"))
	info.add_child(reward)
	var launch := Button.new()
	launch.custom_minimum_size = Vector2(130, 58)
	launch.text = "출정" if unlocked else "Tier %d 필요" % int(zone.get("required_tier", 1))
	launch.icon = UI_ICONS.get_icon("upgrade" if not unlocked else "raid", 30, Color("#e6d8ae"))
	launch.expand_icon = true
	launch.disabled = not unlocked
	launch.add_theme_font_override("font", FONT)
	launch.add_theme_font_size_override("font_size", 15)
	launch.pressed.connect(func() -> void: _launch_raid_zone(zone_id))
	content.add_child(launch)
	return row


func _launch_raid_zone(zone_id: String) -> void:
	if not GameState.is_raid_zone_unlocked(zone_id):
		return
	_open_raid_loadout_confirmation(zone_id)


func _open_raid_loadout_confirmation(zone_id: String) -> void:
	if raid_loadout_ui_open:
		return
	raid_loadout_ui_open = true
	raid_loadout_ui_layer = CanvasLayer.new()
	raid_loadout_ui_layer.name = "RaidLoadoutConfirmLayer"
	raid_loadout_ui_layer.layer = 72
	add_child(raid_loadout_ui_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.006, 0.007, 0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	raid_loadout_ui_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raid_loadout_ui_layer.add_child(center)
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 800.0
	var panel := PanelContainer.new()
	panel.name = "RaidLoadoutConfirmPanel"
	panel.custom_minimum_size = Vector2(
		minf(900.0, viewport_size.x - 24.0),
		minf(680.0, viewport_size.y - 24.0)
	)
	panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.018, 0.026, 0.026, 0.99), Color("#b79a55"), 7)
	)
	center.add_child(panel)
	var margin := MarginContainer.new()
	var inset := 14 if narrow else 24
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, inset)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_raid_loadout_label("출전 장비 확정", 28, Color("#ead69c")))
	var zone := GameState.get_raid_zone(zone_id)
	heading.add_child(_raid_loadout_label(
		"%s · 사망하면 아래 휴대품은 분실 장비로 남습니다." % str(zone.get("name", zone_id)),
		14,
		Color("#b6c5bd")
	))
	var close := _shelter_close_button()
	close.pressed.connect(_close_raid_loadout_confirmation)
	header.add_child(close)

	var manifest := GameState.build_raid_loadout_manifest(zone_id)
	var summary_scroll := ScrollContainer.new()
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(summary_scroll)
	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = maxf(300.0, panel.custom_minimum_size.x - inset * 2.0 - 16.0)
	summary.add_theme_constant_override("separation", 12)
	summary_scroll.add_child(summary)
	var cards := GridContainer.new()
	cards.columns = 1 if narrow else 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	summary.add_child(cards)
	var weapon_id := str(manifest.get("weapon_id", ""))
	var weapon_name := "맨손" if weapon_id.is_empty() else str(WEAPON_SYSTEM.get_weapon(weapon_id).get("display_name", weapon_id))
	cards.add_child(_raid_loadout_card(
		"주무기",
		"%s · 장전 %d발" % [weapon_name, int(manifest.get("magazine_ammo", 0))],
		"weapon",
		Color("#d9bd70") if not weapon_id.is_empty() else Color("#d77f72")
	))
	cards.add_child(_raid_loadout_card(
		"탄약과 치료",
		"예비 탄약 %d발 · 구급약 %d개" % [
			int(manifest.get("ammo_count", 0)),
			int(manifest.get("medkits", 0)),
		],
		"ammo",
		Color("#86c8ae")
	))
	cards.add_child(_raid_loadout_card(
		"착용 장비",
		"%s · %s · %s" % [
			_equipment_loadout_name(str(manifest.get("body_armor", "")), "몸 방어구 없음"),
			_equipment_loadout_name(str(manifest.get("head_armor", "")), "머리 방어구 없음"),
			_equipment_loadout_name(str(manifest.get("footwear", "")), "신발 없음"),
		],
		"armor",
		Color("#8db6ce")
	))
	cards.add_child(_raid_loadout_card(
		"레이드 가방",
		"무기 %d · 장비 %d · 부품 %d · 통조림 %d" % [
			int(manifest.get("weapon_count", 0)),
			int(manifest.get("equipment_count", 0)),
			int(manifest.get("component_count", 0)) + int(manifest.get("mod_count", 0)),
			int(manifest.get("canned_food", 0)),
		],
		"loot",
		Color("#c4b58a")
	))
	cards.add_child(_raid_loadout_card(
		"안전 창고",
		"%d / %d칸 · 창고 물품은 사망해도 보존" % [
			int(manifest.get("storage_used", 0)),
			int(manifest.get("storage_capacity", 0)),
		],
		"secure",
		Color("#77cba5")
	))
	var recovery_active := bool(manifest.get("corpse_recovery", false))
	cards.add_child(_raid_loadout_card(
		"회수 작전",
		"이 구역에 분실 장비가 표시됩니다." if recovery_active else "현재 회수할 분실 장비 없음",
		"map",
		Color("#ef9858") if recovery_active else Color("#778681")
	))
	var warning := _raid_loadout_label(
		"휴대품과 현장에서 얻은 전리품은 사망 시 모두 잃습니다. 출정 전에 보존할 물품은 창고에 넣으십시오.",
		14,
		Color("#f0aa82")
	)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 42
	summary.add_child(warning)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var storage_button := _merchant_button("창고 정리", false, "secure")
	storage_button.custom_minimum_size = Vector2(150, 48)
	storage_button.pressed.connect(_open_storage_from_raid_loadout)
	actions.add_child(storage_button)
	var back_button := _merchant_button("구역 다시 선택", false, "back")
	back_button.custom_minimum_size = Vector2(170, 48)
	back_button.pressed.connect(_close_raid_loadout_confirmation)
	actions.add_child(back_button)
	var confirm_button := _merchant_button("이 장비로 출정", true, "raid")
	confirm_button.name = "ConfirmRaidLoadoutButton"
	confirm_button.custom_minimum_size = Vector2(190, 48)
	confirm_button.pressed.connect(_confirm_launch_raid_zone.bind(zone_id))
	actions.add_child(confirm_button)


func _raid_loadout_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _raid_loadout_card(title: String, value: String, icon_name: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.035, 0.046, 0.045, 0.96), accent.darkened(0.35), 6)
	)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 11)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.texture = UI_ICONS.get_icon(icon_name, 42, accent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	labels.add_child(_raid_loadout_label(title, 12, Color("#93a49e")))
	var value_label := _raid_loadout_label(value, 15, Color("#e7ece8"))
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(value_label)
	return panel


func _equipment_loadout_name(equipment_id: String, fallback: String) -> String:
	if equipment_id.is_empty():
		return fallback
	return str(GameState.get_equipment_definition(equipment_id).get("display_name", equipment_id))


func _open_storage_from_raid_loadout() -> void:
	_close_raid_loadout_confirmation()
	_close_raid_zone_select()
	var modules := get_tree().get_nodes_in_group("shelter_storage")
	if not modules.is_empty() and is_instance_valid(modules[0]):
		modules[0].call("interact")


func _confirm_launch_raid_zone(zone_id: String) -> void:
	if not GameState.select_raid_zone(zone_id):
		return
	GameState.confirm_raid_loadout(zone_id)
	GameState.start_new_raid()
	GameState.returning_from_shelter = true
	GameState.save_persistent_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _close_raid_loadout_confirmation() -> void:
	raid_loadout_ui_open = false
	if is_instance_valid(raid_loadout_ui_layer):
		raid_loadout_ui_layer.queue_free()
	raid_loadout_ui_layer = null


func _close_raid_zone_select() -> void:
	if raid_loadout_ui_open:
		_close_raid_loadout_confirmation()
	raid_zone_ui_open = false
	if is_instance_valid(raid_zone_ui_layer):
		raid_zone_ui_layer.queue_free()
	raid_zone_ui_layer = null


func _build_module_plate(parent: Node3D, position: Vector3, slot_index: int, rotation_y := 0.0) -> void:
	var slot := Node3D.new()
	slot.name = "BedSlot%02d" % slot_index
	slot.position = position + Vector3(0.0, 0.028, 0.0)
	slot.rotation_degrees.y = rotation_y
	slot.add_to_group("shelter_module_slot")
	slot.set_meta("slot_index", slot_index)
	slot.set_meta("module_kind", "bed")
	slot.set_meta("replaceable", true)
	parent.add_child(slot)
	var plate_material := _material(Color(0.035, 0.075, 0.09, 0.82))
	plate_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_plane("ModuleFloorPlate", Vector3.ZERO, BED_MODULE_PLATE_SIZE, plate_material, slot)
	var border_material := _material(Color(0.14, 0.5, 0.58, 0.75))
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_visual_box("NorthBorder", Vector3(0, 0.025, -BED_MODULE_PLATE_SIZE.y * 0.5), Vector3(BED_MODULE_PLATE_SIZE.x, 0.045, 0.045), border_material, slot)
	_add_visual_box("SouthBorder", Vector3(0, 0.025, BED_MODULE_PLATE_SIZE.y * 0.5), Vector3(BED_MODULE_PLATE_SIZE.x, 0.045, 0.045), border_material, slot)
	_add_visual_box("WestBorder", Vector3(-BED_MODULE_PLATE_SIZE.x * 0.5, 0.025, 0), Vector3(0.045, 0.045, BED_MODULE_PLATE_SIZE.y), border_material, slot)
	_add_visual_box("EastBorder", Vector3(BED_MODULE_PLATE_SIZE.x * 0.5, 0.025, 0), Vector3(0.045, 0.045, BED_MODULE_PLATE_SIZE.y), border_material, slot)


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.modulate.a = 1.0


func _build_offline_status_text(progress: Dictionary) -> String:
	var scrap_gain := int(progress.get("scrap", 0))
	var catnip_gain := float(progress.get("catnip", 0.0))
	var repair_gain := float(progress.get("repair", 0.0))
	if scrap_gain > 0 or catnip_gain > 0.01 or repair_gain > 0.01:
		return "오프라인 정산 · 고철 +%d · 캣닢 +%.1f · 내구도 +%.1f%%" % [scrap_gain, catnip_gain, repair_gain]
	return "쉘터에 복귀했습니다. 생산기에 주민을 배치할 수 있습니다."


func _update_facing(screen_direction: Vector2) -> void:
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var index := int(round(angle / 45.0)) % 8
	var next_facing: String = SCREEN_DIRECTION_NAMES[index]
	if facing != next_facing:
		facing = next_facing
		_play_directional_animation()


func _set_motion_state(next_state: String) -> void:
	if motion_state == next_state:
		return
	motion_state = next_state
	_play_directional_animation()


func _play_directional_animation() -> void:
	if survivor == null:
		return
	survivor.flip_h = false
	survivor.play("%s_%s" % [motion_state, facing])


func _create_cat_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in SCREEN_DIRECTION_NAMES:
		var state_prefix: String = CAT_DIRECTION_STATES[direction_name]
		for state in ["idle", "walk"]:
			var animation_name := "%s_%s" % [state, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 4.0 if state == "idle" else 8.0)
			for frame_index in CAT_FRAME_COUNT:
				var texture_path := "%s/%s_%s_%d.png" % [
					CAT_ANIMATION_ROOT, state_prefix, state, frame_index
				]
				var texture := load(texture_path) as Texture2D
				if texture == null:
					push_error("Missing cat animation frame: %s" % texture_path)
					continue
				frames.add_frame(animation_name, texture)
		var roll_animation_name := "roll_%s" % direction_name
		frames.add_animation(roll_animation_name)
		frames.set_animation_loop(roll_animation_name, false)
		frames.set_animation_speed(roll_animation_name, 10.0)
		for frame_index in ROLL_FRAME_COUNT:
			var roll_texture_path := "%s/%s_action-frame-%d.png" % [
				CAT_ROLL_ANIMATION_ROOT,
				state_prefix,
				frame_index,
			]
			var roll_texture := load(roll_texture_path) as Texture2D
			if roll_texture == null:
				push_error("Missing cat roll animation frame: %s" % roll_texture_path)
				continue
			frames.add_frame(roll_animation_name, roll_texture)
	return frames


func _input(event: InputEvent) -> void:
	if inventory_ui != null and bool(inventory_ui.call("is_open")):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_I, KEY_B]:
			inventory_ui.call("toggle")
		return
	if raid_loadout_ui_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_raid_loadout_confirmation()
		return
	if raid_zone_ui_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_raid_zone_select()
		return
	if merchant_ui_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_merchant_ui()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_B:
			inventory_ui.call("toggle")
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_3:
			_add_debug_resident()
		elif event.keycode == KEY_SPACE:
			_try_start_roll()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _is_inventory_button_at(touch.position):
			inventory_ui.call("toggle")
			get_viewport().set_input_as_handled()
			return
		if not _ui_blocks_player() and _handle_mobile_action_touch(touch):
			get_viewport().set_input_as_handled()
			return
		if touch.pressed and touch.position.x < get_viewport().get_visible_rect().size.x * 0.55:
			if touch_id == -1:
				touch_id = touch.index
				touch_origin = touch.position
				touch_vector = Vector2.ZERO
				touch_stick.position = touch_origin - touch_stick.size * 0.5
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			touch_vector = Vector2.ZERO
			touch_knob.position = Vector2(40, 40)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		var radius := touch_stick.size.x * 0.34
		var offset: Vector2 = (event.position - touch_origin).limit_length(radius)
		touch_vector = offset / radius
		touch_knob.position = Vector2(40, 40) + offset
		get_viewport().set_input_as_handled()


func _is_inventory_button_at(screen_position: Vector2) -> bool:
	if inventory_ui == null or bool(inventory_ui.call("is_open")):
		return false
	var button := inventory_ui.get_node_or_null("InventoryButton") as Button
	return button != null and button.visible and button.get_global_rect().has_point(screen_position)


func _mobile_button_contains(button: Button, screen_position: Vector2) -> bool:
	return (
		button != null
		and button.visible
		and not button.disabled
		and button.get_global_rect().has_point(screen_position)
	)


func _handle_mobile_action_touch(touch: InputEventScreenTouch) -> bool:
	if not touch.pressed:
		return false
	if _mobile_button_contains(dash_button, touch.position):
		_try_start_roll()
		if DisplayServer.is_touchscreen_available():
			Input.vibrate_handheld(24)
		return true
	if _mobile_button_contains(interact_button, touch.position):
		_interact()
		if DisplayServer.is_touchscreen_available():
			Input.vibrate_handheld(16)
		return true
	return false


func _build_roll_audio() -> void:
	if not is_instance_valid(player):
		return
	roll_audio_player = AudioStreamPlayer3D.new()
	roll_audio_player.name = "ShelterRollWhoosh"
	roll_audio_player.stream = _create_roll_stream()
	roll_audio_player.unit_size = 4.0
	roll_audio_player.max_distance = 22.0
	roll_audio_player.volume_db = -6.0
	player.add_child(roll_audio_player)


func _create_roll_stream() -> AudioStreamWAV:
	var mix_rate := 32000
	var sample_count := int(mix_rate * 0.28)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 82119
	for index in sample_count:
		var time := float(index) / mix_rate
		var progress := time / 0.28
		var envelope := sin(clampf(progress, 0.0, 1.0) * PI)
		var air := random.randf_range(-1.0, 1.0) * envelope
		var cloth := sin(TAU * (170.0 + 180.0 * progress) * time) * envelope * 0.22
		var low := sin(TAU * 58.0 * time) * exp(-time * 9.0) * 0.2
		var sample := clampf(air * 0.34 + cloth + low, -1.0, 1.0)
		var encoded := int(sample * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _play_roll_sound() -> void:
	if not is_instance_valid(roll_audio_player):
		return
	roll_audio_player.stop()
	roll_audio_player.pitch_scale = randf_range(0.94, 1.08)
	roll_audio_player.play()


func _try_start_roll() -> void:
	if roll_active or roll_stamina < ROLL_STAMINA_COST or not is_instance_valid(player):
		return
	var roll_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): roll_input.x -= 1.0
	if Input.is_key_pressed(KEY_D): roll_input.x += 1.0
	if Input.is_key_pressed(KEY_W): roll_input.y -= 1.0
	if Input.is_key_pressed(KEY_S): roll_input.y += 1.0
	roll_input = roll_input.limit_length(1.0)
	if touch_vector.length_squared() > roll_input.length_squared():
		roll_input = touch_vector
	if roll_input.length_squared() > 0.01:
		roll_direction = Vector3(roll_input.x + roll_input.y, 0.0, -roll_input.x + roll_input.y).normalized()
		_update_facing(roll_input)
	else:
		roll_direction = _get_current_facing_world_direction()
	roll_active = true
	roll_stamina = maxf(0.0, roll_stamina - ROLL_STAMINA_COST)
	roll_elapsed = 0.0
	roll_afterimage_timer = 0.0
	_set_motion_state("roll")
	_play_roll_sound()
	_spawn_roll_afterimage()


func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	var progress := clampf(roll_elapsed / ROLL_DURATION, 0.0, 1.0)
	var speed_weight := pow(1.0 - progress, 2.35)
	var roll_speed := lerpf(ROLL_END_SPEED, ROLL_START_SPEED, speed_weight)
	player.velocity = roll_direction * roll_speed
	roll_afterimage_timer -= delta
	if roll_afterimage_timer <= 0.0:
		roll_afterimage_timer += ROLL_AFTERIMAGE_INTERVAL
		_spawn_roll_afterimage()
	if roll_elapsed >= ROLL_DURATION:
		_finish_roll()


func _finish_roll() -> void:
	if not roll_active:
		return
	roll_active = false
	roll_elapsed = 0.0
	player.velocity = roll_direction * ROLL_END_SPEED
	_set_motion_state("idle")


func _spawn_roll_afterimage() -> void:
	if survivor == null or survivor.sprite_frames == null:
		return
	var ghost_texture := survivor.sprite_frames.get_frame_texture(survivor.animation, survivor.frame)
	if ghost_texture == null:
		return
	var ghost := Sprite3D.new()
	ghost.name = "ShelterRollAfterimage"
	ghost.texture = ghost_texture
	ghost.position = player.position + Vector3(0, 0.3, 0)
	ghost.pixel_size = survivor.pixel_size
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.shaded = false
	ghost.transparent = true
	ghost.no_depth_test = true
	ghost.render_priority = survivor.render_priority - 1
	ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(0.72, 0.82, 0.9, 0.42)
	add_child(ghost)
	roll_afterimages.append(ghost)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate", Color(0.62, 0.68, 0.72, 0.0), 0.28)
	tween.tween_property(ghost, "scale", Vector3.ONE * 1.08, 0.28)
	tween.finished.connect(func():
		roll_afterimages.erase(ghost)
		if is_instance_valid(ghost):
			ghost.queue_free()
	)


func _update_roll_feedback() -> void:
	if roll_cooldown_indicator == null or shelter_camera == null or player == null:
		return
	var stamina_ratio := clampf(roll_stamina / GameState.get_max_stamina(), 0.0, 1.0)
	var stamina_is_active := roll_active or stamina_ratio < 0.999
	var head_position := shelter_camera.unproject_position(player.global_position + Vector3(0, 2.05, 0))
	roll_cooldown_indicator.position = head_position + Vector2(26.0, -9.0)
	roll_cooldown_indicator.call("set_cooldown_progress", stamina_ratio, stamina_is_active)


func _get_current_facing_world_direction() -> Vector3:
	match facing:
		"n": return Vector3(-1, 0, -1).normalized()
		"ne": return Vector3(0, 0, -1)
		"e": return Vector3(1, 0, -1).normalized()
		"se": return Vector3(1, 0, 0)
		"s": return Vector3(1, 0, 1).normalized()
		"sw": return Vector3(0, 0, 1)
		"w": return Vector3(-1, 0, 1).normalized()
		"nw": return Vector3(-1, 0, 0)
	return Vector3(1, 0, 1).normalized()


func _add_obstacle(node_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _add_plane(node_name: String, position: Vector3, size: Vector2, material: Material, parent: Node) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)


func _add_visual_box(node_name: String, position: Vector3, size: Vector3, material: Material, parent: Node) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _texture_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
