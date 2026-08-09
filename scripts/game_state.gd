extends Node

const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const RAID_REGION_CATALOG := preload("res://scripts/raid_region_catalog.gd")

const RAID_BAG_CAPACITY := 15
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
var player_health: int = 82
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
}
var magazine_ammo: int = 30
var reserve_ammo: int = 90
var has_ak: bool = true
var scrap: int = 80
var weapon_level: int = 1
var medkits: int = 0
var canned_food: int = 0
var catnip: int = 0
var churu: int = 0
# 원자재는 출정에서만 들어온다. 쉘터는 이것을 소비해 정제 자원을 만든다.
var raw_scrap: int = 0
var raw_catnip: int = 0
# 귀중품: 용도가 없고 오직 값어치만 있는 물건. 추출 슈터의 핵심 판단축인
# "칸당 가치"를 순수하게 만드는 아이템 계열이다. 쉘터에서 고철로 환전한다.
var valuable_inventory: Dictionary = {}
var fatigue: float = 0.0
var rescued_workers: int = 0
var resident_cat_ids: Array[String] = []
var assigned_worker_ids: Array[String] = []
var assigned_catnip_worker_ids: Array[String] = []
var resident_traits: Dictionary = {}
var mod_component_inventory: Dictionary = {
	"rubber_gasket": 0,
	"scope_lens": 0,
	"magazine_spring": 0,
}
var progression_item_inventory: Dictionary = {
	"rifle_blueprint": 0,
	"shotgun_blueprint": 0,
	"sealed_zone_keycard": 0,
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
var equipment_inventory: Dictionary = {
	"scav_vest": 0,
	"riot_vest": 0,
	"patched_helmet": 0,
	"tactical_helmet": 0,
	"patched_sneakers": 0,
	"tactical_boots": 0,
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
var ammo_inventory: Dictionary = {
	"9mm_fmj": 60,
	"45_fmj": 28,
	"762_fmj": 90,
	"12g_buckshot": 12,
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
var raid_enemy_drops_generated: int = 0
var raid_kills: int = 0
var raid_special_cargo: Dictionary = {}
var recovered_story_cargo_ids: Array[String] = []
var subway_story_stage: int = 0
var shelter_workbench_level: int = 1
var shelter_tier: int = 1
var scratcher_bank_level: int = 1
var scratcher_multiplier: float = 1.0
var catnip_scraper_level: int = 1
var catnip_scraper_multiplier: float = 1.0
var storage_level: int = 1
var storage_inventory: Array[Dictionary] = []
var catnip_boost_end_time: int = 0
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
var shelter_food_fraction: float = 0.0
var shelter_raw_scrap_fraction: float = 0.0
var shelter_raw_catnip_fraction: float = 0.0
# 이번 출정에만 적용되는 츄르 버프. 출정 종료/사망 시 소멸한다.
var active_churu_buffs: Array[String] = []
var last_corpse_decay_notice: Dictionary = {}
# 첫 판에서 "가방이 꽉 찼을 때의 갈등"을 한 번은 반드시 겪게 한다.
var bag_pressure_lesson_seen: bool = false
# 첫 출정에서 한 번씩만 뜨는 코칭. 다리 위 튜토리얼은 동사(이동·조준·사격)만
# 가르치고 끝나서, 정작 이 게임의 결정 구조는 아무도 설명하지 않았다.
var raw_material_lesson_seen: bool = false
var fatigue_lesson_seen: bool = false
var extraction_choice_lesson_seen: bool = false
var unlocked_milestones: Array[String] = []
var pending_milestone_unlocks: Array[Dictionary] = []
var resident_reroll_counts: Dictionary = {}
var shelter_return_serial: int = 0
var merchant_last_roll_serial: int = -1
var merchant_status: String = "away"
var merchant_decline_count: int = 0
var weapon_enhancement_levels: Dictionary = {"ak47": 0}
var mod_enhancement_levels: Dictionary = {}
var artisan_pity: int = 0
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
const ARTISAN_PITY_LIMIT := 10
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
		"reward": {"xp": 80, "canned_food": 4},
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
		"display_name": "누더기 방탄 조끼", "slot": "body", "damage_reduction": 0.12,
		"weight": 3.8, "icon": "armor",
		"texture_path": "res://assets/equipment/generated/scav_vest.png",
		"description": "얇은 철판을 덧댄 경량 조끼. 받는 피해를 12% 줄입니다.",
	},
	"riot_vest": {
		"display_name": "진압대 방탄 조끼", "slot": "body", "damage_reduction": 0.22,
		"weight": 6.2, "icon": "armor",
		"texture_path": "res://assets/equipment/generated/riot_vest.png",
		"description": "무겁지만 튼튼한 진압 장비. 받는 피해를 22% 줄입니다.",
	},
	"patched_helmet": {
		"display_name": "기워 붙인 헬멧", "slot": "head", "damage_reduction": 0.08,
		"weight": 1.4, "icon": "helmet",
		"texture_path": "res://assets/equipment/generated/patched_helmet.png",
		"description": "금이 간 안전모를 보강했습니다. 받는 피해를 8% 줄입니다.",
	},
	"tactical_helmet": {
		"display_name": "전술 방탄 헬멧", "slot": "head", "damage_reduction": 0.15,
		"weight": 2.1, "icon": "helmet",
		"texture_path": "res://assets/equipment/generated/tactical_helmet.png",
		"description": "군용 내피가 남아 있는 헬멧. 받는 피해를 15% 줄입니다.",
	},
	"patched_sneakers": {
		"display_name": "기워 붙인 운동화", "slot": "feet",
		"move_speed_bonus": 0.06, "stamina_cost_multiplier": 0.92,
		"weight": 0.7, "icon": "footwear",
		"texture_path": "res://assets/equipment/generated/patched_sneakers.png",
		"description": "가볍게 기워 발소리와 무게를 줄인 생존용 운동화입니다.",
	},
	"tactical_boots": {
		"display_name": "경량 전술화", "slot": "feet",
		"move_speed_bonus": 0.03, "stamina_cost_multiplier": 0.78,
		"weight": 1.4, "icon": "footwear",
		"texture_path": "res://assets/equipment/generated/tactical_boots.png",
		"description": "발목을 잡아주면서도 유연한 밑창을 사용한 경량 전술화입니다.",
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
const TRAINING_NODE_DEFS := {
	"vitality": {
		"title": "중량 훈련", "description": "랭크마다 최대 체력 +10", "icon": "health",
		"max_rank": 5, "base_cost": 8, "cost_step": 6, "requires": {},
	},
	"endurance": {
		"title": "유산소 훈련", "description": "랭크마다 최대 스태미나 +12", "icon": "stamina",
		"max_rank": 5, "base_cost": 8, "cost_step": 6, "requires": {},
	},
	"recovery": {
		"title": "회복 루틴", "description": "랭크마다 스태미나 회복 +8%", "icon": "recovery",
		"max_rank": 4, "base_cost": 14, "cost_step": 10, "requires": {"vitality": 2},
	},
	"agility": {
		"title": "풋워크", "description": "랭크마다 이동 속도 +2%", "icon": "speed",
		"max_rank": 4, "base_cost": 14, "cost_step": 10, "requires": {"endurance": 2},
	},
	"fieldcraft": {
		"title": "현장 체력", "description": "랭크마다 피로 획득 -7%", "icon": "fitness",
		"max_rank": 3, "base_cost": 28, "cost_step": 18, "requires": {"recovery": 2, "agility": 2},
	},
}
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
	},
	"namsan_core": {
		"name": "남산 오염 핵심부",
		"description": "서울에서 가장 위험한 심야 전투 구역입니다.",
		"required_tier": 5,
		"stage_tier": 4,
		"threat": 1.0,
		"enemy_multiplier": 2.3,
		"boss": true,
		"reward": "최상급 부품 · 대량 츄르",
	},
}

const WORKBENCH_UPGRADE_COSTS := {2: 7500, 3: 55000, 4: 400000, 5: 3000000}
const SCRATCHER_UPGRADE_COSTS := {2: 12000, 3: 150000, 4: 2000000, 5: 30000000}
const CATNIP_SCRAPER_UPGRADE_COSTS := {2: 10000, 3: 120000, 4: 1500000, 5: 20000000}
const STORAGE_GRID_BY_LEVEL := {
	1: Vector2i(6, 5),
	2: Vector2i(7, 6),
	3: Vector2i(8, 7),
	4: Vector2i(9, 8),
	5: Vector2i(10, 9),
}
const STORAGE_UPGRADE_COSTS := {
	2: {"scrap": 8000, "churu": 0},
	3: {"scrap": 60000, "churu": 1},
	4: {"scrap": 500000, "churu": 2},
	5: {"scrap": 4000000, "churu": 4},
}
const SHELTER_CAPACITY_BY_TIER := {1: 5, 2: 10, 3: 20, 4: 35, 5: 50}
const KNEADING_SLOTS_BY_TIER := {1: 3, 2: 6, 3: 10, 4: 15, 5: 20}
const CATNIP_SLOTS_BY_TIER := {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
const SHELTER_UPGRADE_COSTS := {
	2: {"scrap": 30000, "churu": 1},
	3: {"scrap": 400000, "churu": 3},
	4: {"scrap": 5000000, "churu": 8},
	5: {"scrap": 60000000, "churu": 20},
}
# ── 캣닢 경제 ──────────────────────────────────────────────────
# 캣닢은 시설 하나를 통째로 쓰면서 소비처가 부스트 하나뿐이었다.
# 츄르가 "출정 전 한 방"이라면 캣닢은 "쉘터 운영의 상시 비용"이다.
#
# 재굴림: 주민 특성은 이제 트레이드오프라 나쁜 조합이 나올 수 있다.
# 캣닢을 태워 다시 뽑는다. 뽑을수록 비싸져서 무한 리롤은 막는다.
const RESIDENT_REROLL_BASE_COST := 1200
const RESIDENT_REROLL_STEP := 900
const RESIDENT_REROLL_MAX_COST := 12000

const CATNIP_BOOST_COST := 900
const CATNIP_BOOST_DURATION_SECONDS := 600
const CATNIP_BOOST_MULTIPLIER := 10.0
const BASE_SCRAP_PER_WORKER_HOUR := 72.0
const BASE_CATNIP_PER_WORKER_SECOND := 1.0
const WORKER_HOURS_PER_CANNED_FOOD := 6.0

# ── 문턱 해금 ──────────────────────────────────────────────────
#
# 수치가 5% 오르는 것으로는 강해졌다는 느낌이 안 난다. 인크리멘탈의
# 쾌감은 "어제 못 하던 것을 오늘 할 수 있다"에서 온다.
# 청사진과 키카드는 그동안 수집만 되고 아무 문도 열지 않았다.
# 여기서 실제 관문으로 만든다.
const MILESTONE_UNLOCKS := {
	"craft_rifle": {
		"title": "소총 제작 해금",
		"body": "청사진을 읽었다. 작업대에서 캣라시니코프를 직접 만들 수 있다.",
		"requires_progression": "rifle_blueprint",
	},
	"craft_shotgun": {
		"title": "산탄총 제작 해금",
		"body": "청사진을 읽었다. 작업대에서 참치 헌터를 직접 만들 수 있다.",
		"requires_progression": "shotgun_blueprint",
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

# ── 원자재 게이트 ──────────────────────────────────────────────
# 쉘터는 원자재를 만들지 못한다. 출정에서 가져온 만큼만 가공할 수 있다.
# 원자재 1개가 주민 1명을 몇 초 동안 돌리는지.
const WORKER_SECONDS_PER_RAW_SCRAP := 60.0
const WORKER_SECONDS_PER_RAW_CATNIP := 90.0
# 정제 산출: 원자재 1개당 나오는 정제 자원의 기대량 (배율 적용 전).
const REFINED_SCRAP_PER_RAW := 600
const REFINED_CATNIP_PER_RAW := 240
# 특성은 서열이 아니라 선택이어야 한다. 예전엔 전부 1.0 이상이라
# "누가 더 좋은가"만 있었고 어디에 넣을지 고민할 이유가 없었다.
# 이제 각자 잘하는 쪽과 못하는 쪽이 갈리고, 잘하는 만큼 더 먹는다.
# appetite = 통조림 소비 배율. 고성능 주민은 유지비가 비싸다.
const RESIDENT_TRAIT_PRESETS := [
	{"name": "말랑 앞발", "kneading": 1.55, "catnip": 0.70, "appetite": 1.25},
	{"name": "초록 코", "kneading": 0.68, "catnip": 1.60, "appetite": 1.25},
	{"name": "야무진 발톱", "kneading": 1.20, "catnip": 1.15, "appetite": 1.45},
	{"name": "밤샘 체질", "kneading": 1.10, "catnip": 1.10, "appetite": 1.00},
	{"name": "평범한 주민", "kneading": 1.00, "catnip": 1.00, "appetite": 0.85},
	{"name": "대식가", "kneading": 1.75, "catnip": 1.70, "appetite": 2.30},
	{"name": "소식가", "kneading": 0.82, "catnip": 0.82, "appetite": 0.45},
]
const RESIDENT_NAME_POOL: Array[String] = [
	"보리", "두부", "호두", "감자", "밤이", "구름", "탄이", "콩이",
	"모카", "치즈", "소금", "후추", "달이", "별이", "봄이", "여름",
	"가을", "겨울", "라떼", "쿠키", "설탕", "참깨", "들깨", "누룽지",
	"만두", "찹쌀", "팥이", "토리", "마루", "나비", "복실", "몽이",
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
	raid_enemy_drops_generated = 0
	raid_kills = 0


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
	for scalar_key in ["medkits", "canned_food", "churu", "raw_scrap", "raw_catnip"]:
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
	var carried_equipment := equipment_inventory.duplicate(true)
	for equipped_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipped_id.is_empty():
			carried_equipment[equipped_id] = int(carried_equipment.get(equipped_id, 0)) + 1
	return {
		"ammo_inventory": ammo_inventory.duplicate(true),
		"medkits": maxi(0, medkits),
		"canned_food": get_backpack_storage_count("food", "canned_food"),
		"churu": maxi(0, churu),
		"mod_component_inventory": mod_component_inventory.duplicate(true),
		"progression_item_inventory": progression_item_inventory.duplicate(true),
		"weapon_mod_inventory": weapon_mod_inventory.duplicate(true),
		"weapon_inventory": weapon_inventory.duplicate(true),
		"equipment_inventory": carried_equipment,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_weapon_mods": equipped_weapon_mods.duplicate(),
		"weapon_mod_loadouts": weapon_mod_loadouts.duplicate(true),
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
	for inventory in [ammo_inventory, mod_component_inventory, progression_item_inventory, weapon_mod_inventory, equipment_inventory]:
		for key in inventory.keys():
			inventory[key] = 0
	weapon_inventory.clear()
	weapon_mod_loadouts.clear()
	medkits = 0
	canned_food = get_stored_storage_count("food", "canned_food")
	churu = 0
	# 가지고 있던 원자재는 시체와 함께 현장에 남는다. 창고에 넣어둔 분량만 살아남는다.
	raw_scrap = 0
	raw_catnip = 0
	valuable_inventory.clear()
	clear_churu_buffs()
	magazine_ammo = 0
	reserve_ammo = 0
	has_ak = false
	equipped_weapon_id = ""
	equipped_weapon_mods.clear()
	equipped_magazine_id = ""
	equipped_ammo_id = ""
	equipped_body_armor_id = ""
	equipped_head_armor_id = ""
	equipped_footwear_id = ""
	secure_dog_items.clear()
	raid_special_cargo.clear()
	save_persistent_state()


func finish_corpse_recovery_attempt() -> void:
	if corpse_recovery_attempt_active:
		clear_pending_corpse_recovery()


func register_shelter_return() -> void:
	shelter_return_serial += 1
	clear_confirmed_raid_manifest()
	# 츄르 버프는 한 판짜리다. 복귀와 동시에 사라진다.
	clear_churu_buffs()
	# 남겨 둔 시체는 그동안 남의 손을 탄다.
	last_corpse_decay_notice = apply_corpse_decay()
	pending_milestone_unlocks = check_milestone_unlocks()
	sync_shelter_progression_milestones()
	save_persistent_state()


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
				"멈춰. 이 아래로 내려온 이상, 네 발자국도 내 귀에 들어온다.",
				"겁먹을 필요는 없어. 난 사자다. 인간들이 사라진 뒤부터 이 쉘터를 지켜 왔지.",
				"혼자 지키는 데는 한계가 왔다. 너는 도시를 다녀오고, 나는 여기서 돌아올 자리를 지킨다.",
				"서로의 몫을 지키면 공생이고, 욕심이 앞서면 폐허가 하나 더 늘어날 뿐이야.",
				"우선 쉬어. 다음 출정부터 네가 가져오는 것들이 이 빈 공간의 모습을 바꿀 거다.",
			],
		}
	if shelter_return_serial >= 1 and not saja_second_run_intro_seen:
		return {
			"id": "saja_second_run",
			"speaker": "사자",
			"title": "쉘터가 움직이기 시작했다",
			"lines": [
				"한 번 나갔다가 제 발로 돌아왔군. 그 정도면 이곳의 열쇠를 조금 더 맡겨도 되겠어.",
				"창고와 체력 훈련장을 열어 뒀다. 전리품은 창고에 남기고, 통조림은 몸에 투자해.",
				"저 근육 덩어리는 철근이다. 시설 공사는 내게 맡기고, 녀석에게는 특별 훈련을 받아.",
				"오늘은 행상인도 파이프 근처를 기웃거릴 거다. 들일지 말지는 네가 결정해.",
				"내 계약을 해결하면 고철, 캣닢, 무기 정비 설비를 하나씩 세워 주지.",
			],
		}
	if rescued_workers > saja_seen_resident_count:
		return {
			"id": "saja_resident_%d" % rescued_workers,
			"speaker": "사자",
			"title": "새 식구",
			"lines": [
				"뒤에 데려온 고양이, 끝까지 놓치지 않았더군.",
				"여기서는 구조된 주민도 자기 몫과 이름을 가진다. 당장 일부터 시키지는 마.",
				"숨을 돌린 뒤 생산기에 배치하면, 그때부터 쉘터의 숫자가 아니라 구성원이 되는 거야.",
			],
		}
	if total_boss_kills > saja_seen_boss_kills:
		return {
			"id": "saja_boss_%d" % total_boss_kills,
			"speaker": "사자",
			"title": "도시가 이름을 기억한다",
			"lines": [
				"밖이 시끄럽더니 네가 그 원인이었군. 도시가 이름 붙인 놈을 쓰러뜨렸다고 들었다.",
				"보스 하나가 사라지면 빈자리를 노리는 세력이 반드시 움직여. 다음 출정은 같은 길이어도 다를 거다.",
				"전리품만 보지 말고, 누가 그 빈자리를 차지하는지 살펴. 그게 다음 이야기의 시작이니까.",
			],
		}
	if recovered_story_cargo_ids.size() > saja_seen_story_cargo_count:
		return {
			"id": "saja_cargo_%d" % recovered_story_cargo_ids.size(),
			"speaker": "사자",
			"title": "검게 지워진 화물표",
			"lines": [
				"이 표식은 오래전에 사라진 운송대의 것이야. 그런데 누군가 최근에 다시 덧칠했군.",
				"주홍이라는 고양이가 이 표식을 쫓고 있다. 붉은 앞치마를 봐도 먼저 칼부터 보지는 마.",
				"녀석이 나타난다면, 네가 가져온 물건이 단순한 전리품이 아니라는 뜻이다.",
			],
		}
	if subway_story_stage > saja_seen_subway_stage:
		return {
			"id": "saja_subway_%d" % subway_story_stage,
			"speaker": "사자",
			"title": "지하에서 올라온 신호",
			"lines": [
				"지하철 쪽 신호가 다시 살아났어. 인간 설비가 저절로 깨어날 리는 없다.",
				"주홍이 그 아래를 먼저 훑고 있을 거다. 만나면 말은 끝까지 들어.",
				"우리가 모르는 세력이 서울의 오래된 맥박을 다시 뛰게 하고 있어.",
			],
		}
	return {}


func mark_shelter_story_event_seen(event_id: String) -> void:
	if event_id == "saja_intro":
		saja_intro_seen = true
	elif event_id == "saja_second_run":
		saja_second_run_intro_seen = true
	elif event_id.begins_with("saja_resident_"):
		saja_seen_resident_count = rescued_workers
	elif event_id.begins_with("saja_boss_"):
		saja_seen_boss_kills = total_boss_kills
	elif event_id.begins_with("saja_cargo_"):
		saja_seen_story_cargo_count = recovered_story_cargo_ids.size()
	elif event_id.begins_with("saja_subway_"):
		saja_seen_subway_stage = subway_story_stage
	save_persistent_state()


func get_pending_juhong_event() -> Dictionary:
	if recovered_story_cargo_ids.size() > 0 and not juhong_seen_events.has("cargo_warning"):
		return {
			"id": "cargo_warning",
			"speaker": "주홍",
			"title": "붉은 앞치마의 방문자",
			"lines": [
				"그 화물표, 어디서 났지? 대답은 천천히 해도 돼. 거짓말만 아니면.",
				"인간들이 사라진 날, 봉쇄선 안쪽으로 들어간 운송대가 있었어. 돌아온 기록은 없고.",
				"네가 주운 건 그 운송대가 남긴 빵 부스러기야. 다음 조각도 찾게 되면 숨기지 마.",
				"난 주홍. 오래 머물 생각은 없어. 신호가 움직이면 다시 나타나지.",
			],
		}
	if subway_story_stage >= 1 and not juhong_seen_events.has("subway_signal"):
		return {
			"id": "subway_signal",
			"speaker": "주홍",
			"title": "지하의 목소리",
			"lines": [
				"지하 신호를 들었지? 구조 요청처럼 들리지만, 같은 문장이 정확히 반복되고 있어.",
				"살아 있는 목소리가 아니야. 누군가 고양이들을 아래로 유인하고 있다.",
				"그래도 내려가야 해. 누가, 왜 그 목소리를 틀었는지 알아야 하니까.",
			],
		}
	if total_boss_kills >= 1 and not juhong_seen_events.has("boss_vacancy"):
		return {
			"id": "boss_vacancy",
			"speaker": "주홍",
			"title": "빈 왕좌",
			"lines": [
				"네가 보스를 쓰러뜨린 자리로 벌써 다른 무리가 향하고 있어.",
				"우리가 강해진 게 아니라, 도시의 균형을 흔든 거야. 그 차이를 잊으면 오래 못 살아.",
				"다음에는 싸우기 전에 누가 서로를 미워하는지부터 봐. 총알보다 오래 가는 무기니까.",
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


func roll_merchant_visit(chance: float = 0.38) -> bool:
	if merchant_status == "inside" or merchant_status == "waiting":
		return true
	if shelter_return_serial <= 0 or merchant_last_roll_serial == shelter_return_serial:
		return false
	merchant_last_roll_serial = shelter_return_serial
	if shelter_return_serial == 1:
		merchant_status = "waiting"
		save_persistent_state()
		return true
	var random := RandomNumberGenerator.new()
	random.seed = int(map_seed) ^ (shelter_return_serial * 982451653) ^ 0x4D455243
	if random.randf() <= clampf(chance, 0.0, 1.0):
		merchant_status = "waiting"
		save_persistent_state()
		return true
	save_persistent_state()
	return false


func accept_merchant_visit() -> void:
	merchant_status = "inside"


func decline_merchant_visit() -> void:
	merchant_status = "away"
	merchant_decline_count += 1


func store_secure_item(item: Dictionary) -> bool:
	if secure_dog_items.size() >= secure_dog_slots:
		return false
	secure_dog_items.append(item.duplicate(true))
	return true


func upgrade_secure_dog() -> bool:
	if secure_dog_slots >= 6:
		return false
	secure_dog_slots += 1
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
			return get_weapon_mod_count(item_id)
		"medkit":
			return medkits
		"food":
			return maxi(0, canned_food - get_stored_storage_count("food", "canned_food"))
	return 0


func get_raid_bag_capacity() -> int:
	return RAID_BAG_CAPACITY + get_churu_bag_bonus_slots()


func get_raid_item_stack_limit(item_type: String) -> int:
	return maxi(1, int(RAID_STACK_LIMITS.get(item_type, 1)))


# 원자재는 부피가 크다. 한 슬롯에 이만큼만 들어가고, 넘치면 슬롯을 더 먹는다.
const RAW_MATERIAL_PER_SLOT := 10
const RAW_MATERIAL_TYPES := ["raw_scrap", "raw_catnip"]


func get_raid_item_slot_cost(item_type: String, _item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if item_type in ["weapon", "equipment"]:
		return amount
	if item_type in RAW_MATERIAL_TYPES:
		return ceili(float(amount) / float(RAW_MATERIAL_PER_SLOT))
	return 1


func _get_raid_bag_count(item_type: String, item_id: String) -> int:
	match item_type:
		"weapon", "equipment", "ammo", "component", "mod", "medkit", "food":
			return get_backpack_storage_count(item_type, item_id)
		"progression":
			return get_progression_item_count(item_id)
		"churu":
			return maxi(0, churu)
		"raw_scrap":
			return maxi(0, raw_scrap)
		"raw_catnip":
			return maxi(0, raw_catnip)
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
	used += get_raid_item_slot_cost("raw_scrap", "raw_scrap", raw_scrap)
	used += get_raid_item_slot_cost("raw_catnip", "raw_catnip", raw_catnip)
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
			get_progression_item_count(str(progression_id))
		)
	for mod_id in weapon_mod_inventory.keys():
		used += get_raid_item_slot_cost(
			"mod",
			str(mod_id),
			get_weapon_mod_count(str(mod_id))
		)
	for weapon_id in weapon_inventory.keys():
		used += get_raid_item_slot_cost(
			"weapon",
			str(weapon_id),
			get_backpack_storage_count("weapon", str(weapon_id))
		)
	for equipment_id in equipment_inventory.keys():
		used += get_raid_item_slot_cost(
			"equipment",
			str(equipment_id),
			get_equipment_count(str(equipment_id))
		)
	if not raid_special_cargo.is_empty():
		used += 1
	return used


func get_raid_item_added_slot_delta(
	item_type: String,
	item_id: String,
	amount: int
) -> int:
	var current := _get_raid_bag_count(item_type, item_id)
	if item_type == "special_cargo":
		return 0 if current > 0 else 1
	return (
		get_raid_item_slot_cost(item_type, item_id, current + maxi(0, amount))
		- get_raid_item_slot_cost(item_type, item_id, current)
	)


func get_raid_items_added_slot_delta(items: Array[Dictionary]) -> int:
	var added_slots: int = 0
	var planned_stack_keys: Dictionary = {}
	var planned_raw_amounts: Dictionary = {}
	var cargo_planned: bool = not raid_special_cargo.is_empty()
	for item in items:
		var item_type: String = str(item.get("type", ""))
		var item_id: String = str(item.get("id", ""))
		var amount: int = maxi(0, int(item.get("amount", 0)))
		if item_type.is_empty() or item_id.is_empty() or amount <= 0:
			continue
		if item_type in ["weapon", "equipment"]:
			added_slots += amount
			continue
		if item_type == "special_cargo":
			if not cargo_planned:
				added_slots += 1
				cargo_planned = true
			continue
		if item_type in RAW_MATERIAL_TYPES:
			# 원자재는 누적량에 따라 슬롯이 늘어나므로 배치 전체를 합산해서 계산한다.
			planned_raw_amounts[item_type] = int(planned_raw_amounts.get(item_type, 0)) + amount
			continue
		var stack_key: String = "%s:%s" % [item_type, item_id]
		if _get_raid_bag_count(item_type, item_id) <= 0 and not planned_stack_keys.has(stack_key):
			added_slots += 1
			planned_stack_keys[stack_key] = true
	for raw_type in planned_raw_amounts.keys():
		var raw_id := str(raw_type)
		var current_raw := _get_raid_bag_count(raw_id, raw_id)
		added_slots += (
			get_raid_item_slot_cost(raw_id, raw_id, current_raw + int(planned_raw_amounts[raw_type]))
			- get_raid_item_slot_cost(raw_id, raw_id, current_raw)
		)
	return added_slots


func can_add_raid_items(items: Array[Dictionary]) -> bool:
	return get_raid_bag_used_slots() + get_raid_items_added_slot_delta(items) <= get_raid_bag_capacity()


func can_add_raid_item(item_type: String, item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if item_type == "special_cargo" and not raid_special_cargo.is_empty():
		return false
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
		"raw_scrap":
			raw_scrap += amount
		"raw_catnip":
			raw_catnip += amount
		"valuable":
			valuable_inventory[item_id] = int(valuable_inventory.get(item_id, 0)) + amount
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
			progression_item_inventory[item_id] = maxi(0, get_progression_item_count(item_id) - removable)
		"medkit":
			medkits = maxi(0, medkits - removable)
		"food":
			canned_food = maxi(0, canned_food - removable)
		"churu":
			churu = maxi(0, churu - removable)
		"raw_scrap":
			raw_scrap = maxi(0, raw_scrap - removable)
		"raw_catnip":
			raw_catnip = maxi(0, raw_catnip - removable)
		"valuable":
			valuable_inventory[item_id] = maxi(0, int(valuable_inventory.get(item_id, 0)) - removable)
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
	var next_cargo := cargo.duplicate(true)
	var required := 1
	if get_raid_bag_used_slots() + required > get_raid_bag_capacity():
		return false
	raid_special_cargo = next_cargo
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


func deposit_storage_item(item_type: String, item_id: String, amount: int = 1) -> Dictionary:
	_normalize_storage_inventory()
	var available := get_backpack_storage_count(item_type, item_id)
	var moved := mini(maxi(amount, 0), available)
	if moved <= 0:
		return {"ok": false, "reason": "보관할 수 있는 소지품이 없습니다."}
	var stack_limit := _get_storage_stack_limit(item_type)
	var free_units := 0
	for entry in storage_inventory:
		if str(entry.get("type", "")) == item_type and str(entry.get("id", "")) == item_id:
			free_units += maxi(0, stack_limit - int(entry.get("count", 0)))
	free_units += maxi(0, get_storage_capacity() - storage_inventory.size()) * stack_limit
	if free_units < moved:
		return {"ok": false, "reason": "창고에 빈 슬롯이 부족합니다."}
	if not _remove_backpack_storage_item(item_type, item_id, moved):
		return {"ok": false, "reason": "소지품을 창고로 옮기지 못했습니다."}
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
	save_persistent_state()
	return {"ok": true, "moved": moved}


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
		"food":
			return 20
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
		"medkit":
			medkits = maxi(0, medkits - amount)
		"food":
			# Food remains part of the shelter-wide currency total. Storage only
			# records which units are reserved in the warehouse.
			pass
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
		"medkit":
			medkits += amount
		"food":
			pass


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


func _trim_stored_canned_food_to_total() -> void:
	var remaining := maxi(0, canned_food)
	for index in range(storage_inventory.size() - 1, -1, -1):
		var entry := storage_inventory[index]
		if (
			str(entry.get("type", "")) != "food"
			or str(entry.get("id", "")) != "canned_food"
		):
			continue
		var kept := mini(maxi(0, int(entry.get("count", 0))), remaining)
		remaining -= kept
		if kept <= 0:
			storage_inventory.remove_at(index)
		else:
			entry["count"] = kept


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
	weapon_inventory[weapon_id] = maxi(0, int(weapon_inventory.get(weapon_id, 0)) + amount)
	if not weapon_mod_loadouts.has(weapon_id):
		weapon_mod_loadouts[weapon_id] = []


func get_equipment_definition(equipment_id: String) -> Dictionary:
	return (EQUIPMENT_DEFINITIONS.get(equipment_id, {}) as Dictionary).duplicate(true)


func get_equipment_count(equipment_id: String) -> int:
	return int(equipment_inventory.get(equipment_id, 0))


func add_equipment(equipment_id: String, amount: int = 1) -> bool:
	if not EQUIPMENT_DEFINITIONS.has(equipment_id) or amount <= 0:
		return false
	equipment_inventory[equipment_id] = get_equipment_count(equipment_id) + amount
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
	equipment_inventory[equipped_id] = get_equipment_count(equipped_id) + 1
	match slot:
		"head":
			equipped_head_armor_id = ""
		"feet":
			equipped_footwear_id = ""
		_:
			equipped_body_armor_id = ""
	return true


func get_equipment_damage_multiplier() -> float:
	var reduction := 0.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if equipment_id.is_empty():
			continue
		var definition := get_equipment_definition(equipment_id)
		reduction += float(definition.get("damage_reduction", 0.0))
	return clampf(1.0 - reduction, 0.5, 1.0)


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
	return int(progression_item_inventory.get(item_id, 0))


func claim_workbench_starter_parts() -> bool:
	if workbench_starter_parts_claimed:
		return false
	workbench_starter_parts_claimed = true
	add_weapon("m1911", 1)
	add_weapon("mp5", 1)
	add_mod_component("rubber_gasket", 2)
	add_mod_component("scope_lens", 2)
	add_mod_component("magazine_spring", 2)
	return true


func get_mod_component_count(component_id: String) -> int:
	return int(mod_component_inventory.get(component_id, 0))


func add_weapon_mod(mod_id: String, amount: int = 1) -> void:
	weapon_mod_inventory[mod_id] = maxi(
		0,
		int(weapon_mod_inventory.get(mod_id, 0)) + amount
	)


func get_weapon_mod_count(mod_id: String) -> int:
	return int(weapon_mod_inventory.get(mod_id, 0))


func get_supported_worker_count() -> int:
	_ensure_resident_records()
	return resident_cat_ids.size()


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


func get_resident_trait_label(worker_id: String) -> String:
	var trait_data := get_resident_trait(worker_id)
	return "%s · 꾹꾹이 +%d%% · 캣닢 +%d%%" % [
		str(trait_data.get("name", "평범한 주민")),
		roundi((float(trait_data.get("kneading", 1.0)) - 1.0) * 100.0),
		roundi((float(trait_data.get("catnip", 1.0)) - 1.0) * 100.0),
	]


func get_kneading_efficiency_total() -> float:
	var total := 0.0
	for worker_id in assigned_worker_ids:
		total += float(get_resident_trait(worker_id).get("kneading", 1.0))
	return total


func get_catnip_efficiency_total() -> float:
	var total := 0.0
	for worker_id in assigned_catnip_worker_ids:
		total += float(get_resident_trait(worker_id).get("catnip", 1.0))
	return total


func get_worker_production_per_second(worker_id: String, production_kind: String) -> float:
	var trait_data := get_resident_trait(worker_id)
	match production_kind:
		"scratcher", "kneading":
			if not is_shelter_facility_unlocked("scratcher_bank"):
				return 0.0
			if not assigned_worker_ids.has(worker_id):
				return 0.0
			var base_rate := maxi(
				1,
				roundi(
					float(trait_data.get("kneading", 1.0))
					* scratcher_multiplier
				)
			)
			return float(base_rate) * get_production_multiplier()
		"catnip":
			if not is_shelter_facility_unlocked("catnip_scraper"):
				return 0.0
			if not assigned_catnip_worker_ids.has(worker_id):
				return 0.0
			return float(maxi(
				1,
				roundi(
					float(trait_data.get("catnip", 1.0))
					* BASE_CATNIP_PER_WORKER_SECOND
					* catnip_scraper_multiplier
				)
			))
	return 0.0


func get_catnip_boost_remaining() -> int:
	return maxi(0, catnip_boost_end_time - int(Time.get_unix_time_from_system()))


func is_catnip_boost_active() -> bool:
	return get_catnip_boost_remaining() > 0


func get_production_multiplier() -> float:
	return CATNIP_BOOST_MULTIPLIER if is_catnip_boost_active() else 1.0


func activate_catnip_boost() -> bool:
	process_shelter_progress()
	if catnip < CATNIP_BOOST_COST:
		return false
	catnip -= CATNIP_BOOST_COST
	catnip_boost_end_time = int(Time.get_unix_time_from_system()) + CATNIP_BOOST_DURATION_SECONDS
	return true


func get_scrap_per_hour() -> float:
	return get_base_scrap_per_hour() * get_production_multiplier()


func get_base_scrap_per_hour() -> float:
	if not is_shelter_facility_unlocked("scratcher_bank"):
		return 0.0
	var total_per_second := 0.0
	for worker_id in assigned_worker_ids:
		var trait_data := get_resident_trait(worker_id)
		total_per_second += float(maxi(
			1,
			roundi(float(trait_data.get("kneading", 1.0)) * scratcher_multiplier)
		))
	return total_per_second * 3600.0


func get_scrap_per_second() -> float:
	return get_scrap_per_hour() / 3600.0


func get_catnip_per_hour() -> float:
	return get_catnip_per_second() * 3600.0


func get_catnip_per_second() -> float:
	if not is_shelter_facility_unlocked("catnip_scraper"):
		return 0.0
	var total := 0.0
	for worker_id in assigned_catnip_worker_ids:
		total += get_worker_production_per_second(worker_id, "catnip")
	return total


func tick_shelter_live(delta: float) -> int:
	var safe_delta := maxf(delta, 0.0)
	var scrap_rate := get_scrap_per_second()
	var catnip_rate := get_catnip_per_second()
	var work_delta := _consume_worker_food_for_duration(safe_delta)
	# 라인별로 원자재를 따로 태운다. 한쪽이 멈춰도 다른 쪽은 계속 돈다.
	var scrap_seconds := _consume_raw_material_for_duration(
		"scrap", get_active_scratcher_workers(), work_delta
	)
	var catnip_seconds := _consume_raw_material_for_duration(
		"catnip", get_active_catnip_workers(), work_delta
	)
	var gain := scrap_rate * scrap_seconds
	var catnip_gain := catnip_rate * catnip_seconds
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
	var progress_start := shelter_last_progress_time
	var elapsed := maxi(0, now - shelter_last_progress_time)
	shelter_last_progress_time = now
	var base_scrap_rate := get_base_scrap_per_hour()
	var catnip_rate := get_catnip_per_hour()
	var work_seconds := _consume_worker_food_for_duration(float(elapsed))
	var scrap_seconds := _consume_raw_material_for_duration(
		"scrap", get_active_scratcher_workers(), work_seconds
	)
	var catnip_seconds := _consume_raw_material_for_duration(
		"catnip", get_active_catnip_workers(), work_seconds
	)
	var base_scrap_gain := base_scrap_rate * scrap_seconds / 3600.0
	var boosted_seconds := mini(roundi(scrap_seconds), maxi(0, mini(now, catnip_boost_end_time) - progress_start))
	var boosted_extra := base_scrap_rate * float(boosted_seconds) / 3600.0 * (CATNIP_BOOST_MULTIPLIER - 1.0)
	shelter_scrap_fraction += base_scrap_gain + boosted_extra
	var scrap_gain := int(floor(shelter_scrap_fraction))
	shelter_scrap_fraction -= float(scrap_gain)
	shelter_catnip_fraction += catnip_rate * catnip_seconds / 3600.0
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


func _consume_worker_food_for_duration(requested_seconds: float) -> float:
	# 통조림은 주민의 노동 시간 그 자체를 산다. 떨어지면 라인 전체가 멈춘다.
	var worker_count := get_active_scratcher_workers() + get_active_catnip_workers()
	if worker_count <= 0 or requested_seconds <= 0.0:
		return maxf(requested_seconds, 0.0)
	if canned_food <= 0:
		return 0.0
	# 잘 일하는 주민일수록 많이 먹는다. 배치는 산출만이 아니라 식비의 문제다.
	var appetite_total := get_total_worker_appetite()
	var food_per_second := appetite_total / (WORKER_HOURS_PER_CANNED_FOOD * 3600.0)
	var affordable_seconds := float(canned_food) / maxf(food_per_second, 0.000001)
	var work_seconds := minf(requested_seconds, affordable_seconds)
	shelter_food_fraction += work_seconds * food_per_second
	var consumed := mini(canned_food, int(floor(shelter_food_fraction)))
	if consumed > 0:
		canned_food -= consumed
		shelter_food_fraction -= float(consumed)
	return work_seconds


func _consume_raw_material_for_duration(
	kind: String, worker_count: int, requested_seconds: float
) -> float:
	# 원자재가 있는 만큼만 가공한다. 이것이 출정과 쉘터를 묶는 지점이다.
	if worker_count <= 0 or requested_seconds <= 0.0:
		return 0.0
	var is_catnip := kind == "catnip"
	var stock: int = raw_catnip if is_catnip else raw_scrap
	if stock <= 0:
		return 0.0
	var seconds_per_unit: float = (
		WORKER_SECONDS_PER_RAW_CATNIP if is_catnip else WORKER_SECONDS_PER_RAW_SCRAP
	)
	var units_per_second := float(worker_count) / maxf(seconds_per_unit, 0.000001)
	var affordable_seconds := float(stock) / maxf(units_per_second, 0.000001)
	var work_seconds := minf(requested_seconds, affordable_seconds)
	var fraction_key := work_seconds * units_per_second
	if is_catnip:
		shelter_raw_catnip_fraction += fraction_key
		var used_catnip := mini(raw_catnip, int(floor(shelter_raw_catnip_fraction)))
		if used_catnip > 0:
			raw_catnip -= used_catnip
			shelter_raw_catnip_fraction -= float(used_catnip)
	else:
		shelter_raw_scrap_fraction += fraction_key
		var used_scrap := mini(raw_scrap, int(floor(shelter_raw_scrap_fraction)))
		if used_scrap > 0:
			raw_scrap -= used_scrap
			shelter_raw_scrap_fraction -= float(used_scrap)
	return work_seconds


func get_valuable_total_value() -> int:
	var total := 0
	for valuable_id in valuable_inventory.keys():
		var amount := maxi(0, int(valuable_inventory[valuable_id]))
		if amount <= 0:
			continue
		total += amount * int(
			(LOOT_ECONOMY.ITEM_CATALOG.get(str(valuable_id), {}) as Dictionary).get("base_value", 0)
		)
	return total


func sell_all_valuables() -> Dictionary:
	# 귀중품은 용도가 없다. 쉘터에 돌아와 고철로 바꾸는 것이 유일한 출구다.
	var total := get_valuable_total_value()
	var count := 0
	for amount in valuable_inventory.values():
		count += maxi(0, int(amount))
	if total <= 0:
		return {"scrap": 0, "count": 0}
	valuable_inventory.clear()
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
	if catnip < cost:
		return {"ok": false, "reason": "catnip", "cost": cost}
	var current := get_resident_trait(resident_id)
	var current_name := str(current.get("name", ""))
	# 같은 특성이 다시 나오면 돈만 버린 셈이 된다. 후보에서 뺀다.
	var candidates: Array[Dictionary] = []
	for preset in RESIDENT_TRAIT_PRESETS:
		if str((preset as Dictionary).get("name", "")) != current_name:
			candidates.append(preset as Dictionary)
	if candidates.is_empty():
		return {"ok": false, "reason": "no_candidates"}
	catnip -= cost
	resident_reroll_counts[resident_id] = int(resident_reroll_counts.get(resident_id, 0)) + 1
	var picked := candidates[randi() % candidates.size()].duplicate(true)
	# 이름·초상화 같은 정체성은 유지하고 능력치만 바꾼다.
	var record := (resident_traits.get(resident_id, {}) as Dictionary).duplicate(true)
	for key in ["name", "kneading", "catnip", "appetite"]:
		record[key] = picked.get(key, record.get(key))
	resident_traits[resident_id] = record
	save_persistent_state()
	return {"ok": true, "cost": cost, "trait": record}


func is_milestone_unlocked(milestone_id: String) -> bool:
	return unlocked_milestones.has(milestone_id)


func _milestone_condition_met(definition: Dictionary) -> bool:
	var progression_id := str(definition.get("requires_progression", ""))
	if not progression_id.is_empty() and get_progression_item_count(progression_id) <= 0:
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


func get_total_worker_appetite() -> float:
	# 배치된 주민들의 식욕 합계. 인원수가 아니라 이 값이 통조림 소비를 정한다.
	var total := 0.0
	for worker_id in assigned_worker_ids:
		total += float(get_resident_trait(str(worker_id)).get("appetite", 1.0))
	for worker_id in assigned_catnip_worker_ids:
		total += float(get_resident_trait(str(worker_id)).get("appetite", 1.0))
	return maxf(0.0, total)


func get_shelter_runtime_seconds() -> float:
	# HUD의 "쉘터 잔여 가동" — 연료와 식량 중 먼저 바닥나는 쪽이 한계다.
	var scratcher_workers := get_active_scratcher_workers()
	var catnip_workers := get_active_catnip_workers()
	var worker_count := scratcher_workers + catnip_workers
	if worker_count <= 0:
		return 0.0
	var limits: Array[float] = []
	if canned_food > 0:
		var appetite := maxf(0.001, get_total_worker_appetite())
		limits.append(float(canned_food) * WORKER_HOURS_PER_CANNED_FOOD * 3600.0 / appetite)
	else:
		return 0.0
	if scratcher_workers > 0:
		limits.append(
			float(raw_scrap) * WORKER_SECONDS_PER_RAW_SCRAP / float(scratcher_workers)
		)
	if catnip_workers > 0:
		limits.append(
			float(raw_catnip) * WORKER_SECONDS_PER_RAW_CATNIP / float(catnip_workers)
		)
	if limits.is_empty():
		return 0.0
	var shortest: float = limits[0]
	for value in limits:
		shortest = minf(shortest, value)
	return maxf(0.0, shortest)


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


func get_raw_material_runtime_seconds() -> float:
	# "원자재 12개"는 아무 느낌도 주지 않는다. "쉘터 가동 3시간 12분"은 준다.
	# 정산 화면에서 가방을 시간으로 환산해 보여주기 위한 값이다.
	#
	# 주민이 아직 없어도 숫자가 0이 되면 안 된다. 그러면 첫 출정에서 원자재를
	# 주워 온 플레이어가 아무 보상도 못 느낀다. 주민 1명을 기준으로 환산한다.
	var scrap_workers := maxi(1, get_active_scratcher_workers())
	var catnip_workers := maxi(1, get_active_catnip_workers())
	var scrap_seconds := float(raw_scrap) * WORKER_SECONDS_PER_RAW_SCRAP / float(scrap_workers)
	var catnip_seconds := float(raw_catnip) * WORKER_SECONDS_PER_RAW_CATNIP / float(catnip_workers)
	return maxf(0.0, maxf(scrap_seconds, catnip_seconds))


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


func get_churu_buff_definition(buff_id: String) -> Dictionary:
	return (CHURU_BUFFS.get(buff_id, {}) as Dictionary).duplicate(true)


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


func get_shelter_stall_reason() -> String:
	if get_active_scratcher_workers() + get_active_catnip_workers() <= 0:
		return "no_workers"
	if canned_food <= 0:
		return "no_food"
	if get_active_scratcher_workers() > 0 and raw_scrap <= 0:
		return "no_raw_scrap"
	if get_active_catnip_workers() > 0 and raw_catnip <= 0:
		return "no_raw_catnip"
	return ""


func consume_offline_progress_notice() -> Dictionary:
	var notice := {
		"scrap": shelter_offline_scrap_pending,
		"catnip": shelter_offline_catnip_pending,
		"repair": shelter_offline_repair_pending,
	}
	shelter_offline_scrap_pending = 0
	shelter_offline_catnip_pending = 0
	shelter_offline_repair_pending = 0.0
	return notice


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
	scrap -= scrap_cost
	churu -= churu_cost
	shelter_tier = next_tier
	_sanitize_assigned_workers()
	save_persistent_state()
	return true


func get_workbench_slot_limit() -> int:
	if shelter_workbench_level >= 5:
		return 6
	if shelter_workbench_level >= 3:
		return 5
	return 4


func get_workbench_upgrade_cost() -> Dictionary:
	var next_level := shelter_workbench_level + 1
	if next_level > 5:
		return {}
	return {"scrap": int(WORKBENCH_UPGRADE_COSTS.get(next_level, 0))}


func can_mod_weapon(weapon_id: String) -> bool:
	if shelter_workbench_level >= 3:
		return true
	return ["m1911", "mp5"].has(weapon_id)


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
	if next_level > 5:
		return false
	var cost := int(SCRATCHER_UPGRADE_COSTS.get(next_level, 0))
	if scrap < cost:
		return false
	scrap -= cost
	scratcher_bank_level = next_level
	scratcher_multiplier = pow(2.2, float(scratcher_bank_level - 1))
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


# ── 비상 지급 ─────────────────────────────────────────────────
# 사망으로 무기를 전부 잃으면 맨손으로 나가야 하고, 맨손으로는 무기를
# 구하기 어렵다. 진행이 멈추는 구간이 생긴다.
# 사자가 창고 바닥을 긁어 권총 한 자루를 내어 준다. 공짜지만 최소한이다.
const EMERGENCY_WEAPON_ID := "m1911"
const EMERGENCY_AMMO_ID := "45_fmj"
const EMERGENCY_AMMO_COUNT := 24


func needs_emergency_weapon() -> bool:
	return not has_any_weapon()


func grant_emergency_weapon() -> Dictionary:
	if has_any_weapon():
		return {"ok": false, "reason": "already_armed"}
	add_weapon(EMERGENCY_WEAPON_ID, 1)
	set_ammo_count(EMERGENCY_AMMO_ID, get_ammo_count(EMERGENCY_AMMO_ID) + EMERGENCY_AMMO_COUNT)
	equipped_weapon_id = EMERGENCY_WEAPON_ID
	equipped_ammo_id = EMERGENCY_AMMO_ID
	has_ak = true
	weapon_durability = 100.0
	save_persistent_state()
	return {
		"ok": true,
		"weapon_id": EMERGENCY_WEAPON_ID,
		"ammo": EMERGENCY_AMMO_COUNT,
	}


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
	return maxi(900, roundi(900.0 * weapon_factor * pow(1.11, float(level))))


func try_enhance_weapon(weapon_id: String) -> bool:
	if get_weapon_count(weapon_id) <= 0:
		return false
	var level := get_weapon_enhancement_level(weapon_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
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


func get_mod_enhancement_level(mod_id: String) -> int:
	return clampi(int(mod_enhancement_levels.get(mod_id, 0)), 0, MAX_WEAPON_ENHANCEMENT)


func get_mod_enhancement_cost(mod_id: String) -> int:
	var level := get_mod_enhancement_level(mod_id)
	if level >= MAX_WEAPON_ENHANCEMENT:
		return 0
	return maxi(500, roundi(500.0 * pow(1.105, float(level))))


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


func get_artisan_roll_cost() -> Dictionary:
	var tier_index := maxi(0, shelter_tier - 1)
	return {
		"scrap": roundi(12000.0 * pow(3.2, float(tier_index))),
		"canned_food": 8 + tier_index * 4,
	}


func roll_artisan_weapon() -> Dictionary:
	var cost := get_artisan_roll_cost()
	if scrap < int(cost["scrap"]) or canned_food < int(cost["canned_food"]):
		return {}
	scrap -= int(cost["scrap"])
	canned_food -= int(cost["canned_food"])
	artisan_pity += 1
	var pool: Array[String] = ["m1911", "mp5"]
	if shelter_tier >= 2:
		pool.append("ak47")
	if shelter_tier >= 3:
		pool.append("double_barrel")
	var guaranteed := artisan_pity >= ARTISAN_PITY_LIMIT
	var result_id := pool[pool.size() - 1] if guaranteed else pool[randi() % pool.size()]
	if guaranteed:
		artisan_pity = 0
	add_weapon(result_id, 1)
	if not weapon_enhancement_levels.has(result_id):
		weapon_enhancement_levels[result_id] = 0
	var result := {
		"weapon_id": result_id,
		"guaranteed": guaranteed,
		"pity": artisan_pity,
	}
	save_persistent_state()
	return result


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
			equipment_bonus += float(get_equipment_definition(equipment_id).get("move_speed_bonus", 0.0))
	return progression_multiplier * (1.0 + equipment_bonus)


func get_stamina_cost_multiplier() -> float:
	var multiplier := 1.0
	for equipment_id in [equipped_body_armor_id, equipped_head_armor_id, equipped_footwear_id]:
		if not equipment_id.is_empty():
			multiplier *= float(get_equipment_definition(equipment_id).get("stamina_cost_multiplier", 1.0))
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
	return maxf(0.45, 1.0 - reduction)


func get_recoil_control_multiplier() -> float:
	var control := (
		float(training_levels.get("agility", 0)) * 0.035
		+ float(training_levels.get("fieldcraft", 0)) * 0.055
	)
	return maxf(0.62, 1.0 - control)


func get_training_definition(node_id: String) -> Dictionary:
	return (TRAINING_NODE_DEFS.get(node_id, {}) as Dictionary).duplicate(true)


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
	if canned_food < cost:
		return {"ok": false, "reason": "canned_food", "cost": cost}
	canned_food -= cost
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
	canned_food += maxi(0, int(reward.get("canned_food", 0)))
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
	_trim_stored_canned_food_to_total()
	_normalize_contract_state()
	_normalize_iron_mission_state()
	save_equipped_weapon_loadout()
	var data := {
		"version": 11,
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
		"catnip": catnip,
		"churu": churu,
		"raw_scrap": raw_scrap,
		"raw_catnip": raw_catnip,
		"valuable_inventory": valuable_inventory,
		"active_churu_buffs": active_churu_buffs,
		"bag_pressure_lesson_seen": bag_pressure_lesson_seen,
		"raw_material_lesson_seen": raw_material_lesson_seen,
		"fatigue_lesson_seen": fatigue_lesson_seen,
		"extraction_choice_lesson_seen": extraction_choice_lesson_seen,
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
		"equipment_inventory": equipment_inventory,
		"equipped_body_armor_id": equipped_body_armor_id,
		"equipped_head_armor_id": equipped_head_armor_id,
		"equipped_footwear_id": equipped_footwear_id,
		"weapon_enhancement_levels": weapon_enhancement_levels,
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
		"pre_raid_snapshot": pre_raid_snapshot,
		"shelter_last_progress_time": shelter_last_progress_time,
		"workbench_repair_active": workbench_repair_active,
		"workbench_repair_weapon_id": workbench_repair_weapon_id,
		"workbench_starter_parts_claimed": workbench_starter_parts_claimed,
		"shelter_scrap_fraction": shelter_scrap_fraction,
		"shelter_catnip_fraction": shelter_catnip_fraction,
		"shelter_food_fraction": shelter_food_fraction,
		"shelter_raw_scrap_fraction": shelter_raw_scrap_fraction,
		"shelter_raw_catnip_fraction": shelter_raw_catnip_fraction,
		"shelter_return_serial": shelter_return_serial,
		"merchant_last_roll_serial": merchant_last_roll_serial,
		"merchant_status": merchant_status,
		"merchant_decline_count": merchant_decline_count,
		"artisan_pity": artisan_pity,
		"selected_raid_zone": selected_raid_zone,
		"contract_chain_index": contract_chain_index,
		"contract_status": contract_status,
		"contract_progress": contract_progress,
		"completed_contract_ids": completed_contract_ids,
		"unlocked_contract_lore": unlocked_contract_lore,
		"shelter_facility_unlocks": shelter_facility_unlocks,
		"contract_agent_intro_seen": contract_agent_intro_seen,
		"saja_intro_seen": saja_intro_seen,
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
	var file := FileAccess.open(persistence_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_persistent_state() -> bool:
	if not persistence_enabled:
		return false
	if not FileAccess.file_exists(persistence_path):
		return false
	var file := FileAccess.open(persistence_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	var data := parsed as Dictionary
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
	catnip = maxi(0, roundi(float(data.get("catnip", catnip))))
	churu = int(data.get("churu", churu))
	raw_scrap = maxi(0, int(data.get("raw_scrap", raw_scrap)))
	raw_catnip = maxi(0, int(data.get("raw_catnip", raw_catnip)))
	valuable_inventory = (data.get("valuable_inventory", {}) as Dictionary).duplicate(true)
	active_churu_buffs = _to_string_array(data.get("active_churu_buffs", []))
	bag_pressure_lesson_seen = bool(data.get("bag_pressure_lesson_seen", bag_pressure_lesson_seen))
	raw_material_lesson_seen = bool(data.get("raw_material_lesson_seen", raw_material_lesson_seen))
	fatigue_lesson_seen = bool(data.get("fatigue_lesson_seen", fatigue_lesson_seen))
	extraction_choice_lesson_seen = bool(data.get("extraction_choice_lesson_seen", extraction_choice_lesson_seen))
	unlocked_milestones = _to_string_array(data.get("unlocked_milestones", []))
	resident_reroll_counts = (data.get("resident_reroll_counts", {}) as Dictionary).duplicate(true)
	if int(data.get("version", 0)) < 11:
		# 구버전 세이브는 원자재 개념이 없다. 기존 진행이 즉시 멈추지 않도록 초기 연료를 지급한다.
		raw_scrap = maxi(raw_scrap, 40)
		raw_catnip = maxi(raw_catnip, 20)
	fatigue = float(data.get("fatigue", fatigue))
	rescued_workers = int(data.get("rescued_workers", rescued_workers))
	resident_cat_ids = _to_string_array(data.get("resident_cat_ids", []))
	assigned_worker_ids = _to_string_array(data.get("assigned_worker_ids", []))
	assigned_catnip_worker_ids = _to_string_array(data.get("assigned_catnip_worker_ids", []))
	resident_traits = (data.get("resident_traits", {}) as Dictionary).duplicate(true)
	mod_component_inventory = (data.get("mod_component_inventory", mod_component_inventory) as Dictionary).duplicate(true)
	progression_item_inventory = (
		data.get("progression_item_inventory", progression_item_inventory) as Dictionary
	).duplicate(true)
	for progression_item_id in ["rifle_blueprint", "shotgun_blueprint", "sealed_zone_keycard"]:
		if not progression_item_inventory.has(progression_item_id):
			progression_item_inventory[progression_item_id] = 0
	weapon_mod_inventory = (data.get("weapon_mod_inventory", weapon_mod_inventory) as Dictionary).duplicate(true)
	for mod_id in WEAPON_SYSTEM.MODS.keys():
		if not weapon_mod_inventory.has(mod_id):
			weapon_mod_inventory[mod_id] = 0
	weapon_inventory = (data.get("weapon_inventory", weapon_inventory) as Dictionary).duplicate(true)
	equipment_inventory = (data.get("equipment_inventory", equipment_inventory) as Dictionary).duplicate(true)
	for equipment_id in EQUIPMENT_DEFINITIONS:
		if not equipment_inventory.has(equipment_id):
			equipment_inventory[equipment_id] = 0
	equipped_body_armor_id = str(data.get("equipped_body_armor_id", equipped_body_armor_id))
	equipped_head_armor_id = str(data.get("equipped_head_armor_id", equipped_head_armor_id))
	equipped_footwear_id = str(data.get("equipped_footwear_id", equipped_footwear_id))
	weapon_enhancement_levels = (data.get("weapon_enhancement_levels", weapon_enhancement_levels) as Dictionary).duplicate(true)
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
	shelter_workbench_level = clampi(int(data.get("shelter_workbench_level", shelter_workbench_level)), 1, 5)
	shelter_tier = clampi(int(data.get("shelter_tier", shelter_tier)), 1, 5)
	scratcher_bank_level = clampi(int(data.get("scratcher_bank_level", scratcher_bank_level)), 1, 5)
	scratcher_multiplier = float(data.get("scratcher_multiplier", scratcher_multiplier))
	catnip_scraper_level = clampi(int(data.get("catnip_scraper_level", catnip_scraper_level)), 1, 5)
	catnip_scraper_multiplier = float(data.get("catnip_scraper_multiplier", pow(1.8, float(catnip_scraper_level - 1))))
	storage_level = clampi(int(data.get("storage_level", storage_level)), 1, 5)
	storage_inventory = _to_dictionary_array(data.get("storage_inventory", []))
	_normalize_storage_inventory()
	if not bool(data.get("storage_food_in_total", false)):
		canned_food += get_stored_storage_count("food", "canned_food")
	_trim_stored_canned_food_to_total()
	catnip_boost_end_time = int(data.get("catnip_boost_end_time", catnip_boost_end_time))
	pre_raid_snapshot = data.get("pre_raid_snapshot", {}) as Dictionary
	shelter_last_progress_time = int(data.get("shelter_last_progress_time", shelter_last_progress_time))
	workbench_repair_active = bool(data.get("workbench_repair_active", workbench_repair_active))
	workbench_repair_weapon_id = str(data.get("workbench_repair_weapon_id", workbench_repair_weapon_id))
	workbench_starter_parts_claimed = bool(data.get("workbench_starter_parts_claimed", workbench_starter_parts_claimed))
	shelter_scrap_fraction = float(data.get("shelter_scrap_fraction", shelter_scrap_fraction))
	shelter_catnip_fraction = float(data.get("shelter_catnip_fraction", shelter_catnip_fraction))
	shelter_food_fraction = float(data.get("shelter_food_fraction", shelter_food_fraction))
	shelter_raw_scrap_fraction = float(data.get("shelter_raw_scrap_fraction", shelter_raw_scrap_fraction))
	shelter_raw_catnip_fraction = float(data.get("shelter_raw_catnip_fraction", shelter_raw_catnip_fraction))
	shelter_return_serial = int(data.get("shelter_return_serial", shelter_return_serial))
	merchant_last_roll_serial = int(data.get("merchant_last_roll_serial", merchant_last_roll_serial))
	merchant_status = str(data.get("merchant_status", merchant_status))
	merchant_decline_count = int(data.get("merchant_decline_count", merchant_decline_count))
	artisan_pity = clampi(int(data.get("artisan_pity", artisan_pity)), 0, ARTISAN_PITY_LIMIT - 1)
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
	return true


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
	player_health = 82
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
	}
	raid_serial = 0
	reset_raid_supply_counters()
	magazine_ammo = 30
	reserve_ammo = 90
	has_ak = true
	scrap = 80
	weapon_level = 1
	medkits = 0
	canned_food = 0
	catnip = 0
	churu = 0
	raw_scrap = 0
	raw_catnip = 0
	valuable_inventory.clear()
	active_churu_buffs.clear()
	bag_pressure_lesson_seen = false
	raw_material_lesson_seen = false
	fatigue_lesson_seen = false
	extraction_choice_lesson_seen = false
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
	}
	progression_item_inventory = {
		"rifle_blueprint": 0,
		"shotgun_blueprint": 0,
		"sealed_zone_keycard": 0,
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
	equipment_inventory = {
		"scav_vest": 0,
		"riot_vest": 0,
		"patched_helmet": 0,
		"tactical_helmet": 0,
		"patched_sneakers": 0,
		"tactical_boots": 0,
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
		"9mm_fmj": 60,
		"45_fmj": 28,
		"762_fmj": 90,
		"12g_buckshot": 12,
	}
	secure_dog_slots = 1
	secure_dog_items.clear()
	pending_corpse_recovery.clear()
	corpse_recovery_attempt_active = false
	confirmed_raid_manifest.clear()
	raid_special_cargo.clear()
	recovered_story_cargo_ids.clear()
	subway_story_stage = 0
	shelter_workbench_level = 1
	shelter_tier = 1
	scratcher_bank_level = 1
	scratcher_multiplier = 1.0
	catnip_scraper_level = 1
	catnip_scraper_multiplier = 1.0
	storage_level = 1
	storage_inventory.clear()
	catnip_boost_end_time = 0
	shelter_last_progress_time = 0
	workbench_repair_active = false
	workbench_repair_weapon_id = "ak47"
	shelter_offline_scrap_pending = 0
	shelter_offline_catnip_pending = 0
	shelter_offline_repair_pending = 0.0
	workbench_starter_parts_claimed = false
	shelter_scrap_fraction = 0.0
	shelter_catnip_fraction = 0.0
	shelter_food_fraction = 0.0
	shelter_raw_scrap_fraction = 0.0
	shelter_raw_catnip_fraction = 0.0
	workbench_starter_parts_claimed = false
	shelter_return_serial = 0
	merchant_last_roll_serial = -1
	merchant_status = "away"
	merchant_decline_count = 0
	weapon_enhancement_levels = {"ak47": 0}
	mod_enhancement_levels.clear()
	artisan_pity = 0
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
