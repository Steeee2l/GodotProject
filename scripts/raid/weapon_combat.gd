class_name WeaponCombat
extends RefCounted

# 총기 전투 — 발사, 재장전, 반동, 조준(마우스/모바일 보조), 총성.
# main.gd에서 23개 함수를 옮겼다.


const AIM_HOLD_DURATION := 0.55
# 모바일 '정조준 상승' — 정지한 채 0.5s 조준을 유지하면(또는 식빵 자세) 어시스트의
# 조준점이 몸(0.5)에서 머리(0.86 — 상단 28% 안)로 올라간다. PC는 마우스 위치 그대로.
const STEADY_AIM_RAISE_SECONDS := 0.5
const MOBILE_BODY_AIM_RATIO := 0.5
const MOBILE_HEAD_AIM_RATIO := 0.86
const AK_DIRECTIONAL_TEXTURE := preload("res://assets/weapons/ak47_directional.png")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const BASE_CAMERA_SIZE := 28.0
const BOSS_DEFEAT_CAMERA_SIZE := 19.5
const BOSS_DEFEAT_FOCUS_SECONDS := 1.65
const BOSS_DEFEAT_SLOWMO_SECONDS := 1.05
const BOSS_DEFEAT_TIME_SCALE := 0.20
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const CAT_ANIMATION_ROOT := "res://assets/characters/cat_8way"
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
const CAT_LOAF_ANIMATION_ROOT := "res://assets/characters/loaf"
const CAT_MELEE_ANIMATION_ROOT := "res://assets/characters/cat_melee"
const CAT_ROLL_ANIMATION_ROOT := "res://assets/characters/cat_roll"
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
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
const FATIGUE_MAX := 100.0
const FATIGUE_MELEE_GAIN := 1.1
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_ROLL_GAIN := 0.45
const FATIGUE_SHOT_GAIN := 0.28
const FIELD_LOOT_CACHE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const FIRST_STAGE_ZONE_ID := "jongno_outskirts"
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOAF_HOLD_THRESHOLD := 0.45
const LOAF_MIN_STAMINA := 1.0
const LOAF_VISIBILITY_MULTIPLIER := 0.48
const LOOT_CONTAINER_VISUALS := preload("res://scripts/loot_container_visual_catalog.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const MELEE_ANIMATION_DURATION := 0.5
const MELEE_ANIMATION_FPS := 8.0
const MELEE_ATTACK_COOLDOWN := 0.72
const MELEE_ATTACK_DAMAGE := 38
const MELEE_ATTACK_RANGE := 2.2
const MELEE_FAN_HALF_ANGLE_DEG := 56.0
const MELEE_FAN_SEGMENTS := 24
const MELEE_FRAME_COUNT := 4
const MELEE_WINDUP_DURATION := 0.18
const MOBILE_AIM_ASSIST_ANGLE_WEIGHT := 24.0
const MOBILE_AIM_ASSIST_DISTANCE_WEIGHT := 0.32
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 42.0
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 34.0
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const ROLL_AFTERIMAGE_INTERVAL := 0.055
const ROLL_DURATION := 0.42
const ROLL_END_SPEED := 4.4
const ROLL_FRAME_COUNT := 4
const ROLL_STAMINA_COST := 35.0
const ROLL_START_SPEED := 42.0
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const SFX := preload("res://scripts/sfx_bank.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const WEAPON_FLOAT_DISTANCE := 0.72
const WEAPON_FRAME_SIZE := Vector2(192, 192)
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const WEAPON_MUZZLE_FORWARD_DISTANCE := 0.64
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const WEAPON_VISUAL_PIXEL_SIZE := 0.0018

const WEAPON_REVEAL := preload("res://scripts/raid/weapon_reveal.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var camera: Camera3D
# 무기는 조준·사격·재장전 중에만 보인다. 규칙은 scripts/raid/weapon_reveal.gd.
var weapon_reveal := WEAPON_REVEAL.new()


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player
	camera = owner_node.camera


func _try_fire_ak47() -> void:
	if host.has_ak and not host.roll_active and not host.loafing and not host.melee_attack_active and not host.weapon_reloading and host.fire_cooldown <= 0.0:
		_fire_ak47()


func _fire_ak47() -> void:
	if host.weapon_reloading or host.melee_attack_active or host.loafing:
		return
	if host.magazine_ammo <= 0:
		if host.reserve_ammo > 0 and bool(AccessibilitySettings.auto_reload):
			_reload_ak47()
		else:
			host._show_no_ammo_notice()
		return
	if host._weapon_jammed():
		return
	host.magazine_ammo -= 1
	GameState.magazine_ammo = host.magazine_ammo
	if host.field_missions._active_field_mission_requires_silence():
		host.field_mission_noise_breached = true
	host.fire_cooldown = float(host.weapon_stats.get("fire_interval", 0.12))
	var aim_direction := _get_current_fire_direction()
	host._lock_aim_direction(aim_direction)
	host._set_facing_from_world_direction(aim_direction)
	_update_weapon_pose()
	if host.weapon_sprite:
		host._play_weapon_directional_animation("fire")
	var pellet_count := int(host.weapon_stats.get("pellet_count", 1))
	for pellet_index in pellet_count:
		var spread_angle: float = host.weapon_random.randf_range(-host.weapon_spread_deg, host.weapon_spread_deg)
		var shot_direction := aim_direction.rotated(Vector3.UP, deg_to_rad(spread_angle)).normalized()
		_spawn_weapon_projectile(shot_direction, pellet_index)
	host.weapon_durability = maxf(0.0, host.weapon_durability - float(host.weapon_stats.get("durability_loss", 0.06)))
	GameState.weapon_durability = host.weapon_durability
	host.weapon_spread_deg = minf(
		host.weapon_spread_deg + float(host.weapon_stats.get("spread_per_shot_deg", 1.0)),
		float(host.weapon_stats.get("max_spread_deg", 14.0))
	)
	host._add_fatigue(FATIGUE_SHOT_GAIN)
	if host.has_method("break_raid_entry_grace"):
		host.break_raid_entry_grace()
	_apply_weapon_recoil(aim_direction)
	# 엄폐 중 사격 = 0.4s 노출(쏘고 숨기의 리듬).
	if host.get("cover_system") != null:
		host.cover_system.notify_player_fired()
	# 발사 반동을 화면에도 아주 약하게 싣는다. 산탄(다연발)은 조금 더 묵직하게.
	var recoil_kick := 0.032 if pellet_count <= 1 else 0.062
	host.camera_shake_time = maxf(host.camera_shake_time, 0.05)
	host.camera_shake_strength = maxf(host.camera_shake_strength, recoil_kick)
	# 총성은 도시가 듣는다. 소음기를 달면 그만큼 덜 들린다.
	var sound_scale := clampf(float(host.weapon_stats.get("sound_radius", 1.0)), 0.15, 2.0)
	host._add_raid_pressure(
		lerpf(
			RAID_EVENT_DIRECTOR.PRESSURE_PER_SUPPRESSED_GUNSHOT,
			RAID_EVENT_DIRECTOR.PRESSURE_PER_GUNSHOT,
			clampf(sound_scale, 0.0, 1.0)
		)
	)
	_play_gunshot()
	host.bgm.notify_combat()
	_spawn_muzzle_light(aim_direction)
	_spawn_launch_fx(aim_direction)
	host._update_equipment_ui()


func _spawn_weapon_projectile(direction: Vector3, pellet_index: int) -> void:
	var ammo_definition: Dictionary = WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id)
	var damage_multiplier := float(ammo_definition.get("damage_multiplier", 1.0))
	var projectile_damage := roundi(
		float(host.weapon_stats.get("damage", 24)) * damage_multiplier
	)
	var penetration := maxi(
		int(host.weapon_stats.get("penetration_count", 0)),
		int(ammo_definition.get("penetration", 0))
	)
	var projectile := Area3D.new()
	projectile.name = "%sBullet_%d" % [host.equipped_weapon_id, pellet_index]
	projectile.set_script(BULLET_PROJECTILE)
	projectile.set("direction", direction)
	projectile.set("source_body", player)
	projectile.set("damage", projectile_damage)
	projectile.set("critical_chance", host._get_weapon_critical_chance())
	projectile.set("critical_multiplier", 1.65)
	projectile.set("penetrations_remaining", penetration)
	var range_profile: Vector3 = host._get_weapon_range_profile(host.equipped_weapon_id)
	projectile.set("effective_range", range_profile.x)
	projectile.set("maximum_range", range_profile.y)
	projectile.set("minimum_damage_multiplier", range_profile.z)
	# 약점 판정 입력 — 마우스는 발사 순간의 화면 레이, 모바일은 어시스트 조준 높이.
	if _uses_mouse_aim():
		var mouse_position: Vector2 = host.get_viewport().get_mouse_position() + host.recoil_reticle_offset
		projectile.set("aim_ray_origin", camera.project_ray_origin(mouse_position))
		projectile.set("aim_ray_direction", camera.project_ray_normal(mouse_position))
	else:
		projectile.set("aim_height_ratio", get_mobile_aim_height_ratio())
	projectile.position = _get_weapon_muzzle_position(direction)
	host.add_child(projectile)


func _update_firing(delta: float) -> void:
	host.fire_cooldown = maxf(0.0, host.fire_cooldown - delta)
	_update_steady_aim(delta)
	if host.roll_active or host.melee_attack_active or host.loafing:
		return
	var firing_held: bool = host.fire_button_held or host.mouse_fire_held
	if firing_held and host.has_ak and bool(host.weapon_stats.get("automatic", true)) and host.fire_cooldown <= 0.0:
		_fire_ak47()


func grant_sortie_supply() -> void:
	# 출정 보급 훈련: 랭크당 장착 무기 1탄창(훈련 보정 장탄 기준)을 예비탄에 더한다.
	# 판 시작에서 한 번만 — 호출 지점(main 판 시작)이 오프닝·건물 내부 복귀를 거른다.
	var magazines := int(GameState.get_sortie_supply_magazines())
	if magazines <= 0:
		return
	var ammo_id := str(GameState.equipped_ammo_id)
	if ammo_id.is_empty():
		return
	var magazine_size := int(host.weapon_stats.get("magazine_size", 30))
	if magazine_size <= 0:
		return
	var granted := magazine_size * magazines
	GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + granted)
	host.reserve_ammo = GameState.get_ammo_count(ammo_id)
	GameState.reserve_ammo = host.reserve_ammo
	var caliber := str(WEAPON_SYSTEM.get_ammo(ammo_id).get("display_name", ammo_id)).split(" ")[0]
	host.hud.push_toast(
		"출정 보급 · %s %d발 ×%d" % [caliber, magazine_size, magazines], HudStyle.GOLD, 3.0
	)
	host._update_equipment_ui()


func _reload_ak47() -> void:
	var magazine_size := int(host.weapon_stats.get("magazine_size", 30))
	if host.weapon_reloading or host.loafing:
		return
	if host.reserve_ammo <= 0 or host.magazine_ammo >= magazine_size:
		host.fire_cooldown = 0.35
		if host.reserve_ammo <= 0:
			host._show_no_ammo_notice()
		return
	host.weapon_reloading = true
	SFX.play("reload_start")
	host.reload_timer = float(host.weapon_stats.get("reload_time", 2.15))
	host.fire_cooldown = host.reload_timer
	host._add_fatigue(FATIGUE_RELOAD_GAIN)
	host.hud.push_toast(
		"%s 재장전 · %.1f초" % [
			str(host.weapon_stats.get("display_name", "무기")).split("\"")[0].strip_edges(),
			host.reload_timer,
		],
		HudStyle.WARN,
		host.reload_timer
	)
	host._update_equipment_ui()


func _finish_reload() -> void:
	host.weapon_reloading = false
	SFX.play("reload_end")
	var magazine_size := int(host.weapon_stats.get("magazine_size", 30))
	var needed: int = magazine_size - host.magazine_ammo
	var loaded := mini(needed, host.reserve_ammo)
	host.magazine_ammo += loaded
	host.reserve_ammo -= loaded
	GameState.magazine_ammo = host.magazine_ammo
	GameState.set_ammo_count(GameState.equipped_ammo_id, host.reserve_ammo)
	host.hud.ammo_notice.text = "%s 재장전 완료  +%d\n탄창 %d / %d   예비 %d   총 %d" % [
		str(host.weapon_stats.get("display_name", "무기")),
		loaded,
		host.magazine_ammo,
		magazine_size,
		host.reserve_ammo,
		host.magazine_ammo + host.reserve_ammo,
	]
	host.hud.ammo_notice.visible = true
	host.ammo_notice_time = 1.4
	host._update_equipment_ui()


func _apply_weapon_recoil(aim_direction: Vector3) -> void:
	var recoil_kick := float(host.weapon_stats.get("recoil_kick", 0.7)) * GameState.get_recoil_control_multiplier()
	if host.loafing:
		recoil_kick *= float(host.weapon_stats.get("loaf_recoil_multiplier", 1.0))
	var knockback := float(host.weapon_stats.get("player_knockback", 0.15)) * recoil_kick
	host.recoil_velocity -= aim_direction * knockback
	host.recoil_reticle_offset += Vector2(host.weapon_random.randf_range(-5.0, 5.0), -11.0) * recoil_kick


func _update_weapon_ballistics(delta: float, is_moving: bool) -> void:
	if host.weapon_stats.is_empty():
		return
	host.recoil_velocity = host.recoil_velocity.move_toward(Vector3.ZERO, 8.5 * delta)
	var target_spread := float(host.weapon_stats.get("base_spread_deg", 2.4))
	if is_moving:
		target_spread *= float(host.weapon_stats.get("moving_spread_multiplier", 1.0))
	if host.player_health <= 45:
		target_spread *= float(host.weapon_stats.get("injured_spread_multiplier", 1.0))
	if host.loafing:
		target_spread *= float(host.weapon_stats.get("loaf_spread_multiplier", 1.0))
	# 피로 60% 이상부터 탄이 퍼지기 시작한다. 정산 화면이 "탄이 퍼진 상태였다"고
	# 말해 왔는데 정작 탄도에는 피로가 없던 것을 실제로 구현한다.
	target_spread *= lerpf(1.0, 1.35, clampf(inverse_lerp(60.0, 100.0, host.fatigue), 0.0, 1.0))
	# 캣닢 급여 '집중' — 한 판짜리 탄퍼짐 보정.
	var durability_penalty := 1.0 + clampf((50.0 - host.weapon_durability) / 50.0, 0.0, 1.0) * 0.7
	target_spread *= durability_penalty
	var recovery := float(host.weapon_stats.get("spread_recovery_deg", 5.0))
	host.weapon_spread_deg = move_toward(host.weapon_spread_deg, target_spread, recovery * delta)
	host.weapon_spread_deg = clampf(host.weapon_spread_deg, 0.2, float(host.weapon_stats.get("max_spread_deg", 14.0)))
	if host.weapon_reloading:
		host.reload_timer = maxf(0.0, host.reload_timer - delta)
		if host.hud.equipment_reload_bar:
			var reload_duration := maxf(0.01, float(host.weapon_stats.get("reload_time", 2.15)))
			host.hud.equipment_reload_bar.value = 1.0 - clampf(host.reload_timer / reload_duration, 0.0, 1.0)
		if host.hud.equipment_condition_label:
			var reload_ammo_name := str(
				WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get(
					"display_name",
					GameState.equipped_ammo_id
				)
			)
			host.hud.equipment_condition_label.text = "재장전 %.1f초 · 사용 탄환  %s" % [
				host.reload_timer,
				reload_ammo_name,
			]
			# 상태줄은 평소 숨어 있다. 재장전 중에는 반드시 보여야 한다.
			host.hud.equipment_condition_label.visible = true
		if host.reload_timer <= 0.0:
			_finish_reload()


func is_weapon_reveal_requested() -> bool:
	# 조준(우클릭 정조준·모바일 조준 버튼)·사격(마우스/발사 버튼)·재장전 중에만 참.
	# 근접 스윙은 방망이 스프라이트(melee_bat_sprite)가 따로 뜨므로 총은 숨긴다.
	if host.melee_attack_active or host.loafing:
		return false
	return (
		host.laser_aim_held
		or host.mouse_fire_held
		or host.fire_button_held
		or host.weapon_reloading
	)


func update_weapon_reveal(delta: float) -> float:
	# 매 프레임 마지막에 한 번 — 피격 플래시·차폐 실루엣이 modulate 를 만진 뒤에
	# 알파를 덮어써야 한다(그것들은 알파를 1로 되돌린다).
	var alpha := weapon_reveal.update(delta, host.has_ak and is_weapon_reveal_requested())
	if host.weapon_sprite != null:
		var tint: Color = host.weapon_sprite.modulate
		tint.a = alpha
		host.weapon_sprite.modulate = tint
		host.weapon_sprite.visible = _weapon_sprite_should_draw()
	return alpha


func _weapon_sprite_should_draw() -> bool:
	return (
		host.has_ak
		and not host.melee_attack_active
		and not host.loafing
		and host.building_canvas == null
		and weapon_reveal.is_drawn()
	)


func _update_weapon_pose() -> void:
	if host.weapon_sprite == null:
		return
	host.weapon_sprite.visible = _weapon_sprite_should_draw()
	if not host.has_ak or host.melee_attack_active or host.loafing:
		return
	if WEAPON_VISUAL_CATALOG.has_weapon_texture(host.equipped_weapon_id):
		var screen_direction: Vector2 = DIRECTION_VECTORS[host.facing]
		host.weapon_sprite.flip_h = screen_direction.x < -0.01
		var source_angle := PI if host.weapon_sprite.flip_h else 0.0
		host.weapon_sprite.rotation = Vector3(
			0,
			0,
			wrapf(screen_direction.angle() - source_angle, -PI, PI)
		)
	else:
		host.weapon_sprite.flip_h = host.facing in ["w", "sw", "nw"]
		host.weapon_sprite.rotation = Vector3.ZERO
	host.weapon_sprite.render_priority = 0 if host._weapon_renders_behind_player() else 2
	var direction: Vector3 = host._get_current_facing_world_direction()
	host.weapon_sprite.position = direction * WEAPON_FLOAT_DISTANCE + Vector3(0, 0.36, 0)
	host.weapon_sprite.offset = host._get_weapon_screen_offset()
	if not host.weapon_sprite.animation.begins_with("fire_"):
		host._play_weapon_directional_animation("idle")


func _get_weapon_muzzle_position(world_direction: Vector3) -> Vector3:
	var weapon_origin: Vector3 = host.weapon_sprite.global_position if host.weapon_sprite and host.has_ak else player.global_position
	return weapon_origin + world_direction * WEAPON_MUZZLE_FORWARD_DISTANCE + Vector3(0, 0.02, 0)


func _spawn_muzzle_light(direction: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffb347")
	flash.light_energy = 3.0
	flash.omni_range = 2.2
	flash.position = player.position + direction * 0.8 + Vector3(0, 0.2, 0)
	host.add_child(flash)
	host.get_tree().create_timer(0.045).timeout.connect(flash.queue_free)


func _spawn_launch_fx(direction: Vector3) -> void:
	var origin := player.position + direction * 0.86 + Vector3(0, 0.18, 0)
	host._spawn_particle_burst(origin, direction, Color("#ffd98a"), 6, 0.09, 2.0, 4.2, 0.04, 0.12)
	host._spawn_smoke_cloud(origin, direction)
	host.get_tree().create_timer(0.055).timeout.connect(func() -> void:
		# 판이 끝난 뒤(호스트 해제 후) 타이머가 늦게 발화할 수 있다.
		if is_instance_valid(host):
			host._spawn_smoke_cloud(origin + direction * 0.08, direction)
	)


func _play_gunshot() -> void:
	# 플레이어 총성 — 장착 무기 구경별(권총/소총/산탄) 합성음. 자기 총은 2D로
	# 또렷하게, 적 총성은 enemy.gd가 같은 뱅크를 3D 위치로 낮춰 쓴다.
	SFX.play_weapon_shot(host.equipped_weapon_id)


func _get_current_fire_direction() -> Vector3:
	if _uses_mouse_aim():
		return _get_mouse_world_direction()
	# 스티키 표적이 살아 있으면 8방향 quantize를 거치지 않고 표적을 직격한다.
	if _is_mobile_assist_target_valid():
		var to_target: Vector3 = mobile_assist_target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			return to_target.normalized()
	var screen_direction: Vector2 = DIRECTION_VECTORS[host.facing]
	var facing_direction := Vector3(
		screen_direction.x + screen_direction.y,
		0,
		-screen_direction.x + screen_direction.y
	).normalized()
	return _get_mobile_aim_assist_direction(facing_direction)


func _get_mobile_aim_assist_direction(facing_direction: Vector3) -> Vector3:
	facing_direction.y = 0.0
	if facing_direction.length_squared() <= 0.01:
		facing_direction = host._get_current_facing_world_direction()
	facing_direction = facing_direction.normalized()
	var best_enemy: CharacterBody3D
	var best_score := INF
	var assist_strength := clampf(float(AccessibilitySettings.aim_assist_strength), 0.0, 1.0)
	if assist_strength <= 0.01:
		return facing_direction
	var assist_half_angle := lerpf(12.0, MOBILE_AIM_ASSIST_HALF_ANGLE_DEG, assist_strength)
	var minimum_dot := cos(deg_to_rad(assist_half_angle))
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if float(enemy.get("player_visibility_factor")) < 0.2:
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > MOBILE_AIM_ASSIST_MAX_DISTANCE:
			continue
		var enemy_direction: Vector3 = offset / distance
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
	# 새로 잡은 표적을 기억해 다음 프레임부터 스티키로 유지한다.
	mobile_assist_target = best_enemy
	var assisted_direction := best_enemy.global_position - player.global_position
	assisted_direction.y = 0.0
	return facing_direction.slerp(assisted_direction.normalized(), lerpf(0.25, 1.0, assist_strength)).normalized()


func _get_mouse_world_direction() -> Vector3:
	# The same recoil offset drives both the drawn reticle and the actual ray,
	# so sustained fire cannot visually lie about the bullet center.
	var mouse_position: Vector2 = host.get_viewport().get_mouse_position() + host.recoil_reticle_offset
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var target_y := player.global_position.y
	if absf(ray_direction.y) < 0.001:
		return host._get_current_facing_world_direction()
	var distance_to_plane := (target_y - ray_origin.y) / ray_direction.y
	var hit_position := ray_origin + ray_direction * distance_to_plane
	var direction := hit_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return host._get_current_facing_world_direction()
	return direction.normalized()


func _uses_mouse_aim() -> bool:
	if force_touch_aim_for_test:
		return false
	return not DisplayServer.is_touchscreen_available()


var mobile_assist_target: CharacterBody3D
# 프로브용 — 데스크톱 헤드리스에서 모바일 조준 경로를 강제한다.
var force_touch_aim_for_test := false
var steady_aim_time := 0.0


func _update_steady_aim(delta: float) -> void:
	# 정지 + 조준 유지 시간. 움직이거나 구르거나 손을 떼면 0으로.
	if _uses_mouse_aim():
		steady_aim_time = 0.0
		return
	var aiming: bool = host.fire_button_held or host.laser_aim_held
	var moving: bool = player.velocity.length_squared() > 0.09
	if not aiming or moving or host.roll_active:
		steady_aim_time = 0.0
		return
	steady_aim_time += delta


func is_steady_aim_raised() -> bool:
	if _uses_mouse_aim():
		return false
	return bool(host.loafing) or steady_aim_time >= STEADY_AIM_RAISE_SECONDS


func get_mobile_aim_height_ratio() -> float:
	return MOBILE_HEAD_AIM_RATIO if is_steady_aim_raised() else MOBILE_BODY_AIM_RATIO


func _acquire_mobile_fire_target(force_for_test := false) -> void:
	# 발사 버튼을 누르는 순간엔 바라보는 방향과 무관하게 감지범위 안의
	# 최근접 적을 잡는다. 조이스틱으로 총구 방향까지 만들 필요가 없어야
	# 모바일에서 쏠 만해진다. 접근성 어시스트 강도와 무관하게 항상 동작.
	if (_uses_mouse_aim() and not force_for_test) or _is_mobile_assist_target_valid():
		return
	var best_enemy: CharacterBody3D
	var best_distance := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if float(enemy.get("player_visibility_factor")) < 0.2:
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > MOBILE_AIM_ASSIST_MAX_DISTANCE:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 0.45, 0),
			enemy.global_position + Vector3(0, 0.45, 0),
			COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
		)
		query.exclude = [player.get_rid(), enemy.get_rid()]
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	if best_enemy == null:
		return
	mobile_assist_target = best_enemy
	var to_target: Vector3 = best_enemy.global_position - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		var direction := to_target.normalized()
		host._lock_aim_direction(direction)
		host._set_facing_from_world_direction(direction)


