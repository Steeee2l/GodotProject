extends "res://scripts/enemy.gd"

const ROCKET_PROJECTILE := preload("res://scripts/rocket_projectile.gd")
const BOSS_MINE := preload("res://scripts/boss_mine.gd")
const BOSS_ANIMATION_ROOT := "res://assets/enemies/rocket_boss"
const BOSS_SCREEN_DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const BOSS_DIRECTIONS := {
	"n": "up", "ne": "up_right", "e": "right", "se": "down_right",
	"s": "down", "sw": "down_left", "w": "left", "nw": "up_left",
}
const BOSS_SPRITE_POSITION := Vector3(0.0, 0.68, 0.0)
const ROCKET_MAGAZINE_SIZE := 4
const ROCKET_RELOAD_DURATION := 3.25
const ROCKET_DAMAGE := 36
const ROCKET_BLAST_RADIUS := 2.65
const ROCKET_AIM_TIME := 0.58
const ROCKET_SHOT_RECOVERY := 0.72
const BOSS_DASH_DURATION := 0.46
const BOSS_DASH_APPROACH_DISTANCE := 6.4
const BOSS_DASH_RETREAT_DISTANCE := 7.4
const MINE_PATTERN_APPROACH_RANGE := 4.2
const MINE_PATTERN_RETREAT_DISTANCE := 10.2
const MINE_PATTERN_APPROACH_DURATION := 0.42
const MINE_PATTERN_RETREAT_DURATION := 0.5
const MINE_DEPLOY_INTERVAL := 0.14
const MINE_DAMAGE := 38
const MINE_BLAST_RADIUS := 3.1
# 강인도: 매 피격 경직 대신, 최대 체력 대비 누적 피해가 문턱을 넘을 때만
# 길게 그로기(보상 창). 총만 있으면 스턴락으로 무력화되던 문제의 해법.
const POISE_BREAK_RATIO := 0.16
const POISE_GROGGY_TIME := 1.15
const ENRAGE_HEALTH_RATIO := 0.4

var boss_action := "combat"
var boss_action_elapsed := 0.0
var boss_action_duration := 0.0
var boss_dash_cooldown := 0.0
var boss_dash_start := Vector3.ZERO
var boss_dash_end := Vector3.ZERO
var boss_rng := RandomNumberGenerator.new()
var rocket_shots_fired := 0
var mine_pattern_cooldown := 0.0
var mine_deploy_count := 0
var mines_deployed_this_pattern := 0
var mines_deployed_total := 0
var mine_target_snapshot := Vector3.ZERO
var poise_damage_accumulated := 0.0
var enrage_triggered := false
# 보스 체력바 피드백 — 피격 순간 채움이 흰색으로 번쩍이고, 포이즈 게이지가 아래 얇게 쌓인다.
var hit_flash_timer := 0.0
var poise_bar_background: Sprite3D
var poise_bar_fill: Sprite3D


