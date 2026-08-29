extends Area3D

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const SPEED := 46.0
const MAX_LIFETIME := 1.15
const PROJECTILE_COLLISION_RADIUS := 0.26
const DEFAULT_TARGET_HIT_RADIUS := 0.62
# 총알이 최소 이만큼 날아가기 전에는 피해를 주지 않는다. 총구에서 나오자마자
# 같은 프레임에 명중 처리되면 "안 보이는 탄에 맞았다"는 인상을 준다. 이 거리
# 만큼은 반드시 한 번은 렌더링되므로, 무엇에 맞았는지 눈으로 보게 된다.
# 적탄은 0.85m를 날아야 무장된다(총구에서 순간적으로 맞는 '안 보이는 피격' 방지).
# 아군탄까지 같은 값이면 몸에 붙은 근접 적에게 전탄이 통과해 총이 무용지물이 된다.
const ARM_DISTANCE := 0.85
const FRIENDLY_ARM_DISTANCE := 0.4

var direction := Vector3.FORWARD
var source_body: Node3D
var damage := 20
var hostile := false
var critical_chance := 0.0
var critical_multiplier := 1.65
var last_hit_was_critical := false
var last_hit_damage_scale := 1.0
var last_hit_grade := "normal"
var lifetime := 0.0
var penetrations_remaining := 0
var effective_range := 18.0
var maximum_range := 36.0
var minimum_damage_multiplier := 0.35
var spawn_position := Vector3.ZERO
var processed_body_ids: Dictionary = {}
var last_motion_origin := Vector3.INF
# ── 약점(헤드샷) 판정 입력 ──────────────────────────────────────────
# 탄은 수평으로 날아가므로 충돌점 y로는 머리를 알 수 없다. 대신 '조준 높이'를 탄에
# 싣는다: 마우스 조준은 발사 순간의 화면 레이(aim_ray_*) — 맞은 적의 수직축과 레이의
# 최근접점 y를 적의 발 위치·월드 높이(get_world_height)로 나눠 비율을 얻는다. 모바일은
# 에임 어시스트가 정한 높이 비율(aim_height_ratio: 몸 0.5 / 정조준 상승 0.86)을 그대로.
var aim_ray_origin := Vector3.INF
var aim_ray_direction := Vector3.ZERO
var aim_height_ratio := -1.0
var last_hit_zone := "body"
var last_hit_height_ratio := -1.0


func _ready() -> void:
	add_to_group("projectile")
	collision_layer = (
		COLLISION_PROFILES.PLAYER_PROJECTILE_LAYER
		if not hostile
		else COLLISION_PROFILES.ENEMY_PROJECTILE_LAYER
	)
	collision_mask = COLLISION_PROFILES.PROJECTILE_MASK
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_neon_projectile()
	last_motion_origin = global_position
	spawn_position = global_position

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.18, 0.48)
	collision.shape = shape
	add_child(collision)

	# 방향이 0이면 look_at이 "같은 위치" 오류를 뿜는다(보스 처치 직후 적이 자기
	# 자리를 향해 쏘는 프레임에 발생, 오류 스팸으로 프레임이 멈춘 사례). 정면으로 보정.
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	look_at(global_position + direction, Vector3.UP)


func _build_neon_projectile() -> void:
	var glow_colors := (
		[Color(1.0, 0.08, 0.02, 0.12), Color(1.0, 0.22, 0.04, 0.38), Color(1.0, 0.82, 0.55, 1.0)]
		if hostile
		else [Color(1.0, 0.46, 0.02, 0.12), Color(1.0, 0.68, 0.04, 0.42), Color(1.0, 0.96, 0.68, 1.0)]
	)
	var emissions := (
		[Color("#ff240e"), Color("#ff4b16"), Color("#fff0d0")]
		if hostile
		else [Color("#ff9a12"), Color("#ffc52e"), Color("#fff7b0")]
	)
	var widths := [0.18, 0.10, 0.045]
	var lengths := [0.88, 0.70, 0.54]
	var energies := [1.8, 4.0, 7.5]
	for layer_index in widths.size():
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = glow_colors[layer_index]
		material.emission_enabled = true
		material.emission = emissions[layer_index]
		material.emission_energy_multiplier = energies[layer_index]
		material.no_depth_test = layer_index < 2
		var mesh := BoxMesh.new()
		mesh.size = Vector3(widths[layer_index], widths[layer_index], lengths[layer_index])
		mesh.material = material
		var glow_layer := MeshInstance3D.new()
		glow_layer.name = "ProjectileGlow%d" % layer_index
		glow_layer.mesh = mesh
		glow_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow_layer)

	var trail_material := StandardMaterial3D.new()
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.albedo_color = Color(1.0, 0.2, 0.04, 0.75) if hostile else Color(1.0, 0.72, 0.08, 0.75)
	trail_material.emission_enabled = true
	trail_material.emission = Color("#ff3218") if hostile else Color("#ffc62e")
	trail_material.emission_energy_multiplier = 4.2
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_material.no_depth_test = true
	var trail_quad := QuadMesh.new()
	trail_quad.size = Vector2(0.09, 0.09)
	trail_quad.material = trail_material
	var trail_process := ParticleProcessMaterial.new()
	trail_process.direction = Vector3(0, 0, 1)
	trail_process.spread = 10.0
	trail_process.initial_velocity_min = 0.0
	trail_process.initial_velocity_max = 0.45
	trail_process.gravity = Vector3.ZERO
	trail_process.scale_min = 0.35
	trail_process.scale_max = 1.0
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(1.0, 0.82, 0.28, 0.74) if not hostile else Color(1.0, 0.28, 0.12, 0.74))
	trail_gradient.set_color(1, Color(1.0, 0.3, 0.02, 0.0))
	var trail_ramp := GradientTexture1D.new()
	trail_ramp.gradient = trail_gradient
	trail_process.color_ramp = trail_ramp
	var trail := GPUParticles3D.new()
	trail.name = "NeonTrail"
	trail.amount = 22
	trail.lifetime = 0.16
	trail.randomness = 0.35
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	trail.process_material = trail_process
	trail.draw_pass_1 = trail_quad
	add_child(trail)


