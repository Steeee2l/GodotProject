extends Node3D

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const TELEGRAPH := preload("res://scripts/raid/telegraph_fx.gd")

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


func _build_target_marker() -> void:
	# 착탄 원 — 척탄병 예고와 같은 데칼(TelegraphFx 표준). 반경은 실제 폭발 반경,
	# 수명은 비행 시간(착탄 시 release). 풀링된 노드라 여기서 직접 만들지 않는다.
	target_marker = TELEGRAPH.show_landing_circle(
		impact_position, blast_radius, FLIGHT_DURATION + 0.3, get_parent()
	)
	if target_marker != null:
		target_marker.name = "RocketImpactTelegraph_%d" % get_instance_id()


func _update_target_marker(_progress: float) -> void:
	# 맥동·채움은 TelegraphFx의 트윈이 맡는다.
	pass


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
			# take_hostile_hit(…, attacker, source_position) — 사망 화면에 '누가 쐈는지'가
			# 찍히고, 엄폐 판정은 폭심 위치를 기준으로 한다. 없으면 예전 take_hit 경로.
			var receiver: Object = null
			if target_body.has_method("take_hostile_hit"):
				receiver = target_body
			elif target_body.get_parent() != null and target_body.get_parent().has_method("take_hostile_hit"):
				receiver = target_body.get_parent()
			if receiver != null:
				# 폭심 좌표는 플레이어(엄폐 판정)만 받는다. 적·더미는 3인자
				# 시그니처라 인자 수를 확인하지 않고 넘기면 호출 자체가 실패한다.
				# 5번째 인자(impact_kind) — 폭발은 넉백을 남기는 "큰 타격".
				if receiver.get_method_argument_count("take_hostile_hit") >= 5:
					receiver.call(
						"take_hostile_hit",
						applied_damage,
						hit_direction,
						source_body,
						impact_position,
						"blast"
					)
				elif receiver.get_method_argument_count("take_hostile_hit") >= 4:
					receiver.call(
						"take_hostile_hit",
						applied_damage,
						hit_direction,
						source_body,
						impact_position
					)
				else:
					receiver.call("take_hostile_hit", applied_damage, hit_direction, source_body)
			elif target_body.has_method("take_hit"):
				target_body.call("take_hit", applied_damage, hit_direction)
			elif target_body.get_parent() != null and target_body.get_parent().has_method("take_hit"):
				target_body.get_parent().call("take_hit", applied_damage, hit_direction)
	_spawn_explosion_visual()
	exploded.emit(impact_position, blast_radius)
	if is_instance_valid(target_marker):
		TELEGRAPH.release(target_marker)
		target_marker = null
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