func configure_rocket_boss(target_body: CharacterBody3D, initial_threat: float) -> void:
	super.configure("pistol", target_body, {}, maxf(0.65, initial_threat), "ak47")
	enemy_kind = "rocket_boss"
	weapon_id = "rocket_launcher"
	# 보스 표식 — 헤드샷 배율(×1.35)·포이즈 가중(×1.5) 분기가 읽는다(디렉터도 같은 메타를 단다).
	set_meta("raid_boss", true)
	magazine_size = ROCKET_MAGAZINE_SIZE
	magazine_ammo = ROCKET_MAGAZINE_SIZE
	reload_duration = ROCKET_RELOAD_DURATION
	# 체력은 존 티어를 따라 오른다 — 플레이어 장비에 반응하는 게 아니라,
	# 더 깊은 도시의 보스가 더 단단할 뿐이다(러버밴딩 금지 원칙).
	# GameState는 식별자 대신 런타임 조회 — preload 기반 테스트에서
	# 오토로드 등록 전 컴파일 캐스케이드가 나는 함정 회피.
	var zone_tier := 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var game_state := tree.root.get_node_or_null("GameState")
		if game_state != null:
			var zone := game_state.call(
				"get_raid_zone", str(game_state.get("selected_raid_zone"))
			) as Dictionary
			zone_tier = clampi(int(zone.get("stage_tier", 1)), 1, 5)
	var tier_multiplier := 1.0 + float(zone_tier - 1) * 0.30
	# 기준: 유저 신고 "아무리 때려도 안 줄어든다". 예전 (2400+위협×1400)×(1+0.45×(티어-1))은
	# 종로 2,610 / 남산 ~7,900 — AK+0 30dmg·실명중 50%면 첫 보스에만 3탄창 넘게 들었다.
	# 지금은 종로 ~1,235(AK+0 약 41발·1.4탄창), 남산 ~4,400. 포이즈(16%)·격노(40%)는 그대로라
	# "줄어든다"는 체감만 바뀌고 패턴 리듬은 유지된다. 808이었을 땐 4초 만에 끝나 패턴이 놀았다.
	var boss_health := roundi(
		(1100.0 + clampf(initial_threat, 0.0, 1.0) * 900.0) * tier_multiplier
	)
	health = boss_health
	max_health = boss_health
	health_ratio = 1.0
	damage_trail_ratio = 1.0
	threat_level = 1.0
	alerted = false
	visual_contact_confirmed = false


func _ready() -> void:
	super._ready()
	boss_rng.seed = get_instance_id() * 104729
	mine_pattern_cooldown = boss_rng.randf_range(2.8, 4.2)
	add_to_group("raid_boss")
	add_to_group("rocket_boss")
	sprite.sprite_frames = _create_boss_sprite_frames()
	sprite.position = BOSS_SPRITE_POSITION
	sprite.pixel_size = 0.0108
	sprite.render_priority = 36
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var shape := collision.shape as CapsuleShape3D
		shape.radius = 0.52
		shape.height = 1.72
	if shadow != null:
		shadow.scale = Vector3(1.45, 1.0, 1.45)
	for health_node in [health_bar_background, health_bar_damage_trail, health_bar_fill]:
		if health_node != null:
			health_node.position.y = 2.78
			# 보스 바는 일반 적보다 1.5배 크게 — 멀리서도 "줄어드는 것"이 보여야 한다.
			health_node.pixel_size = 0.0108
	if health_bar_damage_trail != null:
		# 감소분 잔상은 흰색, 0.4초 머문 뒤 따라 줄어든다(일반 적은 주황·0.28초).
		health_bar_damage_trail.texture = _get_health_bar_texture("trail_white")
	damage_trail_delay_seconds = 0.4
	_setup_poise_bar()
	if reload_indicator != null:
		reload_indicator.position.y = 3.12
	if threat_marker != null:
		threat_marker.position.y = 3.2
		threat_marker.font_size = 88
	_play_animation()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	boss_dash_cooldown = maxf(0.0, boss_dash_cooldown - delta)
	mine_pattern_cooldown = maxf(0.0, mine_pattern_cooldown - delta)
	_update_alert_marker(delta)
	_update_enemy_health_bar(delta)
	_update_boss_bars(delta)
	if dying:
		velocity = velocity.move_toward(Vector3.ZERO, 7.0 * delta)
		move_and_slide()
		return
	if backstab_stunned:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if combat_state == "stagger":
		_update_stagger(delta)
		return
	if not is_instance_valid(target):
		velocity = Vector3.ZERO
		_set_motion_state("idle")
		return
	if _target_is_in_safe_zone():
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else facing_world_direction
	var target_concealed_by_loaf := _is_target_concealed_by_loaf(distance)
	var has_line_of_sight := _has_line_of_sight()
	var boss_vision_range := _get_vision_range() + 4.0
	if alerted and distance > 72.0:
		_clear_alert()
		_update_patrol(delta)
		move_and_slide()
		return
	if not alerted:
		var detected := (
			_is_position_inside_vision_fan(target.global_position, boss_vision_range)
			and has_line_of_sight
			and not target_concealed_by_loaf
		)
		if detected:
			_become_alerted()
			pursuit_time = 60.0
		else:
			_update_patrol(delta)
			move_and_slide()
			return
	elif target_concealed_by_loaf:
		lost_sight_time += delta
		if lost_sight_time >= LOAF_ESCAPE_CONFIRM_SECONDS:
			_clear_alert()
		else:
			velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
			_set_motion_state("idle")
		move_and_slide()
		return
	else:
		lost_sight_time = 0.0
		last_known_position = target.global_position
		pursuit_time = 60.0

	_set_facing_from_world_direction(direction)
	match boss_action:
		"dash", "mine_approach", "mine_retreat":
			_update_boss_dash(delta)
			return
		"mine_deploy":
			_update_mine_deploy(delta, direction)
			return
		"aim":
			_update_rocket_aim(delta, direction)
			return
		"recovery":
			boss_action_elapsed += delta
			velocity = Vector3.ZERO
			_set_motion_state("idle")
			if boss_action_elapsed >= boss_action_duration:
				boss_action = "combat"
			return
		"reload":
			_update_boss_reload(delta, direction)
			return

	if (
		mine_pattern_cooldown <= 0.0
		and has_line_of_sight
		and distance >= 6.5
		and distance <= 22.0
	):
		_start_mine_pattern(direction, distance)
		return
	if magazine_ammo <= 0:
		_start_boss_reload()
		return
	if boss_dash_cooldown <= 0.0 and (distance < 6.4 or distance > 18.0):
		var dash_direction := -direction if distance < 6.4 else direction
		var dash_distance := BOSS_DASH_RETREAT_DISTANCE if distance < 6.4 else BOSS_DASH_APPROACH_DISTANCE
		_start_boss_dash(dash_direction, dash_distance)
		return
	if has_line_of_sight and distance <= 25.0 and attack_cooldown <= 0.0:
		_start_rocket_aim()
		return

	var movement_direction := direction
	if distance < 10.0:
		movement_direction = -direction
	elif distance <= 18.0:
		var side := Vector3(-direction.z, 0.0, direction.x)
		movement_direction = (side * (1.0 if boss_rng.randf() > 0.5 else -1.0) + direction * 0.12).normalized()
	velocity = _steer_around_obstacles(movement_direction) * (2.8 if _boss_enraged() else 2.35)
	_set_motion_state("walk" if velocity.length_squared() > 0.05 else "idle")
	move_and_slide()


