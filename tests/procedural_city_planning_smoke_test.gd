extends SceneTree

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _block_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _assert_isometric_footprint(definition: Dictionary) -> void:
	var corners: Array = definition["footprint_corners_px"]
	var left: Vector2 = corners[0]
	var top: Vector2 = corners[1]
	var right: Vector2 = corners[2]
	var bottom: Vector2 = corners[3]
	assert(left + right == top + bottom)
	assert(absf((right.y - top.y) / (right.x - top.x) - 0.5) < 0.002)
	assert(absf((left.y - top.y) / (left.x - top.x) + 0.5) < 0.002)
	assert(absf((bottom.y - left.y) / (bottom.x - left.x) - 0.5) < 0.002)
	assert(absf((bottom.y - right.y) / (bottom.x - right.x) + 0.5) < 0.002)


func _assert_sealed_landmark(city: Node3D, cell: Vector2i, node_prefix: String) -> void:
	var matching_bodies: Array[StaticBody3D] = []
	for child in city.get_children():
		if child is StaticBody3D and str(child.name).begins_with(node_prefix):
			matching_bodies.append(child)
	assert(not matching_bodies.is_empty())
	var collision := matching_bodies[0].get_child(0) as CollisionShape3D
	assert(collision != null)
	var box := collision.shape as BoxShape3D
	assert(box != null)
	assert(box.size == Vector3(16.0, 2.4, 16.0))
	# 월드 장애물은 18613c4 에서 레이어 1 -> WORLD_MOVEMENT_LAYER(32) 로 옮겼는데
	# 이 단언만 옛 값 1에 남아 있어 계속 깨지고 있었다. 상수로 맞춘다.
	assert(matching_bodies[0].collision_layer == COLLISION_PROFILES.WORLD_MOVEMENT_LAYER)

	var center: Vector3 = city.call("_cell_center", cell)
	# 레이 마스크도 옛 레이어 1이 아니라 WORLD_MOVEMENT_LAYER 여야 랜드마크
	# 충돌체를 맞힌다. 마스크가 1이면 아무것도 안 맞아 항상 빈 결과였다.
	var query := PhysicsRayQueryParameters3D.create(
		center + Vector3(-8.5, 1.0, 0.0),
		center + Vector3(8.5, 1.0, 0.0),
		COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	)
	var hit := city.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	var hit_name := str((hit["collider"] as Node).name)
	assert(hit_name.begins_with(node_prefix), "Expected %s, hit %s" % [node_prefix, hit_name])


