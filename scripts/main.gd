extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const MOVE_SPEED := 5.2
const BASE_CAMERA_SIZE := 28.0
const CAMERA_DIAGONAL_OFFSET := 13.5
const OCCLUSION_LATERAL_LIMIT := 5.1
const OCCLUSION_DEPTH_LIMIT := 14.0
const SILHOUETTE_COLOR := Color("#26343b")
const STRUCTURE_REVEAL_RADIUS := 9.5
const STRUCTURE_REVEAL_HALF_ANGLE_DEG := 52.5
const STRUCTURE_REVEAL_BUILDING_ALPHA := 0.46
const AIM_REVEAL_BUILDING_ALPHA := 0.28
const STRUCTURE_REVEAL_VEHICLE_ALPHA := 0.58
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const CAT_ANIMATION_ROOT := "res://assets/characters/cat_8way"
const CAT_ROLL_ANIMATION_ROOT := "res://assets/characters/cat_roll"
const CAT_MELEE_ANIMATION_ROOT := "res://assets/characters/cat_melee"
const CAT_LOAF_ANIMATION_ROOT := "res://assets/characters/loaf"
const COWERING_RESIDENT_TEXTURE_PATHS := {
	"n": "res://assets/characters/cowering_resident/up_action-frame-0.png",
	"ne": "res://assets/characters/cowering_resident/up_right_action-frame-0.png",
	"e": "res://assets/characters/cowering_resident/right_action-frame-3.png",
	"se": "res://assets/characters/cowering_resident/down_right_action-frame-1.png",
	"s": "res://assets/characters/cowering_resident/down_action-frame-2.png",
	"sw": "res://assets/characters/cowering_resident/down_left_action-frame-2.png",
	"w": "res://assets/characters/cowering_resident/left_action-frame-3.png",
	"nw": "res://assets/characters/cowering_resident/up_left_action-frame-0.png",
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
const MELEE_FRAME_COUNT := 4
const MELEE_ANIMATION_FPS := 8.0
const MELEE_WINDUP_DURATION := 0.18
const MELEE_ANIMATION_DURATION := 0.5
const MELEE_FAN_HALF_ANGLE_DEG := 56.0
const MELEE_FAN_SEGMENTS := 24
const ROLL_DURATION := 0.42
const ROLL_STAMINA_MAX := 100.0
const ROLL_STAMINA_COST := 35.0
const ROLL_STAMINA_RECOVERY_PER_SECOND := 28.0
const ROLL_START_SPEED := 42.0
const ROLL_END_SPEED := 4.4
const ROLL_AFTERIMAGE_INTERVAL := 0.055
const LOAF_HOLD_THRESHOLD := 0.45
# 식빵 자세는 퍼짐 -55%, 반동 -72%, 피탐지 -52%를 준다. 이동 페널티가 1.0이면
# 켜두는 게 언제나 이득이라 자세가 선택이 아니라 기본값이 된다. 대가를 붙인다.
const LOAF_MOVE_MULTIPLIER := 0.6
const LOAF_STAMINA_DRAIN_PER_SECOND := 7.5
const LOAF_MIN_STAMINA := 1.0
const LOAF_VISIBILITY_MULTIPLIER := 0.48
const WEAPON_FRAME_SIZE := Vector2(192, 192)
const WEAPON_VISUAL_PIXEL_SIZE := 0.0018
const AK_DIRECTIONAL_TEXTURE := preload("res://assets/weapons/ak47_directional.png")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const PERCEPTION_SYSTEM_SCRIPT := preload("res://scripts/perception_system.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const LOOT_CONTAINER_VISUALS := preload("res://scripts/loot_container_visual_catalog.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const GameOverScreen := preload("res://scripts/hud/game_over_screen.gd")
const LoreReader := preload("res://scripts/hud/lore_reader.gd")
const RaidHud := preload("res://scripts/hud/raid_hud.gd")
const JackpotEvent := preload("res://scripts/raid/jackpot_event.gd")
const FieldMissionController := preload("res://scripts/raid/field_mission_controller.gd")
const FieldIncidents := preload("res://scripts/raid/field_incidents.gd")
const ExtractionFlow := preload("res://scripts/raid/extraction_flow.gd")
const EnemyDirector := preload("res://scripts/raid/enemy_director.gd")
const LootPickupSystem := preload("res://scripts/raid/loot_pickup_system.gd")
const BgmDirector := preload("res://scripts/audio/bgm_director.gd")
const StealthSystem := preload("res://scripts/raid/stealth_system.gd")
const WeaponCombat := preload("res://scripts/raid/weapon_combat.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const AIM_RETICLE_SCRIPT := preload("res://scripts/aim_reticle.gd")
const ROLL_COOLDOWN_INDICATOR_SCRIPT := preload("res://scripts/roll_cooldown_indicator.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const TACTICAL_MAP_SCRIPT := preload("res://scripts/tactical_map.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const RESCUED_CAT_FOLLOWER_SCRIPT := preload("res://scripts/rescued_cat_follower.gd")
const LORE_POSTER_TEXTURE := preload("res://assets/lore/forgotten_notice_board_v1.png")
const BROKEN_SENTRY_TEXTURE := preload("res://assets/props/broken_sentry_salvage.png")
const FIELD_LOOT_CACHE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const START_WITH_COMPANION := false
const AK_PICKUP_POSITION := Vector3(1.15, 0.32, 0.7)
const PICKUP_DISTANCE := 1.75
const PICKUP_HOLD_DURATION := 0.9
const AIM_HOLD_DURATION := 0.55
const MAP_CONTENT_SCALE := ProceduralCityMap.WORLD_SCALE
const SECONDS_PER_GAME_HOUR := 36.0
const NIGHT_START_HOUR := 19.0
const DEEP_NIGHT_HOUR := 22.0
const BASE_ENEMY_COUNT := 24
const MAX_NIGHT_ENEMY_COUNT := 44
const ENEMY_PAIR_SQUAD_CHANCE := 0.78
const FIRST_STAGE_ZONE_ID := "jongno_outskirts"
const SALVAGE_VEHICLE_POINT_COUNT := 10
const SALVAGE_MISC_POINT_COUNT := 4
const RESCUE_POINT_COUNT := 5
const MELEE_ATTACK_COOLDOWN := 0.72
const MELEE_ATTACK_RANGE := 2.2
const MELEE_ATTACK_DAMAGE := 38
const BOSS_DEFEAT_TIME_SCALE := 0.20
const BOSS_DEFEAT_SLOWMO_SECONDS := 1.05
const BOSS_DEFEAT_FOCUS_SECONDS := 1.65
const BOSS_DEFEAT_CAMERA_SIZE := 19.5
const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_INTERACTION_FACING_WEIGHT := 1.35
const FIELD_INTERACTION_SIGHT_HEIGHT := 0.48
const SALVAGE_HOLD_DURATION := 2.4
const RESCUE_HOLD_DURATION := 1.8
const FATIGUE_MAX := 100.0
const FATIGUE_MOVING_RATE := 0.055
const FATIGUE_IDLE_RATE := 0.0
const FATIGUE_AIM_HOLD_RATE := 0.09
const FATIGUE_MELEE_GAIN := 1.1
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_SALVAGE_GAIN := 3.5
const FATIGUE_RESCUE_GAIN := 2.2
const FATIGUE_ROLL_GAIN := 0.45
const FATIGUE_DAMAGE_PER_POINT := 0.045
const FATIGUE_SPEED_MIN := 0.58
const ESCORT_SPEED_PENALTY := 0.07
const FIELD_MISSION_TRIGGER_RADIUS := 4.6
const LORE_CLUE_COUNT := 6
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const RAID_PRESSURE_REVEAL_SECONDS := 3.4
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const DYNAMIC_INCIDENT_DELAY_MIN := 55.0
const DYNAMIC_INCIDENT_DELAY_MAX := 85.0
const LORE_ENTRIES := preload("res://scripts/lore_catalog.gd").ENTRIES
const DIRECTION_VECTORS := {
	"n": Vector2(0, -1),
	"ne": Vector2(1, -1),
	"e": Vector2(1, 0),
	"se": Vector2(1, 1),
	"s": Vector2(0, 1),
	"sw": Vector2(-1, 1),
	"w": Vector2(-1, 0),
	"nw": Vector2(-1, -1),
}

@onready var player: CharacterBody3D = $Player
@onready var survivor: AnimatedSprite3D = $Player/Survivor
@onready var companion: CharacterBody3D = $FemaleCatCompanion
@onready var companion_sprite: AnimatedSprite3D = $FemaleCatCompanion/Sprite
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var touch_stick: Control = $HUD/TouchStick
# Knob은 TouchJoystick 위젯이 직접 그린다. 옛 씬 호환용으로만 남긴다.
@onready var touch_knob: Control = $HUD/TouchStick.get_node_or_null("Knob")
@onready var location_label: Label = $HUD/TopRight/Location
@onready var state_label: Label = $HUD/TopRight/State
@onready var time_label: Label = $HUD/TopRight/Time
@onready var objective_panel: PanelContainer = $HUD/Objective
@onready var objective_label: Label = $HUD/Objective/Text
@onready var top_left_status_panel: PanelContainer = $HUD/TopLeft
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var BuildingRunState: Node = get_node("/root/BuildingRunState")

var touch_id := -1
var fire_touch_id := -1
var context_touch_id := -1
var touch_origin := Vector2.ZERO
var touch_vector := Vector2.ZERO
var facing := "s"
var motion_state := "idle"
var occlusion_masks := {}
var weapon_sprite: AnimatedSprite3D
var ak_pickup: Node3D
var pickup_touch_held := false
var pickup_keyboard_held := false
var pickup_hold_time := 0.0
var mobile_context_button: Button
# 컨텍스트 버튼이 "떠 있어야 하는가". 실제 visible과 위치는 유틸리티 줄
# 레이아웃이 결정한다. 둘을 섞으면 생성 시점 좌표에 유령 버튼이 남는다.
var mobile_context_wants_visible := false
var mobile_medkit_button: Button
var mobile_reload_button: Button
var mobile_flashlight_button: Button
var mobile_map_button: Button
var fire_cooldown := 0.0
var fire_button_held := false
var mouse_fire_held := false
var has_ak := false
var magazine_ammo := 30
var reserve_ammo := 90
var gunshot_players: Array[AudioStreamPlayer3D] = []
var roll_audio_player: AudioStreamPlayer3D
var building_canvas: CanvasLayer
var building_overlays := {}
var vehicle_overlays := {}
var survivor_overlay: Sprite2D
var survivor_outline_overlay: Sprite2D
var companion_overlay: Sprite2D
var companion_active := START_WITH_COMPANION
var weapon_overlay: Sprite2D
var roll_afterimages: Array[Sprite2D] = []
var unarmed_sprite_frames: SpriteFrames
var field_loot_containers: Array[Node3D] = []
var ammo_notice_time := 0.0
var last_field_notice := ""
var repeated_field_notice_count := 0
var auto_paused_for_background := false
var nearby_ammo_pickup: Node3D
var perception_system: CanvasLayer
var aim_hold_time := 0.0
var locked_aim_direction := Vector3.ZERO
var smoke_particle_texture: ImageTexture
var loot_glow_texture: ImageTexture
var cowering_resident_texture_cache: Dictionary = {}
var player_health := 82
var enemies: Array[CharacterBody3D] = []
var world_time_hours := 9.0
var night_intensity := 0.0
var reinforcement_timer := 8.0
var day_night_tint: ColorRect
var current_day_phase := ""
var spawn_random := RandomNumberGenerator.new()
var mission_random := RandomNumberGenerator.new()
var melee_bat_sprite: Sprite3D
var melee_bat_overlay: Sprite2D
var melee_attack_cooldown := 0.0
var melee_arc_texture: ImageTexture
var melee_attack_active := false
var melee_attack_elapsed := 0.0
var melee_attack_direction := Vector3.ZERO
var melee_hit_resolved := false
var melee_fan_indicator: MeshInstance3D
var melee_fan_fill_material: StandardMaterial3D
var melee_fan_rim_material: StandardMaterial3D
var melee_fan_tween: Tween
var equipped_weapon_id := "ak47"
var equipped_weapon_mods: Array[String] = []
var weapon_stats: Dictionary = {}
var weapon_durability := 100.0
var weapon_spread_deg := 2.4
var recoil_velocity := Vector3.ZERO
var recoil_reticle_offset := Vector2.ZERO
var weapon_reloading := false
var reload_timer := 0.0
var laser_aim_held := false
var loafing := false
var space_hold_active := false
var space_hold_elapsed := 0.0
var space_hold_consumed := false
var laser_glow_layers: Array[MeshInstance3D] = []
var laser_glow_meshes: Array[BoxMesh] = []
var laser_glow_materials: Array[StandardMaterial3D] = []
var damage_direction_tween: Tween
var camera_shake_time := 0.0
var camera_shake_strength := 0.0
var hit_stop_serial := 0
var combat_hit_stop_cooldown := 0.0
# 같은 프레임에 들어간 피해 합. 샷건 펠릿 8발이 한 방으로 읽히게 한다.
var hit_stop_damage_accumulator := 0
var player_hit_flash_time := 0.0
var player_hit_stun_time := 0.0
var last_damage_source_name := "알 수 없는 공격자"
var last_damage_weapon_name := "알 수 없는 무기"
var last_damage_blocked := 0
var player_death_sequence_active := false
var player_last_safe_position := Vector3.ZERO
var player_last_frame_position := Vector3.ZERO
var player_stuck_time := 0.0
var roll_active := false
var roll_elapsed := 0.0
var roll_iframe_until_msec := 0
var roll_stamina := ROLL_STAMINA_MAX
var roll_afterimage_timer := 0.0
var roll_direction := Vector3.ZERO
var scope_camera_offset := Vector3.ZERO
var weapon_random := RandomNumberGenerator.new()
var tactical_map: Control
var extraction_site: Node3D
var extraction_sites: Array[Node3D] = []
var extraction_transition_active := false
var extraction_fade: ColorRect
var discovered_extraction_indices: Dictionary = {}
var lightning_overlay: ColorRect
var lightning_timer := 12.0
var field_interactions: Array[Node3D] = []
var nearby_field_interaction: Node3D
var field_interaction_visual_signature := ""
var field_interaction_candidates: Array[Node3D] = []
var field_interaction_cycle_index := 0
var field_interaction_candidate_signature := ""
var field_interaction_keyboard_held := false
var field_interaction_hold_time := 0.0
var rescued_followers: Array[CharacterBody3D] = []
var fatigue := 0.0
var fatigue_warning_band := -1
var run_started_msec := 0
var run_kills := 0
var run_damage_dealt := 0
var raid_start_snapshot := {}
var corpse_recovery_point: Node3D
var game_over_screen := GameOverScreen.new()
var lore_reader := LoreReader.new()
var hud := RaidHud.new()
var jackpot := JackpotEvent.new()
var field_missions := FieldMissionController.new()
var incidents := FieldIncidents.new()
var extraction := ExtractionFlow.new()
var enemy_director := EnemyDirector.new()
var loot_system := LootPickupSystem.new()
var bgm := BgmDirector.new()
var stealth := StealthSystem.new()
var weapon_combat := WeaponCombat.new()
var raid_zone_data: Dictionary = {}
var active_zone_rule := ""
var toxic_zone_tick := 0.0
var active_field_mission: Node3D
var active_mission_collectibles: Array[Node3D] = []
var field_mission_elapsed := 0.0
var field_mission_spawned_enemies := 0
var field_mission_kills := 0
var field_mission_collected := 0
var field_mission_detection_time := 0.0
var field_mission_investigation_hold := 0.0
var field_mission_investigation_target: Node3D
var field_mission_noise_breached := false
var basic_raid_missions: Array[Dictionary] = []
var basic_subway_mission_site: Node3D
var lore_clues: Array[Node3D] = []
var completed_mission_titles: Array[String] = []
var completed_mission_xp := 0
var field_objective_title := ""
var field_objective_detail := ""
var field_objective_color := Color("#8fd0c1")
var objective_reveal_alpha := 0.0
const OBJECTIVE_REVEAL_RADIUS := 24.0
const OBJECTIVE_REVEAL_TYPES := ["basic_mission_subway", "mission_start"]
var boss_alert_panel: PanelContainer
var boss_alert_title: Label
var boss_alert_subtitle: Label
var boss_alert_tween: Tween
# 배너 스택이 자리를 양보시킬 수 있으므로, "떠 있어야 하는가"를 패널의
# visible과 분리해서 들고 있어야 한다. visible을 입력이자 출력으로 쓰면
# 한 번 접힌 배너가 다시 뜨지 못한다.
var boss_alert_active := false
var boss_defeat_overlay: Control
var boss_defeat_flash: ColorRect
var boss_defeat_panel: PanelContainer
var boss_defeat_title: Label
var boss_defeat_subtitle: Label
var boss_defeat_tween: Tween
var boss_defeat_sequence_active := false
var boss_defeat_focus_position := Vector3.ZERO
var boss_defeat_sequence_serial := 0
var scent_system: Node3D
var objective_scent_guidance: Node
var scent_focus_active := false
var raid_hotspots: Array[Node3D] = []
var raid_elapsed_seconds := 0.0
var raid_pressure_level := 0
var _carried_value_cache := 0
var _carried_value_cache_msec := 0
# 긴장도의 실제 입력. 시간·전투·소음·전리품이 여기에 누적된다.
var raid_pressure_points := 0.0
var raid_seconds_since_noise := 0.0
var raid_event_last_fired: Dictionary = {}
var raid_event_cooldown := 0.0
var raid_curfew_active := false
var raid_event_random := RandomNumberGenerator.new()
var raid_sealed_extraction_index := -1
var raid_reward_multiplier := 1.0
# 긴장도 패널은 상시 표시하면 다른 스무 개와 같은 목소리가 되어 아무도 안 읽는다.
# 단계가 실제로 바뀌는 순간에만 잠깐 띄운다. 이 게임에서 가장 중요한 숫자다.
var raid_pressure_reveal_time := 0.0
var raid_hotspots_opened := 0
var dynamic_incident_site: Node3D
var dynamic_incident_state := "scheduled"
var dynamic_incident_timer := 0.0
var dynamic_incident_winning_faction := ""


func _ready() -> void:
	run_started_msec = Time.get_ticks_msec()
	raid_zone_data = GameState.get_raid_zone()
	active_zone_rule = str(raid_zone_data.get("zone_rule", ""))
	world_time_hours = GameState.world_time_hours
	night_intensity = _get_night_intensity(world_time_hours)
	spawn_random.seed = GameState.map_seed + 9137
	mission_random.seed = (
		int(GameState.map_seed)
		+ int(GameState.raid_serial) * 486187739
		+ 5065043
	)
	weapon_random.seed = GameState.map_seed + 44123
	# A run interrupted during the death transition can leave zero HP in the
	# persistent save. Revive before field systems read the invalid state.
	if GameState.player_health <= 0:
		GameState.player_health = GameState.get_max_health()
		GameState.save_persistent_state()
	player_health = clampi(GameState.player_health, 0, GameState.get_max_health())
	roll_stamina = GameState.get_max_stamina()
	magazine_ammo = GameState.magazine_ammo
	reserve_ammo = GameState.reserve_ammo
	equipped_weapon_id = GameState.equipped_weapon_id
	equipped_weapon_mods.assign(GameState.equipped_weapon_mods)
	weapon_durability = GameState.weapon_durability
	if not bool(BuildingRunState.pending_field_return):
		GameState.fatigue = 0.0
	fatigue = clampf(GameState.fatigue, 0.0, FATIGUE_MAX)
	_refresh_weapon_stats()
	reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.reserve_ammo = reserve_ammo
	has_ak = bool(GameState.has_ak)
	camera.size = BASE_CAMERA_SIZE
	player.collision_layer = COLLISION_PROFILES.PLAYER_LAYER
	player.collision_mask = COLLISION_PROFILES.PLAYER_MOVEMENT_MASK
	player.add_to_group("player")
	camera.position = Vector3.ONE * CAMERA_DIAGONAL_OFFSET
	camera.look_at(Vector3.ZERO)
	var world := $World as ProceduralCityMap
	var launched_from_shelter := GameState.returning_from_shelter
	if launched_from_shelter:
		BuildingRunState.begin_field_raid(int(GameState.map_seed))
		player.position = world.get_shelter_exit_position()
		GameState.returning_from_shelter = false
	else:
		player.position = world.find_nearest_physically_open_position(
			player.position,
			0.62,
			[player.get_rid()]
		)
	player_last_safe_position = player.position
	player_last_frame_position = player.position
	_snap_camera_to_player()
	$SmokeA.emitting = false
	$SmokeB.emitting = false
	survivor.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	survivor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	survivor.render_priority = 127
	survivor.no_depth_test = true
	if not companion_active:
		_deactivate_companion()
	top_left_status_panel.visible = false
	objective_panel.visible = false
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	touch_stick.visible = DisplayServer.is_touchscreen_available()
	_build_sprite_frames()
	_setup_weapon_layer()
	_setup_melee_weapon()
	hud.attach(self)
	jackpot.attach(self)
	field_missions.attach(self)
	incidents.attach(self)
	extraction.attach(self)
	enemy_director.attach(self)
	loot_system.attach(self)
	stealth.attach(self)
	weapon_combat.attach(self)
	hud.setup_aim_feedback()
	hud.setup_player_combat_feedback()
	game_over_screen.build(self)
	lore_reader.build(self)
	lore_reader.opened.connect(func() -> void:
		_release_mobile_held_actions()
		_refresh_pointer_mode()
		_apply_hud_layout()
		_update_combat_overlay_visibility()
	)
	lore_reader.closed.connect(func() -> void:
		_refresh_pointer_mode()
		_apply_hud_layout()
		_update_combat_overlay_visibility()
	)
	lore_reader.lore_discovered.connect(func() -> void: _advance_contract_progress("lore"))
	_setup_boss_alert_ui()
	_setup_boss_defeat_ui()
	_setup_weather_effects()
	_spawn_ammo_pickups()
	hud.build(self)
	if not get_viewport().size_changed.is_connected(_apply_hud_layout):
		get_viewport().size_changed.connect(_apply_hud_layout)
	if not AccessibilitySettings.settings_changed.is_connected(_apply_hud_layout):
		AccessibilitySettings.settings_changed.connect(_apply_hud_layout)
	if not AccessibilitySettings.settings_changed.is_connected(_apply_runtime_accessibility_settings):
		AccessibilitySettings.settings_changed.connect(_apply_runtime_accessibility_settings)
	_apply_runtime_accessibility_settings()
	weapon_combat._build_gunshot_audio()
	_build_roll_audio()
	_build_bgm_audio()
	stealth._install_scent_system()
	_spawn_enemies()
	_setup_building_overlays()
	_build_day_night_tint()
	stealth._build_visibility_fog()
	_install_perception_system()
	_update_day_night(0.0)
	stealth._update_enemy_visibility()
	_set_facing("s")
	extraction._setup_extraction_site(world)
	if launched_from_shelter:
		_play_raid_entry_fade()
	_setup_field_objectives(world)
	field_missions._setup_procedural_field_missions(world)
	_setup_basic_raid_missions(world)
	_setup_world_lore_clues(world)
	_setup_corpse_recovery(world)
	_register_building_entrance_interactions()
	_apply_zone_rule_on_start()
	_setup_raid_opportunities(world)
	_setup_tactical_map(world)
	var health_bar := get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
	if health_bar:
		health_bar.max_value = GameState.get_max_health()
		health_bar.value = player_health
	_capture_raid_start_snapshot()
	_initialize_equipped_weapon()
	_refresh_pointer_mode()
	_apply_hud_layout()


func _snap_camera_to_player() -> void:
	camera_rig.position = Vector3(player.position.x, 0.0, player.position.z) + scope_camera_offset


func _update_player_stuck_recovery(delta: float, movement_requested: bool) -> void:
	var frame_distance := player.position.distance_to(player_last_frame_position)
	var overlaps_obstacle := _player_overlaps_movement_obstacle()
	if not overlaps_obstacle:
		player_last_safe_position = player.position
	if movement_requested and overlaps_obstacle and frame_distance < 0.018:
		player_stuck_time += delta
	else:
		player_stuck_time = 0.0
	if player_stuck_time >= 0.85:
		var world := $World as ProceduralCityMap
		player.position = world.find_nearest_physically_open_position(
			player_last_safe_position,
			0.62,
			[player.get_rid()]
		)
		player.velocity = Vector3.ZERO
		player_stuck_time = 0.0
		state_label.text = "가까운 안전 위치로 이동했습니다"
	player_last_frame_position = player.position


func _player_overlaps_movement_obstacle() -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.27
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3(0.0, 0.58, 0.0))
	query.collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_camera_follow(delta: float) -> void:
	var camera_target := (
		boss_defeat_focus_position
		if boss_defeat_sequence_active
		else Vector3(player.position.x, 0, player.position.z) + scope_camera_offset
	)
	if camera_shake_time > 0.0:
		var shake_scale := clampf(float(AccessibilitySettings.camera_shake_scale), 0.0, 1.0)
		camera_target += Vector3(
			weapon_random.randf_range(-camera_shake_strength, camera_shake_strength) * shake_scale,
			0.0,
			weapon_random.randf_range(-camera_shake_strength, camera_shake_strength) * shake_scale
		)
	var camera_follow_delta := (
		delta / maxf(Engine.time_scale, 0.05)
		if boss_defeat_sequence_active
		else delta
	)
	camera_rig.position = camera_rig.position.lerp(
		camera_target,
		1.0 - exp(-7.0 * camera_follow_delta)
	)


func _play_raid_entry_fade() -> void:
	if not is_instance_valid(extraction_fade):
		return
	extraction_fade.color = Color(0, 0, 0, 1)
	extraction_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(extraction_fade, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(extraction_fade):
			extraction_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func activate_companion() -> void:
	companion_active = true
	if companion == null:
		return
	companion.visible = true
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.collision_layer = COLLISION_PROFILES.COMPANION_LAYER
	companion.collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	companion.set_physics_process(true)
	if companion.has_method("set_active"):
		companion.call("set_active", true)
	if companion_overlay:
		companion_overlay.visible = true


func _deactivate_companion() -> void:
	if companion == null:
		return
	companion.visible = false
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	companion.collision_layer = 0
	companion.collision_mask = 0
	companion.velocity = Vector3.ZERO
	if companion.has_method("set_active"):
		companion.call("set_active", false)
	if companion_overlay:
		companion_overlay.visible = false


func _physics_process(delta: float) -> void:
	if player_death_sequence_active:
		_update_building_overlays()
		stealth._update_visibility_fog()
		stealth._update_enemy_visibility(delta)
		return
	_update_day_night(delta)
	_update_zone_rule(delta)
	_update_lightning(delta)
	_update_enemy_pressure(delta)
	stealth._update_scent_system(delta)
	incidents._update_faction_conflicts(delta)
	_update_raid_opportunities(delta)
	jackpot._update_jackpot_event(delta)
	melee_attack_cooldown = maxf(0.0, melee_attack_cooldown - delta)
	combat_hit_stop_cooldown = maxf(0.0, combat_hit_stop_cooldown - delta)
	hit_stop_damage_accumulator = 0
	if raid_pressure_reveal_time > 0.0:
		raid_pressure_reveal_time = maxf(0.0, raid_pressure_reveal_time - delta)
		if raid_pressure_reveal_time <= 0.0:
			_layout_center_top_banners()
	_update_melee_attack(delta)
	aim_hold_time = maxf(0.0, aim_hold_time - delta)
	player_hit_stun_time = maxf(0.0, player_hit_stun_time - delta)
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
			state_label.text = "스태미나 부족"
	elif not roll_active:
		roll_stamina = minf(
			GameState.get_max_stamina(),
			roll_stamina + ROLL_STAMINA_RECOVERY_PER_SECOND * GameState.get_stamina_recovery_multiplier() * delta
		)
	if (laser_aim_held or mouse_fire_held) and weapon_combat._uses_mouse_aim():
		_lock_aim_direction(weapon_combat._get_mouse_world_direction())
	_update_scope_camera(delta)
	if hud.melee_button:
		hud.melee_button.disabled = melee_attack_cooldown > 0.0 or loafing
	if hud.dash_button:
		hud.dash_button.disabled = roll_active or roll_stamina < _get_roll_stamina_cost()
	if mobile_reload_button:
		mobile_reload_button.disabled = weapon_reloading or loafing or not has_ak or reserve_ammo <= 0
	_update_field_interactions(delta)
	_update_objective_reveal(delta)
	extraction._update_extraction_discovery()
	_update_combat_overlay_visibility()
	stealth._update_stealth_takedown_prompt()
	if (
		_is_inventory_open()
		or _is_tactical_map_open()
		or lore_reader.is_open()
		or extraction_transition_active
		or boss_defeat_sequence_active
	):
		player.velocity = Vector3.ZERO
		player.move_and_slide()
		if boss_defeat_sequence_active:
			_update_camera_follow(delta)
		_update_building_overlays()
		stealth._update_visibility_fog()
		stealth._update_enemy_visibility(delta)
		return
	field_missions._update_field_missions(delta)
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	input_vector = input_vector.limit_length(1.0)
	if touch_vector.length_squared() > input_vector.length_squared():
		input_vector = touch_vector
	if player_hit_stun_time > 0.0:
		input_vector = Vector2.ZERO
	_update_fatigue(delta, input_vector.length_squared() > 0.01)
	weapon_combat._update_weapon_ballistics(delta, input_vector.length_squared() > 0.01)

	var world_direction := Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y)
	if not weapon_combat._uses_mouse_aim() and (laser_aim_held or fire_button_held):
		# 예전에는 has_ak 조건이 붙어 있어서, 무기를 잃으면 조준 중에
		# 방향이 아예 갱신되지 않고 얼어붙었다.
		weapon_combat._update_mobile_aim_direction(world_direction)
	var aim_is_locked := (
		melee_attack_active
		or laser_aim_held
		or (has_ak and (fire_button_held or mouse_fire_held))
		or aim_hold_time > 0.0
	)
	if roll_active:
		_update_roll(delta)
	elif world_direction.length_squared() > 0.01:
		world_direction = world_direction.normalized()
		var movement_speed := MOVE_SPEED * GameState.get_move_speed_multiplier() * (LOAF_MOVE_MULTIPLIER if loafing else 1.0)
		movement_speed *= _get_fatigue_speed_multiplier()
		movement_speed *= _get_escort_speed_multiplier()
		if scent_focus_active:
			movement_speed *= 0.78
		if weapon_reloading:
			movement_speed *= 0.55
		player.velocity = world_direction * movement_speed + recoil_velocity
		# 모바일에서 조준을 켜면 방향이 잠겨 회전이 안 됐다. 조준 보조는
		# 발사 순간(_get_current_fire_direction)에만 걸면 충분하다.
		# 움직이는 동안에는 언제나 가는 쪽을 본다.
		if not aim_is_locked or not weapon_combat._uses_mouse_aim():
			_update_facing(input_vector)
		_set_motion_state("walk")
		state_label.text = "식빵 자세 이동" if loafing else "이동 중"
	else:
		player.velocity = recoil_velocity
		_set_motion_state("idle")
		state_label.text = "식빵 자세 대기" if loafing else "경계 중"

	var mobile_steering := not weapon_combat._uses_mouse_aim() and input_vector.length_squared() > 0.01
	if (
		not roll_active
		and aim_is_locked
		and not mobile_steering
		and locked_aim_direction.length_squared() > 0.01
	):
		_set_facing_from_world_direction(locked_aim_direction)
	weapon_combat._update_weapon_pose()
	player.set_meta("tactical_heading", _get_current_facing_world_direction())

	player.move_and_slide()
	_update_player_stuck_recovery(delta, input_vector.length_squared() > 0.01)
	var map_limit := ($World as ProceduralCityMap).get_map_limit()
	player.position.x = clampf(player.position.x, -map_limit, map_limit)
	player.position.z = clampf(player.position.z, -map_limit, map_limit)
	_update_pickup(delta)
	loot_system._update_ammo_pickups(delta)
	_refresh_mobile_context_button()
	weapon_combat._update_firing(delta)
	_update_aim_feedback(delta)
	_update_camera_occluders(delta)
	_update_player_combat_feedback(delta)
	_update_camera_follow(delta)
	_update_building_overlays()
	stealth._update_visibility_fog()
	stealth._update_enemy_visibility(delta)
	stealth._update_stealth_takedown_prompt()
	if perception_system:
		perception_system.call("set_aim_direction", _get_perception_aim_direction())
		if perception_system.has_method("set_aim_expanded"):
			perception_system.call("set_aim_expanded", laser_aim_held)
	$CameraRig/Rain.position.y = 8.0
	var city_world := $World as ProceduralCityMap
	var sector_label := city_world.get_sector_label(player.global_position)
	var nearest_exit_distance := INF
	for extraction_site in extraction_sites:
		if is_instance_valid(extraction_site):
			nearest_exit_distance = minf(nearest_exit_distance, player.global_position.distance_to(extraction_site.global_position))
	location_label.text = "%s  ·  %s  ·  탈출 %.0fm" % [
		str(raid_zone_data.get("name", "종로 외곽")),
		sector_label,
		nearest_exit_distance if nearest_exit_distance < INF else 0.0,
	]


func _update_facing(screen_direction: Vector2) -> void:
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var index := int(round(angle / 45.0)) % 8
	_set_facing(SCREEN_DIRECTION_NAMES[index])


func _set_facing_from_world_direction(world_direction: Vector3) -> void:
	if world_direction.length_squared() <= 0.01:
		return
	var screen_direction := Vector2(
		world_direction.x - world_direction.z,
		world_direction.x + world_direction.z
	).normalized()
	_update_facing(screen_direction)


func _lock_aim_direction(world_direction: Vector3) -> void:
	world_direction.y = 0.0
	if world_direction.length_squared() <= 0.01:
		return
	locked_aim_direction = world_direction.normalized()
	aim_hold_time = AIM_HOLD_DURATION


func _get_perception_aim_direction() -> Vector3:
	if (
		(laser_aim_held or (has_ak and (fire_button_held or mouse_fire_held)) or aim_hold_time > 0.0)
		and locked_aim_direction.length_squared() > 0.01
	):
		return locked_aim_direction
	return _get_current_facing_world_direction()


func _try_start_roll() -> void:
	var stamina_cost := _get_roll_stamina_cost()
	if roll_active or loafing or melee_attack_active or roll_stamina < stamina_cost or player_health <= 0:
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
		roll_direction = Vector3(
			roll_input.x + roll_input.y,
			0.0,
			-roll_input.x + roll_input.y
		).normalized()
	else:
		roll_direction = _get_current_facing_world_direction()
	_set_facing_from_world_direction(roll_direction)
	roll_active = true
	roll_stamina = maxf(0.0, roll_stamina - stamina_cost)
	_add_fatigue(FATIGUE_ROLL_GAIN)
	roll_elapsed = 0.0
	roll_afterimage_timer = 0.0
	recoil_velocity = Vector3.ZERO
	_set_motion_state("roll")
	state_label.text = "회피 구르기"
	_play_roll_sound()
	_spawn_roll_afterimage()


func _begin_space_hold() -> void:
	if loafing:
		space_hold_active = false
		space_hold_elapsed = 0.0
		space_hold_consumed = false
		_set_loafing(false)
		return
	if (
		space_hold_active
		or roll_active
		or melee_attack_active
		or player_health <= 0
		or _is_inventory_open()
		or _is_tactical_map_open()
		or lore_reader.is_open()
		or extraction_transition_active
	):
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
		state_label.text = "스태미나 부족"
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
	player.set_meta(
		"stealth_visibility_multiplier",
		LOAF_VISIBILITY_MULTIPLIER if loafing else 1.0
	)
	player.set_meta("loafing_stealth", loafing)
	if loafing:
		fire_button_held = false
		mouse_fire_held = false
		laser_aim_held = false
		aim_hold_time = 0.0
		weapon_reloading = false
		if hud.reload_reticle_indicator:
			hud.reload_reticle_indicator.visible = false
		state_label.text = "식빵 자세 · 은신 중"
	else:
		state_label.text = "경계 중"
	_play_directional_animation()
	weapon_combat._update_weapon_pose()


func _get_roll_stamina_cost() -> float:
	return ROLL_STAMINA_COST * GameState.get_stamina_cost_multiplier()


func _update_roll(delta: float) -> void:
	if player.is_on_wall():
		var wall_normal := player.get_wall_normal()
		wall_normal.y = 0.0
		var slide_direction := roll_direction.slide(wall_normal)
		if slide_direction.length_squared() > 0.12:
			roll_direction = slide_direction.normalized()
		else:
			var unused_ratio := 1.0 - clampf(roll_elapsed / ROLL_DURATION, 0.0, 1.0)
			roll_stamina = minf(
				GameState.get_max_stamina(),
				roll_stamina + _get_roll_stamina_cost() * unused_ratio * 0.45
			)
			_finish_roll()
			return
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
	# 착지 직후 120ms 유예 — 오프닝 튜토리얼과 같은 감각. 굴림이 끝나는
	# 프레임에 맞는 억울함을 막는다.
	roll_iframe_until_msec = Time.get_ticks_msec() + 120
	player.velocity = roll_direction * ROLL_END_SPEED
	_set_motion_state("idle")
	state_label.text = "경계 중"


func _spawn_roll_afterimage() -> void:
	if building_canvas == null or survivor_overlay == null or survivor.sprite_frames == null:
		return
	var ghost_texture := survivor.sprite_frames.get_frame_texture(survivor.animation, survivor.frame)
	if ghost_texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "RollAfterimage"
	ghost.texture = ghost_texture
	ghost.centered = true
	ghost.offset = survivor_overlay.offset
	ghost.flip_h = survivor_overlay.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.position = camera.unproject_position(survivor.global_position)
	ghost.scale = survivor_overlay.scale
	ghost.modulate = Color(0.72, 0.8, 0.82, 0.32)
	ghost.z_index = OVERLAY_DEPTH_SORT.world_depth(player.global_position) - 1
	ghost.set_meta("world_position", survivor.global_position)
	building_canvas.add_child(ghost)
	roll_afterimages.append(ghost)
	var target_scale := ghost.scale * 1.055
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate", Color(0.62, 0.68, 0.7, 0.0), 0.26)
	tween.tween_property(ghost, "scale", target_scale, 0.26)
	tween.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
	)


func _set_facing(direction_name: String) -> void:
	if melee_attack_active and direction_name != facing:
		return
	if facing == direction_name and survivor.is_playing():
		return
	facing = direction_name
	_play_directional_animation()


func _set_motion_state(next_state: String) -> void:
	if melee_attack_active and next_state != "melee":
		return
	if motion_state == next_state:
		return
	motion_state = next_state
	_play_directional_animation()


func _play_directional_animation() -> void:
	# The cat owns all eight views; never mirror one direction into another.
	survivor.flip_h = false
	if loafing:
		survivor.play("loaf_%s" % facing)
	else:
		survivor.play("%s_%s" % [motion_state, facing])
	if weapon_sprite and has_ak and not melee_attack_active and not loafing:
		var weapon_state := "fire" if weapon_sprite.animation.begins_with("fire_") else "idle"
		var previous_frame := weapon_sprite.frame
		_play_weapon_directional_animation(weapon_state)
		if weapon_state == "fire":
			weapon_sprite.frame = mini(previous_frame, weapon_sprite.sprite_frames.get_frame_count(weapon_sprite.animation) - 1)
	weapon_combat._update_weapon_pose()


func _get_weapon_source_facing() -> String:
	match facing:
		"w": return "e"
		"sw": return "se"
		"nw": return "ne"
	return facing


func _play_weapon_directional_animation(state: String) -> void:
	if weapon_sprite == null:
		return
	weapon_sprite.flip_h = facing in ["w", "sw", "nw"]
	weapon_sprite.play("%s_%s" % [state, _get_weapon_source_facing()])


func _build_sprite_frames() -> void:
	unarmed_sprite_frames = _create_cat_frames()
	survivor.sprite_frames = unarmed_sprite_frames


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
		var melee_animation_name := "melee_%s" % direction_name
		frames.add_animation(melee_animation_name)
		frames.set_animation_loop(melee_animation_name, false)
		frames.set_animation_speed(melee_animation_name, MELEE_ANIMATION_FPS)
		for frame_index in MELEE_FRAME_COUNT:
			var melee_texture_path := "%s/%s_action_%d.png" % [
				CAT_MELEE_ANIMATION_ROOT,
				state_prefix,
				frame_index,
			]
			var melee_texture := load(melee_texture_path) as Texture2D
			if melee_texture == null:
				push_error("Missing cat melee animation frame: %s" % melee_texture_path)
				continue
			frames.add_frame(melee_animation_name, melee_texture)
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


func _setup_weapon_layer() -> void:
	weapon_sprite = AnimatedSprite3D.new()
	weapon_sprite.name = "EquippedWeapon"
	weapon_sprite.position = Vector3(0, 0.32, 0)
	weapon_sprite.pixel_size = WEAPON_VISUAL_PIXEL_SIZE
	weapon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_sprite.shaded = false
	weapon_sprite.transparent = true
	weapon_sprite.no_depth_test = true
	weapon_sprite.offset = Vector2(0, -28)
	weapon_sprite.visible = false
	player.add_child(weapon_sprite)

	_rebuild_player_weapon_frames()
	weapon_sprite.animation_finished.connect(_on_weapon_animation_finished)


func _rebuild_player_weapon_frames() -> void:
	var catalog_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(equipped_weapon_id)
	weapon_sprite.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size(
		equipped_weapon_id,
		WEAPON_VISUAL_PIXEL_SIZE
	)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_index in SCREEN_DIRECTION_NAMES.size():
		var direction_name: String = SCREEN_DIRECTION_NAMES[direction_index]
		var idle_name := "idle_%s" % direction_name
		var fire_name := "fire_%s" % direction_name
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(
			idle_name,
			catalog_texture if catalog_texture != null else _weapon_atlas_frame(direction_index, 0)
		)
		frames.add_animation(fire_name)
		frames.set_animation_loop(fire_name, false)
		frames.set_animation_speed(fire_name, 18.0)
		frames.add_frame(
			fire_name,
			catalog_texture if catalog_texture != null else _weapon_atlas_frame(direction_index, 1),
			1.0
		)
		frames.add_frame(
			fire_name,
			catalog_texture if catalog_texture != null else _weapon_atlas_frame(direction_index, 0),
			1.0
		)
	weapon_sprite.sprite_frames = frames
	_play_weapon_directional_animation("idle")


func _weapon_atlas_frame(direction_index: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = AK_DIRECTIONAL_TEXTURE
	atlas.region = Rect2(
		direction_index * WEAPON_FRAME_SIZE.x,
		row * WEAPON_FRAME_SIZE.y,
		WEAPON_FRAME_SIZE.x,
		WEAPON_FRAME_SIZE.y
	)
	return atlas


func _on_weapon_animation_finished() -> void:
	if has_ak:
		_play_weapon_directional_animation("idle")


func _setup_melee_weapon() -> void:
	melee_bat_sprite = Sprite3D.new()
	melee_bat_sprite.name = "TemporaryBaseballBat"
	melee_bat_sprite.texture = BASEBALL_BAT_TEXTURE
	melee_bat_sprite.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size("baseball_bat", 0.00058)
	melee_bat_sprite.centered = true
	melee_bat_sprite.offset = Vector2.ZERO
	melee_bat_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	melee_bat_sprite.shaded = false
	melee_bat_sprite.transparent = true
	melee_bat_sprite.no_depth_test = true
	melee_bat_sprite.render_priority = 126
	melee_bat_sprite.visible = false
	player.add_child(melee_bat_sprite)
	_setup_melee_fan_indicator()


func _setup_melee_fan_indicator() -> void:
	melee_fan_fill_material = StandardMaterial3D.new()
	melee_fan_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	melee_fan_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	melee_fan_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	melee_fan_fill_material.no_depth_test = true
	melee_fan_fill_material.albedo_color = Color(1.0, 0.46, 0.08, 0.3)
	melee_fan_fill_material.render_priority = 1

	melee_fan_rim_material = StandardMaterial3D.new()
	melee_fan_rim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	melee_fan_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	melee_fan_rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	melee_fan_rim_material.no_depth_test = true
	melee_fan_rim_material.albedo_color = Color(1.0, 0.78, 0.22, 0.88)
	melee_fan_rim_material.render_priority = 2

	melee_fan_indicator = MeshInstance3D.new()
	melee_fan_indicator.name = "MeleeFanTelegraph"
	melee_fan_indicator.mesh = _create_melee_fan_mesh()
	melee_fan_indicator.position = Vector3(0, -0.735, 0)
	melee_fan_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	melee_fan_indicator.visible = false
	player.add_child(melee_fan_indicator)


func _create_melee_fan_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var half_angle := deg_to_rad(MELEE_FAN_HALF_ANGLE_DEG)
	var fill_vertices := PackedVector3Array()
	for segment in MELEE_FAN_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / MELEE_FAN_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / MELEE_FAN_SEGMENTS)
		fill_vertices.append(Vector3.ZERO)
		fill_vertices.append(Vector3(sin(angle_a), 0, cos(angle_a)) * MELEE_ATTACK_RANGE)
		fill_vertices.append(Vector3(sin(angle_b), 0, cos(angle_b)) * MELEE_ATTACK_RANGE)
	var fill_arrays := []
	fill_arrays.resize(Mesh.ARRAY_MAX)
	fill_arrays[Mesh.ARRAY_VERTEX] = fill_vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fill_arrays)
	mesh.surface_set_material(0, melee_fan_fill_material)

	var rim_vertices := PackedVector3Array()
	var inner_radius := MELEE_ATTACK_RANGE - 0.09
	for segment in MELEE_FAN_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / MELEE_FAN_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / MELEE_FAN_SEGMENTS)
		var outer_a := Vector3(sin(angle_a), 0.004, cos(angle_a)) * MELEE_ATTACK_RANGE
		var outer_b := Vector3(sin(angle_b), 0.004, cos(angle_b)) * MELEE_ATTACK_RANGE
		var inner_a := Vector3(sin(angle_a), 0.004, cos(angle_a)) * inner_radius
		var inner_b := Vector3(sin(angle_b), 0.004, cos(angle_b)) * inner_radius
		rim_vertices.append_array(PackedVector3Array([
			outer_a, outer_b, inner_b,
			outer_a, inner_b, inner_a,
		]))
	var rim_arrays := []
	rim_arrays.resize(Mesh.ARRAY_MAX)
	rim_arrays[Mesh.ARRAY_VERTEX] = rim_vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rim_arrays)
	mesh.surface_set_material(1, melee_fan_rim_material)
	return mesh