func _update_mobile_aim_direction(movement_world_direction: Vector3) -> void:
	# 스티키 타겟팅: 한 번 잡은 표적은 살아서 보이는 한 놓지 않는다.
	# 예전에는 조준 기준이 이동 방향이라, 적에게서 후퇴하며 쏘면 총구가
	# 등 뒤(도망가는 방향)로 끌려갔다 — 모바일 사용성 최악의 원인.
	if _is_mobile_assist_target_valid():
		var to_target: Vector3 = mobile_assist_target.global_position - player.global_position
		to_target.y = 0.0
		host._lock_aim_direction(to_target.normalized())
		return
	mobile_assist_target = null
	var base_direction := movement_world_direction
	base_direction.y = 0.0
	if base_direction.length_squared() <= 0.01:
		base_direction = (
			host.locked_aim_direction
			if host.locked_aim_direction.length_squared() > 0.01
			else host._get_current_facing_world_direction()
		)
	host._lock_aim_direction(_get_mobile_aim_assist_direction(base_direction.normalized()))


func _is_mobile_assist_target_valid() -> bool:
	if not is_instance_valid(mobile_assist_target) or bool(mobile_assist_target.get("dying")):
		return false
	if float(mobile_assist_target.get("player_visibility_factor")) < 0.2:
		return false
	var offset: Vector3 = mobile_assist_target.global_position - player.global_position
	offset.y = 0.0
	# 새 표적 탐색보다 후한 유지 반경 — 잠깐 멀어져도 표적이 튀지 않는다.
	return offset.length() <= MOBILE_AIM_ASSIST_MAX_DISTANCE * 1.15


