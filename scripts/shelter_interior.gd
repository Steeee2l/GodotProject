extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const FLOOR_TEXTURE_PATH := "res://assets/interiors/shelter_floor_topdown_v3.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/shelter_wall_panel_v3.png"
const ESCAPE_PIPE_TEXTURE_PATH := "res://assets/interiors/shelter_escape_pipe_v1.png"
const BED_MODULE_SCENE := preload("res://scenes/modules/shelter_bed_module.tscn")
# 시설 기계는 더 이상 3D 기물로 놓지 않는다 — 로직 스크립트만 심고 UI(운영 독)로 연다.
const WORKBENCH_MODULE_SCRIPT := preload("res://scripts/shelter_workbench_module.gd")
const SCRATCHER_BANK_MODULE_SCRIPT := preload("res://scripts/scratcher_bank_module.gd")
const CATNIP_SCRAPER_MODULE_SCRIPT := preload("res://scripts/catnip_scraper_module.gd")
const STORAGE_MODULE_SCRIPT := preload("res://scripts/shelter_storage_module.gd")
const TRAINING_MODULE_SCRIPT := preload("res://scripts/shelter_training_module.gd")
const SHELTER_OPS_CONSOLE_SCRIPT := preload("res://scripts/hud/shelter_ops_console.gd")
const DORMITORY_RACK_TEXTURE := preload(
	"res://assets/interiors/modules/dormitory_rack_v1.png"
)
const SHELTER_RESIDENT_SCRIPT := preload("res://scripts/shelter_resident_cat.gd")
const SHELTER_MERCHANT_SCRIPT := preload("res://scripts/shelter_merchant.gd")
const SHELTER_CONTRACT_TRAINER_SCRIPT := preload("res://scripts/shelter_contract_trainer.gd")
const SHELTER_STORY_CHARACTER_SCRIPT := preload("res://scripts/shelter_story_character.gd")
const MERCHANT_TEXTURE := preload("res://assets/characters/merchant_cat/merchant_down_left_idle.png")
const MOVE_SPEED := 4.6
const CAT_ANIMATION_ROOT := "res://assets/characters/cat_8way"
const CAT_ROLL_ANIMATION_ROOT := "res://assets/characters/cat_roll"
const CAT_LOAF_ANIMATION_ROOT := "res://assets/characters/loaf"
const ROLL_COOLDOWN_INDICATOR_SCRIPT := preload("res://scripts/roll_cooldown_indicator.gd")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const BGM_DIRECTOR := preload("res://scripts/audio/bgm_director.gd")
const TOUCH_JOYSTICK := preload("res://scripts/hud/touch_joystick.gd")
# 사자의 보급 구매 단가 — 초반 고철의 첫 소비처. 위험 정산금(판당 1~2K)과
# 맞물려 "벌어서 다음 판을 준비한다"는 순환을 만든다.
const SCRAP_AMMO_BUNDLE_COST := 350
const SCRAP_MEDKIT_COST := 700
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const AMMO_TEXTURE := preload("res://assets/items/ammo_762.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const RAID_ZONE_MAP_TEXTURE := preload("res://assets/ui/raid_map/apocalypse_seoul_operations_map_v1.png")
const RAID_ZONE_MAP_POSITIONS := {
	"jongno_outskirts": Vector2(0.34, 0.23),
	"namdaemun_market": Vector2(0.29, 0.53),
	"euljiro_depths": Vector2(0.66, 0.43),
	"yongsan_blockade": Vector2(0.40, 0.79),
	"namsan_core": Vector2(0.49, 0.35),
}
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
const ROLL_DURATION := 0.41
const ROLL_STAMINA_MAX := 100.0
const ROLL_STAMINA_COST := 35.0
const ROLL_STAMINA_RECOVERY_PER_SECOND := 30.0
const ROLL_START_SPEED := 21.0
const ROLL_END_SPEED := 4.2
const ROLL_AFTERIMAGE_INTERVAL := 0.06
const LOAF_HOLD_THRESHOLD := 0.45
const LOAF_MOVE_MULTIPLIER := 1.0
const LOAF_STAMINA_DRAIN_PER_SECOND := 7.5
const LOAF_MIN_STAMINA := 1.0
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
		"buy_price": 650, "sell_cans": 2, "icon": "res://assets/items/ammo_762.png",
		"description": "AK 계열 총기에 사용하는 보통탄 30발입니다.",
	},
	{
		"id": "scope_lens", "type": "component", "title": "스코프 렌즈", "amount": 1,
		"buy_price": 1200, "sell_cans": 5, "icon": "res://assets/items/mod_components/scope_lens.png",
		"description": "조준경과 정밀 모듈 제작에 사용하는 온전한 렌즈입니다.",
	},
	{
		"id": "rubber_gasket", "type": "component", "title": "고무 패킹", "amount": 1,
		"buy_price": 950, "sell_cans": 3, "icon": "res://assets/items/mod_components/rubber_gasket.png",
		"description": "소음기와 반동 완충 부품 제작에 사용하는 패킹입니다.",
	},
	{
		"id": "magazine_spring", "type": "component", "title": "탄창 스프링", "amount": 1,
		"buy_price": 1050, "sell_cans": 4, "icon": "res://assets/items/mod_components/magazine_spring.png",
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
var status_panel: PanelContainer
var status_hold := 0.0
var stats_label: Label
var health_bar: ProgressBar
var health_value_label: Label
var resident_meter_label: Label
var production_meter_rows: Dictionary = {}
var shelter_currency_labels: Dictionary = {}
var shelter_runtime_label: Label
var shelter_runtime_bar: ProgressBar
var shelter_bgm := BGM_DIRECTOR.new()
var stats_collapse_button: Button
var stats_summary_label: Label
var stats_body_box: VBoxContainer
var stats_panel_expanded := true
var stats_panel_default_applied := false
var scrap_gain_label: Label
var shelter_upgrade_button: Button
var interact_button: Button
var dash_button: Button
var shelter_medkit_button: Button
var roll_cooldown_indicator: Control
var touch_stick: TouchJoystick
var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_vector := Vector2.ZERO
var roll_active := false
var roll_elapsed := 0.0
var roll_stamina := ROLL_STAMINA_MAX
var roll_afterimage_timer := 0.0
var roll_direction := Vector3.ZERO
var roll_afterimages: Array[Sprite3D] = []
var loafing := false
var space_hold_active := false
var space_hold_elapsed := 0.0
var space_hold_consumed := false
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
var contract_agent: Node3D
var iron_trainer: Node3D
var juhong_character: Node3D
var ops_console: ShelterOpsConsole
var facility_logic: Dictionary = {}
var current_chat_resident: Node3D
var resident_chat_random := RandomNumberGenerator.new()
var contract_ui_layer: CanvasLayer
var contract_ui_body: VBoxContainer
var contract_ui_open := false
var contract_report_message := ""
var contract_story_layer: CanvasLayer
var contract_story_title_label: Label
var contract_story_body_label: Label
var contract_story_progress_label: Label
var contract_story_next_button: Button
var contract_story_skip_button: Button
var contract_story_lines: Array[String] = []
var contract_story_index := 0
var contract_story_open := false
var contract_story_speaker_name := "사자"
var contract_story_portrait: Texture2D
var contract_story_typewriter: Typewriter
var contract_story_completion_owner := ""
var contract_story_completion_id := ""
var shelter_stats_refresh_time := 0.0
var shelter_save_time := 0.0
var raid_zone_ui_layer: CanvasLayer
var raid_zone_ui_open := false
var raid_zone_selected_id := ""
var raid_zone_map_markers: Dictionary = {}
var raid_zone_detail_state: Label
var raid_zone_detail_title: Label
var raid_zone_detail_description: Label
var raid_zone_detail_rule: Label
var raid_zone_detail_reward: Label
var raid_zone_detail_loadout: Label
var raid_zone_detail_requirement: Label
var raid_zone_launch_button: Button
var raid_zone_resupply_button: Button
var auto_paused_for_background := false
var raid_loadout_ui_layer: CanvasLayer
var raid_loadout_ui_open := false
var raid_launch_in_progress := false
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


func _factory_line_z() -> float:
	# 생산 설비가 북쪽 벽에 밀착해 늘어서는 기준선 (wall_aligned 아트 전용).
	return -_room_half_extents().y + 1.55


func _has_production_facility() -> bool:
	for facility_id in ["scratcher_bank", "catnip_scraper", "storage"]:
		if GameState.is_shelter_facility_unlocked(facility_id):
			return true
	return false


func _player_bed_position() -> Vector3:
	return Vector3(-_room_half_extents().x + 1.95, 0.0, -5.4)


# 기계 기물은 사라졌지만 작업조가 모이는 "작업 구역" 좌표는 남는다.
# 배정된 주민은 여전히 이 지점 주변에 줄지어 앉아 일한다.
func _scratcher_bank_position() -> Vector3:
	return Vector3(-_room_half_extents().x + 20.0, 0.0, _factory_line_z())


func _catnip_scraper_position() -> Vector3:
	return Vector3(-_room_half_extents().x + 13.0, 0.0, _factory_line_z())


func _contract_agent_position() -> Vector3:
	return Vector3(2.8, 0.78, _north_module_z() + 3.55)


func _iron_trainer_position() -> Vector3:
	return Vector3(7.6, 0.78, _north_module_z() + 3.15)


func _juhong_position() -> Vector3:
	var pipe := _pipe_position()
	return Vector3(pipe.x - 3.7, 0.78, pipe.z + 2.7)


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
	GameState.sync_shelter_progression_milestones()
	var offline_notice: Dictionary = GameState.process_shelter_progress()
	_build_room()
	_build_stage_one_modules()
	_build_player()
	roll_stamina = GameState.get_max_stamina()
	_build_shelter_residents()
	_setup_contract_agent()
	_setup_iron_trainer()
	_setup_juhong_story_character()
	_build_roll_audio()
	# 쉘터는 안식처다 — 필드와 다른 소리가 나야 '돌아왔다'가 된다.
	shelter_bgm.attach(self)
	shelter_bgm.set_state("shelter")
	_build_interface()
	if not get_viewport().size_changed.is_connected(_apply_shelter_safe_layout):
		get_viewport().size_changed.connect(_apply_shelter_safe_layout)
	_apply_shelter_safe_layout()
	_setup_merchant_visit()
	_update_stats()
	var corpse_notice: Dictionary = GameState.consume_corpse_decay_notice()
	if not corpse_notice.is_empty():
		_show_status(_build_corpse_decay_text(corpse_notice))
	else:
		_show_status(_build_offline_status_text(offline_notice))
	# 문턱을 넘은 순간은 반드시 보여줘야 한다. 조용히 해금되면
	# 강해졌다는 감각이 생기지 않는다.
	var unlocks: Array[Dictionary] = GameState.consume_milestone_unlocks()
	if not unlocks.is_empty():
		call_deferred("_show_milestone_unlock_banner", unlocks)
	call_deferred("_open_pending_shelter_story")
	# 주홍 이벤트가 대기 중이고 사자 이벤트가 없다면, 복귀 직후 등장 시네마틱으로
	# 이어 준다(암전 → 레터박스 → 접근 → 대화).
	if (
		is_instance_valid(juhong_character)
		and GameState.get_pending_shelter_story_event().is_empty()
	):
		call_deferred("_play_juhong_entrance_cinematic")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_update_status_toast(delta)
	_update_space_hold(delta)
	if loafing:
		roll_stamina = maxf(
			0.0,
			roll_stamina
			- LOAF_STAMINA_DRAIN_PER_SECOND
			* GameState.get_stamina_cost_multiplier()
			* delta
		)
		if roll_stamina <= 0.0:
			space_hold_active = false
			space_hold_consumed = true
			_set_loafing(false)
			_show_status("스태미나가 부족합니다.")
	elif not roll_active:
		roll_stamina = minf(
			GameState.get_max_stamina(),
			roll_stamina + ROLL_STAMINA_RECOVERY_PER_SECOND * GameState.get_stamina_recovery_multiplier() * delta
		)
	if dash_button:
		dash_button.disabled = roll_active or roll_stamina < ROLL_STAMINA_COST
	if shelter_medkit_button:
		shelter_medkit_button.visible = not _ui_blocks_player()
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
		player.velocity = (
			world_direction
			* MOVE_SPEED
			* GameState.get_move_speed_multiplier()
			* (LOAF_MOVE_MULTIPLIER if loafing else 1.0)
		)
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
	_refresh_unlocked_facilities(module_root, false)


const LOCKED_FACILITY_HINTS := {
	"scratcher_bank": "사자의 첫 계약",
	"catnip_scraper": "사자의 두 번째 계약",
	"workbench": "사자의 계약 진행",
	"storage": "첫 출정에서 복귀",
	"training": "첫 출정에서 복귀",
}


func _refresh_unlocked_facilities(module_root: Node3D = null, animate: bool = true) -> Array[String]:
	if module_root == null:
		module_root = get_node_or_null("StageOneModules") as Node3D
	if module_root == null:
		return []
	var created: Array[String] = []
	# 기계는 방에 놓지 않는다. 시설은 운영 독(UI)에서 열리고,
	# 여기서는 그 UI가 부릴 로직 노드만 기존 이름을 유지한 채 심는다.
	for facility_data in [
		["workbench", "WeaponWorkbench", WORKBENCH_MODULE_SCRIPT],
		["scratcher_bank", "ScratcherBank", SCRATCHER_BANK_MODULE_SCRIPT],
		["catnip_scraper", "CatnipScraper", CATNIP_SCRAPER_MODULE_SCRIPT],
		["storage", "ShelterStorage", STORAGE_MODULE_SCRIPT],
		["training", "SurvivalTrainingFacility", TRAINING_MODULE_SCRIPT],
	]:
		var facility_id := str(facility_data[0])
		var node_name := str(facility_data[1])
		if not GameState.is_shelter_facility_unlocked(facility_id):
			continue
		var existing := module_root.get_node_or_null(node_name)
		if existing != null:
			facility_logic[facility_id] = existing
			continue
		var module_script := facility_data[2] as GDScript
		var module := module_script.new() as Node3D
		module.name = node_name
		module_root.add_child(module)
		# 보이지 않는 로직 노드가 접근 프롬프트를 띄우면 안 된다. 그룹은 침대만 남긴다.
		module.remove_from_group("shelter_module")
		facility_logic[facility_id] = module
		created.append(facility_id)
	if animate and not created.is_empty():
		refresh_shelter_residents(true)
	if ops_console != null:
		ops_console.refresh()
	return created



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


func _unlock_all_facilities_debug() -> void:
	GameState.unlock_all_shelter_facilities()
	var created := _refresh_unlocked_facilities()
	GameState.save_persistent_state()
	_update_stats()
	if created.is_empty():
		_show_status("테스트 시설은 이미 모두 건설되어 있습니다.")
		return
	var facility_names: Array[String] = []
	for facility_id in created:
		facility_names.append(GameState.get_shelter_facility_name(facility_id))
	_show_status("테스트 시설 완공 · %s" % " · ".join(facility_names))


func _setup_contract_agent() -> void:
	if not GameState.is_saja_available() or is_instance_valid(contract_agent):
		return
	contract_agent = SHELTER_STORY_CHARACTER_SCRIPT.new() as Node3D
	contract_agent.call(
		"configure",
		"saja",
		"사자",
		"쉘터 지킴이 · 시설 감독",
		"사자와 대화하기",
		"res://assets/characters/saja",
		"down_left",
		0.0105
	)
	contract_agent.position = _contract_agent_position()
	add_child(contract_agent)
	contract_agent.call("set_player_target", player)


func _setup_iron_trainer() -> void:
	if not GameState.is_iron_trainer_available() or is_instance_valid(iron_trainer):
		return
	iron_trainer = SHELTER_CONTRACT_TRAINER_SCRIPT.new() as Node3D
	iron_trainer.position = _iron_trainer_position()
	add_child(iron_trainer)
	iron_trainer.call("set_player_target", player)


func _setup_juhong_story_character() -> void:
	if is_instance_valid(juhong_character):
		return
	var event: Dictionary = GameState.get_pending_juhong_event()
	if event.is_empty():
		return
	juhong_character = SHELTER_STORY_CHARACTER_SCRIPT.new() as Node3D
	juhong_character.call(
		"configure",
		"juhong",
		"주홍",
		"붉은 칼의 전령",
		"주홍과 대화하기",
		"res://assets/characters/juhong",
		"down_right",
		0.0105
	)
	juhong_character.position = _juhong_position()
	add_child(juhong_character)
	juhong_character.call("set_player_target", player)


func _open_pending_shelter_story() -> void:
	if contract_story_open or not is_instance_valid(contract_agent):
		return
	var event: Dictionary = GameState.get_pending_shelter_story_event()
	if event.is_empty():
		return
	_open_contract_story(
		str(event.get("title", "사자의 이야기")),
		_string_array(event.get("lines", [])),
		str(event.get("speaker", "사자")),
		_character_portrait(contract_agent),
		"saja",
		str(event.get("id", ""))
	)


func _interact_with_saja() -> void:
	var event: Dictionary = GameState.get_pending_shelter_story_event()
	if not event.is_empty():
		_open_pending_shelter_story()
		return
	if not GameState.is_contract_agent_available():
		_show_status("사자 · 첫 출정에서 살아 돌아오면 쉘터 재건 계획을 맡기겠다.")
		return
	_open_contract_ui()


func _apply_portrait_camera_aspect(target_camera: Camera3D) -> void:
	# 세로 화면에서는 직교 카메라 size가 세로 기준(KEEP_HEIGHT)이라 가로 시야가
	# 절반 이하로 좁아진다. KEEP_WIDTH로 뒤집으면 size가 가로 기준이 되어,
	# 세로로 자동 줌아웃되고 가로 시야는 가로모드와 같아진다.
	if target_camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y > viewport_size.x
	target_camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT


func _play_juhong_entrance_cinematic(entrance := true) -> void:
	# 주홍의 모든 대화를 내러티브 이벤트로 연출한다. entrance=true(복귀 직후)는
	# 암전 속에 이미 와 있다가 밝아지며 걸어오고, false(직접 말 걸기)는 암전 없이
	# 레터박스만 내려온 뒤 한 걸음 다가와 말을 시작한다.
	# 예전에는 그냥 구석에 서 있는 NPC라 "뜬금없이 나타나 대사만 하고 사라지는"
	# 인상이었다.
	if not is_instance_valid(juhong_character) or not is_instance_valid(player):
		return
	if get_node_or_null("JuhongCinematicLayer") != null:
		return
	var cine := CanvasLayer.new()
	cine.name = "JuhongCinematicLayer"
	cine.layer = 92
	cine.add_to_group("shelter_modal_ui")
	add_child(cine)
	var black := ColorRect.new()
	black.name = "CineBlack"
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0, 0, 0, 1.0 if entrance else 0.0)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	cine.add_child(black)
	var bar_top := ColorRect.new()
	bar_top.name = "CineBarTop"
	bar_top.color = Color.BLACK
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine.add_child(bar_top)
	var bar_bottom := ColorRect.new()
	bar_bottom.name = "CineBarBottom"
	bar_bottom.color = Color.BLACK
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0.0
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine.add_child(bar_bottom)
	# 등장이라면 "이미 와 있던 것처럼": 플레이어에게서 5.5m 떨어진 자리에 세워
	# 두고 밝아진 뒤 2.2m까지, 직접 말 걸었다면 지금 자리에서 반걸음만 다가온다.
	var away := juhong_character.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1.0, 0.0, 1.0)
	away = away.normalized()
	if entrance:
		juhong_character.global_position = player.global_position + away * 5.5
	var approach_target := player.global_position + away * (2.2 if entrance else 1.6)
	var tween := create_tween()
	if entrance:
		tween.tween_property(black, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_interval(0.05)
	tween.parallel().tween_property(bar_top, "offset_bottom", 62.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bar_bottom, "offset_top", -62.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(juhong_character):
			juhong_character.call("_play_animation", "walk")
	)
	tween.tween_interval(0.2)
	tween.tween_property(
		juhong_character, "global_position", approach_target, 1.4 if entrance else 0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(juhong_character):
			juhong_character.call("_play_animation", "idle")
			_spawn_story_emote(juhong_character, "…", Color("#93a89d"))
		_open_juhong_story()
		_finish_juhong_cinematic(cine)
	)


func _finish_juhong_cinematic(cine: CanvasLayer) -> void:
	# 대화가 닫힐 때까지 기다렸다가 레터박스를 걷는다.
	if not is_instance_valid(cine):
		return
	if contract_story_open:
		get_tree().create_timer(0.25).timeout.connect(_finish_juhong_cinematic.bind(cine))
		return
	var bar_top := cine.get_node_or_null("CineBarTop") as ColorRect
	var bar_bottom := cine.get_node_or_null("CineBarBottom") as ColorRect
	# 조작 잠금을 먼저 푼다 — 레터박스가 걷히는 동안 이미 움직일 수 있어야 답답하지 않다.
	cine.remove_from_group("shelter_modal_ui")
	var tween := create_tween()
	if bar_top != null:
		tween.tween_property(bar_top, "offset_bottom", 0.0, 0.4)
	if bar_bottom != null:
		tween.parallel().tween_property(bar_bottom, "offset_top", 0.0, 0.4)
	tween.tween_callback(cine.queue_free)


func _play_juhong_exit() -> void:
	# 전령은 대사가 끝나면 온 길로 돌아간다 — 있던 자리에서 증발하지 않는다.
	if not is_instance_valid(juhong_character) or not is_instance_valid(player):
		if is_instance_valid(juhong_character):
			juhong_character.queue_free()
		return
	var leaving := juhong_character
	var away := leaving.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1.0, 0.0, 1.0)
	away = away.normalized()
	_spawn_story_emote(leaving, "…", Color("#93a89d"))
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func() -> void:
		if is_instance_valid(leaving):
			leaving.call("_play_animation", "walk")
	)
	tween.tween_property(
		leaving, "global_position", leaving.global_position + away * 6.5, 2.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 걸어가는 마지막 1초 동안 어둠에 녹아든다.
	var fade := create_tween()
	fade.tween_interval(1.7)
	var sprite := leaving.get_node_or_null("CharacterSprite")
	if sprite != null:
		fade.tween_property(sprite, "modulate:a", 0.0, 1.1)
	for child in leaving.get_children():
		if child is Label3D:
			fade.parallel().tween_property(child, "modulate:a", 0.0, 0.8)
	tween.tween_callback(leaving.queue_free)


func _emote_for_story_line(target: Node3D, line: String) -> void:
	# 대사의 문장부호가 곧 감정이다 — 과장 없이 한 글자만 띄운다.
	var glyph := ""
	if line.contains("!"):
		glyph = "!"
	elif line.contains("?"):
		glyph = "?"
	elif line.contains("…") or line.contains("..."):
		glyph = "…"
	if glyph.is_empty():
		return
	var color := (
		Color("#f0d98e") if glyph == "!"
		else Color("#9fc9d8") if glyph == "?"
		else Color("#93a89d")
	)
	_spawn_story_emote(target, glyph, color)


func _spawn_story_emote(target: Node3D, glyph: String, color: Color) -> void:
	if not is_instance_valid(target):
		return
	var previous := target.get_node_or_null("StoryEmote")
	if previous != null:
		previous.queue_free()
	var label := Label3D.new()
	label.name = "StoryEmote"
	label.text = glyph
	label.font = FONT
	label.font_size = 92
	label.pixel_size = 0.006
	label.position = Vector3(0.44, 2.4, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 127
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.outline_modulate = Color(0.015, 0.02, 0.016, 0.98)
	label.outline_size = 14
	label.scale = Vector3.ONE * 0.55
	target.add_child(label)
	var pop := label.create_tween()
	pop.tween_property(label, "scale", Vector3.ONE * 1.12, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector3.ONE, 0.12)
	var visibility := label.create_tween()
	visibility.tween_property(label, "modulate:a", 1.0, 0.1)
	visibility.tween_interval(1.05)
	visibility.tween_property(label, "modulate:a", 0.0, 0.35)
	visibility.tween_callback(label.queue_free)


func _open_juhong_story() -> void:
	var event: Dictionary = GameState.get_pending_juhong_event()
	if event.is_empty():
		_show_status("주홍은 더 남길 말 없이 도시로 돌아갔습니다.")
		return
	_open_contract_story(
		str(event.get("title", "붉은 칼의 전령")),
		_string_array(event.get("lines", [])),
		str(event.get("speaker", "주홍")),
		_character_portrait(juhong_character),
		"juhong",
		str(event.get("id", ""))
	)


func _open_iron_mission_dialog() -> void:
	var state: Dictionary = GameState.get_iron_mission_state()
	var definition: Dictionary = state.get("definition", {}) as Dictionary
	var status := str(state.get("status", "available"))
	var title := str(definition.get("title", "철근의 특별 훈련"))
	var lines: Array[String] = []
	match status:
		"available":
			var accept_result: Dictionary = GameState.accept_current_iron_mission()
			if not bool(accept_result.get("ok", false)):
				_show_status("철근의 훈련을 지금 시작할 수 없습니다.")
				return
			lines.append(str(definition.get("accept_dialogue", "몸부터 단련하고 다시 와.")))
			lines.append("시험 목표 · %s" % str(definition.get("brief", "생존 시험을 완수하세요.")))
		"active":
			lines.append("아직 끝난 게 아니다. 숫자가 아니라 끝까지 살아 돌아오는 걸 보여 줘.")
			lines.append("현재 진행 · %d / %d\n%s" % [
				int(state.get("progress", 0)),
				int(state.get("target", 1)),
				str(definition.get("brief", "")),
			])
		"complete":
			var claim_result: Dictionary = GameState.claim_current_iron_mission_reward()
			if not bool(claim_result.get("ok", false)):
				_show_status("철근의 훈련 보상을 정산하지 못했습니다.")
				return
			lines.append(str(definition.get("complete_dialogue", "이번 시험은 통과다.")))
			lines.append("영구 강화 획득 · %s" % str(definition.get("reward_text", "생존 능력 강화")))
			_update_stats()
		_:
			title = "철근의 생존 훈련"
			lines.append("가르칠 건 다 가르쳤다. 이제 살아 돌아오는 건 네 몫이야.")
	_open_contract_story(title, lines, "철근", _character_portrait(iron_trainer))


func _character_portrait(character: Node3D) -> Texture2D:
	if is_instance_valid(character) and character.has_method("get_portrait_texture"):
		return character.call("get_portrait_texture") as Texture2D
	return null


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _open_contract_story(
	title_text: String,
	lines: Array[String],
	speaker_name: String = "사자",
	portrait_texture: Texture2D = null,
	completion_owner: String = "",
	completion_id: String = ""
) -> void:
	if lines.is_empty() or contract_story_open:
		return
	contract_story_open = true
	contract_story_speaker_name = speaker_name
	contract_story_portrait = portrait_texture
	contract_story_completion_owner = completion_owner
	contract_story_completion_id = completion_id
	contract_story_lines.assign(lines)
	contract_story_index = 0
	touch_vector = Vector2.ZERO
	roll_active = false
	_set_motion_state("idle")
	contract_story_layer = CanvasLayer.new()
	contract_story_layer.name = "ContractNarrativeLayer"
	contract_story_layer.layer = 78
	contract_story_layer.add_to_group("shelter_modal_ui")
	add_child(contract_story_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	contract_story_layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.006, 0.006, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var accent := ColorRect.new()
	accent.anchor_left = 0.0
	accent.anchor_top = 0.0
	accent.anchor_right = 1.0
	accent.anchor_bottom = 0.012
	accent.color = Color("#b89545")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(accent)
	var panel := PanelContainer.new()
	panel.name = "ContractNarrativePanel"
	var viewport_size := get_viewport().get_visible_rect().size
	var compact_layout := viewport_size.x < 760.0
	# 오프닝 대사창과 같은 문법: 하단 슬림 바. 화면 절반을 덮던 두꺼운 모달은
	# 쉘터에서만 이질적이었다. 초상화는 작게 인라인으로 남긴다.
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var narrative_half := minf(450.0, (viewport_size.x - 24.0) * 0.5)
	panel.offset_left = -narrative_half
	panel.offset_right = narrative_half
	panel.offset_bottom = -26.0
	panel.offset_top = -26.0 - (196.0 if compact_layout else 178.0)
	panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.012, 0.019, 0.018, 0.985), Color("#b89545"), 8)
	)
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	# 슬림 바에서는 세로/가로 구분 없이 항상 초상화-왼쪽 가로 배치가 들어간다.
	var row: BoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var portrait_frame := PanelContainer.new()
	var portrait_size := 64.0 if compact_layout else 72.0
	portrait_frame.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color("#101815"), Color("#6e856f"), 6)
	)
	row.add_child(portrait_frame)
	var portrait := TextureRect.new()
	if contract_story_portrait != null:
		portrait.texture = contract_story_portrait
	elif is_instance_valid(contract_agent) and contract_agent.has_method("get_portrait_texture"):
		portrait.texture = contract_agent.call("get_portrait_texture") as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 7)
	row.add_child(text_box)
	var speaker_row := HBoxContainer.new()
	text_box.add_child(speaker_row)
	var speaker := Label.new()
	speaker.text = contract_story_speaker_name
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker.add_theme_font_override("font", FONT)
	speaker.add_theme_font_size_override("font_size", 16)
	speaker.add_theme_color_override("font_color", Color("#f0ce70"))
	speaker_row.add_child(speaker)
	contract_story_progress_label = Label.new()
	contract_story_progress_label.add_theme_font_override("font", FONT)
	contract_story_progress_label.add_theme_font_size_override("font_size", 14)
	contract_story_progress_label.add_theme_color_override("font_color", Color("#82998d"))
	speaker_row.add_child(contract_story_progress_label)
	contract_story_title_label = Label.new()
	contract_story_title_label.text = title_text
	contract_story_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_story_title_label.add_theme_font_override("font", FONT)
	contract_story_title_label.add_theme_font_size_override("font_size", 14)
	contract_story_title_label.add_theme_color_override("font_color", Color("#9cc7ae"))
	contract_story_title_label.add_theme_color_override("font_color", Color("#e7d49a"))
	text_box.add_child(contract_story_title_label)
	contract_story_body_label = Label.new()
	contract_story_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contract_story_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_story_body_label.add_theme_font_override("font", FONT)
	contract_story_body_label.add_theme_font_size_override("font_size", 17)
	contract_story_body_label.add_theme_color_override("font_color", Color("#e5ece7"))
	text_box.add_child(contract_story_body_label)
	# 대사는 한 글자씩 소리와 함께 흘러나온다. 레이어에 붙여 함께 정리된다.
	contract_story_typewriter = Typewriter.new()
	contract_story_layer.add_child(contract_story_typewriter)
	contract_story_typewriter.attach(contract_story_body_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	text_box.add_child(actions)
	# 한 줄씩 두 탭(전체 표시→다음)이 기본이라 긴 대화는 스킵이 있어야 한다.
	contract_story_skip_button = _merchant_button("건너뛰기", false, "close")
	contract_story_skip_button.custom_minimum_size = Vector2(108 if compact_layout else 132, 46)
	contract_story_skip_button.pressed.connect(_skip_contract_story)
	actions.add_child(contract_story_skip_button)
	contract_story_next_button = _merchant_button("다음", true, "collect")
	contract_story_next_button.custom_minimum_size = Vector2(132 if compact_layout else 170, 46)
	contract_story_next_button.pressed.connect(_advance_contract_story)
	actions.add_child(contract_story_next_button)
	_refresh_contract_story()


func _refresh_contract_story() -> void:
	if not is_instance_valid(contract_story_body_label):
		return
	if is_instance_valid(contract_story_typewriter):
		contract_story_typewriter.start(contract_story_lines[contract_story_index])
	else:
		contract_story_body_label.text = contract_story_lines[contract_story_index]
	# 주홍 대사는 줄마다 감정 이모트가 머리 위에 뜬다.
	if contract_story_completion_owner == "juhong" and is_instance_valid(juhong_character):
		_emote_for_story_line(juhong_character, contract_story_lines[contract_story_index])
	contract_story_progress_label.text = "%d / %d" % [
		contract_story_index + 1,
		contract_story_lines.size(),
	]
	var last_line := contract_story_index >= contract_story_lines.size() - 1
	contract_story_next_button.text = "기록 보관" if last_line else "다음"
	if is_instance_valid(contract_story_skip_button):
		contract_story_skip_button.visible = not last_line


func _archive_contract_story() -> void:
	# '기록 보관' 라벨을 진짜로 만든다 — 끝낸 대화는 기록 보관소에서 다시 읽을 수 있다.
	if contract_story_lines.is_empty():
		return
	var title := (
		contract_story_title_label.text
		if is_instance_valid(contract_story_title_label) and not contract_story_title_label.text.is_empty()
		else "%s의 말" % contract_story_speaker_name
	)
	var entry := "%s — %s\n%s" % [
		contract_story_speaker_name,
		title,
		"\n".join(contract_story_lines),
	]
	if not GameState.unlocked_contract_lore.has(entry):
		GameState.unlocked_contract_lore.append(entry)


func _skip_contract_story() -> void:
	# 마지막 줄로 바로 이동 — 종료가 아니라 '기록 보관' 버튼 앞까지만 간다.
	if not contract_story_open or contract_story_lines.is_empty():
		return
	contract_story_index = contract_story_lines.size() - 1
	_refresh_contract_story()
	if is_instance_valid(contract_story_typewriter):
		contract_story_typewriter.skip()


func _advance_contract_story() -> void:
	if not contract_story_open:
		return
	# 아직 타이핑 중이면 첫 입력은 "전부 즉시 표시"로 쓴다. 그 다음 입력에서 넘어간다.
	if is_instance_valid(contract_story_typewriter) and contract_story_typewriter.is_typing():
		contract_story_typewriter.skip()
		return
	contract_story_index += 1
	if contract_story_index < contract_story_lines.size():
		_refresh_contract_story()
		return
	_archive_contract_story()
	if contract_story_completion_owner == "saja":
		GameState.mark_shelter_story_event_seen(contract_story_completion_id)
	elif contract_story_completion_owner == "juhong":
		GameState.mark_juhong_event_seen(contract_story_completion_id)
		_play_juhong_exit()
		juhong_character = null
	contract_story_open = false
	if is_instance_valid(contract_story_layer):
		contract_story_layer.queue_free()
	contract_story_layer = null
	contract_story_typewriter = null
	contract_story_title_label = null
	contract_story_body_label = null
	contract_story_progress_label = null
	contract_story_next_button = null
	contract_story_lines.clear()
	contract_story_index = 0
	contract_story_speaker_name = "사자"
	contract_story_portrait = null
	contract_story_completion_owner = ""
	contract_story_completion_id = ""


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
	var column := maxi(0, index) % 10
	var row := maxi(0, index) / 10
	return Vector3(
		station.x + _factory_worker_x_offset(column),
		0.78,
		station.z + 2.35 + float(row) * 1.08
	)


func _catnip_work_position(index: int) -> Vector3:
	var station := _catnip_scraper_position()
	var column := maxi(0, index) % 5
	var row := maxi(0, index) / 5
	return Vector3(
		station.x + _factory_worker_x_offset(column),
		0.78,
		station.z + 2.35 + float(row) * 1.08
	)


func _factory_worker_x_offset(column: int) -> float:
	if column <= 0:
		return 0.0
	var step: int = (column + 1) / 2
	var side: float = -1.0 if column % 2 == 1 else 1.0
	return float(step) * 1.2 * side


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
		or contract_ui_open
		or contract_story_open
		or raid_zone_ui_open
		or raid_loadout_ui_open
		or not get_tree().get_nodes_in_group("shelter_modal_ui").is_empty()
		or (inventory_ui != null and bool(inventory_ui.call("is_open")))
	)


