extends CharacterBody3D

signal died(enemy: CharacterBody3D)
signal reinforcement_called(enemy: CharacterBody3D)
signal damaged(enemy: CharacterBody3D, amount: int)

const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const GRENADE_PROJECTILE := preload("res://scripts/enemy_grenade.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const DAMAGE_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/damage_number.gd")
const KILL_IMPACT := preload("res://scripts/kill_impact.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const MELEE_SPEED := 5.1
const PISTOL_SPEED := 3.15
const PATROL_SPEED := 1.35
const PATROL_RADIUS := 6.5
const SQUAD_PATROL_RADIUS := 4.2
const ENEMY_MAGAZINE_CAPACITY := {
	"m1911": 6,
	"mp5": 14,
	"ak47": 12,
	"double_barrel": 2,
	# 사다리 상위 기종 — 적 손에선 같은 계열 아키타입으로 다룬다.
	"akm": 12,
	"k2": 12,
	"pump_shotgun": 3,
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
const SPRITE_BASE_POSITION := Vector3(0, 0.48, 0)
const HEALTH_BAR_Y := 1.68
const THREAT_MARKER_Y := 1.98
const RELOAD_INDICATOR_Y := 2.08
const REINFORCEMENT_ICON_Y := 2.42
# ── 엘리트 ──────────────────────────────────────────────────────
# "싸울 이유가 있는 표적" — 같은 스프라이트를 약간 키우고 머리 위 경고
# 아이콘으로 식별시킨다. 아이콘은 "!!"(REINFORCEMENT_ICON_Y 2.42)와 겹치지
# 않게 그보다 위에 둔다. 스탯은 존 티어(threat)만 따른다 — 러버밴딩 금지.
const ELITE_ICON_Y := 3.04
const ELITE_NAME_Y := 2.6
const ELITE_SPRITE_SCALE := 1.18
const ELITE_HEALTH_MULTIPLIER := 2.6
const ELITE_DAMAGE_MULTIPLIER := 1.4
const ELITE_SPEED_MULTIPLIER := 1.12
const MELEE_WINDUP_TIME := 0.46
const MELEE_STRIKE_TIME := 0.16
const MELEE_RECOVERY_TIME := 0.34
const HIT_STAGGER_TIME := 0.13
# 피격 미세 넉백 — 스태거 0.13초 동안 감속(18/s)하며 총 ~0.4u 밀린다.
# 이동 AI와 충돌하지 않게 velocity 임펄스(stagger_velocity)로만 민다.
const HIT_KNOCKBACK_SPEED := 4.4
const STEALTH_TAKEDOWN_MAX_RANGE := 2.05
# 상호 인지 원칙: 적 시야는 플레이어의 적 가시 반경(주간 시야 확장 기준
# 약 16.7u, stealth_system의 fully_visible_radius 430px 환산)을 넘지 않는다.
# 예전 20.0은 화면에 보이지도 않는 적에게 먼저 읽히는 원인이었다.
const MELEE_VISION_RANGE := 14.0
const RANGED_VISION_RANGE := 14.0
const GRENADIER_VISION_RANGE := 14.0
const VISION_RANGE_THREAT_BONUS := 1.5
const VISION_HALF_ANGLE_DEGREES := 60.0
# 야간 플레이어 가시 반경(약 7.2u)에 맞춰 0.72 → 0.52. 밤에도 적이 먼저
# 보는 비대칭을 줄인다.
const NIGHT_VISION_RANGE_MULTIPLIER := 0.52
# Every visual detection fills the same gauge. Proximity only shortens fill time.
const DETECTION_CLOSE_RADIUS := 0.85
const DETECTION_PROXIMITY_RADIUS := 1.25
const FAN_DETECTION_SECONDS_FAR := 2.2
const FAN_DETECTION_SECONDS_NEAR := 0.62
const PROXIMITY_DETECTION_SECONDS_FAR := 1.35
const PROXIMITY_DETECTION_SECONDS_NEAR := 0.38
const DETECTION_DECAY_PER_SECOND := 0.72
const SUSPICION_THRESHOLD := 0.12
const SUSPICION_HOLD_SECONDS := 2.8
const LOAF_STEALTH_REVEAL_RADIUS := 1.35
const LOAF_ESCAPE_CONFIRM_SECONDS := 0.75
const LOAF_AWARENESS_DECAY_MULTIPLIER := 3.5
const ALERT_REACTION_SECONDS := 0.12
const RANGED_WINDUP_TIME := 0.18
const OPENING_PRESSURE_SECONDS := 3.2
const OPENING_PRESSURE_SPEED := 5.25
const ACTIVE_PURSUIT_BASE := 4.5
const ACTIVE_PURSUIT_THREAT_BONUS := 2.5
const SEARCH_BREAK_DISTANCE_BONUS := 10.0
const SEARCH_DURATION_BASE := 7.0
const SEARCH_DURATION_THREAT_BONUS := 4.0
const COMBAT_MEMORY_BASE := 14.0
const COMBAT_MEMORY_THREAT_BONUS := 8.0
const MELEE_DISENGAGE_DISTANCE := 52.0
const RANGED_DISENGAGE_DISTANCE := 76.0
const GRENADE_WINDUP_TIME := 0.72
const GRENADE_RECOVERY_TIME := 0.9
const STEERING_LOCK_MSEC := 220
const FACING_STABILITY_MSEC := 120
const SENTRY_LOOK_INTERVAL_MIN := 0.75
const SENTRY_LOOK_INTERVAL_MAX := 1.25
const FACTION_COMBAT_DAMAGE_MULTIPLIER := 0.42

var enemy_kind := "melee"
var target: CharacterBody3D
var primary_player_target: CharacterBody3D
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
# 피격 플래시/셰이크 전용 트윈 — 자세용 visual_tween과 분리해 연사로
# 초당 여러 발 맞아도 kill 후 재시작만 하면 서로 꼬이지 않는다.
var hit_flash_tween: Tween
var hit_shake_tween: Tween
var weapon_flash_tween: Tween
# 피격 화이트 플래시 보조 스프라이트 — gl_compatibility 렌더러는 과노출
# modulate(2.4배 등)를 1.0으로 클램프해 스프라이트가 실제로 하얘지지 않는다
# (실화면 캡처로 확인). 몸 위에 흰 라디얼 글로를 한 장 겹쳐 번쩍임을 만든다.
var hit_flash_overlay: Sprite3D
var hit_flash_overlay_tween: Tween
# 스프라이트 기본 틴트 — 존 틴트 같은 상시 착색이 생기면 여기에 기록한다.
# 피격 플래시·자세 리셋은 항상 이 값 + 현재 가시성 알파로 복귀한다.
var sprite_base_tint := Color.WHITE
var patrol_origin := Vector3.ZERO
var patrol_target := Vector3.ZERO
var patrol_pause := 0.0
var patrol_repath_time := 0.0
var patrol_mode := "route"
var patrol_route: Array[Vector3] = []
var patrol_route_index := 0
var patrol_look_timer := 0.0
var patrol_stuck_time := 0.0
var squad_id := -1
var squad_anchor := Vector3.ZERO
var squad_formation_offset := Vector3.ZERO
var threat_level := 0.0
var alerted := false
var alert_marker_time := 0.0
var combat_reaction_time := 0.0
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
var health_bar_background: Sprite3D
var health_bar_damage_trail: Sprite3D
var health_bar_fill: Sprite3D
var reload_indicator: Sprite3D
var detection_indicator: Sprite3D
var magazine_size := 1
var magazine_ammo := 1
var reload_duration := 1.8
var reload_elapsed := 0.0
var reinforcement_call_indicator: Sprite3D
# 호출 중인 적을 판 위에서 즉시 골라낼 수 있게 하는 두 장치.
# 머리 위 "!!"(threat_marker는 매 프레임 꺼지는 로직이 있어 별도 노드로 둔다)와
# 발밑 링 — "저 녀석을 죽여라"가 화살표·지도 없이 읽혀야 한다.
var reinforcement_call_marker: Label3D
var reinforcement_call_ring: Sprite3D
var reinforcement_call_active := false
var reinforcement_call_elapsed := 0.0
var reinforcement_call_duration := 8.0
var tactical_waypoint := Vector3.INF
var tactical_repath_timer := 0.0
var hold_position_timer := 0.0
var has_current_line_of_sight := false
var lost_sight_time := 0.0
var ambient_visibility_factor := 1.0
var target_stationary_time := 0.0
var detection_awareness := 0.0
var player_override_awareness := 0.0
var detection_range_multiplier := 1.0
var detection_half_angle_degrees := VISION_HALF_ANGLE_DEGREES
var detection_time_multiplier := 1.0
var perception_state := "patrol"
var suspicion_hold_time := 0.0
var search_time_remaining := 0.0
var search_look_timer := 0.0
var search_turn_sign := 1.0
var health_ratio := 1.0
var damage_trail_ratio := 1.0
var damage_trail_delay := 0.0
# 피격 뒤 잔상이 따라 줄기 시작하기까지의 지연. 보스는 0.4로 늘려 "깎였다"를 더 보여 준다.
var damage_trail_delay_seconds := 0.28
var grenade_cooldown := 0.0
var grenade_target_position := Vector3.ZERO
var steering_direction_cache := Vector3.ZERO
var steering_lock_until_msec := 0
var pending_facing := ""
var pending_facing_since_msec := 0
var faction_id := "raider"
var opening_shot_pending := false
var opening_pressure_time := 0.0
# 엘리트 상태 — promote_to_elite()가 스폰 직후 한 번만 켠다.
var elite := false
var elite_damage_multiplier := 1.0
var elite_speed_multiplier := 1.0
var elite_icon: Sprite3D
var elite_name_label: Label3D
static var weapon_texture_cache: Dictionary = {}
static var health_bar_texture_cache: Dictionary = {}
static var reload_texture_cache: Dictionary = {}
static var detection_texture_cache: Dictionary = {}
static var lost_target_texture: Texture2D
static var reinforcement_call_texture_cache: Dictionary = {}
static var reinforcement_ring_texture: Texture2D
static var hit_flash_overlay_texture: Texture2D


func configure(
	kind: String,
	target_body: CharacterBody3D,
	_sheets: Dictionary,
	initial_threat: float = 0.0,
	assigned_weapon_id: String = ""
) -> void:
	enemy_kind = kind
	target = target_body
	primary_player_target = target_body
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
	# 파밍의 손맛은 "스택이 체감될 때" 산다. 예전 곡선은 종로(위협 0.15)~남산
	# (1.0) 사이 체력이 1.4배밖에 안 벌어져서, 장비를 갖춰도 초반이 안 물렁하고
	# 후반이 안 단단했다. 기본값을 낮추고 위협 보너스를 키워 곡선을 2배 가까이
	# 벌린다 — 갖추면 초반을 쓸어버리고, 심층은 진짜 벽이 되도록.
	var base_health := 120 if enemy_kind == "melee" else (100 if enemy_kind == "grenadier" else 84)
	var threat_health_bonus := 150.0 if enemy_kind == "melee" else (132.0 if enemy_kind == "grenadier" else 118.0)
	health = base_health + roundi(threat_health_bonus * threat_level)
	max_health = health
	health_ratio = 1.0
	damage_trail_ratio = 1.0


func set_threat_level(value: float) -> void:
	threat_level = clampf(value, 0.0, 1.0)


func promote_to_elite(elite_display_name: String) -> void:
	# 엘리트 승격 — 스폰 직후(add_child 이후) 한 번만 호출한다.
	# HP ~2.6배·피해 ~1.4배·이동 약간 빠르게. 새 스프라이트 없이 기존 리소스를
	# 키우고(×1.18) 머리 위 경고 아이콘을 단다. 아이콘은 발각 전에도 보인다 —
	# "쟤는 위험하다"를 접근 전에 알고 싸울지 말지 고를 수 있어야 한다.
	if elite:
		return
	elite = true
	elite_damage_multiplier = ELITE_DAMAGE_MULTIPLIER
	elite_speed_multiplier = ELITE_SPEED_MULTIPLIER
	health = roundi(float(health) * ELITE_HEALTH_MULTIPLIER)
	max_health = health
	set_meta("elite", true)
	set_meta("display_name", elite_display_name)
	if sprite:
		sprite.scale *= ELITE_SPRITE_SCALE
	if shadow:
		shadow.scale = Vector3(ELITE_SPRITE_SCALE, 1.0, ELITE_SPRITE_SCALE)
	if weapon_visual:
		weapon_visual.scale *= ELITE_SPRITE_SCALE
	# 위협 아이콘 — 경고 삼각형(ui_icon_factory "alert")을 붉게. stealth의
	# 가시성 페이드(set_player_visibility_factor)에 안 넣어서 상시 표시된다.
	elite_icon = Sprite3D.new()
	elite_icon.name = "EliteThreatIcon"
	elite_icon.texture = UI_ICONS.get_icon("alert", 96, Color("#ff5f4a"))
	elite_icon.position = Vector3(0, ELITE_ICON_Y, 0)
	elite_icon.pixel_size = 0.0052
	elite_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	elite_icon.shaded = false
	elite_icon.transparent = true
	elite_icon.no_depth_test = true
	elite_icon.render_priority = 121
	add_child(elite_icon)
	# 이름표 — 보스 마커(Label3D) 패턴 재사용. 다만 상시 노출은 소음이라
	# 가시성 페이드를 태워 실제로 보이는 거리에서만 읽히게 한다.
	elite_name_label = Label3D.new()
	elite_name_label.name = "EliteNameLabel"
	elite_name_label.text = elite_display_name
	elite_name_label.position = Vector3(0, ELITE_NAME_Y, 0)
	elite_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	elite_name_label.no_depth_test = true
	elite_name_label.render_priority = 120
	elite_name_label.font = DAMAGE_FONT
	elite_name_label.font_size = 30
	elite_name_label.pixel_size = 0.005
	elite_name_label.modulate = Color("#f3b7a4")
	elite_name_label.outline_modulate = Color(0.1, 0.02, 0.01, 0.95)
	elite_name_label.outline_size = 8
	add_child(elite_name_label)


func set_environment_visibility(night_factor: float) -> void:
	ambient_visibility_factor = lerpf(
		1.0,
		NIGHT_VISION_RANGE_MULTIPLIER,
		clampf(night_factor, 0.0, 1.0)
	)


func set_detection_profile(
	range_multiplier: float,
	half_angle_degrees: float,
	time_multiplier: float = 1.0
) -> void:
	detection_range_multiplier = clampf(range_multiplier, 0.55, 1.25)
	detection_half_angle_degrees = clampf(half_angle_degrees, 32.0, 72.0)
	detection_time_multiplier = clampf(time_multiplier, 0.55, 1.8)


func apply_blackout() -> void:
	# 정전 이벤트: 적도 앞이 안 보인다. 플레이어만 손해 보는 사건은 재미없다.
	detection_range_multiplier = clampf(detection_range_multiplier * 0.62, 0.35, 1.25)
	detection_time_multiplier = clampf(detection_time_multiplier * 1.35, 0.55, 2.4)


func set_faction(value: String) -> void:
	faction_id = value


func get_faction_id() -> String:
	return faction_id


func set_combat_target(next_target: CharacterBody3D) -> void:
	if not is_instance_valid(next_target) or next_target == self:
		return
	target = next_target
	last_known_position = next_target.global_position
	_become_alerted()


func is_targeting_player() -> bool:
	return target == primary_player_target


func restore_player_target() -> void:
	if is_instance_valid(primary_player_target):
		target = primary_player_target
		_clear_alert()


# ── 통조림 유인 ────────────────────────────────────────────────
# 던져진 통조림 소리에 끌려가 먹는다. 경계(alerted) 전 상태에서만 작동하고,
# 의심(suspicious)이 생기면 즉시 유인을 버린다 — 먹다가도 인기척엔 반응한다.
var lure_point: Node3D
var lure_arrived := false


func set_lure_point(point: Node3D) -> bool:
	# 유인 불가: 죽는 중 / 이미 경계(플레이어든 타 세력이든 교전 중이면
	# alerted=true) / 기절 / 보스(통조림 앞에 쪼그려 앉는 보스는 위엄이 없다).
	# 반환값 true = 실제로 반응했다 — can_throw가 반응 연출(말풍선·마커)에 쓴다.
	if dying or alerted or backstab_stunned or bool(get_meta("raid_boss", false)):
		return false
	if combat_state != "normal":
		return false
	lure_point = point
	lure_arrived = false
	return true


func is_lure_eating() -> bool:
	return lure_arrived and is_instance_valid(lure_point)


func _update_lure_behavior(_delta: float) -> bool:
	if not is_instance_valid(lure_point):
		lure_point = null
		lure_arrived = false
		return false
	var offset := lure_point.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 1.15:
		lure_arrived = false
		var direction := _steer_around_obstacles(offset.normalized())
		velocity = direction * PATROL_SPEED * 1.25
		_set_facing_from_world_direction(direction)
		_set_motion_state("walk")
		return true
	# 도착: 통조림을 내려다보며 먹는다 — 캔이 사라질 때까지 정지 표적이 된다.
	# (도착 감지·게이지·대사는 CanThrowSystem이 lure_arrived를 보고 처리한다.)
	lure_arrived = true
	velocity = velocity.move_toward(Vector3.ZERO, 20.0 * _delta)
	if offset.length_squared() > 0.01:
		_set_facing_from_world_direction(offset.normalized())
	_set_motion_state("idle")
	return true


func add_scent_suspicion(scent_position: Vector3, amount: float) -> void:
	if dying or alerted:
		return
	# 진입 유예 중에는 냄새로도 끌려오지 않는다 — 스폰에서 지도를 읽는 동안
	# 고인 냄새가 순찰을 끌어들여 '시작하자마자 포위'를 만들었다.
	var scene := _raid_host()
	if (
		scene != null
		and scene.has_method("is_raid_entry_grace_active")
		and bool(scene.call("is_raid_entry_grace_active"))
	):
		return
	detection_awareness = minf(0.88, detection_awareness + maxf(0.0, amount))
	last_known_position = scent_position
	if detection_awareness >= SUSPICION_THRESHOLD:
		perception_state = "suspicious"
		suspicion_hold_time = maxf(suspicion_hold_time, SUSPICION_HOLD_SECONDS)


func assign_squad(assigned_squad_id: int, assigned_anchor: Vector3, formation_offset: Vector3) -> void:
	squad_id = assigned_squad_id
	squad_anchor = assigned_anchor
	squad_formation_offset = formation_offset
	patrol_origin = squad_anchor + squad_formation_offset
	_choose_patrol_target()


func configure_patrol(mode: String, route_points: Array[Vector3]) -> void:
	patrol_mode = (
		"sentry"
		if mode == "sentry"
		else ("road_route" if mode == "road_route" else "route")
	)
	patrol_route.clear()
	patrol_route.assign(route_points)
	patrol_route_index = 0
	if patrol_route.is_empty():
		patrol_route.append(global_position)
	patrol_origin = patrol_route[0]
	patrol_target = patrol_route[0]
	patrol_pause = weapon_random.randf_range(0.4, 1.2)
	patrol_look_timer = 0.0
	patrol_repath_time = 8.0


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
	if detection_indicator:
		var detection_color := detection_indicator.modulate
		detection_color.a = player_visibility_factor
		detection_indicator.modulate = detection_color
	if reinforcement_call_indicator:
		var call_color := reinforcement_call_indicator.modulate
		call_color.a = player_visibility_factor
		reinforcement_call_indicator.modulate = call_color
	if shadow:
		shadow.transparency = 1.0 - player_visibility_factor
	# 엘리트 이름표는 가시성 페이드를 따른다(실제로 보이는 거리에서만 읽힌다).
	# elite_icon은 일부러 여기서 제외 — 발각 전에도 "쟤는 위험하다"가 보여야 한다.
	if elite_name_label:
		var elite_name_color := elite_name_label.modulate
		elite_name_color.a = player_visibility_factor
		elite_name_label.modulate = elite_name_color
	_update_vision_fan_visual()
	_update_health_bar_visibility()


func _ready() -> void:
	add_to_group("raid_enemy")
	weapon_random.seed = get_instance_id() * 7919 + int(threat_level * 1000.0)
	grenade_cooldown = weapon_random.randf_range(2.4, 5.0)
	collision_layer = COLLISION_PROFILES.ENEMY_LAYER
	collision_mask = COLLISION_PROFILES.ENEMY_MOVEMENT_MASK

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
	_setup_hit_flash_overlay()
	_setup_weapon_visual()
	_setup_enemy_health_bar()
	_setup_reload_indicator()
	_setup_detection_indicator()
	_setup_reinforcement_call_indicator()

	threat_marker = Label3D.new()
	threat_marker.name = "ThreatMarker"
	threat_marker.text = "◆"
	threat_marker.position = Vector3(0, THREAT_MARKER_Y, 0)
	# 폰트를 안 박으면 웹 기본 폰트로 떨어져 ◆·★ 글리프가 깨진 네모로 뜬다.
	threat_marker.font = DAMAGE_FONT
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
	combat_reaction_time = maxf(0.0, combat_reaction_time - delta)
	opening_pressure_time = maxf(0.0, opening_pressure_time - delta)
	_update_alert_marker(delta)
	_update_detection_indicator()
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
	if not is_instance_valid(target) and is_instance_valid(primary_player_target):
		target = primary_player_target
		_clear_alert()
	if not is_instance_valid(target):
		has_current_line_of_sight = false
		_update_patrol(delta)
		move_and_slide()
		return
	if _target_is_in_safe_zone():
		has_current_line_of_sight = false
		combat_state = "normal"
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return
	_update_primary_player_override_detection(delta)

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var vision_range := _get_vision_range()
	var combat_lock_range := _get_combat_lock_range()
	var target_concealed_by_loaf := _is_target_concealed_by_loaf(distance)
	var has_line_of_sight := _has_line_of_sight()
	var target_inside_detection_fan := _is_position_inside_vision_fan(
		target.global_position,
		vision_range
	)
	var target_inside_combat_view := distance <= combat_lock_range
	var has_visual_contact := (
		has_line_of_sight
		and target_inside_combat_view
		and not target_concealed_by_loaf
	)
	has_current_line_of_sight = alerted and has_visual_contact
	if alerted and distance > _get_disengage_distance():
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return
	if not alerted:
		var detection_completed := _update_detection_awareness(
			delta,
			distance,
			has_line_of_sight,
			vision_range
		)
		if detection_completed:
			_become_alerted()
		else:
			if perception_state == "suspicious":
				# 인기척이 통조림보다 우선 — 먹다가도 의심이 생기면 조사한다.
				lure_arrived = false
				_update_suspicious_behavior(
					delta,
					has_line_of_sight and target_inside_detection_fan
				)
			elif _update_lure_behavior(delta):
				pass
			else:
				_update_patrol(delta)
			move_and_slide()
			return
	if alerted and combat_reaction_time > 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		if has_visual_contact:
			last_known_position = target.global_position
		var reaction_offset := last_known_position - global_position
		reaction_offset.y = 0.0
		if reaction_offset.length_squared() > 0.01:
			_set_facing_from_world_direction(reaction_offset.normalized())
		_set_motion_state("idle")
		move_and_slide()
		return
	if alerted and distance <= combat_lock_range and not target_concealed_by_loaf:
		last_known_position = target.global_position
		pursuit_time = COMBAT_MEMORY_BASE + COMBAT_MEMORY_THREAT_BONUS * threat_level
		lost_sight_time = 0.0
		search_time_remaining = 0.0
		perception_state = "combat"
		if has_visual_contact and target.velocity.length_squared() <= 0.16:
			target_stationary_time += delta
		else:
			target_stationary_time = maxf(0.0, target_stationary_time - delta * 2.5)
		if not has_visual_contact:
			_pursue_last_known_position()
			move_and_slide()
			return
	elif alerted and pursuit_time > 0.0:
		pursuit_time = maxf(0.0, pursuit_time - delta)
		lost_sight_time += delta
		target_stationary_time = maxf(0.0, target_stationary_time - delta * 0.35)
		var active_pursuit_duration := (
			LOAF_ESCAPE_CONFIRM_SECONDS
			if target_concealed_by_loaf
			else ACTIVE_PURSUIT_BASE + ACTIVE_PURSUIT_THREAT_BONUS * threat_level
		)
		var target_escaped := distance >= _get_search_break_distance()
		if lost_sight_time <= active_pursuit_duration and not target_escaped:
			perception_state = "combat"
			_pursue_last_known_position()
		else:
			if search_time_remaining <= 0.0:
				search_time_remaining = (
					SEARCH_DURATION_BASE
					+ SEARCH_DURATION_THREAT_BONUS * threat_level
				)
				search_look_timer = 0.0
			perception_state = "search"
			_update_search_behavior(delta)
		move_and_slide()
		return
	else:
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return

	var direction := offset.normalized() if distance > 0.01 else Vector3.ZERO
	_set_facing_from_world_direction(direction)
	if (
		opening_shot_pending
		and enemy_kind not in ["melee", "grenadier"]
		and has_visual_contact
		and distance <= _get_weapon_engagement_range()
	):
		opening_shot_pending = false
		opening_pressure_time = OPENING_PRESSURE_SECONDS
		_start_pistol_burst(direction)
		move_and_slide()
		return
	if enemy_kind == "melee":
		_update_melee(direction, distance)
	elif enemy_kind == "grenadier":
		_update_grenadier(direction, distance, delta)
	else:
		_update_pistol(direction, distance, delta)
	if combat_state == "normal":
		_set_motion_state("walk" if velocity.length_squared() > 0.05 else "idle")
	move_and_slide()


func _get_base_vision_range() -> float:
	return (
		MELEE_VISION_RANGE
		if enemy_kind == "melee"
		else (GRENADIER_VISION_RANGE if enemy_kind == "grenadier" else RANGED_VISION_RANGE)
	)


func _get_vision_range() -> float:
	return (
		(_get_base_vision_range() + VISION_RANGE_THREAT_BONUS * threat_level)
		* ambient_visibility_factor
		* detection_range_multiplier
		* _get_target_visibility_multiplier()
	)


func _get_combat_lock_range() -> float:
	var detection_range := (
		(_get_base_vision_range() + VISION_RANGE_THREAT_BONUS * threat_level)
		* detection_range_multiplier
	)
	if enemy_kind != "melee":
		return maxf(detection_range, _get_weapon_engagement_range() * 0.92)
	return detection_range


func _get_search_break_distance() -> float:
	return _get_combat_lock_range() + SEARCH_BREAK_DISTANCE_BONUS


func _get_target_visibility_multiplier() -> float:
	if target != primary_player_target or not is_instance_valid(primary_player_target):
		return 1.0
	# 상한 1.45: 무거운 방어구는 1.0을 넘겨 "더 잘 보이는" 페널티를 허용한다.
	return clampf(
		float(primary_player_target.get_meta("stealth_visibility_multiplier", 1.0)),
		0.35,
		1.45
	)


func _is_target_concealed_by_loaf(distance: float) -> bool:
	if target != primary_player_target or not is_instance_valid(primary_player_target):
		return false
	return (
		bool(primary_player_target.get_meta("loafing_stealth", false))
		and distance > LOAF_STEALTH_REVEAL_RADIUS
	)


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
	return (
		forward.normalized().dot(offset.normalized())
		>= cos(deg_to_rad(detection_half_angle_degrees))
	)


func _update_detection_awareness(
	delta: float,
	distance: float,
	has_line_of_sight: bool,
	vision_range: float
) -> bool:
	var visibility_multiplier := _get_target_visibility_multiplier()
	if _is_target_concealed_by_loaf(distance):
		_decay_detection_awareness(delta, LOAF_AWARENESS_DECAY_MULTIPLIER)
		return false
	if not has_line_of_sight:
		_decay_detection_awareness(delta)
		return false
	var detection_seconds := _get_detection_seconds(
		target.global_position,
		distance,
		vision_range,
		visibility_multiplier
	)
	if detection_seconds < 0.0:
		_decay_detection_awareness(delta)
		return false
	# 진입 유예 — 판 시작 직후 지도를 읽는 동안에는 지근거리가 아니면
	# 시야 탐지가 쌓이지 않는다. 플레이어가 먼저 쏘면 유예는 즉시 끝난다.
	var scene := _raid_host()
	if (
		distance > 9.0
		and scene != null
		and scene.has_method("is_raid_entry_grace_active")
		and bool(scene.call("is_raid_entry_grace_active"))
	):
		_decay_detection_awareness(delta)
		return false
	detection_awareness = minf(
		1.0,
		detection_awareness + delta / maxf(0.1, detection_seconds)
	)
	last_known_position = target.global_position
	if detection_awareness >= SUSPICION_THRESHOLD:
		perception_state = "suspicious"
		suspicion_hold_time = SUSPICION_HOLD_SECONDS
	return detection_awareness >= 1.0


func _get_detection_seconds(
	world_position: Vector3,
	distance: float,
	vision_range: float,
	visibility_multiplier: float
) -> float:
	var close_radius := DETECTION_CLOSE_RADIUS * visibility_multiplier
	var proximity_radius := DETECTION_PROXIMITY_RADIUS * visibility_multiplier
	var inside_vision_fan := _is_position_inside_vision_fan(
		world_position,
		vision_range
	)
	var base_seconds := -1.0
	if inside_vision_fan:
		var to_target := world_position - global_position
		to_target.y = 0.0
		var forward := facing_world_direction
		forward.y = 0.0
		var direction_dot := forward.normalized().dot(to_target.normalized())
		var edge_dot := cos(deg_to_rad(detection_half_angle_degrees))
		var center_factor := clampf(
			inverse_lerp(edge_dot, 1.0, direction_dot),
			0.0,
			1.0
		)
		var distance_factor := clampf(
			1.0 - distance / maxf(vision_range, 0.01),
			0.0,
			1.0
		)
		var certainty_factor := clampf(
			pow(center_factor, 1.1) * 0.62 + pow(distance_factor, 0.85) * 0.38,
			0.0,
			1.0
		)
		base_seconds = lerpf(
			FAN_DETECTION_SECONDS_FAR,
			FAN_DETECTION_SECONDS_NEAR,
			certainty_factor
		)
	elif distance <= proximity_radius:
		var proximity_factor := clampf(
			inverse_lerp(proximity_radius, 0.0, distance),
			0.0,
			1.0
		)
		base_seconds = lerpf(
			PROXIMITY_DETECTION_SECONDS_FAR,
			PROXIMITY_DETECTION_SECONDS_NEAR,
			proximity_factor
		)
		if distance <= close_radius:
			base_seconds = minf(base_seconds, PROXIMITY_DETECTION_SECONDS_NEAR)
	if base_seconds < 0.0:
		return -1.0
	# 유저 체감상 발각이 즉각적이라 여유 +1.5초 — 점진 감지 전 구간에 일괄로
	# 더해, 시야에 걸려도 반응·이탈할 시간이 생긴다. (피격 즉시 경계는 별도 경로)
	return (
		base_seconds
		* detection_time_multiplier
		/ maxf(visibility_multiplier, 0.1)
		+ 1.5
	)


func _decay_detection_awareness(delta: float, multiplier: float = 1.0) -> void:
	detection_awareness = maxf(
		0.0,
		detection_awareness - DETECTION_DECAY_PER_SECOND * multiplier * delta
	)
	if detection_awareness <= 0.0 and suspicion_hold_time <= 0.0:
		perception_state = "patrol"


func _update_primary_player_override_detection(delta: float) -> void:
	if (
		not is_instance_valid(primary_player_target)
		or target == primary_player_target
		or primary_player_target.get_parent() == null
	):
		player_override_awareness = 0.0
		return
	var player_offset := primary_player_target.global_position - global_position
	player_offset.y = 0.0
	var distance := player_offset.length()
	if (
		bool(primary_player_target.get_meta("loafing_stealth", false))
		and distance > LOAF_STEALTH_REVEAL_RADIUS
	):
		player_override_awareness = maxf(
			0.0,
			player_override_awareness
			- DETECTION_DECAY_PER_SECOND * LOAF_AWARENESS_DECAY_MULTIPLIER * delta
		)
		return
	var visibility_multiplier := clampf(
		float(primary_player_target.get_meta("stealth_visibility_multiplier", 1.0)),
		0.35,
		1.0
	)
	var base_range := (
		MELEE_VISION_RANGE
		if enemy_kind == "melee"
		else (GRENADIER_VISION_RANGE if enemy_kind == "grenadier" else RANGED_VISION_RANGE)
	)
	var vision_range := (
		(base_range + VISION_RANGE_THREAT_BONUS * threat_level)
		* ambient_visibility_factor
		* detection_range_multiplier
		* visibility_multiplier
	)
	if not _has_line_of_sight_to(primary_player_target):
		player_override_awareness = maxf(
			0.0,
			player_override_awareness - DETECTION_DECAY_PER_SECOND * delta
		)
		return
	var detection_seconds := _get_detection_seconds(
		primary_player_target.global_position,
		distance,
		vision_range,
		visibility_multiplier
	)
	if detection_seconds < 0.0:
		player_override_awareness = maxf(
			0.0,
			player_override_awareness - DETECTION_DECAY_PER_SECOND * delta
		)
		return
	player_override_awareness = minf(
		1.0,
		player_override_awareness + delta / maxf(0.1, detection_seconds)
	)
	if player_override_awareness < 1.0:
		return
	target = primary_player_target
	last_known_position = primary_player_target.global_position
	detection_awareness = 1.0
	player_override_awareness = 0.0
	_become_alerted()


func _update_suspicious_behavior(delta: float, has_line_of_sight: bool) -> void:
	suspicion_hold_time = maxf(0.0, suspicion_hold_time - delta)
	var offset := last_known_position - global_position
	offset.y = 0.0
	if has_line_of_sight and offset.length_squared() > 0.01:
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_set_facing_from_world_direction(offset.normalized())
		_set_motion_state("idle")
	elif offset.length() > 1.35 and suspicion_hold_time > 0.0:
		var direction := _steer_around_obstacles(offset.normalized())
		velocity = direction * PATROL_SPEED * 0.72
		_set_facing_from_world_direction(direction)
		_set_motion_state("walk")
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_set_motion_state("idle")
	if suspicion_hold_time <= 0.0 and detection_awareness <= SUSPICION_THRESHOLD * 0.45:
		perception_state = "return"
		patrol_target = patrol_origin
		patrol_repath_time = 5.0


func _update_search_behavior(delta: float) -> void:
	search_time_remaining = maxf(0.0, search_time_remaining - delta)
	search_look_timer = maxf(0.0, search_look_timer - delta)
	var offset := last_known_position - global_position
	offset.y = 0.0
	if offset.length() > 1.2:
		var direction := _steer_around_obstacles(offset.normalized())
		velocity = direction * PATROL_SPEED * 1.18
		_set_facing_from_world_direction(direction)
		_set_motion_state("walk")
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_set_motion_state("idle")
		if search_look_timer <= 0.0:
			var turn_angle := deg_to_rad(54.0 * search_turn_sign)
			var facing_2d := Vector2(facing_world_direction.x, facing_world_direction.z)
			facing_2d = facing_2d.rotated(turn_angle)
			_set_facing_from_world_direction(Vector3(facing_2d.x, 0.0, facing_2d.y))
			search_turn_sign *= -1.0
			search_look_timer = 0.8
	if search_time_remaining <= 0.0:
		_clear_alert()


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
	# 적의 장전 클릭 — 가까이서 들리면 "지금이 기회"라는 텔레그래프가 된다.
	SFX.play("reload_start", global_position, -4.0)


func _update_reload(delta: float) -> void:
	reload_elapsed += delta
	var progress := clampf(reload_elapsed / reload_duration, 0.0, 1.0)
	reload_indicator.texture = _get_reload_texture(roundi(progress * 20.0))
	reload_indicator.visible = true
	if is_instance_valid(target):
		var toward_target := target.global_position - global_position
		toward_target.y = 0.0
		var target_distance := toward_target.length()
		if target_distance > 0.01:
			toward_target /= target_distance
			_set_facing_from_world_direction(toward_target)
			if target_distance > 5.5:
				velocity = (
					_steer_around_obstacles(toward_target)
					* PISTOL_SPEED
					* 1.22
				)
			else:
				var strafe := Vector3(-toward_target.z, 0.0, toward_target.x) * strafe_sign
				velocity = _steer_around_obstacles(strafe) * PISTOL_SPEED * 0.52
	elif last_known_position != Vector3.INF:
		var toward_last_known := last_known_position - global_position
		toward_last_known.y = 0.0
		if toward_last_known.length_squared() > 0.01:
			velocity = (
				_steer_around_obstacles(toward_last_known.normalized())
				* PISTOL_SPEED
				* 1.05
			)
	if progress >= 1.0:
		magazine_ammo = magazine_size
		combat_state = "normal"
		reload_indicator.visible = false
		SFX.play("reload_end", global_position, -4.0)
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

	reinforcement_call_marker = Label3D.new()
	reinforcement_call_marker.name = "ReinforcementCallMarker"
	reinforcement_call_marker.text = "!!"
	reinforcement_call_marker.position = Vector3(0, REINFORCEMENT_ICON_Y + 0.62, 0)
	# 폰트를 안 박으면 웹 기본 폰트로 떨어진다(threat_marker와 같은 이유).
	reinforcement_call_marker.font = DAMAGE_FONT
	reinforcement_call_marker.font_size = 82
	reinforcement_call_marker.outline_size = 20
	reinforcement_call_marker.modulate = Color("#ff3b2f")
	reinforcement_call_marker.outline_modulate = Color(0.14, 0.006, 0.004, 1.0)
	reinforcement_call_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reinforcement_call_marker.no_depth_test = true
	reinforcement_call_marker.render_priority = 127
	reinforcement_call_marker.visible = false
	add_child(reinforcement_call_marker)

	reinforcement_call_ring = Sprite3D.new()
	reinforcement_call_ring.name = "ReinforcementCallRing"
	reinforcement_call_ring.texture = _get_reinforcement_ring_texture()
	reinforcement_call_ring.position = Vector3(0, 0.06, 0)
	# 바닥에 눕힌다 — 빌보드로 두면 벽처럼 서서 링으로 안 읽힌다.
	reinforcement_call_ring.axis = Vector3.AXIS_Y
	reinforcement_call_ring.pixel_size = 0.017
	reinforcement_call_ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	reinforcement_call_ring.shaded = false
	reinforcement_call_ring.transparent = true
	reinforcement_call_ring.no_depth_test = true
	reinforcement_call_ring.render_priority = 118
	reinforcement_call_ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	reinforcement_call_ring.visible = false
	add_child(reinforcement_call_ring)


func _get_reinforcement_ring_texture() -> Texture2D:
	# 발밑 붉은 링 한 장. 전 개체가 같은 텍스처를 공유한다.
	if reinforcement_ring_texture != null:
		return reinforcement_ring_texture
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(47.5, 47.5)
	for y in 96:
		for x in 96:
			var radius := (Vector2(x, y) - center).length()
			if radius >= 33.0 and radius <= 46.0:
				# 바깥으로 갈수록 옅어지는 두꺼운 테두리.
				var edge := clampf(1.0 - absf(radius - 38.0) / 9.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 0.24, 0.18, 0.28 + edge * 0.62))
			elif radius < 33.0 and radius >= 30.0:
				image.set_pixel(x, y, Color(1.0, 0.42, 0.3, 0.22))
	reinforcement_ring_texture = ImageTexture.create_from_image(image)
	return reinforcement_ring_texture


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


func start_reinforcement_call(duration: float = 8.0) -> bool:
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
	_set_reinforcement_call_emphasis(true)
	_set_motion_state("idle")
	return true


func _set_reinforcement_call_emphasis(active: bool) -> void:
	# 머리 위 "!!"와 발밑 링을 함께 켜고 끈다.
	if reinforcement_call_marker:
		reinforcement_call_marker.visible = active
	if reinforcement_call_ring:
		reinforcement_call_ring.visible = active


func _update_reinforcement_call(delta: float) -> void:
	reinforcement_call_elapsed += delta
	var progress := clampf(reinforcement_call_elapsed / reinforcement_call_duration, 0.0, 1.0)
	reinforcement_call_indicator.texture = _get_reinforcement_call_texture(roundi(progress * 24.0))
	reinforcement_call_indicator.visible = true
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.055
	reinforcement_call_indicator.scale = Vector3.ONE * pulse
	# 남은 시간이 줄수록 "!!"와 링이 빨라지고 커진다 — 배너 게이지와 같은 박자.
	if reinforcement_call_marker:
		var urgency := 0.012 + progress * 0.016
		reinforcement_call_marker.visible = true
		reinforcement_call_marker.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * urgency) * 0.12)
	if reinforcement_call_ring:
		reinforcement_call_ring.visible = true
		reinforcement_call_ring.scale = Vector3.ONE * (1.0 + progress * 0.35)
	if progress >= 1.0:
		reinforcement_call_active = false
		reinforcement_call_indicator.visible = false
		_set_reinforcement_call_emphasis(false)
		combat_state = "normal"
		attack_cooldown = 0.45
		reinforcement_called.emit(self)


