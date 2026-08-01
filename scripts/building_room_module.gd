extends Node3D

const CARPET_TEXTURE_PATH := "res://assets/interiors/office_dungeon/office_carpet_tile_v1.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/office_dungeon/office_wall_panel_v1.png"
const WORKSTATION_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/office_workstation_cluster_v1.png"
const SERVER_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/server_rack_cluster_v1.png"
const STORAGE_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/storage_shelf_cluster_v1.png"
const MEETING_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/meeting_table_cluster_v1.png"
const EXECUTIVE_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/executive_lounge_cluster_v1.png"
const FLOOR_TILE_SIZE := 4.0
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

var room_index := 0
var room_size := Vector2(18.0, 14.0)
var room_type := "open_office"
var room_seed := 1
var door_sides: Array[String] = []


func configure(
	index: int,
	size_value: Vector2,
	type_value: String,
	seed_value: int,
	doors: Array[String]
) -> void:
	room_index = index
	room_size = size_value
	room_type = type_value
	room_seed = seed_value
	door_sides = doors.duplicate()
	set_meta("room_index", room_index)
	set_meta("room_type", room_type)
	set_meta("module_size", room_size)
	set_meta("door_sides", door_sides)


func _ready() -> void:
	add_to_group("building_room_module")
	_build_shell()
	_build_furniture()


func _build_shell() -> void:
	_build_floor_tiles()
	_build_wall("north")
	_build_wall("south")
	_build_wall("west")
	_build_wall("east")


func _build_floor_tiles() -> void:
	var columns := ceili(room_size.x / FLOOR_TILE_SIZE)
	var rows := ceili(room_size.y / FLOOR_TILE_SIZE)
	for row in rows:
		for column in columns:
			var tile_width := minf(FLOOR_TILE_SIZE, room_size.x - float(column) * FLOOR_TILE_SIZE)
			var tile_depth := minf(FLOOR_TILE_SIZE, room_size.y - float(row) * FLOOR_TILE_SIZE)
			var x := -room_size.x * 0.5 + float(column) * FLOOR_TILE_SIZE + tile_width * 0.5
			var z := -room_size.y * 0.5 + float(row) * FLOOR_TILE_SIZE + tile_depth * 0.5
			var material := _texture_material(CARPET_TEXTURE_PATH, Vector3.ONE, Color("#b8b8b8"))
			var tile := _add_plane("FloorTile_%02d_%02d" % [column, row], Vector3(x, 0.01, z), Vector2(tile_width, tile_depth), material)
			tile.add_to_group("building_floor_tile")
			tile.set_meta("tile_coord", Vector2i(column, row))


func _build_wall(side: String) -> void:
	var horizontal := side == "north" or side == "south"
	var near_camera_side := side == "south" or side == "east"
	var wall_height := 0.72 if near_camera_side else 2.8
	var total_length := room_size.x if horizontal else room_size.y
	var half_x := room_size.x * 0.5
	var half_z := room_size.y * 0.5
	var center := Vector3.ZERO
	if side == "north": center.z = -half_z
	elif side == "south": center.z = half_z
	elif side == "west": center.x = -half_x
	else: center.x = half_x
	if not door_sides.has(side):
		var full_size := Vector3(total_length, wall_height, 0.28) if horizontal else Vector3(0.28, wall_height, total_length)
		_add_wall_box("%sWall" % side.capitalize(), center + Vector3(0, wall_height * 0.5, 0), full_size, true)
		return
	var door_width := 2.8
	var segment_length := (total_length - door_width) * 0.5
	var offset := (door_width + segment_length) * 0.5
	if horizontal:
		_add_wall_box("%sWallA" % side.capitalize(), center + Vector3(-offset, wall_height * 0.5, 0), Vector3(segment_length, wall_height, 0.28), true)
		_add_wall_box("%sWallB" % side.capitalize(), center + Vector3(offset, wall_height * 0.5, 0), Vector3(segment_length, wall_height, 0.28), true)
	else:
		_add_wall_box("%sWallA" % side.capitalize(), center + Vector3(0, wall_height * 0.5, -offset), Vector3(0.28, wall_height, segment_length), true)
		_add_wall_box("%sWallB" % side.capitalize(), center + Vector3(0, wall_height * 0.5, offset), Vector3(0.28, wall_height, segment_length), true)
	if near_camera_side:
		return
	var header_size := Vector3(door_width, 0.55, 0.28) if horizontal else Vector3(0.28, 0.55, door_width)
	_add_wall_box("%sDoorHeader" % side.capitalize(), center + Vector3(0, 2.525, 0), header_size, true)


