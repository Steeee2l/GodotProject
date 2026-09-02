class_name VehicleCatalog
extends RefCounted

# collision_size 는 (길이, 높이, 너비) — 길이가 '아트에 그려진 긴 축'이다.
# footprint_corners_px 는 그 아트가 땅을 딛는 사각형의 원본 픽셀 좌표 [서, 북, 동, 남],
# source_size 는 그 좌표계의 크기(임포트 size_limit 로 줄어든 텍스처 보정용).
# art_axis 는 아트의 긴 축이 어느 월드 축을 향하는지 — 기본 "z". 실제 배치 축과
# 다르면 scripts/vehicle_footprint.gd 가 좌우 반전으로 맞춘다.
const DEFINITIONS := {
	"sedan": {
		"texture_path": "res://assets/vehicles/wrecked_sedan.png",
		"collision_profile": "vehicle_standard",
		"collision_size": Vector3(4.11, 1.45, 2.36),
		"footprint_corners_px": [
			Vector2(8, 358),
			Vector2(455, 134),
			Vector2(712, 263),
			Vector2(265, 487),
		],
	},
	"truck": {
		"texture_path": "res://assets/vehicles/wrecked_truck.png",
		"collision_profile": "vehicle_heavy",
		"collision_size": Vector3(5.63, 2.85, 3.30),
		"footprint_corners_px": [
			Vector2(15, 590),
			Vector2(491, 352),
			Vector2(770, 492),
			Vector2(294, 730),
		],
	},
	"bus": {
		"texture_path": "res://assets/vehicles/wrecked_bus.png",
		"collision_profile": "vehicle_heavy",
		"collision_size": Vector3(8.90, 3.15, 4.26),
		"footprint_corners_px": [
			Vector2(10, 487),
			Vector2(578, 203),
			Vector2(850, 339),
			Vector2(282, 623),
		],
	},
	"luxury_sedan": {
		"texture_path": "res://assets/vehicles/wrecked_luxury_sedan_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1254, 1254),
		"collision_size": Vector3(4.48, 1.5, 2.72),
		"footprint_corners_px": [
			Vector2(28, 811),
			Vector2(770, 440),
			Vector2(1220, 665),
			Vector2(470, 1005),
		],
	},
	"suv": {
		"texture_path": "res://assets/vehicles/wrecked_suv_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.78, 1.72, 2.92),
		"footprint_corners_px": [
			Vector2(313, 700),
			Vector2(980, 365),
			Vector2(1500, 625),
			Vector2(830, 810),
		],
	},
	"taxi": {
		"texture_path": "res://assets/vehicles/wrecked_taxi_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.81, 1.48, 2.85),
		"footprint_corners_px": [
			Vector2(230, 715),
			Vector2(1000, 330),
			Vector2(1576, 620),
			Vector2(805, 825),
		],
	},
	"delivery_van": {
		"texture_path": "res://assets/vehicles/wrecked_delivery_van_v1.png",
		"collision_profile": "vehicle_heavy",
		"source_size": Vector2i(1536, 1024),
		"collision_size": Vector3(5.35, 2.25, 2.05),
		"footprint_corners_px": [
			Vector2(241, 765),
			Vector2(840, 465),
			Vector2(1383, 710),
			Vector2(785, 933),
		],
	},
	"intact_hatchback": {
		"texture_path": "res://assets/vehicles/abandoned_intact_hatchback_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(4.35, 1.55, 1.78),
		"state": "abandoned_intact",
		"footprint_corners_px": [
			Vector2(281, 680),
			Vector2(920, 360),
			Vector2(1505, 615),
			Vector2(865, 800),
		],
	},
	"burned_sedan": {
		"texture_path": "res://assets/vehicles/burned_sedan_shell_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1484, 1060),
		"collision_size": Vector3(4.70, 1.25, 1.82),
		"state": "burned_out",
		"footprint_corners_px": [
			Vector2(28, 815),
			Vector2(810, 425),
			Vector2(1470, 755),
			Vector2(690, 998),
		],
	},
	"overturned_hatchback": {
		"texture_path": "res://assets/vehicles/overturned_hatchback_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(4.50, 1.32, 1.88),
		"state": "overturned",
		"footprint_corners_px": [
			Vector2(326, 650),
			Vector2(960, 335),
			Vector2(1470, 590),
			Vector2(835, 758),
		],
	},
}

# 오프닝 다리 위의 잔해 차량. 필드 생성기가 뽑아 쓰면 안 되므로 별도 목록이다.
# 접지 사각형은 아트의 알파 실루엣에서 뽑았다 — 화면 가로 폭(서↔동)과 지면에
# 닿는 두 변(앞면·근측면)이 실루엣의 지지선과 맞도록 잡았다.
const OPENING_DEFINITIONS := {
	"opening_taxi": {
		"texture_path": "res://assets/opening/opening_wrecked_taxi_v1.png",
		"collision_profile": "vehicle_standard",
		"source_size": Vector2i(1254, 1254),
		"collision_size": Vector3(4.14, 1.45, 1.91),
		"footprint_corners_px": [
			Vector2(42, 877),
			Vector2(856, 353),
			Vector2(1231, 594),
			Vector2(417, 1118),
		],
	},
	"opening_truck": {
		"texture_path": "res://assets/opening/opening_wrecked_truck_v1.png",
		"collision_profile": "vehicle_heavy",
		"source_size": Vector2i(1254, 1254),
		"collision_size": Vector3(4.27, 2.25, 1.87),
		# 이 그림만 차머리가 오른쪽 아래를 본다 — 긴 축이 월드 X 로 그려져 있다.
		"art_axis": "x",
		"footprint_corners_px": [
			Vector2(83, 696),
			Vector2(414, 483),
			Vector2(1168, 968),
			Vector2(837, 1182),
		],
	},
	"opening_bus": {
		"texture_path": "res://assets/opening/opening_wrecked_bus_v1.png",
		"collision_profile": "vehicle_heavy",
		"source_size": Vector2i(1254, 1254),
		"collision_size": Vector3(5.11, 2.55, 1.80),
		"footprint_corners_px": [
			Vector2(97, 973),
			Vector2(919, 443),
			Vector2(1207, 629),
			Vector2(385, 1158),
		],
	},
}


static func get_definition(vehicle_type: String) -> Dictionary:
	if DEFINITIONS.has(vehicle_type):
		return DEFINITIONS[vehicle_type].duplicate(true)
	return OPENING_DEFINITIONS.get(vehicle_type, {}).duplicate(true)