func _cancel_reinforcement_call() -> void:
	reinforcement_call_active = false
	if reinforcement_call_indicator:
		reinforcement_call_indicator.visible = false
	_set_reinforcement_call_emphasis(false)
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
			elif kind == "trail_white":
				# 보스 체력바의 감소분 잔상 — 흰색이라 "방금 깎인 양"이 한눈에 읽힌다.
				color = Color(0.96, 0.96, 0.93, 0.96)
			elif kind == "poise":
				# 보스 강인도(그로기까지 누적) 게이지 — 노랑. "때리면 뭔가 쌓인다".
				color = Color(1.0, 0.84 - float(y) / float(height) * 0.1, 0.25, 0.98)
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
	damage_trail_delay = damage_trail_delay_seconds
	_set_health_bar_ratio(health_bar_fill, health_ratio)
	_set_health_bar_ratio(health_bar_damage_trail, damage_trail_ratio)


func get_projectile_hit_center() -> Vector3:
	return global_position + Vector3(0, 0.08, 0)


func get_projectile_hit_radius() -> float:
	# Keep the logical hit silhouette slightly wider than the feet collider so
	# stationary actions such as reloading and radio calls remain dependable.
	return 0.62


func _update_patrol(delta: float) -> void:
	if perception_state == "return":
		var return_target := squad_anchor + squad_formation_offset if squad_id >= 0 else patrol_origin
		var return_offset := return_target - global_position
		return_offset.y = 0.0
		if return_offset.length() > 1.25:
			var return_direction := _steer_around_obstacles(return_offset.normalized())
			velocity = return_direction * PATROL_SPEED
			_set_facing_from_world_direction(return_direction)
			_set_motion_state("walk")
			return
		perception_state = "patrol"
		_choose_patrol_target()
	patrol_pause = maxf(0.0, patrol_pause - delta)
	patrol_repath_time = maxf(0.0, patrol_repath_time - delta)
	patrol_look_timer = maxf(0.0, patrol_look_timer - delta)
	if patrol_pause > 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_set_motion_state("idle")
		if patrol_mode == "sentry" and patrol_look_timer <= 0.0:
			var look_angle := deg_to_rad(weapon_random.randf_range(48.0, 112.0))
			if weapon_random.randf() < 0.5:
				look_angle *= -1.0
			_set_facing_from_world_direction(
				facing_world_direction.rotated(Vector3.UP, look_angle)
			)
			patrol_look_timer = weapon_random.randf_range(
				SENTRY_LOOK_INTERVAL_MIN,
				SENTRY_LOOK_INTERVAL_MAX
			)
		return

	var offset := patrol_target - global_position
	offset.y = 0.0
	if offset.length() <= 0.65:
		velocity = Vector3.ZERO
		patrol_stuck_time = 0.0
		if not patrol_route.is_empty():
			patrol_route_index = (patrol_route_index + 1) % patrol_route.size()
			patrol_target = patrol_route[patrol_route_index]
			patrol_repath_time = 8.0
			if patrol_mode == "sentry":
				patrol_pause = weapon_random.randf_range(2.4, 4.8)
				patrol_look_timer = 0.08
			elif patrol_mode == "road_route":
				patrol_pause = weapon_random.randf_range(0.08, 0.24)
			else:
				patrol_pause = weapon_random.randf_range(0.2, 0.65)
		else:
			patrol_pause = randf_range(0.25, 0.75)
			_choose_patrol_target()
		_set_motion_state("idle")
		return
	if patrol_repath_time <= 0.0:
		patrol_repath_time = 8.0
		if patrol_route.is_empty():
			_choose_patrol_target()

	var direction := _steer_around_obstacles(offset.normalized())
	if direction.length_squared() <= 0.01:
		velocity = Vector3.ZERO
		patrol_stuck_time += delta
		_set_motion_state("idle")
		if patrol_stuck_time >= 0.75:
			patrol_stuck_time = 0.0
			if not patrol_route.is_empty():
				patrol_route_index = (patrol_route_index + 1) % patrol_route.size()
				patrol_target = patrol_route[patrol_route_index]
			else:
				_choose_patrol_target()
			patrol_pause = 0.12
		return
	patrol_stuck_time = 0.0
	velocity = direction * PATROL_SPEED
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")


