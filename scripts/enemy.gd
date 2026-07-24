extends CharacterBody3D

signal died(enemy: CharacterBody3D)
signal reinforcement_called(enemy: CharacterBody3D)
signal damaged(enemy: CharacterBody3D, amount: int)

const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const GRENADE_PROJECTILE := preload("res://scripts/enemy_grenade.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const DAMAGE_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/damage_number.gd")
const MELEE_SPEED := 4.15
const PISTOL_SPEED := 2.5
const PATROL_SPEED := 1.35
const PATROL_RADIUS := 6.5
const SQUAD_PATROL_RADIUS := 4.2
const ENEMY_MAGAZINE_CAPACITY := {
	"m1911": 6,
	"mp5": 14,
	"ak47": 12,
	"double_barrel": 2,
}
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ENEMY_ANIMATION_ROOT := "res://assets/enemies/character_5"
const ENEMY_DIRECTION_STATES := {
	"n": "up",
	"ne": "up_right",
	"e": "right",
	"se": "down_right",
	"s": "down",
	"sw": "down_left",
	"w": "left",
	"nw": "up_left",
}
const ENEMY_FRAME_COUNT := 4
const SPRITE_BASE_POSITION := Vector3(0, 0.48, 0)
const HEALTH_BAR_Y := 1.68
const THREAT_MARKER_Y := 1.98
const RELOAD_INDICATOR_Y := 2.08
const REINFORCEMENT_ICON_Y := 2.42
const MELEE_WINDUP_TIME := 0.46
const MELEE_STRIKE_TIME := 0.16
const MELEE_RECOVERY_TIME := 0.34
const HIT_STAGGER_TIME := 0.13
const MELEE_VISION_RANGE := 12.5
const RANGED_VISION_RANGE := 15.0
const GRENADIER_VISION_RANGE := 15.5
const VISION_RANGE_THREAT_BONUS := 3.0
const VISION_HALF_ANGLE_DEGREES := 58.0
const NIGHT_VISION_RANGE_MULTIPLIER := 0.62
const COMBAT_MEMORY_BASE := 20.0
const COMBAT_MEMORY_THREAT_BONUS := 16.0
const MELEE_DISENGAGE_DISTANCE := 52.0
const RANGED_DISENGAGE_DISTANCE := 76.0
const GRENADE_WINDUP_TIME := 0.72
const GRENADE_RECOVERY_TIME := 0.9

var enemy_kind := "melee"
var target: CharacterBody3D
var health := 55
var max_health := 55
var attack_cooldown := 0.0
var sprite: AnimatedSprite3D
var shadow: MeshInstance3D
var threat_marker: Label3D
var motion_state := "idle"
var facing := "s"
var combat_state := "normal"
var state_timer := 0.0
var pending_attack_direction := Vector3.ZERO
var stagger_velocity := Vector3.ZERO
var dying := false
var visual_tween: Tween
var patrol_origin := Vector3.ZERO
var patrol_target := Vector3.ZERO
var patrol_pause := 0.0
var patrol_repath_time := 0.0
var squad_id := -1
var squad_anchor := Vector3.ZERO
var squad_formation_offset := Vector3.ZERO
var threat_level := 0.0
var alerted := false
var alert_marker_time := 0.0
var pursuit_time := 0.0
var last_known_position := Vector3.ZERO
var visual_contact_confirmed := false
var burst_shots_remaining := 0
var strafe_sign := 1.0
var strafe_switch_time := 0.0
var facing_world_direction := Vector3(1.0, 0.0, 1.0).normalized()
var backstab_stunned := false
var weapon_id := "baseball_bat"
var weapon_stats: Dictionary = {}
var weapon_visual: Sprite3D
var weapon_random := RandomNumberGenerator.new()
var current_weapon_spread := 1.0
var player_visibility_factor := 1.0
var vision_fan: MeshInstance3D
var vision_fan_material: StandardMaterial3D
var vision_fan_range := 0.0
var health_bar_background: Sprite3D
var health_bar_damage_trail: Sprite3D
var health_bar_fill: Sprite3D
var reload_indicator: Sprite3D
var shot_audio_player: AudioStreamPlayer3D
var magazine_size := 1
var magazine_ammo := 1
var reload_duration := 1.8
var reload_elapsed := 0.0
var reinforcement_call_indicator: Sprite3D
var reinforcement_call_active := false
var reinforcement_call_elapsed := 0.0
var reinforcement_call_duration := 4.6
var tactical_waypoint := Vector3.INF
var tactical_repath_timer := 0.0
var hold_position_timer := 0.0
var has_current_line_of_sight := false
var lost_sight_time := 0.0
var ambient_visibility_factor := 1.0
var target_stationary_time := 0.0
var health_ratio := 1.0
var damage_trail_ratio := 1.0
var damage_trail_delay := 0.0
var grenade_cooldown := 0.0
var grenade_target_position := Vector3.ZERO
static var weapon_texture_cache: Dictionary = {}
static var health_bar_texture_cache: Dictionary = {}
static var reload_texture_cache: Dictionary = {}
static var reinforcement_call_texture_cache: Dictionary = {}
static var enemy_gunshot_stream_cache: AudioStreamWAV


func configure(
	kind: String,
	target_body: CharacterBody3D,
	_sheets: Dictionary,
	initial_threat: float = 0.0,
	assigned_weapon_id: String = ""
) -> void:
	enemy_kind = kind
	target = target_body
	threat_level = clampf(initial_threat, 0.0, 1.0)
	weapon_id = "baseball_bat" if enemy_kind == "melee" else (assigned_weapon_id if not assigned_weapon_id.is_empty() else "m1911")
	if weapon_id != "baseball_bat":
		var no_mods: Array[String] = []
		weapon_stats = WEAPON_SYSTEM.build_stats(weapon_id, no_mods)
		current_weapon_spread = float(weapon_stats.get("base_spread_deg", 2.0))
		magazine_size = maxi(
			1,
			int(ENEMY_MAGAZINE_CAPACITY.get(
				weapon_id,
				weapon_stats.get("magazine_size", 7)
			))
		)
		magazine_ammo = magazine_size
		reload_duration = maxf(0.6, float(weapon_stats.get("reload_time", 1.8)))
	var base_health := 150 if enemy_kind == "melee" else (122 if enemy_kind == "grenadier" else 105)
	var threat_health_bonus := 70.0 if enemy_kind == "melee" else (62.0 if enemy_kind == "grenadier" else 55.0)
	health = base_health + roundi(threat_health_bonus * threat_level)
	max_health = health
	health_ratio = 1.0
	damage_trail_ratio = 1.0


func set_threat_level(value: float) -> void:
	threat_level = clampf(value, 0.0, 1.0)


func set_environment_visibility(night_factor: float) -> void:
	ambient_visibility_factor = lerpf(
		1.0,
		NIGHT_VISION_RANGE_MULTIPLIER,
		clampf(night_factor, 0.0, 1.0)
	)


func assign_squad(assigned_squad_id: int, assigned_anchor: Vector3, formation_offset: Vector3) -> void:
	squad_id = assigned_squad_id
	squad_anchor = assigned_anchor
	squad_formation_offset = formation_offset
	patrol_origin = squad_anchor + squad_formation_offset
	_choose_patrol_target()


func set_player_visibility_factor(value: float) -> void:
	player_visibility_factor = clampf(value, 0.0, 1.0)
	if sprite:
		var sprite_color := sprite.modulate
		sprite_color.a = player_visibility_factor
		sprite.modulate = sprite_color
	if weapon_visual:
		var weapon_color := weapon_visual.modulate
		weapon_color.a = player_visibility_factor
		weapon_visual.modulate = weapon_color
	if threat_marker:
		var marker_color := threat_marker.modulate
		marker_color.a = player_visibility_factor
		threat_marker.modulate = marker_color
	if reload_indicator:
		var reload_color := reload_indicator.modulate
		reload_color.a = player_visibility_factor
		reload_indicator.modulate = reload_color
	if reinforcement_call_indicator:
		var call_color := reinforcement_call_indicator.modulate
		call_color.a = player_visibility_factor
		reinforcement_call_indicator.modulate = call_color
	if shadow:
		shadow.transparency = 1.0 - player_visibility_factor
	_update_vision_fan_visual()
	_update_health_bar_visibility()


