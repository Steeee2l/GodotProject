extends Node

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const RAID_REGION_CATALOG := preload("res://scripts/raid_region_catalog.gd")
const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")

# 기본 12칸 — 확장 사다리(고철)로 늘려 간다. 처음부터 넉넉하면 성장 재미가 없다.
const RAID_BAG_CAPACITY := 12
# Stack limits control discard batches only. Bag capacity uses one slot per
# stackable type-and-ID pair and one slot per individual weapon or equipment item.
const RAID_STACK_LIMITS := {
	"ammo": 60,
	"food": 4,
	"medkit": 2,
	"churu": 2,
	"component": 3,
	"mod": 1,
	"progression": 1,
}

var map_seed: int = 47291
var raid_serial: int = 0
# 첫 출정은 만전 상태로. 82로 시작하면 새 유저가 이유도 모른 채 깎인 체력으로
# 첫 교전을 치른다.
var player_health: int = 100
var player_level: int = 1
var player_xp: int = 0
var pending_level_choices: int = 0
var player_stat_levels: Dictionary = {
	"max_health": 0,
	"max_stamina": 0,
	"move_speed": 0,
	"recovery": 0,
	"toughness": 0,
	"fatigue_resistance": 0,
}
var training_levels: Dictionary = {
	"vitality": 0,
	"endurance": 0,
	"agility": 0,
	"recovery": 0,
	"fieldcraft": 0,
	# 탄약 운용 훈련 — 옛 세이브에 키가 없으면 load_persistent_state가 0으로 채운다.
	"magazine_drill": 0,
	"quick_hands": 0,
	"ammo_carry": 0,
	"sortie_supply": 0,
}
var magazine_ammo: int = 30
var reserve_ammo: int = 90
var has_ak: bool = true
var scrap: int = 80
var weapon_level: int = 1
# 구급약 1개를 쥐여 주고 시작한다. 0개로 첫 출정을 보내면 회복 수단이 운빨
# 루팅(사실상 동전 던지기)이 되고, 사망 화면은 있지도 않던 구급약을 논한다.
var medkits: int = 1
# 통조림은 '먹는 것'이 아니다(유저 확정: "고철 투자해서 훈련 아니야 통조림
# 소비해야해. 그리고 통조림은 먹는거 아님"). 쓰임은 딱 둘이다 —
#   ① 훈련장 지불 재화 → 쉘터 재고(shelter_canned_food)
#   ② 필드 투척 유인 소모품 → 가방(canned_food)
# 쉘터 연료 개념은 여전히 없다(주민만 배치되면 생산은 돈다).
#
# canned_food = 출정 중 가방에 든 통조림. 던질 수 있고, 사망하면 시체와 함께
# 사라진다. 창고에는 안 들어가고, 복귀 정산에서 전량 쉘터 재고로 귀속된다.
var canned_food: int = 0
# 쉘터 통조림 재고 = 훈련 비용을 내는 지갑. 필드에 들고 나가지 않으므로 사망에
# 안전하다 — 훈련 저축이 한 판 실수로 통째로 날아가면 아무도 저축하지 않는다.
var shelter_canned_food: int = 0
var catnip: int = 0
var churu: int = 0
# 귀중품: 용도가 없고 오직 값어치만 있는 물건. 추출 슈터의 핵심 판단축인
# "칸당 가치"를 순수하게 만드는 아이템 계열이다. 쉘터에서 고철로 환전한다.
var valuable_inventory: Dictionary = {}
# 귀중품 가치 원장(id → 누적 고철 가치). 귀중품은 존 배율(LootEconomy.VALUABLE_STAGE_MULTIPLIER)을
# 받아 같은 id라도 주운 존에 따라 값이 다르다 — 개수(valuable_inventory)만으로는 환전액을 못 구해
# 주울 때 가치를 함께 적는다. 원장이 없는(구세이브) id는 카탈로그 base_value×개수로 환산.
var valuable_value_ledger: Dictionary = {}
var fatigue: float = 0.0
var rescued_workers: int = 0
var resident_cat_ids: Array[String] = []
var assigned_worker_ids: Array[String] = []
var assigned_catnip_worker_ids: Array[String] = []
var resident_traits: Dictionary = {}
# 부품: 일반 3종(필드 어디서나) + 희귀 2종(정밀 기어·군용 합금 — 엘리트·보스·봉인
# 상자). 희귀 부품은 +31부터의 강화와 돌파에 든다. 전부 component 타입(1칸/개).
var mod_component_inventory: Dictionary = {
	"rubber_gasket": 0,
	"scope_lens": 0,
	"magazine_spring": 0,
	"precision_gear": 0,
	"military_alloy": 0,
}
# 진행 아이템(0칸 쉘터 자산). 설계도 조각은 "blueprint_shard_<레시피>" 키로 동적으로
# 쌓인다(레시피당 3조각 = 제작 해금, 소모되지 않음). 레거시 통짜 청사진
# (rifle/shotgun/akm/pump_blueprint)은 로드 시 조각 3개로 환산된다.
var progression_item_inventory: Dictionary = {
	"artisan_seal": 0,
	"sealed_zone_keycard": 0,
	# 쉘터 티어 3~5 확장 키(SHELTER_UPGRADE_COSTS.key_item). 메인 미션 보상 전용.
	"namdaemun_depot_plans": 0,
	"euljiro_grid_schematic": 0,
	"yongsan_control_key": 0,
}
var weapon_mod_inventory: Dictionary = {
	"scope_2x": 0,
	"muffled_sock": 0,
	"sponge_pad": 0,
	"quick_mag": 0,
	"bell_bait": 0,
	"ak_precision_receiver": 0,
}
var weapon_inventory: Dictionary = {"ak47": 1}
# 무기별 "첫 장착 보너스 탄창" 지급 여부 — 무기 체험은 장전된 총으로 시작한다.
var weapon_first_equip_done: Array = []
var equipment_inventory: Dictionary = {
	"scav_vest": 0,
	"riot_vest": 0,
	"patched_helmet": 0,
	"tactical_helmet": 0,
	"patched_sneakers": 0,
	"tactical_boots": 0,
	"military_vest": 0,
	"military_helmet": 0,
	"assault_boots": 0,
}
var equipped_body_armor_id: String = ""
var equipped_head_armor_id: String = ""
var equipped_footwear_id: String = ""
var returning_from_shelter: bool = false
var world_time_hours: float = 9.0
var equipped_weapon_id: String = "ak47"
var weapon_durability: float = 100.0
var equipped_weapon_mods: Array[String] = []
var weapon_mod_loadouts: Dictionary = {"ak47": []}
var equipped_magazine_id: String = "ak_30rnd"
var equipped_ammo_id: String = "762_fmj"
# 시작 탄약은 장착 무기(AK) 것만. 예전엔 권총/샷건 탄까지 들려 줘서, 쓸 무기도
# 없는 탄약이 가방 15칸 중 3칸을 처음부터 좀먹었다(탄종당 1칸).
var ammo_inventory: Dictionary = {
	"762_fmj": 90,
}
var secure_dog_slots: int = 1
var secure_dog_items: Array[Dictionary] = []
var pending_corpse_recovery: Dictionary = {}
var corpse_recovery_attempt_active: bool = false
var confirmed_raid_manifest: Dictionary = {}
var raid_field_loot_value_generated: int = 0
var raid_enemy_loot_value_generated: int = 0
var raid_total_loot_value_generated: int = 0
var raid_weapon_drops_generated: int = 0
# 적 처치로 나온 무기만 따로 센다. 예전엔 필드 컨테이너 무기와 한 통계를
# 공유해서, 무기 상자 몇 개만 열어도 그 판의 적 무기 드랍이 통째로 막혔다.
var raid_enemy_weapon_drops_generated: int = 0
var raid_enemy_drops_generated: int = 0
var raid_kills: int = 0
# 전투 숙련도 — 이번 판 헤드샷 횟수(정산 칩 "헤드샷 N회 · 경험치 +N").
var raid_headshots: int = 0
var raid_special_cargo: Dictionary = {}
var recovered_story_cargo_ids: Array[String] = []
var subway_story_stage: int = 0
# ── 존별 메인 미션 체인 ────────────────────────────────────────
# 구역 id → 완주한 단계 수(0~3). 세 단계를 끝낸 구역에서는 메인 미션이
# 더 이상 뜨지 않고 반복 사건만 남는다.
var main_mission_progress: Dictionary = {}
# 시네마틱 선택의 기록 — 이후 대사·엔딩 문구가 이걸 읽는다. {선택지 id: 고른 값}
var mission_choices: Dictionary = {}
# 이미 본 필드 시네마틱. 같은 장면을 판마다 다시 보면 그건 연출이 아니라 통행세다.
var seen_field_cinematics: Array[String] = []
# 구역 완주 안내를 사자가 이미 전한 구역들.
var saja_seen_main_mission_zones: Array[String] = []
var shelter_workbench_level: int = 1
var shelter_tier: int = 1
var scratcher_bank_level: int = 1
var scratcher_multiplier: float = 1.0
var catnip_scraper_level: int = 1
var catnip_scraper_multiplier: float = 1.0
var storage_level: int = 1
var storage_inventory: Array[Dictionary] = []
var catnip_boost_end_time: int = 0
# 캣닢 피버 — 게이지(0~100)와 발동 여부. 게이지는 세이브에 남는다.
var catnip_fever_gauge: float = 0.0
var catnip_fever_active: bool = false
var shelter_last_progress_time: int = 0
var workbench_repair_active: bool = false
var workbench_repair_weapon_id: String = "ak47"
var shelter_offline_scrap_pending: int = 0
var shelter_offline_catnip_pending: int = 0
var shelter_offline_repair_pending: float = 0.0
# 지난 출정 직전의 성장 지표. 다음 브리핑에서 "무엇이 달라졌는지"를 만든다.
var pre_raid_snapshot: Dictionary = {}
var workbench_starter_parts_claimed: bool = false
var shelter_scrap_fraction: float = 0.0
var shelter_catnip_fraction: float = 0.0
# 이번 출정에만 적용되는 츄르 버프. 출정 종료/사망 시 소멸한다.
var active_churu_buffs: Array[String] = []
# 판 도중 강제 종료(Alt+F4) 감시 — 출정 시작에 켜고 정상 복귀에 끈다.
# 로드 시 켜져 있으면 그 판은 '포기'로 처리된다(사망과 같은 손실, 시체 없음).
var raid_in_progress := false
var last_corpse_decay_notice: Dictionary = {}
# 직전 복귀 정산 결과(통조림·창고 이동·환전·창고 초과분). 쉘터가 한 번 읽고 비운다.
var last_return_settlement: Dictionary = {}
# 첫 판에서 "가방이 꽉 찼을 때의 갈등"을 한 번은 반드시 겪게 한다.
var bag_pressure_lesson_seen: bool = false
# 첫 출정에서 한 번씩만 뜨는 코칭. 다리 위 튜토리얼은 동사(이동·조준·사격)만
# 가르치고 끝나서, 정작 이 게임의 결정 구조는 아무도 설명하지 않았다.
var workbench_lesson_seen: bool = false
# 첫 출정에서 키 조작(TAB/R/SHIFT/E/SPACE)을 한 번 가르쳤는지.
var field_controls_lesson_seen: bool = false
# 전투 숙련도 1회성 필드 레슨 — 첫 예고 목격 / 첫 헤드샷 / 첫 엄폐.
var telegraph_lesson_seen: bool = false
var headshot_lesson_seen: bool = false
var cover_lesson_seen: bool = false
var fatigue_lesson_seen: bool = false
var extraction_choice_lesson_seen: bool = false
# 캣닢 피버는 시설이 아니라 '사건'이라 아무도 설명해 주지 않았다 — 해금 1회 레슨.
var catnip_fever_lesson_seen: bool = false
# 액티브 튜토리얼(ActiveTutorial)에서 끝낸(또는 건너뛴) 스텝 id. 위 레슨 플래그들과 달리
# 읽는 안내가 아니라 "행동하면 넘어가는" 안내의 진행도다. 설정의 '안내 다시 보기'가 비운다.
var tutorial_steps_done: Array[String] = []
var unlocked_milestones: Array[String] = []
var pending_milestone_unlocks: Array[Dictionary] = []
var resident_reroll_counts: Dictionary = {}
var shelter_return_serial: int = 0
# 살아서 돌아온 횟수. shelter_return_serial은 사망 귀환도 세므로(시체 부패·행상인
# 주기 등이 쓴다), "살아 돌아온 자에게만" 열리는 서사는 이 값으로 판정한다.
var survived_return_count: int = 0
# 판 포기(추출 없이 강제 종료)는 가방 재료·탄약·귀중품을 전부 잃는 손실(장비는 영구
# 귀속이라 남는다)인데 지금까지 아무 통보가 없었다. 로드 직후 켜 두고, 쉘터에 들어서는 순간 한 줄로 알린다(세이브 대상 아님).
var pending_abandonment_notice: bool = false
var merchant_last_roll_serial: int = -1
var merchant_status: String = "away"
var merchant_decline_count: int = 0
# 이번 방문의 매대(품목 + 남은 재고). 방문할 때마다 새로 굴린다.
var merchant_stock: Array[Dictionary] = []
# 이번 복귀에 상인이 헛걸음했는가 — 쉘터가 한 줄 단서로 알려 준다.
var merchant_missed_visit: bool = false

# 상인 매대 후보. 탄약은 제작이 폐지돼 필드 루팅과 여기 둘뿐이다.
const MERCHANT_AMMO_GOODS := [
	{
		"id": "762_fmj", "type": "ammo", "title": "7.62mm 보통탄", "amount": 30,
		"buy_price": 650, "sell_scrap": 200, "stock_min": 2, "stock_max": 4,
		"icon": "res://assets/items/ammo_762.png",
		"description": "AK 계열 총기에 사용하는 보통탄입니다.",
	},
	{
		"id": "9mm_fmj", "type": "ammo", "title": "9mm 보통탄", "amount": 45,
		"buy_price": 520, "sell_scrap": 160, "stock_min": 2, "stock_max": 4,
		"icon": "res://assets/items/ammo_762.png",
		"description": "기관단총과 권총에 두루 쓰는 가벼운 탄약입니다.",
	},
	{
		"id": "45_fmj", "type": "ammo", "title": ".45 ACP 보통탄", "amount": 24,
		"buy_price": 480, "sell_scrap": 140, "stock_min": 2, "stock_max": 3,
		"icon": "res://assets/items/ammo_762.png",
		"description": "묵직한 권총탄. 한 발의 무게가 다릅니다.",
	},
	{
		"id": "12g_buckshot", "type": "ammo", "title": "12게이지 벅샷", "amount": 12,
		"buy_price": 700, "sell_scrap": 210, "stock_min": 2, "stock_max": 4,
		"icon": "res://assets/items/ammo_762.png",
		"description": "근거리 저지력이 높은 산탄입니다.",
	},
]
const MERCHANT_SUNDRY_GOODS := [
	{
		"id": "scope_lens", "type": "component", "title": "스코프 렌즈", "amount": 1,
		"buy_price": 1200, "sell_scrap": 360, "stock_min": 1, "stock_max": 3,
		"icon": "res://assets/items/mod_components/scope_lens.png",
		"description": "조준경과 정밀 모듈 제작에 사용하는 온전한 렌즈입니다.",
	},
	{
		"id": "rubber_gasket", "type": "component", "title": "고무 패킹", "amount": 1,
		"buy_price": 950, "sell_scrap": 290, "stock_min": 1, "stock_max": 3,
		"icon": "res://assets/items/mod_components/rubber_gasket.png",
		"description": "소음기와 반동 완충 부품 제작에 사용하는 패킹입니다.",
	},
	{
		"id": "magazine_spring", "type": "component", "title": "탄창 스프링", "amount": 1,
		"buy_price": 1050, "sell_scrap": 320, "stock_min": 1, "stock_max": 3,
		"icon": "res://assets/items/mod_components/magazine_spring.png",
		"description": "탄창과 전술 부품 제작에 사용하는 복원력 높은 스프링입니다.",
	},
	{
		"id": "medkit", "type": "medkit", "title": "구급약", "amount": 1,
		"buy_price": 1600, "sell_scrap": 0, "stock_min": 1, "stock_max": 2,
		"icon": "", "description": "출정 중 체력을 회복하는 응급 처치 키트입니다.",
	},
	# 장비(방어구)는 매대에서 뺐다 — 장비는 작업대 제작 전용(2026-08 경제 코어).
]
# 판매(매입) 목록은 매대와 별개다 — 상인이 오늘 뭘 파느냐와 내 물건을 사 주느냐는
# 다른 문제다. 여기 있는 품목은 방문마다 항상 팔 수 있다.
# 매입 대가는 고철(sell_scrap)이다. 되팔기 가치는 구매가의 약 30%(10 단위
# 반올림) — 상인은 사는 쪽이 늘 남는 장사다.
# 통조림은 매입 목록에서 뺐다: 훈련 재화를 고철로 팔 수 있으면 훈련 비용이
# 사실상 고철이 되고(유저 의도와 정반대) 훈련 경제가 그 구멍으로 샌다.
const MERCHANT_SELL_GOODS := [
	{
		"id": "762_fmj", "type": "ammo", "title": "7.62mm 보통탄", "amount": 30,
		"buy_price": 650, "sell_scrap": 200, "icon": "res://assets/items/ammo_762.png",
		"description": "AK 계열 총기에 사용하는 보통탄입니다.",
	},
	{
		"id": "9mm_fmj", "type": "ammo", "title": "9mm 보통탄", "amount": 45,
		"buy_price": 520, "sell_scrap": 160, "icon": "res://assets/items/ammo_762.png",
		"description": "기관단총과 권총에 두루 쓰는 가벼운 탄약입니다.",
	},
	{
		"id": "12g_buckshot", "type": "ammo", "title": "12게이지 벅샷", "amount": 12,
		"buy_price": 700, "sell_scrap": 210, "icon": "res://assets/items/ammo_762.png",
		"description": "근거리 저지력이 높은 산탄입니다.",
	},
	{
		"id": "scope_lens", "type": "component", "title": "스코프 렌즈", "amount": 1,
		"buy_price": 1200, "sell_scrap": 360,
		"icon": "res://assets/items/mod_components/scope_lens.png",
		"description": "조준경과 정밀 모듈 제작에 사용하는 온전한 렌즈입니다.",
	},
	{
		"id": "rubber_gasket", "type": "component", "title": "고무 패킹", "amount": 1,
		"buy_price": 950, "sell_scrap": 290,
		"icon": "res://assets/items/mod_components/rubber_gasket.png",
		"description": "소음기와 반동 완충 부품 제작에 사용하는 패킹입니다.",
	},
	{
		"id": "magazine_spring", "type": "component", "title": "탄창 스프링", "amount": 1,
		"buy_price": 1050, "sell_scrap": 320,
		"icon": "res://assets/items/mod_components/magazine_spring.png",
		"description": "탄창과 전술 부품 제작에 사용하는 복원력 높은 스프링입니다.",
	},
]
var weapon_enhancement_levels: Dictionary = {"ak47": 0}
var mod_enhancement_levels: Dictionary = {}
# ── 방어구 강화(2026-08 신설) ──
# 기본 id(레벨 접미사 없음) → 0~99. 효과는 get_armor_enhancement_multiplier —
# damage_reduction × (1 + 0.6×(1−0.96^L)), 피스 합산 상한 0.70. 적용 지점은 피해
# 계산 단일 함수(get_equipment_damage_multiplier)뿐이다. 비용 600×가족계수×1.26^L.
var armor_enhancement_levels: Dictionary = {}
# 방어구 이관(같은 슬롯 T1→T2→T3 60%, 상위 1종당 평생 1회) — 무기와 같은 규약.
var armor_enhancement_transfers_done: Array = []
var last_armor_enhancement_transfer: Dictionary = {}
# ── 돌파 ──
# "weapon:ak47" / "armor:scav_vest" → 돌파를 끝낸 최고 단계(10·20·…·90). L이 10의
# 배수일 때 다음 강화로 가려면 try_breakthrough(장인의 인장 + 희귀 부품 + 고철×3).
var gear_breakthroughs: Dictionary = {}
var selected_raid_zone: String = "jongno_outskirts"
var contract_chain_index: int = 0
var contract_status: String = "available"
var contract_progress: int = 0
var completed_contract_ids: Array[String] = []
var unlocked_contract_lore: Array[String] = []
var shelter_facility_unlocks: Dictionary = {
	"bed": true,
	"storage": false,
	"training": false,
	"workbench": false,
	"scratcher_bank": false,
	"catnip_scraper": false,
}
var contract_agent_intro_seen: bool = false
var saja_intro_seen: bool = false
# 행상인 최초 입장 자기소개(게임 전체 1회) 노출 여부.
var merchant_intro_seen: bool = false
var saja_second_run_intro_seen: bool = false
var saja_seen_resident_count: int = 0
var saja_seen_boss_kills: int = 0
var saja_seen_story_cargo_count: int = 0
var saja_seen_subway_stage: int = 0
var total_boss_kills: int = 0
var juhong_seen_events: Array[String] = []
var iron_mission_index: int = 0
var iron_mission_status: String = "available"
var iron_mission_progress: int = 0
var completed_iron_mission_ids: Array[String] = []
var opening_completed: bool = false
var persistence_enabled: bool = true
var persistence_path: String = SAVE_PATH

const SAVE_PATH := "user://shelter_progress_v2.json"
const MAX_WEAPON_ENHANCEMENT := 99
const MAX_ARMOR_ENHANCEMENT := 99
# ── 장비 제작 전용 · 영구 귀속(2026-08 경제 코어) ──
# 무기 7종·방어구 9종 전부 작업대 레시피(설계도 조각 3/3 + 고철 + 부품). 보유 중이면
# 재제작 불가(1개 영구). 장비는 가방 칸 0, 사망·판 포기에도 전부 남는다.
const BLUEPRINT_SHARDS_REQUIRED := 3
const GEAR_WEAPON_RECIPE_IDS: Array[String] = ["m1911", "mp5", "ak47", "double_barrel", "pump_shotgun", "akm", "k2"]
const GEAR_ARMOR_RECIPE_IDS: Array[String] = [
	"scav_vest", "patched_helmet", "patched_sneakers",
	"riot_vest", "tactical_helmet", "tactical_boots",
	"military_vest", "military_helmet", "assault_boots",
]
const BASIC_COMPONENT_IDS: Array[String] = ["rubber_gasket", "scope_lens", "magazine_spring"]
const RARE_COMPONENT_IDS: Array[String] = ["precision_gear", "military_alloy"]
const ARTISAN_SEAL_ID := "artisan_seal"
# 방어구 가족 사다리(슬롯별 T1→T2→T3) — 이관 60%의 기준. 가족 계수는 강화 비용 배율.
const ARMOR_FAMILY_LADDER := {
	"body": ["scav_vest", "riot_vest", "military_vest"],
	"head": ["patched_helmet", "tactical_helmet", "military_helmet"],
	"feet": ["patched_sneakers", "tactical_boots", "assault_boots"],
}
const ARMOR_FAMILY_FACTORS := [1.0, 1.5, 2.2]
# ── 강화 비용 곡선: 3구간 지수(대개편 3단계 · 시뮬 재조정, tmp/econ_model.py) ──
# 단일 지수(무기 ×1.28 / 방어구 ×1.26)는 +40 17.7M → +60 2.6B → +99 36T로 터져
# 60대 이후가 사실상 없는 구간이었다. 구간별로 꺾는다:
#   무기  +1~30 ×1.28 · +31~60 ×1.10 · +61~99 ×1.055  → K2 누적(돌파 포함) +30 11.4M · +50 213M · +99 8.9B
#   방어구 +1~30 ×1.26 · +31~60 ×1.09 · +61~99 ×1.045 → T3 세트(3피스) +99 ≈ 5.0B
# [상한 레벨, 그 구간의 단계당 배율] — _segmented_growth가 구간별 pow를 곱한다.
const WEAPON_ENHANCEMENT_SEGMENTS := [[30, 1.28], [60, 1.10], [99, 1.055]]
const ARMOR_ENHANCEMENT_SEGMENTS := [[30, 1.26], [60, 1.09], [99, 1.045]]
const ARMOR_ENHANCEMENT_BASE_COST := 400.0  # 600 → 400: 세 슬롯을 같이 키우는 방어구는 한 피스가 무기의 ~1/2.
# 돌파 단계 간격 — +10, +20, …, +90에서 한 번씩.
const BREAKTHROUGH_STEP := 10
# 돌파 정체성 보너스 단계 — get_breakthrough_perks / describe_breakthrough_perk가 이 표를 본다.
const BREAKTHROUGH_PERK_LEVELS: Array[int] = [30, 50, 70, 90]
const WEAPON_PERK_ELITE_DAMAGE_BONUS := 0.20     # +70: 엘리트·보스 피해 +20%(일반 적 제외)
const WEAPON_PERK_MAGAZINE_BONUS := 0.25        # +50: 탄창 +25%
const WEAPON_PERK_RELOAD_MULTIPLIER := 0.85     # +50: 장전 −15%
const WEAPON_PERK_KILL_AMMO_REFUND := 0.10      # +90: 처치 시 탄창 10% 탄약 환급 · 내구 소모 0
const ARMOR_PERK_KNOCKBACK_RESIST := 0.50       # +30(몸): 넉백 저항 50%
const ARMOR_PERK_POST_HIT_WINDOW_SEC := 1.5     # +50: 피격 후 1.5s 추가 피해 −20%
const ARMOR_PERK_POST_HIT_DAMAGE_MULTIPLIER := 0.80
const ARMOR_PERK_FATIGUE_MULTIPLIER := 0.85     # +70: 피로 누적 −15%
const ARMOR_PERK_SECURE_SLOT_BONUS := 1         # +90: 시큐어 슬롯 +1


static func _segmented_growth(level: int, segments: Array) -> float:
	# 구간별 지수 성장 누적 — level(=현재 강화 단계, 다음 단계 비용의 지수)까지 각 구간의
	# 배율을 구간 길이만큼 곱한다. 예) level 45, 무기: 1.28^30 × 1.10^15.
	var growth := 1.0
	var previous_cap := 0
	for segment in segments:
		var cap := int(segment[0])
		var ratio := float(segment[1])
		var steps := clampi(level, previous_cap, cap) - previous_cap
		if steps > 0:
			growth *= pow(ratio, float(steps))
		previous_cap = cap
		if level <= cap:
			break
	return growth
const CONTRACT_AGENT_UNLOCK_RETURN := 1
const SHELTER_FACILITY_NAMES := {
	"bed": "개인 침대",
	"storage": "쉘터 창고",
	"training": "생존 체력 훈련장",
	"workbench": "무기 작업대",
	"scratcher_bank": "꾹꾹이 고철 생산기",
	"catnip_scraper": "스크래핑 캣닢 생산기",
}
const SHELTER_FACILITY_NAMES_V2 := {
	"bed": "개인 침상",
	"storage": "쉘터 창고",
	"training": "생존 체력 훈련장",
	"workbench": "무기 작업대",
	"scratcher_bank": "꾹꾹이 고철 생산기",
	"catnip_scraper": "스크래핑 캣닢 생산기",
}
const SAJA_FACILITY_CONTRACTS: Array[Dictionary] = [
	{
		"id": "field_parts",
		"title": "공생의 첫 톱니",
		"brief": "도시에서 기초 부품 3개를 확보해 사자에게 전달하세요.",
		"accept_dialogue": [
			"이 쉘터는 벽만 남았지, 살아갈 힘은 아직 없어.",
			"도시에서 쓸 만한 부품을 모아 와. 네가 길을 열면, 내가 생산 라인을 세우지.",
		],
		"complete_dialogue": [
			"좋아. 녹은 슬었어도 톱니는 아직 맞물리는군.",
			"꾹꾹이 고철 생산기를 가동하겠다. 주민이 늘수록 이곳도 공장처럼 살아날 거야.",
		],
		"objective": "기초 부품 확보",
		"metric": "parts",
		"target": 3,
		"reward": {"xp": 80, "canned_food": 4, "churu": 1},
		"facility_unlock": "scratcher_bank",
		"lore_title": "사자의 기록 01 · 공생",
		"lore": "사자는 쉘터를 지키는 대신, 생존자들이 가져온 자원으로 공동 설비를 세우기로 했다.",
	},
	{
		"id": "street_patrol",
		"title": "초록 불씨",
		"brief": "주변 위협 4명을 정리해 캣닢 재배 장비를 옮길 길을 확보하세요.",
		"accept_dialogue": [
			"캣닢은 사치품이 아니야. 지친 주민을 다시 움직이게 하는 연료지.",
			"운반로를 막은 녀석들을 치워 줘. 초록 불씨를 이 안으로 들여오겠다.",
		],
		"complete_dialogue": [
			"길이 열렸군. 이제 캣닢을 직접 생산할 수 있어.",
			"잘 기억해. 이 도시에서 고철은 뼈고, 캣닢은 피다.",
		],
		"objective": "운반로 위협 제거",
		"metric": "kills",
		"target": 4,
		"reward": {"xp": 110, "ammo": 30},
		"facility_unlock": "catnip_scraper",
		"lore_title": "사자의 기록 02 · 초록 연료",
		"lore": "캣닢은 쉘터 노동을 증폭하는 귀중한 자원이며, 지배 세력이 유통로를 통제하고 있다.",
	},
	{
		"id": "lost_notices",
		"title": "다시 쏘는 법",
		"brief": "현장 기록 2개를 조사해 폐쇄된 정비 구역의 위치를 찾으세요.",
		"accept_dialogue": [
			"총은 주워 올 수 있어도, 망가진 총을 살리는 법은 아무나 모르지.",
			"옛 정비공들의 기록을 찾아와. 작업대를 세울 단서를 거기서 찾을 수 있을 거다.",
		],
		"complete_dialogue": [
			"좌표가 맞아. 필요한 공구도 아직 남아 있군.",
			"무기 작업대를 열겠다. 이제 주운 총을 버리지 말고 네 방식으로 길들여.",
		],
		"objective": "정비 기록 조사",
		"metric": "lore",
		"target": 2,
		"reward": {"xp": 120, "canned_food": 3, "medkits": 1},
		"facility_unlock": "workbench",
		"lore_title": "사자의 기록 03 · 마지막 정비공",
		"lore": "사라진 인간들의 정비 기록은 고양이 생존자들의 무기 제작 기술로 이어졌다.",
	},
	{
		"id": "salvage_cipher",
		"title": "도시의 해체법",
		"brief": "버려진 차량이나 군용 설비 2개를 분해하세요.",
		"accept_dialogue": [
			"폐허는 쓰레기장이 아니야. 아직 읽는 법을 모르는 창고지.",
			"설비를 분해해 봐. 무엇을 챙기고 무엇을 버려야 하는지 몸으로 익혀.",
		],
		"complete_dialogue": [
			"이제야 도시가 물건으로 보이기 시작했겠군.",
			"그 눈을 잃지 마. 좋은 부품 하나가 총 한 자루보다 오래 살아남게 한다.",
		],
		"objective": "현장 설비 분해",
		"metric": "salvage",
		"target": 2,
		"reward": {"xp": 130, "canned_food": 4, "ammo": 45},
		"lore_title": "사자의 기록 04 · 폐허의 가치",
		"lore": "폐허의 가치는 크기가 아니라, 다음 출정을 가능하게 만드는 부품에 있다.",
	},
	{
		"id": "rescue_route",
		"title": "빈 침상의 주인",
		"brief": "도시에서 주민 1명을 구출해 쉘터까지 호송하세요.",
		"accept_dialogue": [
			"설비만 늘어선 곳은 쉘터가 아니라 무덤이야.",
			"밖에 남은 고양이를 데려와. 이곳을 지킬 손과, 함께 살아갈 이유가 필요하다.",
		],
		"complete_dialogue": [
			"잘 데려왔어. 오늘부터 저 고양이도 이곳의 몫을 나눠 가진다.",
			"네가 구한 건 일꾼 한 명이 아니라, 쉘터가 내일도 돌아갈 가능성이야.",
		],
		"objective": "주민 구출",
		"metric": "rescue",
		"target": 1,
		"reward": {"xp": 150, "canned_food": 5, "churu": 1},
		"lore_title": "사자의 기록 05 · 빈 침상",
		"lore": "주민은 생산 수치가 아니라 쉘터의 구성원이며, 각자 다른 기억과 재능을 품고 있다.",
	},
	{
		"id": "field_operation",
		"title": "우리의 첫 작전",
		"brief": "필드 작전 1개를 수락하고 완수한 뒤 생환하세요.",
		"accept_dialogue": [
			"이제 남이 남긴 길만 따라갈 때는 지났어.",
			"현장 작전 하나를 끝내고 돌아와. 네 선택이 이 쉘터의 다음 방향이 된다.",
		],
		"complete_dialogue": [
			"좋아. 이제 이곳은 숨는 구멍이 아니라, 도시로 손을 뻗는 거점이다.",
			"다음부터는 네가 무엇을 가져오느냐에 따라 쉘터의 모습도 달라질 거야.",
		],
		"objective": "현장 작전 완료",
		"metric": "field_mission",
		"target": 1,
		"reward": {"xp": 180, "ammo": 60, "medkits": 2},
		"lore_title": "사자의 기록 06 · 살아 있는 거점",
		"lore": "쉘터는 도시의 자원을 소비하는 장소가 아니라, 다음 탐사를 만드는 살아 있는 거점이 되었다.",
	},
]
const IRON_SPECIAL_MISSIONS: Array[Dictionary] = [
	{
		"id": "iron_trial_vitality",
		"title": "철근의 시험 · 맷집",
		"brief": "한 출정에서 적 8명을 상대해 전투 리듬을 증명하세요.",
		"metric": "kills",
		"target": 8,
		"training_id": "vitality",
		"reward_text": "영구 최대 체력 +10",
		"accept_dialogue": "총만 믿고 서 있으면 첫 탄창 뒤에 끝난다. 여덟을 상대하고도 숨이 붙어 있으면 인정하지.",
		"complete_dialogue": "버텼군. 이제 네 몸이 총성보다 먼저 움츠러들지는 않을 거다.",
	},
	{
		"id": "iron_trial_endurance",
		"title": "철근의 시험 · 지구력",
		"brief": "위험 지역에서 설비 5개를 분해해 지구력을 증명하세요.",
		"metric": "salvage",
		"target": 5,
		"training_id": "endurance",
		"reward_text": "영구 최대 스태미나 +12",
		"accept_dialogue": "싸움은 방아쇠보다 오래 간다. 무거운 부품을 끝까지 챙겨 오는 힘부터 보여 줘.",
		"complete_dialogue": "호흡이 무너지지 않았군. 이 정도면 도망칠 때도, 쫓을 때도 한 걸음 더 간다.",
	},
	{
		"id": "iron_trial_fieldcraft",
		"title": "철근의 시험 · 사냥꾼",
		"brief": "도시의 보스 1명을 쓰러뜨리고 생환하세요.",
		"metric": "boss",
		"target": 1,
		"training_id": "fieldcraft",
		"reward_text": "영구 피로 저항 및 생존술 강화",
		"accept_dialogue": "약한 놈 백 마리보다, 도시가 이름을 붙인 괴물 하나가 네 실력을 말해 준다.",
		"complete_dialogue": "도시가 네 이름을 기억하겠군. 이제 너도 도시의 숨을 읽을 자격이 있다.",
	},
]

