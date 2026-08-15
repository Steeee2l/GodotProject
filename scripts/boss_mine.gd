extends Node3D

signal detonated(world_position: Vector3, radius: float)

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

const FLIGHT_DURATION := 0.42
const ARC_HEIGHT := 1.65
const ARM_DELAY := 0.58
const TRIGGER_RADIUS := 2.45
const TRIGGER_FUSE := 0.32
const MAX_ARMED_LIFETIME := 22.0

var source_body: CollisionObject3D
var target_body: CharacterBody3D
var start_position := Vector3.ZERO
var landing_position := Vector3.ZERO
var damage := 24
var blast_radius := 2.35
var flight_elapsed := 0.0
var flight_trail_elapsed := 0.0
var state_elapsed := 0.0
var mine_state := "flight"
var exploded := false

var visual_root: Node3D
var body_mesh: MeshInstance3D
var fuse_ring: MeshInstance3D
var trigger_ring: MeshInstance3D
var warning_disc: MeshInstance3D
var pulse_light: OmniLight3D
var fuse_material: StandardMaterial3D


func configure(
	owner_body: CollisionObject3D,
	player_target: CharacterBody3D,
	launch_position: Vector3,
	target_position: Vector3,
	base_damage: int = 24,
	explosion_radius: float = 2.35
) -> void:
	source_body = owner_body
	target_body = player_target
	start_position = launch_position
	landing_position = target_position
	landing_position.y = 0.1
	damage = base_damage
	blast_radius = explosion_radius


func _ready() -> void:
	global_position = start_position
	add_to_group("boss_mine")
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
	flight_trail_elapsed += delta
	var progress := clampf(flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)
	var next_position := start_position.lerp(landing_position, progress)
	next_position.y += sin(progress * PI) * ARC_HEIGHT
	global_position = next_position
	visual_root.rotation.x += delta * 9.0
	visual_root.rotation.z += delta * 6.0
	fuse_ring.visible = true
	pulse_light.visible = true
	fuse_ring.scale = Vector3.ONE * (0.82 + sin(progress * TAU * 3.0) * 0.12)
	_set_fuse_color(Color("#ffd56a"), 5.2)
	pulse_light.light_energy = 2.4
	while flight_trail_elapsed >= 0.055:
		flight_trail_elapsed -= 0.055
		_spawn_flight_trail_spark()
	if progress >= 1.0:
		_land()


func _land() -> void:
	mine_state = "arming"
	state_elapsed = 0.0
	global_position = landing_position
	visual_root.rotation = Vector3.ZERO
	trigger_ring.visible = true
	fuse_ring.visible = true
	pulse_light.visible = true


func _update_arming(delta: float) -> void:
	state_elapsed += delta
	var progress := clampf(state_elapsed / ARM_DELAY, 0.0, 1.0)
	var pulse := 0.72 + progress * 0.28
	trigger_ring.scale = Vector3.ONE * pulse
	fuse_ring.rotation.y += delta * 5.5
	_set_fuse_color(Color("#ffc45c"), lerpf(1.8, 4.6, progress))
	pulse_light.light_energy = lerpf(0.7, 2.2, progress)
	if progress >= 1.0:
		mine_state = "armed"
		state_elapsed = 0.0


func _update_armed(delta: float) -> void:
	state_elapsed += delta
	var pulse := 0.88 + (0.5 + 0.5 * sin(state_elapsed * 7.0)) * 0.18
	fuse_ring.scale = Vector3.ONE * pulse
	fuse_ring.rotation.y += delta * 2.8
	trigger_ring.scale = Vector3.ONE * (0.97 + sin(state_elapsed * 3.6) * 0.025)
	_set_fuse_color(Color("#ff754f"), 3.4 + pulse * 1.4)
	pulse_light.light_energy = 1.25 + pulse * 0.8
	if is_instance_valid(target_body):
		var offset := target_body.global_position - global_position
		offset.y = 0.0
		if offset.length() <= TRIGGER_RADIUS:
			_trigger()
			return
	if state_elapsed >= MAX_ARMED_LIFETIME:
		_trigger()


func _trigger() -> void:
	if mine_state == "triggered" or exploded:
		return
	mine_state = "triggered"
	state_elapsed = 0.0
	warning_disc.visible = true
	trigger_ring.visible = false


