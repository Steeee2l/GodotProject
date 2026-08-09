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
const LOAF_MOVE_MULTIPLIER := 1.0
const LOAF_STAMINA_DRAIN_PER_SECOND := 7.5
const LOAF_MIN_STAMINA := 1.0
const LOAF_VISIBILITY_MULTIPLIER := 0.48
const WEAPON_FRAME_SIZE := Vector2(192, 192)
const WEAPON_VISUAL_PIXEL_SIZE := 0.0018
const WEAPON_FLOAT_DISTANCE := 0.72
const WEAPON_MUZZLE_FORWARD_DISTANCE := 0.64
const AK_DROP_TEXTURE := preload("res://assets/weapons/ak47_drop.png")
const AK_DIRECTIONAL_TEXTURE := preload("res://assets/weapons/ak47_directional.png")
const AMMO_762_TEXTURE := preload("res://assets/items/ammo_762.png")
const CHURU_TEXTURE := preload("res://assets/items/churu_rare.png")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const ROCKET_BOSS_SCRIPT := preload("res://scripts/rocket_boss.gd")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const PERCEPTION_SYSTEM_SCRIPT := preload("res://scripts/perception_system.gd")
const SCENT_TRAIL_MANAGER_SCRIPT := preload("res://scripts/scent_trail_manager.gd")
const OBJECTIVE_SCENT_GUIDANCE_SCRIPT := preload("res://scripts/objective_scent_guidance.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const LOOT_CONTAINER_VISUALS := preload("res://scripts/loot_container_visual_catalog.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const GameOverScreen := preload("res://scripts/hud/game_over_screen.gd")
const LoreReader := preload("res://scripts/hud/lore_reader.gd")
const RaidHud := preload("res://scripts/hud/raid_hud.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const RAID_EXTRACTION_POLICY := preload("res://scripts/raid_extraction_policy.gd")
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
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const EXTRACTION_BEACON_TEXTURE := preload("res://assets/extraction/extraction_beacon_generated_v1.png")
const GENERATED_MISSION_ICON_PATHS := {
	"defense": "res://assets/generated/p0_sliced/mission_icons/defend.png",
	"eliminate": "res://assets/generated/p0_sliced/mission_icons/eliminate.png",
	"collect": "res://assets/generated/p0_sliced/mission_icons/collect_cache.png",
	"investigate": "res://assets/generated/p0_sliced/mission_icons/investigate.png",
	"stealth": "res://assets/generated/p0_sliced/mission_icons/stealth.png",
	"stealth_reach": "res://assets/generated/p0_sliced/mission_icons/waypoint.png",
}
const BROKEN_SENTRY_TEXTURE := preload("res://assets/props/broken_sentry_salvage.png")
const FIELD_LOOT_CACHE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const SECURE_MILITARY_CACHE_TEXTURE := preload("res://assets/events/secure_military_cache_v1.png")
const PHARMACY_EMERGENCY_CACHE_TEXTURE := preload("res://assets/events/pharmacy_emergency_cache_v1.png")
const CRASHED_CONVOY_CACHE_TEXTURE := preload("res://assets/events/crashed_convoy_cache_v1.png")
const SUBWAY_MANIFEST_TERMINAL_TEXTURE := preload("res://assets/events/subway_manifest_terminal_v2.png")
const SUBWAY_EMERGENCY_GENERATOR_TEXTURE := preload("res://assets/events/subway_emergency_generator_v2.png")
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
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
const FIRST_STAGE_SOLO_SQUAD_CHANCE := 0.62
const SALVAGE_VEHICLE_POINT_COUNT := 10
const SALVAGE_MISC_POINT_COUNT := 4
const RESCUE_POINT_COUNT := 5
const RAID_ENTRY_ENEMY_SAFE_RADIUS := 30.0
const MELEE_ATTACK_COOLDOWN := 0.72
const MELEE_ATTACK_RANGE := 2.2
const MELEE_ATTACK_DAMAGE := 38
const STEALTH_TAKEDOWN_RANGE := 2.0
const STEALTH_TAKEDOWN_PROMPT_SIZE := Vector2(196.0, 54.0)
const STEALTH_TAKEDOWN_TIME_SCALE := 0.24
const STEALTH_TAKEDOWN_SLOWMO_SECONDS := 0.14
const STEALTH_TAKEDOWN_CAMERA_SHAKE_SECONDS := 0.24
const STEALTH_TAKEDOWN_CAMERA_SHAKE_STRENGTH := 0.34
const BOSS_DEFEAT_TIME_SCALE := 0.20
const BOSS_DEFEAT_SLOWMO_SECONDS := 1.05
const BOSS_DEFEAT_FOCUS_SECONDS := 1.65
const BOSS_DEFEAT_CAMERA_SIZE := 19.5
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 34.0
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 42.0
const MOBILE_AIM_ASSIST_ANGLE_WEIGHT := 24.0
const MOBILE_AIM_ASSIST_DISTANCE_WEIGHT := 0.32
const REINFORCEMENT_CALL_TRIGGER_TIME := 30.0
const REINFORCEMENT_HIDDEN_TRIGGER_TIME := 14.0
const REINFORCEMENT_CALL_DURATION := 4.6
const REINFORCEMENT_CALL_COOLDOWN := 38.0
const ENEMY_VISIBILITY_HOLD_SECONDS := 0.32
const ENEMY_VISIBILITY_FADE_IN_SPEED := 10.0
const ENEMY_VISIBILITY_FADE_OUT_SPEED := 3.2
const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_INTERACTION_FACING_WEIGHT := 1.35
const FIELD_INTERACTION_SIGHT_HEIGHT := 0.48
const SALVAGE_HOLD_DURATION := 2.4
const RESCUE_HOLD_DURATION := 1.8
const FATIGUE_MAX := 100.0
const FATIGUE_MOVING_RATE := 0.055
const FATIGUE_IDLE_RATE := 0.0
const FATIGUE_AIM_HOLD_RATE := 0.09
const FATIGUE_SHOT_GAIN := 0.28
const FATIGUE_MELEE_GAIN := 1.1
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_SALVAGE_GAIN := 3.5
const FATIGUE_RESCUE_GAIN := 2.2
const FATIGUE_ROLL_GAIN := 0.45
const FATIGUE_DAMAGE_PER_POINT := 0.045
const FATIGUE_SPEED_MIN := 0.58
const ESCORT_SPEED_PENALTY := 0.07
const FIELD_MISSION_COUNT := 6
const FIELD_MISSION_TRIGGER_RADIUS := 4.6
const FIELD_MISSION_ACTIVE_RADIUS := 22.0
const FIELD_MISSION_STEALTH_HOLD_RADIUS := 14.0
const FIELD_MISSION_FAIL_RADIUS := 72.0
const FIELD_MISSION_RESULT_DURATION := 2.8
const FIELD_MISSION_START_HOLD_DURATION := 0.65
const FIELD_MISSION_PREPARE_DURATION := 5.0
const FIELD_MISSION_FIRST_WAVE_DELAY := 1.2
const FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE := 16.0
const FIELD_MISSION_ENEMY_MIN_SITE_DISTANCE := 23.0
const FIELD_MISSION_ENEMY_MAX_SITE_DISTANCE := 34.0
const FATIGUE_BOSS_TRIGGER := 50.0
const FATIGUE_BOSS_NAME := "폐허의 포격수 묘르"
const LORE_CLUE_COUNT := 6
const RAID_HOTSPOT_COUNT := 3
const RAID_HOTSPOT_DISCOVERY_DISTANCE := 24.0
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const DYNAMIC_INCIDENT_DELAY_MIN := 55.0
const DYNAMIC_INCIDENT_DELAY_MAX := 85.0
const DYNAMIC_INCIDENT_DURATION := 150.0
const DYNAMIC_INCIDENT_GUARD_RADIUS := 6.0
const DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS := 6
const JACKPOT_ALARM_WAVE_INTERVAL := 9.0
const JACKPOT_ALARM_WAVE_COUNT := 3
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
var gunshot_index := 0
var roll_audio_player: AudioStreamPlayer3D
var bgm_player: AudioStreamPlayer
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
var ammo_pickups: Array[Node3D] = []
var field_loot_containers: Array[Node3D] = []
var ammo_notice_time := 0.0
var last_field_notice := ""
var repeated_field_notice_count := 0
var auto_paused_for_background := false
var ammo_pickup_chain_total := 0
var ammo_pickup_chain_time := 0.0
var nearby_ammo_pickup: Node3D
var visibility_material: ShaderMaterial
var perception_system: CanvasLayer
var aim_hold_time := 0.0
var locked_aim_direction := Vector3.ZERO
var smoke_particle_texture: ImageTexture
var loot_glow_texture: ImageTexture
var canned_food_texture: ImageTexture
var weapon_loot_texture_cache: Dictionary = {}
var cowering_resident_texture_cache: Dictionary = {}
var player_health := 82
var enemies: Array[CharacterBody3D] = []
var world_time_hours := 9.0
var night_intensity := 0.0
var enemy_spawn_serial := 0
var enemy_ranged_spawn_serial := 0
var enemy_squad_serial := 0
var reinforcement_timer := 8.0
var sustained_combat_time := 0.0
var concealed_combat_time := 0.0
var reinforcement_call_cooldown := 0.0
var active_reinforcement_caller: CharacterBody3D
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
var stealth_takedown_prompt: PanelContainer
var stealth_takedown_key_label: Label
var stealth_takedown_input_icon: TextureRect
var stealth_takedown_action_label: Label
var nearby_stealth_takedown_target: CharacterBody3D
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
var roll_stamina := ROLL_STAMINA_MAX
var roll_afterimage_timer := 0.0
var roll_direction := Vector3.ZERO
var scope_camera_offset := Vector3.ZERO
var weapon_random := RandomNumberGenerator.new()
var tactical_map: Control
var extraction_site: Node3D
var extraction_position := Vector3.ZERO
var extraction_sites: Array[Node3D] = []
var extraction_prompt: Control
var extraction_transition_active := false
var extraction_fade: ColorRect
var extraction_success_label: Label
var pending_extraction_xp_result: Dictionary = {}
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
var run_boss_kills := 0
var run_damage_dealt := 0
var raid_start_snapshot := {}
var corpse_recovery_point: Node3D
var game_over_screen := GameOverScreen.new()
var lore_reader := LoreReader.new()
var hud := RaidHud.new()
var raid_zone_data: Dictionary = {}
var field_mission_sites: Array[Node3D] = []
var active_field_mission: Node3D
var active_mission_collectibles: Array[Node3D] = []
var field_mission_elapsed := 0.0
var field_mission_wave_timer := 0.0
var field_mission_prepare_timer := 0.0
var field_mission_phase := "idle"
var field_mission_spawned_enemies := 0
var field_mission_kills := 0
var field_mission_collected := 0
var field_mission_result_timer := 0.0
var field_mission_runtime := 0.0
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
var fatigue_boss_event_triggered := false
var boss_alert_panel: PanelContainer
var boss_alert_title: Label
var boss_alert_subtitle: Label
var boss_alert_tween: Tween
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
var scent_awareness_tick := 0.0
var faction_conflict_tick := 0.0
var raid_hotspots: Array[Node3D] = []
var raid_elapsed_seconds := 0.0
var raid_pressure_level := 0
# 긴장도의 실제 입력. 시간·전투·소음·전리품이 여기에 누적된다.
var raid_pressure_points := 0.0
var raid_seconds_since_noise := 0.0
var raid_event_last_fired: Dictionary = {}
var raid_event_cooldown := 0.0
var raid_curfew_active := false
var raid_event_random := RandomNumberGenerator.new()
var raid_sealed_extraction_index := -1
var raid_reward_multiplier := 1.0
var raid_hotspots_opened := 0
var dynamic_incident_site: Node3D
var dynamic_incident_state := "scheduled"
var dynamic_incident_timer := 0.0
var dynamic_incident_winning_faction := ""
var selected_extraction_index := 0
var selected_extraction_multiplier := 1.0
var selected_extraction_title := "안전 귀환로"
var jackpot_clue_site: Node3D
var jackpot_power_site: Node3D
var jackpot_cargo_site: Node3D
var jackpot_power_position := Vector3.ZERO
var jackpot_cargo_position := Vector3.ZERO
var jackpot_state := "clue"
var jackpot_alarm_wave_timer := 0.0
var jackpot_alarm_waves_spawned := 0
var jackpot_carried_sprite: Sprite3D


func _ready() -> void:
	run_started_msec = Time.get_ticks_msec()
	raid_zone_data = GameState.get_raid_zone()
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
	_build_gunshot_audio()
	_build_roll_audio()
	_build_bgm_audio()
	_install_scent_system()
	_spawn_enemies()
	_setup_building_overlays()
	_build_day_night_tint()
	_build_visibility_fog()
	_install_perception_system()
	_update_day_night(0.0)
	_update_enemy_visibility()
	_set_facing("s")
	_setup_extraction_site(world)
	if launched_from_shelter:
		_play_raid_entry_fade()
	_setup_field_objectives(world)
	_setup_procedural_field_missions(world)
	_setup_basic_raid_missions(world)
	_setup_world_lore_clues(world)
	_setup_corpse_recovery(world)
	_register_building_entrance_interactions()
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
		_update_visibility_fog()
		_update_enemy_visibility(delta)
		return
	_update_day_night(delta)
	_update_lightning(delta)
	_update_enemy_pressure(delta)
	_update_scent_system(delta)
	_update_faction_conflicts(delta)
	_update_raid_opportunities(delta)
	_update_jackpot_event(delta)
	melee_attack_cooldown = maxf(0.0, melee_attack_cooldown - delta)
	combat_hit_stop_cooldown = maxf(0.0, combat_hit_stop_cooldown - delta)
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
	if (laser_aim_held or mouse_fire_held) and _uses_mouse_aim():
		_lock_aim_direction(_get_mouse_world_direction())
	_update_scope_camera(delta)
	if hud.melee_button:
		hud.melee_button.disabled = melee_attack_cooldown > 0.0 or loafing
	if hud.dash_button:
		hud.dash_button.disabled = roll_active or roll_stamina < _get_roll_stamina_cost()
	if mobile_reload_button:
		mobile_reload_button.disabled = weapon_reloading or loafing or not has_ak or reserve_ammo <= 0
	_update_field_interactions(delta)
	_update_extraction_discovery()
	_update_combat_overlay_visibility()
	_update_stealth_takedown_prompt()
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
		_update_visibility_fog()
		_update_enemy_visibility(delta)
		return
	_update_field_missions(delta)
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
	_update_weapon_ballistics(delta, input_vector.length_squared() > 0.01)

	var world_direction := Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y)
	if not _uses_mouse_aim() and (laser_aim_held or fire_button_held):
		# 예전에는 has_ak 조건이 붙어 있어서, 무기를 잃으면 조준 중에
		# 방향이 아예 갱신되지 않고 얼어붙었다.
		_update_mobile_aim_direction(world_direction)
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
		if not aim_is_locked or not _uses_mouse_aim():
			_update_facing(input_vector)
		_set_motion_state("walk")
		state_label.text = "식빵 자세 이동" if loafing else "이동 중"
	else:
		player.velocity = recoil_velocity
		_set_motion_state("idle")
		state_label.text = "식빵 자세 대기" if loafing else "경계 중"

	var mobile_steering := not _uses_mouse_aim() and input_vector.length_squared() > 0.01
	if (
		not roll_active
		and aim_is_locked
		and not mobile_steering
		and locked_aim_direction.length_squared() > 0.01
	):
		_set_facing_from_world_direction(locked_aim_direction)
	_update_weapon_pose()
	player.set_meta("tactical_heading", _get_current_facing_world_direction())

	player.move_and_slide()
	_update_player_stuck_recovery(delta, input_vector.length_squared() > 0.01)
	var map_limit := ($World as ProceduralCityMap).get_map_limit()
	player.position.x = clampf(player.position.x, -map_limit, map_limit)
	player.position.z = clampf(player.position.z, -map_limit, map_limit)
	_update_pickup(delta)
	_update_ammo_pickups(delta)
	_refresh_mobile_context_button()
	_update_firing(delta)
	_update_aim_feedback(delta)
	_update_camera_occluders(delta)
	_update_player_combat_feedback(delta)
	_update_camera_follow(delta)
	_update_building_overlays()
	_update_visibility_fog()
	_update_enemy_visibility(delta)
	_update_stealth_takedown_prompt()
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


func _uses_mouse_aim() -> bool:
	return not DisplayServer.is_touchscreen_available()


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
	_update_weapon_pose()


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
	_update_weapon_pose()


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
	var attack_direction := _get_mouse_world_direction() if _uses_mouse_aim() else _get_current_facing_world_direction()
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


func _try_stealth_takedown() -> bool:
	if (
		melee_attack_cooldown > 0.0
		or melee_attack_active
		or roll_active
		or loafing
		or player_health <= 0
	):
		return false
	var takedown_target := _find_stealth_takedown_target()
	if not is_instance_valid(takedown_target):
		return false
	var attack_direction := takedown_target.global_position - player.global_position
	attack_direction.y = 0.0
	if attack_direction.length_squared() <= 0.01:
		return false
	attack_direction = attack_direction.normalized()
	if not bool(takedown_target.call(
		"receive_stealth_takedown",
		player.global_position,
		attack_direction
	)):
		return false
	_play_stealth_takedown_impact()
	melee_attack_cooldown = MELEE_ATTACK_COOLDOWN
	_add_fatigue(FATIGUE_MELEE_GAIN * 0.65)
	_lock_aim_direction(attack_direction)
	_set_facing_from_world_direction(attack_direction)
	melee_attack_active = true
	melee_attack_elapsed = 0.0
	melee_attack_direction = attack_direction
	melee_hit_resolved = true
	motion_state = "melee"
	_play_directional_animation()
	_play_bat_swing(attack_direction)
	_spawn_player_melee_arc(attack_direction)
	nearby_stealth_takedown_target = null
	if stealth_takedown_prompt:
		stealth_takedown_prompt.visible = false
	state_label.text = "기습 암살"
	return true


func _play_stealth_takedown_impact() -> void:
	camera_shake_time = maxf(camera_shake_time, STEALTH_TAKEDOWN_CAMERA_SHAKE_SECONDS)
	camera_shake_strength = maxf(camera_shake_strength, STEALTH_TAKEDOWN_CAMERA_SHAKE_STRENGTH)
	hit_stop_serial += 1
	var serial := hit_stop_serial
	Engine.time_scale = STEALTH_TAKEDOWN_TIME_SCALE
	get_tree().create_timer(
		STEALTH_TAKEDOWN_SLOWMO_SECONDS,
		true,
		false,
		true
	).timeout.connect(func() -> void:
		if serial == hit_stop_serial and not player_death_sequence_active:
			Engine.time_scale = 1.0
	)


func _find_stealth_takedown_target() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var nearest_distance := STEALTH_TAKEDOWN_RANGE
	for enemy in enemies:
		if (
			not is_instance_valid(enemy)
			or not enemy.has_method("can_receive_stealth_takedown")
			or not bool(enemy.call(
				"can_receive_stealth_takedown",
				player.global_position,
				STEALTH_TAKEDOWN_RANGE
			))
		):
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > nearest_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0.0, 0.42, 0.0),
			enemy.global_position + Vector3(0.0, 0.42, 0.0),
			COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
		)
		query.exclude = [player.get_rid(), enemy.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest


func _update_stealth_takedown_prompt() -> void:
	if stealth_takedown_prompt == null:
		return
	var blocked := (
		player_death_sequence_active
		or melee_attack_active
		or roll_active
		or loafing
		or _is_inventory_open()
		or _is_tactical_map_open()
		or lore_reader.is_open()
		or extraction_transition_active
	)
	nearby_stealth_takedown_target = null if blocked else _find_stealth_takedown_target()
	stealth_takedown_prompt.visible = is_instance_valid(nearby_stealth_takedown_target)
	if hud.melee_button and DisplayServer.is_touchscreen_available():
		hud.melee_button.text = "암살" if stealth_takedown_prompt.visible else "근접"
	if not stealth_takedown_prompt.visible:
		return
	var target_screen := camera.unproject_position(
		nearby_stealth_takedown_target.global_position + Vector3(0.0, 2.15, 0.0)
	)
	var viewport_size := get_viewport().get_visible_rect().size
	var prompt_position := target_screen + Vector2(
		-STEALTH_TAKEDOWN_PROMPT_SIZE.x * 0.5,
		-78.0
	)
	prompt_position.x = clampf(
		prompt_position.x,
		12.0,
		maxf(12.0, viewport_size.x - STEALTH_TAKEDOWN_PROMPT_SIZE.x - 12.0)
	)
	prompt_position.y = clampf(
		prompt_position.y,
		12.0,
		maxf(12.0, viewport_size.y - STEALTH_TAKEDOWN_PROMPT_SIZE.y - 12.0)
	)
	stealth_takedown_prompt.position = prompt_position
	stealth_takedown_prompt.size = STEALTH_TAKEDOWN_PROMPT_SIZE


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
	_update_weapon_pose()


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
		var fallback_direction := _get_mouse_world_direction() if _uses_mouse_aim() else _get_current_facing_world_direction()
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


func _update_weapon_ballistics(delta: float, is_moving: bool) -> void:
	if weapon_stats.is_empty():
		return
	recoil_velocity = recoil_velocity.move_toward(Vector3.ZERO, 8.5 * delta)
	var target_spread := float(weapon_stats.get("base_spread_deg", 2.4))
	if is_moving:
		target_spread *= float(weapon_stats.get("moving_spread_multiplier", 1.0))
	if player_health <= 45:
		target_spread *= float(weapon_stats.get("injured_spread_multiplier", 1.0))
	if loafing:
		target_spread *= float(weapon_stats.get("loaf_spread_multiplier", 1.0))
	var durability_penalty := 1.0 + clampf((50.0 - weapon_durability) / 50.0, 0.0, 1.0) * 0.7
	target_spread *= durability_penalty
	var recovery := float(weapon_stats.get("spread_recovery_deg", 5.0))
	weapon_spread_deg = move_toward(weapon_spread_deg, target_spread, recovery * delta)
	weapon_spread_deg = clampf(weapon_spread_deg, 0.2, float(weapon_stats.get("max_spread_deg", 14.0)))
	if weapon_reloading:
		reload_timer = maxf(0.0, reload_timer - delta)
		if hud.equipment_reload_bar:
			var reload_duration := maxf(0.01, float(weapon_stats.get("reload_time", 2.15)))
			hud.equipment_reload_bar.value = 1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
		if hud.equipment_condition_label:
			var reload_ammo_name := str(
				WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get(
					"display_name",
					GameState.equipped_ammo_id
				)
			)
			hud.equipment_condition_label.text = "재장전 %.1f초 · 사용 탄환  %s" % [
				reload_timer,
				reload_ammo_name,
			]
		if reload_timer <= 0.0:
			_finish_reload()


func _update_aim_feedback(delta: float) -> void:
	if hud.aim_direction_indicator == null:
		return
	var aim_direction := _get_mouse_world_direction() if _uses_mouse_aim() else _get_current_facing_world_direction()
	hud.aim_direction_indicator.look_at(hud.aim_direction_indicator.global_position + aim_direction, Vector3.UP)
	recoil_reticle_offset = recoil_reticle_offset.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	_update_laser_beam(aim_direction)
	if hud.aim_reticle:
		hud.aim_reticle.visible = (
			_uses_mouse_aim()
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
			and _uses_mouse_aim()
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
	var should_show := laser_aim_held and has_ak and _uses_mouse_aim()
	for layer in laser_glow_layers:
		layer.visible = should_show
	if hud.laser_endpoint:
		hud.laser_endpoint.visible = should_show
	if not should_show:
		return
	var start := _get_weapon_muzzle_position(aim_direction)
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
	boss_alert_panel.visible = true
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
		if boss_alert_panel:
			boss_alert_panel.visible = false
	)


func _trigger_fatigue_boss_event() -> void:
	if fatigue_boss_event_triggered or fatigue < FATIGUE_BOSS_TRIGGER:
		return
	var boss: CharacterBody3D
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			boss = enemy
			break
	if boss == null:
		var spawn_position := _find_reinforcement_position()
		if spawn_position == Vector3.INF:
			return
		boss = _spawn_rocket_boss_at(
			spawn_position,
			maxf(0.45, float(raid_zone_data.get("threat", 0.0))),
			"FatigueBoss_%d" % Time.get_ticks_msec()
		)
	var marker := boss.get_node_or_null("BossMarker") as Label3D
	if marker:
		marker.text = FATIGUE_BOSS_NAME
	boss.set_meta("display_name", FATIGUE_BOSS_NAME)
	fatigue_boss_event_triggered = true
	_show_boss_alert(FATIGUE_BOSS_NAME)
	if GameState.subway_story_stage == 1:
		_show_field_notice("연속 임무 갱신 · 포격 신호의 주인을 처치하십시오.")


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
	GameState.secure_dog_items.clear()
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
		GameState.register_shelter_return()
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
	_add_loot_highlight(ak_pickup, Color("#dfb94f"), 1.05)


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
		var pickup := _create_loot_pickup(
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


func _create_loot_pickup(loot_type: String, world_position: Vector3, data: Dictionary = {}) -> Node3D:
	var pickup := Node3D.new()
	pickup.name = "Loot_%s_%d" % [loot_type, Time.get_ticks_usec()]
	add_child(pickup)
	pickup.global_position = Vector3(world_position.x, 0.34, world_position.z)
	pickup.set_meta("base_y", pickup.position.y)
	pickup.set_meta("loot_type", loot_type)
	for key in data:
		pickup.set_meta(str(key), data[key])

	var sprite := Sprite3D.new()
	sprite.name = "LootSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 88
	var highlight_color := Color("#f2d27a")
	match loot_type:
		"canned_food":
			sprite.texture = _get_canned_food_texture()
			sprite.pixel_size = 0.0062
			highlight_color = Color("#83c99a")
		"churu":
			sprite.texture = CHURU_TEXTURE
			sprite.pixel_size = 0.0011
			highlight_color = Color("#f2bd55")
		"raw_scrap":
			sprite.texture = UI_ICONS.get_icon("scrap", 96, Color("#b9a68c"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.62)
			highlight_color = Color("#b9a68c")
		"raw_catnip":
			sprite.texture = UI_ICONS.get_icon("catnip", 96, Color("#8fd07a"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.62)
			highlight_color = Color("#8fd07a")
		"valuable":
			sprite.texture = UI_ICONS.get_icon("loot", 96, Color("#e6c979"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.58)
			highlight_color = Color("#e6c979")
		"medkit":
			sprite.texture = UI_ICONS.get_icon("medkit", 96, Color("#f4eee2"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.62)
			highlight_color = Color("#f2b16a")
		"mod_component":
			var component_id := str(data.get("component_id", "rubber_gasket"))
			sprite.texture = _get_mod_component_texture(component_id)
			sprite.pixel_size = 0.00105
			highlight_color = _get_mod_component_color(component_id)
		"weapon_mod":
			sprite.texture = UI_ICONS.get_icon("mod", 96, Color("#dfc879"))
			sprite.pixel_size = 0.0062
			highlight_color = Color("#dfc879")
		"progression_item":
			var progression_item_id := str(data.get("progression_item_id", "rifle_blueprint"))
			var icon_name := "secure" if progression_item_id == "sealed_zone_keycard" else "craft"
			sprite.texture = UI_ICONS.get_icon(icon_name, 96, Color("#e7c96f"))
			sprite.pixel_size = 0.0062
			highlight_color = Color("#e7c96f")
		"weapon":
			var weapon_id := str(data.get("weapon_id", "ak47"))
			sprite.texture = _get_loot_weapon_texture(weapon_id)
			sprite.pixel_size = _loot_weapon_pixel_size(sprite.texture, weapon_id)
			highlight_color = Color("#df8f55")
		"armor":
			var equipment_id := str(data.get("equipment_id", "scav_vest"))
			var definition := GameState.get_equipment_definition(equipment_id)
			var slot := str(definition.get("slot", "body"))
			sprite.texture = _get_equipment_loot_texture(equipment_id)
			var target_long_edge := 0.7 if slot == "head" else 0.84
			var texture_long_edge := float(maxi(sprite.texture.get_width(), sprite.texture.get_height()))
			sprite.pixel_size = target_long_edge / maxf(texture_long_edge, 1.0)
			highlight_color = Color("#8bb9a4")
		_:
			sprite.texture = AMMO_762_TEXTURE
			sprite.pixel_size = 0.0032
	pickup.add_child(sprite)
	_add_loot_highlight(pickup, highlight_color, 0.92)
	ammo_pickups.append(pickup)
	return pickup


func _pickup_pixel_size(texture: Texture2D, target_world_size: float) -> float:
	# UI_ICONS.get_icon()은 커런시/아이템 아이콘에 대해 size 인자를 무시하고
	# 원본 해상도(예: 1254px)를 그대로 돌려준다. 고정 pixel_size를 쓰면
	# 아트 해상도에 따라 픽업이 건물만 해진다. 목표 월드 크기로 역산한다.
	if texture == null:
		return 0.0062
	var long_edge := float(maxi(texture.get_width(), texture.get_height()))
	return target_world_size / maxf(long_edge, 1.0)


func _loot_weapon_pixel_size(texture: Texture2D, weapon_id: String) -> float:
	if texture == null:
		return 0.001
	var target_long_edge := 1.25
	match weapon_id:
		"m1911":
			target_long_edge = 0.72
		"mp5":
			target_long_edge = 1.1
		"double_barrel":
			target_long_edge = 1.3
	var texture_long_edge := float(maxi(texture.get_width(), texture.get_height()))
	return target_long_edge / maxf(texture_long_edge, 1.0)


func _get_canned_food_texture() -> ImageTexture:
	if canned_food_texture != null:
		return canned_food_texture
	var image := Image.create(72, 88, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(18, 12, 36, 64), Color("#26302d"))
	image.fill_rect(Rect2i(21, 15, 30, 58), Color("#71806d"))
	image.fill_rect(Rect2i(17, 12, 38, 8), Color("#b8b8aa"))
	image.fill_rect(Rect2i(17, 68, 38, 8), Color("#8b8d84"))
	image.fill_rect(Rect2i(23, 31, 26, 28), Color("#8e3f32"))
	image.fill_rect(Rect2i(27, 36, 18, 5), Color("#e0c77c"))
	image.fill_rect(Rect2i(27, 46, 18, 8), Color("#d5a953"))
	image.fill_rect(Rect2i(24, 18, 4, 47), Color(1.0, 1.0, 0.9, 0.2))
	canned_food_texture = ImageTexture.create_from_image(image)
	return canned_food_texture


func _get_loot_weapon_texture(weapon_id: String) -> Texture2D:
	var catalog_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	if catalog_texture != null:
		return catalog_texture
	if weapon_loot_texture_cache.has(weapon_id):
		return weapon_loot_texture_cache[weapon_id]
	var image := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("#171b1c")
	match weapon_id:
		"m1911":
			image.fill_rect(Rect2i(26, 20, 77, 19), outline)
			image.fill_rect(Rect2i(31, 24, 68, 11), Color("#8f9895"))
			image.fill_rect(Rect2i(65, 35, 23, 25), outline)
			image.fill_rect(Rect2i(69, 37, 15, 19), Color("#76503d"))
		"mp5":
			image.fill_rect(Rect2i(16, 24, 101, 17), outline)
			image.fill_rect(Rect2i(22, 28, 88, 9), Color("#4d5654"))
			image.fill_rect(Rect2i(62, 38, 18, 24), outline)
			image.fill_rect(Rect2i(84, 38, 14, 17), outline)
		"double_barrel":
			image.fill_rect(Rect2i(47, 19, 75, 7), outline)
			image.fill_rect(Rect2i(47, 29, 75, 7), outline)
			image.fill_rect(Rect2i(51, 21, 68, 3), Color("#a3aaa4"))
			image.fill_rect(Rect2i(51, 31, 68, 3), Color("#7d8580"))
			image.fill_rect(Rect2i(10, 27, 43, 18), outline)
			image.fill_rect(Rect2i(15, 30, 34, 11), Color("#7d4e35"))
		_:
			return AK_DROP_TEXTURE
	var texture := ImageTexture.create_from_image(image)
	weapon_loot_texture_cache[weapon_id] = texture
	return texture


func _get_equipment_loot_texture(equipment_id: String) -> Texture2D:
	var definition := GameState.get_equipment_definition(equipment_id)
	var texture_path := str(definition.get("texture_path", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var texture := load(texture_path) as Texture2D
		if texture != null:
			return texture
	var slot := str(definition.get("slot", "body"))
	return UI_ICONS.get_icon(
		"helmet" if slot == "head" else "armor",
		96,
		Color("#b7c8bd")
	)


func _update_ammo_pickups(delta: float) -> void:
	ammo_notice_time = maxf(0.0, ammo_notice_time - delta)
	ammo_pickup_chain_time = maxf(0.0, ammo_pickup_chain_time - delta)
	if ammo_pickup_chain_time <= 0.0:
		ammo_pickup_chain_total = 0
	if hud.ammo_notice and ammo_notice_time <= 0.0:
		hud.ammo_notice.visible = false
	var player_ground := Vector2(player.position.x, player.position.z)
	var nearest_distance := INF
	nearby_ammo_pickup = null
	for pickup in ammo_pickups.duplicate():
		if not is_instance_valid(pickup):
			ammo_pickups.erase(pickup)
			continue
		var base_y := float(pickup.get_meta("base_y", 0.3))
		pickup.position.y = base_y + sin(Time.get_ticks_msec() * 0.004 + pickup.position.x) * 0.04
		var pickup_ground := Vector2(pickup.position.x, pickup.position.z)
		var distance := player_ground.distance_to(pickup_ground)
		_update_loot_highlight(pickup, distance, delta)
		if distance <= PICKUP_DISTANCE and distance < nearest_distance:
			nearest_distance = distance
			nearby_ammo_pickup = pickup
	if hud.ammo_prompt_panel:
		hud.ammo_prompt_panel.visible = (
			is_instance_valid(nearby_ammo_pickup)
			and not is_instance_valid(nearby_field_interaction)
		)
	if hud.ammo_pickup_button and is_instance_valid(nearby_ammo_pickup):
		hud.ammo_pickup_button.text = "%s  [F]" % str(nearby_ammo_pickup.get_meta("display_name", "Ammo"))


func _collect_nearby_ammo() -> void:
	if not is_instance_valid(nearby_ammo_pickup):
		return
	var candidate := _build_pickup_candidate(nearby_ammo_pickup)
	if not GameState.can_add_raid_item(
		str(candidate.get("type", "")),
		str(candidate.get("id", "")),
		int(candidate.get("amount", 1))
	):
		_show_bag_full_notice()
		return
	hud.ammo_notice.add_theme_color_override("font_color", Color("#f2d27a"))
	_add_fatigue(FATIGUE_LOOT_GAIN)
	var loot_type := str(nearby_ammo_pickup.get_meta("loot_type", "ammo"))
	var amount := int(nearby_ammo_pickup.get_meta("amount", 1))
	match loot_type:
		"canned_food":
			GameState.canned_food += amount
			hud.ammo_notice.text = "통조림 +%d   보유 %d" % [amount, GameState.canned_food]
		"churu":
			GameState.churu += amount
			hud.ammo_notice.text = "희귀 츄르 +%d   보유 %d" % [amount, GameState.churu]
		"medkit":
			GameState.medkits += amount
			hud.ammo_notice.text = "구급약 +%d   보유 %d" % [amount, GameState.medkits]
		"mod_component":
			var component_id := str(nearby_ammo_pickup.get_meta("component_id", "rubber_gasket"))
			GameState.add_mod_component(component_id, amount)
			_advance_basic_mission("parts", amount)
			_advance_contract_progress("parts", amount)
			hud.ammo_notice.text = "%s +%d   보유 %d" % [
				str(nearby_ammo_pickup.get_meta("display_name", "총기 부품")),
				amount,
				GameState.get_mod_component_count(component_id),
			]
		"weapon_mod":
			var weapon_mod_id := str(nearby_ammo_pickup.get_meta("weapon_mod_id", "scope_2x"))
			GameState.add_weapon_mod(weapon_mod_id, amount)
			hud.ammo_notice.text = "%s +%d" % [
				_raid_item_display_name("mod", weapon_mod_id),
				amount,
			]
		"progression_item":
			var progression_item_id := str(
				nearby_ammo_pickup.get_meta("progression_item_id", "rifle_blueprint")
			)
			GameState.add_progression_item(progression_item_id, amount)
			hud.ammo_notice.text = "%s 획득" % str(
				nearby_ammo_pickup.get_meta("display_name", "진행도 아이템")
			)
		"weapon":
			var weapon_id := str(nearby_ammo_pickup.get_meta("weapon_id", "ak47"))
			GameState.add_weapon(weapon_id, amount)
			hud.ammo_notice.text = "%s 보관 +%d" % [
				str(nearby_ammo_pickup.get_meta("display_name", "무기")),
				amount,
			]
		"armor":
			var equipment_id := str(nearby_ammo_pickup.get_meta("equipment_id", "scav_vest"))
			if GameState.add_equipment(equipment_id, amount):
				var definition := GameState.get_equipment_definition(equipment_id)
				hud.ammo_notice.text = "%s 획득 · 가방에서 장착" % str(definition.get("display_name", "방어구"))
			else:
				hud.ammo_notice.text = "장비 정보를 확인할 수 없습니다."
		_:
			var pickup_ammo_id := str(nearby_ammo_pickup.get_meta("ammo_id", "762_fmj"))
			var updated_ammo_count: int = GameState.get_ammo_count(pickup_ammo_id) + amount
			GameState.set_ammo_count(pickup_ammo_id, updated_ammo_count)
			if GameState.equipped_ammo_id == pickup_ammo_id:
				reserve_ammo = updated_ammo_count
			GameState.reserve_ammo = reserve_ammo
			if ammo_pickup_chain_time <= 0.0:
				ammo_pickup_chain_total = 0
			ammo_pickup_chain_total += amount
			ammo_pickup_chain_time = 2.4
			hud.ammo_notice.text = "+%d %s   보유 %d" % [
				amount,
				str(nearby_ammo_pickup.get_meta("display_name", "탄약")),
				updated_ammo_count,
			]
	hud.ammo_notice.visible = true
	ammo_notice_time = 2.2
	_update_equipment_ui()
	_update_medkit_button()
	ammo_pickups.erase(nearby_ammo_pickup)
	nearby_ammo_pickup.queue_free()
	nearby_ammo_pickup = null
	hud.ammo_prompt_panel.visible = false


func _show_bag_full_notice() -> void:
	if hud.ammo_notice:
		hud.ammo_notice.text = "가방이 꽉 찼습니다."
		hud.ammo_notice.add_theme_color_override("font_color", Color("#ffad8f"))
		hud.ammo_notice.visible = true
		ammo_notice_time = 2.0
	# 처음 가방이 찬 순간이 이 게임의 핵심을 가르칠 유일한 자리다.
	# 조작이 아니라 "무엇을 버릴 것인가"를 가르쳐야 한다.
	if not GameState.bag_pressure_lesson_seen:
		GameState.bag_pressure_lesson_seen = true
		GameState.save_persistent_state()
		_show_field_notice(
			"가방은 여기까지다.\n"
			+ "이제부터는 줍는 게 아니라 고르는 일이다. "
			+ "칸당 가치가 낮은 물건을 버리고 비싼 것을 실어라.\n"
			+ "살아서 나가야 내 것이 된다."
		)
	_update_equipment_ui()


func _build_pickup_candidate(pickup: Node3D) -> Dictionary:
	var loot_type := str(pickup.get_meta("loot_type", "ammo"))
	var amount := maxi(1, int(pickup.get_meta("amount", 1)))
	var item_type := "ammo"
	var item_id := str(pickup.get_meta("ammo_id", "762_fmj"))
	match loot_type:
		"canned_food":
			item_type = "food"
			item_id = "canned_food"
		"churu":
			item_type = "churu"
			item_id = "churu"
		"raw_scrap":
			item_type = "raw_scrap"
			item_id = "raw_scrap"
		"raw_catnip":
			item_type = "raw_catnip"
			item_id = "raw_catnip"
		"valuable":
			item_type = "valuable"
			item_id = str(pickup.get_meta("item_id", "subway_token"))
		"medkit":
			item_type = "medkit"
			item_id = "medkit"
		"mod_component":
			item_type = "component"
			item_id = str(pickup.get_meta("component_id", "rubber_gasket"))
		"weapon_mod":
			item_type = "mod"
			item_id = str(pickup.get_meta("weapon_mod_id", "scope_2x"))
		"progression_item":
			item_type = "progression"
			item_id = str(pickup.get_meta("progression_item_id", "rifle_blueprint"))
		"weapon":
			item_type = "weapon"
			item_id = str(pickup.get_meta("weapon_id", "ak47"))
		"armor":
			item_type = "equipment"
			item_id = str(pickup.get_meta("equipment_id", "scav_vest"))
	var required := GameState.get_raid_item_added_slot_delta(item_type, item_id, amount)
	var display_slots := maxi(1, required)
	var total_value := RAID_ITEM_ECONOMY.get_total_value(
		item_type,
		item_id,
		amount,
		GameState.raid_special_cargo
	)
	return {
		"type": item_type,
		"id": item_id,
		"amount": amount,
		"title": str(pickup.get_meta("display_name", _raid_item_display_name(item_type, item_id))),
		"description": _raid_item_description(item_type, item_id),
		"texture": _raid_item_texture(item_type, item_id),
		"required_slots": required,
		"display_slots": display_slots,
		"total_value": total_value,
		"value_per_slot": float(total_value) / float(display_slots),
		"protected": RAID_ITEM_ECONOMY.is_protected(item_type, item_id),
	}


func _spawn_discarded_raid_item(item_type: String, item_id: String, amount: int) -> void:
	var drop_position := player.global_position + _get_current_facing_world_direction() * 1.25
	var loot_type := "ammo"
	var data := {
		"amount": amount,
		"display_name": _raid_item_display_name(item_type, item_id),
	}
	match item_type:
		"weapon":
			loot_type = "weapon"
			data["weapon_id"] = item_id
		"equipment":
			loot_type = "armor"
			data["equipment_id"] = item_id
		"ammo":
			data["ammo_id"] = item_id
		"component":
			loot_type = "mod_component"
			data["component_id"] = item_id
		"progression":
			loot_type = "progression_item"
			data["progression_item_id"] = item_id
		"medkit":
			loot_type = "medkit"
		"food":
			loot_type = "canned_food"
		"churu":
			loot_type = "churu"
		"raw_scrap":
			loot_type = "raw_scrap"
		"raw_catnip":
			loot_type = "raw_catnip"
		"valuable":
			loot_type = "valuable"
			data["item_id"] = item_id
		"mod":
			loot_type = "weapon_mod"
			data["weapon_mod_id"] = item_id
	_create_loot_pickup(loot_type, drop_position, data)


func _raid_item_display_name(item_type: String, item_id: String) -> String:
	if item_type == "special_cargo":
		return str(GameState.raid_special_cargo.get("title", "봉인된 지하철 화물"))
	if item_type == "weapon":
		return str(WEAPON_SYSTEM.get_weapon(item_id).get("display_name", item_id))
	if item_type == "equipment":
		return str(GameState.get_equipment_definition(item_id).get("display_name", item_id))
	if item_type == "mod":
		return str(WEAPON_SYSTEM.get_mod(item_id).get("display_name", item_id))
	if item_type == "valuable":
		# 귀중품은 종류가 많다. 이름은 카탈로그가 단일 진실 원천이다.
		return str(
			(LOOT_ECONOMY.ITEM_CATALOG.get(item_id, {}) as Dictionary).get("display_name", item_id)
		)
	var names := {
		"9mm_fmj": "9mm FMJ 탄환",
		"45_fmj": ".45 ACP FMJ 탄환",
		"762_fmj": "7.62mm FMJ 탄환",
		"12g_buckshot": "12게이지 벅샷",
		"9mm_ap": "9mm AP 탄환",
		"45_ap": ".45 ACP AP 탄환",
		"762_ap": "7.62mm AP 탄환",
		"12g_slug": "12게이지 슬러그",
		"rubber_gasket": "소음기용 고무 패킹",
		"scope_lens": "스코프 렌즈",
		"magazine_spring": "탄창 스프링",
		"canned_food": "통조림",
		"medkit": "구급약",
		"churu": "희귀 츄르",
		"raw_scrap": "고철 조각",
		"raw_catnip": "캣닢 잎",
		"rifle_blueprint": "소총 제작 청사진",
		"shotgun_blueprint": "산탄총 제작 청사진",
		"sealed_zone_keycard": "봉인구역 키카드",
	}
	return str(names.get(item_id, item_id))


func _raid_item_description(item_type: String, item_id: String) -> String:
	match item_type:
		"weapon":
			return "주무기로 장착하거나 쉘터에서 보관·판매할 수 있습니다."
		"equipment":
			return str(GameState.get_equipment_definition(item_id).get("description", "방어 장비입니다."))
		"ammo":
			return "구경이 맞는 총기에 사용하는 실탄입니다."
		"component", "mod":
			return "작업대 제작과 총기 개조에 사용하는 부품입니다."
		"progression":
			return "상위 제작과 봉인구역 진입에 필요한 희귀 물품입니다."
		"food":
			return "주민이 일하려면 먹어야 합니다. 떨어지면 쉘터 생산이 멈춥니다."
		"churu":
			return "쉘터 확장에 쓰이는 희귀 재화입니다."
		"raw_scrap":
			return "꾹꾹이 라인의 원료입니다. 부피가 커서 10개마다 가방 한 칸을 차지합니다."
		"raw_catnip":
			return "캣닢 정제기의 원료입니다. 부피가 커서 10개마다 가방 한 칸을 차지합니다."
		"valuable":
			return "쓸 데는 없지만 값이 나갑니다. 쉘터에서 고철로 바꿉니다."
		"medkit":
			return "필드에서 체력을 회복하는 응급 치료품입니다."
	return "레이드에서 확보한 휴대품입니다."


func _raid_item_texture(item_type: String, item_id: String) -> Texture2D:
	match item_type:
		"weapon":
			return WEAPON_VISUAL_CATALOG.get_weapon_texture(item_id)
		"equipment":
			return _get_equipment_loot_texture(item_id)
		"component":
			return _get_mod_component_texture(item_id)
		"special_cargo":
			return SUBWAY_SEALED_CARGO_TEXTURE
		"food":
			return _get_canned_food_texture()
		"churu":
			return CHURU_TEXTURE
		"medkit":
			return UI_ICONS.get_icon("medkit", 96, Color("#f4eee2"))
		"raw_scrap":
			return UI_ICONS.get_icon("scrap", 96, Color("#b9a68c"))
		"raw_catnip":
			return UI_ICONS.get_icon("catnip", 96, Color("#8fd07a"))
		"valuable":
			return UI_ICONS.get_icon("loot", 96, Color("#e6c979"))
		"progression":
			return UI_ICONS.get_icon("secure", 96, Color("#e7c96f"))
		"mod":
			return UI_ICONS.get_icon("parts", 96, Color("#d6bf82"))
	return AMMO_762_TEXTURE


func _get_mod_component_texture(component_id: String) -> Texture2D:
	match component_id:
		"scope_lens": return SCOPE_LENS_TEXTURE
		"magazine_spring": return MAGAZINE_SPRING_TEXTURE
		_: return RUBBER_GASKET_TEXTURE


func _get_mod_component_color(component_id: String) -> Color:
	match component_id:
		"scope_lens": return Color("#65c5d7")
		"magazine_spring": return Color("#b4b9ae")
		_: return Color("#d1aa64")


func _add_loot_highlight(pickup: Node3D, color: Color, radius: float) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.34)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.88
	ring_mesh.outer_radius = radius
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.name = "LootRing"
	ring.position.y = -0.26
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pickup.add_child(ring)

	var marker := Sprite3D.new()
	marker.name = "LootMarker"
	marker.texture = _get_loot_glow_texture()
	marker.position.y = 1.1
	marker.pixel_size = 0.006
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.transparent = true
	marker.no_depth_test = true
	marker.render_priority = 120
	marker.modulate = color
	pickup.add_child(marker)


func _update_loot_highlight(pickup: Node3D, distance: float, _delta: float) -> void:
	var ring := pickup.get_node_or_null("LootRing") as MeshInstance3D
	var marker := pickup.get_node_or_null("LootMarker") as Sprite3D
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + pickup.position.x)
	var near_boost := 1.0 if distance > PICKUP_DISTANCE else 1.28
	if ring:
		var scale_value := near_boost * (1.0 + pulse * 0.16)
		ring.scale = Vector3(scale_value, scale_value, scale_value)
	if marker:
		marker.position.y = 1.05 + pulse * 0.18
		var color := marker.modulate
		color.a = 0.58 + pulse * 0.36
		marker.modulate = color


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


func _apply_hud_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var touch_available := DisplayServer.is_touchscreen_available()
	var safe_margins := UI_SAFE_AREA.get_margins(viewport_size)
	var ui_scale := clampf(
		minf(viewport_size.x / 1360.0, viewport_size.y / 780.0)
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

	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.offset_left = side_margin
	objective_panel.offset_top = (
		top_left_status_panel.offset_bottom + 6.0
		if top_left_status_panel.visible
		else top_margin
	)
	objective_panel.offset_right = side_margin + safe_left_width
	objective_panel.offset_bottom = objective_panel.offset_top + objective_height

	var top_right_panel := get_node_or_null("HUD/TopRight") as VBoxContainer
	if top_right_panel != null:
		var status_width := clampf(minf(viewport_size.x * 0.28, 360.0), 180.0, 360.0)
		top_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		top_right_panel.offset_left = -side_margin - status_width
		top_right_panel.offset_top = top_margin
		top_right_panel.offset_right = -side_margin
		top_right_panel.offset_bottom = top_margin + 88.0

	# 손가락 기준으로 키운다. 예전 최소 126px는 폰에서 너무 작았다.
	var touch_stick_size := clampf(minf(viewport_size.x, viewport_size.y) * 0.30, 168.0, 260.0)
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
		var panel_h := clampf(72.0 * ui_scale, 68.0, 86.0)
		hud.pickup_panel.offset_left = -panel_w * 0.5
		hud.pickup_panel.offset_right = panel_w * 0.5
		hud.pickup_panel.offset_bottom = -maxf(bottom_margin + 118.0, viewport_size.y * 0.18)
		hud.pickup_panel.offset_top = hud.pickup_panel.offset_bottom - panel_h
		var pickup_button := hud.pickup_panel.get_node_or_null("VBoxContainer/Button") as Button
		var pickup_progress_bar := hud.pickup_panel.get_node_or_null("VBoxContainer/ProgressBar") as ProgressBar
		if pickup_button != null:
			pickup_button.custom_minimum_size = Vector2(maxf(250.0, panel_w - 24.0), 40.0)
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

	if hud.fatigue_panel:
		var fatigue_w := minf(300.0, maxf(230.0, viewport_size.x * 0.22))
		var fatigue_h := 72.0 if fatigue >= 35.0 else 50.0
		hud.fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hud.fatigue_panel.offset_left = side_margin
		hud.fatigue_panel.offset_top = objective_panel.offset_bottom + 8.0 if objective_panel.visible else top_margin
		hud.fatigue_panel.offset_right = side_margin + fatigue_w
		hud.fatigue_panel.offset_bottom = hud.fatigue_panel.offset_top + fatigue_h

	if hud.raid_pressure_panel:
		hud.raid_pressure_panel.visible = false
	if hud.jackpot_hud:
		var objective_width := clampf(viewport_size.x * 0.38, 310.0, 430.0)
		var jackpot_objective_height := clampf(62.0 * ui_scale, 58.0, 68.0)
		hud.jackpot_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
		hud.jackpot_hud.offset_left = -objective_width * 0.5
		hud.jackpot_hud.offset_top = top_margin
		hud.jackpot_hud.offset_right = objective_width * 0.5
		hud.jackpot_hud.offset_bottom = top_margin + jackpot_objective_height
		hud.jackpot_hud.visible = not hud_blocked
	if hud.dynamic_incident_hud:
		var incident_width := clampf(viewport_size.x * 0.46, 330.0, 500.0)
		hud.dynamic_incident_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
		hud.dynamic_incident_hud.offset_left = -incident_width * 0.5
		hud.dynamic_incident_hud.offset_top = top_margin + 72.0
		hud.dynamic_incident_hud.offset_right = incident_width * 0.5
		hud.dynamic_incident_hud.offset_bottom = top_margin + 148.0
		hud.dynamic_incident_hud.visible = (
			dynamic_incident_state == "active"
			and not hud_blocked
		)

	var action_button_size := clampf(minf(viewport_size.y * 0.17, 132.0), 96.0, 128.0)
	if hud.equipment_panel:
		var eq_width := minf(360.0, maxf(250.0, viewport_size.x * 0.28))
		var eq_height := clampf(viewport_size.y * 0.21, 108.0, 190.0)
		hud.equipment_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hud.equipment_panel.offset_right = -side_margin
		hud.equipment_panel.offset_left = -side_margin - eq_width
		if touch_available:
			# 터치 환경에서는 우하단이 사격/근접/대시 버튼과 그 위 유틸리티 줄의
			# 자리다. 무기 정보를 같은 코너에 두면 반드시 겹친다.
			# 버튼 두 줄 위로 올린다.
			var utility_row := clampf(action_button_size * 0.84, 60.0, 92.0)
			var stack_height := (
				action_button_size + utility_row + clampf(13.0 * ui_scale, 8.0, 16.0) + 10.0
			)
			hud.equipment_panel.offset_bottom = -bottom_margin - stack_height
			eq_height = minf(eq_height, maxf(72.0, viewport_size.y - stack_height - top_margin - 80.0))
		else:
			hud.equipment_panel.offset_bottom = -bottom_margin
		hud.equipment_panel.offset_top = hud.equipment_panel.offset_bottom - eq_height
		hud.equipment_panel.visible = not hud_blocked

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

	var utility_size := clampf(action_button_size * 0.78, 76.0, 104.0)
	var utility_base_bottom := -bottom_margin - action_button_size - clampf(13.0 * ui_scale, 8.0, 16.0)
	var utility_gap := clampf(10.0 * ui_scale, 6.0, 12.0)
	if mobile_context_button:
		mobile_context_button.visible = touch_available and not hud_blocked
		mobile_context_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mobile_context_button.offset_right = -side_margin
		mobile_context_button.offset_left = mobile_context_button.offset_right - utility_size
		mobile_context_button.offset_bottom = utility_base_bottom
		mobile_context_button.offset_top = utility_base_bottom - utility_size
		mobile_context_button.custom_minimum_size = Vector2(utility_size, utility_size)
	if mobile_reload_button:
		mobile_reload_button.visible = touch_available and not hud_blocked
		mobile_reload_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mobile_reload_button.offset_right = mobile_context_button.offset_left - utility_gap if mobile_context_button else -side_margin - utility_size - utility_gap
		mobile_reload_button.offset_left = mobile_reload_button.offset_right - utility_size
		mobile_reload_button.offset_bottom = utility_base_bottom
		mobile_reload_button.offset_top = utility_base_bottom - utility_size
		mobile_reload_button.custom_minimum_size = Vector2(utility_size, utility_size)
	if mobile_flashlight_button:
		mobile_flashlight_button.visible = touch_available and not hud_blocked
		mobile_flashlight_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mobile_flashlight_button.offset_right = (mobile_reload_button.offset_left - utility_gap if mobile_reload_button else -side_margin - utility_size * 2.0) if mobile_reload_button else -side_margin - utility_size * 2.0
		mobile_flashlight_button.offset_left = mobile_flashlight_button.offset_right - utility_size
		mobile_flashlight_button.offset_bottom = utility_base_bottom
		mobile_flashlight_button.offset_top = utility_base_bottom - utility_size
		mobile_flashlight_button.custom_minimum_size = Vector2(utility_size, utility_size)
	if mobile_map_button:
		mobile_map_button.visible = (
			touch_available
			and not _is_inventory_open()
			and not lore_reader.is_open()
			and not extraction_transition_active
		)
		mobile_map_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mobile_map_button.offset_right = mobile_flashlight_button.offset_left - utility_gap if mobile_flashlight_button else -side_margin - utility_size * 3.0
		mobile_map_button.offset_left = mobile_map_button.offset_right - utility_size
		mobile_map_button.offset_bottom = utility_base_bottom
		mobile_map_button.offset_top = utility_base_bottom - utility_size
		mobile_map_button.custom_minimum_size = Vector2(utility_size, utility_size)
	if mobile_medkit_button:
		mobile_medkit_button.visible = not hud_blocked
		mobile_medkit_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		var med_size_w := clampf(side_margin + 64.0, 58.0, 84.0)
		mobile_medkit_button.offset_left = side_margin
		mobile_medkit_button.offset_right = side_margin + med_size_w
		var medkit_bottom := -bottom_margin
		if touch_available and touch_stick:
			medkit_bottom -= touch_stick_size + action_gap
		mobile_medkit_button.offset_bottom = medkit_bottom
		mobile_medkit_button.offset_top = medkit_bottom - med_size_w
		mobile_medkit_button.custom_minimum_size = Vector2(med_size_w, med_size_w)

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


func _setup_stealth_takedown_prompt(font: Font) -> void:
	stealth_takedown_prompt = PanelContainer.new()
	stealth_takedown_prompt.name = "StealthTakedownPrompt"
	stealth_takedown_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stealth_takedown_prompt.custom_minimum_size = STEALTH_TAKEDOWN_PROMPT_SIZE
	stealth_takedown_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stealth_takedown_prompt.z_index = 220
	stealth_takedown_prompt.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.025, 0.032, 0.029, 0.96), Color("#e0ba66"), 6)
	)
	stealth_takedown_prompt.visible = false
	$HUD.add_child(stealth_takedown_prompt)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	stealth_takedown_prompt.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var key_chip := PanelContainer.new()
	key_chip.custom_minimum_size = Vector2(58, 34)
	key_chip.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color("#d5aa55"), Color("#ffe09a"), 5)
	)
	row.add_child(key_chip)
	var input_center := CenterContainer.new()
	key_chip.add_child(input_center)
	stealth_takedown_input_icon = TextureRect.new()
	stealth_takedown_input_icon.name = "MouseLeftIcon"
	stealth_takedown_input_icon.custom_minimum_size = Vector2(28, 28)
	stealth_takedown_input_icon.texture = UI_ICONS.get_icon("mouse_left", 32, Color("#191711"))
	stealth_takedown_input_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stealth_takedown_input_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stealth_takedown_input_icon.visible = not DisplayServer.is_touchscreen_available()
	input_center.add_child(stealth_takedown_input_icon)
	stealth_takedown_key_label = Label.new()
	stealth_takedown_key_label.text = "탭"
	stealth_takedown_key_label.visible = DisplayServer.is_touchscreen_available()
	stealth_takedown_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stealth_takedown_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stealth_takedown_key_label.add_theme_font_override("font", font)
	stealth_takedown_key_label.add_theme_font_size_override("font_size", 14)
	stealth_takedown_key_label.add_theme_color_override("font_color", Color("#191711"))
	input_center.add_child(stealth_takedown_key_label)

	stealth_takedown_action_label = Label.new()
	stealth_takedown_action_label.text = "암살"
	stealth_takedown_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stealth_takedown_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stealth_takedown_action_label.add_theme_font_override("font", font)
	stealth_takedown_action_label.add_theme_font_size_override("font_size", 18)
	stealth_takedown_action_label.add_theme_color_override("font_color", Color("#f5e6c7"))
	row.add_child(stealth_takedown_action_label)


func _build_mobile_utility_buttons(font: Font) -> void:
	var touch_enabled := DisplayServer.is_touchscreen_available()
	mobile_context_button = _make_mobile_utility_button("ContextButton", "줍기", "loot", font, -108.0)
	if not touch_enabled:
		mobile_context_button.button_down.connect(_on_mobile_context_button_down)
		mobile_context_button.button_up.connect(_on_mobile_context_button_up)
	mobile_context_button.visible = false

	mobile_reload_button = _make_mobile_utility_button("ReloadButton", "장전", "reload", font, -198.0)
	if not touch_enabled:
		mobile_reload_button.pressed.connect(_reload_ak47)
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
	mobile_medkit_button.visible = true
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
			_begin_extraction()
		else:
			hud.field_interaction_touch_held = true
	elif is_instance_valid(nearby_ammo_pickup):
		_collect_nearby_ammo()
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
		_lock_aim_direction(_get_mobile_aim_assist_direction(facing_direction))
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
	mobile_context_button.visible = (
		not label.is_empty()
		and not _is_inventory_open()
		and not _is_tactical_map_open()
		and not lore_reader.is_open()
	)
	if not mobile_context_button.visible:
		mobile_context_button.disabled = false
		return
	mobile_context_button.text = label
	mobile_context_button.icon = UI_ICONS.get_icon(icon_name, 32, Color("#e8d890"))


func _on_inventory_weapon_mods_changed() -> void:
	equipped_weapon_mods.assign(GameState.equipped_weapon_mods)
	_refresh_weapon_stats()
	_update_equipment_ui()
	GameState.save_persistent_state()


func _on_inventory_weapon_equipped(weapon_id: String) -> void:
	if (weapon_id == equipped_weapon_id and has_ak) or GameState.get_weapon_count(weapon_id) <= 0:
		return
	var reequipping_same_weapon := not has_ak and weapon_id == equipped_weapon_id
	var previous_ammo_id := GameState.equipped_ammo_id
	if not reequipping_same_weapon and magazine_ammo > 0 and not previous_ammo_id.is_empty():
		GameState.set_ammo_count(previous_ammo_id, GameState.get_ammo_count(previous_ammo_id) + magazine_ammo)
	if not GameState.equip_weapon(weapon_id):
		return
	equipped_weapon_id = GameState.equipped_weapon_id
	equipped_weapon_mods.assign(GameState.equipped_weapon_mods)
	if not reequipping_same_weapon:
		magazine_ammo = 0
	reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.reserve_ammo = reserve_ammo
	has_ak = true
	GameState.has_ak = true
	_refresh_weapon_stats()
	GameState.magazine_ammo = magazine_ammo
	_rebuild_player_weapon_frames()
	_update_weapon_pose()
	_update_equipment_ui()
	GameState.save_persistent_state()


func _on_inventory_weapon_unequipped() -> void:
	if not has_ak:
		return
	reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.magazine_ammo = magazine_ammo
	GameState.reserve_ammo = reserve_ammo
	GameState.unequip_weapon()
	has_ak = false
	weapon_reloading = false
	laser_aim_held = false
	if weapon_sprite:
		weapon_sprite.visible = false
	_update_equipment_ui()
	GameState.save_persistent_state()


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
	_spawn_discarded_raid_item(item_type, item_id, removed)
	if item_type == "ammo" and item_id == str(GameState.equipped_ammo_id):
		reserve_ammo = GameState.get_ammo_count(item_id)
		GameState.reserve_ammo = reserve_ammo
	hud.inventory_ui.call("apply_discard_result", true, "%s x%d을 바닥에 내려놓았습니다." % [
		_raid_item_display_name(item_type, item_id),
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
	_update_loot_highlight(ak_pickup, distance, delta)
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
	_update_weapon_pose()
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
	_update_weapon_pose()
	_update_equipment_ui()


func _update_firing(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if roll_active or melee_attack_active or loafing:
		return
	var firing_held := fire_button_held or mouse_fire_held
	if firing_held and has_ak and bool(weapon_stats.get("automatic", true)) and fire_cooldown <= 0.0:
		_fire_ak47()


func _on_fire_button_down() -> void:
	fire_button_held = true
	_try_fire_ak47()
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(18)


func _on_fire_button_up() -> void:
	fire_button_held = false


func _on_melee_button_pressed() -> void:
	if not _try_stealth_takedown():
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


func _try_fire_ak47() -> void:
	if has_ak and not roll_active and not loafing and not melee_attack_active and not weapon_reloading and fire_cooldown <= 0.0:
		_fire_ak47()


func _fire_ak47() -> void:
	if weapon_reloading or melee_attack_active or loafing:
		return
	if magazine_ammo <= 0:
		if reserve_ammo > 0 and bool(AccessibilitySettings.auto_reload):
			_reload_ak47()
		else:
			_show_no_ammo_notice()
		return
	if _weapon_jammed():
		return
	magazine_ammo -= 1
	GameState.magazine_ammo = magazine_ammo
	if _active_field_mission_requires_silence():
		field_mission_noise_breached = true
	fire_cooldown = float(weapon_stats.get("fire_interval", 0.12))
	var aim_direction := _get_current_fire_direction()
	_lock_aim_direction(aim_direction)
	_set_facing_from_world_direction(aim_direction)
	_update_weapon_pose()
	if weapon_sprite:
		_play_weapon_directional_animation("fire")
	var pellet_count := int(weapon_stats.get("pellet_count", 1))
	for pellet_index in pellet_count:
		var spread_angle := weapon_random.randf_range(-weapon_spread_deg, weapon_spread_deg)
		var shot_direction := aim_direction.rotated(Vector3.UP, deg_to_rad(spread_angle)).normalized()
		_spawn_weapon_projectile(shot_direction, pellet_index)
	weapon_durability = maxf(0.0, weapon_durability - float(weapon_stats.get("durability_loss", 0.06)))
	GameState.weapon_durability = weapon_durability
	weapon_spread_deg = minf(
		weapon_spread_deg + float(weapon_stats.get("spread_per_shot_deg", 1.0)),
		float(weapon_stats.get("max_spread_deg", 14.0))
	)
	_add_fatigue(FATIGUE_SHOT_GAIN)
	_apply_weapon_recoil(aim_direction)
	# 총성은 도시가 듣는다. 소음기를 달면 그만큼 덜 들린다.
	var sound_scale := clampf(float(weapon_stats.get("sound_radius", 1.0)), 0.15, 2.0)
	_add_raid_pressure(
		lerpf(
			RAID_EVENT_DIRECTOR.PRESSURE_PER_SUPPRESSED_GUNSHOT,
			RAID_EVENT_DIRECTOR.PRESSURE_PER_GUNSHOT,
			clampf(sound_scale, 0.0, 1.0)
		)
	)
	_play_gunshot()
	_spawn_muzzle_light(aim_direction)
	_spawn_launch_fx(aim_direction)
	_update_equipment_ui()


func _spawn_weapon_projectile(direction: Vector3, pellet_index: int) -> void:
	var ammo_definition: Dictionary = WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id)
	var damage_multiplier := float(ammo_definition.get("damage_multiplier", 1.0))
	var projectile_damage := roundi(
		float(weapon_stats.get("damage", 24)) * damage_multiplier
	)
	var penetration := maxi(
		int(weapon_stats.get("penetration_count", 0)),
		int(ammo_definition.get("penetration", 0))
	)
	var projectile := Area3D.new()
	projectile.name = "%sBullet_%d" % [equipped_weapon_id, pellet_index]
	projectile.set_script(BULLET_PROJECTILE)
	projectile.set("direction", direction)
	projectile.set("source_body", player)
	projectile.set("damage", projectile_damage)
	projectile.set("critical_chance", _get_weapon_critical_chance())
	projectile.set("critical_multiplier", 1.65)
	projectile.set("penetrations_remaining", penetration)
	var range_profile := _get_weapon_range_profile(equipped_weapon_id)
	projectile.set("effective_range", range_profile.x)
	projectile.set("maximum_range", range_profile.y)
	projectile.set("minimum_damage_multiplier", range_profile.z)
	projectile.position = _get_weapon_muzzle_position(direction)
	add_child(projectile)


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


func _apply_weapon_recoil(aim_direction: Vector3) -> void:
	var recoil_kick := float(weapon_stats.get("recoil_kick", 0.7)) * GameState.get_recoil_control_multiplier()
	if loafing:
		recoil_kick *= float(weapon_stats.get("loaf_recoil_multiplier", 1.0))
	var knockback := float(weapon_stats.get("player_knockback", 0.15)) * recoil_kick
	recoil_velocity -= aim_direction * knockback
	recoil_reticle_offset += Vector2(weapon_random.randf_range(-5.0, 5.0), -11.0) * recoil_kick


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


func _get_current_fire_direction() -> Vector3:
	if _uses_mouse_aim():
		return _get_mouse_world_direction()
	var screen_direction: Vector2 = DIRECTION_VECTORS[facing]
	var facing_direction := Vector3(
		screen_direction.x + screen_direction.y,
		0,
		-screen_direction.x + screen_direction.y
	).normalized()
	return _get_mobile_aim_assist_direction(facing_direction)


func _get_mobile_aim_assist_direction(facing_direction: Vector3) -> Vector3:
	facing_direction.y = 0.0
	if facing_direction.length_squared() <= 0.01:
		facing_direction = _get_current_facing_world_direction()
	facing_direction = facing_direction.normalized()
	var best_enemy: CharacterBody3D
	var best_score := INF
	var assist_strength := clampf(float(AccessibilitySettings.aim_assist_strength), 0.0, 1.0)
	if assist_strength <= 0.01:
		return facing_direction
	var assist_half_angle := lerpf(12.0, MOBILE_AIM_ASSIST_HALF_ANGLE_DEG, assist_strength)
	var minimum_dot := cos(deg_to_rad(assist_half_angle))
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if float(enemy.get("player_visibility_factor")) < 0.2:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.05 or distance > MOBILE_AIM_ASSIST_MAX_DISTANCE:
			continue
		var enemy_direction := offset / distance
		var direction_dot := facing_direction.dot(enemy_direction)
		if direction_dot < minimum_dot:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 0.45, 0),
			enemy.global_position + Vector3(0, 0.45, 0),
			COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
		)
		query.exclude = [player.get_rid(), enemy.get_rid()]
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var angle_error := acos(clampf(direction_dot, -1.0, 1.0))
		var score := (
			angle_error * MOBILE_AIM_ASSIST_ANGLE_WEIGHT
			+ distance * MOBILE_AIM_ASSIST_DISTANCE_WEIGHT
		)
		if score < best_score:
			best_score = score
			best_enemy = enemy
	if best_enemy == null:
		return facing_direction
	var assisted_direction := best_enemy.global_position - player.global_position
	assisted_direction.y = 0.0
	return facing_direction.slerp(assisted_direction.normalized(), lerpf(0.25, 1.0, assist_strength)).normalized()


func _update_mobile_aim_direction(movement_world_direction: Vector3) -> void:
	var base_direction := movement_world_direction
	base_direction.y = 0.0
	if base_direction.length_squared() <= 0.01:
		base_direction = (
			locked_aim_direction
			if locked_aim_direction.length_squared() > 0.01
			else _get_current_facing_world_direction()
		)
	_lock_aim_direction(_get_mobile_aim_assist_direction(base_direction.normalized()))


func _update_weapon_pose() -> void:
	if weapon_sprite == null:
		return
	weapon_sprite.visible = has_ak and not melee_attack_active and not loafing and building_canvas == null
	if not has_ak or melee_attack_active or loafing:
		return
	if WEAPON_VISUAL_CATALOG.has_weapon_texture(equipped_weapon_id):
		var screen_direction: Vector2 = DIRECTION_VECTORS[facing]
		weapon_sprite.flip_h = screen_direction.x < -0.01
		var source_angle := PI if weapon_sprite.flip_h else 0.0
		weapon_sprite.rotation = Vector3(
			0,
			0,
			wrapf(screen_direction.angle() - source_angle, -PI, PI)
		)
	else:
		weapon_sprite.flip_h = facing in ["w", "sw", "nw"]
		weapon_sprite.rotation = Vector3.ZERO
	weapon_sprite.render_priority = 0 if _weapon_renders_behind_player() else 2
	var direction := _get_current_facing_world_direction()
	weapon_sprite.position = direction * WEAPON_FLOAT_DISTANCE + Vector3(0, 0.36, 0)
	weapon_sprite.offset = _get_weapon_screen_offset()
	if not weapon_sprite.animation.begins_with("fire_"):
		_play_weapon_directional_animation("idle")


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


func _get_weapon_muzzle_position(world_direction: Vector3) -> Vector3:
	var weapon_origin := weapon_sprite.global_position if weapon_sprite and has_ak else player.global_position
	return weapon_origin + world_direction * WEAPON_MUZZLE_FORWARD_DISTANCE + Vector3(0, 0.02, 0)


func _get_mouse_world_direction() -> Vector3:
	# The same recoil offset drives both the drawn reticle and the actual ray,
	# so sustained fire cannot visually lie about the bullet center.
	var mouse_position := get_viewport().get_mouse_position() + recoil_reticle_offset
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var target_y := player.global_position.y
	if absf(ray_direction.y) < 0.001:
		return _get_current_facing_world_direction()
	var distance_to_plane := (target_y - ray_origin.y) / ray_direction.y
	var hit_position := ray_origin + ray_direction * distance_to_plane
	var direction := hit_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return _get_current_facing_world_direction()
	return direction.normalized()


func _get_current_facing_world_direction() -> Vector3:
	var screen_direction: Vector2 = DIRECTION_VECTORS[facing]
	return Vector3(
		screen_direction.x + screen_direction.y,
		0,
		-screen_direction.x + screen_direction.y
	).normalized()


func _reload_ak47() -> void:
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	if weapon_reloading or loafing:
		return
	if reserve_ammo <= 0 or magazine_ammo >= magazine_size:
		fire_cooldown = 0.35
		if reserve_ammo <= 0:
			_show_no_ammo_notice()
		return
	weapon_reloading = true
	reload_timer = float(weapon_stats.get("reload_time", 2.15))
	fire_cooldown = reload_timer
	_add_fatigue(FATIGUE_RELOAD_GAIN)
	hud.ammo_notice.text = "%s 재장전 중 · %.1f초\n장전 중 이동·사격 제한" % [
		str(weapon_stats.get("display_name", "무기")),
		reload_timer,
	]
	hud.ammo_notice.visible = true
	ammo_notice_time = reload_timer
	_update_equipment_ui()


func _finish_reload() -> void:
	weapon_reloading = false
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	var needed := magazine_size - magazine_ammo
	var loaded := mini(needed, reserve_ammo)
	magazine_ammo += loaded
	reserve_ammo -= loaded
	GameState.magazine_ammo = magazine_ammo
	GameState.set_ammo_count(GameState.equipped_ammo_id, reserve_ammo)
	hud.ammo_notice.text = "%s 재장전 완료  +%d\n탄창 %d / %d   예비 %d   총 %d" % [
		str(weapon_stats.get("display_name", "무기")),
		loaded,
		magazine_ammo,
		magazine_size,
		reserve_ammo,
		magazine_ammo + reserve_ammo,
	]
	hud.ammo_notice.visible = true
	ammo_notice_time = 1.4
	_update_equipment_ui()


func _show_no_ammo_notice() -> void:
	fire_cooldown = maxf(fire_cooldown, 0.35)
	if hud.ammo_notice:
		hud.ammo_notice.text = "탄약 없음\n예비탄을 확보해야 합니다."
		hud.ammo_notice.visible = true
		ammo_notice_time = 1.1
	_update_equipment_ui()


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
	if hud.equipment_label:
		hud.equipment_label.text = "%s +%d" % [weapon_name, enhancement_level] if has_ak else "무기 없음"
	if hud.equipment_weapon_image:
		hud.equipment_weapon_image.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture(equipped_weapon_id)
		hud.equipment_weapon_image.visible = has_ak
	if hud.equipment_ammo_label:
		hud.equipment_ammo_label.text = str(hud_state.get("ammo_text", "-- / --"))
		var hud_ammo_color: Color = hud_state.get("ammo_color", Color("#f1ce70"))
		hud.equipment_ammo_label.add_theme_color_override(
			"font_color",
			hud_ammo_color
		)
	if hud.equipment_reserve_ammo_label:
		hud.equipment_reserve_ammo_label.text = str(hud_state.get("reserve_text", "예비 없음"))
		var hud_reserve_color: Color = hud_state.get("reserve_color", Color("#c5d0c9"))
		hud.equipment_reserve_ammo_label.add_theme_color_override(
			"font_color",
			hud_reserve_color
		)
	if hud.equipment_condition_label:
		hud.equipment_condition_label.text = str(hud_state.get("condition_text", ""))
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


func _spawn_muzzle_light(direction: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffb347")
	flash.light_energy = 3.0
	flash.omni_range = 2.2
	flash.position = player.position + direction * 0.8 + Vector3(0, 0.2, 0)
	add_child(flash)
	get_tree().create_timer(0.045).timeout.connect(flash.queue_free)


func _spawn_launch_fx(direction: Vector3) -> void:
	var origin := player.position + direction * 0.86 + Vector3(0, 0.18, 0)
	_spawn_particle_burst(origin, direction, Color("#ffd98a"), 6, 0.09, 2.0, 4.2, 0.04, 0.12)
	_spawn_smoke_cloud(origin, direction)
	get_tree().create_timer(0.055).timeout.connect(func() -> void:
		_spawn_smoke_cloud(origin + direction * 0.08, direction)
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


func _build_gunshot_audio() -> void:
	var stream := _create_gunshot_stream()
	for index in 4:
		var audio := AudioStreamPlayer3D.new()
		audio.name = "Gunshot%d" % index
		audio.stream = stream
		audio.unit_size = 9.0
		audio.max_distance = 72.0
		audio.volume_db = -1.0
		player.add_child(audio)
		gunshot_players.append(audio)


func _create_gunshot_stream() -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * 0.34)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 47047
	for index in sample_count:
		var time := float(index) / mix_rate
		var muzzle_blast := random.randf_range(-1.0, 1.0) * exp(-time * 35.0)
		var metallic_crack := sin(TAU * 720.0 * time + random.randf_range(-0.18, 0.18)) * exp(-time * 23.0)
		var low_thump := sin(TAU * 86.0 * time) * exp(-time * 11.0)
		var tail_noise := random.randf_range(-1.0, 1.0) * exp(-maxf(0.0, time - 0.045) * 9.0) * 0.34
		var slapback := 0.0
		if time > 0.055:
			slapback += random.randf_range(-1.0, 1.0) * exp(-(time - 0.055) * 19.0) * 0.18
		if time > 0.115:
			slapback += random.randf_range(-1.0, 1.0) * exp(-(time - 0.115) * 14.0) * 0.11
		var sample := muzzle_blast * 0.82 + metallic_crack * 0.26 + low_thump * 0.58 + tail_noise + slapback
		_write_wav_sample(data, index, tanh(sample * 1.35) * 0.92)
	return _make_wav_stream(data, mix_rate)


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
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "ApocalypseSeoulBGM"
	bgm_player.stream = _create_apocalypse_bgm_stream()
	bgm_player.volume_db = -21.0
	bgm_player.bus = "Master"
	add_child(bgm_player)
	bgm_player.play()


func _create_apocalypse_bgm_stream() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 18.0
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 130713
	var noise_hold := 0.0
	for index in sample_count:
		var time := float(index) / mix_rate
		if index % 300 == 0:
			noise_hold = random.randf_range(-1.0, 1.0)
		var fade_in := clampf(time / 2.0, 0.0, 1.0)
		var fade_out := clampf((duration - time) / 2.0, 0.0, 1.0)
		var loop_fade := minf(fade_in, fade_out)
		var drone := sin(TAU * 43.65 * time) * 0.26
		drone += sin(TAU * 65.41 * time + 1.7) * 0.12
		drone += sin(TAU * 98.0 * time + 0.4) * 0.06
		var distant_alarm := sin(TAU * 0.075 * time) * sin(TAU * 392.0 * time) * 0.045
		var rain_static := noise_hold * 0.04
		var pulse := 0.0
		var pulse_phase := fmod(time, 6.0)
		if pulse_phase < 0.55:
			pulse = sin(TAU * 72.0 * time) * exp(-pulse_phase * 7.0) * 0.16
		_write_wav_sample(data, index, clampf((drone + distant_alarm + rain_static + pulse) * loop_fade, -1.0, 1.0))
	var stream := _make_wav_stream(data, mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


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


func _play_gunshot() -> void:
	if gunshot_players.is_empty():
		return
	var audio := gunshot_players[gunshot_index]
	gunshot_index = (gunshot_index + 1) % gunshot_players.size()
	audio.play()


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
	var squad_sizes := _build_enemy_squad_sizes(total_enemies)
	var spawned_count := 0
	for squad_index in squad_sizes.size():
		var squad_anchor := _find_distributed_enemy_position(world, squad_index, squad_sizes.size())
		squad_anchor = _ensure_initial_enemy_safe_anchor(world, squad_anchor, squad_index)
		var kinds: Array[String] = []
		for member_index in squad_sizes[squad_index]:
			var enemy_index := spawned_count + member_index
			kinds.append(
				"melee"
				if enemy_index < 2
				else ("grenadier" if enemy_index % 6 == 4 else "pistol")
			)
		_spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			maxf(night_intensity, zone_threat)
		)
		spawned_count += squad_sizes[squad_index]
	# Bosses enter only after fatigue reaches the raid threshold. This keeps the
	# opening route readable and makes the arrival alert match the actual spawn.


func _spawn_zone_boss(world: ProceduralCityMap, spawn_index: int, zone_threat: float) -> void:
	var boss_position := _find_distributed_enemy_position(world, spawn_index, spawn_index + 1)
	_spawn_rocket_boss_at(
		boss_position,
		maxf(0.5, zone_threat),
		"RaidBoss_%s" % GameState.selected_raid_zone
	)


func _spawn_rocket_boss_at(
	spawn_position: Vector3,
	boss_threat: float,
	boss_name: String
) -> CharacterBody3D:
	var boss := CharacterBody3D.new()
	boss.set_script(ROCKET_BOSS_SCRIPT)
	boss.position = spawn_position
	boss.call("configure_rocket_boss", player, clampf(boss_threat, 0.0, 1.0))
	add_child(boss)
	if is_instance_valid(scent_system):
		scent_system.call("register_mover", boss, "enemy")
	boss.died.connect(_on_enemy_died)
	if boss.has_signal("damaged"):
		boss.connect("damaged", _on_enemy_damaged)
	enemies.append(boss)
	boss.name = boss_name
	boss.set_meta("raid_boss", true)
	boss.set_meta("zone_id", GameState.selected_raid_zone)
	boss.set_meta("display_name", "로켓 약탈대장")
	var marker := Label3D.new()
	marker.name = "BossMarker"
	marker.text = "로켓 약탈대장"
	marker.position = Vector3(0.0, 3.55, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.render_priority = 127
	marker.font = FONT
	marker.font_size = 42
	marker.pixel_size = 0.005
	marker.modulate = Color("#f1c45d")
	marker.outline_modulate = Color(0.08, 0.02, 0.01, 0.95)
	marker.outline_size = 10
	boss.add_child(marker)
	if is_instance_valid(tactical_map) and tactical_map.has_method("register_boss"):
		tactical_map.call("register_boss", boss)
	return boss


func _spawn_test_boss_near_player() -> void:
	if player_health <= 0 or extraction_transition_active:
		return
	var world := $World as ProceduralCityMap
	var forward := _get_current_facing_world_direction()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var candidate_offsets := [
		forward * 11.0,
		(forward * 12.0 + side * 4.0),
		(forward * 12.0 - side * 4.0),
		forward * 15.0,
	]
	var spawn_position := Vector3.INF
	for offset in candidate_offsets:
		var candidate := world.find_nearest_physically_open_position(
			player.global_position + offset,
			1.05,
			[player.get_rid()]
		)
		candidate.y = 0.78
		if candidate.distance_to(player.global_position) < 7.0:
			continue
		var shape := SphereShape3D.new()
		shape.radius = 1.05
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0.0, 0.7, 0.0))
		query.collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		query.exclude = [player.get_rid()]
		if player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			spawn_position = candidate
			break
	if spawn_position == Vector3.INF:
		_show_field_notice("보스 소환 실패 · 주변에 충분한 공간이 없습니다.")
		return
	var boss := _spawn_rocket_boss_at(
		spawn_position,
		maxf(0.75, night_intensity),
		"RaidBoss_Test_%d" % Time.get_ticks_msec()
	)
	if boss.has_method("receive_reinforcement_order"):
		boss.call("receive_reinforcement_order", player.global_position)
	_show_field_notice("테스트 보스 출현 · 로켓 약탈대장이 접근합니다.")


func _find_distributed_enemy_position(
	world: ProceduralCityMap,
	index: int,
	total_count: int
) -> Vector3:
	var entry_safe_radius := float(raid_zone_data.get(
		"entry_safe_radius", RAID_ENTRY_ENEMY_SAFE_RADIUS
	))
	var occupied_positions: Array[Vector3] = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			occupied_positions.append(enemy.global_position)
	if index == 0:
		var map_limit := world.get_map_limit() - 8.0
		for attempt in 16:
			var angle := TAU * float(attempt) / 16.0 + spawn_random.randf_range(-0.12, 0.12)
			var requested := (
				player.global_position
				+ Vector3(cos(angle), 0.0, sin(angle)) * (entry_safe_radius + 8.0)
			)
			requested.x = clampf(requested.x, -map_limit, map_limit)
			requested.z = clampf(requested.z, -map_limit, map_limit)
			requested.y = 0.78
			var nearby_candidate := world.find_nearest_physically_open_position(
				requested,
				0.62,
				[player.get_rid()]
			)
			nearby_candidate.y = 0.78
			if (
				nearby_candidate.distance_to(player.global_position) >= entry_safe_radius + 3.0
				and world.get_risk_band(nearby_candidate) != "safe"
			):
				return nearby_candidate
	return _find_stratified_map_position(
		world,
		index - 1,
		total_count - 1,
		entry_safe_radius + 3.0,
		7.0,
		occupied_positions,
		0.78
	)


func _ensure_initial_enemy_safe_anchor(
	world: ProceduralCityMap,
	requested_anchor: Vector3,
	squad_index: int
) -> Vector3:
	var entry_safe_radius := float(raid_zone_data.get(
		"entry_safe_radius", RAID_ENTRY_ENEMY_SAFE_RADIUS
	))
	if (
		requested_anchor.distance_to(player.global_position) >= entry_safe_radius + 3.0
		and world.get_risk_band(requested_anchor) != "safe"
	):
		return requested_anchor
	var map_limit := world.get_map_limit() - 8.0
	for attempt in 32:
		var angle := (
			TAU * float(attempt) / 32.0
			+ float(squad_index) * 0.73
			+ spawn_random.randf_range(-0.08, 0.08)
		)
		var distance := entry_safe_radius + spawn_random.randf_range(6.0, 18.0)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = 0.78
		if (
			candidate.distance_to(player.global_position) >= entry_safe_radius + 3.0
			and not world.is_position_in_safe_zone(candidate)
			and world.get_risk_band(candidate) != "safe"
		):
			return candidate
	return requested_anchor


func _build_enemy_squad_sizes(total_count: int) -> Array[int]:
	var sizes: Array[int] = []
	var remaining := maxi(0, total_count)
	while remaining > 0:
		var squad_size := 1
		if _is_first_stage_zone():
			if remaining >= 2 and spawn_random.randf() >= FIRST_STAGE_SOLO_SQUAD_CHANCE:
				squad_size = 2
		elif remaining == 2 or remaining == 4:
			squad_size = 2
		elif remaining == 3:
			squad_size = 3
		elif remaining > 4:
			squad_size = 2 if spawn_random.randf() < ENEMY_PAIR_SQUAD_CHANCE else 3
		sizes.append(squad_size)
		remaining -= squad_size
	return sizes


func _spawn_enemy_squad(
	world: ProceduralCityMap,
	squad_anchor: Vector3,
	kinds: Array[String],
	threat: float,
	order_position: Vector3 = Vector3.INF,
	metadata: Dictionary = {}
) -> Array[CharacterBody3D]:
	var spawned: Array[CharacterBody3D] = []
	var assigned_squad_id := enemy_squad_serial
	enemy_squad_serial += 1
	for member_index in kinds.size():
		var spawn_position := _find_squad_member_position(
			world,
			squad_anchor,
			member_index,
			kinds.size()
		)
		var enemy := _spawn_enemy(
			kinds[member_index],
			spawn_position,
			threat,
			assigned_squad_id,
			squad_anchor,
			spawn_position - squad_anchor
		)
		for metadata_key in metadata:
			enemy.set_meta(str(metadata_key), metadata[metadata_key])
		if order_position != Vector3.INF and enemy.has_method("receive_reinforcement_order"):
			enemy.call("receive_reinforcement_order", order_position)
		elif enemy.has_method("configure_patrol"):
			var patrol_selector := posmod(assigned_squad_id, 4)
			var patrol_mode := (
				"sentry"
				if patrol_selector == 0
				else ("route" if patrol_selector == 1 else "road_route")
			)
			enemy.call(
				"configure_patrol",
				patrol_mode,
				_build_enemy_patrol_route(
					world,
					spawn_position,
					assigned_squad_id * 7 + member_index,
					patrol_mode
				)
			)
		spawned.append(enemy)
	return spawned


func _build_enemy_patrol_route(
	world: ProceduralCityMap,
	origin: Vector3,
	route_seed: int,
	patrol_mode: String
) -> Array[Vector3]:
	var points: Array[Vector3] = [origin]
	if patrol_mode == "road_route":
		return world.get_long_road_patrol_route(origin, route_seed, [player.get_rid()])
	var point_count := 3 if patrol_mode == "sentry" else 5
	var route_radius := 4.2 if patrol_mode == "sentry" else 8.5
	var base_angle := deg_to_rad(float(posmod(route_seed * 67, 360)))
	for point_index in range(1, point_count):
		var angle := base_angle + TAU * float(point_index) / float(point_count - 1)
		var requested := origin + Vector3(cos(angle), 0.0, sin(angle)) * route_radius
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.58,
			[player.get_rid()]
		)
		candidate.y = origin.y
		var duplicate_point := false
		for existing in points:
			if existing.distance_to(candidate) < 1.4:
				duplicate_point = true
				break
		if (
			not duplicate_point
			and candidate.distance_to(origin) <= route_radius * 1.55
		):
			points.append(candidate)
	return points


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


func _spawn_enemy(
	kind: String,
	spawn_position: Vector3,
	threat: float,
	assigned_squad_id: int = -1,
	assigned_squad_anchor: Vector3 = Vector3.ZERO,
	formation_offset: Vector3 = Vector3.ZERO
) -> CharacterBody3D:
	var enemy_weapon_id := "baseball_bat"
	if kind != "melee":
		var roll := spawn_random.randf()
		if roll < lerpf(0.48, 0.22, threat):
			enemy_weapon_id = "m1911"
		elif roll < lerpf(0.82, 0.58, threat):
			enemy_weapon_id = "mp5"
		elif roll < lerpf(0.95, 0.88, threat):
			enemy_weapon_id = "ak47"
		else:
			enemy_weapon_id = "double_barrel"
		enemy_ranged_spawn_serial += 1
	var enemy := CharacterBody3D.new()
	enemy.name = "%s_%s_Enemy%d" % [kind.capitalize(), enemy_weapon_id, enemy_spawn_serial]
	enemy_spawn_serial += 1
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = spawn_position
	enemy.call("configure", kind, player, {}, threat, enemy_weapon_id)
	enemy.call("set_faction", "feral" if posmod(assigned_squad_id, 4) == 0 else "raider")
	if enemy.has_method("set_detection_profile"):
		if _is_first_stage_zone():
			enemy.call("set_detection_profile", 1.0, 60.0, 0.9)
		else:
			enemy.call("set_detection_profile", 1.0, 58.0, 1.0)
	enemy.call("set_environment_visibility", night_intensity)
	add_child(enemy)
	if is_instance_valid(scent_system):
		scent_system.call("register_mover", enemy, "enemy")
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("damaged"):
		enemy.connect("damaged", _on_enemy_damaged)
	if enemy.has_signal("reinforcement_called"):
		enemy.connect("reinforcement_called", _on_enemy_reinforcement_called)
	enemies.append(enemy)
	if assigned_squad_id >= 0 and enemy.has_method("assign_squad"):
		enemy.call("assign_squad", assigned_squad_id, assigned_squad_anchor, formation_offset)
	return enemy


func _on_enemy_died(enemy: CharacterBody3D) -> void:
	run_kills += 1
	GameState.raid_kills += 1
	# 죽인 만큼 도시가 반응한다. 조용히 지나갈수록 판이 길어진다.
	_add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_KILL)
	_advance_contract_progress("kills")
	if (
		is_instance_valid(active_field_mission)
		and int(enemy.get_meta("field_mission_id", -1))
		== int(active_field_mission.get_meta("mission_id", 0))
	):
		field_mission_kills += 1
	if bool(enemy.get_meta("raid_boss", false)):
		run_boss_kills += 1
		GameState.register_boss_defeat()
		# 보스전은 도시 전체가 듣는다. 처치 직후가 가장 위험해야 한다.
		_add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_ALARM)
		_play_boss_defeat_sequence(enemy)
		if GameState.subway_story_stage == 1:
			_advance_basic_mission("subway_boss")
	if enemy == active_reinforcement_caller:
		active_reinforcement_caller = null
		sustained_combat_time = REINFORCEMENT_CALL_TRIGGER_TIME * 0.2
		concealed_combat_time = 0.0
	_spawn_enemy_loot(enemy)
	enemies.erase(enemy)
	reinforcement_timer = minf(reinforcement_timer, 2.5)