func _show_melee_fan(direction: Vector3) -> void:
	if melee_fan_indicator == null:
		return
	if melee_fan_tween != null and melee_fan_tween.is_valid():
		melee_fan_tween.kill()
	melee_fan_indicator.rotation = Vector3(0, atan2(direction.x, direction.z), 0)
	melee_fan_indicator.scale = Vector3(0.84, 1.0, 0.84)
	melee_fan_indicator.transparency = 0.0
	melee_fan_indicator.visible = true
	melee_fan_tween = create_tween()
	melee_fan_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	melee_fan_tween.tween_property(
		melee_fan_indicator, "scale", Vector3.ONE, MELEE_WINDUP_DURATION
	)


func _hide_melee_fan() -> void:
	if melee_fan_indicator == null or not melee_fan_indicator.visible:
		return
	if melee_fan_tween != null and melee_fan_tween.is_valid():
		melee_fan_tween.kill()
	melee_fan_tween = create_tween()
	melee_fan_tween.tween_property(melee_fan_indicator, "transparency", 1.0, 0.08)
	melee_fan_tween.tween_callback(func() -> void:
		if is_instance_valid(melee_fan_indicator):
			melee_fan_indicator.visible = false
	)


func _try_melee_attack() -> void:
	if melee_attack_cooldown > 0.0 or melee_attack_active or roll_active or loafing or player_health <= 0:
		return
	melee_attack_cooldown = MELEE_ATTACK_COOLDOWN
	_add_fatigue(FATIGUE_MELEE_GAIN)
	var attack_direction := weapon_combat._get_mouse_world_direction() if weapon_combat._uses_mouse_aim() else _get_current_facing_world_direction()
	_lock_aim_direction(attack_direction)
	_set_facing_from_world_direction(attack_direction)
	melee_attack_active = true
	melee_attack_elapsed = 0.0
	melee_attack_direction = attack_direction.normalized()
	melee_hit_resolved = false
	motion_state = "melee"
	_play_directional_animation()
	_show_melee_fan(melee_attack_direction)
	_play_bat_swing(attack_direction)
	state_label.text = "근접 공격"


func _update_melee_attack(delta: float) -> void:
	if not melee_attack_active:
		return
	melee_attack_elapsed += delta
	if not melee_hit_resolved and melee_attack_elapsed >= MELEE_WINDUP_DURATION:
		melee_hit_resolved = true
		_hide_melee_fan()
		_spawn_player_melee_arc(melee_attack_direction)
		_resolve_melee_hit(melee_attack_direction)
		state_label.text = "근접 공격"
	if melee_attack_elapsed >= MELEE_ANIMATION_DURATION:
		_finish_melee_attack()


func _finish_melee_attack() -> void:
	if not melee_attack_active:
		return
	melee_attack_active = false
	melee_attack_elapsed = 0.0
	melee_hit_resolved = false
	_hide_melee_fan()
	motion_state = ""
	_set_motion_state("walk" if player.velocity.length_squared() > 0.1 else "idle")
	weapon_combat._update_weapon_pose()


func _play_bat_swing(direction: Vector3) -> void:
	var player_screen := camera.unproject_position(player.global_position)
	var target_screen := camera.unproject_position(
		player.global_position + direction * MELEE_ATTACK_RANGE
	)
	var screen_direction := (target_screen - player_screen).normalized()
	var screen_reach := player_screen.distance_to(target_screen)
	var screen_angle := atan2(screen_direction.y, screen_direction.x)
	var aligned_angle := screen_angle + PI * 0.25
	var bat_texture_size := Vector2(
		BASEBALL_BAT_TEXTURE.get_width(),
		BASEBALL_BAT_TEXTURE.get_height()
	)
	var bat_texture_length := maxf(1.0, bat_texture_size.length())
	var bat_visual_length := clampf(screen_reach * 0.72, 48.0, 68.0)
	var bat_overlay_scale := bat_visual_length / bat_texture_length
	var bat_world_length := bat_texture_length * melee_bat_sprite.pixel_size * 0.9
	var bat_world_center := maxf(0.3, MELEE_ATTACK_RANGE - bat_world_length * 0.5)
	var bat_screen_center := maxf(18.0, screen_reach - bat_visual_length * 0.5)
	melee_bat_sprite.visible = building_canvas == null
	melee_bat_sprite.flip_h = false
	melee_bat_sprite.flip_v = false
	melee_bat_sprite.modulate = Color(1.18, 1.08, 0.92, 1.0)
	melee_bat_sprite.position = direction * 0.28 + Vector3(0, 0.43, 0)
	melee_bat_sprite.rotation.z = aligned_angle - deg_to_rad(96.0)
	melee_bat_sprite.scale = Vector3.ONE * 0.78
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(melee_bat_sprite, "rotation:z", aligned_angle + deg_to_rad(58.0), 0.21).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(melee_bat_sprite, "position", direction * bat_world_center + Vector3(0, 0.45, 0), 0.21)
	tween.tween_property(melee_bat_sprite, "scale", Vector3.ONE * 0.9, 0.21)
	tween.chain().tween_property(melee_bat_sprite, "modulate", Color(1.0, 0.82, 0.55, 0.0), 0.13)
	tween.chain().tween_callback(func() -> void:
		melee_bat_sprite.visible = false
	)
	if is_instance_valid(melee_bat_overlay):
		melee_bat_overlay.visible = true
		melee_bat_overlay.modulate = Color(1.2, 1.08, 0.88, 1.0)
		melee_bat_overlay.position = player_screen + screen_direction * 18.0 + Vector2(0, -10)
		melee_bat_overlay.rotation = aligned_angle - deg_to_rad(98.0)
		melee_bat_overlay.scale = Vector2.ONE * (bat_overlay_scale * 0.82)
		melee_bat_overlay.z_index = OVERLAY_DEPTH_SORT.world_depth(player.global_position) + 4
		var overlay_tween := create_tween()
		overlay_tween.set_parallel(true)
		overlay_tween.tween_property(melee_bat_overlay, "rotation", aligned_angle + deg_to_rad(62.0), 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		overlay_tween.tween_property(melee_bat_overlay, "position", player_screen + screen_direction * bat_screen_center + Vector2(0, -10), 0.22)
		overlay_tween.tween_property(melee_bat_overlay, "scale", Vector2.ONE * bat_overlay_scale, 0.22)
		overlay_tween.chain().tween_property(melee_bat_overlay, "modulate:a", 0.0, 0.11)
		overlay_tween.chain().tween_callback(func() -> void:
			melee_bat_overlay.visible = false
		)


func _resolve_melee_hit(direction: Vector3) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.05 or distance > MELEE_ATTACK_RANGE:
			continue
		if direction.dot(offset.normalized()) < cos(deg_to_rad(MELEE_FAN_HALF_ANGLE_DEG)):
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 0.35, 0),
			enemy.global_position + Vector3(0, 0.35, 0),
			COLLISION_PROFILES.ENEMY_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
		)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != enemy:
			continue
		var backstab := bool(enemy.call("is_backstab_from", player.global_position))
		var melee_damage := MELEE_ATTACK_DAMAGE
		if GameState.is_churu_buff_active("sharp_claws"):
			melee_damage = roundi(float(melee_damage) * 1.4)
		enemy.call("take_melee_hit", melee_damage, direction, backstab)


func _spawn_player_melee_arc(direction: Vector3) -> void:
	if melee_arc_texture == null:
		melee_arc_texture = _create_melee_arc_texture()
	var arc := Sprite3D.new()
	arc.name = "PlayerMeleeArc"
	arc.texture = melee_arc_texture
	arc.pixel_size = 0.012
	arc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arc.shaded = false
	arc.transparent = true
	arc.no_depth_test = true
	arc.render_priority = 125
	arc.position = player.position + direction * 0.95 + Vector3(0, 0.3, 0)
	add_child(arc)
	var player_screen := camera.unproject_position(player.global_position)
	var target_screen := camera.unproject_position(player.global_position + direction * 2.0)
	var screen_direction := (target_screen - player_screen).normalized()
	arc.rotation.z = atan2(screen_direction.y, screen_direction.x)
	arc.scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(arc, "scale", Vector3.ONE * 1.28, 0.18)
	tween.tween_property(arc, "modulate", Color(1.0, 0.52, 0.2, 0.0), 0.2)
	get_tree().create_timer(0.22).timeout.connect(arc.queue_free)


func _create_melee_arc_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(64, 64)
	for y in 128:
		for x in 128:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			var angle := rad_to_deg(atan2(offset.y, offset.x))
			if radius >= 40.0 and radius <= 57.0 and absf(angle) <= 68.0:
				var edge_alpha := 1.0 - absf(radius - 48.5) / 8.5
				image.set_pixel(x, y, Color(1.0, 0.7, 0.32, edge_alpha * 0.72))
	return ImageTexture.create_from_image(image)


func _refresh_weapon_stats() -> void:
	weapon_stats = WEAPON_SYSTEM.build_stats(
		equipped_weapon_id,
		equipped_weapon_mods,
		GameState.get_weapon_enhancement_level(equipped_weapon_id),
		GameState.mod_enhancement_levels
	)
	var magazine_id: String = GameState.equipped_magazine_id
	if not WEAPON_SYSTEM.is_magazine_compatible(equipped_weapon_id, magazine_id):
		magazine_id = str(weapon_stats.get("magazine_id", ""))
		GameState.equipped_magazine_id = magazine_id
	var ammo_id: String = GameState.equipped_ammo_id
	if not WEAPON_SYSTEM.is_ammo_compatible(magazine_id, ammo_id):
		ammo_id = str(weapon_stats.get("default_ammo_id", ""))
		GameState.equipped_ammo_id = ammo_id
	if not GameState.ammo_inventory.has(ammo_id):
		GameState.ammo_inventory[ammo_id] = reserve_ammo
	weapon_spread_deg = float(weapon_stats.get("base_spread_deg", 2.4))
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	magazine_ammo = mini(magazine_ammo, magazine_size)


func _update_scope_camera(delta: float) -> void:
	var scope_zoom := float(weapon_stats.get("scope_zoom", 1.0))
	var scope_active := (
		laser_aim_held
		and has_ak
		and scope_zoom > 1.0
		and not _is_inventory_open()
		and not _is_tactical_map_open()
		and not lore_reader.is_open()
	)
	var target_offset := Vector3.ZERO
	var target_camera_size := BASE_CAMERA_SIZE
	if boss_defeat_sequence_active:
		target_camera_size = BOSS_DEFEAT_CAMERA_SIZE
	elif scope_active:
		var fallback_direction := weapon_combat._get_mouse_world_direction() if weapon_combat._uses_mouse_aim() else _get_current_facing_world_direction()
		var aim_direction := locked_aim_direction if locked_aim_direction.length_squared() > 0.01 else fallback_direction
		target_offset = aim_direction.normalized() * float(weapon_stats.get("scope_shift", 0.0))
		target_camera_size = BASE_CAMERA_SIZE - minf(4.5, (scope_zoom - 1.0) * 1.5)
	var camera_delta := (
		delta / maxf(Engine.time_scale, 0.05)
		if boss_defeat_sequence_active
		else delta
	)
	var blend_speed := 1.0 - exp(-8.5 * camera_delta)
	scope_camera_offset = scope_camera_offset.lerp(target_offset, blend_speed)
	camera.size = lerpf(camera.size, target_camera_size, blend_speed)


func _create_aim_ring_arrow_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var radius := 0.72
	var half_width := 0.045
	var start_angle := deg_to_rad(-150.0)
	var end_angle := deg_to_rad(150.0)
	var segment_count := 44
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment_index in segment_count:
		var ratio_a := float(segment_index) / float(segment_count)
		var ratio_b := float(segment_index + 1) / float(segment_count)
		var angle_a := lerpf(start_angle, end_angle, ratio_a)
		var angle_b := lerpf(start_angle, end_angle, ratio_b)
		var inner_a := Vector3(
			sin(angle_a) * (radius - half_width),
			0.0,
			-cos(angle_a) * (radius - half_width)
		)
		var outer_a := Vector3(
			sin(angle_a) * (radius + half_width),
			0.0,
			-cos(angle_a) * (radius + half_width)
		)
		var inner_b := Vector3(
			sin(angle_b) * (radius - half_width),
			0.0,
			-cos(angle_b) * (radius - half_width)
		)
		var outer_b := Vector3(
			sin(angle_b) * (radius + half_width),
			0.0,
			-cos(angle_b) * (radius + half_width)
		)
		for vertex in [inner_a, outer_a, outer_b, inner_a, outer_b, inner_b]:
			mesh.surface_add_vertex(vertex)
	var arrow_tip := Vector3(0.0, 0.0, -1.03)
	var arrow_left := Vector3(-0.2, 0.0, -0.68)
	var arrow_right := Vector3(0.2, 0.0, -0.68)
	for vertex in [arrow_tip, arrow_left, arrow_right]:
		mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	return mesh


func _update_aim_feedback(delta: float) -> void:
	if hud.aim_direction_indicator == null:
		return
	var aim_direction := weapon_combat._get_mouse_world_direction() if weapon_combat._uses_mouse_aim() else _get_current_facing_world_direction()
	hud.aim_direction_indicator.look_at(hud.aim_direction_indicator.global_position + aim_direction, Vector3.UP)
	recoil_reticle_offset = recoil_reticle_offset.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	_update_laser_beam(aim_direction)
	if hud.aim_reticle:
		hud.aim_reticle.visible = (
			weapon_combat._uses_mouse_aim()
			and not _is_inventory_open()
			and not lore_reader.is_open()
		)
		if hud.aim_reticle.visible:
			hud.aim_reticle.call(
				"update_feedback",
				get_viewport().get_mouse_position(),
				weapon_spread_deg,
				recoil_reticle_offset,
				laser_aim_held
			)
	if hud.reload_reticle_indicator:
		var show_reload := (
			weapon_reloading
			and weapon_combat._uses_mouse_aim()
			and not _is_inventory_open()
			and not lore_reader.is_open()
		)
		var reload_progress := 0.0
		if show_reload:
			var reload_duration := maxf(0.01, float(weapon_stats.get("reload_time", 2.15)))
			reload_progress = 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
			hud.reload_reticle_indicator.position = get_viewport().get_mouse_position() - hud.reload_reticle_indicator.size * 0.5
		hud.reload_reticle_indicator.call("set_cooldown_progress", reload_progress, show_reload)


func _update_laser_beam(aim_direction: Vector3) -> void:
	if hud.laser_beam == null:
		return
	var should_show := laser_aim_held and has_ak and weapon_combat._uses_mouse_aim()
	for layer in laser_glow_layers:
		layer.visible = should_show
	if hud.laser_endpoint:
		hud.laser_endpoint.visible = should_show
	if not should_show:
		return
	var start := weapon_combat._get_weapon_muzzle_position(aim_direction)
	var end := start + aim_direction * 48.0
	var query := PhysicsRayQueryParameters3D.create(
		start,
		end,
		COLLISION_PROFILES.ENEMY_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.get("position")
	var distance := start.distance_to(end)
	if distance <= 0.02:
		for layer in laser_glow_layers:
			layer.visible = false
		if hud.laser_endpoint:
			hud.laser_endpoint.visible = false
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var base_widths := [0.072, 0.034, 0.010]
	for layer_index in laser_glow_layers.size():
		var width_scale := 1.0 + pulse * (0.18 if layer_index == 0 else 0.06)
		laser_glow_meshes[layer_index].size = Vector3(
			base_widths[layer_index] * width_scale,
			base_widths[layer_index] * width_scale,
			distance
		)
		var layer := laser_glow_layers[layer_index]
		layer.global_position = start.lerp(end, 0.5)
		layer.look_at(end, Vector3.UP)
	if hud.laser_endpoint:
		hud.laser_endpoint.global_position = end
		hud.laser_endpoint.scale = Vector3.ONE * lerpf(0.82, 1.28, pulse)


func _update_player_combat_feedback(delta: float) -> void:
	if hud.player_world_health_bar:
		var health_ratio := clampf(float(player_health) / float(GameState.get_max_health()), 0.0, 1.0)
		hud.player_world_health_fill.size.x = 46.0 * health_ratio
		hud.player_health_fill_style.bg_color = (
			Color(0.88, 0.18, 0.12, 0.98) if health_ratio <= 0.3
			else Color(0.94, 0.66, 0.16, 0.98) if health_ratio <= 0.6
			else Color(0.28, 0.86, 0.48, 0.96)
		)
		var head_position := camera.unproject_position(player.global_position + Vector3(0, 2.15, 0))
		hud.player_world_health_bar.position = head_position - Vector2(hud.player_world_health_bar.size.x * 0.5, 3.0)
		hud.player_world_health_bar.visible = not camera.is_position_behind(player.global_position)
		if hud.roll_cooldown_indicator:
			var stamina_ratio := clampf(roll_stamina / GameState.get_max_stamina(), 0.0, 1.0)
			var stamina_is_active := roll_active or stamina_ratio < 0.999
			hud.roll_cooldown_indicator.position = head_position + Vector2(28.0, -8.5)
			hud.roll_cooldown_indicator.call(
				"set_cooldown_progress",
				stamina_ratio,
				stamina_is_active
			)

	player_hit_flash_time = maxf(0.0, player_hit_flash_time - delta)
	camera_shake_time = maxf(0.0, camera_shake_time - delta)
	camera_shake_strength = move_toward(camera_shake_strength, 0.0, delta * 8.0)
	var hit_strength := clampf(player_hit_flash_time / 0.32, 0.0, 1.0)
	var flash_scale := clampf(float(AccessibilitySettings.hit_flash_scale), 0.0, 1.0)
	if hud.damage_vignette_material:
		hud.damage_vignette_material.set_shader_parameter(
			"intensity",
			hit_strength * hit_strength * clampf(float(AccessibilitySettings.vignette_scale), 0.0, 1.0)
		)
	if hit_strength <= 0.0:
		return
	var strobe := (0.55 + 0.45 * absf(sin(player_hit_flash_time * 58.0))) * flash_scale
	var survivor_alpha := survivor.modulate.a
	var flash_color := Color(1.8, 0.34, 0.18, survivor_alpha)
	survivor.modulate = survivor.modulate.lerp(flash_color, hit_strength * strobe)
	if weapon_sprite:
		var weapon_alpha := weapon_sprite.modulate.a
		weapon_sprite.modulate = weapon_sprite.modulate.lerp(
			Color(1.7, 0.3, 0.15, weapon_alpha),
			hit_strength * strobe
		)


func _setup_boss_alert_ui() -> void:
	boss_alert_panel = PanelContainer.new()
	boss_alert_panel.name = "BossArrivalAlert"
	boss_alert_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_alert_panel.offset_left = -280
	boss_alert_panel.offset_top = 54
	boss_alert_panel.offset_right = 280
	boss_alert_panel.offset_bottom = 150
	boss_alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_alert_panel.z_index = 480
	boss_alert_panel.modulate.a = 0.0
	boss_alert_panel.visible = false
	boss_alert_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.035, 0.024, 0.02, 0.96), Color("#d66a4a"), 8)
	)
	$HUD.add_child(boss_alert_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 13)
	boss_alert_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	margin.add_child(content)
	boss_alert_title = Label.new()
	boss_alert_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert_title.add_theme_font_override("font", FONT)
	boss_alert_title.add_theme_font_size_override("font_size", 26)
	boss_alert_title.add_theme_color_override("font_color", Color("#ffb075"))
	content.add_child(boss_alert_title)
	boss_alert_subtitle = Label.new()
	boss_alert_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert_subtitle.add_theme_font_override("font", FONT)
	boss_alert_subtitle.add_theme_font_size_override("font_size", 15)
	boss_alert_subtitle.add_theme_color_override("font_color", Color("#d6c3b5"))
	content.add_child(boss_alert_subtitle)


func _setup_boss_defeat_ui() -> void:
	boss_defeat_overlay = Control.new()
	boss_defeat_overlay.name = "BossDefeatCinematic"
	boss_defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_defeat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_defeat_overlay.z_index = 490
	boss_defeat_overlay.visible = false
	$HUD.add_child(boss_defeat_overlay)
	boss_defeat_flash = ColorRect.new()
	boss_defeat_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_defeat_flash.color = Color(1.0, 0.72, 0.28, 0.0)
	boss_defeat_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_defeat_overlay.add_child(boss_defeat_flash)
	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if is_top else 0.90
		bar.anchor_bottom = 0.10 if is_top else 1.0
		bar.color = Color(0.003, 0.005, 0.005, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_defeat_overlay.add_child(bar)
	boss_defeat_panel = PanelContainer.new()
	boss_defeat_panel.name = "BossDefeatTitlePanel"
	# 연출 중 카메라는 보스를 화면 중앙에 잡는다. 패널을 가운데 두면 정작
	# 보여주려는 보스를 가린다. 하단 레터박스 바로 위로 내린다.
	boss_defeat_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_defeat_panel.offset_left = -360
	boss_defeat_panel.offset_top = -252
	boss_defeat_panel.offset_right = 360
	boss_defeat_panel.offset_bottom = -104
	boss_defeat_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.012, 0.016, 0.015, 0.96), Color("#d9a441"), 8)
	)
	boss_defeat_overlay.add_child(boss_defeat_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 18)
	boss_defeat_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = "BOSS ELIMINATED"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", FONT)
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("#c58f39"))
	content.add_child(eyebrow)
	boss_defeat_title = Label.new()
	boss_defeat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_defeat_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_defeat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_defeat_title.add_theme_font_override("font", FONT)
	boss_defeat_title.add_theme_font_size_override("font_size", 38)
	boss_defeat_title.add_theme_color_override("font_color", Color("#ffe39a"))
	content.add_child(boss_defeat_title)
	boss_defeat_subtitle = Label.new()
	boss_defeat_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_defeat_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_defeat_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_defeat_subtitle.add_theme_font_override("font", FONT)
	boss_defeat_subtitle.add_theme_font_size_override("font_size", 16)
	boss_defeat_subtitle.add_theme_color_override("font_color", Color("#c9d3ce"))
	content.add_child(boss_defeat_subtitle)
	get_viewport().size_changed.connect(_layout_boss_defeat_panel)
	call_deferred("_layout_boss_defeat_panel")