func _choose_patrol_target() -> void:
	if not patrol_route.is_empty():
		patrol_route_index = clampi(patrol_route_index, 0, patrol_route.size() - 1)
		patrol_target = patrol_route[patrol_route_index]
		patrol_repath_time = 8.0
		return
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


func _raid_host() -> Node:
	# current_scene은 테스트/시뮬 환경에서 메인 씬이 아닐 수 있다.
	# 그룹이 1순위, current_scene은 폴백.
	var host := get_tree().get_first_node_in_group("raid_host")
	return host if host != null else get_tree().current_scene


func _become_alerted() -> void:
	var newly_alerted := not alerted
	alerted = true
	lure_point = null
	lure_arrived = false
	detection_awareness = 1.0
	if newly_alerted and is_targeting_player():
		var scene := _raid_host()
		if scene != null and scene.has_method("notify_player_detected"):
			scene.call("notify_player_detected")
		# 발각 "!" 스팅 — 플레이어를 향한 경계 진입 순간 한 번. 분대 연쇄 경보는
		# SfxBank의 종류별 최소 간격이 겹침을 억제한다.
		SFX.play("alert_sting")
	if is_instance_valid(target):
		last_known_position = target.global_position
	pursuit_time = maxf(
		pursuit_time,
		COMBAT_MEMORY_BASE + COMBAT_MEMORY_THREAT_BONUS * threat_level
	)
	perception_state = "combat"
	suspicion_hold_time = 0.0
	search_time_remaining = 0.0
	visual_contact_confirmed = true
	_update_vision_fan_visual()
	if newly_alerted:
		combat_reaction_time = ALERT_REACTION_SECONDS
		opening_shot_pending = enemy_kind not in ["melee", "grenadier"]
	alert_marker_time = maxf(alert_marker_time, combat_reaction_time + 0.22)
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
	detection_awareness = 1.0
	combat_reaction_time = ALERT_REACTION_SECONDS
	alert_marker_time = combat_reaction_time + 0.22
	perception_state = "combat"
	search_time_remaining = 0.0
	visual_contact_confirmed = true
	opening_shot_pending = false
	opening_pressure_time = 0.0
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
	detection_awareness = 0.0
	combat_reaction_time = 0.0
	perception_state = "return"
	suspicion_hold_time = 0.0
	search_time_remaining = 0.0
	visual_contact_confirmed = false
	has_current_line_of_sight = false
	pursuit_time = 0.0
	opening_shot_pending = false
	opening_pressure_time = 0.0
	lost_sight_time = 0.0
	target_stationary_time = 0.0
	tactical_waypoint = Vector3.INF
	patrol_target = squad_anchor + squad_formation_offset if squad_id >= 0 else patrol_origin
	patrol_repath_time = 5.0
	_update_vision_fan_visual()
	if threat_marker and combat_state not in ["melee_windup", "grenade_windup"]:
		threat_marker.visible = false
	if detection_indicator:
		detection_indicator.visible = false