func _on_enemy_damaged(_enemy: CharacterBody3D, amount: int) -> void:
	run_damage_dealt += maxi(0, amount)
	if amount >= 20 and combat_hit_stop_cooldown <= 0.0:
		combat_hit_stop_cooldown = 0.12
		_trigger_hit_stop(0.028)


func _spawn_enemy_loot(enemy: CharacterBody3D) -> Node3D:
	var drop_position := enemy.global_position
	var enemy_weapon_id := str(enemy.get("weapon_id"))
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	if bool(enemy.get_meta("raid_boss", false)):
		var component_ids := ["rubber_gasket", "scope_lens", "magazine_spring"]
		var component_names := {
			"rubber_gasket": "소음기용 고무 패킹",
			"scope_lens": "스코프 렌즈",
			"magazine_spring": "탄창 스프링",
		}
		var component_id: String = component_ids[spawn_random.randi_range(0, component_ids.size() - 1)]
		var guaranteed_churu := 1
		var boss_drop := _create_loot_pickup(
			"churu",
			drop_position,
			{"amount": guaranteed_churu, "display_name": "보스 보상 츄르"}
		)
		_create_loot_pickup(
			"mod_component",
			drop_position + Vector3(1.0, 0.0, 0.7),
			{
				"amount": 1,
				"component_id": component_id,
				"display_name": component_names[component_id],
			}
		)
		return boss_drop
	var definition: Dictionary = LOOT_ECONOMY.roll_enemy_drop(
		stage_tier,
		str(enemy.get("enemy_kind")),
		enemy_weapon_id,
		spawn_random,
		not has_ak
	)
	if definition.is_empty():
		return null
	if not LOOT_ECONOMY.try_register_loot(
		GameState,
		definition,
		"enemy",
		stage_tier
	):
		return null
	var data := (definition.get("data", {}) as Dictionary).duplicate(true)
	data["loot_source"] = "enemy"
	return _create_loot_pickup(
		str(definition.get("type", "canned_food")),
		drop_position,
		data
	)


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


