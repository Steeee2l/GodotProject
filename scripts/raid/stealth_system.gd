class_name StealthSystem
extends RefCounted

# 잠입 — 시야 안개, 냄새 흔적, 적 가시성 판정, 상황별 처형.
# main.gd에서 14개 함수를 옮겼다.


const AIM_REVEAL_BUILDING_ALPHA := 0.28
const AK_PICKUP_POSITION := Vector3(1.15, 0.32, 0.7)
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const BASE_CAMERA_SIZE := 28.0
const BASE_ENEMY_COUNT := 24
const BOSS_DEFEAT_CAMERA_SIZE := 19.5
const BOSS_DEFEAT_FOCUS_SECONDS := 1.65
const BOSS_DEFEAT_SLOWMO_SECONDS := 1.05
const BOSS_DEFEAT_TIME_SCALE := 0.20
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const DEEP_NIGHT_HOUR := 22.0
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
const ENEMY_PAIR_SQUAD_CHANCE := 0.78
const ENEMY_VISIBILITY_FADE_IN_SPEED := 10.0
const ENEMY_VISIBILITY_FADE_OUT_SPEED := 3.2
const ENEMY_VISIBILITY_HOLD_SECONDS := 0.32
const FATIGUE_DAMAGE_PER_POINT := 0.045
const FATIGUE_MAX := 100.0
const FATIGUE_MELEE_GAIN := 1.1
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_SHOT_GAIN := 0.28
const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_LOOT_CACHE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")
const FIELD_MISSION_STEALTH_HOLD_RADIUS := 14.0
const FIRST_STAGE_ZONE_ID := "jongno_outskirts"
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOOT_CONTAINER_VISUALS := preload("res://scripts/loot_container_visual_catalog.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const LORE_CLUE_COUNT := 6
const LORE_ENTRIES := preload("res://scripts/lore_catalog.gd").ENTRIES
const LORE_POSTER_TEXTURE := preload("res://assets/lore/forgotten_notice_board_v1.png")
const MAP_CONTENT_SCALE := ProceduralCityMap.WORLD_SCALE
const MAX_NIGHT_ENEMY_COUNT := 44
const MELEE_ANIMATION_DURATION := 0.5
const MELEE_ATTACK_COOLDOWN := 0.72
const MELEE_ATTACK_DAMAGE := 38
const MELEE_ATTACK_RANGE := 2.2
const MELEE_FAN_HALF_ANGLE_DEG := 56.0
const MELEE_WINDUP_DURATION := 0.18
const MOBILE_AIM_ASSIST_ANGLE_WEIGHT := 24.0
const MOBILE_AIM_ASSIST_DISTANCE_WEIGHT := 0.32
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 42.0
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 34.0
const NIGHT_START_HOUR := 19.0
const OBJECTIVE_SCENT_GUIDANCE_SCRIPT := preload("res://scripts/objective_scent_guidance.gd")
const OCCLUSION_DEPTH_LIMIT := 14.0
const OCCLUSION_LATERAL_LIMIT := 5.1
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const PERCEPTION_SYSTEM_SCRIPT := preload("res://scripts/perception_system.gd")
const PICKUP_DISTANCE := 1.75
const PICKUP_HOLD_DURATION := 0.9
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const SCENT_TRAIL_MANAGER_SCRIPT := preload("res://scripts/scent_trail_manager.gd")
const SECONDS_PER_GAME_HOUR := 36.0
const SILHOUETTE_COLOR := Color("#26343b")
const STEALTH_TAKEDOWN_CAMERA_SHAKE_SECONDS := 0.24
const STEALTH_TAKEDOWN_CAMERA_SHAKE_STRENGTH := 0.34
const STEALTH_TAKEDOWN_PROMPT_SIZE := Vector2(196.0, 54.0)
const STEALTH_TAKEDOWN_RANGE := 2.0
const STEALTH_TAKEDOWN_SLOWMO_SECONDS := 0.14
const STEALTH_TAKEDOWN_TIME_SCALE := 0.24
const STRUCTURE_REVEAL_BUILDING_ALPHA := 0.46
const STRUCTURE_REVEAL_HALF_ANGLE_DEG := 52.5
const STRUCTURE_REVEAL_RADIUS := 9.5
const STRUCTURE_REVEAL_VEHICLE_ALPHA := 0.58
const TACTICAL_MAP_SCRIPT := preload("res://scripts/tactical_map.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const WEAPON_FLOAT_DISTANCE := 0.72
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const WEAPON_MUZZLE_FORWARD_DISTANCE := 0.64
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var camera: Camera3D
var visibility_material: ShaderMaterial
var stealth_takedown_prompt: PanelContainer
var stealth_takedown_key_label: Label
var stealth_takedown_input_icon: TextureRect
var stealth_takedown_action_label: Label
var nearby_stealth_takedown_target: CharacterBody3D
var scent_awareness_tick := 0.0


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player
	camera = owner_node.camera


func _build_visibility_fog() -> void:
	host.get_node("HUD").layer = 3
	var fog_layer := CanvasLayer.new()
	fog_layer.name = "VisibilityFog"
	fog_layer.layer = 2
	host.add_child(fog_layer)
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
	var viewport_size := host.get_viewport().get_visible_rect().size
	var circle_radius := lerpf(178.0, 104.0, host.night_intensity)
	var inner_radius := lerpf(430.0, 185.0, host.night_intensity)
	var outer_radius := lerpf(560.0, 285.0, host.night_intensity)
	var brightness_floor := clampf(float(AccessibilitySettings.minimum_brightness), 0.0, 0.5)
	var edge_darkness := minf(
		lerpf(0.82, 0.97, host.night_intensity),
		0.99 - brightness_floor * 0.55
	)
	var player_screen := camera.unproject_position(player.global_position)
	var facing_screen := camera.unproject_position(player.global_position + host._get_perception_aim_direction() * 5.0)
	var facing_screen_direction: Vector2 = (facing_screen - player_screen).normalized()
	if facing_screen_direction.length_squared() <= 0.001:
		facing_screen_direction = Vector2(0.0, -1.0)
	visibility_material.set_shader_parameter("viewport_size", viewport_size)
	visibility_material.set_shader_parameter("player_screen", player_screen)
	visibility_material.set_shader_parameter("facing_screen_direction", facing_screen_direction)
	visibility_material.set_shader_parameter("inner_radius", inner_radius)
	visibility_material.set_shader_parameter("outer_radius", outer_radius)
	visibility_material.set_shader_parameter("near_radius", lerpf(112.0, 64.0, host.night_intensity))
	visibility_material.set_shader_parameter("fan_cos", lerpf(0.06, 0.34, host.night_intensity))
	visibility_material.set_shader_parameter("darkness", edge_darkness)
	visibility_material.set_shader_parameter("aim_expanded", 1.0 if host.laser_aim_held else 0.0)
	visibility_material.set_shader_parameter("circle_radius", circle_radius)


func _install_scent_system() -> void:
	host.scent_system = SCENT_TRAIL_MANAGER_SCRIPT.new() as Node3D
	host.scent_system.name = "ScentTrailManager"
	host.add_child(host.scent_system)
	host.scent_system.call("setup", player)
	host.objective_scent_guidance = OBJECTIVE_SCENT_GUIDANCE_SCRIPT.new() as Node
	host.objective_scent_guidance.name = "ObjectiveScentGuidance"
	host.add_child(host.objective_scent_guidance)
	host.objective_scent_guidance.call("setup", host.scent_system, player, host.get_node("World"))
	host.scent_system.connect("focus_changed", func(active: bool) -> void:
		host.scent_focus_active = active
		if host.hud.ammo_notice:
			host.hud.ammo_notice.text = "후각 집중 · 금빛은 임무, 초록빛은 구조 흔적" if active else ""
			host.hud.ammo_notice.visible = active
			host.ammo_notice_time = 0.35
	)


func _update_scent_system(delta: float) -> void:
	if not is_instance_valid(host.scent_system):
		return
	host.scent_system.call("set_night_factor", host.night_intensity)
	if is_instance_valid(host.objective_scent_guidance):
		host.objective_scent_guidance.call("update_guidance", delta)
	if host.loafing:
		return
	scent_awareness_tick += delta
	if scent_awareness_tick < 0.3:
		return
	scent_awareness_tick = 0.0
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("add_scent_suspicion"):
			continue
		var strength: float = float(host.scent_system.call("get_strength_near", enemy.global_position, "player", 5.0))
		if strength >= 60.0:
			enemy.call("add_scent_suspicion", player.global_position, strength * 0.0018)


func _update_enemy_visibility(delta: float = 1.0 / 60.0) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var fully_visible_radius := lerpf(178.0, 104.0, host.night_intensity)
	var reveal_radius := fully_visible_radius + lerpf(46.0, 30.0, host.night_intensity)
	if host.laser_aim_held:
		fully_visible_radius = lerpf(430.0, 185.0, host.night_intensity)
		reveal_radius = lerpf(560.0, 285.0, host.night_intensity)
	for enemy in host.enemies:
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
	var viewport_rect := host.get_viewport().get_visible_rect()
	var enemy_screen := camera.unproject_position(enemy.global_position + Vector3(0, 0.45, 0))
	if not viewport_rect.grow(24.0).has_point(enemy_screen):
		return 0.0
	var player_screen := camera.unproject_position(player.global_position + Vector3(0, 0.22, 0))
	var screen_distance := player_screen.distance_to(enemy_screen)
	if screen_distance > reveal_radius:
		return 0.0
	var facing_screen := camera.unproject_position(player.global_position + host._get_perception_aim_direction() * 5.0)
	var facing_screen_direction: Vector2 = (facing_screen - player_screen).normalized()
	var enemy_screen_direction := (enemy_screen - player_screen).normalized()
	var near_radius := lerpf(112.0, 64.0, host.night_intensity)
	var fan_cos := lerpf(0.06, 0.34, host.night_intensity)
	if host.laser_aim_held and screen_distance > near_radius and enemy_screen_direction.dot(facing_screen_direction) < fan_cos:
		return 0.0
	if screen_distance <= fully_visible_radius:
		return 1.0
	return 1.0 - smoothstep(fully_visible_radius, reveal_radius, screen_distance)


func _enemy_is_in_player_vision(enemy: Node3D, visible_radius: float) -> bool:
	if not is_instance_valid(enemy) or camera.is_position_behind(enemy.global_position):
		return false
	var viewport_rect := host.get_viewport().get_visible_rect()
	var enemy_screen := camera.unproject_position(enemy.global_position + Vector3(0, 0.45, 0))
	if not viewport_rect.grow(24.0).has_point(enemy_screen):
		return false
	var player_screen := camera.unproject_position(player.global_position + Vector3(0, 0.22, 0))
	if player_screen.distance_to(enemy_screen) > visible_radius:
		return false
	var facing_screen := camera.unproject_position(player.global_position + host._get_perception_aim_direction() * 5.0)
	var facing_screen_direction: Vector2 = (facing_screen - player_screen).normalized()
	var enemy_screen_direction := (enemy_screen - player_screen).normalized()
	var near_radius := lerpf(112.0, 64.0, host.night_intensity)
	var fan_cos := lerpf(0.06, 0.34, host.night_intensity)
	if host.laser_aim_held and player_screen.distance_to(enemy_screen) > near_radius and enemy_screen_direction.dot(facing_screen_direction) < fan_cos:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.42, 0),
		enemy.global_position + Vector3(0, 0.42, 0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid(), enemy.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _setup_stealth_takedown_prompt(font: Font) -> void:
	stealth_takedown_prompt = PanelContainer.new()
	stealth_takedown_prompt.name = "StealthTakedownPrompt"
	stealth_takedown_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stealth_takedown_prompt.custom_minimum_size = STEALTH_TAKEDOWN_PROMPT_SIZE
	stealth_takedown_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stealth_takedown_prompt.z_index = 220
	stealth_takedown_prompt.add_theme_stylebox_override(
		"panel",
		host._make_panel_style(Color(0.025, 0.032, 0.029, 0.96), Color("#e0ba66"), 6)
	)
	stealth_takedown_prompt.visible = false
	host.get_node("HUD").add_child(stealth_takedown_prompt)

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
		host._make_panel_style(Color("#d5aa55"), Color("#ffe09a"), 5)
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


func _update_stealth_takedown_prompt() -> void:
	if stealth_takedown_prompt == null:
		return
	var blocked: bool = (
		host.player_death_sequence_active
		or host.melee_attack_active
		or host.roll_active
		or host.loafing
		or host._is_inventory_open()
		or host._is_tactical_map_open()
		or host.lore_reader.is_open()
		or host.extraction_transition_active
	)
	nearby_stealth_takedown_target = null if blocked else _find_stealth_takedown_target()
	stealth_takedown_prompt.visible = is_instance_valid(nearby_stealth_takedown_target)
	if host.hud.melee_button and DisplayServer.is_touchscreen_available():
		host.hud.melee_button.text = "암살" if stealth_takedown_prompt.visible else "근접"
	if not stealth_takedown_prompt.visible:
		return
	var target_screen := camera.unproject_position(
		nearby_stealth_takedown_target.global_position + Vector3(0.0, 2.15, 0.0)
	)
	var viewport_size := host.get_viewport().get_visible_rect().size
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


func _find_stealth_takedown_target() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var nearest_distance := STEALTH_TAKEDOWN_RANGE
	for enemy in host.enemies:
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
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
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


func _try_stealth_takedown() -> bool:
	if (
		host.melee_attack_cooldown > 0.0
		or host.melee_attack_active
		or host.roll_active
		or host.loafing
		or host.player_health <= 0
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
	host.melee_attack_cooldown = MELEE_ATTACK_COOLDOWN
	host._add_fatigue(FATIGUE_MELEE_GAIN * 0.65)
	host._lock_aim_direction(attack_direction)
	host._set_facing_from_world_direction(attack_direction)
	host.melee_attack_active = true
	host.melee_attack_elapsed = 0.0
	host.melee_attack_direction = attack_direction
	host.melee_hit_resolved = true
	host.motion_state = "melee"
	host._play_directional_animation()
	host._play_bat_swing(attack_direction)
	host._spawn_player_melee_arc(attack_direction)
	nearby_stealth_takedown_target = null
	if stealth_takedown_prompt:
		stealth_takedown_prompt.visible = false
	host.state_label.text = "기습 암살"
	return true


func _play_stealth_takedown_impact() -> void:
	host.camera_shake_time = maxf(host.camera_shake_time, STEALTH_TAKEDOWN_CAMERA_SHAKE_SECONDS)
	host.camera_shake_strength = maxf(host.camera_shake_strength, STEALTH_TAKEDOWN_CAMERA_SHAKE_STRENGTH)
	host.hit_stop_serial += 1
	var serial: int = host.hit_stop_serial
	Engine.time_scale = STEALTH_TAKEDOWN_TIME_SCALE
	host.get_tree().create_timer(
		STEALTH_TAKEDOWN_SLOWMO_SECONDS,
		true,
		false,
		true
	).timeout.connect(func() -> void:
		if serial == host.hit_stop_serial and not host.player_death_sequence_active:
			Engine.time_scale = 1.0
	)


func _update_stealth_mission(delta: float, distance_to_site: float) -> void:
	if host.field_mission_noise_breached:
		host.field_missions._fail_field_mission("총성이 울려 잠복 위치가 노출됐습니다.")
		return
	var detected: bool = host.field_missions._update_field_mission_detection(delta)
	var detection_grace := float(host.active_field_mission.get_meta("detection_grace", 1.25))
	if host.field_mission_detection_time >= detection_grace:
		host.field_missions._fail_field_mission("수색대에게 위치를 들켰습니다.")
		return
	# 은신 유지 반경도 존 작전 반경에 비례한다. 고정 14m는 넓은 후반 구역에서
	# 지나치게 답답했다. 반경의 60%(약 15~24m)를 엄폐 구역으로 준다.
	var hold_radius := maxf(
		FIELD_MISSION_STEALTH_HOLD_RADIUS,
		host.field_missions._get_field_mission_active_radius() * 0.6
	)
	var inside_hide_area := distance_to_site <= hold_radius
	if inside_hide_area and not detected:
		host.field_mission_elapsed += delta
	var duration := float(host.active_field_mission.get_meta("duration", 15.0))
	var remaining := maxf(0.0, duration - host.field_mission_elapsed)
	var detail := "엄폐 상태 유지  %.1f초" % remaining
	var color := Color("#8fd0c1")
	if detected:
		detail = "발각 위험 · 시야를 끊으십시오  %.1f / %.1f초" % [
			host.field_mission_detection_time,
			detection_grace,
		]
		color = Color("#ff9b77")
	elif not inside_hide_area:
		detail = "은신 지점으로 복귀하십시오 · 거리 %.0fm" % distance_to_site
		color = Color("#d7bd72")
	host.field_missions._set_field_mission_objective(
		str(host.active_field_mission.get_meta("title", "은밀 잠복")),
		detail,
		color
	)
	if host.field_mission_elapsed >= duration:
		host.field_missions._complete_field_mission()


func _update_stealth_reach_mission(delta: float) -> void:
	if host.field_mission_noise_breached:
		host.field_missions._fail_field_mission("총성이 울려 우회 경로가 차단됐습니다.")
		return
	var detected: bool = host.field_missions._update_field_mission_detection(delta)
	var detection_grace := float(host.active_field_mission.get_meta("detection_grace", 1.0))
	if host.field_mission_detection_time >= detection_grace:
		host.field_missions._fail_field_mission("순찰대에게 우회 이동을 들켰습니다.")
		return
	var target: Node3D = host.active_mission_collectibles[0] if not host.active_mission_collectibles.is_empty() else null
	if not is_instance_valid(target):
		host.field_missions._fail_field_mission("안전 지점 신호를 찾을 수 없습니다.")
		return
	var target_distance := player.global_position.distance_to((target as Node3D).global_position)
	var detail := "안전 지점까지 %.1fm · 시야에 들지 마십시오." % target_distance
	var color := Color("#8fd0c1")
	if detected:
		detail = "발각 위험 · 엄폐물 뒤로 이동하십시오  %.1f / %.1f초" % [
			host.field_mission_detection_time,
			detection_grace,
		]
		color = Color("#ff9b77")
	host.field_missions._set_field_mission_objective(
		str(host.active_field_mission.get_meta("title", "감시망 우회")),
		detail,
		color
	)
	if target_distance <= 1.55:
		host.field_missions._complete_field_mission()