const EQUIPMENT_DEFINITIONS := {
	"scav_vest": {
		"display_name": "누더기 방탄 조끼", "slot": "body", "damage_reduction": 0.15,
		"weight": 3.8, "icon": "armor",
		"texture_path": "res://assets/equipment/generated/scav_vest.png",
		"description": "얇은 철판을 덧댄 경량 조끼. 받는 피해를 20% 줄입니다.",
	},
	"riot_vest": {
		"display_name": "진압대 방탄 조끼", "slot": "body", "damage_reduction": 0.30,
		"weight": 6.2, "icon": "armor", "visibility_multiplier": 1.08,
		"texture_path": "res://assets/equipment/generated/riot_vest.png",
		"description": "무겁지만 튼튼한 진압 장비. 받는 피해를 30% 줄이지만 덩치가 커져 눈에 잘 띕니다.",
	},
	"patched_helmet": {
		"display_name": "기워 붙인 헬멧", "slot": "head", "damage_reduction": 0.10,
		"weight": 1.4, "icon": "helmet",
		"texture_path": "res://assets/equipment/generated/patched_helmet.png",
		"description": "금이 간 안전모를 보강했습니다. 받는 피해를 10% 줄입니다.",
	},
	"tactical_helmet": {
		"display_name": "전술 방탄 헬멧", "slot": "head", "damage_reduction": 0.20,
		"weight": 2.1, "icon": "helmet", "visibility_multiplier": 1.04,
		"texture_path": "res://assets/equipment/generated/tactical_helmet.png",
		"description": "군용 내피가 남아 있는 헬멧. 받는 피해를 20% 줄이지만 실루엣이 커집니다.",
	},
	"patched_sneakers": {
		"display_name": "기워 붙인 운동화", "slot": "feet",
		"move_speed_bonus": 0.06, "stamina_cost_multiplier": 0.92,
		"weight": 0.7, "icon": "footwear", "scent_multiplier": 0.85,
		"texture_path": "res://assets/equipment/generated/patched_sneakers.png",
		"description": "가볍게 기워 발소리와 냄새 흔적을 줄인 생존용 운동화입니다.",
	},
	"tactical_boots": {
		"display_name": "경량 전술화", "slot": "feet",
		"move_speed_bonus": 0.03, "stamina_cost_multiplier": 0.78,
		"weight": 1.4, "icon": "footwear",
		"texture_path": "res://assets/equipment/generated/tactical_boots.png",
		"description": "발목을 잡아주면서도 유연한 밑창을 사용한 경량 전술화입니다.",
	},
	"military_vest": {
		"display_name": "군납 방탄복", "slot": "body", "damage_reduction": 0.34,
		"weight": 7.4, "icon": "armor", "visibility_multiplier": 1.12,
		"texture_path": "res://assets/equipment/generated/military_vest.png",
		"description": "봉쇄선 부대에서 흘러나온 정식 군납품. 받는 피해를 34% 줄이지만 눈에 확 띕니다.",
	},
	"military_helmet": {
		"display_name": "군납 전투 헬멧", "slot": "head", "damage_reduction": 0.24,
		"weight": 2.6, "icon": "helmet", "visibility_multiplier": 1.06,
		"texture_path": "res://assets/equipment/generated/military_helmet.png",
		"description": "레일과 내피가 온전한 전투 헬멧. 받는 피해를 24% 줄이지만 실루엣이 커집니다.",
	},
	"assault_boots": {
		"display_name": "강습 부츠", "slot": "feet",
		"move_speed_bonus": 0.05, "stamina_cost_multiplier": 0.70,
		"weight": 1.7, "icon": "footwear", "scent_multiplier": 1.15,
		"texture_path": "res://assets/equipment/generated/assault_boots.png",
		"description": "봉쇄선 강습조가 신던 부츠. 기동성이 탁월하지만 무거워 냄새 흔적이 짙게 남습니다.",
	},
}
const PLAYER_LEVEL_REWARDS := {
	"max_health": {"title": "생존 체질", "description": "최대 체력 +8", "icon": "health"},
	"max_stamina": {"title": "지구력", "description": "최대 스태미나 +10", "icon": "stamina"},
	"move_speed": {"title": "민첩한 발", "description": "이동 속도 +2.5%", "icon": "speed"},
	"recovery": {"title": "호흡 조절", "description": "스태미나 회복 +7%", "icon": "recovery"},
	"toughness": {"title": "충격 적응", "description": "받는 피해 -2%", "icon": "armor"},
	"fatigue_resistance": {"title": "현장 적응", "description": "피로 획득 -5%", "icon": "fitness"},
}
# 훈련 비용은 통조림이다(유저 확정: "고철 투자해서 훈련 아니야 통조림 소비해야해").
# 지불처는 쉘터 재고(shelter_canned_food) — 가방 통조림은 던지기용이다.
#
# 수급 눈금: 판당 확정 픽업 12~17개(LootEconomy.get_guaranteed_canned_food_pickup_count)
# ×더블스택 1.2~1.3 + 낱개 드랍 ≈ 판당 15~25개. 아래 표는 20개/판을 기준으로 잡았다.
#   · 초반 노드 1랭크 14~20 = 출정 한 판 안쪽 → "다녀오면 한 칸 오른다"
#   · 상위/후반 노드 상위 랭크 90~122 = 출정 4~6판 → 저축의 목표가 된다
#   · 9종 만렙 합계 1,674 ≈ 출정 84판(25개/판이면 67판)
const TRAINING_NODE_DEFS := {
	"vitality": {
		"title": "중량 훈련", "description": "랭크마다 최대 체력 +10", "icon": "health",
		"max_rank": 5, "base_cost": 14, "cost_step": 9, "requires": {},
	},
	"endurance": {
		"title": "유산소 훈련", "description": "랭크마다 최대 스태미나 +12", "icon": "stamina",
		"max_rank": 5, "base_cost": 14, "cost_step": 9, "requires": {},
	},
	"recovery": {
		"title": "회복 루틴", "description": "랭크마다 스태미나 회복 +8%", "icon": "recovery",
		"max_rank": 4, "base_cost": 20, "cost_step": 14, "requires": {"vitality": 2},
	},
	"agility": {
		"title": "풋워크", "description": "랭크마다 이동 속도 +2%", "icon": "speed",
		"max_rank": 4, "base_cost": 20, "cost_step": 14, "requires": {"endurance": 2},
	},
	"fieldcraft": {
		"title": "현장 체력", "description": "랭크마다 피로 획득 -7%", "icon": "fitness",
		"max_rank": 3, "base_cost": 40, "cost_step": 26, "requires": {"recovery": 2, "agility": 2},
	},
	# ── 탄약 운용 훈련(유저 신고: "총기 업그레이드가 아니라 훈련으로 탄창 개수·기본
	# 장착 개수를 늘릴 수 있어야지, 탄약 모자라고 장전이 잦아서 힘들다") ──
	# 장탄·장전 배율은 build_player_weapon_stats(단일 지점)에서 곱한다. 적은 영향 없음.
	"magazine_drill": {
		"title": "탄창 숙련", "description": "랭크마다 장탄수 +8% (반올림, 최소 +1발)", "icon": "ammo",
		"max_rank": 4, "base_cost": 18, "cost_step": 11, "requires": {},
	},
	"quick_hands": {
		"title": "신속 장전", "description": "랭크마다 장전 시간 -8%", "icon": "reload",
		"max_rank": 4, "base_cost": 24, "cost_step": 16, "requires": {"magazine_drill": 1},
	},
	"ammo_carry": {
		"title": "탄약 휴대", "description": "랭크마다 탄약 한 칸에 들어가는 발수 +25%", "icon": "backpack",
		"max_rank": 4, "base_cost": 30, "cost_step": 20, "requires": {"vitality": 1},
	},
	"sortie_supply": {
		"title": "출정 보급", "description": "랭크마다 출정 시작 시 장착 구경 1탄창 지급", "icon": "raid",
		"max_rank": 3, "base_cost": 50, "cost_step": 36, "requires": {"ammo_carry": 1},
	},
}
# 탄약 한 칸에 들어가는 발수(훈련 0랭크). 예전엔 "탄약 한 종류 = 무조건 1칸"이라
# 발수가 칸에 영향을 주지 않았다 — 탄약 휴대 훈련이 의미를 가지려면 상한이 있어야
# 한다. 240은 AK 8탄창: 평범한 출정에선 1칸 그대로고, 쟁여 둔 600발만 3칸이 된다.
const AMMO_ROUNDS_PER_SLOT := 240
const RAID_ZONES := {
	"jongno_outskirts": {
		"name": "종로 외곽",
		"description": "낮은 위협도의 폐상가 지대. 통조림과 기초 부품을 확보하기 좋습니다.",
		"required_tier": 1,
		"stage_tier": 1,
		"threat": 0.15,
		"enemy_multiplier": 1.0,
		"boss": false,
		"reward": "통조림 · 기초 부품",
		"zone_rule": "",
		"rule_brief": "안정적인 초반 구역. 특수 규칙 없음.",
	},
	"namdaemun_market": {
		"name": "남대문 폐시장",
		"description": "무장 약탈자가 상가 통로를 점거한 중위험 구역입니다.",
		"required_tier": 2,
		"stage_tier": 2,
		"threat": 0.35,
		"enemy_multiplier": 1.25,
		"boss": true,
		"reward": "츄르 · 총기 부품",
		"zone_rule": "crowd",
		"rule_brief": "상가 통로가 좁다. 적이 무리로 몰려오니 퇴로를 확보하라.",
	},
	"euljiro_depths": {
		"name": "을지로 지하구역",
		"description": "좁은 골목과 지하 통로가 이어지는 고위험 구역입니다.",
		"required_tier": 3,
		"stage_tier": 3,
		"threat": 0.55,
		"enemy_multiplier": 1.55,
		"boss": true,
		"reward": "고급 부품 · 츄르",
		"zone_rule": "darkness",
		"rule_brief": "지하는 어둡다. 시야가 좁고 소음이 멀리 퍼진다.",
	},
	"yongsan_blockade": {
		"name": "용산 봉쇄선",
		"description": "군용 화기와 정예 병력이 남아 있는 봉쇄 구역입니다.",
		"required_tier": 4,
		"stage_tier": 4,
		"threat": 0.78,
		"enemy_multiplier": 1.9,
		"boss": true,
		"reward": "특수 모듈 · 츄르",
		"zone_rule": "sniper",
		"rule_brief": "정예 병력이 트인 길을 감시한다. 엄폐물을 끼고 움직여라.",
	},
	"namsan_core": {
		"name": "남산 오염 핵심부",
		"description": "서울에서 가장 위험한 심야 전투 구역입니다.",
		"required_tier": 5,
		"stage_tier": 5,
		"threat": 1.0,
		"enemy_multiplier": 2.3,
		"boss": true,
		"reward": "최상급 부품 · 대량 츄르",
		"zone_rule": "toxic",
		"rule_brief": "오염 지대. 머무는 동안 체력이 서서히 깎이니 빠르게 움직여라.",
	},
}

const WORKBENCH_UPGRADE_COSTS := {2: 7500, 3: 40000, 4: 180000, 5: 800000}
# 꾹꾹이 생산기 최대 Lv 5 → 8(대개편 3단계). Lv5에서 수입이 멈추면 +60 이후 강화 구간이
# '기다림'뿐이라, 수입 성장 수단을 Lv8(×1.9^7 ≈ ×89)까지 연장한다. 비용은 ×5 계단 유지.
const SCRATCHER_BANK_MAX_LEVEL := 8
const SCRATCHER_UPGRADE_COSTS := {2: 12000, 3: 60000, 4: 280000, 5: 1300000, 6: 6000000, 7: 30000000, 8: 150000000}
# 고철 생산기 확장에는 캣닢이 함께 든다. 캣닢은 출정 버프를 잃은 대신
# "고철 라인을 키우는 재료"가 됐다 — 착즙 라인을 키워야 꾹꾹이 라인이 큰다.
# 요구량은 대략 해당 시점 착즙 생산 30분~2시간치를 노린 지수 곡선이다.
const SCRATCHER_UPGRADE_CATNIP_COSTS := {2: 900, 3: 4500, 4: 22000, 5: 110000, 6: 500000, 7: 2500000, 8: 12000000}
const CATNIP_SCRAPER_UPGRADE_COSTS := {2: 10000, 3: 50000, 4: 230000, 5: 1000000}
const STORAGE_GRID_BY_LEVEL := {
	1: Vector2i(6, 5),
	2: Vector2i(7, 6),
	3: Vector2i(8, 7),
	4: Vector2i(9, 8),
	5: Vector2i(10, 9),
}
const STORAGE_UPGRADE_COSTS := {
	2: {"scrap": 8000, "churu": 0},
	3: {"scrap": 38000, "churu": 1},
	4: {"scrap": 170000, "churu": 2},
	5: {"scrap": 700000, "churu": 4},
}
const SHELTER_CAPACITY_BY_TIER := {1: 5, 2: 10, 3: 20, 4: 35, 5: 50}
# 티어 5 좌석 20 → 24(대개편 3단계): 최종 티어 수입 상한을 한 칸 더 연다.
const KNEADING_SLOTS_BY_TIER := {1: 3, 2: 6, 3: 10, 4: 15, 5: 24}
const CATNIP_SLOTS_BY_TIER := {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
# 예전 곡선은 티어마다 약 13배(30k→400k→5M→60M)라 중반부터 출정이 재미가
# 아니라 고철 대기가 됐다. 스텝을 약 5배로 낮춰 진행이 계단이 아니라
# 곡선이 되게 한다. 츄르 요구는 완만히 유지해 성취감은 남긴다.
#
# key_item(티어 3~5): 가방 칸을 안 먹는 서사 키 1개. 메인 미션 체인 3단계 완료
# 보상으로만 나온다(상인 매대 금지) — "다음 쉘터는 다음 도시의 이야기를 끝내야
# 열린다". 티어 2는 키 없음(첫 확장은 츄르 1개면 충분해야 한다). 키는 소모하지
# 않는다(설계도는 남는다). 표시·문구는 scripts/shelter/requisition.gd가 맡는다.
const SHELTER_UPGRADE_COSTS := {
	2: {"scrap": 30000, "churu": 1},
	3: {"scrap": 150000, "churu": 2, "key_item": "namdaemun_depot_plans"},
	4: {"scrap": 750000, "churu": 4, "key_item": "euljiro_grid_schematic"},
	5: {"scrap": 3500000, "churu": 8, "key_item": "yongsan_control_key"},
}
# ── 캣닢 경제 ──────────────────────────────────────────────────
# 캣닢은 시설 하나를 통째로 쓰면서 소비처가 부스트 하나뿐이었다.
# 츄르가 "출정 전 한 방"이라면 캣닢은 "쉘터 운영의 상시 비용"이다.
#
# 재굴림: 주민 특성은 이제 트레이드오프라 나쁜 조합이 나올 수 있다.
# 캣닢을 태워 다시 뽑는다. 뽑을수록 비싸져서 무한 리롤은 막는다.
# 리롤은 츄르로 지불한다 — 희귀 재화이므로 낮은 수치로 시작해 천천히 오른다.
const RESIDENT_REROLL_BASE_COST := 1
const RESIDENT_REROLL_STEP := 1
const RESIDENT_REROLL_MAX_COST := 5

const CATNIP_BOOST_COST := 900
const CATNIP_BOOST_DURATION_SECONDS := 600
const CATNIP_BOOST_MULTIPLIER := 10.0
const BASE_CATNIP_PER_WORKER_SECOND := 1.0
# ── 쉘터 오프라인 정산 상한 ────────────────────────────────────
# 연료 개념이 사라져 주민이 배치돼 있으면 라인은 항상 돈다. 대신 "자리를 비운
# 시간"에 상한을 둔다 — 예전 연료 게이지가 8시간을 '가득'으로 봤던 눈금을 그대로
# 시간 상한으로 옮긴 것. 껐다 켜서 하루치를 받는 일은 없다(러버밴딩 아님, 고정 상한).
const SHELTER_OFFLINE_MAX_SECONDS := 8 * 3600

# ── 통조림 = 훈련 재화 + 투척 소모품 ───────────────────────────
# '먹기'는 폐지됐다(유저 확정: "통조림은 먹는거 아님"). 회복은 구급약이 전담하고,
# 통조림은 훈련장 지불(쉘터 재고)과 필드 투척 유인(가방)만 맡는다.

# ── 문턱 해금 ──────────────────────────────────────────────────
#
# 수치가 5% 오르는 것으로는 강해졌다는 느낌이 안 난다. 인크리멘탈의
# 쾌감은 "어제 못 하던 것을 오늘 할 수 있다"에서 온다.
# 청사진과 키카드는 그동안 수집만 되고 아무 문도 열지 않았다.
# 여기서 실제 관문으로 만든다.
const MILESTONE_UNLOCKS := {
	# 제작 해금 문턱은 "설계도 조각 3/3"이다(requires_blueprint = 레시피 id).
	# 키(craft_rifle 등)는 옛 세이브의 unlocked_milestones와 호환되게 그대로 둔다.
	"craft_rifle": {
		"title": "기관단총 제작 해금",
		"body": "MP5 설계도 조각을 전부 맞췄다. 작업대에서 MP5를 만들 수 있다.",
		"requires_blueprint": "mp5",
	},
	"craft_akm": {
		"title": "AKM 개조 해금",
		"body": "AKM 설계도 조각을 전부 맞췄다. 작업대에서 AKM 개조형을 만들 수 있다 — AK의 강화를 60% 이어받는다.",
		"requires_blueprint": "akm",
	},
	"craft_pump": {
		"title": "펌프 산탄총 해금",
		"body": "펌프 산탄총 설계도 조각을 전부 맞췄다. 작업대에서 만들 수 있다 — 참치 헌터의 강화를 60% 이어받는다.",
		"requires_blueprint": "pump_shotgun",
	},
	"craft_shotgun": {
		"title": "산탄총 제작 해금",
		"body": "더블배럴 설계도 조각을 전부 맞췄다. 작업대에서 참치 헌터를 직접 만들 수 있다.",
		"requires_blueprint": "double_barrel",
	},
	"sealed_access": {
		"title": "봉인구역 개방",
		"body": "키카드를 확보했다. 잠겨 있던 구역의 문이 열린다.",
		"requires_progression": "sealed_zone_keycard",
	},
	"shelter_line": {
		"title": "생산 라인 가동",
		"body": "주민 세 명이 모였다. 쉘터가 스스로 돌아가기 시작한다.",
		"requires_residents": 3,
	},
	"veteran": {
		"title": "베테랑 정찰묘",
		"body": "보스를 세 번 넘겼다. 이제 이 도시에서 이름이 알려진다.",
		"requires_boss_kills": 3,
	},
}


# ── 츄르 출정 버프 ─────────────────────────────────────────────
# 츄르는 아껴두면 의미가 없다. 한 판을 확실히 바꾸는 소비처를 준다.
const CHURU_BUFFS := {
	"full_belly": {
		"title": "든든한 배",
		"short_title": "체력",
		"description": "이번 출정 동안 최대 체력 +25, 시작 체력 전부 회복",
		"cost": 1,
		"icon": "health",
	},
	"sharp_claws": {
		"title": "날 선 발톱",
		"short_title": "공격",
		"description": "이번 출정 동안 근접 피해 +40%, 스태미나 회복 +25%",
		"cost": 1,
		"icon": "stamina",
	},
	"big_pockets": {
		"title": "넉넉한 주머니",
		"short_title": "가방",
		"description": "이번 출정 동안 가방 슬롯 +4",
		"cost": 2,
		"icon": "loot",
	},
}

# 특성은 서열이 아니라 선택이어야 한다. 예전엔 전부 1.0 이상이라
# "누가 더 좋은가"만 있었고 어디에 넣을지 고민할 이유가 없었다.
# 이제 각자 잘하는 쪽과 못하는 쪽이 갈린다.
# (식비 appetite는 쉘터 연료 폐지와 함께 사라졌다 — 구 세이브의 값은 무시된다.)
const RESIDENT_TRAIT_PRESETS := [
	{"name": "말랑 앞발", "kneading": 1.55, "catnip": 0.70},
	{"name": "초록 코", "kneading": 0.68, "catnip": 1.60},
	{"name": "야무진 발톱", "kneading": 1.20, "catnip": 1.15},
	{"name": "밤샘 체질", "kneading": 1.10, "catnip": 1.10},
	{"name": "평범한 주민", "kneading": 1.00, "catnip": 1.00},
	# 연료(식비)가 폐지되면서 대식가/소식가의 트레이드오프가 사라졌다 — 대식가가
	# 순수 상위 특성이 되는 걸 막기 위해 '자리 비움(오프라인)' 규칙으로 대가를 둔다.
	# 대식가: 보는 사람 없으면 먹으러 간다 → 오프라인 생산 0.
	# 소식가: 꾸준하다 → 오프라인 누적 상한 8h 대신 16h.
	{
		"name": "대식가", "kneading": 1.75, "catnip": 1.70,
		"offline": 0.0, "quirk": "자리를 비우면 먹으러 간다 · 오프라인 생산 없음",
	},
	{
		"name": "소식가", "kneading": 0.82, "catnip": 0.82,
		"offline_cap_hours": 16, "quirk": "꾸준하다 · 자리를 비워도 16시간까지 쌓인다",
	},
]
const RESIDENT_NAME_POOL: Array[String] = [
	"보리", "두부", "호두", "감자", "밤이", "구름", "탄이", "콩이",
	"모카", "치즈", "소금", "후추", "달이", "별이", "봄이", "여름",
	"가을", "겨울", "라떼", "쿠키", "설탕", "참깨", "들깨", "누룽지",
	# "나비"는 주인공 이름이라 뺐다 — 주민 명단에 주인공과 같은 이름이 뜨면
	# 플레이어는 자기 자신이 두 명이 된 줄로 읽는다.
	"만두", "찹쌀", "팥이", "토리", "마루", "복실", "몽이",
	"뭉치", "초코", "우유", "크림", "연탄", "까미", "백설", "자두",
	"앵두", "매실", "도담", "다온", "하루", "새벽", "노을", "이슬",
	"단추", "양말", "꼬리", "수박", "참외", "호박", "미소", "단비",
]
const RESIDENT_PORTRAIT_COUNT := 5


func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if str(argument).begins_with("res://tests/"):
			persistence_enabled = false
			break
	load_persistent_state()
	if raid_serial == 0:
		randomize_map()
	process_shelter_progress()


func format_compact_number(value: float) -> String:
	var absolute_value := absf(value)
	var divisor := 1.0
	var suffix := ""
	if absolute_value >= 1_000_000_000_000.0:
		divisor = 1_000_000_000_000.0
		suffix = "T"
	elif absolute_value >= 1_000_000_000.0:
		divisor = 1_000_000_000.0
		suffix = "B"
	elif absolute_value >= 1_000_000.0:
		divisor = 1_000_000.0
		suffix = "M"
	elif absolute_value >= 1_000.0:
		divisor = 1_000.0
		suffix = "K"
	else:
		return str(roundi(value))

	var scaled := value / divisor
	var compact := "%.0f" % scaled if absf(scaled) >= 100.0 else "%.1f" % scaled
	if compact.ends_with(".0"):
		compact = compact.substr(0, compact.length() - 2)
	return compact + suffix


func randomize_map() -> void:
	raid_serial += 1
	var previous_seed := map_seed
	var time_mix := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	var candidate := absi(time_mix ^ (raid_serial * 104729) ^ (previous_seed * 31)) % 2_000_000_000
	if candidate == previous_seed:
		candidate = (candidate + 104729) % 2_000_000_000
	map_seed = candidate


func start_new_raid() -> void:
	process_shelter_progress()
	if (
		confirmed_raid_manifest.is_empty()
		or str(confirmed_raid_manifest.get("zone_id", "")) != selected_raid_zone
	):
		confirm_raid_loadout(selected_raid_zone)
	var corpse_zone := str(pending_corpse_recovery.get("raid_zone", ""))
	var corpse_seed := int(pending_corpse_recovery.get("map_seed", 0))
	if not pending_corpse_recovery.is_empty() and corpse_zone == selected_raid_zone and corpse_seed != 0:
		raid_serial += 1
		map_seed = corpse_seed
		corpse_recovery_attempt_active = true
	else:
		randomize_map()
		corpse_recovery_attempt_active = false
	world_time_hours = 9.0
	fatigue = 0.0
	reset_raid_supply_counters()
	save_persistent_state()


func reset_raid_supply_counters() -> void:
	raid_field_loot_value_generated = 0
	raid_enemy_loot_value_generated = 0
	raid_total_loot_value_generated = 0
	raid_weapon_drops_generated = 0
	raid_enemy_weapon_drops_generated = 0
	raid_enemy_drops_generated = 0
	raid_kills = 0
	raid_headshots = 0


func build_raid_loadout_manifest(zone_id: String = "") -> Dictionary:
	var resolved_zone := selected_raid_zone if zone_id.is_empty() else zone_id
	var weapon_id := equipped_weapon_id if has_ak and not equipped_weapon_id.is_empty() else ""
	var weapon_count := 0
	for count in weapon_inventory.values():
		weapon_count += maxi(0, int(count))
	var equipment_count := 0
	for count in equipment_inventory.values():
		equipment_count += maxi(0, int(count))
	for equipped_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipped_id.is_empty():
			equipment_count += 1
	var ammo_count := 0
	for count in ammo_inventory.values():
		ammo_count += maxi(0, int(count))
	var component_count := 0
	for count in mod_component_inventory.values():
		component_count += maxi(0, int(count))
	var mod_count := 0
	for count in weapon_mod_inventory.values():
		mod_count += maxi(0, int(count))
	return {
		"zone_id": resolved_zone,
		"weapon_id": weapon_id,
		"weapon_count": weapon_count,
		"magazine_ammo": magazine_ammo if not weapon_id.is_empty() else 0,
		"ammo_count": ammo_count,
		"medkits": maxi(0, medkits),
		"canned_food": maxi(0, canned_food),
		"component_count": component_count,
		"mod_count": mod_count,
		"equipment_count": equipment_count,
		"body_armor": equipped_body_armor_id,
		"head_armor": equipped_head_armor_id,
		"footwear": equipped_footwear_id,
		"storage_used": get_storage_used_slots(),
		"storage_capacity": get_storage_capacity(),
		"corpse_recovery": (
			not pending_corpse_recovery.is_empty()
			and str(pending_corpse_recovery.get("raid_zone", "")) == resolved_zone
		),
	}


func confirm_raid_loadout(zone_id: String = "") -> Dictionary:
	confirmed_raid_manifest = build_raid_loadout_manifest(zone_id)
	confirmed_raid_manifest["confirmed_at"] = int(Time.get_unix_time_from_system())
	save_persistent_state()
	return confirmed_raid_manifest.duplicate(true)


func clear_confirmed_raid_manifest() -> void:
	confirmed_raid_manifest.clear()


func set_subway_story_stage(stage: int) -> void:
	subway_story_stage = clampi(stage, 0, 3)
	save_persistent_state()


# ── 존별 메인 미션 체인 ────────────────────────────────────────


func get_main_mission_progress(zone_id: String) -> int:
	var total := MAIN_MISSION_CATALOG.get_stage_count(zone_id)
	return clampi(int(main_mission_progress.get(zone_id, 0)), 0, maxi(0, total))


func advance_main_mission(zone_id: String, completed_stage_index: int) -> int:
	# 같은 단계를 두 번 정산해도 진행도는 한 칸만 오른다 — 재도전으로 앞서
	# 갈 수 없다.
	var total := MAIN_MISSION_CATALOG.get_stage_count(zone_id)
	var next_progress := clampi(
		maxi(get_main_mission_progress(zone_id), completed_stage_index + 1), 0, maxi(0, total)
	)
	main_mission_progress[zone_id] = next_progress
	save_persistent_state()
	return next_progress


func is_zone_main_chain_complete(zone_id: String) -> bool:
	var total := MAIN_MISSION_CATALOG.get_stage_count(zone_id)
	return total > 0 and get_main_mission_progress(zone_id) >= total


func get_zone_unlock_hint(zone_id: String) -> String:
	# 다음 도시를 가리키면서 "아직 못 간다"만 말하면 벽이다. 무엇이 필요한지 붙인다.
	if is_raid_zone_unlocked(zone_id):
		return ""
	var required_tier := int((RAID_ZONES.get(zone_id, {}) as Dictionary).get("required_tier", 1))
	var needs: Array[String] = []
	if shelter_tier < required_tier:
		needs.append("쉘터 티어 %d" % required_tier)
	if required_tier >= 4 and get_progression_item_count("sealed_zone_keycard") <= 0:
		needs.append("봉인구역 키카드")
	if needs.is_empty():
		return ""
	return "아직 길이 막혀 있다 · 필요: %s" % " · ".join(needs)


func record_mission_choice(choice_id: String, option_id: String) -> void:
	if choice_id.is_empty():
		return
	mission_choices[choice_id] = option_id
	save_persistent_state()


func get_mission_choice(choice_id: String) -> String:
	return str(mission_choices.get(choice_id, ""))


func has_seen_field_cinematic(cinematic_id: String) -> bool:
	return seen_field_cinematics.has(cinematic_id)


func mark_field_cinematic_seen(cinematic_id: String) -> void:
	if cinematic_id.is_empty() or seen_field_cinematics.has(cinematic_id):
		return
	seen_field_cinematics.append(cinematic_id)
	save_persistent_state()


func ensure_story_key_items() -> Array[String]:
	# 안전망: 메인 미션 체인 단계를 끝냈는데 그 단계의 서사 키(쉘터 확장 키 등)가
	# 없는 세이브에 키를 보정 지급한다 — 키 도입 전 클리어한 구세이브, 시체와 함께
	# 분실한 경우. 키는 첫 회수에만 나와 두 번 받을 길이 없고, 없으면 티어가 영원히
	# 막히므로 "끝냈는데 없다"를 허용하지 않는다. 멱등 — 이미 있으면 아무것도 안 한다.
	# (이 파일은 requisition.gd를 preload하지 않는다 — 그 모듈이 GameState를 참조해
	#  autoload 초기화 전 컴파일 순환이 생긴다. 문구는 모듈, 지급은 여기.)
	var granted: Array[String] = []
	for zone_id in MAIN_MISSION_CATALOG.ZONE_ORDER:
		var progress := get_main_mission_progress(zone_id)
		for stage_index in progress:
			var stage := MAIN_MISSION_CATALOG.get_stage(zone_id, stage_index)
			var items := (stage.get("reward", {}) as Dictionary).get("progression_items", {}) as Dictionary
			for item_id in items.keys():
				# 장인의 인장은 돌파에 소모되는 재화라 "없음 = 잃음"이 아니다 — 보정 대상 제외.
				if str(item_id) == ARTISAN_SEAL_ID:
					continue
				if get_progression_item_count(str(item_id)) > 0:
					continue
				add_progression_item(str(item_id), maxi(1, int(items[item_id])))
				granted.append(str(item_id))
	return granted


func _migrate_main_mission_progress() -> void:
	# 구세이브 승격: 종로 1단계는 예전 "봉인 화물(잭팟)"이었다. 이미 화물을
	# 회수한 세이브는 그 단계를 끝낸 것으로 본다 — 안 그러면 다 깬 미션이
	# 처음부터 다시 뜬다.
	if (
		recovered_story_cargo_ids.has("seoul_line3_relief_core")
		and int(main_mission_progress.get("jongno_outskirts", 0)) < 1
	):
		main_mission_progress["jongno_outskirts"] = 1
	# 회수 목록에 이미 들어 있는 단계는 전부 완주로 승격한다(구세이브 일반화).
	for zone_id in MAIN_MISSION_CATALOG.ZONE_ORDER:
		var total := MAIN_MISSION_CATALOG.get_stage_count(zone_id)
		var progress := int(main_mission_progress.get(zone_id, 0))
		for stage_index in total:
			var stage := MAIN_MISSION_CATALOG.get_stage(str(zone_id), stage_index)
			var recovery_id := str((stage.get("recovery", {}) as Dictionary).get("id", ""))
			if recovered_story_cargo_ids.has(recovery_id):
				progress = maxi(progress, stage_index + 1)
		main_mission_progress[zone_id] = clampi(progress, 0, total)


# ── 시체 회수 압박 ─────────────────────────────────────────────
# 시체가 영원히 기다리면 회수 판은 그냥 한 판 더일 뿐이다. 다른 것들이
# 먼저 도착하기 시작하면, 회수는 "지금 가야 하는 일"이 된다.
const CORPSE_GRACE_RETURNS := 1        # 이 횟수까지는 온전히 남아 있다
const CORPSE_DECAY_PER_RETURN := 0.28  # 이후 복귀마다 이만큼씩 약탈당한다
const CORPSE_LOST_AFTER_RETURNS := 4   # 이만큼 지나면 아무것도 남지 않는다


func set_pending_corpse_recovery(data: Dictionary) -> void:
	pending_corpse_recovery = data.duplicate(true)
	pending_corpse_recovery["return_serial"] = shelter_return_serial
	corpse_recovery_attempt_active = false


func get_corpse_returns_elapsed() -> int:
	if pending_corpse_recovery.is_empty():
		return 0
	return maxi(
		0,
		shelter_return_serial - int(pending_corpse_recovery.get("return_serial", shelter_return_serial))
	)


func get_corpse_intact_ratio() -> float:
	# 1.0 = 온전함, 0.0 = 전부 사라짐.
	var elapsed := get_corpse_returns_elapsed()
	if elapsed <= CORPSE_GRACE_RETURNS:
		return 1.0
	var decayed := float(elapsed - CORPSE_GRACE_RETURNS) * CORPSE_DECAY_PER_RETURN
	return clampf(1.0 - decayed, 0.0, 1.0)


func get_corpse_returns_remaining() -> int:
	return maxi(0, CORPSE_LOST_AFTER_RETURNS - get_corpse_returns_elapsed())


func apply_corpse_decay() -> Dictionary:
	# 복귀할 때마다 호출한다. 남의 손을 탄 만큼 시체에서 물건이 사라진다.
	if pending_corpse_recovery.is_empty():
		return {}
	var elapsed := get_corpse_returns_elapsed()
	if elapsed >= CORPSE_LOST_AFTER_RETURNS:
		var lost := pending_corpse_recovery.duplicate(true)
		clear_pending_corpse_recovery()
		return {"status": "lost", "loot": lost}
	var ratio := get_corpse_intact_ratio()
	if ratio >= 1.0:
		return {"status": "intact"}
	var loot := pending_corpse_recovery.get("loot", {}) as Dictionary
	for scalar_key in ["medkits", "canned_food", "churu"]:
		loot[scalar_key] = int(floor(float(int(loot.get(scalar_key, 0))) * ratio))
	for inventory_key in [
		"ammo_inventory",
		"mod_component_inventory",
		"weapon_mod_inventory",
		"equipment_inventory",
	]:
		var inventory := loot.get(inventory_key, {}) as Dictionary
		for item_id in inventory.keys():
			inventory[item_id] = int(floor(float(int(inventory[item_id])) * ratio))
	# 청사진·키카드와 무기는 약탈자가 가장 먼저 노린다. 하지만 진행에
	# 필요한 물건이라 완전히 잃기 전까지는 남겨 둔다.
	pending_corpse_recovery["loot"] = loot
	return {"status": "decayed", "ratio": ratio}


func clear_pending_corpse_recovery() -> void:
	pending_corpse_recovery.clear()
	corpse_recovery_attempt_active = false


func build_carried_raid_loot() -> Dictionary:
	# 시체(회수 대상)에 가는 것 = 가방의 재료·탄약·소모품·귀중품뿐. 장비(무기·방어구·
	# 부착물)와 진행 아이템(조각·인장·키 = 0칸 쉘터 자산)은 영구 귀속이라 시체에
	# 들어가지 않는다(raid_loss_manager.build_death_corpse_loot와 같은 규칙).
	return {
		"ammo_inventory": ammo_inventory.duplicate(true),
		"medkits": maxi(0, medkits),
		"canned_food": get_backpack_storage_count("food", "canned_food"),
		"churu": maxi(0, churu),
		"mod_component_inventory": mod_component_inventory.duplicate(true),
		"progression_item_inventory": {},
		"weapon_mod_inventory": {},
		"weapon_inventory": {},
		"equipment_inventory": {},
		"equipped_weapon_id": "",
		"equipped_weapon_mods": [],
		"weapon_mod_loadouts": {},
		"raid_special_cargo": raid_special_cargo.duplicate(true),
	}


func store_carried_raid_loot_for_recovery(world_position: Vector3) -> Dictionary:
	var loot := build_carried_raid_loot()
	set_pending_corpse_recovery({
		"map_seed": map_seed,
		"raid_zone": selected_raid_zone,
		"position": [world_position.x, world_position.y, world_position.z],
		"loot": loot,
	})
	return loot


func clear_carried_raid_inventory_after_death() -> void:
	# ── 영구 귀속(2026-08 경제 코어) ──
	# 사망·판 포기에 잃는 것은 가방의 재료(부품)·탄약·구급약·통조림·츄르·귀중품뿐이다.
	# 무기·방어구(장착+보유)·부착물·강화·돌파·설계도 조각·인장·키는 전부 남는다 —
	# 장비는 필드에서 절대 안 나오고 제작으로만 생기므로, 잃는 순간 "다시 주워서 복구"가
	# 불가능하다. 전손이면 전투 위험이 항상 비합리적이라 "도망만 다니는" 플레이가 정답이
	# 된다(테스터 신고). 잃는 건 이번 판에 주운 것뿐 — 그래야 다음 판이 두려움이 아니라
	# 기대가 된다. 탄은 빈 상태(magazine/reserve 0)로 시작한다.
	for inventory in [ammo_inventory, mod_component_inventory]:
		for key in inventory.keys():
			inventory[key] = 0
	medkits = 0
	# 가방 통조림(이번 판에 주운 투척용)만 사라진다 — 쉘터 훈련 재고
	# (shelter_canned_food)는 필드에 나온 적이 없으므로 손대지 않는다.
	canned_food = 0
	churu = 0
	valuable_inventory.clear()
	valuable_value_ledger.clear()
	clear_churu_buffs()
	magazine_ammo = 0
	reserve_ammo = 0
	# 장착 상태·부착물·방어구는 손대지 않는다 — 총은 계속 손에 들려 있고 옷은 입은 채다.
	# 장착 무기가 없는(해제 상태) 세이브도 재고는 그대로라 다시 들면 된다.
	# secure_dog_items는 여기서 지우지 않는다 — 사망 정산이 끝난 뒤
	# restore_secure_items_after_death가 돌려주고 스스로 비운다.
	raid_special_cargo.clear()
	save_persistent_state()


func finish_corpse_recovery_attempt(recovered: bool = false) -> void:
	# 회수 판이 끝났다. 예전에는 무조건 시체 기록을 지워서, 시체 근처에
	# 가지도 않고 탈출한 판에서도 장비가 영구 소멸했다(회수 기회 1회 박탈).
	# 실제로 주웠을 때만 지운다 — 안 주웠으면 부패 규칙에 맡긴다.
	if not corpse_recovery_attempt_active:
		return
	if recovered:
		clear_pending_corpse_recovery()
	else:
		corpse_recovery_attempt_active = false


func apply_raid_abandonment() -> void:
	# 판 도중 강제 종료 후 재접속 — 추출 없이 나간 판은 '포기'다.
	# 사망과 같은 손실이되 회수할 시체가 없다: 강제 종료가 사망보다
	# 이득이 되는 순간 그게 정식 전략이 되기 때문이다.
	clear_carried_raid_inventory_after_death()
	var loss_manager := load("res://scripts/raid_loss_manager.gd")
	loss_manager.restore_secure_items_after_death()
	# 벌칙은 전리품 손실로 충분하다 — 쉘터에 있는 이상 체력은 가득.
	player_health = get_max_health()
	raid_in_progress = false
	# 무엇을 왜 잃었는지 반드시 말한다. 조용한 전손은 버그로 읽힌다.
	pending_abandonment_notice = true
	save_persistent_state()


func consume_abandonment_notice() -> bool:
	var had_notice := pending_abandonment_notice
	pending_abandonment_notice = false
	return had_notice


func register_shelter_return(survived: bool = true) -> void:
	shelter_return_serial += 1
	# 정상 경로(추출·사망 정산)로 돌아왔다 — 판 포기 감시 해제.
	raid_in_progress = false
	# 쉘터 복귀 = 완전 회복. 침대·수면 절차는 폐지됐다.
	player_health = get_max_health()
	if survived:
		survived_return_count += 1
		# 살아 돌아온 판만 정산한다. 사망 귀환은 이미 가방을 통째로 잃었다.
		last_return_settlement = settle_shelter_return_inventory()
	clear_confirmed_raid_manifest()
	# 츄르 버프는 한 판짜리다. 복귀와 동시에 사라진다.
	clear_churu_buffs()
	# 남겨 둔 시체는 그동안 남의 손을 탄다.
	last_corpse_decay_notice = apply_corpse_decay()
	pending_milestone_unlocks = check_milestone_unlocks()
	sync_shelter_progression_milestones()
	# 계약을 완주했다면 복귀마다 새 도시 의뢰를 내건다(후반 반복 목표).
	roll_city_commission()
	save_persistent_state()


# ── 복귀 정산 ─────────────────────────────────────────────────
# 복귀는 "가방을 든 채 쉘터에 서 있는 것"이 아니라 정산이다. 필드에서 주운
# 것들이 다음 출정 가방을 그대로 좀먹으면, 매 판 시작이 정리 작업이 된다.
# 재료·부착물·진행품·여분 장비 → 창고, 귀중품 → 고철.
# 탄약·구급약은 가방에 남긴다: 다음 출정의 준비물이고, 창고 인출 UI를 매판
# 거치게 만드는 건 순수한 마찰이다. 통조림만 예외로 쉘터 재고로 귀속된다 —
# 훈련 재화이기 때문이다(가방에 두면 다음 판 사망에 훈련 저축이 통째로 날아간다).
func settle_shelter_return_inventory() -> Dictionary:
	var report := {
		"food": 0,
		"stored": 0,
		"overflow": 0,
		"valuable_count": 0,
		"valuable_scrap": 0,
	}
	# 1) 통조림 → 쉘터 훈련 재고. 가방 통조림은 필드 투척용이고, 돌아오면 훈련
	#    비용이 된다. 다음 판 투척분은 필드에서 다시 줍는다(판당 15~25개).
	report["food"] = maxi(0, canned_food)
	shelter_canned_food = maxi(0, shelter_canned_food + maxi(0, canned_food))
	canned_food = 0
	# 2) 귀중품: 용도가 없는 물건이다. 쉘터에 오는 순간이 곧 환전이다.
	var valuable_result := sell_all_valuables()
	report["valuable_count"] = int(valuable_result.get("count", 0))
	report["valuable_scrap"] = int(valuable_result.get("scrap", 0))
	# 2.5) 잉여 장비 → 부품. 창고 입고 전에 한다 — 잉여가 창고 칸을 먹은 뒤
	#    분해하면 그 칸만큼 다른 물건이 넘쳤다고 거짓 보고하게 된다. 나온 부품은
	#    가방에 들어가 바로 아래 3)에서 다른 부품과 함께 창고로 간다.
	var salvage := salvage_surplus_equipment()
	report["salvaged_items"] = int(salvage.get("items", 0))
	report["salvaged_components"] = int(salvage.get("components", 0))
	# 3) 나머지 소지품은 창고로. 무기·방어구는 옮기지 않는다 — 영구 귀속 장비는 가방
	#    칸을 안 먹고(0칸) 몸에 딸린 것이라, 창고 왕복은 장착 교체를 방해하는 마찰일
	#    뿐이다(구세이브가 창고에 넣어 둔 장비는 그대로 꺼낼 수 있다).
	var settlement_targets: Array = [
		["component", mod_component_inventory],
		["mod", weapon_mod_inventory],
		["progression", progression_item_inventory],
	]
	for target in settlement_targets:
		var item_type := str(target[0])
		var inventory := target[1] as Dictionary
		for item_id_value in inventory.keys():
			var item_id := str(item_id_value)
			var carried := get_backpack_storage_count(item_type, item_id)
			if carried <= 0:
				continue
			var result := deposit_storage_item(item_type, item_id, carried, false)
			var moved := int(result.get("moved", 0))
			report["stored"] = int(report["stored"]) + moved
			# 창고가 모자라면 넘치는 만큼만 가방에 남는다. 조용히 버리지 않는다.
			report["overflow"] = int(report["overflow"]) + (carried - moved)
	save_persistent_state()
	return report


# ── 잉여 장비 분해(구세이브 정리 전용) ───────────────────────────
# 장비는 제작 전용·1개 영구(보유 중이면 같은 레시피 재제작 불가)라 같은 id가 2개
# 이상 생길 길이 없다. 이 함수는 옛 드랍 시절에 쌓인 중복만 정리한다:
#   · 같은 id(레벨 접미사까지 같은 정확한 id)가 가방+창고+장착 합쳐 2개 이상이면
#     1개만 남기고 부품으로(장착분은 절대 건드리지 않는다).
#   · 다른 id(상위 가족·다른 레벨)는 전부 각자의 영구 장비 — 손대지 않는다.
#   · 부품 수: 방어구 가족 T1 1 / T2 2 / T3 3, 무기는 사다리 단계 1/2/3(밖은 1).
#     종류는 패킹→스프링→렌즈 순환.
#   · 부품은 가방(mod_component_inventory)에 넣는다 — 이어지는 창고 정산이 입고한다.
# 귀환 정산이 여전히 부르지만 보통은 0점으로 끝난다.
const SALVAGE_COMPONENT_CYCLE := ["rubber_gasket", "magazine_spring", "scope_lens"]


func salvage_surplus_equipment() -> Dictionary:
	var report := {"items": 0, "components": 0, "armor_items": 0, "weapon_items": 0, "details": []}
	var cycle_index := 0
	# 1) 방어구 — 정확히 같은 id의 중복만.
	var owned_armor: Dictionary = {}
	for equipment_id_value in equipment_inventory.keys():
		var equipment_id := str(equipment_id_value)
		var count := get_equipment_count(equipment_id)
		if count > 0:
			owned_armor[equipment_id] = int(owned_armor.get(equipment_id, 0)) + count
	for entry in storage_inventory:
		if str(entry.get("type", "")) != "equipment":
			continue
		var equipment_id := str(entry.get("id", ""))
		owned_armor[equipment_id] = int(owned_armor.get(equipment_id, 0)) + maxi(0, int(entry.get("count", 0)))
	for equipment_id_value in owned_armor.keys():
		var equipment_id := str(equipment_id_value)
		if get_equipment_definition(equipment_id).is_empty():
			continue
		var equipped := equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]
		# 장착 중이면 예비는 전부 잉여, 아니면 예비 중 1개를 남긴다.
		var keep := 0 if equipped else 1
		var surplus := int(owned_armor.get(equipment_id, 0)) - keep
		if surplus <= 0:
			continue
		var removed := _take_owned_item_units("equipment", equipment_id, surplus)
		if removed <= 0:
			continue
		var yield_per_unit := _salvage_armor_family_index(equipment_id) + 1
		var produced := 0
		for _unit in removed:
			for _part in yield_per_unit:
				add_mod_component(SALVAGE_COMPONENT_CYCLE[cycle_index % SALVAGE_COMPONENT_CYCLE.size()], 1)
				cycle_index += 1
				produced += 1
		report["items"] = int(report["items"]) + removed
		report["armor_items"] = int(report["armor_items"]) + removed
		report["components"] = int(report["components"]) + produced
		(report["details"] as Array).append({"type": "equipment", "id": equipment_id, "count": removed, "components": produced})
	# 2) 무기 — 같은 id가 장착분 포함 2정 이상이면 1정 남긴다(사다리 밖 기종도 포함:
	#    무기는 전부 제작 전용 1정 영구라 중복은 정리 대상이다).
	for weapon_id_value in WEAPON_SYSTEM.WEAPONS.keys():
		var weapon_id := str(weapon_id_value)
		var total := int(weapon_inventory.get(weapon_id, 0)) + get_stored_storage_count("weapon", weapon_id)
		if total <= 1:
			continue
		var removed := _take_owned_item_units("weapon", weapon_id, total - 1)
		if removed <= 0:
			continue
		var ladder_index := 0
		var family_id := WEAPON_SYSTEM.get_weapon_family(weapon_id)
		if not family_id.is_empty():
			ladder_index = maxi(0, (WEAPON_SYSTEM.WEAPON_FAMILY_LADDER[family_id] as Array).find(weapon_id))
		var produced := 0
		for _unit in removed:
			for _part in ladder_index + 1:
				add_mod_component(SALVAGE_COMPONENT_CYCLE[cycle_index % SALVAGE_COMPONENT_CYCLE.size()], 1)
				cycle_index += 1
				produced += 1
		report["items"] = int(report["items"]) + removed
		report["weapon_items"] = int(report["weapon_items"]) + removed
		report["components"] = int(report["components"]) + produced
		(report["details"] as Array).append({"type": "weapon", "id": weapon_id, "count": removed, "components": produced})
	return report


