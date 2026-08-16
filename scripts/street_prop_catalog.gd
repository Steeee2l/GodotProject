class_name StreetPropCatalog
extends RefCounted

# 거리 사물 카탈로그.
#
# 앞의 3종(dumpster/vending/construction)은 어느 구역에나 어울리는 "서울 공통"
# 사물이다. 그 아래 zone_* 계열은 구역 전용 대표 사물로, 원본 3종의 실루엣을
# 재활용하되 tmp/gen_zone_props.gd 로 리컬러한 별도 PNG를 쓴다. 같은 그림을
# modulate 로만 물들이면 밤/안개 색과 섞여 구분이 흐려지므로 아예 구워 두었다.
#
# collision_size 는 일부러 사물마다 크게 흔들었다. 스프라이트 크기가
# collision_size 로부터 역산되기 때문에, 크기를 바꾸면 실루엣 자체가 달라져
# "좌판 줄 / 배전반 / 드럼통"이 한눈에 구분된다.

# 원본 3종은 모두 같은 아이소메트릭 격자로 그려져 있어 발자국 좌표를 공유한다.
const _DUMPSTER_FOOTPRINT := [
	Vector2(203, 635),
	Vector2(780, 346),
	Vector2(1461, 686),
	Vector2(884, 793),
]
const _VENDING_FOOTPRINT := [
	Vector2(482, 715),
	Vector2(805, 553),
	Vector2(1275, 788),
	Vector2(952, 839),
]
const _CONSTRUCTION_FOOTPRINT := [
	Vector2(319, 615),
	Vector2(865, 342),
	Vector2(1453, 636),
	Vector2(907, 744),
]
const _ALL_DISTRICTS := [
	"street_mixed", "market_lane", "multi_family", "residential_buffer",
	"business_corner", "luxury_core", "open_space_edge", "service_interior",
]

const DEFINITIONS := {
	"dumpster_cluster": {
		"texture_path": "res://assets/props/street_dumpster_cluster_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.4, 1.65, 1.55),
		"footprint_corners_px": _DUMPSTER_FOOTPRINT,
		"districts": ["street_mixed", "market_lane", "multi_family", "residential_buffer"],
		"weight": 3.0,
	},
	"vending_cluster": {
		"texture_path": "res://assets/props/street_vending_cluster_v1.png",
		"collision_profile": "furniture_solid",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.65, 2.25, 0.95),
		"footprint_corners_px": _VENDING_FOOTPRINT,
		"districts": ["street_mixed", "business_corner", "luxury_core"],
		"weight": 2.2,
	},
	"construction_cluster": {
		"texture_path": "res://assets/props/street_construction_cluster_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.15, 1.45, 1.75),
		"footprint_corners_px": _CONSTRUCTION_FOOTPRINT,
		"districts": ["street_mixed", "business_corner", "market_lane", "multi_family"],
		"weight": 2.5,
	},

	# --- 남대문 폐시장: 골목을 좁히는 좌판·천막·간판 더미 ---
	"namdaemun_stall_row": {
		"texture_path": "res://assets/props/zone/namdaemun_stall_row_v1.png",
		"collision_profile": "furniture_solid",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.35, 2.55, 1.05),
		"footprint_corners_px": _VENDING_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 3.4,
	},
	"namdaemun_awning_stack": {
		"texture_path": "res://assets/props/zone/namdaemun_awning_stack_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.55, 1.85, 1.70),
		"footprint_corners_px": _CONSTRUCTION_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 2.8,
	},
	"namdaemun_signboard_pile": {
		"texture_path": "res://assets/props/zone/namdaemun_signboard_pile_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.30, 2.05, 1.35),
		"footprint_corners_px": _DUMPSTER_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 2.4,
	},

	# --- 을지로 지하구역: 배관 다발과 배전반 ---
	"euljiro_pipe_bundle": {
		"texture_path": "res://assets/props/zone/euljiro_pipe_bundle_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.85, 1.20, 1.55),
		"footprint_corners_px": _CONSTRUCTION_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 3.2,
	},
	"euljiro_switchboard_bank": {
		"texture_path": "res://assets/props/zone/euljiro_switchboard_bank_v1.png",
		"collision_profile": "furniture_solid",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.15, 2.60, 0.85),
		"footprint_corners_px": _VENDING_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 2.6,
	},

	# --- 용산 봉쇄선: 철조망 릴과 보급 상자 ---
	"yongsan_razorwire_spool": {
		"texture_path": "res://assets/props/zone/yongsan_razorwire_spool_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.60, 1.15, 2.10),
		"footprint_corners_px": _CONSTRUCTION_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 3.0,
	},
	"yongsan_supply_crate": {
		"texture_path": "res://assets/props/zone/yongsan_supply_crate_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.60, 1.90, 1.90),
		"footprint_corners_px": _DUMPSTER_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 2.8,
	},

	# --- 남산 오염 핵심부: 오염 드럼통과 격리 천막 ---
	"namsan_contamination_drum": {
		"texture_path": "res://assets/props/zone/namsan_contamination_drum_v1.png",
		"collision_profile": "street_cluster",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(2.05, 1.80, 1.95),
		"footprint_corners_px": _DUMPSTER_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 3.4,
	},
	"namsan_quarantine_tent": {
		"texture_path": "res://assets/props/zone/namsan_quarantine_tent_v1.png",
		"collision_profile": "furniture_solid",
		"source_size": Vector2i(1774, 887),
		"collision_size": Vector3(3.70, 2.70, 1.45),
		"footprint_corners_px": _VENDING_FOOTPRINT,
		"districts": _ALL_DISTRICTS,
		"weight": 2.6,
	},
}


static func get_definition(prop_id: String) -> Dictionary:
	return DEFINITIONS.get(prop_id, {}).duplicate(true)