func _build_furniture() -> void:
	match room_type:
		"storage":
			_add_image_furniture("StorageNorth", STORAGE_TEXTURE_PATH, Vector3(-6.5, 0, -4.0), 0.0043, [
				{"position": Vector3(0, 0.8, 0), "size": Vector3(6.0, 1.6, 3.7)},
			])
			_add_image_furniture("StorageSouth", STORAGE_TEXTURE_PATH, Vector3(6.5, 0, 4.0), 0.0043, [
				{"position": Vector3(0, 0.8, 0), "size": Vector3(6.0, 1.6, 3.7)},
			], true)
		"server":
			_add_image_furniture("ServerWest", SERVER_TEXTURE_PATH, Vector3(-7.2, 0, -4.0), 0.0042, [
				{"position": Vector3(0, 0.95, 0), "size": Vector3(4.8, 1.9, 2.8)},
			])
			_add_image_furniture("ServerEast", SERVER_TEXTURE_PATH, Vector3(7.2, 0, 4.0), 0.0042, [
				{"position": Vector3(0, 0.95, 0), "size": Vector3(4.8, 1.9, 2.8)},
			], true)
		"meeting":
			_add_image_furniture("MeetingTable", MEETING_TEXTURE_PATH, Vector3(0, 0, 0), 0.0048, [
				{"position": Vector3(0, 0.7, 0), "size": Vector3(7.2, 1.4, 4.6)},
			])
		"executive":
			_add_workstation_module("ExecutiveWorkstation", Vector3(0, 0, -4.6), false)
			_add_image_furniture("ExecutiveLounge", EXECUTIVE_TEXTURE_PATH, Vector3(6.5, 0, 4.2), 0.0047, [
				{"position": Vector3(0.5, 0.7, 0), "size": Vector3(6.6, 1.4, 4.4)},
			], true)
		_:
			_add_workstation_module("WorkstationNorthWest", Vector3(-7.0, 0, -5.1), false)
			_add_workstation_module("WorkstationNorthEast", Vector3(7.0, 0, -5.1), true)
			_add_workstation_module("WorkstationSouthWest", Vector3(-7.0, 0, 5.1), true)
			_add_workstation_module("WorkstationSouthEast", Vector3(7.0, 0, 5.1), false)


func _add_workstation_module(node_name: String, local_position: Vector3, mirrored: bool) -> void:
	_add_image_furniture(node_name, WORKSTATION_TEXTURE_PATH, local_position, 0.0056, [
		{"position": Vector3(-2.0, 0.7, -1.65), "size": Vector3(2.15, 1.4, 1.05)},
		{"position": Vector3(1.45, 0.7, -1.65), "size": Vector3(2.15, 1.4, 1.05)},
		{"position": Vector3(-0.25, 0.7, -0.62), "size": Vector3(1.15, 1.4, 1.35)},
	], mirrored)