func _update_alert_marker(delta: float) -> void:
	if alert_marker_time > 0.0:
		alert_marker_time = maxf(0.0, alert_marker_time - delta)
	if threat_marker and combat_state not in ["melee_windup", "grenade_windup"]:
		threat_marker.visible = false


func _setup_detection_indicator() -> void:
	detection_indicator = Sprite3D.new()
	detection_indicator.name = "DetectionIndicator"
	detection_indicator.position = Vector3(0, THREAT_MARKER_Y + 0.18, 0)
	detection_indicator.pixel_size = 0.0115
	detection_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	detection_indicator.shaded = false
	detection_indicator.transparent = true
	detection_indicator.no_depth_test = true
	detection_indicator.render_priority = 126
	detection_indicator.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	detection_indicator.visible = false
	add_child(detection_indicator)


func _update_detection_indicator() -> void:
	if detection_indicator == null:
		return
	var show_alert_confirmation := alerted and alert_marker_time > 0.0
	var show_suspicion := not alerted and detection_awareness > 0.025
	var show_lost_target := (
		alerted
		and perception_state == "search"
		and alert_marker_time <= 0.0
	)
	var show_player_override := (
		target != primary_player_target
		and player_override_awareness > 0.025
	)
	detection_indicator.visible = (
		(
			show_alert_confirmation
			or show_suspicion
			or show_lost_target
			or show_player_override
		)
		and player_visibility_factor > 0.02
		and not dying
	)
	if not detection_indicator.visible:
		return
	if show_lost_target:
		detection_indicator.texture = _get_lost_target_texture()
		var search_pulse := 1.0 + 0.055 * sin(Time.get_ticks_msec() * 0.012)
		detection_indicator.scale = Vector3.ONE * search_pulse
		return
	var progress := (
		1.0
		if show_alert_confirmation
		else maxf(detection_awareness, player_override_awareness)
	)
	detection_indicator.texture = _get_detection_texture(roundi(progress * 20.0))
	var pulse := 1.0
	if show_alert_confirmation:
		pulse += 0.11 * sin(Time.get_ticks_msec() * 0.024)
	detection_indicator.scale = Vector3.ONE * pulse


