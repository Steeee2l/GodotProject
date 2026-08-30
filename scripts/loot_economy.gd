class_name LootEconomy
extends RefCounted

# ── 캡 설계 메모 ────────────────────────────────────────────────
# 예전 enemy_value_cap(1스테이지 1200)은 킬 4~5번이면 소진됐다. 그 뒤 모든
# 적 드랍이 try_register_loot에서 조용히 거부되고, 처치 보장 fallback만
# ignore_caps로 새어 나왔다 — 즉 캡은 이미 '지켜지지 않는 캡'이었는데
# (실측: 25킬에 8,677 가치가 스폰) 정작 호환탄 회수·식량·부품 같은 정상
# 드랍만 골라 죽이고 있었다. 캡을 실제 판 규모(raid_kill_cap 40~100킬)에
# 맞춰 다시 세운다. 값을 올리는 게 아니라, 있는 그대로 정직하게 만드는 것.
#
# ── 대개편 1단계(2026-08, 경제 코어) ──────────────────────────────
# 장비(무기·방어구)는 필드 어디에서도 나오지 않는다 — 적 드랍·상자·엘리트·보스
# 전부. 장비는 오직 쉘터 작업대 제작(설계도 조각 3/3 + 고철 + 부품)으로만 생기고,
# 한 번 만들면 영구 귀속(사망에도 안 잃음), 관리는 +99 강화/돌파(장인의 인장).
# 그래서 weapon_spawn_cap·enemy_weapon_spawn_cap은 0(무효) — try_register_loot이
# 혹시 들어오는 weapon 정의를 전부 거절하는 안전장치로만 남는다.
# 필드 드랍은 부품·탄약·통조림·구급약·귀중품 + 새 품목 3종:
#   · 설계도 조각 blueprint_shard_<recipe>  (progression · 0칸 · 레시피당 3조각 해금)
#   · 희귀 부품 precision_gear(정밀 기어) / military_alloy(군용 합금)  (component · 1칸)
#   · 장인의 인장 artisan_seal  (progression · 0칸 · 돌파 재료)
# blueprint_shard_case_chance: 봉인 보급함·잠긴 장비 상자가 조각 1개를 남길 확률(40%).
# 러버밴딩 없음: 모든 확률은 존 티어 상수다. 조각의 '종류'만 "이미 완성한 레시피
# 제외(미완성 우선)"로 고른다 — 확률이 아니라 낭비를 줄이는 선택.
# ── 귀중품 존 가치 배율(대개편 3단계) ─────────────────────────────
# 귀중품 base_value는 존 1 기준이다. 상위 존의 같은 귀중품이 같은 값이면 출정 수입이 존을 따라
# 크지 않아(존1 869 → 존5 6.7K/판) 후반 강화(수억~수십억)에서 출정이 '이유'가 못 됐다.
# 존 티어마다 ×1/×2/×4/×10/×25 — 러버밴딩 아님, 전부 존 상수. _materialize_item이 base_value에
# 곱하고, 판 가치 캡(field/enemy/total_value_cap)도 같은 배율로 늘린다 — 캡은 존1 기준 숫자라
# 그대로 두면 ×25 귀중품 하나가 캡을 넘겨 등록이 거부된다(get_stage_value_cap).
const VALUABLE_STAGE_MULTIPLIER := {1: 1.0, 2: 2.0, 3: 4.0, 4: 10.0, 5: 25.0}

