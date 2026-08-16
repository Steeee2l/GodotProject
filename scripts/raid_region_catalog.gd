class_name RaidRegionCatalog
extends RefCounted

# 구역 프로필 카탈로그.
#
# 예전에는 도로 밴드 수와 building_chance_multiplier 만 몇 % 씩 다르고 나머지는
# 전부 공통이라, 티어2(남대문)가 티어1(종로)와 사실상 같은 지도로 보였다.
# 이제는 아래 네 축을 구역마다 크게 벌려 "다른 동네"로 읽히게 한다.
#
#   1. 도로 격자 위상 — 밴드 개수 자체를 4~8개로 흔든다. 종로는 블록 5칸,
#      남대문은 블록 1~2칸(골목 미로), 을지로는 가로만 촘촘한 직선 통로,
#      용산은 중앙 2칸 폭 봉쇄 간선, 남산은 밴드 폭이 넓어 매 시드마다 어긋난다.
#   2. 건물 밀도와 개활지 비율 — building_chance_range / open_spread_radius /
#      parking_chance 로 "시야가 트인 정도"를 구역별로 정한다.
#   3. 대표 사물 — street_prop_pool 로 구역 전용 사물만 깔린다.
#   4. 색과 대기 — building_tint / prop_tint / vehicle_tint 로 스프라이트를
#      물들이고 fog_* 로 공기색을 바꾼다. 스프라이트가 전부 UNSHADED 라
#      조명은 아무 일도 하지 않으므로 이 둘이 유일한 색 레버다.

const DEFAULT_ZONE_ID := "jongno_outskirts"

const COMMON_BUILDINGS := [
	"hanbit_apartment_8x4",
	"academy_tower_6x4",
	"gangnam_single_story_8x4_aligned",
	"gangnam_ruined_lowrise_6x8_aligned",
	"gangnam_glass_tower_6x4_aligned",
	"gangnam_lowrise_commercial_8x4_aligned",
	"gangnam_lowrise_garage_8x4_aligned",
	"gangnam_clinic_pharmacy_6x4_aligned",
	"gangnam_food_alley_4x6_aligned",
	"gangnam_damaged_officetel_6x6_aligned",
	"seoul_market_row_8x4_v1",
	"seoul_multifamily_villa_6x6_v1",
	"gangnam_luxury_showroom_6x6_v1",
	"seoul_laundromat_repair_8x4_v1",
	"seoul_redbrick_corner_villa_6x6_v1",
]