func _physics_process(delta: float) -> void:
	last_motion_origin = global_position
	var next_position := global_position + direction * SPEED * delta
	var exclusions: Array[RID] = []
	if is_instance_valid(source_body) and source_body is CollisionObject3D:
		exclusions.append((source_body as CollisionObject3D).get_rid())
	for body_id in processed_body_ids:
		var processed_body := instance_from_id(int(body_id))
		if processed_body is CollisionObject3D:
			exclusions.append((processed_body as CollisionObject3D).get_rid())
	var armed := spawn_position.distance_to(global_position) >= (ARM_DISTANCE if hostile else FRIENDLY_ARM_DISTANCE)
	var hit := _find_swept_hit(global_position, next_position, exclusions) if armed else {}
	if not hit.is_empty():
		var continues := _apply_hit(hit.get("collider"), global_position)
		if continues:
			global_position = (hit.get("position") as Vector3) + direction * 0.12
		return
	global_position = next_position
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == source_body:
		return
	if spawn_position.distance_to(global_position) < (ARM_DISTANCE if hostile else FRIENDLY_ARM_DISTANCE):
		return
	_apply_hit(body, last_motion_origin)


func _find_swept_hit(from: Vector3, to: Vector3, exclusions: Array[RID]) -> Dictionary:
	var side := Vector3(-direction.z, 0.0, direction.x)
	if side.length_squared() <= 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var offsets := [
		Vector3.ZERO,
		side * PROJECTILE_COLLISION_RADIUS * 0.5,
		-side * PROJECTILE_COLLISION_RADIUS * 0.5,
		side * PROJECTILE_COLLISION_RADIUS,
		-side * PROJECTILE_COLLISION_RADIUS,
	]
	var closest_hit := {}
	var closest_distance := INF
	for offset in offsets:
		var query := PhysicsRayQueryParameters3D.create(from + offset, to + offset, collision_mask)
		query.exclude = exclusions
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_distance := from.distance_squared_to(hit.get("position") as Vector3)
		if hit_distance < closest_distance:
			closest_distance = hit_distance
			closest_hit = hit
	return closest_hit


func _get_hit_damage_scale(body: Object, trajectory_origin: Vector3) -> float:
	if not body is Node3D or trajectory_origin == Vector3.INF:
		last_hit_grade = "normal"
		return 1.0
	var target_center := (body as Node3D).global_position
	if body.has_method("get_projectile_hit_center"):
		target_center = body.call("get_projectile_hit_center") as Vector3
	var target_radius := DEFAULT_TARGET_HIT_RADIUS
	if body.has_method("get_projectile_hit_radius"):
		target_radius = maxf(0.05, float(body.call("get_projectile_hit_radius")))
	var flat_direction := direction
	flat_direction.y = 0.0
	var to_target := target_center - trajectory_origin
	to_target.y = 0.0
	var lateral_distance := absf(flat_direction.normalized().cross(to_target).y)
	var normalized_offset := lateral_distance / target_radius
	if normalized_offset <= 0.28:
		last_hit_grade = "center"
		return 1.3
	if normalized_offset <= 0.72:
		last_hit_grade = "normal"
		return 1.0
	last_hit_grade = "graze"
	return 0.65


