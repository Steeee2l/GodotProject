class_name LootEconomy
extends RefCounted

const STAGE_PROFILES := {
	1: {
		"name": "초반 생존 구역",
		"weapon_rarity_cap": 1,
		"ammo_tier_cap": 1,
		"field_value_cap": 3600,
		"enemy_value_cap": 1200,
		"total_value_cap": 4900,
		"weapon_spawn_cap": 1,
		"enemy_drop_cap": 18,
		"raid_kill_cap": 40,
		"weapon_case_chance": 0.16,
		"guaranteed_canned_food_pickups": 20,
		"canned_food_double_stack_chance": 0.22,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 5,
			"toolbox": 6,
			"clothing_cache": 4,
			"weapon_case": 1,
			"scrap_pile": 4,
			"catnip_planter": 3,
			"residential_pantry": 2,
			"vending_machine": 2,
			"pet_shop_crate": 2,
		},
	},
	2: {
		"name": "중간 파밍 구역",
		"weapon_rarity_cap": 2,
		"ammo_tier_cap": 2,
		"field_value_cap": 5200,
		"enemy_value_cap": 1800,
		"total_value_cap": 7200,
		"weapon_spawn_cap": 2,
		"enemy_drop_cap": 22,
		"raid_kill_cap": 55,
		"weapon_case_chance": 0.24,
		"guaranteed_canned_food_pickups": 22,
		"canned_food_double_stack_chance": 0.24,
		"container_counts": {
			"street_cache": 15,
			"ammo_case": 6,
			"toolbox": 7,
			"clothing_cache": 5,
			"weapon_case": 2,
			"secure_cache": 1,
			"scrap_pile": 5,
			"catnip_planter": 4,
			"residential_pantry": 2,
			"vending_machine": 2,
			"pharmacy_shelf": 2,
			"jewelry_case": 2,
		},
	},
	3: {
		"name": "고위험 파밍 구역",
		"weapon_rarity_cap": 3,
		"ammo_tier_cap": 3,
		"field_value_cap": 8000,
		"enemy_value_cap": 2800,
		"total_value_cap": 11000,
		"weapon_spawn_cap": 3,
		"enemy_drop_cap": 28,
		"raid_kill_cap": 70,
		"weapon_case_chance": 0.34,
		"guaranteed_canned_food_pickups": 24,
		"canned_food_double_stack_chance": 0.26,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 7,
			"toolbox": 8,
			"clothing_cache": 5,
			"weapon_case": 3,
			"secure_cache": 4,
			"scrap_pile": 6,
			"catnip_planter": 4,
			"pharmacy_shelf": 2,
			"electronics_bin": 3,
			"office_desk": 2,
			"subway_locker": 2,
		},
	},
	4: {
		"name": "봉인 고위험 구역",
		"weapon_rarity_cap": 4,
		"ammo_tier_cap": 4,
		"field_value_cap": 12000,
		"enemy_value_cap": 4200,
		"total_value_cap": 16500,
		"weapon_spawn_cap": 5,
		"enemy_drop_cap": 34,
		"raid_kill_cap": 85,
		"weapon_case_chance": 0.42,
		"guaranteed_canned_food_pickups": 26,
		"canned_food_double_stack_chance": 0.28,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 8,
			"toolbox": 9,
			"clothing_cache": 6,
			"weapon_case": 5,
			"secure_cache": 5,
			"scrap_pile": 7,
			"catnip_planter": 5,
			"electronics_bin": 4,
			"office_desk": 3,
			"subway_locker": 3,
			"jewelry_case": 2,
		},
	},
}