func _ready() -> void:
	add_to_group("raid_enemy")
	weapon_random.seed = get_instance_id() * 7919 + int(threat_level * 1000.0)
	grenade_cooldown = weapon_random.randf_range(2.4, 5.0)
	collision_layer = 2
	collision_mask = 3

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.3
	collision.shape = shape
	add_child(collision)

	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0, 0, 0, 0.34)
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.46
	shadow_mesh.bottom_radius = 0.46
	shadow_mesh.height = 0.015
	shadow_mesh.radial_segments = 20
	shadow_mesh.material = shadow_material
	shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.position.y = -0.7
	shadow.mesh = shadow_mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	sprite = AnimatedSprite3D.new()
	sprite.name = "EnemySprite"
	sprite.sprite_frames = _create_sprite_frames()
	sprite.position = SPRITE_BASE_POSITION
	sprite.pixel_size = 0.0092
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.no_depth_test = true
	sprite.render_priority = 30
	add_child(sprite)
	_setup_weapon_visual()
	_setup_enemy_audio()
	_setup_enemy_health_bar()
	_setup_reload_indicator()
	_setup_reinforcement_call_indicator()

	threat_marker = Label3D.new()
	threat_marker.name = "ThreatMarker"
	threat_marker.text = "◆"
	threat_marker.position = Vector3(0, THREAT_MARKER_Y, 0)
	threat_marker.font_size = 72
	threat_marker.outline_size = 18
	threat_marker.modulate = Color("#ff4d3d")
	threat_marker.outline_modulate = Color(0.12, 0.008, 0.004, 1.0)
	threat_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	threat_marker.no_depth_test = true
	threat_marker.render_priority = 120
	threat_marker.visible = false
	add_child(threat_marker)
	patrol_origin = global_position
	_choose_patrol_target()
	_play_animation()
	_update_weapon_visual()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	grenade_cooldown = maxf(0.0, grenade_cooldown - delta)
	_update_alert_marker(delta)
	_update_enemy_health_bar(delta)
	tactical_repath_timer = maxf(0.0, tactical_repath_timer - delta)
	hold_position_timer = maxf(0.0, hold_position_timer - delta)
	if dying:
		has_current_line_of_sight = false
		velocity = velocity.move_toward(Vector3.ZERO, 7.0 * delta)
		move_and_slide()
		return
	if backstab_stunned:
		has_current_line_of_sight = false
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if combat_state == "stagger":
		has_current_line_of_sight = alerted and is_instance_valid(target) and _has_line_of_sight()
		_update_stagger(delta)
		return
	has_current_line_of_sight = alerted and is_instance_valid(target) and _has_line_of_sight()
	if combat_state != "normal":
		_update_combat_state(delta)
		return
	if not is_instance_valid(target):
		has_current_line_of_sight = false
		velocity = Vector3.ZERO
		_set_motion_state("idle")
		return
	if _target_is_in_safe_zone():
		has_current_line_of_sight = false
		combat_state = "normal"
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var vision_range := _get_vision_range()
	var has_line_of_sight := _has_line_of_sight()
	has_current_line_of_sight = alerted and has_line_of_sight
	if alerted and distance > _get_disengage_distance():
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return
	var detected_in_fan := (
		not alerted
		and _is_position_inside_vision_fan(target.global_position, vision_range)
		and has_line_of_sight
	)
	if detected_in_fan:
		_become_alerted()
	if alerted and has_line_of_sight:
		last_known_position = target.global_position
		pursuit_time = COMBAT_MEMORY_BASE + COMBAT_MEMORY_THREAT_BONUS * threat_level
		lost_sight_time = 0.0
		if target.velocity.length_squared() <= 0.16:
			target_stationary_time += delta
		else:
			target_stationary_time = maxf(0.0, target_stationary_time - delta * 2.5)
	elif alerted and pursuit_time > 0.0:
		pursuit_time = maxf(0.0, pursuit_time - delta)
		lost_sight_time += delta
		target_stationary_time = maxf(0.0, target_stationary_time - delta * 0.35)
		_pursue_last_known_position()
		move_and_slide()
		return
	else:
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return

	var direction := offset.normalized() if distance > 0.01 else Vector3.ZERO
	_set_facing_from_world_direction(direction)
	if enemy_kind == "melee":
		_update_melee(direction, distance)
	elif enemy_kind == "grenadier":
		_update_grenadier(direction, distance, delta)
	else:
		_update_pistol(direction, distance, delta)
	if combat_state == "normal":
		_set_motion_state("walk" if velocity.length_squared() > 0.05 else "idle")
	move_and_slide()


func _get_vision_range() -> float:
	var base_range := MELEE_VISION_RANGE if enemy_kind == "melee" else (GRENADIER_VISION_RANGE if enemy_kind == "grenadier" else RANGED_VISION_RANGE)
	return (base_range + VISION_RANGE_THREAT_BONUS * threat_level) * ambient_visibility_factor


func _get_disengage_distance() -> float:
	return MELEE_DISENGAGE_DISTANCE if enemy_kind == "melee" else RANGED_DISENGAGE_DISTANCE


func _is_position_inside_vision_fan(world_position: Vector3, vision_range: float = -1.0) -> bool:
	var offset := world_position - global_position
	offset.y = 0.0
	var distance_squared := offset.length_squared()
	if distance_squared <= 0.0001:
		return true
	var effective_range := _get_vision_range() if vision_range < 0.0 else vision_range
	if distance_squared > effective_range * effective_range:
		return false
	var forward := facing_world_direction
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return false
	return forward.normalized().dot(offset.normalized()) >= cos(deg_to_rad(VISION_HALF_ANGLE_DEGREES))


func _setup_vision_fan() -> void:
	# Detection remains directional, but its debug fan is intentionally hidden in play.
	vision_fan = null
	vision_fan_material = null


func _update_vision_fan(radius: float, force_rebuild: bool = false) -> void:
	vision_fan_range = radius


func _update_vision_fan_visual() -> void:
	pass


func _setup_enemy_health_bar() -> void:
	health_bar_background = _create_health_bar_sprite("background", 0.0072, 112)
	health_bar_background.name = "HealthBarBackground"
	health_bar_background.position.y = HEALTH_BAR_Y
	add_child(health_bar_background)
	health_bar_damage_trail = _create_health_bar_sprite("damage", 0.0072, 113)
	health_bar_damage_trail.name = "HealthBarDamageTrail"
	health_bar_damage_trail.position.y = HEALTH_BAR_Y
	health_bar_damage_trail.centered = false
	health_bar_damage_trail.offset = Vector2(-45, -4)
	health_bar_damage_trail.region_enabled = true
	add_child(health_bar_damage_trail)
	health_bar_fill = _create_health_bar_sprite("fill", 0.0072, 114)
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.position.y = HEALTH_BAR_Y
	health_bar_fill.centered = false
	health_bar_fill.offset = Vector2(-45, -4)
	health_bar_fill.region_enabled = true
	add_child(health_bar_fill)
	_set_health_bar_ratio(health_bar_damage_trail, 1.0)
	_set_health_bar_ratio(health_bar_fill, 1.0)
	_update_health_bar_visibility()


func _setup_reload_indicator() -> void:
	reload_indicator = Sprite3D.new()
	reload_indicator.name = "ReloadIndicator"
	reload_indicator.position = Vector3(0, RELOAD_INDICATOR_Y, 0)
	reload_indicator.pixel_size = 0.012
	reload_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reload_indicator.shaded = false
	reload_indicator.transparent = true
	reload_indicator.no_depth_test = true
	reload_indicator.render_priority = 124
	reload_indicator.visible = false
	add_child(reload_indicator)