func _resolve_hit_zone(body: Object) -> String:
	# "head" 또는 "body". 적이 높이 API(get_world_height 등)를 내놓을 때만 판정한다.
	last_hit_height_ratio = -1.0
	if hostile or not body is Node3D:
		return "body"
	if not (
		body.has_method("get_world_height")
		and body.has_method("get_feet_world_y")
		and body.has_method("get_head_zone_ratio")
	):
		return "body"
	var height := maxf(0.2, float(body.call("get_world_height")))
	var feet_y := float(body.call("get_feet_world_y"))
	var head_zone := clampf(float(body.call("get_head_zone_ratio")), 0.05, 0.6)
	var ratio := -1.0
	if aim_height_ratio >= 0.0:
		ratio = aim_height_ratio
	elif aim_ray_origin != Vector3.INF and aim_ray_direction.length_squared() > 0.0001:
		ratio = _aim_ray_height_ratio(body as Node3D, feet_y, height)
	if ratio < 0.0:
		return "body"
	last_hit_height_ratio = ratio
	# 상단 head_zone(기본 28%) 안이면 머리. 머리 위 살짝(15%)까지는 관용 — 스프라이트
	# 머리 윗선 근처를 겨눈 탄이 몸으로 떨어지면 억울하다.
	return "head" if ratio >= 1.0 - head_zone and ratio <= 1.15 else "body"


func _aim_ray_height_ratio(target_node: Node3D, feet_y: float, height: float) -> float:
	# 화면 레이와 적 수직축의 수평 최근접점 — 거기서의 레이 y가 '겨눈 높이'다.
	# 커서가 실루엣(명중 반경) 밖이면 이 적을 겨눈 게 아니다 → 판정 없음(-1).
	var axis := Vector2(target_node.global_position.x, target_node.global_position.z)
	var origin_xz := Vector2(aim_ray_origin.x, aim_ray_origin.z)
	var direction_xz := Vector2(aim_ray_direction.x, aim_ray_direction.z)
	if direction_xz.length_squared() <= 0.000001:
		return -1.0
	var radius := DEFAULT_TARGET_HIT_RADIUS
	if target_node.has_method("get_projectile_hit_radius"):
		radius = maxf(0.05, float(target_node.call("get_projectile_hit_radius")))
	var t := (axis - origin_xz).dot(direction_xz) / direction_xz.length_squared()
	var closest := origin_xz + direction_xz * t
	if closest.distance_to(axis) > radius:
		return -1.0
	var aim_y := aim_ray_origin.y + aim_ray_direction.y * t
	return (aim_y - feet_y) / height


func _apply_hit(body: Object, trajectory_origin: Vector3 = Vector3.INF) -> bool:
	if body == null:
		queue_free()
		return false
	if _shares_source_faction(body):
		return true
	# 주홍 동행 — 아군 오사 방지(양방향 통과). 아군 탄은 동행을 통과하고,
	# 동행(그룹 "companion")이 쏜 탄은 플레이어를 통과한다. 적탄(hostile)은 그대로.
	if not hostile and body is Node:
		var hit_node := body as Node
		if hit_node.is_in_group("companion"):
			return true
		if (
			hit_node.is_in_group("player")
			and is_instance_valid(source_body)
			and source_body.is_in_group("companion")
		):
			return true
	var body_id := body.get_instance_id()
	if processed_body_ids.has(body_id):
		return true
	var damaged := false
	last_hit_damage_scale = _get_hit_damage_scale(body, trajectory_origin)
	# 약점 — 머리면 명중 등급 대신 "head"를 넘긴다(피해 배율·팝 색·소리는 적이 정한다).
	last_hit_zone = _resolve_hit_zone(body)
	var reported_grade := "head" if last_hit_zone == "head" else last_hit_grade
	var adjusted_damage := maxi(1, roundi(float(damage) * last_hit_damage_scale))
	var traveled_distance := spawn_position.distance_to(global_position)
	var range_factor := 1.0
	if traveled_distance > effective_range:
		range_factor = lerpf(
			1.0,
			minimum_damage_multiplier,
			clampf(inverse_lerp(effective_range, maximum_range, traveled_distance), 0.0, 1.0)
		)
	adjusted_damage = maxi(1, roundi(float(adjusted_damage) * range_factor))
	last_hit_was_critical = not hostile and randf() < critical_chance
	if body != null and not hostile and body.has_method("take_projectile_hit"):
		body.call(
			"take_projectile_hit",
			adjusted_damage,
			direction,
			last_hit_was_critical,
			critical_multiplier,
			reported_grade,
			source_body
		)
		damaged = true
	elif body != null and hostile and body.has_method("take_hostile_hit"):
		body.call("take_hostile_hit", adjusted_damage, direction, source_body)
		damaged = true
	elif body != null and body.has_method("take_hit"):
		body.call("take_hit", adjusted_damage, direction)
		damaged = true
	elif body != null and body.has_method("take_damage"):
		body.call("take_damage", adjusted_damage)
		damaged = true
	elif body is Node and (body as Node).get_parent() != null:
		var parent := (body as Node).get_parent()
		if not hostile and parent.has_method("take_projectile_hit"):
			parent.call(
				"take_projectile_hit",
				adjusted_damage,
				direction,
				last_hit_was_critical,
				critical_multiplier,
				reported_grade,
				source_body
			)
			damaged = true
		elif hostile and parent.has_method("take_hostile_hit"):
			parent.call("take_hostile_hit", adjusted_damage, direction, source_body)
			damaged = true
		elif parent.has_method("take_hit"):
			parent.call("take_hit", adjusted_damage, direction)
			damaged = true
		elif parent.has_method("take_damage"):
			parent.call("take_damage", adjusted_damage)
			damaged = true
	processed_body_ids[body_id] = true
	# 엄폐 v2 — 탄이 낮은 엄폐물의 탄막 상자에 '물리적으로' 막힌 경우에도, 그 뒤에
	# 웅크린 대상이 있으면 같은 차단 피드백(스파크+"막힘")을 띄운다. 판정 경로
	# (take_hostile_hit/take_projectile_hit의 차단)와 물리 경로의 언어를 통일한다.
	if not damaged and body is Node and (body as Node).is_in_group("projectile_blocker"):
		_notify_cover_block()
	_spawn_impact_flash()
	# 동행(주홍) 탄의 명중은 플레이어 히트마커·셰이크를 울리지 않는다 — 내 사격만.
	var companion_shot := is_instance_valid(source_body) and source_body.is_in_group("companion")
	if damaged and not hostile and not companion_shot:
		_report_player_hit(body, adjusted_damage)
	if damaged and not hostile and penetrations_remaining > 0:
		penetrations_remaining -= 1
		return true
	queue_free()
	return false


