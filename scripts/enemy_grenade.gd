class_name EnemyGrenade
extends Node3D

var source_body: CollisionObject3D
var target_body: CharacterBody3D
var launch_origin := Vector3.ZERO
var target_position := Vector3.ZERO
var velocity := Vector3.ZERO
var damage := 28
var blast_radius := 3.15
var fuse_time := 2.45
var fuse_elapsed := 0.0
var landed := false
var exploded := false
var grenade_mesh: MeshInstance3D
var warning_disc: MeshInstance3D
var fuse_label: Label3D


func configure(
	thrower: CollisionObject3D,
	next_target: CharacterBody3D,
	start: Vector3,
	landing_position: Vector3,
	base_damage: int,
	radius: float,
	fuse: float
) -> void:
	source_body = thrower
	target_body = next_target
	launch_origin = start
	target_position = landing_position
	damage = base_damage
	blast_radius = radius
	fuse_time = fuse
	var flight_time := 0.88
	var horizontal := target_position - start
	horizontal.y = 0.0
	velocity = horizontal / flight_time
	velocity.y = 5.7


func _ready() -> void:
	_build_visuals()


func _physics_process(delta: float) -> void:
	if exploded:
		return
	if not landed:
		_update_flight(delta)
		return
	fuse_elapsed += delta
	_update_warning()
	if fuse_elapsed >= fuse_time:
		_explode()


func _update_flight(delta: float) -> void:
	velocity.y -= 13.0 * delta
	var next_position := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, 1)
	if is_instance_valid(source_body):
		query.exclude = [source_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and velocity.y <= 0.0:
		global_position = hit.get("position") + Vector3(0.0, 0.08, 0.0)
		landed = true
		velocity = Vector3.ZERO
		_show_landing_warning()
	elif next_position.y <= 0.09:
		next_position.y = 0.09
		global_position = next_position
		landed = true
		velocity = Vector3.ZERO
		_show_landing_warning()
	else:
		global_position = next_position
		grenade_mesh.rotation.x += delta * 8.0
		grenade_mesh.rotation.z += delta * 5.0


func _build_visuals() -> void:
	grenade_mesh = MeshInstance3D.new()
	grenade_mesh.name = "GrenadeBody"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.12
	body_mesh.height = 0.24
	body_mesh.radial_segments = 12
	body_mesh.rings = 7
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#354239")
	body_material.metallic = 0.58
	body_material.roughness = 0.48
	body_mesh.material = body_material
	grenade_mesh.mesh = body_mesh
	grenade_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grenade_mesh)

	warning_disc = MeshInstance3D.new()
	warning_disc.name = "GrenadeBlastWarning"
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = blast_radius
	disc_mesh.bottom_radius = blast_radius
	disc_mesh.height = 0.012
	disc_mesh.radial_segments = 48
	var disc_material := StandardMaterial3D.new()
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.albedo_color = Color(1.0, 0.16, 0.05, 0.13)
	disc_material.emission_enabled = true
	disc_material.emission = Color("#ff4b24")
	disc_material.emission_energy_multiplier = 1.4
	disc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc_mesh.material = disc_material
	warning_disc.mesh = disc_mesh
	warning_disc.position.y = -0.075
	warning_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_disc.visible = false
	add_child(warning_disc)

	fuse_label = Label3D.new()
	fuse_label.position = Vector3(0.0, 0.52, 0.0)
	fuse_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fuse_label.no_depth_test = true
	fuse_label.render_priority = 127
	fuse_label.font_size = 38
	fuse_label.outline_size = 10
	fuse_label.modulate = Color("#ffd06a")
	fuse_label.outline_modulate = Color(0.08, 0.015, 0.005, 0.95)
	fuse_label.visible = false
	add_child(fuse_label)


func _show_landing_warning() -> void:
	warning_disc.visible = true
	fuse_label.visible = true
	_update_warning()


func _update_warning() -> void:
	var remaining := maxf(0.0, fuse_time - fuse_elapsed)
	fuse_label.text = "%.1f" % remaining
	var pulse := 0.82 + (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.022)) * 0.22
	warning_disc.scale = Vector3(pulse, 1.0, pulse)
	grenade_mesh.scale = Vector3.ONE * (1.0 + (1.0 - remaining / fuse_time) * 0.25)


func _explode() -> void:
	exploded = true
	if is_instance_valid(target_body):
		var offset := target_body.global_position - global_position
		offset.y = 0.0
		if offset.length() <= blast_radius and _has_clear_blast_path(target_body):
			var falloff := 1.0 - clampf(offset.length() / blast_radius, 0.0, 0.72)
			var applied_damage := maxi(8, roundi(float(damage) * falloff))
			if target_body.has_method("take_hostile_hit"):
				target_body.call("take_hostile_hit", applied_damage, offset.normalized(), source_body)
			elif target_body.has_method("take_damage"):
				target_body.call("take_damage", applied_damage)
			elif target_body.get_parent() != null:
				var parent := target_body.get_parent()
				if parent.has_method("take_hostile_hit"):
					parent.call("take_hostile_hit", applied_damage, offset.normalized(), source_body)
				elif parent.has_method("take_damage"):
					parent.call("take_damage", applied_damage)
	_spawn_explosion_fx()
	grenade_mesh.visible = false
	warning_disc.visible = false
	fuse_label.visible = false
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _has_clear_blast_path(body: CollisionObject3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 0.15, 0.0),
		body.global_position + Vector3(0.0, 0.35, 0.0),
		1
	)
	if is_instance_valid(source_body):
		query.exclude = [source_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


func _spawn_explosion_fx() -> void:
	var blast := MeshInstance3D.new()
	var blast_mesh := SphereMesh.new()
	blast_mesh.radius = 0.34
	blast_mesh.height = 0.68
	blast_mesh.radial_segments = 16
	blast_mesh.rings = 8
	var blast_material := StandardMaterial3D.new()
	blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blast_material.albedo_color = Color(1.0, 0.42, 0.08, 0.9)
	blast_material.emission_enabled = true
	blast_material.emission = Color("#ff7a1e")
	blast_material.emission_energy_multiplier = 7.0
	blast_material.no_depth_test = true
	blast_mesh.material = blast_material
	blast.mesh = blast_mesh
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blast)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE * blast_radius * 2.15, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(blast, "transparency", 1.0, 0.34)
	for index in 14:
		var fragment := MeshInstance3D.new()
		var fragment_mesh := SphereMesh.new()
		fragment_mesh.radius = 0.035
		fragment_mesh.height = 0.07
		fragment_mesh.material = blast_material
		fragment.mesh = fragment_mesh
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fragment)
		var angle := TAU * float(index) / 14.0
		var target_offset := Vector3(cos(angle), 0.15 + (index % 3) * 0.12, sin(angle)) * blast_radius
		var fragment_tween := fragment.create_tween()
		fragment_tween.set_parallel(true)
		fragment_tween.tween_property(fragment, "position", target_offset, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		fragment_tween.tween_property(fragment, "transparency", 1.0, 0.32)