func _interaction_prompt_text(action: String) -> String:
	# 터치 기기에는 F키가 없다 — 있지도 않은 키를 안내하지 않는다.
	if DisplayServer.is_touchscreen_available():
		return action
	return "[F]  %s" % action


var shelter_weapon_card: PanelContainer
var shelter_weapon_card_icon: TextureRect
var shelter_weapon_card_label: Label


func _build_shelter_weapon_card() -> void:
	# 출정 필드의 우하단 무기 카드를 쉘터에서도 유지한다 — 지금 낀 총과
	# 그 총이 먹는 탄을 어디서든 한눈에. (탄약 혼동 방지)
	shelter_weapon_card = PanelContainer.new()
	shelter_weapon_card.name = "ShelterWeaponCard"
	shelter_weapon_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var card_bottom := -196.0 if DisplayServer.is_touchscreen_available() else -16.0
	shelter_weapon_card.offset_right = -14.0
	shelter_weapon_card.offset_left = -292.0
	shelter_weapon_card.offset_bottom = card_bottom
	shelter_weapon_card.offset_top = card_bottom - 66.0
	shelter_weapon_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelter_weapon_card.add_theme_stylebox_override(
		"panel", _rounded_panel_style(Color(0.02, 0.027, 0.025, 0.92), Color("#6f8a7c"), 8)
	)
	get_node("ShelterHUD").add_child(shelter_weapon_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	shelter_weapon_card.add_child(row)
	shelter_weapon_card_icon = TextureRect.new()
	shelter_weapon_card_icon.custom_minimum_size = Vector2(74, 40)
	shelter_weapon_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shelter_weapon_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(shelter_weapon_card_icon)
	shelter_weapon_card_label = Label.new()
	shelter_weapon_card_label.add_theme_font_override("font", FONT)
	shelter_weapon_card_label.add_theme_font_size_override("font_size", 12)
	shelter_weapon_card_label.add_theme_color_override("font_color", Color("#dfe8e2"))
	shelter_weapon_card_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shelter_weapon_card_label)
	_refresh_shelter_weapon_card()