func _absorbs_hit_stagger(amount: int) -> bool:
	# 탄환 한 발마다 비틀거리지 않는다. 누적 피해가 문턱(최대 체력 16%)을
	# 넘는 순간에만 길게 그로기 — 퍼붓기의 보상이 '무력화'가 아니라
	# '보상 창'이 되도록. 그로기 중 진행하던 패턴은 취소된다.
	# 헤드샷은 포이즈 누적 ×1.5(피해 배율은 ×1.35로 낮은 대신) — enemy.take_projectile_hit가 세팅.
	poise_damage_accumulated += float(amount) * maxf(1.0, last_hit_poise_multiplier)
	hit_flash_timer = 0.1
	var threshold := _poise_threshold()
	if poise_damage_accumulated < threshold:
		_check_enrage()
		return true
	poise_damage_accumulated = 0.0
	boss_action = "combat"
	boss_action_elapsed = 0.0
	threat_marker.visible = false
	if reload_indicator != null:
		reload_indicator.visible = false
	combat_state = "stagger"
	state_timer = POISE_GROGGY_TIME
	stagger_velocity *= 0.55
	_set_motion_state("hit")
	_spawn_hit_burst(-facing_world_direction, Color("#ffd23e"), 16, 0.5)
	_check_enrage()
	return true


func _poise_threshold() -> float:
	return maxf(60.0, float(max_health) * POISE_BREAK_RATIO)


