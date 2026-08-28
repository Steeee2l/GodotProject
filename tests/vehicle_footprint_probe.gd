extends SceneTree

# 차량·엄폐물의 '그림 대 충돌' 정합 프로브(--headless 가능).
#
# 재는 것 —
#   스프라이트에 실제로 그려지는 접지 사각형(vehicle_footprint 가 아트에서 유도)을
#   월드 XZ 로 되돌린 뒤, 충돌 상자의 AABB 중심·크기와 비교한다.
#   합격선: 중심 편차 ≤ 0.3m, 크기 비율 0.8 ~ 1.2.
#
# LEGACY 줄은 이번 수정 전 오프닝이 쓰던 손계산 값(월드 폭·화면 회전·충돌 오프셋)을
# 그대로 복원해 같은 자로 잰 것이다 — 전/후 비교표의 '전'.

const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const VEHICLE_FOOTPRINT := preload("res://scripts/vehicle_footprint.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

# 수정 전 오프닝이 _add_vehicle 에 손으로 넣던 인자들.
const LEGACY_OPENING := [
	{
		"label": "opening_taxi#1",
		"texture": "res://assets/opening/opening_wrecked_taxi_v1.png",
		"catalog": "opening_taxi",
		"body_y": 0.84,
		"world_width": 4.5144,
		"screen_rotation": 12.0,
		"collision_size": Vector3(1.75, 1.1, 4.0),
		"collision_offset": Vector3(0.0, -0.2, 0.0),
	},
	{
		"label": "opening_truck",
		"texture": "res://assets/opening/opening_wrecked_truck_v1.png",
		"catalog": "opening_truck",
		"body_y": 0.95,
		"world_width": 5.016,
		"screen_rotation": -8.0,
		"collision_size": Vector3(2.05, 1.3, 4.8),
		"collision_offset": Vector3(-0.23, -0.2, 0.23),
	},
	{
		"label": "opening_taxi#2",
		"texture": "res://assets/opening/opening_wrecked_taxi_v1.png",
		"catalog": "opening_taxi",
		"body_y": 0.82,
		"world_width": 4.0128,
		"screen_rotation": -18.0,
		"collision_size": Vector3(1.6, 1.0, 3.55),
		"collision_offset": Vector3(0.0, -0.2, 0.0),
	},
	{
		"label": "opening_bus",
		"texture": "res://assets/opening/opening_wrecked_bus_v1.png",
		"catalog": "opening_bus",
		"body_y": 1.0,
		"world_width": 5.5176,
		"screen_rotation": 4.0,
		"collision_size": Vector3(2.15, 1.3, 5.65),
		"collision_offset": Vector3(0.0, -0.2, 0.0),
	},
]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("== VEHICLE FOOTPRINT PROBE ==")
	print("label                       centre_dx  size_ratio(x,z)   verdict")
	await _probe_legacy_opening()
	await _probe_opening()
	await _probe_field()
	print("")
	print("합격 판정은 오프닝 4대에만 건다.")
	print("필드·엄폐물은 참고값이다 — 아트가 그려진 투영각(≈23°)이 엔진 카메라의")
	print("아이소메트릭(30°)과 달라, 손으로 찍은 접지 사각형이 평행사변형이 아니다.")
	print("중심 편차는 전부 ≤0.3m 로 들어오지만 크기비는 아트를 다시 뽑기 전에는 남는다.")
	print("FOOTPRINT_PROBE_%s failures=%d" % ["FAIL" if failures > 0 else "OK", failures])
	quit(1 if failures > 0 else 0)


func _report(label: String, centre_delta: float, ratio: Vector2, counts: bool) -> void:
	var centre_ok := centre_delta <= 0.3
	var size_ok := ratio.x >= 0.8 and ratio.x <= 1.2 and ratio.y >= 0.8 and ratio.y <= 1.2
	if counts and not (centre_ok and size_ok):
		failures += 1
	print("%-26s  %7.3fm  (%.2f, %.2f)  %s" % [
		label, centre_delta, ratio.x, ratio.y, "OK" if centre_ok and size_ok else "OUT"
	])


func _ratio(collision_size: Vector3, visual_size: Vector2) -> Vector2:
	return Vector2(
		collision_size.x / maxf(0.01, visual_size.x),
		collision_size.z / maxf(0.01, visual_size.y)
	)


# ── 수정 전(손계산) 오프닝 ────────────────────────────────────────────

func _probe_legacy_opening() -> void:
	# 오프닝 카메라(10.5, 12.5, 10.5)의 화면 성분.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.position = Vector3(10.5, 12.5, 10.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	var screen_depth := VEHICLE_FOOTPRINT.ground_screen_depth(camera)
	var screen_up := VEHICLE_FOOTPRINT.ground_screen_up(camera)
	for entry_variant in LEGACY_OPENING:
		var entry: Dictionary = entry_variant
		var texture := load(str(entry["texture"])) as Texture2D
		var definition := VEHICLE_CATALOG.get_definition(str(entry["catalog"]))
		var corners := VEHICLE_FOOTPRINT.texture_space_corners(definition, texture)
		var pixel_size := float(entry["world_width"]) / float(maxi(1, texture.get_width()))
		# 옛 방식: offset 없이 텍스처 중앙 정렬 + 알파 바닥만큼 월드 Y 로 띄우기.
		var silhouette := VEHICLE_FOOTPRINT.silhouette_ground_bounds(texture)
		var bottom_padding := float(silhouette.get("bottom_padding_px", 0.0))
		var body_y := float(entry["body_y"])
		var sprite_y := maxf(
			0.05,
			texture.get_height() * pixel_size * 0.5 - bottom_padding * pixel_size - body_y
		)
		var lift := (body_y + sprite_y) * screen_up
		var half := Vector2(texture.get_width() * 0.5, texture.get_height() * 0.5)
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for corner in corners:
			var screen_offset := Vector2(
				(corner.x - half.x) * pixel_size,
				-(corner.y - half.y) * pixel_size + lift
			)
			var ground := VEHICLE_FOOTPRINT.screen_offset_to_ground(screen_offset, screen_depth)
			minimum = minimum.min(ground)
			maximum = maximum.max(ground)
		var visual_center := (minimum + maximum) * 0.5
		var visual_size := maximum - minimum
		var collision_size: Vector3 = entry["collision_size"]
		var yaw := deg_to_rad(_legacy_yaw(float(entry["screen_rotation"])))
		var aabb := Vector3(
			collision_size.x * absf(cos(yaw)) + collision_size.z * absf(sin(yaw)),
			collision_size.y,
			collision_size.x * absf(sin(yaw)) + collision_size.z * absf(cos(yaw))
		)
		var collision_offset: Vector3 = entry["collision_offset"]
		var centre_delta := Vector2(collision_offset.x, collision_offset.z).distance_to(visual_center)
		_report("LEGACY %s" % str(entry["label"]), centre_delta, _ratio(aabb, visual_size), false)
	camera.queue_free()
	await process_frame


func _legacy_yaw(screen_rotation: float) -> float:
	# 삭제된 CollisionProfileCatalog.sprite_tilt_to_collision_yaw 의 복제(비교 전용).
	var alpha := deg_to_rad(210.0 + screen_rotation)
	var axis_x := cos(alpha) * 1.4142135623730951 - sin(alpha) * 2.449489742783178
	var axis_z := -sin(alpha) * 2.449489742783178 - cos(alpha) * 1.4142135623730951
	return rad_to_deg(PI * 0.5 - atan2(axis_z, axis_x))


# ── 수정 후 ──────────────────────────────────────────────────────────

func _probe_opening() -> void:
	var scene := load("res://scenes/opening_sequence.tscn") as PackedScene
	var opening := scene.instantiate() as Node3D
	root.add_child(opening)
	await process_frame
	await physics_frame
	var camera := opening.get("camera") as Camera3D
	var index := 0
	for wreck_node in get_nodes_in_group("opening_wreck"):
		if not opening.is_ancestor_of(wreck_node):
			continue
		index += 1
		var body := wreck_node as StaticBody3D
		var sprite := body.get_node("VehicleSprite") as Sprite3D
		var collision := body.get_node("VehicleCollision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		var definition := VEHICLE_CATALOG.get_definition(str(body.get_meta("vehicle_type", "")))
		var visual: Dictionary = VEHICLE_FOOTPRINT.visual_footprint_from_sprite(
			sprite, definition, camera
		)
		var visual_center: Vector2 = visual["center"]
		var visual_size: Vector2 = visual["size"]
		_report(
			"opening %d %s" % [index, str(body.get_meta("vehicle_type", ""))],
			Vector2(collision.position.x, collision.position.z).distance_to(visual_center),
			_ratio(shape.size, visual_size),
			true
		)
	opening.queue_free()
	await process_frame


func _probe_field() -> void:
	var city: Node3D = load("res://scripts/procedural_map.gd").new()
	city.set("map_seed", 42)
	root.add_child(city)
	await process_frame
	await physics_frame
	# 필드 카메라는 정아이소메트릭(1,1,1) — null 을 넘기면 그 기본값을 쓴다.
	var index := 0
	for vehicle_type in VEHICLE_CATALOG.DEFINITIONS:
		for along_z in [false, true]:
			index += 1
			var node_name := "ProbeVehicle_%d" % index
			city.call(
				"_spawn_vehicle",
				node_name,
				vehicle_type,
				Vector3(320.0 + index * 18.0, 0.1, 0.0),
				along_z
			)
			var body := city.get_node_or_null(node_name) as StaticBody3D
			if body == null:
				continue
			var sprite := body.get_node("VehicleSprite") as Sprite3D
			var collision := body.get_node("VehicleCollision") as CollisionShape3D
			var shape := collision.shape as BoxShape3D
			var definition := VEHICLE_CATALOG.get_definition(str(vehicle_type))
			var visual: Dictionary = VEHICLE_FOOTPRINT.visual_footprint_from_sprite(
				sprite, definition, null
			)
			var visual_center: Vector2 = visual["center"]
			_report(
				"field %s/%s" % [str(vehicle_type), "z" if along_z else "x"],
				Vector2(collision.position.x, collision.position.z).distance_to(visual_center),
				_ratio(shape.size, visual["size"] as Vector2),
				false
			)

	var cover_definitions: Dictionary = city.get_script().get_script_constant_map()["ROAD_COVER_DEFINITIONS"]
	var cover_index := 0
	for cover_node in city.get_children():
		if not cover_node.is_in_group("road_cover_obstacle"):
			continue
		cover_index += 1
		if cover_index > 6:
			break
		var cover := cover_node as StaticBody3D
		var sprite := cover.get_node("CoverSprite") as Sprite3D
		var collision := cover.get_node("CoverCollision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		var cover_type := str(cover.get_meta("cover_type"))
		var definition: Dictionary = cover_definitions.get(cover_type, {})
		var visual: Dictionary = VEHICLE_FOOTPRINT.visual_footprint_from_sprite(
			sprite, definition, null
		)
		if not bool(visual.get("valid", false)):
			continue
		_report(
			"road_cover %s" % cover_type,
			Vector2(collision.position.x, collision.position.z).distance_to(visual["center"] as Vector2),
			_ratio(shape.size, visual["size"] as Vector2),
			false
		)
	city.queue_free()
	await process_frame