func _refresh_shelter_weapon_card() -> void:
	if shelter_weapon_card == null:
		return
	var weapon_id := str(GameState.equipped_weapon_id)
	if weapon_id.is_empty() or not bool(GameState.has_ak):
		shelter_weapon_card.visible = false
		return
	shelter_weapon_card.visible = true
	var weapon_definition := WEAPON_SYSTEM.get_weapon(weapon_id)
	var ammo_name := str(
		WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get(
			"display_name", GameState.equipped_ammo_id
		)
	)
	var short_name := str(weapon_definition.get("display_name", weapon_id)).split("\"")[0].strip_edges()
	shelter_weapon_card_icon.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	shelter_weapon_card_label.text = "%s  +%d\n%s\n장탄 %02d · 예비 %d" % [
		short_name,
		GameState.get_weapon_enhancement_level(weapon_id),
		ammo_name,
		int(GameState.magazine_ammo),
		GameState.get_ammo_count(GameState.equipped_ammo_id),
	]


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShelterHUD"
	canvas.layer = 5
	add_child(canvas)
	ops_console = SHELTER_OPS_CONSOLE_SCRIPT.new()
	ops_console.attach(self)
	ops_console.build_dock(canvas)
	var theme := Theme.new()
	theme.default_font = FONT
	var panel := PanelContainer.new()
	panel.name = "ShelterStatsPanel"
	panel.position = Vector2(24, 22)
	panel.custom_minimum_size = Vector2(370, 0)
	panel.theme = theme
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.023, 0.92), Color("#577a69")))
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var outer_box := VBoxContainer.new()
	outer_box.add_theme_constant_override("separation", 6)
	margin.add_child(outer_box)

	# 헤더는 늘 보인다. 여기까지가 "지금 무슨 일이 벌어지는가"의 최소 단위다.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	outer_box.add_child(header_row)
	stats_label = Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color("#8fa79c"))
	header_row.add_child(stats_label)
	# 접기(더보기) 버튼은 제거했다. 패널 자체를 4재화+가동연료의 컴팩트한 형태로
	# 줄였으므로, 항상 펼쳐 두는 쪽이 정보도 더 잘 전달되고 탭 낭비도 없다.
	outer_box.add_child(_build_health_row())
	# 접혔을 때도 이 한 줄은 남는다. 나갈 이유를 늘 보여주기 위해서.
	stats_summary_label = Label.new()
	stats_summary_label.add_theme_font_override("font", FONT)
	stats_summary_label.add_theme_font_size_override("font_size", 13)
	stats_summary_label.add_theme_color_override("font_color", Color("#9db3a9"))
	outer_box.add_child(stats_summary_label)

	var stats_box := VBoxContainer.new()
	stats_box.name = "ShelterStatsBody"
	stats_box.add_theme_constant_override("separation", 7)
	outer_box.add_child(stats_box)
	stats_body_box = stats_box
	# 주민·꾹꾹이·스크래핑은 전부 "인원/슬롯" 정보다. 세 줄 대신 한 줄에 세그먼트로
	# 나란히 둔다. 각 세그먼트가 자기 HBox를 가지므로 기존 숨김 로직이 그대로 돈다.
	var population_row := HBoxContainer.new()
	population_row.add_theme_constant_override("separation", 16)
	stats_box.add_child(population_row)
	resident_meter_label = _build_meter_row(population_row, "resident", "주민", Color("#9fc9d8"))
	for production_data in [
		["scratcher", "꾹꾹이", Color("#d4ad55")],
		["catnip", "스크래핑", Color("#8fcf7a")],
	]:
		var production_id := str(production_data[0])
		var row_label := _build_meter_row(
			population_row,
			"scrap" if production_id == "scratcher" else "catnip",
			str(production_data[1]),
			production_data[2] as Color
		)
		production_meter_rows[production_id] = row_label
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 6)
	stats_box.add_child(divider)
	var resource_grid := GridContainer.new()
	# 재화 4종을 아이콘+숫자만으로 한 줄에. 이름 텍스트는 아이콘이 대신한다.
	# 툴팁에 이름을 남겨 무엇인지 확인은 가능하게 둔다.
	resource_grid.columns = 4
	resource_grid.add_theme_constant_override("h_separation", 12)
	resource_grid.add_theme_constant_override("v_separation", 4)
	stats_box.add_child(resource_grid)
	for resource_data in [
		["scrap", "고철", Color("#c7d1ce")],
		["food", "통조림", Color("#e5b55b")],
		["catnip", "캣닢", Color("#a9db78")],
		["churu", "츄르", Color("#d99b67")],
	]:
		var chip := _currency_chip(str(resource_data[0]), str(resource_data[1]), resource_data[2], 20, 62)
		chip.tooltip_text = str(resource_data[1])
		resource_grid.add_child(chip)
		shelter_currency_labels[str(resource_data[0])] = chip.get_meta("value_label")
	stats_box.add_child(_build_runtime_row())
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
	prompt_label.offset_left = -220.0
	prompt_label.offset_top = -112.0
	prompt_label.offset_right = 220.0
	prompt_label.offset_bottom = -60.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", FONT)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(prompt_label)
	# 토스트는 월드 위에 맨몸 텍스트로 떠 있으면 배경과 섞여 안 읽힌다.
	status_panel = PanelContainer.new()
	status_panel.name = "ShelterStatusToast"
	status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_panel.offset_left = -270.0
	status_panel.offset_top = 24.0
	status_panel.offset_right = 270.0
	status_panel.offset_bottom = 76.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.modulate.a = 0.0
	status_panel.visible = false
	status_panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.015, 0.028, 0.025, 0.9), Color("#4f7a68"), 7)
	)
	canvas.add_child(status_panel)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#b7f0d4"))
	status_panel.add_child(status_label)
	_build_merchant_arrival_notice(canvas)
	interact_button = Button.new()
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.offset_left = -154.0
	interact_button.offset_top = -142.0
	interact_button.offset_right = -36.0
	interact_button.offset_bottom = -70.0
	interact_button.text = "상호작용"
	interact_button.icon = UI_ICONS.get_icon("interact", 32, Color("#dce8e1"))
	interact_button.expand_icon = true
	interact_button.add_theme_font_override("font", FONT)
	interact_button.add_theme_font_size_override("font_size", 16)
	if not DisplayServer.is_touchscreen_available():
		interact_button.pressed.connect(_interact)
	canvas.add_child(interact_button)
	dash_button = Button.new()
	dash_button.name = "DashButton"
	dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_button.offset_left = -284.0
	dash_button.offset_top = -142.0
	dash_button.offset_right = -166.0
	dash_button.offset_bottom = -70.0
	dash_button.text = "대시"
	dash_button.icon = UI_ICONS.get_icon("dash", 32, Color("#d8e5de"))
	dash_button.expand_icon = true
	dash_button.add_theme_font_override("font", FONT)
	dash_button.add_theme_font_size_override("font_size", 16)
	if not DisplayServer.is_touchscreen_available():
		dash_button.pressed.connect(_try_start_roll)
	dash_button.visible = DisplayServer.is_touchscreen_available()
	canvas.add_child(dash_button)
	shelter_medkit_button = Button.new()
	shelter_medkit_button.name = "ShelterMedkitButton"
	shelter_medkit_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var medkit_left := 174.0 if DisplayServer.is_touchscreen_available() else 24.0
	shelter_medkit_button.offset_left = medkit_left
	shelter_medkit_button.offset_top = -104.0
	shelter_medkit_button.offset_right = medkit_left + 104.0
	shelter_medkit_button.offset_bottom = -24.0
	shelter_medkit_button.icon = UI_ICONS.get_icon("medkit", 36, Color("#f0eee4"))
	shelter_medkit_button.expand_icon = true
	shelter_medkit_button.add_theme_constant_override("icon_max_width", 36)
	shelter_medkit_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shelter_medkit_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	shelter_medkit_button.focus_mode = Control.FOCUS_NONE
	shelter_medkit_button.add_theme_font_override("font", FONT)
	shelter_medkit_button.add_theme_font_size_override("font_size", 13)
	shelter_medkit_button.add_theme_stylebox_override(
		"normal",
		_rounded_panel_style(Color(0.018, 0.025, 0.025, 0.94), Color("#718a7e"), 7)
	)
	shelter_medkit_button.add_theme_stylebox_override(
		"hover",
		_rounded_panel_style(Color(0.055, 0.08, 0.07, 0.97), Color("#b9d1c4"), 7)
	)
	shelter_medkit_button.add_theme_stylebox_override(
		"pressed",
		_rounded_panel_style(Color(0.11, 0.17, 0.13, 0.98), Color("#dff0e5"), 7)
	)
	if not DisplayServer.is_touchscreen_available():
		shelter_medkit_button.pressed.connect(_use_shelter_medkit)
	canvas.add_child(shelter_medkit_button)
	_update_shelter_medkit_button()
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
	inventory_ui.connect("item_discard_requested", _on_inventory_item_discard_requested)
	_refresh_inventory_state()
	_build_shelter_weapon_card()
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
	title.add_theme_font_size_override("font_size", 14)
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


func _open_contract_ui() -> void:
	if contract_ui_open:
		return
	contract_ui_open = true
	touch_vector = Vector2.ZERO
	roll_active = false
	_set_motion_state("idle")
	contract_ui_layer = CanvasLayer.new()
	contract_ui_layer.name = "ContractAgentLayer"
	contract_ui_layer.layer = 60
	add_child(contract_ui_layer)

	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	contract_ui_layer.add_child(root_control)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.009, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)
	ModalDismiss.install(contract_ui_layer, dim, _close_contract_ui)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ContractAgentPanel"
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 24.0, 320.0, 820.0),
		clampf(viewport_size.y - 24.0, 430.0, 640.0)
	)
	panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.018, 0.025, 0.023, 0.99), Color("#a98a4c"), 8)
	)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	contract_ui_body = VBoxContainer.new()
	contract_ui_body.name = "ContractContent"
	contract_ui_body.add_theme_constant_override("separation", 12)
	margin.add_child(contract_ui_body)
	call_deferred("_refresh_contract_ui")