func _update_triggered(delta: float) -> void:
	state_elapsed += delta
	var progress := clampf(state_elapsed / TRIGGER_FUSE, 0.0, 1.0)
	var pulse := 1.0 + sin(progress * TAU * 4.0) * 0.12
	warning_disc.scale = Vector3.ONE * lerpf(0.35, 1.0, progress)
	fuse_ring.scale = Vector3.ONE * pulse
	_set_fuse_color(Color("#ff2e18"), lerpf(5.0, 10.0, progress))
	pulse_light.light_color = Color("#ff321c")
	pulse_light.light_energy = lerpf(2.5, 6.0, progress)
	if progress >= 1.0:
		_detonate()


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "MineVisual"
	add_child(visual_root)

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#2f3534")
	body_material.metallic = 0.82
	body_material.roughness = 0.3
	var body_shape := CylinderMesh.new()
	body_shape.top_radius = 0.25
	body_shape.bottom_radius = 0.29
	body_shape.height = 0.12
	body_shape.radial_segments = 16
	body_shape.material = body_material
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "MineBody"
	body_mesh.position.y = 0.06
	body_mesh.mesh = body_shape
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(body_mesh)

	var hub_material := StandardMaterial3D.new()
	hub_material.albedo_color = Color("#0f1515")
	hub_material.metallic = 0.65
	hub_material.roughness = 0.26
	var hub_shape := CylinderMesh.new()
	hub_shape.top_radius = 0.105
	hub_shape.bottom_radius = 0.12
	hub_shape.height = 0.11
	hub_shape.radial_segments = 14
	hub_shape.material = hub_material
	var hub := MeshInstance3D.new()
	hub.name = "FuseHub"
	hub.position.y = 0.15
	hub.mesh = hub_shape
	hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(hub)

	fuse_material = _make_glow_material(Color("#ffc45c"), 3.0, 0.92)
	var fuse_shape := TorusMesh.new()
	fuse_shape.inner_radius = 0.11
	fuse_shape.outer_radius = 0.16
	fuse_shape.rings = 24
	fuse_shape.ring_segments = 7
	fuse_shape.material = fuse_material
	fuse_ring = MeshInstance3D.new()
	fuse_ring.name = "ArmingFuse"
	fuse_ring.position.y = 0.215
	fuse_ring.mesh = fuse_shape
	fuse_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fuse_ring.visible = false
	visual_root.add_child(fuse_ring)

	var trigger_material := _make_glow_material(Color("#ff9b55"), 2.1, 0.35)
	var trigger_shape := TorusMesh.new()
	trigger_shape.inner_radius = TRIGGER_RADIUS - 0.055
	trigger_shape.outer_radius = TRIGGER_RADIUS
	trigger_shape.rings = 48
	trigger_shape.ring_segments = 8
	trigger_shape.material = trigger_material
	trigger_ring = MeshInstance3D.new()
	trigger_ring.name = "ProximityRing"
	trigger_ring.position.y = 0.025
	trigger_ring.mesh = trigger_shape
	trigger_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trigger_ring.visible = false
	add_child(trigger_ring)

	var warning_material := _make_glow_material(Color("#ff351d"), 3.8, 0.18)
	var warning_shape := CylinderMesh.new()
	warning_shape.top_radius = blast_radius
	warning_shape.bottom_radius = blast_radius
	warning_shape.height = 0.014
	warning_shape.radial_segments = 48
	warning_shape.material = warning_material
	warning_disc = MeshInstance3D.new()
	warning_disc.name = "BlastWarning"
	warning_disc.position.y = 0.018
	warning_disc.mesh = warning_shape
	warning_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_disc.visible = false
	add_child(warning_disc)

	pulse_light = OmniLight3D.new()
	pulse_light.name = "FuseLight"
	pulse_light.position.y = 0.4
	pulse_light.light_color = Color("#ff754f")
	pulse_light.light_energy = 1.2
	pulse_light.omni_range = 2.6
	pulse_light.shadow_enabled = false
	pulse_light.visible = false
	add_child(pulse_light)


func _make_glow_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _set_fuse_color(color: Color, energy: float) -> void:
	fuse_material.albedo_color = Color(color.r, color.g, color.b, 0.96)
	fuse_material.emission = color
	fuse_material.emission_energy_multiplier = energy
	pulse_light.light_color = color