func _salvage_armor_family_index(equipment_id: String) -> int:
	# ARMOR_FAMILIES 인덱스(0=생존자 T1 · 1=진압 T2 · 2=군납 T3). 모르는 id는 T1 취급.
	var base_id := str(split_equipment_id(equipment_id)[0])
	for index in LOOT_ECONOMY.ARMOR_FAMILIES.size():
		if (LOOT_ECONOMY.ARMOR_FAMILIES[index] as Array).has(base_id):
			return index
	return 0


func _take_owned_item_units(item_type: String, item_id: String, amount: int) -> int:
	# 가방(장착분 제외) → 창고 순으로 amount만큼 덜어낸다. 실제로 덜어낸 수를 돌려준다.
	var remaining := maxi(0, amount)
	var removed := 0
	var from_bag := mini(remaining, get_backpack_storage_count(item_type, item_id))
	if from_bag > 0 and _remove_backpack_storage_item(item_type, item_id, from_bag):
		removed += from_bag
		remaining -= from_bag
	for slot_index in range(storage_inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var entry := storage_inventory[slot_index]
		if str(entry.get("type", "")) != item_type or str(entry.get("id", "")) != item_id:
			continue
		var take := mini(remaining, maxi(0, int(entry.get("count", 0))))
		if take <= 0:
			continue
		entry["count"] = int(entry.get("count", 0)) - take
		remaining -= take
		removed += take
		if int(entry.get("count", 0)) <= 0:
			storage_inventory.remove_at(slot_index)
	return removed


func consume_return_settlement() -> Dictionary:
	var settlement := last_return_settlement.duplicate(true)
	last_return_settlement.clear()
	return settlement


func consume_milestone_unlocks() -> Array[Dictionary]:
	var unlocks := pending_milestone_unlocks.duplicate(true)
	pending_milestone_unlocks.clear()
	return unlocks


func consume_corpse_decay_notice() -> Dictionary:
	var notice := last_corpse_decay_notice.duplicate(true)
	last_corpse_decay_notice.clear()
	return notice


func is_saja_available() -> bool:
	return opening_completed


func is_contract_agent_available() -> bool:
	return shelter_return_serial >= CONTRACT_AGENT_UNLOCK_RETURN


func is_iron_trainer_available() -> bool:
	return is_contract_agent_available()


func get_shelter_facility_name(facility_id: String) -> String:
	return str(SHELTER_FACILITY_NAMES_V2.get(facility_id, facility_id))


func is_shelter_facility_unlocked(facility_id: String) -> bool:
	return bool(shelter_facility_unlocks.get(facility_id, false))


func unlock_shelter_facility(facility_id: String) -> bool:
	if not SHELTER_FACILITY_NAMES.has(facility_id):
		return false
	var was_unlocked := is_shelter_facility_unlocked(facility_id)
	shelter_facility_unlocks[facility_id] = true
	return not was_unlocked


func unlock_all_shelter_facilities() -> void:
	for facility_id in SHELTER_FACILITY_NAMES.keys():
		shelter_facility_unlocks[str(facility_id)] = true


func sync_shelter_progression_milestones() -> Array[String]:
	var newly_unlocked: Array[String] = []
	shelter_facility_unlocks["bed"] = true
	# 창고는 처음부터 연다. 사망하면 "창고에 넣어둔 것만" 살아남는데, 예전에는
	# 창고가 첫 복귀 뒤에 열려서 첫 출정에서 죽은 신규 플레이어는 완충 장치가
	# 존재하지도 않는 상태로 전부 잃었다. 배우기 전의 실패는 학습이 아니라 벌이다.
	if unlock_shelter_facility("storage"):
		newly_unlocked.append("storage")
	# 훈련장은 철근이 등장하는 첫 복귀 이후 그대로 둔다.
	if is_contract_agent_available():
		if unlock_shelter_facility("training"):
			newly_unlocked.append("training")
	for contract_value in SAJA_FACILITY_CONTRACTS:
		var contract := contract_value as Dictionary
		if not completed_contract_ids.has(str(contract.get("id", ""))):
			continue
		var facility_id := str(contract.get("facility_unlock", ""))
		if not facility_id.is_empty() and unlock_shelter_facility(facility_id):
			newly_unlocked.append(facility_id)
	return newly_unlocked


func get_pending_shelter_story_event() -> Dictionary:
	if not opening_completed:
		return {}
	if not saja_intro_seen:
		return {
			"id": "saja_intro",
			"speaker": "사자",
			"title": "빈 쉘터의 지킴이",
			"lines": [
				"멈춰. 발소리만으로 넌 벌써 반쯤 읽혔다.",
				"난 사자. 인간이 사라진 그날부터, 아무도 돌아오지 않는 이 쉘터를 지켜 왔지.",
				"그날 무슨 일이 있었는지는 나도 몰라. 도시는 하룻밤 새 비었고, 문들은 안에서 잠겼다.",
				"혼자로는 여기까지였어. 너는 밖을 읽어 오고, 나는 돌아올 자리를 지킨다.",
				"우선 쉬어. 네가 가져오는 조각들이, 이 침묵이 무엇을 숨겼는지 한 겹씩 말해 줄 거다.",
			],
		}
	if survived_return_count >= 1 and not saja_second_run_intro_seen:
		return {
			"id": "saja_second_run",
			"speaker": "사자",
			"title": "쉘터가 움직이기 시작했다",
			"lines": [
				"제 발로 돌아왔군. 살아 돌아온 자에게만 이 아래의 문이 하나씩 열린다.",
				"창고와 체력 훈련장을 풀었다. 전리품은 창고에 남기고, 통조림은 네 몸에 투자해.",
				# 필드에 캣닢 픽업이 없다 — 없는 것을 찾게 만드는 대사는 뺐다.
				"도시의 고철 더미를 그냥 지나치지 마. 그 부스러기가 이 쉘터의 심장을 돌린다.",
				"저 근육 덩어리에게 특별 훈련을 받아. 시설 공사는 내 몫이다.",
				"오늘은 행상인도 파이프 곁을 맴돌 거다. 들일지는 네가 정해.",
				"내 계약을 하나씩 풀 때마다, 이 도시가 왜 이렇게 됐는지도 한 겹씩 벗겨질 거다.",
			],
		}
	# 부품을 처음 들고 온 순간이 제작대를 가르칠 유일한 적기다. "스프링을 주웠는데
	# 팔 것밖에 없다"는 인상이 생기기 전에, 부품→개조→강화 루프를 사자가 짚어 준다.
	if (
		not workbench_lesson_seen
		and not is_tutorial_step_done("workbench_craft")
		and is_shelter_facility_unlocked("workbench")
		and _count_total_mod_components() > 0
	):
		return {
			"id": "saja_workbench",
			"speaker": "사자",
			"title": "쇳내 나는 가방",
			"lines": [
				"가방에서 쇳내가 난다. 스프링, 렌즈, 고무… 그거 행상인에게 팔 생각부터 하지 마라.",
				"작업대로 가져가. 부품 몇 개면 조준경이 되고, 스프링은 급탄 개조가 된다.",
				"만든 개조품은 무기에 끼워라. 같은 총이라도 전혀 다른 물건이 된다.",
				"고철이 남아돌면 작업대에서 무기 영구 강화도 된다. 도시에서 주워 온 모든 것에는 자리가 있어.",
			],
		}
	if rescued_workers > saja_seen_resident_count:
		return {
			"id": "saja_resident_%d" % rescued_workers,
			"speaker": "사자",
			"title": "새 식구",
			"lines": [
				"뒤에 달고 온 고양이, 끝까지 놓지 않았군.",
				"여기선 구조된 자도 이름과 몫을 가진다. 숫자가 아니라 식구야.",
				"숨 돌리게 두었다가 생산기에 세워. 살아남은 자가 하나 늘 때마다, 우리가 틀리지 않았다는 증거도 하나 늘지.",
			],
		}
	if total_boss_kills > saja_seen_boss_kills:
		return {
			"id": "saja_boss_%d" % total_boss_kills,
			"speaker": "사자",
			"title": "도시가 이름을 기억한다",
			"lines": [
				"밖이 시끄럽더니, 도시가 이름 붙인 놈을 네가 지웠다더군.",
				"이름을 가진 것들은 그냥 짐승이 아니야. 누군가 그들에게 자리를 내줬다는 뜻이다.",
				"빈자리는 반드시 채워진다. 다음 출정은 같은 길이어도, 주인이 바뀌어 있을 거야.",
			],
		}
	if recovered_story_cargo_ids.size() > saja_seen_story_cargo_count:
		return {
			"id": "saja_cargo_%d" % recovered_story_cargo_ids.size(),
			"speaker": "사자",
			"title": "검게 지워진 화물표",
			"lines": [
				"이 표식… 오래전 사라진 운송대의 것이다. 그런데 잉크가 아직 마르지 않았어.",
				"누군가 죽은 기록 위에 다시 덧칠하고 있다. 대체 무엇을, 왜 지우려는 걸까.",
				"주홍이라는 고양이가 같은 표식을 쫓아. 붉은 앞치마를 보거든, 칼보다 귀를 먼저 열어.",
			],
		}
	# 한 구역의 메인 미션 셋을 다 끝냈으면 사자가 다음 도시를 가리킨다.
	# 흔적이 끊긴 자리에서 유저를 세워 두지 않는다.
	for zone_id in MAIN_MISSION_CATALOG.ZONE_ORDER:
		var chain_zone_id := str(zone_id)
		if not is_zone_main_chain_complete(chain_zone_id):
			continue
		if saja_seen_main_mission_zones.has(chain_zone_id):
			continue
		var zone_name := str((RAID_ZONES.get(chain_zone_id, {}) as Dictionary).get("name", "그 구역"))
		var next_zone_id := MAIN_MISSION_CATALOG.get_next_zone(chain_zone_id)
		var closing_lines: Array[String] = [
			"%s에서 가져온 기록, 전부 읽었다. 거기서 나올 건 더 없어." % zone_name,
			"기록을 남긴 손은 한 방향으로만 움직였다. 끝이 아니라 이어지는 선이야.",
		]
		if next_zone_id.is_empty():
			closing_lines.append("그 선의 끝이 여기다. 이제 남은 건 문 뒤를 직접 보는 일뿐이다.")
		else:
			var next_name := str(
				(RAID_ZONES.get(next_zone_id, {}) as Dictionary).get("name", "다음 구역")
			)
			closing_lines.append("다음은 %s. 같은 필체가 거기서 다시 시작한다." % next_name)
			var hint := get_zone_unlock_hint(next_zone_id)
			if not hint.is_empty():
				closing_lines.append("%s 준비가 되기 전엔 문이 안 열려." % hint)
		return {
			"id": "saja_main_chain_%s" % chain_zone_id,
			"speaker": "사자",
			"title": "끊긴 흔적",
			"lines": closing_lines,
		}
	if subway_story_stage > saja_seen_subway_stage:
		return {
			"id": "saja_subway_%d" % subway_story_stage,
			"speaker": "사자",
			"title": "지하에서 올라온 신호",
			"lines": [
				"지하철 쪽 신호가 다시 뛴다. 인간의 설비가 저 혼자 깨어날 리 없지.",
				"누군가 서울의 오래된 맥박을 손으로 되짚고 있어. 살아남은 자인지, 남겨진 것인지는 나도 몰라.",
				"주홍이 먼저 아래를 훑고 있을 거다. 만나면 끝까지 들어 — 우리가 모르는 이야기를 그 아이는 안다.",
			],
		}
	return {}


func mark_shelter_story_event_seen(event_id: String) -> void:
	if event_id == "saja_intro":
		saja_intro_seen = true
	elif event_id == "saja_second_run":
		saja_second_run_intro_seen = true
	elif event_id == "saja_workbench":
		workbench_lesson_seen = true
	elif event_id.begins_with("saja_resident_"):
		saja_seen_resident_count = rescued_workers
	elif event_id.begins_with("saja_boss_"):
		saja_seen_boss_kills = total_boss_kills
	elif event_id.begins_with("saja_cargo_"):
		saja_seen_story_cargo_count = recovered_story_cargo_ids.size()
	elif event_id.begins_with("saja_subway_"):
		saja_seen_subway_stage = subway_story_stage
	elif event_id.begins_with("saja_main_chain_"):
		var chain_zone_id := event_id.trim_prefix("saja_main_chain_")
		if not saja_seen_main_mission_zones.has(chain_zone_id):
			saja_seen_main_mission_zones.append(chain_zone_id)
	save_persistent_state()


func get_pending_juhong_event() -> Dictionary:
	if recovered_story_cargo_ids.size() > 0 and not juhong_seen_events.has("cargo_warning"):
		return {
			"id": "cargo_warning",
			"speaker": "주홍",
			"title": "붉은 앞치마의 방문자",
			"lines": [
				"그 화물표, 어디서 났지. …됐어, 표정 보니 훔친 건 아니군.",
				"인간이 사라지던 날, 봉쇄선 안쪽으로 들어간 운송대가 있었어. 나온 기록은 없다.",
				"네가 주운 건 그들이 흘린 부스러기야. 조각이 모이면, 그날의 진짜 이야기가 보일 거다.",
				"난 주홍. 오래 머물진 않아. 신호가 움직이면, 나도 움직이지.",
			],
		}
	if subway_story_stage >= 1 and not juhong_seen_events.has("subway_signal"):
		return {
			"id": "subway_signal",
			"speaker": "주홍",
			"title": "지하의 목소리",
			"lines": [
				"지하 신호, 너도 들었지. 구조 요청 같지만… 같은 문장이 한 치도 안 틀리고 반복돼.",
				"산 자의 목소리가 아니야. 누가 그걸 틀어 두고, 고양이들을 아래로 부르고 있다.",
				"그래도 내려가야 해. 누가, 무엇을 위해 그 목소리를 남겼는지 — 그게 이 도시의 비밀이니까.",
			],
		}
	if total_boss_kills >= 1 and not juhong_seen_events.has("boss_vacancy"):
		return {
			"id": "boss_vacancy",
			"speaker": "주홍",
			"title": "빈 왕좌",
			"lines": [
				"네가 비운 왕좌로 벌써 다른 무리가 기어들고 있어.",
				"우리가 강해진 게 아니야. 도시의 균형을 건드린 거지. 그 차이를 잊으면 오래 못 가.",
				"싸우기 전에 누가 누구를 미워하는지부터 읽어. 총알보다 오래 가는 무기다.",
			],
		}
	return {}


func mark_juhong_event_seen(event_id: String) -> void:
	if not event_id.is_empty() and not juhong_seen_events.has(event_id):
		juhong_seen_events.append(event_id)
	save_persistent_state()


func register_boss_defeat() -> void:
	total_boss_kills += 1
	advance_iron_special_mission("boss", 1)
	save_persistent_state()


func get_raid_zone(zone_id: String = "") -> Dictionary:
	var resolved_id := selected_raid_zone if zone_id.is_empty() else zone_id
	var result := (
		RAID_ZONES.get(resolved_id, RAID_ZONES["jongno_outskirts"]) as Dictionary
	).duplicate(true)
	result.merge(RAID_REGION_CATALOG.get_profile(resolved_id), true)
	return result


func get_raid_zone_ids() -> Array[String]:
	var result: Array[String] = []
	for zone_id in RAID_ZONES.keys():
		result.append(str(zone_id))
	result.sort_custom(func(a: String, b: String) -> bool:
		return int((RAID_ZONES[a] as Dictionary).get("required_tier", 1)) < int((RAID_ZONES[b] as Dictionary).get("required_tier", 1))
	)
	return result


func is_raid_zone_unlocked(zone_id: String) -> bool:
	if not RAID_ZONES.has(zone_id):
		return false
	var required_tier := int((RAID_ZONES[zone_id] as Dictionary).get("required_tier", 1))
	if shelter_tier < required_tier:
		return false
	if required_tier >= 4 and get_progression_item_count("sealed_zone_keycard") <= 0:
		return false
	return true


func select_raid_zone(zone_id: String) -> bool:
	if not is_raid_zone_unlocked(zone_id):
		return false
	selected_raid_zone = zone_id
	save_persistent_state()
	return true


# 떠돌이 상인은 약속을 하지 않는다. 매 복귀 65%만 찾아온다(35%는 헛걸음).
# 늘 있는 상점이면 그건 상인이 아니라 자판기다 — 왔을 때 사 두는 판단이 생긴다.
func roll_merchant_visit(chance: float = 0.65) -> bool:
	merchant_missed_visit = false
	# 같은 귀환 안에서는 다시 굴리지 않는다 — 이미 와 있으면(대기/입장) 그대로.
	if merchant_last_roll_serial == shelter_return_serial:
		return merchant_status == "inside" or merchant_status == "waiting"
	if shelter_return_serial <= 0:
		return false
	merchant_last_roll_serial = shelter_return_serial
	# 새 귀환 = 지난 방문은 끝났다. 예전엔 한 번 들어온 상인이 영영 'inside'로
	# 남아 매대가 다시 짜이지 않았다 — 탄약을 한 번 사 가면 그 뒤로는 빈 매대만
	# 보여서 "상인이 물건을 안 판다"(유저 신고). 상인은 판 사이에 떠났다가
	# 확률로 다시 온다. 그래야 '이번 방문에 사야 할 이유'와 '안 오는 날'이 산다.
	merchant_status = "away"
	if shelter_return_serial == 1:
		merchant_status = "waiting"
		roll_merchant_stock()
		save_persistent_state()
		return true
	var random := RandomNumberGenerator.new()
	random.seed = int(map_seed) ^ (shelter_return_serial * 982451653) ^ 0x4D455243
	if random.randf() <= clampf(chance, 0.0, 1.0):
		merchant_status = "waiting"
		roll_merchant_stock()
		save_persistent_state()
		return true
	merchant_missed_visit = true
	merchant_stock.clear()
	save_persistent_state()
	return false


func roll_merchant_stock() -> Array[Dictionary]:
	# 방문마다 매대를 새로 짠다. 고정 매대는 "언제든 살 수 있다"는 뜻이라
	# 지금 사야 할 이유가 없다. 탄약 2~3종 + 잡화 2~3종, 각 품목에 재고가 있다.
	var random := RandomNumberGenerator.new()
	random.seed = (
		int(map_seed)
		^ (maxi(1, shelter_return_serial) * 2654435761)
		^ 0x53544F4B
	)
	var rolled: Array[Dictionary] = []
	# 장착 구경은 60% 확률로 매대에 오른다 — 상인이 유일한 "확정" 보급선이라
	# 내 총알을 아예 안 파는 방문이 이어지면 탄약 경제가 막힌다.
	var ammo_pool: Array = MERCHANT_AMMO_GOODS.duplicate(true)
	var equipped_index := -1
	for index in ammo_pool.size():
		if str((ammo_pool[index] as Dictionary).get("id", "")) == equipped_ammo_id:
			equipped_index = index
			break
	if equipped_index >= 0 and random.randf() < 0.6:
		rolled.append(_make_merchant_stock_entry(ammo_pool[equipped_index] as Dictionary, random))
		ammo_pool.remove_at(equipped_index)
	var ammo_slots := 2 + random.randi_range(0, 1) - rolled.size()
	for _slot in maxi(0, ammo_slots):
		if ammo_pool.is_empty():
			break
		var pick := random.randi_range(0, ammo_pool.size() - 1)
		rolled.append(_make_merchant_stock_entry(ammo_pool[pick] as Dictionary, random))
		ammo_pool.remove_at(pick)
	var sundry_pool: Array = MERCHANT_SUNDRY_GOODS.duplicate(true)
	for _slot in 2 + random.randi_range(0, 1):
		if sundry_pool.is_empty():
			break
		var pick := random.randi_range(0, sundry_pool.size() - 1)
		rolled.append(_make_merchant_stock_entry(sundry_pool[pick] as Dictionary, random))
		sundry_pool.remove_at(pick)
	merchant_stock = rolled
	return merchant_stock


func _make_merchant_stock_entry(good: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var entry := good.duplicate(true)
	var low := int(good.get("stock_min", 1))
	var high := maxi(low, int(good.get("stock_max", 1)))
	var stock := random.randi_range(low, high)
	entry["stock"] = stock
	entry["stock_total"] = stock
	return entry


func settle_merchant_sale(price: int) -> int:
	# 상인 매입 대가(고철) 입금. UI는 장부를 만지지 않는다 — 구매(buy_merchant_stock)와
	# 같은 규약. 가격은 MERCHANT_SELL_GOODS.sell_scrap에서만 온다.
	var paid := maxi(0, price)
	scrap += paid
	save_persistent_state()
	return paid


func buy_merchant_stock(stock_index: int) -> Dictionary:
	# 재고는 방문 한 번의 몫이다. 다 팔리면 그 방문에서는 끝이다.
	if stock_index < 0 or stock_index >= merchant_stock.size():
		return {"ok": false, "reason": "그 물건은 이미 매대에서 내려갔습니다."}
	var entry := merchant_stock[stock_index]
	if int(entry.get("stock", 0)) <= 0:
		return {"ok": false, "reason": "품절입니다."}
	var price := int(entry.get("buy_price", 0))
	if scrap < price:
		return {"ok": false, "reason": "고철이 부족합니다."}
	scrap -= price
	entry["stock"] = int(entry.get("stock", 0)) - 1
	save_persistent_state()
	return {
		"ok": true,
		"type": str(entry.get("type", "")),
		"id": str(entry.get("id", "")),
		"amount": int(entry.get("amount", 1)),
		"title": str(entry.get("title", "")),
	}


func accept_merchant_visit() -> void:
	merchant_status = "inside"
	# 구세이브(매대 개념이 없던 시절)에서 넘어왔거나 재고 기록이 비었으면 지금 굴린다.
	if merchant_stock.is_empty():
		roll_merchant_stock()


func decline_merchant_visit() -> void:
	merchant_status = "away"
	merchant_decline_count += 1
	# 돌려보낸 상인은 매대를 그대로 지고 떠난다.
	merchant_stock.clear()


func consume_merchant_missed_notice() -> bool:
	var missed := merchant_missed_visit
	merchant_missed_visit = false
	return missed


func get_secure_slot_count() -> int:
	# 시큐어 슬롯 수의 단일 지점 — 츄르로 산 칸(secure_dog_slots, 최대 3) + 방어구 돌파 +90 보너스.
	return secure_dog_slots + (ARMOR_PERK_SECURE_SLOT_BONUS if has_armor_breakthrough_perk(90) else 0)


func store_secure_item(item: Dictionary) -> bool:
	if secure_dog_items.size() >= get_secure_slot_count():
		return false
	secure_dog_items.append(item.duplicate(true))
	return true


func get_storage_grid_size() -> Vector2i:
	return STORAGE_GRID_BY_LEVEL.get(storage_level, STORAGE_GRID_BY_LEVEL[1])


func get_storage_capacity() -> int:
	var grid_size := get_storage_grid_size()
	return grid_size.x * grid_size.y


func get_storage_used_slots() -> int:
	_normalize_storage_inventory()
	return storage_inventory.size()


func get_storage_upgrade_cost() -> Dictionary:
	return (STORAGE_UPGRADE_COSTS.get(storage_level + 1, {}) as Dictionary).duplicate(true)


func try_upgrade_storage() -> bool:
	var next_level := storage_level + 1
	var cost := STORAGE_UPGRADE_COSTS.get(next_level, {}) as Dictionary
	if cost.is_empty():
		return false
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	if scrap < scrap_cost or churu < churu_cost:
		return false
	scrap -= scrap_cost
	churu -= churu_cost
	storage_level = next_level
	save_persistent_state()
	return true


func get_backpack_storage_count(item_type: String, item_id: String) -> int:
	match item_type:
		"weapon":
			var count := int(weapon_inventory.get(item_id, 0))
			if has_ak and equipped_weapon_id == item_id:
				count -= 1
			return maxi(0, count)
		"equipment":
			return get_equipment_count(item_id)
		"ammo":
			return get_ammo_count(item_id)
		"component":
			return get_mod_component_count(item_id)
		"mod":
			# 총에 박아 넣은 부착물은 총의 일부다 — 가방 칸을 먹지 않는다.
			var mod_count := get_weapon_mod_count(item_id)
			if equipped_weapon_mods.has(item_id):
				mod_count -= 1
			return maxi(0, mod_count)
		"medkit":
			return medkits
		"progression":
			# 창고에 넣은 진행 아이템은 가방 몫이 아니다 — 원장(dict)만 센다.
			# (가방 '칸'은 안 먹는다 — get_raid_item_slot_cost에서 0으로 친다.)
			return maxi(0, int(progression_item_inventory.get(item_id, 0)))
		"food":
			# 통조림은 창고에 안 들어간다 — canned_food가 곧 가방 몫(투척용)이다.
			# 훈련에 쓰는 쉘터 재고는 shelter_canned_food로 따로 산다.
			return maxi(0, canned_food)
	return 0


# ── 인크리멘탈 사다리 ────────────────────────────────────────────
# 인크리멘탈 게임의 핵심 문법: 화폐마다 "다음에 살 것"이 항상 보이고, 비용은
# 점증하며, 생산 건물은 자기 강화를 판다(복리). 고철=가방·오버클럭,
# 캣닢=농축, 츄르=시큐어·티어.
var bag_capacity_level: int = 0
var scratcher_overclock_level: int = 0
var catnip_infusion_level: int = 0

const BAG_UPGRADE_MAX_LEVEL := 12
const OVERCLOCK_BONUS_PER_LEVEL := 0.08
const INFUSION_BONUS_PER_LEVEL := 0.08


func get_bag_upgrade_cost() -> int:
	if bag_capacity_level >= BAG_UPGRADE_MAX_LEVEL:
		return 0
	return roundi(400.0 * pow(1.6, bag_capacity_level) / 10.0) * 10


func try_upgrade_bag_capacity() -> bool:
	var cost := get_bag_upgrade_cost()
	if cost <= 0 or scrap < cost:
		return false
	scrap -= cost
	bag_capacity_level += 1
	save_persistent_state()
	return true


const OVERCLOCK_COST_GROWTH := 1.5
const OVERCLOCK_CATNIP_COST_GROWTH := 1.5


func get_overclock_cost() -> int:
	# ×1.8 → ×1.5(대개편 3단계). 1.8은 회수 10h 기준 Lv12~13에서 멈춰 후반 수입 성장 수단이
	# 사라졌다. 1.5면 Lv20 ≈ 3M, Lv25 ≈ 23M — 티어 5 수입(수백만/h)에서도 계속 살 수 있는
	# 싱크가 된다. 수입 +8%/Lv(선형)이므로 지수 비용이면 폭주하지 않는다.
	return roundi(900.0 * pow(OVERCLOCK_COST_GROWTH, scratcher_overclock_level) / 10.0) * 10


func get_overclock_catnip_cost() -> int:
	# 오버클럭도 고철 단독이 아니다. 캣닢 없이는 꾹꾹이 라인이 한 칸도 못 큰다. ×1.7 → ×1.5.
	return roundi(60.0 * pow(OVERCLOCK_CATNIP_COST_GROWTH, scratcher_overclock_level) / 5.0) * 5


func try_upgrade_scratcher_overclock() -> bool:
	var cost := get_overclock_cost()
	var catnip_cost := get_overclock_catnip_cost()
	if scrap < cost or catnip < catnip_cost:
		return false
	scrap -= cost
	catnip -= catnip_cost
	scratcher_overclock_level += 1
	save_persistent_state()
	return true


func get_infusion_cost() -> int:
	return roundi(20.0 * pow(1.7, catnip_infusion_level))


func try_upgrade_catnip_infusion() -> bool:
	var cost := get_infusion_cost()
	if catnip < cost:
		return false
	catnip -= cost
	catnip_infusion_level += 1
	save_persistent_state()
	return true


func get_secure_upgrade_cost() -> int:
	# 시큐어 슬롯: 죽어도 지키는 칸. 츄르(프리미엄)로만, 최대 3칸.
	if secure_dog_slots >= 3:
		return 0
	return 2 * secure_dog_slots


func try_upgrade_secure_dog() -> bool:
	var cost := get_secure_upgrade_cost()
	if cost <= 0 or churu < cost:
		return false
	churu -= cost
	secure_dog_slots += 1
	save_persistent_state()
	return true


func get_raid_bag_capacity() -> int:
	return RAID_BAG_CAPACITY + bag_capacity_level + get_churu_bag_bonus_slots()


func get_raid_item_stack_limit(item_type: String) -> int:
	return maxi(1, int(RAID_STACK_LIMITS.get(item_type, 1)))


func get_ammo_rounds_per_slot() -> int:
	# 탄약 휴대 훈련: 랭크마다 칸당 발수 +25% (240 → 300/360/420/480).
	return maxi(1, roundi(float(AMMO_ROUNDS_PER_SLOT) * (1.0 + 0.25 * float(get_training_rank("ammo_carry")))))


func get_raid_item_slot_cost(item_type: String, _item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	# 청사진·키카드는 버릴 수도 쓸 수도 없는 쉘터 자산이다. 칸만 먹던
	# 문제(유저 신고) — 보유는 유지하되 가방 칸은 차지하지 않는다.
	if item_type == "progression":
		return 0
	# 메인 미션 회수물(특별 화물)은 가방과 무관하게 먹힌다(유저 신고: "메인 미션
	# 아이템 루팅은 가방과 상관없이 먹을 수 있어야지"). 칸 0, 만재 검사 우회.
	if item_type == "special_cargo":
		return 0
	# 무기·방어구는 가방 칸을 먹지 않는다(2026-08 영구 귀속): 제작 전용 장비는 몸에
	# 딸린 것이지 전리품이 아니다. 가방에 보이는 장비는 장착 교체용(0칸).
	if item_type in ["weapon", "equipment"]:
		return 0
	# 제작 재료는 부피가 있다 — 한 개가 한 칸. 재료를 쓸어 담으면 가방이
	# 실제로 차야 '무엇을 두고 갈까'라는 이 게임의 심장이 재료에도 뛴다.
	if item_type == "component":
		return amount
	# 탄약은 칸당 발수 상한(탄약 휴대 훈련으로 늘어난다)을 넘는 만큼 칸을 더 먹는다.
	if item_type == "ammo":
		return ceili(float(amount) / float(get_ammo_rounds_per_slot()))
	return 1


func _get_raid_bag_count(item_type: String, item_id: String) -> int:
	match item_type:
		"weapon", "equipment", "ammo", "component", "mod", "medkit", "food", "progression":
			return get_backpack_storage_count(item_type, item_id)
		"churu":
			return maxi(0, churu)
		"valuable":
			return maxi(0, int(valuable_inventory.get(item_id, 0)))
		"special_cargo":
			return 0 if raid_special_cargo.is_empty() else 1
	return 0


func get_raid_bag_used_slots() -> int:
	var used := 0
	for ammo_id in ammo_inventory.keys():
		used += get_raid_item_slot_cost("ammo", str(ammo_id), get_ammo_count(str(ammo_id)))
	used += get_raid_item_slot_cost("medkit", "medkit", medkits)
	used += get_raid_item_slot_cost(
		"food",
		"canned_food",
		get_backpack_storage_count("food", "canned_food")
	)
	used += get_raid_item_slot_cost("churu", "churu", churu)
	for valuable_id in valuable_inventory.keys():
		used += get_raid_item_slot_cost(
			"valuable", str(valuable_id), int(valuable_inventory[valuable_id])
		)
	for component_id in mod_component_inventory.keys():
		used += get_raid_item_slot_cost(
			"component",
			str(component_id),
			get_mod_component_count(str(component_id))
		)
	for progression_id in progression_item_inventory.keys():
		used += get_raid_item_slot_cost(
			"progression",
			str(progression_id),
			get_backpack_storage_count("progression", str(progression_id))
		)
	for mod_id in weapon_mod_inventory.keys():
		# 장착분 제외는 get_backpack_storage_count가 안다 — 총에 박힌
		# 부착물이 가방 칸을 계속 먹던 문제(유저 신고)의 지점.
		used += get_raid_item_slot_cost(
			"mod",
			str(mod_id),
			get_backpack_storage_count("mod", str(mod_id))
		)
	for weapon_id in weapon_inventory.keys():
		# 장착 중인 1정은 몸에 있는 것이지 가방에 있는 게 아니다 — 그 차감은
		# get_backpack_storage_count가 이미 한다. 여기서 한 번 더 빼면 같은 총을
		# 2정 들고 있을 때 예비 1정이 공짜가 돼 가방이 용량 너머로 부푼다.
		var weapon_count := get_backpack_storage_count("weapon", str(weapon_id))
		used += get_raid_item_slot_cost("weapon", str(weapon_id), weapon_count)
	for equipment_id in equipment_inventory.keys():
		used += get_raid_item_slot_cost(
			"equipment",
			str(equipment_id),
			get_equipment_count(str(equipment_id))
		)
	# 특별 화물(메인 미션 회수물)은 칸을 먹지 않는다 — get_raid_item_slot_cost가 0.
	return used


func get_raid_item_added_slot_delta(
	item_type: String,
	item_id: String,
	amount: int
) -> int:
	var current := _get_raid_bag_count(item_type, item_id)
	if item_type == "special_cargo":
		return 0
	return (
		get_raid_item_slot_cost(item_type, item_id, current + maxi(0, amount))
		- get_raid_item_slot_cost(item_type, item_id, current)
	)


func get_raid_items_added_slot_delta(items: Array[Dictionary]) -> int:
	var added_slots: int = 0
	# 더미 단위로 합산해 칸을 센다 — 탄약은 칸당 발수 상한이 있어 같은 더미에
	# 여러 번 얹히면 합계로 넘침 여부를 봐야 한다.
	var planned_amounts: Dictionary = {}
	var planned_types: Dictionary = {}
	for item in items:
		var item_type: String = str(item.get("type", ""))
		var item_id: String = str(item.get("id", ""))
		var amount: int = maxi(0, int(item.get("amount", 0)))
		if item_type.is_empty() or item_id.is_empty() or amount <= 0:
			continue
		# 개수만큼 칸을 먹는 부류(재료)는 한 상자에서 여러 개가 나와도 개수만큼
		# 자리가 필요하다. 무기·장비는 0칸(영구 귀속)이라 가방 판정에서 빠진다.
		if item_type == "component":
			added_slots += amount
			continue
		if item_type in ["weapon", "equipment"]:
			continue
		if item_type == "special_cargo":
			# 메인 미션 회수물은 칸 0 — 가방과 무관하게 먹힌다.
			continue
		var stack_key: String = "%s:%s" % [item_type, item_id]
		planned_amounts[stack_key] = int(planned_amounts.get(stack_key, 0)) + amount
		planned_types[stack_key] = [item_type, item_id]
	for stack_key in planned_amounts.keys():
		var item_type: String = str((planned_types[stack_key] as Array)[0])
		var item_id: String = str((planned_types[stack_key] as Array)[1])
		var current: int = _get_raid_bag_count(item_type, item_id)
		added_slots += (
			get_raid_item_slot_cost(item_type, item_id, current + int(planned_amounts[stack_key]))
			- get_raid_item_slot_cost(item_type, item_id, current)
		)
	return added_slots


func can_add_raid_items(items: Array[Dictionary]) -> bool:
	return get_raid_bag_used_slots() + get_raid_items_added_slot_delta(items) <= get_raid_bag_capacity()


func can_add_raid_item(item_type: String, item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if item_type == "special_cargo":
		# 미션 화물은 만재 검사를 타지 않는다 — 이미 하나 들고 있을 때만 거절.
		return raid_special_cargo.is_empty()
	var delta := get_raid_item_added_slot_delta(item_type, item_id, amount)
	return delta <= 0 or get_raid_bag_used_slots() + delta <= get_raid_bag_capacity()


func try_add_raid_item(item_type: String, item_id: String, amount: int = 1) -> bool:
	if not can_add_raid_item(item_type, item_id, amount):
		return false
	match item_type:
		"weapon":
			add_weapon(item_id, amount)
		"equipment":
			return add_equipment(item_id, amount)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) + amount)
		"component":
			add_mod_component(item_id, amount)
		"mod":
			add_weapon_mod(item_id, amount)
		"progression":
			add_progression_item(item_id, amount)
		"medkit":
			medkits += amount
		"food":
			canned_food += amount
		"churu":
			churu += amount
		"valuable":
			valuable_inventory[item_id] = int(valuable_inventory.get(item_id, 0)) + amount
			valuable_value_ledger[item_id] = int(valuable_value_ledger.get(item_id, 0)) + amount * get_valuable_unit_value(item_id)
		_:
			return false
	return true


func remove_raid_bag_item(item_type: String, item_id: String, amount: int) -> int:
	var removable := mini(maxi(0, amount), _get_raid_bag_count(item_type, item_id))
	if removable <= 0:
		return 0
	match item_type:
		"weapon":
			weapon_inventory[item_id] = maxi(0, int(weapon_inventory.get(item_id, 0)) - removable)
		"equipment":
			equipment_inventory[item_id] = maxi(0, get_equipment_count(item_id) - removable)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) - removable)
		"component":
			mod_component_inventory[item_id] = maxi(0, get_mod_component_count(item_id) - removable)
		"mod":
			weapon_mod_inventory[item_id] = maxi(0, get_weapon_mod_count(item_id) - removable)
		"progression":
			progression_item_inventory[item_id] = maxi(
				0,
				int(progression_item_inventory.get(item_id, 0)) - removable
			)
		"medkit":
			medkits = maxi(0, medkits - removable)
		"food":
			canned_food = maxi(0, canned_food - removable)
		"churu":
			churu = maxi(0, churu - removable)
		"valuable":
			var count_before := maxi(0, int(valuable_inventory.get(item_id, 0)))
			valuable_inventory[item_id] = maxi(0, count_before - removable)
			# 원장은 개수 비율만큼 덜어낸다(같은 id 안에서는 평균 단가).
			if count_before > 0 and valuable_value_ledger.has(item_id):
				var ledger_before := int(valuable_value_ledger.get(item_id, 0))
				valuable_value_ledger[item_id] = maxi(0, ledger_before - roundi(float(ledger_before) * float(removable) / float(count_before)))
		"special_cargo":
			raid_special_cargo.clear()
	return removable


