extends Area3D

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const SPEED := 46.0
const MAX_LIFETIME := 1.15
const PROJECTILE_COLLISION_RADIUS := 0.26
const DEFAULT_TARGET_HIT_RADIUS := 0.62
# 총알이 최소 이만큼 날아가기 전에는 피해를 주지 않는다. 총구에서 나오자마자
# 같은 프레임에 명중 처리되면 "안 보이는 탄에 맞았다"는 인상을 준다. 이 거리
# 만큼은 반드시 한 번은 렌더링되므로, 무엇에 맞았는지 눈으로 보게 된다.
const ARM_DISTANCE := 0.85

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
	var armed := spawn_position.distance_to(global_position) >= ARM_DISTANCE
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
	if spawn_position.distance_to(global_position) < ARM_DISTANCE:
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


func _apply_hit(body: Object, trajectory_origin: Vector3 = Vector3.INF) -> bool:
	if body == null:
		queue_free()
		return false
	if _shares_source_faction(body):
		return true
	var body_id := body.get_instance_id()
	if processed_body_ids.has(body_id):
		return true
	var damaged := false
	last_hit_damage_scale = _get_hit_damage_scale(body, trajectory_origin)
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
			last_hit_grade,
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
				last_hit_grade,
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
	_spawn_impact_flash()
	if damaged and not hostile and penetrations_remaining > 0:
		penetrations_remaining -= 1
		return true
	queue_free()
	return false


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