func _setup_poise_bar() -> void:
	# 체력바 바로 아래, 얇은 노란 게이지. 그로기 문턱까지 누적 피해가 쌓이는 게 보인다.
	poise_bar_background = _create_health_bar_sprite("background", 0.0108, 112)
	poise_bar_background.name = "PoiseBarBackground"
	poise_bar_background.position.y = 2.62
	poise_bar_background.scale = Vector3(1.0, 0.42, 1.0)
	add_child(poise_bar_background)
	poise_bar_fill = _create_health_bar_sprite("poise", 0.0108, 114)
	poise_bar_fill.name = "PoiseBarFill"
	poise_bar_fill.position.y = 2.62
	poise_bar_fill.scale = Vector3(1.0, 0.42, 1.0)
	poise_bar_fill.centered = false
	poise_bar_fill.offset = Vector2(-45, -4)
	poise_bar_fill.region_enabled = true
	add_child(poise_bar_fill)
	_set_health_bar_ratio(poise_bar_fill, 0.0)


func get_poise_ratio() -> float:
	return clampf(poise_damage_accumulated / _poise_threshold(), 0.0, 1.0)


func _update_boss_bars(delta: float) -> void:
	# 피격 플래시: 채움 바가 한순간 희게 번쩍 — "맞았다"가 바에서도 읽히게.
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		if health_bar_fill != null:
			health_bar_fill.modulate = Color(2.4, 2.4, 2.4, player_visibility_factor)
	if poise_bar_fill == null or poise_bar_background == null:
		return
	var should_show := not dying and player_visibility_factor > 0.01
	var ratio := get_poise_ratio()
	_set_health_bar_ratio(poise_bar_fill, ratio)
	poise_bar_fill.modulate = Color(1.0, 1.0, 1.0, player_visibility_factor)
	poise_bar_background.modulate = Color(1.0, 1.0, 1.0, player_visibility_factor)
	poise_bar_background.visible = should_show
	poise_bar_fill.visible = should_show and ratio > 0.001
	if combat_state == "stagger":
		# 그로기 중엔 게이지가 비어 있되 배경을 노랗게 — "보상 창" 표시.
		poise_bar_background.modulate = Color(1.6, 1.4, 0.6, player_visibility_factor)


func _boss_enraged() -> bool:
	return health <= roundi(float(max_health) * ENRAGE_HEALTH_RATIO)


func _check_enrage() -> void:
	# 체력 40% 이하: 조준이 빨라지고 지뢰·대시 간격이 줄어든다. 마무리
	# 구간이 소모전이 아니라 가장 위험한 구간이 되도록.
	if enrage_triggered or not _boss_enraged():
		return
	enrage_triggered = true
	_spawn_hit_burst(Vector3.UP, Color("#ff4d2e"), 22, 0.7)
	threat_marker.text = "!!"
	threat_marker.modulate = Color("#ff4d2e")
	threat_marker.visible = true
	threat_marker.scale = Vector3.ONE * 2.0
	mine_pattern_cooldown = minf(mine_pattern_cooldown, 1.6)
	boss_dash_cooldown = minf(boss_dash_cooldown, 0.8)


func _start_rocket_aim() -> void:
	boss_action = "aim"
	boss_action_elapsed = 0.0
	aim_line_shown = false
	_clear_telegraphs()
	boss_action_duration = ROCKET_AIM_TIME * (0.72 if _boss_enraged() else 1.0)
	velocity = Vector3.ZERO
	_set_motion_state("attack")
	threat_marker.text = "!"
	threat_marker.modulate = Color("#ff6a2d")
	threat_marker.visible = true
	threat_marker.scale = Vector3.ONE * 1.6


func _update_rocket_aim(delta: float, direction: Vector3) -> void:
	boss_action_elapsed += delta
	velocity = Vector3.ZERO
	_set_facing_from_world_direction(direction)
	threat_marker.visible = true
	threat_marker.scale = Vector3.ONE * (1.35 + sin(boss_action_elapsed * 18.0) * 0.16)
	# 조준선 예고 — 사수와 같은 규격(발사 0.35s 전 깜빡이는 선 + 총구 반짝).
	var remaining := boss_action_duration - boss_action_elapsed
	if not aim_line_shown and remaining <= RANGED_AIM_LINE_LEAD + 0.0001:
		pending_attack_direction = direction
		_show_aim_line_telegraph(remaining)
	if boss_action_elapsed < boss_action_duration:
		return
	threat_marker.visible = false
	_clear_telegraphs()
	_fire_rocket(direction)
	boss_action = "recovery"
	boss_action_elapsed = 0.0
	boss_action_duration = ROCKET_SHOT_RECOVERY
	attack_cooldown = ROCKET_SHOT_RECOVERY