func get_raid_bag_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var inventories := [
		["ammo", ammo_inventory],
		["component", mod_component_inventory],
		["progression", progression_item_inventory],
		["mod", weapon_mod_inventory],
		["weapon", weapon_inventory],
		["equipment", equipment_inventory],
	]
	for inventory_data in inventories:
		var item_type := str(inventory_data[0])
		var inventory := inventory_data[1] as Dictionary
		for item_id_value in inventory.keys():
			var item_id := str(item_id_value)
			var count := _get_raid_bag_count(item_type, item_id)
			if count <= 0:
				continue
			entries.append({
				"type": item_type,
				"id": item_id,
				"count": count,
				"drop_amount": mini(count, get_raid_item_stack_limit(item_type)),
			})
	for scalar in [
		["food", "canned_food", get_backpack_storage_count("food", "canned_food")],
		["medkit", "medkit", medkits],
		["churu", "churu", churu],
	]:
		var scalar_type := str(scalar[0])
		var scalar_id := str(scalar[1])
		var scalar_count := int(scalar[2])
		if scalar_count <= 0:
			continue
		entries.append({
			"type": scalar_type,
			"id": scalar_id,
			"count": scalar_count,
			"drop_amount": mini(scalar_count, get_raid_item_stack_limit(scalar_type)),
		})
	if not raid_special_cargo.is_empty():
		entries.append({
			"type": "special_cargo",
			"id": str(raid_special_cargo.get("id", "sealed_subway_cargo")),
			"count": 1,
			"drop_amount": 1,
		})
	return entries


func try_take_story_cargo(cargo: Dictionary) -> bool:
	if not raid_special_cargo.is_empty():
		return false
	# 가방 만재 검사 없음 — 메인 미션 회수물은 가방과 무관하게 먹힌다(칸 0).
	raid_special_cargo = cargo.duplicate(true)
	return true


func complete_story_cargo() -> Dictionary:
	if raid_special_cargo.is_empty():
		return {}
	var completed := raid_special_cargo.duplicate(true)
	var cargo_id := str(completed.get("id", "sealed_subway_cargo"))
	if not recovered_story_cargo_ids.has(cargo_id):
		recovered_story_cargo_ids.append(cargo_id)
	raid_special_cargo.clear()
	return completed


func get_stored_storage_count(item_type: String, item_id: String) -> int:
	var total := 0
	for entry in storage_inventory:
		if (
			str(entry.get("type", "")) == item_type
			and str(entry.get("id", "")) == item_id
		):
			total += maxi(0, int(entry.get("count", 0)))
	return total


func deposit_storage_item(
	item_type: String,
	item_id: String,
	amount: int = 1,
	persist: bool = true
) -> Dictionary:
	_normalize_storage_inventory()
	if item_type == "food":
		# 통조림은 창고에 안 들어간다 — 필드에선 던지는 소모품이고, 돌아오면 정산이
		# 쉘터 훈련 재고로 옮긴다.
		return {"ok": false, "moved": 0, "reason": "통조림은 창고에 보관하지 않습니다. 귀환하면 쉘터 훈련 재고로 들어갑니다."}
	var available := get_backpack_storage_count(item_type, item_id)
	var moved := mini(maxi(amount, 0), available)
	if moved <= 0:
		return {"ok": false, "moved": 0, "reason": "보관할 수 있는 소지품이 없습니다."}
	var stack_limit := _get_storage_stack_limit(item_type)
	var free_units := 0
	for entry in storage_inventory:
		if str(entry.get("type", "")) == item_type and str(entry.get("id", "")) == item_id:
			free_units += maxi(0, stack_limit - int(entry.get("count", 0)))
	free_units += maxi(0, get_storage_capacity() - storage_inventory.size()) * stack_limit
	# 자리가 모자라면 들어가는 만큼만 넣는다. 전량 실패로 되돌리면 복귀 정산이
	# "창고가 반쯤 비었는데 아무것도 안 들어갔다"로 끝난다.
	var requested := moved
	moved = mini(moved, free_units)
	if moved <= 0:
		return {"ok": false, "moved": 0, "reason": "창고에 빈 슬롯이 부족합니다."}
	if not _remove_backpack_storage_item(item_type, item_id, moved):
		return {"ok": false, "moved": 0, "reason": "소지품을 창고로 옮기지 못했습니다."}
	var remaining := moved
	for entry in storage_inventory:
		if str(entry.get("type", "")) != item_type or str(entry.get("id", "")) != item_id:
			continue
		var room := maxi(0, stack_limit - int(entry.get("count", 0)))
		var added := mini(room, remaining)
		entry["count"] = int(entry.get("count", 0)) + added
		remaining -= added
		if remaining <= 0:
			break
	while remaining > 0:
		var added := mini(stack_limit, remaining)
		storage_inventory.append({"type": item_type, "id": item_id, "count": added})
		remaining -= added
	if persist:
		save_persistent_state()
	return {
		"ok": true,
		"moved": moved,
		"partial": moved < requested,
		"reason": "창고가 가득 차 일부만 보관했습니다." if moved < requested else "",
	}


func withdraw_storage_item(slot_index: int, amount: int = 1) -> Dictionary:
	_normalize_storage_inventory()
	if slot_index < 0 or slot_index >= storage_inventory.size():
		return {"ok": false, "reason": "선택한 창고 슬롯이 비어 있습니다."}
	var entry := storage_inventory[slot_index]
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var moved := mini(maxi(amount, 1), int(entry.get("count", 0)))
	if moved <= 0:
		return {"ok": false, "reason": "선택한 창고 슬롯이 비어 있습니다."}
	if not can_add_raid_item(item_type, item_id, moved):
		return {
			"ok": false,
			"reason": "가방이 꽉 찼습니다.",
		}
	_add_backpack_storage_item(item_type, item_id, moved)
	entry["count"] = int(entry.get("count", 0)) - moved
	if int(entry.get("count", 0)) <= 0:
		storage_inventory.remove_at(slot_index)
	save_persistent_state()
	return {"ok": true, "moved": moved, "type": item_type, "id": item_id}


func withdraw_storage_item_by_type(item_type: String, item_id: String, amount: int) -> Dictionary:
	_normalize_storage_inventory()
	var requested := maxi(0, amount)
	var moved_total := 0
	var last_reason := "창고에 해당 물품이 없습니다."
	for slot_index in range(storage_inventory.size() - 1, -1, -1):
		if moved_total >= requested:
			break
		var entry := storage_inventory[slot_index]
		if (
			str(entry.get("type", "")) != item_type
			or str(entry.get("id", "")) != item_id
		):
			continue
		var move_amount := mini(
			requested - moved_total,
			maxi(0, int(entry.get("count", 0)))
		)
		var result := withdraw_storage_item(slot_index, move_amount)
		if not bool(result.get("ok", false)):
			last_reason = str(result.get("reason", last_reason))
			break
		moved_total += int(result.get("moved", 0))
	if moved_total <= 0:
		return {"ok": false, "moved": 0, "reason": last_reason}
	return {
		"ok": true,
		"moved": moved_total,
		"partial": moved_total < requested,
		"reason": last_reason if moved_total < requested else "",
	}


func remove_stored_storage_item(item_type: String, item_id: String, amount: int) -> int:
	# 창고에서 곧바로 덜어낸다(가방을 경유하지 않는다). 제작대가 창고 재료를
	# 쓰려면 "인출 → 제작 → 다시 보관"이라는 3단 심부름을 강요하지 않아야 한다.
	# 실제로 뺀 수량을 돌려준다.
	_normalize_storage_inventory()
	var remaining := maxi(0, amount)
	var removed := 0
	for index in range(storage_inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var entry := storage_inventory[index]
		if (
			str(entry.get("type", "")) != item_type
			or str(entry.get("id", "")) != item_id
		):
			continue
		var taken := mini(remaining, maxi(0, int(entry.get("count", 0))))
		entry["count"] = int(entry.get("count", 0)) - taken
		remaining -= taken
		removed += taken
		if int(entry.get("count", 0)) <= 0:
			storage_inventory.remove_at(index)
	return removed


func _get_storage_stack_limit(item_type: String) -> int:
	match item_type:
		"ammo":
			return 120
		"component":
			return 10
		"mod":
			return 5
		"medkit":
			return 5
		"progression":
			# 청사진·키카드는 종류별로 한 장이면 충분하지만, 중복 습득이
			# 창고 슬롯을 계속 갉아먹지 않게 한 슬롯에 겹쳐 쌓는다.
			return 9
	return 1


func _remove_backpack_storage_item(item_type: String, item_id: String, amount: int) -> bool:
	if get_backpack_storage_count(item_type, item_id) < amount:
		return false
	match item_type:
		"weapon":
			weapon_inventory[item_id] = maxi(0, int(weapon_inventory.get(item_id, 0)) - amount)
		"equipment":
			equipment_inventory[item_id] = maxi(0, get_equipment_count(item_id) - amount)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) - amount)
		"component":
			mod_component_inventory[item_id] = maxi(0, get_mod_component_count(item_id) - amount)
		"mod":
			weapon_mod_inventory[item_id] = maxi(0, get_weapon_mod_count(item_id) - amount)
		"progression":
			progression_item_inventory[item_id] = maxi(
				0,
				int(progression_item_inventory.get(item_id, 0)) - amount
			)
		"medkit":
			medkits = maxi(0, medkits - amount)
		_:
			return false
	return true


func _add_backpack_storage_item(item_type: String, item_id: String, amount: int) -> void:
	match item_type:
		"weapon":
			add_weapon(item_id, amount)
		"equipment":
			add_equipment(item_id, amount)
		"ammo":
			set_ammo_count(item_id, get_ammo_count(item_id) + amount)
		"component":
			add_mod_component(item_id, amount)
		"mod":
			add_weapon_mod(item_id, amount)
		"progression":
			add_progression_item(item_id, amount)
		"medkit":
			medkits += amount


func _normalize_storage_inventory() -> void:
	var normalized: Array[Dictionary] = []
	for value in storage_inventory:
		if not (value is Dictionary):
			continue
		var entry := (value as Dictionary).duplicate(true)
		var item_type := str(entry.get("type", ""))
		var item_id := str(entry.get("id", ""))
		var count := maxi(0, int(entry.get("count", 0)))
		if item_type.is_empty() or item_id.is_empty() or count <= 0:
			continue
		normalized.append({"type": item_type, "id": item_id, "count": count})
	storage_inventory = normalized


func _purge_stored_canned_food() -> int:
	# 구 세이브 마이그레이션: 창고 "food" 슬롯은 더 이상 없다. 예전 장부에서는 창고
	# 통조림이 canned_food 총량에 이미 포함돼 있었으므로(storage_food_in_total),
	# 슬롯만 지우면 그 몫이 자동으로 가방 보유량이 된다. 통조림은 몇 개든 가방
	# 1칸이라 슬롯 초과 환전은 필요 없다. 지운 개수를 돌려준다.
	var removed := 0
	for index in range(storage_inventory.size() - 1, -1, -1):
		var entry := storage_inventory[index]
		if str(entry.get("type", "")) != "food":
			continue
		removed += maxi(0, int(entry.get("count", 0)))
		storage_inventory.remove_at(index)
	return removed


func get_ammo_count(ammo_id: String) -> int:
	return int(ammo_inventory.get(ammo_id, 0))


func get_mission_reward_ammo_id() -> String:
	if not equipped_ammo_id.is_empty() and not WEAPON_SYSTEM.get_ammo(equipped_ammo_id).is_empty():
		return equipped_ammo_id
	if not equipped_weapon_id.is_empty():
		var weapon_definition := WEAPON_SYSTEM.get_weapon(equipped_weapon_id)
		var default_ammo_id := str(weapon_definition.get("default_ammo_id", ""))
		if not default_ammo_id.is_empty() and not WEAPON_SYSTEM.get_ammo(default_ammo_id).is_empty():
			return default_ammo_id
	return "9mm_fmj"


func set_ammo_count(ammo_id: String, amount: int) -> void:
	ammo_inventory[ammo_id] = maxi(0, amount)
	if ammo_id == equipped_ammo_id:
		reserve_ammo = int(ammo_inventory[ammo_id])


func add_weapon(weapon_id: String, amount: int = 1) -> void:
	var first_acquisition := amount > 0 and int(weapon_inventory.get(weapon_id, 0)) <= 0
	weapon_inventory[weapon_id] = maxi(0, int(weapon_inventory.get(weapon_id, 0)) + amount)
	if not weapon_mod_loadouts.has(weapon_id):
		weapon_mod_loadouts[weapon_id] = []
	if first_acquisition:
		# 처음 손에 넣은 총은 바로 쏴 볼 수 있어야 한다 — 기본 탄약 두 탄창을 얹는다.
		var definition: Dictionary = WEAPON_SYSTEM.get_weapon(weapon_id)
		var ammo_id := str(definition.get("default_ammo_id", ""))
		var magazine_size := int(definition.get("magazine_size", 0))
		if not ammo_id.is_empty() and magazine_size > 0:
			set_ammo_count(ammo_id, get_ammo_count(ammo_id) + magazine_size * 2)
		# 작업대 제작·장인 뽑기·필드 픽업·정산 귀속 — 무기가 들어오는 길은 전부
		# 여기를 지나므로 "처음 보유" 훅은 이 한 곳이면 된다.
		_on_weapon_first_owned(weapon_id)


# ── 무기 사다리 · 강화 이관 ──────────────────────────────────────
# 같은 가족(소총 ak47→akm→k2, 산탄 double_barrel→pump_shotgun)의 상위 무기를
# 처음 손에 넣는 순간, 아래 단계의 강화를 60% 이어받는다(내림). 고철 비용 없음,
# 하위 무기의 강화는 그대로 — 갈아타기가 손실이 아니라 승계여야 사다리가 선다.
# 상위 무기 1정당 평생 1회(weapon_enhancement_transfers_done, 세이브 저장) —
# 사망으로 가방을 잃고 다시 주워도 다시 이관되지 않는다. 플레이어 상태를
# 적 스탯·드랍률에 되먹이지 않으므로 러버밴딩과 무관하다.
var weapon_enhancement_transfers_done: Array = []
var last_weapon_enhancement_transfer: Dictionary = {}


func _on_weapon_first_owned(weapon_id: String) -> void:
	transfer_weapon_enhancement_on_first_own(weapon_id)