func _get_reload_texture(step: int) -> Texture2D:
	step = clampi(step, 0, 20)
	if reload_texture_cache.has(step):
		return reload_texture_cache[step]
	var image := Image.create(56, 56, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(27.5, 27.5)
	var progress := float(step) / 20.0
	for y in 56:
		for x in 56:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius < 17.0 or radius > 24.0:
				continue
			var angle := fposmod(atan2(offset.y, offset.x) + PI * 0.5, TAU)
			var filled := angle <= progress * TAU
			image.set_pixel(x, y, Color("#f0c75a") if filled else Color(0.12, 0.13, 0.13, 0.9))
	var texture := ImageTexture.create_from_image(image)
	reload_texture_cache[step] = texture
	return texture


func _start_reload() -> void:
	if enemy_kind == "melee" or dying or combat_state == "reloading":
		return
	combat_state = "reloading"
	reload_elapsed = 0.0
	burst_shots_remaining = 0
	state_timer = 0.0
	reload_indicator.texture = _get_reload_texture(0)
	reload_indicator.visible = true
	_set_motion_state("idle")


func _update_reload(delta: float) -> void:
	reload_elapsed += delta
	var progress := clampf(reload_elapsed / reload_duration, 0.0, 1.0)
	reload_indicator.texture = _get_reload_texture(roundi(progress * 20.0))
	reload_indicator.visible = true
	var away := global_position - target.global_position if is_instance_valid(target) else Vector3.ZERO
	away.y = 0.0
	if away.length_squared() > 0.01:
		velocity = _steer_around_obstacles(away.normalized()) * PISTOL_SPEED * 0.42
		_set_facing_from_world_direction(-away.normalized())
	if progress >= 1.0:
		magazine_ammo = magazine_size
		combat_state = "normal"
		reload_indicator.visible = false
		attack_cooldown = 0.28
		_reset_sprite_pose()


func _setup_reinforcement_call_indicator() -> void:
	reinforcement_call_indicator = Sprite3D.new()
	reinforcement_call_indicator.name = "ReinforcementCallIndicator"
	reinforcement_call_indicator.position = Vector3(0, REINFORCEMENT_ICON_Y, 0)
	reinforcement_call_indicator.pixel_size = 0.0105
	reinforcement_call_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reinforcement_call_indicator.shaded = false
	reinforcement_call_indicator.transparent = true
	reinforcement_call_indicator.no_depth_test = true
	reinforcement_call_indicator.render_priority = 126
	reinforcement_call_indicator.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	reinforcement_call_indicator.visible = false
	add_child(reinforcement_call_indicator)


func _get_reinforcement_call_texture(step: int) -> Texture2D:
	step = clampi(step, 0, 24)
	if reinforcement_call_texture_cache.has(step):
		return reinforcement_call_texture_cache[step]
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(31.5, 31.5)
	var progress := float(step) / 24.0
	for y in 64:
		for x in 64:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius <= 21.0:
				image.set_pixel(x, y, Color(0.025, 0.03, 0.032, 0.94))
			elif radius >= 24.0 and radius <= 28.0:
				var angle := fposmod(atan2(offset.y, offset.x) + PI * 0.5, TAU)
				image.set_pixel(x, y, Color("#ff6a3a") if angle <= progress * TAU else Color(0.22, 0.24, 0.24, 0.92))
	# Compact loudspeaker silhouette.
	image.fill_rect(Rect2i(18, 27, 9, 11), Color("#ffe09a"))
	image.fill_rect(Rect2i(20, 38, 6, 8), Color("#d87832"))
	for x in range(27, 44):
		var half_height := 4 + (x - 27) / 3
		for y in range(32 - half_height, 33 + half_height):
			image.set_pixel(x, y, Color("#f3a647"))
	for wave_index in 3:
		var wave_x := 47 + wave_index * 3
		var wave_height := 4 + wave_index * 3
		for wave_y in range(32 - wave_height, 33 + wave_height):
			if abs(wave_y - 32) >= wave_height - 1:
				image.set_pixel(wave_x, wave_y, Color("#ff6a3a"))
	var texture := ImageTexture.create_from_image(image)
	reinforcement_call_texture_cache[step] = texture
	return texture


func start_reinforcement_call(duration: float = 4.6) -> bool:
	if dying or reinforcement_call_active or not alerted or combat_state != "normal":
		return false
	reinforcement_call_active = true
	reinforcement_call_elapsed = 0.0
	reinforcement_call_duration = maxf(1.0, duration)
	combat_state = "reinforcement_call"
	burst_shots_remaining = 0
	velocity = Vector3.ZERO
	reinforcement_call_indicator.texture = _get_reinforcement_call_texture(0)
	reinforcement_call_indicator.visible = true
	_set_motion_state("idle")
	return true


func _update_reinforcement_call(delta: float) -> void:
	reinforcement_call_elapsed += delta
	var progress := clampf(reinforcement_call_elapsed / reinforcement_call_duration, 0.0, 1.0)
	reinforcement_call_indicator.texture = _get_reinforcement_call_texture(roundi(progress * 24.0))
	reinforcement_call_indicator.visible = true
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.055
	reinforcement_call_indicator.scale = Vector3.ONE * pulse
	if progress >= 1.0:
		reinforcement_call_active = false
		reinforcement_call_indicator.visible = false
		combat_state = "normal"
		attack_cooldown = 0.45
		reinforcement_called.emit(self)


func _cancel_reinforcement_call() -> void:
	reinforcement_call_active = false
	if reinforcement_call_indicator:
		reinforcement_call_indicator.visible = false
	if combat_state == "reinforcement_call":
		combat_state = "normal"


func _create_health_bar_sprite(kind: String, pixel_size: float, priority: int) -> Sprite3D:
	var bar := Sprite3D.new()
	bar.texture = _get_health_bar_texture(kind)
	bar.pixel_size = pixel_size
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.shaded = false
	bar.transparent = true
	bar.no_depth_test = true
	bar.render_priority = priority
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return bar


func _get_health_bar_texture(kind: String) -> Texture2D:
	if health_bar_texture_cache.has(kind):
		return health_bar_texture_cache[kind]
	var width := 96 if kind == "background" else 90
	var height := 14 if kind == "background" else 8
	var radius := 6.0 if kind == "background" else 4.0
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in height:
		for x in width:
			if not _point_in_rounded_rect(Vector2(x + 0.5, y + 0.5), Vector2(width, height), radius):
				continue
			var color := Color("#171b1d")
			if kind == "background":
				var inner_point := Vector2(x - 1.5, y - 1.5)
				var inside_inner := _point_in_rounded_rect(inner_point, Vector2(width - 3, height - 3), radius - 1.5)
				color = Color(0.54, 0.59, 0.6, 0.92) if not inside_inner else Color(0.035, 0.045, 0.05, 0.92)
			elif kind == "damage":
				color = Color(1.0, 0.31 + float(y) / float(height) * 0.12, 0.09, 0.96)
			else:
				color = Color(0.19, 0.82 - float(y) / float(height) * 0.13, 0.38, 0.98)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	health_bar_texture_cache[kind] = texture
	return texture


func _point_in_rounded_rect(point: Vector2, size: Vector2, radius: float) -> bool:
	var nearest := Vector2(
		clampf(point.x, radius, size.x - radius),
		clampf(point.y, radius, size.y - radius)
	)
	return point.distance_squared_to(nearest) <= radius * radius


func _set_health_bar_ratio(bar: Sprite3D, ratio: float) -> void:
	if bar == null or bar.texture == null:
		return
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var texture_width := float(bar.texture.get_width())
	bar.region_rect = Rect2(0, 0, maxf(1.0, roundf(texture_width * clamped_ratio)), bar.texture.get_height())
	bar.visible = clamped_ratio > 0.001 and not dying and player_visibility_factor > 0.01


func _update_enemy_health_bar(delta: float) -> void:
	if health_bar_fill == null:
		return
	if damage_trail_delay > 0.0:
		damage_trail_delay = maxf(0.0, damage_trail_delay - delta)
	else:
		damage_trail_ratio = move_toward(damage_trail_ratio, health_ratio, delta * 1.25)
	_set_health_bar_ratio(health_bar_fill, health_ratio)
	_set_health_bar_ratio(health_bar_damage_trail, damage_trail_ratio)
	var fill_color := Color.WHITE
	if health_ratio <= 0.3:
		fill_color = Color(1.35, 0.34, 0.25, 1.0)
	elif health_ratio <= 0.6:
		fill_color = Color(1.15, 0.82, 0.3, 1.0)
	health_bar_fill.modulate = Color(fill_color, player_visibility_factor)
	_update_health_bar_visibility()


func _update_health_bar_visibility() -> void:
	var should_show := not dying and player_visibility_factor > 0.01
	for bar_node in [health_bar_background, health_bar_damage_trail, health_bar_fill]:
		var bar := bar_node as Sprite3D
		if bar == null:
			continue
		var color: Color = bar.modulate
		color.a = player_visibility_factor
		bar.modulate = color
		if bar == health_bar_background:
			bar.visible = should_show
		elif bar == health_bar_damage_trail:
			bar.visible = should_show and damage_trail_ratio > 0.001
		else:
			bar.visible = should_show and health_ratio > 0.001


func _register_health_damage() -> void:
	health_ratio = clampf(float(health) / float(maxi(1, max_health)), 0.0, 1.0)
	damage_trail_ratio = maxf(damage_trail_ratio, health_ratio)
	damage_trail_delay = 0.28
	_set_health_bar_ratio(health_bar_fill, health_ratio)
	_set_health_bar_ratio(health_bar_damage_trail, damage_trail_ratio)


func get_projectile_hit_center() -> Vector3:
	return global_position + Vector3(0, 0.08, 0)


func get_projectile_hit_radius() -> float:
	# Keep the logical hit silhouette slightly wider than the feet collider so
	# stationary actions such as reloading and radio calls remain dependable.
	return 0.62


func _update_patrol(delta: float) -> void:
	patrol_pause = maxf(0.0, patrol_pause - delta)
	patrol_repath_time = maxf(0.0, patrol_repath_time - delta)
	if patrol_pause > 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_set_motion_state("idle")
		return

	var offset := patrol_target - global_position
	offset.y = 0.0
	if offset.length() <= 0.65 or patrol_repath_time <= 0.0 or is_on_wall():
		velocity = Vector3.ZERO
		patrol_pause = randf_range(0.25, 0.75)
		_choose_patrol_target()
		_set_motion_state("idle")
		return

	var direction := _steer_around_obstacles(offset.normalized())
	velocity = direction * PATROL_SPEED
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")


func _choose_patrol_target() -> void:
	if squad_id >= 0:
		var patrol_epoch := int(Time.get_ticks_msec() / 4500)
		var angle := deg_to_rad(float(posmod(squad_id * 73 + patrol_epoch * 137, 360)))
		var shared_offset := Vector3(cos(angle), 0.0, sin(angle)) * SQUAD_PATROL_RADIUS
		patrol_target = squad_anchor + shared_offset + squad_formation_offset
		patrol_repath_time = 2.4
		return
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(PATROL_RADIUS * 0.35, PATROL_RADIUS)
	patrol_target = patrol_origin + Vector3(cos(angle), 0.0, sin(angle)) * radius
	patrol_repath_time = randf_range(2.0, 4.5)


func _become_alerted() -> void:
	var newly_alerted := not alerted
	alerted = true
	visual_contact_confirmed = true
	_update_vision_fan_visual()
	alert_marker_time = 0.0
	if newly_alerted and squad_id >= 0:
		var shared_position := target.global_position if is_instance_valid(target) else global_position
		for squad_member in get_tree().get_nodes_in_group("raid_enemy"):
			if (
				squad_member == self
				or not is_instance_valid(squad_member)
				or not squad_member.has_method("receive_squad_alert")
			):
				continue
			if int(squad_member.get("squad_id")) == squad_id:
				squad_member.call("receive_squad_alert", shared_position)


func receive_squad_alert(world_position: Vector3) -> void:
	if dying or not is_instance_valid(target) or _target_is_in_safe_zone():
		return
	last_known_position = world_position
	pursuit_time = COMBAT_MEMORY_BASE + COMBAT_MEMORY_THREAT_BONUS * threat_level
	alerted = true
	visual_contact_confirmed = true
	_update_vision_fan_visual()


func receive_reinforcement_order(world_position: Vector3) -> void:
	if dying or not is_instance_valid(target) or _target_is_in_safe_zone():
		return
	last_known_position = world_position
	pursuit_time = COMBAT_MEMORY_BASE + COMBAT_MEMORY_THREAT_BONUS * threat_level
	_become_alerted()


func _with_player_visibility(color: Color) -> Color:
	color.a *= player_visibility_factor
	return color


func _clear_alert() -> void:
	alerted = false
	visual_contact_confirmed = false
	has_current_line_of_sight = false
	pursuit_time = 0.0
	lost_sight_time = 0.0
	target_stationary_time = 0.0
	_update_vision_fan_visual()
	if threat_marker and combat_state not in ["melee_windup", "grenade_windup"]:
		threat_marker.visible = false


func _update_alert_marker(delta: float) -> void:
	if alert_marker_time > 0.0:
		alert_marker_time = maxf(0.0, alert_marker_time - delta)
	if threat_marker and combat_state not in ["melee_windup", "grenade_windup"]:
		threat_marker.visible = false


func _pursue_last_known_position() -> void:
	if hold_position_timer > 0.0:
		velocity = Vector3.ZERO
		_set_motion_state("idle")
		return
	if tactical_repath_timer <= 0.0 or tactical_waypoint == Vector3.INF:
		var direct := last_known_position - global_position
		direct.y = 0.0
		var side := Vector3(-direct.z, 0.0, direct.x).normalized() if direct.length_squared() > 0.01 else Vector3.RIGHT
		var flank_distance := randf_range(5.5, 9.5) if lost_sight_time >= 2.0 else randf_range(2.5, 4.8)
		var overshoot := direct.normalized() * minf(3.5, lost_sight_time * 0.7) if direct.length_squared() > 0.01 else Vector3.ZERO
		tactical_waypoint = last_known_position + side * strafe_sign * flank_distance + overshoot
		strafe_sign *= -1.0
		tactical_waypoint = _resolve_tactical_waypoint(tactical_waypoint)
		tactical_repath_timer = randf_range(1.1, 2.0)
	var offset := tactical_waypoint - global_position
	offset.y = 0.0
	if offset.length() <= 0.7:
		tactical_waypoint = Vector3.INF
		hold_position_timer = randf_range(0.18, 0.55)
		return
	var direction := _steer_around_obstacles(offset.normalized())
	var base_speed := MELEE_SPEED if enemy_kind == "melee" else PISTOL_SPEED
	velocity = direction * base_speed * lerpf(1.0, 1.32, threat_level)
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")


func _update_stationary_target_flank(direction: Vector3, distance: float) -> bool:
	if (
		target_stationary_time < 3.8
		or distance < 7.5
		or enemy_kind == "melee"
		or posmod(get_instance_id(), 3) == 0
	):
		return false
	if tactical_repath_timer <= 0.0 or tactical_waypoint == Vector3.INF:
		var side := Vector3(-direction.z, 0.0, direction.x)
		var flank_distance := weapon_random.randf_range(7.0, 11.0)
		# `direction` points from this enemy to the player, so continuing along it
		# places the waypoint beyond the player's current position.
		var rear_offset := direction * weapon_random.randf_range(1.5, 3.5)
		tactical_waypoint = target.global_position + side * strafe_sign * flank_distance + rear_offset
		strafe_sign *= -1.0
		tactical_waypoint = _resolve_tactical_waypoint(tactical_waypoint)
		tactical_repath_timer = weapon_random.randf_range(2.2, 3.4)
	var offset := tactical_waypoint - global_position
	offset.y = 0.0
	if offset.length() <= 1.0:
		tactical_waypoint = Vector3.INF
		target_stationary_time = 1.4
		return false
	var flank_direction := _steer_around_obstacles(offset.normalized())
	if flank_direction.length_squared() <= 0.01:
		tactical_waypoint = Vector3.INF
		tactical_repath_timer = 0.0
		return false
	velocity = flank_direction * PISTOL_SPEED * lerpf(1.25, 1.65, threat_level)
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")
	return true


func _resolve_tactical_waypoint(requested_position: Vector3) -> Vector3:
	var world := get_parent().get_node_or_null("World") if get_parent() != null else null
	if world == null:
		return requested_position
	if world.has_method("find_nearest_physically_open_position"):
		return world.call(
			"find_nearest_physically_open_position",
			requested_position,
			0.58,
			[get_rid()]
		)
	if world.has_method("find_nearest_open_position"):
		return world.call("find_nearest_open_position", requested_position)
	return requested_position


func _steer_around_obstacles(desired_direction: Vector3) -> Vector3:
	if desired_direction.length_squared() <= 0.01:
		return Vector3.ZERO
	var desired := desired_direction.normalized()
	var angles := [0.0, 24.0, -24.0, 48.0, -48.0, 76.0, -76.0, 112.0, -112.0]
	var from := global_position + Vector3(0, 0.32, 0)
	for angle in angles:
		var candidate := desired.rotated(Vector3.UP, deg_to_rad(angle))
		var probe_distance := 3.1 if is_zero_approx(angle) else 2.35
		var query := PhysicsRayQueryParameters3D.create(from, from + candidate * probe_distance, 1)
		query.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return candidate
	return Vector3.ZERO


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in SCREEN_DIRECTION_NAMES:
		_add_file_animation(frames, direction_name, "idle", "idle", [0, 1, 2, 3], 6.0, true)
		_add_file_animation(frames, direction_name, "walk", "walk", [0, 1, 2, 3], 8.5, true)
		_add_file_animation(frames, direction_name, "attack", "walk", [0, 1, 2, 3, 2, 1], 15.0, false)
		_add_file_animation(frames, direction_name, "hit", "idle", [2, 1, 2], 18.0, false)
		_add_file_animation(frames, direction_name, "death", "idle", [0, 1, 2, 3], 7.0, false)
	return frames


func _add_file_animation(
	frames: SpriteFrames,
	direction_name: String,
	state: String,
	source_state: String,
	frame_indices,
	speed: float,
	looped: bool
) -> void:
	var animation_name := "%s_%s" % [state, direction_name]
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, looped)
	frames.set_animation_speed(animation_name, speed)
	var direction_prefix: String = ENEMY_DIRECTION_STATES[direction_name]
	for frame_index in frame_indices:
		var texture_path := "%s/%s_%s-frame-%d.png" % [
			ENEMY_ANIMATION_ROOT,
			direction_prefix,
			source_state,
			int(frame_index),
		]
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_error("Missing enemy animation frame: %s" % texture_path)
			continue
		frames.add_frame(animation_name, texture)