func _spawn_flight_trail_spark() -> void:
	var trail_material := _make_glow_material(Color("#ffb83d"), 5.6, 0.7)
	trail_material.no_depth_test = true
	var trail_shape := SphereMesh.new()
	trail_shape.radius = 0.065
	trail_shape.height = 0.13
	trail_shape.radial_segments = 10
	trail_shape.rings = 5
	trail_shape.material = trail_material
	var spark := MeshInstance3D.new()
	spark.name = "MineFlightSpark"
	spark.top_level = true
	spark.mesh = trail_shape
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spark)
	spark.global_position = global_position
	var tween := spark.create_tween().set_parallel(true)
	tween.tween_property(spark, "scale", Vector3.ONE * 0.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(spark, "transparency", 1.0, 0.3)
	get_tree().create_timer(0.32).timeout.connect(spark.queue_free)


func _detonate() -> void:
	if exploded:
		return
	exploded = true
	var valid_source: CollisionObject3D = source_body if is_instance_valid(source_body) else null
	if is_instance_valid(target_body):
		var offset := target_body.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= blast_radius and _has_clear_blast_path(target_body):
			var falloff := lerpf(1.0, 0.42, distance / blast_radius)
			var applied_damage := maxi(6, roundi(float(damage) * falloff))
			var hit_direction := offset.normalized() if distance > 0.01 else Vector3.RIGHT
			if target_body.has_method("take_hostile_hit"):
				target_body.call("take_hostile_hit", applied_damage, hit_direction, valid_source)
			elif target_body.has_method("take_hit"):
				target_body.call("take_hit", applied_damage, hit_direction)
			elif target_body.get_parent() != null and target_body.get_parent().has_method("take_hostile_hit"):
				target_body.get_parent().call("take_hostile_hit", applied_damage, hit_direction, valid_source)
			elif target_body.get_parent() != null and target_body.get_parent().has_method("take_hit"):
				target_body.get_parent().call("take_hit", applied_damage, hit_direction)
	_spawn_explosion_fx()
	detonated.emit(global_position, blast_radius)
	visual_root.visible = false
	trigger_ring.visible = false
	warning_disc.visible = false
	pulse_light.visible = false
	get_tree().create_timer(0.85).timeout.connect(queue_free)


func _has_clear_blast_path(body: CollisionObject3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 0.16, 0.0),
		body.global_position + Vector3(0.0, 0.36, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	if is_instance_valid(source_body):
		query.exclude = [source_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


func _spawn_explosion_fx() -> void:
	var flash_material := _make_glow_material(Color("#ff5a1f"), 8.5, 0.92)
	flash_material.no_depth_test = true
	var flash_shape := SphereMesh.new()
	flash_shape.radius = 0.42
	flash_shape.height = 0.84
	flash_shape.radial_segments = 18
	flash_shape.rings = 9
	flash_shape.material = flash_material
	var flash := MeshInstance3D.new()
	flash.name = "MineBlastFlash"
	flash.position.y = 0.22
	flash.mesh = flash_shape
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)

	var shock_shape := TorusMesh.new()
	shock_shape.inner_radius = 0.34
	shock_shape.outer_radius = 0.46
	shock_shape.rings = 36
	shock_shape.ring_segments = 8
	shock_shape.material = flash_material
	var shock_ring := MeshInstance3D.new()
	shock_ring.name = "MineShockRing"
	shock_ring.position.y = 0.08
	shock_ring.mesh = shock_shape
	shock_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shock_ring)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * blast_radius * 1.55, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, 0.38)
	tween.tween_property(shock_ring, "scale", Vector3.ONE * blast_radius * 3.8, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(shock_ring, "transparency", 1.0, 0.42)

	for index in 16:
		var fragment_shape := BoxMesh.new()
		fragment_shape.size = Vector3(0.05, 0.035, 0.13)
		fragment_shape.material = flash_material
		var fragment := MeshInstance3D.new()
		fragment.mesh = fragment_shape
		fragment.position.y = 0.16
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fragment)
		var angle := TAU * float(index) / 16.0
		var distance := blast_radius * (0.72 + float(index % 3) * 0.15)
		var destination := Vector3(cos(angle) * distance, 0.18 + float(index % 4) * 0.11, sin(angle) * distance)
		var fragment_tween := fragment.create_tween().set_parallel(true)
		fragment_tween.tween_property(fragment, "position", destination, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		fragment_tween.tween_property(fragment, "transparency", 1.0, 0.5)

	_spawn_smoke_particles()


func _spawn_smoke_particles() -> void:
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
	smoke.name = "MineBlastSmoke"
	smoke.amount = 34
	smoke.lifetime = 0.76
	smoke.one_shot = true
	smoke.explosiveness = 0.92
	smoke.randomness = 0.42
	smoke.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 7, 10))
	smoke.process_material = process_material
	smoke.draw_pass_1 = smoke_quad
	add_child(smoke)
	smoke.emitting = true