const CONTAINER_DEFINITIONS := {
	"street_cache": {
		"display_name": "버려진 보급 가방",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.22,
		"entries": [
			["canned_food", 46.0],
			["medkit", 15.0],
			["rubber_gasket", 13.0],
			["scope_lens", 10.0],
			["magazine_spring", 16.0],
		],
	},
	"ammo_case": {
		"display_name": "탄약 상자",
		"roll_min": 2,
		"roll_max": 3,
		"empty_chance": 0.15,
		"entries": [
			["ammo_9mm_fmj", 27.0],
			["ammo_45_fmj", 23.0],
			["ammo_12g_buckshot", 18.0],
			["ammo_762_fmj", 20.0],
		],
	},
	"toolbox": {
		"display_name": "폐공구함",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.12,
		"entries": [
			["rubber_gasket", 34.0],
			["scope_lens", 25.0],
			["magazine_spring", 31.0],
			["medkit", 10.0],
		],
	},
	"clothing_cache": {
		"display_name": "버려진 의류 더미",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.24,
		"entries": [
			["canned_food", 38.0],
			["medkit", 18.0],
			["scav_vest", 15.0],
			["patched_helmet", 12.0],
			["patched_sneakers", 17.0],
			["riot_vest", 4.0],
			["tactical_helmet", 3.0],
			["tactical_boots", 4.0],
		],
	},
	"weapon_case": {
		"display_name": "잠긴 무기 상자",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.22,
		"entries": [
			["magazine_spring", 38.0],
			["scope_lens", 24.0],
			["ammo_9mm_fmj", 16.0],
			["ammo_45_fmj", 12.0],
			["ammo_762_fmj", 10.0],
		],
	},
	"scrap_pile": {
		"display_name": "고철 더미",
		"roll_min": 2,
		"roll_max": 3,
		"empty_chance": 0.05,
		"entries": [
			["raw_scrap", 82.0],
			["raw_catnip", 8.0],
			["rubber_gasket", 6.0],
			["magazine_spring", 4.0],
		],
	},
	"catnip_planter": {
		"display_name": "야생 캣닢 화단",
		"roll_min": 2,
		"roll_max": 3,
		"empty_chance": 0.08,
		"entries": [
			["raw_catnip", 78.0],
			["raw_scrap", 10.0],
			["canned_food", 12.0],
		],
	},
	# ── 장소가 성격을 갖게 하는 컨테이너들 ──
	"pharmacy_shelf": {
		"display_name": "약국 진열대",
		"roll_min": 1, "roll_max": 3, "empty_chance": 0.18,
		"entries": [
			["medkit", 46.0], ["canned_food", 18.0],
			["rubber_gasket", 12.0], ["silver_spoon", 10.0], ["old_wristwatch", 14.0],
		],
	},
	"electronics_bin": {
		"display_name": "전자상가 부품함",
		"roll_min": 2, "roll_max": 3, "empty_chance": 0.14,
		"entries": [
			["circuit_board", 32.0], ["lithium_cell", 22.0], ["fiber_spool", 14.0],
			["copper_bundle", 18.0], ["scope_lens", 9.0], ["server_drive", 5.0],
		],
	},
	"jewelry_case": {
		"display_name": "귀금속 진열장",
		"roll_min": 1, "roll_max": 2, "empty_chance": 0.34,
		"minimum_stage": 2,
		"entries": [
			["gold_tooth", 30.0], ["wedding_ring", 24.0],
			["gold_chain", 12.0], ["old_wristwatch", 22.0], ["silver_spoon", 12.0],
		],
	},
	"pet_shop_crate": {
		"display_name": "반려동물 용품 상자",
		"roll_min": 2, "roll_max": 3, "empty_chance": 0.12,
		"entries": [
			["canned_food", 34.0], ["raw_catnip", 26.0], ["cat_toy_mouse", 18.0],
			["bell_collar", 14.0], ["medkit", 8.0],
		],
	},
	"vending_machine": {
		"display_name": "부서진 자판기",
		"roll_min": 1, "roll_max": 3, "empty_chance": 0.26,
		"entries": [
			["canned_food", 52.0], ["subway_token", 24.0], ["medkit", 10.0],
			["cat_toy_mouse", 14.0],
		],
	},
	"office_desk": {
		"display_name": "사무실 책상",
		"roll_min": 1, "roll_max": 2, "empty_chance": 0.28,
		"entries": [
			["faded_photo", 26.0], ["subway_map", 18.0], ["old_wristwatch", 16.0],
			["circuit_board", 14.0], ["shelter_roster", 10.0], ["ceramic_shard", 16.0],
		],
	},
	"subway_locker": {
		"display_name": "지하철 물품보관함",
		"roll_min": 1, "roll_max": 3, "empty_chance": 0.30,
		"entries": [
			["subway_token", 22.0], ["subway_map", 16.0], ["canned_food", 18.0],
			["gold_tooth", 8.0], ["ammo_9mm_fmj", 20.0], ["bell_collar", 16.0],
		],
	},
	"residential_pantry": {
		"display_name": "가정집 찬장",
		"roll_min": 2, "roll_max": 3, "empty_chance": 0.16,
		"entries": [
			["canned_food", 44.0], ["silver_spoon", 16.0], ["ceramic_shard", 14.0],
			["faded_photo", 12.0], ["medkit", 14.0],
		],
	},
	"secure_cache": {
		"display_name": "봉인 보급함",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.32,
		"minimum_stage": 3,
		"entries": [
			["scope_lens", 18.0],
			["magazine_spring", 16.0],
			["ammo_9mm_ap", 13.0],
			["ammo_45_ap", 13.0],
			["ammo_12g_slug", 13.0],
			["ammo_762_ap", 9.0],
			["riot_vest", 7.0],
			["tactical_helmet", 6.0],
			["tactical_boots", 5.0],
			["rifle_blueprint", 3.2],
			["shotgun_blueprint", 3.2],
			["sealed_zone_keycard", 1.4],
		],
	},
}