func _setup_weapon_visual() -> void:
	weapon_visual = Sprite3D.new()
	weapon_visual.name = "EquippedWeapon_%s" % weapon_id
	weapon_visual.texture = _get_weapon_visual_texture()
	weapon_visual.pixel_size = (
		WEAPON_VISUAL_CATALOG.get_world_pixel_size("baseball_bat", 0.00058)
		if weapon_id == "baseball_bat"
		else WEAPON_VISUAL_CATALOG.get_world_pixel_size(weapon_id, 0.0042)
	)
	weapon_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_visual.shaded = false
	weapon_visual.transparent = true
	weapon_visual.no_depth_test = true
	weapon_visual.render_priority = 34
	weapon_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(weapon_visual)


func _get_weapon_visual_texture() -> Texture2D:
	if weapon_id == "baseball_bat":
		return BASEBALL_BAT_TEXTURE
	var catalog_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	if catalog_texture != null:
		return catalog_texture
	if weapon_texture_cache.has(weapon_id):
		return weapon_texture_cache[weapon_id]
	var image := Image.create(160, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var metal := Color("#8c9492")
	var dark_metal := Color("#3b403f")
	var wood := Color("#82533a")
	var black := Color("#171b1c")
	match weapon_id:
		"m1911":
			_paint_weapon_rect(image, Rect2i(35, 25, 82, 13), black, metal)
			_paint_weapon_rect(image, Rect2i(42, 38, 51, 8), black, dark_metal)
			_paint_weapon_rect(image, Rect2i(70, 43, 20, 25), black, wood)
			_paint_weapon_rect(image, Rect2i(116, 29, 18, 5), black, Color("#b8c09e"))
		"mp5":
			_paint_weapon_rect(image, Rect2i(43, 27, 70, 20), black, dark_metal)
			_paint_weapon_rect(image, Rect2i(17, 31, 31, 8), black, Color("#4e5553"))
			_paint_weapon_rect(image, Rect2i(111, 31, 31, 6), black, metal)
			_paint_weapon_rect(image, Rect2i(71, 45, 17, 28), black, Color("#252b2c"))
			_paint_weapon_rect(image, Rect2i(93, 44, 12, 18), black, Color("#33393a"))
		"ak47":
			_paint_weapon_rect(image, Rect2i(48, 26, 64, 18), black, wood)
			_paint_weapon_rect(image, Rect2i(19, 31, 34, 10), black, wood)
			_paint_weapon_rect(image, Rect2i(109, 30, 39, 6), black, metal)
			_paint_weapon_rect(image, Rect2i(77, 43, 16, 25), black, dark_metal)
			_paint_weapon_rect(image, Rect2i(91, 44, 13, 16), black, wood)
			image.fill_rect(Rect2i(78, 62, 13, 6), Color("#252a29"))
		"double_barrel":
			_paint_weapon_rect(image, Rect2i(68, 25, 79, 6), black, metal)
			_paint_weapon_rect(image, Rect2i(68, 34, 79, 6), black, Color("#707876"))
			_paint_weapon_rect(image, Rect2i(32, 29, 40, 17), black, wood)
			_paint_weapon_rect(image, Rect2i(18, 38, 30, 13), black, Color("#6f4432"))
			_paint_weapon_rect(image, Rect2i(56, 43, 12, 20), black, dark_metal)
	var texture := ImageTexture.create_from_image(image)
	weapon_texture_cache[weapon_id] = texture
	return texture


func _paint_weapon_rect(image: Image, rect: Rect2i, outline: Color, fill_color: Color) -> void:
	image.fill_rect(rect.grow(2), outline)
	image.fill_rect(rect, fill_color)


func _update_weapon_visual() -> void:
	if weapon_visual == null:
		return
	var direction := facing_world_direction.normalized()
	weapon_visual.position = direction * (0.34 if weapon_id == "baseball_bat" else 0.44) + Vector3(0, 0.48, 0)
	var screen_direction := Vector2(direction.x - direction.z, direction.x + direction.z).normalized()
	weapon_visual.flip_h = weapon_id != "baseball_bat" and screen_direction.x < -0.01
	var source_angle := PI if weapon_visual.flip_h else 0.0
	weapon_visual.rotation.z = wrapf(screen_direction.angle() - source_angle, -PI, PI)
	weapon_visual.scale = Vector3.ONE * (0.72 if weapon_id == "baseball_bat" else 1.0)
	weapon_visual.visible = not dying


func _get_weapon_muzzle_position(direction: Vector3) -> Vector3:
	var reach := 0.78
	if weapon_id == "m1911":
		reach = 0.58
	elif weapon_id == "double_barrel":
		reach = 0.88
	return global_position + direction * reach + Vector3(0, 0.48, 0)


func _set_motion_state(next_state: String) -> void:
	if motion_state == next_state:
		return
	motion_state = next_state
	_play_animation()


func _set_facing(direction_name: String) -> void:
	if facing == direction_name:
		return
	facing = direction_name
	_play_animation()


func _set_facing_from_world_direction(world_direction: Vector3) -> void:
	if world_direction.length_squared() <= 0.01:
		return
	facing_world_direction = world_direction.normalized()
	var screen_direction := Vector2(
		world_direction.x - world_direction.z,
		world_direction.x + world_direction.z
	).normalized()
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var index := int(round(angle / 45.0)) % 8
	_set_facing(SCREEN_DIRECTION_NAMES[index])
	_update_weapon_visual()


func _play_animation() -> void:
	if sprite == null:
		return
	# Every direction has authored frames; mirroring would reverse asymmetrical gear.
	sprite.flip_h = false
	var animation_name := "%s_%s" % [motion_state, facing]
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _update_melee(direction: Vector3, distance: float) -> void:
	if distance > 1.4:
		velocity = _steer_around_obstacles(direction) * MELEE_SPEED * lerpf(1.0, 1.36, threat_level)
	elif attack_cooldown <= 0.0:
		_start_melee_windup(direction)
	else:
		velocity = Vector3.ZERO


func _start_melee_windup(direction: Vector3) -> void:
	combat_state = "melee_windup"
	state_timer = MELEE_WINDUP_TIME
	pending_attack_direction = direction
	attack_cooldown = lerpf(1.2, 0.82, threat_level)
	velocity = Vector3.ZERO
	_set_motion_state("attack")
	threat_marker.visible = true
	_start_windup_pose()


func _update_pistol(direction: Vector3, distance: float, delta: float) -> void:
	if magazine_ammo <= 0:
		_start_reload()
		return
	var movement_speed := PISTOL_SPEED * lerpf(1.12, 1.48, threat_level)
	var preferred_min := 8.0
	var preferred_max := 17.0
	var attack_range := _get_weapon_engagement_range()
	match weapon_id:
		"mp5":
			preferred_min = 10.0
			preferred_max = 22.0
		"ak47":
			preferred_min = 15.0
			preferred_max = 30.0
		"double_barrel":
			preferred_min = 4.0
			preferred_max = 9.0
	if _update_stationary_target_flank(direction, distance):
		return
	strafe_switch_time = maxf(0.0, strafe_switch_time - delta)
	if distance > preferred_max:
		velocity = _steer_around_obstacles(direction) * movement_speed
	elif distance < preferred_min:
		velocity = _steer_around_obstacles(-direction) * movement_speed
	else:
		if strafe_switch_time <= 0.0 or is_on_wall():
			strafe_sign = -strafe_sign if strafe_switch_time > 0.0 else (1.0 if randf() >= 0.5 else -1.0)
			strafe_switch_time = randf_range(0.85, 1.55)
		var strafe_direction := Vector3(-direction.z, 0.0, direction.x) * strafe_sign
		velocity = _steer_around_obstacles(strafe_direction) * movement_speed * 0.78
	if distance <= attack_range and attack_cooldown <= 0.0:
		burst_shots_remaining = mini(magazine_ammo - 1, maxi(0, _get_weapon_burst_size() - 1))
		combat_state = "pistol_burst"
		state_timer = _get_enemy_fire_interval()
		pending_attack_direction = direction
		velocity = Vector3.ZERO
		_set_motion_state("attack")
		_fire_weapon(direction)
		_start_recoil_pose()


func _update_grenadier(direction: Vector3, distance: float, delta: float) -> void:
	var movement_speed := PISTOL_SPEED * lerpf(1.0, 1.25, threat_level)
	if grenade_cooldown <= 0.0 and distance >= 7.0 and distance <= 28.0 and _has_line_of_sight():
		grenade_target_position = target.global_position + target.velocity * 0.32
		combat_state = "grenade_windup"
		state_timer = GRENADE_WINDUP_TIME
		velocity = Vector3.ZERO
		pending_attack_direction = direction
		_set_motion_state("attack")
		threat_marker.text = "◆"
		threat_marker.modulate = _with_player_visibility(Color("#ffb84f"))
		threat_marker.visible = true
		return
	if distance > 20.0:
		velocity = _steer_around_obstacles(direction) * movement_speed
	elif distance < 9.0:
		velocity = _steer_around_obstacles(-direction) * movement_speed
	else:
		strafe_switch_time = maxf(0.0, strafe_switch_time - delta)
		if strafe_switch_time <= 0.0:
			strafe_sign *= -1.0
			strafe_switch_time = weapon_random.randf_range(0.8, 1.45)
		var strafe_direction := Vector3(-direction.z, 0.0, direction.x) * strafe_sign
		velocity = _steer_around_obstacles(strafe_direction) * movement_speed * 0.68


func _throw_grenade() -> void:
	if get_parent() == null:
		return
	var start := global_position + pending_attack_direction * 0.72 + Vector3(0.0, 0.62, 0.0)
	var grenade := Node3D.new()
	grenade.name = "EnemyGrenade"
	grenade.set_script(GRENADE_PROJECTILE)
	grenade.call("configure", self, target, start, grenade_target_position, 28, 3.15, 2.45)
	get_parent().add_child(grenade)
	grenade.global_position = start
	grenade_cooldown = weapon_random.randf_range(6.8, 9.5)


func _get_weapon_engagement_range() -> float:
	match weapon_id:
		"mp5":
			return 38.0
		"ak47":
			return 48.0
		"double_barrel":
			return 12.0
		_:
			return 24.0


func _update_combat_state(delta: float) -> void:
	state_timer = maxf(0.0, state_timer - delta)
	velocity = Vector3.ZERO
	if combat_state == "pistol_burst" and is_instance_valid(target):
		var target_direction := target.global_position - global_position
		target_direction.y = 0.0
		if target_direction.length_squared() > 0.01:
			target_direction = target_direction.normalized()
			var burst_strafe := Vector3(-target_direction.z, 0.0, target_direction.x) * strafe_sign
			velocity = (
				_steer_around_obstacles(burst_strafe)
				* PISTOL_SPEED
				* lerpf(0.42, 0.68, threat_level)
			)
			_set_facing_from_world_direction(target_direction)
	if combat_state == "reinforcement_call":
		_update_reinforcement_call(delta)
	elif combat_state == "reloading":
		_update_reload(delta)
	elif combat_state == "grenade_windup":
		_set_facing_from_world_direction(pending_attack_direction)
		if state_timer <= 0.0:
			_throw_grenade()
			combat_state = "grenade_recovery"
			state_timer = GRENADE_RECOVERY_TIME
			threat_marker.visible = false
			_start_recoil_pose()
	elif combat_state == "grenade_recovery" and state_timer <= 0.0:
		combat_state = "normal"
		_reset_sprite_pose()
		_set_motion_state("idle")
	elif combat_state == "melee_windup":
		_update_threat_marker()
		if state_timer <= 0.0:
			threat_marker.visible = false
			combat_state = "melee_strike"
			state_timer = MELEE_STRIKE_TIME
			velocity = pending_attack_direction * 2.2
			_perform_melee_strike()
			_spawn_melee_slash()
			_start_strike_pose()
	elif combat_state == "melee_strike":
		velocity = pending_attack_direction * 1.2
		if state_timer <= 0.0:
			combat_state = "melee_recovery"
			state_timer = MELEE_RECOVERY_TIME
			velocity = Vector3.ZERO
	elif combat_state == "pistol_burst" and state_timer <= 0.0:
		if burst_shots_remaining > 0 and magazine_ammo > 0 and is_instance_valid(target) and _has_line_of_sight():
			var burst_direction := target.global_position - global_position
			burst_direction.y = 0.0
			if burst_direction.length_squared() > 0.01:
				burst_direction = burst_direction.normalized()
				pending_attack_direction = burst_direction
				_set_facing_from_world_direction(burst_direction)
				_fire_weapon(burst_direction)
				_start_recoil_pose()
			burst_shots_remaining -= 1
			state_timer = _get_enemy_fire_interval()
		else:
			burst_shots_remaining = 0
			if magazine_ammo <= 0:
				_start_reload()
			else:
				attack_cooldown = _get_weapon_burst_cooldown()
				combat_state = "normal"
				_reset_sprite_pose()
				_set_motion_state("idle")
	elif combat_state in ["melee_recovery", "pistol_fire"] and state_timer <= 0.0:
		combat_state = "normal"
		_reset_sprite_pose()
		_set_motion_state("idle")
	move_and_slide()


func _perform_melee_strike() -> void:
	if not is_instance_valid(target):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() > 1.75 or not _has_line_of_sight():
		return
	if target.has_method("take_damage"):
		target.call("take_damage", 12 + roundi(6.0 * threat_level))
	elif target.get_parent() != null and target.get_parent().has_method("take_damage"):
		target.get_parent().call("take_damage", 12 + roundi(6.0 * threat_level))


func _update_stagger(delta: float) -> void:
	state_timer = maxf(0.0, state_timer - delta)
	velocity = stagger_velocity
	stagger_velocity = stagger_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	move_and_slide()
	if state_timer <= 0.0:
		combat_state = "normal"
		_reset_sprite_pose()
		_set_motion_state("idle")


func _has_line_of_sight() -> bool:
	var from := global_position + Vector3(0, 0.35, 0)
	var to := target.global_position + Vector3(0, 0.35, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target


func _target_is_in_safe_zone() -> bool:
	if not is_instance_valid(target) or target.get_parent() == null:
		return false
	var world := target.get_parent().get_node_or_null("World")
	return world != null and world.has_method("is_position_in_safe_zone") and world.call("is_position_in_safe_zone", target.global_position)


func _get_weapon_burst_size() -> int:
	match weapon_id:
		"mp5": return magazine_size
		"ak47": return magazine_size
		"m1911": return mini(magazine_size, 3 + roundi(3.0 * threat_level))
		"double_barrel": return 1
	return 1


func _get_enemy_fire_interval() -> float:
	var base_interval := float(weapon_stats.get("fire_interval", 0.22))
	return maxf(0.065, base_interval * lerpf(1.12, 0.88, threat_level))


func _get_weapon_burst_cooldown() -> float:
	match weapon_id:
		"mp5": return lerpf(0.72, 0.34, threat_level)
		"ak47": return lerpf(0.88, 0.4, threat_level)
		"double_barrel": return lerpf(2.3, 1.25, threat_level)
	return lerpf(1.05, 0.58, threat_level)


func _get_enemy_bullet_damage() -> int:
	match weapon_id:
		"mp5": return 6 + roundi(3.0 * threat_level)
		"ak47": return 9 + roundi(4.0 * threat_level)
		"double_barrel": return 5 + roundi(2.0 * threat_level)
	return 12 + roundi(4.0 * threat_level)


func _fire_weapon(direction: Vector3) -> void:
	if magazine_ammo <= 0:
		_start_reload()
		return
	magazine_ammo -= 1
	_play_enemy_gunshot()
	var pellet_count := 6 if weapon_id == "double_barrel" else 1
	var base_spread := float(weapon_stats.get("base_spread_deg", 2.0))
	var accuracy_multiplier := lerpf(1.55, 0.72, threat_level)
	for pellet_index in pellet_count:
		var spread_angle := weapon_random.randf_range(-base_spread, base_spread) * accuracy_multiplier
		var shot_direction := direction.rotated(Vector3.UP, deg_to_rad(spread_angle)).normalized()
		var projectile := Area3D.new()
		projectile.name = "Enemy_%s_Bullet_%d" % [weapon_id, pellet_index]
		projectile.set_script(BULLET_PROJECTILE)
		projectile.set("direction", shot_direction)
		projectile.set("source_body", self)
		projectile.set("damage", _get_enemy_bullet_damage())
		projectile.set("hostile", true)
		projectile.position = _get_weapon_muzzle_position(direction)
		get_parent().add_child(projectile)
	_spawn_enemy_muzzle_flash(direction)
	_play_attack_feedback()


func _fire_pistol(direction: Vector3) -> void:
	_fire_weapon(direction)


func _setup_enemy_audio() -> void:
	if weapon_id == "baseball_bat":
		return
	shot_audio_player = AudioStreamPlayer3D.new()
	shot_audio_player.name = "EnemyGunshot"
	shot_audio_player.stream = _get_enemy_gunshot_stream()
	shot_audio_player.unit_size = 6.0
	shot_audio_player.max_distance = 48.0
	shot_audio_player.volume_db = -6.0
	add_child(shot_audio_player)


func _get_enemy_gunshot_stream() -> AudioStreamWAV:
	if enemy_gunshot_stream_cache:
		return enemy_gunshot_stream_cache
	var mix_rate := 32000
	var sample_count := int(mix_rate * 0.22)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 54019
	for index in sample_count:
		var time := float(index) / mix_rate
		var snap := random.randf_range(-1.0, 1.0) * exp(-time * 42.0)
		var crack := sin(TAU * 920.0 * time + random.randf_range(-0.2, 0.2)) * exp(-time * 29.0)
		var body := sin(TAU * 132.0 * time) * exp(-time * 15.0)
		var tail := 0.0
		if time > 0.045:
			tail = random.randf_range(-1.0, 1.0) * exp(-(time - 0.045) * 18.0) * 0.16
		var sample := tanh((snap * 0.76 + crack * 0.22 + body * 0.3 + tail) * 1.25) * 0.78
		var encoded := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	enemy_gunshot_stream_cache = stream
	return enemy_gunshot_stream_cache


func _play_enemy_gunshot() -> void:
	if not is_instance_valid(shot_audio_player):
		return
	shot_audio_player.stop()
	shot_audio_player.pitch_scale = randf_range(0.94, 1.12)
	shot_audio_player.play()


func _spawn_enemy_muzzle_flash(direction: Vector3) -> void:
	if get_parent() == null:
		return
	var flash := MeshInstance3D.new()
	flash.name = "EnemyMuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.075
	flash_mesh.height = 0.15
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.72, 0.18, 0.95)
	flash_material.emission_enabled = true
	flash_material.emission = Color("#ffb326")
	flash_material.emission_energy_multiplier = 6.0
	flash_material.no_depth_test = true
	flash_mesh.material = flash_material
	flash.mesh = flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(flash)
	flash.global_position = _get_weapon_muzzle_position(direction)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.4, 0.08)
	tween.tween_property(flash, "transparency", 1.0, 0.1)
	get_tree().create_timer(0.12).timeout.connect(flash.queue_free)