func _add_image_furniture(node_name: String, texture_path: String, local_position: Vector3, pixel_size: float, footprints: Array, mirrored: bool = false) -> void:
	var module := Node3D.new()
	module.name = node_name
	module.position = local_position
	module.add_to_group("building_furniture_module")
	module.set_meta("module_type", texture_path.get_file().get_basename())
	add_child(module)
	var texture := load(texture_path) as Texture2D
	var sprite := Sprite3D.new()
	sprite.name = "GeneratedFurnitureVisual"
	sprite.texture = texture
	sprite.position = Vector3(0, float(texture.get_height()) * pixel_size * 0.5, 0)
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.flip_h = mirrored
	module.add_child(sprite)
	var resolved_footprints: Array = []
	for index in footprints.size():
		var footprint: Dictionary = footprints[index]
		var footprint_position: Vector3 = footprint.position
		if mirrored:
			footprint_position.x = -footprint_position.x
		resolved_footprints.append({"position": footprint_position, "size": footprint.size})
		_add_collision_box(module, "FurnitureCollision%d" % index, footprint_position, footprint.size)
	module.set_meta("collision_footprints", resolved_footprints)


func _add_collision_box(parent: Node, node_name: String, local_position: Vector3, size: Vector3) -> void:
	var profile_id := "furniture_table" if size.x >= 1.1 and size.z >= 0.7 else "furniture_solid"
	var profile := COLLISION_PROFILES.get_profile(profile_id, size)
	var movement_size: Vector3 = profile["movement_size"]
	var projectile_size: Vector3 = profile["projectile_size"]
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = movement_size
	collision.shape = shape
	collision.position.y = -local_position.y + movement_size.y * 0.5
	body.add_child(collision)
	parent.add_child(body)
	var projectile_body := StaticBody3D.new()
	projectile_body.name = "%sProjectileBlocker" % node_name
	projectile_body.position = local_position
	projectile_body.collision_layer = COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	projectile_body.collision_mask = 0
	var projectile_collision := CollisionShape3D.new()
	var projectile_shape := BoxShape3D.new()
	projectile_shape.size = projectile_size
	projectile_collision.shape = projectile_shape
	projectile_collision.position.y = -local_position.y + projectile_size.y * 0.5
	projectile_body.add_child(projectile_collision)
	parent.add_child(projectile_body)
	_add_collision_debug(parent, node_name, local_position, movement_size)


func _add_collision_debug(parent: Node, node_name: String, local_position: Vector3, size: Vector3) -> void:
	var debug := MeshInstance3D.new()
	debug.name = "%sDebugRed" % node_name
	debug.position = Vector3(local_position.x, 0.035, local_position.z)
	debug.add_to_group("building_collision_debug")
	debug.add_to_group("collision_debug_visual")
	debug.visible = false
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.035, size.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.04, 0.04, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	mesh.material = material
	debug.mesh = mesh
	parent.add_child(debug)


func _add_plane(node_name: String, local_position: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)
	return instance


func _add_wall_box(node_name: String, local_position: Vector3, size: Vector3, collision_enabled: bool) -> void:
	var material := _texture_material(WALL_TEXTURE_PATH, Vector3(maxf(1.0, size.x / 4.0), maxf(1.0, size.y / 2.8), maxf(1.0, size.z / 4.0)), Color.WHITE)
	_add_box_with_material(self, node_name, local_position, size, material, collision_enabled)


func _add_box(node_name: String, local_position: Vector3, size: Vector3, color: Color, collision_enabled: bool) -> void:
	_add_box_to(self, node_name, local_position, size, color, collision_enabled)


func _add_box_to(parent: Node, node_name: String, local_position: Vector3, size: Vector3, color: Color, collision_enabled: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	_add_box_with_material(parent, node_name, local_position, size, material, collision_enabled)


func _add_box_with_material(parent: Node, node_name: String, local_position: Vector3, size: Vector3, material: Material, collision_enabled: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%sVisual" % node_name
	mesh_instance.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	if not collision_enabled:
		return
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = local_position
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _texture_material(path: String, uv_scale: Vector3, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	material.albedo_color = tint
	material.texture_repeat = true
	material.uv1_scale = uv_scale
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
