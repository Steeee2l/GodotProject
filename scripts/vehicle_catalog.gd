class_name VehicleCatalog
extends RefCounted

const DEFINITIONS := {
	"sedan": {
		"texture_path": "res://assets/vehicles/wrecked_sedan.png",
		"collision_size": Vector3(4.65, 1.45, 1.82),
		"footprint_corners_px": [
			Vector2(8, 358),
			Vector2(455, 134),
			Vector2(712, 263),
			Vector2(265, 487),
		],
	},
	"truck": {
		"texture_path": "res://assets/vehicles/wrecked_truck.png",
		"collision_size": Vector3(6.65, 2.85, 2.28),
		"footprint_corners_px": [
			Vector2(15, 590),
			Vector2(491, 352),
			Vector2(770, 492),
			Vector2(294, 730),
		],
	},
	"bus": {
		"texture_path": "res://assets/vehicles/wrecked_bus.png",
		"collision_size": Vector3(10.6, 3.15, 2.55),
		"footprint_corners_px": [
			Vector2(10, 487),
			Vector2(578, 203),
			Vector2(850, 339),
			Vector2(282, 623),
		],
	},
	"luxury_sedan": {
		"texture_path": "res://assets/vehicles/wrecked_luxury_sedan_v1.png",
		"collision_size": Vector3(5.25, 1.5, 1.95),
		"footprint_corners_px": [
			Vector2(28, 811),
			Vector2(770, 440),
			Vector2(1220, 665),
			Vector2(470, 1005),
		],
	},
	"suv": {
		"texture_path": "res://assets/vehicles/wrecked_suv_v1.png",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(4.78, 1.72, 1.92),
		"footprint_corners_px": [
			Vector2(313, 700),
			Vector2(980, 365),
			Vector2(1500, 625),
			Vector2(830, 810),
		],
	},
	"taxi": {
		"texture_path": "res://assets/vehicles/wrecked_taxi_v1.png",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(4.82, 1.48, 1.84),
		"footprint_corners_px": [
			Vector2(230, 715),
			Vector2(1000, 330),
			Vector2(1576, 620),
			Vector2(805, 825),
		],
	},
	"delivery_van": {
		"texture_path": "res://assets/vehicles/wrecked_delivery_van_v1.png",
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


static func get_definition(vehicle_type: String) -> Dictionary:
	return DEFINITIONS.get(vehicle_type, {}).duplicate(true)