func _refresh_contract_ui() -> void:
	if not is_instance_valid(contract_ui_body):
		return
	for child in contract_ui_body.get_children():
		contract_ui_body.remove_child(child)
		child.queue_free()
	var state := GameState.get_contract_state()
	var definition := state.get("definition", {}) as Dictionary
	var status := str(state.get("status", "available"))
	var completed_count := int(state.get("completed_count", 0))
	var total_count := int(state.get("total_count", 0))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	contract_ui_body.add_child(header)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(82, 82)
	if is_instance_valid(contract_agent) and contract_agent.has_method("get_portrait_texture"):
		portrait.texture = contract_agent.call("get_portrait_texture") as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(title_box)
	var eyebrow := Label.new()
	eyebrow.text = "쉘터 지킴이 사자  ·  공생 시설 건설 계약"
	eyebrow.add_theme_font_override("font", FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#9fb2a9"))
	title_box.add_child(eyebrow)
	var title := Label.new()
	title.text = "사자의 쉘터 재건 계획"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#ead69c"))
	title_box.add_child(title)
	var chain_progress := Label.new()
	chain_progress.text = "완료한 건설 계약  %d / %d" % [completed_count, total_count]
	chain_progress.add_theme_font_override("font", FONT)
	chain_progress.add_theme_font_size_override("font_size", 13)
	chain_progress.add_theme_color_override("font_color", Color("#b9c8c1"))
	title_box.add_child(chain_progress)
	var close := _shelter_close_button()
	close.pressed.connect(_close_contract_ui)
	header.add_child(close)

	var separator := HSeparator.new()
	contract_ui_body.add_child(separator)
	var contract_card := PanelContainer.new()
	contract_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contract_card.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.035, 0.043, 0.04, 0.96), Color("#60786c"), 7)
	)
	contract_ui_body.add_child(contract_card)
	var contract_margin := MarginContainer.new()
	contract_margin.add_theme_constant_override("margin_left", 18)
	contract_margin.add_theme_constant_override("margin_top", 15)
	contract_margin.add_theme_constant_override("margin_right", 18)
	contract_margin.add_theme_constant_override("margin_bottom", 15)
	contract_card.add_child(contract_margin)
	var contract_box := VBoxContainer.new()
	contract_box.add_theme_constant_override("separation", 10)
	contract_margin.add_child(contract_box)

	if status == "finished" or definition.is_empty():
		var finished_title := Label.new()
		finished_title.text = "쉘터의 기본 생산망이 완성되었습니다"
		finished_title.add_theme_font_override("font", FONT)
		finished_title.add_theme_font_size_override("font_size", 24)
		finished_title.add_theme_color_override("font_color", Color("#82d5aa"))
		contract_box.add_child(finished_title)
		var finished_body := Label.new()
		# 계약 완주 후에도 사자는 매 복귀마다 도시 의뢰를 내건다. 완성 화면이
		# 막다른 벽이 아니라 다음 목표 게시판이 된다.
		var commission: Dictionary = GameState.get_city_commission()
		if not commission.is_empty() and not bool(commission.get("completed", false)):
			finished_body.text = "생산망은 완성됐다. 이제 도시를 되찾을 차례.\n\n이번 의뢰 · %s → 고철 %s%s" % [
				GameState.get_city_commission_summary(),
				GameState.format_compact_number(int(commission.get("reward_scrap", 0))),
				" + 츄르 %d" % int(commission.get("reward_churu", 0)) if int(commission.get("reward_churu", 0)) > 0 else "",
			]
		elif not commission.is_empty():
			finished_body.text = "이번 의뢰는 완수했다. 다음 복귀 때 새 의뢰를 준비해 두지."
		else:
			finished_body.text = "사자가 약속한 시설은 모두 가동되었습니다.\n이제 주민 배치와 업그레이드로 쉘터를 거대한 생존 공장으로 키우세요."
		finished_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		finished_body.add_theme_font_override("font", FONT)
		finished_body.add_theme_font_size_override("font_size", 16)
		finished_body.add_theme_color_override("font_color", Color("#d1ddd6"))
		contract_box.add_child(finished_body)
	else:
		var status_text := "새 건설 계약"
		match status:
			"active":
				status_text = "현장 목표 진행 중"
			"complete":
				status_text = "사자에게 결과 보고"
		var contract_heading := HBoxContainer.new()
		contract_heading.add_theme_constant_override("separation", 10)
		contract_box.add_child(contract_heading)
		var contract_title := Label.new()
		contract_title.text = str(definition.get("title", "현장 계약"))
		contract_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contract_title.add_theme_font_override("font", FONT)
		contract_title.add_theme_font_size_override("font_size", 24)
		contract_title.add_theme_color_override("font_color", Color("#f0d58d"))
		contract_heading.add_child(contract_title)
		var status_label_local := Label.new()
		status_label_local.text = str(status_text)
		status_label_local.add_theme_font_override("font", FONT)
		status_label_local.add_theme_font_size_override("font_size", 14)
		status_label_local.add_theme_color_override(
			"font_color",
			Color("#7de0a8") if status == "complete" else Color("#d5b96d")
		)
		contract_heading.add_child(status_label_local)
		var brief := Label.new()
		brief.text = str(definition.get("brief", "현장 목표를 따른다."))
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brief.add_theme_font_override("font", FONT)
		brief.add_theme_font_size_override("font_size", 16)
		brief.add_theme_color_override("font_color", Color("#c8d5ce"))
		contract_box.add_child(brief)
		var progress := int(state.get("progress", 0))
		var target := maxi(1, int(state.get("target", 1)))
		var objective_line := Label.new()
		objective_line.text = "%s    %d / %d" % [
			str(definition.get("objective", "목표")),
			progress,
			target,
		]
		objective_line.add_theme_font_override("font", FONT)
		objective_line.add_theme_font_size_override("font_size", 16)
		objective_line.add_theme_color_override("font_color", Color("#e5e0ce"))
		contract_box.add_child(objective_line)
		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 18)
		progress_bar.max_value = target
		progress_bar.value = progress
		progress_bar.show_percentage = false
		progress_bar.add_theme_stylebox_override(
			"background",
			_rounded_panel_style(Color("#101816"), Color("#32463e"), 7)
		)
		progress_bar.add_theme_stylebox_override(
			"fill",
			_rounded_panel_style(
				Color("#62bd8d") if status == "complete" else Color("#c49b4d"),
				Color.TRANSPARENT,
				7
			)
		)
		contract_box.add_child(progress_bar)
		var reward_title := Label.new()
		reward_title.text = "완료 보상과 건설 결과"
		reward_title.add_theme_font_override("font", FONT)
		reward_title.add_theme_font_size_override("font_size", 14)
		reward_title.add_theme_color_override("font_color", Color("#8fa89c"))
		contract_box.add_child(reward_title)
		var rewards := HFlowContainer.new()
		rewards.add_theme_constant_override("h_separation", 12)
		rewards.add_theme_constant_override("v_separation", 6)
		contract_box.add_child(rewards)
		_add_contract_reward_chips(
			rewards,
			definition.get("reward", {}) as Dictionary,
			definition
		)

	var latest_lore := GameState.get_latest_contract_lore()
	if not contract_report_message.is_empty() or not latest_lore.is_empty():
		var lore_panel := PanelContainer.new()
		lore_panel.add_theme_stylebox_override(
			"panel",
			_rounded_panel_style(Color(0.045, 0.04, 0.025, 0.92), Color("#8d7644"), 6)
		)
		contract_ui_body.add_child(lore_panel)
		var lore_margin := MarginContainer.new()
		for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			lore_margin.add_theme_constant_override(margin_name, 12)
		lore_panel.add_child(lore_margin)
		var lore_label := Label.new()
		lore_label.text = contract_report_message if not contract_report_message.is_empty() else latest_lore
		lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore_label.max_lines_visible = 4
		lore_label.add_theme_font_override("font", FONT)
		lore_label.add_theme_font_size_override("font_size", 14)
		lore_label.add_theme_color_override("font_color", Color("#dccb9f"))
		lore_margin.add_child(lore_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	contract_ui_body.add_child(actions)
	var close_text := _merchant_button("닫기", false, "close")
	close_text.custom_minimum_size = Vector2(130, 44)
	close_text.pressed.connect(_close_contract_ui)
	actions.add_child(close_text)
	var action := _merchant_button("", true, "collect")
	action.custom_minimum_size = Vector2(250, 44)
	match status:
		"available":
			action.text = "사자의 계약 받기"
			action.pressed.connect(_accept_current_contract)
		"active":
			action.text = "현장 목표 진행 중"
			action.disabled = true
		"complete":
			action.text = "사자에게 결과 보고"
			action.pressed.connect(_claim_current_contract)
		_:
			action.text = "모든 계약 완료"
			action.disabled = true
	actions.add_child(action)


func _add_contract_reward_chips(
	container: HFlowContainer,
	reward: Dictionary,
	definition: Dictionary = {}
) -> void:
	var entries := [
		["upgrade", "경험치 %d" % maxi(0, int(reward.get("xp", 0))), Color("#e4cc73")],
		["food", "통조림 %d" % maxi(0, int(reward.get("canned_food", 0))), Color("#e5b55b")],
		["ammo", "탄약 %d" % maxi(0, int(reward.get("ammo", 0))), Color("#d8c576")],
		["medkit", "구급약 %d" % maxi(0, int(reward.get("medkits", 0))), Color("#d47f74")],
		["churu", "츄르 %d" % maxi(0, int(reward.get("churu", 0))), Color("#d99b67")],
	]
	for entry in entries:
		var text := str(entry[1])
		if text.ends_with(" 0"):
			continue
		var color: Color = entry[2]
		container.add_child(_currency_chip(str(entry[0]), text, color, 22, 120))
	var facility_id := str(definition.get("facility_unlock", ""))
	if not facility_id.is_empty():
		container.add_child(
			_currency_chip(
				"upgrade",
				"시설 건설 · %s" % GameState.get_shelter_facility_name(facility_id),
				Color("#79c69a"),
				22,
				210
			)
		)


func _accept_current_contract() -> void:
	var result := GameState.accept_current_contract()
	if not bool(result.get("ok", false)):
		contract_report_message = "사자: 지금 맡긴 계약부터 끝내자. 쉘터는 순서대로 세워야 해."
	else:
		var definition := result.get("definition", {}) as Dictionary
		var story_lines: Array[String] = []
		for line in definition.get("accept_dialogue", []) as Array:
			story_lines.append(str(line))
		story_lines.append("목표는 %s. 살아서 돌아와 보고해." % str(
			definition.get("objective", "현장 목표 완수")
		))
		_show_status("사자에게서 시설 건설 계약을 받았습니다.")
		_close_contract_ui()
		_open_contract_story(
			"계약 수락 · %s" % str(definition.get("title", "현장 계약")),
			story_lines
		)
		return
	call_deferred("_refresh_contract_ui")


func _claim_current_contract() -> void:
	var result := GameState.claim_current_contract_reward()
	if not bool(result.get("ok", false)):
		contract_report_message = "사자: 아직 재료가 모자라. 계약 목표부터 확인하고 와."
	else:
		var definition := result.get("definition", {}) as Dictionary
		var construction_line := ""
		var facility_id := str(result.get("facility_id", ""))
		if not facility_id.is_empty():
			_refresh_unlocked_facilities()
			construction_line = "\n시설 완공 · %s" % str(result.get("facility_name", facility_id))
		var story_lines: Array[String] = []
		for line in definition.get("complete_dialogue", []) as Array:
			story_lines.append(str(line))
		story_lines.append("기록 해독 · %s\n%s" % [
			str(definition.get("lore_title", "사자의 기록")),
			str(definition.get("lore", "")),
		])
		var reward_line := "보고 보상 · %s" % _format_contract_reward_text(
			result.get("reward", {}) as Dictionary
		)
		if not construction_line.is_empty():
			reward_line += construction_line
		story_lines.append(reward_line)
		_show_status(
			"사자가 %s 공사를 완료했습니다." % str(result.get("facility_name", "새 시설"))
			if not facility_id.is_empty()
			else "계약 보상을 받고 새로운 세계 기록을 해금했습니다."
		)
		_update_stats()
		_close_contract_ui()
		_open_contract_story(
			"현장 보고 · %s" % str(definition.get("title", "계약 완료")),
			story_lines
		)
		return
	call_deferred("_refresh_contract_ui")


func _format_contract_reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for reward_data in [
		["xp", "경험치"],
		["canned_food", "통조림"],
		["ammo", "탄약"],
		["medkits", "구급약"],
		["churu", "츄르"],
	]:
		var amount := maxi(0, int(reward.get(str(reward_data[0]), 0)))
		if amount > 0:
			parts.append("%s +%d" % [str(reward_data[1]), amount])
	return " · ".join(parts)


func _close_contract_ui() -> void:
	contract_ui_open = false
	contract_report_message = ""
	if is_instance_valid(contract_ui_layer):
		contract_ui_layer.queue_free()
	contract_ui_layer = null
	contract_ui_body = null


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
	title.add_theme_font_size_override("font_size", 24)
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
	line.add_theme_font_size_override("font_size", 16)
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
	# 상점은 구경 UI라 닫아도 안전하다. 입장 카드(수락/거절)는 의도적 선택이라 제외.
	ModalDismiss.install(merchant_ui_layer, dim, _close_merchant_ui)
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
	title.add_theme_font_size_override("font_size", 24)
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
	(merchant_shop_currency_labels.get("scrap") as Label).text = "고철  %s" % GameState.format_compact_number(GameState.scrap)
	(merchant_shop_currency_labels.get("food") as Label).text = "통조림  %s" % GameState.format_compact_number(GameState.canned_food)
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
		empty_label.add_theme_font_size_override("font_size", 16)
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
	value_label.add_theme_font_size_override("font_size", 16)
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
	call_deferred("_refresh_merchant_shop")


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


func _build_health_row() -> Control:
	# 체력은 숫자만으로는 위험도가 안 읽혀서 바 + 수치를 함께 둔다.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.texture = UI_ICONS.get_icon("health", 20, Color("#e07a72"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	health_bar = ProgressBar.new()
	health_bar.name = "ShelterHealthBar"
	health_bar.custom_minimum_size = Vector2(186, 16)
	health_bar.show_percentage = false
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.07, 0.07, 0.95)
	track.border_color = Color("#3d5148")
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#c4574f")
	fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(health_bar)
	health_value_label = Label.new()
	health_value_label.add_theme_font_override("font", FONT)
	health_value_label.add_theme_font_size_override("font_size", 14)
	health_value_label.add_theme_color_override("font_color", Color("#dcdcd2"))
	health_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(health_value_label)
	return row


func _build_meter_row(parent: Node, icon_name: String, title: String, color: Color) -> Label:
	# 주민/생산 슬롯을 아이콘 + 라벨 + 수치의 같은 리듬으로 정렬한다.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.texture = UI_ICONS.get_icon(icon_name, 20, color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#9db3a9"))
	row.add_child(title_label)
	var value_label := Label.new()
	value_label.add_theme_font_override("font", FONT)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	value_label.set_meta("meter_row", row)
	return value_label


func _toggle_stats_panel() -> void:
	_set_stats_panel_expanded(not stats_panel_expanded)


func _set_stats_panel_expanded(expanded: bool) -> void:
	stats_panel_expanded = expanded
	if is_instance_valid(stats_body_box):
		stats_body_box.visible = expanded
	if is_instance_valid(stats_collapse_button):
		stats_collapse_button.text = "▲" if expanded else "▼"
		stats_collapse_button.tooltip_text = "쉘터 정보 접기" if expanded else "쉘터 정보 펼치기"
	if is_instance_valid(stats_summary_label):
		stats_summary_label.visible = not expanded
	_update_stats_summary()


func _update_stats_summary() -> void:
	# 접힌 상태에서 남길 것은 딱 두 가지다.
	# 지금 얼마나 모았는가, 그리고 언제 다시 나가야 하는가.
	if not is_instance_valid(stats_summary_label) or stats_panel_expanded:
		return
	var reason: String = GameState.get_shelter_stall_reason()
	var fuel := _format_runtime_duration(GameState.get_shelter_runtime_seconds())
	match reason:
		"no_workers":
			fuel = "주민 미배치"
		"no_food":
			fuel = "통조림 없음"
	stats_summary_label.text = "고철 %s  ·  가동 %s" % [
		GameState.format_compact_number(GameState.scrap),
		fuel,
	]
	stats_summary_label.add_theme_color_override(
		"font_color",
		Color("#c4574f") if not reason.is_empty() else Color("#9db3a9")
	)


