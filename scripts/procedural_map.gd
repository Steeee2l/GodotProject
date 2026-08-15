class_name ProceduralCityMap
extends Node3D

const GRID_SIZE := 22
const WORLD_SCALE := 2.0
const BASE_CELL_SIZE := 10.0
const CELL_SIZE := BASE_CELL_SIZE * WORLD_SCALE
const MAP_SIZE := GRID_SIZE * CELL_SIZE
const SIDEWALK_WIDTH := 2.0 * WORLD_SCALE
const ISOMETRIC_VERTICAL_PROJECTION := 0.816496580927726
const BUILDING_CATALOG := preload("res://scripts/building_catalog.gd")
const LANDMARK_CATALOG := preload("res://scripts/urban_landmark_catalog.gd")
const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const STREET_PROP_CATALOG := preload("res://scripts/street_prop_catalog.gd")
const RAID_REGION_CATALOG := preload("res://scripts/raid_region_catalog.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const BUILDING_ENTRANCE_SCENE := preload("res://scenes/modules/building_entrance_portal.tscn")
const OPEN_SPACE_HIGH_RISE_BUFFER_CELLS := 2
const OPEN_SPACE_MID_RISE_BUFFER_CELLS := 1
const TARGET_PLAYGROUND_COUNT := 2
const TARGET_SUBWAY_COUNT := 2
const APARTMENT_HIGH_RISE_BUFFER_CELLS := 2
const FAR_DEPTH_OPEN_CELL := Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)
const ROAD_SETBACK_MODULES := 4
const INTERIOR_SETBACK_MODULES := 1
const ROAD_VEHICLE_CHANCE := 0.46
const ROAD_COVER_OBSTACLE_CHANCE := 0.68
const COLLISION_DEBUG_FOCUS_PROFILES := {
	"vehicle_standard": true,
	"vehicle_heavy": true,
	"road_barricade": true,
	"rubble_wall": true,
}
const DISTRICT_RADIUS_CELLS := 2
const DISTRICT_MIN_SEPARATION_CELLS := 6
const ROAD_COVER_DEFINITIONS := {
	"concrete_barricade_axis_a": {
		"texture_path": "res://assets/props/road_cover/concrete_barricade_axis_a_v1.png",
		"collision_size": Vector3(0.82, 1.2, 6.10),
		"pixel_size": 0.00375,
		"footprint_corners_px": [
			Vector2(136, 617),
			Vector2(1170, 84),
			Vector2(1440, 492),
			Vector2(330, 962),
		],
	},
	"concrete_barricade_axis_b": {
		"texture_path": "res://assets/props/road_cover/concrete_barricade_axis_b_v1.png",
		"collision_size": Vector3(5.15, 1.2, 0.82),
		"pixel_size": 0.00375,
		"footprint_corners_px": [
			Vector2(192, 470),
			Vector2(386, 92),
			Vector2(1318, 824),
			Vector2(1075, 928),
		],
	},
	"rubble_wall_axis_a": {
		"texture_path": "res://assets/props/road_cover/rubble_wall_axis_a_v1.png",
		"collision_size": Vector3(1.12, 1.45, 4.45),
		"pixel_size": 0.00355,
		"footprint_corners_px": [
			Vector2(198, 785),
			Vector2(1120, 84),
			Vector2(1308, 475),
			Vector2(420, 906),
		],
	},
	"rubble_wall_axis_b": {
		"texture_path": "res://assets/props/road_cover/rubble_wall_axis_b_v1.png",
		"collision_size": Vector3(4.82, 1.45, 1.12),
		"pixel_size": 0.00355,
		"footprint_corners_px": [
			Vector2(174, 480),
			Vector2(337, 92),
			Vector2(1356, 850),
			Vector2(1160, 906),
		],
	},
}
const MARKET_HANDCART_TEXTURE_PATH := "res://assets/props/market_handcart_v1.png"
const MARKET_HANDCART_COLLISION_SIZE := Vector3(4.2, 1.55, 2.15)
const MARKET_HANDCART_FOOTPRINT_CORNERS := [
	Vector2(67, 870),
	Vector2(785, 510),
	Vector2(1180, 705),
	Vector2(307, 1047),
]
const ASPHALT_TEXTURE := preload("res://assets/tiles/asphalt.png")
const CONCRETE_TEXTURE := preload("res://assets/tiles/concrete.png")
const RIVER_TEXTURE_PATH := "res://assets/tiles/river_water_generated.png"
const PARKING_TEXTURE_PATH := "res://assets/tiles/parking_lot_generated.png"
const BRIDGE_DECK_TEXTURE_PATH := "res://assets/tiles/bridge_deck_generated.png"
const GUARDRAIL_TEXTURE_PATH := "res://assets/tiles/guardrail_metal_generated.png"
const OPEN_LOT_TEXTURE_PATHS := [
	"res://assets/tiles/open_lot_demolition_generated.png",
	"res://assets/tiles/open_lot_courtyard_generated.png",
]
const OUTER_GROUND_TEXTURE_PATH := "res://assets/backgrounds/apocalypse_seoul_outer_ground_v2.png"
const OUTER_BACKDROP_SIZE := 1040.0
const FIELD_RETURN_CELL := Vector2i(2, 2)
const MAX_ENTERABLE_BUILDINGS := 3

@export var map_seed: int = 0
@export var raid_zone_id: String = ""

var rng := RandomNumberGenerator.new()
var vertical_roads: Array[int] = []
var horizontal_roads: Array[int] = []
var river_columns := PackedInt32Array()
var river_center_x := 0
var building_cells := {}
var parking_cells := {}
var open_cells := {}
var waterfront_cells := {}
var park_cells: Array[Vector2i] = []
var playground_cells: Array[Vector2i] = []
var subway_cells: Array[Vector2i] = []
var apartment_origin := Vector2i(-1, -1)
var apartment_cells: Array[Vector2i] = []
var cell_zones := {}
var building_type_by_cell := {}
var district_anchors := {}
var district_signature_road_cells := {}
var cell_risk_bands := {}
var enterable_building_count := 0
var region_profile := {}
var collision_debug_enabled := true
var generated_obstacle_footprints: Array[Dictionary] = []
var generated_overlap_report: Array[Dictionary] = []

var asphalt_material: StandardMaterial3D
var lot_material: StandardMaterial3D
var sidewalk_material: StandardMaterial3D
var sidewalk_edge_material: StandardMaterial3D
var marking_material: StandardMaterial3D
var curb_material: StandardMaterial3D
var water_material: StandardMaterial3D
var riverbank_material: StandardMaterial3D
var bridge_material: StandardMaterial3D
var vehicle_collision_material: StandardMaterial3D
var parking_material: StandardMaterial3D
var bridge_deck_material: StandardMaterial3D
var bridge_rail_material: StandardMaterial3D
var open_lot_materials: Array[StandardMaterial3D] = []
var outer_ground_material: StandardMaterial3D


func _ready() -> void:
	if raid_zone_id.is_empty():
		raid_zone_id = GameState.selected_raid_zone
	region_profile = RAID_REGION_CATALOG.get_profile(raid_zone_id)
	raid_zone_id = str(region_profile.get("zone_id", RAID_REGION_CATALOG.DEFAULT_ZONE_ID))
	set_meta("raid_zone_id", raid_zone_id)
	set_meta("region_identity", str(region_profile.get("identity", "")))
	if map_seed == 0:
		map_seed = GameState.map_seed
	rng.seed = map_seed
	_generate_layout()
	_build_materials()
	_build_outer_city_backdrop()
	_build_perimeter_fences()
	_build_floor_collision()
	_build_tiles()
	_build_zoned_lots()
	_audit_generated_obstacle_overlaps()


func _generate_layout() -> void:
	_clear_layout_state()
	vertical_roads = _roll_road_bands(region_profile.get("vertical_road_bands", []))
	horizontal_roads = _roll_road_bands(region_profile.get("horizontal_road_bands", []))
	vertical_roads.sort()
	horizontal_roads.sort()

	if bool(region_profile.get("river_enabled", true)):
		river_center_x = GRID_SIZE / 2 + rng.randi_range(-1, 0)
		for z in range(GRID_SIZE):
			river_columns.append(river_center_x)
	else:
		river_center_x = -100

	var eligible_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var cell := Vector2i(x, z)
			if _is_apartment_cell(cell) or _is_road_cell(cell) or _is_river_cell(cell):
				continue
			if _is_waterfront_cell(cell):
				waterfront_cells[cell] = true
				continue
			if cell == FAR_DEPTH_OPEN_CELL:
				open_cells[cell] = true
				continue
			eligible_cells.append(cell)

	_select_planned_landmarks(eligible_cells)
	_select_district_anchors(eligible_cells)
	_assign_zoning_districts(eligible_cells)
	for cell in eligible_cells:
		if _is_landmark_cell(cell):
			continue
		var zone := str(cell_zones.get(cell, "street_mixed"))
		var building_chance := float({
			"market_lane": 0.72,
			"luxury_core": 0.68,
			"multi_family": 0.66,
			"business_corner": 0.58,
			"street_mixed": 0.48,
			"residential_buffer": 0.32,
			"open_space_edge": 0.24,
			"service_interior": 0.34,
		}.get(zone, 0.42)) * float(region_profile.get("building_chance_multiplier", 1.0))
		building_chance = clampf(building_chance, 0.08, 0.92)
		if district_anchors.values().has(cell) or rng.randf() < building_chance:
			building_cells[cell] = true

	for cell in eligible_cells:
		if building_cells.has(cell):
			continue
		if _has_building_within(cell, 1):
			open_cells[cell] = true
		elif _distance_to_cells(cell, subway_cells) <= 1:
			open_cells[cell] = true
		elif _touches_road(cell) and rng.randf() < float(region_profile.get("parking_chance", 0.58)):
			parking_cells[cell] = true
		else:
			open_cells[cell] = true
	_assign_risk_bands()