const PROFILES := {
	"jongno_outskirts": {
		"display_name": "종로 외곽",
		"identity": "넓은 간선도로와 생활권 폐허가 섞인 초반 탐색 구역",
		"ground_texture_path": "res://assets/tiles/asphalt.png",
		"asphalt_tint": Color("#ffffff"),
		"lot_tint": Color("#77756f"),
		"sidewalk_tint": Color("#aaa79e"),
		"marking_tint": Color("#d1c87d"),
		"outer_tint": Color(0.62, 0.66, 0.66, 1.0),
		"building_tint": Color("#f4f5f0"),
		"prop_tint": Color("#ffffff"),
		"vehicle_tint": Color("#ffffff"),
		"fog_light_color": Color("#5c6663"),
		"fog_density_scale": 0.85,
		"fog_energy_scale": 1.0,
		"ambient_color": Color("#8e968f"),
		"river_enabled": true,
		# 4밴드 = 블록 5칸. 간선도로가 길게 뚫려 원거리 교전이 성립한다.
		"vertical_road_bands": [Vector2i(1, 2), Vector2i(7, 8), Vector2i(13, 14), Vector2i(19, 20)],
		"horizontal_road_bands": [Vector2i(1, 2), Vector2i(7, 8), Vector2i(13, 14), Vector2i(19, 20)],
		"building_chance_multiplier": 0.86,
		"building_chance_range": Vector2(0.10, 0.60),
		"open_spread_radius": 1,
		"parking_chance": 0.58,
		"vehicle_chance": 0.46,
		"cover_chance": 0.44,
		"cover_style": "mixed",
		"street_prop_count": 14,
		"street_prop_chance": 0.14,
		"street_prop_pool": {
			"dumpster_cluster": 3.0,
			"vending_cluster": 2.2,
			"construction_cluster": 2.5,
		},
		"market_prop_chance": 0.42,
		"large_vehicle_pool": [
			"sedan", "sedan", "suv", "taxi", "delivery_van",
			"burned_sedan", "overturned_hatchback", "truck", "bus",
		],
		"parked_vehicle_pool": [
			"sedan", "suv", "taxi", "delivery_van", "intact_hatchback",
			"intact_hatchback", "burned_sedan",
		],
		"container_adjustments": {},
		"loot_focus": "통조림 · 보통탄 · 기본 부품",
		"tactical_rule": "큰 도로는 빠르지만 노출되고, 생활 골목은 안전합니다.",
		"district_radius": 2,
		"district_min_separation": 6,
		"district_plan": [
			{"name": "luxury_core", "require_intersection": true, "avoid_intersection": false},
			{"name": "market_lane", "require_intersection": false, "avoid_intersection": true},
			{"name": "multi_family", "require_intersection": false, "avoid_intersection": false},
		],
		"playground_count": 2,
		"subway_count": 2,
		"apartment_estate_enabled": true,
		"allowed_buildings": COMMON_BUILDINGS,
		"entry_safe_radius": 30.0,
		"first_supply_distance": Vector2(8.0, 14.0),
		"mission_radius": 25.0,
		"recommended_duration_minutes": 24,
		"target_enemy_count": 24,
		"risk_split": Vector2(0.34, 0.70),
	},
	"namdaemun_market": {
		"display_name": "남대문 폐시장",
		"identity": "촘촘한 시장 골목, 짧은 시야, 식량과 공구 중심의 근거리 탐색",
		"ground_texture_path": "res://assets/tiles/regions/namdaemun_market_ground_v1.png",
		"asphalt_tint": Color("#e8dcc0"),
		"lot_tint": Color("#b9a985"),
		"sidewalk_tint": Color("#cbb994"),
		"marking_tint": Color("#d8bf63"),
		"outer_tint": Color("#7d6f55"),
		"building_tint": Color("#ffd7a3"),
		"prop_tint": Color("#fff0d8"),
		"vehicle_tint": Color("#f5d9b0"),
		"fog_light_color": Color("#8a6a41"),
		"fog_density_scale": 1.15,
		"fog_energy_scale": 1.05,
		"ambient_color": Color("#c49a6a"),
		"river_enabled": false,
		# 8밴드 = 블록 1~2칸. 종로 블록(5칸)의 3분의 1 수준이라 걸어 들어가면
		# 바로 "좁은 골목 미로"로 읽힌다. 블록은 거의 전부 건물로 채워
		# 도로가 양옆이 막힌 통로가 되게 한다.
		"vertical_road_bands": [
			Vector2i(1, 1), Vector2i(3, 4), Vector2i(6, 6), Vector2i(8, 9),
			Vector2i(11, 11), Vector2i(13, 14), Vector2i(16, 16), Vector2i(18, 19),
		],
		"horizontal_road_bands": [
			Vector2i(1, 2), Vector2i(4, 4), Vector2i(6, 7), Vector2i(9, 9),
			Vector2i(11, 12), Vector2i(14, 14), Vector2i(16, 17), Vector2i(19, 20),
		],
		"building_chance_multiplier": 1.6,
		"building_chance_range": Vector2(0.55, 0.98),
		"open_spread_radius": 2,
		"parking_chance": 0.06,
		"vehicle_chance": 0.16,
		"cover_chance": 0.94,
		"cover_style": "mixed",
		"street_prop_count": 48,
		"street_prop_chance": 0.62,
		"street_prop_pool": {
			"namdaemun_stall_row": 4.0,
			"namdaemun_awning_stack": 3.0,
			"namdaemun_signboard_pile": 2.6,
			"dumpster_cluster": 0.5,
		},
		"market_prop_chance": 0.95,
		"large_vehicle_pool": [
			"delivery_van", "delivery_van", "delivery_van", "taxi", "taxi",
			"sedan", "intact_hatchback", "truck",
		],
		"parked_vehicle_pool": [
			"delivery_van", "delivery_van", "taxi", "sedan", "intact_hatchback",
		],
		"container_adjustments": {
			"street_cache": 2,
			"clothing_cache": 2,
			"ammo_case": -2,
			"toolbox": -2,
		},
		"loot_focus": "통조림 · 의류 · 생활 공구",
		"tactical_rule": "골목 시야가 짧고 엄폐물이 많아 근거리 우회가 유리합니다.",
		"district_radius": 3,
		"district_min_separation": 5,
		# 시장 구역에 명품 상권은 없다. 좌판 골목 / 다세대 / 상가 거리로 짠다.
		"district_plan": [
			{"name": "market_lane", "require_intersection": false, "avoid_intersection": true},
			{"name": "multi_family", "require_intersection": false, "avoid_intersection": false},
			{"name": "street_mixed", "require_intersection": true, "avoid_intersection": false},
		],
		"playground_count": 1,
		"subway_count": 2,
		"apartment_estate_enabled": false,
		"allowed_buildings": [
			"gangnam_single_story_8x4_aligned", "gangnam_ruined_lowrise_6x8_aligned",
			"gangnam_lowrise_commercial_8x4_aligned", "gangnam_food_alley_4x6_aligned",
			"seoul_market_row_8x4_v1", "seoul_laundromat_repair_8x4_v1",
			"seoul_multifamily_villa_6x6_v1", "gangnam_luxury_showroom_6x6_v1",
			"seoul_redbrick_corner_villa_6x6_v1", "namdaemun_covered_market_8x4_v1",
		],
		"signature_building_id": "namdaemun_covered_market_8x4_v1",
		"signature_district": "market_lane",
		"entry_safe_radius": 34.0,
		"first_supply_distance": Vector2(9.0, 16.0),
		"mission_radius": 29.0,
		"recommended_duration_minutes": 26,
		"target_enemy_count": 30,
		"risk_split": Vector2(0.30, 0.66),
	},
	"euljiro_depths": {
		"display_name": "을지로 지하구역",
		"identity": "금속 공방과 산업 통로가 직선으로 이어지는 어두운 부품 파밍 구역",
		"ground_texture_path": "res://assets/tiles/regions/euljiro_industrial_ground_v1.png",
		"asphalt_tint": Color("#9fb0ae"),
		"lot_tint": Color("#5d6b6c"),
		"sidewalk_tint": Color("#78888a"),
		"marking_tint": Color("#93a05f"),
		"outer_tint": Color("#3c4749"),
		"building_tint": Color("#9fb8c6"),
		"prop_tint": Color("#c2d4dd"),
		"vehicle_tint": Color("#a8bcc6"),
		"fog_light_color": Color("#2b3f4a"),
		"fog_density_scale": 1.4,
		"fog_energy_scale": 0.8,
		"ambient_color": Color("#43626f"),
		"river_enabled": false,
		# 세로 4 / 가로 8 — 비대칭 격자. 동서로만 길게 뚫린 산업 통로가 되고
		# 남북 교차로가 드물어 "빠져나갈 옆길이 없는" 긴 복도 느낌이 난다.
		"vertical_road_bands": [Vector2i(2, 2), Vector2i(9, 9), Vector2i(16, 16), Vector2i(20, 20)],
		"horizontal_road_bands": [
			Vector2i(1, 1), Vector2i(4, 4), Vector2i(6, 6), Vector2i(9, 9),
			Vector2i(11, 11), Vector2i(14, 14), Vector2i(17, 17), Vector2i(20, 20),
		],
		"building_chance_multiplier": 1.35,
		"building_chance_range": Vector2(0.42, 0.94),
		"open_spread_radius": 0,
		"parking_chance": 0.52,
		"vehicle_chance": 0.30,
		"cover_chance": 0.88,
		"cover_style": "rubble",
		"street_prop_count": 34,
		"street_prop_chance": 0.44,
		"street_prop_pool": {
			"euljiro_pipe_bundle": 4.0,
			"euljiro_switchboard_bank": 3.2,
			"construction_cluster": 0.6,
		},
		"market_prop_chance": 0.20,
		"large_vehicle_pool": [
			"truck", "truck", "delivery_van", "delivery_van", "burned_sedan",
			"sedan", "overturned_hatchback",
		],
		"parked_vehicle_pool": [
			"delivery_van", "delivery_van", "truck", "sedan", "burned_sedan",
		],
		"container_adjustments": {
			"toolbox": 4,
			"ammo_case": 2,
			"street_cache": -4,
			"clothing_cache": -2,
		},
		"loot_focus": "총기 부품 · 공구 · 중급 탄약",
		"tactical_rule": "직선 산업 통로의 긴 사선과 지하 진입로를 번갈아 사용합니다.",
		"district_radius": 2,
		"district_min_separation": 6,
		"district_plan": [
			{"name": "business_corner", "require_intersection": true, "avoid_intersection": false},
			{"name": "market_lane", "require_intersection": false, "avoid_intersection": true},
			{"name": "multi_family", "require_intersection": false, "avoid_intersection": false},
		],
		"playground_count": 0,
		"subway_count": 3,
		"apartment_estate_enabled": false,
		"allowed_buildings": [
			"gangnam_ruined_lowrise_6x8_aligned", "gangnam_lowrise_garage_8x4_aligned",
			"gangnam_damaged_officetel_6x6_aligned", "seoul_laundromat_repair_8x4_v1",
			"gangnam_lowrise_commercial_8x4_aligned", "academy_tower_6x4",
			"seoul_market_row_8x4_v1", "seoul_multifamily_villa_6x6_v1",
			"gangnam_luxury_showroom_6x6_v1", "euljiro_metalworks_8x4_v1",
		],
		"signature_building_id": "euljiro_metalworks_8x4_v1",
		"signature_district": "business_corner",
		"entry_safe_radius": 36.0,
		"first_supply_distance": Vector2(10.0, 18.0),
		"mission_radius": 32.0,
		"recommended_duration_minutes": 27,
		"target_enemy_count": 37,
		"risk_split": Vector2(0.27, 0.62),
	},
	"yongsan_blockade": {
		"display_name": "용산 봉쇄선",
		"identity": "넓은 사선과 군용 엄폐물이 교차하는 장거리 교전 구역",
		"ground_texture_path": "res://assets/tiles/regions/yongsan_blockade_ground_v1.png",
		"asphalt_tint": Color("#cfcdb6"),
		"lot_tint": Color("#7c7f66"),
		"sidewalk_tint": Color("#9d9d82"),
		"marking_tint": Color("#e0bd52"),
		"outer_tint": Color("#5b5f4a"),
		"building_tint": Color("#d5d4a6"),
		"prop_tint": Color("#dcdcb4"),
		"vehicle_tint": Color("#cfd0ab"),
		"fog_light_color": Color("#5e6247"),
		"fog_density_scale": 0.6,
		"fog_energy_scale": 1.1,
		"ambient_color": Color("#a3a87c"),
		"river_enabled": false,
		# 10·11 두 칸이 나란히 도로 = 폭 40의 중앙 봉쇄 간선. 위성사진처럼
		# 지도를 반으로 가르는 굵은 띠가 생겨 다른 구역과 즉시 구분된다.
		"vertical_road_bands": [Vector2i(2, 2), Vector2i(10, 10), Vector2i(11, 11), Vector2i(19, 20)],
		"horizontal_road_bands": [Vector2i(2, 3), Vector2i(9, 9), Vector2i(15, 16), Vector2i(20, 20)],
		"building_chance_multiplier": 0.60,
		"building_chance_range": Vector2(0.05, 0.42),
		# -1 이면 "건물 옆칸은 무조건 공터" 규칙을 끈다. 건물 사이사이까지
		# 차량 집결지가 파고들어 군 차량 야적장처럼 보인다.
		"open_spread_radius": -1,
		"parking_chance": 0.50,
		"vehicle_chance": 0.74,
		"cover_chance": 0.92,
		"cover_style": "barricade",
		"street_prop_count": 30,
		"street_prop_chance": 0.42,
		"street_prop_pool": {
			"yongsan_razorwire_spool": 4.0,
			"yongsan_supply_crate": 3.4,
			"construction_cluster": 0.5,
		},
		"market_prop_chance": 0.0,
		"large_vehicle_pool": [
			"truck", "truck", "truck", "bus", "bus", "burned_sedan",
			"overturned_hatchback", "suv",
		],
		"parked_vehicle_pool": [
			"truck", "delivery_van", "suv", "burned_sedan", "overturned_hatchback",
		],
		"container_adjustments": {
			"ammo_case": 3,
			"weapon_case": 1,
			"street_cache": -3,
			"clothing_cache": -1,
		},
		"loot_focus": "방어구 · 군용 탄약 · 무기 부품",
		"tactical_rule": "차량과 검문소를 옮겨 다니며 장거리 사선을 끊어야 합니다.",
		"district_radius": 2,
		"district_min_separation": 7,
		# 봉쇄 구역에 명품 상권·시장 골목은 없다. 검문 거점 두 곳과 배후 주거.
		"district_plan": [
			{"name": "business_corner", "require_intersection": true, "avoid_intersection": false},
			{"name": "street_mixed", "require_intersection": false, "avoid_intersection": true},
			{"name": "multi_family", "require_intersection": false, "avoid_intersection": false},
		],
		"playground_count": 0,
		"subway_count": 1,
		"apartment_estate_enabled": false,
		"allowed_buildings": [
			"gangnam_glass_tower_6x4_aligned", "gangnam_damaged_officetel_6x6_aligned",
			"gangnam_lowrise_garage_8x4_aligned", "gangnam_ruined_lowrise_6x8_aligned",
			"academy_tower_6x4", "hanbit_apartment_8x4",
			"seoul_market_row_8x4_v1", "seoul_multifamily_villa_6x6_v1",
			"gangnam_luxury_showroom_6x6_v1", "yongsan_checkpoint_depot_8x4_v1",
		],
		"signature_building_id": "yongsan_checkpoint_depot_8x4_v1",
		"signature_district": "business_corner",
		"entry_safe_radius": 40.0,
		"first_supply_distance": Vector2(11.0, 20.0),
		"mission_radius": 36.0,
		"recommended_duration_minutes": 28,
		"target_enemy_count": 45,
		"risk_split": Vector2(0.25, 0.58),
	},
	"namsan_core": {
		"display_name": "남산 오염 핵심부",
		"identity": "붕괴한 고지대와 오염 공터 사이를 건너는 최고위험 심야 구역",
		"ground_texture_path": "res://assets/tiles/regions/namsan_contaminated_ground_v1.png",
		"asphalt_tint": Color("#9dab8c"),
		"lot_tint": Color("#5c6853"),
		"sidewalk_tint": Color("#77836b"),
		"marking_tint": Color("#9d8f4c"),
		"outer_tint": Color("#3b423a"),
		"building_tint": Color("#b5c39e"),
		"prop_tint": Color("#c8d4ae"),
		"vehicle_tint": Color("#a9b795"),
		"fog_light_color": Color("#4e5c3b"),
		"fog_density_scale": 1.6,
		"fog_energy_scale": 0.9,
		"ambient_color": Color("#74875c"),
		"river_enabled": false,
		# 밴드 폭이 3~4칸으로 넓어 시드마다 도로가 어긋난다. 격자가 무너져
		# 블록 크기가 들쭉날쭉해지고, 붕괴한 고지대처럼 읽힌다.
		"vertical_road_bands": [Vector2i(1, 3), Vector2i(6, 8), Vector2i(12, 15), Vector2i(18, 20)],
		"horizontal_road_bands": [
			Vector2i(1, 2), Vector2i(5, 7), Vector2i(9, 12), Vector2i(14, 16), Vector2i(19, 20),
		],
		"building_chance_multiplier": 0.55,
		"building_chance_range": Vector2(0.04, 0.38),
		"open_spread_radius": 1,
		"parking_chance": 0.22,
		"vehicle_chance": 0.52,
		"cover_chance": 0.95,
		"cover_style": "rubble",
		"street_prop_count": 36,
		"street_prop_chance": 0.50,
		"street_prop_pool": {
			"namsan_contamination_drum": 4.2,
			"namsan_quarantine_tent": 3.2,
			"dumpster_cluster": 0.4,
		},
		"market_prop_chance": 0.0,
		"large_vehicle_pool": [
			"burned_sedan", "burned_sedan", "burned_sedan", "overturned_hatchback",
			"overturned_hatchback", "truck", "bus",
		],
		"parked_vehicle_pool": [
			"burned_sedan", "burned_sedan", "overturned_hatchback", "sedan",
		],
		"container_adjustments": {
			"secure_cache": 3,
			"weapon_case": 1,
			"ammo_case": 2,
			"street_cache": -4,
			"clothing_cache": -2,
		},
		"loot_focus": "청사진 · AP탄 · 최고급 장비",
		"tactical_rule": "개활지를 짧게 건너고 붕괴 잔해 뒤에서 다음 이동을 준비해야 합니다.",
		"district_radius": 2,
		"district_min_separation": 7,
		# 오염 핵심부에는 명품 상권이 없다. 방역 거점 두 곳과 버려진 주거지.
		"district_plan": [
			{"name": "business_corner", "require_intersection": true, "avoid_intersection": false},
			{"name": "multi_family", "require_intersection": false, "avoid_intersection": true},
			{"name": "street_mixed", "require_intersection": false, "avoid_intersection": false},
		],
		"playground_count": 0,
		"subway_count": 1,
		"apartment_estate_enabled": false,
		"allowed_buildings": [
			"gangnam_ruined_lowrise_6x8_aligned", "gangnam_damaged_officetel_6x6_aligned",
			"gangnam_glass_tower_6x4_aligned", "hanbit_apartment_8x4",
			"seoul_market_row_8x4_v1", "seoul_multifamily_villa_6x6_v1",
			"gangnam_luxury_showroom_6x6_v1", "seoul_redbrick_corner_villa_6x6_v1",
			"namsan_decon_station_8x4_v1",
		],
		"signature_building_id": "namsan_decon_station_8x4_v1",
		"signature_district": "business_corner",
		"entry_safe_radius": 42.0,
		"first_supply_distance": Vector2(12.0, 22.0),
		"mission_radius": 40.0,
		"recommended_duration_minutes": 30,
		"target_enemy_count": 52,
		"risk_split": Vector2(0.22, 0.54),
	},
}


static func get_profile(zone_id: String) -> Dictionary:
	var resolved_id := zone_id if PROFILES.has(zone_id) else DEFAULT_ZONE_ID
	var profile := (PROFILES[resolved_id] as Dictionary).duplicate(true)
	profile["zone_id"] = resolved_id
	return profile


static func get_zone_ids() -> Array[String]:
	var result: Array[String] = []
	for zone_id in PROFILES.keys():
		result.append(str(zone_id))
	return result
