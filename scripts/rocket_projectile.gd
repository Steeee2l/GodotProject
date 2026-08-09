extends Node3D

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

signal exploded(world_position: Vector3, radius: float)

const FLIGHT_DURATION := 1.05
const ARC_HEIGHT := 4.6
const DEFAULT_BLAST_RADIUS := 2.65

var source_body: Node3D
var target_body: CharacterBody3D
var start_position := Vector3.ZERO
var impact_position := Vector3.ZERO
var damage := 34
var blast_radius := DEFAULT_BLAST_RADIUS
var flight_elapsed := 0.0
var target_marker: Node3D
var rocket_visual: Node3D
var detonated := false


func configure(
	owner_body: Node3D,
	player_target: CharacterBody3D,
	launch_position: Vector3,
	target_position: Vector3,
	rocket_damage: int,
	explosion_radius: float = DEFAULT_BLAST_RADIUS
) -> void:
	source_body = owner_body
	target_body = player_target
	start_position = launch_position
	impact_position = target_position
	impact_position.y = 0.1
	damage = rocket_damage
	blast_radius = explosion_radius


func _ready() -> void:
	global_position = start_position
	_build_target_marker()
	_build_rocket_visual()


func _physics_process(delta: float) -> void:
	if detonated:
		return
	flight_elapsed += delta
	var progress := clampf(flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)
	var next_position := start_position.lerp(impact_position, progress)
	next_position.y += sin(progress * PI) * ARC_HEIGHT
	var travel := next_position - global_position
	# 로켓은 예전에 아무것도 통과했다. 이제 비행 구간마다 엄폐물을 검사해
	# 부딪히면 그 자리에서 터진다. 버스 뒤에 숨으면 실제로 막힌다.
	var blocker := _find_flight_blocker(global_position, next_position)
	if not blocker.is_empty():
		global_position = blocker.get("position", next_position) as Vector3
		impact_position = global_position
		_detonate()
		return
	global_position = next_position
	if travel.length_squared() > 0.0001:
		look_at(global_position + travel.normalized(), Vector3.UP)
	_update_target_marker(progress)
	if progress >= 1.0:
		_detonate()


func _find_flight_blocker(from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		from, to, COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	)
	var exclusions: Array[RID] = []
	if is_instance_valid(source_body) and source_body is CollisionObject3D:
		exclusions.append((source_body as CollisionObject3D).get_rid())
	query.exclude = exclusions
	return get_world_3d().direct_space_state.intersect_ray(query)