func _update_threat_marker() -> void:
	if threat_marker == null or not threat_marker.visible:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.025) * 0.18
	threat_marker.scale = Vector3.ONE * pulse
	threat_marker.position.y = THREAT_MARKER_Y + sin(Time.get_ticks_msec() * 0.012) * 0.08


func _start_windup_pose() -> void:
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.set_parallel(true)
	visual_tween.tween_property(sprite, "scale", Vector3(0.9, 1.08, 1.0), MELEE_WINDUP_TIME)
	visual_tween.tween_property(sprite, "rotation", Vector3(0, 0, deg_to_rad(-8.0 if not sprite.flip_h else 8.0)), MELEE_WINDUP_TIME)
	visual_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION - pending_attack_direction * 0.1, MELEE_WINDUP_TIME)


func _start_strike_pose() -> void:
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.set_parallel(true)
	visual_tween.tween_property(sprite, "scale", Vector3(1.12, 0.94, 1.0), 0.07)
	visual_tween.tween_property(sprite, "rotation", Vector3(0, 0, deg_to_rad(12.0 if not sprite.flip_h else -12.0)), 0.07)
	visual_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION + pending_attack_direction * 0.18, 0.07)


func _start_recoil_pose() -> void:
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION - pending_attack_direction * 0.08, 0.05)
	visual_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION, 0.12)
	if weapon_visual:
		var weapon_base_position := weapon_visual.position
		var weapon_recoil := 0.13 if weapon_id == "ak47" else 0.08
		var weapon_tween := create_tween()
		weapon_tween.tween_property(
			weapon_visual,
			"position",
			weapon_base_position - pending_attack_direction * weapon_recoil,
			0.04
		)
		weapon_tween.tween_property(weapon_visual, "position", weapon_base_position, 0.1)


