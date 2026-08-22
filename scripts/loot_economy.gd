class_name LootEconomy
extends RefCounted

# ── 캡 설계 메모 ────────────────────────────────────────────────
# 예전 enemy_value_cap(1스테이지 1200)은 킬 4~5번이면 소진됐다. 그 뒤 모든
# 적 드랍이 try_register_loot에서 조용히 거부되고, 처치 보장 fallback만
# ignore_caps로 새어 나왔다 — 즉 캡은 이미 '지켜지지 않는 캡'이었는데
# (실측: 25킬에 8,677 가치가 스폰) 정작 호환탄 회수·식량·부품 같은 정상
# 드랍만 골라 죽이고 있었다. 캡을 실제 판 규모(raid_kill_cap 40~100킬)에
# 맞춰 다시 세운다. 값을 올리는 게 아니라, 있는 그대로 정직하게 만드는 것.
# weapon_spawn_cap은 필드 컨테이너 전용으로 좁히고, 적 드랍은 아래
# enemy_weapon_spawn_cap이 따로 센다(카운터도 분리).
const STAGE_PROFILES := {
	1: {
		"name": "초반 생존 구역",
		"weapon_rarity_cap": 1,
		"ammo_tier_cap": 1,
		"field_value_cap": 3600,
		"enemy_value_cap": 12000,
		"total_value_cap": 16000,
		"weapon_spawn_cap": 4,
		"enemy_weapon_spawn_cap": 8,
		"enemy_drop_cap": 70,
		"raid_kill_cap": 40,
		"weapon_case_chance": 0.16,
		"guaranteed_canned_food_pickups": 12,
		"canned_food_double_stack_chance": 0.22,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 5,
			"toolbox": 6,
			"clothing_cache": 4,
			"weapon_case": 1,
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
		"enemy_value_cap": 17000,
		"total_value_cap": 22500,
		"weapon_spawn_cap": 5,
		"enemy_weapon_spawn_cap": 10,
		"enemy_drop_cap": 95,
		"raid_kill_cap": 55,
		"weapon_case_chance": 0.24,
		"guaranteed_canned_food_pickups": 14,
		"canned_food_double_stack_chance": 0.24,
		"container_counts": {
			"street_cache": 15,
			"ammo_case": 6,
			"toolbox": 7,
			"clothing_cache": 5,
			"weapon_case": 2,
			"secure_cache": 1,
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
		"enemy_value_cap": 24000,
		"total_value_cap": 32000,
		"weapon_spawn_cap": 6,
		"enemy_weapon_spawn_cap": 12,
		"enemy_drop_cap": 125,
		"raid_kill_cap": 70,
		"weapon_case_chance": 0.34,
		"guaranteed_canned_food_pickups": 15,
		"canned_food_double_stack_chance": 0.26,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 7,
			"toolbox": 8,
			"clothing_cache": 5,
			"weapon_case": 3,
			"secure_cache": 4,
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
		"enemy_value_cap": 34000,
		"total_value_cap": 46000,
		"weapon_spawn_cap": 8,
		"enemy_weapon_spawn_cap": 15,
		"enemy_drop_cap": 150,
		"raid_kill_cap": 85,
		"weapon_case_chance": 0.42,
		"guaranteed_canned_food_pickups": 16,
		"canned_food_double_stack_chance": 0.28,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 8,
			"toolbox": 9,
			"clothing_cache": 6,
			"weapon_case": 5,
			"secure_cache": 5,
			"electronics_bin": 4,
			"office_desk": 3,
			"subway_locker": 3,
			"jewelry_case": 2,
		},
	},
	5: {
		"name": "남산 오염 핵심부",
		"weapon_rarity_cap": 4,
		"ammo_tier_cap": 4,
		"field_value_cap": 17000,
		"enemy_value_cap": 44000,
		"total_value_cap": 61000,
		"weapon_spawn_cap": 10,
		"enemy_weapon_spawn_cap": 18,
		"enemy_drop_cap": 175,
		"raid_kill_cap": 100,
		"weapon_case_chance": 0.5,
		"guaranteed_canned_food_pickups": 17,
		"canned_food_double_stack_chance": 0.30,
		"container_counts": {
			"street_cache": 14,
			"ammo_case": 9,
			"toolbox": 10,
			"clothing_cache": 6,
			"weapon_case": 7,
			"secure_cache": 8,
			"electronics_bin": 5,
			"office_desk": 4,
			"subway_locker": 4,
			"jewelry_case": 4,
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
			["military_vest", 2.0],
			["military_helmet", 1.5],
			["assault_boots", 2.0],
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
			["canned_food", 60.0], ["cat_toy_mouse", 18.0],
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
			["military_vest", 5.0],
			["military_helmet", 4.0],
			["assault_boots", 4.0],
			["rifle_blueprint", 3.2],
			["shotgun_blueprint", 3.2],
			["sealed_zone_keycard", 1.4],
			["churu", 8.0],
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
	"churu": {
		"loot_type": "churu",
		"display_name": "희귀 츄르",
		"base_value": 1500,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 4,
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
	# ── 무기 사다리 청사진 ──
	# 메인 미션 체인 2단계 보상 전용(을지로 2단계 → AKM, 남대문 2단계 → 펌프).
	# 드랍 테이블·상인 매대에 넣지 않는다. progression 타입이라 가방 칸 0.
	"akm_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "akm_blueprint",
		"display_name": "AKM 개조 청사진",
		"base_value": 2600,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 3,
	},
	"pump_blueprint": {
		"loot_type": "progression_item",
		"progression_item_id": "pump_blueprint",
		"display_name": "펌프 산탄총 청사진",
		"base_value": 2200,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 2,
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
	# ── 쉘터 확장 키(티어 3·4·5) ──
	# 메인 미션 체인 3단계 보상 전용. 드랍 테이블·상인 매대 어디에도 넣지 않는다 —
	# 카탈로그에 두는 이유는 이름·가치 조회(정산·창고 표시)를 한 곳에서 하기 위해서다.
	# progression 타입이라 가방 칸은 0(get_raid_item_slot_cost).
	"namdaemun_depot_plans": {
		"loot_type": "progression_item",
		"progression_item_id": "namdaemun_depot_plans",
		"display_name": "남대문 창고 설계도",
		"base_value": 2400,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 2,
	},
	"euljiro_grid_schematic": {
		"loot_type": "progression_item",
		"progression_item_id": "euljiro_grid_schematic",
		"display_name": "을지로 배전 도면",
		"base_value": 3600,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 3,
	},
	"yongsan_control_key": {
		"loot_type": "progression_item",
		"progression_item_id": "yongsan_control_key",
		"display_name": "용산 통제 키",
		"base_value": 5200,
		"slot_size": 1,
		"rarity_tier": 5,
		"minimum_stage": 4,
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
	# ── 무기 사다리 상위 기종 ──
	# akm·pump_shotgun은 존3+ 적 무장 풀과 weapon_case에 낮은 비율로 들어간다.
	# k2는 카탈로그에만 있다(정산·창고 표시용) — 적 풀·상자 어디에도 안 넣는다.
	# 용산 통제 키로 작업대에서만 만든다(_roll_weapon_id 목록에서도 제외).
	"akm": {
		"loot_type": "weapon",
		"weapon_id": "akm",
		"display_name": "AKM",
		"base_value": 3600,
		"slot_size": 10,
		"rarity_tier": 3,
		"minimum_stage": 3,
		"weight": 1.4,
	},
	"pump_shotgun": {
		"loot_type": "weapon",
		"weapon_id": "pump_shotgun",
		"display_name": "펌프 산탄총",
		"base_value": 2900,
		"slot_size": 9,
		"rarity_tier": 3,
		"minimum_stage": 3,
		"weight": 1.6,
	},
	"k2": {
		"loot_type": "weapon",
		"weapon_id": "k2",
		"display_name": "K2",
		"base_value": 6400,
		"slot_size": 10,
		"rarity_tier": 4,
		"minimum_stage": 5,
		"weight": 0.0,
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
	"military_vest": {
		"loot_type": "armor",
		"equipment_id": "military_vest",
		"display_name": "군납 방탄복",
		"base_value": 1450,
		"slot_size": 5,
		"rarity_tier": 4,
		"minimum_stage": 4,
	},
	"military_helmet": {
		"loot_type": "armor",
		"equipment_id": "military_helmet",
		"display_name": "군납 전투 헬멧",
		"base_value": 1200,
		"slot_size": 3,
		"rarity_tier": 4,
		"minimum_stage": 4,
	},
	"assault_boots": {
		"loot_type": "armor",
		"equipment_id": "assault_boots",
		"display_name": "강습 부츠",
		"base_value": 1050,
		"slot_size": 2,
		"rarity_tier": 4,
		"minimum_stage": 4,
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
	return (STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary).duplicate(true)


static func get_guaranteed_canned_food_pickup_count(stage_tier: int) -> int:
	# 판당 확정 통조림 픽업 수. 쉘터 연료 싱크가 사라지고(주민 식비 폐지) 통조림이
	# 먹기·투척 소모품만 남으면서 예전 21~29개는 가방에 쌓이기만 했다 — 약 60%
	# (12~17개)로 줄여 "한 판에 먹을 만큼 + 던질 여분" 선에 맞춘다.
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary
	return maxi(0, int(profile.get("guaranteed_canned_food_pickups", 0)))


static func roll_guaranteed_canned_food_amount(
	stage_tier: int,
	random: RandomNumberGenerator
) -> int:
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary
	var double_stack_chance := float(
		profile.get("canned_food_double_stack_chance", 0.0)
	)
	return 2 if random.randf() < double_stack_chance else 1


static func get_container_display_name(container_type: String) -> String:
	var definition := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	return str(definition.get("display_name", "보급품"))


static func build_container_plan(stage_tier: int, random: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary
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
	random: RandomNumberGenerator,
	unarmed_recovery: bool = false
) -> Array[Dictionary]:
	var stage := clampi(stage_tier, 1, 5)
	var container := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	if container.is_empty() or stage < int(container.get("minimum_stage", 1)):
		# 맨손이면 빈 컨테이너라도 기본 권총 하나는 나올 수 있게 해준다. 무기를
		# 다 잃어도 파밍으로 재무장하는 회복 루프가 사자 예비 권총을 대신한다.
		if unarmed_recovery and random.randf() < 0.5:
			return [_materialize_item("m1911", stage, random)]
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
			# 스마트 탄약: 상자에서 탄약이 나오면 장착 무기 구경으로 치환.
			# 전용 탄약상자는 85% — "탄약상자 = 내 총 보급소"가 직관이 되도록.
			# 일반 상자는 55% → 75%로 올렸다. 제작대의 탄약 레시피가 폐지되면서
			# 탄약 수급선이 필드 루팅과 상인 구매만 남았다. 상자에서 나온 탄이
			# 절반은 못 쓰는 구경이면 "주웠는데 못 쏜다"가 반복돼 압박만 커진다.
			var matched_chance := 0.85 if container_type == "ammo_case" else 0.75
			if item_id.begins_with("ammo_") and random.randf() < matched_chance:
				var matched_ammo_id := _equipped_ammo_item_id(stage)
				if not matched_ammo_id.is_empty():
					item_id = matched_ammo_id
			results.append(_materialize_item(item_id, stage, random))
	# 맨손 회복: 이번 컨테이너에서 무기가 하나도 안 나왔다면 절반 확률로 기본
	# 권총을 끼워 준다. 돌아다니며 상자만 몇 개 열어도 다시 무장하게 된다.
	if unarmed_recovery:
		var has_weapon := false
		for entry in results:
			if str(entry.get("type", "")) == "weapon":
				has_weapon = true
				break
		if not has_weapon and random.randf() < 0.5:
			results.append(_materialize_item("m1911", stage, random))
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
	var stage := clampi(stage_tier, 1, 5)
	# ── 장비 드랍 재설계(2026-08) ─────────────────────────────────
	# 예전: 무기 15~27% → 방어구 26~42% → 거기에 enemy_director의 "매 킬 장비
	# 보장 fallback"까지 얹혀 25킬 판에 방어구 ~20개가 떨어졌다(실측 21.7).
	# 슬롯은 몸·머리·발 3개뿐이라 거의 전부 잉여였고, 잉여 방어구는 상인 판매
	# 불가·분해 불가라 창고에 쌓이거나 버려졌다. 드랍은 "많이"가 아니라 "세트를
	# 맞출 만큼"이어야 한다 — 일반 적은 입고 있던 방어구 12% / 들고 있던 총 10%,
	# 나머지는 기존 탄약·식량·부품 분포(호환탄 회수 60%는 별도 판정, 불변).
	# 러버밴딩 없음: 확률은 존 티어만 참조하고 플레이어 상태는 보지 않는다.
	# 한 번의 굴림으로 가른다 — 방어구 12%가 무기 판정 뒤에 깎이지 않게.
	var equipment_roll := random.randf()
	var is_melee := enemy_kind == "melee" or enemy_weapon_id == "baseball_bat"
	# 맨손 회복: 무기를 다 잃었을 때만 재무장 루프를 위해 무기 비중을 58%로 크게 연다.
	var weapon_drop_chance := 0.58 if unarmed_recovery else ENEMY_CARRIED_WEAPON_DROP_CHANCE
	if equipment_roll < ENEMY_ARMOR_DROP_CHANCE:
		# 입고 있던 방어구 — 그 존 가족, 슬롯 균등. 근접 적도 몸에 두른 것을 떨군다.
		return _materialize_item(_roll_enemy_armor_id(stage, random), stage, random)
	# 근접 적은 무기 드랍에서 제외한다 — 야구방망이는 WeaponSystem.WEAPONS와
	# ITEM_CATALOG 어디에도 정의가 없어(플레이어 근접 무기 체계 자체가 없다)
	# 드랍시켜 봐야 장착·판매가 안 되는 유령 아이템이 된다.
	if not is_melee and equipment_roll < ENEMY_ARMOR_DROP_CHANCE + weapon_drop_chance:
		if _enemy_carried_weapon_allowed(enemy_weapon_id):
			return _materialize_item(enemy_weapon_id, stage, random)
	var ordinary_drop_chance := 0.62 + float(stage - 1) * 0.03
	if random.randf() > ordinary_drop_chance:
		return {}
	var roll := random.randf()
	if enemy_kind != "melee":
		if roll < 0.26:
			# 70%는 장착 무기 탄약으로 기울인다. 매칭 탄은 낱개(3~8발)가
			# 아니라 정상 스택으로 떨어져 "죽이면 계속 쏠 수 있다"가 성립.
			var matched_ammo_id := ""
			if random.randf() < 0.7:
				matched_ammo_id = _equipped_ammo_item_id(stage)
			if not matched_ammo_id.is_empty():
				return _materialize_item(matched_ammo_id, stage, random, false)
			var ammo_item_id := _enemy_ammo_item_id(enemy_weapon_id, stage, random)
			if not ammo_item_id.is_empty():
				return _materialize_item(ammo_item_id, stage, random, true)
		if roll < 0.56:
			return _materialize_item("canned_food", stage, random)
		if roll < 0.64:
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
	# 꼬리 8%는 예전엔 방어구 필러였다. 방어구는 위 12% 단일 판정에 전부 모았으니
	# 여기서 또 새어 나오면 "12%"가 거짓말이 된다 — 부품으로 돌린다.
	return _materialize_item(_roll_basic_component_id(stage, random), stage, random)


# 일반 적 장비 드랍률 — 존 티어와 무관한 상수(플레이어 상태 참조 금지).
# 목표 밴드: 25킬 일반 판 방어구 3~4개(엘리트·상자 포함), 같은 존 2회차 안에
# 그 존 세트 3종을 모을 확률 ≥70%. 어긋나면 이 값과 상자 가중치만 만진다(적 체력 X).
const ENEMY_ARMOR_DROP_CHANCE := 0.12
const ENEMY_CARRIED_WEAPON_DROP_CHANCE := 0.10
# 엘리트 추가 방어구(한 단계 위 가족) 확률. 보스는 확정.
const ELITE_TIER_UP_ARMOR_CHANCE := 0.30


static func _roll_tier_up_armor_id(stage: int, random: RandomNumberGenerator) -> String:
	# 한 단계 위 가족(존 가족+1, 상한 T3=군납) 슬롯 균등 — 엘리트·보스가 "다음
	# 존의 장비"를 미리 보여 주는 창. 최상위 존(가족 T3)에선 같은 가족이 나온다.
	var family_index := mini(armor_family_index_for_stage(stage) + 1, ARMOR_FAMILIES.size() - 1)
	var pool: Array = ARMOR_FAMILIES[family_index]
	return str(pool[random.randi_range(0, pool.size() - 1)])


static func roll_boss_armor_drop(stage_tier: int, random: RandomNumberGenerator) -> Dictionary:
	# 보스 확정 장비 1개 — 한 단계 위 가족 확정. 굴림이 아니라 확정.
	var stage := clampi(stage_tier, 1, 5)
	return _materialize_item(_roll_tier_up_armor_id(stage, random), stage, random)


static func _roll_enemy_armor_id(stage: int, random: RandomNumberGenerator) -> String:
	# 적이 두른 방어구는 그 도시의 계열을 따른다. 슬롯(몸·머리·발)은 고르게
	# 굴려서 어느 칸이든 갈아 끼울 기회가 돌아오게 한다.
	var pool: Array = armor_pool_for_stage(stage)
	var family_index := armor_family_index_for_stage(stage)
	if family_index > 0 and random.randf() < 0.25:
		pool = ARMOR_FAMILIES[family_index - 1]
	return str(pool[random.randi_range(0, pool.size() - 1)])


static func roll_guaranteed_equipment_drop(
	stage_tier: int,
	enemy_kind: String,
	enemy_weapon_id: String,
	random: RandomNumberGenerator
) -> Dictionary:
	# "장비 확정 1개" 굴림 — 무기 22% / 방어구 78%.
	# 2026-08 장비 드랍 재설계로 enemy_director의 "매 킬 보장 fallback"에서는
	# 뺐다(모든 킬 = 장비 1개가 25킬 판에 방어구 ~20개를 만든 진범). 일반 적은
	# roll_enemy_drop의 12%/10% 판정만 탄다. 이 함수는 "확정으로 장비 하나"가
	# 필요한 곳(테스트·이벤트 보상)을 위한 유틸로 남긴다 — 분포는 그대로다.
	# 근접 적(baseball_bat)은 방어구 확정 — 야구방망이는 WeaponSystem WEAPONS에도
	# ITEM_CATALOG에도 정의가 없어 주워도 장착할 수 없다.
	var stage := clampi(stage_tier, 1, 5)
	if (
		enemy_kind != "melee"
		and enemy_weapon_id != "baseball_bat"
		and random.randf() < 0.22
	):
		if _enemy_carried_weapon_allowed(enemy_weapon_id):
			return _materialize_item(enemy_weapon_id, stage, random)
	return _materialize_item(_roll_enemy_armor_id(stage, random), stage, random)


static func _enemy_carried_weapon_allowed(enemy_weapon_id: String) -> bool:
	# 적이 손에 들고 나를 쏘던 총은 존 등급과 무관하게 떨어져야 한다.
	# 예전엔 _item_allowed로 weapon_rarity_cap·minimum_stage를 걸었는데,
	# 적 무장 구성은 존 threat이 정하지 스테이지 캡이 정하지 않는다. 그래서
	# 1스테이지(rarity_cap 1)에서는 MP5·AK·산탄총을 든 적이 절반이 넘는데도
	# 그 총은 절대 안 나오고, 나오는 건 항상 M1911뿐이었다 — 실측 25킬에
	# 무기 픽업 5정이 전부 M1911. "적을 죽여도 무기가 안 나온다"는 신고의
	# 정체가 이것이다(수가 아니라 종류가 고정돼 있었다).
	# 러버밴딩이 아니다 — 플레이어 장비가 아니라 그 적의 무장을 그대로 따른다.
	# 컨테이너(weapon_case)의 rarity_cap은 그대로 둔다: 그쪽은 존이 정한다.
	return not _find_weapon_definition(enemy_weapon_id).is_empty()


static func roll_weapon_companion_ammo(
	weapon_id: String,
	stage_tier: int,
	random: RandomNumberGenerator
) -> Dictionary:
	# 총이 드랍되면 그 구경 탄약을 정상 스택으로 반드시 동반시킨다 — 주운 총을
	# 그 자리에서 장전해 써 볼 수 있어야 드랍이 의미가 있다(유저 요구).
	# 동반 탄약은 ammo_tier_cap을 타지 않는다: 1스테이지(cap 1)에서 AK가
	# 떨어지면 7.62(tier 2)가 막혀 "탄 없는 총"만 남았다.
	var ammo_item_id := _enemy_ammo_item_id(
		weapon_id, clampi(stage_tier, 1, 5), random, true
	)
	if ammo_item_id.is_empty():
		return {}
	return _materialize_item(ammo_item_id, clampi(stage_tier, 1, 5), random, false)


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
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary
	var value := get_definition_value(definition)
	var loot_type := str(definition.get("type", ""))
	if not ignore_caps:
		# 무기 캡은 출처별로 따로 센다. 예전엔 하나의 카운터를 공유해서,
		# 무기 상자 몇 개를 먼저 열면 그 판의 적 무기 드랍이 통째로 막혔다.
		if loot_type == "weapon":
			if source == "enemy":
				if (
					int(game_state.get("raid_enemy_weapon_drops_generated"))
					>= int(profile.get("enemy_weapon_spawn_cap", 4))
				):
					return false
			elif (
				int(game_state.get("raid_weapon_drops_generated"))
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
		if source == "enemy":
			game_state.set(
				"raid_enemy_weapon_drops_generated",
				int(game_state.get("raid_enemy_weapon_drops_generated")) + 1
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
	var profile := STAGE_PROFILES[clampi(stage_tier, 1, 5)] as Dictionary
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
				# 확정 통조림 픽업은 위 루프에서 따로 세고 가치 예산 밖에 둔다
				# (try_register_loot과 같은 규약) — 탄약·부품 스폰을 잠식하지 않는다.
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
	# k2는 의도적으로 뺀다 — 용산 통제 키 전용 제작 무기.
	for item_id_value in ["m1911", "mp5", "double_barrel", "ak47", "akm", "pump_shotgun"]:
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
	var stage := clampi(stage_tier, 1, 5)
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
	data["stage_tier"] = clampi(stage_tier, 1, 5)
	if loot_type == "armor":
		# 장비 레벨은 도시 티어를 따라 굴린다 — 상위 도시일수록 같은 장비도
		# 좋은 개체가 나와 갈아 끼우는 맛을 만든다. 가치도 레벨을 따라 오른다.
		var level := roll_equipment_level(random.randf())
		if level > 1:
			data["equipment_id"] = "%s@%d" % [str(data.get("equipment_id", item_id)), level]
			data["display_name"] = "%s Lv.%d" % [str(data.get("display_name", "장비")), level]
			data["base_value"] = int(round(
				float(data.get("base_value", 0)) * (1.0 + 0.35 * float(level - 1))
			))
	data["total_value"] = int(data.get("base_value", 0)) * amount
	data["value_per_slot"] = float(data["total_value"]) / float(maxi(1, int(data.get("slot_size", 1))))
	return {"type": loot_type, "data": data}


# ── 장비 계열과 레벨 ────────────────────────────────────────────
# 도시가 정하는 건 "어떤 계열의 장비가 나오는가"(생존자 → 진압 → 군납).
# 레벨(1~5)은 어느 도시에서든 같은 분포로 굴러간다 — 종로 전용 운동화도
# Lv5까지 존재하고, 봉쇄선의 군납품도 Lv1부터 나온다. 도시 진행 = 계열
# 상승, 파밍 반복 = 레벨 상승. 두 축이 곱해져 풀이 넓어진다.
const ARMOR_FAMILIES := [
	["scav_vest", "patched_helmet", "patched_sneakers"],   # 티어 1~2 · 생존자 계열
	["riot_vest", "tactical_helmet", "tactical_boots"],    # 티어 3 · 진압 계열
	["military_vest", "military_helmet", "assault_boots"], # 티어 4~5 · 군납 계열
]
const EQUIPMENT_LEVEL_WEIGHTS := [0.45, 0.27, 0.15, 0.09, 0.04]


static func armor_family_index_for_stage(stage_tier: int) -> int:
	if stage_tier >= 4:
		return 2
	if stage_tier >= 3:
		return 1
	return 0


static func armor_pool_for_stage(stage_tier: int) -> Array:
	return ARMOR_FAMILIES[armor_family_index_for_stage(stage_tier)]


static func roll_equipment_level(unit_roll: float) -> int:
	# 도시와 무관한 공통 분포: Lv1 45% · Lv2 27% · Lv3 15% · Lv4 9% · Lv5 4%.
	var threshold := clampf(unit_roll, 0.0, 0.999999)
	var accumulated := 0.0
	for level in range(1, 6):
		accumulated += EQUIPMENT_LEVEL_WEIGHTS[level - 1]
		if threshold < accumulated:
			return level
	return 5


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
	match clampi(stage_tier, 1, 5):
		1:
			return random.randi_range(4, 7)
		2:
			return random.randi_range(4, 8)
		3:
			return random.randi_range(5, 10)
		_:
			return random.randi_range(6, 12)


static func _equipped_ammo_item_id(stage: int) -> String:
	# 스마트 탄약: 판 안에서 재무장→쓸어버리기 파워커브가 살려면 "내 총에
	# 맞는 탄"이 나와야 한다. 장착 무기의 탄약을 조회해 드랍을 기울인다.
	# (난이도 러버밴딩이 아니라 편의 보정 — 적·위협은 그대로다.)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	var game_state := tree.root.get_node_or_null("GameState")
	if game_state == null or not bool(game_state.get("has_ak")):
		return ""
	var ammo_id := str(game_state.get("equipped_ammo_id"))
	if ammo_id.is_empty():
		return ""
	var item_id := "ammo_%s" % ammo_id
	# 장착 구경은 스테이지 게이트를 안 탄다 — 플레이어가 이미 그 총을 들고
	# 왔는데 그 도시에 그 탄이 "없어야 할" 이유가 없다. (762가 minimum_stage
	# 2라서 시작 무기 AK가 정작 종로에서 굶던 문제.)
	var definition := ITEM_CATALOG.get(item_id, {}) as Dictionary
	if definition.is_empty():
		return ""
	return item_id


static func roll_matched_ammo_recovery(
	stage_tier: int,
	random: RandomNumberGenerator
) -> Dictionary:
	# 호환탄 회수 — 사수 시체에서 내 총에 맞는 탄을 골라 줍는다.
	# 일반 드랍 테이블과 별개 판정: 테이블 안에서 확률을 키우면 방어구·식량
	# 비중이 무너지므로, 회수는 독립 드랍으로 얹는다.
	var stage := clampi(stage_tier, 1, 5)
	var item_id := _equipped_ammo_item_id(stage)
	if item_id.is_empty():
		return {}
	var definition := _materialize_item(item_id, stage, random)
	if definition.is_empty():
		return {}
	var data := definition.get("data", {}) as Dictionary
	# 회수량 상향: 기존 (4~7)+스테이지는 킬당 회수가 탄창 하나에도 못 미쳐
	# "쏠수록 가난해진다"는 체감이 남았다(유저 신고). 탄약 제작 레시피가
	# 폐지돼 필드 회수가 사실상 유일한 보급선이 된 것도 이유다.
	# 하한은 6으로 고정하고 상한만 스테이지를 따라 늘리되 3스테이지에서 멈춘다 —
	# 초반에도 한 킬이 탄창 값을 하고, 후반에는 다른 수급선(고티어 탄·무기 동반
	# 탄약)이 이미 두꺼워서 여기까지 계속 늘리면 탄약 압박 자체가 사라진다.
	# 실측 기준 킬당 장착 구경 회수 4.2~5.9발(목표 4~6발) 곡선.
	data["amount"] = random.randi_range(6, 10 + mini(stage, 3))
	return definition


static func _enemy_ammo_item_id(
	enemy_weapon_id: String,
	stage_tier: int,
	random: RandomNumberGenerator,
	ignore_tier_cap: bool = false
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
		"double_barrel", "pump_shotgun":
			ordinary_id = "ammo_12g_buckshot"
			high_tier_id = "ammo_12g_slug"
		"ak47", "akm", "k2":
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
	if ordinary_definition.is_empty():
		return ""
	if not ignore_tier_cap and not _item_allowed(ordinary_definition, stage_tier):
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


# ── 엘리트 확정 드랍 ────────────────────────────────────────────
# 엘리트를 굳이 골라 싸운 대가는 굴림이 아니라 확정이어야 한다.
# 기존 roll_* 함수의 시그니처는 건드리지 않는 별도 진입점.
# 고가치품 후보 — 스테이지 하한(minimum_stage)만 지키면 되는 값나가는 축.
const ELITE_PRIZE_VALUABLE_IDS := [
	"old_wristwatch",
	"circuit_board",
	"lithium_cell",
	"fiber_spool",
	"server_drive",
	"gold_tooth",
	"wedding_ring",
	"gold_chain",
	"military_freq",
]


static func roll_elite_drop(
	stage_tier: int,
	enemy_weapon_id: String,
	random: RandomNumberGenerator
) -> Array[Dictionary]:
	# 반환 순서: [무기, 동반 탄약(2배), 고가치품, (30%) 상위 가족 방어구]. 비는 항목은 건너뛴다.
	# ① 들고 있던 무기 — 희귀도 게이트 면제(_enemy_carried_weapon_allowed 경로:
	#    적의 무장을 그대로 따르므로 러버밴딩이 아니다). 이것이 "확정 장비 1개".
	# ② 그 구경 탄약 — roll_weapon_companion_ammo의 정상 스택을 2배로.
	# ③ 귀중품 70% / 개조 부품 30% 확정 1개.
	# ④ 30%로 한 단계 위 가족 방어구(존 가족+1, 상한 T3) — 일반 적 12%만으로는
	#    세트가 더디니 엘리트가 세트의 지름길이자 다음 존 미리보기가 된다.
	var stage := clampi(stage_tier, 1, 5)
	var results: Array[Dictionary] = []
	if _enemy_carried_weapon_allowed(enemy_weapon_id):
		var weapon_definition := _materialize_item(enemy_weapon_id, stage, random)
		if not weapon_definition.is_empty():
			results.append(weapon_definition)
	var ammo_definition := roll_weapon_companion_ammo(enemy_weapon_id, stage, random)
	if not ammo_definition.is_empty():
		var ammo_data := ammo_definition.get("data", {}) as Dictionary
		var doubled := maxi(1, int(ammo_data.get("amount", 6))) * 2
		ammo_data["amount"] = doubled
		ammo_data["total_value"] = int(ammo_data.get("base_value", 0)) * doubled
		ammo_data["value_per_slot"] = float(ammo_data["total_value"]) / float(
			maxi(1, int(ammo_data.get("slot_size", 1)))
		)
		results.append(ammo_definition)
	var prize := _roll_elite_prize(stage, random)
	if not prize.is_empty():
		results.append(prize)
	if random.randf() < ELITE_TIER_UP_ARMOR_CHANCE:
		var tier_up_armor := _materialize_item(_roll_tier_up_armor_id(stage, random), stage, random)
		if not tier_up_armor.is_empty():
			results.append(tier_up_armor)
	return results


# ── 장비 공급 시뮬레이션 ────────────────────────────────────────
# 존 티어 하나를 골라 "25킬 일반 판"을 여러 번 굴려 장비 픽업 수·세트 완성
# 확률을 잰다. enemy_director의 드랍 경로(일반 적 roll_enemy_drop · 엘리트
# roll_elite_drop · 옷 상자·봉인 보급함)를 수식 없이 그대로 굴린다 — 확률
# 상수를 만진 뒤 목표 밴드(판당 방어구 3~4 · 2판 세트 완성 ≥70%)를 이걸로 확인한다.
# 적 무장 구성은 존 threat가 정하므로 여기선 대표 혼합만 쓴다(수치가 아니라 추세용).
const SIMULATION_ENEMY_WEAPON_MIX := {
	1: [["m1911", 0.5], ["mp5", 0.3], ["ak47", 0.1], ["double_barrel", 0.1]],
	2: [["m1911", 0.35], ["mp5", 0.35], ["ak47", 0.2], ["double_barrel", 0.1]],
	3: [["m1911", 0.2], ["mp5", 0.35], ["ak47", 0.25], ["double_barrel", 0.1], ["akm", 0.05], ["pump_shotgun", 0.05]],
	4: [["mp5", 0.3], ["ak47", 0.3], ["akm", 0.2], ["double_barrel", 0.1], ["pump_shotgun", 0.1]],
	5: [["mp5", 0.25], ["ak47", 0.3], ["akm", 0.25], ["double_barrel", 0.05], ["pump_shotgun", 0.15]],
}


static func simulate_enemy_equipment_supply(
	stage_tier: int,
	kill_count: int = 25,
	run_count: int = 200,
	seed_value: int = 4242,
	include_boss: bool = false
) -> Dictionary:
	var stage := clampi(stage_tier, 1, 5)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var profile := STAGE_PROFILES[stage] as Dictionary
	var weapon_cap := int(profile.get("enemy_weapon_spawn_cap", 8))
	var counts := profile.get("container_counts", {}) as Dictionary
	var clothing_count := int(counts.get("clothing_cache", 0))
	var secure_count := int(counts.get("secure_cache", 0))
	var family_index := armor_family_index_for_stage(stage)
	var set_ids: Array = ARMOR_FAMILIES[family_index]
	var total_armor := 0
	var total_armor_enemy := 0
	var total_weapons := 0
	var total_elite_armor := 0
	var total_tier_up := 0
	var total_boss_tier_up := 0
	var set_done_one := 0
	var set_done_two := 0
	var owned_previous: Dictionary = {}
	var runs := maxi(2, run_count)
	for run_index in runs:
		var owned: Dictionary = {}
		var run_weapons := 0
		var run_armor := 0
		for _kill in maxi(1, kill_count):
			var melee := random.randf() < 0.25
			var weapon_id := "baseball_bat" if melee else _weighted_pick(
				SIMULATION_ENEMY_WEAPON_MIX[stage] as Array, random
			)
			var drop := roll_enemy_drop(stage, "melee" if melee else "pistol", weapon_id, random)
			match str(drop.get("type", "")):
				"weapon":
					if run_weapons < weapon_cap:
						run_weapons += 1
				"armor":
					run_armor += 1
					total_armor_enemy += 1
					owned[_simulation_base_id(drop)] = true
		# 엘리트: 존 티어 1~2 = 1명, 3+ = 2명(enemy_director.get_initial_elite_count).
		for _elite in (1 if stage <= 2 else 2):
			var elite_weapon := "mp5"
			var weapon_roll := random.randf()
			if weapon_roll >= 0.8:
				elite_weapon = "double_barrel"
			elif weapon_roll >= 0.45:
				elite_weapon = "ak47"
			if stage >= 3 and random.randf() < 0.5:
				elite_weapon = "akm" if elite_weapon == "ak47" else (
					"pump_shotgun" if elite_weapon == "double_barrel" else elite_weapon
				)
			for entry in roll_elite_drop(stage, elite_weapon, random):
				match str(entry.get("type", "")):
					"weapon":
						run_weapons += 1
					"armor":
						run_armor += 1
						total_elite_armor += 1
						owned[_simulation_base_id(entry)] = true
						if _simulation_family_of(_simulation_base_id(entry)) > family_index:
							total_tier_up += 1
		if include_boss:
			var boss_armor := roll_boss_armor_drop(stage, random)
			run_armor += 1
			owned[_simulation_base_id(boss_armor)] = true
			if _simulation_family_of(_simulation_base_id(boss_armor)) > family_index:
				total_boss_tier_up += 1
		for _container in clothing_count:
			for entry in roll_container("clothing_cache", stage, "street_mixed", random):
				if str(entry.get("type", "")) == "armor":
					run_armor += 1
					owned[_simulation_base_id(entry)] = true
		for _container in secure_count:
			for entry in roll_container("secure_cache", stage, "street_mixed", random):
				if str(entry.get("type", "")) == "armor":
					run_armor += 1
					owned[_simulation_base_id(entry)] = true
		total_armor += run_armor
		total_weapons += run_weapons
		if _simulation_set_complete(owned, set_ids):
			set_done_one += 1
		if run_index % 2 == 1:
			var merged := owned.duplicate()
			for key in owned_previous.keys():
				merged[key] = true
			if _simulation_set_complete(merged, set_ids):
				set_done_two += 1
		owned_previous = owned
	var divisor := float(runs)
	return {
		"armor_per_run": float(total_armor) / divisor,
		"armor_from_enemies_per_run": float(total_armor_enemy) / divisor,
		"weapons_per_run": float(total_weapons) / divisor,
		"set_complete_1run": float(set_done_one) / divisor,
		"set_complete_2runs": float(set_done_two) / float(runs / 2),
		"elite_armor_per_run": float(total_elite_armor) / divisor,
		"elite_tier_up_share": float(total_tier_up) / float(maxi(1, total_elite_armor)),
		"boss_tier_up_share": (float(total_boss_tier_up) / divisor) if include_boss else 0.0,
	}


static func _simulation_base_id(definition: Dictionary) -> String:
	return str((definition.get("data", {}) as Dictionary).get("equipment_id", "")).split("@")[0]


static func _simulation_family_of(base_id: String) -> int:
	for index in ARMOR_FAMILIES.size():
		if (ARMOR_FAMILIES[index] as Array).has(base_id):
			return index
	return -1


static func _simulation_set_complete(owned: Dictionary, set_ids: Array) -> bool:
	for id in set_ids:
		if not owned.has(str(id)):
			return false
	return true


static func _roll_elite_prize(stage: int, random: RandomNumberGenerator) -> Dictionary:
	if random.randf() < 0.3:
		return _materialize_item(_roll_basic_component_id(stage, random), stage, random)
	var eligible: Array[String] = []
	for item_id in ELITE_PRIZE_VALUABLE_IDS:
		var definition := ITEM_CATALOG.get(str(item_id), {}) as Dictionary
		if not definition.is_empty() and _item_allowed(definition, stage):
			eligible.append(str(item_id))
	if eligible.is_empty():
		# 어떤 스테이지에서도 비지 않지만, 카탈로그가 변해도 확정은 지킨다.
		return _materialize_item(_roll_basic_component_id(stage, random), stage, random)
	return _materialize_item(
		eligible[random.randi_range(0, eligible.size() - 1)],
		stage,
		random
	)