func _fire_rocket(direction: Vector3) -> void:
	if magazine_ammo <= 0 or not is_instance_valid(target):
		_start_boss_reload()
		return
	magazine_ammo -= 1
	rocket_shots_fired += 1
	var lead_position := target.global_position + target.velocity * 0.24
	lead_position.y = 0.1
	var rocket := Node3D.new()
	rocket.name = "BossRocket_%d" % rocket_shots_fired
	rocket.set_script(ROCKET_PROJECTILE)
	rocket.call(
		"configure", self, target,
		global_position + direction * 0.72 + Vector3(0.0, 1.18, 0.0),
		lead_position, ROCKET_DAMAGE, ROCKET_BLAST_RADIUS
	)
	get_parent().add_child(rocket)
	_spawn_enemy_muzzle_flash(direction)
	_play_enemy_gunshot()
	_play_attack_feedback()


func _start_boss_reload() -> void:
	boss_action = "reload"
	boss_action_elapsed = 0.0
	boss_action_duration = ROCKET_RELOAD_DURATION
	velocity = Vector3.ZERO
	_set_motion_state("idle")
	if reload_indicator != null:
		reload_indicator.texture = _get_reload_texture(0)
		reload_indicator.visible = true


func _update_boss_reload(delta: float, direction_to_target: Vector3) -> void:
	boss_action_elapsed += delta
	var progress := clampf(boss_action_elapsed / boss_action_duration, 0.0, 1.0)
	if reload_indicator != null:
		reload_indicator.texture = _get_reload_texture(roundi(progress * 20.0))
		reload_indicator.visible = true
	velocity = _steer_around_obstacles(-direction_to_target) * 1.35
	_set_motion_state("walk" if velocity.length_squared() > 0.05 else "idle")
	move_and_slide()
	if progress >= 1.0:
		magazine_ammo = ROCKET_MAGAZINE_SIZE
		boss_action = "combat"
		attack_cooldown = 0.45
		if reload_indicator != null:
			reload_indicator.visible = false


func _start_boss_dash(direction: Vector3, distance: float) -> void:
	if direction.length_squared() <= 0.01:
		return
	boss_action = "dash"
	boss_action_elapsed = 0.0
	boss_action_duration = BOSS_DASH_DURATION
	boss_dash_start = global_position
	boss_dash_end = global_position + direction.normalized() * distance
	boss_dash_end.y = global_position.y
	boss_dash_cooldown = (
		boss_rng.randf_range(1.5, 2.3) if _boss_enraged() else boss_rng.randf_range(2.4, 3.6)
	)
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")


func _start_mine_pattern(direction: Vector3, distance: float) -> void:
	mine_target_snapshot = target.global_position + target.velocity * 0.34
	mine_target_snapshot.y = 0.1
	mine_deploy_count = boss_rng.randi_range(5, 7) if _boss_enraged() else boss_rng.randi_range(4, 6)
	mines_deployed_this_pattern = 0
	mine_pattern_cooldown = (
		boss_rng.randf_range(5.5, 7.5) if _boss_enraged() else boss_rng.randf_range(8.5, 11.5)
	)
	boss_action = "mine_approach"
	boss_action_elapsed = 0.0
	boss_action_duration = MINE_PATTERN_APPROACH_DURATION
	boss_dash_start = global_position
	var approach_distance := clampf(distance - MINE_PATTERN_APPROACH_RANGE, 2.4, 10.0)
	boss_dash_end = global_position + direction.normalized() * approach_distance
	boss_dash_end.y = global_position.y
	_set_facing_from_world_direction(direction)
	_set_motion_state("walk")
	threat_marker.text = "!"
	threat_marker.modulate = Color("#ff9b45")
	threat_marker.visible = true
	threat_marker.scale = Vector3.ONE * 1.75