func _reset_sprite_pose() -> void:
	if sprite == null or dying:
		return
	sprite.position = SPRITE_BASE_POSITION
	sprite.scale = Vector3.ONE
	sprite.rotation = Vector3.ZERO
	sprite.modulate = Color.WHITE
	_update_weapon_visual()
	if weapon_visual:
		weapon_visual.modulate = Color.WHITE


func _kill_visual_tween() -> void:
	if visual_tween != null:
		visual_tween.kill()


func _play_attack_feedback() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.45, 0.82, 0.58, 1), 0.045)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.11)
	if weapon_visual:
		var weapon_flash := create_tween()
		weapon_flash.tween_property(weapon_visual, "modulate", Color(1.8, 1.35, 0.5, 1), 0.035)
		weapon_flash.tween_property(weapon_visual, "modulate", Color.WHITE, 0.09)


func take_damage(amount: int) -> void:
	take_hit(amount, Vector3.ZERO)


func is_backstab_from(attacker_position: Vector3) -> bool:
	var direction_to_attacker := attacker_position - global_position
	direction_to_attacker.y = 0.0
	if direction_to_attacker.length_squared() <= 0.01:
		return false
	return facing_world_direction.dot(direction_to_attacker.normalized()) <= -0.42


func take_melee_hit(amount: int, hit_direction: Vector3, backstab: bool) -> void:
	if dying or backstab_stunned:
		return
	if not backstab:
		take_hit(amount, hit_direction)
		return
	var fatal_damage := maxi(amount, health)
	backstab_stunned = true
	health = 0
	damaged.emit(self, fatal_damage)
	_register_health_damage()
	_spawn_damage_number(fatal_damage, true, hit_direction)
	combat_state = "stagger"
	state_timer = 0.28
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	threat_marker.text = "★"
	threat_marker.modulate = Color("#ffe17a")
	threat_marker.visible = true
	alert_marker_time = 0.28
	_set_motion_state("hit")
	_spawn_hit_burst(hit_direction, Color("#fff0a3"), 16, 0.34)
	_play_hit_reaction(hit_direction)
	get_tree().create_timer(0.24).timeout.connect(func() -> void:
		if is_instance_valid(self) and not dying:
			backstab_stunned = false
			_start_death(hit_direction)
	)