func _layout_boss_defeat_panel() -> void:
	if not is_instance_valid(boss_defeat_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := clampf(viewport_size.x * 0.84, 280.0, 720.0)
	var panel_height := clampf(viewport_size.y * 0.24, 148.0, 176.0)
	boss_defeat_panel.offset_left = -panel_width * 0.5
	boss_defeat_panel.offset_right = panel_width * 0.5
	boss_defeat_panel.offset_top = -panel_height * 0.5
	boss_defeat_panel.offset_bottom = panel_height * 0.5
	var compact := viewport_size.x < 620.0
	boss_defeat_title.add_theme_font_size_override("font_size", 29 if compact else 38)
	boss_defeat_subtitle.add_theme_font_size_override("font_size", 14 if compact else 16)


func _play_boss_defeat_sequence(enemy: CharacterBody3D) -> void:
	if (
		boss_defeat_sequence_active
		or player_death_sequence_active
		or extraction_transition_active
		or not is_instance_valid(enemy)
	):
		return
	boss_defeat_sequence_serial += 1
	var serial := boss_defeat_sequence_serial
	hit_stop_serial += 1
	boss_defeat_sequence_active = true
	boss_defeat_focus_position = enemy.global_position
	_release_mobile_held_actions()
	mouse_fire_held = false
	laser_aim_held = false
	touch_vector = Vector2.ZERO
	player.velocity = Vector3.ZERO
	if mobile_flashlight_button:
		mobile_flashlight_button.set_pressed_no_signal(false)
	_update_combat_overlay_visibility()
	var display_name := str(enemy.get_meta("display_name", "위험 개체"))
	boss_defeat_title.text = "%s, 침묵" % display_name
	# 처치는 끝이 아니라 시작이다. 총성은 도시 전체가 들었다.
	boss_defeat_subtitle.text = (
		"소리가 멎었다. 그리고 도시가 이쪽을 본다.\n챙길 것을 챙기고, 나가라."
		if raid_pressure_level >= RAID_EVENT_DIRECTOR.LEVEL_HUNT
		else "소리가 멎었다. 남은 것을 챙기고 빠져나가라."
	)
	boss_defeat_overlay.visible = true
	boss_defeat_overlay.modulate.a = 1.0
	boss_defeat_panel.modulate.a = 0.0
	boss_defeat_panel.scale = Vector2(0.82, 0.82)
	boss_defeat_panel.pivot_offset = boss_defeat_panel.size * 0.5
	boss_defeat_flash.color.a = 0.26
	camera_shake_time = maxf(camera_shake_time, 0.72)
	camera_shake_strength = maxf(camera_shake_strength, 0.46)
	Engine.time_scale = BOSS_DEFEAT_TIME_SCALE
	if boss_defeat_tween and boss_defeat_tween.is_valid():
		boss_defeat_tween.kill()
	boss_defeat_tween = create_tween()
	boss_defeat_tween.set_ignore_time_scale(true)
	boss_defeat_tween.set_parallel(true)
	boss_defeat_tween.tween_property(boss_defeat_flash, "color:a", 0.0, 0.42)
	boss_defeat_tween.tween_property(boss_defeat_panel, "modulate:a", 1.0, 0.18)
	boss_defeat_tween.tween_property(boss_defeat_panel, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(BOSS_DEFEAT_SLOWMO_SECONDS, true, false, true).timeout
	if serial != boss_defeat_sequence_serial or player_death_sequence_active:
		return
	Engine.time_scale = 1.0
	await get_tree().create_timer(
		maxf(0.0, BOSS_DEFEAT_FOCUS_SECONDS - BOSS_DEFEAT_SLOWMO_SECONDS),
		true,
		false,
		true
	).timeout
	if serial != boss_defeat_sequence_serial:
		return
	boss_defeat_sequence_active = false
	_update_combat_overlay_visibility()
	var hide_tween := create_tween()
	hide_tween.set_ignore_time_scale(true)
	hide_tween.tween_property(boss_defeat_overlay, "modulate:a", 0.0, 0.28)
	hide_tween.tween_callback(func() -> void:
		if boss_defeat_overlay:
			boss_defeat_overlay.visible = false
			boss_defeat_overlay.modulate.a = 1.0
	)


func _show_boss_alert(display_name: String) -> void:
	if boss_alert_panel == null:
		return
	if boss_alert_tween and boss_alert_tween.is_valid():
		boss_alert_tween.kill()
	boss_alert_title.text = "위험 개체 출현 · %s" % display_name
	boss_alert_subtitle.text = (
		"지하철 통신에서 포착한 포격 신호의 주인이 접근합니다."
		if GameState.subway_story_stage >= 1
		else "피로가 쌓인 생존자의 흔적을 추적해 접근합니다."
	)
	boss_alert_active = true
	_layout_center_top_banners()
	boss_alert_panel.modulate.a = 0.0
	boss_alert_panel.scale = Vector2(0.96, 0.96)
	boss_alert_panel.pivot_offset = boss_alert_panel.size * 0.5
	boss_alert_tween = create_tween()
	boss_alert_tween.set_parallel(true)
	boss_alert_tween.tween_property(boss_alert_panel, "modulate:a", 1.0, 0.24)
	boss_alert_tween.tween_property(boss_alert_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	boss_alert_tween.set_parallel(false)
	boss_alert_tween.tween_interval(3.2)
	boss_alert_tween.tween_property(boss_alert_panel, "modulate:a", 0.0, 0.42)
	boss_alert_tween.tween_callback(func() -> void:
		boss_alert_active = false
		_layout_center_top_banners()
	)


func _capture_raid_start_snapshot() -> void:
	raid_start_snapshot = {
		"magazine_ammo": GameState.magazine_ammo,
		"reserve_ammo": GameState.reserve_ammo,
		"ammo_inventory": GameState.ammo_inventory.duplicate(true),
		"medkits": GameState.medkits,
		"canned_food": GameState.get_backpack_storage_count("food", "canned_food"),
		"churu": GameState.churu,
		"mod_component_inventory": GameState.mod_component_inventory.duplicate(true),
		"progression_item_inventory": GameState.progression_item_inventory.duplicate(true),
		"weapon_mod_inventory": GameState.weapon_mod_inventory.duplicate(true),
		"weapon_inventory": GameState.weapon_inventory.duplicate(true),
		"equipment_inventory": GameState.equipment_inventory.duplicate(true),
		"equipped_body_armor_id": GameState.equipped_body_armor_id,
		"equipped_head_armor_id": GameState.equipped_head_armor_id,
		"equipped_footwear_id": GameState.equipped_footwear_id,
		"weapon_durability": GameState.weapon_durability,
		"equipped_weapon_id": GameState.equipped_weapon_id,
		"equipped_weapon_mods": GameState.equipped_weapon_mods.duplicate(),
		"weapon_mod_loadouts": GameState.weapon_mod_loadouts.duplicate(true),
		"equipped_magazine_id": GameState.equipped_magazine_id,
		"equipped_ammo_id": GameState.equipped_ammo_id,
		"has_ak": GameState.has_ak,
		"fatigue": GameState.fatigue,
	}


func _clear_carried_inventory_after_death() -> void:
	GameState.clear_carried_raid_inventory_after_death()
	if not GameState.is_raid_zone_unlocked(GameState.selected_raid_zone):
		GameState.selected_raid_zone = FIRST_STAGE_ZONE_ID
	# 시큐어 슬롯이 지킨 것을 돌려준다. 이 호출이 빠져 있어서 슬롯 시스템 전체가
	# 죽은 코드였고, 사망은 예외 없는 100% 손실이었다.
	RAID_LOSS_MANAGER.restore_secure_items_after_death()
	GameState.fatigue = minf(fatigue + 18.0, FATIGUE_MAX)
	GameState.player_health = mini(82, GameState.get_max_health())
	GameState.returning_from_shelter = false
	GameState.world_time_hours = 9.0
	GameState.save_persistent_state()


func _format_survival_time() -> String:
	var elapsed_seconds := maxi(0, int((Time.get_ticks_msec() - run_started_msec) / 1000))
	var minutes := elapsed_seconds / 60
	var seconds := elapsed_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _build_death_lesson() -> String:
	# "누가 나를 죽였나"는 이미 보여준다. 정작 필요한 건 "그래서 무엇이
	# 문제였나"다. 죽는 순간의 상태에서 가장 큰 원인 하나만 짚어 준다.
	# 사망이 처벌로만 끝나면 배우는 게 없다.
	if fatigue >= 65.0:
		return "피로 %d%% · 이동이 느려지고 탄이 퍼진 상태였습니다. 더 일찍 빠져나올 수 있었습니다." % roundi(fatigue)
	if magazine_ammo <= 0 and reserve_ammo <= 0:
		return "탄약이 바닥난 상태였습니다. 탄이 떨어지면 그 자리가 곧 한계선입니다."
	if raid_pressure_level >= 2:
		return "도시 긴장도가 높아 증원이 계속 도착하고 있었습니다. 추출 비콘이 가까웠다면 그쪽이 답이었습니다."
	if GameState.medkits > 0:
		return "치료 키트가 %d개 남아 있었습니다. 다음엔 더 일찍 쓰세요." % GameState.medkits
	return "무리한 교전 하나가 판 전체를 가져갑니다. 다음엔 한 발 물러서는 것도 선택입니다."


func _begin_player_death_sequence() -> void:
	if player_death_sequence_active:
		return
	player_death_sequence_active = true
	_refresh_pointer_mode()
	_update_combat_overlay_visibility()
	var corpse_loot := RAID_LOSS_MANAGER.store_death_corpse(player.global_position)
	fire_button_held = false
	mouse_fire_held = false
	laser_aim_held = false
	space_hold_active = false
	space_hold_consumed = false
	_set_loafing(false)
	player.velocity = Vector3.ZERO
	if hud.reload_reticle_indicator:
		hud.reload_reticle_indicator.visible = false
	game_over_screen.present({
		"survival_time": _format_survival_time(),
		"kills": run_kills,
		"damage_text": GameState.format_compact_number(run_damage_dealt),
		"source_name": last_damage_source_name,
		"weapon_name": last_damage_weapon_name,
		"blocked": last_damage_blocked,
		"loss_value_text": GameState.format_compact_number(
			RAID_LOSS_MANAGER.get_total_value(corpse_loot)
		),
		"loot": corpse_loot,
		"lesson": _build_death_lesson(),
	})
	Engine.time_scale = 0.18
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(camera, "size", maxf(8.5, camera.size * 0.46), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(survivor, "modulate", Color(1, 1, 1, 0), 1.25).set_delay(0.45)
	tween.tween_property(game_over_screen.panel, "modulate:a", 1.0, 0.55).set_delay(0.65)
	tween.tween_property(game_over_screen.fade, "color:a", 0.62, 0.85).set_delay(1.15)
	tween.set_parallel(false)
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void: game_over_screen.ready_to_continue = true)


func _continue_after_death() -> void:
	if not game_over_screen.can_continue():
		return
	game_over_screen.mark_continue_started()
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(game_over_screen.fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		Engine.time_scale = 1.0
		_clear_carried_inventory_after_death()
		# 사망 귀환은 "살아 돌아온" 게 아니다 — 생환 전용 서사가 열리지 않게 한다.
		GameState.register_shelter_return(false)
		SceneTransition.transition_to("res://scenes/shelter_interior.tscn")
	)


func _spawn_ak_pickup() -> void:
	ak_pickup = Node3D.new()
	ak_pickup.name = "AK47Pickup"
	ak_pickup.position = _safe_map_position(_scale_map_position(AK_PICKUP_POSITION))
	add_child(ak_pickup)

	var sprite := Sprite3D.new()
	sprite.name = "DropSprite"
	sprite.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture("ak47")
	sprite.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size("ak47", 0.0034)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 90
	ak_pickup.add_child(sprite)

	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0, 0, 0, 0.32)
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.46
	shadow_mesh.bottom_radius = 0.46
	shadow_mesh.height = 0.012
	shadow_mesh.radial_segments = 20
	shadow_mesh.material = shadow_material
	var shadow := MeshInstance3D.new()
	shadow.name = "DropShadow"
	shadow.position.y = -0.29
	shadow.mesh = shadow_mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ak_pickup.add_child(shadow)
	loot_system._add_loot_highlight(ak_pickup, Color("#dfb94f"), 1.05)


func _spawn_ammo_pickups() -> void:
	var world := $World as ProceduralCityMap
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	var container_plan: Array[String] = LOOT_ECONOMY.build_container_plan(
		stage_tier,
		spawn_random
	)
	_apply_region_container_mix(container_plan)
	var first_basic_cache_index := container_plan.find("street_cache")
	if first_basic_cache_index > 0:
		var first_container_type := container_plan[0]
		container_plan[0] = container_plan[first_basic_cache_index]
		container_plan[first_basic_cache_index] = first_container_type
	var occupied_positions: Array[Vector3] = []
	for index in container_plan.size():
		var container_type := str(container_plan[index])
		var position := (
			_find_first_supply_container_position(world, occupied_positions)
			if index == 0
			else _find_risk_band_loot_position(
				world,
				_target_risk_band_for_container(container_type),
				index,
				container_plan.size(),
				occupied_positions
			)
		)
		occupied_positions.append(position)
		_spawn_field_loot_container(
			world,
			position,
			container_type,
			stage_tier,
			index
		)
	var canned_food_pickup_count := (
		LOOT_ECONOMY.get_guaranteed_canned_food_pickup_count(stage_tier)
	)
	for index in canned_food_pickup_count:
		var position := _find_stratified_map_position(
			world,
			index,
			canned_food_pickup_count,
			8.0,
			5.5,
			occupied_positions,
			0.34
		)
		occupied_positions.append(position)
		var amount := LOOT_ECONOMY.roll_guaranteed_canned_food_amount(
			stage_tier,
			spawn_random
		)
		var pickup := loot_system._create_loot_pickup(
			"canned_food",
			position,
			{
				"amount": amount,
				"display_name": "통조림",
				"guaranteed_field_supply": true,
			}
		)
		pickup.name = "CannedFoodPickup_%02d" % index


func _apply_region_container_mix(container_plan: Array[String]) -> void:
	var adjustments := raid_zone_data.get("container_adjustments", {}) as Dictionary
	if adjustments.is_empty():
		return
	var donor_types: Array[String] = []
	var receiver_types: Array[String] = []
	for container_type_variant in adjustments:
		var container_type := str(container_type_variant)
		var delta := int(adjustments[container_type_variant])
		if delta < 0:
			for _index in -delta:
				donor_types.append(container_type)
		elif delta > 0:
			for _index in delta:
				receiver_types.append(container_type)
	var replacement_count := mini(donor_types.size(), receiver_types.size())
	for replacement_index in replacement_count:
		var donor_type := donor_types[replacement_index]
		var donor_index := container_plan.find(donor_type)
		if donor_index < 0:
			continue
		container_plan[donor_index] = receiver_types[replacement_index]


func _find_first_supply_container_position(
	world: ProceduralCityMap,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var distance_band: Vector2 = raid_zone_data.get(
		"first_supply_distance", Vector2(9.0, 16.0)
	)
	var map_limit := world.get_map_limit() - 4.0
	for attempt in 18:
		var angle := TAU * float(attempt) / 18.0 + spawn_random.randf_range(-0.12, 0.12)
		var distance := spawn_random.randf_range(distance_band.x, distance_band.y)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		requested.y = 0.34
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = 0.34
		if candidate.distance_to(player.global_position) < distance_band.x * 0.75:
			continue
		var overlaps_existing := false
		for occupied in occupied_positions:
			if occupied.distance_to(candidate) < 5.0:
				overlaps_existing = true
				break
		if not overlaps_existing:
			return candidate
	return world.find_nearest_physically_open_position(
		player.global_position + Vector3(distance_band.x, 0.34, 0.0),
		0.62,
		[player.get_rid()]
	)


func _target_risk_band_for_container(container_type: String) -> String:
	match container_type:
		"weapon_case", "secure_cache":
			return "restricted"
		"ammo_case", "toolbox":
			return "scavenge"
		_:
			return "safe" if spawn_random.randf() < 0.42 else "scavenge"


func _find_risk_band_loot_position(
	world: ProceduralCityMap,
	target_band: String,
	index: int,
	total_count: int,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var map_limit := world.get_map_limit() - 5.0
	var best_candidate := Vector3.INF
	var best_score := -INF
	for attempt in 30:
		var requested := Vector3(
			spawn_random.randf_range(-map_limit, map_limit),
			0.34,
			spawn_random.randf_range(-map_limit, map_limit)
		)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = 0.34
		if candidate.distance_to(player.global_position) < 10.0:
			continue
		var nearest_spacing := INF
		for occupied in occupied_positions:
			nearest_spacing = minf(nearest_spacing, occupied.distance_to(candidate))
		if nearest_spacing < 7.0:
			continue
		var band_matches := world.get_risk_band(candidate) == target_band
		var spacing_score := 18.0 if nearest_spacing == INF else minf(nearest_spacing, 18.0)
		var score := spacing_score + (35.0 if band_matches else 0.0)
		if score > best_score:
			best_score = score
			best_candidate = candidate
		if band_matches and nearest_spacing >= 12.0:
			return candidate
	if best_candidate != Vector3.INF:
		return best_candidate
	return _find_stratified_map_position(
		world,
		index,
		total_count,
		12.0,
		9.0,
		occupied_positions,
		0.34
	)


func _spawn_field_loot_container(
	world: ProceduralCityMap,
	position: Vector3,
	container_type: String,
	stage_tier: int,
	index: int
) -> Node3D:
	var district := world.get_district_id(position)
	var visual_definition := LOOT_CONTAINER_VISUALS.get_definition(container_type)
	var point := _create_field_interaction(
		"loot_container",
		position,
		LOOT_ECONOMY.get_container_display_name(container_type),
		float(visual_definition.get("open_duration", 0.72))
	)
	point.name = "LootContainer_%02d_%s" % [index, container_type]
	point.set_meta("container_type", container_type)
	point.set_meta("stage_tier", stage_tier)
	point.set_meta("district_id", district)
	point.set_meta("risk_band", world.get_risk_band(position))
	point.set_meta("raid_zone_id", world.get_region_id())
	point.set_meta("container_index", index)
	_build_field_loot_container_visual(point, container_type)
	field_loot_containers.append(point)
	return point


func _build_field_loot_container_visual(point: Node3D, container_type: String) -> void:
	var definition := LOOT_CONTAINER_VISUALS.get_definition(container_type)
	var texture_path := str(definition.get("texture_path", ""))
	var texture := (
		load(texture_path) as Texture2D
		if ResourceLoader.exists(texture_path)
		else FIELD_LOOT_CACHE_TEXTURE
	)
	var sprite := Sprite3D.new()
	sprite.name = "ContainerSprite"
	sprite.texture = texture
	sprite.pixel_size = float(definition.get("world_width", 1.55)) / maxf(
		1.0, float(texture.get_width())
	)
	sprite.position = Vector3(0.0, float(definition.get("world_height", 0.82)) * 0.5, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	point.add_child(sprite)
	point.set_meta("container_texture_path", texture_path)
	point.set_meta("visual_world_width", float(definition.get("world_width", 1.55)))
	var icon_name := str(definition.get("icon", "backpack"))
	var icon := Sprite3D.new()
	icon.name = "ContainerTypeIcon"
	icon.texture = UI_ICONS.get_icon(icon_name, 72, Color("#f2d889"))
	icon.pixel_size = 0.0048
	icon.position = Vector3(
		0.0,
		float(definition.get("world_height", 0.82)) + 0.34,
		0.0
	)
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.transparent = true
	icon.no_depth_test = true
	icon.render_priority = 38
	icon.modulate.a = 0.82 if container_type in ["weapon_case", "secure_cache"] else 0.58
	point.add_child(icon)


func _roll_district_loot_definition(district: String, index: int) -> Dictionary:
	var deterministic_random := RandomNumberGenerator.new()
	deterministic_random.seed = (
		GameState.map_seed
		+ index * 104729
		+ district.hash()
	)
	return LOOT_ECONOMY.roll_loose_loot(
		LOOT_ECONOMY.get_stage_for_zone(raid_zone_data),
		district,
		deterministic_random
	)


func _get_loot_glow_texture() -> ImageTexture:
	if loot_glow_texture != null:
		return loot_glow_texture
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / 96.0
			var center_distance := uv.distance_to(Vector2(0.5, 0.5))
			var diamond := absf(uv.x - 0.5) + absf(uv.y - 0.5)
			var alpha := maxf(0.0, 1.0 - diamond * 2.1)
			alpha = maxf(alpha, maxf(0.0, 1.0 - center_distance * 2.6) * 0.55)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	loot_glow_texture = ImageTexture.create_from_image(image)
	return loot_glow_texture


func _layout_mobile_utility_row() -> float:
	# 우하단 액션 버튼 바로 위에 오른쪽부터 채운다. 반환값은 줄 높이(없으면 0).
	#
	# 이 함수가 표시 여부와 위치를 함께 정하는 유일한 곳이어야 한다. 예전에는
	# _refresh_mobile_context_button()이 매 프레임 visible만 직접 켰고, 위치는
	# 생성 시점 offset(-108)에 머물러 있었다. 그래서 줍기 버튼이 발사 버튼
	# 아래 화면 밖에 잘린 채 떠 있었고 눌러도 아무 일이 없었다.
	if not DisplayServer.is_touchscreen_available():
		return 0.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return 0.0
	var ui_scale := clampf(
		(minf(viewport_size.x / 780.0, viewport_size.y / 1360.0) if viewport_size.y > viewport_size.x else minf(viewport_size.x / 1360.0, viewport_size.y / 780.0))
		* float(AccessibilitySettings.ui_scale),
		0.62,
		1.5
	)
	var safe_margins := UI_SAFE_AREA.get_margins(viewport_size)
	var side_margin := maxf(
		maxf(safe_margins.x, safe_margins.z),
		clampf(viewport_size.x * 0.02, 10.0, 26.0)
	)
	var bottom_margin := maxf(safe_margins.w, clampf(viewport_size.y * 0.018, 8.0, 26.0))
	var action_button_size := clampf(viewport_size.y * 0.155, 68.0, 128.0)
	var utility_size := clampf(action_button_size * 0.72, 52.0, 96.0)
	var utility_gap := clampf(10.0 * ui_scale, 6.0, 12.0)
	var utility_base_bottom := (
		-bottom_margin - action_button_size - clampf(13.0 * ui_scale, 8.0, 16.0)
	)
	var hud_blocked := _is_inventory_open() or _is_tactical_map_open() or lore_reader.is_open()
	# 자동 재장전이 켜져 있으면 장전 버튼은 아무 일도 하지 않는다.
	var manual_reload := not bool(AccessibilitySettings.auto_reload)
	var placed := 0
	var utility_cursor := -side_margin
	for entry in [
		[mobile_context_button, mobile_context_wants_visible and not hud_blocked],
		[mobile_medkit_button, not hud_blocked],
		[mobile_reload_button, manual_reload and not hud_blocked],
		[mobile_flashlight_button, not hud_blocked],
		[
			mobile_map_button,
			not hud_blocked and not extraction_transition_active,
		],
	]:
		var button := entry[0] as Button
		if button == null:
			continue
		button.visible = bool(entry[1])
		if not button.visible:
			continue
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.offset_right = utility_cursor
		button.offset_left = utility_cursor - utility_size
		button.offset_bottom = utility_base_bottom
		button.offset_top = utility_base_bottom - utility_size
		button.custom_minimum_size = Vector2(utility_size, utility_size)
		utility_cursor -= utility_size + utility_gap
		placed += 1
	return utility_size if placed > 0 else 0.0


func _layout_center_top_banners() -> void:
	# 보스 경고·긴장도 변화·잭팟·돌발사건이 각자 자기 offset을 고집하고 있어서
	# 둘 이상 동시에 뜨면 반드시 겹쳤다. 보스 경고는 반응형 배치조차 없었다.
	# 하나의 세로 스택으로 묶고, 우선순위가 높은 것부터 위에서 채운다.
	#
	# 배너가 뜨고 지는 순간마다 다시 불려야 하므로 전체 레이아웃과 분리해 둔다.
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var ui_scale := clampf(
		(minf(viewport_size.x / 780.0, viewport_size.y / 1360.0) if viewport_size.y > viewport_size.x else minf(viewport_size.x / 1360.0, viewport_size.y / 780.0))
		* float(AccessibilitySettings.ui_scale),
		0.62,
		1.5
	)
	var top_margin := maxf(
		UI_SAFE_AREA.get_margins(viewport_size).y,
		clampf(viewport_size.y * 0.018, 8.0, 26.0)
	)
	var hud_blocked := _is_inventory_open() or _is_tactical_map_open() or lore_reader.is_open()
	# 폰 세로 390px 화면에서 배너 셋이면 화면의 절반이 사라진다. 동시에 보이는
	# 수를 제한하고, 넘치면 우선순위가 낮은 쪽을 접는다.
	var banner_limit := 2 if viewport_size.y < 520.0 else 3
	var banner_gap := clampf(8.0 * ui_scale, 6.0, 12.0)
	# 세로 화면(폭 720)에서는 중앙 배너가 좌상단 상태 컬럼과 반드시 겹친다.
	# 세로는 아래 공간이 남아도니, 배너 스택을 상태 패널 높이만큼 내려서 시작한다.
	var portrait := viewport_size.y > viewport_size.x
	var banner_cursor := top_margin + (186.0 if portrait else 0.0)
	var banner_shown := 0
	for entry in [
		[
			boss_alert_panel,
			boss_alert_active and not hud_blocked,
			clampf(viewport_size.x * 0.5, 340.0, 560.0),
			clampf(96.0 * ui_scale, 84.0, 104.0),
		],
		[
			hud.raid_pressure_panel,
			raid_pressure_reveal_time > 0.0 and not hud_blocked,
			clampf(viewport_size.x * 0.42, 300.0, 460.0),
			clampf(74.0 * ui_scale, 64.0, 84.0),
		],
		[
			hud.jackpot_hud,
			hud.jackpot_hud != null and not hud_blocked,
			clampf(viewport_size.x * 0.38, 310.0, 430.0),
			clampf(62.0 * ui_scale, 58.0, 68.0),
		],
		[
			hud.dynamic_incident_hud,
			dynamic_incident_state == "active" and not hud_blocked,
			clampf(viewport_size.x * 0.46, 330.0, 500.0),
			clampf(76.0 * ui_scale, 68.0, 84.0),
		],
	]:
		var banner := entry[0] as Control
		if banner == null:
			continue
		var wants_visible := bool(entry[1]) and banner_shown < banner_limit
		banner.visible = wants_visible
		if not wants_visible:
			continue
		var banner_w := float(entry[2])
		var banner_h := float(entry[3])
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.offset_left = -banner_w * 0.5
		banner.offset_right = banner_w * 0.5
		banner.offset_top = banner_cursor
		banner.offset_bottom = banner_cursor + banner_h
		banner.pivot_offset = Vector2(banner_w * 0.5, banner_h * 0.5)
		banner_cursor += banner_h + banner_gap
		banner_shown += 1


func _apply_hud_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var touch_available := DisplayServer.is_touchscreen_available()
	var safe_margins := UI_SAFE_AREA.get_margins(viewport_size)
	var ui_scale := clampf(
		(minf(viewport_size.x / 780.0, viewport_size.y / 1360.0) if viewport_size.y > viewport_size.x else minf(viewport_size.x / 1360.0, viewport_size.y / 780.0))
		* float(AccessibilitySettings.ui_scale),
		0.62,
		1.5
	)
	var top_margin := maxf(safe_margins.y, clampf(viewport_size.y * 0.018, 8.0, 26.0))
	var bottom_margin := maxf(safe_margins.w, clampf(viewport_size.y * 0.018, 8.0, 26.0))
	var side_margin := maxf(maxf(safe_margins.x, safe_margins.z), clampf(viewport_size.x * 0.02, 10.0, 26.0))
	var safe_left_width := clampf(viewport_size.x * 0.33 * ui_scale, 205.0, 460.0)
	var status_height := clampf(88.0 * ui_scale, 80.0, 108.0)
	var objective_line_count := objective_label.text.count("\n") + 1
	var objective_height := clampf(
		24.0 + float(objective_line_count) * 21.0 * ui_scale,
		72.0,
		148.0
	)
	var hud_blocked := _is_inventory_open() or _is_tactical_map_open() or lore_reader.is_open()

	lore_reader.apply_layout(viewport_size)
	var health_bar := top_left_status_panel.get_node_or_null("Margin/VBox/Health")
	var status_stats := top_left_status_panel.get_node_or_null("Margin/VBox/Stats")
	if health_bar is ProgressBar:
		(health_bar as ProgressBar).custom_minimum_size.x = maxf(182.0, safe_left_width - 56.0)
	if status_stats is Label:
		(status_stats as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	top_left_status_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left_status_panel.offset_left = side_margin
	top_left_status_panel.offset_top = top_margin
	top_left_status_panel.offset_right = side_margin + safe_left_width
	top_left_status_panel.offset_bottom = top_margin + status_height

	# 좌측 열은 아래로 무한정 자랄 수 없다. 조이스틱이 차지할 자리를 미리 빼두고
	# 남는 높이 안에서만 목표 패널을 키운다. 예산을 안 걸었을 때 폰 가로 모드에서
	# 40px까지 겹쳤다. 스틱 크기도 고정 하한 168px 대신 화면 높이에 비례시킨다.
	var touch_stick_size := clampf(minf(viewport_size.x, viewport_size.y) * 0.28, 124.0, 240.0)
	var left_column_limit := viewport_size.y - bottom_margin - 10.0
	if touch_available:
		left_column_limit -= touch_stick_size
	# 좌측 열 순서: 체력 → 피로 → 목표. 커서로 쌓아 서로 밀어낸다.
	var left_column_cursor := (
		top_left_status_panel.offset_bottom + 6.0
		if top_left_status_panel.visible
		else top_margin
	)

	if hud.fatigue_panel:
		# 우상단으로 옮겼더니 이번엔 가방 버튼(top-right +68~106px)과 겹쳤다.
		# 애초에 체력과 피로는 둘 다 "내 상태"라 떨어져 있을 이유가 없다.
		# 좌상단 체력 바로 아래, 얇은 띠로 붙인다.
		var fatigue_w := minf(300.0, maxf(190.0, safe_left_width))
		var fatigue_compact := viewport_size.y < 430.0
		# 라벨("피로도")+퍼센트+바를 항상 보여주므로 높이는 일정하게. 세로 중앙 정렬은
		# 패널 내부(row/box의 SHRINK_CENTER)가 맡는다.
		var fatigue_h := 46.0 if fatigue_compact else 54.0
		hud.fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hud.fatigue_panel.offset_left = side_margin
		hud.fatigue_panel.offset_right = side_margin + fatigue_w
		hud.fatigue_panel.offset_top = left_column_cursor
		hud.fatigue_panel.offset_bottom = left_column_cursor + fatigue_h
		left_column_cursor = hud.fatigue_panel.offset_bottom + 6.0

	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.offset_left = side_margin
	objective_panel.offset_top = left_column_cursor
	objective_panel.offset_right = side_margin + safe_left_width
	objective_panel.offset_bottom = objective_panel.offset_top + minf(
		objective_height,
		maxf(44.0, left_column_limit - objective_panel.offset_top)
	)

	var right_column_top := top_margin
	var top_right_panel := get_node_or_null("HUD/TopRight") as VBoxContainer
	if top_right_panel != null:
		var status_width := clampf(minf(viewport_size.x * 0.28, 360.0), 180.0, 360.0)
		top_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		top_right_panel.offset_left = -side_margin - status_width
		top_right_panel.offset_top = top_margin
		top_right_panel.offset_right = -side_margin
		top_right_panel.offset_bottom = top_margin + 88.0
		if top_right_panel.visible:
			right_column_top = top_right_panel.offset_bottom + 8.0

	if touch_stick:
		touch_stick.visible = touch_available
		if touch_available:
			touch_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			touch_stick.offset_left = side_margin
			touch_stick.offset_top = -touch_stick_size - clampf(6.0 * ui_scale, 6.0, 14.0)
			touch_stick.offset_right = side_margin + touch_stick_size
			touch_stick.offset_bottom = -bottom_margin
			touch_stick.set_size(Vector2(touch_stick_size, touch_stick_size))
			if touch_stick.has_method("queue_redraw"):
				touch_stick.queue_redraw()
			var ring := touch_stick.get_node_or_null("Ring") as ColorRect
			var knob := touch_stick.get_node_or_null("Knob") as ColorRect
			if ring:
				ring.set_anchors_preset(Control.PRESET_FULL_RECT)
				ring.anchor_right = 1.0
				ring.anchor_bottom = 1.0
			if knob:
				var knob_size := maxf(42.0, touch_stick_size * 0.22)
				knob.size = Vector2(knob_size, knob_size)
				var knob_offset := Vector2(touch_stick_size - knob_size, touch_stick_size - knob_size) * 0.5
				knob.offset_left = knob_offset.x
				knob.offset_top = knob_offset.y
				knob.offset_right = knob_offset.x + knob_size
				knob.offset_bottom = knob_offset.y + knob_size

	if hud.pickup_panel:
		hud.pickup_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		var panel_w := clampf(viewport_size.x * 0.52, 300.0, 380.0)
		# 버튼 48 + 진행바 8 + 여백이 들어가야 한다.
		var panel_h := clampf(80.0 * ui_scale, 76.0, 94.0)
		hud.pickup_panel.offset_left = -panel_w * 0.5
		hud.pickup_panel.offset_right = panel_w * 0.5
		hud.pickup_panel.offset_bottom = -maxf(bottom_margin + 118.0, viewport_size.y * 0.18)
		hud.pickup_panel.offset_top = hud.pickup_panel.offset_bottom - panel_h
		var pickup_button := hud.pickup_panel.get_node_or_null("VBoxContainer/Button") as Button
		var pickup_progress_bar := hud.pickup_panel.get_node_or_null("VBoxContainer/ProgressBar") as ProgressBar
		if pickup_button != null:
			pickup_button.custom_minimum_size = Vector2(maxf(250.0, panel_w - 24.0), 48.0)
		if pickup_progress_bar != null:
			pickup_progress_bar.custom_minimum_size = Vector2(maxf(250.0, panel_w - 24.0), 8.0)

	if hud.ammo_prompt_panel:
		hud.ammo_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		var ammo_panel_w := clampf(viewport_size.x * 0.52, 300.0, 380.0)
		var ammo_panel_h := clampf(64.0 * ui_scale, 60.0, 76.0)
		hud.ammo_prompt_panel.offset_left = -ammo_panel_w * 0.5
		hud.ammo_prompt_panel.offset_right = ammo_panel_w * 0.5
		hud.ammo_prompt_panel.offset_bottom = -maxf(bottom_margin + 128.0, viewport_size.y * 0.18)
		hud.ammo_prompt_panel.offset_top = hud.ammo_prompt_panel.offset_bottom - ammo_panel_h

	if hud.field_interaction_panel:
		hud.field_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		var field_panel_w := clampf(viewport_size.x * 0.54, 320.0, 410.0)
		var field_panel_h := clampf(124.0 * ui_scale, 118.0, 134.0)
		hud.field_interaction_panel.offset_left = -field_panel_w * 0.5
		hud.field_interaction_panel.offset_right = field_panel_w * 0.5
		hud.field_interaction_panel.offset_bottom = -maxf(bottom_margin + 154.0, viewport_size.y * 0.24)
		hud.field_interaction_panel.offset_top = hud.field_interaction_panel.offset_bottom - field_panel_h
		if hud.field_interaction_action_card != null:
			hud.field_interaction_action_card.custom_minimum_size = Vector2(0.0, 52.0)
		if hud.field_interaction_progress != null:
			hud.field_interaction_progress.custom_minimum_size = Vector2(0.0, 6.0)

	_layout_center_top_banners()

	# 하한 96px은 짧은 화면에서 버튼 하나가 높이의 25%를 차지했다. 비율을 따르되
	# 손가락이 닿는 최소치(68px)까지만 내려간다.
	var action_button_size := clampf(viewport_size.y * 0.155, 68.0, 128.0)
	var action_base := -side_margin
	var action_gap := clampf(11.0 * ui_scale, 8.0, 15.0)
	var hide_action := hud_blocked
	if hud.fire_button:
		hud.fire_button.visible = touch_available and not hide_action
		hud.fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hud.fire_button.offset_bottom = -bottom_margin
		hud.fire_button.offset_top = -bottom_margin - action_button_size
		hud.fire_button.offset_right = action_base
		hud.fire_button.offset_left = action_base - action_button_size
		hud.fire_button.custom_minimum_size = Vector2(action_button_size, action_button_size)
	if hud.melee_button:
		hud.melee_button.visible = touch_available and not hide_action
		hud.melee_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hud.melee_button.offset_bottom = -bottom_margin
		hud.melee_button.offset_top = -bottom_margin - action_button_size
		hud.melee_button.offset_right = action_base - action_button_size - action_gap
		hud.melee_button.offset_left = action_base - action_button_size * 2.0 - action_gap
		hud.melee_button.custom_minimum_size = Vector2(action_button_size, action_button_size)
	if hud.dash_button:
		hud.dash_button.visible = touch_available and not hide_action
		hud.dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hud.dash_button.offset_bottom = -bottom_margin
		hud.dash_button.offset_top = -bottom_margin - action_button_size
		hud.dash_button.offset_right = action_base - action_button_size * 2.0 - action_gap * 2.0
		hud.dash_button.offset_left = action_base - action_button_size * 3.0 - action_gap * 2.0
		hud.dash_button.custom_minimum_size = Vector2(action_button_size, action_button_size)

	# 유틸리티 줄은 우하단 액션 버튼 바로 위에 오른쪽부터 채운다. 버튼을 추가하거나
	# 빼도 위치가 자동으로 다시 잡히도록 배열을 돌린다. 예전에는 각 버튼이 앞 버튼의
	# offset_left를 직접 참조해서, 하나만 숨겨도 줄 전체가 어긋났다.
	var utility_size := _layout_mobile_utility_row()

	# 장비 패널은 우하단 스택 "실제로 보이는 높이" 위에 얹는다. 예전에는 터치
	# 여부만 보고 고정값을 빼서, 버튼이 숨겨진 상황에서도 빈 자리를 남기거나
	# 반대로 겹쳤다.
	if hud.equipment_panel:
		var right_stack := 0.0
		if hud.fire_button != null and hud.fire_button.visible:
			right_stack += action_button_size + action_gap
		if utility_size > 0.0:
			right_stack += utility_size + clampf(13.0 * ui_scale, 8.0, 16.0)
		# 폰에서는 무기 정보가 화면을 크게 먹을 이유가 없다. 탄약 한 줄과
		# 무기 그림이면 충분하고, 상태줄은 할 말이 있을 때만 나온다.
		# 무기 정보는 그림 + [이름·탄약명 / 잔탄] 2줄이면 끝이다. PC·모바일 모두
		# 낮고 좁게. 예전엔 데스크톱에서 108~190px까지 키워 화면을 크게 먹었다.
		var compact := viewport_size.y < 520.0
		var eq_width := (
			clampf(viewport_size.x * 0.20, 176.0, 224.0)
			if compact
			else clampf(viewport_size.x * 0.15, 208.0, 248.0)
		)
		var eq_height := (
			clampf(viewport_size.y * 0.12, 50.0, 62.0)
			if compact
			else clampf(viewport_size.y * 0.10, 56.0, 68.0)
		)
		hud.equipment_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hud.equipment_panel.offset_right = -side_margin
		hud.equipment_panel.offset_left = -side_margin - eq_width
		hud.equipment_panel.offset_bottom = -bottom_margin - right_stack
		var right_column_room := (
			viewport_size.y - bottom_margin - right_stack - right_column_top - 8.0
		)
		eq_height = minf(eq_height, maxf(58.0, right_column_room))
		hud.equipment_panel.offset_top = hud.equipment_panel.offset_bottom - eq_height
		hud.equipment_panel.visible = not hud_blocked

	if hud.ammo_notice:
		hud.ammo_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		var notice_w := minf(viewport_size.x * 0.62, 500.0)
		var notice_h := 54.0
		hud.ammo_notice.offset_left = -notice_w * 0.5
		hud.ammo_notice.offset_right = notice_w * 0.5
		hud.ammo_notice.offset_bottom = -maxf(266.0, viewport_size.y - (viewport_size.y * 0.68))
		hud.ammo_notice.offset_top = hud.ammo_notice.offset_bottom - notice_h

	game_over_screen.apply_layout(viewport_size)

	if hud.extraction_result_panel:
		var panel_w := clampf(minf(viewport_size.x * 0.94, 920.0), 520.0, 1000.0)
		var panel_h := clampf(minf(viewport_size.y * 0.86, 600.0), 360.0, 620.0)
		hud.extraction_result_panel.set_anchors_preset(Control.PRESET_CENTER)
		hud.extraction_result_panel.offset_left = -panel_w * 0.5
		hud.extraction_result_panel.offset_right = panel_w * 0.5
		hud.extraction_result_panel.offset_top = -panel_h * 0.5
		hud.extraction_result_panel.offset_bottom = panel_h * 0.5


func _build_mobile_utility_buttons(font: Font) -> void:
	var touch_enabled := DisplayServer.is_touchscreen_available()
	mobile_context_button = _make_mobile_utility_button("ContextButton", "줍기", "loot", font, -108.0)
	if not touch_enabled:
		mobile_context_button.button_down.connect(_on_mobile_context_button_down)
		mobile_context_button.button_up.connect(_on_mobile_context_button_up)
	mobile_context_button.visible = false

	mobile_reload_button = _make_mobile_utility_button("ReloadButton", "장전", "reload", font, -198.0)
	if not touch_enabled:
		mobile_reload_button.pressed.connect(weapon_combat._reload_ak47)
	mobile_reload_button.visible = touch_enabled

	mobile_flashlight_button = _make_mobile_utility_button("FlashlightButton", "Flash", "flashlight", font, -288.0)
	mobile_flashlight_button.toggle_mode = true
	if not touch_enabled:
		mobile_flashlight_button.toggled.connect(_on_mobile_flashlight_toggled)
	mobile_flashlight_button.visible = touch_enabled

	mobile_map_button = _make_mobile_utility_button("MapButton", "Map", "map", font, -378.0)
	if not touch_enabled:
		mobile_map_button.pressed.connect(_on_mobile_map_pressed)
	mobile_map_button.visible = touch_enabled

	mobile_medkit_button = _make_mobile_utility_button_left(
		"MedkitButton",
		"MEDI",
		"medkit",
		font
	)
	if not touch_enabled:
		mobile_medkit_button.pressed.connect(_use_quick_medkit)
	# 표시 여부는 _layout_mobile_utility_row()가 단독으로 정한다. 예전에는
	# 여기서 visible=true를 박아, 레이아웃이 소유하지 않는 데스크톱/전환 상황에
	# 버튼이 생성 좌표(화면 하단)에 떠 있었다.
	mobile_medkit_button.visible = false
	_update_medkit_button()


func _make_mobile_utility_button(
	button_name: String,
	label: String,
	icon_name: String,
	font: Font,
	right_offset: float
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = right_offset
	button.offset_top = -194
	button.offset_right = right_offset + 80
	button.offset_bottom = -114
	button.text = label
	button.icon = UI_ICONS.get_icon(icon_name, 32, Color("#dbe8df"))
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 90
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.025, 0.035, 0.034, 0.94), Color("#718a7e"), 38))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.055, 0.08, 0.07, 0.97), Color("#b9d1c4"), 38))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.11, 0.17, 0.13, 0.98), Color("#dff0e5"), 38))
	$HUD.add_child(button)
	return button


