class_name DeployablesSystem
extends RefCounted

# 중장비(소모성 화력) — 지뢰·감시포탑·로켓 발사기의 필드 로직.
# "부품으로 만들고, 쓰면 부서지고, 다시 만든다" — 제작은 작업대(workbench),
# 선택·조준은 can_throw_system(투척/배치 선택기), 여기는 '터지는 것'만 안다.
#
# 규약: host 패턴(cover_system/telegraph_fx와 동일). 적 피해 전달은 수신자
# 인자 수 분기(take_hostile_hit 3/4/5인자 — rocket_projectile.gd 패턴 준수).
# 플레이어는 자기 중장비에 절대 피해를 입지 않는다(폭발 대상 = host.enemies만).

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const TELEGRAPH := preload("res://scripts/raid/telegraph_fx.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const SENTRY_TEXTURE := preload("res://assets/props/broken_sentry_salvage.png")

# 아군 중장비 식별색 — 적 지뢰(주황·붉음)와 헷갈리면 자기 지뢰를 피해 다닌다.
const TEAL := Color("#57d9c4")
const TEAL_DIM := Color("#2f8d80")

const MINE_FLIGHT_DURATION := 0.42
const MINE_ARC_HEIGHT := 1.65
const MINE_ARM_DELAY := 1.0
const MINE_TRIGGER_RADIUS := 1.3
const MINE_TRIGGER_FUSE := 0.14
const MINE_BLAST_RADIUS := 2.6
const MINE_DAMAGE_CENTER := 150
const MINE_DAMAGE_EDGE := 60

const TURRET_PLACE_RANGE := 5.0
const TURRET_LIFETIME := 45.0
const TURRET_HP := 220
const TURRET_RANGE := 12.0
const TURRET_FIRE_INTERVAL := 0.5
const TURRET_BULLET_DAMAGE := 16

const ROCKET_RANGE := 18.0
const ROCKET_SPEED := 14.0
const ROCKET_ARC_HEIGHT := 2.3
const ROCKET_BLAST_RADIUS := 3.2
const ROCKET_DAMAGE_CENTER := 380
const ROCKET_DAMAGE_EDGE_RATIO := 0.42
const ROCKET_COOLDOWN := 1.2
const ROCKET_CHARGES := 3

var host: Node
var player: CharacterBody3D
var active_turret: Node3D
var rocket_cooldown_left := 0.0
# 발수는 판 로컬이다 — GameState.heavy_gear_inventory는 '발사기 개수'만 안다.
# -1 = 아직 개봉하지 않은 발사기(첫 발에 3발로 개봉). 판이 끝나면 사라진다.
var rocket_charges_left := -1

# 프로브·통계용 카운터.
var mines_thrown := 0
var mine_explosions := 0
var turrets_placed := 0
var turret_shots_fired := 0
var rockets_fired := 0

func attach(owner_node: Node) -> void:
	host = owner_node
	player = host.get_node("Player")


func update(delta: float) -> void:
	rocket_cooldown_left = maxf(0.0, rocket_cooldown_left - delta)


func is_rocket_ready() -> bool:
	return rocket_cooldown_left <= 0.0


# ── 지뢰 ─────────────────────────────────────────────────────────


func throw_mine(target: Vector3) -> void:
	var mine := FriendlyMine.new()
	mine.name = "FriendlyMine_%d" % (mines_thrown + 1)
	mine.system = self
	mine.start_position = player.global_position + Vector3(0, 0.5, 0)
	mine.landing_position = Vector3(target.x, 0.1, target.z)
	host.add_child(mine)
	mines_thrown += 1


# ── 감시포탑 ─────────────────────────────────────────────────────


func place_turret(target: Vector3) -> void:
	# 동시 1기 제한 — 새로 설치하면 기존 것은 그 자리에서 부서진다.
	if is_instance_valid(active_turret):
		active_turret.call("force_destroy", "replaced")
	var turret := SalvageTurret.new()
	turret.name = "SalvageTurret"
	turret.system = self
	host.add_child(turret)
	turret.global_position = Vector3(target.x, 0.0, target.z)
	active_turret = turret
	turrets_placed += 1
	if host.hud != null and host.hud.has_method("push_toast"):
		host.hud.push_toast("감시포탑 가동 — %d초" % int(TURRET_LIFETIME), TEAL, 2.0)


func notify_turret_gone(reason: String) -> void:
	active_turret = null
	if host == null or host.hud == null or not host.hud.has_method("push_toast"):
		return
	if reason == "replaced":
		return
	host.hud.push_toast("포탑 가동 종료", TEAL_DIM, 1.8)


# ── 로켓 발사기 ──────────────────────────────────────────────────


func fire_rocket(target: Vector3) -> bool:
	if rocket_cooldown_left > 0.0:
		return false
	if GameState.get_heavy_gear_count("rocket_launcher") <= 0:
		return false
	if rocket_charges_left < 0:
		rocket_charges_left = ROCKET_CHARGES
	var rocket := PlayerRocket.new()
	rocket.name = "PlayerRocket_%d" % (rockets_fired + 1)
	rocket.system = self
	rocket.start_position = player.global_position + Vector3(0, 1.0, 0)
	rocket.impact_position = Vector3(target.x, 0.1, target.z)
	host.add_child(rocket)
	rockets_fired += 1
	rocket_charges_left -= 1
	rocket_cooldown_left = ROCKET_COOLDOWN
	_raise_noise(1.0)
	if rocket_charges_left <= 0:
		# 3발 소진 = 발사기 소멸. 다음 발사기는 새로 3발이다.
		GameState.consume_heavy_gear("rocket_launcher", 1)
		rocket_charges_left = -1
		if host.hud != null and host.hud.has_method("push_toast"):
			host.hud.push_toast("3발을 다 썼다 — 발사기를 버렸다", Color("#e2a35e"), 2.2)
	elif host.hud != null and host.hud.has_method("push_toast"):
		host.hud.push_toast("로켓 %d발 남음" % rocket_charges_left, TEAL, 1.2)
	return true


# ── 공용 폭발 처리 ───────────────────────────────────────────────


func apply_blast_to_hostiles(
	center: Vector3, radius: float, center_damage: int, edge_damage: int
) -> int:
	# 반경 안의 적(보스 포함 — enemy_director가 host.enemies에 넣는다)에게
	# 중심→가장자리 감쇠 피해. 플레이어·구조대상은 대상이 아니다(아군 화력).
	var damaged := 0
	if host == null:
		return 0
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy_value in enemies.duplicate():
		var enemy := enemy_value as Node3D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		var distance := offset.length()
		if distance > radius:
			continue
		if not _has_clear_blast_path(center, enemy):
			continue
		var falloff := lerpf(1.0, float(edge_damage) / maxf(1.0, float(center_damage)), distance / radius)
		var applied := maxi(1, roundi(float(center_damage) * falloff))
		var hit_direction := offset.normalized() if distance > 0.01 else Vector3.RIGHT
		_deal_hostile_hit(enemy, applied, hit_direction, center)
		damaged += 1
	return damaged


func _deal_hostile_hit(
	receiver: Node, applied_damage: int, hit_direction: Vector3, blast_center: Vector3
) -> void:
	# 수신자 인자 수가 다르다 — rocket_projectile.gd/boss_mine.gd의 분기 패턴 그대로.
	if receiver.has_method("take_hostile_hit"):
		if receiver.get_method_argument_count("take_hostile_hit") >= 5:
			receiver.call("take_hostile_hit", applied_damage, hit_direction, player, blast_center, "blast")
		elif receiver.get_method_argument_count("take_hostile_hit") >= 4:
			receiver.call("take_hostile_hit", applied_damage, hit_direction, player, blast_center)
		else:
			receiver.call("take_hostile_hit", applied_damage, hit_direction, player)
	elif receiver.has_method("take_hit"):
		receiver.call("take_hit", applied_damage, hit_direction)
	elif receiver.has_method("take_damage"):
		receiver.call("take_damage", applied_damage)


func _has_clear_blast_path(center: Vector3, body: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return true
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		center + Vector3(0.0, 0.35, 0.0),
		body.global_position + Vector3(0.0, 0.35, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


func _raise_noise(scale: float) -> void:
	# 폭발음은 도시가 듣는다 — 총성과 같은 긴장도 경로(소음 유인 시스템의 실체).
	if host != null and host.has_method("_add_raid_pressure"):
		host.call("_add_raid_pressure", RAID_EVENT_DIRECTOR.PRESSURE_PER_GUNSHOT * scale)


# 공용 연출 헬퍼 — 내부 클래스(지뢰·포탑·로켓)가 함께 쓴다. GDScript의 내부
# 클래스는 바깥 클래스의 상수는 보지만 static 함수는 못 부른다 — 그래서
# 형제 클래스로 묶는다(내부 클래스끼리는 이름으로 접근 가능).
class Fx:
	# 포탑 스프라이트 리컬러 캐시 — 프로세스당 한 번만 만든다(1254² 원본을 줄여서).
	static var _turret_texture: Texture2D

	static func make_glow_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(color.r, color.g, color.b, alpha)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return material


	static func get_turret_texture() -> Texture2D:
		# broken_sentry_salvage를 런타임 리컬러 — 채도를 죽이고(모노톤 고물),
		# modulate 청록 틴트는 스프라이트 쪽에서 얹는다("재생된" 느낌).
		if _turret_texture != null:
			return _turret_texture
		var image := SENTRY_TEXTURE.get_image()
		if image == null:
			return SENTRY_TEXTURE
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(512, 512, Image.INTERPOLATE_NEAREST)
		# 밝기를 조금 끌어올린다 — 청록 modulate가 얹히면 원본 그대로는 너무 어둡다.
		image.adjust_bcs(1.18, 1.06, 0.18)
		_turret_texture = ImageTexture.create_from_image(image)
		return _turret_texture


	static func spawn_explosion_fx(parent: Node3D, radius: float) -> void:
		# boss_mine의 폭발 연출 재활용(플래시 + 쇼크링 + 파편 + 연기). 불꽃은 불꽃색.
		var flash_material := make_glow_material(Color("#ff5a1f"), 8.5, 0.92)
		flash_material.no_depth_test = true
		var flash_shape := SphereMesh.new()
		flash_shape.radius = 0.42
		flash_shape.height = 0.84
		flash_shape.radial_segments = 18
		flash_shape.rings = 9
		flash_shape.material = flash_material
		var flash := MeshInstance3D.new()
		flash.name = "HeavyBlastFlash"
		flash.position.y = 0.22
		flash.mesh = flash_shape
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(flash)

		var shock_shape := TorusMesh.new()
		shock_shape.inner_radius = 0.34
		shock_shape.outer_radius = 0.46
		shock_shape.rings = 36
		shock_shape.ring_segments = 8
		shock_shape.material = flash_material
		var shock_ring := MeshInstance3D.new()
		shock_ring.name = "HeavyShockRing"
		shock_ring.position.y = 0.08
		shock_ring.mesh = shock_shape
		shock_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(shock_ring)

		var tween := parent.create_tween().set_parallel(true)
		tween.tween_property(flash, "scale", Vector3.ONE * radius * 1.55, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(flash, "transparency", 1.0, 0.38)
		tween.tween_property(shock_ring, "scale", Vector3.ONE * radius * 3.8, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(shock_ring, "transparency", 1.0, 0.42)

		for index in 14:
			var fragment_shape := BoxMesh.new()
			fragment_shape.size = Vector3(0.05, 0.035, 0.13)
			fragment_shape.material = flash_material
			var fragment := MeshInstance3D.new()
			fragment.mesh = fragment_shape
			fragment.position.y = 0.16
			fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(fragment)
			var angle := TAU * float(index) / 14.0
			var distance := radius * (0.72 + float(index % 3) * 0.15)
			var destination := Vector3(cos(angle) * distance, 0.18 + float(index % 4) * 0.11, sin(angle) * distance)
			var fragment_tween := fragment.create_tween().set_parallel(true)
			fragment_tween.tween_property(fragment, "position", destination, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			fragment_tween.tween_property(fragment, "transparency", 1.0, 0.5)

		var process_material := ParticleProcessMaterial.new()
		process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process_material.emission_sphere_radius = 0.22
		process_material.direction = Vector3.UP
		process_material.spread = 62.0
		process_material.initial_velocity_min = 0.9
		process_material.initial_velocity_max = 2.4
		process_material.gravity = Vector3(0.0, 0.75, 0.0)
		process_material.scale_min = 0.7
		process_material.scale_max = 1.65
		var smoke_gradient := Gradient.new()
		smoke_gradient.set_color(0, Color(0.28, 0.24, 0.2, 0.86))
		smoke_gradient.set_color(1, Color(0.055, 0.06, 0.06, 0.0))
		var smoke_ramp := GradientTexture1D.new()
		smoke_ramp.gradient = smoke_gradient
		process_material.color_ramp = smoke_ramp
		var smoke_material := StandardMaterial3D.new()
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_material.vertex_color_use_as_albedo = true
		smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var smoke_quad := QuadMesh.new()
		smoke_quad.size = Vector2(0.42, 0.42)
		smoke_quad.material = smoke_material
		var smoke := GPUParticles3D.new()
		smoke.name = "HeavyBlastSmoke"
		smoke.amount = 30
		smoke.lifetime = 0.76
		smoke.one_shot = true
		smoke.explosiveness = 0.92
		smoke.randomness = 0.42
		smoke.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 7, 10))
		smoke.process_material = process_material
		smoke.draw_pass_1 = smoke_quad
		parent.add_child(smoke)
		smoke.emitting = true


# ══════════════════════════════════════════════════════════════════
# 아군 지뢰 — boss_mine.gd의 상태기(비행→무장→대기→격발)와 연출을 재활용,
# 색은 청록(아군 식별), 격발 대상·피해 대상은 host.enemies.
# ══════════════════════════════════════════════════════════════════
class FriendlyMine extends Node3D:
	var system: DeployablesSystem
	var start_position := Vector3.ZERO
	var landing_position := Vector3.ZERO
	var flight_elapsed := 0.0
	var state_elapsed := 0.0
	var mine_state := "flight"
	var exploded := false

	var visual_root: Node3D
	var fuse_ring: MeshInstance3D
	var trigger_ring: MeshInstance3D
	var pulse_light: OmniLight3D
	var fuse_material: StandardMaterial3D

	func _ready() -> void:
		global_position = start_position
		add_to_group("friendly_mine")
		_build_visuals()

	func _physics_process(delta: float) -> void:
		if exploded:
			return
		match mine_state:
			"flight":
				_update_flight(delta)
			"arming":
				_update_arming(delta)
			"armed":
				_update_armed(delta)
			"triggered":
				_update_triggered(delta)

	func _update_flight(delta: float) -> void:
		flight_elapsed += delta
		var progress := clampf(flight_elapsed / MINE_FLIGHT_DURATION, 0.0, 1.0)
		var next_position := start_position.lerp(landing_position, progress)
		next_position.y += sin(progress * PI) * MINE_ARC_HEIGHT
		global_position = next_position
		visual_root.rotation.x += delta * 9.0
		visual_root.rotation.z += delta * 6.0
		if progress >= 1.0:
			mine_state = "arming"
			state_elapsed = 0.0
			global_position = landing_position
			visual_root.rotation = Vector3.ZERO
			fuse_ring.visible = true
			trigger_ring.visible = true
			pulse_light.visible = true

	func _update_arming(delta: float) -> void:
		# 착지 1.0s 무장 대기 — 점멸 링이 "아직 안 터진다"를 말한다.
		state_elapsed += delta
		var progress := clampf(state_elapsed / MINE_ARM_DELAY, 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(state_elapsed * 22.0)
		fuse_ring.scale = Vector3.ONE * (0.72 + progress * 0.28)
		fuse_ring.rotation.y += delta * 5.5
		_set_fuse_color(TEAL, lerpf(1.2, 4.2, blink))
		pulse_light.light_energy = lerpf(0.5, 1.8, blink)
		if progress >= 1.0:
			mine_state = "armed"
			state_elapsed = 0.0

	func _update_armed(delta: float) -> void:
		state_elapsed += delta
		var pulse := 0.88 + (0.5 + 0.5 * sin(state_elapsed * 5.0)) * 0.16
		fuse_ring.scale = Vector3.ONE * pulse
		fuse_ring.rotation.y += delta * 2.2
		trigger_ring.scale = Vector3.ONE * (0.97 + sin(state_elapsed * 3.0) * 0.025)
		_set_fuse_color(TEAL, 2.6 + pulse * 1.2)
		pulse_light.light_energy = 0.9 + pulse * 0.6
		if _hostile_in_trigger_range():
			mine_state = "triggered"
			state_elapsed = 0.0

	func _hostile_in_trigger_range() -> bool:
		if system == null or system.host == null:
			return false
		var enemies: Array = system.host.get("enemies") if system.host.get("enemies") != null else []
		for enemy_value in enemies:
			var enemy := enemy_value as Node3D
			if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dying")):
				continue
			var offset := enemy.global_position - global_position
			offset.y = 0.0
			if offset.length() <= MINE_TRIGGER_RADIUS:
				return true
		return false

	func _update_triggered(delta: float) -> void:
		state_elapsed += delta
		var progress := clampf(state_elapsed / MINE_TRIGGER_FUSE, 0.0, 1.0)
		_set_fuse_color(Color("#c9fff2"), lerpf(5.0, 10.0, progress))
		pulse_light.light_energy = lerpf(2.5, 6.0, progress)
		if progress >= 1.0:
			detonate()

	func detonate() -> void:
		if exploded:
			return
		exploded = true
		if system != null:
			system.mine_explosions += 1
			system.apply_blast_to_hostiles(
				global_position,
				MINE_BLAST_RADIUS,
				MINE_DAMAGE_CENTER,
				MINE_DAMAGE_EDGE
			)
			system._raise_noise(0.8)
		Fx.spawn_explosion_fx(self, MINE_BLAST_RADIUS)
		SFX.play("shotgun_shot", global_position, -3.0, 0.62)
		visual_root.visible = false
		trigger_ring.visible = false
		pulse_light.visible = false
		if get_tree() != null:
			get_tree().create_timer(0.85).timeout.connect(queue_free)
		else:
			queue_free()

	func _build_visuals() -> void:
		# boss_mine의 본체(원판+허브) + 링 연출, 아군 청록 팔레트.
		visual_root = Node3D.new()
		visual_root.name = "MineVisual"
		add_child(visual_root)

		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = Color("#2c3b39")
		body_material.metallic = 0.82
		body_material.roughness = 0.3
		var body_shape := CylinderMesh.new()
		body_shape.top_radius = 0.25
		body_shape.bottom_radius = 0.29
		body_shape.height = 0.12
		body_shape.radial_segments = 16
		body_shape.material = body_material
		var body_mesh := MeshInstance3D.new()
		body_mesh.name = "MineBody"
		body_mesh.position.y = 0.06
		body_mesh.mesh = body_shape
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_root.add_child(body_mesh)

		fuse_material = Fx.make_glow_material(TEAL, 3.0, 0.92)
		var fuse_shape := TorusMesh.new()
		fuse_shape.inner_radius = 0.11
		fuse_shape.outer_radius = 0.16
		fuse_shape.rings = 24
		fuse_shape.ring_segments = 7
		fuse_shape.material = fuse_material
		fuse_ring = MeshInstance3D.new()
		fuse_ring.name = "ArmingFuse"
		fuse_ring.position.y = 0.185
		fuse_ring.mesh = fuse_shape
		fuse_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fuse_ring.visible = false
		visual_root.add_child(fuse_ring)

		var trigger_material := Fx.make_glow_material(TEAL_DIM, 1.8, 0.3)
		var trigger_shape := TorusMesh.new()
		trigger_shape.inner_radius = MINE_TRIGGER_RADIUS - 0.05
		trigger_shape.outer_radius = MINE_TRIGGER_RADIUS
		trigger_shape.rings = 40
		trigger_shape.ring_segments = 8
		trigger_shape.material = trigger_material
		trigger_ring = MeshInstance3D.new()
		trigger_ring.name = "ProximityRing"
		trigger_ring.position.y = 0.025
		trigger_ring.mesh = trigger_shape
		trigger_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trigger_ring.visible = false
		add_child(trigger_ring)

		pulse_light = OmniLight3D.new()
		pulse_light.name = "FuseLight"
		pulse_light.position.y = 0.4
		pulse_light.light_color = TEAL
		pulse_light.light_energy = 1.0
		pulse_light.omni_range = 2.4
		pulse_light.shadow_enabled = false
		pulse_light.visible = false
		add_child(pulse_light)

	func _set_fuse_color(color: Color, energy: float) -> void:
		fuse_material.albedo_color = Color(color.r, color.g, color.b, 0.96)
		fuse_material.emission = color
		fuse_material.emission_energy_multiplier = energy
		pulse_light.light_color = color


# ══════════════════════════════════════════════════════════════════
# 재생 감시포탑 — 배치형 정적 노드. 45초 가동 또는 HP 소진 시 파괴.
# 아트: broken_sentry_salvage 런타임 리컬러(채도 다운) + 청록 modulate.
# ══════════════════════════════════════════════════════════════════
class SalvageTurret extends Node3D:
	var system: DeployablesSystem
	var lifetime_left := TURRET_LIFETIME
	var health := TURRET_HP
	var fire_timer := 0.6
	var destroyed := false
	var sprite: Sprite3D
	var status_ring: MeshInstance3D
	var ring_material: StandardMaterial3D
	var muzzle_flash: OmniLight3D
	var elapsed := 0.0

	func _ready() -> void:
		add_to_group("friendly_turret")
		_build_visuals()

	func _build_visuals() -> void:
		# 접지: 생산기 기물과 같은 방식 — 중앙 정렬 스프라이트를 절반 높이 월드 Y에.
		var texture := Fx.get_turret_texture()
		# 스프라이트 여백을 감안한 폭 — 1.9는 화면에서 고양이보다 작아 보였다.
		var world_width := 2.3
		sprite = Sprite3D.new()
		sprite.name = "TurretSprite"
		sprite.texture = texture
		sprite.pixel_size = world_width / maxf(1.0, float(texture.get_width()))
		sprite.position = Vector3(0, world_width * 0.5, 0)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.transparent = true
		sprite.no_depth_test = true
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.render_priority = 8
		# 청록 틴트 — "고물을 재생했다"는 아군 식별색.
		sprite.modulate = Color(0.66, 0.98, 0.92, 1.0)
		add_child(sprite)

		ring_material = Fx.make_glow_material(TEAL, 2.2, 0.34)
		var ring_shape := TorusMesh.new()
		ring_shape.inner_radius = 0.52
		ring_shape.outer_radius = 0.6
		ring_shape.rings = 32
		ring_shape.ring_segments = 8
		ring_shape.material = ring_material
		status_ring = MeshInstance3D.new()
		status_ring.name = "TurretStatusRing"
		status_ring.position.y = 0.03
		status_ring.mesh = ring_shape
		status_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(status_ring)

		muzzle_flash = OmniLight3D.new()
		muzzle_flash.name = "TurretMuzzleFlash"
		muzzle_flash.position = Vector3(0, 1.15, 0)
		muzzle_flash.light_color = Color("#ffd27a")
		muzzle_flash.light_energy = 0.0
		muzzle_flash.omni_range = 3.2
		muzzle_flash.shadow_enabled = false
		add_child(muzzle_flash)

	func _physics_process(delta: float) -> void:
		if destroyed:
			return
		elapsed += delta
		lifetime_left -= delta
		muzzle_flash.light_energy = maxf(0.0, muzzle_flash.light_energy - delta * 22.0)
		# 잔여 시간 링 — 끝이 가까울수록 어두워지고 빨리 깜빡인다.
		var life_ratio := clampf(lifetime_left / TURRET_LIFETIME, 0.0, 1.0)
		var blink := 1.0 if life_ratio > 0.18 else (0.5 + 0.5 * sin(elapsed * 14.0))
		ring_material.emission_energy_multiplier = lerpf(0.6, 2.4, life_ratio) * blink
		if lifetime_left <= 0.0:
			force_destroy("expired")
			return
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_timer = TURRET_FIRE_INTERVAL
			_try_fire()

	func _try_fire() -> void:
		var target := _find_target()
		if target == null:
			return
		var muzzle := global_position + Vector3(0, 1.05, 0)
		var aim := target.global_position + Vector3(0, 0.55, 0) - muzzle
		if aim.length_squared() < 0.001:
			return
		var direction := Vector3(aim.x, 0.0, aim.z).normalized()
		var bullet := Area3D.new()
		bullet.name = "TurretBullet"
		bullet.set_script(TurretBullet)
		bullet.set("direction", direction)
		bullet.set("source_body", self)
		bullet.set("damage", TURRET_BULLET_DAMAGE)
		bullet.set("critical_chance", 0.0)
		bullet.set("effective_range", TURRET_RANGE)
		bullet.set("maximum_range", TURRET_RANGE + 4.0)
		bullet.position = muzzle + direction * 0.4
		get_parent().add_child(bullet)
		if system != null:
			system.turret_shots_fired += 1
		muzzle_flash.light_energy = 2.4
		SFX.play("pistol_shot", muzzle, -9.0, 1.06)

	func _find_target() -> Node3D:
		if system == null or system.host == null:
			return null
		var enemies: Array = system.host.get("enemies") if system.host.get("enemies") != null else []
		var best: Node3D = null
		var best_distance := TURRET_RANGE
		for enemy_value in enemies:
			var enemy := enemy_value as Node3D
			if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dying")):
				continue
			var offset := enemy.global_position - global_position
			offset.y = 0.0
			var distance := offset.length()
			if distance > best_distance:
				continue
			if not _has_line_of_sight(enemy):
				continue
			best = enemy
			best_distance = distance
		return best

	func _has_line_of_sight(enemy: Node3D) -> bool:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 1.05, 0),
			enemy.global_position + Vector3(0, 0.55, 0),
			COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
		)
		var hit := space.intersect_ray(query)
		return hit.is_empty() or hit.get("collider") == enemy

	func take_hostile_hit(amount: int, _hit_direction: Vector3, _attacker = null) -> void:
		# v1: 적 총알은 포탑을 조준하지 않는다 — 폭발 스플래시가 유일한 피해원.
		if destroyed:
			return
		health -= maxi(0, amount)
		if health <= 0:
			force_destroy("destroyed")

	func take_hit(amount: int, hit_direction: Vector3) -> void:
		take_hostile_hit(amount, hit_direction)

	func force_destroy(reason: String) -> void:
		if destroyed:
			return
		destroyed = true
		# 부서지는 연출 — 스프라이트가 주저앉고 파편이 튄다.
		var flash_material := Fx.make_glow_material(TEAL, 4.5, 0.8)
		for index in 8:
			var fragment_shape := BoxMesh.new()
			fragment_shape.size = Vector3(0.07, 0.05, 0.12)
			fragment_shape.material = flash_material
			var fragment := MeshInstance3D.new()
			fragment.mesh = fragment_shape
			fragment.position.y = 0.7
			fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fragment)
			var angle := TAU * float(index) / 8.0
			var destination := Vector3(cos(angle) * 0.9, 0.08, sin(angle) * 0.9)
			var fragment_tween := fragment.create_tween().set_parallel(true)
			fragment_tween.tween_property(fragment, "position", destination, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			fragment_tween.tween_property(fragment, "transparency", 1.0, 0.55)
		if is_instance_valid(sprite):
			var collapse := sprite.create_tween()
			collapse.set_parallel(true)
			collapse.tween_property(sprite, "position:y", sprite.position.y * 0.4, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			collapse.tween_property(sprite, "modulate", Color(0.3, 0.36, 0.34, 0.0), 0.5)
		if is_instance_valid(status_ring):
			status_ring.visible = false
		if system != null:
			system.notify_turret_gone(reason)
		if get_tree() != null:
			get_tree().create_timer(0.7).timeout.connect(queue_free)
		else:
			queue_free()


# 포탑 탄 — 플레이어 탄과 같은 팀 판정(bullet_projectile 파생)이되,
# ① 히트마커를 울리지 않고 ② 플레이어에게는 절대 피해를 주지 않는다.
class TurretBullet extends "res://scripts/bullet_projectile.gd":
	func _report_player_hit(_body: Object) -> void:
		# 포탑의 명중은 내 손맛이 아니다 — HUD 히트마커 없음.
		pass

	func _apply_hit(body: Object, trajectory_origin: Vector3 = Vector3.INF) -> bool:
		# 플레이어(및 그 부모 main의 take_hit 폴백)로는 절대 흐르지 않게 선차단.
		if body is Node and ((body as Node).is_in_group("player")):
			queue_free()
			return false
		return super._apply_hit(body, trajectory_origin)


# ══════════════════════════════════════════════════════════════════
# 플레이어 로켓 — rocket_projectile.gd의 비행·예고·폭발 연출을 파생하되
# 소속이 반대다: 적·보스에 피해, 플레이어 무피해. 속도 14, 반경 3.2.
# ══════════════════════════════════════════════════════════════════
class PlayerRocket extends Node3D:
	var system: DeployablesSystem
	var start_position := Vector3.ZERO
	var impact_position := Vector3.ZERO
	var flight_elapsed := 0.0
	var flight_duration := 1.0
	var detonated := false
	var target_marker: Node3D
	var rocket_visual: Node3D

	func _ready() -> void:
		global_position = start_position
		var flat_distance := Vector2(
			impact_position.x - start_position.x, impact_position.z - start_position.z
		).length()
		flight_duration = maxf(0.22, flat_distance / ROCKET_SPEED)
		target_marker = TELEGRAPH.show_landing_circle(
			impact_position, ROCKET_BLAST_RADIUS, flight_duration + 0.3, get_parent()
		)
		if target_marker != null:
			target_marker.name = "PlayerRocketTelegraph_%d" % get_instance_id()
		_build_rocket_visual()

	func _physics_process(delta: float) -> void:
		if detonated:
			return
		flight_elapsed += delta
		var progress := clampf(flight_elapsed / flight_duration, 0.0, 1.0)
		var next_position := start_position.lerp(impact_position, progress)
		next_position.y += sin(progress * PI) * ROCKET_ARC_HEIGHT
		# 엄폐물에 막히면 그 자리에서 터진다(rocket_projectile과 같은 규칙).
		var blocker := _find_flight_blocker(global_position, next_position)
		if not blocker.is_empty():
			global_position = blocker.get("position", next_position) as Vector3
			impact_position = global_position
			_detonate()
			return
		var travel := next_position - global_position
		global_position = next_position
		if travel.length_squared() > 0.0001:
			look_at(global_position + travel.normalized(), Vector3.UP)
		if progress >= 1.0:
			_detonate()

	func _find_flight_blocker(from: Vector3, to: Vector3) -> Dictionary:
		if from.distance_squared_to(to) < 0.000001:
			return {}
		var query := PhysicsRayQueryParameters3D.create(
			from, to, COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
		)
		return get_world_3d().direct_space_state.intersect_ray(query)

	func _build_rocket_visual() -> void:
		# rocket_projectile의 몸통+화염 연출 재활용(아군 화염은 청록빛).
		rocket_visual = Node3D.new()
		rocket_visual.name = "RocketVisual"
		add_child(rocket_visual)
		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = Color("#4f514b")
		body_material.metallic = 0.72
		body_material.roughness = 0.34
		var body_mesh := CylinderMesh.new()
		body_mesh.top_radius = 0.12
		body_mesh.bottom_radius = 0.12
		body_mesh.height = 0.62
		body_mesh.radial_segments = 12
		body_mesh.material = body_material
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.rotation.x = PI * 0.5
		rocket_visual.add_child(body)
		var flame_material := Fx.make_glow_material(TEAL, 6.0, 0.85)
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.12
		flame_mesh.height = 0.36
		flame_mesh.material = flame_material
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh
		flame.position.z = 0.38
		rocket_visual.add_child(flame)

	func _detonate() -> void:
		if detonated:
			return
		detonated = true
		global_position = impact_position
		if system != null:
			system.apply_blast_to_hostiles(
				impact_position,
				ROCKET_BLAST_RADIUS,
				ROCKET_DAMAGE_CENTER,
				roundi(float(ROCKET_DAMAGE_CENTER) * ROCKET_DAMAGE_EDGE_RATIO)
			)
			system._raise_noise(1.2)
		Fx.spawn_explosion_fx(self, ROCKET_BLAST_RADIUS)
		SFX.play("shotgun_shot", impact_position, -1.5, 0.55)
		if is_instance_valid(target_marker):
			TELEGRAPH.release(target_marker)
			target_marker = null
		if is_instance_valid(rocket_visual):
			rocket_visual.visible = false
		if get_tree() != null:
			get_tree().create_timer(0.55).timeout.connect(queue_free)
		else:
			queue_free()