const ITEM_CATALOG := {
	"canned_food": {
		"loot_type": "canned_food",
		"display_name": "통조림",
		"base_value": 35,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	# 원자재: 쉘터 가동 연료. 개당 가치는 낮지만 부피가 커서 가방을 압박한다.
	"raw_scrap": {
		"loot_type": "raw_scrap",
		"display_name": "고철 조각",
		"base_value": 14,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
		"stack_min": 3,
		"stack_max": 6,
	},
	"raw_catnip": {
		"loot_type": "raw_catnip",
		"display_name": "캣닢 잎",
		"base_value": 11,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
		"stack_min": 2,
		"stack_max": 5,
	},
	"medkit": {
		"loot_type": "medkit",
		"display_name": "구급약",
		"base_value": 120,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	# ── 귀중품 ────────────────────────────────────────────────
	# 쓸 데는 없고 값만 나가는 물건들. 가방 한 칸을 무엇으로 채울지가
	# 이 게임의 핵심 판단인데, 그 판단을 순수하게 만드는 계열이다.
	# 사람이 사라진 서울에 남은 것들 — 고양이에겐 쓸모없지만 값은 나간다.
	"subway_token": {
		"loot_type": "valuable", "display_name": "지하철 승차권 뭉치",
		"base_value": 55, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
		"stack_min": 2, "stack_max": 4,
	},
	"ceramic_shard": {
		"loot_type": "valuable", "display_name": "청자 조각",
		"base_value": 90, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
	},
	"silver_spoon": {
		"loot_type": "valuable", "display_name": "은수저",
		"base_value": 140, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
		"stack_min": 1, "stack_max": 3,
	},
	"old_wristwatch": {
		"loot_type": "valuable", "display_name": "낡은 손목시계",
		"base_value": 180, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1,
	},
	"circuit_board": {
		"loot_type": "valuable", "display_name": "회로 기판",
		"base_value": 210, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1,
		"stack_min": 1, "stack_max": 3,
	},
	"lithium_cell": {
		"loot_type": "valuable", "display_name": "리튬 셀",
		"base_value": 260, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 2,
		"stack_min": 1, "stack_max": 3,
	},
	"copper_bundle": {
		"loot_type": "valuable", "display_name": "구리 배선 뭉치",
		"base_value": 175, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
		"stack_min": 2, "stack_max": 4,
	},
	"server_drive": {
		"loot_type": "valuable", "display_name": "서버 하드디스크",
		"base_value": 420, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2,
	},
	"fiber_spool": {
		"loot_type": "valuable", "display_name": "광섬유 다발",
		"base_value": 330, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 2,
	},
	"gold_tooth": {
		"loot_type": "valuable", "display_name": "금니",
		"base_value": 480, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 1,
	},
	"wedding_ring": {
		"loot_type": "valuable", "display_name": "결혼반지",
		"base_value": 620, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2,
	},
	"gold_chain": {
		"loot_type": "valuable", "display_name": "순금 목걸이",
		"base_value": 880, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 3,
	},
	# 고양이에게만 의미가 있는 것들 — 값은 낮지만 세계관을 만든다
	"bell_collar": {
		"loot_type": "valuable", "display_name": "낡은 방울 목걸이",
		"base_value": 70, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
	},
	"faded_photo": {
		"loot_type": "valuable", "display_name": "빛바랜 가족사진",
		"base_value": 45, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
	},
	"cat_toy_mouse": {
		"loot_type": "valuable", "display_name": "쥐 인형",
		"base_value": 60, "slot_size": 1, "rarity_tier": 1, "minimum_stage": 1,
		"stack_min": 1, "stack_max": 3,
	},
	# 정보 — 서사와 지역 해금의 씨앗
	"subway_map": {
		"loot_type": "valuable", "display_name": "지하철 노선도",
		"base_value": 300, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1,
	},
	"shelter_roster": {
		"loot_type": "valuable", "display_name": "대피소 명단",
		"base_value": 380, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2,
	},
	"military_freq": {
		"loot_type": "valuable", "display_name": "군용 주파수표",
		"base_value": 700, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 3,
	},
	"rubber_gasket": {
		"loot_type": "mod_component",
		"component_id": "rubber_gasket",
		"display_name": "소음기용 고무 패킹",
		"base_value": 85,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"scope_lens": {
		"loot_type": "mod_component",
		"component_id": "scope_lens",
		"display_name": "스코프 렌즈",
		"base_value": 110,
		"slot_size": 1,
		"rarity_tier": 2,
		"minimum_stage": 1,
	},
	"magazine_spring": {
		"loot_type": "mod_component",
		"component_id": "magazine_spring",
		"display_name": "탄창 스프링",
		"base_value": 95,
		"slot_size": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"rifle_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "rifle_blueprint",
		"display_name": "소총 제작 청사진",
		"base_value": 1800,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"shotgun_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "shotgun_blueprint",
		"display_name": "산탄총 제작 청사진",
		"base_value": 1600,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"sealed_zone_keycard": {
		"loot_type": "progression_item",
		"progression_item_id": "sealed_zone_keycard",
		"display_name": "봉인구역 키카드",
		"base_value": 3200,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 3,
	},
	"m1911": {
		"loot_type": "weapon",
		"weapon_id": "m1911",
		"display_name": "M1911",
		"base_value": 480,
		"slot_size": 6,
		"rarity_tier": 1,
		"minimum_stage": 1,
		"weight": 12.0,
	},
	"mp5": {
		"loot_type": "weapon",
		"weapon_id": "mp5",
		"display_name": "MP5",
		"base_value": 1200,
		"slot_size": 8,
		"rarity_tier": 2,
		"minimum_stage": 2,
		"weight": 7.0,
	},
	"double_barrel": {
		"loot_type": "weapon",
		"weapon_id": "double_barrel",
		"display_name": "더블배럴 산탄총",
		"base_value": 1050,
		"slot_size": 8,
		"rarity_tier": 2,
		"minimum_stage": 2,
		"weight": 6.0,
	},
	"ak47": {
		"loot_type": "weapon",
		"weapon_id": "ak47",
		"display_name": "AK-47",
		"base_value": 2400,
		"slot_size": 10,
		"rarity_tier": 3,
		"minimum_stage": 3,
		"weight": 3.0,
	},
	"ammo_9mm_fmj": {
		"loot_type": "ammo",
		"ammo_id": "9mm_fmj",
		"display_name": "9mm 보통탄",
		"base_value": 3,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_45_fmj": {
		"loot_type": "ammo",
		"ammo_id": "45_fmj",
		"display_name": ".45 ACP 보통탄",
		"base_value": 4,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_12g_buckshot": {
		"loot_type": "ammo",
		"ammo_id": "12g_buckshot",
		"display_name": "12게이지 벅샷",
		"base_value": 7,
		"slot_size": 1,
		"ammo_tier": 1,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"ammo_762_fmj": {
		"loot_type": "ammo",
		"ammo_id": "762_fmj",
		"display_name": "7.62mm 보통탄",
		"base_value": 6,
		"slot_size": 1,
		"ammo_tier": 2,
		"rarity_tier": 2,
		"minimum_stage": 2,
	},
	"ammo_9mm_ap": {
		"loot_type": "ammo",
		"ammo_id": "9mm_ap",
		"display_name": "9mm AP탄",
		"base_value": 14,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_45_ap": {
		"loot_type": "ammo",
		"ammo_id": "45_ap",
		"display_name": ".45 ACP 철갑탄",
		"base_value": 16,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_12g_slug": {
		"loot_type": "ammo",
		"ammo_id": "12g_slug",
		"display_name": "12게이지 슬러그",
		"base_value": 18,
		"slot_size": 1,
		"ammo_tier": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"ammo_762_ap": {
		"loot_type": "ammo",
		"ammo_id": "762_ap",
		"display_name": "7.62mm AP탄",
		"base_value": 24,
		"slot_size": 1,
		"ammo_tier": 4,
		"rarity_tier": 4,
		"minimum_stage": 4,
	},
	"scav_vest": {
		"loot_type": "armor",
		"equipment_id": "scav_vest",
		"display_name": "누더기 방탄 조끼",
		"base_value": 260,
		"slot_size": 4,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"patched_helmet": {
		"loot_type": "armor",
		"equipment_id": "patched_helmet",
		"display_name": "덧댄 철판 헬멧",
		"base_value": 220,
		"slot_size": 3,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"patched_sneakers": {
		"loot_type": "armor",
		"equipment_id": "patched_sneakers",
		"display_name": "누더기 운동화",
		"base_value": 180,
		"slot_size": 2,
		"rarity_tier": 1,
		"minimum_stage": 1,
	},
	"riot_vest": {
		"loot_type": "armor",
		"equipment_id": "riot_vest",
		"display_name": "진압 방탄 조끼",
		"base_value": 850,
		"slot_size": 5,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"tactical_helmet": {
		"loot_type": "armor",
		"equipment_id": "tactical_helmet",
		"display_name": "전술 헬멧",
		"base_value": 720,
		"slot_size": 3,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"tactical_boots": {
		"loot_type": "armor",
		"equipment_id": "tactical_boots",
		"display_name": "전술 부츠",
		"base_value": 620,
		"slot_size": 2,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
}

const DISTRICT_BIASES := {
	"market_lane": {"canned_food": 1.8, "medkit": 1.15},
	"luxury_core": {
		"scav_vest": 1.5,
		"patched_helmet": 1.5,
		"riot_vest": 2.1,
		"tactical_helmet": 2.1,
	},
	"multi_family": {"canned_food": 1.45, "medkit": 1.25},
	"business_corner": {"scope_lens": 1.5, "magazine_spring": 1.35},
	"residential_buffer": {"canned_food": 1.5, "medkit": 1.35},
	"open_space_edge": {
		"rubber_gasket": 1.35,
		"scope_lens": 1.35,
		"magazine_spring": 1.35,
	},
}


static func get_stage_for_zone(zone_data: Dictionary) -> int:
	return clampi(
		int(zone_data.get("stage_tier", zone_data.get("required_tier", 1))),
		1,
		4
	)


static func get_stage_profile(stage_tier: int) -> Dictionary:
	return (STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary).duplicate(true)


static func get_guaranteed_canned_food_pickup_count(stage_tier: int) -> int:
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	return maxi(0, int(profile.get("guaranteed_canned_food_pickups", 0)))


static func roll_guaranteed_canned_food_amount(
	stage_tier: int,
	random: RandomNumberGenerator
) -> int:
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	var double_stack_chance := float(
		profile.get("canned_food_double_stack_chance", 0.0)
	)
	return 2 if random.randf() < double_stack_chance else 1


static func get_container_display_name(container_type: String) -> String:
	var definition := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	return str(definition.get("display_name", "보급품"))


static func build_container_plan(stage_tier: int, random: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	var counts := profile.get("container_counts", {}) as Dictionary
	for container_type_value in counts.keys():
		var container_type := str(container_type_value)
		for _index in maxi(0, int(counts[container_type_value])):
			result.append(container_type)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var held := result[index]
		result[index] = result[swap_index]
		result[swap_index] = held
	return result


static func roll_container(
	container_type: String,
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> Array[Dictionary]:
	var stage := clampi(stage_tier, 1, 4)
	var container := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	if container.is_empty() or stage < int(container.get("minimum_stage", 1)):
		return []
	var profile := STAGE_PROFILES[stage] as Dictionary
	var results: Array[Dictionary] = []
	var roll_count := random.randi_range(
		int(container.get("roll_min", 1)),
		int(container.get("roll_max", 1))
	)
	if container_type == "weapon_case":
		if random.randf() <= float(profile.get("weapon_case_chance", 0.0)):
			var weapon_id := _roll_weapon_id(stage, random)
			if not weapon_id.is_empty():
				results.append(_materialize_item(weapon_id, stage, random))
				roll_count = maxi(0, roll_count - 1)
	for _roll_index in roll_count:
		if random.randf() < float(container.get("empty_chance", 0.0)):
			continue
		var item_id := _roll_weighted_item(
			container.get("entries", []) as Array,
			stage,
			district,
			random
		)
		if not item_id.is_empty():
			results.append(_materialize_item(item_id, stage, random))
	return results


static func roll_loose_loot(
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> Dictionary:
	var container_type := "street_cache"
	match district:
		"luxury_core":
			container_type = "clothing_cache"
		"business_corner", "open_space_edge":
			container_type = "toolbox"
	var results := roll_container(container_type, stage_tier, district, random)
	if results.is_empty():
		return _materialize_item("canned_food", stage_tier, random)
	return results[0]


static func roll_enemy_drop(
	stage_tier: int,
	enemy_kind: String,
	enemy_weapon_id: String,
	random: RandomNumberGenerator,
	unarmed_recovery: bool = false
) -> Dictionary:
	var stage := clampi(stage_tier, 1, 4)
	var weapon_drop_chance := (
		0.58
		if unarmed_recovery
		else get_enemy_weapon_drop_chance(stage)
	)
	if (
		enemy_kind != "melee"
		and enemy_weapon_id != "baseball_bat"
		and random.randf() < weapon_drop_chance
	):
		var weapon_definition := _find_weapon_definition(enemy_weapon_id)
		if not weapon_definition.is_empty() and _item_allowed(weapon_definition, stage):
			return _materialize_item(enemy_weapon_id, stage, random)
	var ordinary_drop_chance := 0.62 + float(stage - 1) * 0.03
	if random.randf() > ordinary_drop_chance:
		return {}
	var roll := random.randf()
	if enemy_kind != "melee":
		if roll < 0.20:
			var ammo_item_id := _enemy_ammo_item_id(enemy_weapon_id, stage, random)
			if not ammo_item_id.is_empty():
				return _materialize_item(ammo_item_id, stage, random, true)
		if roll < 0.52:
			return _materialize_item("canned_food", stage, random)
		if roll < 0.60:
			return _materialize_item("medkit", stage, random)
		if roll < 0.92:
			return _materialize_item(
				_roll_basic_component_id(stage, random),
				stage,
				random
			)
	elif roll < 0.45:
		return _materialize_item("canned_food", stage, random)
	elif roll < 0.55:
		return _materialize_item("medkit", stage, random)
	elif roll < 0.92:
		return _materialize_item(
			_roll_basic_component_id(stage, random),
			stage,
			random
		)
	var armor_pool := ["scav_vest", "patched_helmet", "patched_sneakers"]
	if stage >= 3 and random.randf() < 0.22:
		armor_pool = ["riot_vest", "tactical_helmet", "tactical_boots"]
	return _materialize_item(
		armor_pool[random.randi_range(0, armor_pool.size() - 1)],
		stage,
		random
	)


static func get_enemy_weapon_drop_chance(stage_tier: int) -> float:
	return 0.05 + float(clampi(stage_tier, 1, 4) - 1) * 0.01


static func get_definition_value(definition: Dictionary) -> int:
	var data := definition.get("data", {}) as Dictionary
	return maxi(
		0,
		int(data.get(
			"total_value",
			int(data.get("base_value", 0)) * maxi(1, int(data.get("amount", 1)))
		))
	)


static func try_register_loot(
	game_state: Node,
	definition: Dictionary,
	source: String,
	stage_tier: int,
	ignore_caps: bool = false
) -> bool:
	if definition.is_empty():
		return false
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	var value := get_definition_value(definition)
	var loot_type := str(definition.get("type", ""))
	# 원자재는 쉘터 가동 연료다. 가치 상한 때문에 스폰이 막히면 진행이 멈추므로 제외한다.
	if loot_type in ["raw_scrap", "raw_catnip"]:
		return true
	if not ignore_caps:
		if (
			loot_type == "weapon"
			and int(game_state.get("raid_weapon_drops_generated"))
			>= int(profile.get("weapon_spawn_cap", 1))
		):
			return false
		if (
			source == "enemy"
			and int(game_state.get("raid_enemy_drops_generated"))
			>= int(profile.get("enemy_drop_cap", 1))
		):
			return false
		var source_value := int(game_state.get("raid_field_loot_value_generated"))
		var source_cap := int(profile.get("field_value_cap", 0))
		if source == "enemy":
			source_value = int(game_state.get("raid_enemy_loot_value_generated"))
			source_cap = int(profile.get("enemy_value_cap", 0))
		if source_value + value > source_cap:
			return false
		if (
			int(game_state.get("raid_total_loot_value_generated")) + value
			> int(profile.get("total_value_cap", 0))
		):
			return false
	game_state.set(
		"raid_total_loot_value_generated",
		int(game_state.get("raid_total_loot_value_generated")) + value
	)
	if source == "enemy":
		game_state.set(
			"raid_enemy_loot_value_generated",
			int(game_state.get("raid_enemy_loot_value_generated")) + value
		)
		game_state.set(
			"raid_enemy_drops_generated",
			int(game_state.get("raid_enemy_drops_generated")) + 1
		)
	else:
		game_state.set(
			"raid_field_loot_value_generated",
			int(game_state.get("raid_field_loot_value_generated")) + value
		)
	if loot_type == "weapon":
		game_state.set(
			"raid_weapon_drops_generated",
			int(game_state.get("raid_weapon_drops_generated")) + 1
		)
	return true


static func simulate_stage_supply(stage_tier: int, run_count: int, seed_value: int = 7331) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var total_weapons := 0
	var total_ammo := 0
	var total_value := 0
	var total_high_tier_ammo := 0
	var total_canned_food := 0
	var total_components := 0
	var runs_with_common_supply := 0
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 4)] as Dictionary
	for _run_index in maxi(1, run_count):
		var run_value := 0
		var guaranteed_supply_value := 0
		var run_weapon_count := 0
		var run_common_supply := 0
		for _pickup_index in get_guaranteed_canned_food_pickup_count(stage_tier):
			var amount := roll_guaranteed_canned_food_amount(stage_tier, random)
			total_canned_food += amount
			run_common_supply += amount
			guaranteed_supply_value += amount * int(
				(ITEM_CATALOG["canned_food"] as Dictionary).get("base_value", 0)
			)
		for container_type in build_container_plan(stage_tier, random):
			for definition in roll_container(container_type, stage_tier, "street_mixed", random):
				var value := get_definition_value(definition)
				# 원자재는 전리품이 아니라 연료다. try_register_loot과 마찬가지로
				# 가치 예산에서 빼야 탄약·부품 스폰을 잠식하지 않는다.
				if str(definition.get("type", "")) in ["raw_scrap", "raw_catnip"]:
					continue
				if run_value + value > int(profile.get("field_value_cap", 0)):
					continue
				if (
					str(definition.get("type", "")) == "weapon"
					and run_weapon_count >= int(profile.get("weapon_spawn_cap", 1))
				):
					continue
				run_value += value
				var data := definition.get("data", {}) as Dictionary
				match str(definition.get("type", "")):
					"weapon":
						run_weapon_count += 1
						total_weapons += 1
					"ammo":
						total_ammo += int(data.get("amount", 0))
						if int(data.get("ammo_tier", 1)) >= 3:
							total_high_tier_ammo += int(data.get("amount", 0))
					"canned_food":
						var amount := int(data.get("amount", 1))
						total_canned_food += amount
						run_common_supply += amount
					"mod_component":
						var amount := int(data.get("amount", 1))
						total_components += amount
						run_common_supply += amount
		if run_common_supply >= 12:
			runs_with_common_supply += 1
		total_value += run_value + guaranteed_supply_value
	var divisor := float(maxi(1, run_count))
	return {
		"average_weapons": float(total_weapons) / divisor,
		"average_ammo": float(total_ammo) / divisor,
		"average_value": float(total_value) / divisor,
		"average_high_tier_ammo": float(total_high_tier_ammo) / divisor,
		"average_canned_food": float(total_canned_food) / divisor,
		"average_components": float(total_components) / divisor,
		"average_common_supply": float(total_canned_food + total_components) / divisor,
		"common_supply_success_rate": float(runs_with_common_supply) / divisor,
	}


static func _roll_weapon_id(stage_tier: int, random: RandomNumberGenerator) -> String:
	var weighted: Array = []
	for item_id_value in ["m1911", "mp5", "double_barrel", "ak47"]:
		var item_id := str(item_id_value)
		var definition := ITEM_CATALOG[item_id] as Dictionary
		if _item_allowed(definition, stage_tier):
			weighted.append([item_id, float(definition.get("weight", 1.0))])
	return _weighted_pick(weighted, random)


static func _roll_weighted_item(
	entries: Array,
	stage_tier: int,
	district: String,
	random: RandomNumberGenerator
) -> String:
	var eligible: Array = []
	var biases := DISTRICT_BIASES.get(district, {}) as Dictionary
	for entry_value in entries:
		var entry := entry_value as Array
		if entry.size() < 2:
			continue
		var item_id := str(entry[0])
		if not ITEM_CATALOG.has(item_id):
			continue
		var definition := ITEM_CATALOG[item_id] as Dictionary
		if not _item_allowed(definition, stage_tier):
			continue
		var weight := float(entry[1]) * float(biases.get(item_id, 1.0))
		if weight > 0.0:
			eligible.append([item_id, weight])
	return _weighted_pick(eligible, random)


static func _weighted_pick(entries: Array, random: RandomNumberGenerator) -> String:
	var total_weight := 0.0
	for entry_value in entries:
		var entry := entry_value as Array
		total_weight += float(entry[1])
	if total_weight <= 0.0:
		return ""
	var roll := random.randf() * total_weight
	for entry_value in entries:
		var entry := entry_value as Array
		roll -= float(entry[1])
		if roll <= 0.0:
			return str(entry[0])
	return str((entries.back() as Array)[0])


static func _item_allowed(definition: Dictionary, stage_tier: int) -> bool:
	var stage := clampi(stage_tier, 1, 4)
	var profile := STAGE_PROFILES[stage] as Dictionary
	if stage < int(definition.get("minimum_stage", 1)):
		return false
	if (
		str(definition.get("loot_type", "")) == "weapon"
		and int(definition.get("rarity_tier", 1))
		> int(profile.get("weapon_rarity_cap", 1))
	):
		return false
	if (
		str(definition.get("loot_type", "")) == "ammo"
		and int(definition.get("ammo_tier", 1))
		> int(profile.get("ammo_tier_cap", 1))
	):
		return false
	return true


static func _materialize_item(
	item_id: String,
	stage_tier: int,
	random: RandomNumberGenerator,
	enemy_stack: bool = false
) -> Dictionary:
	if not ITEM_CATALOG.has(item_id):
		return {}
	var catalog := (ITEM_CATALOG[item_id] as Dictionary).duplicate(true)
	var loot_type := str(catalog.get("loot_type", ""))
	var amount := 1
	if loot_type == "ammo":
		amount = _roll_ammo_amount(
			stage_tier,
			int(catalog.get("ammo_tier", 1)),
			random,
			enemy_stack
		)
	elif catalog.has("stack_min") or catalog.has("stack_max"):
		# 원자재처럼 뭉쳐 나오는 아이템은 카탈로그의 스택 범위를 굴린다.
		var stack_min := maxi(1, int(catalog.get("stack_min", 1)))
		var stack_max := maxi(stack_min, int(catalog.get("stack_max", stack_min)))
		var tier_bonus := clampi(stage_tier - 1, 0, 3)
		amount = random.randi_range(stack_min, stack_max + tier_bonus)
	var data := catalog.duplicate(true)
	data.erase("loot_type")
	data.erase("weight")
	data.erase("stack_min")
	data.erase("stack_max")
	data["amount"] = amount
	data["item_id"] = item_id
	data["stage_tier"] = clampi(stage_tier, 1, 4)
	data["total_value"] = int(data.get("base_value", 0)) * amount
	data["value_per_slot"] = float(data["total_value"]) / float(maxi(1, int(data.get("slot_size", 1))))
	return {"type": loot_type, "data": data}


static func _roll_ammo_amount(
	stage_tier: int,
	ammo_tier: int,
	random: RandomNumberGenerator,
	enemy_stack: bool
) -> int:
	if enemy_stack:
		return random.randi_range(3, 8)
	if ammo_tier >= 3:
		return random.randi_range(2, 5) if stage_tier == 3 else random.randi_range(3, 6)
	match clampi(stage_tier, 1, 4):
		1:
			return random.randi_range(4, 7)
		2:
			return random.randi_range(4, 8)
		3:
			return random.randi_range(5, 10)
		_:
			return random.randi_range(6, 12)


static func _enemy_ammo_item_id(
	enemy_weapon_id: String,
	stage_tier: int,
	random: RandomNumberGenerator
) -> String:
	var ordinary_id := ""
	var high_tier_id := ""
	match enemy_weapon_id:
		"m1911":
			ordinary_id = "ammo_45_fmj"
			high_tier_id = "ammo_45_ap"
		"mp5":
			ordinary_id = "ammo_9mm_fmj"
			high_tier_id = "ammo_9mm_ap"
		"double_barrel":
			ordinary_id = "ammo_12g_buckshot"
			high_tier_id = "ammo_12g_slug"
		"ak47":
			ordinary_id = "ammo_762_fmj"
			high_tier_id = "ammo_762_ap"
		_:
			return ""
	var ap_chance := 0.0
	if stage_tier == 3:
		ap_chance = 0.035
	elif stage_tier >= 4:
		ap_chance = 0.07
	if ap_chance > 0.0 and random.randf() < ap_chance:
		var high_definition := ITEM_CATALOG.get(high_tier_id, {}) as Dictionary
		if not high_definition.is_empty() and _item_allowed(high_definition, stage_tier):
			return high_tier_id
	var ordinary_definition := ITEM_CATALOG.get(ordinary_id, {}) as Dictionary
	if ordinary_definition.is_empty() or not _item_allowed(ordinary_definition, stage_tier):
		return ""
	return ordinary_id


static func _roll_basic_component_id(
	stage_tier: int,
	random: RandomNumberGenerator
) -> String:
	var components := ["rubber_gasket", "magazine_spring"]
	if stage_tier >= 2:
		components.append("scope_lens")
	return components[random.randi_range(0, components.size() - 1)]


static func _find_weapon_definition(weapon_id: String) -> Dictionary:
	var definition := ITEM_CATALOG.get(weapon_id, {}) as Dictionary
	if str(definition.get("loot_type", "")) != "weapon":
		return {}
	return definition