func take_projectile_hit(
	amount: int,
	hit_direction: Vector3,
	is_critical: bool = false,
	critical_multiplier: float = 1.65,
	hit_zone: String = "body"
) -> void:
	var critical := is_critical or hit_zone == "head"
	var final_damage := roundi(float(amount) * critical_multiplier) if critical else amount
	take_hit(final_damage, hit_direction, critical)


func take_hit(amount: int, hit_direction: Vector3, is_critical: bool = false) -> void:
	if dying or backstab_stunned:
		return
	if reinforcement_call_active:
		_cancel_reinforcement_call()
	if is_instance_valid(target):
		last_known_position = target.global_position
		pursuit_time = maxf(pursuit_time, lerpf(8.0, 15.0, threat_level))
		_become_alerted()
		attack_cooldown = minf(attack_cooldown, 0.18)
	var lethal := amount >= health
	health -= amount
	damaged.emit(self, amount)
	_register_health_damage()
	_spawn_damage_number(amount, is_critical or lethal, hit_direction)
	threat_marker.visible = false
	var knockback_direction := hit_direction
	knockback_direction.y = 0.0
	if knockback_direction.length_squared() <= 0.01:
		knockback_direction = -pending_attack_direction
	knockback_direction = knockback_direction.normalized()
	stagger_velocity = knockback_direction * 3.6
	_spawn_hit_burst(knockback_direction, Color("#ffcf91"), 10, 0.3)
	_play_hit_reaction(knockback_direction)
	if health <= 0:
		_start_death(knockback_direction)
		return
	combat_state = "stagger"
	state_timer = HIT_STAGGER_TIME
	_set_motion_state("hit")


