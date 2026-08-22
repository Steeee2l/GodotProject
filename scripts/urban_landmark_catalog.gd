class_name UrbanLandmarkCatalog
extends RefCounted

const MODULES_PER_CELL := 10

# footprint_corners_px 는 원본 아트 픽셀 좌표, source_size 는 그 좌표계 크기(임포트
# size_limit 보정용 — procedural_map._texture_space_footprint_corners 참고).
const DEFINITIONS := {
	"playground": {
		"node_name": "UrbanPlayground",
		"texture_path": "res://assets/landmarks/urban_playground_8x8_sealed_aligned.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(8, 8),
		"footprint_corners_px": [
			Vector2(25, 598),
			Vector2(624, 299),
			Vector2(1226, 600),
			Vector2(627, 899),
		],
		"collision_boxes": [
			{"offset": Vector2.ZERO, "size": Vector2(8.0, 8.0), "height": 2.4},
		],
	},
	"subway_entrance": {
		"node_name": "SubwayEntrance",
		"texture_path": "res://assets/landmarks/subway_entrance_4x4_aligned.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(4, 4),
		"footprint_corners_px": [
			Vector2(157, 885),
			Vector2(646, 641),
			Vector2(1100, 867),
			Vector2(610, 1139),
		],
		"collision_boxes": [
			{"offset": Vector2(0.0, 0.0), "size": Vector2(4.0, 4.0)},
		],
	},
	"apartment_complex": {
		"node_name": "KoreanApartmentGateway",
		"texture_path": "res://assets/landmarks/korean_apartment_gateway_36x32_v2.png",
		"source_size": Vector2i(1536, 1024),
		"footprint_modules": Vector2i(36, 32),
		"footprint_corners_px": [
			Vector2(20, 566),
			Vector2(768, 192),
			Vector2(1516, 566),
			Vector2(768, 940),
		],
		# A large estate continues beyond the north map edge. Only its closed
		# frontage is reachable; the central gap is filled by a modular portal
		# blocker in procedural_map.gd so it can be replaced by a portal later.
		"collision_boxes": [
			{"offset": Vector2(-13.0, -4.0), "size": Vector2(8.0, 22.0), "height": 3.4},
			{"offset": Vector2(13.0, -4.0), "size": Vector2(8.0, 22.0), "height": 3.4},
			{"offset": Vector2(0.0, -11.0), "size": Vector2(14.0, 8.0), "height": 3.4},
			{"offset": Vector2(-17.4, -2.0), "size": Vector2(1.2, 27.0), "height": 2.8},
			{"offset": Vector2(17.4, -2.0), "size": Vector2(1.2, 27.0), "height": 2.8},
			{"offset": Vector2(0.0, -15.4), "size": Vector2(36.0, 1.2), "height": 2.8},
			{"offset": Vector2(-12.0, 15.4), "size": Vector2(12.0, 1.2), "height": 2.8},
			{"offset": Vector2(12.0, 15.4), "size": Vector2(12.0, 1.2), "height": 2.8},
			{"offset": Vector2(-10.0, 12.4), "size": Vector2(5.0, 5.0), "height": 3.4},
		],
	},
}


static func get_definition(landmark_id: String) -> Dictionary:
	return DEFINITIONS.get(landmark_id, {}).duplicate(true)