func _get_lost_target_texture() -> Texture2D:
	if lost_target_texture != null:
		return lost_target_texture
	var image := Image.create(72, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(35.5, 35.5)
	for y in 72:
		for x in 72:
			var radius := (Vector2(x, y) - center).length()
			if radius <= 22.0:
				image.set_pixel(x, y, Color(0.03, 0.025, 0.02, 0.94))
			elif radius >= 26.0 and radius <= 30.0:
				image.set_pixel(x, y, Color(0.95, 0.68, 0.2, 0.92))
	var question_color := Color("#ffe09a")
	image.fill_rect(Rect2i(27, 17, 17, 6), question_color)
	image.fill_rect(Rect2i(40, 21, 7, 14), question_color)
	image.fill_rect(Rect2i(34, 32, 12, 6), question_color)
	image.fill_rect(Rect2i(31, 36, 7, 11), question_color)
	image.fill_rect(Rect2i(31, 52, 7, 7), Color("#ffb545"))
	lost_target_texture = ImageTexture.create_from_image(image)
	return lost_target_texture


func _get_detection_texture(step: int) -> Texture2D:
	step = clampi(step, 0, 20)
	if detection_texture_cache.has(step):
		return detection_texture_cache[step]
	var image := Image.create(72, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(35.5, 35.5)
	var progress := float(step) / 20.0
	var active_color := Color("#ff9a4f").lerp(Color("#ff3434"), progress)
	for y in 72:
		for x in 72:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius <= 19.0:
				image.set_pixel(x, y, Color(0.03, 0.025, 0.022, 0.94))
			elif radius >= 25.0 and radius <= 31.0:
				var angle := fposmod(atan2(offset.y, offset.x) + PI * 0.5, TAU)
				image.set_pixel(
					x,
					y,
					active_color
					if angle <= progress * TAU
					else Color(0.24, 0.22, 0.2, 0.92)
				)
	image.fill_rect(Rect2i(32, 17, 7, 25), Color("#fff1c4"))
	image.fill_rect(Rect2i(33, 48, 6, 6), active_color)
	var texture := ImageTexture.create_from_image(image)
	detection_texture_cache[step] = texture
	return texture


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
	# elite_speed_multiplier: 엘리트만 1.12, 일반은 1.0.
	velocity = direction * base_speed * lerpf(1.0, 1.32, threat_level) * elite_speed_multiplier
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
	velocity = flank_direction * PISTOL_SPEED * lerpf(1.25, 1.65, threat_level) * elite_speed_multiplier
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
		steering_direction_cache = Vector3.ZERO
		return Vector3.ZERO
	var desired := desired_direction.normalized()
	var now_msec := Time.get_ticks_msec()
	if (
		now_msec < steering_lock_until_msec
		and steering_direction_cache.length_squared() > 0.01
		and steering_direction_cache.dot(desired) >= 0.35
		and _is_steering_direction_clear(steering_direction_cache, 2.15)
	):
		return steering_direction_cache
	var angles := [0.0, 24.0, -24.0, 48.0, -48.0, 76.0, -76.0, 112.0, -112.0]
	for angle in angles:
		var candidate := desired.rotated(Vector3.UP, deg_to_rad(angle))
		var probe_distance := 3.1 if is_zero_approx(angle) else 2.35
		if _is_steering_direction_clear(candidate, probe_distance):
			steering_direction_cache = candidate
			steering_lock_until_msec = now_msec + STEERING_LOCK_MSEC
			return candidate
	steering_direction_cache = Vector3.ZERO
	return Vector3.ZERO


func _is_steering_direction_clear(direction: Vector3, probe_distance: float) -> bool:
	if direction.length_squared() <= 0.01:
		return false
	var from := global_position + Vector3(0, 0.32, 0)
	var query := PhysicsRayQueryParameters3D.create(
		from,
		from + direction.normalized() * probe_distance,
		COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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


func _is_shotgun() -> bool:
	# 산탄 계열(더블배럴·펌프) 공용 판정 — 펠릿 수·총구 거리에 쓴다.
	return str(weapon_stats.get("category", "")) == "산탄총"


func _get_weapon_muzzle_position(direction: Vector3) -> Vector3:
	var reach := 0.78
	if weapon_id == "m1911":
		reach = 0.58
	elif _is_shotgun():
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
	var next_facing: String = SCREEN_DIRECTION_NAMES[index]
	if next_facing == facing:
		pending_facing = ""
	elif next_facing != pending_facing:
		pending_facing = next_facing
		pending_facing_since_msec = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - pending_facing_since_msec >= FACING_STABILITY_MSEC:
		_set_facing(next_facing)
		pending_facing = ""
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
	# 동시 근접 상한 — 자리가 없으면 반 박자 물러나 포위를 잇는다.
	var scene := _raid_host()
	if (
		scene != null
		and scene.has_method("request_enemy_melee_token")
		and not bool(scene.call("request_enemy_melee_token", self))
	):
		attack_cooldown = 0.45
		return
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
	var movement_speed := PISTOL_SPEED * lerpf(1.12, 1.48, threat_level) * elite_speed_multiplier
	var preferred_min := 8.0
	var preferred_max := 17.0
	var attack_range := _get_weapon_engagement_range()
	match weapon_id:
		"mp5":
			preferred_min = 10.0
			preferred_max = 22.0
		"ak47", "akm", "k2":
			preferred_min = 15.0
			preferred_max = 30.0
		"double_barrel", "pump_shotgun":
			preferred_min = 4.0
			preferred_max = 9.0
	if opening_pressure_time > 0.0 and distance > 3.0:
		velocity = (
			_steer_around_obstacles(direction)
			* maxf(movement_speed, OPENING_PRESSURE_SPEED * lerpf(1.0, 1.12, threat_level))
		)
	elif _update_stationary_target_flank(direction, distance):
		return
	else:
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
		_start_pistol_burst(direction)


func _start_pistol_burst(direction: Vector3) -> void:
	if magazine_ammo <= 0:
		_start_reload()
		return
	# 동시 사격 상한 — 사격 자리가 없으면 잠깐 물러나 포위를 잇는다.
	var scene := _raid_host()
	if (
		scene != null
		and scene.has_method("request_enemy_fire_token")
		and not bool(scene.call("request_enemy_fire_token", self))
	):
		attack_cooldown = 0.55
		return
	combat_state = "ranged_windup"
	# 예비동작은 위협도에 반비례한다. 초반 존(0.15)은 0.4초 남짓으로 사람이
	# 반응할 수 있게, 심층 존은 0.18초로 날카롭게. 예전 고정 0.18초 + 인지 0.12초
	# = 0.3초는 게임에서 가장 치명적인 공격이 가장 안 읽히는 상태였다.
	state_timer = lerpf(0.44, RANGED_WINDUP_TIME, clampf(threat_level, 0.0, 1.0))
	pending_attack_direction = direction
	velocity = Vector3.ZERO
	_set_motion_state("attack")
	threat_marker.text = "◆"
	threat_marker.modulate = _with_player_visibility(Color("#ffd36a"))
	threat_marker.visible = true


func _update_grenadier(direction: Vector3, distance: float, delta: float) -> void:
	var movement_speed := PISTOL_SPEED * lerpf(1.0, 1.25, threat_level) * elite_speed_multiplier
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
		"ak47", "akm", "k2":
			return 48.0
		"double_barrel", "pump_shotgun":
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
	elif combat_state == "ranged_windup":
		velocity = Vector3.ZERO
		_set_facing_from_world_direction(pending_attack_direction)
		_update_threat_marker()
		if state_timer <= 0.0:
			threat_marker.visible = false
			burst_shots_remaining = mini(
				magazine_ammo - 1,
				maxi(0, _get_weapon_burst_size() - 1)
			)
			combat_state = "pistol_burst"
			state_timer = _get_enemy_fire_interval()
			_fire_weapon(pending_attack_direction)
			_start_recoil_pose()
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
	# 엘리트 배율(일반 1.0)을 근접 타격에도 동일하게 적용한다.
	var strike_damage := roundi(float(12 + roundi(6.0 * threat_level)) * elite_damage_multiplier)
	if target.has_method("take_hostile_hit"):
		target.call("take_hostile_hit", strike_damage, pending_attack_direction, self)
	elif target.has_method("take_damage"):
		target.call("take_damage", strike_damage)
	elif target.get_parent() != null and target.get_parent().has_method("take_hostile_hit"):
		target.get_parent().call(
			"take_hostile_hit",
			strike_damage,
			pending_attack_direction,
			self
		)
	elif target.get_parent() != null and target.get_parent().has_method("take_damage"):
		target.get_parent().call("take_damage", strike_damage)


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
	return _has_line_of_sight_to(target)


func _has_line_of_sight_to(body: CharacterBody3D) -> bool:
	if not is_instance_valid(body):
		return false
	# Check only for world obstruction. Requiring the ray to return the target
	# body itself is unreliable when the endpoint lies inside its collider.
	var collision_mask := COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	var excluded_rids: Array[RID] = [get_rid(), body.get_rid()]
	var sight_heights := [0.42, 0.92]
	for sight_height in sight_heights:
		var from := global_position + Vector3(0, sight_height, 0)
		var to := body.global_position + Vector3(0, sight_height, 0)
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		query.exclude = excluded_rids
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _target_is_in_safe_zone() -> bool:
	if not is_instance_valid(target) or target.get_parent() == null:
		return false
	var world := target.get_parent().get_node_or_null("World")
	return world != null and world.has_method("is_position_in_safe_zone") and world.call("is_position_in_safe_zone", target.global_position)


func _get_weapon_burst_size() -> int:
	# 자동화기도 점사로 끊는다. 탄창 전체(12~14발)를 한 번에 쏟으면 AK 하나가
	# 무중단 1.4초 동안 최대 144 피해를 밀어넣어 — 100 체력 상한을 넘는 —
	# 초반 최대의 억울한 죽음 원인이었다. 위협도가 높을수록 점사가 길어진다.
	match weapon_id:
		"mp5": return mini(magazine_size, 4 + roundi(4.0 * threat_level))
		"ak47", "akm", "k2": return mini(magazine_size, 3 + roundi(4.0 * threat_level))
		"m1911": return mini(magazine_size, 3 + roundi(3.0 * threat_level))
		"double_barrel", "pump_shotgun": return 1
	return 1


func _get_enemy_fire_interval() -> float:
	var base_interval := float(weapon_stats.get("fire_interval", 0.22))
	return maxf(0.065, base_interval * lerpf(1.12, 0.88, threat_level))


func _get_weapon_burst_cooldown() -> float:
	match weapon_id:
		"mp5": return lerpf(0.72, 0.34, threat_level)
		"ak47", "akm", "k2": return lerpf(0.88, 0.4, threat_level)
		"double_barrel", "pump_shotgun": return lerpf(2.3, 1.25, threat_level)
	return lerpf(1.05, 0.58, threat_level)


func _get_enemy_bullet_damage() -> int:
	var base_damage := 12 + roundi(4.0 * threat_level)
	match weapon_id:
		"mp5": base_damage = 6 + roundi(3.0 * threat_level)
		"ak47": base_damage = 9 + roundi(4.0 * threat_level)
		# 상위 소총을 든 적은 한 발이 조금 더 아프다(+1) — 총의 정체성은 지키되
		# 존 체력 곡선(러버밴딩 없음)은 그대로다. 적 무장은 존 threat이 정한다.
		"akm", "k2": base_damage = 10 + roundi(4.0 * threat_level)
		"double_barrel", "pump_shotgun": base_damage = 5 + roundi(2.0 * threat_level)
	# 엘리트 배율(일반 1.0) — 존 티어 스탯 위에 곱한다.
	return roundi(float(base_damage) * elite_damage_multiplier)


func get_combat_identity() -> Dictionary:
	var weapon_name := "근접 무기"
	if weapon_id != "baseball_bat":
		weapon_name = str(weapon_stats.get("display_name", weapon_id))
	return {
		# 엘리트에게 죽었다면 사망 화면에도 그 이름이 찍힌다.
		"source_name": str(get_meta("display_name", "적대 생존자")) if elite else "적대 생존자",
		"weapon_name": weapon_name,
	}


func _fire_weapon(direction: Vector3) -> void:
	if magazine_ammo <= 0:
		_start_reload()
		return
	# 방향이 0인 사격은 버린다. 표적과 같은 좌표에 서는 프레임(보스 사망 연출 등)에
	# 0벡터가 내려오면 총알 look_at이 오류를 뿜으며 프레임을 세운다.
	if direction.length_squared() < 0.0001:
		return
	magazine_ammo -= 1
	_play_enemy_gunshot()
	var pellet_count := 6 if _is_shotgun() else 1
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
		var range_profile := _get_weapon_range_profile()
		projectile.set("effective_range", range_profile.x)
		projectile.set("maximum_range", range_profile.y)
		projectile.set("minimum_damage_multiplier", range_profile.z)
		projectile.position = _get_weapon_muzzle_position(direction)
		get_parent().add_child(projectile)
	_spawn_enemy_muzzle_flash(direction)
	_play_attack_feedback()


func _get_weapon_range_profile() -> Vector3:
	match weapon_id:
		"double_barrel", "pump_shotgun": return Vector3(6.5, 15.0, 0.16)
		"mp5": return Vector3(13.0, 29.0, 0.32)
		"m1911": return Vector3(17.0, 34.0, 0.42)
		"ak47", "akm", "k2": return Vector3(25.0, 46.0, 0.58)
	return Vector3(16.0, 34.0, 0.35)


func _play_enemy_gunshot() -> void:
	# 적 총성 — 공용 SfxBank에서 무기 구경별 소리를 3D 위치로 재생한다(멀면 작게).
	# 플레이어 자신의 총성보다 한 단계 낮춰 누가 쏘는지 귀로 구분되게 한다.
	SFX.play_weapon_shot(weapon_id, global_position, -4.0)


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
		var weapon_recoil := 0.13 if weapon_id in ["ak47", "akm", "k2"] else 0.08
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
	# Color.WHITE 강제 복귀는 기본 틴트와 가시성 알파(스텔스 페이드)를 지웠다.
	_apply_sprite_base_modulate()
	_update_weapon_visual()
	_apply_weapon_base_modulate()


func _kill_visual_tween() -> void:
	if visual_tween != null:
		visual_tween.kill()


func _play_attack_feedback() -> void:
	if sprite == null:
		return
	# Color.WHITE 복귀는 기본 틴트·가시성 알파를 지웠다 — 기본색으로 되돌린 뒤
	# 콜백으로 최신 값을 한 번 더 스냅한다(피격 플래시와 같은 원칙).
	var sprite_base := sprite_base_tint
	sprite_base.a = player_visibility_factor
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.45, 0.82, 0.58, player_visibility_factor), 0.045)
	tween.tween_property(sprite, "modulate", sprite_base, 0.11)
	tween.tween_callback(_apply_sprite_base_modulate)
	if weapon_visual:
		var weapon_base := Color(1.0, 1.0, 1.0, player_visibility_factor)
		var weapon_flash := create_tween()
		weapon_flash.tween_property(weapon_visual, "modulate", Color(1.8, 1.35, 0.5, player_visibility_factor), 0.035)
		weapon_flash.tween_property(weapon_visual, "modulate", weapon_base, 0.09)
		weapon_flash.tween_callback(_apply_weapon_base_modulate)


func take_damage(amount: int) -> void:
	take_hit(amount, Vector3.ZERO)


func take_hostile_hit(amount: int, hit_direction: Vector3, attacker = null) -> void:
	var applied_damage := amount
	if (
		is_instance_valid(attacker)
		and attacker != self
		and attacker.has_method("get_faction_id")
		and not faction_id.is_empty()
		and str(attacker.call("get_faction_id")) != faction_id
	):
		applied_damage = maxi(
			1,
			roundi(float(amount) * FACTION_COMBAT_DAMAGE_MULTIPLIER)
		)
	take_hit(applied_damage, hit_direction)


func is_backstab_from(attacker_position: Vector3) -> bool:
	var direction_to_attacker := attacker_position - global_position
	direction_to_attacker.y = 0.0
	if direction_to_attacker.length_squared() <= 0.01:
		return false
	return facing_world_direction.dot(direction_to_attacker.normalized()) <= -0.42


func can_receive_stealth_takedown(
	attacker_position: Vector3,
	max_distance: float
) -> bool:
	if dying or backstab_stunned or alerted or reinforcement_call_active:
		return false
	var offset := attacker_position - global_position
	offset.y = 0.0
	return (
		offset.length_squared() <= max_distance * max_distance
		and detection_awareness < 1.0
		and perception_state != "combat"
	)


func receive_stealth_takedown(
	attacker_position: Vector3,
	hit_direction: Vector3
) -> bool:
	if not can_receive_stealth_takedown(
		attacker_position,
		STEALTH_TAKEDOWN_MAX_RANGE
	):
		return false
	take_melee_hit(maxi(health, 1), hit_direction, true)
	return true


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
	_spawn_damage_number(fatal_damage, true, hit_direction, "normal", true)
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
	_spawn_stealth_takedown_flash(hit_direction)
	_spawn_hit_burst(hit_direction, Color("#fff0a3"), 16, 0.34)
	_play_hit_reaction(hit_direction)
	SFX.play("hit_enemy", global_position)
	get_tree().create_timer(0.24).timeout.connect(func() -> void:
		if is_instance_valid(self) and not dying:
			backstab_stunned = false
			_start_death(hit_direction)
	)


func _spawn_stealth_takedown_flash(hit_direction: Vector3) -> void:
	if get_parent() == null:
		return
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.93, 0.68, 0.96)
	flash_material.emission_enabled = true
	flash_material.emission = Color("#fff2ad")
	flash_material.emission_energy_multiplier = 9.0
	flash_material.no_depth_test = true

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.34
	flash_mesh.height = 0.68
	flash_mesh.radial_segments = 18
	flash_mesh.rings = 9
	flash_mesh.material = flash_material
	var flash := MeshInstance3D.new()
	flash.name = "StealthImpactFlash"
	flash.mesh = flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3(0.0, 0.72, 0.0) + hit_direction * 0.08

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.48
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	ring_mesh.material = flash_material
	var ring := MeshInstance3D.new()
	ring.name = "StealthImpactRing"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.18, 0.0)

	var light := OmniLight3D.new()
	light.name = "StealthImpactLight"
	light.light_color = Color("#ffe29a")
	light.light_energy = 6.5
	light.omni_range = 4.2
	light.shadow_enabled = false
	get_parent().add_child(light)
	light.global_position = global_position + Vector3(0.0, 0.85, 0.0)

	var flash_tween := flash.create_tween().set_parallel(true)
	flash_tween.set_ignore_time_scale(true)
	flash_tween.tween_property(flash, "scale", Vector3.ONE * 3.2, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "transparency", 1.0, 0.25)
	var ring_tween := ring.create_tween().set_parallel(true)
	ring_tween.set_ignore_time_scale(true)
	ring_tween.tween_property(ring, "scale", Vector3.ONE * 4.6, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "transparency", 1.0, 0.3)
	var light_tween := light.create_tween()
	light_tween.set_ignore_time_scale(true)
	light_tween.tween_property(light, "light_energy", 0.0, 0.24)
	get_tree().create_timer(0.34, true, false, true).timeout.connect(flash.queue_free)
	get_tree().create_timer(0.34, true, false, true).timeout.connect(ring.queue_free)
	get_tree().create_timer(0.28, true, false, true).timeout.connect(light.queue_free)