func _make_mobile_utility_button_left(
	button_name: String,
	label: String,
	icon_name: String,
	font: Font
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button.offset_left = -226
	button.offset_top = -94
	button.offset_right = -128
	button.offset_bottom = -18
	button.text = label
	button.icon = UI_ICONS.get_icon(icon_name, 34, Color("#dbe8df"))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 34)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 90
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.018, 0.025, 0.025, 0.94), Color("#718a7e"), 7))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.055, 0.08, 0.07, 0.97), Color("#b9d1c4"), 7))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.11, 0.17, 0.13, 0.98), Color("#dff0e5"), 7))
	$HUD.add_child(button)
	return button


func _update_medkit_button() -> void:
	if mobile_medkit_button == null:
		return
	mobile_medkit_button.text = (
		"구급약\nx%d" % GameState.medkits
		if DisplayServer.is_touchscreen_available()
		else "SHIFT\n구급약 x%d" % GameState.medkits
	)
	mobile_medkit_button.disabled = player_health <= 0 or player_health >= GameState.get_max_health() or GameState.medkits <= 0
	if GameState.medkits <= 0:
		mobile_medkit_button.tooltip_text = "보유한 구급약이 없습니다"
	elif player_health >= GameState.get_max_health():
		mobile_medkit_button.tooltip_text = "체력이 이미 가득 찼습니다"
	else:
		mobile_medkit_button.tooltip_text = "구급약 사용 (Shift)"


func _on_mobile_context_button_down() -> void:
	if is_instance_valid(nearby_field_interaction):
		if not str(nearby_field_interaction.get_meta("locked_reason", "")).is_empty():
			return
		var interaction_type := str(nearby_field_interaction.get_meta("interaction_type", ""))
		if interaction_type == "extraction":
			extraction._begin_extraction()
		else:
			hud.field_interaction_touch_held = true
	elif is_instance_valid(nearby_ammo_pickup):
		loot_system._collect_nearby_ammo()
	elif not has_ak and is_instance_valid(ak_pickup):
		pickup_touch_held = true
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(16)


func _on_mobile_context_button_up() -> void:
	hud.field_interaction_touch_held = false
	pickup_touch_held = false


func _on_mobile_flashlight_toggled(enabled: bool) -> void:
	laser_aim_held = enabled
	if laser_aim_held:
		var facing_direction := _get_current_facing_world_direction()
		_lock_aim_direction(weapon_combat._get_mobile_aim_assist_direction(facing_direction))
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(12)


func _on_mobile_map_pressed() -> void:
	_release_mobile_held_actions()
	if mobile_context_button != null:
		mobile_context_button.visible = false
	if _is_inventory_open():
		_toggle_inventory()
	if is_instance_valid(tactical_map):
		tactical_map.call("toggle")
	_apply_hud_layout()


func _refresh_mobile_context_button() -> void:
	if mobile_context_button == null or not DisplayServer.is_touchscreen_available():
		return
	var label := ""
	var icon_name := "loot"
	if is_instance_valid(nearby_field_interaction):
		var interaction_type := str(nearby_field_interaction.get_meta("interaction_type", ""))
		var locked_reason := str(nearby_field_interaction.get_meta("locked_reason", ""))
		label = "잠김" if not locked_reason.is_empty() else INTERACTION_TARGETING.get_action_label(interaction_type)
		icon_name = "raid" if interaction_type == "extraction" else "interact"
		mobile_context_button.disabled = not locked_reason.is_empty()
	elif is_instance_valid(nearby_ammo_pickup):
		label = "줍기"
		mobile_context_button.disabled = false
	elif not has_ak and is_instance_valid(ak_pickup):
		var distance := Vector2(player.position.x, player.position.z).distance_to(Vector2(ak_pickup.position.x, ak_pickup.position.z))
		if distance <= PICKUP_DISTANCE:
			label = "무기 획득"
			icon_name = "weapon"
	# 표시 의도만 기록하고, 실제 visible과 위치는 _layout_mobile_utility_row()가
	# 정한다. 여기서 visible을 직접 켜면 생성 시점 좌표에 그대로 나타난다.
	var wants_visible := not label.is_empty()
	if wants_visible != mobile_context_wants_visible:
		mobile_context_wants_visible = wants_visible
		_layout_mobile_utility_row()
	if not wants_visible:
		mobile_context_button.disabled = false
		return
	mobile_context_button.text = label
	mobile_context_button.icon = UI_ICONS.get_icon(icon_name, 32, Color("#e8d890"))


func _on_inventory_equipment_changed() -> void:
	_update_equipment_ui()
	GameState.save_persistent_state()


func _on_inventory_item_discard_requested(item_type: String, item_id: String, amount: int) -> void:
	if RAID_ITEM_ECONOMY.is_protected(item_type, item_id):
		hud.inventory_ui.call("apply_discard_result", false, "중요 임무 물품은 버릴 수 없습니다.")
		return
	if item_type == "weapon" and has_ak and item_id == equipped_weapon_id:
		hud.inventory_ui.call("apply_discard_result", false, "장착을 해제한 뒤 버릴 수 있습니다.")
		return
	if item_type == "equipment":
		var definition: Dictionary = GameState.get_equipment_definition(item_id)
		var slot := str(definition.get("slot", "body"))
		if str(GameState.get_equipped_equipment(slot)) == item_id:
			hud.inventory_ui.call("apply_discard_result", false, "장착을 해제한 뒤 버릴 수 있습니다.")
			return
	var removed: int = GameState.remove_raid_bag_item(item_type, item_id, amount)
	if removed <= 0:
		hud.inventory_ui.call("apply_discard_result", false, "버릴 수 없는 아이템입니다.")
		return
	loot_system._spawn_discarded_raid_item(item_type, item_id, removed)
	if item_type == "ammo" and item_id == str(GameState.equipped_ammo_id):
		reserve_ammo = GameState.get_ammo_count(item_id)
		GameState.reserve_ammo = reserve_ammo
	hud.inventory_ui.call("apply_discard_result", true, "%s x%d을 바닥에 내려놓았습니다." % [
		loot_system._raid_item_display_name(item_type, item_id),
		removed,
	])
	_update_equipment_ui()
	_update_medkit_button()


func _make_panel_style(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _get_field_interaction_accent(interaction_type: String, is_locked: bool) -> Color:
	if is_locked:
		return Color("#c97871")
	match interaction_type:
		"extraction":
			return Color("#e1c36f")
		"rescue":
			return Color("#71d29b")
		"mission_start", "incident", "jackpot_cargo":
			return Color("#e2a65f")
		"lore", "lore_clue", "jackpot_clue":
			return Color("#8fb5dc")
		"corpse_recovery":
			return Color("#d58a72")
		_:
			return Color("#7fc5a4")


func _get_field_interaction_icon_name(interaction_type: String) -> String:
	match interaction_type:
		"loot_container":
			return "loot"
		"salvage":
			return "parts"
		"rescue":
			return "resident"
		"corpse_recovery", "jackpot_cargo", "incident":
			return "collect"
		"jackpot_power":
			return "repair"
		"extraction":
			return "secure"
		_:
			return "interact"


func _refresh_field_interaction_visual(interaction_type: String, is_locked: bool) -> void:
	var signature: String = "%s:%s" % [interaction_type, str(is_locked)]
	if signature == field_interaction_visual_signature:
		return
	field_interaction_visual_signature = signature
	var accent: Color = _get_field_interaction_accent(interaction_type, is_locked)
	var border_color: Color = accent
	border_color.a = 0.78
	var panel_style: StyleBoxFlat = _make_panel_style(
		Color(0.014, 0.021, 0.022, 0.97),
		border_color,
		7
	)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 9.0
	panel_style.content_margin_bottom = 9.0
	hud.field_interaction_panel.add_theme_stylebox_override("panel", panel_style)

	var card_background: Color = accent
	card_background.a = 0.075 if not is_locked else 0.055
	var card_border: Color = accent
	card_border.a = 0.38
	var card_style: StyleBoxFlat = _make_panel_style(card_background, card_border, 6)
	card_style.content_margin_left = 7.0
	card_style.content_margin_right = 8.0
	card_style.content_margin_top = 5.0
	card_style.content_margin_bottom = 5.0
	hud.field_interaction_action_card.add_theme_stylebox_override("panel", card_style)

	var key_background: Color = accent.darkened(0.72)
	key_background.a = 0.98
	hud.field_interaction_key_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(key_background, accent, 5)
	)
	hud.field_interaction_key_label.text = (
		"!"
		if is_locked
		else ("길게" if DisplayServer.is_touchscreen_available() else "F")
	)
	hud.field_interaction_key_label.add_theme_color_override("font_color", accent.lightened(0.24))
	hud.field_interaction_icon.texture = UI_ICONS.get_icon(
		_get_field_interaction_icon_name(interaction_type),
		28,
		accent.lightened(0.18)
	)
	hud.field_interaction_duration_label.add_theme_color_override("font_color", accent.lightened(0.12))
	hud.field_interaction_progress.add_theme_stylebox_override(
		"fill",
		_make_panel_style(accent, accent.lightened(0.28), 3)
	)

	var hover_background: Color = accent
	hover_background.a = 0.09
	var hover_border: Color = accent
	hover_border.a = 0.52
	hud.field_interaction_button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(hover_background, hover_border, 6)
	)
	var pressed_background: Color = accent
	pressed_background.a = 0.17
	hud.field_interaction_button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(pressed_background, accent, 6)
	)


func _update_pickup(delta: float) -> void:
	if has_ak or not is_instance_valid(ak_pickup):
		return
	ak_pickup.position.y = AK_PICKUP_POSITION.y + sin(Time.get_ticks_msec() * 0.004) * 0.045
	var player_ground := Vector2(player.position.x, player.position.z)
	var pickup_ground := Vector2(ak_pickup.position.x, ak_pickup.position.z)
	var distance := player_ground.distance_to(pickup_ground)
	loot_system._update_loot_highlight(ak_pickup, distance, delta)
	var is_near := distance <= PICKUP_DISTANCE
	hud.pickup_panel.visible = is_near
	var holding := pickup_touch_held or pickup_keyboard_held
	if is_near and holding:
		pickup_hold_time = minf(pickup_hold_time + delta, PICKUP_HOLD_DURATION)
		if pickup_hold_time >= PICKUP_HOLD_DURATION:
			_equip_ak47()
	else:
		pickup_hold_time = 0.0
	hud.pickup_progress.value = pickup_hold_time


func _equip_ak47() -> void:
	equipped_weapon_id = "ak47"
	if equipped_weapon_mods.is_empty():
		equipped_weapon_mods.append("scope_2x")
	GameState.equipped_weapon_mods.assign(equipped_weapon_mods)
	_refresh_weapon_stats()
	has_ak = true
	GameState.has_ak = true
	GameState.equipped_weapon_id = equipped_weapon_id
	pickup_touch_held = false
	hud.pickup_panel.visible = false
	if is_instance_valid(ak_pickup):
		ak_pickup.queue_free()
	weapon_sprite.visible = true
	survivor.sprite_frames = unarmed_sprite_frames
	_play_directional_animation()
	weapon_combat._update_weapon_pose()
	hud.equipment_panel.visible = true
	hud.fire_button.visible = true
	hud.fire_button.tooltip_text = "%s 발사" % str(weapon_stats.get("display_name", "AK-47"))
	_update_equipment_ui()


func _initialize_equipped_weapon() -> void:
	var weapon_available := (
		has_ak
		and not equipped_weapon_id.is_empty()
		and GameState.get_weapon_count(equipped_weapon_id) > 0
	)
	if not weapon_available:
		has_ak = false
		GameState.has_ak = false
		magazine_ammo = 0
		reserve_ammo = 0
		if weapon_sprite:
			weapon_sprite.visible = false
		_update_equipment_ui()
		return
	_refresh_weapon_stats()
	_rebuild_player_weapon_frames()
	if weapon_sprite:
		weapon_sprite.visible = true
	weapon_combat._update_weapon_pose()
	_update_equipment_ui()


func _on_fire_button_down() -> void:
	fire_button_held = true
	weapon_combat._try_fire_ak47()
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(18)


func _on_fire_button_up() -> void:
	fire_button_held = false


func _on_melee_button_pressed() -> void:
	if not stealth._try_stealth_takedown():
		_try_melee_attack()
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(35)


func _on_dash_button_pressed() -> void:
	if loafing:
		_set_loafing(false)
		return
	_try_start_roll()
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(24)


func _get_weapon_range_profile(weapon_id: String) -> Vector3:
	match weapon_id:
		"double_barrel": return Vector3(6.5, 15.0, 0.16)
		"mp5": return Vector3(13.0, 29.0, 0.32)
		"m1911": return Vector3(17.0, 34.0, 0.42)
		"ak47": return Vector3(25.0, 46.0, 0.58)
	return Vector3(16.0, 34.0, 0.35)


func _get_weapon_critical_chance() -> float:
	match equipped_weapon_id:
		"m1911": return 0.16
		"mp5": return 0.08
		"double_barrel": return 0.11
		_: return 0.12


func _weapon_jammed() -> bool:
	if weapon_durability >= 35.0:
		return false
	var jam_chance := clampf((35.0 - weapon_durability) / 500.0, 0.0, 0.07)
	if weapon_random.randf() >= jam_chance:
		return false
	fire_cooldown = 0.7
	if hud.ammo_notice:
		hud.ammo_notice.text = "급탄 불량 · 내구도 %.1f%%" % weapon_durability
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.2
	return true


func _weapon_renders_behind_player() -> bool:
	return facing == "n" or facing == "ne" or facing == "nw"


func _get_weapon_screen_offset() -> Vector2:
	match facing:
		"n": return Vector2(0, -34)
		"ne": return Vector2(24, -30)
		"e": return Vector2(34, -18)
		"se": return Vector2(28, -8)
		"s": return Vector2(0, -6)
		"sw": return Vector2(-28, -8)
		"w": return Vector2(-34, -18)
		"nw": return Vector2(-24, -30)
	return Vector2(0, -18)


func _get_current_facing_world_direction() -> Vector3:
	var screen_direction: Vector2 = DIRECTION_VECTORS[facing]
	return Vector3(
		screen_direction.x + screen_direction.y,
		0,
		-screen_direction.x + screen_direction.y
	).normalized()


func _show_no_ammo_notice() -> void:
	fire_cooldown = maxf(fire_cooldown, 0.35)
	if hud.ammo_notice:
		hud.ammo_notice.text = "탄약 없음\n예비탄을 확보해야 합니다."
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.1
	_update_equipment_ui()


func _weapon_condition_tint() -> Color:
	# 내구도를 별도 라벨 대신 무기 그림의 색으로 알린다. 숫자를 읽지 않아도
	# 총이 점점 붉어지는 것만으로 "곧 수리해야 한다"가 전달된다.
	if not has_ak:
		return Color(1.0, 1.0, 1.0, 1.0)
	var ratio := clampf(GameState.weapon_durability / 100.0, 0.0, 1.0)
	if ratio >= 0.6:
		return Color(1.0, 1.0, 1.0, 1.0)
	if ratio >= 0.3:
		return Color(1.0, 0.86, 0.62, 1.0)
	return Color(1.0, 0.62, 0.55, 1.0)


func _update_equipment_ui() -> void:
	var weapon_name := str(weapon_stats.get("display_name", "AK-47"))
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	var ammo_name := str(WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get("display_name", GameState.equipped_ammo_id))
	var enhancement_level := GameState.get_weapon_enhancement_level(equipped_weapon_id)
	var hud_state := WEAPON_HUD_PRESENTER.build_state(
		has_ak,
		magazine_ammo,
		magazine_size,
		reserve_ammo,
		weapon_reloading,
		reload_timer,
		ammo_name
	)
	# 무기 이름 라벨은 무기 그림과 같은 말을 두 번 하는 자리였다. 그림만 남기고,
	# 강화 수치와 내구도는 그림 위에 색으로 얹는다. 총이 출정 중에 바뀌는 게임이라
	# 그림 자체는 유일한 즉시 식별 수단이므로 지우지 않는다.
	if hud.equipment_weapon_image:
		hud.equipment_weapon_image.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture(equipped_weapon_id)
		hud.equipment_weapon_image.visible = has_ak
		hud.equipment_weapon_image.modulate = _weapon_condition_tint()
		hud.equipment_weapon_image.tooltip_text = (
			"%s +%d" % [weapon_name, enhancement_level] if has_ak else "무기 없음"
		)
	if hud.equipment_name_label:
		hud.equipment_name_label.text = (
			"%s +%d" % [weapon_name, enhancement_level]
			if has_ak and enhancement_level > 0
			else (weapon_name if has_ak else "무기 없음")
		)
		hud.equipment_name_label.visible = has_ak
	if hud.equipment_ammo_type_label:
		hud.equipment_ammo_type_label.text = ammo_name if has_ak else ""
		hud.equipment_ammo_type_label.visible = has_ak
	if hud.equipment_ammo_label:
		hud.equipment_ammo_label.text = str(hud_state.get("ammo_combined_text", "-- / --"))
		var hud_ammo_color: Color = hud_state.get("ammo_color", Color("#f1ce70"))
		hud.equipment_ammo_label.add_theme_color_override(
			"font_color",
			hud_ammo_color
		)
	if hud.equipment_condition_label:
		hud.equipment_condition_label.text = str(hud_state.get("condition_text", ""))
		hud.equipment_condition_label.visible = bool(hud_state.get("condition_notable", true))
	if hud.equipment_reload_bar:
		var reload_duration := maxf(0.01, float(weapon_stats.get("reload_time", 2.15)))
		hud.equipment_reload_bar.value = 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0) if weapon_reloading else 1.0
		hud.equipment_reload_bar.visible = weapon_reloading and has_ak
	if hud.inventory_ui:
		hud.inventory_ui.call(
			"set_weapon_texture",
			WEAPON_VISUAL_CATALOG.get_weapon_texture(equipped_weapon_id)
		)
		hud.inventory_ui.call(
			"update_state",
			has_ak,
			magazine_ammo,
			reserve_ammo,
			weapon_name,
			magazine_size,
			weapon_durability,
			equipped_weapon_mods,
			GameState.canned_food,
			_get_stored_weapon_count(),
			GameState.mod_component_inventory,
			GameState.rescued_workers,
			fatigue
		)
	_refresh_top_status_label()


func _refresh_top_status_label() -> void:
	var top_stats := get_node_or_null("HUD/TopLeft/Margin/VBox/Stats") as Label
	if top_stats == null:
		return
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	top_stats.text = "체력 %d/%d  피로 %d%%  총알 %d/%d +%d  구급약 %d" % [
		player_health,
		GameState.get_max_health(),
		roundi(fatigue),
		magazine_ammo if has_ak else 0,
		magazine_size if has_ak else 0,
		reserve_ammo if has_ak else 0,
		GameState.medkits,
	]
	_update_medkit_button()


func _use_quick_medkit() -> void:
	var maximum_health := GameState.get_max_health()
	if GameState.medkits <= 0 or player_health >= maximum_health:
		_show_action_notice("구급약이 없습니다.")
		return
	GameState.medkits -= 1
	var recovered := mini(38, maximum_health - player_health)
	player_health += recovered
	GameState.player_health = player_health
	var health_bar := get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
	if health_bar:
		health_bar.value = player_health
	_refresh_top_status_label()
	_show_action_notice("구급약 회복 +%d" % recovered)
	_update_medkit_button()
	GameState.save_persistent_state()


func _show_action_notice(message: String) -> void:
	if hud.ammo_notice:
		hud.ammo_notice.text = message
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.25


func _get_stored_weapon_count() -> int:
	var total := 0
	for count in GameState.weapon_inventory.values():
		total += int(count)
	return maxi(0, total - (1 if has_ak else 0))


func _is_inventory_open() -> bool:
	return hud.inventory_ui != null and bool(hud.inventory_ui.call("is_open"))


func _toggle_inventory() -> void:
	if hud.inventory_ui:
		_update_equipment_ui()
		hud.inventory_ui.call("toggle")


func _is_inventory_button_at(screen_position: Vector2) -> bool:
	if hud.inventory_ui == null or _is_inventory_open():
		return false
	var button := hud.inventory_ui.get_node_or_null("InventoryButton") as Button
	return button != null and button.visible and button.get_global_rect().has_point(screen_position)


func _on_inventory_open_state_changed(is_open: bool) -> void:
	if is_open:
		_release_mobile_held_actions()
		mouse_fire_held = false
		laser_aim_held = false
		pickup_keyboard_held = false
		field_interaction_keyboard_held = false
		touch_vector = Vector2.ZERO
		if mobile_flashlight_button:
			mobile_flashlight_button.set_pressed_no_signal(false)
	_refresh_pointer_mode()
	_apply_hud_layout()
	_update_combat_overlay_visibility()


func _update_combat_overlay_visibility() -> void:
	if hud.aim_canvas:
		hud.aim_canvas.visible = (
			not _is_inventory_open()
			and not _is_tactical_map_open()
			and not lore_reader.is_open()
			and not extraction_transition_active
			and not player_death_sequence_active
			and not boss_defeat_sequence_active
		)


func _is_pointer_ui_active() -> bool:
	return (
		_is_inventory_open()
		or _is_tactical_map_open()
		or lore_reader.is_open()
		or extraction_transition_active
		or player_death_sequence_active
	)


func _refresh_pointer_mode() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if _is_pointer_ui_active() else Input.MOUSE_MODE_HIDDEN
	)