func _has_blast_line_of_sight(body: CollisionObject3D) -> bool:
	# 폭심에서 대상까지 엄폐물이 가로막으면 폭풍 피해가 닿지 않는다.
	# 수류탄(_has_clear_blast_path)과 같은 규칙을 쓴다.
	var query := PhysicsRayQueryParameters3D.create(
		impact_position + Vector3(0.0, 0.35, 0.0),
		body.global_position + Vector3(0.0, 0.35, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	if is_instance_valid(source_body) and source_body is CollisionObject3D:
		query.exclude = [(source_body as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


func get_flight_progress() -> float:
	return clampf(flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)


func _build_target_marker() -> void:
	target_marker = Node3D.new()
	target_marker.name = "RocketImpactTelegraph"
	get_parent().add_child(target_marker)
	target_marker.global_position = impact_position + Vector3(0.0, 0.035, 0.0)

	var disc_material := StandardMaterial3D.new()
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.albedo_color = Color(0.85, 0.07, 0.025, 0.18)
	disc_material.emission_enabled = true
	disc_material.emission = Color("#ff351d")
	disc_material.emission_energy_multiplier = 1.6
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = blast_radius
	disc_mesh.bottom_radius = blast_radius
	disc_mesh.height = 0.025
	disc_mesh.radial_segments = 48
	disc_mesh.material = disc_material
	var disc := MeshInstance3D.new()
	disc.name = "DangerDisc"
	disc.mesh = disc_mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_marker.add_child(disc)

	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.3, 0.08, 0.92)
	ring_material.emission_enabled = true
	ring_material.emission = Color("#ff4b18")
	ring_material.emission_energy_multiplier = 4.2
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = blast_radius - 0.10
	ring_mesh.outer_radius = blast_radius
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 8
	ring_mesh.material = ring_material
	var ring := MeshInstance3D.new()
	ring.name = "DangerRing"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_marker.add_child(ring)


func _update_target_marker(progress: float) -> void:
	if not is_instance_valid(target_marker):
		return
	var pulse := 1.0 + sin(progress * TAU * 5.0) * 0.035
	target_marker.scale = Vector3.ONE * pulse
	var disc := target_marker.get_node_or_null("DangerDisc") as MeshInstance3D
	if disc != null:
		disc.transparency = lerpf(0.45, 0.0, progress)


func _build_rocket_visual() -> void:
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

	var flame_material := StandardMaterial3D.new()
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color(1.0, 0.24, 0.03, 0.85)
	flame_material.emission_enabled = true
	flame_material.emission = Color("#ff4a12")
	flame_material.emission_energy_multiplier = 6.0
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.12
	flame_mesh.height = 0.36
	flame_mesh.material = flame_material
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.position.z = 0.38
	rocket_visual.add_child(flame)

	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = Vector3(0.0, 0.0, 1.0)
	smoke_process.spread = 18.0
	smoke_process.initial_velocity_min = 0.35
	smoke_process.initial_velocity_max = 1.1
	smoke_process.gravity = Vector3(0.0, 0.35, 0.0)
	smoke_process.scale_min = 0.8
	smoke_process.scale_max = 1.8
	var smoke_gradient := Gradient.new()
	smoke_gradient.set_color(0, Color(0.22, 0.20, 0.18, 0.72))
	smoke_gradient.set_color(1, Color(0.08, 0.08, 0.08, 0.0))
	var smoke_ramp := GradientTexture1D.new()
	smoke_ramp.gradient = smoke_gradient
	smoke_process.color_ramp = smoke_ramp
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.22, 0.22)
	smoke_quad.material = smoke_material
	var smoke := GPUParticles3D.new()
	smoke.amount = 34
	smoke.lifetime = 0.72
	smoke.randomness = 0.4
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 12, 20))
	smoke.process_material = smoke_process
	smoke.draw_pass_1 = smoke_quad
	add_child(smoke)


func _detonate() -> void:
	if detonated:
		return
	detonated = true
	global_position = impact_position
	if is_instance_valid(target_body):
		var offset := target_body.global_position - impact_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= blast_radius and _has_blast_line_of_sight(target_body):
			var falloff := lerpf(1.0, 0.52, distance / blast_radius)
			var applied_damage := maxi(1, roundi(float(damage) * falloff))
			var hit_direction := offset.normalized() if distance > 0.01 else Vector3.RIGHT
			if target_body.has_method("take_hit"):
				target_body.call("take_hit", applied_damage, hit_direction)
			elif target_body.get_parent() != null and target_body.get_parent().has_method("take_hit"):
				target_body.get_parent().call("take_hit", applied_damage, hit_direction)
	_spawn_explosion_visual()
	exploded.emit(impact_position, blast_radius)
	if is_instance_valid(target_marker):
		target_marker.queue_free()
	if is_instance_valid(rocket_visual):
		rocket_visual.visible = false
	get_tree().create_timer(0.48).timeout.connect(queue_free)


func _spawn_explosion_visual() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.22, 0.03, 0.86)
	material.emission_enabled = true
	material.emission = Color("#ff6a19")
	material.emission_energy_multiplier = 7.0
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.7
	sphere_mesh.height = 1.4
	sphere_mesh.material = material
	var flash := MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * (blast_radius * 1.35), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, 0.42)