func _spawn_damage_number(amount: int, is_critical: bool, hit_direction: Vector3) -> void:
	var number := DAMAGE_NUMBER_SCRIPT.new() as Label3D
	get_parent().add_child(number)
	number.call(
		"setup",
		amount,
		is_critical,
		DAMAGE_FONT,
		global_position + Vector3(0, 1.62, 0),
		hit_direction,
		weapon_random.randf_range(-0.28, 0.28)
	)


func _play_hit_reaction(hit_direction: Vector3) -> void:
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.tween_property(sprite, "modulate", Color(2.4, 2.4, 2.4, 1), 0.025)
	visual_tween.tween_property(sprite, "modulate", Color(1.8, 0.16, 0.1, 1), 0.055)
	visual_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var shake := create_tween()
	shake.tween_property(sprite, "position", SPRITE_BASE_POSITION + hit_direction * 0.11, 0.035)
	shake.tween_property(sprite, "position", SPRITE_BASE_POSITION - hit_direction * 0.055, 0.035)
	shake.tween_property(sprite, "position", SPRITE_BASE_POSITION, 0.07)
	if weapon_visual:
		var weapon_hit := create_tween()
		weapon_hit.tween_property(weapon_visual, "modulate", Color(2.2, 0.28, 0.16, 1), 0.05)
		weapon_hit.tween_property(weapon_visual, "modulate", Color.WHITE, 0.12)


func _start_death(hit_direction: Vector3) -> void:
	dying = true
	_cancel_reinforcement_call()
	if reload_indicator:
		reload_indicator.visible = false
	backstab_stunned = false
	combat_state = "dying"
	threat_marker.visible = false
	_update_vision_fan_visual()
	_update_health_bar_visibility()
	collision_layer = 0
	collision_mask = 0
	velocity = hit_direction * 2.5
	_set_motion_state("death")
	_spawn_hit_burst(hit_direction, Color("#8b1717"), 18, 0.55)
	died.emit(self)
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.set_parallel(true)
	visual_tween.tween_property(sprite, "modulate", Color(0.35, 0.08, 0.07, 0.0), 0.48)
	visual_tween.tween_property(sprite, "scale", Vector3(1.18, 0.48, 1.0), 0.48)
	visual_tween.tween_property(sprite, "position", Vector3(0, -0.25, 0), 0.48)
	visual_tween.tween_property(sprite, "rotation", Vector3(0, 0, deg_to_rad(18.0 if not sprite.flip_h else -18.0)), 0.48)
	if shadow:
		var shadow_tween := create_tween()
		shadow_tween.tween_property(shadow, "scale", Vector3(0.2, 0.2, 0.2), 0.42)
	if weapon_visual:
		var weapon_death_tween := create_tween()
		weapon_death_tween.set_parallel(true)
		weapon_death_tween.tween_property(weapon_visual, "modulate", Color(0.4, 0.12, 0.08, 0.0), 0.36)
		weapon_death_tween.tween_property(weapon_visual, "position:y", -0.35, 0.36)
	get_tree().create_timer(0.52).timeout.connect(queue_free)


func _spawn_hit_burst(direction: Vector3, color: Color, amount: int, lifetime: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "EnemyHitBurst"
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.7
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.direction = (direction + Vector3.UP * 0.7).normalized()
	process.spread = 58.0
	process.gravity = Vector3(0, -4.5, 0)
	process.initial_velocity_min = 1.8
	process.initial_velocity_max = 4.8
	process.scale_min = 0.55
	process.scale_max = 1.25
	process.color = color
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.2
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.075, 0.075)
	mesh.material = material
	particles.draw_pass_1 = mesh
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.35, 0)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


func _spawn_melee_slash() -> void:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(48, 48)
	for y in 96:
		for x in 96:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			var angle := rad_to_deg(atan2(offset.y, offset.x))
			if radius >= 31.0 and radius <= 42.0 and absf(angle) <= 72.0:
				var alpha := 1.0 - absf(radius - 36.5) / 5.5
				image.set_pixel(x, y, Color(1.0, 0.72, 0.28, alpha * 0.9))
	var slash := Sprite3D.new()
	slash.name = "MeleeSlash"
	slash.texture = ImageTexture.create_from_image(image)
	slash.pixel_size = 0.011
	slash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	slash.shaded = false
	slash.transparent = true
	slash.no_depth_test = true
	slash.render_priority = 95
	get_parent().add_child(slash)
	slash.global_position = global_position + pending_attack_direction * 0.62 + Vector3(0, 0.34, 0)
	slash.flip_h = sprite.flip_h
	slash.rotation.z = deg_to_rad(-22.0 if not sprite.flip_h else 22.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "scale", Vector3(1.35, 1.35, 1.35), 0.16)
	tween.tween_property(slash, "modulate", Color(1, 0.45, 0.18, 0), 0.16)
	get_tree().create_timer(0.18).timeout.connect(slash.queue_free)