func _start_mine_deploy() -> void:
	boss_action = "mine_deploy"
	boss_action_elapsed = 0.0
	boss_action_duration = MINE_DEPLOY_INTERVAL * float(mine_deploy_count) + 0.3
	velocity = Vector3.ZERO
	_set_motion_state("attack")
	threat_marker.visible = true


func _update_mine_deploy(delta: float, direction_to_target: Vector3) -> void:
	boss_action_elapsed += delta
	velocity = Vector3.ZERO
	_set_facing_from_world_direction(direction_to_target)
	threat_marker.scale = Vector3.ONE * (1.55 + sin(boss_action_elapsed * 24.0) * 0.16)
	while (
		mines_deployed_this_pattern < mine_deploy_count
		and boss_action_elapsed
		>= MINE_DEPLOY_INTERVAL * float(mines_deployed_this_pattern + 1)
	):
		_deploy_boss_mine(mines_deployed_this_pattern)
		mines_deployed_this_pattern += 1
	if boss_action_elapsed < boss_action_duration:
		return
	threat_marker.visible = false
	var retreat_direction := -direction_to_target
	if retreat_direction.length_squared() <= 0.01:
		retreat_direction = -facing_world_direction
	boss_action = "mine_retreat"
	boss_action_elapsed = 0.0
	boss_action_duration = MINE_PATTERN_RETREAT_DURATION
	boss_dash_start = global_position
	boss_dash_end = global_position + retreat_direction.normalized() * MINE_PATTERN_RETREAT_DISTANCE
	boss_dash_end.y = global_position.y
	_set_facing_from_world_direction(retreat_direction)
	_set_motion_state("walk")


func _deploy_boss_mine(index: int) -> void:
	if not is_instance_valid(target):
		return
	var forward := mine_target_snapshot - global_position
	forward.y = 0.0
	if forward.length_squared() <= 0.01:
		forward = facing_world_direction
	forward = forward.normalized()
	var fraction := 0.5
	if mine_deploy_count > 1:
		fraction = float(index) / float(mine_deploy_count - 1)
	# 예전엔 플레이어 주변에 무작위로 흩뿌려서 그냥 걸어 나가면 그만이었다.
	# 이제는 플레이어 뒤쪽 반원에 깔아 후퇴로를 끊는다. 앞으로 나오거나
	# 지뢰 사이 틈을 노려 굴러 빠져나가야 한다.
	var away_from_boss := forward  # 보스 -> 플레이어 방향 = 플레이어의 후퇴 방향
	var arc_angle := lerpf(-1.15, 1.15, fraction) + boss_rng.randf_range(-0.1, 0.1)
	var spread_direction := away_from_boss.rotated(Vector3.UP, arc_angle)
	var spread_distance := boss_rng.randf_range(2.6, 4.4)
	var landing_position := mine_target_snapshot + spread_direction * spread_distance
	landing_position.y = 0.1
	var mine := Node3D.new()
	mine.name = "BossMine_%02d" % (mines_deployed_total + 1)
	mine.set_script(BOSS_MINE)
	mine.call(
		"configure",
		self,
		target,
		global_position + forward * 0.58 + Vector3(0.0, 0.92, 0.0),
		landing_position,
		MINE_DAMAGE,
		MINE_BLAST_RADIUS
	)
	get_parent().add_child(mine)
	mines_deployed_total += 1
	_spawn_enemy_muzzle_flash(forward)
	if index == 0:
		_play_enemy_gunshot()
	_play_attack_feedback()