func _update_runtime_row() -> void:
	if not is_instance_valid(shelter_runtime_label) or not is_instance_valid(shelter_runtime_bar):
		return
	var seconds: float = GameState.get_shelter_runtime_seconds()
	var reason: String = GameState.get_shelter_stall_reason()
	# 8시간을 가득 찬 상태로 본다. 그 이상은 어차피 여유롭다.
	var ratio := clampf(seconds / (8.0 * 3600.0), 0.0, 1.0)
	shelter_runtime_bar.value = ratio
	var fill := shelter_runtime_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var accent := Color("#6fc4a4")
	if seconds <= 0.0:
		accent = Color("#c4574f")
	elif seconds < 1800.0:
		accent = Color("#d08a4a")
	if fill != null:
		fill.bg_color = accent
	var text := _format_runtime_duration(seconds)
	match reason:
		"no_workers":
			text = "주민 미배치"
		"no_food":
			text = "통조림 없음 · 정지"
	shelter_runtime_label.text = text
	shelter_runtime_label.add_theme_color_override("font_color", accent)


func _build_runtime_row() -> Control:
	# 쉘터가 앞으로 얼마나 더 돌 수 있는지. 0에 가까울수록 다음 출정 압박이 커진다.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title_label := Label.new()
	title_label.text = "가동 연료"
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#9db3a9"))
	header.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	shelter_runtime_label = Label.new()
	shelter_runtime_label.add_theme_font_override("font", FONT)
	shelter_runtime_label.add_theme_font_size_override("font_size", 13)
	shelter_runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(shelter_runtime_label)
	shelter_runtime_bar = ProgressBar.new()
	shelter_runtime_bar.custom_minimum_size.y = 6
	shelter_runtime_bar.show_percentage = false
	shelter_runtime_bar.min_value = 0.0
	shelter_runtime_bar.max_value = 1.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.09, 0.12, 0.11, 0.9)
	track.set_corner_radius_all(3)
	shelter_runtime_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#6fc4a4")
	fill.set_corner_radius_all(3)
	shelter_runtime_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(shelter_runtime_bar)
	return box


func _format_runtime_duration(seconds: float) -> String:
	if seconds <= 0.0:
		return "정지"
	if seconds >= 3600.0:
		return "%.1f시간" % (seconds / 3600.0)
	if seconds >= 60.0:
		return "%d분" % int(seconds / 60.0)
	return "%d초" % int(seconds)


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
	value_label.add_theme_font_size_override("font_size", 14)
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
	# 주 행동(accent)은 골드 보더 + 큰 글씨, 보조는 표준. 4상태 전부 시스템이 정의.
	return HudStyle.style_button(button, HudStyle.GOLD if accent else HudStyle.LINE_FOCUS, accent)


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
	# 크기는 _layout_touch_stick()이 화면에 맞춰 정한다. 128px 고정이었을 때
	# 출정 화면 스틱만 커지고 쉘터는 그대로여서 조작감이 화면마다 달랐다.
	# 필드와 같은 공용 위젯을 쓴다. 예전에는 쉘터만 ColorRect 링+노브라
	# 화면마다 조작감이 달랐다.
	touch_stick = TOUCH_JOYSTICK.new()
	touch_stick.name = "ShelterTouchStick"
	touch_stick.moved.connect(func(vector: Vector2) -> void: touch_vector = vector)
	canvas.add_child(touch_stick)
	touch_stick.visible = DisplayServer.is_touchscreen_available()
	_layout_touch_stick()


func _layout_touch_stick() -> void:
	# 출정 화면과 같은 공식을 쓴다. 화면마다 스틱 크기가 다르면 손이 헷갈린다.
	if not is_instance_valid(touch_stick):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var safe := UISafeArea.get_margins(viewport_size)
	var stick_size := clampf(minf(viewport_size.x, viewport_size.y) * 0.28, 124.0, 240.0)
	var side_margin := maxf(safe.x, clampf(viewport_size.x * 0.02, 10.0, 26.0))
	var bottom_margin := maxf(safe.w, clampf(viewport_size.y * 0.018, 8.0, 26.0))
	touch_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	touch_stick.offset_left = side_margin
	touch_stick.offset_right = side_margin + stick_size
	touch_stick.offset_bottom = -bottom_margin
	touch_stick.offset_top = -bottom_margin - stick_size
	touch_stick.set_size(Vector2(stick_size, stick_size))
	touch_stick.queue_redraw()


func _apply_shelter_safe_layout() -> void:
	_apply_portrait_camera_aspect(shelter_camera)
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	_layout_touch_stick()
	var stats_panel := get_node_or_null("ShelterHUD/ShelterStatsPanel") as Control
	if stats_panel:
		stats_panel.position = Vector2(24.0 + safe.x, 22.0 + safe.y)
		# 접기 버튼을 없앴으므로 항상 펼친다. 내용 자체를 4재화+연료로 줄여
		# 모바일에서도 패널이 화면을 잠식하지 않는다.
		if not stats_panel_default_applied:
			stats_panel_default_applied = true
			_set_stats_panel_expanded(true)
		stats_panel.custom_minimum_size.x = (
			clampf(viewport_size.x * 0.42, 240.0, 370.0)
			if DisplayServer.is_touchscreen_available()
			else 370.0
		)
	if is_instance_valid(touch_stick):
		touch_stick.offset_left = 34.0 + safe.x
		touch_stick.offset_top = -160.0 - safe.w
		touch_stick.offset_right = touch_stick.offset_left + 128.0
		touch_stick.offset_bottom = touch_stick.offset_top + 128.0
	if is_instance_valid(shelter_medkit_button):
		var medkit_left := 174.0 if DisplayServer.is_touchscreen_available() else 24.0
		shelter_medkit_button.offset_left = medkit_left + safe.x
		shelter_medkit_button.offset_top = -104.0 - safe.w
		shelter_medkit_button.offset_right = shelter_medkit_button.offset_left + 104.0
		shelter_medkit_button.offset_bottom = shelter_medkit_button.offset_top + 80.0
	if is_instance_valid(interact_button):
		interact_button.offset_right = -36.0 - safe.z
		interact_button.offset_bottom = -70.0 - safe.w
		interact_button.offset_left = interact_button.offset_right - 118.0
		interact_button.offset_top = interact_button.offset_bottom - 72.0
	if is_instance_valid(dash_button):
		dash_button.offset_right = -166.0 - safe.z
		dash_button.offset_bottom = -70.0 - safe.w
		dash_button.offset_left = dash_button.offset_right - 118.0
		dash_button.offset_top = dash_button.offset_bottom - 72.0
	if is_instance_valid(prompt_label):
		prompt_label.offset_left = -220.0
		prompt_label.offset_right = 220.0
		prompt_label.offset_bottom = -60.0 - safe.w
		prompt_label.offset_top = prompt_label.offset_bottom - 52.0
	if is_instance_valid(status_panel):
		status_panel.offset_left = -270.0
		status_panel.offset_top = 24.0 + safe.y
		status_panel.offset_right = 270.0
		status_panel.offset_bottom = status_panel.offset_top + 52.0
	if ops_console != null:
		ops_console.apply_layout(safe)