func take_projectile_hit(
	amount: int,
	hit_direction: Vector3,
	is_critical: bool = false,
	critical_multiplier: float = 1.65,
	hit_zone: String = "body",
	attacker = null
) -> void:
	_alert_to_projectile_attacker(attacker)
	# hit_zone은 탄도의 명중 등급("center"/"normal"/"graze")이다. 예전 "head" 비교는
	# 어떤 경로로도 올 수 없는 값이라 죽은 분기였다.
	var final_damage := roundi(float(amount) * critical_multiplier) if is_critical else amount
	take_hit(final_damage, hit_direction, is_critical, hit_zone)


func _alert_to_projectile_attacker(attacker = null) -> void:
	if dying or backstab_stunned:
		return
	var retaliation_target: CharacterBody3D = null
	if is_instance_valid(attacker) and attacker is CharacterBody3D:
		retaliation_target = attacker as CharacterBody3D
	if not is_instance_valid(retaliation_target):
		retaliation_target = primary_player_target
	if not is_instance_valid(retaliation_target) or retaliation_target == self:
		return
	target = retaliation_target
	last_known_position = retaliation_target.global_position
	detection_awareness = 1.0
	player_override_awareness = 0.0
	_become_alerted()
	combat_reaction_time = minf(combat_reaction_time, 0.08)
	attack_cooldown = 0.0
	alert_marker_time = maxf(alert_marker_time, 0.38)