func transfer_weapon_enhancement_on_first_own(to_id: String) -> Dictionary:
	# 사다리에서 to_id 아래 단계(보유 여부 무관, 강화 레벨이 가장 높은 것)를 찾아
	# transfer_weapon_enhancement를 1회 호출한다. 이관이 없으면 빈 딕셔너리.
	if weapon_enhancement_transfers_done.has(to_id):
		return {}
	var lower_ids: Array[String] = WEAPON_SYSTEM.get_lower_ladder_weapons(to_id)
	if lower_ids.is_empty():
		return {}
	var from_id := ""
	var from_level := 0
	for candidate_id in lower_ids:
		var level := get_weapon_enhancement_level(candidate_id)
		if level > from_level:
			from_level = level
			from_id = candidate_id
	# 이관할 강화가 없어도 "1회"는 소진한다 — 상위를 먼저 줍고 하위를 키워서
	# 나중에 다시 받는 역순 플레이를 막는다.
	weapon_enhancement_transfers_done.append(to_id)
	if from_id.is_empty() or from_level <= 0:
		return {}
	return transfer_weapon_enhancement(from_id, to_id)


func transfer_weapon_enhancement(from_id: String, to_id: String) -> Dictionary:
	# to 레벨 = max(기존 to 레벨, floor(from 레벨 × 0.6)). from 레벨은 유지.
	# 같은 가족이 아니거나 상위 방향이 아니면 아무것도 안 한다.
	var family_id := WEAPON_SYSTEM.get_weapon_family(from_id)
	if family_id.is_empty() or family_id != WEAPON_SYSTEM.get_weapon_family(to_id):
		return {}
	var ladder: Array = WEAPON_SYSTEM.WEAPON_FAMILY_LADDER[family_id]
	if ladder.find(from_id) >= ladder.find(to_id):
		return {}
	var from_level := get_weapon_enhancement_level(from_id)
	var transferred_level := int(floor(float(from_level) * WEAPON_SYSTEM.ENHANCEMENT_TRANSFER_RATIO))
	var previous_level := get_weapon_enhancement_level(to_id)
	var next_level := clampi(maxi(previous_level, transferred_level), 0, MAX_WEAPON_ENHANCEMENT)
	if next_level <= previous_level:
		return {}
	weapon_enhancement_levels[to_id] = next_level
	if to_id == equipped_weapon_id:
		weapon_level = next_level + 1
	var result := {
		"from_id": from_id,
		"to_id": to_id,
		"from_level": from_level,
		"previous_level": previous_level,
		"level": next_level,
		"notice": "%s +%d의 강화를 이어받았다 → %s +%d" % [
			_weapon_short_name(from_id), from_level, _weapon_short_name(to_id), next_level,
		],
	}
	last_weapon_enhancement_transfer = result
	return result


func take_weapon_enhancement_transfer_notice() -> String:
	# 방금 일어난 이관의 토스트 문구를 한 번만 돌려준다(픽업·작업대·뽑기 공용).
	if last_weapon_enhancement_transfer.is_empty():
		return ""
	var notice := str(last_weapon_enhancement_transfer.get("notice", ""))
	last_weapon_enhancement_transfer = {}
	return notice


func _weapon_short_name(weapon_id: String) -> String:
	# 'AK-47 "캣라시니코프"' → 'AK-47'. 토스트 한 줄에 별명까지 넣으면 넘친다.
	var display_name := str(WEAPON_SYSTEM.get_weapon(weapon_id).get("display_name", weapon_id))
	return display_name.split("\"")[0].strip_edges()


# ── 장비 레벨 ──────────────────────────────────────────────────
# 같은 장비도 "레벨 3짜리 신발"이 존재한다. 저장·장착·거래는 전부 문자열 ID
# 기반이라, 레벨을 ID에 접미사("scav_vest@3")로 새기면 나머지 시스템은 그대로
# 동작한다. 정의 조회가 접미사를 해석해 스탯을 키워서 돌려준다.
const EQUIPMENT_MAX_LEVEL := 5
const EQUIPMENT_LEVEL_GROWTH := 0.28  # 레벨당 성능 성장률


func split_equipment_id(equipment_id: String) -> Array:
	var at := equipment_id.find("@")
	if at < 0:
		return [equipment_id, 1]
	return [
		equipment_id.substr(0, at),
		clampi(int(equipment_id.substr(at + 1)), 1, EQUIPMENT_MAX_LEVEL),
	]


func get_equipment_level(equipment_id: String) -> int:
	return int(split_equipment_id(equipment_id)[1])


func make_equipment_id(base_id: String, level: int) -> String:
	level = clampi(level, 1, EQUIPMENT_MAX_LEVEL)
	return base_id if level <= 1 else "%s@%d" % [base_id, level]


func get_equipment_definition(equipment_id: String) -> Dictionary:
	var parts := split_equipment_id(equipment_id)
	var definition := (EQUIPMENT_DEFINITIONS.get(parts[0], {}) as Dictionary).duplicate(true)
	if definition.is_empty():
		return definition
	var level := int(parts[1])
	definition["base_id"] = parts[0]
	definition["level"] = level
	if level > 1:
		var growth := 1.0 + EQUIPMENT_LEVEL_GROWTH * float(level - 1)
		if definition.has("damage_reduction"):
			# 부위당 상한 0.5 — 총합 하한 0.4(get_equipment_damage_multiplier)와 이중 안전망.
			definition["damage_reduction"] = minf(
				float(definition["damage_reduction"]) * growth, 0.5
			)
		if definition.has("move_speed_bonus"):
			definition["move_speed_bonus"] = float(definition["move_speed_bonus"]) * growth
		if definition.has("stamina_cost_multiplier"):
			definition["stamina_cost_multiplier"] = maxf(
				1.0 - (1.0 - float(definition["stamina_cost_multiplier"])) * growth, 0.55
			)
		definition["display_name"] = "%s Lv.%d" % [definition["display_name"], level]
	return definition


func roll_equipment_drop_id(base_id: String) -> String:
	# 레벨 분포는 도시와 무관한 공통 분포(loot_economy 단일 소스) — 도시가
	# 정하는 건 계열(어떤 장비가 나오는가)이고, 레벨은 어디서든 1~5다.
	return make_equipment_id(base_id, LOOT_ECONOMY.roll_equipment_level(randf()))


func get_equipment_count(equipment_id: String) -> int:
	return int(equipment_inventory.get(equipment_id, 0))


func add_equipment(equipment_id: String, amount: int = 1) -> bool:
	if get_equipment_definition(equipment_id).is_empty() or amount <= 0:
		return false
	var base_id := str(split_equipment_id(equipment_id)[0])
	var first_acquisition := not is_armor_base_owned(base_id)
	equipment_inventory[equipment_id] = get_equipment_count(equipment_id) + amount
	if first_acquisition:
		# 작업대 제작·구세이브 회수 — 방어구가 처음 들어오는 길은 여기 한 곳이다.
		transfer_armor_enhancement_on_first_own(base_id)
	return true


func get_equipped_equipment(slot: String) -> String:
	match slot:
		"head":
			return equipped_head_armor_id
		"feet":
			return equipped_footwear_id
		_:
			return equipped_body_armor_id


func equip_equipment(equipment_id: String) -> bool:
	var definition := get_equipment_definition(equipment_id)
	if definition.is_empty() or get_equipment_count(equipment_id) <= 0:
		return false
	var slot := str(definition.get("slot", ""))
	if not ["body", "head", "feet"].has(slot):
		return false
	var previous := get_equipped_equipment(slot)
	if previous == equipment_id:
		return true
	equipment_inventory[equipment_id] = get_equipment_count(equipment_id) - 1
	if not previous.is_empty():
		equipment_inventory[previous] = get_equipment_count(previous) + 1
	match slot:
		"head":
			equipped_head_armor_id = equipment_id
		"feet":
			equipped_footwear_id = equipment_id
		_:
			equipped_body_armor_id = equipment_id
	return true


func unequip_equipment(slot: String) -> bool:
	var equipped_id := get_equipped_equipment(slot)
	if equipped_id.is_empty():
		return false
	# 몸에서 벗으면 가방으로 들어간다 — 가방에 그 자리가 있어야 벗을 수 있다.
	if not can_add_raid_item("equipment", equipped_id, 1):
		return false
	equipment_inventory[equipped_id] = get_equipment_count(equipped_id) + 1
	match slot:
		"head":
			equipped_head_armor_id = ""
		"feet":
			equipped_footwear_id = ""
		_:
			equipped_body_armor_id = ""
	return true


func get_equipment_score(equipment_id: String) -> float:
	# 슬롯마다 "좋다"의 기준이 다르다. 방어구는 피해 감소, 신발은 이동/스태미나.
	# 이 점수 하나로 어떤 장비가 더 나은지 한 번에 비교한다.
	var definition := get_equipment_definition(equipment_id)
	if definition.is_empty():
		return -1.0
	var slot := str(definition.get("slot", "body"))
	if slot == "feet":
		return (
			float(definition.get("move_speed_bonus", 0.0)) * 100.0
			+ (1.0 - float(definition.get("stamina_cost_multiplier", 1.0))) * 60.0
		)
	return float(definition.get("damage_reduction", 0.0)) * 100.0


func equip_if_upgrade(equipment_id: String) -> Dictionary:
	# 파밍의 손맛: 주운 장비가 지금 낀 것보다 나으면 그 자리에서 갈아 끼운다.
	# 낡은 건 가방으로 돌아가 팔거나 버릴 거리가 된다. 나쁘면 가방에만 넣는다.
	var definition := get_equipment_definition(equipment_id)
	if definition.is_empty():
		return {"ok": false}
	var slot := str(definition.get("slot", "body"))
	var current_id := get_equipped_equipment(slot)
	var new_score := get_equipment_score(equipment_id)
	var current_score := get_equipment_score(current_id) if not current_id.is_empty() else -1.0
	var result := {
		"ok": true,
		"slot": slot,
		"equipment_id": equipment_id,
		"display_name": str(definition.get("display_name", "장비")),
		"previous_id": current_id,
		"new_score": new_score,
		"previous_score": maxf(0.0, current_score),
	}
	if new_score > current_score:
		# equip_equipment은 인벤토리에서 한 장 소비하므로, 방금 주운 것을 반영하기
		# 위해 먼저 인벤토리에 넣어 두고 장착한다.
		var equipped := equip_equipment(equipment_id)
		result["equipped"] = equipped
	else:
		result["equipped"] = false
	return result


func get_equipped_armor_piece_count() -> int:
	var count := 0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			count += 1
	return count


# ── 방어구 트레이드오프 ────────────────────────────────────────
# 상위 계열은 순수 상위호환이 아니다: 두꺼운 방어구는 눈에 잘 띄고(피탐지↑),
# 무거운 부츠는 냄새 흔적이 짙다. "무엇을 입을까"가 빌드 선택이 된다.
# 트레이드오프 스탯은 레벨 성장에서 제외 — 계열 고유의 성격이다.


func get_equipment_visibility_multiplier() -> float:
	var multiplier := 1.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if str(equipment_id).is_empty():
			continue
		multiplier *= float(
			get_equipment_definition(str(equipment_id)).get("visibility_multiplier", 1.0)
		)
	return clampf(multiplier, 0.8, 1.35)


func get_equipment_scent_multiplier() -> float:
	var multiplier := 1.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if str(equipment_id).is_empty():
			continue
		multiplier *= float(
			get_equipment_definition(str(equipment_id)).get("scent_multiplier", 1.0)
		)
	return clampf(multiplier, 0.7, 1.4)


# 방어구 강화 효과의 단일 적용 지점. 레벨 접미사(@n) 성장은 get_equipment_definition이,
# +N 강화는 여기서 곱한다 — 피스 합산 감소 상한 0.70(= 배율 하한 0.30).
const ARMOR_TOTAL_REDUCTION_CAP := 0.70


func get_equipment_effective_damage_reduction(equipment_id: String) -> float:
	# 한 피스의 실제 피해 감소 = 정의값 × 강화 배율. UI(장비 카드)와 피해 계산이 같은 값을 본다.
	if equipment_id.is_empty():
		return 0.0
	var definition := get_equipment_definition(equipment_id)
	if definition.is_empty():
		return 0.0
	return float(definition.get("damage_reduction", 0.0)) * get_armor_enhancement_multiplier(equipment_id)


func get_equipment_damage_multiplier() -> float:
	var reduction := 0.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if equipment_id.is_empty():
			continue
		reduction += get_equipment_effective_damage_reduction(equipment_id)
	# 피스 합산 상한 0.70 — 풀아머 T3 +99(0.58×1.59≈0.92)도 여기서 멈춘다. 적은 종이가
	# 되지 않고, 강화는 끝이 없되 힘은 끝이 있다.
	return clampf(1.0 - minf(reduction, ARMOR_TOTAL_REDUCTION_CAP), 1.0 - ARMOR_TOTAL_REDUCTION_CAP, 1.0)


func save_equipped_weapon_loadout() -> void:
	if equipped_weapon_id.is_empty():
		return
	weapon_mod_loadouts[equipped_weapon_id] = equipped_weapon_mods.duplicate()


func equip_weapon(weapon_id: String) -> bool:
	if get_weapon_count(weapon_id) <= 0:
		return false
	if weapon_id == equipped_weapon_id:
		has_ak = true
		return true
	save_equipped_weapon_loadout()
	equipped_weapon_id = weapon_id
	equipped_weapon_mods = _to_string_array(weapon_mod_loadouts.get(weapon_id, []))
	var definition := WEAPON_SYSTEM.get_weapon(weapon_id)
	equipped_magazine_id = str(definition.get("magazine_id", ""))
	equipped_ammo_id = str(definition.get("default_ammo_id", ""))
	magazine_ammo = 0
	reserve_ammo = get_ammo_count(equipped_ammo_id)
	has_ak = true
	return true


func unequip_weapon() -> bool:
	if not has_ak:
		return false
	# 장착 해제하면 그 1정이 다시 가방 슬롯을 차지한다. 자리가 없으면 못 벗는다.
	if not can_add_raid_item("weapon", equipped_weapon_id, 1):
		return false
	save_equipped_weapon_loadout()
	has_ak = false
	return true


func add_mod_component(component_id: String, amount: int = 1) -> void:
	mod_component_inventory[component_id] = maxi(
		0,
		int(mod_component_inventory.get(component_id, 0)) + amount
	)


func add_progression_item(item_id: String, amount: int = 1) -> void:
	progression_item_inventory[item_id] = maxi(
		0,
		int(progression_item_inventory.get(item_id, 0)) + amount
	)


func get_progression_item_count(item_id: String) -> int:
	# 청사진·키카드는 소모되지 않는 해금 토큰이다. 복귀 정산이 이것들을 창고로
	# 옮기므로, "보유 판정"은 가방과 창고를 함께 봐야 한다 — 안 그러면 창고에
	# 넣은 순간 AK 설계도가 사라진 것처럼 제작대가 잠긴다.
	return (
		maxi(0, int(progression_item_inventory.get(item_id, 0)))
		+ get_stored_storage_count("progression", item_id)
	)


func claim_workbench_starter_parts() -> bool:
	if workbench_starter_parts_claimed:
		return false
	workbench_starter_parts_claimed = true
	# 예전엔 M1911·MP5를 공짜로 쥐여 줬다 — 장비는 제작 전용(설계도 조각 3/3)이 된
	# 이상 공짜 총은 규칙을 거짓으로 만든다. 첫 제작을 위한 부품만 남긴다.
	add_mod_component("rubber_gasket", 2)
	add_mod_component("scope_lens", 2)
	add_mod_component("magazine_spring", 2)
	return true


func get_mod_component_count(component_id: String) -> int:
	return int(mod_component_inventory.get(component_id, 0))


func _count_total_mod_components() -> int:
	var total := 0
	for amount in mod_component_inventory.values():
		total += maxi(0, int(amount))
	return total


func add_weapon_mod(mod_id: String, amount: int = 1) -> void:
	weapon_mod_inventory[mod_id] = maxi(
		0,
		int(weapon_mod_inventory.get(mod_id, 0)) + amount
	)


func get_weapon_mod_count(mod_id: String) -> int:
	return int(weapon_mod_inventory.get(mod_id, 0))


func get_resident_capacity() -> int:
	return int(SHELTER_CAPACITY_BY_TIER.get(shelter_tier, 5))


func get_available_resident_slots() -> int:
	_ensure_resident_records()
	return maxi(0, get_resident_capacity() - resident_cat_ids.size())


func try_add_rescued_workers(amount: int) -> int:
	var accepted := mini(maxi(amount, 0), get_available_resident_slots())
	if accepted <= 0:
		return 0
	rescued_workers += accepted
	_ensure_resident_records()
	return accepted


func get_scratcher_worker_slots() -> int:
	return int(KNEADING_SLOTS_BY_TIER.get(shelter_tier, 3))


func get_catnip_worker_slots() -> int:
	return int(CATNIP_SLOTS_BY_TIER.get(shelter_tier, 1))


func get_active_scratcher_workers() -> int:
	if not is_shelter_facility_unlocked("scratcher_bank"):
		return 0
	_ensure_resident_records()
	_sanitize_assigned_workers()
	return mini(assigned_worker_ids.size(), get_scratcher_worker_slots())


func get_active_catnip_workers() -> int:
	if not is_shelter_facility_unlocked("catnip_scraper"):
		return 0
	_ensure_resident_records()
	_sanitize_assigned_workers()
	return mini(assigned_catnip_worker_ids.size(), get_catnip_worker_slots())


func get_resident_trait(worker_id: String) -> Dictionary:
	_ensure_resident_records()
	return (resident_traits.get(worker_id, RESIDENT_TRAIT_PRESETS[4]) as Dictionary).duplicate(true)


func _resident_trait_field(worker_id: String, key: String, default_value: Variant) -> Variant:
	# 특성 기록에 키가 없으면(연료 폐지 이전 세이브) 같은 이름의 프리셋에서 찾는다.
	var trait_data := get_resident_trait(worker_id)
	if trait_data.has(key):
		return trait_data[key]
	var trait_name := str(trait_data.get("name", ""))
	for preset in RESIDENT_TRAIT_PRESETS:
		if str((preset as Dictionary).get("name", "")) == trait_name:
			return (preset as Dictionary).get(key, default_value)
	return default_value


func get_worker_offline_factor(worker_id: String) -> float:
	# 자리를 비운 동안 이 주민의 생산이 얼마나 쌓이는가(1.0 = 전량, 0.0 = 없음).
	return clampf(float(_resident_trait_field(worker_id, "offline", 1.0)), 0.0, 1.0)


func get_worker_offline_cap_seconds(worker_id: String) -> int:
	var cap_hours := int(_resident_trait_field(worker_id, "offline_cap_hours", 0))
	if cap_hours <= 0:
		return SHELTER_OFFLINE_MAX_SECONDS
	return cap_hours * 3600


func get_resident_trait_quirk(worker_id: String) -> String:
	return str(_resident_trait_field(worker_id, "quirk", ""))


func get_worker_production_per_second(worker_id: String, production_kind: String) -> float:
	var trait_data := get_resident_trait(worker_id)
	match production_kind:
		"scratcher", "kneading":
			if not is_shelter_facility_unlocked("scratcher_bank"):
				return 0.0
			if not assigned_worker_ids.has(worker_id):
				return 0.0
			# 배율은 반올림 밖에서 곱한다. 안에서 곱하면 특성이 낮은 주민은
			# 강화를 해도 정수 반올림에 먹혀 산출이 그대로다(죽은 업그레이드).
			var base_rate := float(maxi(1, roundi(float(trait_data.get("kneading", 1.0)))))
			return base_rate * scratcher_multiplier * get_production_multiplier()
		"catnip":
			if not is_shelter_facility_unlocked("catnip_scraper"):
				return 0.0
			if not assigned_catnip_worker_ids.has(worker_id):
				return 0.0
			return (
				float(maxi(
					1,
					roundi(
						float(trait_data.get("catnip", 1.0))
						* BASE_CATNIP_PER_WORKER_SECOND
					)
				))
				* catnip_scraper_multiplier
			)
	return 0.0


func get_catnip_boost_remaining() -> int:
	return maxi(0, catnip_boost_end_time - int(Time.get_unix_time_from_system()))


func is_catnip_boost_active() -> bool:
	return get_catnip_boost_remaining() > 0


# ── 캣닢 피버 ─────────────────────────────────────────────────
# 캣닢은 출정 버프를 잃은 대신 두 개의 출구를 얻었다: 고철 생산기 확장 재료와
# 이 피버다. 게이지에 캣닢을 부어 두었다가, 꽉 차는 순간 쉘터 전체가 취한다.
# 게이지는 저장된다 — 오늘 절반만 채워 두고 내일 마저 채워도 된다.
const CATNIP_FEVER_GAUGE_MAX := 100.0
const CATNIP_FEVER_CHARGE_STEP := 25.0
const CATNIP_FEVER_BASE_MULTIPLIER := 5.0
const CATNIP_FEVER_BASE_DURATION := 20.0


func get_catnip_fever_charge_cost() -> int:
	# 한 번 누를 때마다 "착즙 10분치". 4번이면 만충이니 한 번의 피버는
	# 대략 40분치 캣닢을 태운다 — 잉여 캣닢의 스케일 소비처.
	return maxi(120, roundi(get_base_catnip_per_second() * 60.0 * 10.0))


func get_catnip_fever_multiplier() -> float:
	# 쉘터가 클수록 취기도 크다. Tier 1 = 5배, Tier 5 = 9배.
	return CATNIP_FEVER_BASE_MULTIPLIER + float(clampi(shelter_tier, 1, 5) - 1)


func get_catnip_fever_duration() -> float:
	# Tier당 +5초. Tier 1 = 20초, Tier 5 = 40초.
	return CATNIP_FEVER_BASE_DURATION + float(clampi(shelter_tier, 1, 5) - 1) * 5.0


func get_catnip_fever_ratio() -> float:
	return clampf(catnip_fever_gauge / CATNIP_FEVER_GAUGE_MAX, 0.0, 1.0)


func get_catnip_fever_remaining_seconds() -> float:
	if not catnip_fever_active:
		return 0.0
	return get_catnip_fever_duration() * get_catnip_fever_ratio()


func try_charge_catnip_fever() -> Dictionary:
	# 발동 중에는 더 부을 수 없다 — 취한 위에 또 취할 수는 없다.
	if catnip_fever_active:
		return {"ok": false, "reason": "이미 캣닢 피버가 진행 중입니다."}
	var cost := get_catnip_fever_charge_cost()
	if catnip < cost:
		return {"ok": false, "reason": "캣닢이 부족합니다. (필요 %d)" % cost}
	catnip -= cost
	catnip_fever_gauge = minf(CATNIP_FEVER_GAUGE_MAX, catnip_fever_gauge + CATNIP_FEVER_CHARGE_STEP)
	var activated := catnip_fever_gauge >= CATNIP_FEVER_GAUGE_MAX
	if activated:
		# 만충은 곧 발동이다. 다 채워 놓고 또 한 번 눌러야 한다면 그건 절차지 사건이 아니다.
		catnip_fever_active = true
		catnip_fever_gauge = CATNIP_FEVER_GAUGE_MAX
	save_persistent_state()
	return {"ok": true, "activated": activated, "cost": cost, "ratio": get_catnip_fever_ratio()}


func tick_catnip_fever(delta: float) -> bool:
	# 발동 중에는 게이지가 곧 남은 시간이다. 0이 되면 그대로 끝난다.
	# 방금 끝났으면 true를 돌려준다(쉘터가 마무리 연출을 켠다).
	if not catnip_fever_active:
		return false
	var duration := maxf(1.0, get_catnip_fever_duration())
	catnip_fever_gauge -= CATNIP_FEVER_GAUGE_MAX * maxf(0.0, delta) / duration
	if catnip_fever_gauge > 0.0:
		return false
	catnip_fever_gauge = 0.0
	catnip_fever_active = false
	save_persistent_state()
	return true


func get_active_catnip_fever_multiplier() -> float:
	return get_catnip_fever_multiplier() if catnip_fever_active else 1.0


func get_production_multiplier() -> float:
	return CATNIP_BOOST_MULTIPLIER if is_catnip_boost_active() else 1.0


func activate_catnip_boost() -> bool:
	process_shelter_progress()
	var cost := get_catnip_boost_cost()
	if catnip < cost:
		return false
	catnip -= cost
	catnip_boost_end_time = int(Time.get_unix_time_from_system()) + CATNIP_BOOST_DURATION_SECONDS
	return true


func get_scrap_per_hour() -> float:
	return (
		get_base_scrap_per_hour()
		* get_production_multiplier()
		* get_active_catnip_fever_multiplier()
		* (1.0 + OVERCLOCK_BONUS_PER_LEVEL * scratcher_overclock_level)
	)


func get_base_scrap_per_hour() -> float:
	if not is_shelter_facility_unlocked("scratcher_bank"):
		return 0.0
	var total_per_second := 0.0
	for worker_id in assigned_worker_ids:
		var trait_data := get_resident_trait(worker_id)
		# 배율은 반올림 밖에서 — get_worker_production_per_second와 같은 이유.
		total_per_second += (
			float(maxi(1, roundi(float(trait_data.get("kneading", 1.0)))))
			* scratcher_multiplier
		)
	return total_per_second * 3600.0


func get_scrap_per_second() -> float:
	return get_scrap_per_hour() / 3600.0


func get_catnip_per_hour() -> float:
	return get_catnip_per_second() * 3600.0


func get_catnip_per_second() -> float:
	# 피버는 착즙 라인에도 걸린다 — "모든 생산기"가 함께 취해야 화면이 산다.
	return get_base_catnip_per_second() * get_active_catnip_fever_multiplier()


func get_base_catnip_per_second() -> float:
	# 피버 배율을 뺀 평상시 생산량. 피버 충전 가격이 피버 중에 부풀지 않게
	# 가격 계산은 반드시 이쪽을 본다.
	if not is_shelter_facility_unlocked("catnip_scraper"):
		return 0.0
	var total := 0.0
	for worker_id in assigned_catnip_worker_ids:
		total += get_worker_production_per_second(worker_id, "catnip")
	return total * (1.0 + INFUSION_BONUS_PER_LEVEL * catnip_infusion_level)


func tick_shelter_live(delta: float) -> int:
	var safe_delta := maxf(delta, 0.0)
	var scrap_rate := get_scrap_per_second()
	var catnip_rate := get_catnip_per_second()
	# 연료 게이트는 없다 — 주민이 배치돼 있으면 두 라인은 늘 함께 돈다.
	var work_delta := safe_delta
	var gain := scrap_rate * work_delta
	var catnip_gain := catnip_rate * work_delta
	shelter_scrap_fraction += gain
	shelter_catnip_fraction += catnip_gain
	var whole_catnip := int(floor(shelter_catnip_fraction))
	if whole_catnip > 0:
		shelter_catnip_fraction -= float(whole_catnip)
		catnip += whole_catnip
	var whole := int(floor(shelter_scrap_fraction))
	if whole <= 0:
		return 0
	shelter_scrap_fraction -= float(whole)
	scrap += whole
	return whole


func _ensure_resident_records() -> void:
	while resident_cat_ids.size() < rescued_workers:
		var next_index := resident_cat_ids.size() + 1
		var resident_id := "resident_%03d" % next_index
		resident_cat_ids.append(resident_id)
		var new_record: Dictionary = RESIDENT_TRAIT_PRESETS[
			(next_index - 1) % RESIDENT_TRAIT_PRESETS.size()
		].duplicate(true)
		resident_traits[resident_id] = _ensure_resident_identity(resident_id, new_record)
	if resident_cat_ids.size() > rescued_workers:
		resident_cat_ids.resize(rescued_workers)
	for resident_id in resident_cat_ids:
		var record: Dictionary
		if resident_traits.has(resident_id):
			record = (resident_traits[resident_id] as Dictionary).duplicate(true)
		else:
			var resident_index := maxi(0, int(resident_id.trim_prefix("resident_")) - 1)
			record = RESIDENT_TRAIT_PRESETS[resident_index % RESIDENT_TRAIT_PRESETS.size()].duplicate(true)
		resident_traits[resident_id] = _ensure_resident_identity(resident_id, record)
	_sanitize_assigned_workers()


func _ensure_resident_identity(resident_id: String, record: Dictionary) -> Dictionary:
	if str(record.get("display_name", "")).is_empty():
		var used_names: Array[String] = []
		for resident_value in resident_traits.values():
			var resident_record := resident_value as Dictionary
			var used_name := str(resident_record.get("display_name", ""))
			if not used_name.is_empty():
				used_names.append(used_name)
		var start_index := posmod(hash("%s:%d" % [resident_id, map_seed]), RESIDENT_NAME_POOL.size())
		var selected_name := ""
		for offset in RESIDENT_NAME_POOL.size():
			var candidate := RESIDENT_NAME_POOL[(start_index + offset) % RESIDENT_NAME_POOL.size()]
			if not used_names.has(candidate):
				selected_name = candidate
				break
		if selected_name.is_empty():
			selected_name = "%s %02d" % [
				RESIDENT_NAME_POOL[start_index],
				resident_cat_ids.find(resident_id) + 1,
			]
		record["display_name"] = selected_name
	if not record.has("portrait_index"):
		record["portrait_index"] = posmod(
			hash("portrait:%s:%d" % [resident_id, map_seed]),
			RESIDENT_PORTRAIT_COUNT
		)
	return record


func _sanitize_assigned_workers() -> void:
	var cleaned: Array[String] = []
	for worker_id in assigned_worker_ids:
		if cleaned.size() >= get_scratcher_worker_slots():
			break
		if resident_cat_ids.has(worker_id) and not cleaned.has(worker_id):
			cleaned.append(worker_id)
	assigned_worker_ids = cleaned
	var cleaned_catnip: Array[String] = []
	for worker_id in assigned_catnip_worker_ids:
		if cleaned_catnip.size() >= get_catnip_worker_slots():
			break
		if resident_cat_ids.has(worker_id) and not cleaned.has(worker_id) and not cleaned_catnip.has(worker_id):
			cleaned_catnip.append(worker_id)
	assigned_catnip_worker_ids = cleaned_catnip


func assign_worker_to_scratcher(worker_id: String) -> bool:
	if not is_shelter_facility_unlocked("scratcher_bank"):
		return false
	_ensure_resident_records()
	if not resident_cat_ids.has(worker_id):
		return false
	if assigned_worker_ids.has(worker_id):
		return true
	if assigned_worker_ids.size() >= get_scratcher_worker_slots():
		return false
	assigned_catnip_worker_ids.erase(worker_id)
	assigned_worker_ids.append(worker_id)
	return true


func unassign_worker_from_scratcher(worker_id: String) -> void:
	assigned_worker_ids.erase(worker_id)


func toggle_worker_assignment(worker_id: String) -> bool:
	if assigned_worker_ids.has(worker_id):
		unassign_worker_from_scratcher(worker_id)
		return false
	return assign_worker_to_scratcher(worker_id)


func assign_worker_to_catnip(worker_id: String) -> bool:
	if not is_shelter_facility_unlocked("catnip_scraper"):
		return false
	_ensure_resident_records()
	if not resident_cat_ids.has(worker_id):
		return false
	if assigned_catnip_worker_ids.has(worker_id):
		return true
	if assigned_catnip_worker_ids.size() >= get_catnip_worker_slots():
		return false
	assigned_worker_ids.erase(worker_id)
	assigned_catnip_worker_ids.append(worker_id)
	return true


func unassign_worker_from_catnip(worker_id: String) -> void:
	assigned_catnip_worker_ids.erase(worker_id)


func toggle_catnip_worker_assignment(worker_id: String) -> bool:
	if assigned_catnip_worker_ids.has(worker_id):
		unassign_worker_from_catnip(worker_id)
		return false
	return assign_worker_to_catnip(worker_id)


func get_workbench_repair_per_hour() -> float:
	var base_rate := 18.0
	if shelter_workbench_level >= 3:
		base_rate *= 1.2
	if shelter_workbench_level >= 5:
		base_rate *= 1.18
	return base_rate


func process_shelter_progress() -> Dictionary:
	_ensure_resident_records()
	var now := int(Time.get_unix_time_from_system())
	if shelter_last_progress_time <= 0:
		shelter_last_progress_time = now
		return {"scrap": 0, "catnip": 0, "repair": 0.0, "elapsed": 0}
	# 자리를 비운 시간은 SHELTER_OFFLINE_MAX_SECONDS까지만 쳐준다(연료 대신 시간 상한).
	var raw_elapsed := maxi(0, now - shelter_last_progress_time)
	var elapsed := mini(raw_elapsed, SHELTER_OFFLINE_MAX_SECONDS)
	var progress_start := now - elapsed
	shelter_last_progress_time = now
	var base_scrap_rate := get_base_scrap_per_hour()
	# 주민마다 오프라인 규칙이 다르다(대식가 0배 / 소식가 16h 상한). 기본값은
	# 전량·8h라 특성이 없는 주민은 종전 계산과 같다.
	var base_scrap_gain := 0.0
	if is_shelter_facility_unlocked("scratcher_bank"):
		for worker_id in assigned_worker_ids:
			var worker_rate_per_hour := get_worker_production_per_second(worker_id, "kneading") * 3600.0
			var worker_seconds := float(mini(raw_elapsed, get_worker_offline_cap_seconds(worker_id)))
			base_scrap_gain += worker_rate_per_hour * worker_seconds / 3600.0 * get_worker_offline_factor(worker_id)
	var catnip_gain_raw := 0.0
	if is_shelter_facility_unlocked("catnip_scraper"):
		var catnip_line_multiplier := (
			(1.0 + INFUSION_BONUS_PER_LEVEL * catnip_infusion_level)
			* get_active_catnip_fever_multiplier()
		)
		for worker_id in assigned_catnip_worker_ids:
			var worker_catnip_per_second := get_worker_production_per_second(worker_id, "catnip") * catnip_line_multiplier
			var worker_seconds := float(mini(raw_elapsed, get_worker_offline_cap_seconds(worker_id)))
			catnip_gain_raw += worker_catnip_per_second * worker_seconds * get_worker_offline_factor(worker_id)
	var work_seconds := float(elapsed)
	var boosted_seconds := mini(roundi(work_seconds), maxi(0, mini(now, catnip_boost_end_time) - progress_start))
	var boosted_extra := base_scrap_rate * float(boosted_seconds) / 3600.0 * (CATNIP_BOOST_MULTIPLIER - 1.0)
	shelter_scrap_fraction += base_scrap_gain + boosted_extra
	var scrap_gain := int(floor(shelter_scrap_fraction))
	shelter_scrap_fraction -= float(scrap_gain)
	shelter_catnip_fraction += catnip_gain_raw
	var catnip_gain := int(floor(shelter_catnip_fraction))
	shelter_catnip_fraction -= float(catnip_gain)
	catnip += catnip_gain
	var repair_gain := 0.0
	if workbench_repair_active and weapon_durability < 100.0:
		repair_gain = get_workbench_repair_per_hour() * float(elapsed) / 3600.0
		var before := weapon_durability
		weapon_durability = minf(100.0, weapon_durability + repair_gain)
		repair_gain = weapon_durability - before
		if weapon_durability >= 100.0:
			workbench_repair_active = false
	if scrap_gain > 0:
		scrap += scrap_gain
	shelter_offline_scrap_pending += scrap_gain
	shelter_offline_catnip_pending += catnip_gain
	shelter_offline_repair_pending += repair_gain
	return {"scrap": scrap_gain, "catnip": catnip_gain, "repair": repair_gain, "elapsed": elapsed}