func _spawn_smoke_cloud(origin: Vector3, direction: Vector3) -> void:
	if smoke_particle_texture == null:
		smoke_particle_texture = _create_smoke_texture()
	var particles := GPUParticles3D.new()
	particles.position = origin
	particles.amount = 9
	particles.lifetime = 0.72
	particles.one_shot = true
	particles.explosiveness = 0.82
	particles.randomness = 0.7
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.direction = (direction * 0.28 + Vector3.UP * 0.72).normalized()
	process.spread = 38.0
	process.gravity = Vector3(0, 0.42, 0)
	process.initial_velocity_min = 0.18
	process.initial_velocity_max = 0.8
	process.damping_min = 0.4
	process.damping_max = 1.1
	process.scale_min = 0.35
	process.scale_max = 0.85
	var alpha_gradient := Gradient.new()
	alpha_gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	alpha_gradient.colors = PackedColorArray([
		Color(0.32, 0.34, 0.35, 0.0),
		Color(0.32, 0.34, 0.35, 0.52),
		Color(0.18, 0.2, 0.21, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = alpha_gradient
	process.color_ramp = color_ramp
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = smoke_particle_texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.42, 0.42)
	mesh.material = material
	particles.draw_pass_1 = mesh
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _create_smoke_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / 64.0
			var radius := uv.distance_to(Vector2(0.5, 0.5)) * 2.0
			var noise := sin(float(x * 17 + y * 31)) * 0.035
			var alpha := clampf((1.0 - radius + noise) * 2.3, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(image)


func _spawn_particle_burst(
	position: Vector3,
	direction: Vector3,
	color: Color,
	amount: int,
	lifetime: float,
	velocity_min: float,
	velocity_max: float,
	scale_min: float,
	scale_max: float
) -> void:
	var particles := GPUParticles3D.new()
	particles.position = position
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var process := ParticleProcessMaterial.new()
	process.direction = direction.normalized()
	process.spread = 24.0
	process.gravity = Vector3(0, 0.5, 0)
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.color = color
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.16, 0.16)
	mesh.material = material
	particles.draw_pass_1 = mesh
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _build_roll_audio() -> void:
	roll_audio_player = AudioStreamPlayer3D.new()
	roll_audio_player.name = "RollWhoosh"
	roll_audio_player.stream = _create_roll_stream()
	roll_audio_player.unit_size = 4.0
	roll_audio_player.max_distance = 24.0
	roll_audio_player.volume_db = -5.0
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
		_write_wav_sample(data, index, clampf(air * 0.34 + cloth + low, -1.0, 1.0))
	return _make_wav_stream(data, mix_rate)


func _play_roll_sound() -> void:
	if not is_instance_valid(roll_audio_player):
		return
	roll_audio_player.stop()
	roll_audio_player.pitch_scale = randf_range(0.94, 1.08)
	roll_audio_player.play()


func _build_bgm_audio() -> void:
	# 상태별 배경음은 BgmDirector가 맡는다. 필드는 "불안"에서 시작한다.
	bgm.attach(self)
	bgm.set_state("field")





func _make_wav_stream(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _write_wav_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var encoded := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data[index * 2] = encoded & 0xff
	data[index * 2 + 1] = (encoded >> 8) & 0xff


func _is_first_stage_zone() -> bool:
	return GameState.selected_raid_zone == FIRST_STAGE_ZONE_ID


func _spawn_enemies() -> void:
	var world := $World as ProceduralCityMap
	var enemy_multiplier := float(raid_zone_data.get("enemy_multiplier", 1.0))
	var total_enemies := int(raid_zone_data.get(
		"target_enemy_count",
		maxi(BASE_ENEMY_COUNT, roundi(float(BASE_ENEMY_COUNT) * enemy_multiplier))
	))
	var zone_threat := float(raid_zone_data.get("threat", 0.0))
	if GameState.corpse_recovery_attempt_active:
		total_enemies += 2
		zone_threat = minf(1.0, zone_threat + 0.14)
		call_deferred("_show_field_notice", "회수 작전 · 같은 구역의 경계가 강화됐습니다.")
	var squad_sizes := enemy_director._build_enemy_squad_sizes(total_enemies)
	var spawned_count := 0
	for squad_index in squad_sizes.size():
		var squad_anchor := enemy_director._find_distributed_enemy_position(world, squad_index, squad_sizes.size())
		squad_anchor = enemy_director._ensure_initial_enemy_safe_anchor(world, squad_anchor, squad_index)
		var kinds: Array[String] = []
		for member_index in squad_sizes[squad_index]:
			var enemy_index := spawned_count + member_index
			kinds.append(
				"melee"
				if enemy_index < 2
				else ("grenadier" if enemy_index % 6 == 4 else "pistol")
			)
		enemy_director._spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			maxf(night_intensity, zone_threat)
		)
		spawned_count += squad_sizes[squad_index]
	# Bosses enter only after fatigue reaches the raid threshold. This keeps the
	# opening route readable and makes the arrival alert match the actual spawn.


func _find_squad_member_position(
	world: ProceduralCityMap,
	squad_anchor: Vector3,
	member_index: int,
	member_count: int
) -> Vector3:
	if member_index == 0:
		return squad_anchor
	var base_angle := TAU * float(member_index) / float(maxi(1, member_count))
	var fallback := squad_anchor
	for attempt in 10:
		var angle := base_angle + float(attempt / 2 + 1) * (0.28 if attempt % 2 == 0 else -0.28)
		var distance := 1.45 + float(attempt / 3) * 0.38
		var requested := squad_anchor + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.58,
			[player.get_rid()]
		)
		candidate.y = squad_anchor.y
		fallback = candidate
		if candidate.distance_to(squad_anchor) > 4.2:
			continue
		var overlaps_enemy := false
		for existing_enemy in enemies:
			if is_instance_valid(existing_enemy) and existing_enemy.global_position.distance_to(candidate) < 0.9:
				overlaps_enemy = true
				break
		if not overlaps_enemy:
			return candidate
	return fallback


func _get_random_armor_drop(seed_hint: int = 0) -> Dictionary:
	var equipment_slot_roll := posmod(seed_hint + spawn_random.randi(), 3)
	var high_grade := spawn_random.randf() < 0.22 + night_intensity * 0.18
	var equipment_id := ""
	match equipment_slot_roll:
		0:
			equipment_id = "riot_vest" if high_grade else "scav_vest"
		1:
			equipment_id = "tactical_helmet" if high_grade else "patched_helmet"
		_:
			equipment_id = "tactical_boots" if high_grade else "patched_sneakers"
	var definition := GameState.get_equipment_definition(equipment_id)
	return {
		"amount": 1,
		"equipment_id": equipment_id,
		"display_name": str(definition.get("display_name", "Armor")),
	}


func _update_enemy_pressure(delta: float) -> void:
	# 존 위협도가 바닥이다. 예전엔 night_intensity만 봐서, 낮 출정에서는 남산도
	# 종로도 전부 threat 0으로 굴렀다 — 공격력·명중률·연사 곡선이 전부 죽어
	# 존 난이도가 HP 말고는 작동하지 않았다. 밤은 그 위에 얹히는 가산 요소다.
	var zone_threat := float(raid_zone_data.get("threat", 0.0))
	var effective_threat := clampf(maxf(night_intensity, zone_threat), 0.0, 1.0)
	for index in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index]
		if not is_instance_valid(enemy):
			enemies.remove_at(index)
			continue
		enemy.call("set_threat_level", effective_threat)
		enemy.call("set_environment_visibility", night_intensity)
	var stage_profile: Dictionary = LOOT_ECONOMY.get_stage_profile(
		LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	)
	if GameState.raid_kills >= int(stage_profile.get("raid_kill_cap", 40)):
		reinforcement_timer = 6.0
		return
	enemy_director._update_reinforcement_call(delta, effective_threat)
	var target_count := (
		BASE_ENEMY_COUNT
		+ roundi(night_intensity * float(MAX_NIGHT_ENEMY_COUNT - BASE_ENEMY_COUNT))
	)
	if enemies.size() >= target_count:
		reinforcement_timer = minf(reinforcement_timer, 3.0)
		return

	reinforcement_timer -= delta
	if reinforcement_timer > 0.0:
		return
	var squad_anchor := enemy_director._find_reinforcement_position()
	if squad_anchor != Vector3.INF:
		var missing_count := target_count - enemies.size()
		var squad_size := (
			2
			if missing_count <= 2 or spawn_random.randf() < ENEMY_PAIR_SQUAD_CHANCE
			else 3
		)
		var kinds: Array[String] = []
		for member_index in squad_size:
			var roll := spawn_random.randf()
			kinds.append(
				"grenadier"
					if roll < 0.14
					else ("pistol" if roll < lerpf(0.76, 0.9, effective_threat) else "melee")
			)
		enemy_director._spawn_enemy_squad(
			$World as ProceduralCityMap,
			squad_anchor,
			kinds,
			effective_threat
		)
	reinforcement_timer = lerpf(15.0, 2.8, effective_threat)


func _build_day_night_tint() -> void:
	var tint_layer := CanvasLayer.new()
	tint_layer.name = "DayNightTint"
	tint_layer.layer = 1
	add_child(tint_layer)
	day_night_tint = ColorRect.new()
	day_night_tint.name = "NightColor"
	day_night_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	day_night_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_layer.add_child(day_night_tint)


func _update_day_night(delta: float) -> void:
	world_time_hours = fposmod(world_time_hours + delta / SECONDS_PER_GAME_HOUR, 24.0)
	GameState.world_time_hours = world_time_hours
	night_intensity = _get_night_intensity(world_time_hours)
	var next_phase := _get_day_phase(world_time_hours)
	if next_phase != current_day_phase:
		current_day_phase = next_phase
	_update_day_night_visuals()
	_update_time_hud()
	if perception_system:
		perception_system.call("set_vision_range", lerpf(13.5, 5.0, night_intensity))


func _get_night_intensity(hour: float) -> float:
	if hour >= 19.0:
		return clampf(inverse_lerp(17.0, 24.0, hour), 0.0, 1.0)
	if hour < 4.5:
		return 1.0
	if hour < 7.0:
		return 1.0 - inverse_lerp(4.5, 7.0, hour)
	if hour >= 17.0:
		return inverse_lerp(17.0, 24.0, hour)
	return 0.0


func _get_day_phase(hour: float) -> String:
	if hour >= DEEP_NIGHT_HOUR or hour < 4.5:
		return "심야"
	if hour >= NIGHT_START_HOUR or hour < 6.0:
		return "밤"
	if hour >= 17.0:
		return "황혼"
	if hour < 7.0:
		return "새벽"
	return "낮"


func _update_day_night_visuals() -> void:
	var minimum_brightness := clampf(float(AccessibilitySettings.minimum_brightness), 0.0, 0.5)
	if day_night_tint:
		var tint_alpha := lerpf(0.0, 0.48, night_intensity) * (1.0 - minimum_brightness * 0.7)
		var tint_color := Color(0.025, 0.055, 0.12, tint_alpha)
		day_night_tint.color = tint_color
	if sun:
		sun.light_energy = lerpf(1.15, 0.18, night_intensity)
		sun.light_color = Color(0.72, 0.77, 0.8).lerp(Color(0.25, 0.34, 0.52), night_intensity)
	if world_environment and world_environment.environment:
		var environment := world_environment.environment
		environment.ambient_light_energy = maxf(
			lerpf(0.72, 0.2, night_intensity),
			minimum_brightness
		)
		environment.ambient_light_color = Color(0.54, 0.59, 0.62).lerp(Color(0.12, 0.18, 0.28), night_intensity)
		environment.fog_light_energy = lerpf(0.65, 0.18, night_intensity)
		environment.fog_light_color = Color(0.32, 0.36, 0.38).lerp(Color(0.08, 0.12, 0.2), night_intensity)
		environment.fog_density = lerpf(0.008, 0.014, night_intensity)


func _update_time_hud() -> void:
	var hour := floori(world_time_hours)
	var minute := floori((world_time_hours - float(hour)) * 60.0)
	var danger_tier := 1 + floori(night_intensity * 3.99)
	time_label.text = "%s  %02d:%02d  ·  위험 %d" % [current_day_phase, hour, minute, danger_tier]
	var phase_color := Color("#d6c891").lerp(Color("#ff6f5c"), night_intensity)
	time_label.add_theme_color_override("font_color", phase_color)


func _install_perception_system() -> void:
	perception_system = PERCEPTION_SYSTEM_SCRIPT.new() as CanvasLayer
	perception_system.call("setup", player, camera)
	add_child(perception_system)


func take_damage(amount: int) -> void:
	bgm.notify_combat()
	if (
		amount <= 0
		or player_health <= 0
		or extraction_transition_active
		or player_death_sequence_active
		or boss_defeat_sequence_active
	):
		return
	# 구르는 동안 + 착지 유예까지 무적. 오프닝 튜토리얼이 "구르는 동안은 총알이
	# 몸을 스치지 못한다"고 가르치는데, 정작 필드에서 안 지키면 거짓말이 된다.
	if roll_active or Time.get_ticks_msec() < roll_iframe_until_msec:
		return
	if loafing:
		space_hold_active = false
		space_hold_consumed = true
		_set_loafing(false)
	var applied_damage := maxi(1, roundi(float(amount) * GameState.get_damage_taken_multiplier()))
	_add_fatigue(minf(1.8, float(applied_damage) * FATIGUE_DAMAGE_PER_POINT))
	player_health = maxi(0, player_health - applied_damage)
	GameState.player_health = player_health
	player_hit_flash_time = 0.32
	player_hit_stun_time = maxf(player_hit_stun_time, 0.18)
	var health_bar := get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
	if health_bar:
		health_bar.value = player_health
	_refresh_top_status_label()
	if hud.ammo_notice:
		hud.ammo_notice.text = "피격  -%d   체력 %d/%d" % [applied_damage, player_health, GameState.get_max_health()]
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.1
	if player_health <= 0:
		fire_button_held = false
		_begin_player_death_sequence()
		player.velocity = Vector3.ZERO
		state_label.text = "행동 불능"


func take_hit(amount: int, hit_direction: Vector3) -> void:
	if extraction_transition_active or player_death_sequence_active:
		return
	take_damage(amount)
	hit_direction.y = 0.0
	if player_health > 0 and hit_direction.length_squared() > 0.01:
		recoil_velocity += hit_direction.normalized() * 1.35
		player_hit_stun_time = maxf(player_hit_stun_time, 0.24)
		_show_damage_direction(hit_direction)
		camera_shake_time = 0.22
		camera_shake_strength = minf(0.38, 0.12 + float(amount) * 0.006)
		_trigger_hit_stop(0.045)


func take_hostile_hit(amount: int, hit_direction: Vector3, attacker = null) -> void:
	var multiplier := GameState.get_damage_taken_multiplier()
	last_damage_blocked = maxi(0, amount - maxi(1, roundi(float(amount) * multiplier)))
	last_damage_source_name = "적대 생존자"
	last_damage_weapon_name = "원거리 무기"
	if is_instance_valid(attacker) and attacker.has_method("get_combat_identity"):
		var identity := attacker.call("get_combat_identity") as Dictionary
		last_damage_source_name = str(identity.get("source_name", last_damage_source_name))
		last_damage_weapon_name = str(identity.get("weapon_name", last_damage_weapon_name))
	take_hit(amount, hit_direction)
	if last_damage_blocked > 0 and player_health > 0 and hud.ammo_notice:
		hud.ammo_notice.text = "방어구가 피해 %d을 막았습니다" % last_damage_blocked
		hud.ammo_notice.add_theme_color_override("font_color", Color("#8ed9ff"))
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.0


func _show_damage_direction(hit_direction: Vector3) -> void:
	if hud.damage_direction_indicator == null:
		return
	var source_world := -hit_direction.normalized()
	var screen_direction := Vector2(
		source_world.x - source_world.z,
		source_world.x + source_world.z
	).normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var radius := minf(viewport_size.x, viewport_size.y) * 0.31
	hud.damage_direction_indicator.position = viewport_size * 0.5 + screen_direction * radius - Vector2(20, 20)
	hud.damage_direction_indicator.rotation = screen_direction.angle() + PI * 0.5
	if damage_direction_tween:
		damage_direction_tween.kill()
	hud.damage_direction_indicator.modulate.a = 1.0
	hud.damage_direction_indicator.scale = Vector2.ONE * 1.28
	damage_direction_tween = create_tween()
	damage_direction_tween.set_parallel(true)
	damage_direction_tween.tween_property(hud.damage_direction_indicator, "modulate:a", 0.0, 0.7)
	damage_direction_tween.tween_property(hud.damage_direction_indicator, "scale", Vector2.ONE * 0.82, 0.7)


func _trigger_hit_stop(duration: float) -> void:
	hit_stop_serial += 1
	var serial := hit_stop_serial
	Engine.time_scale = 0.24
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if serial == hit_stop_serial and not player_death_sequence_active:
			Engine.time_scale = 1.0
	)


func _setup_building_overlays() -> void:
	building_canvas = CanvasLayer.new()
	building_canvas.name = "BuildingOverlay"
	building_canvas.layer = 0
	add_child(building_canvas)
	for node in get_tree().get_nodes_in_group("camera_occluder"):
		var building := node as Node3D
		var source := building.get_node_or_null("BuildingSprite") as Sprite3D
		if source == null or source.texture == null:
			continue
		var overlay := Sprite2D.new()
		overlay.name = "%sOverlay" % building.name
		overlay.texture = source.texture
		overlay.centered = true
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		overlay.z_index = OVERLAY_DEPTH_SORT.world_depth(building.global_position)
		building_canvas.add_child(overlay)
		building_overlays[building] = overlay
		source.visible = false
	for node in get_tree().get_nodes_in_group("vehicle_obstacle"):
		var vehicle := node as Node3D
		var source := vehicle.get_node_or_null("VehicleSprite") as Sprite3D
		if source == null or source.texture == null:
			continue
		var overlay := Sprite2D.new()
		overlay.name = "%sOverlay" % vehicle.name
		overlay.texture = source.texture
		overlay.centered = true
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		building_canvas.add_child(overlay)
		vehicle_overlays[vehicle] = overlay
		source.visible = false
	survivor_overlay = Sprite2D.new()
	survivor_overlay.name = "SurvivorOverlay"
	survivor_overlay.centered = true
	survivor_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	building_canvas.add_child(survivor_overlay)
	survivor_outline_overlay = Sprite2D.new()
	survivor_outline_overlay.name = "SurvivorOutlineOverlay"
	survivor_outline_overlay.centered = true
	survivor_outline_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	survivor_outline_overlay.modulate = Color(0.16, 0.82, 0.72, 0.28)
	building_canvas.add_child(survivor_outline_overlay)
	companion_overlay = Sprite2D.new()
	companion_overlay.name = "CompanionOverlay"
	companion_overlay.centered = true
	companion_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	companion_overlay.visible = companion_active
	building_canvas.add_child(companion_overlay)
	weapon_overlay = Sprite2D.new()
	weapon_overlay.name = "WeaponOverlay"
	weapon_overlay.centered = true
	weapon_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	building_canvas.add_child(weapon_overlay)
	melee_bat_overlay = Sprite2D.new()
	melee_bat_overlay.name = "MeleeBatOverlay"
	melee_bat_overlay.texture = BASEBALL_BAT_TEXTURE
	melee_bat_overlay.centered = true
	melee_bat_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	melee_bat_overlay.visible = false
	building_canvas.add_child(melee_bat_overlay)
	survivor.visible = false
	companion_sprite.visible = false
	weapon_sprite.visible = false
	_update_building_overlays()


func _update_building_overlays() -> void:
	if building_canvas == null:
		return
	var viewport_height := get_viewport().get_visible_rect().size.y
	var screen_scale := viewport_height / camera.size
	var player_depth := OVERLAY_DEPTH_SORT.world_depth(player.global_position)
	for index in range(roll_afterimages.size() - 1, -1, -1):
		var ghost := roll_afterimages[index]
		if not is_instance_valid(ghost):
			roll_afterimages.remove_at(index)
			continue
		var ghost_world_position: Vector3 = ghost.get_meta("world_position", player.global_position)
		ghost.position = camera.unproject_position(ghost_world_position)
	for building in building_overlays:
		if not is_instance_valid(building):
			continue
		var source := building.get_node_or_null("BuildingSprite") as Sprite3D
		var overlay := building_overlays[building] as Sprite2D
		if source == null or overlay == null:
			continue
		overlay.position = camera.unproject_position(source.global_position)
		overlay.scale = Vector2.ONE * source.pixel_size * screen_scale
		overlay.offset = source.offset
		var overlay_color := source.modulate
		if building.has_meta("overlay_focus_local"):
			var focus_local: Vector3 = building.get_meta("overlay_focus_local")
			var focus_screen := camera.unproject_position(building.to_global(focus_local))
			var fade_pixels: Vector2 = building.get_meta(
				"overlay_focus_fade_pixels",
				Vector2(32.0, 150.0)
			)
			var focus_alpha := OVERLAY_DEPTH_SORT.focused_overlay_alpha(
				focus_screen,
				get_viewport().get_visible_rect().size,
				fade_pixels.x,
				fade_pixels.y
			)
			overlay_color.a *= focus_alpha
			overlay.visible = focus_alpha > 0.005
		else:
			overlay.visible = true
		overlay.modulate = overlay_color
		overlay.z_index = OVERLAY_DEPTH_SORT.building_depth(
			building.global_position,
			player.global_position,
			bool(building.get_meta("overlay_overlaps_player", false)),
			bool(building.get_meta("overlay_occludes_player", false))
		)
	for vehicle in vehicle_overlays:
		if not is_instance_valid(vehicle):
			continue
		var source := vehicle.get_node_or_null("VehicleSprite") as Sprite3D
		var overlay := vehicle_overlays[vehicle] as Sprite2D
		if source == null or overlay == null:
			continue
		overlay.position = camera.unproject_position(source.global_position)
		overlay.scale = Vector2.ONE * source.pixel_size * screen_scale
		overlay.offset = source.offset
		overlay.flip_h = source.flip_h
		overlay.modulate = source.modulate
		overlay.z_index = OVERLAY_DEPTH_SORT.world_depth(vehicle.global_position)
	var survivor_texture := survivor.sprite_frames.get_frame_texture(survivor.animation, survivor.frame)
	if survivor_texture:
		survivor_overlay.texture = survivor_texture
		survivor_outline_overlay.texture = survivor_texture
	survivor_overlay.position = camera.unproject_position(survivor.global_position)
	survivor_overlay.scale = Vector2.ONE * survivor.pixel_size * screen_scale
	survivor_overlay.flip_h = survivor.flip_h
	survivor_overlay.modulate = survivor.modulate
	survivor_overlay.z_index = player_depth
	survivor_outline_overlay.position = survivor_overlay.position
	survivor_outline_overlay.offset = survivor_overlay.offset
	survivor_outline_overlay.flip_h = survivor_overlay.flip_h
	survivor_outline_overlay.scale = survivor_overlay.scale * 1.055
	survivor_outline_overlay.z_index = player_depth - 1
	survivor_outline_overlay.visible = survivor_overlay.visible
	var outline_alpha := 0.72 if bool(player.get_meta("is_camera_occluded", false)) else 0.28
	survivor_outline_overlay.modulate = Color(0.16, 0.82, 0.72, outline_alpha)
	if companion_active:
		var companion_texture := companion_sprite.sprite_frames.get_frame_texture(
			companion_sprite.animation,
			companion_sprite.frame
		)
		if companion_texture:
			companion_overlay.texture = companion_texture
		companion_overlay.visible = true
		companion_overlay.position = camera.unproject_position(companion_sprite.global_position)
		companion_overlay.scale = Vector2.ONE * companion_sprite.pixel_size * screen_scale
		companion_overlay.offset = companion_sprite.offset
		companion_overlay.flip_h = companion_sprite.flip_h
		companion_overlay.modulate = companion_sprite.modulate
		companion_overlay.z_index = OVERLAY_DEPTH_SORT.world_depth(companion.global_position)
	else:
		companion_overlay.visible = false
	if has_ak and not roll_active and not melee_attack_active and weapon_sprite and weapon_sprite.sprite_frames:
		var weapon_texture := weapon_sprite.sprite_frames.get_frame_texture(weapon_sprite.animation, weapon_sprite.frame)
		if weapon_texture:
			weapon_overlay.texture = weapon_texture
		weapon_overlay.visible = true
		weapon_overlay.position = camera.unproject_position(weapon_sprite.global_position)
		weapon_overlay.scale = Vector2.ONE * weapon_sprite.pixel_size * screen_scale
		weapon_overlay.offset = weapon_sprite.offset
		weapon_overlay.flip_h = weapon_sprite.flip_h
		weapon_overlay.rotation = weapon_sprite.rotation.z
		weapon_overlay.modulate = weapon_sprite.modulate
		weapon_overlay.z_index = player_depth - 1 if _weapon_renders_behind_player() else player_depth + 1
	else:
		weapon_overlay.visible = false


func _update_camera_occluders(delta: float) -> void:
	var camera_direction := Vector2(1, 1).normalized()
	var player_position := Vector2(player.position.x, player.position.z)
	var player_is_occluded := false
	var aimed_building := _get_aimed_camera_occluder()
	for node in get_tree().get_nodes_in_group("camera_occluder"):
		var building := node as Node3D
		var player_offset := Vector2(building.global_position.x, building.global_position.z) - player_position
		var depth := player_offset.dot(camera_direction)
		var lateral := absf(player_offset.cross(camera_direction))
		var lateral_limit := float(building.get_meta("occlusion_lateral_limit", OCCLUSION_LATERAL_LIMIT))
		var depth_limit := float(building.get_meta("occlusion_depth_limit", OCCLUSION_DEPTH_LIMIT))
		var sprite := building.get_node_or_null("BuildingSprite") as Sprite3D
		var overlaps_player := sprite != null and _is_player_inside_sprite_screen_rect(sprite)
		var is_occluding := (
			overlaps_player
			and depth > 0.8
			and depth < depth_limit
			and lateral < lateral_limit
		)
		var touches_facing_sector := _structure_touches_visibility_sector(building)
		var is_aim_target := aimed_building == building
		building.set_meta("overlay_overlaps_player", overlaps_player)
		building.set_meta("overlay_occludes_player", is_occluding)
		building.set_meta("overlay_in_facing_sector", touches_facing_sector)
		building.set_meta("overlay_aim_target", is_aim_target)
		player_is_occluded = player_is_occluded or is_occluding
		if sprite:
			var color := sprite.modulate
			var target_alpha := 1.0
			if is_aim_target:
				target_alpha = AIM_REVEAL_BUILDING_ALPHA
			elif is_occluding or touches_facing_sector:
				target_alpha = STRUCTURE_REVEAL_BUILDING_ALPHA
			color.a = move_toward(color.a, target_alpha, delta * 4.2)
			sprite.modulate = color
	for node in get_tree().get_nodes_in_group("vehicle_obstacle"):
		var vehicle := node as Node3D
		var vehicle_sprite := vehicle.get_node_or_null("VehicleSprite") as Sprite3D
		if vehicle_sprite == null:
			continue
		var touches_facing_sector := _structure_touches_visibility_sector(vehicle)
		vehicle.set_meta("overlay_in_facing_sector", touches_facing_sector)
		var vehicle_color := vehicle_sprite.modulate
		var vehicle_target_alpha := STRUCTURE_REVEAL_VEHICLE_ALPHA if touches_facing_sector else 1.0
		vehicle_color.a = move_toward(vehicle_color.a, vehicle_target_alpha, delta * 4.8)
		vehicle_sprite.modulate = vehicle_color
	var target_player_color := SILHOUETTE_COLOR if player_is_occluded else Color.WHITE
	player.set_meta("is_camera_occluded", player_is_occluded)
	survivor.modulate = survivor.modulate.lerp(target_player_color, 1.0 - exp(-10.0 * delta))
	if weapon_sprite:
		weapon_sprite.modulate = weapon_sprite.modulate.lerp(target_player_color, 1.0 - exp(-10.0 * delta))


func _get_aimed_camera_occluder() -> Node3D:
	if not is_instance_valid(player) or player.get_world_3d() == null:
		return null
	var aim_direction := (
		locked_aim_direction
		if laser_aim_held and locked_aim_direction.length_squared() > 0.01
		else weapon_combat._get_mouse_world_direction() if weapon_combat._uses_mouse_aim() else _get_current_facing_world_direction()
	)
	aim_direction.y = 0.0
	if aim_direction.length_squared() <= 0.01:
		return null
	aim_direction = aim_direction.normalized()
	var ray_start := player.global_position + Vector3(0.0, 0.48, 0.0)
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_start + aim_direction * 48.0,
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	var excluded: Array[RID] = [player.get_rid()]
	for _index in 16:
		query.exclude = excluded
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as Node
		var ancestor := collider
		while ancestor != null:
			if ancestor is Node3D and ancestor.is_in_group("camera_occluder"):
				return ancestor as Node3D
			ancestor = ancestor.get_parent()
		if collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
		else:
			break
	var player_ground := Vector2(player.global_position.x, player.global_position.z)
	var aim_ground := Vector2(aim_direction.x, aim_direction.z).normalized()
	var nearest: Node3D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("camera_occluder"):
		var structure := node as Node3D
		if not is_instance_valid(structure):
			continue
		var offset := Vector2(structure.global_position.x, structure.global_position.z) - player_ground
		var forward_distance := offset.dot(aim_ground)
		if forward_distance < 0.1 or forward_distance > 48.0:
			continue
		var lateral_distance := absf(offset.cross(aim_ground))
		if lateral_distance > _get_structure_footprint_radius(structure):
			continue
		if forward_distance < nearest_distance:
			nearest = structure
			nearest_distance = forward_distance
	return nearest


func _structure_touches_visibility_sector(structure: Node3D) -> bool:
	if not is_instance_valid(structure):
		return false
	var player_ground := Vector2(player.global_position.x, player.global_position.z)
	var structure_ground := Vector2(structure.global_position.x, structure.global_position.z)
	var center_offset := structure_ground - player_ground
	var center_distance := center_offset.length()
	var footprint_radius := _get_structure_footprint_radius(structure)
	if center_distance - footprint_radius > STRUCTURE_REVEAL_RADIUS:
		return false
	if center_distance <= footprint_radius + 0.2:
		return true
	var facing_world := _get_current_facing_world_direction()
	var facing_ground := Vector2(facing_world.x, facing_world.z).normalized()
	if facing_ground.length_squared() <= 0.01:
		return false
	var center_direction := center_offset / center_distance
	var center_angle := acos(clampf(facing_ground.dot(center_direction), -1.0, 1.0))
	var angular_padding := asin(clampf(footprint_radius / center_distance, 0.0, 0.98))
	return center_angle <= deg_to_rad(STRUCTURE_REVEAL_HALF_ANGLE_DEG) + angular_padding


func _get_structure_footprint_radius(structure: Node3D) -> float:
	if structure.has_meta("collision_world_size"):
		var collision_world_size: Variant = structure.get_meta("collision_world_size")
		if collision_world_size is Vector3:
			var vehicle_size: Vector3 = collision_world_size
			return Vector2(vehicle_size.x, vehicle_size.z).length() * 0.5
	for child in structure.get_children():
		var collision := child as CollisionShape3D
		if collision == null or not (collision.shape is BoxShape3D):
			continue
		var box_size := (collision.shape as BoxShape3D).size
		return Vector2(box_size.x, box_size.z).length() * 0.5
	return float(structure.get_meta("occlusion_lateral_limit")) if structure.has_meta("occlusion_lateral_limit") else 1.6


func _is_player_inside_sprite_screen_rect(sprite: Sprite3D) -> bool:
	if sprite.texture == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return false
	var viewport_height := get_viewport().get_visible_rect().size.y
	var screen_scale := viewport_height / camera.size
	var sprite_size := Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.pixel_size * screen_scale
	var sprite_center := camera.unproject_position(sprite.global_position)
	var sprite_rect := Rect2(sprite_center - sprite_size * 0.5, sprite_size)
	var player_screen_position := camera.unproject_position(survivor.global_position)
	if not sprite_rect.has_point(player_screen_position):
		return false
	var mask_key := sprite.texture.resource_path
	var mask: Image = occlusion_masks.get(mask_key)
	if mask == null:
		mask = sprite.texture.get_image()
		occlusion_masks[mask_key] = mask
	var uv := (player_screen_position - sprite_rect.position) / sprite_rect.size
	var pixel := Vector2i(
		clampi(floori(uv.x * mask.get_width()), 0, mask.get_width() - 1),
		clampi(floori(uv.y * mask.get_height()), 0, mask.get_height() - 1)
	)
	return mask.get_pixelv(pixel).a > 0.1


func _safe_map_position(requested_position: Vector3) -> Vector3:
	var world := get_node_or_null("World") as ProceduralCityMap
	if world == null:
		return requested_position
	return world.find_nearest_open_position(requested_position)


func _scale_map_position(position: Vector3) -> Vector3:
	return Vector3(position.x * MAP_CONTENT_SCALE, position.y, position.z * MAP_CONTENT_SCALE)


func _setup_raid_opportunities(world: ProceduralCityMap) -> void:
	raid_elapsed_seconds = 0.0
	raid_pressure_level = 0
	raid_pressure_points = 0.0
	raid_seconds_since_noise = 99.0
	raid_event_last_fired.clear()
	extraction.reset_banked_level_watch()
	raid_event_cooldown = 40.0
	raid_curfew_active = false
	raid_sealed_extraction_index = -1
	raid_event_random.seed = GameState.map_seed + GameState.raid_serial * 7919
	if GameState.corpse_recovery_attempt_active:
		# 회수 판은 시작부터 도시가 깨어 있다. 내 물건이 있는 자리를
		# 다른 것들도 알고 있다.
		raid_pressure_points = float(RAID_EVENT_DIRECTOR.LEVEL_THRESHOLDS[1]) * 0.75
	raid_reward_multiplier = RAID_PRESSURE_REWARD_MULTIPLIERS[0]
	dynamic_incident_state = "idle"
	dynamic_incident_winning_faction = ""
	dynamic_incident_timer = 0.0
	hud.build_raid_opportunity_hud()
	# 시작 지점 옆 온보딩 루팅 무더기는 제거했다. 출정 직후 발밑에 아이템이
	# 깔려 있으면 "찾아서 줍는" 파밍의 첫인상이 죽는다. 가방 압박 학습은
	# 일반 루팅 과정에서 자연히 온다.
	incidents._spawn_high_value_hotspots(world)
	jackpot._setup_jackpot_event(world)
	_refresh_raid_pressure_hud()


func _update_raid_opportunities(delta: float) -> void:
	if (
		extraction_transition_active
		or player_death_sequence_active
		or _is_inventory_open()
		or _is_tactical_map_open()
		or lore_reader.is_open()
	):
		return
	raid_elapsed_seconds += delta
	raid_seconds_since_noise += delta
	bgm.tick(delta)
	# 시간은 가장 약한 입력이다. 소란을 피우면 훨씬 빨리 오른다.
	raid_pressure_points += RAID_EVENT_DIRECTOR.PRESSURE_PER_SECOND * delta
	if not raid_curfew_active and RAID_EVENT_DIRECTOR.is_stealth_decay_allowed(raid_seconds_since_noise):
		# 감쇠는 현재 단계의 진입점까지만. 예전엔 감쇠(1.35/s)가 시간 가산(0.62/s)을
		# 이겨서 조용한 플레이는 압박이 0에 고정 — 단계 상승 사건 8종이 영원히
		# 잠겼다. 이제 소란으로 얻은 단계는 유지되고, 그 안에서만 식는다.
		var level_floor := float(RAID_EVENT_DIRECTOR.LEVEL_THRESHOLDS[raid_pressure_level])
		raid_pressure_points = maxf(
			level_floor,
			raid_pressure_points - RAID_EVENT_DIRECTOR.PRESSURE_DECAY_PER_SECOND * delta
		)
	var next_pressure_level: int = RAID_EVENT_DIRECTOR.resolve_level(raid_pressure_points)
	if next_pressure_level != raid_pressure_level:
		_apply_raid_pressure_level(next_pressure_level)
	_tick_raid_event_director(delta)
	_refresh_raid_pressure_hud()
	incidents._update_hotspot_discovery()
	incidents._update_dynamic_incident(delta)