func _update_nearby_station() -> void:
	if merchant_ui_open or contract_ui_open or contract_story_open:
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
	if is_instance_valid(contract_agent):
		var contract_distance := player.global_position.distance_to(contract_agent.global_position)
		var contract_radius := (
			float(contract_agent.call("get_interaction_radius"))
			if contract_agent.has_method("get_interaction_radius")
			else 2.35
		)
		if contract_distance <= contract_radius and contract_distance < nearest_distance:
			nearest = "contract_agent"
			nearest_distance = contract_distance
	if is_instance_valid(iron_trainer):
		var iron_distance := player.global_position.distance_to(iron_trainer.global_position)
		var iron_radius := (
			float(iron_trainer.call("get_interaction_radius"))
			if iron_trainer.has_method("get_interaction_radius")
			else 2.45
		)
		if iron_distance <= iron_radius and iron_distance < nearest_distance:
			nearest = "iron_trainer"
			nearest_distance = iron_distance
	if is_instance_valid(juhong_character):
		var juhong_distance := player.global_position.distance_to(juhong_character.global_position)
		var juhong_radius := (
			float(juhong_character.call("get_interaction_radius"))
			if juhong_character.has_method("get_interaction_radius")
			else 2.45
		)
		if juhong_distance <= juhong_radius and juhong_distance < nearest_distance:
			nearest = "juhong"
			nearest_distance = juhong_distance
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
	# 주민 곁을 지나면 잡담을 걸 수 있다. 관리(일 배정)는 운영 독이 맡고,
	# 발로 하는 건 대화뿐이다.
	var nearest_resident: Node3D
	for node in get_tree().get_nodes_in_group("shelter_resident"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var resident := node as Node3D
		var resident_distance := player.global_position.distance_to(resident.global_position)
		if resident_distance <= 1.55 and resident_distance < nearest_distance:
			nearest = "resident_chat"
			nearest_distance = resident_distance
			nearest_resident = resident
	current_chat_resident = nearest_resident
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
		# 기계가 사라진 지금 이 그룹에는 침대만 남아 있다.
		prompt_label.text = _interaction_prompt_text(str(current_module.call("get_interaction_prompt")))
		interact_button.text = "휴식"
		interact_button.icon = UI_ICONS.get_icon("recovery", 32, Color("#dce8e1"))
	elif current_station == "resident_chat":
		prompt_label.text = _interaction_prompt_text("주민과 잡담")
		interact_button.text = "잡담"
		interact_button.icon = UI_ICONS.get_icon("resident", 32, Color("#9fc9d8"))
	elif current_station == "merchant_waiting":
		prompt_label.text = _interaction_prompt_text("누군가와 대화")
		interact_button.text = "대화"
		interact_button.icon = UI_ICONS.get_icon("resident", 32, Color("#e4c874"))
	elif current_station == "merchant_shop":
		prompt_label.text = _interaction_prompt_text("행상인과 거래하기")
		interact_button.text = "거래"
		interact_button.icon = UI_ICONS.get_icon("backpack", 32, Color("#e4c874"))
	elif current_station == "contract_agent":
		var contract_prompt := (
			str(contract_agent.call("get_interaction_prompt"))
			if is_instance_valid(contract_agent) and contract_agent.has_method("get_interaction_prompt")
			else "사자에게 시설 계약 확인"
		)
		prompt_label.text = _interaction_prompt_text(contract_prompt)
		interact_button.text = "대화"
		interact_button.icon = UI_ICONS.get_icon("collect", 32, Color("#e4c874"))
	elif current_station == "iron_trainer":
		var iron_prompt := str(iron_trainer.call("get_interaction_prompt"))
		prompt_label.text = _interaction_prompt_text(iron_prompt)
		interact_button.text = "훈련"
		interact_button.icon = UI_ICONS.get_icon("fitness", 32, Color("#e4c874"))
	elif current_station == "juhong":
		prompt_label.text = _interaction_prompt_text("주홍과 대화하기")
		interact_button.text = "대화"
		interact_button.icon = UI_ICONS.get_icon("lore", 32, Color("#dc7667"))
	else:
		prompt_label.text = _interaction_prompt_text(str(_pipe_exit_station()["label"]))
		interact_button.text = "탐색"
		interact_button.icon = UI_ICONS.get_icon("upgrade", 32, Color("#dce8e1"))


func _interact() -> void:
	if merchant_ui_open or contract_ui_open or contract_story_open:
		return
	match current_station:
		"module":
			if is_instance_valid(current_module) and current_module.has_method("interact"):
				_show_status(str(current_module.call("interact")))
		"resident_chat":
			_spawn_resident_chat_bubble(current_chat_resident)
		"pipe_exit":
			_open_raid_zone_select()
		"merchant_waiting":
			_open_merchant_arrival_dialog()
		"merchant_shop":
			_open_merchant_shop()
		"contract_agent":
			_interact_with_saja()
		"iron_trainer":
			_open_iron_mission_dialog()
		"juhong":
			# 직접 말을 걸어도 전령의 대화는 연출을 탄다 — 레터박스 + 반걸음 접근.
			_play_juhong_entrance_cinematic(false)
	_update_stats()


# 잡담은 정보가 아니라 공기다. 다만 그 공기에 세계의 비밀이 조금씩 섞여 나온다.
const RESIDENT_CHAT_LINES := [
	"오늘도 사이렌은 남쪽에서만 울리더라.",
	"사람들 냄새가 하나도 안 남았어. 삼백 밤이 지났는데도.",
	"캣닢 배급이 늘었대. 나비 덕이라고들 해.",
	"격리 신호 얘기 들었어? 벽 너머에서 온다던데.",
	"발톱 관리는 게으름이 아니야. 생존이지.",
	"어젯밤 고철 더미에서 라디오가 지직거렸대. 아직 누가 있다는 거야.",
	"같은 문장만 반복되는 방송이 있대. 소름 돋아서 더는 안 들었어.",
	"철근 교관 무섭지. 근데 그 덕에 다들 살아 있잖아.",
	"바깥은 어때? …아니, 말 안 해도 돼. 얼굴에 다 써 있어.",
	"꾹꾹이도 하다 보면 요령이 붙어. 뭐든 그래.",
	"사자님은 뭔가 알고 있어. 말을 아끼는 것뿐이지.",
	"비 오는 날엔 도시가 조용해. 그게 더 무서워.",
]


func _spawn_resident_chat_bubble(resident: Node3D) -> void:
	if not is_instance_valid(resident):
		return
	var previous := resident.get_node_or_null("ChatBubble")
	if previous != null:
		previous.queue_free()
	var label := Label3D.new()
	label.name = "ChatBubble"
	label.text = RESIDENT_CHAT_LINES[resident_chat_random.randi_range(0, RESIDENT_CHAT_LINES.size() - 1)]
	label.font = FONT
	label.font_size = 30
	label.pixel_size = 0.0056
	label.width = 340.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 1.92, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 127
	label.modulate = Color(0.92, 0.95, 0.93, 0.0)
	label.outline_modulate = Color(0.015, 0.02, 0.016, 0.98)
	label.outline_size = 10
	resident.add_child(label)
	var fade := label.create_tween()
	fade.tween_property(label, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_interval(2.8)
	fade.tween_property(label, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_callback(label.queue_free)


func _update_stats() -> void:
	GameState._ensure_resident_records()
	if ops_console != null:
		ops_console.refresh()
	stats_label.text = "SHELTER 01   ·   Tier %d   ·   Lv.%d" % [
		GameState.shelter_tier,
		GameState.player_level,
	]
	var maximum_health := GameState.get_max_health()
	if is_instance_valid(health_bar):
		health_bar.max_value = maxf(1.0, float(maximum_health))
		health_bar.value = clampf(float(GameState.player_health), 0.0, health_bar.max_value)
		var ratio: float = float(GameState.player_health) / maxf(1.0, float(maximum_health))
		var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			# 위험 구간에서 색이 바뀌어야 숫자를 읽기 전에 상태가 보인다.
			fill.bg_color = (
				Color("#c4574f") if ratio <= 0.3
				else Color("#c8a24e") if ratio <= 0.6
				else Color("#5fa86a")
			)
	if is_instance_valid(health_value_label):
		health_value_label.text = "%d/%d" % [GameState.player_health, maximum_health]
	if is_instance_valid(resident_meter_label):
		resident_meter_label.text = "%d/%d" % [
			GameState.rescued_workers,
			GameState.get_resident_capacity(),
		]
	_update_production_meter("scratcher", "scratcher_bank",
		GameState.get_active_scratcher_workers(), GameState.get_scratcher_worker_slots())
	_update_production_meter("catnip", "catnip_scraper",
		GameState.get_active_catnip_workers(), GameState.get_catnip_worker_slots())
	if shelter_currency_labels.has("scrap"):
		# 아이콘이 이름을 대신한다. 숫자만 크게 — 4열 한 줄 컴팩트 표기의 핵심.
		(shelter_currency_labels["scrap"] as Label).text = GameState.format_compact_number(GameState.scrap)
		(shelter_currency_labels["catnip"] as Label).text = GameState.format_compact_number(GameState.catnip)
		(shelter_currency_labels["food"] as Label).text = GameState.format_compact_number(GameState.canned_food)
		(shelter_currency_labels["churu"] as Label).text = GameState.format_compact_number(GameState.churu)
	_update_runtime_row()
	_update_stats_summary()
	if shelter_upgrade_button:
		var cost := GameState.get_shelter_upgrade_cost()
		if cost.is_empty():
			shelter_upgrade_button.text = "쉘터 최고 Tier"
			shelter_upgrade_button.disabled = true
		else:
			var scrap_cost := int(cost.get("scrap", 0))
			var churu_cost := int(cost.get("churu", 0))
			var next_tier := GameState.shelter_tier + 1
			# 확장이 뭘 바꾸는지 버튼이 직접 말한다. 다음 티어로 열리는 출정 구역이
			# 있으면 그것부터 — 구역 해금이 확장의 가장 큰 이유다.
			var unlock_hint := ""
			for zone_id in GameState.get_raid_zone_ids():
				var zone: Dictionary = GameState.get_raid_zone(str(zone_id))
				if int(zone.get("required_tier", 1)) == next_tier:
					unlock_hint = "%s 해금" % str(zone.get("name", ""))
					break
			if unlock_hint.is_empty():
				unlock_hint = "수용·생산 슬롯 확장"
			shelter_upgrade_button.text = "Tier %d 확장 → %s  ·  고철 %s + 츄르 %s" % [
				next_tier,
				unlock_hint,
				GameState.format_compact_number(scrap_cost),
				GameState.format_compact_number(churu_cost),
			]
			shelter_upgrade_button.disabled = GameState.scrap < scrap_cost or GameState.churu < churu_cost
	_update_shelter_medkit_button()


func _update_production_meter(
	row_id: String, facility_id: String, active: int, slots: int
) -> void:
	var value_label := production_meter_rows.get(row_id) as Label
	if not is_instance_valid(value_label):
		return
	var row := value_label.get_meta("meter_row") as Control
	var unlocked: bool = GameState.is_shelter_facility_unlocked(facility_id)
	if is_instance_valid(row):
		row.visible = unlocked
	if not unlocked:
		return
	value_label.text = "%d/%d" % [active, slots]
	# 배치 가능한 빈 슬롯이 남았다는 걸 색으로 먼저 알린다.
	value_label.modulate = (
		Color(1.0, 1.0, 1.0, 1.0) if active >= slots else Color(1.0, 0.86, 0.45, 1.0)
	)


func _update_shelter_medkit_button() -> void:
	if shelter_medkit_button == null:
		return
	shelter_medkit_button.text = (
		"구급약\nx%d" % GameState.medkits
		if DisplayServer.is_touchscreen_available()
		else "SHIFT\nx%d" % GameState.medkits
	)
	shelter_medkit_button.disabled = (
		GameState.medkits <= 0
		or GameState.player_health <= 0
		or GameState.player_health >= GameState.get_max_health()
	)
	shelter_medkit_button.tooltip_text = "구급약 사용 (Shift)"


func _use_shelter_medkit() -> void:
	if _ui_blocks_player():
		return
	var maximum_health := GameState.get_max_health()
	if GameState.medkits <= 0:
		_show_status("보유한 구급약이 없습니다.")
		return
	if GameState.player_health >= maximum_health:
		_show_status("체력이 이미 가득 찼습니다.")
		return
	GameState.medkits -= 1
	var recovered := mini(38, maximum_health - GameState.player_health)
	GameState.player_health += recovered
	GameState.save_persistent_state()
	_update_stats()
	_show_status("구급약 회복 +%d" % recovered)


func _refresh_inventory_state() -> void:
	if inventory_ui == null:
		return
	_refresh_shelter_weapon_card()
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
	else:
		_refresh_shelter_weapon_card()


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


func _on_inventory_item_discard_requested(item_type: String, item_id: String, amount: int) -> void:
	if RAID_ITEM_ECONOMY.is_protected(item_type, item_id):
		inventory_ui.call("apply_discard_result", false, "중요 임무 물품은 버릴 수 없습니다.")
		return
	if item_type == "weapon" and bool(GameState.has_ak) and item_id == str(GameState.equipped_weapon_id):
		inventory_ui.call("apply_discard_result", false, "장착을 해제한 뒤 버릴 수 있습니다.")
		return
	if item_type == "equipment":
		var definition: Dictionary = GameState.get_equipment_definition(item_id)
		var slot := str(definition.get("slot", "body"))
		if str(GameState.get_equipped_equipment(slot)) == item_id:
			inventory_ui.call("apply_discard_result", false, "장착을 해제한 뒤 버릴 수 있습니다.")
			return
	var removed: int = GameState.remove_raid_bag_item(item_type, item_id, amount)
	if removed <= 0:
		inventory_ui.call("apply_discard_result", false, "버릴 수 없는 아이템입니다.")
		return
	GameState.save_persistent_state()
	inventory_ui.call("apply_discard_result", true, "%s x%d을 폐기했습니다." % [
		_inventory_discard_display_name(item_type, item_id),
		removed,
	])
	_refresh_inventory_state()
	_update_shelter_medkit_button()


func _inventory_discard_display_name(item_type: String, item_id: String) -> String:
	if item_type == "weapon":
		return str(WEAPON_SYSTEM.get_weapon(item_id).get("display_name", item_id))
	if item_type == "equipment":
		return str(GameState.get_equipment_definition(item_id).get("display_name", item_id))
	var names := {
		"canned_food": "통조림",
		"medkit": "구급약",
		"churu": "츄르",
		"rubber_gasket": "고무 패킹",
		"scope_lens": "스코프 렌즈",
		"magazine_spring": "탄창 스프링",
	}
	return str(names.get(item_id, item_id))


var shelter_tier_upgrade_armed_msec := 0


func _upgrade_shelter_tier() -> void:
	# 최대 지출 + 씬 리로드가 걸린 파괴적 행동 — 원탭으로 나가면 안 된다.
	# 첫 탭은 비용을 다시 보여주며 무장, 4초 안의 두 번째 탭만 실행.
	if Time.get_ticks_msec() - shelter_tier_upgrade_armed_msec > 4000:
		shelter_tier_upgrade_armed_msec = Time.get_ticks_msec()
		var cost: Dictionary = GameState.get_shelter_upgrade_cost()
		_show_status("한 번 더 누르면 확장 · 고철 %s%s 소모" % [
			GameState.format_compact_number(int(cost.get("scrap", 0))),
			(" + 츄르 %d" % int(cost.get("churu", 0))) if int(cost.get("churu", 0)) > 0 else "",
		])
		return
	shelter_tier_upgrade_armed_msec = 0
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
		scrap_gain_label.text = "+%s 고철   %s/s" % [
			GameState.format_compact_number(gained),
			GameState.format_compact_number(GameState.get_scrap_per_second()),
		]
		scrap_gain_label.modulate.a = 1.0


func _open_raid_zone_select() -> void:
	if raid_zone_ui_open:
		return
	raid_zone_ui_open = true
	raid_zone_selected_id = ""
	raid_zone_map_markers.clear()
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
	panel.name = "RaidZoneSelectPanel"
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(1120.0, maxf(0.0, viewport_size.x - 24.0))
	# 세로 화면은 세로로 길게 쓴다. 700 상한을 그대로 두면 위아래에 죽은 여백만 남는다.
	var panel_height_cap := 1180.0 if viewport_size.y > viewport_size.x else 700.0
	var panel_height := minf(panel_height_cap, maxf(0.0, viewport_size.y - 24.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.023, 0.99), Color("#8f7950")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var header_icon := TextureRect.new()
	header_icon.custom_minimum_size = Vector2(42, 42)
	header_icon.texture = UI_ICONS.get_icon("map", 42, Color("#d8bd72"))
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(header_icon)
	var title := Label.new()
	title.text = "서울 작전 지도"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#ead69c"))
	header.add_child(title)
	var close := _shelter_close_button()
	close.pressed.connect(_close_raid_zone_select)
	header.add_child(close)
	var subtitle := Label.new()
	subtitle.text = "진입 지점을 고른다. 깊이 들어갈수록 위험하고, 그만큼 희귀한 것이 남아 있다."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#aebdb5"))
	box.add_child(subtitle)
	# 세로 화면에서는 지도(위)·브리핑(아래)로 쌓는다. 가로 2열을 세로에 우겨넣으면
	# 지도가 우표만 해지고 브리핑은 한 줄에 몇 글자씩 흐른다.
	var portrait_layout := viewport_size.y > viewport_size.x
	var body: BoxContainer = VBoxContainer.new() if portrait_layout else HBoxContainer.new()
	body.name = "RaidZoneMapBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	box.add_child(body)

	var map_frame := PanelContainer.new()
	map_frame.name = "SeoulMapFrame"
	if portrait_layout:
		# 지도는 위쪽 40%. 마커 5개를 만질 수 있을 만큼은 크고, 브리핑과 출정
		# 버튼(엄지 권역)이 아래 60%를 가져간다.
		map_frame.custom_minimum_size = Vector2(0.0, panel_height * 0.40)
	else:
		map_frame.custom_minimum_size.x = maxf(310.0, panel_width - 390.0)
		map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.clip_contents = true
	map_frame.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.012, 0.018, 0.018, 1.0), Color("#536b61"), 6)
	)
	body.add_child(map_frame)
	var map_texture := TextureRect.new()
	map_texture.name = "SeoulOperationsMap"
	map_texture.texture = RAID_ZONE_MAP_TEXTURE
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(map_texture)
	var map_tint := ColorRect.new()
	map_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_tint.color = Color(0.025, 0.045, 0.042, 0.13)
	map_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_texture.add_child(map_tint)
	var marker_layer := Control.new()
	marker_layer.name = "RaidZoneMarkerLayer"
	marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_texture.add_child(marker_layer)
	var zone_ids := GameState.get_raid_zone_ids()
	for zone_index in zone_ids.size():
		var zone_id := str(zone_ids[zone_index])
		marker_layer.add_child(_build_raid_zone_map_marker(zone_id, zone_index))

	var legend := PanelContainer.new()
	legend.name = "RaidMapLegend"
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.position = Vector2(14, -48)
	legend.custom_minimum_size = Vector2(270, 34)
	legend.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.01, 0.015, 0.014, 0.88), Color(0.33, 0.43, 0.39, 0.8), 4)
	)
	map_texture.add_child(legend)
	var legend_label := Label.new()
	legend_label.text = "● 진입 가능    ◇ 선택 구역    ■ 봉쇄 구역"
	legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend_label.add_theme_font_override("font", FONT)
	legend_label.add_theme_font_size_override("font_size", 12)
	legend_label.add_theme_color_override("font_color", Color("#c0cec6"))
	legend.add_child(legend_label)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "RaidZoneBriefingPanel"
	detail_panel.custom_minimum_size.x = 300
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override(
		"panel",
		_rounded_panel_style(Color(0.025, 0.034, 0.032, 0.98), Color("#52695f"), 6)
	)
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		detail_margin.add_theme_constant_override(margin_name, 16)
	detail_panel.add_child(detail_margin)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_column)
	# 브리핑 본문은 스크롤 안에 둔다. 창이 낮아도 출정 버튼이 잘리지 않아야 한다.
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_column.add_child(detail_scroll)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 9)
	detail_scroll.add_child(detail_box)
	var briefing_header := HBoxContainer.new()
	briefing_header.add_theme_constant_override("separation", 8)
	detail_box.add_child(briefing_header)
	var briefing_icon := TextureRect.new()
	briefing_icon.custom_minimum_size = Vector2(30, 30)
	briefing_icon.texture = UI_ICONS.get_icon("alert", 30, Color("#d8bd72"))
	briefing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	briefing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	briefing_header.add_child(briefing_icon)
	var briefing_label := Label.new()
	briefing_label.text = "작전 브리핑"
	briefing_label.add_theme_font_override("font", FONT)
	briefing_label.add_theme_font_size_override("font_size", 14)
	briefing_label.add_theme_color_override("font_color", Color("#9eb2a8"))
	briefing_header.add_child(briefing_label)
	raid_zone_detail_state = Label.new()
	raid_zone_detail_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raid_zone_detail_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	raid_zone_detail_state.add_theme_font_override("font", FONT)
	raid_zone_detail_state.add_theme_font_size_override("font_size", 13)
	briefing_header.add_child(raid_zone_detail_state)
	raid_zone_detail_title = Label.new()
	raid_zone_detail_title.add_theme_font_override("font", FONT)
	raid_zone_detail_title.add_theme_font_size_override("font_size", 24)
	raid_zone_detail_title.add_theme_color_override("font_color", Color("#f0e3bc"))
	detail_box.add_child(raid_zone_detail_title)
	raid_zone_detail_description = Label.new()
	raid_zone_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raid_zone_detail_description.add_theme_font_override("font", FONT)
	raid_zone_detail_description.add_theme_font_size_override("font_size", 14)
	raid_zone_detail_description.add_theme_color_override("font_color", Color("#b7c7bf"))
	detail_box.add_child(raid_zone_detail_description)
	raid_zone_detail_rule = Label.new()
	raid_zone_detail_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raid_zone_detail_rule.add_theme_font_override("font", FONT)
	raid_zone_detail_rule.add_theme_font_size_override("font_size", 14)
	raid_zone_detail_rule.add_theme_color_override("font_color", Color("#d8bd72"))
	raid_zone_detail_rule.visible = false
	detail_box.add_child(raid_zone_detail_rule)
	# 위협도는 헤더 오른쪽의 등급 칩으로만 말한다(막대·퍼센트 제거). 작전 규모/
	# 예상 시간/보급 수치는 화면만 채워서 걷어냈다. 츄르 보급 버프도 제거.
	raid_zone_detail_reward = Label.new()
	raid_zone_detail_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_build_raid_zone_detail_entry("loot", "주요 전리품", raid_zone_detail_reward))
	# 출정 준비 — 지금 몸에 걸친 것. 가방 여유·탄약·구급약을 한눈에. 위협도 숫자
	# 대신 "내가 준비됐나"를 말하는, 실제로 결정에 쓰이는 정보다.
	raid_zone_detail_loadout = Label.new()
	raid_zone_detail_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_build_raid_zone_detail_entry("backpack", "출정 준비", raid_zone_detail_loadout))
	# 잠긴 구역일 때만 뜨는 상태 문구(키카드/티어 필요). 평상시엔 숨긴다.
	raid_zone_detail_requirement = Label.new()
	raid_zone_detail_requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raid_zone_detail_requirement.add_theme_font_override("font", FONT)
	raid_zone_detail_requirement.add_theme_font_size_override("font_size", 14)
	raid_zone_detail_requirement.add_theme_color_override("font_color", Color("#d78371"))
	raid_zone_detail_requirement.visible = false
	detail_box.add_child(raid_zone_detail_requirement)
	# 캣닢 급여 택1 — 착즙 라인이 곧 전투 준비라는 등식을 여기서 만든다.
	detail_column.add_child(_build_catnip_buff_row())
	raid_zone_resupply_button = _merchant_button("창고에서 빠른 보충", false, "backpack")
	raid_zone_resupply_button.name = "RaidZoneResupplyButton"
	raid_zone_resupply_button.custom_minimum_size.y = 44
	raid_zone_resupply_button.tooltip_text = "장착 무기 탄약 90발과 구급약 2개까지 창고에서 꺼냅니다."
	raid_zone_resupply_button.pressed.connect(_quick_resupply_for_raid, CONNECT_DEFERRED)
	detail_column.add_child(raid_zone_resupply_button)
	raid_zone_launch_button = _merchant_button("선택 구역으로 출정", true, "raid")
	raid_zone_launch_button.name = "RaidZoneLaunchButton"
	raid_zone_launch_button.custom_minimum_size.y = 52
	raid_zone_launch_button.pressed.connect(_launch_selected_raid_zone, CONNECT_DEFERRED)
	detail_column.add_child(raid_zone_launch_button)

	# 재출정 마찰 줄이기: 지난번에 갔던 구역을 기억해 미리 선택해 둔다.
	# 브리핑을 열면 바로 '선택 구역으로 출정'만 누르면 된다.
	var initial_zone_id := ""
	if GameState.is_raid_zone_unlocked(GameState.selected_raid_zone):
		initial_zone_id = GameState.selected_raid_zone
	if initial_zone_id.is_empty():
		for zone_id in zone_ids:
			if GameState.is_raid_zone_unlocked(str(zone_id)):
				initial_zone_id = str(zone_id)
				break
	if initial_zone_id.is_empty() and not zone_ids.is_empty():
		initial_zone_id = str(zone_ids[0])
	_select_raid_zone_preview(initial_zone_id)