func _clear_layout_state() -> void:
	vertical_roads.clear()
	horizontal_roads.clear()
	river_columns.clear()
	building_cells.clear()
	parking_cells.clear()
	open_cells.clear()
	waterfront_cells.clear()
	park_cells.clear()
	playground_cells.clear()
	subway_cells.clear()
	apartment_cells.clear()
	cell_zones.clear()
	building_type_by_cell.clear()
	district_anchors.clear()
	district_signature_road_cells.clear()
	cell_risk_bands.clear()
	generated_obstacle_footprints.clear()
	generated_overlap_report.clear()
	apartment_origin = Vector2i(-1, -1)
	enterable_building_count = 0


func _roll_road_bands(raw_bands: Array) -> Array[int]:
	var roads: Array[int] = []
	for raw_band in raw_bands:
		var band: Vector2i = raw_band
		var road_index := rng.randi_range(
			clampi(band.x, 1, GRID_SIZE - 2),
			clampi(band.y, 1, GRID_SIZE - 2)
		)
		if not roads.has(road_index):
			roads.append(road_index)
	if roads.is_empty():
		roads = [2, 6, 10, 15, 20]
	return roads


func _assign_risk_bands() -> void:
	var split: Vector2 = region_profile.get("risk_split", Vector2(0.34, 0.70))
	var farthest_cell := Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)
	var maximum_distance := Vector2(farthest_cell - FIELD_RETURN_CELL).length()
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var cell := Vector2i(x, z)
			var normalized_distance := (
				Vector2(cell - FIELD_RETURN_CELL).length() / maxf(1.0, maximum_distance)
			)
			var risk_band := "safe" if normalized_distance <= split.x else "scavenge"
			if normalized_distance >= split.y:
				risk_band = "restricted"
			cell_risk_bands[cell] = risk_band


func _assign_zoning_districts(eligible_cells: Array[Vector2i]) -> void:
	for cell in eligible_cells:
		var zone := "service_interior"
		var planned_district := _planned_district_for_cell(cell)
		if not planned_district.is_empty():
			zone = planned_district
		elif _distance_to_cells(cell, playground_cells) <= 1:
			zone = "open_space_edge"
		elif _distance_to_cells(cell, apartment_cells) <= 2:
			zone = "residential_buffer"
		elif _is_near_road_intersection(cell, 1):
			zone = "business_corner"
		elif _touches_road(cell):
			zone = "street_mixed"
		cell_zones[cell] = zone


func _select_district_anchors(eligible_cells: Array[Vector2i]) -> void:
	district_anchors.clear()
	district_signature_road_cells.clear()
	var luxury_anchor := _pick_district_anchor(eligible_cells, [], true, false)
	if luxury_anchor.x >= 0:
		district_anchors["luxury_core"] = luxury_anchor
	var occupied: Array[Vector2i] = []
	if luxury_anchor.x >= 0:
		occupied.append(luxury_anchor)
	var market_anchor := _pick_district_anchor(eligible_cells, occupied, false, true)
	if market_anchor.x >= 0:
		district_anchors["market_lane"] = market_anchor
		occupied.append(market_anchor)
	var residential_anchor := _pick_district_anchor(eligible_cells, occupied, false, false)
	if residential_anchor.x >= 0:
		district_anchors["multi_family"] = residential_anchor

	for district_name in district_anchors:
		var anchor: Vector2i = district_anchors[district_name]
		var road_cell := _first_adjacent_road(anchor)
		if road_cell.x >= 0:
			district_signature_road_cells[district_name] = road_cell


func _district_anchor_for(district_name: String) -> Vector2i:
	if not district_anchors.has(district_name):
		return Vector2i(-1, -1)
	var anchor: Vector2i = district_anchors[district_name]
	return anchor