func _tick_raid_event_director(delta: float) -> void:
	# 사건 발동의 단일 창구. 예전에는 시스템마다 자기 타이머를 들고 있어서
	# 새 사건을 넣으려면 스케줄러를 또 써야 했다. 이제 여기 하나만 돈다.
	raid_event_cooldown -= delta
	if raid_event_cooldown > 0.0:
		return
	var event_id: String = RAID_EVENT_DIRECTOR.pick_event(
		raid_pressure_level,
		raid_elapsed_seconds,
		raid_event_last_fired,
		raid_event_random
	)
	# 첫 판 보장: 첫 출정은 threat 0.15에 보스도 없어서, 운이 나쁘면 사건이
	# 폭우 한 번으로 끝난다. 첫인상을 운에 맡기지 않는다 — 2분쯤에 수송대
	# 추락을 한 번은 반드시 보여준다.
	if (
		GameState.shelter_return_serial == 0
		and raid_elapsed_seconds >= 110.0
		and not raid_event_last_fired.has("convoy_wreck")
	):
		event_id = "convoy_wreck"
	# 빈 추첨은 전체 간격(95초)을 태우지 않는다. 예전에는 t=40에 후보가 없으면
	# 다음 평가가 t=135라, 첫 출정의 첫 2분이 완전히 비어 있었다. 짧게 재시도해서
	# 후보가 자격을 갖추는 순간(수송대 55초 등) 놓치지 않고 잡는다.
	if event_id.is_empty():
		raid_event_cooldown = 12.0
		return
	raid_event_cooldown = RAID_EVENT_DIRECTOR.get_event_interval(raid_pressure_level)
	raid_event_last_fired[event_id] = raid_elapsed_seconds
	var definition: Dictionary = RAID_EVENT_DIRECTOR.get_event(event_id)
	_show_field_notice(
		"%s\n%s" % [definition.get("title", event_id), definition.get("body", "")]
	)
	# 핸들러는 이름으로 부른다. 새 사건 = 표에 한 줄 + 함수 하나.
	var handler := str(definition.get("handler", ""))
	if not handler.is_empty() and has_method(handler):
		call(handler)


func _event_spawn_hostile_squad() -> void:
	_spawn_raid_event_squad(raid_pressure_level)


func _event_seal_extraction() -> void:
	extraction._seal_one_extraction_route()


func _event_blackout() -> void:
	_apply_raid_blackout()


func _event_supply_drop() -> void:
	_spawn_raid_supply_drop()


func _event_convoy_wreck() -> void:
	# 예전 _update_dynamic_incident의 자체 타이머를 디렉터가 대신한다.
	if dynamic_incident_state == "active":
		return
	dynamic_incident_state = "scheduled"
	incidents._spawn_dynamic_convoy_incident($World as ProceduralCityMap)


func _event_spawn_overwatch() -> void:
	# 트인 길을 위험하게 만든다. 원거리 사수 둘이 자리를 잡는다.
	var world := $World as ProceduralCityMap
	if world == null:
		return
	var post := enemy_director._find_event_position_near_player(world, 22.0, 34.0)
	enemy_director._spawn_enemy_squad(
		world,
		post,
		["pistol", "pistol"],
		1.0,
		player.global_position,
		{"overwatch": true}
	)


func _event_curfew() -> void:
	# 통금: 남은 시간 동안 압박이 식지 않는다. 나가야 한다.
	raid_curfew_active = true
	_add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_ALARM * 0.5)


func _event_downpour() -> void:
	# 폭우: 발소리가 묻히고(압박 감소) 대신 시야가 줄어든다.
	raid_pressure_points = maxf(0.0, raid_pressure_points * 0.82)
	var tween := create_tween()
	tween.tween_method(_set_blackout_strength, 0.0, 0.55, 1.8)


func _event_scavenger_cache() -> void:
	var world := $World as ProceduralCityMap
	if world == null:
		return
	var cache_position := enemy_director._find_event_position_near_player(world, 14.0, 26.0)
	for index in 3:
		var angle := TAU * float(index) / 3.0
		var drop := cache_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.4
		loot_system._create_loot_pickup(
			"mod_component" if index < 2 else "medkit",
			world.find_nearest_open_position(drop),
			{"component_id": "scope_lens", "amount": 1}
		)
	if is_instance_valid(tactical_map) and tactical_map.has_method("register_raid_marker"):
		tactical_map.call(
			"register_raid_marker", "scavenger_cache", cache_position, "loot", "은닉처", true
		)


func _spawn_raid_event_squad(level: int) -> void:
	var world := $World as ProceduralCityMap
	if world == null:
		return
	var spawn_position := enemy_director._find_event_position_near_player(world, 26.0, 38.0)
	var kinds: Array[String] = ["pistol", "melee"] if level < 2 else ["pistol", "pistol", "grenadier"]
	enemy_director._spawn_enemy_squad(
		world,
		spawn_position,
		kinds,
		clampf(0.4 + level * 0.2, 0.0, 1.0),
		player.global_position,
		{"raid_pressure_response": level}
	)


func _apply_raid_blackout() -> void:
	# 시야는 좁아지지만 적의 경계도 함께 떨어진다. 손해만 있는 사건은 재미없다.
	var tween := create_tween()
	tween.tween_method(_set_blackout_strength, 0.0, 1.0, 1.2)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("apply_blackout"):
			enemy.call("apply_blackout")


func _apply_zone_rule_on_start() -> void:
	# 존마다 플레이가 달라야 한다. 숫자만 다른 5개 존이 아니라, 각자 다르게
	# 움직여야 하는 5개 구역으로.
	match active_zone_rule:
		"darkness":
			# 지하: 상시 어둠. 시야가 좁아진다(정전과 같은 셰이더 재사용).
			_set_blackout_strength(0.7)
		"crowd":
			# 무리: 분대가 더 크게 뭉친다. enemy_director가 참조한다.
			pass
		"sniper":
			# 감시: 트인 곳이 위험. field_incidents의 고지 감시를 시작부터 건다.
			var world := $World as ProceduralCityMap
			if world != null:
				incidents._spawn_high_value_hotspots(world)
		"toxic":
			_show_field_notice("오염 지대 진입 · 머무는 동안 체력이 깎인다. 빠르게 움직여라.")
	if not active_zone_rule.is_empty() and active_zone_rule != "darkness":
		var brief := str(raid_zone_data.get("rule_brief", ""))
		if not brief.is_empty():
			_show_field_notice(brief)


func _update_zone_rule(delta: float) -> void:
	if extraction_transition_active or player_death_sequence_active:
		return
	match active_zone_rule:
		"toxic":
			# 오염: 초당 서서히 깎되 죽지는 않는 하한(20%)을 둔다. 압박은 주되
			# 좌절은 주지 않는다. 은신처(건물 안)에서는 멈춘다.
			toxic_zone_tick += delta
			if toxic_zone_tick >= 2.0:
				toxic_zone_tick = 0.0
				var floor_hp := roundi(GameState.get_max_health() * 0.2)
				if player_health > floor_hp:
					player_health = maxi(floor_hp, player_health - 2)
					var health_bar := get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
					if health_bar:
						health_bar.value = player_health


func _set_blackout_strength(strength: float) -> void:
	if not is_instance_valid(world_environment) or world_environment.environment == null:
		return
	var environment := world_environment.environment
	# adjustment_enabled를 켜지 않으면 brightness 값이 무시된다.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = lerpf(1.0, 0.62, strength)


func _spawn_raid_supply_drop() -> void:
	var world := $World as ProceduralCityMap
	if world == null:
		return
	var drop_position := enemy_director._find_event_position_near_player(world, 18.0, 32.0)
	loot_system._create_loot_pickup(
		"progression_item",
		drop_position,
		{"progression_item_id": "rifle_blueprint", "amount": 1, "display_name": "낙하 보급 · 청사진"}
	)
	if is_instance_valid(tactical_map) and tactical_map.has_method("register_raid_marker"):
		tactical_map.call(
			"register_raid_marker",
			"supply_drop",
			drop_position,
			"loot",
			"낙하 보급",
			true
		)


func _add_raid_pressure(amount: float) -> void:
	# 소란을 피우면 도시가 반응한다. 조용해지면 _update_raid_opportunities가
	# 다시 식혀 준다.
	if extraction_transition_active or player_death_sequence_active:
		return
	raid_pressure_points = maxf(0.0, raid_pressure_points + amount)
	if amount > 0.0:
		raid_seconds_since_noise = 0.0


func _apply_raid_pressure_level(new_level: int) -> void:
	var previous_multiplier := raid_reward_multiplier
	raid_pressure_level = clampi(
		new_level,
		0,
		RAID_PRESSURE_REWARD_MULTIPLIERS.size() - 1
	)
	raid_reward_multiplier = float(
		RAID_PRESSURE_REWARD_MULTIPLIERS[raid_pressure_level]
	)
	if not is_equal_approx(previous_multiplier, raid_reward_multiplier):
		raid_pressure_reveal_time = RAID_PRESSURE_REVEAL_SECONDS
		_show_pressure_change_notice(previous_multiplier, raid_reward_multiplier)
	if raid_pressure_level <= 0:
		return
	var world := $World as ProceduralCityMap
	var response_position := enemy_director._find_event_position_near_player(
		world,
		30.0,
		42.0
	)
	var kinds: Array[String] = ["pistol", "melee"]
	if raid_pressure_level >= 2:
		kinds = ["pistol", "pistol", "melee"]
	if raid_pressure_level >= 3:
		kinds = ["pistol", "pistol", "grenadier"]
	enemy_director._spawn_enemy_squad(
		world,
		response_position,
		kinds,
		clampf(0.35 + raid_pressure_level * 0.2, 0.0, 1.0),
		player.global_position,
		{"raid_pressure_response": raid_pressure_level}
	)
	# 단계가 오르면 즉시 한 건 터뜨린다. 나머지는 디렉터가 주기적으로 판단한다.
	raid_event_cooldown = 0.0


func _show_pressure_change_notice(previous: float, current: float) -> void:
	# "지금 얼마인가"가 아니라 "방금 올랐다"를 보여준다. 버틴 대가가 눈에 보여야
	# 다음 판에도 조금 더 버틸 이유가 생긴다.
	if not is_instance_valid(hud.raid_pressure_panel):
		return
	# 배너가 하나 늘었으니 스택을 다시 잡는다. 보스 경고와 동시에 뜰 수 있다.
	_layout_center_top_banners()
	if not hud.raid_pressure_panel.visible:
		# 이미 자리가 꽉 찼다면 조용히 접힌다. 알림이 서로를 덮지는 않는다.
		return
	if is_instance_valid(hud.raid_pressure_detail):
		hud.raid_pressure_detail.text = "전리품 ×%.2f  →  ×%.2f" % [previous, current]
	hud.raid_pressure_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	hud.raid_pressure_panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hud.raid_pressure_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(hud.raid_pressure_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(RAID_PRESSURE_REVEAL_SECONDS - 0.9)
	tween.tween_property(hud.raid_pressure_panel, "modulate:a", 0.0, 0.5)


func _refresh_raid_pressure_hud() -> void:
	if not is_instance_valid(hud.raid_pressure_panel):
		return
	var level_names := ["정찰", "경계", "추적", "봉쇄"]
	var level_colors := [
		Color("#8db8a3"),
		Color("#d0bd6b"),
		Color("#df8d52"),
		Color("#e45d4e"),
	]
	var color: Color = level_colors[raid_pressure_level]
	if is_instance_valid(hud.jackpot_pressure_label):
		hud.jackpot_pressure_label.text = level_names[raid_pressure_level]
		hud.jackpot_pressure_label.add_theme_color_override("font_color", color)
	hud.raid_pressure_title.text = "도시 긴장도 · %s" % level_names[raid_pressure_level]
	# 승급 알림이 떠 있는 동안에는 "×1.15 → ×1.35" 문구를 덮어쓰지 않는다.
	if raid_pressure_reveal_time > 0.0:
		hud.raid_pressure_icon.texture = UI_ICONS.get_icon("alert", 44, color)
		return
	if raid_pressure_level < RAID_PRESSURE_THRESHOLDS.size():
		# 시계가 아니라 게이지를 보여준다. 플레이어가 속도를 통제할 수 있어야 한다.
		var progress: float = RAID_EVENT_DIRECTOR.get_level_progress(raid_pressure_points)
		hud.raid_pressure_detail.text = "다음 대응 %d%% · 전리품 ×%.2f" % [
			roundi(progress * 100.0),
			raid_reward_multiplier,
		]
	else:
		hud.raid_pressure_detail.text = "최고 경계 · 전리품 ×%.2f" % raid_reward_multiplier
	hud.raid_pressure_icon.texture = UI_ICONS.get_icon("alert", 44, color)
	# 게이지는 실제 압박 점수를 보여준다. 예전에는 경과 시간(구식 시스템 잔재)을
	# 넣어서 막대·단계 라벨·퍼센트가 서로 다른 값을 말했고, 압박을 낮추는
	# 사건이 터져도 막대는 꿈쩍하지 않았다.
	hud.raid_pressure_bar.value = minf(
		raid_pressure_points,
		float(RAID_EVENT_DIRECTOR.LEVEL_THRESHOLDS.back())
	)
	hud.raid_pressure_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(color.darkened(0.12), color.lightened(0.12), 7)
	)


func _complete_raid_opportunity(point: Node3D) -> void:
	var interaction_type := str(point.get_meta("interaction_type", ""))
	var spawned_count := 0
	if interaction_type == "dynamic_incident_cache":
		spawned_count = incidents._spawn_dynamic_incident_rewards(point.global_position)
		dynamic_incident_state = "claimed"
		dynamic_incident_site = null
		_layout_center_top_banners()
		if is_instance_valid(tactical_map) and tactical_map.has_method("remove_raid_marker"):
			tactical_map.call("remove_raid_marker", "dynamic_convoy")
		_show_field_notice("추락 수송품 확보 · 전리품 %d개" % spawned_count)
		return
	var hotspot_type := str(point.get_meta("hotspot_type", "military"))
	spawned_count = _spawn_high_value_cache_rewards(
		point.global_position,
		hotspot_type
	)
	raid_hotspots_opened += 1
	var marker_id := str(point.get_meta("map_marker_id", ""))
	if is_instance_valid(tactical_map) and tactical_map.has_method("remove_raid_marker"):
		tactical_map.call("remove_raid_marker", marker_id)
	_show_field_notice(
		"고가치 보급 확보 · 전리품 %d개 · 현재 배율 ×%.2f"
		% [spawned_count, raid_reward_multiplier]
	)


func _spawn_high_value_cache_rewards(origin: Vector3, hotspot_type: String) -> int:
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	var random := RandomNumberGenerator.new()
	random.seed = GameState.map_seed ^ hash(origin) ^ hotspot_type.hash()
	var container_type := "weapon_case"
	var guaranteed_ids: Array[String] = ["magazine_spring", "ammo"]
	match hotspot_type:
		"pharmacy":
			container_type = "clothing_cache"
			guaranteed_ids = ["medkit", "canned_food"]
		"sealed_parts":
			container_type = "toolbox"
			guaranteed_ids = ["scope_lens", "rubber_gasket"]
	var definitions: Array[Dictionary] = LOOT_ECONOMY.roll_container(
		container_type,
		stage_tier,
		"business_corner" if hotspot_type != "pharmacy" else "market_lane",
		random
	)
	var spawned_count := _spawn_opportunity_definitions(
		origin,
		definitions,
		false
	)
	for item_id in guaranteed_ids:
		var definition := _build_guaranteed_opportunity_definition(
			item_id,
			stage_tier,
			random
		)
		if _spawn_opportunity_definition(
			origin,
			definition,
			spawned_count,
			true
		):
			spawned_count += 1
	return spawned_count


func _spawn_opportunity_definitions(
	origin: Vector3,
	definitions: Array[Dictionary],
	guaranteed: bool
) -> int:
	var spawned_count := 0
	for definition in definitions:
		if _spawn_opportunity_definition(
			origin,
			definition,
			spawned_count,
			guaranteed
		):
			spawned_count += 1
	return spawned_count


func _spawn_opportunity_definition(
	origin: Vector3,
	definition: Dictionary,
	index: int,
	guaranteed: bool
) -> bool:
	if definition.is_empty():
		return false
	var adjusted := definition.duplicate(true)
	var data := (adjusted.get("data", {}) as Dictionary).duplicate(true)
	var loot_type := str(adjusted.get("type", ""))
	if loot_type in ["ammo", "canned_food", "mod_component", "medkit", "raw_scrap", "raw_catnip", "valuable"]:
		var amount := maxi(1, int(data.get("amount", 1)))
		data["amount"] = maxi(1, ceili(float(amount) * raid_reward_multiplier))
		data["total_value"] = int(data.get("base_value", 0)) * int(data["amount"])
	adjusted["data"] = data
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	if not LOOT_ECONOMY.try_register_loot(
		GameState,
		adjusted,
		"field",
		stage_tier,
		guaranteed
	):
		return false
	var angle := TAU * float(index) / 5.0 + 0.35
	var radius := 0.78 + float(index % 3) * 0.18
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	data["loot_source"] = "raid_opportunity"
	loot_system._create_loot_pickup(loot_type, origin + offset, data)
	return true


func _build_guaranteed_opportunity_definition(
	item_id: String,
	stage_tier: int,
	random: RandomNumberGenerator
) -> Dictionary:
	if item_id == "ammo":
		var ammo_id := "9mm_fmj"
		if stage_tier >= 2:
			ammo_id = "762_fmj" if random.randf() < 0.55 else "9mm_fmj"
		return {
			"type": "ammo",
			"data": {
				"ammo_id": ammo_id,
				"display_name": "7.62mm 보통탄" if ammo_id == "762_fmj" else "9mm 보통탄",
				"amount": random.randi_range(5, 9),
				"base_value": 6 if ammo_id == "762_fmj" else 3,
				"slot_size": 1,
			},
		}
	if item_id == "medkit":
		return {
			"type": "medkit",
			"data": {
				"display_name": "구급약",
				"amount": 1,
				"base_value": 120,
				"slot_size": 1,
			},
		}
	if item_id == "canned_food":
		return {
			"type": "canned_food",
			"data": {
				"display_name": "통조림",
				"amount": random.randi_range(2, 4),
				"base_value": 35,
				"slot_size": 1,
			},
		}
	var component_names := {
		"rubber_gasket": "소음기용 고무 패킹",
		"scope_lens": "스코프 렌즈",
		"magazine_spring": "탄창 스프링",
	}
	return {
		"type": "mod_component",
		"data": {
			"component_id": item_id,
			"display_name": str(component_names.get(item_id, "정비 부품")),
			"amount": 1,
			"base_value": 110 if item_id == "scope_lens" else 90,
			"slot_size": 1,
		},
	}


func _setup_tactical_map(world: ProceduralCityMap) -> void:
	var map_layer := CanvasLayer.new()
	map_layer.name = "TacticalMapLayer"
	# Tactical map must cover combat HUD (layer 130) while staying below game over (layer 180).
	map_layer.layer = 170
	add_child(map_layer)
	tactical_map = TACTICAL_MAP_SCRIPT.new() as Control
	map_layer.add_child(tactical_map)
	var positions: Array[Vector3] = []
	for site in extraction_sites:
		positions.append(site.global_position)
	var recovery_position := (
		corpse_recovery_point.global_position
		if is_instance_valid(corpse_recovery_point)
		else Vector3.INF
	)
	tactical_map.call("setup", world, player, positions, recovery_position)
	tactical_map.connect(
		"open_state_changed",
		Callable(self, "_on_tactical_map_open_state_changed")
	)
	for discovered_index in discovered_extraction_indices.keys():
		tactical_map.call("discover_extraction", int(discovered_index))
	var extraction_profiles: Array[Dictionary] = []
	for site in extraction_sites:
		extraction_profiles.append({
			"title": str(site.get_meta("route_title", "탈출로")),
			"multiplier": float(site.get_meta("reward_multiplier", 1.0)),
			"color": site.get_meta("route_color", Color("#dcb64b")),
		})
	if tactical_map.has_method("set_extraction_profiles"):
		tactical_map.call("set_extraction_profiles", extraction_profiles)
	for hotspot in raid_hotspots:
		if not is_instance_valid(hotspot):
			continue
		tactical_map.call(
			"register_raid_marker",
			str(hotspot.get_meta("map_marker_id", "")),
			hotspot.global_position,
			"hotspot",
			str(hotspot.get_meta("display_name", "고가치 보급")),
			bool(hotspot.get_meta("map_discovered", false))
		)
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			tactical_map.call("register_boss", enemy)
	_refresh_tactical_map_status()


func _on_tactical_map_open_state_changed(is_open: bool) -> void:
	if is_open:
		_refresh_tactical_map_status()
		_release_mobile_held_actions()
		mouse_fire_held = false
		laser_aim_held = false
	else:
		# 우클릭을 물리적으로 유지한 채 TAB을 눌렀다 떼면 조준이 끊겼다.
		# 닫힐 때 실제 버튼 상태로 되살린다. 발사는 오발 위험이 있어 복원하지 않는다.
		laser_aim_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_refresh_pointer_mode()
	_apply_hud_layout()
	_update_combat_overlay_visibility()
	_refresh_mobile_context_button()


func _refresh_tactical_map_status() -> void:
	if not is_instance_valid(tactical_map) or not tactical_map.has_method("set_raid_status"):
		return
	var bag_value := 0
	for raw_entry in GameState.get_raid_bag_entries():
		var entry := raw_entry as Dictionary
		bag_value += RAID_ITEM_ECONOMY.get_total_value(
			str(entry.get("type", "")),
			str(entry.get("id", "")),
			int(entry.get("count", 0)),
			GameState.raid_special_cargo
		)
	var threat := clampf(float(raid_zone_data.get("threat", 0.0)), 0.0, 1.0)
	var risk_tier := clampi(ceili(maxf(0.01, threat) * 5.0), 1, 5)
	var risk_label := "지역 위험 %d/5" % risk_tier
	tactical_map.call(
		"set_raid_status",
		bag_value,
		GameState.get_raid_bag_used_slots(),
		GameState.get_raid_bag_capacity(),
		risk_label
	)


func _is_tactical_map_open() -> bool:
	return is_instance_valid(tactical_map) and bool(tactical_map.call("is_open"))


func _show_level_reward_choices() -> void:
	hud.extraction_level_choice_title.visible = true
	hud.extraction_level_choice_row.visible = true
	for child in hud.extraction_level_choice_row.get_children():
		child.queue_free()
	var choice_seed := GameState.map_seed + run_kills * 101 + GameState.pending_level_choices * 17
	for choice_value in GameState.get_level_reward_choices(choice_seed):
		var stat_id := str(choice_value)
		var definition := GameState.get_level_reward_definition(stat_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 132)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = "%s\n%s\n현재 %d단계" % [
			str(definition.get("title", stat_id)),
			str(definition.get("description", "")),
			int(GameState.player_stat_levels.get(stat_id, 0)),
		]
		card.icon = UI_ICONS.get_icon(str(definition.get("icon", "upgrade")), 54, Color("#e4cc7c"))
		card.expand_icon = true
		card.add_theme_constant_override("icon_max_width", 54)
		card.add_theme_font_override("font", FONT)
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_color_override("font_color", Color("#e6ece7"))
		card.add_theme_stylebox_override("normal", _make_panel_style(Color("#101716"), Color("#536b61"), 7))
		card.add_theme_stylebox_override("hover", _make_panel_style(Color("#19231f"), Color("#e0c46f"), 7))
		card.add_theme_stylebox_override("pressed", _make_panel_style(Color("#283126"), Color("#f0d77d"), 7))
		card.pressed.connect(_on_level_reward_selected.bind(stat_id))
		hud.extraction_level_choice_row.add_child(card)


func _on_level_reward_selected(stat_id: String) -> void:
	if not GameState.apply_level_reward(stat_id):
		return
	if GameState.pending_level_choices > 0:
		_show_level_reward_choices()
		return
	hud.extraction_level_choice_title.text = "성장 선택 완료"
	hud.extraction_level_choice_row.visible = false
	var wait_tween := create_tween()
	wait_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	wait_tween.tween_interval(0.75)
	wait_tween.tween_callback(extraction._finish_extraction_to_shelter)


func _find_random_field_position(world: ProceduralCityMap, minimum_player_distance: float = 18.0) -> Vector3:
	var map_limit := world.get_map_limit() * 0.82
	var fallback := world.find_nearest_physically_open_position(
		Vector3.ZERO,
		0.62,
		[player.get_rid()]
	)
	var fallback_distance := fallback.distance_to(player.global_position)
	for attempt in 96:
		var requested := Vector3(
			spawn_random.randf_range(-map_limit, map_limit),
			0.08,
			spawn_random.randf_range(-map_limit, map_limit)
		)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = 0.08
		var player_distance := candidate.distance_to(player.global_position)
		if not world.is_position_in_safe_zone(candidate) and player_distance > fallback_distance:
			fallback = candidate
			fallback_distance = player_distance
		if (
			player_distance >= minimum_player_distance
			and not world.is_position_in_safe_zone(candidate)
		):
			return candidate
	return fallback


func _find_stratified_map_position(
	world: ProceduralCityMap,
	index: int,
	total_count: int,
	minimum_player_distance: float,
	minimum_separation: float,
	occupied_positions: Array[Vector3],
	world_y: float
) -> Vector3:
	var item_count := maxi(1, total_count)
	var grid_rows := maxi(1, roundi(sqrt(float(item_count))))
	var base_columns := floori(float(item_count) / float(grid_rows))
	var extra_columns := item_count % grid_rows
	var row_index := 0
	var row_start := 0
	var columns_in_row := maxi(1, base_columns)
	for candidate_row in grid_rows:
		columns_in_row = base_columns + (1 if candidate_row < extra_columns else 0)
		columns_in_row = maxi(1, columns_in_row)
		if index < row_start + columns_in_row:
			row_index = candidate_row
			break
		row_start += columns_in_row
	var column_index := clampi(index - row_start, 0, columns_in_row - 1)
	var map_limit := world.get_map_limit() - 8.0
	var sector_width := map_limit * 2.0 / float(columns_in_row)
	var sector_height := map_limit * 2.0 / float(grid_rows)
	var sector_span := minf(sector_width, sector_height)
	var sector_center := Vector3(
		-map_limit + (float(column_index) + 0.5) * sector_width,
		world_y,
		-map_limit + (float(row_index) + 0.5) * sector_height
	)
	var distant_fallback := Vector3.INF
	var distant_fallback_separation := -1.0
	for attempt in 72:
		var jitter_scale := sector_span * (0.12 + 0.015 * float(attempt % 8))
		var angle := spawn_random.randf_range(0.0, TAU)
		var requested := sector_center + Vector3(cos(angle), 0.0, sin(angle)) * jitter_scale
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = world_y
		if candidate.distance_to(player.global_position) < minimum_player_distance:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var nearest_occupied_distance := INF
		for occupied_position in occupied_positions:
			nearest_occupied_distance = minf(
				nearest_occupied_distance,
				occupied_position.distance_to(candidate)
			)
		if occupied_positions.is_empty():
			nearest_occupied_distance = minimum_separation
		if nearest_occupied_distance > distant_fallback_separation:
			distant_fallback = candidate
			distant_fallback_separation = nearest_occupied_distance
		var separated := true
		for occupied_position in occupied_positions:
			if occupied_position.distance_to(candidate) < minimum_separation:
				separated = false
				break
		if separated:
			return candidate
	if distant_fallback != Vector3.INF:
		return distant_fallback
	return _find_random_field_position(world, minimum_player_distance)


func _find_randomized_mission_position(
	world: ProceduralCityMap,
	minimum_player_distance: float,
	minimum_separation: float,
	occupied_positions: Array[Vector3],
	world_y: float
) -> Vector3:
	var map_limit: float = world.get_map_limit() - 8.0
	var best_candidate: Vector3 = Vector3.INF
	var best_score: float = -INF
	for _attempt in 192:
		var requested := Vector3(
			mission_random.randf_range(-map_limit, map_limit),
			world_y,
			mission_random.randf_range(-map_limit, map_limit)
		)
		var candidate: Vector3 = world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = world_y
		var player_distance: float = candidate.distance_to(player.global_position)
		if player_distance < minimum_player_distance:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var nearest_occupied_distance: float = minimum_separation
		if not occupied_positions.is_empty():
			nearest_occupied_distance = INF
			for occupied_position in occupied_positions:
				nearest_occupied_distance = minf(
					nearest_occupied_distance,
					occupied_position.distance_to(candidate)
				)
		var score: float = (
			minf(nearest_occupied_distance, minimum_separation * 1.8)
			+ minf(player_distance, minimum_player_distance * 2.0) * 0.12
		)
		if score > best_score:
			best_score = score
			best_candidate = candidate
		if nearest_occupied_distance >= minimum_separation:
			return candidate
	if best_candidate != Vector3.INF:
		return best_candidate
	return _find_random_field_position(world, minimum_player_distance)


func _setup_field_objectives(world: ProceduralCityMap) -> void:
	_setup_salvage_points(world)
	_setup_rescue_points(world)


func _setup_basic_raid_missions(world: ProceduralCityMap) -> void:
	var story_stage := GameState.subway_story_stage
	basic_raid_missions = FIELD_MISSION_CATALOG.build_basic_missions(story_stage)
	if story_stage == 1 or story_stage >= 3:
		_refresh_objective_panel()
		return
	var occupied_positions: Array[Vector3] = []
	for interaction in field_interactions:
		if is_instance_valid(interaction):
			occupied_positions.append(interaction.global_position)
	var mission_position := _find_basic_subway_survey_position(world, occupied_positions)
	basic_subway_mission_site = Node3D.new()
	basic_subway_mission_site.name = "BasicMission_SubwaySurvey"
	add_child(basic_subway_mission_site)
	basic_subway_mission_site.global_position = mission_position
	basic_subway_mission_site.set_meta("interaction_type", "basic_mission_subway")
	var subway_mission_id := "subway_return" if story_stage == 2 else "subway"
	var subway_display_name := "지하 보급로 봉쇄" if story_stage == 2 else "지하철역 입구 조사"
	basic_subway_mission_site.set_meta("basic_mission_id", subway_mission_id)
	basic_subway_mission_site.set_meta("display_name", subway_display_name)
	basic_subway_mission_site.set_meta("hold_duration", 1.35)
	basic_subway_mission_site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE + 0.35)
	basic_subway_mission_site.add_to_group("field_interaction")
	field_interactions.append(basic_subway_mission_site)
	_build_basic_subway_marker(basic_subway_mission_site)
	_refresh_objective_panel()