var raid_catnip_buff_choice := ""
var raid_catnip_buff_buttons: Dictionary = {}


func _build_catnip_buff_row() -> Control:
	# 출정 전에 캣닢 한 줌 = 한 판짜리 체질 보정. 세 개 중 하나만 고를 수 있다.
	raid_catnip_buff_choice = ""
	raid_catnip_buff_buttons.clear()
	var box := VBoxContainer.new()
	box.name = "CatnipBuffRow"
	box.add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#9db3a9"))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for buff_id in GameState.CATNIP_FIELD_BUFFS:
		var definition: Dictionary = GameState.CATNIP_FIELD_BUFFS[buff_id]
		var button := Button.new()
		button.name = "CatnipBuff_%s" % buff_id
		button.toggle_mode = true
		# 효과는 버튼 본문에 직접 쓴다 — 터치엔 툴팁이 없다.
		var effect := str(definition.get("description", "")).replace("이번 출정 동안 ", "")
		button.text = "%s\n%s" % [str(definition.get("title", buff_id)), effect]
		button.tooltip_text = "%s · 캣닢 %s" % [
			str(definition.get("description", "")),
			GameState.format_compact_number(GameState.get_catnip_field_buff_cost()),
		]
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = UI_ICONS.get_icon(str(definition.get("icon", "catnip")), 18, Color("#aeea78"))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 18)
		HudStyle.style_button(button, Color("#7fb069"))
		button.toggled.connect(_on_catnip_buff_toggled.bind(str(buff_id)))
		row.add_child(button)
		raid_catnip_buff_buttons[str(buff_id)] = button
	_refresh_catnip_buff_row(title)
	box.set_meta("title_label", title)
	return box


func _refresh_catnip_buff_row(title: Label) -> void:
	# 가격은 "내 캣닢 생산 20분치" — 인크리멘탈 성장에 비례해 따라온다.
	var cost := GameState.get_catnip_field_buff_cost()
	for buff_id in raid_catnip_buff_buttons:
		var button := raid_catnip_buff_buttons[buff_id] as Button
		button.disabled = GameState.catnip < cost and raid_catnip_buff_choice != str(buff_id)
	title.text = "캣닢 급여 · 한 판 버프 택1 (캣닢 %s) · 보유 %s" % [
		GameState.format_compact_number(cost),
		GameState.format_compact_number(GameState.catnip),
	]


func _on_catnip_buff_toggled(pressed: bool, buff_id: String) -> void:
	# 토글 하나만 켜지게. 실제 소비는 출정 확정 순간에 이뤄진다.
	if pressed:
		raid_catnip_buff_choice = buff_id
		for other_id in raid_catnip_buff_buttons:
			if str(other_id) != buff_id:
				(raid_catnip_buff_buttons[other_id] as Button).set_pressed_no_signal(false)
	elif raid_catnip_buff_choice == buff_id:
		raid_catnip_buff_choice = ""


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
	name_label.add_theme_font_size_override("font_size", 20)
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
	var required_tier := int(zone.get("required_tier", 1))
	var needs_keycard := (
		required_tier >= 4
		and GameState.shelter_tier >= required_tier
		and GameState.get_progression_item_count("sealed_zone_keycard") <= 0
	)
	launch.text = (
		"출정"
		if unlocked
		else ("키카드 필요" if needs_keycard else "Tier %d 필요" % required_tier)
	)
	launch.icon = UI_ICONS.get_icon("upgrade" if not unlocked else "raid", 30, Color("#e6d8ae"))
	launch.expand_icon = true
	launch.disabled = not unlocked
	launch.add_theme_font_override("font", FONT)
	launch.add_theme_font_size_override("font_size", 14)
	launch.pressed.connect(func() -> void: _launch_raid_zone(zone_id))
	content.add_child(launch)
	return row


func _build_raid_zone_map_marker(zone_id: String, zone_index: int) -> Control:
	var zone := GameState.get_raid_zone(zone_id)
	var map_position: Vector2 = RAID_ZONE_MAP_POSITIONS.get(zone_id, Vector2(0.5, 0.5))
	var wrapper := Control.new()
	wrapper.name = "RaidZoneNode_%s" % zone_id
	wrapper.set_anchor(SIDE_LEFT, map_position.x)
	wrapper.set_anchor(SIDE_RIGHT, map_position.x)
	wrapper.set_anchor(SIDE_TOP, map_position.y)
	wrapper.set_anchor(SIDE_BOTTOM, map_position.y)
	wrapper.offset_left = -66
	wrapper.offset_right = 66
	wrapper.offset_top = -31
	wrapper.offset_bottom = 52
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marker := Button.new()
	marker.name = "RaidZoneMarker_%s" % zone_id
	marker.position = Vector2(39, 0)
	marker.size = Vector2(54, 54)
	marker.text = "%02d" % (zone_index + 1)
	marker.tooltip_text = str(zone.get("name", zone_id))
	marker.focus_mode = Control.FOCUS_ALL
	marker.add_theme_font_override("font", FONT)
	marker.add_theme_font_size_override("font_size", 14)
	marker.add_theme_color_override("font_color", Color("#f5e5b6"))
	marker.add_theme_color_override("font_hover_color", Color.WHITE)
	marker.pressed.connect(_select_raid_zone_preview.bind(zone_id))
	wrapper.add_child(marker)
	raid_zone_map_markers[zone_id] = marker
	var zone_name := Label.new()
	zone_name.name = "ZoneName"
	zone_name.position = Vector2(0, 55)
	zone_name.size = Vector2(132, 25)
	zone_name.text = str(zone.get("name", zone_id))
	zone_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_name.add_theme_font_override("font", FONT)
	zone_name.add_theme_font_size_override("font_size", 13)
	zone_name.add_theme_color_override(
		"font_color",
		Color("#d9e2dc") if GameState.is_raid_zone_unlocked(zone_id) else Color("#7b8580")
	)
	zone_name.add_theme_color_override("font_outline_color", Color(0.005, 0.008, 0.008, 1.0))
	zone_name.add_theme_constant_override("outline_size", 5)
	wrapper.add_child(zone_name)
	return wrapper


func _build_raid_zone_detail_entry(icon_name: String, title: String, value_label: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = UI_ICONS.get_icon(icon_name, 34, Color("#d3b86b"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color("#82958b"))
	text_box.add_child(title_label)
	value_label.add_theme_font_override("font", FONT)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color("#e2d3a7"))
	text_box.add_child(value_label)
	return row


func _select_raid_zone_preview(zone_id: String) -> void:
	if zone_id.is_empty() or not GameState.get_raid_zone_ids().has(zone_id):
		return
	raid_zone_selected_id = zone_id
	var zone := GameState.get_raid_zone(zone_id)
	var unlocked := GameState.is_raid_zone_unlocked(zone_id)
	var required_tier := int(zone.get("required_tier", 1))
	var needs_keycard := (
		required_tier >= 4
		and GameState.shelter_tier >= required_tier
		and GameState.get_progression_item_count("sealed_zone_keycard") <= 0
	)
	raid_zone_detail_title.text = str(zone.get("name", zone_id))
	var identity := str(zone.get("identity", ""))
	var base_description := str(zone.get("description", ""))
	var tactical_rule := str(zone.get("tactical_rule", ""))
	# 정체성과 설명은 같은 말을 두 번 하는 경우가 많다. 화면엔 한 줄만 남기고
	# 상세 설명은 툴팁으로 내린다.
	raid_zone_detail_description.text = identity if not identity.is_empty() else base_description
	if not tactical_rule.is_empty():
		raid_zone_detail_description.text += "\n전술 · %s" % tactical_rule
	# 존 고유 규칙 — 이 구역이 다른 구역과 어떻게 다르게 굴러가는지. 위협도
	# 숫자가 아니라, 준비물이 달라지는 정보라 눈에 띄게 노란색으로 붙인다.
	# 특수 규칙이 있는 구역에서만 노란 줄로 알린다. 규칙 없는 초반 구역에서
	# "특수 규칙 없음"을 띄우는 건 소음이라 아예 감춘다.
	var rule_brief := str(zone.get("rule_brief", ""))
	var has_special_rule := not str(zone.get("zone_rule", "")).is_empty()
	if is_instance_valid(raid_zone_detail_rule):
		if rule_brief.is_empty() or not has_special_rule:
			raid_zone_detail_rule.visible = false
		else:
			raid_zone_detail_rule.visible = true
			raid_zone_detail_rule.text = "⚑ %s" % rule_brief
	# 나가기 직전에 "지난 출정 이후 내가 뭐가 나아졌는지"를 확인시킨다. 성장은
	# 숫자가 오르는 순간이 아니라, 그 숫자를 들고 나가는 순간에 체감된다.
	var growth := GameState.build_pre_raid_changes()
	if not growth.is_empty():
		raid_zone_detail_description.text += "\n\n지난 출정 이후 ·  %s" % "    ".join(growth)
	raid_zone_detail_description.tooltip_text = base_description
	raid_zone_detail_reward.text = str(zone.get("loot_focus", zone.get("reward", "-")))
	var threat_percent := roundi(float(zone.get("threat", 0.0)) * 100.0)
	if unlocked:
		# 위협도는 헤더 칩에 등급으로만. 낮음/보통/높음/극심.
		var tier_label := "위협 낮음"
		var tier_color := Color("#72d6a0")
		if threat_percent >= 75:
			tier_label = "위협 극심"
			tier_color = Color("#e36f55")
		elif threat_percent >= 50:
			tier_label = "위협 높음"
			tier_color = Color("#e39b55")
		elif threat_percent >= 25:
			tier_label = "위협 보통"
			tier_color = Color("#e3cf67")
		raid_zone_detail_state.text = "◆ %s" % tier_label
		raid_zone_detail_state.add_theme_color_override("font_color", tier_color)
		raid_zone_detail_state.tooltip_text = ""
		raid_zone_detail_requirement.visible = false
		var manifest := GameState.build_raid_loadout_manifest(zone_id)
		var ammo_count := int(manifest.get("ammo_count", 0))
		var medkit_count := int(manifest.get("medkits", 0))
		if is_instance_valid(raid_zone_detail_loadout):
			var manifest_weapon_id := str(manifest.get("weapon_id", ""))
			var weapon_display := (
				str(WEAPON_SYSTEM.get_weapon(manifest_weapon_id).get("display_name", manifest_weapon_id))
				if not manifest_weapon_id.is_empty()
				else "맨손 · 현장 조달"
			)
			raid_zone_detail_loadout.text = "%s\n가방 %d/%d칸 · 탄약 %d발 · 구급약 %d개" % [
				weapon_display,
				GameState.get_raid_bag_used_slots(),
				GameState.get_raid_bag_capacity(),
				ammo_count,
				medkit_count,
			]
			var loadout_short := ammo_count < 60 or medkit_count <= 0
			raid_zone_detail_loadout.add_theme_color_override(
				"font_color", Color("#e0b06a") if loadout_short else Color("#b7c7bf")
			)
		var weapon_id := str(manifest.get("weapon_id", ""))
		var ammo_id := str(GameState.equipped_ammo_id) if not weapon_id.is_empty() else ""
		var stored_ammo := (
			GameState.get_stored_storage_count("ammo", ammo_id)
			if not ammo_id.is_empty()
			else 0
		)
		var stored_medkits := GameState.get_stored_storage_count("medkit", "medkit")
		var needs_supply := ammo_count < 90 or medkit_count < 2
		var has_storage_supply := (
			(ammo_count < 90 and stored_ammo > 0)
			or (medkit_count < 2 and stored_medkits > 0)
		)
		var can_buy_supply := needs_supply and GameState.scrap >= SCRAP_AMMO_BUNDLE_COST
		var can_resupply := has_storage_supply or can_buy_supply
		# 부족할 때만 버튼을 띄운다. 창고가 비어도 고철로 산다(초반 고철의 소비처).
		raid_zone_resupply_button.visible = can_resupply
		raid_zone_resupply_button.disabled = not can_resupply
		if has_storage_supply:
			raid_zone_resupply_button.text = "창고에서 보충 · 탄약 %d / 구급약 %d" % [
				stored_ammo, stored_medkits
			]
		elif can_buy_supply:
			raid_zone_resupply_button.text = "사자에게 보급 구매 · 탄 30발 %s / 구급약 %s" % [
				GameState.format_compact_number(SCRAP_AMMO_BUNDLE_COST),
				GameState.format_compact_number(SCRAP_MEDKIT_COST),
			]
	else:
		raid_zone_detail_state.text = "■ 봉쇄 구역"
		raid_zone_detail_state.add_theme_color_override("font_color", Color("#d78371"))
		raid_zone_detail_requirement.visible = true
		raid_zone_detail_requirement.text = (
			"봉쇄 구역 키카드 필요" if needs_keycard else "쉘터 Tier %d 필요" % required_tier
		)
		raid_zone_resupply_button.visible = false
	raid_zone_launch_button.disabled = not unlocked
	raid_zone_launch_button.text = (
		"선택 구역으로 출정"
		if unlocked
		else ("키카드 필요" if needs_keycard else "Tier %d에서 해금" % required_tier)
	)
	raid_zone_launch_button.icon = UI_ICONS.get_icon(
		"raid" if unlocked else "secure",
		30,
		Color("#f0dda7") if unlocked else Color("#7b837f")
	)
	_refresh_raid_zone_map_markers()


func _refresh_raid_zone_map_markers() -> void:
	for zone_id in raid_zone_map_markers:
		var marker := raid_zone_map_markers[zone_id] as Button
		if not is_instance_valid(marker):
			continue
		var unlocked := GameState.is_raid_zone_unlocked(str(zone_id))
		var selected := str(zone_id) == raid_zone_selected_id
		marker.add_theme_stylebox_override("normal", _raid_zone_marker_style(unlocked, selected, false))
		marker.add_theme_stylebox_override("hover", _raid_zone_marker_style(unlocked, true, true))
		marker.add_theme_stylebox_override("pressed", _raid_zone_marker_style(unlocked, true, true))
		marker.add_theme_stylebox_override("focus", _raid_zone_marker_style(unlocked, true, false))


func _raid_zone_marker_style(unlocked: bool, selected: bool, hovered: bool) -> StyleBoxFlat:
	var background := Color(0.055, 0.075, 0.069, 0.96) if unlocked else Color(0.035, 0.04, 0.04, 0.94)
	var border := Color("#6aa985") if unlocked else Color("#626a66")
	if selected:
		background = Color(0.18, 0.145, 0.065, 0.98)
		border = Color("#efd274")
	elif hovered:
		background = background.lightened(0.08)
	var style := _rounded_panel_style(background, border, 27)
	style.border_width_left = 3 if selected else 2
	style.border_width_top = 3 if selected else 2
	style.border_width_right = 3 if selected else 2
	style.border_width_bottom = 3 if selected else 2
	style.shadow_color = Color(border.r, border.g, border.b, 0.36 if selected else 0.18)
	style.shadow_size = 9 if selected else 4
	return style


func _launch_selected_raid_zone() -> void:
	if raid_launch_in_progress or raid_zone_selected_id.is_empty():
		return
	_launch_raid_zone(raid_zone_selected_id)


func _quick_resupply_for_raid() -> void:
	if raid_zone_selected_id.is_empty():
		return
	var manifest := GameState.build_raid_loadout_manifest(raid_zone_selected_id)
	var moved_ammo := 0
	var moved_medkits := 0
	var failure_reason := ""
	var weapon_id := str(manifest.get("weapon_id", ""))
	var ammo_id := str(GameState.equipped_ammo_id) if not weapon_id.is_empty() else ""
	if not ammo_id.is_empty():
		var ammo_needed := maxi(0, 90 - int(manifest.get("ammo_count", 0)))
		if ammo_needed > 0:
			var ammo_result := GameState.withdraw_storage_item_by_type("ammo", ammo_id, ammo_needed)
			moved_ammo = int(ammo_result.get("moved", 0))
			if moved_ammo <= 0:
				failure_reason = str(ammo_result.get("reason", ""))
	var medkits_needed := maxi(0, 2 - int(manifest.get("medkits", 0)))
	if medkits_needed > 0:
		var medkit_result := GameState.withdraw_storage_item_by_type("medkit", "medkit", medkits_needed)
		moved_medkits = int(medkit_result.get("moved", 0))
		if moved_medkits <= 0 and failure_reason.is_empty():
			failure_reason = str(medkit_result.get("reason", ""))
	# 창고가 비어도 고철로 산다. 초반에 쌓이기만 하던 고철의 첫 소비처 —
	# "다음 판 준비"에 돈을 쓰는 감각이 파밍의 이유를 만든다.
	var bought_ammo := 0
	var bought_medkits := 0
	var scrap_spent := 0
	if not ammo_id.is_empty():
		var still_needed_ammo := maxi(0, 90 - int(manifest.get("ammo_count", 0)) - moved_ammo)
		if still_needed_ammo > 0:
			var ammo_bundles := ceili(float(still_needed_ammo) / 30.0)
			for _bundle in ammo_bundles:
				if GameState.scrap < SCRAP_AMMO_BUNDLE_COST:
					break
				GameState.scrap -= SCRAP_AMMO_BUNDLE_COST
				scrap_spent += SCRAP_AMMO_BUNDLE_COST
				GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + 30)
				bought_ammo += 30
	var still_needed_medkits := maxi(0, medkits_needed - moved_medkits)
	for _kit in still_needed_medkits:
		if GameState.scrap < SCRAP_MEDKIT_COST:
			break
		GameState.scrap -= SCRAP_MEDKIT_COST
		scrap_spent += SCRAP_MEDKIT_COST
		GameState.medkits += 1
		bought_medkits += 1
	if scrap_spent > 0:
		GameState.save_persistent_state()
	if moved_ammo + bought_ammo > 0 or moved_medkits + bought_medkits > 0:
		var summary := "출정 보급 완료 · 탄약 +%d · 구급약 +%d" % [
			moved_ammo + bought_ammo, moved_medkits + bought_medkits
		]
		if scrap_spent > 0:
			summary += " · 고철 -%s" % GameState.format_compact_number(scrap_spent)
		_show_status(summary)
	else:
		_show_status(failure_reason if not failure_reason.is_empty() else "추가로 보충할 물품이 없습니다.")
	_update_stats()
	_select_raid_zone_preview(raid_zone_selected_id)