func take_hit(amount: int, hit_direction: Vector3, is_critical: bool = false, hit_grade: String = "normal") -> void:
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
	# 처치 마지막 타격(lethal)은 killing_blow로 따로 넘긴다 — 치명타 색을
	# 빌리는 대신 "살짝 크게"로 구분해 표시한다.
	_spawn_damage_number(amount, is_critical, hit_direction, hit_grade, lethal)
	threat_marker.visible = false
	var knockback_direction := hit_direction
	knockback_direction.y = 0.0
	if knockback_direction.length_squared() <= 0.01:
		knockback_direction = -pending_attack_direction
	knockback_direction = knockback_direction.normalized()
	# 미세 넉백 — 스태거 상태의 _update_stagger가 velocity로 적용한다.
	# 보스는 아래 _absorbs_hit_stagger에서 경직·넉백을 함께 흡수한다.
	stagger_velocity = knockback_direction * HIT_KNOCKBACK_SPEED
	_spawn_hit_burst(knockback_direction, Color("#ffcf91"), 10, 0.3)
	_play_hit_reaction(knockback_direction)
	# 명중음 — 피격 플래시와 같은 프레임에, 적 위치 기준 3D 감쇠로.
	SFX.play("hit_enemy", global_position)
	if health <= 0:
		_start_death(knockback_direction)
		return
	if _absorbs_hit_stagger(amount):
		return
	combat_state = "stagger"
	state_timer = HIT_STAGGER_TIME
	_set_motion_state("hit")