func _update_reinforcement_call(delta: float, effective_threat: float) -> void:
	reinforcement_call_cooldown = maxf(0.0, reinforcement_call_cooldown - delta)
	if active_reinforcement_caller != null and not is_instance_valid(active_reinforcement_caller):
		active_reinforcement_caller = null
	elif active_reinforcement_caller != null and not bool(active_reinforcement_caller.get("reinforcement_call_active")):
		active_reinforcement_caller = null
		sustained_combat_time = REINFORCEMENT_CALL_TRIGGER_TIME * 0.2
		concealed_combat_time = 0.0
	var alerted_count := 0
	var visual_contact_count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if bool(enemy.get("alerted")):
			alerted_count += 1
			if bool(enemy.get("has_current_line_of_sight")):
				visual_contact_count += 1
	if visual_contact_count > 0:
		sustained_combat_time += delta
		concealed_combat_time = maxf(0.0, concealed_combat_time - delta * 2.0)
	elif alerted_count >= 2:
		concealed_combat_time += delta
		sustained_combat_time = maxf(0.0, sustained_combat_time - delta * 0.2)
	else:
		sustained_combat_time = maxf(0.0, sustained_combat_time - delta * 2.0)
		concealed_combat_time = maxf(0.0, concealed_combat_time - delta * 2.5)
	if active_reinforcement_caller != null or reinforcement_call_cooldown > 0.0:
		return
	var prolonged_firefight := sustained_combat_time >= REINFORCEMENT_CALL_TRIGGER_TIME
	var prolonged_standoff := concealed_combat_time >= REINFORCEMENT_HIDDEN_TRIGGER_TIME
	if not prolonged_firefight and not prolonged_standoff:
		return
	var caller: CharacterBody3D
	var best_score := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")) or not bool(enemy.get("alerted")):
			continue
		if str(enemy.get("enemy_kind")) == "melee":
			continue
		if not enemy.has_method("start_reinforcement_call"):
			continue
		var score := enemy.global_position.distance_to(player.global_position)
		if prolonged_standoff and bool(enemy.get("has_current_line_of_sight")):
			score += 18.0
		if score < best_score:
			best_score = score
			caller = enemy
	if caller != null and bool(caller.call("start_reinforcement_call", REINFORCEMENT_CALL_DURATION)):
		active_reinforcement_caller = caller
		sustained_combat_time = 0.0
		concealed_combat_time = 0.0