func _update_boss_dash(delta: float) -> void:
	var completed_action := boss_action
	boss_action_elapsed += delta
	var progress := clampf(boss_action_elapsed / boss_action_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var desired_position := boss_dash_start.lerp(boss_dash_end, eased)
	var collision := move_and_collide(desired_position - global_position)
	if collision != null or progress >= 1.0:
		velocity = Vector3.ZERO
		if completed_action == "mine_approach":
			_start_mine_deploy()
		elif completed_action == "mine_retreat":
			boss_action = "recovery"
			boss_action_elapsed = 0.0
			boss_action_duration = 0.55
			attack_cooldown = 0.45
			_set_motion_state("idle")
		else:
			boss_action = "combat"
			_set_motion_state("idle")


func _create_boss_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in BOSS_SCREEN_DIRECTIONS:
		_add_boss_animation(frames, direction_name, "idle", "idle", [0, 1, 2, 3], 5.5, true)
		_add_boss_animation(frames, direction_name, "walk", "walk", [0, 1, 2, 3], 8.0, true)
		_add_boss_animation(frames, direction_name, "attack", "idle", [0, 1, 2, 1], 12.0, false)
		_add_boss_animation(frames, direction_name, "hit", "idle", [2, 1, 2], 17.0, false)
		_add_boss_animation(frames, direction_name, "death", "idle", [0, 1, 2, 3], 6.0, false)
	return frames


func _add_boss_animation(
	frames: SpriteFrames, direction_name: String, state: String, source_state: String,
	frame_indices: Array, speed: float, looped: bool
) -> void:
	var animation_name := "%s_%s" % [state, direction_name]
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, looped)
	frames.set_animation_speed(animation_name, speed)
	var prefix: String = BOSS_DIRECTIONS[direction_name]
	for frame_index in frame_indices:
		var texture_path := "%s/%s_%s_%d.png" % [BOSS_ANIMATION_ROOT, prefix, source_state, int(frame_index)]
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_error("Missing rocket boss animation frame: %s" % texture_path)
			continue
		frames.add_frame(animation_name, texture)


func _update_weapon_visual() -> void:
	if weapon_visual == null:
		return
	var direction := facing_world_direction.normalized()
	weapon_visual.position = direction * 0.58 + Vector3(0, 0.74, 0)
	var screen_direction := Vector2(direction.x - direction.z, direction.x + direction.z).normalized()
	weapon_visual.flip_h = screen_direction.x < -0.01
	var source_angle := PI if weapon_visual.flip_h else 0.0
	weapon_visual.rotation.z = wrapf(screen_direction.angle() - source_angle, -PI, PI)
	weapon_visual.scale = Vector3.ONE * 0.92
	weapon_visual.visible = not dying


func _reset_sprite_pose() -> void:
	if sprite == null:
		return
	sprite.position = BOSS_SPRITE_POSITION
	sprite.rotation = Vector3.ZERO
	sprite.scale = Vector3.ONE
	sprite.modulate = Color.WHITE


func _play_hit_reaction(hit_direction: Vector3) -> void:
	_kill_visual_tween()
	visual_tween = create_tween()
	visual_tween.tween_property(sprite, "modulate", Color(2.4, 2.4, 2.4, 1.0), 0.025)
	visual_tween.tween_property(sprite, "modulate", Color(1.8, 0.16, 0.1, 1.0), 0.055)
	visual_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var shake := create_tween()
	shake.tween_property(sprite, "position", BOSS_SPRITE_POSITION + hit_direction * 0.11, 0.035)
	shake.tween_property(sprite, "position", BOSS_SPRITE_POSITION - hit_direction * 0.055, 0.035)
	shake.tween_property(sprite, "position", BOSS_SPRITE_POSITION, 0.07)


func get_projectile_hit_center() -> Vector3:
	return global_position + Vector3(0.0, 0.25, 0.0)


func get_projectile_hit_radius() -> float:
	return 0.78


func get_world_height() -> float:
	# 보스 스프라이트(0.0108×256)의 실제 몸 높이 — 일반 적(1.62)보다 크다.
	return 2.1


func get_head_zone_ratio() -> float:
	# 덩치가 큰 만큼 머리 비율은 조금 작다(상단 24%).
	return 0.24


func get_rocket_magazine_ammo() -> int:
	return magazine_ammo


func is_rocket_reloading() -> bool:
	return boss_action == "reload"


func get_mines_deployed_total() -> int:
	return mines_deployed_total