func _pick_district_anchor(
	eligible_cells: Array[Vector2i],
	occupied: Array[Vector2i],
	require_intersection: bool,
	avoid_intersection: bool
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in eligible_cells:
		if _is_landmark_cell(cell) or not _touches_road(cell):
			continue
		if _distance_to_cells(cell, playground_cells) <= 3:
			continue
		if _distance_to_cells(cell, subway_cells) <= 1:
			continue
		if _distance_to_cells(cell, apartment_cells) <= APARTMENT_HIGH_RISE_BUFFER_CELLS:
			continue
		var minimum_separation := int(region_profile.get(
			"district_min_separation", DISTRICT_MIN_SEPARATION_CELLS
		))
		if not occupied.is_empty() and _distance_to_cells(cell, occupied) < minimum_separation:
			continue
		var near_intersection := _is_near_road_intersection(cell, 1)
		if require_intersection and not near_intersection:
			continue
		if avoid_intersection and near_intersection:
			continue
		candidates.append(cell)
	if candidates.is_empty() and (require_intersection or avoid_intersection):
		return _pick_district_anchor(eligible_cells, occupied, false, false)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _planned_district_for_cell(cell: Vector2i) -> String:
	var closest_district := ""
	var district_radius := int(region_profile.get("district_radius", DISTRICT_RADIUS_CELLS))
	var closest_distance := district_radius + 1
	for district_name in ["market_lane", "luxury_core", "multi_family"]:
		if not district_anchors.has(district_name):
			continue
		var distance := _block_distance(cell, district_anchors[district_name])
		if distance <= district_radius and distance < closest_distance:
			closest_distance = distance
			closest_district = district_name
	return closest_district


func _first_adjacent_road(cell: Vector2i) -> Vector2i:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var candidate: Vector2i = cell + Vector2i(direction)
		if _is_road_cell(candidate):
			return candidate
	return Vector2i(-1, -1)


func _select_planned_landmarks(eligible_cells: Array[Vector2i]) -> void:
	var shuffled := eligible_cells.duplicate()
	shuffled.shuffle()
	var playground_target := int(region_profile.get("playground_count", TARGET_PLAYGROUND_COUNT))
	var subway_target := int(region_profile.get("subway_count", TARGET_SUBWAY_COUNT))
	for cell in shuffled:
		if playground_cells.size() >= playground_target:
			break
		if not _touches_road(cell):
			continue
		if _distance_to_cells(cell, playground_cells) < 5:
			continue
		if not _is_near_road_intersection(cell, 2):
			continue
		playground_cells.append(cell)

	for cell in shuffled:
		if subway_cells.size() >= subway_target:
			break
		if _is_landmark_cell(cell) or not _touches_road(cell):
			continue
		if not _is_near_road_intersection(cell, 1):
			continue
		if _distance_to_cells(cell, playground_cells) <= 1 or _distance_to_cells(cell, subway_cells) < 4:
			continue
		subway_cells.append(cell)


func _is_landmark_cell(cell: Vector2i) -> bool:
	return playground_cells.has(cell) or subway_cells.has(cell) or _is_apartment_cell(cell)


func _is_apartment_cell(cell: Vector2i) -> bool:
	return apartment_cells.has(cell)


func _is_subway_vehicle_clearance_cell(cell: Vector2i) -> bool:
	return _distance_to_cells(cell, subway_cells) <= 1


func _is_apartment_gate_clearance_cell(cell: Vector2i) -> bool:
	return apartment_origin.x >= 0 and cell == apartment_origin + Vector2i(2, 0)


func _block_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _distance_to_cells(cell: Vector2i, cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return 999
	var nearest := 999
	for other_cell in cells:
		nearest = mini(nearest, _block_distance(cell, other_cell))
	return nearest


func _is_near_road_intersection(cell: Vector2i, radius: int) -> bool:
	for offset_x in range(-radius, radius + 1):
		for offset_z in range(-radius, radius + 1):
			var candidate := cell + Vector2i(offset_x, offset_z)
			if vertical_roads.has(candidate.x) and horizontal_roads.has(candidate.y):
				return true
	return false


func _has_building_within(cell: Vector2i, radius: int) -> bool:
	for offset_x in range(-radius, radius + 1):
		for offset_z in range(-radius, radius + 1):
			if building_cells.has(cell + Vector2i(offset_x, offset_z)):
				return true
	return false


func _touches_road(cell: Vector2i) -> bool:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_road_cell(cell + direction):
			return true
	return false


func _build_materials() -> void:
	var ground_texture: Texture2D = ASPHALT_TEXTURE
	var ground_texture_path := str(region_profile.get("ground_texture_path", ""))
	if not ground_texture_path.is_empty() and ResourceLoader.exists(ground_texture_path):
		ground_texture = load(ground_texture_path) as Texture2D
	var asphalt_tint: Color = region_profile.get("asphalt_tint", Color.WHITE)
	var lot_tint: Color = region_profile.get("lot_tint", Color("#77756f"))
	var sidewalk_tint: Color = region_profile.get("sidewalk_tint", Color("#aaa79e"))
	var marking_tint: Color = region_profile.get("marking_tint", Color("#d1c87d"))
	var outer_tint: Color = region_profile.get("outer_tint", Color(0.62, 0.66, 0.66, 1.0))
	asphalt_material = _texture_material(
		ground_texture,
		asphalt_tint
	)
	lot_material = _texture_material(
		ground_texture if raid_zone_id != RAID_REGION_CATALOG.DEFAULT_ZONE_ID else CONCRETE_TEXTURE,
		lot_tint
	)
	sidewalk_material = _texture_material(
		CONCRETE_TEXTURE,
		sidewalk_tint
	)
	sidewalk_edge_material = _color_material(Color("#64645f"))
	marking_material = _color_material(marking_tint)
	curb_material = _color_material(Color("#8b8981"))
	if ResourceLoader.exists(RIVER_TEXTURE_PATH):
		water_material = _texture_material(load(RIVER_TEXTURE_PATH) as Texture2D, Color("#b9dce2"))
	else:
		water_material = _color_material(Color("#264d59"))
	water_material.metallic = 0.12
	water_material.roughness = 0.38
	if ResourceLoader.exists(PARKING_TEXTURE_PATH):
		parking_material = _texture_material(load(PARKING_TEXTURE_PATH) as Texture2D)
	else:
		parking_material = asphalt_material
	riverbank_material = _color_material(Color("#4f5146"))
	bridge_material = _color_material(Color("#575b5d"))
	if ResourceLoader.exists(BRIDGE_DECK_TEXTURE_PATH):
		bridge_deck_material = _texture_material(load(BRIDGE_DECK_TEXTURE_PATH) as Texture2D)
	else:
		bridge_deck_material = asphalt_material
	if ResourceLoader.exists(GUARDRAIL_TEXTURE_PATH):
		bridge_rail_material = _texture_material(load(GUARDRAIL_TEXTURE_PATH) as Texture2D)
	else:
		bridge_rail_material = _color_material(Color("#796d58"))
	bridge_rail_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for texture_path in OPEN_LOT_TEXTURE_PATHS:
		if ResourceLoader.exists(texture_path):
			open_lot_materials.append(_texture_material(load(texture_path) as Texture2D))
	if open_lot_materials.is_empty():
		open_lot_materials.append(lot_material)
	if ResourceLoader.exists(OUTER_GROUND_TEXTURE_PATH):
		outer_ground_material = _texture_material(
			load(OUTER_GROUND_TEXTURE_PATH) as Texture2D,
			outer_tint
		)
		outer_ground_material.texture_repeat = true
		outer_ground_material.uv1_scale = Vector3(12.0, 12.0, 1.0)
	vehicle_collision_material = _color_material(Color(1.0, 0.02, 0.02, 0.46))
	vehicle_collision_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vehicle_collision_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vehicle_collision_material.no_depth_test = true
	vehicle_collision_material.render_priority = 120


func _build_outer_city_backdrop() -> void:
	if outer_ground_material:
		var outer_ground := MeshInstance3D.new()
		outer_ground.name = "ApocalypseSeoulOuterGround"
		outer_ground.position.y = -0.32
		outer_ground.add_to_group("outer_city_ground")
		outer_ground.set_meta("collision_free", true)
		var ground_mesh := PlaneMesh.new()
		ground_mesh.size = Vector2(OUTER_BACKDROP_SIZE, OUTER_BACKDROP_SIZE)
		ground_mesh.material = outer_ground_material
		outer_ground.mesh = ground_mesh
		outer_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(outer_ground)

	# Do not add vertical transparent skyline sprites here. At the north/west map
	# edges the mobile isometric camera can intersect their large transparent
	# quads, making distant towers look like a full-screen afterimage over roads
	# and characters. The collision-free ruined ground remains as the safe outer
	# backdrop; future horizon art must be camera-composited instead of world
	# billboards.


func _build_perimeter_fences() -> void:
	var fence_root := Node3D.new()
	fence_root.name = "OuterPerimeterFence"
	fence_root.add_to_group("outer_perimeter_fence")
	add_child(fence_root)

	var edge := MAP_SIZE * 0.5 + 1.55
	var length := MAP_SIZE + 3.1
	var rail_material := bridge_rail_material if bridge_rail_material != null else curb_material
	for rail_height in [0.62, 1.08]:
		_add_box_to(fence_root, "FenceRailNorth_%s" % rail_height, Vector3(0.0, rail_height, -edge), Vector3(length, 0.12, 0.14), rail_material)
		_add_box_to(fence_root, "FenceRailSouth_%s" % rail_height, Vector3(0.0, rail_height, edge), Vector3(length, 0.12, 0.14), rail_material)
		_add_box_to(fence_root, "FenceRailWest_%s" % rail_height, Vector3(-edge, rail_height, 0.0), Vector3(0.14, 0.12, length), rail_material)
		_add_box_to(fence_root, "FenceRailEast_%s" % rail_height, Vector3(edge, rail_height, 0.0), Vector3(0.14, 0.12, length), rail_material)

	var post_step := 18.0
	var post_count := int(ceil(length / post_step)) + 1
	var first := -length * 0.5
	for index in range(post_count):
		var offset := clampf(first + index * post_step, -length * 0.5, length * 0.5)
		_add_box_to(fence_root, "FencePostNorth_%d" % index, Vector3(offset, 0.7, -edge), Vector3(0.28, 1.4, 0.28), rail_material)
		_add_box_to(fence_root, "FencePostSouth_%d" % index, Vector3(offset, 0.7, edge), Vector3(0.28, 1.4, 0.28), rail_material)
		_add_box_to(fence_root, "FencePostWest_%d" % index, Vector3(-edge, 0.7, offset), Vector3(0.28, 1.4, 0.28), rail_material)
		_add_box_to(fence_root, "FencePostEast_%d" % index, Vector3(edge, 0.7, offset), Vector3(0.28, 1.4, 0.28), rail_material)
	_add_perimeter_collision()


func _add_perimeter_collision() -> void:
	var edge := MAP_SIZE * 0.5 + 1.4
	var length := MAP_SIZE + 8.0
	_add_static_collision_box("PerimeterNorthCollision", Vector3(0.0, 1.2, -edge), Vector3(length, 2.4, 2.8))
	_add_static_collision_box("PerimeterSouthCollision", Vector3(0.0, 1.2, edge), Vector3(length, 2.4, 2.8))
	_add_static_collision_box("PerimeterWestCollision", Vector3(-edge, 1.2, 0.0), Vector3(2.8, 2.4, length))
	_add_static_collision_box("PerimeterEastCollision", Vector3(edge, 1.2, 0.0), Vector3(2.8, 2.4, length))


func _build_floor_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "MapFloor"
	body.position.y = -0.1
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	collision.shape = shape
	body.add_child(collision)


func _build_tiles() -> void:
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var cell := Vector2i(x, z)
			var center := _cell_center(cell)
			var is_river := _is_river_cell(cell)
			var is_road := _is_road_cell(cell)
			if is_river and horizontal_roads.has(z):
				_build_river_cell(center, false)
				_build_bridge_cell(center, vertical_roads.has(x), horizontal_roads.has(z))
			elif is_river:
				_build_river_cell(center, true)
			elif is_road:
				_build_road_cell(cell, center, vertical_roads.has(x), horizontal_roads.has(z))
			else:
				_build_lot_cell(center, cell)


func _build_lot_cell(center: Vector3, cell: Vector2i) -> void:
	_add_plane("LotPaving", center, Vector2(CELL_SIZE, CELL_SIZE), lot_material, 0.0)
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + direction
		if _is_road_cell(neighbor):
			_add_lot_sidewalk(center, Vector3(direction.x, 0, direction.y))


func _build_road_cell(cell: Vector2i, center: Vector3, vertical: bool, horizontal: bool) -> void:
	_add_plane("AsphaltRoad", center, Vector2(CELL_SIZE, CELL_SIZE), asphalt_material, 0.01)
	if vertical and horizontal:
		_add_crosswalks(center)
	elif vertical:
		_add_lane_dash(center, true)
	else:
		_add_lane_dash(center, false)
	var is_luxury_signature: bool = (
		district_signature_road_cells.get("luxury_core", Vector2i(-1, -1)) == cell
	)
	if (
		vertical != horizontal
		and not _is_subway_vehicle_clearance_cell(cell)
		and not _is_apartment_gate_clearance_cell(cell)
		and (is_luxury_signature or not _is_road_cover_clearance_cell(cell, vertical))
	):
		if is_luxury_signature:
			_spawn_road_cover_vehicle(center, vertical, "luxury_core", true)
		elif rng.randf() < float(region_profile.get("vehicle_chance", ROAD_VEHICLE_CHANCE)):
			_spawn_road_cover_vehicle(center, vertical, _road_district(cell))
		elif rng.randf() < float(region_profile.get("cover_chance", ROAD_COVER_OBSTACLE_CHANCE)):
			_spawn_road_cover_obstacle(cell, center, vertical)


func _is_road_cover_clearance_cell(cell: Vector2i, vertical: bool) -> bool:
	# Keep regular gaps on every long road so procedural cover never seals a lane.
	var lane_index := cell.y if vertical else cell.x
	var cross_index := cell.x if vertical else cell.y
	return posmod(lane_index + cross_index * 2, 5) == 0


func _road_district(cell: Vector2i) -> String:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var zone := str(cell_zones.get(cell + direction, ""))
		if zone in ["market_lane", "luxury_core", "multi_family"]:
			return zone
	return ""


func _build_river_cell(center: Vector3, block_movement: bool) -> void:
	_add_plane("RiverWater", center, Vector2(CELL_SIZE, CELL_SIZE), water_material, -0.04)
	_add_plane("RiverBankLeft", center + Vector3(-4.65 * WORLD_SCALE, 0, 0), Vector2(0.7 * WORLD_SCALE, CELL_SIZE), riverbank_material, 0.015)
	_add_plane("RiverBankRight", center + Vector3(4.65 * WORLD_SCALE, 0, 0), Vector2(0.7 * WORLD_SCALE, CELL_SIZE), riverbank_material, 0.015)
	if block_movement:
		var blocker := StaticBody3D.new()
		blocker.name = "RiverBarrier"
		blocker.position = center + Vector3(0, 0.45, 0)
		blocker.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		blocker.collision_mask = 0
		add_child(blocker)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(CELL_SIZE - 0.8 * WORLD_SCALE, 0.9, CELL_SIZE)
		collision.shape = shape
		blocker.add_child(collision)


func _build_bridge_cell(center: Vector3, _vertical: bool, _horizontal: bool) -> void:
	_add_plane("BridgeDeck", center, Vector2(CELL_SIZE, CELL_SIZE), bridge_material, 0.13)
	_add_oriented_plane("BridgeRoadArt", center, Vector2(CELL_SIZE, 8.8 * WORLD_SCALE), bridge_deck_material, 0.15, false)
	_build_guardrails(center, false, 0.15, CELL_SIZE, 4.35 * WORLD_SCALE, true)


func _build_guardrails(
	center: Vector3,
	vertical: bool,
	deck_height: float,
	segment_length: float,
	half_width: float,
	with_collision: bool
) -> void:
	for side in [-1.0, 1.0]:
		var side_offset := Vector3(side * half_width, 0, 0) if vertical else Vector3(0, 0, side * half_width)
		var rail_size := Vector3(0.16, 0.14, segment_length) if vertical else Vector3(segment_length, 0.14, 0.16)
		for rail_height in [0.42, 0.72]:
			_add_box("GuardrailBeam", center + side_offset + Vector3(0, deck_height + rail_height, 0), rail_size, bridge_rail_material)
		for post_index in range(5):
			var post_offset := lerpf(-segment_length * 0.4, segment_length * 0.4, post_index / 4.0)
			var post_position := center + side_offset
			if vertical:
				post_position.z += post_offset
			else:
				post_position.x += post_offset
			_add_box("GuardrailPost", post_position + Vector3(0, deck_height + 0.39, 0), Vector3(0.2, 0.78, 0.2), bridge_rail_material)
		if with_collision:
			var collision_size := Vector3(0.32, 1.0, segment_length) if vertical else Vector3(segment_length, 1.0, 0.32)
			_add_static_collision_box("BridgeGuardCollision", center + side_offset + Vector3(0, deck_height + 0.48, 0), collision_size)
func _build_zoned_lots() -> void:
	for cell in playground_cells:
		_spawn_landmark(cell, "playground")
	for cell in subway_cells:
		_spawn_landmark(cell, "subway_entrance")
	for cell in waterfront_cells:
		_build_waterfront_lot(cell)
	for cell in parking_cells:
		_build_parking_lot(cell)
	for cell in building_cells:
		_try_build_building(cell)
	for cell in open_cells:
		_build_open_lot(cell)
	_build_district_props()


func _add_apartment_portal_site(parent: Node3D, local_position: Vector3, size: Vector3) -> void:
	var gate := Area3D.new()
	gate.name = "FutureApartmentPortal"
	gate.position = local_position
	gate.collision_layer = 0
	gate.collision_mask = 0
	gate.add_to_group("apartment_gate")
	gate.add_to_group("apartment_portal_site")
	gate.set_meta("gate_kind", "main_entrance")
	gate.set_meta("road_connected", true)
	gate.set_meta("future_portal", true)
	gate.set_meta("portal_ready", false)
	parent.add_child(gate)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	gate.add_child(collision)



func _build_waterfront_lot(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	var promenade_size := CELL_SIZE - 0.6 * WORLD_SCALE
	_add_plane("RiverfrontPromenade", center, Vector2(promenade_size, promenade_size), sidewalk_material, 0.04)
	var river_side := signf(float(river_center_x - cell.x))
	var edge_position := center + Vector3(river_side * (CELL_SIZE * 0.5 - 0.55), 0, 0)
	_add_plane("RiverfrontEdge", edge_position, Vector2(0.65, promenade_size), riverbank_material, 0.055)


func _spawn_road_cover_vehicle(center: Vector3, vertical: bool, district: String = "", force_signature: bool = false) -> void:
	var vehicle_type := _choose_vehicle_type(district, true)
	if district == "luxury_core" and force_signature:
		vehicle_type = "luxury_sedan"
	var lane_offset := (3.0 if rng.randf() < 0.5 else -3.0) * WORLD_SCALE
	var travel_offset := rng.randf_range(-2.2, 2.2) * WORLD_SCALE
	var position := center + (Vector3(lane_offset, 0.1, travel_offset) if vertical else Vector3(travel_offset, 0.1, lane_offset))
	_spawn_vehicle("RoadCover_%d_%d" % [roundi(center.x), roundi(center.z)], vehicle_type, position, vertical)


func _choose_vehicle_type(district: String, allow_large: bool) -> String:
	var candidates: Array[String] = []
	var profile_pool_key := "large_vehicle_pool" if allow_large else "parked_vehicle_pool"
	var profile_pool: Array = region_profile.get(profile_pool_key, [])
	for vehicle_type_variant in profile_pool:
		var vehicle_type := str(vehicle_type_variant)
		if VEHICLE_CATALOG.DEFINITIONS.has(vehicle_type):
			candidates.append(vehicle_type)
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	match district:
		"luxury_core":
			candidates = ["luxury_sedan", "luxury_sedan", "suv", "taxi", "sedan"]
		"market_lane":
			candidates = ["delivery_van", "delivery_van", "taxi", "sedan", "truck"]
		"multi_family", "residential_buffer":
			candidates = ["suv", "suv", "sedan", "taxi", "delivery_van"]
		_:
			candidates = ["sedan", "sedan", "suv", "taxi", "delivery_van"]
	if allow_large:
		var road_state_roll := rng.randf()
		if road_state_roll < 0.08:
			return "overturned_hatchback"
		if road_state_roll < 0.24:
			return "burned_sedan"
		if rng.randf() < 0.14:
			candidates.append("truck")
		if rng.randf() < 0.055:
			candidates.append("bus")
	else:
		var parked_state_roll := rng.randf()
		if parked_state_roll < 0.16:
			return "intact_hatchback"
		if parked_state_roll < 0.23:
			return "burned_sedan"
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _spawn_road_cover_obstacle(cell: Vector2i, center: Vector3, vertical: bool) -> void:
	var axis_suffix := "b" if vertical else "a"
	var candidates: Array[String] = []
	match str(region_profile.get("cover_style", "mixed")):
		"barricade":
			candidates = ["concrete_barricade_axis_%s" % axis_suffix]
		"rubble":
			candidates = ["rubble_wall_axis_%s" % axis_suffix]
		_:
			candidates = [
				"concrete_barricade_axis_%s" % axis_suffix,
				"rubble_wall_axis_%s" % axis_suffix,
			]
	var cover_type := str(candidates[rng.randi_range(0, candidates.size() - 1)])
	var definition: Dictionary = ROAD_COVER_DEFINITIONS.get(cover_type, {})
	if definition.is_empty():
		return
	var texture_path := str(definition.get("texture_path", ""))
	if not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var lateral_offset := rng.randf_range(-1.35, 1.35) * WORLD_SCALE
	var travel_offset := rng.randf_range(-1.7, 1.7) * WORLD_SCALE
	var position := center + (
		Vector3(lateral_offset, 0.0, travel_offset)
		if vertical
		else Vector3(travel_offset, 0.0, lateral_offset)
	)
	var body := StaticBody3D.new()
	body.name = "RoadCoverObstacle_%d_%d" % [cell.x, cell.y]
	body.position = position
	body.collision_layer = 0
	body.add_to_group("road_cover_obstacle")
	body.add_to_group("cover_obstacle")
	body.set_meta("cover_type", cover_type)
	body.set_meta("road_cell", cell)
	add_child(body)

	var sprite := Sprite3D.new()
	sprite.name = "CoverSprite"
	sprite.texture = texture
	var collision_size: Vector3 = definition.get("collision_size", Vector3(4.0, 1.4, 1.4))
	var footprint_corners: Array = definition.get("footprint_corners_px", [])
	if footprint_corners.size() >= 4:
		var left_corner := footprint_corners[0] as Vector2
		var right_corner := footprint_corners[2] as Vector2
		var footprint_center_px := _footprint_centroid(footprint_corners)
		var base_pixel_width := maxf(1.0, absf(right_corner.x - left_corner.x))
		var projected_width := (collision_size.x + collision_size.z) / sqrt(2.0)
		sprite.pixel_size = projected_width / base_pixel_width
		sprite.offset = Vector2(
			texture.get_width() * 0.5 - footprint_center_px.x,
			texture.get_height() * 0.5 - footprint_center_px.y
		)
		sprite.position = Vector3(0.0, -body.position.y + 0.02, 0.0)
	else:
		sprite.pixel_size = float(definition.get("pixel_size", 0.007))
		sprite.position.y = -body.position.y + 0.02
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 4
	body.add_child(sprite)

	var collision_axis := "x" if collision_size.x >= collision_size.z else "z"
	body.set_meta("cover_axis", collision_axis)
	var profile_id := "rubble_wall" if cover_type.begins_with("rubble") else "road_barricade"
	var collision_center := Vector2.ZERO
	var collision_profile: Dictionary = COLLISION_PROFILES.get_profile(profile_id, collision_size)
	var movement_size: Vector3 = collision_profile["movement_size"]
	if not _reserve_generated_obstacle(
		body.global_position + Vector3(collision_center.x, 0.0, collision_center.y),
		movement_size,
		"road_cover"
	):
		body.queue_free()
		return
	_configure_profiled_collision(body, collision_size, profile_id, collision_center, -body.position.y)


func _footprint_centroid(corners: Array) -> Vector2:
	if corners.is_empty():
		return Vector2.ZERO
	var centroid := Vector2.ZERO
	for corner_variant in corners:
		centroid += corner_variant as Vector2
	return centroid / float(corners.size())


func _build_parking_lot(cell: Vector2i) -> void:
	if _is_subway_vehicle_clearance_cell(cell):
		_build_open_lot(cell)
		return
	var center := _cell_center(cell)
	var lot_art_size := CELL_SIZE - 0.6 * WORLD_SCALE
	_add_plane("ParkingLotArt", center, Vector2(lot_art_size, lot_art_size), parking_material, 0.045)
	var slots := [
		Vector3(-2.45 * WORLD_SCALE, 0.1, -2.15 * WORLD_SCALE),
		Vector3(-2.45 * WORLD_SCALE, 0.1, 2.15 * WORLD_SCALE),
		Vector3(2.45 * WORLD_SCALE, 0.1, -2.15 * WORLD_SCALE),
		Vector3(2.45 * WORLD_SCALE, 0.1, 2.15 * WORLD_SCALE),
	]
	slots.shuffle()
	var vehicle_count := rng.randi_range(2, slots.size())
	var zone := str(cell_zones.get(cell, "street_mixed"))
	for slot_index in range(vehicle_count):
		var vehicle_type := _choose_vehicle_type(zone, false)
		_spawn_vehicle(
			"Parked_%d_%d_%d" % [cell.x, cell.y, slot_index],
			vehicle_type,
			center + slots[slot_index],
			true
		)


func _build_district_props() -> void:
	_build_market_district_props()
	var spawned_count := 0
	var target_count := int(region_profile.get("street_prop_count", 14))
	var spawn_chance := float(region_profile.get("street_prop_chance", 0.14))
	var cells: Array = building_cells.keys()
	cells.shuffle()
	for cell_variant in cells:
		if spawned_count >= target_count:
			break
		var cell: Vector2i = cell_variant
		if not _touches_road(cell):
			continue
		var zone := str(cell_zones.get(cell, "street_mixed"))
		var is_anchor: bool = _district_anchor_for(zone) == cell
		if not is_anchor and rng.randf() >= spawn_chance:
			continue
		var frontage := _get_road_frontage(cell)
		if frontage.is_empty():
			continue
		var prop_id := _choose_street_prop(zone)
		if prop_id.is_empty():
			continue
		var side := frontage[rng.randi_range(0, frontage.size() - 1)]
		_spawn_street_prop(cell, side, prop_id, spawned_count)
		spawned_count += 1


func _choose_street_prop(district: String) -> String:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for prop_id_variant in STREET_PROP_CATALOG.DEFINITIONS:
		var prop_id := str(prop_id_variant)
		var definition: Dictionary = STREET_PROP_CATALOG.get_definition(prop_id)
		var districts: Array = definition.get("districts", [])
		if not districts.has(district):
			continue
		var weight := float(definition.get("weight", 1.0))
		total_weight += weight
		candidates.append({
			"id": prop_id,
			"weight": weight,
		})
	if candidates.is_empty():
		return ""
	var roll := rng.randf() * total_weight
	for candidate in candidates:
		roll -= float(candidate["weight"])
		if roll <= 0.0:
			return str(candidate["id"])
	return str(candidates.back()["id"])


func _spawn_street_prop(
	cell: Vector2i,
	frontage: String,
	prop_id: String,
	instance_index: int
) -> void:
	var definition: Dictionary = STREET_PROP_CATALOG.get_definition(prop_id)
	if definition.is_empty():
		return
	var texture_path := str(definition.get("texture_path", ""))
	if not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var base_size: Vector3 = definition.get("collision_size", Vector3(2.4, 1.5, 1.0))
	var along_z := frontage in ["west", "east"]
	var collision_size := Vector3(base_size.z, base_size.y, base_size.x) if along_z else base_size
	var edge_depth := collision_size.x if along_z else collision_size.z
	var inward_offset := CELL_SIZE * 0.5 - edge_depth * 0.5 - 0.25
	var parallel_offset := rng.randf_range(3.0, 3.8) * (-1.0 if rng.randf() < 0.5 else 1.0)
	var offset := Vector3.ZERO
	match frontage:
		"west":
			offset = Vector3(-inward_offset, 0.08, parallel_offset)
		"east":
			offset = Vector3(inward_offset, 0.08, parallel_offset)
		"north":
			offset = Vector3(parallel_offset, 0.08, -inward_offset)
		"south":
			offset = Vector3(parallel_offset, 0.08, inward_offset)
		_:
			return

	var body := StaticBody3D.new()
	body.name = "StreetProp_%s_%d_%d_%d" % [prop_id, cell.x, cell.y, instance_index]
	body.position = _cell_center(cell) + offset
	body.collision_layer = 0
	body.add_to_group("district_prop")
	body.add_to_group("street_prop_obstacle")
	body.add_to_group("cover_obstacle")
	body.set_meta("prop_id", prop_id)
	body.set_meta("planning_cell", cell)
	body.set_meta("zoning_district", str(cell_zones.get(cell, "street_mixed")))
	body.set_meta("raid_zone_id", raid_zone_id)
	body.set_meta("risk_band", str(cell_risk_bands.get(cell, "scavenge")))
	add_child(body)

	var sprite := Sprite3D.new()
	sprite.name = "StreetPropSprite"
	sprite.texture = texture
	var corners: Array[Vector2] = _texture_space_footprint_corners(definition, texture)
	var left_corner := corners[0] as Vector2
	var right_corner := corners[2] as Vector2
	var bottom_corner := corners[3] as Vector2
	var base_pixel_width := maxf(1.0, absf(right_corner.x - left_corner.x))
	var projected_width := (base_size.x + base_size.z) / sqrt(2.0)
	sprite.pixel_size = projected_width / base_pixel_width
	var horizontal_offset := texture.get_width() * 0.5 - bottom_corner.x
	var flip_prop := not along_z
	sprite.offset.x = -horizontal_offset if flip_prop else horizontal_offset
	sprite.flip_h = flip_prop
	sprite.position = Vector3(
		collision_size.x * 0.5,
		(bottom_corner.y - texture.get_height() * 0.5) * sprite.pixel_size / ISOMETRIC_VERTICAL_PROJECTION - body.position.y,
		collision_size.z * 0.5
	)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 4
	body.add_child(sprite)

	var profile_id := str(definition.get("collision_profile", "street_cluster"))
	var collision_center := Vector2(collision_size.x * 0.5, collision_size.z * 0.5)
	if not _reserve_generated_obstacle(
		body.global_position + Vector3(collision_center.x, 0.0, collision_center.y),
		COLLISION_PROFILES.get_profile(profile_id, collision_size)["movement_size"],
		"street_prop"
	):
		body.queue_free()
		return
	_configure_profiled_collision(body, collision_size, profile_id, collision_center, -body.position.y)


func _build_market_district_props() -> void:
	if not district_anchors.has("market_lane"):
		return
	var market_anchor: Vector2i = district_anchors["market_lane"]
	var spawned_count := 0
	var spawn_chance := float(region_profile.get("market_prop_chance", 0.42))
	for cell in cell_zones:
		if str(cell_zones[cell]) != "market_lane" or not _touches_road(cell):
			continue
		if cell != market_anchor and rng.randf() >= spawn_chance:
			continue
		var frontage := _get_road_frontage(cell)
		if frontage.is_empty():
			continue
		var side := frontage[rng.randi_range(0, frontage.size() - 1)]
		_spawn_market_handcart(cell, side, spawned_count)
		spawned_count += 1


func _spawn_market_handcart(cell: Vector2i, frontage: String, instance_index: int) -> void:
	if not ResourceLoader.exists(MARKET_HANDCART_TEXTURE_PATH):
		return
	var along_z := frontage in ["west", "east"]
	var inward_offset := CELL_SIZE * 0.5 - 1.7
	var offset := Vector3.ZERO
	match frontage:
		"west":
			offset.x = -inward_offset
		"east":
			offset.x = inward_offset
		"north":
			offset.z = -inward_offset
		"south":
			offset.z = inward_offset
	var base_size := MARKET_HANDCART_COLLISION_SIZE
	var collision_size := Vector3(base_size.z, base_size.y, base_size.x) if along_z else base_size
	var body := StaticBody3D.new()
	body.name = "MarketHandcart_%d_%d_%d" % [cell.x, cell.y, instance_index]
	body.position = _cell_center(cell) + offset + Vector3(0, 0.08, 0)
	body.collision_layer = 0
	body.add_to_group("district_prop")
	body.add_to_group("market_handcart")
	body.set_meta("zoning_district", "market_lane")
	add_child(body)

	var texture := load(MARKET_HANDCART_TEXTURE_PATH) as Texture2D
	var sprite := Sprite3D.new()
	sprite.name = "HandcartSprite"
	sprite.texture = texture
	var base_pixel_width := absf(MARKET_HANDCART_FOOTPRINT_CORNERS[2].x - MARKET_HANDCART_FOOTPRINT_CORNERS[0].x)
	var projected_width := (base_size.x + base_size.z) / sqrt(2.0)
	sprite.pixel_size = projected_width / base_pixel_width
	var bottom_corner: Vector2 = MARKET_HANDCART_FOOTPRINT_CORNERS[3]
	var horizontal_offset := texture.get_width() * 0.5 - bottom_corner.x
	var flip_prop := not along_z
	sprite.offset.x = -horizontal_offset if flip_prop else horizontal_offset
	sprite.flip_h = flip_prop
	sprite.position = Vector3(
		collision_size.x * 0.5,
		(bottom_corner.y - texture.get_height() * 0.5) * sprite.pixel_size / ISOMETRIC_VERTICAL_PROJECTION - body.position.y,
		collision_size.z * 0.5
	)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 5
	body.add_child(sprite)

	var collision_center := Vector2(collision_size.x * 0.5, collision_size.z * 0.5)
	if not _reserve_generated_obstacle(
		body.global_position + Vector3(collision_center.x, 0.0, collision_center.y),
		COLLISION_PROFILES.get_profile("handcart", collision_size)["movement_size"],
		"handcart"
	):
		body.queue_free()
		return
	_configure_profiled_collision(body, collision_size, "handcart", collision_center, -body.position.y)


func _build_open_lot(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	var material := open_lot_materials[rng.randi_range(0, open_lot_materials.size() - 1)]
	var lot_art_size := CELL_SIZE - 0.6 * WORLD_SCALE
	_add_plane("UrbanOpenLotArt", center, Vector2(lot_art_size, lot_art_size), material, 0.035)


func _try_build_building(cell: Vector2i) -> void:
	var modules_per_cell := BUILDING_CATALOG.MODULES_PER_CELL
	var zone := str(cell_zones.get(cell, "street_mixed"))
	var definitions: Array[Dictionary] = []
	var allowed_buildings: Array = region_profile.get("allowed_buildings", [])
	var signature_building_id := str(region_profile.get("signature_building_id", ""))
	var signature_district := str(region_profile.get("signature_district", ""))
	for building_id in BUILDING_CATALOG.DEFINITIONS:
		if not allowed_buildings.is_empty() and not allowed_buildings.has(str(building_id)):
			continue
		if (
			not signature_building_id.is_empty()
			and zone == signature_district
			and _district_anchor_for(signature_district) == cell
			and str(building_id) != signature_building_id
		):
			continue
		var definition: Dictionary = BUILDING_CATALOG.get_definition(building_id)
		var district_tags: Array = definition.get("districts", [])
		if not district_tags.is_empty() and not district_tags.has(zone):
			continue
		var is_district_anchor: bool = _district_anchor_for(zone) == cell
		if is_district_anchor and not district_tags.has(zone):
			continue
		var footprint: Vector2i = definition.get("footprint_modules", Vector2i.ZERO)
		if footprint.x > modules_per_cell - 2 or footprint.y > modules_per_cell - 2:
			continue
		var height_class := str(definition.get("height_class", "mid"))
		var open_space_distance := _distance_to_cells(cell, playground_cells)
		if height_class == "high":
			if zone not in ["business_corner", "luxury_core"] or open_space_distance <= OPEN_SPACE_HIGH_RISE_BUFFER_CELLS or _distance_to_cells(cell, apartment_cells) <= APARTMENT_HIGH_RISE_BUFFER_CELLS:
				continue
		elif height_class == "mid" and (open_space_distance <= OPEN_SPACE_MID_RISE_BUFFER_CELLS or (zone == "residential_buffer" and zone != "multi_family")):
			continue
		var selection_weight := float(definition.get("density_weight", 1.0))
		if zone in ["market_lane", "luxury_core", "multi_family"]:
			selection_weight *= 5.0 if district_tags.has(zone) else 0.18
		definitions.append({
			"id": building_id,
			"definition": definition,
			"weight": selection_weight,
		})
	if definitions.is_empty():
		return
	var neighboring_types := {}
	for offset_x in range(-1, 2):
		for offset_z in range(-1, 2):
			var neighboring_id: String = str(building_type_by_cell.get(cell + Vector2i(offset_x, offset_z), ""))
			if not neighboring_id.is_empty():
				neighboring_types[neighboring_id] = true
	if definitions.size() > 1:
		var varied_definitions: Array[Dictionary] = definitions.filter(func(candidate: Dictionary) -> bool:
			return not neighboring_types.has(str(candidate["id"]))
		)
		if not varied_definitions.is_empty():
			definitions = varied_definitions
	var total_weight := 0.0
	for candidate in definitions:
		total_weight += float(candidate["weight"])
	var selection_roll := rng.randf() * total_weight
	var selected: Dictionary = definitions.back()
	for candidate in definitions:
		selection_roll -= float(candidate["weight"])
		if selection_roll <= 0.0:
			selected = candidate
			break
	var definition: Dictionary = selected["definition"]
	var footprint: Vector2i = definition["footprint_modules"]
	var cell_origin := cell * modules_per_cell
	var offset_x := _choose_parcel_axis_offset(
		modules_per_cell - footprint.x,
		_is_road_cell(cell + Vector2i.LEFT),
		_is_road_cell(cell + Vector2i.RIGHT)
	)
	var offset_y := _choose_parcel_axis_offset(
		modules_per_cell - footprint.y,
		_is_road_cell(cell + Vector2i.UP),
		_is_road_cell(cell + Vector2i.DOWN)
	)
	var module_origin := cell_origin + Vector2i(offset_x, offset_y)
	_spawn_building(selected["id"], definition, module_origin)
	building_type_by_cell[cell] = str(selected["id"])


func _choose_parcel_axis_offset(slack_modules: int, road_at_negative_edge: bool, road_at_positive_edge: bool) -> int:
	if slack_modules <= 0:
		return 0
	if road_at_negative_edge and not road_at_positive_edge:
		return mini(ROAD_SETBACK_MODULES, slack_modules)
	if road_at_positive_edge and not road_at_negative_edge:
		return maxi(0, slack_modules - ROAD_SETBACK_MODULES)
	var minimum := mini(INTERIOR_SETBACK_MODULES, slack_modules)
	var maximum := maxi(minimum, slack_modules - INTERIOR_SETBACK_MODULES)
	return rng.randi_range(minimum, maximum)


func _spawn_landmark(cell: Vector2i, landmark_id: String) -> void:
	_spawn_landmark_at(_cell_center(cell), landmark_id, "%d_%d" % [cell.x, cell.y])


func _spawn_landmark_at(center: Vector3, landmark_id: String, instance_suffix: String) -> Node3D:
	var definition := LANDMARK_CATALOG.get_definition(landmark_id)
	if definition.is_empty():
		return null
	var texture := load(str(definition["texture_path"])) as Texture2D
	if texture == null:
		return null
	var footprint_modules: Vector2i = definition["footprint_modules"]
	var module_world_size := CELL_SIZE / float(LANDMARK_CATALOG.MODULES_PER_CELL)
	var footprint_world := Vector2(footprint_modules) * module_world_size
	var landmark := Node3D.new()
	landmark.name = "%s_%s" % [str(definition["node_name"]), instance_suffix]
	landmark.position = center
	landmark.add_to_group("urban_landmark")
	landmark.add_to_group("urban_%s" % landmark_id)
	landmark.set_meta("landmark_kind", landmark_id)
	landmark.set_meta("raid_zone_id", raid_zone_id)
	landmark.set_meta("risk_band", get_risk_band(center))
	add_child(landmark)

	var sprite := Sprite3D.new()
	sprite.name = "LandmarkSprite"
	sprite.texture = texture
	var corners: Array[Vector2] = _texture_space_footprint_corners(definition, texture)
	var base_pixel_width := absf((corners[2] as Vector2).x - (corners[0] as Vector2).x)
	var projected_width := (footprint_world.x + footprint_world.y) / sqrt(2.0)
	sprite.pixel_size = projected_width / base_pixel_width
	sprite.offset.x = texture.get_width() * 0.5 - (corners[3] as Vector2).x
	sprite.position = Vector3(
		footprint_world.x * 0.5,
		((corners[3] as Vector2).y - texture.get_height() * 0.5) * sprite.pixel_size / ISOMETRIC_VERTICAL_PROJECTION,
		footprint_world.y * 0.5
	)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmark.add_child(sprite)

	for box_definition in definition.get("collision_boxes", []):
		var offset: Vector2 = box_definition["offset"]
		var size: Vector2 = box_definition["size"]
		var collision_height := float(box_definition.get("height", 1.2))
		_add_static_collision_box(
			"%sCollision" % str(definition["node_name"]),
			center + Vector3(offset.x * module_world_size, collision_height * 0.5, offset.y * module_world_size),
			Vector3(size.x * module_world_size, collision_height, size.y * module_world_size)
		)
	return landmark


func _spawn_building(building_id: String, definition: Dictionary, module_origin: Vector2i) -> void:
	var footprint_modules: Vector2i = definition["footprint_modules"]
	var module_world_size := CELL_SIZE / float(BUILDING_CATALOG.MODULES_PER_CELL)
	var footprint_world := Vector2(footprint_modules) * module_world_size
	var center_x := -MAP_SIZE * 0.5 + (module_origin.x + footprint_modules.x * 0.5) * module_world_size
	var center_z := -MAP_SIZE * 0.5 + (module_origin.y + footprint_modules.y * 0.5) * module_world_size
	var texture := load(definition["texture_path"]) as Texture2D
	if texture == null:
		return
	var body := StaticBody3D.new()
	body.name = "%s_%d_%d" % [building_id, module_origin.x, module_origin.y]
	body.position = Vector3(center_x, 0, center_z)
	body.add_to_group("camera_occluder")
	body.collision_layer = 0
	body.set_meta("building_id", building_id)
	body.set_meta("height_class", str(definition.get("height_class", "mid")))
	body.set_meta("planning_cell", Vector2i(
		module_origin.x / BUILDING_CATALOG.MODULES_PER_CELL,
		module_origin.y / BUILDING_CATALOG.MODULES_PER_CELL
	))
	var planning_cell: Vector2i = body.get_meta("planning_cell")
	body.set_meta("zoning_district", str(cell_zones.get(planning_cell, "street_mixed")))
	body.set_meta("raid_zone_id", raid_zone_id)
	body.set_meta("risk_band", str(cell_risk_bands.get(planning_cell, "scavenge")))
	var road_frontage := _get_road_frontage(planning_cell)
	body.set_meta("road_frontage", road_frontage)
	add_child(body)
	var sprite := Sprite3D.new()
	sprite.name = "BuildingSprite"
	sprite.texture = texture
	var corners: Array[Vector2] = _texture_space_footprint_corners(definition, texture)
	var base_pixel_width := absf((corners[2] as Vector2).x - (corners[0] as Vector2).x)
	var projected_width := (footprint_world.x + footprint_world.y) / sqrt(2.0)
	sprite.pixel_size = projected_width / base_pixel_width
	sprite.offset.x = texture.get_width() * 0.5 - (corners[3] as Vector2).x
	sprite.position = Vector3(footprint_world.x * 0.5, ((corners[3] as Vector2).y - texture.get_height() * 0.5) * sprite.pixel_size / ISOMETRIC_VERTICAL_PROJECTION, footprint_world.y * 0.5)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(sprite)
	var height := float(definition["height_world"]) * WORLD_SCALE
	var building_collision_size := Vector3(footprint_world.x, height, footprint_world.y)
	_configure_profiled_collision(body, building_collision_size, "building")
	body.set_meta("occlusion_lateral_limit", (footprint_world.x + footprint_world.y) / (2.0 * sqrt(2.0)))
	body.set_meta("occlusion_depth_limit", float(definition["occlusion_depth"]) * WORLD_SCALE)
	_try_add_building_entrance(body, building_id, definition, footprint_world, road_frontage, module_origin)


func _try_add_building_entrance(
	body: StaticBody3D,
	building_id: String,
	definition: Dictionary,
	footprint_world: Vector2,
	road_frontage: PackedStringArray,
	module_origin: Vector2i
) -> void:
	if enterable_building_count >= MAX_ENTERABLE_BUILDINGS or road_frontage.is_empty():
		return
	var height_class := str(definition.get("height_class", "low"))
	if height_class == "low":
		return
	var frontage_index := absi(building_id.hash() ^ module_origin.x * 92821 ^ module_origin.y * 68917) % road_frontage.size()
	var frontage := str(road_frontage[frontage_index])
	var outward := Vector3.ZERO
	var local_position := Vector3.ZERO
	var rotation_y := 0.0
	match frontage:
		"west":
			outward = Vector3.LEFT
			local_position.x = -footprint_world.x * 0.5 - 1.25
			rotation_y = -PI * 0.5
		"east":
			outward = Vector3.RIGHT
			local_position.x = footprint_world.x * 0.5 + 1.25
			rotation_y = PI * 0.5
		"north":
			outward = Vector3.FORWARD
			local_position.z = -footprint_world.y * 0.5 - 1.25
			rotation_y = PI
		_:
			outward = Vector3.BACK
			local_position.z = footprint_world.y * 0.5 + 1.25
	var portal := BUILDING_ENTRANCE_SCENE.instantiate() as Area3D
	portal.name = "InteriorEntrance"
	portal.position = local_position
	portal.rotation.y = rotation_y
	portal.set("building_id", "%s_%d_%d" % [building_id, module_origin.x, module_origin.y])
	portal.set("seed_offset", module_origin.x * 92821 ^ module_origin.y * 68917)
	portal.set("floor_count", clampi(roundi(float(definition.get("height_world", 8.0)) / 2.7), 3, 8))
	portal.set("return_offset", Vector3(0.0, 0.0, 2.8))
	portal.set_meta("frontage", frontage)
	portal.set_meta("outward_direction", outward)
	body.set_meta("interior_accessible", true)
	body.set_meta("interior_entrance_frontage", frontage)
	body.add_child(portal)
	enterable_building_count += 1


func _get_road_frontage(cell: Vector2i) -> PackedStringArray:
	var frontage := PackedStringArray()
	if _is_road_cell(cell + Vector2i.LEFT):
		frontage.append("west")
	if _is_road_cell(cell + Vector2i.RIGHT):
		frontage.append("east")
	if _is_road_cell(cell + Vector2i.UP):
		frontage.append("north")
	if _is_road_cell(cell + Vector2i.DOWN):
		frontage.append("south")
	return frontage


func _texture_space_footprint_corners(
	definition: Dictionary,
	texture: Texture2D
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var raw_corners: Array = definition.get("footprint_corners_px", [])
	var source_size: Vector2i = definition.get(
		"source_size",
		Vector2i(texture.get_width(), texture.get_height())
	)
	var coordinate_scale := Vector2.ONE
	if source_size.x > 0 and source_size.y > 0:
		coordinate_scale = Vector2(
			float(texture.get_width()) / float(source_size.x),
			float(texture.get_height()) / float(source_size.y)
		)
	for corner_variant in raw_corners:
		var corner: Vector2 = corner_variant
		result.append(corner * coordinate_scale)
	return result


func _spawn_vehicle(node_name: String, vehicle_type: String, position: Vector3, along_z: bool = false) -> void:
	var definition := VEHICLE_CATALOG.get_definition(vehicle_type)
	if definition.is_empty():
		return
	var texture := load(str(definition["texture_path"])) as Texture2D
	if texture == null:
		return
	var footprint: Vector3 = definition["collision_size"]
	var collision_size := Vector3(footprint.z, footprint.y, footprint.x) if along_z else footprint
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 0
	body.add_to_group("vehicle_obstacle")
	body.set_meta("vehicle_type", vehicle_type)
	body.set_meta("vehicle_state", str(definition.get("state", "wrecked")))
	body.set_meta("vehicle_axis", "z" if along_z else "x")
	add_child(body)
	var sprite := Sprite3D.new()
	sprite.name = "VehicleSprite"
	sprite.texture = texture
	var corners: Array[Vector2] = _texture_space_footprint_corners(definition, texture)
	var base_pixel_width := absf((corners[2] as Vector2).x - (corners[0] as Vector2).x)
	var projected_width := (footprint.x + footprint.z) / sqrt(2.0)
	sprite.pixel_size = projected_width / base_pixel_width
	var footprint_center_px := _footprint_centroid(corners)
	var sprite_offset := Vector2(
		texture.get_width() * 0.5 - footprint_center_px.x,
		texture.get_height() * 0.5 - footprint_center_px.y
	)
	# The source art's long axis projects along world Z. Mirroring it turns that
	# axis onto world X, so only horizontal-road vehicles should be flipped.
	# The old rule did the opposite: the picture pointed across its own physics
	# box even though the box dimensions themselves were correct.
	var flip_vehicle := not along_z
	if flip_vehicle:
		sprite_offset.x = -sprite_offset.x
	sprite.offset = sprite_offset
	sprite.flip_h = flip_vehicle
	sprite.position = Vector3(0.0, -body.position.y + 0.02, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 5
	body.add_child(sprite)
	var profile_id := str(definition.get("collision_profile", "vehicle_standard"))
	var collision_center := Vector2.ZERO
	var collision_profile: Dictionary = COLLISION_PROFILES.get_profile(profile_id, collision_size)
	var movement_size: Vector3 = collision_profile["movement_size"]
	if not _reserve_generated_obstacle(
		body.global_position + Vector3(collision_center.x, 0.0, collision_center.y),
		movement_size,
		"vehicle"
	):
		body.queue_free()
		return
	_configure_profiled_collision(body, collision_size, profile_id, collision_center, -body.position.y)


func get_shelter_exit_position() -> Vector3:
	var result := _cell_center(FIELD_RETURN_CELL)
	result.y = 0.78
	return find_nearest_open_position(result)


func get_map_limit() -> float:
	return MAP_SIZE * 0.5 - 1.5


func get_extraction_position() -> Vector3:
	var best_cell := Vector2i(GRID_SIZE - 2, GRID_SIZE - 2)
	var best_score := -INF
	for road_x in vertical_roads:
		for road_z in horizontal_roads:
			var candidate := Vector2i(road_x, road_z)
			if not _cell_in_bounds(candidate) or _is_river_cell(candidate):
				continue
			var edge_margin := mini(
				mini(candidate.x, GRID_SIZE - 1 - candidate.x),
				mini(candidate.y, GRID_SIZE - 1 - candidate.y)
			)
			var score := float(_block_distance(candidate, FIELD_RETURN_CELL)) + float(edge_margin) * 0.12
			if score > best_score:
				best_score = score
				best_cell = candidate
	var result := _cell_center(best_cell)
	result.y = 0.18
	return result


func get_map_snapshot_data() -> Dictionary:
	return {
		"map_seed": map_seed,
		"raid_zone_id": raid_zone_id,
		"region_identity": str(region_profile.get("identity", "")),
		"grid_size": GRID_SIZE,
		"map_size": MAP_SIZE,
		"cell_size": CELL_SIZE,
		"vertical_roads": vertical_roads.duplicate(),
		"horizontal_roads": horizontal_roads.duplicate(),
		"river_columns": river_columns.duplicate(),
		"building_cells": building_cells.keys(),
		"risk_bands": cell_risk_bands.duplicate(),
		"field_return_cell": FIELD_RETURN_CELL,
	}


func get_region_id() -> String:
	return raid_zone_id


func get_risk_band(world_position: Vector3) -> String:
	var cell := _world_to_cell(world_position)
	cell.x = clampi(cell.x, 0, GRID_SIZE - 1)
	cell.y = clampi(cell.y, 0, GRID_SIZE - 1)
	return str(cell_risk_bands.get(cell, "scavenge"))


func get_long_road_patrol_route(
	origin: Vector3,
	route_seed: int,
	excluded_rids: Array = []
) -> Array[Vector3]:
	var origin_cell := _world_to_cell(origin)
	origin_cell.x = clampi(origin_cell.x, 1, GRID_SIZE - 2)
	origin_cell.y = clampi(origin_cell.y, 1, GRID_SIZE - 2)
	var nearest_vertical := vertical_roads[0]
	var nearest_horizontal := horizontal_roads[0]
	for road_x in vertical_roads:
		if absi(road_x - origin_cell.x) < absi(nearest_vertical - origin_cell.x):
			nearest_vertical = road_x
	for road_z in horizontal_roads:
		if absi(road_z - origin_cell.y) < absi(nearest_horizontal - origin_cell.y):
			nearest_horizontal = road_z

	var use_vertical := absi(nearest_vertical - origin_cell.x) < absi(nearest_horizontal - origin_cell.y)
	if absi(nearest_vertical - origin_cell.x) == absi(nearest_horizontal - origin_cell.y):
		use_vertical = posmod(route_seed, 2) == 0
	var center_axis := origin_cell.y if use_vertical else origin_cell.x
	var route_span_cells := 8
	var first_axis := clampi(
		center_axis - route_span_cells / 2,
		1,
		GRID_SIZE - 2 - route_span_cells
	)
	var forward_points: Array[Vector3] = []
	for point_index in 5:
		var axis := first_axis + roundi(float(route_span_cells) * float(point_index) / 4.0)
		var cell := (
			Vector2i(nearest_vertical, axis)
			if use_vertical
			else Vector2i(axis, nearest_horizontal)
		)
		var requested := _cell_center(cell)
		requested.y = origin.y
		var candidate := find_nearest_physically_open_position(
			requested,
			0.58,
			excluded_rids
		)
		candidate.y = origin.y
		if forward_points.is_empty() or forward_points[-1].distance_to(candidate) >= 2.0:
			forward_points.append(candidate)

	if forward_points.size() < 3:
		return [origin]
	if posmod(route_seed, 2) != 0:
		forward_points.reverse()
	var route := forward_points.duplicate()
	for reverse_index in range(forward_points.size() - 2, 0, -1):
		route.append(forward_points[reverse_index])
	return route


func world_to_map_cell(world_position: Vector3) -> Vector2i:
	return _world_to_cell(world_position)


func get_sector_label(world_position: Vector3) -> String:
	var cell := _world_to_cell(world_position)
	cell.x = clampi(cell.x, 0, GRID_SIZE - 1)
	cell.y = clampi(cell.y, 0, GRID_SIZE - 1)
	const COLUMN_NAMES := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return "%s-%02d" % [COLUMN_NAMES.substr(cell.x, 1), cell.y + 1]


func get_district_id(world_position: Vector3) -> String:
	var cell := _world_to_cell(world_position)
	cell.x = clampi(cell.x, 0, GRID_SIZE - 1)
	cell.y = clampi(cell.y, 0, GRID_SIZE - 1)
	return str(cell_zones.get(cell, "street_mixed"))


func is_position_in_safe_zone(world_position: Vector3) -> bool:
	return false


func find_nearest_open_position(world_position: Vector3) -> Vector3:
	var start := _world_to_cell(world_position)
	if _cell_in_bounds(start) and not _is_river_cell(start) and not building_cells.has(start):
		return world_position
	for radius in range(GRID_SIZE):
		for x in range(start.x - radius, start.x + radius + 1):
			for z in range(start.y - radius, start.y + radius + 1):
				var cell := Vector2i(x, z)
				if _cell_in_bounds(cell) and not _is_river_cell(cell) and not building_cells.has(cell):
					var result := _cell_center(cell)
					result.y = world_position.y
					return result
	return Vector3(0, world_position.y, 0)


func find_nearest_physically_open_position(
	world_position: Vector3,
	clearance_radius: float = 0.72,
	excluded_rids: Array = []
) -> Vector3:
	var base_position := find_nearest_open_position(world_position)
	if _is_physical_space_open(base_position, clearance_radius, excluded_rids):
		return base_position
	for ring in range(1, 11):
		var radius := float(ring) * 0.9
		var sample_count := maxi(10, ring * 8)
		for sample in sample_count:
			var angle := TAU * float(sample) / float(sample_count)
			var requested := base_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
			var candidate := find_nearest_open_position(requested)
			candidate.y = world_position.y
			if _is_physical_space_open(candidate, clearance_radius, excluded_rids):
				return candidate
	return base_position


func _is_physical_space_open(
	world_position: Vector3,
	clearance_radius: float,
	excluded_rids: Array
) -> bool:
	var cell := _world_to_cell(world_position)
	if not _cell_in_bounds(cell) or _is_river_cell(cell) or building_cells.has(cell):
		return false
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.25, clearance_radius)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		world_position + Vector3(0.0, maxf(0.42, clearance_radius + 0.18), 0.0)
	)
	query.collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	query.exclude = excluded_rids
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_road_cell(cell: Vector2i) -> bool:
	return _cell_in_bounds(cell) and (vertical_roads.has(cell.x) or horizontal_roads.has(cell.y))


func _is_river_cell(cell: Vector2i) -> bool:
	return (
		_cell_in_bounds(cell)
		and river_columns.size() == GRID_SIZE
		and river_columns[cell.y] == cell.x
	)


func _is_waterfront_cell(cell: Vector2i) -> bool:
	return (
		bool(region_profile.get("river_enabled", true))
		and _cell_in_bounds(cell)
		and abs(cell.x - river_center_x) == 1
	)


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(-MAP_SIZE * 0.5 + (cell.x + 0.5) * CELL_SIZE, 0, -MAP_SIZE * 0.5 + (cell.y + 0.5) * CELL_SIZE)


func _world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(floori((position.x + MAP_SIZE * 0.5) / CELL_SIZE), floori((position.z + MAP_SIZE * 0.5) / CELL_SIZE))


func _add_lane_dash(center: Vector3, vertical: bool) -> void:
	for base_offset in [-3.5, 0.0, 3.5]:
		var offset: float = float(base_offset) * WORLD_SCALE
		var position := center
		if vertical:
			position.z += offset
			_add_plane("LaneDash", position, Vector2(0.12, 1.7) * WORLD_SCALE, marking_material, 0.032)
		else:
			position.x += offset
			_add_plane("LaneDash", position, Vector2(1.7, 0.12) * WORLD_SCALE, marking_material, 0.032)


func _add_crosswalks(center: Vector3) -> void:
	for stripe in range(-4, 5):
		var offset := stripe * 0.5 * WORLD_SCALE
		var edge_offset := 3.65 * WORLD_SCALE
		_add_plane("Crosswalk", center + Vector3(offset, 0, -edge_offset), Vector2(0.28, 1.35) * WORLD_SCALE, marking_material, 0.034)
		_add_plane("Crosswalk", center + Vector3(offset, 0, edge_offset), Vector2(0.28, 1.35) * WORLD_SCALE, marking_material, 0.034)
		_add_plane("Crosswalk", center + Vector3(-edge_offset, 0, offset), Vector2(1.35, 0.28) * WORLD_SCALE, marking_material, 0.034)
		_add_plane("Crosswalk", center + Vector3(edge_offset, 0, offset), Vector2(1.35, 0.28) * WORLD_SCALE, marking_material, 0.034)


func _add_lot_sidewalk(center: Vector3, direction: Vector3) -> void:
	var edge_offset := CELL_SIZE * 0.5 - SIDEWALK_WIDTH * 0.5
	var sidewalk_center := center + direction * edge_offset
	var curb_center := center + direction * (CELL_SIZE * 0.5 - 0.07 * WORLD_SCALE)
	if abs(direction.x) > 0.5:
		_add_plane("Sidewalk", sidewalk_center, Vector2(SIDEWALK_WIDTH, CELL_SIZE), sidewalk_material, 0.022)
		_add_plane("Curb", curb_center, Vector2(0.14 * WORLD_SCALE, CELL_SIZE), curb_material, 0.034)
	else:
		_add_plane("Sidewalk", sidewalk_center, Vector2(CELL_SIZE, SIDEWALK_WIDTH), sidewalk_material, 0.022)
		_add_plane("Curb", curb_center, Vector2(CELL_SIZE, 0.14 * WORLD_SCALE), curb_material, 0.034)


func _add_plane(node_name: String, position: Vector3, size: Vector2, material: Material, height: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position + Vector3(0, height, 0)
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_oriented_plane(
	node_name: String,
	position: Vector3,
	size: Vector2,
	material: Material,
	height: float,
	vertical: bool
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position + Vector3(0, height, 0)
	if vertical:
		instance.rotation.y = PI * 0.5
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func set_collision_debug_enabled(enabled: bool) -> void:
	collision_debug_enabled = enabled
	for node in get_tree().get_nodes_in_group("collision_debug_visual"):
		if node is GeometryInstance3D and is_instance_valid(node):
			node.visible = enabled and bool(node.get_meta("collision_debug_focus", false))


func toggle_collision_debug() -> bool:
	set_collision_debug_enabled(not collision_debug_enabled)
	return collision_debug_enabled


func _configure_profiled_collision(
	body: StaticBody3D,
	base_size: Vector3,
	profile_id: String,
	footprint_center: Vector2 = Vector2.ZERO,
	ground_local_y: float = 0.0
) -> void:
	var profile := COLLISION_PROFILES.get_profile(profile_id, base_size)
	var movement_size: Vector3 = profile["movement_size"]
	var projectile_size: Vector3 = profile["projectile_size"]
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
	body.collision_mask = 0
	body.set_meta("collision_profile", profile_id)
	body.set_meta("collision_world_size", movement_size)
	body.set_meta("projectile_collision_world_size", projectile_size)
	body.add_to_group("generated_collision_obstacle")

	var movement_collision := CollisionShape3D.new()
	var is_vehicle := profile_id.begins_with("vehicle_")
	var is_road_cover := profile_id in ["road_barricade", "rubble_wall"]
	movement_collision.name = "MovementCollision"
	if is_vehicle:
		movement_collision.name = "VehicleCollision"
	elif is_road_cover:
		movement_collision.name = "CoverCollision"
	var movement_shape := BoxShape3D.new()
	movement_shape.size = movement_size
	movement_collision.shape = movement_shape
	movement_collision.position = Vector3(
		footprint_center.x,
		ground_local_y + movement_size.y * 0.5,
		footprint_center.y
	)
	body.add_child(movement_collision)

	var projectile_body := StaticBody3D.new()
	projectile_body.name = "ProjectileBlocker"
	projectile_body.collision_layer = COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	projectile_body.collision_mask = 0
	projectile_body.add_to_group("projectile_blocker")
	body.add_child(projectile_body)
	var projectile_collision := CollisionShape3D.new()
	projectile_collision.name = "ProjectileCollision"
	var projectile_shape := BoxShape3D.new()
	projectile_shape.size = projectile_size
	projectile_collision.shape = projectile_shape
	projectile_collision.position = Vector3(
		footprint_center.x,
		ground_local_y + projectile_size.y * 0.5,
		footprint_center.y
	)
	projectile_body.add_child(projectile_collision)

	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "MovementCollisionDebug"
	if is_vehicle:
		debug_mesh.name = "VehicleCollisionDebug"
	elif is_road_cover:
		debug_mesh.name = "CoverCollisionDebug"
	debug_mesh.position = Vector3(
		footprint_center.x,
		ground_local_y + 0.035,
		footprint_center.y
	)
	var footprint_mesh := PlaneMesh.new()
	footprint_mesh.size = Vector2(movement_size.x, movement_size.z)
	footprint_mesh.material = vehicle_collision_material
	debug_mesh.mesh = footprint_mesh
	debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var is_debug_focus := bool(COLLISION_DEBUG_FOCUS_PROFILES.get(profile_id, false))
	debug_mesh.visible = collision_debug_enabled and is_debug_focus
	debug_mesh.add_to_group("collision_debug_visual")
	debug_mesh.set_meta("collision_profile", profile_id)
	debug_mesh.set_meta("collision_debug_focus", is_debug_focus)
	debug_mesh.set_meta("footprint_world_size", Vector2(movement_size.x, movement_size.z))
	if is_vehicle:
		debug_mesh.set_meta("vehicle_type", str(body.get_meta("vehicle_type", "")))
		debug_mesh.set_meta("vehicle_axis", str(body.get_meta("vehicle_axis", "")))
	body.add_child(debug_mesh)


func _reserve_generated_obstacle(
	center: Vector3,
	size: Vector3,
	category: String,
	margin: float = 0.16
) -> bool:
	var footprint := Rect2(
		Vector2(center.x - size.x * 0.5 - margin, center.z - size.z * 0.5 - margin),
		Vector2(size.x + margin * 2.0, size.z + margin * 2.0)
	)
	for existing in generated_obstacle_footprints:
		var existing_rect: Rect2 = existing["rect"]
		if footprint.intersects(existing_rect, true):
			generated_overlap_report.append({
				"rejected_category": category,
				"existing_category": str(existing.get("category", "unknown")),
				"center": center,
			})
			return false
	generated_obstacle_footprints.append({
		"rect": footprint,
		"category": category,
		"center": center,
	})
	return true


func _audit_generated_obstacle_overlaps() -> void:
	var accepted_overlap_count := 0
	for first_index in range(generated_obstacle_footprints.size()):
		var first: Dictionary = generated_obstacle_footprints[first_index]
		for second_index in range(first_index + 1, generated_obstacle_footprints.size()):
			var second: Dictionary = generated_obstacle_footprints[second_index]
			var first_rect: Rect2 = first["rect"]
			var second_rect: Rect2 = second["rect"]
			if first_rect.intersects(second_rect, true):
				accepted_overlap_count += 1
	set_meta("generated_obstacle_count", generated_obstacle_footprints.size())
	set_meta("rejected_overlap_count", generated_overlap_report.size())
	set_meta("accepted_overlap_count", accepted_overlap_count)


func _add_static_collision_box(node_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 0
	add_child(body)
	_configure_profiled_collision(body, size, "thin_wall", Vector2.ZERO, -size.y * 0.5)


func _add_static_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	body.collision_mask = 0
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _add_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	_add_box_to(self, node_name, position, size, material)


func _add_box_to(parent: Node, node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)


func _texture_material(texture: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.96
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _color_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