func _on_enemy_reinforcement_called(caller: CharacterBody3D) -> void:
	if caller != active_reinforcement_caller:
		return
	active_reinforcement_caller = null
	reinforcement_call_cooldown = REINFORCEMENT_CALL_COOLDOWN
	concealed_combat_time = 0.0
	_spawn_called_reinforcements()


func _spawn_called_reinforcements() -> void:
	var stage_profile: Dictionary = LOOT_ECONOMY.get_stage_profile(
		LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	)
	var remaining_kills := int(stage_profile.get("raid_kill_cap", 40)) - GameState.raid_kills
	if remaining_kills <= 0:
		return
	var effective_threat := clampf(maxf(0.58, night_intensity), 0.0, 1.0)
	var reinforcement_count := mini(
		6 + roundi(night_intensity * 4.0),
		remaining_kills
	)
	var world := $World as ProceduralCityMap
	var squad_sizes := _build_enemy_squad_sizes(reinforcement_count)
	var spawned_count := 0
	for squad_size in squad_sizes:
		var squad_anchor := _find_reinforcement_position()
		if squad_anchor == Vector3.INF:
			continue
		var kinds: Array[String] = []
		for member_index in squad_size:
			var enemy_index := spawned_count + member_index
			kinds.append(
				"grenadier"
				if enemy_index == reinforcement_count - 1
				else ("pistol" if enemy_index < reinforcement_count - 2 or spawn_random.randf() < 0.82 else "melee")
			)
		_spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			effective_threat,
			player.global_position
		)
		spawned_count += squad_size


