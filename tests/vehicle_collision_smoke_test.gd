extends SceneTree

const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _assert_vehicle(city: Node3D, vehicle_type: String, along_z: bool, index: int) -> void:
	var node_name := "MeasuredVehicle_%s_%s" % [vehicle_type, "z" if along_z else "x"]
	city.call(
		"_spawn_vehicle",
		node_name,
		vehicle_type,
		Vector3(300.0 + index * 15.0, 0.1, 0.0),
		along_z
	)
	var body := city.get_node(node_name) as StaticBody3D
	var definition: Dictionary = VEHICLE_CATALOG.get_definition(vehicle_type)
	assert(body != null)
	assert(body.collision_layer == 1)
	assert(str(body.get_meta("vehicle_type")) == vehicle_type)
	assert(str(body.get_meta("vehicle_state")) == str(definition.get("state", "wrecked")))
	assert(str(body.get_meta("vehicle_axis")) == ("z" if along_z else "x"))

	var measured: Vector3 = definition["collision_size"]
	var expected := Vector3(measured.z, measured.y, measured.x) if along_z else measured
	var collision := body.get_node("VehicleCollision") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	assert(shape.size == expected)
	assert(collision.rotation == Vector3.ZERO)
	assert(is_equal_approx(body.global_position.y + collision.position.y - shape.size.y * 0.5, 0.0))

	var sprite := body.get_node("VehicleSprite") as Sprite3D
	assert(sprite.flip_h == not along_z)
	var source_size: Vector2i = definition.get(
		"source_size",
		Vector2i(sprite.texture.get_width(), sprite.texture.get_height())
	)
	var coordinate_scale := Vector2(
		float(sprite.texture.get_width()) / float(source_size.x),
		float(sprite.texture.get_height()) / float(source_size.y)
	)
	var raw_corners: Array = definition["footprint_corners_px"]
	var corners: Array[Vector2] = []
	for corner_variant in raw_corners:
		var corner: Vector2 = corner_variant
		corners.append(corner * coordinate_scale)
	var projected_width := (measured.x + measured.z) / sqrt(2.0)
	var base_pixel_width := absf((corners[2] as Vector2).x - (corners[0] as Vector2).x)
	assert(is_equal_approx(sprite.pixel_size, projected_width / base_pixel_width))
	var expected_offset := sprite.texture.get_width() * 0.5 - (corners[3] as Vector2).x
	assert(is_equal_approx(sprite.offset.x, expected_offset if along_z else -expected_offset))

	var debug_mesh := body.get_node("VehicleCollisionDebug") as MeshInstance3D
	var debug_footprint := debug_mesh.mesh as PlaneMesh
	assert(debug_footprint != null)
	assert(debug_footprint.size == Vector2(expected.x, expected.z))
	assert(is_equal_approx(body.global_position.y + debug_mesh.position.y, 0.035))
	assert(is_equal_approx(debug_mesh.position.x, collision.position.x))
	assert(is_equal_approx(debug_mesh.position.z, collision.position.z))
	assert(str(debug_mesh.get_meta("vehicle_type")) == vehicle_type)
	assert(str(debug_mesh.get_meta("vehicle_axis")) == ("z" if along_z else "x"))


func _run() -> void:
	var city: Node3D = load("res://scripts/procedural_map.gd").new()
	city.set("map_seed", 42)
	root.add_child(city)
	await process_frame
	await physics_frame

	var road_vehicle_count := 0
	var parking_vehicle_count := 0
	for vehicle in get_nodes_in_group("vehicle_obstacle"):
		if str(vehicle.name).begins_with("RoadCover_"):
			road_vehicle_count += 1
		elif str(vehicle.name).begins_with("Parked_"):
			parking_vehicle_count += 1
	assert(road_vehicle_count >= 30)
	assert(parking_vehicle_count >= int(city.get("parking_cells").size()) * 2)

	var index := 0
	for vehicle_type in VEHICLE_CATALOG.DEFINITIONS:
		_assert_vehicle(city, vehicle_type, false, index)
		_assert_vehicle(city, vehicle_type, true, index + 1)
		index += 2
	print("VEHICLE_COLLISION_OK road=%d parking=%d types=%d" % [
		road_vehicle_count,
		parking_vehicle_count,
		VEHICLE_CATALOG.DEFINITIONS.size(),
	])
	quit(0)