func _on_inventory_weapon_equipped(weapon_id: String) -> void:
	if (weapon_id == host.equipped_weapon_id and host.has_ak) or GameState.get_weapon_count(weapon_id) <= 0:
		return
	var reequipping_same_weapon: bool = not host.has_ak and weapon_id == host.equipped_weapon_id
	var previous_ammo_id := GameState.equipped_ammo_id
	if not reequipping_same_weapon and host.magazine_ammo > 0 and not previous_ammo_id.is_empty():
		GameState.set_ammo_count(previous_ammo_id, GameState.get_ammo_count(previous_ammo_id) + host.magazine_ammo)
	if not GameState.equip_weapon(weapon_id):
		return
	host.equipped_weapon_id = GameState.equipped_weapon_id
	host.equipped_weapon_mods.assign(GameState.equipped_weapon_mods)
	if not reequipping_same_weapon:
		host.magazine_ammo = 0
	host.reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.reserve_ammo = host.reserve_ammo
	host.has_ak = true
	GameState.has_ak = true
	host._refresh_weapon_stats()
	# 처음 잡아 보는 총은 장전된 채로 온다 — 주운 즉시 쏴 보는 경험이 우선이다.
	# 무기당 1회뿐이라 교체로 재장전 시간을 회피하는 꼼수는 안 된다.
	if not reequipping_same_weapon and not GameState.weapon_first_equip_done.has(weapon_id):
		GameState.weapon_first_equip_done.append(weapon_id)
		host.magazine_ammo = int(host.weapon_stats.get("magazine_size", host.magazine_ammo))
	GameState.magazine_ammo = host.magazine_ammo
	host._rebuild_player_weapon_frames()
	_update_weapon_pose()
	host._update_equipment_ui()
	GameState.save_persistent_state()


func _on_inventory_weapon_unequipped() -> void:
	if not host.has_ak:
		return
	host.reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
	GameState.magazine_ammo = host.magazine_ammo
	GameState.reserve_ammo = host.reserve_ammo
	# 가방이 꽉 차면 해제가 거부된다(벗은 무기가 들어갈 자리가 없다). 그 경우
	# 장착 상태를 그대로 유지해야 GameState와 어긋나지 않는다.
	if not GameState.unequip_weapon():
		return
	host.has_ak = false
	host.weapon_reloading = false
	host.laser_aim_held = false
	if host.weapon_sprite:
		host.weapon_sprite.visible = false
	host._update_equipment_ui()
	GameState.save_persistent_state()


func _on_inventory_weapon_mods_changed() -> void:
	host.equipped_weapon_mods.assign(GameState.equipped_weapon_mods)
	host._refresh_weapon_stats()
	host._update_equipment_ui()
	GameState.save_persistent_state()