func _update_enemy_pressure(delta: float) -> void:
	var effective_threat := clampf(night_intensity, 0.0, 1.0)
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
	_update_reinforcement_call(delta, effective_threat)
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
	var squad_anchor := _find_reinforcement_position()
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
		_spawn_enemy_squad(
			$World as ProceduralCityMap,
			squad_anchor,
			kinds,
			effective_threat
		)
	reinforcement_timer = lerpf(15.0, 2.8, effective_threat)


func _find_reinforcement_position() -> Vector3:
	var world := $World as ProceduralCityMap
	var map_limit := world.get_map_limit() - 4.0
	for attempt in 16:
		var angle := spawn_random.randf_range(0.0, TAU)
		var distance := spawn_random.randf_range(20.0, 34.0)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		requested.y = 0.78
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		if candidate.distance_to(player.global_position) < 17.0:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var overlaps_enemy := false
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(candidate) < 2.2:
				overlaps_enemy = true
				break
		if not overlaps_enemy:
			return candidate
	return Vector3.INF


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


func _build_visibility_fog() -> void:
	$HUD.layer = 3
	var fog_layer := CanvasLayer.new()
	fog_layer.name = "VisibilityFog"
	fog_layer.layer = 2
	add_child(fog_layer)
	var darkness := ColorRect.new()
	darkness.name = "Darkness"
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_layer.add_child(darkness)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 player_screen = vec2(640.0, 360.0);
uniform vec2 facing_screen_direction = vec2(0.0, -1.0);
uniform float inner_radius = 245.0;
uniform float outer_radius = 430.0;
uniform float near_radius = 96.0;
uniform float fan_cos = 0.34;
uniform float darkness = 0.86;
uniform float aim_expanded = 0.0;
uniform float circle_radius = 245.0;