func _find_basic_subway_survey_position(
	world: ProceduralCityMap,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var landmarks := get_tree().get_nodes_in_group("urban_subway_entrance")
	if not landmarks.is_empty():
		var landmark := landmarks[mission_random.randi_range(0, landmarks.size() - 1)] as Node3D
		if landmark:
			var start_angle: float = mission_random.randf_range(0.0, TAU)
			var survey_radius: float = mission_random.randf_range(4.8, 7.2)
			for attempt in 16:
				var angle: float = start_angle + TAU * float(attempt) / 16.0
				var requested := (
					landmark.global_position
					+ Vector3(cos(angle), 0.0, sin(angle)) * survey_radius
				)
				var candidate := world.find_nearest_physically_open_position(
					requested,
					0.62,
					[player.get_rid()]
				)
				candidate.y = 0.08
				var separated := true
				for occupied in occupied_positions:
					if candidate.distance_to(occupied) < 8.0:
						separated = false
						break
				if (
					separated
					and candidate.distance_to(player.global_position) >= 48.0
					and candidate.distance_to(landmark.global_position) <= 9.0
				):
					return candidate
	return _find_randomized_mission_position(
		world,
		52.0,
		36.0,
		occupied_positions,
		0.08
	)


func _build_basic_subway_marker(site: Node3D) -> void:
	var signal_color := Color("#6fc8b4")
	_add_interaction_marker(site, signal_color, 0.9, true)
	var label := Label3D.new()
	label.name = "BasicMissionLabel"
	label.text = "조사 지점"
	label.position = Vector3(0.0, 1.18, 0.0)
	label.font = FONT
	label.font_size = 26
	label.modulate = signal_color.lightened(0.2)
	label.outline_size = 7
	label.outline_modulate = Color(0.01, 0.02, 0.018, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	site.add_child(label)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("register_site", site, "primary", "objective", 7.0)


func _setup_world_lore_clues(world: ProceduralCityMap) -> void:
	lore_clues.clear()
	lore_reader.clues_discovered = 0
	var occupied_positions: Array[Vector3] = []
	for interaction in field_interactions:
		if is_instance_valid(interaction):
			occupied_positions.append(interaction.global_position)
	for index in LORE_CLUE_COUNT:
		var position := _find_stratified_map_position(
			world,
			index,
			LORE_CLUE_COUNT,
			30.0,
			34.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(position)
		var point := Node3D.new()
		point.name = "WorldLore_%02d" % (index + 1)
		add_child(point)
		point.global_position = position
		point.set_meta("interaction_type", "lore_clue")
		point.set_meta("lore_index", index % LORE_ENTRIES.size())
		point.set_meta("read", false)
		point.set_meta(
			"display_name",
			"기록 조사 · %s" % str(
				(LORE_ENTRIES[index % LORE_ENTRIES.size()] as Dictionary).get(
					"title",
					"훼손된 벽보"
				)
			)
		)
		point.set_meta("hold_duration", 0.8)
		point.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE + 0.55)
		point.add_to_group("field_interaction")
		point.add_to_group("world_lore_clue")
		field_interactions.append(point)
		lore_clues.append(point)
		_build_world_lore_board(point)


func _build_world_lore_board(point: Node3D) -> void:
	var poster := Sprite3D.new()
	poster.name = "LoreNoticeBoard"
	poster.texture = LORE_POSTER_TEXTURE
	poster.position = Vector3(0.0, 1.48, 0.0)
	poster.pixel_size = 0.00245
	poster.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	poster.shaded = true
	poster.transparent = false
	poster.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	poster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	poster.render_priority = 8
	point.add_child(poster)

	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color("#232a28")
	base_material.metallic = 0.45
	base_material.roughness = 0.72
	for x_offset in [-1.34, 1.34]:
		var support_mesh := BoxMesh.new()
		support_mesh.size = Vector3(0.1, 1.35, 0.1)
		support_mesh.material = base_material
		var support := MeshInstance3D.new()
		support.position = Vector3(x_offset, 0.58, 0.1)
		support.mesh = support_mesh
		point.add_child(support)

	_add_interaction_marker(point, Color("#c9ad68"), 0.74, false)
	var label := Label3D.new()
	label.name = "LoreMarkerLabel"
	label.text = "기록 단서"
	label.position = Vector3(0.0, 2.92, 0.0)
	label.font = FONT
	label.font_size = 23
	label.modulate = Color("#e4cb8d")
	label.outline_size = 7
	label.outline_modulate = Color(0.01, 0.018, 0.016, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	point.add_child(label)


func _advance_contract_progress(metric: String, amount: int = 1) -> void:
	var result := GameState.advance_contract(metric, amount)
	if not bool(result.get("changed", false)):
		return
	var definition := result.get("definition", {}) as Dictionary
	var title := str(definition.get("title", "현장 계약"))
	var progress := int(result.get("progress", 0))
	var target := maxi(1, int(result.get("target", 1)))
	if bool(result.get("completed", false)):
		_show_field_notice("계약 목표 달성 · %s · 쉘터의 철근에게 보고" % title)
	else:
		_show_field_notice("계약 진행 · %s  %d/%d" % [title, progress, target])
	_refresh_objective_panel()


func _advance_basic_mission(mission_id: String, amount: int = 1) -> void:
	for mission in basic_raid_missions:
		if str(mission.get("id", "")) != mission_id or bool(mission.get("completed", false)):
			continue
		var target_count := maxi(1, int(mission.get("target", 1)))
		mission["progress"] = mini(target_count, int(mission.get("progress", 0)) + maxi(0, amount))
		if int(mission["progress"]) >= target_count:
			mission["completed"] = true
			var mission_title := str(mission.get("title", "기본 목표"))
			var xp_reward := maxi(0, int(mission.get("xp", 0)))
			if not completed_mission_titles.has(mission_title):
				completed_mission_titles.append(mission_title)
				completed_mission_xp += xp_reward
			_show_field_notice("기본 목표 완료 · %s · 경험치 +%d" % [mission_title, xp_reward])
			_handle_basic_mission_chain_completion(mission_id)
		_refresh_objective_panel()
		return


func _handle_basic_mission_chain_completion(mission_id: String) -> void:
	match mission_id:
		"subway":
			GameState.set_subway_story_stage(1)
			var has_boss_objective := false
			for mission in basic_raid_missions:
				if str(mission.get("id", "")) == "subway_boss":
					has_boss_objective = true
					break
			if not has_boss_objective:
				basic_raid_missions.append(
					FIELD_MISSION_CATALOG.get_basic_mission("subway_boss")
				)
			_show_field_notice("연속 임무 해금 · 폐허의 포격수 묘르의 신호를 추적합니다.")
		"subway_boss":
			GameState.set_subway_story_stage(2)
			_show_field_notice("묘르 처치 · 다음 탐사에서 지하 보급로를 봉쇄할 수 있습니다.")
		"subway_return":
			GameState.set_subway_story_stage(3)
			_show_field_notice("연속 임무 완료 · 종로 지하선 생존 통로를 확보했습니다.")


func _get_basic_mission_lines() -> Array[String]:
	return FIELD_MISSION_CATALOG.get_basic_mission_lines(basic_raid_missions)


func _refresh_objective_panel() -> void:
	if objective_panel == null or objective_label == null:
		return
	var lines: Array[String] = []
	if not field_objective_title.is_empty():
		lines.append(field_objective_title)
		var detail_lines := field_objective_detail.split("\n", false)
		if not detail_lines.is_empty():
			lines.append(str(detail_lines[0]))
	else:
		var contract_state := GameState.get_contract_state()
		var contract_status := str(contract_state.get("status", "available"))
		var contract_definition := contract_state.get("definition", {}) as Dictionary
		if contract_status in ["active", "complete"] and not contract_definition.is_empty():
			if contract_status == "complete":
				lines.append("계약 완료 · %s · 쉘터에서 보고" % str(
					contract_definition.get("title", "현장 계약")
				))
			else:
				lines.append("계약 · %s  %d/%d" % [
					str(contract_definition.get("title", "현장 계약")),
					int(contract_state.get("progress", 0)),
					maxi(1, int(contract_state.get("target", 1))),
				])
		var basic_lines := _get_basic_mission_lines()
		if not basic_lines.is_empty():
			lines.append("기본 목표 · %s" % " · ".join(basic_lines.slice(0, 2)))
	objective_label.text = "\n".join(lines)
	objective_label.add_theme_color_override(
		"font_color",
		field_objective_color if not field_objective_title.is_empty() else Color("#d9cfab")
	)
	# 상시 표시하지 않는다. 내용이 있어도 목표 스팟 근처에 왔을 때만 스윽 드러난다.
	# 실제 노출은 _update_objective_reveal이 근접도로 페이드한다.
	objective_panel.visible = not lines.is_empty()
	_apply_hud_layout()


func _update_objective_reveal(delta: float) -> void:
	# 목표는 항상 떠 있지 않는다. 미션 스팟 근처에 진입하면 스윽 드러나고, 멀어지면
	# 사라진다. 진행 중인 현장 미션이 있을 땐 계속 보인다. 상시 목표 UI가 화면을
	# 덮던 문제와 시작 문구 중복을 함께 줄인다.
	if objective_panel == null or not objective_panel.visible:
		return
	var reveal := is_instance_valid(active_field_mission)
	if not reveal:
		for point in field_interactions:
			if not is_instance_valid(point):
				continue
			if str(point.get_meta("interaction_type", "")) in OBJECTIVE_REVEAL_TYPES:
				if player.global_position.distance_to(point.global_position) <= OBJECTIVE_REVEAL_RADIUS:
					reveal = true
					break
	var target_alpha := 1.0 if reveal else 0.0
	objective_reveal_alpha = move_toward(objective_reveal_alpha, target_alpha, delta * 3.5)
	objective_panel.modulate.a = objective_reveal_alpha


func _update_defense_mission(delta: float, distance_to_site: float) -> void:
	var hold_radius := field_missions._get_field_mission_active_radius()
	var inside_hold_area := distance_to_site <= hold_radius
	if inside_hold_area:
		field_mission_elapsed += delta
	var enemy_count := int(active_field_mission.get_meta("enemy_count", 6))
	var duration := float(active_field_mission.get_meta("duration", 18.0))
	var remaining := maxf(0.0, duration - field_mission_elapsed)
	var detail := (
		"구역 방어  %.1f초 · 접근 중인 적 %d명"
		% [remaining, maxi(0, enemy_count - field_mission_spawned_enemies)]
		if inside_hold_area
		else "방어 구역으로 복귀하십시오 · 이탈 %.0fm"
		% distance_to_site
	)
	field_missions._set_field_mission_objective(
		str(active_field_mission.get_meta("title", "구역 방어")),
		detail,
		Color("#efd06f") if inside_hold_area else Color("#ff9b77")
	)
	if field_mission_elapsed >= duration and field_mission_spawned_enemies >= enemy_count:
		field_missions._complete_field_mission()


func _update_eliminate_mission() -> void:
	var target_count := int(active_field_mission.get_meta("target_count", 5))
	field_missions._set_field_mission_objective(
		str(active_field_mission.get_meta("title", "적 소탕")),
		"임무 대상 제거  %d / %d" % [mini(field_mission_kills, target_count), target_count],
		Color("#efd06f")
	)
	if field_mission_kills >= target_count:
		field_missions._complete_field_mission()


func _update_collect_mission() -> void:
	for collectible in active_mission_collectibles.duplicate():
		if not is_instance_valid(collectible):
			active_mission_collectibles.erase(collectible)
			continue
		if player.global_position.distance_to(collectible.global_position) <= 1.35:
			field_mission_collected += 1
			active_mission_collectibles.erase(collectible)
			collectible.queue_free()
			_show_field_notice("임무 물자 회수 · %d개" % field_mission_collected)
	var target_count := int(active_field_mission.get_meta("target_count", 3))
	field_missions._set_field_mission_objective(
		str(active_field_mission.get_meta("title", "물자 회수")),
		"현장 목표물 회수  %d / %d" % [mini(field_mission_collected, target_count), target_count],
		Color("#efd06f")
	)
	if field_mission_collected >= target_count:
		field_missions._complete_field_mission()


func _update_investigation_mission(delta: float) -> void:
	var silence_required := bool(active_field_mission.get_meta("silence_required", false))
	if silence_required and field_mission_noise_breached:
		field_missions._fail_field_mission("총성으로 조사 현장이 노출됐습니다.")
		return
	var detected := field_missions._update_field_mission_detection(delta)
	var detection_grace := float(active_field_mission.get_meta("detection_grace", 1.25))
	if silence_required and field_mission_detection_time >= detection_grace:
		field_missions._fail_field_mission("감시망에 발각되어 기록을 확보하지 못했습니다.")
		return
	var nearest: Node3D
	var nearest_distance := INF
	for clue in active_mission_collectibles:
		if not is_instance_valid(clue):
			continue
		var distance := player.global_position.distance_to(clue.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = clue
	if nearest != field_mission_investigation_target:
		field_mission_investigation_target = nearest
		field_mission_investigation_hold = 0.0
	var investigate_duration := float(active_field_mission.get_meta("investigate_duration", 2.2))
	var can_investigate := is_instance_valid(nearest) and nearest_distance <= 1.6 and not detected
	if can_investigate:
		field_mission_investigation_hold += delta
	else:
		field_mission_investigation_hold = maxf(0.0, field_mission_investigation_hold - delta * 1.5)
	if can_investigate and field_mission_investigation_hold >= investigate_duration:
		field_mission_collected += 1
		active_mission_collectibles.erase(nearest)
		nearest.queue_free()
		field_mission_investigation_target = null
		field_mission_investigation_hold = 0.0
		_show_field_notice("현장 단서 확인 · %d개" % field_mission_collected)
	var target_count := int(active_field_mission.get_meta("target_count", 3))
	var detail := "조사 지점 접근  %d / %d" % [
		mini(field_mission_collected, target_count),
		target_count,
	]
	var color := Color("#e3ca82")
	if detected:
		detail = "적의 시야를 끊어야 조사를 계속할 수 있습니다."
		color = Color("#ff9b77")
	elif is_instance_valid(nearest) and nearest_distance <= 1.6:
		detail = "단서 분석  %.1f / %.1f초 · %d / %d" % [
			field_mission_investigation_hold,
			investigate_duration,
			field_mission_collected,
			target_count,
		]
	field_missions._set_field_mission_objective(
		str(active_field_mission.get_meta("title", "현장 조사")),
		detail,
		color
	)
	if field_mission_collected >= target_count:
		field_missions._complete_field_mission()


func _clear_active_mission_collectibles() -> void:
	for collectible in active_mission_collectibles:
		if is_instance_valid(collectible):
			collectible.queue_free()
	active_mission_collectibles.clear()
	field_mission_investigation_target = null
	field_mission_investigation_hold = 0.0


func _setup_corpse_recovery(world: ProceduralCityMap) -> void:
	if not GameState.corpse_recovery_attempt_active or GameState.pending_corpse_recovery.is_empty():
		return
	var position_data := GameState.pending_corpse_recovery.get("position", []) as Array
	if position_data.size() < 3:
		GameState.clear_pending_corpse_recovery()
		return
	var requested_position := Vector3(
		float(position_data[0]),
		float(position_data[1]),
		float(position_data[2])
	)
	var recovery_position := world.find_nearest_physically_open_position(
		requested_position,
		0.68,
		[player.get_rid()]
	)
	recovery_position.y = 0.08
	corpse_recovery_point = _create_field_interaction(
		"corpse_recovery",
		recovery_position,
		"이전 탐사 장비 회수",
		1.4
	)
	corpse_recovery_point.set_meta("interaction_distance", 3.1)
	_build_corpse_recovery_prop(corpse_recovery_point)
	_add_interaction_marker(corpse_recovery_point, Color("#e4b65b"), 1.15, false)
	_guard_corpse_recovery_site(world, recovery_position)


func _guard_corpse_recovery_site(world: ProceduralCityMap, recovery_position: Vector3) -> void:
	# 내 물건이 떨어진 자리는 남들도 안다. 그냥 주우러 가는 게 아니라
	# 되찾으러 가는 일이 되어야 한다.
	var elapsed := GameState.get_corpse_returns_elapsed()
	var guard_count := clampi(2 + elapsed, 2, 5)
	var kinds: Array[String] = []
	for index in guard_count:
		kinds.append("pistol" if index % 2 == 0 else "melee")
	if elapsed >= 2:
		kinds.append("grenadier")
	var guard_origin := recovery_position + Vector3(
		spawn_random.randf_range(-3.2, 3.2),
		0.0,
		spawn_random.randf_range(-3.2, 3.2)
	)
	enemy_director._spawn_enemy_squad(
		world,
		world.find_nearest_open_position(guard_origin),
		kinds,
		0.0,  # 아직 플레이어를 못 봤다. 잠입으로 빼돌릴 여지를 남긴다.
		recovery_position,
		{"corpse_guard": true}
	)
	var remaining := GameState.get_corpse_returns_remaining()
	var intact := GameState.get_corpse_intact_ratio()
	_show_field_notice(
		"장비가 남아 있는 자리에 약탈자가 붙었다.\n잔존 %d%% · 앞으로 %d회 안에 회수하지 않으면 사라진다."
		% [roundi(intact * 100.0), remaining]
	)


func _build_corpse_recovery_prop(point: Node3D) -> void:
	var pack_material := StandardMaterial3D.new()
	pack_material.albedo_color = Color("#323a36")
	pack_material.metallic = 0.22
	pack_material.roughness = 0.9
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.9, 0.32, 0.68)
	pack_mesh.material = pack_material
	var pack := MeshInstance3D.new()
	pack.name = "LostFieldPack"
	pack.position.y = 0.18
	pack.rotation_degrees.y = 18.0
	pack.mesh = pack_mesh
	point.add_child(pack)

	var strap_material := StandardMaterial3D.new()
	strap_material.albedo_color = Color("#b78a45")
	strap_material.roughness = 0.82
	var strap_mesh := BoxMesh.new()
	strap_mesh.size = Vector3(0.12, 0.36, 0.74)
	strap_mesh.material = strap_material
	var strap := MeshInstance3D.new()
	strap.name = "PackStrap"
	strap.position = Vector3(0.0, 0.19, 0.0)
	strap.rotation_degrees.y = 18.0
	strap.mesh = strap_mesh
	point.add_child(strap)

	var label := Label3D.new()
	label.name = "RecoveryLabel"
	label.text = "분실 장비"
	label.position = Vector3(0.0, 1.05, 0.0)
	label.font = FONT
	label.font_size = 34
	label.modulate = Color("#f2d27a")
	label.outline_size = 8
	label.outline_modulate = Color(0.03, 0.025, 0.015, 0.94)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	point.add_child(label)


func _setup_salvage_points(world: ProceduralCityMap) -> void:
	var vehicles := get_tree().get_nodes_in_group("vehicle_obstacle")
	vehicles.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	var occupied_positions: Array[Vector3] = []
	var vehicle_count := mini(SALVAGE_VEHICLE_POINT_COUNT, vehicles.size())
	for index in vehicle_count:
		var sampled_index := floori(float(index) * float(vehicles.size()) / float(vehicle_count))
		var vehicle := vehicles[posmod(sampled_index + GameState.map_seed, vehicles.size())] as Node3D
		if not is_instance_valid(vehicle):
			continue
		var collision_size: Vector3 = vehicle.get_meta("collision_world_size", Vector3(3.0, 1.0, 1.8))
		var access_offset := (
			Vector3(0, 0, collision_size.z * 0.5 + 0.9)
			if collision_size.x >= collision_size.z
			else Vector3(collision_size.x * 0.5 + 0.9, 0, 0)
		)
		var point := _create_field_interaction(
			"salvage",
			vehicle.global_position + access_offset,
			"파손 차량 부품 분해",
			SALVAGE_HOLD_DURATION
		)
		point.set_meta("source_kind", str(vehicle.get_meta("vehicle_type", "wrecked_vehicle")))
		_add_interaction_marker(point, Color("#67b8bd"), 1.05, false)
		occupied_positions.append(point.global_position)

	for index in SALVAGE_MISC_POINT_COUNT:
		var position := _find_stratified_map_position(
			world,
			index,
			SALVAGE_MISC_POINT_COUNT,
			22.0,
			28.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(position)
		var is_sentry := index % 2 == 0
		var point := _create_field_interaction(
			"salvage",
			position,
			"망가진 센트리 건 분해" if is_sentry else "폐가전 부품 분해",
			SALVAGE_HOLD_DURATION
		)
		point.set_meta("source_kind", "broken_sentry" if is_sentry else "broken_electronics")
		if is_sentry:
			_build_sentry_prop(point)
		else:
			_build_electronics_prop(point)
		_add_interaction_marker(point, Color("#67b8bd"), 0.9, false)


func _setup_rescue_points(world: ProceduralCityMap) -> void:
	var occupied_rescue_positions: Array[Vector3] = []
	for index in RESCUE_POINT_COUNT:
		var rescue_position := _find_rescue_position(
			world,
			occupied_rescue_positions,
			index,
			RESCUE_POINT_COUNT
		)
		occupied_rescue_positions.append(rescue_position)
		var point := _create_field_interaction(
			"rescue",
			rescue_position,
			"갇힌 피난민 고양이 구조",
			RESCUE_HOLD_DURATION
		)
		_build_rescue_locker(point)
		_add_interaction_marker(point, Color("#74d39f"), 0.95, false)
		if is_instance_valid(objective_scent_guidance):
			objective_scent_guidance.call("register_site", point, "rescue", "rescue", 6.5)


func _find_rescue_position(
	world: ProceduralCityMap,
	occupied_positions: Array[Vector3],
	index: int,
	total_count: int
) -> Vector3:
	var distributed_candidate := _find_stratified_map_position(
		world,
		index,
		total_count,
		26.0,
		28.0,
		occupied_positions,
		0.08
	)
	var distributed_clear := true
	for site in extraction_sites:
		if is_instance_valid(site) and distributed_candidate.distance_to(site.global_position) < 14.0:
			distributed_clear = false
			break
	if distributed_clear:
		return distributed_candidate
	var fallback := _find_random_field_position(world, 26.0)
	var safe_fallback := Vector3.INF
	for attempt in 64:
		var candidate := _find_random_field_position(world, 26.0)
		fallback = candidate
		var blocked_by_extraction := false
		for site in extraction_sites:
			if is_instance_valid(site) and candidate.distance_to(site.global_position) < 14.0:
				blocked_by_extraction = true
				break
		if blocked_by_extraction:
			continue
		safe_fallback = candidate
		var separated := true
		for occupied_position in occupied_positions:
			if candidate.distance_to(occupied_position) < 10.0:
				separated = false
				break
		if separated:
			return candidate
	if safe_fallback != Vector3.INF:
		return safe_fallback
	var emergency_position := world.find_nearest_physically_open_position(
		player.global_position + Vector3(18.0, 0.08, 18.0),
		0.72,
		[player.get_rid()]
	)
	for site in extraction_sites:
		if is_instance_valid(site) and emergency_position.distance_to(site.global_position) < 14.0:
			emergency_position = world.find_nearest_physically_open_position(
				-site.global_position * 0.65,
				0.72,
				[player.get_rid()]
			)
			break
	return emergency_position if emergency_position != Vector3.ZERO else fallback


func _create_field_interaction(
	interaction_type: String,
	world_position: Vector3,
	display_name: String,
	hold_duration: float
) -> Node3D:
	var point := Node3D.new()
	point.name = "Field_%s_%d" % [interaction_type, field_interactions.size()]
	add_child(point)
	point.global_position = Vector3(world_position.x, 0.08, world_position.z)
	point.set_meta("interaction_type", interaction_type)
	point.set_meta("display_name", display_name)
	point.set_meta("hold_duration", hold_duration)
	point.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE)
	point.set_meta("completed", false)
	point.add_to_group("field_interaction")
	field_interactions.append(point)
	return point


func _add_interaction_marker(point: Node3D, color: Color, radius: float, strong_light: bool) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.84
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 12
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.name = "InteractionRing"
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	point.add_child(ring)
	if strong_light:
		return
	var light := OmniLight3D.new()
	light.name = "InteractionLight"
	light.position.y = 0.75
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 2.8
	light.shadow_enabled = false
	point.add_child(light)


func _build_electronics_prop(point: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#374246")
	material.metallic = 0.65
	material.roughness = 0.78
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.25, 0.7, 0.85)
	mesh.material = material
	var prop := MeshInstance3D.new()
	prop.name = "BrokenElectronics"
	prop.position.y = 0.36
	prop.rotation.y = deg_to_rad(spawn_random.randf_range(-35.0, 35.0))
	prop.mesh = mesh
	point.add_child(prop)


func _build_sentry_prop(point: Node3D) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "BrokenSentry"
	sprite.texture = BROKEN_SENTRY_TEXTURE
	sprite.position = Vector3(0, 0.7, 0)
	sprite.pixel_size = 0.00215
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.render_priority = 8
	point.add_child(sprite)


func _build_rescue_locker(point: Node3D) -> void:
	var cabinet_material := StandardMaterial3D.new()
	cabinet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cabinet_material.albedo_color = Color(0.20, 0.25, 0.24, 0.42)
	cabinet_material.metallic = 0.55
	cabinet_material.roughness = 0.82
	var cabinet_mesh := BoxMesh.new()
	cabinet_mesh.size = Vector3(1.1, 1.65, 0.72)
	cabinet_mesh.material = cabinet_material
	var cabinet := MeshInstance3D.new()
	cabinet.name = "RescueLocker"
	cabinet.position.y = 0.82
	cabinet.mesh = cabinet_mesh
	point.add_child(cabinet)
	var resident := Sprite3D.new()
	resident.name = "CoweringResident"
	resident.texture = _get_cowering_resident_texture("s")
	resident.position = Vector3(0, 0.72, -0.4)
	resident.pixel_size = 0.0078
	resident.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	resident.shaded = false
	resident.transparent = true
	resident.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	resident.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	resident.no_depth_test = true
	resident.render_priority = 108
	point.add_child(resident)
	point.set_meta("resident_facing", "s")
	var sign := Label3D.new()
	sign.name = "RescueSign"
	sign.text = "SOS"
	sign.position = Vector3(0, 1.24, -0.38)
	sign.font_size = 28
	sign.modulate = Color("#8de0b2")
	sign.outline_size = 6
	sign.no_depth_test = true
	point.add_child(sign)
	if is_instance_valid(scent_system):
		scent_system.call("add_trace", point.global_position, "rescue", 100.0)


func _update_cowering_resident_facing(point: Node3D) -> void:
	var resident := point.get_node_or_null("CoweringResident") as Sprite3D
	if resident == null:
		return
	var world_direction := player.global_position - point.global_position
	world_direction.y = 0.0
	if world_direction.length_squared() <= 0.01:
		return
	var screen_direction := Vector2(
		world_direction.x - world_direction.z,
		world_direction.x + world_direction.z
	).normalized()
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var direction_index := int(round(angle / 45.0)) % SCREEN_DIRECTION_NAMES.size()
	var direction_name: String = SCREEN_DIRECTION_NAMES[direction_index]
	if str(point.get_meta("resident_facing", "")) == direction_name:
		return
	point.set_meta("resident_facing", direction_name)
	resident.texture = _get_cowering_resident_texture(direction_name)


func _get_cowering_resident_texture(direction_name: String) -> Texture2D:
	if cowering_resident_texture_cache.has(direction_name):
		return cowering_resident_texture_cache[direction_name] as Texture2D
	var texture_path := str(COWERING_RESIDENT_TEXTURE_PATHS.get(
		direction_name,
		COWERING_RESIDENT_TEXTURE_PATHS["s"]
	))
	var texture := load(texture_path) as Texture2D
	cowering_resident_texture_cache[direction_name] = texture
	return texture


func _update_field_interactions(delta: float) -> void:
	var previous_interaction := nearby_field_interaction
	var eligible_candidates: Array[Node3D] = []
	var facing_direction := _get_perception_aim_direction()
	facing_direction.y = 0.0
	if facing_direction.length_squared() <= 0.01:
		facing_direction = _get_current_facing_world_direction()
	facing_direction = facing_direction.normalized()
	for point in field_interactions.duplicate():
		if not is_instance_valid(point):
			field_interactions.erase(point)
			continue
		var point_type := str(point.get_meta("interaction_type", ""))
		if point_type == "mission_start":
			if (
				is_instance_valid(active_field_mission)
				or str(point.get_meta("status", "waiting")) != "waiting"
			):
				continue
		if point_type == "rescue":
			_update_cowering_resident_facing(point)
		var ring := point.get_node_or_null("InteractionRing") as MeshInstance3D
		if ring:
			var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.0035 + point.global_position.x)
			ring.scale = Vector3(pulse, pulse, pulse)
		var distance := player.global_position.distance_to(point.global_position)
		var interaction_distance := float(point.get_meta("interaction_distance", FIELD_INTERACTION_DISTANCE))
		if distance > interaction_distance or not _has_field_interaction_line_of_sight(point):
			continue
		eligible_candidates.append(point)
	field_interaction_candidates = INTERACTION_TARGETING.rank_candidates(
		player.global_position,
		facing_direction,
		eligible_candidates,
		FIELD_INTERACTION_FACING_WEIGHT
	)
	var signature_parts: PackedStringArray = []
	for candidate_point in field_interaction_candidates:
		signature_parts.append(str(candidate_point.get_instance_id()))
	var candidate_signature := ":".join(signature_parts)
	if candidate_signature != field_interaction_candidate_signature:
		field_interaction_candidate_signature = candidate_signature
		field_interaction_cycle_index = 0
	nearby_field_interaction = null
	if not field_interaction_candidates.is_empty():
		field_interaction_cycle_index = posmod(
			field_interaction_cycle_index,
			field_interaction_candidates.size()
		)
		nearby_field_interaction = field_interaction_candidates[field_interaction_cycle_index]

	if previous_interaction != nearby_field_interaction:
		field_interaction_hold_time = 0.0
		field_interaction_keyboard_held = false
		hud.field_interaction_touch_held = false

	var can_show := (
		is_instance_valid(nearby_field_interaction)
		and not extraction_transition_active
		and not _is_inventory_open()
		and not _is_tactical_map_open()
		and not lore_reader.is_open()
	)
	if hud.field_interaction_panel:
		hud.field_interaction_panel.visible = can_show
	if not can_show:
		field_interaction_hold_time = 0.0
		if hud.field_interaction_progress:
			hud.field_interaction_progress.value = 0.0
		return
	if hud.ammo_prompt_panel:
		hud.ammo_prompt_panel.visible = false

	var interaction_type := str(nearby_field_interaction.get_meta("interaction_type", ""))
	var display_name := str(nearby_field_interaction.get_meta("display_name", "상호작용"))
	var hold_duration := float(nearby_field_interaction.get_meta("hold_duration", 1.0))
	var locked_reason := str(nearby_field_interaction.get_meta("locked_reason", ""))
	var next_name := "다른 대상"
	if field_interaction_candidates.size() > 1:
		var next_index := (field_interaction_cycle_index + 1) % field_interaction_candidates.size()
		next_name = str(field_interaction_candidates[next_index].get_meta("display_name", next_name))
	var prompt_state := INTERACTION_TARGETING.build_prompt_state(
		interaction_type,
		display_name,
		locked_reason
	)
	var is_locked: bool = not locked_reason.is_empty()
	var action_label: String = INTERACTION_TARGETING.get_action_label(interaction_type)
	_refresh_field_interaction_visual(interaction_type, is_locked)
	# 이 게임의 심장은 첫 추출 비콘 앞에서 멈추는 순간이다. 지금 나갈지 더 갈지를
	# 한 번은 명시적으로 물어봐야 그 다음부터 스스로 계산한다.
	if (
		interaction_type == "extraction"
		and not is_locked
		and not GameState.extraction_choice_lesson_seen
	):
		GameState.extraction_choice_lesson_seen = true
		GameState.save_persistent_state()
		_show_field_notice(
			"탈출로를 찾았다.\n"
			+ "지금 나가면 가방에 든 것이 전부 내 것이 된다. 죽으면 전부 놓고 간다.\n"
			+ "더 버티면 전리품 배율이 오른다. 어느 쪽을 고를지는 네 몫이다."
		)
	if hud.field_interaction_button:
		hud.field_interaction_button.disabled = bool(prompt_state.get("disabled", false))
	# 주 문구 한 줄: "행동 · 대상". 대상 이름과 행동을 따로 띄울 이유가 없다.
	if hud.field_interaction_action_label:
		hud.field_interaction_action_label.text = "%s · %s" % [action_label, display_name]
	# 보조 문구는 정말 할 말이 있을 때만. 평상시 "길게 눌러 진행"은 한 번 배우면
	# 다시 읽지 않는 문장이라 자리를 비운다.
	if hud.field_interaction_action_detail_label:
		var detail := ""
		if is_locked:
			detail = locked_reason
		elif interaction_type == "extraction":
			# 이 게임의 심장 박동: 지금 확보할 가치와 죽으면 잃을 가치를 같은 줄에
			# 나란히 세운다. 배율은 "더 버티면 커진다"는 신호로 뒤에 붙인다.
			var carried_value := _get_carried_loot_value_cached()
			var multiplier := float(nearby_field_interaction.get_meta("reward_multiplier", 1.0))
			if carried_value > 0:
				detail = "지금 확보 %s  ·  죽으면 전부 잃는다  ·  정산 ×%.2f" % [
					GameState.format_compact_number(roundi(float(carried_value) * multiplier)),
					multiplier,
				]
			else:
				detail = "가방이 비었다 · 정산 ×%.2f로 빈손 탈출" % multiplier
		elif field_interaction_candidates.size() > 1:
			detail = "[G] 다음 · %s" % next_name
		hud.field_interaction_action_detail_label.text = detail
		hud.field_interaction_action_detail_label.visible = not detail.is_empty()
	if hud.field_interaction_duration_label:
		if is_locked:
			hud.field_interaction_duration_label.text = "잠김"
		elif interaction_type == "extraction":
			hud.field_interaction_duration_label.text = "즉시"
		elif field_interaction_hold_time > 0.0:
			hud.field_interaction_duration_label.text = "%.1f초" % maxf(
				0.0,
				hold_duration - field_interaction_hold_time
			)
		else:
			hud.field_interaction_duration_label.text = "%.1f초" % hold_duration
	if hud.field_interaction_progress:
		hud.field_interaction_progress.max_value = maxf(hold_duration, 1.0)
		hud.field_interaction_progress.value = field_interaction_hold_time
		hud.field_interaction_progress.visible = bool(prompt_state.get("show_progress", false))
	if not bool(prompt_state.get("can_hold", false)):
		return

	if field_interaction_keyboard_held or hud.field_interaction_touch_held:
		field_interaction_hold_time = minf(field_interaction_hold_time + delta, hold_duration)
	else:
		field_interaction_hold_time = maxf(0.0, field_interaction_hold_time - delta * 2.8)
	if hud.field_interaction_progress:
		hud.field_interaction_progress.value = field_interaction_hold_time
	if field_interaction_hold_time >= hold_duration:
		_complete_field_interaction(nearby_field_interaction)


func _has_field_interaction_line_of_sight(point: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0.0, FIELD_INTERACTION_SIGHT_HEIGHT, 0.0),
		point.global_position + Vector3(0.0, FIELD_INTERACTION_SIGHT_HEIGHT, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _cycle_field_interaction() -> void:
	if field_interaction_candidates.size() <= 1:
		return
	field_interaction_cycle_index = (
		(field_interaction_cycle_index + 1) % field_interaction_candidates.size()
	)
	nearby_field_interaction = field_interaction_candidates[field_interaction_cycle_index]
	field_interaction_hold_time = 0.0
	field_interaction_keyboard_held = false
	hud.field_interaction_touch_held = false


func _register_building_entrance_interactions() -> void:
	for portal_node in get_tree().get_nodes_in_group("building_entrance_portal"):
		var portal := portal_node as Node3D
		if portal != null and portal.has_method("refresh_access_state"):
			portal.call("refresh_access_state")
		if (
			portal != null
			and not bool(portal.get_meta("completed", false))
			and not field_interactions.has(portal)
		):
			field_interactions.append(portal)


func _complete_field_interaction(point: Node3D) -> void:
	if not is_instance_valid(point) or bool(point.get_meta("completed", false)):
		return
	var interaction_type := str(point.get_meta("interaction_type", ""))
	if interaction_type == "building_portal" and point.has_method("enter_building"):
		field_interaction_keyboard_held = false
		hud.field_interaction_touch_held = false
		field_interaction_hold_time = 0.0
		point.call("enter_building", player)
		return
	if interaction_type == "mission_start":
		if (
			not is_instance_valid(active_field_mission)
			and str(point.get_meta("status", "waiting")) == "waiting"
		):
			point.set_meta("completed", true)
			field_interactions.erase(point)
			nearby_field_interaction = null
			field_interaction_hold_time = 0.0
			field_interaction_keyboard_held = false
			hud.field_interaction_touch_held = false
			if hud.field_interaction_panel:
				hud.field_interaction_panel.visible = false
			field_missions._start_field_mission(point)
		return
	if interaction_type == "lore_clue":
		field_interaction_hold_time = 0.0
		field_interaction_keyboard_held = false
		hud.field_interaction_touch_held = false
		lore_reader.show_entry(point)
		return
	if interaction_type == "jackpot_cargo":
		field_interaction_hold_time = 0.0
		field_interaction_keyboard_held = false
		hud.field_interaction_touch_held = false
		jackpot._attempt_take_jackpot_cargo(point)
		return
	if interaction_type == "rescue":
		var occupied_after_escort: int = GameState.rescued_workers + rescued_followers.size()
		if occupied_after_escort >= GameState.get_resident_capacity():
			_show_field_notice("쉘터 수용량 부족 · 시설을 확장해야 구조할 수 있습니다.")
			field_interaction_hold_time = 0.0
			return
	point.set_meta("completed", true)
	match interaction_type:
		"jackpot_clue":
			jackpot._handle_jackpot_clue()
		"jackpot_power":
			jackpot._handle_jackpot_power()
		"loot_container":
			_open_field_loot_container(point)
		"high_value_cache", "dynamic_incident_cache":
			_complete_raid_opportunity(point)
		"salvage":
			_add_fatigue(FATIGUE_SALVAGE_GAIN)
			_spawn_salvage_rewards(point.global_position)
			_advance_contract_progress("salvage")
			_show_field_notice("분해 완료 · 총기 개조 부품이 떨어졌습니다.")
		"basic_mission_subway":
			var subway_mission_id := str(point.get_meta("basic_mission_id", "subway"))
			_advance_basic_mission(subway_mission_id)
			_show_field_notice(
				"지하 보급로 확인 완료 · 종로 지하선을 확보했습니다."
				if subway_mission_id == "subway_return"
				else "지하철역 진입로 조사 완료 · 포격 신호를 기록했습니다."
			)
		"rescue":
			_add_fatigue(FATIGUE_RESCUE_GAIN)
			_add_rescued_follower(point.global_position)
			_show_field_notice("피난민 구조 · 호송 중 이동 속도가 감소합니다.")
		"corpse_recovery":
			_recover_previous_corpse()
	field_loot_containers.erase(point)
	field_interactions.erase(point)
	raid_hotspots.erase(point)
	nearby_field_interaction = null
	field_interaction_hold_time = 0.0
	field_interaction_keyboard_held = false
	hud.field_interaction_touch_held = false
	if hud.field_interaction_panel:
		hud.field_interaction_panel.visible = false
	if interaction_type == "loot_container":
		_mark_field_loot_container_opened(point)
	else:
		point.queue_free()
	_update_equipment_ui()


func _mark_field_loot_container_opened(point: Node3D) -> void:
	point.set_meta("opened", true)
	point.remove_from_group("field_interaction")
	var sprite := point.get_node_or_null("ContainerSprite") as Sprite3D
	if sprite:
		sprite.modulate = Color(0.48, 0.52, 0.50, 0.58)
		sprite.position.y = maxf(0.12, sprite.position.y - 0.08)
	var type_icon := point.get_node_or_null("ContainerTypeIcon") as Sprite3D
	if type_icon:
		type_icon.texture = UI_ICONS.get_icon("check", 72, Color("#71877d"))
		type_icon.modulate.a = 0.28
		type_icon.position.y -= 0.08


func _open_field_loot_container(point: Node3D) -> void:
	var container_type := str(point.get_meta("container_type", "street_cache"))
	var stage_tier := int(point.get_meta(
		"stage_tier",
		LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	))
	var district := str(point.get_meta("district_id", "street_mixed"))
	var container_index := int(point.get_meta("container_index", 0))
	var container_random := RandomNumberGenerator.new()
	container_random.seed = (
		GameState.map_seed
		^ (container_index * 104729)
		^ container_type.hash()
		^ district.hash()
	)
	var unarmed_recovery := not GameState.has_any_weapon()
	var definitions: Array[Dictionary] = LOOT_ECONOMY.roll_container(
		container_type,
		stage_tier,
		district,
		container_random,
		unarmed_recovery
	)
	var spawned_count := 0
	for definition in definitions:
		# 맨손 회복용 무기는 스폰 상한을 무시하고 반드시 나오게 한다. 재무장을
		# 막으면 판이 그대로 멈추기 때문이다.
		var bypass_cap := unarmed_recovery and str(definition.get("type", "")) == "weapon"
		if not LOOT_ECONOMY.try_register_loot(
			GameState,
			definition,
			"field",
			stage_tier,
			bypass_cap
		):
			continue
		var angle := TAU * float(spawned_count) / float(maxi(1, definitions.size()))
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * (0.55 + spawned_count * 0.12)
		var data := (definition.get("data", {}) as Dictionary).duplicate(true)
		data["loot_source"] = "container"
		data["container_type"] = container_type
		loot_system._create_loot_pickup(
			str(definition.get("type", "canned_food")),
			point.global_position + offset,
			data
		)
		spawned_count += 1
	_add_fatigue(FATIGUE_LOOT_GAIN)
	if spawned_count == 0:
		_show_field_notice("%s · 비어 있습니다." % LOOT_ECONOMY.get_container_display_name(container_type))
	elif (
		container_type in ["scrap_pile", "catnip_planter"]
		and not GameState.raw_material_tip_seen
	):
		# 첫 원자재 컨테이너 — 이 조각이 왜 필요한지 여기서 한 번만 가르친다.
		GameState.raw_material_tip_seen = true
		GameState.save_persistent_state()
		_show_field_notice(
			"%s 개방.
이 조각들이 쉘터 생산 라인의 연료다. 주민이 일하려면 이걸 가져가야 한다.
부피가 커서 10개마다 가방 한 칸을 차지한다."
			% LOOT_ECONOMY.get_container_display_name(container_type)
		)
	else:
		_show_field_notice(
			"%s 개방 · 전리품 %d개" % [
				LOOT_ECONOMY.get_container_display_name(container_type),
				spawned_count,
			]
		)


func _add_dictionary_loot(target: Dictionary, recovered: Dictionary) -> void:
	for key in recovered.keys():
		var item_id := str(key)
		target[item_id] = int(target.get(item_id, 0)) + maxi(0, int(recovered[key]))


func _recover_previous_corpse() -> void:
	var corpse_data := GameState.pending_corpse_recovery
	var loot := corpse_data.get("loot", {}) as Dictionary
	var recovered_count := RAID_LOSS_MANAGER.get_item_count(loot)
	if recovered_count <= 0:
		GameState.clear_pending_corpse_recovery()
		_show_field_notice("회수할 장비가 남아 있지 않습니다.")
		return
	_add_dictionary_loot(
		GameState.ammo_inventory,
		loot.get("ammo_inventory", {}) as Dictionary
	)
	GameState.medkits += maxi(0, int(loot.get("medkits", 0)))
	GameState.canned_food += maxi(0, int(loot.get("canned_food", 0)))
	GameState.churu += maxi(0, int(loot.get("churu", 0)))
	GameState.raw_scrap += maxi(0, int(loot.get("raw_scrap", 0)))
	GameState.raw_catnip += maxi(0, int(loot.get("raw_catnip", 0)))
	_add_dictionary_loot(
		GameState.mod_component_inventory,
		loot.get("mod_component_inventory", {}) as Dictionary
	)
	_add_dictionary_loot(
		GameState.progression_item_inventory,
		loot.get("progression_item_inventory", {}) as Dictionary
	)
	_add_dictionary_loot(
		GameState.weapon_mod_inventory,
		loot.get("weapon_mod_inventory", {}) as Dictionary
	)
	var recovered_weapons := loot.get("weapon_inventory", {}) as Dictionary
	for weapon_id in recovered_weapons.keys():
		GameState.add_weapon(str(weapon_id), maxi(0, int(recovered_weapons[weapon_id])))
	var recovered_loadouts := loot.get("weapon_mod_loadouts", {}) as Dictionary
	for weapon_id in recovered_loadouts.keys():
		GameState.weapon_mod_loadouts[str(weapon_id)] = (recovered_loadouts[weapon_id] as Array).duplicate()
	var recovered_equipment := loot.get("equipment_inventory", {}) as Dictionary
	for equipment_id in recovered_equipment.keys():
		GameState.add_equipment(str(equipment_id), maxi(0, int(recovered_equipment[equipment_id])))
	var recovered_cargo := loot.get("raid_special_cargo", {}) as Dictionary
	if not recovered_cargo.is_empty():
		GameState.raid_special_cargo = recovered_cargo.duplicate(true)
		jackpot._restore_jackpot_cargo_presentation()
	var recovered_weapon_id := str(loot.get("equipped_weapon_id", ""))
	if (
		not recovered_weapon_id.is_empty()
		and GameState.get_weapon_count(recovered_weapon_id) > 0
		and not has_ak
	):
		weapon_combat._on_inventory_weapon_equipped(recovered_weapon_id)
	reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.reserve_ammo = reserve_ammo
	GameState.clear_pending_corpse_recovery()
	GameState.save_persistent_state()
	if is_instance_valid(tactical_map) and tactical_map.has_method("clear_corpse_recovery"):
		tactical_map.call("clear_corpse_recovery")
	_show_field_notice("분실 장비 회수 완료 · %d개 품목을 되찾았습니다." % recovered_count)
	_update_medkit_button()


func _spawn_salvage_rewards(origin: Vector3) -> void:
	var component_ids := ["rubber_gasket", "scope_lens", "magazine_spring"]
	var component_names := {
		"rubber_gasket": "소음기용 고무 패킹",
		"scope_lens": "스코프 렌즈",
		"magazine_spring": "탄창 스프링",
	}
	var reward_count := spawn_random.randi_range(1, 2)
	for reward_index in reward_count:
		var component_id: String = component_ids[spawn_random.randi_range(0, component_ids.size() - 1)]
		var angle := TAU * float(reward_index) / float(maxi(reward_count, 1)) + spawn_random.randf_range(-0.5, 0.5)
		var offset := Vector3(cos(angle), 0, sin(angle)) * (0.75 + reward_index * 0.2)
		loot_system._create_loot_pickup("mod_component", origin + offset, {
			"component_id": component_id,
			"amount": 1,
			"display_name": component_names[component_id],
		})


func _add_rescued_follower(world_position: Vector3) -> void:
	var follower := RESCUED_CAT_FOLLOWER_SCRIPT.new() as CharacterBody3D
	follower.name = "RescuedCat_%02d" % (rescued_followers.size() + 1)
	add_child(follower)
	follower.global_position = Vector3(world_position.x, 0.05, world_position.z)
	follower.call("setup", player, rescued_followers.size())
	rescued_followers.append(follower)
	if is_instance_valid(scent_system):
		scent_system.call("register_mover", follower, "rescue")


func _show_field_notice(message: String) -> void:
	if not hud.ammo_notice:
		return
	if message == last_field_notice and ammo_notice_time > 0.0:
		repeated_field_notice_count += 1
	else:
		last_field_notice = message
		repeated_field_notice_count = 1
	hud.ammo_notice.text = (
		message
		if repeated_field_notice_count <= 1
		else "%s  ×%d" % [message, repeated_field_notice_count]
	)
	hud.ammo_notice.visible = true
	ammo_notice_time = 2.4


func _update_fatigue(delta: float, is_moving: bool) -> void:
	var rate := FATIGUE_MOVING_RATE if is_moving else FATIGUE_IDLE_RATE
	if rescued_followers.size() > 0 and is_moving:
		rate *= 1.0 + minf(0.6, rescued_followers.size() * 0.12)
	if laser_aim_held:
		rate += FATIGUE_AIM_HOLD_RATE
	_add_fatigue(rate * delta)
	GameState.fatigue = fatigue
	_refresh_fatigue_hud()
	enemy_director._trigger_fatigue_boss_event()


func _add_fatigue(amount: float) -> void:
	if amount <= 0.0:
		return
	fatigue = clampf(fatigue + amount * GameState.get_fatigue_gain_multiplier(), 0.0, FATIGUE_MAX)
	GameState.fatigue = fatigue
	_refresh_fatigue_hud()
	# 피로는 체력이 아니라 "얼마나 더 머무를 수 있는가"다. 보스가 튀어나오는
	# 50에 도달하기 전에 한 번은 그 규칙을 말해 줘야 한다.
	if fatigue >= 25.0 and not GameState.fatigue_lesson_seen:
		GameState.fatigue_lesson_seen = true
		GameState.save_persistent_state()
		_show_field_notice(
			"피로가 쌓이고 있다.\n"
			+ "체력과 달리 피로는 회복되지 않는다. 이 판에 남은 시간 그 자체다.\n"
			+ "절반을 넘기면 도시가 사냥꾼을 보낸다."
		)
	enemy_director._trigger_fatigue_boss_event()


func _refresh_fatigue_hud() -> void:
	if hud.fatigue_bar:
		hud.fatigue_bar.value = fatigue
	var status := "안정"
	var color := Color("#78b993")
	var next_warning_band := 0
	if fatigue >= 90.0:
		status = "탈진"
		color = Color("#e06c62")
		next_warning_band = 3
	elif fatigue >= 65.0:
		status = "과부하"
		color = Color("#e3ad61")
		next_warning_band = 2
	elif fatigue >= 35.0:
		status = "피곤"
		color = Color("#d5c16b")
		next_warning_band = 1
	# 정보가 있는 쪽은 바다. 예전에는 35 미만에서 바를 숨기고 "안정"이라는
	# 글자만 남겨서, 정작 배워야 할 게이지가 안 보였다. 뒤집는다.
	if hud.fatigue_status_label:
		# 퍼센트는 늘 보이고(라벨 옆 정렬이 살아난다), 경고 단어는 임계치부터 붙는다.
		hud.fatigue_status_label.text = (
			"%d%%" % roundi(fatigue)
			if next_warning_band <= 0
			else "%d%% · %s" % [roundi(fatigue), status]
		)
		hud.fatigue_status_label.visible = true
		hud.fatigue_status_label.add_theme_color_override("font_color", color)
	if hud.fatigue_fill_style:
		hud.fatigue_fill_style.bg_color = color
		hud.fatigue_fill_style.border_color = color.lightened(0.2)
	if fatigue_warning_band < 0:
		fatigue_warning_band = next_warning_band
	elif fatigue_warning_band != next_warning_band:
		if next_warning_band > fatigue_warning_band:
			var warning_text: String = str({
				1: "피로 누적 · 조준과 전투 행동이 피로를 빠르게 높입니다.",
				2: "피로 과부하 · 이동 성능이 곧 저하됩니다.",
				3: "탈진 위험 · 즉시 탈출하거나 휴식하십시오.",
			}.get(next_warning_band, ""))
			if not warning_text.is_empty():
				_show_field_notice(warning_text)
		fatigue_warning_band = next_warning_band
		_apply_hud_layout()
	_refresh_top_status_label()


func _get_fatigue_speed_multiplier() -> float:
	if fatigue < 70.0:
		return 1.0
	var exhaustion := inverse_lerp(70.0, FATIGUE_MAX, fatigue)
	return lerpf(1.0, FATIGUE_SPEED_MIN, exhaustion)


func _get_escort_speed_multiplier() -> float:
	return maxf(0.65, 1.0 - rescued_followers.size() * ESCORT_SPEED_PENALTY)


func _commit_rescued_followers() -> int:
	var rescued_count := rescued_followers.size()
	if rescued_count <= 0:
		return 0
	var accepted: int = GameState.try_add_rescued_workers(rescued_count)
	rescued_followers.clear()
	if accepted > 0:
		_advance_contract_progress("rescue", accepted)
	return accepted


func _setup_weather_effects() -> void:
	var weather_layer := CanvasLayer.new()
	weather_layer.name = "WeatherFlashLayer"
	weather_layer.layer = 20
	add_child(weather_layer)
	lightning_overlay = ColorRect.new()
	lightning_overlay.name = "LightningFlash"
	lightning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lightning_overlay.color = Color(0.72, 0.84, 1.0, 0.0)
	lightning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_layer.add_child(lightning_overlay)
	lightning_timer = spawn_random.randf_range(35.0, 75.0)


func _update_lightning(delta: float) -> void:
	if bool(AccessibilitySettings.battery_saver):
		lightning_timer = maxf(lightning_timer, 90.0)
		if is_instance_valid(lightning_overlay):
			lightning_overlay.color.a = 0.0
		return
	lightning_timer -= delta
	if lightning_timer > 0.0:
		return
	lightning_timer = spawn_random.randf_range(45.0, 100.0)
	var tween := create_tween()
	tween.tween_property(lightning_overlay, "color:a", 0.14, 0.055)
	tween.tween_property(lightning_overlay, "color:a", 0.018, 0.12)
	tween.tween_interval(0.08)
	tween.tween_property(lightning_overlay, "color:a", 0.075, 0.04)
	tween.tween_property(lightning_overlay, "color:a", 0.0, 0.32)


func _save_run_state() -> void:
	GameState.player_health = player_health
	GameState.magazine_ammo = magazine_ammo
	GameState.reserve_ammo = reserve_ammo
	GameState.has_ak = has_ak
	GameState.equipped_weapon_id = equipped_weapon_id
	GameState.weapon_durability = weapon_durability
	GameState.equipped_weapon_mods.assign(equipped_weapon_mods)
	GameState.fatigue = fatigue
	GameState.save_persistent_state()


func _mobile_button_contains(button: Button, screen_position: Vector2) -> bool:
	return (
		button != null
		and button.visible
		and not button.disabled
		and button.get_global_rect().has_point(screen_position)
	)


func _is_emulated_touch_mouse_event(event: InputEventMouseButton) -> bool:
	return (
		DisplayServer.is_touchscreen_available()
		and event.device == InputEvent.DEVICE_ID_EMULATION
	)


func _release_mobile_held_actions() -> void:
	fire_touch_id = -1
	context_touch_id = -1
	fire_button_held = false
	hud.field_interaction_touch_held = false
	pickup_touch_held = false


func _handle_mobile_action_touch(touch: InputEventScreenTouch) -> bool:
	if not touch.pressed:
		var released_action := false
		if touch.index == fire_touch_id:
			fire_touch_id = -1
			_on_fire_button_up()
			released_action = true
		if touch.index == context_touch_id:
			context_touch_id = -1
			_on_mobile_context_button_up()
			released_action = true
		return released_action
	if _is_inventory_button_at(touch.position):
		_toggle_inventory()
		return true
	if _mobile_button_contains(mobile_map_button, touch.position):
		_on_mobile_map_pressed()
		return true
	if _is_inventory_open() or _is_tactical_map_open() or lore_reader.is_open() or extraction_transition_active:
		return false
	if _mobile_button_contains(hud.fire_button, touch.position):
		if fire_touch_id != -1:
			return true
		fire_touch_id = touch.index
		_on_fire_button_down()
		return true
	if _mobile_button_contains(hud.melee_button, touch.position):
		_on_melee_button_pressed()
		return true
	if _mobile_button_contains(hud.dash_button, touch.position):
		_on_dash_button_pressed()
		return true
	if _mobile_button_contains(mobile_context_button, touch.position):
		context_touch_id = touch.index
		_on_mobile_context_button_down()
		return true
	if _mobile_button_contains(mobile_reload_button, touch.position):
		weapon_combat._reload_ak47()
		return true
	if _mobile_button_contains(mobile_flashlight_button, touch.position):
		var enabled := not mobile_flashlight_button.button_pressed
		mobile_flashlight_button.set_pressed_no_signal(enabled)
		_on_mobile_flashlight_toggled(enabled)
		return true
	if _mobile_button_contains(mobile_medkit_button, touch.position):
		_use_quick_medkit()
		return true
	return false


func _input(event: InputEvent) -> void:
	if player_death_sequence_active:
		var continue_requested := (
			event is InputEventScreenTouch
			and (event as InputEventScreenTouch).pressed
		) or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed
		) or (
			event is InputEventKey
			and (event as InputEventKey).pressed
			and not (event as InputEventKey).echo
			and ((event as InputEventKey).keycode == KEY_SPACE or (event as InputEventKey).physical_keycode == KEY_SPACE)
		)
		if continue_requested:
			_continue_after_death()
			get_viewport().set_input_as_handled()
		return
	if boss_defeat_sequence_active:
		if (
			event is InputEventScreenTouch
			or event is InputEventScreenDrag
			or event is InputEventMouseButton
			or event is InputEventKey
		):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		if key == KEY_ESCAPE and key_event.pressed and lore_reader.is_open():
			lore_reader.close()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_SPACE:
			if key_event.pressed:
				_begin_space_hold()
			else:
				_end_space_hold()
			get_viewport().set_input_as_handled()
			return
		if lore_reader.is_open():
			return
		if key == KEY_TAB and key_event.pressed:
			if _is_inventory_open():
				_toggle_inventory()
			if is_instance_valid(tactical_map):
				tactical_map.call("toggle")
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_E, KEY_I, KEY_B] and key_event.pressed:
			if _is_tactical_map_open():
				tactical_map.call("close")
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE and key_event.pressed and _is_inventory_open():
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		if (
			_is_inventory_open()
			or _is_tactical_map_open()
			or lore_reader.is_open()
			or extraction_transition_active
		):
			return
		if key_event.pressed and key == KEY_F5:
			enemy_director._spawn_test_boss_near_player()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and key == KEY_F8:
			var city_world := $World as ProceduralCityMap
			var debug_enabled := city_world.toggle_collision_debug()
			state_label.text = "충돌 판정 표시 켜짐" if debug_enabled else "충돌 판정 표시 꺼짐"
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and key == KEY_SHIFT:
			_use_quick_medkit()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_Q:
			if is_instance_valid(scent_system):
				scent_system.call("set_focus_active", key_event.pressed)
			get_viewport().set_input_as_handled()
			return
		if key == KEY_G and key_event.pressed and field_interaction_candidates.size() > 1:
			_cycle_field_interaction()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_F:
			if is_instance_valid(nearby_field_interaction):
				var interaction_type := str(nearby_field_interaction.get_meta("interaction_type", ""))
				if interaction_type == "extraction" and key_event.pressed:
					extraction._begin_extraction()
					field_interaction_keyboard_held = false
				else:
					field_interaction_keyboard_held = key_event.pressed
				pickup_keyboard_held = false
			elif key_event.pressed and is_instance_valid(nearby_ammo_pickup):
				loot_system._collect_nearby_ammo()
				pickup_keyboard_held = false
			else:
				field_interaction_keyboard_held = false
				pickup_keyboard_held = key_event.pressed
		elif key == KEY_R and key_event.pressed and has_ak:
			weapon_combat._reload_ak47()
		elif key == KEY_N and key_event.pressed:
			_save_run_state()
			GameState.randomize_map()
			get_tree().reload_current_scene()
	elif event is InputEventMouseButton:
		if (
			_is_inventory_open()
			or _is_tactical_map_open()
			or lore_reader.is_open()
			or extraction_transition_active
		):
			return
		var mouse_event := event as InputEventMouseButton
		if _is_emulated_touch_mouse_event(mouse_event):
			get_viewport().set_input_as_handled()
			return
		if _is_inventory_button_at(mouse_event.position):
			return
		if hud.fire_button and hud.fire_button.visible and hud.fire_button.get_global_rect().has_point(mouse_event.position):
			return
		_handle_combat_mouse_button(mouse_event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if (
			_is_inventory_open()
			or _is_tactical_map_open()
			or lore_reader.is_open()
			or extraction_transition_active
		):
			return
		if _handle_mobile_action_touch(touch):
			get_viewport().set_input_as_handled()
			return
		if touch.pressed:
			if touch_id == -1 and touch.position.x < get_viewport().get_visible_rect().size.x * 0.55:
				touch_id = touch.index
				touch_origin = touch.position
				touch_vector = Vector2.ZERO
				touch_stick.visible = true
				touch_stick.position = touch_origin - touch_stick.size * 0.5
				# 공용 위젯이 손가락 위치를 그린다.
				if touch_stick.has_method("begin_touch"):
					touch_stick.call("begin_touch", touch.index, touch.position)
				get_viewport().set_input_as_handled()
		else:
			if touch.index == touch_id:
				touch_id = -1
				touch_vector = Vector2.ZERO
				if touch_stick.has_method("end_touch"):
					touch_stick.call("end_touch")
				elif touch_knob:
					touch_knob.position = (touch_stick.size - touch_knob.size) * 0.5
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if (
			_is_inventory_open()
			or _is_tactical_map_open()
			or lore_reader.is_open()
			or extraction_transition_active
		):
			return
		if drag.index == fire_touch_id:
			var fire_release_rect := hud.fire_button.get_global_rect().grow(28.0)
			if not fire_release_rect.has_point(drag.position):
				fire_touch_id = -1
				_on_fire_button_up()
			get_viewport().set_input_as_handled()
			return
		if drag.index == context_touch_id:
			var context_release_rect := mobile_context_button.get_global_rect().grow(28.0)
			if not context_release_rect.has_point(drag.position):
				context_touch_id = -1
				_on_mobile_context_button_up()
			get_viewport().set_input_as_handled()
			return
		if drag.index != touch_id:
			return
		var radius := touch_stick.size.x * 0.34
		var offset := (drag.position - touch_origin).limit_length(radius)
		touch_vector = offset / radius
		if touch_stick.has_method("update_touch"):
			touch_stick.call("update_touch", drag.position)
		elif touch_knob:
			touch_knob.position = (touch_stick.size - touch_knob.size) * 0.5 + offset
		get_viewport().set_input_as_handled()


func _handle_combat_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			if stealth._try_stealth_takedown():
				mouse_fire_held = false
			elif laser_aim_held and has_ak and (magazine_ammo > 0 or reserve_ammo > 0):
				mouse_fire_held = true
				weapon_combat._try_fire_ak47()
			else:
				mouse_fire_held = false
				_try_melee_attack()
		else:
			mouse_fire_held = false
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		laser_aim_held = mouse_event.pressed
		if not mouse_event.pressed:
			mouse_fire_held = false
		if mouse_event.pressed:
			_lock_aim_direction(weapon_combat._get_mouse_world_direction())


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mobile_held_actions()
		mouse_fire_held = false
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


func _apply_runtime_accessibility_settings() -> void:
	var rain := get_node_or_null("CameraRig/Rain") as GPUParticles3D
	if rain:
		rain.amount_ratio = 0.36 if bool(AccessibilitySettings.battery_saver) else 1.0
	_update_day_night_visuals()
	stealth._update_visibility_fog()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for audio_player in gunshot_players:
		if is_instance_valid(audio_player):
			audio_player.stop()
	if is_instance_valid(roll_audio_player):
		roll_audio_player.stop()
	# 장면 전환 시 BGM 정리는 플레이어 노드가 함께 해제되며 자연히 멈춘다.
	if not DisplayServer.is_touchscreen_available():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── 모듈 위임 스텁 ─────────────────────────────────────────────
# 함수 본문은 scripts/raid/* 모듈로 옮겨졌다. 하지만 적 스크립트와
# 테스트가 call()로 main을 통해 부르는 계약이 있어, 이름을 유지한다.


func _begin_extraction() -> void:
	extraction._begin_extraction()


func _show_extraction_result(rescued_count: int) -> void:
	extraction._show_extraction_result(rescued_count)


func _grant_extraction_route_bonus() -> Dictionary:
	return extraction._grant_extraction_route_bonus()


func _get_carried_loot_value_cached() -> int:
	# 탈출 프롬프트는 매 프레임 갱신되지만, 가방 가치 집계는 딕셔너리를 여럿
	# 복제하므로 0.4초마다 한 번만 다시 계산한다. 시체 전리품 가치 = 지금 죽으면
	# 잃을 것 = 지금 나가면 확보할 것. 부작용 없는 build_death_corpse_loot을 쓴다.
	var now := Time.get_ticks_msec()
	if now - _carried_value_cache_msec < 400:
		return _carried_value_cache
	_carried_value_cache_msec = now
	var loot := RAID_LOSS_MANAGER.build_death_corpse_loot()
	_carried_value_cache = RAID_LOSS_MANAGER.get_total_value(loot)
	return _carried_value_cache


func _update_field_missions(delta: float) -> void:
	field_missions._update_field_missions(delta)


func _fail_field_mission(reason: String) -> void:
	field_missions._fail_field_mission(reason)


func _grant_field_mission_reward(reward: Dictionary) -> String:
	return field_missions._grant_field_mission_reward(reward)


func _is_player_detected_for_field_mission() -> bool:
	return field_missions._is_player_detected_for_field_mission()


func _update_jackpot_event(delta: float) -> void:
	jackpot._update_jackpot_event(delta)


func _settle_jackpot_cargo() -> Dictionary:
	return jackpot._settle_jackpot_cargo()


func _update_faction_conflicts(delta: float) -> void:
	incidents._update_faction_conflicts(delta)


func _spawn_dynamic_convoy_incident(world: ProceduralCityMap) -> void:
	incidents._spawn_dynamic_convoy_incident(world)

# 적 소환 계열은 scripts/raid/enemy_director.gd 로 옮겨졌다. call() 계약 유지용 스텁.

func _build_enemy_squad_sizes(total_count: int) -> Array[int]:
	return enemy_director._build_enemy_squad_sizes(total_count)

func _find_event_position_near_player(world: ProceduralCityMap,
	minimum_distance: float,
	maximum_distance: float) -> Vector3:
	return enemy_director._find_event_position_near_player(world, minimum_distance, maximum_distance)

func _find_reinforcement_position() -> Vector3:
	return enemy_director._find_reinforcement_position()

func _on_enemy_died(enemy: CharacterBody3D) -> void:
	enemy_director._on_enemy_died(enemy)

func _spawn_enemy_loot(enemy: CharacterBody3D) -> Node3D:
	return enemy_director._spawn_enemy_loot(enemy)

func _spawn_enemy_squad(world: ProceduralCityMap,
	squad_anchor: Vector3,
	kinds: Array[String],
	threat: float,
	order_position: Vector3 = Vector3.INF,
	metadata: Dictionary = {}) -> Array[CharacterBody3D]:
	return enemy_director._spawn_enemy_squad(world, squad_anchor, kinds, threat, order_position, metadata)

func _spawn_rocket_boss_at(spawn_position: Vector3,
	boss_threat: float,
	boss_name: String) -> CharacterBody3D:
	return enemy_director._spawn_rocket_boss_at(spawn_position, boss_threat, boss_name)

func _trigger_fatigue_boss_event() -> void:
	enemy_director._trigger_fatigue_boss_event()

func _update_reinforcement_call(delta: float, effective_threat: float) -> void:
	enemy_director._update_reinforcement_call(delta, effective_threat)

# 전리품 픽업은 scripts/raid/loot_pickup_system.gd 로 옮겨졌다. call() 계약 유지용.

func _collect_nearby_ammo() -> void:
	loot_system._collect_nearby_ammo()

func _create_loot_pickup(loot_type: String, world_position: Vector3, data: Dictionary = {}) -> Node3D:
	return loot_system._create_loot_pickup(loot_type, world_position, data)

func _show_bag_full_notice() -> void:
	loot_system._show_bag_full_notice()

# 잠입/무기 전투는 scripts/raid/{stealth_system,weapon_combat}.gd 로 옮겨졌다.

func _setup_stealth_takedown_prompt(font: Font) -> void:
	stealth._setup_stealth_takedown_prompt(font)

func _update_stealth_mission(delta: float, distance_to_site: float) -> void:
	stealth._update_stealth_mission(delta, distance_to_site)

func _update_stealth_reach_mission(delta: float) -> void:
	stealth._update_stealth_reach_mission(delta)

func _enemy_player_visibility_factor(enemy: Node3D,
	fully_visible_radius: float,
	reveal_radius: float) -> float:
	return stealth._enemy_player_visibility_factor(enemy, fully_visible_radius, reveal_radius)

func _update_enemy_visibility(delta: float = 1.0 / 60.0) -> void:
	stealth._update_enemy_visibility(delta)

func _update_visibility_fog() -> void:
	stealth._update_visibility_fog()

func _update_stealth_takedown_prompt() -> void:
	stealth._update_stealth_takedown_prompt()

func _on_inventory_weapon_equipped(weapon_id: String) -> void:
	weapon_combat._on_inventory_weapon_equipped(weapon_id)

func _on_inventory_weapon_mods_changed() -> void:
	weapon_combat._on_inventory_weapon_mods_changed()

func _on_inventory_weapon_unequipped() -> void:
	weapon_combat._on_inventory_weapon_unequipped()

func _get_mobile_aim_assist_direction(facing_direction: Vector3) -> Vector3:
	return weapon_combat._get_mobile_aim_assist_direction(facing_direction)

func _update_mobile_aim_direction(movement_world_direction: Vector3) -> void:
	weapon_combat._update_mobile_aim_direction(movement_world_direction)

func _apply_weapon_recoil(aim_direction: Vector3) -> void:
	weapon_combat._apply_weapon_recoil(aim_direction)

func _fire_ak47() -> void:
	weapon_combat._fire_ak47()

func _reload_ak47() -> void:
	weapon_combat._reload_ak47()

func _update_weapon_ballistics(delta: float, is_moving: bool) -> void:
	weapon_combat._update_weapon_ballistics(delta, is_moving)

func _update_weapon_pose() -> void:
	weapon_combat._update_weapon_pose()