func get_current_raid_stage_tier() -> int:
	# 선택(진행) 중인 출정 존의 스테이지 티어 — 귀중품 존 가치 배율의 기준.
	return LOOT_ECONOMY.get_stage_for_zone(get_raid_zone())


func get_valuable_unit_value(valuable_id: String, stage_tier: int = -1) -> int:
	# 귀중품 1개의 환전 가치 = 카탈로그 base_value × 존 배율(기본: 현재 출정 존).
	var base := int((LOOT_ECONOMY.ITEM_CATALOG.get(valuable_id, {}) as Dictionary).get("base_value", 0))
	var tier := get_current_raid_stage_tier() if stage_tier <= 0 else stage_tier
	return int(round(float(base) * LOOT_ECONOMY.get_valuable_stage_multiplier(tier)))


func get_valuable_total_value() -> int:
	var total := 0
	for valuable_id in valuable_inventory.keys():
		var amount := maxi(0, int(valuable_inventory[valuable_id]))
		if amount <= 0:
			continue
		# 원장(주운 존의 배율이 반영된 누적 가치)이 있으면 그 값, 없으면(구세이브) 카탈로그×개수.
		if valuable_value_ledger.has(valuable_id) and int(valuable_value_ledger[valuable_id]) > 0:
			total += int(valuable_value_ledger[valuable_id])
			continue
		total += amount * int(
			(LOOT_ECONOMY.ITEM_CATALOG.get(str(valuable_id), {}) as Dictionary).get("base_value", 0)
		)
	return total


func get_valuable_total_count() -> int:
	# 귀중품은 get_raid_bag_entries()에 안 들어간다(가방 칸을 안 먹는 별도 목록).
	# 정산 화면의 '가져온 것'이 귀중품을 통째로 빠뜨리던 원인이라 개수를 따로 센다.
	var count := 0
	for amount in valuable_inventory.values():
		count += maxi(0, int(amount))
	return count


func grant_extraction_risk_payout(kills: int, pressure_level: int, reward_multiplier: float) -> int:
	# 출정 자체가 진행 통화를 벌게 한다. 예전에는 고철이 거의 전부 쉘터
	# 수동 생산에서 나와, 중반부터 출정이 "심부름"이 되고 진행은 대기가 됐다.
	# 오래 버티고(긴장도) 싸운(킬) 대가를 고철로 직접 준다.
	var base := 1000 + maxi(0, kills) * 180
	var risk := 1.0 + float(clampi(pressure_level, 0, 3)) * 0.6
	var payout := roundi(float(base) * risk * maxf(1.0, reward_multiplier))
	scrap += payout
	return payout


func sell_all_valuables() -> Dictionary:
	# 귀중품은 용도가 없다. 쉘터에 돌아와 고철로 바꾸는 것이 유일한 출구다.
	var total := get_valuable_total_value()
	var count := 0
	for amount in valuable_inventory.values():
		count += maxi(0, int(amount))
	if total <= 0:
		return {"scrap": 0, "count": 0}
	valuable_inventory.clear()
	valuable_value_ledger.clear()
	scrap += total
	save_persistent_state()
	return {"scrap": total, "count": count}


func get_resident_reroll_cost(resident_id: String) -> int:
	var times := int(resident_reroll_counts.get(resident_id, 0))
	return mini(
		RESIDENT_REROLL_MAX_COST,
		RESIDENT_REROLL_BASE_COST + RESIDENT_REROLL_STEP * times
	)


func try_reroll_resident_trait(resident_id: String) -> Dictionary:
	# 특성이 트레이드오프가 된 이상, 마음에 안 드는 조합을 바꿀 길이 있어야 한다.
	if not resident_cat_ids.has(resident_id):
		return {"ok": false, "reason": "unknown"}
	var cost := get_resident_reroll_cost(resident_id)
	if churu < cost:
		return {"ok": false, "reason": "churu", "cost": cost}
	var current := get_resident_trait(resident_id)
	var current_name := str(current.get("name", ""))
	# 같은 특성이 다시 나오면 돈만 버린 셈이 된다. 후보에서 뺀다.
	var candidates: Array[Dictionary] = []
	for preset in RESIDENT_TRAIT_PRESETS:
		if str((preset as Dictionary).get("name", "")) != current_name:
			candidates.append(preset as Dictionary)
	if candidates.is_empty():
		return {"ok": false, "reason": "no_candidates"}
	churu -= cost
	resident_reroll_counts[resident_id] = int(resident_reroll_counts.get(resident_id, 0)) + 1
	var picked := candidates[randi() % candidates.size()].duplicate(true)
	# 이름·초상화 같은 정체성은 유지하고 능력치만 바꾼다.
	var record := (resident_traits.get(resident_id, {}) as Dictionary).duplicate(true)
	for key in ["name", "kneading", "catnip"]:
		record[key] = picked.get(key, record.get(key))
	# 오프라인 규칙 같은 부가 키는 새 특성 기준으로 갈아끼운다 — 지난 특성의
	# 페널티가 남으면 '대식가였던 평범한 주민'이 계속 오프라인 0이 된다.
	for key in ["offline", "offline_cap_hours", "quirk"]:
		record.erase(key)
		if picked.has(key):
			record[key] = picked[key]
	resident_traits[resident_id] = record
	save_persistent_state()
	return {"ok": true, "cost": cost, "trait": record}


func is_milestone_unlocked(milestone_id: String) -> bool:
	return unlocked_milestones.has(milestone_id)


func _milestone_condition_met(definition: Dictionary) -> bool:
	var progression_id := str(definition.get("requires_progression", ""))
	if not progression_id.is_empty() and get_progression_item_count(progression_id) <= 0:
		return false
	var blueprint_recipe := str(definition.get("requires_blueprint", ""))
	if not blueprint_recipe.is_empty() and not is_blueprint_unlocked(blueprint_recipe):
		return false
	var required_residents := int(definition.get("requires_residents", 0))
	if required_residents > 0 and rescued_workers < required_residents:
		return false
	var required_bosses := int(definition.get("requires_boss_kills", 0))
	if required_bosses > 0 and total_boss_kills < required_bosses:
		return false
	return true


func check_milestone_unlocks() -> Array[Dictionary]:
	# 새로 넘긴 문턱만 돌려준다. 호출한 쪽이 연출을 담당한다.
	var newly_unlocked: Array[Dictionary] = []
	for milestone_id in MILESTONE_UNLOCKS.keys():
		var key := str(milestone_id)
		if unlocked_milestones.has(key):
			continue
		var definition := MILESTONE_UNLOCKS[key] as Dictionary
		if not _milestone_condition_met(definition):
			continue
		unlocked_milestones.append(key)
		var entry := definition.duplicate(true)
		entry["id"] = key
		newly_unlocked.append(entry)
	if not newly_unlocked.is_empty():
		save_persistent_state()
	return newly_unlocked


func capture_pre_raid_snapshot() -> void:
	# 출정 직전 상태를 남겨 둔다. 다음 출정 브리핑에서 "지난번과 무엇이
	# 달라졌는지"를 만들기 위한 기준점이다.
	pre_raid_snapshot = {
		"bag_capacity": get_raid_bag_capacity(),
		"max_health": get_max_health(),
		"player_level": player_level,
		"weapon_level": get_weapon_enhancement_level(equipped_weapon_id),
		"shelter_tier": shelter_tier,
		"residents": resident_cat_ids.size(),
		"facilities": shelter_facility_unlocks.keys().filter(
			func(key: Variant) -> bool: return bool(shelter_facility_unlocks.get(key, false))
		).size(),
	}
	save_persistent_state()


func build_pre_raid_changes() -> Array[String]:
	# 성장은 상태가 아니라 차이에서 느껴진다. 출정 전에 자기가 강해진 것을
	# 확인하고 나가는 것과 그냥 나가는 것은 완전히 다르다.
	var changes: Array[String] = []
	if pre_raid_snapshot.is_empty():
		return changes
	var rows := [
		["bag_capacity", "가방", get_raid_bag_capacity(), "칸"],
		["max_health", "최대 체력", get_max_health(), ""],
		["player_level", "레벨", player_level, ""],
		["weapon_level", "무기 강화", get_weapon_enhancement_level(equipped_weapon_id), "단계"],
		["shelter_tier", "쉘터 단계", shelter_tier, ""],
		["residents", "주민", resident_cat_ids.size(), "명"],
	]
	for row in rows:
		var key := str(row[0])
		if not pre_raid_snapshot.has(key):
			continue
		var before := int(pre_raid_snapshot.get(key, 0))
		var after := int(row[2])
		if after <= before:
			continue
		changes.append("%s  %d → %d%s" % [str(row[1]), before, after, str(row[3])])
	var facility_before := int(pre_raid_snapshot.get("facilities", 0))
	var facility_after := shelter_facility_unlocks.keys().filter(
		func(key: Variant) -> bool: return bool(shelter_facility_unlocks.get(key, false))
	).size()
	if facility_after > facility_before:
		changes.append("새 시설 %d곳 가동" % (facility_after - facility_before))
	return changes


static func format_duration_korean(total_seconds: float) -> String:
	var seconds := maxi(0, roundi(total_seconds))
	if seconds <= 0:
		return "0분"
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%d시간 %d분" % [hours, minutes]
	if hours > 0:
		return "%d시간" % hours
	return "%d분" % maxi(1, minutes)


func get_active_contract_progress_text() -> String:
	# 정산 화면이 "끝난 것"만 정리하고 "다음"을 말하지 않으면 한 판 더 나갈
	# 이유가 텍스트로만 남는다. 남은 거리를 숫자로 보여준다.
	var contract := get_current_contract_definition()
	if contract.is_empty() or contract_status != "active":
		return ""
	var target := maxi(1, int(contract.get("target", 1)))
	var progress := clampi(contract_progress, 0, target)
	var remaining := maxi(0, target - progress)
	var objective := str(contract.get("objective", "목표"))
	if remaining <= 0:
		return "%s %d / %d · 사자에게 보고하면 %s" % [
			objective,
			progress,
			target,
			get_shelter_facility_name(str(contract.get("facility_unlock", "다음 시설"))),
		]
	return "%s %d / %d · %d개 더 모으면 %s" % [
		objective,
		progress,
		target,
		remaining,
		get_shelter_facility_name(str(contract.get("facility_unlock", "다음 시설"))),
	]


func is_churu_buff_active(buff_id: String) -> bool:
	return active_churu_buffs.has(buff_id)


func try_activate_churu_buff(buff_id: String) -> bool:
	if not CHURU_BUFFS.has(buff_id) or active_churu_buffs.has(buff_id):
		return false
	var cost := maxi(1, int((CHURU_BUFFS[buff_id] as Dictionary).get("cost", 1)))
	if churu < cost:
		return false
	churu -= cost
	active_churu_buffs.append(buff_id)
	if buff_id == "full_belly":
		player_health = get_max_health()
	save_persistent_state()
	return true


func clear_churu_buffs() -> void:
	if active_churu_buffs.is_empty():
		return
	active_churu_buffs.clear()
	player_health = mini(player_health, get_max_health())


func get_churu_bag_bonus_slots() -> int:
	return 4 if is_churu_buff_active("big_pockets") else 0


func get_catnip_boost_cost() -> int:
	# 생산 부스트도 같은 원리 — 생산 30분치.
	return maxi(CATNIP_BOOST_COST, roundi(get_catnip_per_second() * 60.0 * 30.0))


func get_shelter_stall_reason() -> String:
	# 라인이 멈추는 이유는 이제 하나뿐이다 — 주민 미배치. 연료 부족은 없다.
	if get_active_scratcher_workers() + get_active_catnip_workers() <= 0:
		return "no_workers"
	return ""


func get_shelter_upgrade_cost() -> Dictionary:
	return (SHELTER_UPGRADE_COSTS.get(shelter_tier + 1, {}) as Dictionary).duplicate(true)


func try_upgrade_shelter_tier() -> bool:
	var next_tier := shelter_tier + 1
	if next_tier > 5:
		return false
	var cost := SHELTER_UPGRADE_COSTS.get(next_tier, {}) as Dictionary
	var scrap_cost := int(cost.get("scrap", 0))
	var churu_cost := int(cost.get("churu", 0))
	if scrap < scrap_cost or churu < churu_cost:
		return false
	# 서사 키(티어 3~5). 소급 없음 — 이미 그 티어 이상인 세이브는 다음 티어 키만 본다.
	# 키는 소모하지 않는다.
	var key_item := str(cost.get("key_item", ""))
	if not key_item.is_empty() and get_progression_item_count(key_item) <= 0:
		return false
	scrap -= scrap_cost
	churu -= churu_cost
	shelter_tier = next_tier
	_sanitize_assigned_workers()
	save_persistent_state()
	return true


func get_workbench_upgrade_cost() -> Dictionary:
	var next_level := shelter_workbench_level + 1
	if next_level > 5:
		return {}
	return {"scrap": int(WORKBENCH_UPGRADE_COSTS.get(next_level, 0))}


