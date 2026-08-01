class_name BuildingCatalog
extends RefCounted

const MODULE_SIZE := 1.0
const MODULES_PER_CELL := 10

const DEFINITIONS := {
	"hanbit_apartment_8x4": {
		"node_name": "HanbitApartment",
		"texture_path": "res://assets/buildings/hanbit_apartment_8x4.png",
		"footprint_modules": Vector2i(8, 4),
		"height_world": 12.5,
		"footprint_corners_px": [
			Vector2(289, 1116),
			Vector2(528, 996),
			Vector2(1007, 1235),
			Vector2(768, 1355),
		],
		"occlusion_depth": 11.0,
		"height_class": "high",
		"density_weight": 0.35,
	},
	"academy_tower_6x4": {
		"node_name": "AcademyTower",
		"texture_path": "res://assets/buildings/academy_tower_6x4.png",
		"footprint_modules": Vector2i(6, 4),
		"height_world": 16.0,
		"footprint_corners_px": [
			Vector2(337, 1140),
			Vector2(624, 996),
			Vector2(1055, 1211),
			Vector2(768, 1355),
		],
		"occlusion_depth": 13.0,
		"height_class": "high",
		"density_weight": 0.25,
	},
	"gangnam_single_story_8x4_aligned": {
		"node_name": "GangnamSingleStory",
		"texture_path": "res://assets/buildings/gangnam_single_story_8x4_aligned.png",
		"footprint_modules": Vector2i(8, 4),
		"height_world": 3.6,
		"footprint_corners_px": [
			Vector2(40, 678),
			Vector2(399, 498),
			Vector2(1229, 913),
			Vector2(870, 1102),
		],
		"occlusion_depth": 5.5,
		"height_class": "low",
		"density_weight": 3.0,
	},
	"gangnam_ruined_lowrise_6x8_aligned": {
		"node_name": "GangnamRuinedLowrise",
		"texture_path": "res://assets/buildings/gangnam_ruined_lowrise_6x8_aligned.png",
		"footprint_modules": Vector2i(6, 8),
		"height_world": 8.5,
		"footprint_corners_px": [
			Vector2(40, 1013),
			Vector2(694, 686),
			Vector2(1219, 949),
			Vector2(563, 1220),
		],
		"occlusion_depth": 10.0,
		"height_class": "mid",
		"density_weight": 1.1,
	},
	"gangnam_glass_tower_6x4_aligned": {
		"node_name": "GangnamGlassTower",
		"texture_path": "res://assets/buildings/gangnam_glass_tower_6x4_aligned.png",
		"footprint_modules": Vector2i(6, 4),
		"height_world": 15.5,
		"footprint_corners_px": [
			Vector2(332, 1021),
			Vector2(549, 912),
			Vector2(922, 1099),
			Vector2(695, 1227),
		],
		"occlusion_depth": 14.0,
		"height_class": "high",
		"density_weight": 0.2,
	},
	"gangnam_lowrise_commercial_8x4_aligned": {
		"node_name": "GangnamLowriseCommercial",
		"texture_path": "res://assets/buildings/gangnam_lowrise_commercial_8x4_aligned.png",
		# The generated artwork's long axis runs along world Z. Treating it as
		# 8x4 rotated its collision box ninety degrees away from the storefront.
		"footprint_modules": Vector2i(4, 8),
		"height_world": 5.6,
		"footprint_corners_px": [
			Vector2(263, 927),
			Vector2(1029, 544),
			Vector2(1269, 663),
			Vector2(502, 1047),
		],
		"occlusion_depth": 6.8,
		"height_class": "low",
		"density_weight": 3.2,
	},
	"gangnam_lowrise_garage_8x4_aligned": {
		"node_name": "GangnamLowriseGarage",
		"texture_path": "res://assets/buildings/gangnam_lowrise_garage_8x4_aligned.png",
		"footprint_modules": Vector2i(8, 4),
		"height_world": 3.8,
		"footprint_corners_px": [
			Vector2(93, 703),
			Vector2(450, 525),
			Vector2(1176, 888),
			Vector2(819, 1066),
		],
		"occlusion_depth": 5.0,
		"height_class": "low",
		"density_weight": 3.5,
	},
	"gangnam_clinic_pharmacy_6x4_aligned": {
		"node_name": "GangnamClinicPharmacy",
		"texture_path": "res://assets/buildings/gangnam_clinic_pharmacy_6x4_aligned.png",
		"footprint_modules": Vector2i(6, 4),
		"height_world": 8.0,
		"footprint_corners_px": [
			Vector2(466, 795),
			Vector2(829, 613),
			Vector2(1065, 731),
			Vector2(702, 913),
		],
		"occlusion_depth": 9.2,
		"height_class": "mid",
		"density_weight": 1.35,
	},
	"gangnam_food_alley_4x6_aligned": {
		"node_name": "GangnamFoodAlley",
		"texture_path": "res://assets/buildings/gangnam_food_alley_4x6_aligned.png",
		"footprint_modules": Vector2i(4, 6),
		"height_world": 5.4,
		"footprint_corners_px": [
			Vector2(122, 1093),
			Vector2(620, 844),
			Vector2(907, 988),
			Vector2(409, 1237),
		],
		"occlusion_depth": 6.6,
		"height_class": "low",
		"density_weight": 2.8,
	},
	"gangnam_damaged_officetel_6x6_aligned": {
		"node_name": "GangnamDamagedOfficetel",
		"texture_path": "res://assets/buildings/gangnam_damaged_officetel_6x6_aligned.png",
		"footprint_modules": Vector2i(6, 6),
		"height_world": 13.0,
		"footprint_corners_px": [
			Vector2(279, 942),
			Vector2(629, 767),
			Vector2(975, 940),
			Vector2(625, 1115),
		],
		"occlusion_depth": 13.8,
		"height_class": "mid",
		"density_weight": 0.65,
	},
	"seoul_market_row_8x4_v1": {
		"node_name": "SeoulMarketRow",
		"texture_path": "res://assets/buildings/seoul_market_row_8x4_v1.png",
		"footprint_modules": Vector2i(8, 4),
		"height_world": 6.2,
		"footprint_corners_px": [
			Vector2(40, 860),
			Vector2(360, 700),
			Vector2(1000, 1020),
			Vector2(680, 1180),
		],
		"occlusion_depth": 7.4,
		"height_class": "low",
		"density_weight": 4.8,
		"districts": ["market_lane"],
	},
	"seoul_multifamily_villa_6x6_v1": {
		"node_name": "SeoulMultifamilyVilla",
		"texture_path": "res://assets/buildings/seoul_multifamily_villa_6x6_v1.png",
		"footprint_modules": Vector2i(6, 6),
		"height_world": 10.5,
		"footprint_corners_px": [
			Vector2(235, 995),
			Vector2(625, 800),
			Vector2(1015, 995),
			Vector2(625, 1190),
		],
		"occlusion_depth": 11.2,
		"height_class": "mid",
		"density_weight": 4.6,
		"districts": ["multi_family"],
	},
	"gangnam_luxury_showroom_6x6_v1": {
		"node_name": "GangnamLuxuryShowroom",
		"texture_path": "res://assets/buildings/gangnam_luxury_showroom_6x6_v1.png",
		"footprint_modules": Vector2i(6, 6),
		"height_world": 17.5,
		"footprint_corners_px": [
			Vector2(250, 990),
			Vector2(625, 802.5),
			Vector2(1000, 990),
			Vector2(625, 1177.5),
		],
		"occlusion_depth": 15.8,
		"height_class": "high",
		"density_weight": 4.4,
		"districts": ["luxury_core"],
	},
	"seoul_laundromat_repair_8x4_v1": {
		"node_name": "SeoulLaundromatRepair",
		"texture_path": "res://assets/buildings/seoul_laundromat_repair_8x4_v1.png",
		"source_size": Vector2i(1536, 1024),
		"footprint_modules": Vector2i(8, 4),
		"height_world": 7.2,
		"footprint_corners_px": [
			Vector2(165, 670),
			Vector2(765, 370),
			Vector2(1365, 670),
			Vector2(765, 970),
		],
		"occlusion_depth": 8.1,
		"height_class": "low",
		"density_weight": 3.8,
		"districts": ["street_mixed", "market_lane"],
	},
	"seoul_redbrick_corner_villa_6x6_v1": {
		"node_name": "SeoulRedbrickCornerVilla",
		"texture_path": "res://assets/buildings/seoul_redbrick_corner_villa_6x6_v1.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(6, 6),
		"height_world": 11.8,
		"footprint_corners_px": [
			Vector2(142, 890),
			Vector2(602, 660),
			Vector2(1062, 890),
			Vector2(602, 1120),
		],
		"occlusion_depth": 12.4,
		"height_class": "mid",
		"density_weight": 4.0,
		"districts": ["multi_family", "residential_buffer"],
	},
	"namdaemun_covered_market_8x4_v1": {
		"node_name": "NamdaemunCoveredMarket",
		"texture_path": "res://assets/buildings/namdaemun_covered_market_8x4_v1.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(8, 4),
		"height_world": 6.4,
		# This asset was generated from the verified Seoul market 8x4 template.
		"footprint_corners_px": [
			Vector2(40, 860),
			Vector2(360, 700),
			Vector2(1000, 1020),
			Vector2(680, 1180),
		],
		"occlusion_depth": 7.6,
		"height_class": "low",
		"density_weight": 6.4,
		"districts": ["market_lane"],
	},
	"euljiro_metalworks_8x4_v1": {
		"node_name": "EuljiroMetalworks",
		"texture_path": "res://assets/buildings/euljiro_metalworks_8x4_v1.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(8, 4),
		"height_world": 4.8,
		"footprint_corners_px": [
			Vector2(93, 703),
			Vector2(450, 525),
			Vector2(1176, 888),
			Vector2(819, 1066),
		],
		"occlusion_depth": 6.1,
		"height_class": "low",
		"density_weight": 6.0,
		"districts": ["street_mixed", "business_corner", "market_lane"],
	},
	"yongsan_checkpoint_depot_8x4_v1": {
		"node_name": "YongsanCheckpointDepot",
		"texture_path": "res://assets/buildings/yongsan_checkpoint_depot_8x4_v1.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(8, 4),
		"height_world": 5.4,
		"footprint_corners_px": [
			Vector2(93, 703),
			Vector2(450, 525),
			Vector2(1176, 888),
			Vector2(819, 1066),
		],
		"occlusion_depth": 7.0,
		"height_class": "low",
		"density_weight": 6.2,
		"districts": ["street_mixed", "business_corner", "luxury_core"],
	},
	"namsan_decon_station_8x4_v1": {
		"node_name": "NamsanDeconStation",
		"texture_path": "res://assets/buildings/namsan_decon_station_8x4_v1.png",
		"source_size": Vector2i(1254, 1254),
		"footprint_modules": Vector2i(8, 4),
		"height_world": 5.2,
		"footprint_corners_px": [
			Vector2(93, 703),
			Vector2(450, 525),
			Vector2(1176, 888),
			Vector2(819, 1066),
		],
		"occlusion_depth": 6.8,
		"height_class": "low",
		"density_weight": 6.2,
		"districts": ["street_mixed", "business_corner", "open_space_edge", "luxury_core"],
	}
}


static func get_definition(building_id: String) -> Dictionary:
	return DEFINITIONS.get(building_id, {}).duplicate(true)


static func is_valid_definition(definition: Dictionary) -> bool:
	if definition.is_empty():
		return false
	var footprint: Vector2i = definition.get("footprint_modules", Vector2i.ZERO)
	var corners: Array = definition.get("footprint_corners_px", [])
	return (
		footprint.x >= 2
		and footprint.y >= 2
		and footprint.x % 2 == 0
		and footprint.y % 2 == 0
		and corners.size() == 4
		and float(definition.get("height_world", 0.0)) > 0.0
	)