const STAGE_PROFILES := {
	1: {
		"name": "초반 생존 구역",
		"weapon_rarity_cap": 1,
		"ammo_tier_cap": 1,
		"field_value_cap": 3600,
		"enemy_value_cap": 12000,
		"total_value_cap": 16000,
		"weapon_spawn_cap": 0,
		"enemy_weapon_spawn_cap": 0,
		"enemy_drop_cap": 70,
		"raid_kill_cap": 40,
		"blueprint_shard_case_chance": 0.4,
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
		"weapon_spawn_cap": 0,
		"enemy_weapon_spawn_cap": 0,
		"enemy_drop_cap": 95,
		"raid_kill_cap": 55,
		"blueprint_shard_case_chance": 0.4,
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
		"weapon_spawn_cap": 0,
		"enemy_weapon_spawn_cap": 0,
		"enemy_drop_cap": 125,
		"raid_kill_cap": 70,
		"blueprint_shard_case_chance": 0.4,
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
		"weapon_spawn_cap": 0,
		"enemy_weapon_spawn_cap": 0,
		"enemy_drop_cap": 150,
		"raid_kill_cap": 85,
		"blueprint_shard_case_chance": 0.4,
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
		"weapon_spawn_cap": 0,
		"enemy_weapon_spawn_cap": 0,
		"enemy_drop_cap": 175,
		"raid_kill_cap": 100,
		"blueprint_shard_case_chance": 0.4,
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
	# 장비 제작 전용화(2026-08): 옷 더미에서 방어구가 나오지 않는다. 사람이 버리고
	# 간 옷가지 = 통조림·구급약·소지품(귀중품)·부품으로 채운다.
	"clothing_cache": {
		"display_name": "버려진 의류 더미",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.24,
		"entries": [
			["canned_food", 34.0],
			["medkit", 16.0],
			["rubber_gasket", 14.0],
			["magazine_spring", 10.0],
			["bell_collar", 8.0],
			["faded_photo", 8.0],
			["old_wristwatch", 6.0],
			["silver_spoon", 4.0],
		],
	},
	# 잠긴 장비 상자 — 총이 아니라 총을 만들 재료가 든 상자. 40%로 설계도 조각 1개
	# (roll_container의 봉인 상자 공통 판정), 나머지는 부품·탄약.
	"weapon_case": {
		"display_name": "잠긴 장비 상자",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.22,
		"entries": [
			["magazine_spring", 34.0],
			["scope_lens", 22.0],
			["rubber_gasket", 12.0],
			["ammo_9mm_fmj", 12.0],
			["ammo_45_fmj", 10.0],
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
	# 봉인 보급함(존3+) = '금고'. 40%로 설계도 조각 1개(공통 판정) + 희귀 부품:
	# 정밀 기어는 존3부터, 군용 합금은 존4~5(minimum_stage 4)부터 굴림에 든다.
	# 방어구·청사진(레거시)은 뺐다 — 장비는 작업대에서만.
	"secure_cache": {
		"display_name": "봉인 보급함",
		"roll_min": 1,
		"roll_max": 2,
		"empty_chance": 0.32,
		"minimum_stage": 3,
		"entries": [
			["scope_lens", 16.0],
			["magazine_spring", 14.0],
			["ammo_9mm_ap", 12.0],
			["ammo_45_ap", 12.0],
			["ammo_12g_slug", 12.0],
			["ammo_762_ap", 9.0],
			["precision_gear", 14.0],
			["military_alloy", 8.0],
			["sealed_zone_keycard", 1.4],
			["churu", 8.0],
		],
	},
}

# 봉인 상자 공통 판정이 붙는 컨테이너 — blueprint_shard_case_chance(40%)로 조각 1개.
const BLUEPRINT_SHARD_CONTAINERS := ["secure_cache", "weapon_case"]

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
	# ── 레거시 청사진(통짜) ──
	# 2026-08 경제 코어 개편으로 드랍·보상 경로에서 전부 빠졌다. 구세이브가 들고
	# 있으면 로드 시 해당 레시피의 설계도 조각 3개로 환산한다(GameState 마이그레이션).
	# 카탈로그에 남겨 두는 이유는 환산 전 표시(이름·가치)뿐이다.
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
	# ── 설계도 조각 ──────────────────────────────────────────────
	# 무기·방어구 레시피마다 3조각이 모이면 작업대 제작이 열린다(소모되지 않는 해금
	# 토큰). progression 타입 = 가방 칸 0, 스택. 출처: 그 존 가족의 엘리트 확정 1,
	# 보스 2, 봉인 보급함·잠긴 장비 상자 40%, 일반 적 소량, 메인 미션 2·3단계 보상.
	# 존별 해금 대상은 BLUEPRINT_SHARD_ZONE_TABLE. minimum_stage는 그 존의 stage_tier.
	"blueprint_shard_m1911": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_m1911", "display_name": "설계도 조각 · M1911", "base_value": 420, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_mp5": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_mp5", "display_name": "설계도 조각 · MP5", "base_value": 520, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_ak47": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_ak47", "display_name": "설계도 조각 · AK-47", "base_value": 520, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_scav_vest": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_scav_vest", "display_name": "설계도 조각 · 누더기 방탄 조끼", "base_value": 380, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_patched_helmet": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_patched_helmet", "display_name": "설계도 조각 · 기워 붙인 헬멧", "base_value": 360, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_patched_sneakers": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_patched_sneakers", "display_name": "설계도 조각 · 기워 붙인 운동화", "base_value": 340, "slot_size": 1, "rarity_tier": 2, "minimum_stage": 1},
	"blueprint_shard_double_barrel": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_double_barrel", "display_name": "설계도 조각 · 더블배럴", "base_value": 720, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2},
	"blueprint_shard_pump_shotgun": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_pump_shotgun", "display_name": "설계도 조각 · 펌프 산탄총", "base_value": 860, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2},
	"blueprint_shard_riot_vest": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_riot_vest", "display_name": "설계도 조각 · 진압대 방탄 조끼", "base_value": 700, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2},
	"blueprint_shard_tactical_boots": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_tactical_boots", "display_name": "설계도 조각 · 경량 전술화", "base_value": 620, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 2},
	"blueprint_shard_akm": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_akm", "display_name": "설계도 조각 · AKM", "base_value": 1200, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 3},
	"blueprint_shard_tactical_helmet": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_tactical_helmet", "display_name": "설계도 조각 · 전술 방탄 헬멧", "base_value": 900, "slot_size": 1, "rarity_tier": 3, "minimum_stage": 3},
	"blueprint_shard_military_vest": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_military_vest", "display_name": "설계도 조각 · 군납 방탄복", "base_value": 1600, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 4},
	"blueprint_shard_military_helmet": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_military_helmet", "display_name": "설계도 조각 · 군납 전투 헬멧", "base_value": 1400, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 4},
	"blueprint_shard_assault_boots": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_assault_boots", "display_name": "설계도 조각 · 강습 부츠", "base_value": 1300, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 4},
	"blueprint_shard_k2": {"loot_type": "progression_item", "progression_item_id": "blueprint_shard_k2", "display_name": "설계도 조각 · K2", "base_value": 2400, "slot_size": 1, "rarity_tier": 4, "minimum_stage": 5},
	# ── 희귀 부품 2종 ────────────────────────────────────────────
	# +31부터의 강화와 돌파에 든다. component 타입 = 1칸/개, 창고 입고·작업대 합산.
	"precision_gear": {
		"loot_type": "mod_component",
		"component_id": "precision_gear",
		"display_name": "정밀 기어",
		"base_value": 640,
		"slot_size": 1,
		"rarity_tier": 3,
		"minimum_stage": 1,
	},
	"military_alloy": {
		"loot_type": "mod_component",
		"component_id": "military_alloy",
		"display_name": "군용 합금",
		"base_value": 1400,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 4,
	},
	# ── 장인의 인장 ──────────────────────────────────────────────
	# 돌파(+10·+20·…·+90 → 다음 단계) 1회당 1개. 보스 확정 1, 메인 미션 3단계, 엘리트 5%.
	"artisan_seal": {
		"loot_type": "progression_item",
		"progression_item_id": "artisan_seal",
		"display_name": "장인의 인장",
		"base_value": 3000,
		"slot_size": 1,
		"rarity_tier": 4,
		"minimum_stage": 1,
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
	# progression 타입 — 쉘터 자산이라 버릴 수 없다(가방은 무제한).
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
	# ── 무기·방어구 카탈로그 ─────────────────────────────────────
	# 2026-08 경제 코어: 어떤 드랍 테이블에도 들어가지 않는다(작업대 제작 전용).
	# 엔트리를 남기는 이유는 이름·가치 조회(시체 가치·창고 표시·정산)뿐이다.
	# slot_size는 가방과 무관한 잔존 데이터다(가방 무제한 — 칸 개념 없음).
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
	# akm·pump_shotgun·k2 전부 작업대 제작 전용(설계도 조각 3/3). 적은 여전히 이
	# 총을 들고 쏘지만 떨어뜨리지는 않는다. weight는 옛 상자 가중치의 흔적(미사용).
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
	# 고급 주거지는 장비가 아니라 값나가는 소지품이 남는다(장비 드랍 폐지).
	"luxury_core": {
		"old_wristwatch": 1.6,
		"silver_spoon": 1.4,
		"wedding_ring": 1.3,
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
	# 투척 유인 + 훈련 재화만 남으면서 예전 21~29개는 가방에 쌓이기만 했다 — 약 60%
	# (12~17개)로 줄였다. 지금은 이 수치가 훈련 진행 속도의 눈금이기도 하다
	# (TRAINING_NODE_DEFS 주석: 판당 15~25개 ≈ 초반 노드 1랭크).
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
	_unarmed_recovery: bool = false
) -> Array[Dictionary]:
	# _unarmed_recovery: 예전 "맨손 회복용 M1911 끼워 주기"의 흔적. 장비는 영구
	# 귀속이라 맨손이 될 일이 없고, 필드에서 무기가 나오면 안 되므로 무시한다.
	# 호출 시그니처만 유지(main·건물 내부·테스트가 넘긴다).
	var stage := clampi(stage_tier, 1, 5)
	var container := CONTAINER_DEFINITIONS.get(container_type, {}) as Dictionary
	if container.is_empty() or stage < int(container.get("minimum_stage", 1)):
		return []
	var profile := STAGE_PROFILES[stage] as Dictionary
	var results: Array[Dictionary] = []
	var roll_count := random.randi_range(
		int(container.get("roll_min", 1)),
		int(container.get("roll_max", 1))
	)
	# 봉인 상자(봉인 보급함·잠긴 장비 상자)는 40%로 설계도 조각 1개를 먼저 남긴다.
	# 조각은 일반 굴림 수를 깎지 않는다 — "상자를 열었는데 조각 하나뿐"을 피한다.
	if BLUEPRINT_SHARD_CONTAINERS.has(container_type):
		if random.randf() < float(profile.get("blueprint_shard_case_chance", 0.0)):
			var shard := materialize_blueprint_shard(stage, random)
			if not shard.is_empty():
				results.append(shard)
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
			var matched_chance := 0.92 if container_type == "ammo_case" else 0.85
			if item_id.begins_with("ammo_") and random.randf() < matched_chance:
				var matched_ammo_id := _equipped_ammo_item_id(stage)
				if not matched_ammo_id.is_empty():
					item_id = matched_ammo_id
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
	_unarmed_recovery: bool = false
) -> Dictionary:
	# ── 장비 제작 전용화(2026-08) ───────────────────────────────
	# 예전: 입고 있던 방어구 12% / 든 총 10% / 나머지 탄약·식량·부품. 이제 장비는
	# 필드에서 절대 안 나온다(작업대 제작 전용·영구 귀속). 그 22%는 빈 드랍이
	# 아니라 부품·탄약·설계도 조각으로 메운다 — 판당 드랍 총량(any ≈ 0.70)은 유지.
	#   · 설계도 조각 6%(그 존 가족, 미완성 우선)  ← "적 드랍은 부품·통조림·설계도·귀중품"
	#   · 그 외 ordinary 64%(+3%p/스테이지): 탄약 26 / 통조림 30 / 구급약 8 / 부품 36
	# 러버밴딩 없음: 확률은 존 티어 상수, 플레이어 상태는 조각 '종류'(완성분 제외)와
	# 스마트 탄약(장착 구경 치환)에만 쓴다 — 둘 다 난이도가 아니라 낭비를 줄이는 보정.
	# _unarmed_recovery는 옛 "무기 58%" 회복 루프의 흔적 — 장비가 영구 귀속이라 무시.
	var stage := clampi(stage_tier, 1, 5)
	var is_melee := enemy_kind == "melee" or enemy_weapon_id == "baseball_bat"
	if random.randf() < ENEMY_BLUEPRINT_SHARD_CHANCE:
		var shard := materialize_blueprint_shard(stage, random)
		if not shard.is_empty():
			return shard
	var ordinary_drop_chance := 0.64 + float(stage - 1) * 0.03
	if random.randf() > ordinary_drop_chance:
		return {}
	var roll := random.randf()
	if not is_melee:
		if roll < 0.26:
			# 90%는 장착 무기 탄약으로 기울인다(70→90, "어지간하면 내 탄" 유저 요청).
			# 매칭 탄은 낱개가 아니라 정상 스택으로 떨어져 "죽이면 계속 쏠 수 있다"가 성립.
			var matched_ammo_id := ""
			if random.randf() < 0.9:
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
		return _materialize_item(_roll_basic_component_id(stage, random), stage, random)
	# 근접 적: 탄약이 없으니 식량·구급약·부품만.
	if roll < 0.45:
		return _materialize_item("canned_food", stage, random)
	if roll < 0.55:
		return _materialize_item("medkit", stage, random)
	return _materialize_item(_roll_basic_component_id(stage, random), stage, random)


# ── 드랍률 상수 — 존 티어와 무관, 플레이어 상태 참조 금지(러버밴딩 방지) ──
# 일반 적 설계도 조각 6%: 40킬 판이면 조각 ~2.4개. 엘리트 1(존1~2)·2(존3+) 확정과
# 봉인 상자 40%를 합쳐 존1 T1 세트(9조각)+M1911·MP5(6조각)가 4~5판에 모이는 선.
const ENEMY_BLUEPRINT_SHARD_CHANCE := 0.06
# 엘리트 보너스 — 정밀 기어 50%, 장인의 인장 5%. 보스는 인장 확정.
const ELITE_PRECISION_GEAR_CHANCE := 0.50
const ELITE_ARTISAN_SEAL_CHANCE := 0.05
# 보스 확정: 설계도 조각 2 + 군용 합금 1~2 + 장인의 인장 1.
const BOSS_BLUEPRINT_SHARDS := 2
const BOSS_ARTISAN_SEALS := 1

# ── 존별 설계도 조각 풀 ─────────────────────────────────────────
# 그 존의 엘리트·보스·봉인 상자·일반 적이 떨구는 조각은 이 표의 레시피에서 고른다.
# 존1 T1 방어구 3종 + M1911 + MP5(+AK-47: 시작 보유라 평소엔 완성 취급으로 제외),
# 존2 펌프·더블배럴 + T2 일부(진압 조끼·경량 전술화), 존3 AKM + T2 나머지(전술 헬멧),
# 존4 T3 3종, 존5 K2. 레시피 id = 무기 id / 방어구 기본 id(레벨 접미사 없음).
const BLUEPRINT_SHARD_ZONE_TABLE := {
	1: ["scav_vest", "patched_helmet", "patched_sneakers", "m1911", "mp5", "ak47"],
	2: ["pump_shotgun", "double_barrel", "riot_vest", "tactical_boots"],
	3: ["akm", "tactical_helmet"],
	4: ["military_vest", "military_helmet", "assault_boots"],
	5: ["k2"],
}
const BLUEPRINT_SHARD_PREFIX := "blueprint_shard_"


static func blueprint_shard_item_id(recipe_id: String) -> String:
	return "%s%s" % [BLUEPRINT_SHARD_PREFIX, recipe_id]


static func get_gear_stage_for_zone(zone_data: Dictionary) -> int:
	# 조각·희귀 부품 풀 전용 1~5 존 단계. get_stage_for_zone은 옛 컨테이너 표 호환
	# 때문에 4에서 멈춘다 — 남산(존5)의 K2 조각이 거기 묶이면 안 된다.
	return clampi(int(zone_data.get("stage_tier", zone_data.get("required_tier", 1))), 1, 5)


static func roll_blueprint_shard_recipe(stage_tier: int, random: RandomNumberGenerator) -> String:
	# 그 존 풀에서 "아직 완성하지 않은" 레시피(조각 3/3 미만이고 장비도 미보유) 우선.
	# 그 존이 전부 완성이면 아래 존의 미완성 → 그마저 없으면 "".
	# 플레이어 상태는 제외 판정에만 쓴다(러버밴딩 아님 — 확률·수량은 불변).
	var stage := clampi(stage_tier, 1, 5)
	for probe_stage in range(stage, 0, -1):
		var pool: Array = BLUEPRINT_SHARD_ZONE_TABLE.get(probe_stage, [])
		var open_recipes: Array[String] = []
		for recipe_value in pool:
			var recipe_id := str(recipe_value)
			if not _is_blueprint_recipe_complete(recipe_id):
				open_recipes.append(recipe_id)
		if not open_recipes.is_empty():
			return open_recipes[random.randi_range(0, open_recipes.size() - 1)]
	return ""


static func materialize_blueprint_shard(
	stage_tier: int,
	random: RandomNumberGenerator,
	amount: int = 1
) -> Dictionary:
	# 조각 1개(또는 amount개) 정의. 고를 레시피가 없으면(전부 완성) 정밀 기어로 대체 —
	# "확정"은 빈손이 아니어야 한다.
	var recipe_id := roll_blueprint_shard_recipe(stage_tier, random)
	if recipe_id.is_empty():
		return _materialize_item("precision_gear", stage_tier, random)
	var definition := _materialize_item(blueprint_shard_item_id(recipe_id), stage_tier, random)
	if definition.is_empty():
		return {}
	var data := definition.get("data", {}) as Dictionary
	data["amount"] = maxi(1, amount)
	data["recipe_id"] = recipe_id
	data["total_value"] = int(data.get("base_value", 0)) * int(data["amount"])
	return definition


static func _is_blueprint_recipe_complete(recipe_id: String) -> bool:
	# GameState가 있으면 "조각 3/3 또는 장비 보유"를 물어본다. 없으면(순수 시뮬) 미완성.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var game_state := tree.root.get_node_or_null("GameState")
	if game_state == null or not game_state.has_method("is_blueprint_recipe_complete"):
		return false
	return bool(game_state.call("is_blueprint_recipe_complete", recipe_id))


static func roll_boss_drops(stage_tier: int, random: RandomNumberGenerator) -> Array[Dictionary]:
	# 보스 확정 3종 — [설계도 조각 2, 군용 합금 1~2, 장인의 인장 1]. 굴림이 아니라 확정.
	# (츄르·부품·장착 구경 탄약 번들은 enemy_director가 종전대로 따로 얹는다.)
	var stage := clampi(stage_tier, 1, 5)
	var results: Array[Dictionary] = []
	var shards := materialize_blueprint_shard(stage, random, BOSS_BLUEPRINT_SHARDS)
	if not shards.is_empty():
		results.append(shards)
	var alloy := _materialize_item("military_alloy", stage, random)
	if not alloy.is_empty():
		var alloy_data := alloy.get("data", {}) as Dictionary
		alloy_data["amount"] = random.randi_range(1, 2)
		alloy_data["total_value"] = int(alloy_data.get("base_value", 0)) * int(alloy_data["amount"])
		results.append(alloy)
	var seal := _materialize_item("artisan_seal", stage, random)
	if not seal.is_empty():
		var seal_data := seal.get("data", {}) as Dictionary
		seal_data["amount"] = BOSS_ARTISAN_SEALS
		results.append(seal)
	return results


static func get_valuable_stage_multiplier(stage_tier: int) -> float:
	return float(VALUABLE_STAGE_MULTIPLIER.get(clampi(stage_tier, 1, 5), 1.0))


static func get_stage_value_cap(stage_tier: int, cap_key: String) -> int:
	# 판 가치 캡(field_value_cap / enemy_value_cap / total_value_cap) — 프로필 값 × 귀중품 존 배율.
	var profile: Dictionary = STAGE_PROFILES.get(clampi(stage_tier, 1, 5), STAGE_PROFILES[1])
	return int(round(float(profile.get(cap_key, 0)) * get_valuable_stage_multiplier(stage_tier)))


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
	# 장비 제작 전용화(2026-08): 무기·방어구 정의는 출처를 불문하고 필드에 스폰되지
	# 않는다. 드랍 테이블에서 이미 뺐지만, 어딘가 남은 옛 호출이 장비를 밀어 넣어도
	# 여기서 막힌다(ignore_caps여도 — 이건 캡이 아니라 규칙이다).
	if loot_type in ["weapon", "armor"]:
		return false
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
		var source_cap := get_stage_value_cap(stage_tier, "field_value_cap")
		if source == "enemy":
			source_value = int(game_state.get("raid_enemy_loot_value_generated"))
			source_cap = get_stage_value_cap(stage_tier, "enemy_value_cap")
		if source_value + value > source_cap:
			return false
		if (
			int(game_state.get("raid_total_loot_value_generated")) + value
			> get_stage_value_cap(stage_tier, "total_value_cap")
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
	var total_shards := 0
	var total_rare_components := 0
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
				if run_value + value > get_stage_value_cap(stage_tier, "field_value_cap"):
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
						var component_id := str(data.get("component_id", ""))
						if component_id in ["precision_gear", "military_alloy"]:
							total_rare_components += amount
						else:
							total_components += amount
							run_common_supply += amount
					"progression_item":
						if str(data.get("item_id", "")).begins_with(BLUEPRINT_SHARD_PREFIX):
							total_shards += int(data.get("amount", 1))
		if run_common_supply >= 12:
			runs_with_common_supply += 1
		total_value += run_value + guaranteed_supply_value
	var divisor := float(maxi(1, run_count))
	return {
		"average_weapons": float(total_weapons) / divisor,
		"average_blueprint_shards": float(total_shards) / divisor,
		"average_rare_components": float(total_rare_components) / divisor,
		"average_ammo": float(total_ammo) / divisor,
		"average_value": float(total_value) / divisor,
		"average_high_tier_ammo": float(total_high_tier_ammo) / divisor,
		"average_canned_food": float(total_canned_food) / divisor,
		"average_components": float(total_components) / divisor,
		"average_common_supply": float(total_canned_food + total_components) / divisor,
		"common_supply_success_rate": float(runs_with_common_supply) / divisor,
	}


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
	if loot_type == "valuable":
		# 귀중품 존 가치 — 존 배율(VALUABLE_STAGE_MULTIPLIER)을 base_value에 곱한다.
		data["base_value"] = int(round(float(data.get("base_value", 0)) * get_valuable_stage_multiplier(stage_tier)))
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
	# 2026-08-30 전면 상향(~2.2배) — 탄약이 짜서 교전 자체가 손해라는 체감(유저).
	# 국소 교전 개편과 세트: 싸움은 판당 몇 번, 대신 한 번 싸우면 확실히 남는다.
	if enemy_stack:
		return random.randi_range(8, 16)
	if ammo_tier >= 3:
		return random.randi_range(4, 9) if stage_tier == 3 else random.randi_range(5, 11)
	match clampi(stage_tier, 1, 5):
		1:
			return random.randi_range(10, 16)
		2:
			return random.randi_range(11, 18)
		3:
			return random.randi_range(13, 22)
		_:
			return random.randi_range(15, 26)


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
	# 회수량 2차 상향(2026-08-30): 국소 교전 개편으로 판당 교전 횟수가 줄었으니
	# 한 번의 교전이 확실히 남아야 한다. 하한 12발(반 탄창), 상한은 스테이지를
	# 따라 20~26발 — 사수 하나를 정리하면 최소한 쏜 만큼은 돌아온다.
	data["amount"] = random.randi_range(12, 20 + 2 * mini(stage, 3))
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
	# 반환 순서: [설계도 조각 1(확정), 탄약 2배 스택, 고가치품, (50%) 정밀 기어, (5%) 장인의 인장].
	# 비는 항목은 건너뛴다. 장비(무기·방어구)는 없다 — 제작 전용.
	# ① 그 존 가족 설계도 조각 1 — "확정 장비"의 자리를 대신한다. 전부 완성이면 정밀 기어.
	# ② 엘리트가 들던 총 구경 탄약 2배 스택(장착 구경 매칭 우선 — 스마트 탄약 규약).
	# ③ 귀중품 70% / 개조 부품 30% 확정 1개.
	# ④ 50% 정밀 기어 1 — +31 이후 강화와 돌파의 핵심 재료.
	# ⑤ 5% 장인의 인장.
	var stage := clampi(stage_tier, 1, 5)
	var results: Array[Dictionary] = []
	var shard := materialize_blueprint_shard(stage, random)
	if not shard.is_empty():
		results.append(shard)
	var ammo_definition := _roll_elite_ammo(enemy_weapon_id, stage, random)
	if not ammo_definition.is_empty():
		results.append(ammo_definition)
	var prize := _roll_elite_prize(stage, random)
	if not prize.is_empty():
		results.append(prize)
	if random.randf() < ELITE_PRECISION_GEAR_CHANCE:
		var gear := _materialize_item("precision_gear", stage, random)
		if not gear.is_empty():
			results.append(gear)
	if random.randf() < ELITE_ARTISAN_SEAL_CHANCE:
		var seal := _materialize_item("artisan_seal", stage, random)
		if not seal.is_empty():
			results.append(seal)
	return results


static func _roll_elite_ammo(
	enemy_weapon_id: String,
	stage: int,
	random: RandomNumberGenerator
) -> Dictionary:
	# 장착 구경이 있으면 그 탄(회수 규약), 없으면 엘리트가 들던 총의 구경. 정상 스택 2배.
	var ammo_item_id := _equipped_ammo_item_id(stage)
	if ammo_item_id.is_empty():
		ammo_item_id = _enemy_ammo_item_id(enemy_weapon_id, stage, random, true)
	if ammo_item_id.is_empty():
		return {}
	var definition := _materialize_item(ammo_item_id, stage, random, false)
	if definition.is_empty():
		return {}
	var data := definition.get("data", {}) as Dictionary
	var doubled := maxi(1, int(data.get("amount", 6))) * 2
	data["amount"] = doubled
	data["total_value"] = int(data.get("base_value", 0)) * doubled
	data["value_per_slot"] = float(data["total_value"]) / float(maxi(1, int(data.get("slot_size", 1))))
	return definition


# ── 장비 재료 공급 시뮬레이션 ────────────────────────────────────
# 존 티어 하나를 골라 "N킬 일반 판"을 여러 번 굴려 무기·방어구 드랍이 0인지, 설계도
# 조각·희귀 부품·인장이 판당 얼마나 나오는지 잰다. enemy_director의 드랍 경로(일반 적
# roll_enemy_drop · 엘리트 roll_elite_drop · 보스 roll_boss_drops · 봉인 상자)를 그대로
# 굴린다 — 확률 상수를 만진 뒤 목표 밴드를 이걸로 확인한다.
# 적 무장 구성은 존 threat가 정하므로 여기선 대표 혼합만 쓴다(수치가 아니라 추세용).
const SIMULATION_ENEMY_WEAPON_MIX := {
	1: [["m1911", 0.5], ["mp5", 0.3], ["ak47", 0.1], ["double_barrel", 0.1]],
	2: [["m1911", 0.35], ["mp5", 0.35], ["ak47", 0.2], ["double_barrel", 0.1]],
	3: [["m1911", 0.2], ["mp5", 0.35], ["ak47", 0.25], ["double_barrel", 0.1], ["akm", 0.05], ["pump_shotgun", 0.05]],
	4: [["mp5", 0.3], ["ak47", 0.3], ["akm", 0.2], ["double_barrel", 0.1], ["pump_shotgun", 0.1]],
	5: [["mp5", 0.25], ["ak47", 0.3], ["akm", 0.25], ["double_barrel", 0.05], ["pump_shotgun", 0.15]],
}


static func simulate_gear_supply(
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
	var counts := profile.get("container_counts", {}) as Dictionary
	var case_count := int(counts.get("weapon_case", 0)) + int(counts.get("secure_cache", 0))
	var totals := {"weapon": 0, "armor": 0, "shard": 0, "precision": 0, "alloy": 0, "seal": 0}
	var total_shards_enemy := 0
	var total_empty := 0
	var runs := maxi(1, run_count)
	for _run_index in runs:
		for _kill in maxi(1, kill_count):
			var melee := random.randf() < 0.25
			var weapon_id := "baseball_bat" if melee else _weighted_pick(
				SIMULATION_ENEMY_WEAPON_MIX[stage] as Array, random
			)
			var drop := roll_enemy_drop(stage, "melee" if melee else "pistol", weapon_id, random)
			if drop.is_empty():
				total_empty += 1
				continue
			var tally := _classify_gear_drop(drop)
			_merge_gear_tally(totals, tally)
			total_shards_enemy += int(tally.get("shard", 0))
		# 엘리트: 존 티어 1~2 = 1명, 3+ = 2명(enemy_director.get_initial_elite_count).
		for _elite in (1 if stage <= 2 else 2):
			var elite_weapon := "mp5"
			var weapon_roll := random.randf()
			if weapon_roll >= 0.8:
				elite_weapon = "double_barrel"
			elif weapon_roll >= 0.45:
				elite_weapon = "ak47"
			for entry in roll_elite_drop(stage, elite_weapon, random):
				_merge_gear_tally(totals, _classify_gear_drop(entry))
		if include_boss:
			for entry in roll_boss_drops(stage, random):
				_merge_gear_tally(totals, _classify_gear_drop(entry))
		for _case in case_count:
			var container_type := "secure_cache" if stage >= 3 and random.randf() < 0.5 else "weapon_case"
			for entry in roll_container(container_type, stage, "street_mixed", random):
				_merge_gear_tally(totals, _classify_gear_drop(entry))
	var divisor := float(runs)
	return {
		"weapons_per_run": float(totals["weapon"]) / divisor,
		"armor_per_run": float(totals["armor"]) / divisor,
		"shards_per_run": float(totals["shard"]) / divisor,
		"shards_from_enemies_per_run": float(total_shards_enemy) / divisor,
		"precision_gear_per_run": float(totals["precision"]) / divisor,
		"military_alloy_per_run": float(totals["alloy"]) / divisor,
		"artisan_seals_per_run": float(totals["seal"]) / divisor,
		"empty_kill_rate": float(total_empty) / float(runs * maxi(1, kill_count)),
	}


static func _merge_gear_tally(totals: Dictionary, tally: Dictionary) -> void:
	for key in tally.keys():
		totals[key] = int(totals.get(key, 0)) + int(tally[key])


static func _classify_gear_drop(definition: Dictionary) -> Dictionary:
	# 드랍 정의 하나를 {weapon, armor, shard, precision, alloy, seal} 카운트로 분류.
	var result := {"weapon": 0, "armor": 0, "shard": 0, "precision": 0, "alloy": 0, "seal": 0}
	if definition.is_empty():
		return result
	var data := definition.get("data", {}) as Dictionary
	var amount := maxi(1, int(data.get("amount", 1)))
	match str(definition.get("type", "")):
		"weapon":
			result["weapon"] = amount
		"armor":
			result["armor"] = amount
		"progression_item":
			var item_id := str(data.get("item_id", data.get("progression_item_id", "")))
			if item_id.begins_with(BLUEPRINT_SHARD_PREFIX):
				result["shard"] = amount
			elif item_id == "artisan_seal":
				result["seal"] = amount
		"mod_component":
			var component_id := str(data.get("component_id", ""))
			if component_id == "precision_gear":
				result["precision"] = amount
			elif component_id == "military_alloy":
				result["alloy"] = amount
	return result


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