func try_upgrade_workbench() -> bool:
	var next_level := shelter_workbench_level + 1
	if next_level > 5:
		return false
	var cost := int(WORKBENCH_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	shelter_workbench_level = next_level
	return true


func try_upgrade_scratcher_bank() -> bool:
	var next_level := scratcher_bank_level + 1
	if next_level > SCRATCHER_BANK_MAX_LEVEL:
		return false
	var cost := int(SCRATCHER_UPGRADE_COSTS.get(next_level, 0))
	var catnip_cost := int(SCRATCHER_UPGRADE_CATNIP_COSTS.get(next_level, 0))
	if scrap < cost or catnip < catnip_cost:
		return false
	scrap -= cost
	catnip -= catnip_cost
	scratcher_bank_level = next_level
	# 착즙(1.8ⁿ)과 균형 — 2.2ⁿ은 후반 고철 인플레를 만들었다.
	scratcher_multiplier = pow(1.9, float(scratcher_bank_level - 1))
	return true


func try_upgrade_catnip_scraper() -> bool:
	var next_level := catnip_scraper_level + 1
	if next_level > 5:
		return false
	var cost := int(CATNIP_SCRAPER_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	catnip_scraper_level = next_level
	catnip_scraper_multiplier = pow(1.8, float(catnip_scraper_level - 1))
	return true


func get_weapon_count(weapon_id: String) -> int:
	return int(weapon_inventory.get(weapon_id, 0))


func has_any_weapon() -> bool:
	for count in weapon_inventory.values():
		if int(count) > 0:
			return true
	return false




func get_weapon_enhancement_level(weapon_id: String) -> int:
	return clampi(int(weapon_enhancement_levels.get(weapon_id, 0)), 0, MAX_WEAPON_ENHANCEMENT)


func get_weapon_enhancement_cost(weapon_id: String) -> int:
	var level := get_weapon_enhancement_level(weapon_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return 0
	var weapon_factor := 1.0
	match weapon_id:
		"mp5": weapon_factor = 1.2
		"ak47": weapon_factor = 1.55
		"double_barrel": weapon_factor = 1.4
		# 사다리 상위 기종 — 기본 피해가 높은 만큼 같은 +N에 더 비싸다.
		"akm": weapon_factor = 1.7
		"pump_shotgun": weapon_factor = 1.5
		"k2": weapon_factor = 2.0
	# ×1.11 → ×1.28(+1~30) → 3구간(대개편 3단계). 쉘터 수입이 지수(생산기 Lv당 ×1.9, 주민 수)로
	# 크는데 강화 비용은 완만해 티어 3쯤엔 한 시간 수입으로 +40을 찍었다 — 싱크가 아니라
	# 파워 폭주 경로였다. 반대로 ×1.28 단일 지수는 +60 이후가 영원히 닿지 않는 구간이었다.
	# WEAPON_ENHANCEMENT_SEGMENTS: +10 10.6K, +30 1.5M(×1.28) → +31~60 ×1.10 → +61~99 ×1.055.
	# '항상 다음 버튼이 있지만 공짜는 아닌' 인크리멘탈 곡선.
	return maxi(900, roundi(900.0 * weapon_factor * _segmented_growth(level, WEAPON_ENHANCEMENT_SEGMENTS)))


const WEAPON_ENHANCEMENT_PART_CYCLE: Array[String] = ["magazine_spring", "rubber_gasket", "scope_lens"]


func get_weapon_enhancement_part_cost(weapon_id: String) -> Dictionary:
	# 고단계 강화는 고철만으로 안 된다 — 필드 부품이 들어간다. +10까지는 고철만,
	# +11~20 일반 부품 1종, +21~30 2종, +31부터 3종(한 종류씩). 종류당 개수는
	# +1~40 1개 · +41~80 2개 · +81~99 3개(대개편 3단계 — 출정이 후반에도 이유가 되게).
	# 희귀 부품: +31~80 정밀 기어 1, +81~99 정밀 기어 2. 군용 합금은 돌파(get_breakthrough_cost)
	# 전용으로 옮겨 "합금 = 돌파 재료"라는 정체성을 준다.
	# 부품은 필드 전용이라 넘치는 고철에 '출정 이유'를 한 번 더 묶는다. 부품 종류는
	# 단계마다 돌아가며 요구해 한 종류만 쌓아 두는 플레이를 막는다.
	return _gear_enhancement_part_cost(get_weapon_enhancement_level(weapon_id) + 1, MAX_WEAPON_ENHANCEMENT)


func _gear_enhancement_part_cost(next_level: int, max_level: int) -> Dictionary:
	# 무기·방어구 공통 부품 규칙(다음 단계 기준).
	if next_level > max_level:
		return {}
	var part_kinds := 0
	if next_level > 30:
		part_kinds = 3
	elif next_level > 20:
		part_kinds = 2
	elif next_level > 10:
		part_kinds = 1
	# 종류당 개수: 1 + (next−1)/40 → +1~40 1개 · +41~80 2개 · +81~99 3개.
	var per_kind := 1 + (next_level - 1) / 40
	var cost := {}
	for offset in part_kinds:
		var part_id := WEAPON_ENHANCEMENT_PART_CYCLE[(next_level + offset) % WEAPON_ENHANCEMENT_PART_CYCLE.size()]
		cost[part_id] = int(cost.get(part_id, 0)) + per_kind
	if next_level > 80:
		cost["precision_gear"] = int(cost.get("precision_gear", 0)) + 2
	elif next_level > 30:
		cost["precision_gear"] = int(cost.get("precision_gear", 0)) + 1
	return cost


func try_enhance_weapon(weapon_id: String) -> bool:
	if get_weapon_count(weapon_id) <= 0:
		return false
	var level := get_weapon_enhancement_level(weapon_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return false
	# 돌파 게이트 — +10·+20·… 에서는 장인의 인장으로 돌파해야 다음 강화가 열린다.
	if is_breakthrough_required("weapon", weapon_id):
		return false
	var cost := get_weapon_enhancement_cost(weapon_id)
	if scrap < cost:
		return false
	scrap -= cost
	weapon_enhancement_levels[weapon_id] = level + 1
	if weapon_id == equipped_weapon_id:
		weapon_level = level + 2
	save_persistent_state()
	return true


# ── 방어구 +99 강화 ─────────────────────────────────────────────
# 무기와 같은 규칙(부품 단계·돌파)이되 비용 곡선은 400×가족계수(T1 1.0/T2 1.5/T3 2.2)
# ×ARMOR_ENHANCEMENT_SEGMENTS(+1~30 ×1.26 · +31~60 ×1.09 · +61~99 ×1.045) — 무기보다
# 완만하다. 세 슬롯을 같이 키워야 하므로(T3 세트 +99 ≈ 5.0B ≈ K2 +99의 절반 남짓).
# 키는 기본 id(레벨 접미사 없음). 보유(가방·창고·장착 어디든) 중인 방어구만 강화된다.


func armor_enhancement_key(equipment_id: String) -> String:
	return str(split_equipment_id(equipment_id)[0])


func get_armor_enhancement_level(equipment_id: String) -> int:
	return clampi(int(armor_enhancement_levels.get(armor_enhancement_key(equipment_id), 0)), 0, MAX_ARMOR_ENHANCEMENT)


func get_armor_family_index(equipment_id: String) -> int:
	# ARMOR_FAMILY_LADDER 단(0=T1·1=T2·2=T3). 모르는 id는 T1.
	var base_id := armor_enhancement_key(equipment_id)
	for slot in ARMOR_FAMILY_LADDER.keys():
		var ladder: Array = ARMOR_FAMILY_LADDER[slot]
		var index := ladder.find(base_id)
		if index >= 0:
			return index
	return 0


func get_armor_enhancement_cost(equipment_id: String) -> int:
	var level := get_armor_enhancement_level(equipment_id)
	if level >= MAX_ARMOR_ENHANCEMENT:
		return 0
	var family_factor := float(ARMOR_FAMILY_FACTORS[clampi(get_armor_family_index(equipment_id), 0, ARMOR_FAMILY_FACTORS.size() - 1)])
	return maxi(400, roundi(ARMOR_ENHANCEMENT_BASE_COST * family_factor * _segmented_growth(level, ARMOR_ENHANCEMENT_SEGMENTS)))


func get_armor_enhancement_part_cost(equipment_id: String) -> Dictionary:
	return _gear_enhancement_part_cost(get_armor_enhancement_level(equipment_id) + 1, MAX_ARMOR_ENHANCEMENT)


func get_armor_enhancement_multiplier(equipment_id: String) -> float:
	return armor_enhancement_multiplier_for_level(get_armor_enhancement_level(equipment_id))


func armor_enhancement_multiplier_for_level(level: int) -> float:
	# 효과 배율 = 1 + 0.6×(1−0.96^L): +10 ×1.20 · +30 ×1.42 · +50 ×1.52 · +99 ×1.59(수렴 1.6).
	# 레벨 인자 버전은 작업대 강화 보드의 "현재 ▲ 다음" 미리보기가 같은 곡선을 보게 하려는 것.
	if level <= 0:
		return 1.0
	return 1.0 + 0.6 * (1.0 - pow(0.96, float(clampi(level, 0, MAX_ARMOR_ENHANCEMENT))))


func is_armor_base_owned(base_id: String) -> bool:
	# 장착·가방·창고 어디든, 레벨 접미사(@n)는 무시하고 기종으로 본다.
	for equipped_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not str(equipped_id).is_empty() and armor_enhancement_key(str(equipped_id)) == base_id:
			return true
	for equipment_id_value in equipment_inventory.keys():
		if get_equipment_count(str(equipment_id_value)) > 0 and armor_enhancement_key(str(equipment_id_value)) == base_id:
			return true
	for entry in storage_inventory:
		if str(entry.get("type", "")) == "equipment" and int(entry.get("count", 0)) > 0 and armor_enhancement_key(str(entry.get("id", ""))) == base_id:
			return true
	return false


func try_enhance_armor(equipment_id: String) -> bool:
	# 부품은 작업대가 가방+창고 합산으로 보고 성공 시 태운다(무기 강화와 같은 규약).
	var base_id := armor_enhancement_key(equipment_id)
	if not is_armor_base_owned(base_id):
		return false
	var level := get_armor_enhancement_level(base_id)
	if level >= MAX_ARMOR_ENHANCEMENT:
		return false
	if is_breakthrough_required("armor", base_id):
		return false
	var cost := get_armor_enhancement_cost(base_id)
	if scrap < cost:
		return false
	scrap -= cost
	armor_enhancement_levels[base_id] = level + 1
	save_persistent_state()
	return true


func transfer_armor_enhancement_on_first_own(to_base_id: String) -> Dictionary:
	# 같은 슬롯 사다리에서 아래 단계(강화가 가장 높은 것)의 60%를 내림 이관. 상위 1종당
	# 평생 1회 — 무기 이관(transfer_weapon_enhancement_on_first_own)과 같은 규약.
	if armor_enhancement_transfers_done.has(to_base_id):
		return {}
	var lower_ids: Array[String] = get_lower_armor_ladder_ids(to_base_id)
	if lower_ids.is_empty():
		return {}
	armor_enhancement_transfers_done.append(to_base_id)
	var from_id := ""
	var from_level := 0
	for candidate_id in lower_ids:
		var level := get_armor_enhancement_level(candidate_id)
		if level > from_level:
			from_level = level
			from_id = candidate_id
	if from_id.is_empty() or from_level <= 0:
		return {}
	var transferred_level := int(floor(float(from_level) * WEAPON_SYSTEM.ENHANCEMENT_TRANSFER_RATIO))
	var previous_level := get_armor_enhancement_level(to_base_id)
	var next_level := clampi(maxi(previous_level, transferred_level), 0, MAX_ARMOR_ENHANCEMENT)
	if next_level <= previous_level:
		return {}
	armor_enhancement_levels[to_base_id] = next_level
	var result := {
		"from_id": from_id,
		"to_id": to_base_id,
		"from_level": from_level,
		"previous_level": previous_level,
		"level": next_level,
		"notice": "%s +%d의 강화를 이어받았다 → %s +%d" % [
			str(get_equipment_definition(from_id).get("display_name", from_id)), from_level,
			str(get_equipment_definition(to_base_id).get("display_name", to_base_id)), next_level,
		],
	}
	last_armor_enhancement_transfer = result
	return result


func take_armor_enhancement_transfer_notice() -> String:
	if last_armor_enhancement_transfer.is_empty():
		return ""
	var notice := str(last_armor_enhancement_transfer.get("notice", ""))
	last_armor_enhancement_transfer = {}
	return notice


func get_lower_armor_ladder_ids(base_id: String) -> Array[String]:
	var result: Array[String] = []
	for slot in ARMOR_FAMILY_LADDER.keys():
		var ladder: Array = ARMOR_FAMILY_LADDER[slot]
		var index := ladder.find(base_id)
		if index < 0:
			continue
		for lower_index in index:
			result.append(str(ladder[lower_index]))
		return result
	return result


# ── 돌파(장인) ──────────────────────────────────────────────────
# L = 10·20·…·90에서 다음 단계로 가려면 장인의 인장 1 + 희귀 부품(정밀 기어 L/10,
# +50부터 군용 합금 (L−40)/10) + 고철(그 단계 강화 비용 × 3). 옛 "장인 뽑기"
# (roll_artisan_weapon)는 폐지 — 장인은 이제 돌파 서비스다. 작업대 '장인' 탭의 재구성은
# 2단계 UI 몫이고, 여기는 데이터 함수만 둔다.


func gear_breakthrough_key(kind: String, item_id: String) -> String:
	return "%s:%s" % [kind, armor_enhancement_key(item_id) if kind == "armor" else item_id]


func get_gear_enhancement_level(kind: String, item_id: String) -> int:
	return get_armor_enhancement_level(item_id) if kind == "armor" else get_weapon_enhancement_level(item_id)


func get_gear_enhancement_cost(kind: String, item_id: String) -> int:
	return get_armor_enhancement_cost(item_id) if kind == "armor" else get_weapon_enhancement_cost(item_id)


func get_gear_enhancement_part_cost(kind: String, item_id: String) -> Dictionary:
	return get_armor_enhancement_part_cost(item_id) if kind == "armor" else get_weapon_enhancement_part_cost(item_id)


func get_breakthrough_level_done(kind: String, item_id: String) -> int:
	return maxi(0, int(gear_breakthroughs.get(gear_breakthrough_key(kind, item_id), 0)))


func is_breakthrough_required(kind: String, item_id: String) -> bool:
	# 현재 레벨이 10의 배수(10~90)이고 그 단계의 돌파를 아직 안 했으면 강화가 막힌다.
	var level := get_gear_enhancement_level(kind, item_id)
	if level <= 0 or level >= MAX_WEAPON_ENHANCEMENT or level % BREAKTHROUGH_STEP != 0:
		return false
	return get_breakthrough_level_done(kind, item_id) < level


func get_breakthrough_cost(kind: String, item_id: String) -> Dictionary:
	# 돌파가 필요 없는 상태면 빈 딕셔너리.
	if not is_breakthrough_required(kind, item_id):
		return {}
	# 대개편 3단계 — 돌파가 '출정 이유'가 되게 희귀 재료를 단계에 비례시킨다.
	#   인장: 무기 L/10(+10 1 … +90 9) · 방어구 L/20(+10~+30 1 … +90 4) — 방어구는 피스 3개라 절반.
	#   정밀 기어: (L/10)×2 → +10 2 · +50 10 · +90 18.
	#   군용 합금(+50~): (L−40)/5 → +50 2 · +70 6 · +90 10. 강화 단계 부품에서는 뺐다(돌파 전용).
	var level := get_gear_enhancement_level(kind, item_id)
	var seal_divisor := BREAKTHROUGH_STEP * 2 if kind == "armor" else BREAKTHROUGH_STEP
	var cost := {
		"scrap": get_gear_enhancement_cost(kind, item_id) * 3,
		ARTISAN_SEAL_ID: maxi(1, level / seal_divisor),
		"precision_gear": maxi(1, level / BREAKTHROUGH_STEP) * 2,
	}
	if level >= 50:
		cost["military_alloy"] = maxi(1, (level - 40) / 5)
	return cost


func get_owned_component_total(component_id: String) -> int:
	# 가방 + 창고(작업대 규약과 동일).
	return get_mod_component_count(component_id) + get_stored_storage_count("component", component_id)


func consume_owned_component(component_id: String, amount: int) -> int:
	# 가방 몫을 먼저 태우고 모자란 만큼 창고에서 덜어낸다. 실제로 태운 수를 돌려준다.
	var remaining := maxi(0, amount)
	var from_bag := mini(remaining, get_mod_component_count(component_id))
	if from_bag > 0:
		mod_component_inventory[component_id] = maxi(0, get_mod_component_count(component_id) - from_bag)
		remaining -= from_bag
	if remaining > 0:
		remaining -= remove_stored_storage_item("component", component_id, remaining)
	return maxi(0, amount) - remaining


func consume_progression_item(item_id: String, amount: int) -> int:
	# 진행 아이템(인장 등)을 가방 → 창고 순으로 소모한다. 실제로 뺀 수를 돌려준다.
	var remaining := maxi(0, amount)
	var from_bag := mini(remaining, maxi(0, int(progression_item_inventory.get(item_id, 0))))
	if from_bag > 0:
		progression_item_inventory[item_id] = int(progression_item_inventory.get(item_id, 0)) - from_bag
		remaining -= from_bag
	if remaining > 0:
		remaining -= remove_stored_storage_item("progression", item_id, remaining)
	return maxi(0, amount) - remaining


func get_breakthrough_block_reason(kind: String, item_id: String) -> String:
	# 빈 문자열 = 돌파 가능. 아니면 무엇이 모자란지 한 줄.
	if not is_breakthrough_required(kind, item_id):
		return "돌파가 필요한 단계가 아닙니다."
	var cost := get_breakthrough_cost(kind, item_id)
	if scrap < int(cost.get("scrap", 0)):
		return "고철 %s 부족" % format_compact_number(int(cost.get("scrap", 0)) - scrap)
	if get_progression_item_count(ARTISAN_SEAL_ID) < int(cost.get(ARTISAN_SEAL_ID, 1)):
		return "장인의 인장 부족 — 보스 처치·메인 미션 3단계에서 나옵니다"
	for component_id in RARE_COMPONENT_IDS:
		var need := int(cost.get(component_id, 0))
		if need > 0 and get_owned_component_total(component_id) < need:
			var name := "정밀 기어" if component_id == "precision_gear" else "군용 합금"
			return "%s %d개 부족 — 엘리트·보스·봉인 보급함에서 나옵니다" % [name, need - get_owned_component_total(component_id)]
	return ""


func try_breakthrough(kind: String, item_id: String) -> bool:
	# 돌파 성공 시 인장·희귀 부품·고철을 태우고 그 단계를 기록한다. 강화 레벨은 그대로
	# (다음 try_enhance_*가 열린다).
	if not get_breakthrough_block_reason(kind, item_id).is_empty():
		return false
	if kind == "armor" and not is_armor_base_owned(armor_enhancement_key(item_id)):
		return false
	if kind == "weapon" and get_weapon_count(item_id) <= 0:
		return false
	var cost := get_breakthrough_cost(kind, item_id)
	scrap -= int(cost.get("scrap", 0))
	consume_progression_item(ARTISAN_SEAL_ID, int(cost.get(ARTISAN_SEAL_ID, 1)))
	for component_id in RARE_COMPONENT_IDS:
		var need := int(cost.get(component_id, 0))
		if need > 0:
			consume_owned_component(component_id, need)
	gear_breakthroughs[gear_breakthrough_key(kind, item_id)] = get_gear_enhancement_level(kind, item_id)
	save_persistent_state()
	return true


# ── 돌파 정체성 보너스(대개편 3단계) ─────────────────────────────
# 돌파는 비용 게이트만이 아니라 '정체성'을 준다. 단계(+30/+50/+70/+90)마다 하나씩,
# 판정은 "그 단계의 돌파를 마쳤는가"(gear_breakthroughs 기록 ≥ 단계, 또는 강화 레벨이
# 단계를 넘어섰으면 이미 돌파한 것). 적용 지점은 각 계산의 단일 함수:
#   무기 — build_player_weapon_stats(관통·탄창·장전·내구·스탯 키), enemy.take_projectile_hit(엘리트 피해),
#          main._on_enemy_died(처치 탄약 환급)
#   방어구 — main.take_hit(넉백 저항) · main/building_interior.take_damage(피격 후 추가 피해 −20%) ·
#          get_fatigue_gain_multiplier(피로) · get_secure_slot_count(시큐어 슬롯)
# 방어구는 장착 중인 피스 기준: +30(넉백)은 몸 슬롯만, 나머지는 장착 피스 중 하나라도 달성하면(중첩 없음).
const BREAKTHROUGH_PERKS := {
	"weapon": {
		30: {"id": "pierce", "label": "관통 +1", "description": "탄환이 적 하나를 더 꿰뚫는다."},
		50: {"id": "magazine", "label": "탄창 +25% · 장전 −15%", "description": "장탄수가 늘고 장전이 빨라진다."},
		70: {"id": "elite_damage", "label": "엘리트·보스 피해 +20%", "description": "일반 적에게는 적용되지 않는다."},
		90: {"id": "kill_refund", "label": "처치 시 탄약 10% 환급 · 내구 소모 0", "description": "적을 쓰러뜨릴 때마다 탄창의 10%가 예비탄으로 돌아오고, 사격으로 내구도가 닳지 않는다."},
	},
	"armor": {
		30: {"id": "knockback_resist", "label": "넉백 저항 50% (몸 방어구)", "description": "피격 밀림이 절반으로 준다."},
		50: {"id": "post_hit_guard", "label": "피격 후 1.5초 추가 피해 −20%", "description": "연타를 맞을 때 뒤이은 피해가 줄어든다."},
		70: {"id": "fatigue_guard", "label": "피로 누적 −15%", "description": "필드에 더 오래 머물 수 있다."},
		90: {"id": "secure_slot", "label": "시큐어 슬롯 +1", "description": "죽어도 지키는 칸이 하나 늘어난다."},
	},
}


func is_breakthrough_perk_unlocked(kind: String, item_id: String, perk_level: int) -> bool:
	# 그 단계의 돌파를 마쳤는가 — 돌파 기록이 단계 이상이거나, 강화 레벨이 단계를 넘어섰으면 참.
	if not BREAKTHROUGH_PERK_LEVELS.has(perk_level):
		return false
	var level := get_gear_enhancement_level(kind, item_id)
	if level > perk_level:
		return true
	return level >= perk_level and get_breakthrough_level_done(kind, item_id) >= perk_level


func get_breakthrough_perks(kind: String, item_id: String) -> Array[String]:
	# 열린 보너스 id 목록(낮은 단계부터). 무기: pierce/magazine/elite_damage/kill_refund,
	# 방어구: knockback_resist/post_hit_guard/fatigue_guard/secure_slot.
	var perks: Array[String] = []
	var table: Dictionary = BREAKTHROUGH_PERKS.get(kind, {})
	for perk_level in BREAKTHROUGH_PERK_LEVELS:
		if table.has(perk_level) and is_breakthrough_perk_unlocked(kind, item_id, perk_level):
			perks.append(str((table[perk_level] as Dictionary).get("id", "")))
	return perks


func describe_breakthrough_perk(kind: String, perk_level: int) -> String:
	# UI용 한 줄 — "+30 돌파: 관통 +1". 표에 없는 단계면 빈 문자열.
	var table: Dictionary = BREAKTHROUGH_PERKS.get(kind, {})
	if not table.has(perk_level):
		return ""
	return "+%d 돌파: %s" % [perk_level, str((table[perk_level] as Dictionary).get("label", ""))]


func has_weapon_breakthrough_perk(perk_level: int) -> bool:
	# 장착 무기 기준.
	return is_breakthrough_perk_unlocked("weapon", equipped_weapon_id, perk_level)


func get_player_elite_damage_multiplier() -> float:
	# 무기 돌파 +70 — 장착 무기 기준 엘리트·보스 피해 배율. enemy.take_projectile_hit이 읽는다.
	return 1.0 + WEAPON_PERK_ELITE_DAMAGE_BONUS if has_weapon_breakthrough_perk(70) else 1.0


func has_armor_breakthrough_perk(perk_level: int) -> bool:
	# 장착 방어구 기준. +30(넉백 저항)은 몸 슬롯 전용, 나머지는 장착 피스 중 하나라도.
	if perk_level == 30:
		return not equipped_body_armor_id.is_empty() and is_breakthrough_perk_unlocked("armor", equipped_body_armor_id, perk_level)
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not str(equipment_id).is_empty() and is_breakthrough_perk_unlocked("armor", str(equipment_id), perk_level):
			return true
	return false


func get_armor_knockback_multiplier() -> float:
	# 피격 넉백 배율의 단일 지점 — main.take_hit이 recoil_velocity에 곱한다.
	return 1.0 - ARMOR_PERK_KNOCKBACK_RESIST if has_armor_breakthrough_perk(30) else 1.0


var last_player_hit_msec: int = -100000


func apply_post_hit_guard(amount: int) -> int:
	# 방어구 +50 보너스 — 직전 피격 후 1.5s 안에 들어온 피해는 −20%. 피격 시각도 여기서 기록한다
	# (필드 main.take_damage · 건물 내부 take_damage 공용). 보너스가 없으면 그대로 돌려준다.
	var now := Time.get_ticks_msec()
	var guarded := amount
	if has_armor_breakthrough_perk(50) and now - last_player_hit_msec <= int(ARMOR_PERK_POST_HIT_WINDOW_SEC * 1000.0):
		guarded = maxi(1, roundi(float(amount) * ARMOR_PERK_POST_HIT_DAMAGE_MULTIPLIER))
	last_player_hit_msec = now
	return guarded


# ── 설계도 조각 · 제작 해금 ─────────────────────────────────────
# 레시피 id = 무기 id / 방어구 기본 id. 조각은 progression 원장(가방+창고 합산)에
# "blueprint_shard_<id>" 키로 쌓이고 소모되지 않는다. 3/3이면 제작이 열리고,
# 장비를 보유 중이면 "제작됨 · 영구 보유"(재제작 불가).


func blueprint_shard_item_id(recipe_id: String) -> String:
	return LOOT_ECONOMY.blueprint_shard_item_id(recipe_id)


func get_blueprint_shard_count(recipe_id: String) -> int:
	return get_progression_item_count(blueprint_shard_item_id(recipe_id))


func add_blueprint_shards(recipe_id: String, amount: int = 1) -> void:
	add_progression_item(blueprint_shard_item_id(recipe_id), amount)


func is_blueprint_unlocked(recipe_id: String) -> bool:
	return get_blueprint_shard_count(recipe_id) >= BLUEPRINT_SHARDS_REQUIRED


func get_gear_recipe_kind(recipe_id: String) -> String:
	if GEAR_WEAPON_RECIPE_IDS.has(recipe_id):
		return "weapon"
	if GEAR_ARMOR_RECIPE_IDS.has(recipe_id):
		return "armor"
	return ""


func is_gear_owned(recipe_id: String) -> bool:
	# 무기: 재고(장착분 포함)+창고. 방어구: 장착·가방·창고(레벨 변종 포함).
	match get_gear_recipe_kind(recipe_id):
		"weapon":
			return get_weapon_count(recipe_id) > 0 or get_stored_storage_count("weapon", recipe_id) > 0
		"armor":
			return is_armor_base_owned(recipe_id)
	return false


func is_blueprint_recipe_complete(recipe_id: String) -> bool:
	# 드랍 풀의 "미완성 우선" 판정 — 3/3 모였거나 장비를 이미 갖고 있으면 완성.
	return is_blueprint_unlocked(recipe_id) or is_gear_owned(recipe_id)


func get_blueprint_progress_text(recipe_id: String) -> String:
	return "설계도 조각 %d/%d" % [mini(get_blueprint_shard_count(recipe_id), BLUEPRINT_SHARDS_REQUIRED), BLUEPRINT_SHARDS_REQUIRED]


func _migrate_legacy_blueprints() -> Array[String]:
	# 구세이브: 통짜 청사진 보유 → 해당 레시피 조각 3개(이미 3 이상이면 그대로). 통짜는
	# 가방·창고에서 지운다. 돌려주는 건 환산된 레시피 id 목록.
	var converted: Array[String] = []
	var mapping := {
		"akm_blueprint": "akm",
		"rifle_blueprint": "akm",
		"pump_blueprint": "pump_shotgun",
		"shotgun_blueprint": "double_barrel",
	}
	for legacy_id in mapping.keys():
		var count := get_progression_item_count(str(legacy_id))
		if count <= 0:
			progression_item_inventory.erase(str(legacy_id))
			continue
		var recipe_id := str(mapping[legacy_id])
		var shard_id := blueprint_shard_item_id(recipe_id)
		var have := get_blueprint_shard_count(recipe_id)
		if have < BLUEPRINT_SHARDS_REQUIRED:
			progression_item_inventory[shard_id] = int(progression_item_inventory.get(shard_id, 0)) + (BLUEPRINT_SHARDS_REQUIRED - have)
		progression_item_inventory.erase(str(legacy_id))
		remove_stored_storage_item("progression", str(legacy_id), count)
		converted.append(recipe_id)
	return converted


func get_mod_enhancement_level(mod_id: String) -> int:
	return clampi(int(mod_enhancement_levels.get(mod_id, 0)), 0, MAX_WEAPON_ENHANCEMENT)


func get_mod_enhancement_cost(mod_id: String) -> int:
	var level := get_mod_enhancement_level(mod_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return 0
	# ×1.105 → ×1.22 — 무기 강화와 같은 이유(수입 지수 vs 비용 완만).
	return maxi(500, roundi(500.0 * pow(1.22, float(level))))


func try_enhance_mod(mod_id: String) -> bool:
	if not equipped_weapon_mods.has(mod_id):
		return false
	var level := get_mod_enhancement_level(mod_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return false
	var cost := get_mod_enhancement_cost(mod_id)
	if scrap < cost:
		return false
	scrap -= cost
	mod_enhancement_levels[mod_id] = level + 1
	save_persistent_state()
	return true


func get_xp_required(level: int = player_level) -> int:
	var level_index := maxi(0, level - 1)
	return 100 + level_index * 55 + roundi(pow(float(level_index), 1.28) * 18.0)


func get_raid_experience_reward(kills: int, boss_kills: int = 0) -> int:
	return 35 + maxi(0, kills) * 22 + maxi(0, boss_kills) * 120


func add_raid_experience(amount: int) -> Dictionary:
	var gained := maxi(0, amount)
	var old_level := player_level
	var old_xp := player_xp
	var old_required := get_xp_required(player_level)
	player_xp += gained
	var levels_gained := 0
	while player_xp >= get_xp_required(player_level):
		player_xp -= get_xp_required(player_level)
		player_level += 1
		levels_gained += 1
	pending_level_choices += levels_gained
	save_persistent_state()
	return {
		"gained": gained,
		"old_level": old_level,
		"old_xp": old_xp,
		"old_required": old_required,
		"new_level": player_level,
		"new_xp": player_xp,
		"new_required": get_xp_required(player_level),
		"levels_gained": levels_gained,
	}


func get_level_reward_choices(seed_value: int) -> Array[String]:
	var options: Array[String] = []
	for stat_id in PLAYER_LEVEL_REWARDS.keys():
		options.append(str(stat_id))
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + player_level * 7919 + pending_level_choices * 101
	for index in range(options.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary := options[index]
		options[index] = options[swap_index]
		options[swap_index] = temporary
	var choices: Array[String] = []
	for index in mini(3, options.size()):
		choices.append(options[index])
	return choices


func get_level_reward_definition(stat_id: String) -> Dictionary:
	return (PLAYER_LEVEL_REWARDS.get(stat_id, {}) as Dictionary).duplicate(true)


func apply_level_reward(stat_id: String) -> bool:
	if pending_level_choices <= 0 or not PLAYER_LEVEL_REWARDS.has(stat_id):
		return false
	player_stat_levels[stat_id] = int(player_stat_levels.get(stat_id, 0)) + 1
	pending_level_choices -= 1
	if stat_id == "max_health":
		player_health = mini(get_max_health(), player_health + 8)
	save_persistent_state()
	return true


func get_max_health() -> int:
	var total := 100 + int(player_stat_levels.get("max_health", 0)) * 8 + int(training_levels.get("vitality", 0)) * 10
	if is_churu_buff_active("full_belly"):
		total += 25
	return total


func get_max_stamina() -> float:
	return 100.0 + float(player_stat_levels.get("max_stamina", 0)) * 10.0 + float(training_levels.get("endurance", 0)) * 12.0


func get_move_speed_multiplier() -> float:
	var progression_multiplier := 1.0 + float(player_stat_levels.get("move_speed", 0)) * 0.025 + float(training_levels.get("agility", 0)) * 0.02
	var equipment_bonus := 0.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			# 신발의 강화는 이동 보너스에 같은 배율을 곱한다(피해 감소가 없는 슬롯의 성장축).
			equipment_bonus += (
				float(get_equipment_definition(equipment_id).get("move_speed_bonus", 0.0))
				* get_armor_enhancement_multiplier(equipment_id)
			)
	return progression_multiplier * (1.0 + equipment_bonus)


func get_stamina_cost_multiplier() -> float:
	var multiplier := 1.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			# 신발 강화는 스태미나 절감폭(1−배율)에 같은 강화 배율을 곱한다.
			var saving := 1.0 - float(get_equipment_definition(equipment_id).get("stamina_cost_multiplier", 1.0))
			multiplier *= maxf(0.4, 1.0 - saving * get_armor_enhancement_multiplier(equipment_id))
	return clampf(multiplier, 0.5, 1.5)


func get_stamina_recovery_multiplier() -> float:
	var multiplier := 1.0 + float(player_stat_levels.get("recovery", 0)) * 0.07 + float(training_levels.get("recovery", 0)) * 0.08
	if is_churu_buff_active("sharp_claws"):
		multiplier += 0.25
	return multiplier


func get_damage_taken_multiplier() -> float:
	var toughness_multiplier := maxf(0.68, 1.0 - float(player_stat_levels.get("toughness", 0)) * 0.02)
	return toughness_multiplier * get_equipment_damage_multiplier()


func get_fatigue_gain_multiplier() -> float:
	var reduction := float(player_stat_levels.get("fatigue_resistance", 0)) * 0.05
	reduction += float(training_levels.get("fieldcraft", 0)) * 0.07
	var multiplier := maxf(0.45, 1.0 - reduction)
	# 방어구 돌파 +70 보너스 — 피로 누적 −15%(피로 계산의 단일 지점은 여기).
	if has_armor_breakthrough_perk(70):
		multiplier *= ARMOR_PERK_FATIGUE_MULTIPLIER
	return multiplier


func get_recoil_control_multiplier() -> float:
	var control := (
		float(training_levels.get("agility", 0)) * 0.035
		+ float(training_levels.get("fieldcraft", 0)) * 0.055
	)
	return maxf(0.62, 1.0 - control)


func get_training_definition(node_id: String) -> Dictionary:
	return (TRAINING_NODE_DEFS.get(node_id, {}) as Dictionary).duplicate(true)


# ── 탄약 운용 훈련 효과 ─────────────────────────────────────────


func get_magazine_capacity_bonus(base_capacity: int) -> int:
	# 탄창 숙련: 랭크마다 +8%(반올림), 단 랭크당 최소 +1발. 작은 탄창(권총 7발)도
	# 랭크마다 한 발은 는다. 상한 +50%(2발짜리 더블배럴이 6발이 되지 않게).
	# 예: AK 30발 → 4랭크 30×1.32=39.6 → 40발.
	var rank := get_training_rank("magazine_drill")
	if rank <= 0 or base_capacity <= 0:
		return 0
	var bonus := maxi(rank, roundi(float(base_capacity) * 0.08 * float(rank)))
	return mini(bonus, maxi(1, roundi(float(base_capacity) * 0.5)))


func get_reload_time_multiplier() -> float:
	# 신속 장전: 랭크마다 장전 시간 -8% (4랭크 ×0.68 — AK 2.15s → 1.46s).
	return maxf(0.3, 1.0 - 0.08 * float(get_training_rank("quick_hands")))


func get_sortie_supply_magazines() -> int:
	# 출정 보급: 랭크 = 판 시작 시 지급 탄창 수.
	return maxi(0, get_training_rank("sortie_supply"))


func build_player_weapon_stats(
	weapon_id: String,
	mod_ids: Array[String],
	enhancement_level: int = 0,
	mod_enhancement_levels: Dictionary = {}
) -> Dictionary:
	# 플레이어 무기 스탯을 조립하는 단일 지점 — 필드 main·건물 내부·인벤토리 상세가
	# 전부 여기를 거친다. WeaponSystem.build_stats(무기·부착물·강화) 위에 훈련
	# (장탄·장전)을 곱한다. 적(enemy.gd)은 WeaponSystem을 직접 써서 영향이 없다.
	var stats := WEAPON_SYSTEM.build_stats(weapon_id, mod_ids, enhancement_level, mod_enhancement_levels)
	var base_magazine := int(stats.get("magazine_size", 0))
	stats["base_magazine_size"] = base_magazine
	stats["magazine_size"] = base_magazine + get_magazine_capacity_bonus(base_magazine)
	stats["base_reload_time"] = float(stats.get("reload_time", 2.15))
	stats["reload_time"] = float(stats.get("reload_time", 2.15)) * get_reload_time_multiplier()
	# 무기 돌파 정체성 보너스(+30 관통 · +50 탄창/장전 · +70 엘리트 피해 · +90 환급/내구) —
	# 스탯으로 표현되는 것은 전부 여기서 얹는다. 엘리트 피해·탄약 환급은 스탯 키로 실어
	# 각 적용 지점(enemy.take_projectile_hit / main._on_enemy_died)이 읽는다.
	var perks := get_breakthrough_perks("weapon", weapon_id)
	if perks.has("pierce"):
		stats["penetration_count"] = int(stats.get("penetration_count", 0)) + 1
	if perks.has("magazine"):
		stats["magazine_size"] = int(ceil(float(stats.get("magazine_size", 0)) * (1.0 + WEAPON_PERK_MAGAZINE_BONUS)))
		stats["reload_time"] = float(stats.get("reload_time", 2.15)) * WEAPON_PERK_RELOAD_MULTIPLIER
	stats["elite_damage_multiplier"] = 1.0 + WEAPON_PERK_ELITE_DAMAGE_BONUS if perks.has("elite_damage") else 1.0
	stats["kill_ammo_refund"] = WEAPON_PERK_KILL_AMMO_REFUND if perks.has("kill_refund") else 0.0
	if perks.has("kill_refund"):
		stats["durability_loss"] = 0.0
	stats["breakthrough_perks"] = perks
	return stats


func get_training_rank(node_id: String) -> int:
	return int(training_levels.get(node_id, 0))


func get_training_cost(node_id: String) -> int:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return 0
	var rank := get_training_rank(node_id)
	return int(definition.get("base_cost", 1)) + rank * int(definition.get("cost_step", 1))


func get_training_requirements_met(node_id: String) -> bool:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return false
	var requirements := definition.get("requires", {}) as Dictionary
	for required_id in requirements.keys():
		if get_training_rank(str(required_id)) < int(requirements[required_id]):
			return false
	return true


func try_upgrade_training(node_id: String) -> Dictionary:
	var definition := get_training_definition(node_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown"}
	var rank := get_training_rank(node_id)
	if rank >= int(definition.get("max_rank", 1)):
		return {"ok": false, "reason": "max_rank"}
	if not get_training_requirements_met(node_id):
		return {"ok": false, "reason": "prerequisite"}
	var cost := get_training_cost(node_id)
	# 지불은 쉘터 통조림 재고다 — 가방 통조림(던지기용)은 훈련에 못 쓴다.
	if shelter_canned_food < cost:
		return {"ok": false, "reason": "canned_food", "cost": cost}
	shelter_canned_food -= cost
	training_levels[node_id] = rank + 1
	if node_id == "vitality":
		player_health = mini(get_max_health(), player_health + 10)
	save_persistent_state()
	return {"ok": true, "rank": rank + 1, "cost": cost}


# ── 퀘스트 엔진 ────────────────────────────────────────────────
#
# 사자 계약과 철근 임무는 데이터 스키마가 완전히 같은데도 조회/수락/진행
# 로직이 따로 복사돼 있었다. 새 인물을 하나 추가하려면 그 한 벌을 또 쓰는
# 구조였다.
#
# 이제 진행 규칙은 아래 제네릭 함수들이 전담한다. 새 서사 트랙은
# QUESTLINES에 한 줄 + 대사 데이터 배열 하나면 된다.
#
# 기존 UI(217곳)를 건드리지 않으려고 예전 API는 얇은 래퍼로 남겨 둔다.


func get_questline_chain(line_id: String) -> Array:
	match line_id:
		"saja":
			return SAJA_FACILITY_CONTRACTS
		"iron":
			return IRON_SPECIAL_MISSIONS
	return []


func get_quest_definition(line_id: String, index: int) -> Dictionary:
	var chain := get_questline_chain(line_id)
	if index < 0 or index >= chain.size():
		return {}
	return (chain[index] as Dictionary).duplicate(true)


func _build_quest_state(
	line_id: String, index: int, status: String, progress: int, completed: Array
) -> Dictionary:
	var chain := get_questline_chain(line_id)
	var definition := get_quest_definition(line_id, index)
	if definition.is_empty():
		return {
			"status": "finished",
			"progress": 0,
			"target": 0,
			"definition": {},
			"completed_count": completed.size(),
			"total_count": chain.size(),
		}
	var target := maxi(1, int(definition.get("target", 1)))
	return {
		"status": status,
		"progress": clampi(progress, 0, target),
		"target": target,
		"definition": definition,
		"completed_count": completed.size(),
		"total_count": chain.size(),
	}


func _accept_quest(line_id: String, index: int, status: String) -> Dictionary:
	var definition := get_quest_definition(line_id, index)
	if definition.is_empty():
		return {"ok": false, "reason": "finished"}
	if status != "available":
		return {"ok": false, "reason": status}
	return {
		"ok": true,
		"definition": definition,
		"progress": 0,
		"target": maxi(1, int(definition.get("target", 1))),
	}


func _advance_quest(
	line_id: String, index: int, status: String, progress: int, metric: String, amount: int
) -> Dictionary:
	# 진행 규칙은 한 곳에만 있어야 한다. 트랙마다 복사되면 반드시 어긋난다.
	var definition := get_quest_definition(line_id, index)
	if (
		definition.is_empty()
		or status != "active"
		or str(definition.get("metric", "")) != metric
		or amount <= 0
	):
		return {"changed": false, "progress": progress, "status": status}
	var target := maxi(1, int(definition.get("target", 1)))
	var next_progress := mini(target, progress + amount)
	var next_status := "complete" if next_progress >= target else status
	return {
		"changed": next_progress != progress,
		"completed": next_status == "complete",
		"progress": next_progress,
		"status": next_status,
		"target": target,
		"definition": definition,
	}


func get_current_contract_definition() -> Dictionary:
	return get_quest_definition("saja", contract_chain_index)


# ── 도시 의뢰: 계약 완주 후의 반복 목표 ────────────────────────────
# 사자의 시설 계약이 끝나면 서사가 끊기던 공백을 메운다. 복귀할 때마다 사자가
# 새 의뢰(이번 출정 처치 목표)를 내걸고, 탈출 정산에서 달성 시 즉시 지급한다.
var city_commission: Dictionary = {}


func is_contract_chain_finished() -> bool:
	return str(get_contract_state().get("status", "")) == "finished"


func roll_city_commission() -> void:
	if not is_contract_chain_finished():
		city_commission = {}
		return
	# 결정론: 같은 복귀 차수에는 같은 의뢰. 최고 해금 존 티어로 난이도를 잡는다.
	var highest_tier := 1
	for zone_id in get_raid_zone_ids():
		if is_raid_zone_unlocked(str(zone_id)):
			highest_tier = maxi(highest_tier, int(get_raid_zone(str(zone_id)).get("required_tier", 1)))
	var random := RandomNumberGenerator.new()
	random.seed = int(map_seed) ^ (shelter_return_serial * 2654435761) ^ 0x434F4D4D
	# 의뢰 유형 3종 순환 — 처치(전투) / 귀중품(루팅) / 긴장도(배짱).
	# 매 복귀마다 다른 놀이 방식을 요구해야 반복 목표가 심부름이 되지 않는다.
	var commission_type: String = ["kills", "valuables", "pressure"][shelter_return_serial % 3]
	city_commission = {
		"type": commission_type,
		"reward_churu": 1 if shelter_return_serial % 3 == 0 else 0,
		"serial": shelter_return_serial,
		"completed": false,
	}
	match commission_type:
		"kills":
			var kills_target := 5 + highest_tier * 2 + random.randi_range(0, 3)
			city_commission["kills_target"] = kills_target
			city_commission["reward_scrap"] = kills_target * (280 + highest_tier * 130)
		"valuables":
			var value_target := 500 + highest_tier * 300 + random.randi_range(0, 2) * 100
			city_commission["value_target"] = value_target
			city_commission["reward_scrap"] = roundi(value_target * 1.5) + 600
		"pressure":
			var level_target := clampi(1 + (highest_tier - 1) / 2, 1, 3)
			city_commission["level_target"] = level_target
			city_commission["reward_scrap"] = 1400 + level_target * 1600


func get_city_commission() -> Dictionary:
	return city_commission.duplicate(true)


func get_city_commission_summary() -> String:
	# 게시판·브리핑 공용 한 줄 요약.
	if city_commission.is_empty():
		return ""
	match str(city_commission.get("type", "kills")):
		"valuables":
			return "귀중품 가치 %s 이상 확보해 귀환" % format_compact_number(
				int(city_commission.get("value_target", 0))
			)
		"pressure":
			return "도시 긴장도 %d단계 이상에서 탈출" % int(city_commission.get("level_target", 1))
	return "출정에서 약탈자 %d명 처치" % int(city_commission.get("kills_target", 0))


func settle_city_commission(run_kills: int, pressure_level: int = 0, valuable_value: int = 0) -> Dictionary:
	# 탈출 정산에서 호출. 달성했으면 즉시 지급하고 완료 표시(다음 복귀 때 새 의뢰).
	if city_commission.is_empty() or bool(city_commission.get("completed", false)):
		return {}
	var achieved := false
	match str(city_commission.get("type", "kills")):
		"kills":
			achieved = run_kills >= int(city_commission.get("kills_target", 999))
		"valuables":
			achieved = valuable_value >= int(city_commission.get("value_target", 999999))
		"pressure":
			achieved = pressure_level >= int(city_commission.get("level_target", 99))
	if not achieved:
		return {}
	var reward_scrap := int(city_commission.get("reward_scrap", 0))
	var reward_churu := int(city_commission.get("reward_churu", 0))
	scrap += reward_scrap
	churu += reward_churu
	city_commission["completed"] = true
	return {"scrap": reward_scrap, "churu": reward_churu}


func get_contract_state() -> Dictionary:
	return _build_quest_state(
		"saja", contract_chain_index, contract_status, contract_progress, completed_contract_ids
	)


func accept_current_contract() -> Dictionary:
	var result := _accept_quest("saja", contract_chain_index, contract_status)
	if not bool(result.get("ok", false)):
		return result
	contract_status = "active"
	contract_progress = 0
	save_persistent_state()
	return result


func advance_contract(metric: String, amount: int = 1) -> Dictionary:
	# 하나의 지표가 여러 트랙을 동시에 진행시킨다. 트랙이 늘어도 여기만 돈다.
	advance_iron_special_mission(metric, amount)
	var result := _advance_quest(
		"saja", contract_chain_index, contract_status, contract_progress, metric, amount
	)
	if not bool(result.get("changed", false)):
		return {"changed": false}
	contract_progress = int(result["progress"])
	contract_status = str(result["status"])
	save_persistent_state()
	return result


func claim_current_contract_reward() -> Dictionary:
	var definition := get_current_contract_definition()
	if definition.is_empty() or contract_status != "complete":
		return {"ok": false, "reason": contract_status}
	var reward := (definition.get("reward", {}) as Dictionary).duplicate(true)
	var experience_result := add_raid_experience(maxi(0, int(reward.get("xp", 0))))
	# 계약 보상 통조림은 쉘터에서 받는다 — 훈련 재고로 바로 들어가야 "받은 즉시
	# 훈련에 쓸 수 있다"가 성립한다(가방에 넣으면 한 판 다녀와야 쓸 수 있다).
	shelter_canned_food += maxi(0, int(reward.get("canned_food", 0)))
	medkits += maxi(0, int(reward.get("medkits", 0)))
	churu += maxi(0, int(reward.get("churu", 0)))
	var ammo_reward := maxi(0, int(reward.get("ammo", 0)))
	if ammo_reward > 0:
		var ammo_id := get_mission_reward_ammo_id()
		set_ammo_count(ammo_id, get_ammo_count(ammo_id) + ammo_reward)
		if ammo_id == equipped_ammo_id:
			reserve_ammo = get_ammo_count(ammo_id)
	var contract_id := str(definition.get("id", ""))
	if not completed_contract_ids.has(contract_id):
		completed_contract_ids.append(contract_id)
	var facility_id := str(definition.get("facility_unlock", ""))
	var facility_unlocked := false
	if not facility_id.is_empty():
		facility_unlocked = unlock_shelter_facility(facility_id)
	var lore_entry := "%s\n%s" % [
		str(definition.get("lore_title", "사자의 기록")),
		str(definition.get("lore", "")),
	]
	if not unlocked_contract_lore.has(lore_entry):
		unlocked_contract_lore.append(lore_entry)
	contract_chain_index += 1
	contract_progress = 0
	contract_status = "available" if contract_chain_index < SAJA_FACILITY_CONTRACTS.size() else "finished"
	save_persistent_state()
	return {
		"ok": true,
		"definition": definition,
		"reward": reward,
		"experience": experience_result,
		"lore": lore_entry,
		"facility_id": facility_id,
		"facility_name": get_shelter_facility_name(facility_id) if not facility_id.is_empty() else "",
		"facility_unlocked": facility_unlocked,
		"next_definition": get_current_contract_definition(),
		"finished": contract_status == "finished",
	}


func get_latest_contract_lore() -> String:
	if unlocked_contract_lore.is_empty():
		return ""
	return unlocked_contract_lore.back()


func _normalize_quest_progress(line_id: String, index: int, status: String, progress: int) -> Dictionary:
	# 세이브가 깨졌거나 데이터가 바뀌었을 때 상태를 되돌려 놓는다.
	var chain := get_questline_chain(line_id)
	var safe_index := clampi(index, 0, chain.size())
	if safe_index >= chain.size():
		return {"index": safe_index, "status": "finished", "progress": 0}
	var safe_status := status if status in ["available", "active", "complete"] else "available"
	var definition := get_quest_definition(line_id, safe_index)
	var target := maxi(1, int(definition.get("target", 1)))
	var safe_progress := target if safe_status == "complete" else clampi(progress, 0, target)
	return {"index": safe_index, "status": safe_status, "progress": safe_progress}


func _normalize_contract_state() -> void:
	var normalized := _normalize_quest_progress(
		"saja", contract_chain_index, contract_status, contract_progress
	)
	contract_chain_index = int(normalized["index"])
	contract_status = str(normalized["status"])
	contract_progress = int(normalized["progress"])


func get_current_iron_mission_definition() -> Dictionary:
	return get_quest_definition("iron", iron_mission_index)


func get_iron_mission_state() -> Dictionary:
	return _build_quest_state(
		"iron",
		iron_mission_index,
		iron_mission_status,
		iron_mission_progress,
		completed_iron_mission_ids
	)


func accept_current_iron_mission() -> Dictionary:
	var result := _accept_quest("iron", iron_mission_index, iron_mission_status)
	if not bool(result.get("ok", false)):
		return result
	iron_mission_status = "active"
	iron_mission_progress = 0
	save_persistent_state()
	return result


func advance_iron_special_mission(metric: String, amount: int = 1) -> Dictionary:
	var result := _advance_quest(
		"iron", iron_mission_index, iron_mission_status, iron_mission_progress, metric, amount
	)
	if not bool(result.get("changed", false)):
		return {"changed": false}
	iron_mission_progress = int(result["progress"])
	iron_mission_status = str(result["status"])
	save_persistent_state()
	return result


func claim_current_iron_mission_reward() -> Dictionary:
	var definition := get_current_iron_mission_definition()
	if definition.is_empty() or iron_mission_status != "complete":
		return {"ok": false, "reason": iron_mission_status}
	var training_id := str(definition.get("training_id", ""))
	var previous_rank := get_training_rank(training_id)
	var training_definition := get_training_definition(training_id)
	var maximum_rank := maxi(previous_rank + 1, int(training_definition.get("max_rank", previous_rank + 1)))
	training_levels[training_id] = mini(maximum_rank, previous_rank + 1)
	if training_id == "vitality":
		player_health = mini(get_max_health(), player_health + 10)
	var mission_id := str(definition.get("id", ""))
	if not completed_iron_mission_ids.has(mission_id):
		completed_iron_mission_ids.append(mission_id)
	iron_mission_index += 1
	iron_mission_progress = 0
	iron_mission_status = "available" if iron_mission_index < IRON_SPECIAL_MISSIONS.size() else "finished"
	save_persistent_state()
	return {
		"ok": true,
		"definition": definition,
		"training_id": training_id,
		"rank": int(training_levels.get(training_id, previous_rank)),
		"finished": iron_mission_status == "finished",
	}


func _normalize_iron_mission_state() -> void:
	var normalized := _normalize_quest_progress(
		"iron", iron_mission_index, iron_mission_status, iron_mission_progress
	)
	iron_mission_index = int(normalized["index"])
	iron_mission_status = str(normalized["status"])
	iron_mission_progress = int(normalized["progress"])


func save_persistent_state() -> bool:
	if not persistence_enabled:
		return false
	_normalize_storage_inventory()
	_normalize_contract_state()
	_normalize_iron_mission_state()
	save_equipped_weapon_loadout()
	var data := {
		"version": 14,
		"map_seed": map_seed,
		"raid_serial": raid_serial,
		"player_health": player_health,
		"player_level": player_level,
		"player_xp": player_xp,
		"pending_level_choices": pending_level_choices,
		"player_stat_levels": player_stat_levels,
		"training_levels": training_levels,
		"magazine_ammo": magazine_ammo,
		"scrap": scrap,
		"medkits": medkits,
		"canned_food": canned_food,
		"shelter_canned_food": shelter_canned_food,
		"catnip": catnip,
		"churu": churu,
		"valuable_inventory": valuable_inventory,
		"valuable_value_ledger": valuable_value_ledger,
		"active_churu_buffs": active_churu_buffs,
		"raid_in_progress": raid_in_progress,
		"bag_pressure_lesson_seen": bag_pressure_lesson_seen,
		"workbench_lesson_seen": workbench_lesson_seen,
		"field_controls_lesson_seen": field_controls_lesson_seen,
		"telegraph_lesson_seen": telegraph_lesson_seen,
		"headshot_lesson_seen": headshot_lesson_seen,
		"cover_lesson_seen": cover_lesson_seen,
		"fatigue_lesson_seen": fatigue_lesson_seen,
		"extraction_choice_lesson_seen": extraction_choice_lesson_seen,
		"catnip_fever_lesson_seen": catnip_fever_lesson_seen,
		"tutorial_steps_done": tutorial_steps_done,
		"unlocked_milestones": unlocked_milestones,
		"resident_reroll_counts": resident_reroll_counts,
		"fatigue": fatigue,
		"rescued_workers": rescued_workers,
		"resident_cat_ids": resident_cat_ids,
		"assigned_worker_ids": assigned_worker_ids,
		"assigned_catnip_worker_ids": assigned_catnip_worker_ids,
		"resident_traits": resident_traits,
		"mod_component_inventory": mod_component_inventory,
		"progression_item_inventory": progression_item_inventory,
		"weapon_mod_inventory": weapon_mod_inventory,
		"weapon_inventory": weapon_inventory,
		"weapon_first_equip_done": weapon_first_equip_done,
		"equipment_inventory": equipment_inventory,
		"equipped_body_armor_id": equipped_body_armor_id,
		"equipped_head_armor_id": equipped_head_armor_id,
		"equipped_footwear_id": equipped_footwear_id,
		"weapon_enhancement_levels": weapon_enhancement_levels,
		"weapon_enhancement_transfers_done": weapon_enhancement_transfers_done,
		"armor_enhancement_levels": armor_enhancement_levels,
		"armor_enhancement_transfers_done": armor_enhancement_transfers_done,
		"gear_breakthroughs": gear_breakthroughs,
		"mod_enhancement_levels": mod_enhancement_levels,
		"equipped_weapon_id": equipped_weapon_id,
		"weapon_durability": weapon_durability,
		"equipped_weapon_mods": equipped_weapon_mods,
		"weapon_mod_loadouts": weapon_mod_loadouts,
		"equipped_magazine_id": equipped_magazine_id,
		"equipped_ammo_id": equipped_ammo_id,
		"ammo_inventory": ammo_inventory,
		"pending_corpse_recovery": pending_corpse_recovery,
		"corpse_recovery_attempt_active": corpse_recovery_attempt_active,
		"confirmed_raid_manifest": confirmed_raid_manifest,
		"raid_special_cargo": raid_special_cargo,
		"recovered_story_cargo_ids": recovered_story_cargo_ids,
		"subway_story_stage": subway_story_stage,
		"main_mission_progress": main_mission_progress,
		"mission_choices": mission_choices,
		"seen_field_cinematics": seen_field_cinematics,
		"saja_seen_main_mission_zones": saja_seen_main_mission_zones,
		"shelter_workbench_level": shelter_workbench_level,
		"shelter_tier": shelter_tier,
		"scratcher_bank_level": scratcher_bank_level,
		"scratcher_multiplier": scratcher_multiplier,
		"catnip_scraper_level": catnip_scraper_level,
		"catnip_scraper_multiplier": catnip_scraper_multiplier,
		"storage_level": storage_level,
		"storage_inventory": storage_inventory,
		"storage_food_in_total": true,
		"catnip_boost_end_time": catnip_boost_end_time,
		"catnip_fever_gauge": catnip_fever_gauge,
		"catnip_fever_active": catnip_fever_active,
		"pre_raid_snapshot": pre_raid_snapshot,
		"shelter_last_progress_time": shelter_last_progress_time,
		"workbench_repair_active": workbench_repair_active,
		"workbench_repair_weapon_id": workbench_repair_weapon_id,
		"workbench_starter_parts_claimed": workbench_starter_parts_claimed,
		"shelter_scrap_fraction": shelter_scrap_fraction,
		"shelter_catnip_fraction": shelter_catnip_fraction,
		"shelter_return_serial": shelter_return_serial,
		"survived_return_count": survived_return_count,
		"city_commission": city_commission,
		"bag_capacity_level": bag_capacity_level,
		"scratcher_overclock_level": scratcher_overclock_level,
		"catnip_infusion_level": catnip_infusion_level,
		"secure_dog_slots": secure_dog_slots,
		"merchant_last_roll_serial": merchant_last_roll_serial,
		"merchant_status": merchant_status,
		"merchant_decline_count": merchant_decline_count,
		"merchant_stock": merchant_stock,
		"merchant_missed_visit": merchant_missed_visit,
		"selected_raid_zone": selected_raid_zone,
		"contract_chain_index": contract_chain_index,
		"contract_status": contract_status,
		"contract_progress": contract_progress,
		"completed_contract_ids": completed_contract_ids,
		"unlocked_contract_lore": unlocked_contract_lore,
		"shelter_facility_unlocks": shelter_facility_unlocks,
		"contract_agent_intro_seen": contract_agent_intro_seen,
		"saja_intro_seen": saja_intro_seen,
		"merchant_intro_seen": merchant_intro_seen,
		"saja_second_run_intro_seen": saja_second_run_intro_seen,
		"saja_seen_resident_count": saja_seen_resident_count,
		"saja_seen_boss_kills": saja_seen_boss_kills,
		"saja_seen_story_cargo_count": saja_seen_story_cargo_count,
		"saja_seen_subway_stage": saja_seen_subway_stage,
		"total_boss_kills": total_boss_kills,
		"juhong_seen_events": juhong_seen_events,
		"iron_mission_index": iron_mission_index,
		"iron_mission_status": iron_mission_status,
		"iron_mission_progress": iron_mission_progress,
		"completed_iron_mission_ids": completed_iron_mission_ids,
		"opening_completed": opening_completed,
	}
	# 원자적 저장: 임시 파일에 다 쓴 뒤 교체한다. 어느 순간에 크래시가 나도
	# 본 파일은 항상 완전한 JSON이다. 교체 직전 본은 .bak으로 남겨,
	# 최악의 경우에도 한 세이브 전으로만 돌아간다.
	var temp_path := persistence_path + ".tmp"
	var backup_path := persistence_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	# 세이브가 user:// 밖(테스트의 res://.godot 등)을 가리킬 수도 있다. "user://"를
	# 통째로 열면 그 경로의 rename이 실패해 저장이 통째로 실패한다.
	var dir := DirAccess.open(persistence_path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(persistence_path):
		if FileAccess.file_exists(backup_path):
			dir.remove(backup_path)
		dir.rename(persistence_path, backup_path)
	return dir.rename(temp_path, persistence_path) == OK


func load_persistent_state() -> bool:
	if not persistence_enabled:
		return false
	# 본 파일이 없거나 손상됐으면 .bak으로 물러난다 — 조용한 진행 초기화 금지.
	var data: Dictionary = {}
	for candidate_path in [persistence_path, persistence_path + ".bak"]:
		if not FileAccess.file_exists(str(candidate_path)):
			continue
		var file := FileAccess.open(str(candidate_path), FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed as Dictionary
			if str(candidate_path) != persistence_path:
				push_warning("세이브 본 파일 손상 — 백업(.bak)에서 복구했습니다.")
			break
	if data.is_empty():
		return false
	map_seed = int(data.get("map_seed", map_seed))
	raid_serial = int(data.get("raid_serial", raid_serial))
	player_health = int(data.get("player_health", player_health))
	player_level = maxi(1, int(data.get("player_level", player_level)))
	player_xp = maxi(0, int(data.get("player_xp", player_xp)))
	pending_level_choices = maxi(0, int(data.get("pending_level_choices", pending_level_choices)))
	player_stat_levels = (data.get("player_stat_levels", player_stat_levels) as Dictionary).duplicate(true)
	training_levels = (data.get("training_levels", training_levels) as Dictionary).duplicate(true)
	for stat_id in PLAYER_LEVEL_REWARDS.keys():
		if not player_stat_levels.has(stat_id):
			player_stat_levels[stat_id] = 0
		else:
			player_stat_levels[stat_id] = int(player_stat_levels[stat_id])
	for training_id in TRAINING_NODE_DEFS.keys():
		if not training_levels.has(training_id):
			training_levels[training_id] = 0
		else:
			training_levels[training_id] = int(training_levels[training_id])
	magazine_ammo = int(data.get("magazine_ammo", magazine_ammo))
	scrap = int(data.get("scrap", scrap))
	medkits = int(data.get("medkits", medkits))
	canned_food = int(data.get("canned_food", canned_food))
	shelter_canned_food = maxi(0, int(data.get("shelter_canned_food", shelter_canned_food)))
	# 구 세이브의 쉘터 식료 선반 필드(구 연료 재고)는 읽지 않는다 — 그 몫은 이미
	# canned_food 총량에 포함돼 있었으므로, 무시하면 그대로 가방 보유량이 된다.
	catnip = maxi(0, roundi(float(data.get("catnip", catnip))))
	churu = int(data.get("churu", churu))
	valuable_inventory = (data.get("valuable_inventory", {}) as Dictionary).duplicate(true)
	valuable_value_ledger = (data.get("valuable_value_ledger", {}) as Dictionary).duplicate(true)
	active_churu_buffs = _to_string_array(data.get("active_churu_buffs", []))
	raid_in_progress = bool(data.get("raid_in_progress", false))
	bag_pressure_lesson_seen = bool(data.get("bag_pressure_lesson_seen", bag_pressure_lesson_seen))
	workbench_lesson_seen = bool(data.get("workbench_lesson_seen", workbench_lesson_seen))
	field_controls_lesson_seen = bool(data.get("field_controls_lesson_seen", field_controls_lesson_seen))
	telegraph_lesson_seen = bool(data.get("telegraph_lesson_seen", telegraph_lesson_seen))
	headshot_lesson_seen = bool(data.get("headshot_lesson_seen", headshot_lesson_seen))
	cover_lesson_seen = bool(data.get("cover_lesson_seen", cover_lesson_seen))
	fatigue_lesson_seen = bool(data.get("fatigue_lesson_seen", fatigue_lesson_seen))
	extraction_choice_lesson_seen = bool(data.get("extraction_choice_lesson_seen", extraction_choice_lesson_seen))
	catnip_fever_lesson_seen = bool(data.get("catnip_fever_lesson_seen", catnip_fever_lesson_seen))
	tutorial_steps_done = _to_string_array(data.get("tutorial_steps_done", []))
	unlocked_milestones = _to_string_array(data.get("unlocked_milestones", []))
	resident_reroll_counts = (data.get("resident_reroll_counts", {}) as Dictionary).duplicate(true)
	if int(data.get("version", 0)) < 12:
		# v12: 원자재 2종을 폐지하고 통조림으로 통합했다(당시엔 쉘터 연료였고,
		# 지금은 가방 소모품). 구세이브의 원자재 잔량은 통조림으로 환전한다.
		var legacy_raw := maxi(0, int(data.get("raw_scrap", 0))) + maxi(0, int(data.get("raw_catnip", 0)))
		if legacy_raw > 0:
			canned_food += maxi(1, ceili(float(legacy_raw) / 4.0))
	fatigue = float(data.get("fatigue", fatigue))
	rescued_workers = int(data.get("rescued_workers", rescued_workers))
	resident_cat_ids = _to_string_array(data.get("resident_cat_ids", []))
	assigned_worker_ids = _to_string_array(data.get("assigned_worker_ids", []))
	assigned_catnip_worker_ids = _to_string_array(data.get("assigned_catnip_worker_ids", []))
	resident_traits = (data.get("resident_traits", {}) as Dictionary).duplicate(true)
	mod_component_inventory = (data.get("mod_component_inventory", mod_component_inventory) as Dictionary).duplicate(true)
	for component_id in BASIC_COMPONENT_IDS + RARE_COMPONENT_IDS:
		if not mod_component_inventory.has(component_id):
			mod_component_inventory[component_id] = 0
	progression_item_inventory = (
		data.get("progression_item_inventory", progression_item_inventory) as Dictionary
	).duplicate(true)
	for progression_item_id in [
		ARTISAN_SEAL_ID, "sealed_zone_keycard",
		"namdaemun_depot_plans", "euljiro_grid_schematic", "yongsan_control_key",
	]:
		if not progression_item_inventory.has(progression_item_id):
			progression_item_inventory[progression_item_id] = 0
	weapon_mod_inventory = (data.get("weapon_mod_inventory", weapon_mod_inventory) as Dictionary).duplicate(true)
	for mod_id in WEAPON_SYSTEM.MODS.keys():
		if not weapon_mod_inventory.has(mod_id):
			weapon_mod_inventory[mod_id] = 0
	weapon_inventory = (data.get("weapon_inventory", weapon_inventory) as Dictionary).duplicate(true)
	weapon_first_equip_done = (data.get("weapon_first_equip_done", weapon_first_equip_done) as Array).duplicate()
	equipment_inventory = (data.get("equipment_inventory", equipment_inventory) as Dictionary).duplicate(true)
	for equipment_id in EQUIPMENT_DEFINITIONS:
		if not equipment_inventory.has(equipment_id):
			equipment_inventory[equipment_id] = 0
	equipped_body_armor_id = str(data.get("equipped_body_armor_id", equipped_body_armor_id))
	equipped_head_armor_id = str(data.get("equipped_head_armor_id", equipped_head_armor_id))
	equipped_footwear_id = str(data.get("equipped_footwear_id", equipped_footwear_id))
	weapon_enhancement_levels = (data.get("weapon_enhancement_levels", weapon_enhancement_levels) as Dictionary).duplicate(true)
	# 구세이브엔 키가 없다 → 빈 배열(= 아직 아무 이관도 안 함). 상위 무기를 이미
	# 들고 있던 세이브는 다음 "처음 보유" 순간이 없으니 자연히 이관 대상이 아니다.
	weapon_enhancement_transfers_done = (data.get("weapon_enhancement_transfers_done", []) as Array).duplicate()
	# v13(2026-08 경제 코어): 방어구 강화·이관·돌파 기록. 구세이브엔 없다 → 빈 값.
	armor_enhancement_levels = (data.get("armor_enhancement_levels", {}) as Dictionary).duplicate(true)
	armor_enhancement_transfers_done = (data.get("armor_enhancement_transfers_done", []) as Array).duplicate()
	gear_breakthroughs = (data.get("gear_breakthroughs", {}) as Dictionary).duplicate(true)
	mod_enhancement_levels = (data.get("mod_enhancement_levels", mod_enhancement_levels) as Dictionary).duplicate(true)
	equipped_weapon_id = str(data.get("equipped_weapon_id", equipped_weapon_id))
	weapon_durability = float(data.get("weapon_durability", weapon_durability))
	equipped_weapon_mods = _to_string_array(data.get("equipped_weapon_mods", []))
	weapon_mod_loadouts = (data.get("weapon_mod_loadouts", {}) as Dictionary).duplicate(true)
	if not weapon_mod_loadouts.has(equipped_weapon_id):
		weapon_mod_loadouts[equipped_weapon_id] = equipped_weapon_mods.duplicate()
	equipped_magazine_id = str(data.get("equipped_magazine_id", equipped_magazine_id))
	equipped_ammo_id = str(data.get("equipped_ammo_id", equipped_ammo_id))
	ammo_inventory = (data.get("ammo_inventory", ammo_inventory) as Dictionary).duplicate(true)
	pending_corpse_recovery = (data.get("pending_corpse_recovery", {}) as Dictionary).duplicate(true)
	corpse_recovery_attempt_active = bool(data.get("corpse_recovery_attempt_active", false))
	confirmed_raid_manifest = (data.get("confirmed_raid_manifest", {}) as Dictionary).duplicate(true)
	raid_special_cargo = (data.get("raid_special_cargo", {}) as Dictionary).duplicate(true)
	recovered_story_cargo_ids = _to_string_array(data.get("recovered_story_cargo_ids", []))
	subway_story_stage = clampi(int(data.get("subway_story_stage", 0)), 0, 3)
	main_mission_progress = (data.get("main_mission_progress", {}) as Dictionary).duplicate(true)
	mission_choices = (data.get("mission_choices", {}) as Dictionary).duplicate(true)
	seen_field_cinematics = _to_string_array(data.get("seen_field_cinematics", []))
	saja_seen_main_mission_zones = _to_string_array(data.get("saja_seen_main_mission_zones", []))
	_migrate_main_mission_progress()
	# 구세이브 보정: 키 도입 전에 체인 3단계를 끝낸 세이브에 쉘터 확장 키를 준다.
	# progression_item_inventory 로드 뒤(위쪽)여야 "이미 있음"을 제대로 본다.
	ensure_story_key_items()
	shelter_workbench_level = clampi(int(data.get("shelter_workbench_level", shelter_workbench_level)), 1, 5)
	shelter_tier = clampi(int(data.get("shelter_tier", shelter_tier)), 1, 5)
	scratcher_bank_level = clampi(int(data.get("scratcher_bank_level", scratcher_bank_level)), 1, SCRATCHER_BANK_MAX_LEVEL)
	# 저장값을 믿지 않고 레벨에서 재계산 — 배율 곡선을 바꿔도 구세이브가 따라온다.
	scratcher_multiplier = pow(1.9, float(scratcher_bank_level - 1))
	catnip_scraper_level = clampi(int(data.get("catnip_scraper_level", catnip_scraper_level)), 1, 5)
	catnip_scraper_multiplier = float(data.get("catnip_scraper_multiplier", pow(1.8, float(catnip_scraper_level - 1))))
	storage_level = clampi(int(data.get("storage_level", storage_level)), 1, 5)
	storage_inventory = _to_dictionary_array(data.get("storage_inventory", []))
	_normalize_storage_inventory()
	# v13: 레거시 통짜 청사진(가방·창고) → 설계도 조각 3개 환산. 창고 로드 뒤여야 한다.
	_migrate_legacy_blueprints()
	# 안전망: 무기를 하나도 갖지 못한 세이브(옛 전손 규칙의 흔적)에 시작 AK를 되돌려
	# 준다 — 장비는 제작 전용이라 맨손에서 스스로 재무장할 길이 없다.
	if not has_any_weapon() and get_stored_storage_count("weapon", "ak47") <= 0:
		var ladder_bottom_missing := true
		for weapon_id_value in WEAPON_SYSTEM.WEAPONS.keys():
			if get_stored_storage_count("weapon", str(weapon_id_value)) > 0:
				ladder_bottom_missing = false
		if ladder_bottom_missing:
			weapon_inventory["ak47"] = 1
			if not weapon_mod_loadouts.has("ak47"):
				weapon_mod_loadouts["ak47"] = []
	if not bool(data.get("storage_food_in_total", false)):
		canned_food += get_stored_storage_count("food", "canned_food")
	# 창고 통조림 슬롯은 폐지 — 구 세이브의 슬롯은 비우고 그 몫은 가방 보유량으로 남긴다.
	_purge_stored_canned_food()
	canned_food = maxi(0, canned_food)
	shelter_canned_food = maxi(0, shelter_canned_food)
	if int(data.get("version", 0)) < 14:
		# v14: 통조림이 훈련 재화가 됐다(먹기 폐지). 구세이브가 가방에 쌓아 둔
		# 통조림은 훈련에 쓸 수 있어야 의미가 있으니 쉘터 재고로 옮긴다. 복사가
		# 아니라 이동이다 — 복사면 로드 한 번에 재화가 두 배가 된다. 위치가 여기인
		# 이유: v12 원자재 환전·구 창고 슬롯 회수까지 끝난 최종 수량을 옮겨야 한다.
		shelter_canned_food += canned_food
		canned_food = 0
	catnip_boost_end_time = int(data.get("catnip_boost_end_time", catnip_boost_end_time))
	catnip_fever_gauge = clampf(
		float(data.get("catnip_fever_gauge", 0.0)), 0.0, CATNIP_FEVER_GAUGE_MAX
	)
	# 피버는 눈앞에서 벌어지는 사건이다. 로드 직후 오프라인 정산에 5~9배가
	# 걸리면 껐다 켜는 게 최적 전략이 된다 — 남은 게이지만 들고 멈춘 채 시작한다.
	catnip_fever_active = false
	pre_raid_snapshot = data.get("pre_raid_snapshot", {}) as Dictionary
	shelter_last_progress_time = int(data.get("shelter_last_progress_time", shelter_last_progress_time))
	workbench_repair_active = bool(data.get("workbench_repair_active", workbench_repair_active))
	workbench_repair_weapon_id = str(data.get("workbench_repair_weapon_id", workbench_repair_weapon_id))
	workbench_starter_parts_claimed = bool(data.get("workbench_starter_parts_claimed", workbench_starter_parts_claimed))
	shelter_scrap_fraction = float(data.get("shelter_scrap_fraction", shelter_scrap_fraction))
	shelter_catnip_fraction = float(data.get("shelter_catnip_fraction", shelter_catnip_fraction))
	shelter_return_serial = int(data.get("shelter_return_serial", shelter_return_serial))
	# 구 세이브 호환: 값이 없으면 기존 귀환 수를 생환 수로 간주한다.
	survived_return_count = int(data.get("survived_return_count", shelter_return_serial))
	city_commission = (data.get("city_commission", {}) as Dictionary).duplicate(true)
	bag_capacity_level = int(data.get("bag_capacity_level", bag_capacity_level))
	scratcher_overclock_level = int(data.get("scratcher_overclock_level", scratcher_overclock_level))
	catnip_infusion_level = int(data.get("catnip_infusion_level", catnip_infusion_level))
	secure_dog_slots = clampi(int(data.get("secure_dog_slots", secure_dog_slots)), 1, 3)
	merchant_last_roll_serial = int(data.get("merchant_last_roll_serial", merchant_last_roll_serial))
	merchant_status = str(data.get("merchant_status", merchant_status))
	merchant_decline_count = int(data.get("merchant_decline_count", merchant_decline_count))
	merchant_stock = _to_dictionary_array(data.get("merchant_stock", []))
	merchant_missed_visit = bool(data.get("merchant_missed_visit", false))
	# artisan_pity(장인 뽑기 천장)는 뽑기 폐지와 함께 읽지 않는다.
	selected_raid_zone = str(data.get("selected_raid_zone", selected_raid_zone))
	contract_chain_index = int(data.get("contract_chain_index", contract_chain_index))
	contract_status = str(data.get("contract_status", contract_status))
	contract_progress = int(data.get("contract_progress", contract_progress))
	completed_contract_ids = _to_string_array(data.get("completed_contract_ids", []))
	unlocked_contract_lore = _to_string_array(data.get("unlocked_contract_lore", []))
	if data.has("shelter_facility_unlocks"):
		shelter_facility_unlocks = (
			data.get("shelter_facility_unlocks", shelter_facility_unlocks) as Dictionary
		).duplicate(true)
		for facility_id in SHELTER_FACILITY_NAMES.keys():
			if not shelter_facility_unlocks.has(facility_id):
				shelter_facility_unlocks[facility_id] = facility_id == "bed"
	else:
		# 단계별 해금이 생기기 전 세이브. 예전에는 여기서 전부 열어 버려서
		# 오래된 세이브를 불러오면 첫 복귀에 생산기가 다 서 있었다.
		# 기본값(침대만)으로 두면 바로 아래 sync_shelter_progression_milestones()가
		# 완료한 계약과 복귀 횟수로부터 올바른 해금 상태를 다시 만들어 준다.
		shelter_facility_unlocks = {
			"bed": true,
			"storage": false,
			"training": false,
			"workbench": false,
			"scratcher_bank": false,
			"catnip_scraper": false,
		}
	contract_agent_intro_seen = bool(data.get("contract_agent_intro_seen", shelter_return_serial >= CONTRACT_AGENT_UNLOCK_RETURN))
	saja_intro_seen = bool(data.get("saja_intro_seen", false))
	merchant_intro_seen = bool(data.get("merchant_intro_seen", false))
	saja_second_run_intro_seen = bool(data.get("saja_second_run_intro_seen", false))
	saja_seen_resident_count = maxi(0, int(data.get("saja_seen_resident_count", 0)))
	saja_seen_boss_kills = maxi(0, int(data.get("saja_seen_boss_kills", 0)))
	saja_seen_story_cargo_count = maxi(0, int(data.get("saja_seen_story_cargo_count", 0)))
	saja_seen_subway_stage = maxi(0, int(data.get("saja_seen_subway_stage", 0)))
	total_boss_kills = maxi(0, int(data.get("total_boss_kills", 0)))
	juhong_seen_events = _to_string_array(data.get("juhong_seen_events", []))
	iron_mission_index = maxi(0, int(data.get("iron_mission_index", 0)))
	iron_mission_status = str(data.get("iron_mission_status", "available"))
	iron_mission_progress = maxi(0, int(data.get("iron_mission_progress", 0)))
	completed_iron_mission_ids = _to_string_array(data.get("completed_iron_mission_ids", []))
	# Saves made before the opening existed should continue from the shelter.
	opening_completed = bool(data.get("opening_completed", true))
	_normalize_contract_state()
	_normalize_iron_mission_state()
	sync_shelter_progression_milestones()
	if not RAID_ZONES.has(selected_raid_zone) or not is_raid_zone_unlocked(selected_raid_zone):
		selected_raid_zone = "jongno_outskirts"
	_ensure_resident_records()
	player_health = clampi(player_health, 0, get_max_health())
	reserve_ammo = get_ammo_count(equipped_ammo_id)
	# 모든 복원이 끝난 '마지막'에 판 포기 검사 — 중간에 하면 이후 복원이
	# 정리분을 도로 덮어쓴다.
	if raid_in_progress:
		apply_raid_abandonment()
	return true


# ── 액티브 튜토리얼 진행도 ───────────────────────────────────────


func is_tutorial_step_done(step_id: String) -> bool:
	return tutorial_steps_done.has(step_id)


func mark_tutorial_step_done(step_id: String) -> void:
	if step_id.is_empty() or tutorial_steps_done.has(step_id):
		return
	tutorial_steps_done.append(step_id)
	save_persistent_state()


func reset_tutorial_steps() -> void:
	# 설정의 '안내 다시 보기' — 모든 스텝을 처음 상태로. 기존 1회성 레슨 플래그는 건드리지 않는다.
	tutorial_steps_done.clear()
	save_persistent_state()


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_persistent_state()


func reset_run() -> void:
	player_health = 100
	player_level = 1
	player_xp = 0
	pending_level_choices = 0
	player_stat_levels = {
		"max_health": 0,
		"max_stamina": 0,
		"move_speed": 0,
		"recovery": 0,
		"toughness": 0,
		"fatigue_resistance": 0,
	}
	training_levels = {
		"vitality": 0,
		"endurance": 0,
		"agility": 0,
		"recovery": 0,
		"fieldcraft": 0,
		# 탄약 운용 훈련(훈련 정의 TRAINING_NODE_DEFS와 키를 맞춘다 — 세이브 왕복 비교가 어긋나지 않게)
		"magazine_drill": 0,
		"quick_hands": 0,
		"ammo_carry": 0,
		"sortie_supply": 0,
	}
	raid_serial = 0
	reset_raid_supply_counters()
	magazine_ammo = 30
	reserve_ammo = 90
	has_ak = true
	scrap = 80
	weapon_level = 1
	medkits = 1
	canned_food = 0
	shelter_canned_food = 0
	last_return_settlement.clear()
	catnip = 0
	churu = 0
	valuable_inventory.clear()
	valuable_value_ledger.clear()
	active_churu_buffs.clear()
	bag_pressure_lesson_seen = false
	fatigue_lesson_seen = false
	field_controls_lesson_seen = false
	telegraph_lesson_seen = false
	headshot_lesson_seen = false
	cover_lesson_seen = false
	extraction_choice_lesson_seen = false
	catnip_fever_lesson_seen = false
	tutorial_steps_done.clear()
	unlocked_milestones.clear()
	resident_reroll_counts.clear()
	fatigue = 0.0
	rescued_workers = 0
	resident_cat_ids.clear()
	assigned_worker_ids.clear()
	assigned_catnip_worker_ids.clear()
	resident_traits.clear()
	mod_component_inventory = {
		"rubber_gasket": 0,
		"scope_lens": 0,
		"magazine_spring": 0,
		"precision_gear": 0,
		"military_alloy": 0,
	}
	progression_item_inventory = {
		"artisan_seal": 0,
		"sealed_zone_keycard": 0,
		"namdaemun_depot_plans": 0,
		"euljiro_grid_schematic": 0,
		"yongsan_control_key": 0,
	}
	weapon_mod_inventory = {
		"scope_2x": 0,
		"muffled_sock": 0,
		"sponge_pad": 0,
		"quick_mag": 0,
		"bell_bait": 0,
		"ak_precision_receiver": 0,
	}
	weapon_inventory = {"ak47": 1}
	weapon_first_equip_done = []
	equipment_inventory = {
		"scav_vest": 0,
		"riot_vest": 0,
		"patched_helmet": 0,
		"tactical_helmet": 0,
		"patched_sneakers": 0,
		"tactical_boots": 0,
		"military_vest": 0,
		"military_helmet": 0,
		"assault_boots": 0,
	}
	equipped_body_armor_id = ""
	equipped_head_armor_id = ""
	equipped_footwear_id = ""
	returning_from_shelter = false
	world_time_hours = 9.0
	equipped_weapon_id = "ak47"
	weapon_durability = 100.0
	equipped_weapon_mods.clear()
	weapon_mod_loadouts = {"ak47": []}
	equipped_magazine_id = "ak_30rnd"
	equipped_ammo_id = "762_fmj"
	ammo_inventory = {
		"762_fmj": 90,
	}
	secure_dog_slots = 1
	bag_capacity_level = 0
	scratcher_overclock_level = 0
	catnip_infusion_level = 0
	secure_dog_items.clear()
	pending_corpse_recovery.clear()
	corpse_recovery_attempt_active = false
	confirmed_raid_manifest.clear()
	raid_special_cargo.clear()
	recovered_story_cargo_ids.clear()
	subway_story_stage = 0
	main_mission_progress.clear()
	mission_choices.clear()
	seen_field_cinematics.clear()
	saja_seen_main_mission_zones.clear()
	shelter_workbench_level = 1
	shelter_tier = 1
	scratcher_bank_level = 1
	scratcher_multiplier = 1.0
	catnip_scraper_level = 1
	catnip_scraper_multiplier = 1.0
	storage_level = 1
	storage_inventory.clear()
	catnip_boost_end_time = 0
	catnip_fever_gauge = 0.0
	catnip_fever_active = false
	shelter_last_progress_time = 0
	workbench_repair_active = false
	workbench_repair_weapon_id = "ak47"
	shelter_offline_scrap_pending = 0
	shelter_offline_catnip_pending = 0
	shelter_offline_repair_pending = 0.0
	workbench_starter_parts_claimed = false
	shelter_scrap_fraction = 0.0
	shelter_catnip_fraction = 0.0
	workbench_starter_parts_claimed = false
	shelter_return_serial = 0
	survived_return_count = 0
	merchant_last_roll_serial = -1
	merchant_status = "away"
	merchant_decline_count = 0
	merchant_stock.clear()
	merchant_missed_visit = false
	weapon_enhancement_levels = {"ak47": 0}
	weapon_enhancement_transfers_done = []
	last_weapon_enhancement_transfer = {}
	armor_enhancement_levels = {}
	armor_enhancement_transfers_done = []
	last_armor_enhancement_transfer = {}
	gear_breakthroughs = {}
	mod_enhancement_levels.clear()
	selected_raid_zone = "jongno_outskirts"
	contract_chain_index = 0
	contract_status = "available"
	contract_progress = 0
	completed_contract_ids.clear()
	unlocked_contract_lore.clear()
	shelter_facility_unlocks = {
		"bed": true,
		"storage": false,
		"training": false,
		"workbench": false,
		"scratcher_bank": false,
		"catnip_scraper": false,
	}
	contract_agent_intro_seen = false
	saja_intro_seen = false
	merchant_intro_seen = false
	saja_second_run_intro_seen = false
	saja_seen_resident_count = 0
	saja_seen_boss_kills = 0
	saja_seen_story_cargo_count = 0
	saja_seen_subway_stage = 0
	total_boss_kills = 0
	juhong_seen_events.clear()
	iron_mission_index = 0
	iron_mission_status = "available"
	iron_mission_progress = 0
	completed_iron_mission_ids.clear()


func reset_all_progress_for_opening() -> bool:
	reset_run()
	opening_completed = false
	map_seed = 47291
	raid_serial = 0
	randomize_map()
	player_health = get_max_health()
	magazine_ammo = 30
	ammo_inventory["762_fmj"] = 300
	reserve_ammo = 300
	shelter_last_progress_time = int(Time.get_unix_time_from_system())
	if persistence_enabled and FileAccess.file_exists(persistence_path):
		var absolute_path := ProjectSettings.globalize_path(persistence_path)
		var remove_result := DirAccess.remove_absolute(absolute_path)
		if remove_result != OK:
			push_warning("Could not remove previous save before reset: %s" % absolute_path)
	return save_persistent_state() if persistence_enabled else true


func complete_opening_and_prepare_shelter() -> void:
	opening_completed = true
	player_health = get_max_health()
	fatigue = 0.0
	has_ak = true
	weapon_inventory["ak47"] = maxi(1, int(weapon_inventory.get("ak47", 0)))
	equipped_weapon_id = "ak47"
	equipped_magazine_id = "ak_30rnd"
	equipped_ammo_id = "762_fmj"
	magazine_ammo = 30
	ammo_inventory["762_fmj"] = maxi(300, int(ammo_inventory.get("762_fmj", 0)))
	reserve_ammo = int(ammo_inventory["762_fmj"])
	returning_from_shelter = false
	save_persistent_state()