func _launch_raid_zone(zone_id: String) -> void:
	if not GameState.is_raid_zone_unlocked(zone_id):
		return
	var used_slots := int(GameState.get_raid_bag_used_slots())
	var capacity := int(GameState.get_raid_bag_capacity())
	if used_slots > capacity:
		_show_status(
			"출정 불가 · 가방이 %d/%d칸입니다. 창고에 휴대품을 보관한 뒤 다시 시도하세요."
			% [used_slots, capacity]
		)
		return
	if _raid_requires_unarmed_confirmation(zone_id):
		_open_raid_loadout_confirmation(zone_id)
	else:
		_confirm_launch_raid_zone(zone_id)


func _raid_requires_unarmed_confirmation(zone_id: String) -> bool:
	var manifest := GameState.build_raid_loadout_manifest(zone_id)
	return str(manifest.get("weapon_id", "")).is_empty()


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
	var panel := PanelContainer.new()
	panel.name = "RaidLoadoutConfirmPanel"
	panel.custom_minimum_size = Vector2(
		minf(570.0, viewport_size.x - 28.0),
		minf(330.0, viewport_size.y - 28.0)
	)
	panel.add_theme_stylebox_override(
		"panel", _rounded_panel_style(Color(0.018, 0.026, 0.026, 0.99), Color("#c56f59"), 7)
	)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var warning_icon := TextureRect.new()
	warning_icon.custom_minimum_size = Vector2(52, 52)
	warning_icon.texture = UI_ICONS.get_icon("alert", 48, Color("#f09a75"))
	warning_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	warning_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(warning_icon)
	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_box)
	heading_box.add_child(_raid_loadout_label("무기 없이 출정하시겠습니까?", 24, Color("#f0d3a3")))
	var zone := GameState.get_raid_zone(zone_id)
	heading_box.add_child(_raid_loadout_label(
		str(zone.get("name", zone_id)),
		14,
		Color("#b6c5bd")
	))
	var close := _shelter_close_button()
	close.pressed.connect(_close_raid_loadout_confirmation)
	header.add_child(close)

	var manifest := GameState.build_raid_loadout_manifest(zone_id)
	var recovery_active := bool(manifest.get("corpse_recovery", false))
	var warning_text := (
		"현재 주무기가 없습니다. 맨손으로 시작하며 필드에서 무기를 확보해야 합니다."
	)
	if recovery_active:
		warning_text += "\n이 구역에는 한 번 회수할 수 있는 분실 장비가 남아 있습니다."
	var warning := _raid_loadout_label(
		warning_text,
		16,
		Color("#e7d8c0")
	)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 68
	box.add_child(warning)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var back_button := _merchant_button("취소", false, "back")
	back_button.custom_minimum_size = Vector2(140, 50)
	back_button.pressed.connect(_close_raid_loadout_confirmation)
	actions.add_child(back_button)
	var confirm_button := _merchant_button("맨손으로 출정", true, "raid")
	confirm_button.name = "ConfirmRaidLoadoutButton"
	confirm_button.custom_minimum_size = Vector2(190, 50)
	confirm_button.pressed.connect(
		_confirm_launch_raid_zone.bind(zone_id),
		CONNECT_DEFERRED
	)
	actions.add_child(confirm_button)


func _raid_loadout_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _confirm_launch_raid_zone(zone_id: String) -> void:
	if raid_launch_in_progress:
		return
	if not GameState.select_raid_zone(zone_id):
		_show_raid_launch_error("선택한 구역에 진입할 수 없습니다.")
		return
	raid_launch_in_progress = true
	if is_instance_valid(raid_zone_launch_button):
		raid_zone_launch_button.disabled = true
		raid_zone_launch_button.text = "출정 준비 중..."
	# 캣닢 급여는 확정 순간에만 소비된다 — 브리핑에서 고르기만 하고 취소하면 무료.
	if not raid_catnip_buff_choice.is_empty():
		GameState.try_activate_catnip_field_buff(raid_catnip_buff_choice)
		raid_catnip_buff_choice = ""
	GameState.confirm_raid_loadout(zone_id)
	GameState.start_new_raid()
	# 다음 브리핑에서 "지난 출정 이후"를 계산할 기준점을 여기서 찍는다.
	GameState.capture_pre_raid_snapshot()
	GameState.returning_from_shelter = true
	GameState.save_persistent_state()
	call_deferred("_change_to_raid_scene")


func _change_to_raid_scene() -> void:
	if SceneTransition.transition_to("res://scenes/main.tscn", "res://scenes/shelter_interior.tscn"):
		return
	raid_launch_in_progress = false
	GameState.returning_from_shelter = false
	_show_raid_launch_error("도시 진입에 실패했습니다. 다시 시도해 주세요.")
	if is_instance_valid(raid_zone_launch_button):
		raid_zone_launch_button.disabled = false
		raid_zone_launch_button.text = "선택 구역으로 출정"


func _show_raid_launch_error(message: String) -> void:
	if is_instance_valid(raid_zone_detail_requirement):
		raid_zone_detail_requirement.text = message
		raid_zone_detail_requirement.add_theme_color_override("font_color", Color("#ee806c"))
	_show_status(message)


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
	raid_zone_selected_id = ""
	raid_zone_map_markers.clear()
	raid_zone_detail_state = null
	raid_zone_detail_title = null
	raid_zone_detail_description = null
	raid_zone_detail_reward = null
	raid_zone_detail_loadout = null
	raid_zone_detail_requirement = null
	raid_zone_resupply_button = null
	raid_zone_launch_button = null


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


const STATUS_HOLD_DURATION := 3.2
const STATUS_FADE_DURATION := 0.55


func _show_status(message: String) -> void:
	if not is_instance_valid(status_label):
		return
	if message.is_empty():
		status_hold = 0.0
		status_label.text = ""
		if is_instance_valid(status_panel):
			status_panel.modulate.a = 0.0
		return
	status_label.text = message
	status_hold = STATUS_HOLD_DURATION + STATUS_FADE_DURATION
	if is_instance_valid(status_panel):
		status_panel.modulate.a = 1.0
		status_panel.visible = true


func _update_status_toast(delta: float) -> void:
	# 예전에는 알파를 켜기만 하고 끄지 않아 토스트가 영구히 남아 있었다.
	if status_hold <= 0.0 or not is_instance_valid(status_panel):
		return
	status_hold = maxf(0.0, status_hold - delta)
	status_panel.modulate.a = clampf(status_hold / STATUS_FADE_DURATION, 0.0, 1.0)
	if status_hold <= 0.0:
		status_panel.visible = false
		status_label.text = ""


func _show_milestone_unlock_banner(unlocks: Array) -> void:
	if unlocks.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.name = "MilestoneUnlockLayer"
	layer.layer = 78
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override(
		"panel", _rounded_panel_style(Color(0.02, 0.028, 0.026, 0.97), Color("#e0c274"), 8)
	)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var eyebrow := Label.new()
	eyebrow.text = "새로 열린 문"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color("#c39a4d"))
	box.add_child(eyebrow)
	for unlock in unlocks:
		var entry := unlock as Dictionary
		var title := Label.new()
		title.text = str(entry.get("title", ""))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", FONT)
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color("#f3e3ba"))
		box.add_child(title)
		var body := Label.new()
		body.text = str(entry.get("body", ""))
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 420
		body.add_theme_font_override("font", FONT)
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", Color("#b3c3ba"))
		box.add_child(body)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.6 + 0.6 * float(unlocks.size()))
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)


func _build_corpse_decay_text(notice: Dictionary) -> String:
	match str(notice.get("status", "")):
		"lost":
			return "두고 온 장비를 누군가 전부 가져갔다. 이제 그 자리엔 아무것도 없다."
		"decayed":
			var ratio := float(notice.get("ratio", 1.0))
			return "두고 온 장비가 약탈당하고 있다 · 잔존 %d%% · 앞으로 %d회" % [
				roundi(ratio * 100.0),
				GameState.get_corpse_returns_remaining(),
			]
	return ""


func _build_offline_status_text(progress: Dictionary) -> String:
	# 돌아왔더니 뭔가 쌓여 있다는 감각이 재방문을 만든다. 예전에는 한 줄 토스트로
	# 지나갔다. 쌓인 것과 함께 "앞으로 얼마나 더 돌아가는지"를 붙여서, 복귀가
	# 정산이 아니라 다음 출정의 이유가 되게 한다.
	var scrap_gain := int(progress.get("scrap", 0))
	var catnip_gain := int(progress.get("catnip", 0))
	var repair_gain := float(progress.get("repair", 0.0))
	var has_line := GameState.is_shelter_facility_unlocked("scratcher_bank") \
		or GameState.is_shelter_facility_unlocked("catnip_scraper")
	var lines: PackedStringArray = []
	if scrap_gain > 0 or catnip_gain > 0 or repair_gain > 0.01:
		var parts: PackedStringArray = []
		if scrap_gain > 0:
			parts.append("고철 +%s" % GameState.format_compact_number(scrap_gain))
		if catnip_gain > 0:
			parts.append("캣닢 +%s" % GameState.format_compact_number(catnip_gain))
		if repair_gain > 0.01:
			parts.append("내구도 +%.1f%%" % repair_gain)
		lines.append("자리를 비운 사이 ·  %s" % "  ".join(parts))
	if has_line:
		var runtime := GameState.get_shelter_runtime_seconds()
		if runtime > 0.0:
			lines.append("남은 통조림으로 %s 더 돌아갑니다." % GameState.format_duration_korean(runtime))
		elif GameState.get_active_scratcher_workers() + GameState.get_active_catnip_workers() > 0:
			# 이게 이 게임의 연결 고리다. 라인이 멈췄다는 건 곧 나가야 한다는 뜻이다.
			lines.append("통조림이 떨어져 생산이 멈췄습니다. 도시에서 더 가져와야 합니다.")
		elif lines.is_empty():
			lines.append("쉘터에 복귀했습니다. 생산기에 주민을 배치할 수 있습니다.")
	return "\n".join(lines)


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
	if loafing:
		survivor.play("loaf_%s" % facing)
	else:
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
		var loaf_animation_name := "loaf_%s" % direction_name
		frames.add_animation(loaf_animation_name)
		frames.set_animation_loop(loaf_animation_name, true)
		frames.set_animation_speed(loaf_animation_name, 1.0)
		var loaf_texture_path := "%s/%s.png" % [
			CAT_LOAF_ANIMATION_ROOT,
			direction_name,
		]
		var loaf_texture := load(loaf_texture_path) as Texture2D
		if loaf_texture == null:
			push_error("Missing cat loaf frame: %s" % loaf_texture_path)
		else:
			frames.add_frame(loaf_animation_name, loaf_texture)
	return frames


func _input(event: InputEvent) -> void:
	if contract_story_open:
		if (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_F, KEY_ESCAPE]
		):
			_advance_contract_story()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and event.pressed:
			_advance_contract_story()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		if key == KEY_SPACE:
			if key_event.pressed:
				_begin_space_hold()
			else:
				_end_space_hold()
			get_viewport().set_input_as_handled()
			return
	if inventory_ui != null and bool(inventory_ui.call("is_open")):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_E, KEY_I, KEY_B]:
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
	if contract_ui_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_contract_ui()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_I, KEY_B]:
			inventory_ui.call("toggle")
		elif event.keycode == KEY_SHIFT:
			_use_shelter_medkit()
		elif event.keycode == KEY_F:
			_interact()
		elif event.keycode == KEY_8:
			_add_debug_resident()
		elif event.keycode == KEY_9:
			_unlock_all_facilities_debug()
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
				touch_stick.position = touch.position - touch_stick.size * 0.5
				touch_stick.begin_touch(touch.index, touch.position)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			touch_stick.end_touch()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_stick.update_touch(event.position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		touch_id = -1
		touch_vector = Vector2.ZERO
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or (what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and DisplayServer.is_touchscreen_available())
	):
		if not get_tree().paused:
			auto_paused_for_background = true
			get_tree().paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		if auto_paused_for_background:
			auto_paused_for_background = false
			get_tree().paused = false


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
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
			Input.vibrate_handheld(24)
		return true
	if _mobile_button_contains(shelter_medkit_button, touch.position):
		_use_shelter_medkit()
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
			Input.vibrate_handheld(16)
		return true
	if _mobile_button_contains(interact_button, touch.position):
		_interact()
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
			Input.vibrate_handheld(16)
		return true
	if ops_console != null and ops_console.handle_touch(touch.position):
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
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
	if loafing:
		_set_loafing(false)
		return
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


func _begin_space_hold() -> void:
	if loafing:
		space_hold_active = false
		space_hold_elapsed = 0.0
		space_hold_consumed = false
		_set_loafing(false)
		return
	if space_hold_active or roll_active or _ui_blocks_player() or not is_instance_valid(player):
		return
	space_hold_active = true
	space_hold_elapsed = 0.0
	space_hold_consumed = false


func _update_space_hold(delta: float) -> void:
	if not space_hold_active or space_hold_consumed or roll_active:
		return
	space_hold_elapsed += delta
	if space_hold_elapsed < LOAF_HOLD_THRESHOLD:
		return
	space_hold_consumed = true
	if roll_stamina < LOAF_MIN_STAMINA:
		_show_status("스태미나가 부족합니다.")
		return
	_set_loafing(true)


func _end_space_hold() -> void:
	if not space_hold_active:
		return
	var should_roll := not space_hold_consumed and space_hold_elapsed < LOAF_HOLD_THRESHOLD
	space_hold_active = false
	space_hold_elapsed = 0.0
	if should_roll:
		_try_start_roll()
	space_hold_consumed = false


func _set_loafing(enabled: bool) -> void:
	if loafing == enabled:
		return
	loafing = enabled
	_play_directional_animation()
	if loafing:
		_show_status("식빵 자세 · 은신 강화")


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