void fragment() {
	vec2 pixel_position = UV * viewport_size;
	vec2 to_pixel = pixel_position - player_screen;
	float distance_from_player = length(to_pixel);
	vec2 pixel_direction = distance_from_player > 0.001 ? normalize(to_pixel) : facing_screen_direction;
	float alignment = dot(pixel_direction, normalize(facing_screen_direction));
	float near_visibility = 1.0 - smoothstep(near_radius * 0.72, near_radius, distance_from_player);
	float circle_visibility = 1.0 - smoothstep(circle_radius * 0.78, circle_radius, distance_from_player);
	float fan_visibility = smoothstep(fan_cos - 0.11, fan_cos + 0.08, alignment);
	float range_visibility = 1.0 - smoothstep(inner_radius, outer_radius, distance_from_player);
	float relaxed_visibility = max(near_visibility, circle_visibility);
	float aimed_visibility = max(relaxed_visibility, fan_visibility * range_visibility);
	float visibility = mix(relaxed_visibility, aimed_visibility, aim_expanded);
	float fog_alpha = mix(darkness, 0.035, visibility);
	COLOR = vec4(0.008, 0.012, 0.015, fog_alpha);
}
"""
	visibility_material = ShaderMaterial.new()
	visibility_material.shader = shader
	darkness.material = visibility_material
	_update_visibility_fog()


func _update_visibility_fog() -> void:
	if visibility_material == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var circle_radius := lerpf(178.0, 104.0, night_intensity)
	var inner_radius := lerpf(430.0, 185.0, night_intensity)
	var outer_radius := lerpf(560.0, 285.0, night_intensity)
	var brightness_floor := clampf(float(AccessibilitySettings.minimum_brightness), 0.0, 0.5)
	var edge_darkness := minf(
		lerpf(0.82, 0.97, night_intensity),
		0.99 - brightness_floor * 0.55
	)
	var player_screen := camera.unproject_position(player.global_position)
	var facing_screen := camera.unproject_position(player.global_position + _get_perception_aim_direction() * 5.0)
	var facing_screen_direction := (facing_screen - player_screen).normalized()
	if facing_screen_direction.length_squared() <= 0.001:
		facing_screen_direction = Vector2(0.0, -1.0)
	visibility_material.set_shader_parameter("viewport_size", viewport_size)
	visibility_material.set_shader_parameter("player_screen", player_screen)
	visibility_material.set_shader_parameter("facing_screen_direction", facing_screen_direction)
	visibility_material.set_shader_parameter("inner_radius", inner_radius)
	visibility_material.set_shader_parameter("outer_radius", outer_radius)
	visibility_material.set_shader_parameter("near_radius", lerpf(112.0, 64.0, night_intensity))
	visibility_material.set_shader_parameter("fan_cos", lerpf(0.06, 0.34, night_intensity))
	visibility_material.set_shader_parameter("darkness", edge_darkness)
	visibility_material.set_shader_parameter("aim_expanded", 1.0 if laser_aim_held else 0.0)
	visibility_material.set_shader_parameter("circle_radius", circle_radius)


func _update_enemy_visibility(delta: float = 1.0 / 60.0) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var fully_visible_radius := lerpf(178.0, 104.0, night_intensity)
	var reveal_radius := fully_visible_radius + lerpf(46.0, 30.0, night_intensity)
	if laser_aim_held:
		fully_visible_radius = lerpf(430.0, 185.0, night_intensity)
		reveal_radius = lerpf(560.0, 285.0, night_intensity)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var raw_visibility := _enemy_player_visibility_factor(
			enemy,
			fully_visible_radius,
			reveal_radius
		)
		var previous_visibility := float(enemy.get_meta("smoothed_player_visibility", raw_visibility))
		var visibility_hold := maxf(
			0.0,
			float(enemy.get_meta("player_visibility_hold", 0.0)) - delta
		)
		if raw_visibility > 0.01:
			visibility_hold = ENEMY_VISIBILITY_HOLD_SECONDS
		elif visibility_hold > 0.0:
			raw_visibility = previous_visibility
		var blend_speed := (
			ENEMY_VISIBILITY_FADE_IN_SPEED
			if raw_visibility > previous_visibility
			else ENEMY_VISIBILITY_FADE_OUT_SPEED
		)
		var visibility_factor := lerpf(
			previous_visibility,
			raw_visibility,
			1.0 - exp(-blend_speed * maxf(delta, 0.0001))
		)
		if raw_visibility <= 0.0 and visibility_factor < 0.012:
			visibility_factor = 0.0
		enemy.set_meta("smoothed_player_visibility", visibility_factor)
		enemy.set_meta("player_visibility_hold", visibility_hold)
		enemy.visible = visibility_factor > 0.001
		if enemy.has_method("set_player_visibility_factor"):
			enemy.call("set_player_visibility_factor", visibility_factor)


func _enemy_player_visibility_factor(
	enemy: Node3D,
	fully_visible_radius: float,
	reveal_radius: float
) -> float:
	if not is_instance_valid(enemy) or camera.is_position_behind(enemy.global_position):
		return 0.0
	var viewport_rect := get_viewport().get_visible_rect()
	var enemy_screen := camera.unproject_position(enemy.global_position + Vector3(0, 0.45, 0))
	if not viewport_rect.grow(24.0).has_point(enemy_screen):
		return 0.0
	var player_screen := camera.unproject_position(player.global_position + Vector3(0, 0.22, 0))
	var screen_distance := player_screen.distance_to(enemy_screen)
	if screen_distance > reveal_radius:
		return 0.0
	var facing_screen := camera.unproject_position(player.global_position + _get_perception_aim_direction() * 5.0)
	var facing_screen_direction := (facing_screen - player_screen).normalized()
	var enemy_screen_direction := (enemy_screen - player_screen).normalized()
	var near_radius := lerpf(112.0, 64.0, night_intensity)
	var fan_cos := lerpf(0.06, 0.34, night_intensity)
	if laser_aim_held and screen_distance > near_radius and enemy_screen_direction.dot(facing_screen_direction) < fan_cos:
		return 0.0
	if screen_distance <= fully_visible_radius:
		return 1.0
	return 1.0 - smoothstep(fully_visible_radius, reveal_radius, screen_distance)


func _enemy_is_in_player_vision(enemy: Node3D, visible_radius: float) -> bool:
	if not is_instance_valid(enemy) or camera.is_position_behind(enemy.global_position):
		return false
	var viewport_rect := get_viewport().get_visible_rect()
	var enemy_screen := camera.unproject_position(enemy.global_position + Vector3(0, 0.45, 0))
	if not viewport_rect.grow(24.0).has_point(enemy_screen):
		return false
	var player_screen := camera.unproject_position(player.global_position + Vector3(0, 0.22, 0))
	if player_screen.distance_to(enemy_screen) > visible_radius:
		return false
	var facing_screen := camera.unproject_position(player.global_position + _get_perception_aim_direction() * 5.0)
	var facing_screen_direction := (facing_screen - player_screen).normalized()
	var enemy_screen_direction := (enemy_screen - player_screen).normalized()
	var near_radius := lerpf(112.0, 64.0, night_intensity)
	var fan_cos := lerpf(0.06, 0.34, night_intensity)
	if laser_aim_held and player_screen.distance_to(enemy_screen) > near_radius and enemy_screen_direction.dot(facing_screen_direction) < fan_cos:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.42, 0),
		enemy.global_position + Vector3(0, 0.42, 0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid(), enemy.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _install_perception_system() -> void:
	perception_system = PERCEPTION_SYSTEM_SCRIPT.new() as CanvasLayer
	perception_system.call("setup", player, camera)
	add_child(perception_system)


func _install_scent_system() -> void:
	scent_system = SCENT_TRAIL_MANAGER_SCRIPT.new() as Node3D
	scent_system.name = "ScentTrailManager"
	add_child(scent_system)
	scent_system.call("setup", player)
	objective_scent_guidance = OBJECTIVE_SCENT_GUIDANCE_SCRIPT.new() as Node
	objective_scent_guidance.name = "ObjectiveScentGuidance"
	add_child(objective_scent_guidance)
	objective_scent_guidance.call("setup", scent_system, player, $World)
	scent_system.connect("focus_changed", func(active: bool) -> void:
		scent_focus_active = active
		if hud.ammo_notice:
			hud.ammo_notice.text = "후각 집중 · 금빛은 임무, 초록빛은 구조 흔적" if active else ""
			hud.ammo_notice.visible = active
			ammo_notice_time = 0.35
	)


func _update_scent_system(delta: float) -> void:
	if not is_instance_valid(scent_system):
		return
	scent_system.call("set_night_factor", night_intensity)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("update_guidance", delta)
	if loafing:
		return
	scent_awareness_tick += delta
	if scent_awareness_tick < 0.3:
		return
	scent_awareness_tick = 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("add_scent_suspicion"):
			continue
		var strength: float = float(scent_system.call("get_strength_near", enemy.global_position, "player", 5.0))
		if strength >= 60.0:
			enemy.call("add_scent_suspicion", player.global_position, strength * 0.0018)


func _update_faction_conflicts(delta: float) -> void:
	faction_conflict_tick += delta
	if faction_conflict_tick < 0.8:
		return
	faction_conflict_tick = 0.0
	_update_dynamic_incident_winner_guard()
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("get_faction_id"):
			continue
		if bool(enemy.get_meta("dynamic_incident_guard", false)):
			continue
		var is_dynamic_incident_actor := bool(enemy.get_meta("dynamic_incident", false))
		if (
			not is_dynamic_incident_actor
			and enemy.has_method("is_targeting_player")
			and not bool(enemy.call("is_targeting_player"))
		):
			continue
		if not is_dynamic_incident_actor and bool(enemy.get("alerted")):
			continue
		var nearest_hostile: CharacterBody3D
		var nearest_distance := 30.0 if is_dynamic_incident_actor else 14.0
		for other in enemies:
			if (
				not is_instance_valid(other)
				or bool(other.get("dying"))
				or other == enemy
				or not other.has_method("get_faction_id")
			):
				continue
			if is_dynamic_incident_actor and not bool(other.get_meta("dynamic_incident", false)):
				continue
			if str(other.call("get_faction_id")) == str(enemy.call("get_faction_id")):
				continue
			var distance := enemy.global_position.distance_to(other.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_hostile = other
		if is_instance_valid(nearest_hostile) and enemy.has_method("set_combat_target"):
			enemy.call("set_combat_target", nearest_hostile)


func _update_dynamic_incident_winner_guard() -> void:
	if (
		dynamic_incident_state != "active"
		or not is_instance_valid(dynamic_incident_site)
		or not dynamic_incident_winning_faction.is_empty()
	):
		return
	var survivors: Array[CharacterBody3D] = []
	var surviving_factions: Array[String] = []
	for enemy in enemies:
		if (
			not is_instance_valid(enemy)
			or bool(enemy.get("dying"))
			or not bool(enemy.get_meta("dynamic_incident", false))
			or not enemy.has_method("get_faction_id")
		):
			continue
		var faction_id := str(enemy.call("get_faction_id"))
		if faction_id.is_empty():
			continue
		survivors.append(enemy)
		if not surviving_factions.has(faction_id):
			surviving_factions.append(faction_id)
	if survivors.is_empty() or surviving_factions.size() != 1:
		return
	dynamic_incident_winning_faction = surviving_factions[0]
	var route := _build_dynamic_incident_guard_route(dynamic_incident_site.global_position)
	for survivor_index in survivors.size():
		var survivor := survivors[survivor_index]
		survivor.set_meta("dynamic_incident_guard", true)
		if survivor.has_method("restore_player_target"):
			survivor.call("restore_player_target")
		if survivor.has_method("assign_squad"):
			var angle := TAU * float(survivor_index) / float(maxi(1, survivors.size()))
			var formation_offset := Vector3(cos(angle), 0.0, sin(angle)) * 1.8
			survivor.call(
				"assign_squad",
				9000,
				dynamic_incident_site.global_position,
				formation_offset
			)
		if survivor.has_method("configure_patrol"):
			var assigned_route: Array[Vector3] = []
			for route_offset in route.size():
				assigned_route.append(route[(route_offset + survivor_index) % route.size()])
			survivor.call("configure_patrol", "route", assigned_route)
	_show_field_notice("수송품 교전 종료 · 승리 세력이 보급품 주변을 경계합니다.")


func _build_dynamic_incident_guard_route(center: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var world := get_node_or_null("World") as ProceduralCityMap
	if world == null:
		route.append(center)
		return route
	for index in DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS:
		var angle := TAU * float(index) / float(DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS)
		var requested := center + Vector3(cos(angle), 0.0, sin(angle)) * DYNAMIC_INCIDENT_GUARD_RADIUS
		var position := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		position.y = 0.78
		route.append(position)
	return route


func take_damage(amount: int) -> void:
	if (
		amount <= 0
		or player_health <= 0
		or extraction_transition_active
		or player_death_sequence_active
		or boss_defeat_sequence_active
	):
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
		else _get_mouse_world_direction() if _uses_mouse_aim() else _get_current_facing_world_direction()
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
	if not GameState.bag_pressure_lesson_seen:
		_spawn_onboarding_loot_cluster(world)
	_spawn_high_value_hotspots(world)
	_setup_jackpot_event(world)
	_refresh_raid_pressure_hud()


func _setup_jackpot_event(world: ProceduralCityMap) -> void:
	hud.build_jackpot_hud()
	if not GameState.raid_special_cargo.is_empty():
		jackpot_state = "carried"
		_attach_jackpot_cargo_visual()
		_set_jackpot_step(
			"탈출 필요 · 4/4",
			"특수 화물 운반 중 · 가장 가까운 하수구로 이동하세요",
			4
		)
		return
	var occupied: Array[Vector3] = []
	for site in extraction_sites:
		if is_instance_valid(site):
			occupied.append(site.global_position)
	var clue_position := _find_stratified_map_position(world, 1, 3, 34.0, 22.0, occupied, 0.08)
	occupied.append(clue_position)
	jackpot_power_position = _find_stratified_map_position(world, 2, 3, 42.0, 26.0, occupied, 0.08)
	occupied.append(jackpot_power_position)
	jackpot_cargo_position = _find_stratified_map_position(world, 0, 3, 48.0, 30.0, occupied, 0.08)
	jackpot_state = "clue"
	jackpot_clue_site = _create_field_interaction(
		"jackpot_clue",
		clue_position,
		"격리 수송 기록 판독",
		1.6
	)
	jackpot_clue_site.name = "JackpotManifestTerminal"
	jackpot_clue_site.set_meta("interaction_distance", 3.2)
	_build_jackpot_prop(
		jackpot_clue_site,
		SUBWAY_MANIFEST_TERMINAL_TEXTURE,
		0.00105,
		Color("#62c9ca"),
		0.95
	)
	_set_jackpot_step(
		"특별 기회 · 격리 신호 0/4",
		"TAB 지도 확인 → 주황 신호의 단말을 조사하세요",
		0
	)
	call_deferred("_register_jackpot_map_marker", "jackpot_clue", clue_position, "불명 격리 신호")


func _set_jackpot_step(title: String, detail: String, step: int) -> void:
	if not is_instance_valid(hud.jackpot_hud):
		return
	hud.jackpot_step_label.text = title
	hud.jackpot_detail_label.text = detail
	hud.jackpot_progress.value = clampi(step, 0, 4)
	hud.jackpot_hud.modulate.a = 0.35
	var tween := create_tween()
	tween.tween_property(hud.jackpot_hud, "modulate:a", 1.0, 0.25)
	tween.tween_property(hud.jackpot_hud, "modulate", Color("#fff0c9"), 0.12)
	tween.tween_property(hud.jackpot_hud, "modulate", Color.WHITE, 0.28)


func _build_jackpot_prop(
	point: Node3D,
	texture: Texture2D,
	pixel_size: float,
	color: Color,
	height: float
) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "JackpotPropSprite"
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position.y = height
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 12
	point.add_child(sprite)
	_add_interaction_marker(point, color, 1.35, false)
	var beacon := Sprite3D.new()
	beacon.name = "JackpotBeacon"
	beacon.texture = _get_loot_glow_texture()
	beacon.position = Vector3(0, 2.35, 0)
	beacon.pixel_size = 0.0065
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.shaded = false
	beacon.transparent = true
	beacon.no_depth_test = true
	beacon.render_priority = 122
	beacon.modulate = color
	point.add_child(beacon)


func _register_jackpot_map_marker(
	marker_id: String,
	position: Vector3,
	label: String
) -> void:
	if is_instance_valid(tactical_map) and tactical_map.has_method("register_raid_marker"):
		tactical_map.call("register_raid_marker", marker_id, position, "jackpot", label, true)


func _remove_jackpot_map_marker(marker_id: String) -> void:
	if is_instance_valid(tactical_map) and tactical_map.has_method("remove_raid_marker"):
		tactical_map.call("remove_raid_marker", marker_id)


func _handle_jackpot_clue() -> void:
	jackpot_state = "power"
	_remove_jackpot_map_marker("jackpot_clue")
	jackpot_power_site = _create_field_interaction(
		"jackpot_power",
		jackpot_power_position,
		"지하선 비상 전력 복구",
		2.8
	)
	jackpot_power_site.name = "JackpotEmergencyGenerator"
	jackpot_power_site.set_meta("interaction_distance", 3.4)
	_build_jackpot_prop(
		jackpot_power_site,
		SUBWAY_EMERGENCY_GENERATOR_TEXTURE,
		0.00115,
		Color("#e7a847"),
		0.72
	)
	_register_jackpot_map_marker(
		"jackpot_power",
		jackpot_power_position,
		"지하선 비상 발전기"
	)
	_set_jackpot_step(
		"비상 전력 복구 · 1/4",
		"주황 발전기로 이동해 전력을 복구하세요",
		1
	)
	_show_field_notice("격리 기록 복원 · 지하선 3번 화물의 비상 전력 좌표가 지도에 표시됩니다.")


func _handle_jackpot_power() -> void:
	jackpot_state = "alarm"
	jackpot_alarm_wave_timer = 0.8
	jackpot_alarm_waves_spawned = 0
	_remove_jackpot_map_marker("jackpot_power")
	jackpot_cargo_site = _create_field_interaction(
		"jackpot_cargo",
		jackpot_cargo_position,
		"봉인 화물 분리",
		4.2
	)
	jackpot_cargo_site.name = "JackpotSealedCargo"
	jackpot_cargo_site.set_meta("interaction_distance", 3.5)
	_build_jackpot_prop(
		jackpot_cargo_site,
		SUBWAY_SEALED_CARGO_TEXTURE,
		0.00118,
		Color("#e66a47"),
		0.82
	)
	_register_jackpot_map_marker(
		"jackpot_cargo",
		jackpot_cargo_position,
		"경보 발생 · 봉인 화물"
	)
	_set_jackpot_step(
		"봉인 화물 회수 · 2/4",
		"붉은 화물 위치로 이동 · 접근하는 약탈대를 경계하세요",
		2
	)
	_show_jackpot_alarm_flash()
	_show_field_notice("경보 발생 · 봉인 화물 좌표 노출 · 접근하는 대응대를 경계하십시오.")


func _show_jackpot_alarm_flash() -> void:
	var flash := ColorRect.new()
	flash.name = "JackpotAlarmFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.16, 0.06, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 81
	$HUD.add_child(flash)
	var tween := create_tween()
	for pulse in 3:
		tween.tween_property(flash, "color:a", 0.16, 0.12)
		tween.tween_property(flash, "color:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func _update_jackpot_event(delta: float) -> void:
	if jackpot_state != "alarm" or jackpot_alarm_waves_spawned >= JACKPOT_ALARM_WAVE_COUNT:
		return
	jackpot_alarm_wave_timer -= delta
	if jackpot_alarm_wave_timer > 0.0:
		return
	_spawn_jackpot_alarm_wave()
	jackpot_alarm_waves_spawned += 1
	jackpot_alarm_wave_timer = JACKPOT_ALARM_WAVE_INTERVAL
	_set_jackpot_step(
		"봉인 화물 회수 · 3/4",
		"대응대 %d/%d · 화물에 접근해 분리하세요" % [
			jackpot_alarm_waves_spawned,
			JACKPOT_ALARM_WAVE_COUNT,
		],
		3
	)


func _spawn_jackpot_alarm_wave() -> void:
	var world := $World as ProceduralCityMap
	var anchor := _find_event_position_near_player(world, 17.0, 26.0)
	var kinds: Array[String] = ["pistol", "melee"]
	if jackpot_alarm_waves_spawned == 1:
		kinds = ["pistol", "pistol"]
	elif jackpot_alarm_waves_spawned >= 2:
		kinds = ["pistol", "grenadier", "pistol"]
	_spawn_enemy_squad(
		world,
		anchor,
		kinds,
		maxf(0.58, night_intensity),
		jackpot_cargo_position,
		{"jackpot_response": true}
	)


func _attempt_take_jackpot_cargo(point: Node3D) -> void:
	var cargo := {
		"id": "seoul_line3_relief_core",
		"title": "서울 지하선 3번 보급 코어",
		"description": "인간 격리 당시 보호소 이송 명부와 냉각 보급품이 함께 봉인된 대형 화물입니다.",
	}
	if not GameState.can_add_raid_item("special_cargo", str(cargo.id), 1):
		_show_bag_full_notice()
		return
	_claim_jackpot_cargo(point)


func _claim_jackpot_cargo(point: Node3D) -> void:
	if not is_instance_valid(point):
		return
	var cargo := {
		"id": "seoul_line3_relief_core",
		"title": "서울 지하선 3번 보급 코어",
		"description": "인간 격리 당시 보호소 이송 명부와 냉각 보급품이 함께 봉인된 대형 화물입니다.",
	}
	if not GameState.try_take_story_cargo(cargo):
		_show_bag_full_notice()
		return
	point.set_meta("completed", true)
	field_interactions.erase(point)
	nearby_field_interaction = null
	field_interaction_hold_time = 0.0
	field_interaction_keyboard_held = false
	hud.field_interaction_touch_held = false
	if hud.field_interaction_panel:
		hud.field_interaction_panel.visible = false
	_remove_jackpot_map_marker("jackpot_cargo")
	point.queue_free()
	jackpot_cargo_site = null
	jackpot_state = "carried"
	_attach_jackpot_cargo_visual()
	GameState.save_persistent_state()
	_set_jackpot_step(
		"탈출 필요 · 4/4",
		"특수 화물 운반 중 · 가장 가까운 하수구로 이동하세요",
		4
	)
	_show_field_notice("특수 화물 확보 · 탈출 시 특별 보상과 기록 해금")


func _attach_jackpot_cargo_visual() -> void:
	if is_instance_valid(jackpot_carried_sprite):
		return
	jackpot_carried_sprite = Sprite3D.new()
	jackpot_carried_sprite.name = "CarriedSubwayCargo"
	jackpot_carried_sprite.texture = SUBWAY_SEALED_CARGO_TEXTURE
	jackpot_carried_sprite.pixel_size = 0.00048
	jackpot_carried_sprite.position = Vector3(-0.62, 0.48, 0.42)
	jackpot_carried_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	jackpot_carried_sprite.shaded = false
	jackpot_carried_sprite.transparent = true
	jackpot_carried_sprite.no_depth_test = true
	jackpot_carried_sprite.render_priority = 124
	player.add_child(jackpot_carried_sprite)


func _restore_jackpot_cargo_presentation() -> void:
	if GameState.raid_special_cargo.is_empty():
		return
	for site in [jackpot_clue_site, jackpot_power_site, jackpot_cargo_site]:
		if not is_instance_valid(site):
			continue
		field_interactions.erase(site)
		site.queue_free()
	jackpot_clue_site = null
	jackpot_power_site = null
	jackpot_cargo_site = null
	for marker_id in ["jackpot_clue", "jackpot_power", "jackpot_cargo"]:
		_remove_jackpot_map_marker(marker_id)
	jackpot_state = "carried"
	_attach_jackpot_cargo_visual()
	_set_jackpot_step(
		"화물 재회수 · 4/4",
		"되찾은 특수 화물을 운반해 하수구로 탈출하세요",
		4
	)


func _spawn_high_value_hotspots(world: ProceduralCityMap) -> void:
	raid_hotspots.clear()
	var occupied_positions: Array[Vector3] = []
	for site in extraction_sites:
		if is_instance_valid(site):
			occupied_positions.append(site.global_position)
	var hotspot_types := ["military", "pharmacy", "sealed_parts"]
	for index in RAID_HOTSPOT_COUNT:
		var position := _find_stratified_map_position(
			world,
			index,
			RAID_HOTSPOT_COUNT,
			30.0,
			24.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(position)
		var hotspot_type: String = hotspot_types[index % hotspot_types.size()]
		var display_name := "봉쇄 약국 응급 캐시"
		if hotspot_type == "military":
			display_name = "잠긴 군용 보급함"
		elif hotspot_type == "sealed_parts":
			display_name = "기밀 정비 부품함"
		var point := _create_field_interaction(
			"high_value_cache",
			position,
			display_name,
			3.0
		)
		var marker_id := "hotspot_%02d" % index
		point.name = "HighValueHotspot_%02d" % index
		point.set_meta("hotspot_type", hotspot_type)
		point.set_meta("map_marker_id", marker_id)
		point.set_meta("map_discovered", false)
		point.set_meta("interaction_distance", 3.2)
		_build_high_value_hotspot_prop(point, hotspot_type)
		raid_hotspots.append(point)


func _build_high_value_hotspot_prop(point: Node3D, hotspot_type: String) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "HotspotSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 9
	sprite.position.y = 0.72
	var color := Color("#dfb85d")
	match hotspot_type:
		"pharmacy":
			sprite.texture = PHARMACY_EMERGENCY_CACHE_TEXTURE
			sprite.pixel_size = 0.00145
			sprite.position.y = 1.02
			color = Color("#62d5d8")
		"sealed_parts":
			sprite.texture = SECURE_MILITARY_CACHE_TEXTURE
			sprite.pixel_size = 0.00185
			sprite.modulate = Color("#b6cee0")
			color = Color("#8fb9db")
		_:
			sprite.texture = SECURE_MILITARY_CACHE_TEXTURE
			sprite.pixel_size = 0.00185
	point.add_child(sprite)
	_add_interaction_marker(point, color, 1.55, false)
	var marker := Sprite3D.new()
	marker.name = "HotspotBeacon"
	marker.texture = _get_loot_glow_texture()
	marker.position = Vector3(0, 2.35, 0)
	marker.pixel_size = 0.0055
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.transparent = true
	marker.no_depth_test = true
	marker.render_priority = 121
	marker.modulate = color
	point.add_child(marker)


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
	# 시간은 가장 약한 입력이다. 소란을 피우면 훨씬 빨리 오른다.
	raid_pressure_points += RAID_EVENT_DIRECTOR.PRESSURE_PER_SECOND * delta
	if not raid_curfew_active and RAID_EVENT_DIRECTOR.is_stealth_decay_allowed(raid_seconds_since_noise):
		raid_pressure_points = maxf(
			0.0,
			raid_pressure_points - RAID_EVENT_DIRECTOR.PRESSURE_DECAY_PER_SECOND * delta
		)
	var next_pressure_level: int = RAID_EVENT_DIRECTOR.resolve_level(raid_pressure_points)
	if next_pressure_level != raid_pressure_level:
		_apply_raid_pressure_level(next_pressure_level)
	_tick_raid_event_director(delta)
	_refresh_raid_pressure_hud()
	_update_hotspot_discovery()
	_update_dynamic_incident(delta)


func _spawn_onboarding_loot_cluster(world: ProceduralCityMap) -> void:
	# 첫 판에서 가방 갈등을 반드시 한 번 겪게 한다. 부피가 큰 원자재와
	# 값비싼 소형 물품을 같이 깔아, 무엇을 실을지 고르게 만든다.
	var origin := player.global_position
	# 한 자리에 몰아 두면 "왜 이렇게 많아?"가 된다. 수를 줄이고 넓게 흩뿌린다.
	var plan := [
		{"type": "raw_scrap", "amount": 8, "data": {}},
		{"type": "raw_catnip", "amount": 6, "data": {}},
		{"type": "medkit", "amount": 1, "data": {}},
		{"type": "mod_component", "amount": 1, "data": {"component_id": "scope_lens"}},
	]
	for index in plan.size():
		var entry := plan[index] as Dictionary
		var angle := TAU * float(index) / float(plan.size()) + spawn_random.randf_range(-0.4, 0.4)
		var radius := spawn_random.randf_range(9.0, 16.0)
		var drop := origin + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var data := (entry["data"] as Dictionary).duplicate()
		data["amount"] = int(entry["amount"])
		_create_loot_pickup(
			str(entry["type"]),
			world.find_nearest_open_position(drop),
			data
		)


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
	raid_event_cooldown = RAID_EVENT_DIRECTOR.get_event_interval(raid_pressure_level)
	if event_id.is_empty():
		return
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
	_seal_one_extraction_route()


func _event_blackout() -> void:
	_apply_raid_blackout()


func _event_supply_drop() -> void:
	_spawn_raid_supply_drop()


func _event_convoy_wreck() -> void:
	# 예전 _update_dynamic_incident의 자체 타이머를 디렉터가 대신한다.
	if dynamic_incident_state == "active":
		return
	dynamic_incident_state = "scheduled"
	_spawn_dynamic_convoy_incident($World as ProceduralCityMap)


func _event_spawn_overwatch() -> void:
	# 트인 길을 위험하게 만든다. 원거리 사수 둘이 자리를 잡는다.
	var world := $World as ProceduralCityMap
	if world == null:
		return
	var post := _find_event_position_near_player(world, 22.0, 34.0)
	_spawn_enemy_squad(
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
	var cache_position := _find_event_position_near_player(world, 14.0, 26.0)
	for index in 3:
		var angle := TAU * float(index) / 3.0
		var drop := cache_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.4
		_create_loot_pickup(
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
	var spawn_position := _find_event_position_near_player(world, 26.0, 38.0)
	var kinds: Array[String] = ["pistol", "melee"] if level < 2 else ["pistol", "pistol", "grenadier"]
	_spawn_enemy_squad(
		world,
		spawn_position,
		kinds,
		clampf(0.4 + level * 0.2, 0.0, 1.0),
		player.global_position,
		{"raid_pressure_response": level}
	)


func _seal_one_extraction_route() -> void:
	# 탈출로 하나를 실제로 잠근다. 계획이 무너지는 순간을 만드는 장치다.
	var sites := get_tree().get_nodes_in_group("field_extraction")
	var candidates: Array[Node3D] = []
	for site in sites:
		if not is_instance_valid(site):
			continue
		var node := site as Node3D
		if int(node.get_meta("extraction_index", 0)) == 0:
			continue  # 기본 귀환로는 남겨 둔다. 완전히 갇히면 좌절만 남는다.
		if bool(node.get_meta("extraction_sealed", false)):
			continue
		candidates.append(node)
	if candidates.is_empty():
		return
	var target := candidates[raid_event_random.randi_range(0, candidates.size() - 1)]
	target.set_meta("extraction_sealed", true)
	raid_sealed_extraction_index = int(target.get_meta("extraction_index", -1))
	target.remove_from_group("field_extraction")
	for child in target.get_children():
		if child is Sprite3D:
			(child as Sprite3D).modulate = Color(0.42, 0.36, 0.36, 0.85)
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if is_instance_valid(tactical_map) and tactical_map.has_method("seal_extraction"):
		tactical_map.call("seal_extraction", raid_sealed_extraction_index)


func _apply_raid_blackout() -> void:
	# 시야는 좁아지지만 적의 경계도 함께 떨어진다. 손해만 있는 사건은 재미없다.
	var tween := create_tween()
	tween.tween_method(_set_blackout_strength, 0.0, 1.0, 1.2)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("apply_blackout"):
			enemy.call("apply_blackout")


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
	var drop_position := _find_event_position_near_player(world, 18.0, 32.0)
	_create_loot_pickup(
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
	raid_pressure_level = clampi(
		new_level,
		0,
		RAID_PRESSURE_REWARD_MULTIPLIERS.size() - 1
	)
	raid_reward_multiplier = float(
		RAID_PRESSURE_REWARD_MULTIPLIERS[raid_pressure_level]
	)
	if raid_pressure_level <= 0:
		return
	var world := $World as ProceduralCityMap
	var response_position := _find_event_position_near_player(
		world,
		30.0,
		42.0
	)
	var kinds: Array[String] = ["pistol", "melee"]
	if raid_pressure_level >= 2:
		kinds = ["pistol", "pistol", "melee"]
	if raid_pressure_level >= 3:
		kinds = ["pistol", "pistol", "grenadier"]
	_spawn_enemy_squad(
		world,
		response_position,
		kinds,
		clampf(0.35 + raid_pressure_level * 0.2, 0.0, 1.0),
		player.global_position,
		{"raid_pressure_response": raid_pressure_level}
	)
	# 단계가 오르면 즉시 한 건 터뜨린다. 나머지는 디렉터가 주기적으로 판단한다.
	raid_event_cooldown = 0.0


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
	hud.raid_pressure_bar.value = minf(
		raid_elapsed_seconds,
		float(RAID_PRESSURE_THRESHOLDS.back())
	)
	hud.raid_pressure_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(color.darkened(0.12), color.lightened(0.12), 7)
	)


func _update_hotspot_discovery() -> void:
	for point in raid_hotspots:
		if (
			not is_instance_valid(point)
			or bool(point.get_meta("completed", false))
			or bool(point.get_meta("map_discovered", false))
		):
			continue
		if player.global_position.distance_to(point.global_position) > RAID_HOTSPOT_DISCOVERY_DISTANCE:
			continue
		point.set_meta("map_discovered", true)
		var marker_id := str(point.get_meta("map_marker_id", ""))
		if is_instance_valid(tactical_map) and tactical_map.has_method("discover_raid_marker"):
			tactical_map.call("discover_raid_marker", marker_id)
		_show_field_notice(
			"고가치 지점 발견 · %s" % str(point.get_meta("display_name", "보급 거점"))
		)


func _update_dynamic_incident(delta: float) -> void:
	# 발동 시점은 이제 raid_event_director가 정한다. 여기서는 진행 중인
	# 사건의 남은 시간과 HUD만 돌본다.
	if dynamic_incident_state != "active":
		return
	dynamic_incident_timer = maxf(0.0, dynamic_incident_timer - delta)
	if is_instance_valid(hud.dynamic_incident_hud):
		var distance := (
			player.global_position.distance_to(dynamic_incident_site.global_position)
			if is_instance_valid(dynamic_incident_site)
			else 0.0
		)
		var remaining := ceili(dynamic_incident_timer)
		hud.dynamic_incident_detail.text = "수송품 쟁탈전 · %dm · %02d:%02d" % [
			roundi(distance),
			remaining / 60,
			remaining % 60,
		]
		hud.dynamic_incident_progress.value = dynamic_incident_timer
	if dynamic_incident_timer <= 0.0:
		_expire_dynamic_incident()


func _spawn_dynamic_convoy_incident(world: ProceduralCityMap) -> void:
	if dynamic_incident_state != "scheduled":
		return
	dynamic_incident_winning_faction = ""
	var incident_position := _find_event_position_near_player(world, 36.0, 58.0)
	dynamic_incident_site = _create_field_interaction(
		"dynamic_incident_cache",
		incident_position,
		"추락 수송대 보급품 확보",
		2.8
	)
	dynamic_incident_site.name = "DynamicConvoyIncident"
	dynamic_incident_site.set_meta("map_marker_id", "dynamic_convoy")
	dynamic_incident_site.set_meta("map_discovered", true)
	dynamic_incident_site.set_meta("interaction_distance", 3.5)
	var sprite := Sprite3D.new()
	sprite.name = "ConvoyWreck"
	sprite.texture = CRASHED_CONVOY_CACHE_TEXTURE
	sprite.pixel_size = 0.0019
	sprite.position.y = 0.86
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 9
	dynamic_incident_site.add_child(sprite)
	_add_interaction_marker(
		dynamic_incident_site,
		Color("#e76549"),
		1.85,
		false
	)
	var conflict_axis := Vector3(
		spawn_random.randf_range(-1.0, 1.0),
		0.0,
		spawn_random.randf_range(-1.0, 1.0)
	).normalized()
	if conflict_axis.length_squared() < 0.1:
		conflict_axis = Vector3.RIGHT
	var first_anchor := world.find_nearest_physically_open_position(
		incident_position + conflict_axis * 6.5,
		0.62,
		[player.get_rid()]
	)
	var second_anchor := world.find_nearest_physically_open_position(
		incident_position - conflict_axis * 6.5,
		0.62,
		[player.get_rid()]
	)
	first_anchor.y = 0.78
	second_anchor.y = 0.78
	var first_squad := _spawn_enemy_squad(
		world,
		first_anchor,
		["pistol", "melee"],
		maxf(0.45, night_intensity),
		Vector3.INF,
		{"dynamic_incident": true}
	)
	var second_squad := _spawn_enemy_squad(
		world,
		second_anchor,
		["pistol", "pistol"],
		maxf(0.5, night_intensity),
		Vector3.INF,
		{"dynamic_incident": true}
	)
	for enemy in first_squad:
		enemy.call("set_faction", "raider")
	for enemy in second_squad:
		enemy.call("set_faction", "feral")
	if not first_squad.is_empty() and not second_squad.is_empty():
		for enemy in first_squad:
			enemy.call("set_combat_target", second_squad[0])
		for enemy in second_squad:
			enemy.call("set_combat_target", first_squad[0])
	dynamic_incident_state = "active"
	dynamic_incident_timer = DYNAMIC_INCIDENT_DURATION
	hud.dynamic_incident_hud.visible = true
	hud.dynamic_incident_progress.value = DYNAMIC_INCIDENT_DURATION
	if is_instance_valid(tactical_map) and tactical_map.has_method("register_raid_marker"):
		tactical_map.call(
			"register_raid_marker",
			"dynamic_convoy",
			incident_position,
			"incident",
			"추락 수송대",
			true
		)
	_show_field_notice("돌발 사건 · 두 약탈 세력이 추락 수송품을 두고 교전합니다.")


func _find_event_position_near_player(
	world: ProceduralCityMap,
	minimum_distance: float,
	maximum_distance: float
) -> Vector3:
	var map_limit := world.get_map_limit() - 8.0
	var fallback := _find_random_field_position(world, minimum_distance)
	for attempt in 48:
		var angle := TAU * float(attempt) / 48.0 + spawn_random.randf_range(-0.08, 0.08)
		var distance := spawn_random.randf_range(minimum_distance, maximum_distance)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		var player_distance := candidate.distance_to(player.global_position)
		if (
			player_distance >= minimum_distance
			and player_distance <= maximum_distance
			and not world.is_position_in_safe_zone(candidate)
		):
			return candidate
	return fallback


func _expire_dynamic_incident() -> void:
	dynamic_incident_state = "expired"
	if is_instance_valid(hud.dynamic_incident_hud):
		hud.dynamic_incident_hud.visible = false
	if is_instance_valid(tactical_map) and tactical_map.has_method("remove_raid_marker"):
		tactical_map.call("remove_raid_marker", "dynamic_convoy")
	if is_instance_valid(dynamic_incident_site):
		field_interactions.erase(dynamic_incident_site)
		field_loot_containers.erase(dynamic_incident_site)
		dynamic_incident_site.queue_free()
	dynamic_incident_site = null
	_show_field_notice("돌발 사건 종료 · 수송품이 다른 세력에게 넘어갔습니다.")


func _complete_raid_opportunity(point: Node3D) -> void:
	var interaction_type := str(point.get_meta("interaction_type", ""))
	var spawned_count := 0
	if interaction_type == "dynamic_incident_cache":
		spawned_count = _spawn_dynamic_incident_rewards(point.global_position)
		dynamic_incident_state = "claimed"
		dynamic_incident_site = null
		if is_instance_valid(hud.dynamic_incident_hud):
			hud.dynamic_incident_hud.visible = false
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


func _spawn_dynamic_incident_rewards(origin: Vector3) -> int:
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(raid_zone_data)
	var random := RandomNumberGenerator.new()
	random.seed = GameState.map_seed ^ 0x51C7 ^ hash(origin)
	var container_type := "secure_cache" if stage_tier >= 3 else "weapon_case"
	var definitions: Array[Dictionary] = LOOT_ECONOMY.roll_container(
		container_type,
		stage_tier,
		"open_space_edge",
		random
	)
	var spawned_count := _spawn_opportunity_definitions(
		origin,
		definitions,
		false
	)
	for item_id in ["ammo", "medkit", "scope_lens"]:
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
	_create_loot_pickup(loot_type, origin + offset, data)
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


func _find_random_extraction_position(
	world: ProceduralCityMap,
	random: RandomNumberGenerator,
	minimum_player_distance: float,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var map_limit := world.get_map_limit() * 0.82
	var fallback := world.get_extraction_position()
	fallback.y = 0.08
	var fallback_separation := -1.0
	for _attempt in 160:
		var requested := Vector3(
			random.randf_range(-map_limit, map_limit),
			0.08,
			random.randf_range(-map_limit, map_limit)
		)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		if candidate.distance_to(player.global_position) < minimum_player_distance:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var nearest_extraction_distance := INF
		for occupied_position in occupied_positions:
			nearest_extraction_distance = minf(
				nearest_extraction_distance,
				candidate.distance_to(occupied_position)
			)
		if occupied_positions.is_empty():
			nearest_extraction_distance = 32.0
		if nearest_extraction_distance > fallback_separation:
			fallback = candidate
			fallback_separation = nearest_extraction_distance
		if nearest_extraction_distance >= 32.0:
			return candidate
	return fallback


func _setup_extraction_site(world: ProceduralCityMap) -> void:
	extraction_sites.clear()
	discovered_extraction_indices.clear()
	var extraction_random := RandomNumberGenerator.new()
	extraction_random.seed = (
		int(GameState.map_seed)
		^ (int(GameState.raid_serial) * 982451653)
		^ 0x45584954
	)
	var positions: Array[Vector3] = []
	for index in 3:
		positions.append(_find_random_extraction_position(
			world,
			extraction_random,
			24.0 + float(index) * 3.0,
			positions
		))
	for index in positions.size():
		var site := _create_extraction_beacon(positions[index], index)
		extraction_sites.append(site)
		field_interactions.append(site)
		if index == 0:
			site.set_meta("map_discovered", true)
			discovered_extraction_indices[index] = true
	extraction_site = extraction_sites[0]
	extraction_position = extraction_site.global_position
	extraction_prompt = hud.field_interaction_panel

	extraction_fade = ColorRect.new()
	extraction_fade.name = "ExtractionFade"
	extraction_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	extraction_fade.color = Color(0, 0, 0, 0)
	extraction_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extraction_fade.z_index = 500
	$HUD.add_child(extraction_fade)
	extraction_success_label = Label.new()
	extraction_success_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	extraction_success_label.text = "탈출 성공"
	extraction_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_success_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extraction_success_label.add_theme_font_override("font", preload("res://assets/fonts/Pretendard-Regular.otf"))
	extraction_success_label.add_theme_font_size_override("font_size", 44)
	extraction_success_label.add_theme_color_override("font_color", Color("#e6dfc4"))
	extraction_success_label.modulate.a = 0.0
	extraction_success_label.z_index = 501
	$HUD.add_child(extraction_success_label)
	hud.build_extraction_progress_ui()


func _show_extraction_result(rescued_count: int) -> void:
	_refresh_pointer_mode()
	_update_combat_overlay_visibility()
	var combat_xp := GameState.get_raid_experience_reward(run_kills, run_boss_kills)
	var cargo_result := _settle_jackpot_cargo()
	var cargo_xp := int(cargo_result.get("xp", 0))
	var base_xp_reward := combat_xp + completed_mission_xp + cargo_xp
	var xp_reward := roundi(float(base_xp_reward) * selected_extraction_multiplier)
	var route_xp_bonus := maxi(0, xp_reward - base_xp_reward)
	var route_bonus := _grant_extraction_route_bonus()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(selected_extraction_index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	hud.extraction_route_icon.texture = UI_ICONS.get_icon("raid", 44, route_color)
	hud.extraction_route_label.text = "%s  ·  정산 배율 ×%.2f\n%s" % [
		selected_extraction_title,
		selected_extraction_multiplier,
		str(route_bonus.get("summary", "경로 보급 보너스 없음")),
	]
	hud.extraction_route_label.add_theme_color_override(
		"font_color",
		route_color.lightened(0.18)
	)
	pending_extraction_xp_result = GameState.add_raid_experience(xp_reward)
	hud.extraction_result_title.text = "탈출 성공 · Lv.%d" % int(pending_extraction_xp_result.get("new_level", GameState.player_level))
	var mission_summary := "완료한 임무 없음"
	if not completed_mission_titles.is_empty():
		mission_summary = "완료 임무 · %s · 임무 XP +%d" % [
			", ".join(completed_mission_titles),
			completed_mission_xp,
		]
	var cargo_summary := str(cargo_result.get("summary", "특별 화물 없음"))
	hud.extraction_result_summary.text = "처치 %d명 · 보스 %d명 · 주민 후송 %d명\n%s\n%s\n%s ×%.2f · 경로 XP +%d · 총 경험치 +%d\n%s\n획득품은 가방에 보존됩니다." % [
		run_kills,
		run_boss_kills,
		rescued_count,
		mission_summary,
		cargo_summary,
		selected_extraction_title,
		selected_extraction_multiplier,
		route_xp_bonus,
		xp_reward,
		str(route_bonus.get("summary", "경로 보급 보너스 없음")),
	]
	var new_xp := int(pending_extraction_xp_result.get("new_xp", GameState.player_xp))
	var required := maxi(1, int(pending_extraction_xp_result.get("new_required", GameState.get_xp_required())))
	hud.extraction_xp_bar.value = float(new_xp) / float(required) * 100.0
	hud.extraction_xp_label.text = "Lv.%d   %d / %d XP" % [GameState.player_level, new_xp, required]
	hud.extraction_result_panel.visible = true
	if GameState.pending_level_choices > 0:
		_show_level_reward_choices()
	else:
		var wait_tween := create_tween()
		wait_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		wait_tween.tween_interval(1.25)
		wait_tween.tween_callback(_finish_extraction_to_shelter)


func _settle_jackpot_cargo() -> Dictionary:
	var cargo := GameState.complete_story_cargo()
	if cargo.is_empty():
		return {"xp": 0, "summary": "특별 화물 없음"}
	GameState.canned_food += 8
	GameState.churu += 1
	GameState.add_mod_component("scope_lens", 1)
	var cargo_lore := (
		"붉은비 격리 기록 · 3번선 마지막 명부\n"
		+ "봉인된 명부에는 인간이 떠나기 직전 개방한 고양이 보호소 27곳이 적혀 있었다. "
		+ "누군가는 재난의 마지막 순간까지 이 도시의 작은 생존자들이 지하로 도망칠 길을 남겨 두었다."
	)
	if not GameState.unlocked_contract_lore.has(cargo_lore):
		GameState.unlocked_contract_lore.append(cargo_lore)
	if is_instance_valid(jackpot_carried_sprite):
		jackpot_carried_sprite.queue_free()
	jackpot_carried_sprite = null
	return {
		"xp": 220,
		"summary": "지하선 3번 보급 코어 개봉 · 통조림 +8 · 츄르 +1 · 스코프 렌즈 +1 · XP +220\n새 세계 기록 · ‘3번선 마지막 명부’ 해금",
	}


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
	wait_tween.tween_callback(_finish_extraction_to_shelter)


func _finish_extraction_to_shelter() -> void:
	get_tree().paused = false
	GameState.returning_from_shelter = false
	GameState.register_shelter_return()
	SceneTransition.transition_to("res://scenes/shelter_interior.tscn")


func _grant_extraction_route_bonus() -> Dictionary:
	var bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(
		selected_extraction_index,
		raid_hotspots_opened,
		dynamic_incident_state == "claimed",
		run_kills,
		GameState.map_seed
	)
	GameState.canned_food += int(bonus.get("food", 0))
	GameState.medkits += int(bonus.get("medkits", 0))
	var component_id := str(bonus.get("component_id", ""))
	var component_count := int(bonus.get("component_count", 0))
	if not component_id.is_empty() and component_count > 0:
		GameState.add_mod_component(component_id, component_count)
	return bonus


func _create_extraction_beacon(world_position: Vector3, index: int) -> Node3D:
	var site := Node3D.new()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	var route_title := str(route_definition.get("title", "안전 귀환로"))
	var reward_multiplier := float(route_definition.get("reward_multiplier", 1.0))
	site.name = "SewerExtraction_%02d" % (index + 1)
	add_child(site)
	site.global_position = Vector3(world_position.x, 0.08, world_position.z)
	site.set_meta("interaction_type", "extraction")
	site.set_meta(
		"display_name",
		"안전 귀환 하수구" if index == 0 else route_title
	)
	site.set_meta("hold_duration", 0.0)
	site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE)
	site.set_meta("extraction_index", index)
	site.set_meta("map_discovered", false)
	site.set_meta("route_title", route_title)
	site.set_meta("reward_multiplier", reward_multiplier)
	site.set_meta("route_color", route_color)
	site.add_to_group("field_extraction")

	var sewer_sprite := Sprite3D.new()
	sewer_sprite.name = "SewerHatch"
	sewer_sprite.texture = EXTRACTION_BEACON_TEXTURE
	# The generated beacon is a taller freestanding prop than the old flat hatch.
	# Keep its footprint inside the extraction ring and lift the visual bottom to
	# the ground line instead of letting the transparent canvas sink below it.
	sewer_sprite.pixel_size = 0.0022
	sewer_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sewer_sprite.shaded = false
	sewer_sprite.transparent = true
	sewer_sprite.position.y = 0.92
	sewer_sprite.render_priority = 4
	site.add_child(sewer_sprite)

	_add_interaction_marker(site, route_color, 1.55, true)
	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(
		route_color.r,
		route_color.g,
		route_color.b,
		0.12
	)
	beam_material.emission_enabled = true
	beam_material.emission = route_color
	beam_material.emission_energy_multiplier = 1.8
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.28
	beam_mesh.bottom_radius = 1.25
	beam_mesh.height = 5.5
	beam_mesh.radial_segments = 24
	beam_mesh.material = beam_material
	var beam := MeshInstance3D.new()
	beam.name = "ExtractionBeacon"
	beam.position.y = 2.75
	beam.mesh = beam_mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(beam)

	var light := OmniLight3D.new()
	light.name = "ExtractionLight"
	light.position.y = 1.15
	light.light_color = route_color
	light.light_energy = 3.2
	light.omni_range = 7.5
	light.shadow_enabled = false
	site.add_child(light)
	return site


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
	objective_panel.visible = not lines.is_empty()
	_apply_hud_layout()


func _setup_procedural_field_missions(world: ProceduralCityMap) -> void:
	field_mission_sites.clear()
	active_field_mission = null
	active_mission_collectibles.clear()
	objective_panel.visible = false
	var occupied_positions: Array[Vector3] = []
	for site in extraction_sites:
		if is_instance_valid(site):
			occupied_positions.append(site.global_position)
	for interaction in field_interactions:
		if is_instance_valid(interaction):
			occupied_positions.append(interaction.global_position)
	for index in FIELD_MISSION_COUNT:
		var mission_position := _find_randomized_mission_position(
			world,
			38.0,
			36.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(mission_position)
		var definition := _pick_field_mission_definition(index)
		var mission_site := Node3D.new()
		mission_site.name = "FieldMission_%02d" % (index + 1)
		add_child(mission_site)
		mission_site.global_position = mission_position
		mission_site.set_meta("mission_id", index + 1)
		mission_site.set_meta("status", "waiting")
		mission_site.set_meta("interaction_type", "mission_start")
		mission_site.set_meta(
			"display_name",
			"현장 작전 · %s · %s" % [
				_get_field_mission_category(str(definition.get("type", "defense"))),
				str(definition.get("title", "현장 임무")),
			]
		)
		mission_site.set_meta("hold_duration", FIELD_MISSION_START_HOLD_DURATION)
		mission_site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE + 0.45)
		mission_site.set_meta("completed", false)
		for key in definition:
			mission_site.set_meta(str(key), definition[key])
		mission_site.add_to_group("field_mission_site")
		mission_site.add_to_group("field_interaction")
		field_mission_sites.append(mission_site)
		field_interactions.append(mission_site)
		_build_field_mission_marker(mission_site)


func _pick_field_mission_definition(index: int) -> Dictionary:
	return FIELD_MISSION_CATALOG.pick_definition(index, mission_random)


func _get_field_mission_category(mission_type: String) -> String:
	return FIELD_MISSION_CATALOG.get_category(mission_type)


func _get_field_mission_active_radius() -> float:
	return float(raid_zone_data.get("mission_radius", FIELD_MISSION_ACTIVE_RADIUS))


func _get_field_mission_fail_radius() -> float:
	return maxf(FIELD_MISSION_FAIL_RADIUS, _get_field_mission_active_radius() * 3.0)


func _get_field_mission_rules(site: Node3D) -> String:
	return FIELD_MISSION_CATALOG.build_rules(
		str(site.get_meta("type", "defense")),
		bool(site.get_meta("silence_required", false)),
		_get_field_mission_fail_radius()
	)


func _format_field_mission_reward(reward: Dictionary) -> String:
	return FIELD_MISSION_CATALOG.format_reward(reward)


func _build_field_mission_marker(site: Node3D) -> void:
	var mission_type := str(site.get_meta("type", "defense"))
	var marker_color := Color("#5eb9ad")
	var marker_text := "F · %s 작전" % _get_field_mission_category(mission_type)
	match mission_type:
		"stealth":
			marker_color = Color("#6aa8b9")
		"investigate":
			marker_color = Color("#c5a964")
		"stealth_reach":
			marker_color = Color("#78b59a")
	var marker_material := StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(marker_color, 0.16)
	marker_material.emission_enabled = true
	marker_material.emission = marker_color
	marker_material.emission_energy_multiplier = 1.2
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.5
	ring_mesh.outer_radius = 2.64
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 12
	ring_mesh.material = marker_material
	var ring := MeshInstance3D.new()
	ring.name = "MissionBoundary"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(ring)
	site.set_meta("marker_material", marker_material)

	var active_boundary_material := StandardMaterial3D.new()
	active_boundary_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	active_boundary_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	active_boundary_material.albedo_color = Color(marker_color, 0.10)
	active_boundary_material.emission_enabled = true
	active_boundary_material.emission = marker_color
	active_boundary_material.emission_energy_multiplier = 0.65
	var active_boundary_mesh := TorusMesh.new()
	var active_radius := _get_field_mission_active_radius()
	active_boundary_mesh.inner_radius = active_radius - 0.18
	active_boundary_mesh.outer_radius = active_radius
	active_boundary_mesh.rings = 64
	active_boundary_mesh.ring_segments = 12
	active_boundary_mesh.material = active_boundary_material
	var active_boundary := MeshInstance3D.new()
	active_boundary.name = "MissionPlayArea"
	active_boundary.position.y = 0.025
	active_boundary.mesh = active_boundary_mesh
	active_boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	active_boundary.visible = false
	site.add_child(active_boundary)
	site.set_meta("active_boundary_material", active_boundary_material)

	var marker_label := Label3D.new()
	marker_label.name = "MissionMarkerLabel"
	marker_label.text = marker_text
	marker_label.position = Vector3(0.0, 1.15, 0.0)
	marker_label.font = FONT
	marker_label.font_size = 28
	marker_label.modulate = marker_color.lightened(0.2)
	marker_label.outline_size = 7
	marker_label.outline_modulate = Color(0.01, 0.02, 0.018, 0.94)
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_label.no_depth_test = true
	site.add_child(marker_label)
	var mission_icon_path := str(GENERATED_MISSION_ICON_PATHS.get(mission_type, ""))
	if not mission_icon_path.is_empty() and ResourceLoader.exists(mission_icon_path):
		var mission_icon := Sprite3D.new()
		mission_icon.name = "MissionIcon"
		mission_icon.texture = load(mission_icon_path) as Texture2D
		mission_icon.pixel_size = 0.0048
		mission_icon.position = Vector3(0.0, 0.66, 0.0)
		mission_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mission_icon.shaded = false
		mission_icon.transparent = true
		mission_icon.no_depth_test = true
		mission_icon.render_priority = 18
		site.add_child(mission_icon)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("register_site", site, "mission", "objective", 7.0)


func _update_field_missions(delta: float) -> void:
	if field_mission_result_timer > 0.0:
		field_mission_result_timer = maxf(0.0, field_mission_result_timer - delta)
		if field_mission_result_timer <= 0.0 and not is_instance_valid(active_field_mission):
			field_objective_title = ""
			field_objective_detail = ""
			_refresh_objective_panel()
	if not is_instance_valid(active_field_mission):
		return

	var distance_to_site := player.global_position.distance_to(active_field_mission.global_position)
	if distance_to_site > _get_field_mission_fail_radius():
		_fail_field_mission("작전 구역을 너무 멀리 이탈했습니다.")
		return

	if field_mission_phase == "preparing":
		field_mission_prepare_timer = maxf(0.0, field_mission_prepare_timer - delta)
		_set_field_mission_objective(
			"작전 준비 · %s" % str(active_field_mission.get_meta("title", "현장 임무")),
			"시작까지 %.1f초 · 주변을 확인하고 엄폐하십시오." % field_mission_prepare_timer,
			Color("#f0c96d")
		)
		if field_mission_prepare_timer <= 0.0:
			_activate_field_mission()
		return

	field_mission_runtime += delta
	_update_field_mission_waves(delta)
	var mission_type := str(active_field_mission.get_meta("type", "defense"))
	match mission_type:
		"defense":
			_update_defense_mission(delta, distance_to_site)
		"eliminate":
			_update_eliminate_mission()
		"collect":
			_update_collect_mission()
		"stealth":
			_update_stealth_mission(delta, distance_to_site)
		"investigate":
			_update_investigation_mission(delta)
		"stealth_reach":
			_update_stealth_reach_mission(delta)


func _start_field_mission(site: Node3D) -> void:
	active_field_mission = site
	site.set_meta("status", "active")
	field_mission_elapsed = 0.0
	field_mission_wave_timer = FIELD_MISSION_FIRST_WAVE_DELAY
	field_mission_prepare_timer = FIELD_MISSION_PREPARE_DURATION
	field_mission_phase = "preparing"
	field_mission_spawned_enemies = 0
	field_mission_kills = 0
	field_mission_collected = 0
	field_mission_result_timer = 0.0
	field_mission_runtime = 0.0
	field_mission_detection_time = 0.0
	field_mission_investigation_hold = 0.0
	field_mission_investigation_target = null
	field_mission_noise_breached = false
	_clear_active_mission_collectibles()
	_set_field_mission_site_state(site, "preparing")
	_set_field_mission_objective(
		"작전 준비 · %s" % str(site.get_meta("title", "현장 임무")),
		"시작까지 %.1f초 · 준비가 끝나기 전에는 적이 투입되지 않습니다." % field_mission_prepare_timer,
		Color("#f0c96d")
	)
	_show_field_notice("작전 수락 · %d초 후 시작" % ceili(FIELD_MISSION_PREPARE_DURATION))


func _activate_field_mission() -> void:
	if not is_instance_valid(active_field_mission):
		return
	field_mission_phase = "active"
	field_mission_prepare_timer = 0.0
	field_mission_wave_timer = FIELD_MISSION_FIRST_WAVE_DELAY
	field_mission_runtime = 0.0
	_set_field_mission_site_state(active_field_mission, "active")
	var mission_type := str(active_field_mission.get_meta("type", "defense"))
	match mission_type:
		"collect":
			_spawn_field_mission_collectibles(int(active_field_mission.get_meta("target_count", 3)))
		"investigate":
			_spawn_field_mission_investigation_points(int(active_field_mission.get_meta("target_count", 3)))
		"stealth_reach":
			_spawn_field_mission_reach_target(float(active_field_mission.get_meta("target_distance", 13.5)))
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "현장 임무")),
		str(active_field_mission.get_meta("description", "현장 목표를 수행하십시오.")),
		Color("#efd06f")
	)
	_show_field_notice("현장 임무 시작 · 첫 위협 접근 %.1f초" % FIELD_MISSION_FIRST_WAVE_DELAY)


func _get_field_mission_enemy_total() -> int:
	if not is_instance_valid(active_field_mission):
		return 0
	var mission_type := str(active_field_mission.get_meta("type", "defense"))
	if mission_type in ["stealth", "investigate", "stealth_reach"]:
		return int(active_field_mission.get_meta("guard_count", 0))
	return int(active_field_mission.get_meta("enemy_count", 0))


func _update_field_mission_waves(delta: float) -> void:
	if field_mission_phase != "active" or not is_instance_valid(active_field_mission):
		return
	var total_enemies := _get_field_mission_enemy_total()
	if total_enemies <= 0 or field_mission_spawned_enemies >= total_enemies:
		return
	field_mission_wave_timer = maxf(0.0, field_mission_wave_timer - delta)
	if field_mission_wave_timer > 0.0:
		return
	var progress := float(field_mission_spawned_enemies) / float(maxi(1, total_enemies))
	var wave_size := 3 if progress >= 0.55 else 2
	wave_size = mini(wave_size, total_enemies - field_mission_spawned_enemies)
	var mission_type := str(active_field_mission.get_meta("type", "defense"))
	if mission_type in ["stealth", "investigate", "stealth_reach"]:
		_spawn_field_mission_patrols(wave_size, progress)
	else:
		_spawn_field_mission_enemies(wave_size, progress)
	field_mission_wave_timer = lerpf(4.2, 2.2, progress)


func _get_field_mission_wave_status() -> String:
	var total_enemies := _get_field_mission_enemy_total()
	if total_enemies <= 0:
		return ""
	var stage := clampi(
		1 + floori(3.0 * float(field_mission_spawned_enemies) / float(maxi(1, total_enemies))),
		1,
		3
	)
	if field_mission_spawned_enemies < total_enemies:
		return "다음 접근 %.1f초 · 위협 %d단계" % [field_mission_wave_timer, stage]
	return "현장 투입 완료 · 위협 %d단계" % stage


func _update_defense_mission(delta: float, distance_to_site: float) -> void:
	var hold_radius := _get_field_mission_active_radius()
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
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "구역 방어")),
		detail,
		Color("#efd06f") if inside_hold_area else Color("#ff9b77")
	)
	if field_mission_elapsed >= duration and field_mission_spawned_enemies >= enemy_count:
		_complete_field_mission()


func _update_eliminate_mission() -> void:
	var target_count := int(active_field_mission.get_meta("target_count", 5))
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "적 소탕")),
		"임무 대상 제거  %d / %d" % [mini(field_mission_kills, target_count), target_count],
		Color("#efd06f")
	)
	if field_mission_kills >= target_count:
		_complete_field_mission()


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
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "물자 회수")),
		"현장 목표물 회수  %d / %d" % [mini(field_mission_collected, target_count), target_count],
		Color("#efd06f")
	)
	if field_mission_collected >= target_count:
		_complete_field_mission()


func _update_stealth_mission(delta: float, distance_to_site: float) -> void:
	if field_mission_noise_breached:
		_fail_field_mission("총성이 울려 잠복 위치가 노출됐습니다.")
		return
	var detected := _update_field_mission_detection(delta)
	var detection_grace := float(active_field_mission.get_meta("detection_grace", 1.25))
	if field_mission_detection_time >= detection_grace:
		_fail_field_mission("수색대에게 위치를 들켰습니다.")
		return
	var hold_radius := FIELD_MISSION_STEALTH_HOLD_RADIUS
	var inside_hide_area := distance_to_site <= hold_radius
	if inside_hide_area and not detected:
		field_mission_elapsed += delta
	var duration := float(active_field_mission.get_meta("duration", 15.0))
	var remaining := maxf(0.0, duration - field_mission_elapsed)
	var detail := "엄폐 상태 유지  %.1f초" % remaining
	var color := Color("#8fd0c1")
	if detected:
		detail = "발각 위험 · 시야를 끊으십시오  %.1f / %.1f초" % [
			field_mission_detection_time,
			detection_grace,
		]
		color = Color("#ff9b77")
	elif not inside_hide_area:
		detail = "은신 지점으로 복귀하십시오 · 거리 %.0fm" % distance_to_site
		color = Color("#d7bd72")
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "은밀 잠복")),
		detail,
		color
	)
	if field_mission_elapsed >= duration:
		_complete_field_mission()


func _update_investigation_mission(delta: float) -> void:
	var silence_required := bool(active_field_mission.get_meta("silence_required", false))
	if silence_required and field_mission_noise_breached:
		_fail_field_mission("총성으로 조사 현장이 노출됐습니다.")
		return
	var detected := _update_field_mission_detection(delta)
	var detection_grace := float(active_field_mission.get_meta("detection_grace", 1.25))
	if silence_required and field_mission_detection_time >= detection_grace:
		_fail_field_mission("감시망에 발각되어 기록을 확보하지 못했습니다.")
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
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "현장 조사")),
		detail,
		color
	)
	if field_mission_collected >= target_count:
		_complete_field_mission()


func _update_stealth_reach_mission(delta: float) -> void:
	if field_mission_noise_breached:
		_fail_field_mission("총성이 울려 우회 경로가 차단됐습니다.")
		return
	var detected := _update_field_mission_detection(delta)
	var detection_grace := float(active_field_mission.get_meta("detection_grace", 1.0))
	if field_mission_detection_time >= detection_grace:
		_fail_field_mission("순찰대에게 우회 이동을 들켰습니다.")
		return
	var target := active_mission_collectibles[0] if not active_mission_collectibles.is_empty() else null
	if not is_instance_valid(target):
		_fail_field_mission("안전 지점 신호를 찾을 수 없습니다.")
		return
	var target_distance := player.global_position.distance_to((target as Node3D).global_position)
	var detail := "안전 지점까지 %.1fm · 시야에 들지 마십시오." % target_distance
	var color := Color("#8fd0c1")
	if detected:
		detail = "발각 위험 · 엄폐물 뒤로 이동하십시오  %.1f / %.1f초" % [
			field_mission_detection_time,
			detection_grace,
		]
		color = Color("#ff9b77")
	_set_field_mission_objective(
		str(active_field_mission.get_meta("title", "감시망 우회")),
		detail,
		color
	)
	if target_distance <= 1.55:
		_complete_field_mission()


func _update_field_mission_detection(delta: float) -> bool:
	if field_mission_runtime < 1.0:
		field_mission_detection_time = 0.0
		return false
	var detected := _is_player_detected_for_field_mission()
	if detected:
		field_mission_detection_time += delta
	else:
		field_mission_detection_time = maxf(0.0, field_mission_detection_time - delta * 1.8)
	return detected


func _is_player_detected_for_field_mission() -> bool:
	if not is_instance_valid(active_field_mission):
		return false
	var mission_id := int(active_field_mission.get_meta("mission_id", -1))
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if int(enemy.get_meta("field_mission_id", -2)) != mission_id:
			continue
		if bool(enemy.get("alerted")) and bool(enemy.get("has_current_line_of_sight")):
			return true
	return false


func _active_field_mission_requires_silence() -> bool:
	return (
		is_instance_valid(active_field_mission)
		and bool(active_field_mission.get_meta("silence_required", false))
	)


func _spawn_field_mission_enemies(count: int, escalation: float = 0.0) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var world := $World as ProceduralCityMap
	var mission_id := int(active_field_mission.get_meta("mission_id", 0))
	for squad_size in _build_enemy_squad_sizes(count):
		var squad_anchor := _find_field_mission_enemy_position(
			world,
			active_field_mission.global_position
		)
		var kinds: Array[String] = []
		for member_index in squad_size:
			var loadout_roll := posmod(
				field_mission_spawned_enemies + member_index + mission_id,
				7
			)
			kinds.append(
				"grenadier"
					if loadout_roll == 6
					else ("melee" if loadout_roll == 4 else "pistol")
			)
		var threat := maxf(
			night_intensity,
			float(raid_zone_data.get("threat", 0.0)) + 0.16 + escalation * 0.34
		)
		var spawned := _spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			threat,
			active_field_mission.global_position,
			{"field_mission_id": mission_id}
		)
		field_mission_spawned_enemies += spawned.size()


func _spawn_field_mission_patrols(count: int, escalation: float = 0.0) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var world := $World as ProceduralCityMap
	var mission_id := int(active_field_mission.get_meta("mission_id", 0))
	var patrol_index := 0
	for squad_size in _build_enemy_squad_sizes(count):
		var squad_anchor := _find_field_mission_enemy_position(
			world,
			active_field_mission.global_position
		)
		var kinds: Array[String] = []
		for member_index in squad_size:
			kinds.append("melee" if (patrol_index + member_index) % 4 == 3 else "pistol")
		var threat := maxf(
			night_intensity,
			float(raid_zone_data.get("threat", 0.0)) + 0.08 + escalation * 0.26
		)
		var spawned := _spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			threat,
			Vector3.INF,
			{
				"field_mission_id": mission_id,
				"stealth_mission_guard": true,
			}
		)
		field_mission_spawned_enemies += spawned.size()
		patrol_index += squad_size


func _find_field_mission_enemy_position(
	world: ProceduralCityMap,
	mission_position: Vector3
) -> Vector3:
	var fallback := world.find_nearest_physically_open_position(
		mission_position + Vector3(FIELD_MISSION_ENEMY_MAX_SITE_DISTANCE, 0.0, 0.0),
		0.72,
		[player.get_rid()]
	)
	fallback.y = 0.08
	for attempt in 32:
		var angle := spawn_random.randf_range(0.0, TAU)
		var distance := spawn_random.randf_range(
			FIELD_MISSION_ENEMY_MIN_SITE_DISTANCE,
			FIELD_MISSION_ENEMY_MAX_SITE_DISTANCE
		)
		var candidate := world.find_nearest_physically_open_position(
			mission_position + Vector3(cos(angle), 0.0, sin(angle)) * distance,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		fallback = candidate
		if (
			candidate.distance_to(player.global_position) >= FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE
			and not world.is_position_in_safe_zone(candidate)
		):
			return candidate
	if fallback.distance_to(player.global_position) < FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE:
		var reinforcement_position := _find_reinforcement_position()
		if reinforcement_position != Vector3.INF:
			return reinforcement_position
	return fallback


func _spawn_field_mission_investigation_points(count: int) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var world := $World as ProceduralCityMap
	for index in count:
		var angle := (
			TAU * float(index) / float(maxi(1, count))
			+ spawn_random.randf_range(-0.42, 0.42)
		)
		var distance := spawn_random.randf_range(12.0, 24.0)
		var requested := (
			active_field_mission.global_position
			+ Vector3(cos(angle), 0.0, sin(angle)) * distance
		)
		var position := world.find_nearest_physically_open_position(
			requested,
			0.52,
			[player.get_rid()]
		)
		var clue := Node3D.new()
		clue.name = "MissionClue_%02d" % (index + 1)
		add_child(clue)
		clue.global_position = Vector3(position.x, 0.08, position.z)
		_build_field_mission_investigation_point(clue)
		active_mission_collectibles.append(clue)


func _build_field_mission_investigation_point(clue: Node3D) -> void:
	var case_material := StandardMaterial3D.new()
	case_material.albedo_color = Color("#39443f")
	case_material.metallic = 0.38
	case_material.roughness = 0.72
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.52, 0.12, 0.38)
	case_mesh.material = case_material
	var case := MeshInstance3D.new()
	case.name = "EvidenceCase"
	case.position.y = 0.11
	case.rotation.y = spawn_random.randf_range(-0.45, 0.45)
	case.mesh = case_mesh
	clue.add_child(case)
	var signal_material := StandardMaterial3D.new()
	signal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	signal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	signal_material.albedo_color = Color(0.92, 0.73, 0.32, 0.72)
	signal_material.emission_enabled = true
	signal_material.emission = Color("#d8b456")
	signal_material.emission_energy_multiplier = 2.0
	var signal_mesh := CylinderMesh.new()
	signal_mesh.top_radius = 0.09
	signal_mesh.bottom_radius = 0.12
	signal_mesh.height = 0.06
	signal_mesh.material = signal_material
	var signal_marker := MeshInstance3D.new()
	signal_marker.name = "EvidenceSignal"
	signal_marker.position.y = 0.21
	signal_marker.mesh = signal_mesh
	clue.add_child(signal_marker)
	_add_interaction_marker(clue, Color("#d8b456"), 0.58, false)
	var label := Label3D.new()
	label.name = "EvidenceLabel"
	label.text = "조사"
	label.position = Vector3(0.0, 0.86, 0.0)
	label.font = FONT
	label.font_size = 23
	label.modulate = Color("#f0d994")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	clue.add_child(label)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("register_site", clue, "active_target", "objective", 6.0)


func _spawn_field_mission_reach_target(target_distance: float) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var world := $World as ProceduralCityMap
	var angle := spawn_random.randf_range(0.0, TAU)
	var requested := (
		active_field_mission.global_position
		+ Vector3(cos(angle), 0.0, sin(angle)) * maxf(30.0, target_distance)
	)
	var position := world.find_nearest_physically_open_position(
		requested,
		0.62,
		[player.get_rid()]
	)
	var target := Node3D.new()
	target.name = "StealthReachTarget"
	add_child(target)
	target.global_position = Vector3(position.x, 0.08, position.z)
	_build_field_mission_reach_target(target)
	active_mission_collectibles.append(target)


func _build_field_mission_reach_target(target: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.34, 0.78, 0.58, 0.22)
	material.emission_enabled = true
	material.emission = Color("#67c898")
	material.emission_energy_multiplier = 1.8
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 0.94
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 10
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.name = "SafeRouteRing"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(ring)
	var label := Label3D.new()
	label.name = "ReachTargetLabel"
	label.text = "안전 지점"
	label.position = Vector3(0.0, 1.02, 0.0)
	label.font = FONT
	label.font_size = 25
	label.modulate = Color("#9be0bb")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	target.add_child(label)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("register_site", target, "active_target", "objective", 6.5)


func _spawn_field_mission_collectibles(count: int) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var world := $World as ProceduralCityMap
	for index in count:
		var angle := TAU * float(index) / float(maxi(1, count)) + spawn_random.randf_range(-0.35, 0.35)
		var requested := (
			active_field_mission.global_position
			+ Vector3(cos(angle), 0.0, sin(angle))
			* spawn_random.randf_range(11.0, 22.0)
		)
		var position := world.find_nearest_physically_open_position(
			requested,
			0.52,
			[player.get_rid()]
		)
		var collectible := Node3D.new()
		collectible.name = "MissionCollectible_%02d" % (index + 1)
		add_child(collectible)
		collectible.global_position = Vector3(position.x, 0.08, position.z)
		_build_field_mission_collectible(collectible)
		active_mission_collectibles.append(collectible)


func _build_field_mission_collectible(collectible: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#e2c56a")
	material.emission_enabled = true
	material.emission = Color("#f2cf69")
	material.emission_energy_multiplier = 2.2
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.28
	mesh.height = 0.42
	mesh.radial_segments = 12
	mesh.material = material
	var prop := MeshInstance3D.new()
	prop.name = "MissionCollectibleSignal"
	prop.position.y = 0.24
	prop.mesh = mesh
	collectible.add_child(prop)
	_add_interaction_marker(collectible, Color("#efd06f"), 0.68, false)
	var label := Label3D.new()
	label.name = "MissionCollectibleLabel"
	label.text = "회수"
	label.position = Vector3(0.0, 0.94, 0.0)
	label.font = FONT
	label.font_size = 24
	label.modulate = Color("#ffe79a")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	collectible.add_child(label)
	if is_instance_valid(objective_scent_guidance):
		objective_scent_guidance.call("register_site", collectible, "active_target", "objective", 6.0)


func _complete_field_mission() -> void:
	if not is_instance_valid(active_field_mission):
		return
	var completed_site := active_field_mission
	completed_site.set_meta("status", "completed")
	var reward_text := _grant_field_mission_reward(
		completed_site.get_meta("reward", {}) as Dictionary
	)
	var mission_title := str(completed_site.get_meta("title", "현장 임무"))
	if not completed_mission_titles.has(mission_title):
		completed_mission_titles.append(mission_title)
		completed_mission_xp += 70
	_set_field_mission_site_state(completed_site, "completed")
	_set_field_mission_objective(
		"임무 완료 · %s" % mission_title,
		"보상  %s · 경험치 +70" % reward_text,
		Color("#7de0a8")
	)
	_show_field_notice("임무 완료 · %s" % reward_text)
	_advance_contract_progress("field_mission")
	field_mission_result_timer = FIELD_MISSION_RESULT_DURATION
	field_mission_phase = "idle"
	field_mission_prepare_timer = 0.0
	active_field_mission = null
	_clear_active_mission_collectibles()


func _fail_field_mission(reason: String) -> void:
	if not is_instance_valid(active_field_mission):
		return
	var failed_site := active_field_mission
	failed_site.set_meta("status", "failed")
	_set_field_mission_site_state(failed_site, "failed")
	_set_field_mission_objective(
		"임무 실패 · %s" % str(failed_site.get_meta("title", "현장 임무")),
		reason,
		Color("#ef796f")
	)
	_show_field_notice("임무 실패 · %s" % reason)
	field_mission_result_timer = FIELD_MISSION_RESULT_DURATION
	field_mission_phase = "idle"
	field_mission_prepare_timer = 0.0
	active_field_mission = null
	_clear_active_mission_collectibles()


func _grant_field_mission_reward(reward: Dictionary) -> String:
	var reward_parts: Array[String] = []
	var canned_food_reward := int(reward.get("canned_food", 0))
	var medkit_reward := int(reward.get("medkits", 0))
	var ammo_reward := int(reward.get("ammo", 0))
	if canned_food_reward > 0:
		GameState.canned_food += canned_food_reward
		reward_parts.append("통조림 %d" % canned_food_reward)
	if medkit_reward > 0:
		GameState.medkits += medkit_reward
		reward_parts.append("구급약 %d" % medkit_reward)
	if ammo_reward > 0:
		var ammo_id := GameState.get_mission_reward_ammo_id()
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + ammo_reward)
		if ammo_id == GameState.equipped_ammo_id:
			reserve_ammo = GameState.get_ammo_count(ammo_id)
			GameState.reserve_ammo = reserve_ammo
		reward_parts.append("%s %d발" % [
			str(WEAPON_SYSTEM.get_ammo(ammo_id).get("display_name", "탄환")),
			ammo_reward,
		])
	var component_reward := maxi(0, int(reward.get("component", 0)))
	if component_reward > 0:
		var component_ids := ["rubber_gasket", "scope_lens", "magazine_spring"]
		var component_names := ["고무 패킹", "스코프 렌즈", "탄창 스프링"]
		var rewarded_components: Array[String] = []
		for _reward_index in component_reward:
			var component_index := spawn_random.randi_range(0, component_ids.size() - 1)
			GameState.add_mod_component(component_ids[component_index], 1)
			rewarded_components.append(component_names[component_index])
		reward_parts.append("부품 %d개 · %s" % [
			component_reward,
			", ".join(rewarded_components),
		])
	GameState.save_persistent_state()
	_update_equipment_ui()
	return ", ".join(reward_parts) if not reward_parts.is_empty() else "현장 보급품"


func _set_field_mission_site_state(site: Node3D, state: String) -> void:
	var color := Color("#5eb9ad")
	var label_text := str(site.get_meta("title", "현장 임무"))
	match state:
		"preparing":
			color = Color("#e0b957")
			label_text = "작전 준비 중"
		"active":
			color = Color("#e7c765")
			label_text = "작전 진행 중"
		"completed":
			color = Color("#69d89c")
			label_text = "완료"
		"failed":
			color = Color("#d35f5f")
			label_text = "실패"
	var marker_material := site.get_meta("marker_material", null) as StandardMaterial3D
	if marker_material:
		marker_material.albedo_color = Color(color.r, color.g, color.b, 0.24)
		marker_material.emission = color
	var marker_label := site.get_node_or_null("MissionMarkerLabel") as Label3D
	if marker_label:
		marker_label.text = label_text
		marker_label.modulate = color
	var active_boundary := site.get_node_or_null("MissionPlayArea") as MeshInstance3D
	if active_boundary:
		active_boundary.visible = state in ["preparing", "active"]
	var active_boundary_material := (
		site.get_meta("active_boundary_material", null) as StandardMaterial3D
	)
	if active_boundary_material:
		active_boundary_material.albedo_color = Color(color.r, color.g, color.b, 0.10)
		active_boundary_material.emission = color


func _set_field_mission_objective(title: String, detail: String, color: Color) -> void:
	var objective_detail := detail
	var objective_title := title
	if is_instance_valid(active_field_mission):
		var category := _get_field_mission_category(
			str(active_field_mission.get_meta("type", "defense"))
		)
		if not objective_title.begins_with("["):
			objective_title = "[%s 작전] %s" % [category, objective_title]
		if (
			str(active_field_mission.get_meta("status", "")) == "active"
			and field_mission_phase == "active"
		):
			var wave_status := _get_field_mission_wave_status()
			if not wave_status.is_empty():
				var compact_detail_lines := objective_detail.split("\n", false)
				var compact_detail := (
					compact_detail_lines[0]
					if not compact_detail_lines.is_empty()
					else "현장 목표 수행 중"
				)
				objective_detail = "%s · %s" % [
					compact_detail,
					wave_status,
				]
	field_objective_title = objective_title
	field_objective_detail = objective_detail
	field_objective_color = color
	_refresh_objective_panel()


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
	_spawn_enemy_squad(
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


func _update_extraction_prompt() -> void:
	_update_field_interactions(0.0)


func _update_extraction_discovery() -> void:
	for site in extraction_sites:
		if not is_instance_valid(site) or bool(site.get_meta("map_discovered", false)):
			continue
		if not _is_extraction_in_player_sight(site):
			continue
		var index := int(site.get_meta("extraction_index", -1))
		if index < 0:
			continue
		site.set_meta("map_discovered", true)
		discovered_extraction_indices[index] = true
		if is_instance_valid(tactical_map):
			tactical_map.call("discover_extraction", index)
		_show_field_notice("탈출구 발견 · 전술 지도에 하수구 위치가 기록되었습니다.")


func _is_extraction_in_player_sight(site: Node3D) -> bool:
	var offset := site.global_position - player.global_position
	offset.y = 0.0
	var distance := offset.length()
	var in_visibility_shape := distance <= 10.5
	if not in_visibility_shape and laser_aim_held and distance <= 32.0:
		var aim_direction := _get_perception_aim_direction()
		aim_direction.y = 0.0
		in_visibility_shape = aim_direction.normalized().dot(offset.normalized()) >= cos(deg_to_rad(58.0))
	if not in_visibility_shape:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.55, 0),
		site.global_position + Vector3(0, 0.55, 0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
		hold_duration,
		locked_reason,
		float(nearby_field_interaction.get_meta("reward_multiplier", 1.0)),
		rescued_followers.size(),
		field_interaction_candidates.size(),
		next_name
	)
	var is_locked: bool = not locked_reason.is_empty()
	var action_label: String = INTERACTION_TARGETING.get_action_label(interaction_type)
	_refresh_field_interaction_visual(interaction_type, is_locked)
	if hud.field_interaction_target_label:
		hud.field_interaction_target_label.text = str(prompt_state.get("target_text", display_name))
	if hud.field_interaction_button:
		hud.field_interaction_button.disabled = bool(prompt_state.get("disabled", false))
	if hud.field_interaction_action_label:
		hud.field_interaction_action_label.text = action_label
	if hud.field_interaction_action_detail_label:
		if is_locked:
			hud.field_interaction_action_detail_label.text = locked_reason
		elif interaction_type == "extraction":
			hud.field_interaction_action_detail_label.text = "즉시 탈출 · 정산 배율 x%.2f" % float(
				nearby_field_interaction.get_meta("reward_multiplier", 1.0)
			)
		else:
			hud.field_interaction_action_detail_label.text = "길게 눌러 진행"
	if hud.field_interaction_duration_label:
		if is_locked:
			hud.field_interaction_duration_label.text = "잠김"
		elif interaction_type == "extraction":
			hud.field_interaction_duration_label.text = "즉시"
		elif field_interaction_hold_time > 0.0:
			hud.field_interaction_duration_label.text = "%.1f초 남음" % maxf(
				0.0,
				hold_duration - field_interaction_hold_time
			)
		else:
			hud.field_interaction_duration_label.text = "%.1f초" % hold_duration
	if hud.field_interaction_hint_label:
		var footer_parts: PackedStringArray = []
		if is_locked:
			footer_parts.append("조건을 충족해야 사용할 수 있습니다")
		elif interaction_type == "extraction":
			footer_parts.append("후송 주민 %d명" % rescued_followers.size())
		else:
			footer_parts.append("키를 놓으면 취소됩니다")
		if field_interaction_candidates.size() > 1:
			footer_parts.append("[G] 다음 · %s" % next_name)
		hud.field_interaction_hint_label.text = "  ·  ".join(footer_parts)
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
			_start_field_mission(point)
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
		_attempt_take_jackpot_cargo(point)
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
			_handle_jackpot_clue()
		"jackpot_power":
			_handle_jackpot_power()
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
	var definitions: Array[Dictionary] = LOOT_ECONOMY.roll_container(
		container_type,
		stage_tier,
		district,
		container_random
	)
	var spawned_count := 0
	for definition in definitions:
		if not LOOT_ECONOMY.try_register_loot(
			GameState,
			definition,
			"field",
			stage_tier
		):
			continue
		var angle := TAU * float(spawned_count) / float(maxi(1, definitions.size()))
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * (0.55 + spawned_count * 0.12)
		var data := (definition.get("data", {}) as Dictionary).duplicate(true)
		data["loot_source"] = "container"
		data["container_type"] = container_type
		_create_loot_pickup(
			str(definition.get("type", "canned_food")),
			point.global_position + offset,
			data
		)
		spawned_count += 1
	_add_fatigue(FATIGUE_LOOT_GAIN)
	if spawned_count == 0:
		_show_field_notice("%s · 비어 있습니다." % LOOT_ECONOMY.get_container_display_name(container_type))
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
		_restore_jackpot_cargo_presentation()
	var recovered_weapon_id := str(loot.get("equipped_weapon_id", ""))
	if (
		not recovered_weapon_id.is_empty()
		and GameState.get_weapon_count(recovered_weapon_id) > 0
		and not has_ak
	):
		_on_inventory_weapon_equipped(recovered_weapon_id)
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
		_create_loot_pickup("mod_component", origin + offset, {
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
	_trigger_fatigue_boss_event()


func _add_fatigue(amount: float) -> void:
	if amount <= 0.0:
		return
	fatigue = clampf(fatigue + amount * GameState.get_fatigue_gain_multiplier(), 0.0, FATIGUE_MAX)
	GameState.fatigue = fatigue
	_refresh_fatigue_hud()
	_trigger_fatigue_boss_event()


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
	if hud.fatigue_bar:
		hud.fatigue_bar.visible = next_warning_band > 0
	if hud.fatigue_status_label:
		hud.fatigue_status_label.text = (
			"%d%% · %s" % [roundi(fatigue), status]
			if next_warning_band > 0
			else "안정"
		)
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


func _begin_extraction() -> void:
	if extraction_transition_active or player_death_sequence_active or player_health <= 0:
		return
	if is_instance_valid(nearby_field_interaction):
		selected_extraction_index = int(
			nearby_field_interaction.get_meta("extraction_index", 0)
		)
		selected_extraction_multiplier = float(
			nearby_field_interaction.get_meta("reward_multiplier", 1.0)
		)
		selected_extraction_title = str(
			nearby_field_interaction.get_meta("route_title", "안전 귀환로")
		)
	else:
		selected_extraction_index = 0
		selected_extraction_multiplier = 1.0
		selected_extraction_title = "안전 귀환로"
	extraction_transition_active = true
	_refresh_pointer_mode()
	_update_combat_overlay_visibility()
	extraction_prompt.visible = false
	fire_button_held = false
	mouse_fire_held = false
	laser_aim_held = false
	field_interaction_keyboard_held = false
	hud.field_interaction_touch_held = false
	pickup_touch_held = false
	touch_vector = Vector2.ZERO
	player.velocity = Vector3.ZERO
	recoil_velocity = Vector3.ZERO
	if is_instance_valid(extraction_fade):
		extraction_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var rescued_count := _commit_rescued_followers()
	extraction_success_label.text = "탈출 성공 · %s" % selected_extraction_title
	GameState.finish_corpse_recovery_attempt()
	_save_run_state()
	get_tree().paused = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(extraction_fade, "color:a", 1.0, 0.65)
	tween.tween_property(extraction_success_label, "modulate:a", 1.0, 0.32)
	tween.tween_interval(0.55)
	tween.tween_property(extraction_success_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_show_extraction_result.bind(rescued_count))


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
		_reload_ak47()
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
			_spawn_test_boss_near_player()
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
					_begin_extraction()
					field_interaction_keyboard_held = false
				else:
					field_interaction_keyboard_held = key_event.pressed
				pickup_keyboard_held = false
			elif key_event.pressed and is_instance_valid(nearby_ammo_pickup):
				_collect_nearby_ammo()
				pickup_keyboard_held = false
			else:
				field_interaction_keyboard_held = false
				pickup_keyboard_held = key_event.pressed
		elif key == KEY_R and key_event.pressed and has_ak:
			_reload_ak47()
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
			if _try_stealth_takedown():
				mouse_fire_held = false
			elif laser_aim_held and has_ak and (magazine_ammo > 0 or reserve_ammo > 0):
				mouse_fire_held = true
				_try_fire_ak47()
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
			_lock_aim_direction(_get_mouse_world_direction())


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
	_update_visibility_fog()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for audio_player in gunshot_players:
		if is_instance_valid(audio_player):
			audio_player.stop()
	if is_instance_valid(roll_audio_player):
		roll_audio_player.stop()
	if is_instance_valid(bgm_player):
		bgm_player.stop()
	if not DisplayServer.is_touchscreen_available():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