func _notify_cover_block() -> void:
	# 스파크·라벨은 CoverSystem이 0.25s 스로틀로 관리한다 — 여기선 후보만 거른다.
	if not is_inside_tree():
		return
	if hostile:
		var host := get_tree().get_first_node_in_group("raid_host")
		if host == null:
			return
		var cover_system = host.get("cover_system")
		if cover_system == null:
			return
		if str(cover_system.call("get_state")) != "covered":
			return
		if not bool(cover_system.call("is_covered_from", spawn_position)):
			return
		CoverSystem.spawn_block_fx(self, global_position)
		return
	for enemy in get_tree().get_nodes_in_group("raid_enemy"):
		if not enemy is Node3D or not enemy.has_method("_cover_blocks_shot_from"):
			continue
		if (enemy as Node3D).global_position.distance_to(global_position) > 2.6:
			continue
		if bool(enemy.call("_cover_blocks_shot_from", source_body, direction)):
			CoverSystem.spawn_block_fx(self, global_position)
			return


func _report_player_hit(body: Object, applied_damage: int = 0) -> void:
	# 히트마커: 내 탄이 무언가를 맞힌 순간을 HUD에 알린다. 처치면 X로 커진다.
	# 피해량·약점·크리티컬도 함께 넘긴다 — 명중 마이크로 셰이크가 피해에 비례한다.
	var scene := get_tree().get_first_node_in_group("raid_host")
	if scene == null:
		scene = get_tree().current_scene
	if scene == null or not scene.has_method("notify_player_projectile_hit"):
		return
	if body is Node3D:
		scene.call(
			"notify_player_projectile_hit",
			(body as Node3D).global_position,
			bool(body.get("dying")),
			applied_damage,
			last_hit_zone,
			last_hit_was_critical
		)


func _shares_source_faction(body: Object) -> bool:
	if not is_instance_valid(source_body) or not source_body.has_method("get_faction_id"):
		return false
	var hit_actor := body
	if not hit_actor.has_method("get_faction_id") and body is Node and (body as Node).get_parent() != null:
		hit_actor = (body as Node).get_parent()
	return (
		hit_actor.has_method("get_faction_id")
		and str(hit_actor.call("get_faction_id")) == str(source_body.call("get_faction_id"))
	)


func _spawn_impact_flash() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var impact := Node3D.new()
	impact.name = "ProjectileImpact"
	get_parent().add_child(impact)
	impact.global_position = global_position
	var color := Color("#ff3d1f") if hostile else Color("#ffd33d")
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, 0.88)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 5.5
	material.no_depth_test = true
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.055
	ring_mesh.outer_radius = 0.10
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 8
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.add_child(ring)
	var tween := impact.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.4, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.18)
	get_tree().create_timer(0.2).timeout.connect(impact.queue_free)
