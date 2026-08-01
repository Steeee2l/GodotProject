class_name StreetPropCatalog
extends RefCounted

const DEFINITIONS := {
    "dumpster_cluster": {
        "texture_path": "res://assets/props/street_dumpster_cluster_v1.png",
        "collision_profile": "street_cluster",
        "source_size": Vector2i(1774, 887),
        "collision_size": Vector3(3.4, 1.65, 1.55),
        "footprint_corners_px": [
            Vector2(203, 635),
            Vector2(780, 346),
            Vector2(1461, 686),
            Vector2(884, 793),
        ],
        "districts": ["street_mixed", "market_lane", "multi_family", "residential_buffer"],
        "weight": 3.0,
    },
    "vending_cluster": {
        "texture_path": "res://assets/props/street_vending_cluster_v1.png",
        "collision_profile": "furniture_solid",
        "source_size": Vector2i(1774, 887),
        "collision_size": Vector3(2.65, 2.25, 0.95),
        "footprint_corners_px": [
            Vector2(482, 715),
            Vector2(805, 553),
            Vector2(1275, 788),
            Vector2(952, 839),
        ],
        "districts": ["street_mixed", "business_corner", "luxury_core"],
        "weight": 2.2,
    },
    "construction_cluster": {
        "texture_path": "res://assets/props/street_construction_cluster_v1.png",
        "collision_profile": "street_cluster",
        "source_size": Vector2i(1774, 887),
        "collision_size": Vector3(3.15, 1.45, 1.75),
        "footprint_corners_px": [
            Vector2(319, 615),
            Vector2(865, 342),
            Vector2(1453, 636),
            Vector2(907, 744),
        ],
        "districts": ["street_mixed", "business_corner", "market_lane", "multi_family"],
        "weight": 2.5,
    },
}


static func get_definition(prop_id: String) -> Dictionary:
    return DEFINITIONS.get(prop_id, {}).duplicate(true)
