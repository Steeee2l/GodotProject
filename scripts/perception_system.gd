class_name PerceptionSystem
extends CanvasLayer

const MAX_OCCLUDERS := 24
const FOV_HALF_ANGLE_DEGREES := 58.0
const VISION_WORLD_RANGE := 11.5

var player: CharacterBody3D
var camera: Camera3D
var fog_rect: ColorRect
var fog_material: ShaderMaterial
var aim_world_direction := Vector3(1, 0, 1).normalized()
var vision_world_range := VISION_WORLD_RANGE
var aim_expanded := false


func setup(player_body: CharacterBody3D, active_camera: Camera3D) -> void:
	player = player_body
	camera = active_camera


func _ready() -> void:
	name = "PerceptionSystem"
	layer = 2
	add_to_group("perception_system")


func set_aim_direction(world_direction: Vector3) -> void:
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.01:
		aim_world_direction = world_direction.normalized()


func set_vision_range(world_range: float) -> void:
	vision_world_range = maxf(2.0, world_range)


func set_aim_expanded(value: bool) -> void:
	aim_expanded = value


func _collect_nearby_occluders() -> Array[Node3D]:
	var unique := {}
	for group_name in ["vision_occluder", "camera_occluder", "vehicle_obstacle"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node3D:
				unique[node.get_instance_id()] = node
	var result: Array[Node3D] = []
	for node in unique.values():
		var body := node as Node3D
		if is_instance_valid(body) and player.global_position.distance_squared_to(body.global_position) <= 625.0:
			result.append(body)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
	)
	return result


func _occluder_screen_segment(body: Node3D, viewport_size: Vector2) -> Vector4:
	var collision := _find_box_collision(body)
	if collision == null or not (collision.shape is BoxShape3D):
		var center := camera.unproject_position(body.global_position) / viewport_size
		return Vector4(center.x - 0.015, center.y, center.x + 0.015, center.y)
	var box := collision.shape as BoxShape3D
	var half := box.size * 0.5
	var local_player := collision.to_local(player.global_position)
	var point_a := Vector3.ZERO
	var point_b := Vector3.ZERO
	var ground_y := -half.y + minf(0.3, box.size.y * 0.35)
	if absf(local_player.x) > absf(local_player.z):
		var edge_x := half.x * signf(local_player.x)
		point_a = Vector3(edge_x, ground_y, -half.z)
		point_b = Vector3(edge_x, ground_y, half.z)
	else:
		var edge_z := half.z * signf(local_player.z)
		point_a = Vector3(-half.x, ground_y, edge_z)
		point_b = Vector3(half.x, ground_y, edge_z)
	var screen_a := camera.unproject_position(collision.to_global(point_a)) / viewport_size
	var screen_b := camera.unproject_position(collision.to_global(point_b)) / viewport_size
	return Vector4(screen_a.x, screen_a.y, screen_b.x, screen_b.y)


func _find_box_collision(body: Node3D) -> CollisionShape3D:
	for child in body.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		if collision and collision.shape is BoxShape3D:
			return collision
	return null