func _absorbs_hit_stagger(_amount: int) -> bool:
	# 강인도 개체(보스)가 재정의한다. true를 돌려주면 이번 피격의 경직을 생략 —
	# 연사 무기로 피격 경직을 무한 갱신해 패턴을 봉인하는 스턴락을 막는 장치.
	return false


func _spawn_damage_number(
	amount: int,
	is_critical: bool,
	hit_direction: Vector3,
	hit_grade: String = "normal",
	killing_blow: bool = false
) -> void:
	# 기본 켜짐 — 접근성 설정(F10 → 피해량 숫자 표시)에서 끌 수 있다.
	# 오토로드 식별자를 직접 쓰면 --script 콜드 스타트에서 enemy.gd 컴파일이
	# 깨진다(raid_loss_manager의 GameState와 같은 문제) — 노드 경로로 찾는다.
	var accessibility := get_node_or_null("/root/AccessibilitySettings")
	if accessibility != null and not bool(accessibility.get("damage_numbers_enabled")):
		return
	if get_parent() == null:
		return
	# 풀 재사용 — 연사로 초당 수십 개가 떠도 노드 생성/해제 비용이 안 쌓인다.
	var number: Label3D = DAMAGE_NUMBER_SCRIPT.acquire(get_parent())
	if number == null:
		number = DAMAGE_NUMBER_SCRIPT.new() as Label3D
		get_parent().add_child(number)
	number.call(
		"setup",
		amount,
		is_critical,
		DAMAGE_FONT,
		global_position + Vector3(0, 1.62, 0),
		hit_direction,
		weapon_random.randf_range(-0.28, 0.28),
		hit_grade,
		elite,
		killing_blow
	)


func _play_hit_reaction(hit_direction: Vector3) -> void:
	if sprite == null:
		return
	_kill_visual_tween()
	# ── 피격 화이트 플래시 ──
	# 과노출 modulate로 하얗게 번쩍인 뒤 "기본 틴트 + 현재 가시성 알파"로
	# 정확히 복귀한다. 복귀 색을 트윈 시작 시점에 굳혀 두면 스텔스 페이드와
	# 어긋나므로, tween_method가 매 프레임 기본색을 다시 읽어 섞는다.
	# 예전 구현은 Color.WHITE로 복귀해 가시성 알파를 지우는 문제가 있었다.
	if hit_flash_tween != null:
		hit_flash_tween.kill()
	# 오토로드 식별자 대신 노드 경로 — --script 콜드 스타트 컴파일 안전.
	var accessibility := get_node_or_null("/root/AccessibilitySettings")
	var flash_scale := 1.0
	if accessibility != null:
		flash_scale = clampf(float(accessibility.get("hit_flash_scale")), 0.0, 1.0)
	if flash_scale > 0.01:
		# 곱연산 modulate라 순백은 못 만들지만 4~6배 과노출이면 실화면에서
		# 충분히 '하얀 번쩍'으로 읽힌다(스크린샷 프로브로 확인).
		var flash_gain := 1.0 + 5.2 * flash_scale
		_apply_hit_flash(1.0, flash_gain)
		hit_flash_tween = create_tween()
		hit_flash_tween.tween_method(_apply_hit_flash.bind(flash_gain), 1.0, 1.0, 0.06)
		hit_flash_tween.tween_method(_apply_hit_flash.bind(flash_gain), 1.0, 0.0, 0.08)
		hit_flash_tween.tween_callback(_apply_sprite_base_modulate)
		# 보조 스프라이트 플래시 — gl_compatibility에서 modulate 과노출이
		# 클램프되어도 이쪽은 확실히 하얗게 번쩍인다. 연사 대비 kill 후 재시작.
		if hit_flash_overlay != null:
			if hit_flash_overlay_tween != null:
				hit_flash_overlay_tween.kill()
			# 투명 정렬 함정: 본체 스프라이트와 거의 같은 깊이에 두면
			# render_priority만으로는 위에 안 그려진다(실화면 검증). 직교
			# 카메라라 화면 위치는 그대로인 채, 카메라 쪽으로 당겨 깊이
			# 정렬에서 확실히 앞에 세운다.
			var view_camera := get_viewport().get_camera_3d()
			var overlay_anchor := global_position + SPRITE_BASE_POSITION + Vector3(0, 0.06, 0)
			if view_camera != null:
				var toward_camera := view_camera.global_position - overlay_anchor
				if toward_camera.length_squared() > 0.01:
					hit_flash_overlay.global_position = (
						overlay_anchor + toward_camera.normalized() * 1.5
					)
			# 스텔스로 흐려진 적이라도 명중 확인은 보여야 한다(맞춘 위치가
			# 읽히는 게 피드백의 목적) — 가시성 배율은 0.6 밑으로 안 내린다.
			hit_flash_overlay.modulate = Color(
				1.0, 1.0, 1.0,
				0.88 * flash_scale * maxf(player_visibility_factor, 0.6)
			)
			hit_flash_overlay_tween = create_tween()
			hit_flash_overlay_tween.tween_interval(0.05)
			hit_flash_overlay_tween.tween_property(
				hit_flash_overlay, "modulate:a", 0.0, 0.09
			)
	if hit_shake_tween != null:
		hit_shake_tween.kill()
	hit_shake_tween = create_tween()
	hit_shake_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION + hit_direction * 0.11, 0.035)
	hit_shake_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION - hit_direction * 0.055, 0.035)
	hit_shake_tween.tween_property(sprite, "position", SPRITE_BASE_POSITION, 0.07)
	if weapon_visual:
		if weapon_flash_tween != null:
			weapon_flash_tween.kill()
		weapon_flash_tween = create_tween()
		weapon_flash_tween.tween_property(
			weapon_visual,
			"modulate",
			Color(2.2, 2.2, 2.2, player_visibility_factor),
			0.05
		)
		weapon_flash_tween.tween_callback(_apply_weapon_base_modulate)


func _setup_hit_flash_overlay() -> void:
	hit_flash_overlay = Sprite3D.new()
	hit_flash_overlay.name = "HitFlashOverlay"
	hit_flash_overlay.texture = _get_hit_flash_texture()
	hit_flash_overlay.position = SPRITE_BASE_POSITION + Vector3(0, 0.06, 0)
	hit_flash_overlay.pixel_size = 0.0125
	hit_flash_overlay.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hit_flash_overlay.shaded = false
	hit_flash_overlay.transparent = true
	hit_flash_overlay.no_depth_test = true
	# 적 스프라이트(30) 바로 위, 체력바(112~)와 표식 아래.
	hit_flash_overlay.render_priority = 32
	hit_flash_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(hit_flash_overlay)


static func _get_hit_flash_texture() -> Texture2D:
	# 흰 라디얼 글로 한 장 — 전 개체가 공유한다(reinforcement 링과 같은 방식).
	if hit_flash_overlay_texture != null:
		return hit_flash_overlay_texture
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(47.5, 47.5)
	for y in 96:
		for x in 96:
			var radius := (Vector2(x, y) - center).length()
			var falloff := clampf(1.0 - radius / 46.0, 0.0, 1.0)
			if falloff <= 0.0:
				continue
			# 중심은 진한 흰색, 가장자리로 부드럽게 소멸.
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(falloff, 1.4)))
	hit_flash_overlay_texture = ImageTexture.create_from_image(image)
	return hit_flash_overlay_texture


func _apply_hit_flash(weight: float, flash_gain: float) -> void:
	if sprite == null or dying:
		return
	var base := sprite_base_tint
	base.a = player_visibility_factor
	var flash := Color(flash_gain, flash_gain, flash_gain, player_visibility_factor)
	sprite.modulate = base.lerp(flash, clampf(weight, 0.0, 1.0))


func _apply_sprite_base_modulate() -> void:
	# 기본 틴트 + 현재 가시성 알파 — 플래시·자세 리셋의 공통 복귀 지점.
	if sprite == null or dying:
		return
	var base := sprite_base_tint
	base.a = player_visibility_factor
	sprite.modulate = base


func _apply_weapon_base_modulate() -> void:
	if weapon_visual == null or dying:
		return
	var base := Color.WHITE
	base.a = player_visibility_factor
	weapon_visual.modulate = base


func _start_death(hit_direction: Vector3) -> void:
	dying = true
	_cancel_reinforcement_call()
	if reload_indicator:
		reload_indicator.visible = false
	if detection_indicator:
		detection_indicator.visible = false
	backstab_stunned = false
	combat_state = "dying"
	threat_marker.visible = false
	# 엘리트 표식은 위협 안내다 — 시체 위에 떠 있으면 안 된다.
	if elite_icon:
		elite_icon.visible = false
	if elite_name_label:
		elite_name_label.visible = false
	_update_vision_fan_visual()
	_update_health_bar_visibility()
	collision_layer = 0
	collision_mask = 0
	velocity = hit_direction * 2.5
	_set_motion_state("death")
	_spawn_hit_burst(hit_direction, Color("#8b1717"), 18, 0.55)
	# 처치 임팩트(히트스톱 + 확인음) — 필드·건물 내부 공용(static 헬퍼).
	# 보스는 전용 처치 연출(_play_boss_defeat_sequence)이 있어 제외한다.
	if not bool(get_meta("raid_boss", false)):
		KILL_IMPACT.play_kill_impact(elite)
	died.emit(self)
	_kill_visual_tween()
	# 피격 플래시/셰이크 트윈이 살아 있으면 사망 페이드의 modulate와 싸운다.
	if hit_flash_tween != null:
		hit_flash_tween.kill()
	if hit_shake_tween != null:
		hit_shake_tween.kill()
	if weapon_flash_tween != null:
		weapon_flash_tween.kill()
	# 마지막 타격의 흰 플래시는 처치 순간을 강조하도록 남겨 두되,
	# 시체 위에 계속 떠 있지 않게 빠르게 꺼 준다.
	if hit_flash_overlay != null:
		if hit_flash_overlay_tween != null:
			hit_flash_overlay_tween.kill()
		hit_flash_overlay_tween = create_tween()
		hit_flash_overlay_tween.tween_property(hit_flash_overlay, "modulate:a", 0.0, 0.16)
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