func _run() -> void:
	var map_script: Script = load("res://scripts/procedural_map.gd")
	var building_catalog = load("res://scripts/building_catalog.gd")
	var landmark_catalog = load("res://scripts/urban_landmark_catalog.gd")
	var street_prop_catalog = load("res://scripts/street_prop_catalog.gd")
	for landmark_id in ["playground"]:
		var definition: Dictionary = landmark_catalog.get_definition(landmark_id)
		_assert_isometric_footprint(definition)
		assert(definition["collision_boxes"].size() == 1)
		assert(definition["collision_boxes"][0]["size"] == Vector2(8.0, 8.0))
		assert(float(definition["collision_boxes"][0]["height"]) == 2.4)
	for building_id in [
		"gangnam_clinic_pharmacy_6x4_aligned",
		"gangnam_food_alley_4x6_aligned",
		"gangnam_damaged_officetel_6x6_aligned",
		"seoul_market_row_8x4_v1",
		"seoul_multifamily_villa_6x6_v1",
		"gangnam_luxury_showroom_6x6_v1",
		"seoul_laundromat_repair_8x4_v1",
		"seoul_redbrick_corner_villa_6x6_v1",
		"namdaemun_covered_market_8x4_v1",
		"euljiro_metalworks_8x4_v1",
		"yongsan_checkpoint_depot_8x4_v1",
		"namsan_decon_station_8x4_v1",
	]:
		var definition: Dictionary = building_catalog.get_definition(building_id)
		assert(building_catalog.is_valid_definition(definition))
		assert(ResourceLoader.exists(str(definition["texture_path"])))
		_assert_isometric_footprint(definition)
		if building_id.ends_with("_8x4_v1"):
			assert(definition["footprint_modules"] == Vector2i(8, 4))
	assert(building_catalog.get_definition("seoul_market_row_8x4_v1")["districts"].has("market_lane"))
	assert(building_catalog.get_definition("seoul_multifamily_villa_6x6_v1")["districts"].has("multi_family"))
	assert(building_catalog.get_definition("gangnam_luxury_showroom_6x6_v1")["districts"].has("luxury_core"))
	assert(building_catalog.get_definition("seoul_laundromat_repair_8x4_v1")["districts"].has("street_mixed"))
	assert(building_catalog.get_definition("seoul_redbrick_corner_villa_6x6_v1")["districts"].has("residential_buffer"))
	for prop_id in street_prop_catalog.DEFINITIONS:
		var prop_definition: Dictionary = street_prop_catalog.get_definition(prop_id)
		var prop_collision_size: Vector3 = prop_definition["collision_size"]
		var prop_corners: Array = prop_definition["footprint_corners_px"]
		assert(ResourceLoader.exists(str(prop_definition["texture_path"])))
		assert(prop_collision_size.x > 0.0)
		assert(prop_collision_size.z > 0.0)
		assert(prop_corners.size() == 4)
	var generated_lowrise_ids := {}
	var generated_prop_ids := {}
	for seed in [1, 7, 42, 1337, 24681357]:
		var city: Node3D = map_script.new()
		city.set("map_seed", seed)
		root.add_child(city)
		await process_frame
		await physics_frame

		var parks: Array = city.get("park_cells")
		var playgrounds: Array = city.get("playground_cells")
		var subways: Array = city.get("subway_cells")
		var apartment_cells: Array = city.get("apartment_cells")
		var apartment_origin: Vector2i = city.get("apartment_origin")
		assert(parks.is_empty())
		assert(playgrounds.size() == 2)
		assert(subways.size() == 2)
		assert(get_nodes_in_group("urban_pocket_park").is_empty())
		assert(get_nodes_in_group("urban_playground").size() == 2)
		assert(get_nodes_in_group("urban_subway_entrance").size() == 2)
		assert(get_nodes_in_group("safe_zone").is_empty())
		assert(city.get_node_or_null("ShelterSafehouse") == null)
		assert(city.find_children("ShelterPortal", "", true, false).is_empty())
		assert(not bool(city.call("is_position_in_safe_zone", city.call("_cell_center", Vector2i(1, 1)))))
		var road_covers: Array[Node] = []
		for child in city.get_children():
			if child.is_in_group("road_cover_obstacle"):
				road_covers.append(child)
		assert(road_covers.size() >= 4)
		for cover in road_covers:
			assert(cover is StaticBody3D)
			assert(
				(cover as StaticBody3D).collision_layer
				== COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
			)
			var cover_cell: Vector2i = cover.get_meta("road_cell")
			assert(city.call("_is_road_cell", cover_cell))
			assert(not city.call("_is_subway_vehicle_clearance_cell", cover_cell))
			assert(not (city.get("vertical_roads").has(cover_cell.x) and city.get("horizontal_roads").has(cover_cell.y)))
			var cover_collision := cover.get_node("CoverCollision") as CollisionShape3D
			var cover_shape := cover_collision.shape as BoxShape3D
			assert(maxf(cover_shape.size.x, cover_shape.size.z) <= 6.2)
			assert(minf(cover_shape.size.x, cover_shape.size.z) <= 1.2)
			var cover_type := str(cover.get_meta("cover_type"))
			if cover_type.ends_with("axis_a"):
				assert(cover_shape.size.z > cover_shape.size.x)
			elif cover_type.ends_with("axis_b"):
				assert(cover_shape.size.x > cover_shape.size.z)
			assert(cover.get_node("CoverSprite") is Sprite3D)
			var debug_mesh := cover.get_node("CoverCollisionDebug") as MeshInstance3D
			var debug_plane := debug_mesh.mesh as PlaneMesh
			assert(debug_plane.size == Vector2(cover_shape.size.x, cover_shape.size.z))
			assert(debug_mesh.visible)
			var projectile_cross_axis := (
				Vector3(0.0, 0.0, 1.0)
				if cover_shape.size.x >= cover_shape.size.z
				else Vector3(1.0, 0.0, 0.0)
			)
			var projectile_cross_distance := minf(cover_shape.size.x, cover_shape.size.z) * 0.5 + 0.7
			var cover_center := cover_collision.global_position
			var projectile_query := PhysicsRayQueryParameters3D.create(
				cover_center - projectile_cross_axis * projectile_cross_distance,
				cover_center + projectile_cross_axis * projectile_cross_distance,
				COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
			)
			var projectile_hit := city.get_world_3d().direct_space_state.intersect_ray(projectile_query)
			assert(not projectile_hit.is_empty())
			assert(projectile_hit.get("collider") == cover)
		var street_props := get_nodes_in_group("street_prop_obstacle")
		assert(street_props.size() >= 3)
		for prop_node in street_props:
			var prop := prop_node as StaticBody3D
			assert(prop != null)
			assert(prop.collision_layer == COLLISION_PROFILES.WORLD_MOVEMENT_LAYER)
			assert(prop.get_node_or_null("StreetPropSprite") is Sprite3D)
			var prop_collision := prop.get_node("StreetPropCollision") as CollisionShape3D
			var prop_shape := prop_collision.shape as BoxShape3D
			assert(prop_shape != null)
			assert(prop_shape.size == prop.get_meta("collision_world_size"))
			var prop_debug := prop.get_node("StreetPropCollisionDebug") as MeshInstance3D
			var prop_debug_plane := prop_debug.mesh as PlaneMesh
			assert(prop_debug_plane.size == Vector2(prop_shape.size.x, prop_shape.size.z))
			generated_prop_ids[str(prop.get_meta("prop_id"))] = true
		var blocked_cover := road_covers[0] as Node3D
		var physically_open: Vector3 = city.call(
			"find_nearest_physically_open_position",
			blocked_cover.global_position,
			0.62,
			[]
		)
		assert(physically_open.distance_to(blocked_cover.global_position) > 0.5)
		_assert_sealed_landmark(city, playgrounds[0], "UrbanPlaygroundCollision")
		assert(apartment_cells.is_empty())
		assert(apartment_origin == Vector2i(-1, -1))
		assert(get_nodes_in_group("urban_apartment_complex").is_empty())
		assert(get_nodes_in_group("apartment_gate").is_empty())
		assert(get_nodes_in_group("apartment_portal_site").is_empty())
		assert(get_nodes_in_group("apartment_portal_blocker").is_empty())
		assert(float(city.call("get_map_limit")) > 210.0)

		var anchors: Dictionary = city.get("district_anchors")
		var zones: Dictionary = city.get("cell_zones")
		var signature_roads: Dictionary = city.get("district_signature_road_cells")
		var building_by_cell: Dictionary = city.get("building_type_by_cell")
		var expected_anchor_buildings := {
			"market_lane": ["seoul_market_row_8x4_v1", "seoul_laundromat_repair_8x4_v1"],
			"multi_family": ["seoul_multifamily_villa_6x6_v1", "seoul_redbrick_corner_villa_6x6_v1"],
			"luxury_core": ["gangnam_luxury_showroom_6x6_v1"],
		}
		for district_name in expected_anchor_buildings:
			assert(anchors.has(district_name))
			assert(signature_roads.has(district_name))
			var anchor_cell: Vector2i = anchors[district_name]
			assert(str(zones[anchor_cell]) == district_name)
			assert(expected_anchor_buildings[district_name].has(str(building_by_cell[anchor_cell])))
			for other_name in expected_anchor_buildings:
				if other_name == district_name:
					continue
				assert(_block_distance(anchor_cell, anchors[other_name]) >= 6)
		assert(get_nodes_in_group("market_handcart").size() >= 1)
		for handcart in get_nodes_in_group("market_handcart"):
			assert(handcart is StaticBody3D)
			# 손수레도 같은 이유로 레이어 1이 아니라 WORLD_MOVEMENT_LAYER 다.
			assert((handcart as StaticBody3D).collision_layer == COLLISION_PROFILES.WORLD_MOVEMENT_LAYER)
			assert((handcart as Node).get_node_or_null("HandcartCollision") != null)
		var has_luxury_sedan := false
		for vehicle in get_nodes_in_group("vehicle_obstacle"):
			var vehicle_cell: Vector2i = city.call("world_to_map_cell", (vehicle as Node3D).global_position)
			for subway_cell in subways:
				assert(_block_distance(vehicle_cell, subway_cell) > 1)
			if str((vehicle as Node).get_meta("vehicle_type")) == "luxury_sedan":
				has_luxury_sedan = true
		assert(has_luxury_sedan)

		var low_count := 0
		var high_count := 0
		for building in get_nodes_in_group("camera_occluder"):
			if not building.has_meta("height_class"):
				continue
			var height_class := str(building.get_meta("height_class"))
			var definition: Dictionary = building_catalog.get_definition(str(building.get_meta("building_id")))
			var footprint: Vector2i = definition["footprint_modules"]
			var collision := building.get_node_or_null("BuildingCollision") as CollisionShape3D
			assert(collision != null)
			var collision_box := collision.shape as BoxShape3D
			assert(is_equal_approx(collision_box.size.x, footprint.x * 2.0))
			assert(is_equal_approx(collision_box.size.z, footprint.y * 2.0))
			var sprite := building.get_node_or_null("BuildingSprite") as Sprite3D
			var source_size: Vector2i = definition.get(
				"source_size",
				Vector2i(sprite.texture.get_width(), sprite.texture.get_height())
			)
			var corner_scale := Vector2(
				float(sprite.texture.get_width()) / float(source_size.x),
				float(sprite.texture.get_height()) / float(source_size.y)
			)
			var corners: Array = definition["footprint_corners_px"]
			var bottom_corner: Vector2 = (corners[3] as Vector2) * corner_scale
			assert(is_equal_approx(sprite.offset.x, sprite.texture.get_width() * 0.5 - bottom_corner.x))
			var planning_cell: Vector2i = building.get_meta("planning_cell")
			var cell_center: Vector3 = city.call("_cell_center", planning_cell)
			var half_size := Vector2(collision_box.size.x, collision_box.size.z) * 0.5
			if city.call("_is_road_cell", planning_cell + Vector2i.LEFT):
				assert(building.global_position.x - half_size.x >= cell_center.x - 6.01)
			if city.call("_is_road_cell", planning_cell + Vector2i.RIGHT):
				assert(building.global_position.x + half_size.x <= cell_center.x + 6.01)
			if city.call("_is_road_cell", planning_cell + Vector2i.UP):
				assert(building.global_position.z - half_size.y >= cell_center.z - 6.01)
			if city.call("_is_road_cell", planning_cell + Vector2i.DOWN):
				assert(building.global_position.z + half_size.y <= cell_center.z + 6.01)
			if height_class == "low":
				low_count += 1
				generated_lowrise_ids[str(building.get_meta("building_id"))] = true
			if height_class != "high":
				continue
			high_count += 1
			var building_cell: Vector2i = building.get_meta("planning_cell")
			for playground_cell in playgrounds:
				assert(_block_distance(building_cell, playground_cell) > 2)
			for apartment_cell in apartment_cells:
				assert(_block_distance(building_cell, apartment_cell) > 2)
		assert(low_count > high_count)
		var interior_portals := get_nodes_in_group("building_entrance_portal")
		assert(interior_portals.size() >= 1)
		assert(interior_portals.size() <= 3)
		for portal_node in interior_portals:
			var portal := portal_node as Area3D
			assert(portal.is_in_group("field_interaction"))
			assert(str(portal.get_meta("interaction_type", "")) == "building_portal")
			assert(portal.get_node_or_null("EntranceMarker") != null)
			assert(portal.get_node_or_null("EntrancePrompt") != null)
			var building := portal.get_parent() as StaticBody3D
			assert(building != null and bool(building.get_meta("interior_accessible", false)))
			var building_collision := building.get_node("BuildingCollision") as CollisionShape3D
			var building_box := building_collision.shape as BoxShape3D
			var frontage := str(portal.get_meta("frontage", ""))
			if frontage in ["west", "east"]:
				assert(absf(portal.position.x) > building_box.size.x * 0.5)
			else:
				assert(absf(portal.position.z) > building_box.size.z * 0.5)

		city.queue_free()
		await process_frame

	assert(generated_lowrise_ids.has("gangnam_lowrise_commercial_8x4_aligned"))
	assert(generated_lowrise_ids.has("gangnam_lowrise_garage_8x4_aligned"))
	assert(generated_lowrise_ids.has("seoul_market_row_8x4_v1"))
	assert(generated_prop_ids.has("dumpster_cluster"))
	assert(generated_prop_ids.has("vending_cluster"))
	assert(generated_prop_ids.has("construction_cluster"))
	assert(building_catalog.get_definition("gangnam_lowrise_commercial_8x4_aligned")["footprint_modules"] == Vector2i(4, 8))
	print("CITY_PLANNING_OK seeds=5 parks=0 playgrounds=2 subways=2 apartments=0 districts=3 lowrise_types=%d" % generated_lowrise_ids.size())
	quit(0)
