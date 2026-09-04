class_name ShelterWorkbenchModule
extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const SHELTER_UI := preload("res://scripts/shelter_ui_components.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const SHELTER_REQUISITION := preload("res://scripts/shelter/requisition.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const AMMO_TEXTURE := preload("res://assets/items/ammo_762.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")

# 제작대는 "만드는 곳"이지 "재료를 찍어내는 곳"이 아니다. 원자재 3종(렌즈·패킹·
# 스프링)과 탄약은 필드에서만 나온다 — 고철만 있으면 무엇이든 나오던 시절엔
# 출정이 심부름이 되고, 도시를 뒤질 이유가 사라졌다(유저 요구).
# 통조림은 재료가 아니다 — 투척 소모품 겸 훈련 재화로 갈라지며 레시피에서 빠졌고,
# 그 몫은 고철(통조림 1 ≈ 70, 100 단위 반올림)로 접어 넣었다.
# ── 2026-08 경제 코어: 장비는 여기서만 생긴다 ──
# 무기 7종·방어구 9종 전부 레시피. 해금은 설계도 조각 3/3(gear_id 기준, GameState.
# is_blueprint_unlocked), 보유 중이면 "제작됨 · 영구 보유"로 재제작 불가(1개 영구).
# 비용은 존별 수입(T1 ~7K/h · T2 ~43K/h · T3 ~260K/h · T4 ~1.1M/h · T5 ~5M/h)에 맞춰
# "그 존 도달 후 1~3시간" 선: 고철 + 일반 부품, 존3부터 정밀 기어, 존4부터 군용 합금.
# 캣닢은 장비 레시피에서 뺐다(개조품에만) — 고철·부품이 어마어마하게 드는 인크리멘탈.
# ── 2026-08 대개편 2단계: 작업대 UI = '강화 보드' ──
# 장비는 만들고(평생 1회) → 평생 들고 → 끝없이 올리는 것이라, 주인공 탭은 제작이
# 아니라 강화다. 탭 2개(2026-08-29 재개편): 강화(보유 장비 보드 + 돌파) / 제작(16종
# 레시피 + 하단 '보급품' 섹션). 옛 '개조·보급' 탭은 폐지 — 개조(mods) 레시피는
# 데이터만 남기고 UI에서 뺐고(별도 재설계 예정, 이미 만든 부착물은 가방에서 계속
# 작동), 보급품(수리·확장)은 제작 탭 하단으로 합류했다(탄약·소모품 경로 유지).
# '장인'은 강화 보드의 [돌파] 버튼으로 흡수됐다. 비용·가능 판정·소비·부족 사유는
# 전부 1단계의 GameState 함수와 아래 _effective_cost/_can_craft/_craft가 담당한다 —
# 여기는 표시 계층. 강화·돌파는 고철 단독(GameState 개정 2026-08-29: part_cost {} ·
# 돌파 {"scrap": ×3})이라 우측 '재료 · 창고 합산' 패널도 함께 폐지됐다.

# 재화 표기 규칙(유저 확정): 아이콘이 이미 이름을 말하는 재화는 이름 라벨을 쓰지
# 않는다. 반대로 부품·재료(스코프 렌즈·정밀 기어…)는 아이콘만으로 못 알아보므로
# 이름을 유지한다 — 아이콘도 이름도 없으면 무슨 비용인지 알 길이 없어진다.
const ICON_ONLY_RESOURCES := ["scrap", "catnip", "canned_food", "churu"]

const RECIPES := {
	"armor": [
		{
			"id": "craft_scav_vest", "gear_id": "scav_vest",
			"name": "누더기 방탄 조끼",
			"desc": "철판을 덧대 꿰맨 생존자 계열 경량 조끼. 첫 방어구로 충분합니다.",
			"cost": {"scrap": 4300, "rubber_gasket": 2},
			"result": {"equipment": "scav_vest", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "craft_patched_sneakers", "gear_id": "patched_sneakers",
			"name": "기워 붙인 운동화",
			"desc": "밑창을 갈아 끼운 생존자 계열 신발. 발소리와 냄새를 줄입니다.",
			"cost": {"scrap": 5200, "rubber_gasket": 1, "magazine_spring": 1},
			"result": {"equipment": "patched_sneakers", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "craft_patched_helmet", "gear_id": "patched_helmet",
			"name": "기워 붙인 헬멧",
			"desc": "금 간 안전모를 철판으로 보강한 머리 보호구. 생존자 세트의 마지막 조각.",
			"cost": {"scrap": 6400, "magazine_spring": 1, "rubber_gasket": 1, "scope_lens": 1},
			"result": {"equipment": "patched_helmet", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "craft_riot_vest", "gear_id": "riot_vest",
			"name": "진압대 방탄 조끼",
			"desc": "진압 계열 중량 조끼. 튼튼한 대신 실루엣이 커집니다. 첫 제작 시 누더기 조끼 강화의 60%를 이어받습니다.",
			"cost": {"scrap": 60000, "rubber_gasket": 3, "magazine_spring": 2},
			"result": {"equipment": "riot_vest", "amount": 1},
			"required_tier": 2,
			"required_workbench": 2,
		},
		{
			"id": "craft_tactical_boots", "gear_id": "tactical_boots",
			"name": "경량 전술화",
			"desc": "발목을 잡아주면서도 유연한 밑창의 진압 계열 전술화. 첫 제작 시 운동화 강화의 60%를 이어받습니다.",
			"cost": {"scrap": 48000, "rubber_gasket": 2, "magazine_spring": 2, "scope_lens": 1},
			"result": {"equipment": "tactical_boots", "amount": 1},
			"required_tier": 2,
			"required_workbench": 2,
		},
		{
			"id": "craft_tactical_helmet", "gear_id": "tactical_helmet",
			"name": "전술 방탄 헬멧",
			"desc": "진압 계열 헬멧. 내피를 새로 짜 넣어야 해 작업대 숙련과 정밀 기어가 필요합니다.",
			"cost": {"scrap": 300000, "magazine_spring": 3, "rubber_gasket": 2, "scope_lens": 2, "precision_gear": 1},
			"result": {"equipment": "tactical_helmet", "amount": 1},
			"required_tier": 3,
			"required_workbench": 3,
		},
		{
			"id": "craft_military_vest", "gear_id": "military_vest",
			"name": "군납 방탄복",
			"desc": "봉쇄선 규격을 흉내 낸 최상급 방탄복. 군용 합금이 들어가야 판이 버팁니다.",
			"cost": {"scrap": 1600000, "rubber_gasket": 5, "magazine_spring": 4, "scope_lens": 3, "precision_gear": 2, "military_alloy": 1},
			"result": {"equipment": "military_vest", "amount": 1},
			"required_tier": 4,
			"required_workbench": 4,
		},
		{
			"id": "craft_military_helmet", "gear_id": "military_helmet",
			"name": "군납 전투 헬멧",
			"desc": "레일과 내피가 온전한 전투 헬멧. 군납 세트의 머리.",
			"cost": {"scrap": 1300000, "scope_lens": 4, "magazine_spring": 3, "rubber_gasket": 3, "precision_gear": 2, "military_alloy": 1},
			"result": {"equipment": "military_helmet", "amount": 1},
			"required_tier": 4,
			"required_workbench": 4,
		},
		{
			"id": "craft_assault_boots", "gear_id": "assault_boots",
			"name": "강습 부츠",
			"desc": "봉쇄선 강습조가 신던 부츠. 기동성이 탁월하지만 무거워 냄새 흔적이 짙습니다.",
			"cost": {"scrap": 1100000, "rubber_gasket": 4, "magazine_spring": 4, "scope_lens": 2, "precision_gear": 1, "military_alloy": 1},
			"result": {"equipment": "assault_boots", "amount": 1},
			"required_tier": 4,
			"required_workbench": 4,
		},
	],
	# [2026-08-29] 개조 기능 폐지 — 어떤 탭에도 안 나온다(데이터만 유지, 별도 재설계 예정).
	# 이미 만든 부착물은 가방에서 계속 작동한다(여기 소관 아님).
	"mods": [
		{
			"id": "scope_2x",
			"name": "폐점포 2x 스코프",
			"desc": "스코프 렌즈를 조립한 완성 조준경입니다.",
			"cost": {"scrap": 1800, "catnip": 600, "scope_lens": 1},
			"result": {"weapon_mod": "scope_2x", "amount": 1},
		},
		{
			"id": "muffled_sock",
			"name": "소리 방지용 양말",
			"desc": "고무 패킹으로 고정한 임시 소음기입니다.",
			"cost": {"scrap": 1500, "rubber_gasket": 1},
			"result": {"weapon_mod": "muffled_sock", "amount": 1},
		},
		{
			"id": "sponge_pad",
			"name": "스펀지 턱받이",
			"desc": "반동 회복을 돕는 완성 개머리판 패드입니다.",
			"cost": {"scrap": 2400, "rubber_gasket": 1},
			"result": {"weapon_mod": "sponge_pad", "amount": 1},
		},
		{
			"id": "quick_mag",
			"name": "테이프 듀얼 탄창",
			"desc": "탄창 스프링을 사용한 빠른 교체용 탄창입니다.",
			"cost": {"scrap": 3200, "catnip": 800, "magazine_spring": 1},
			"result": {"weapon_mod": "quick_mag", "amount": 1},
		},
		{
			"id": "bell_bait",
			"name": "딸랑이 방울",
			"desc": "적의 주의를 유도하는 전술 보조공구입니다.",
			"cost": {"scrap": 1200, "magazine_spring": 1},
			"result": {"weapon_mod": "bell_bait", "amount": 1},
		},
		{
			"id": "ak_precision_receiver",
			"name": "AK 정밀 단발 리시버",
			"desc": "AK의 발사 특성을 바꾸는 특수 전술 모듈입니다.",
			"cost": {"scrap": 25000, "scope_lens": 2},
			"result": {"weapon_mod": "ak_precision_receiver", "amount": 1},
			"required_workbench": 5,
		},
	],
	"weapons": [
		{
			"id": "m1911", "gear_id": "m1911",
			"name": "M1911 솜방망이",
			"desc": "초반 거지런과 최후의 보루용 권총.",
			"cost": {"scrap": 9000, "rubber_gasket": 1, "magazine_spring": 2},
			"result": {"weapon": "m1911", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "mp5", "gear_id": "mp5",
			"name": "MP5 하악이",
			"desc": "기동전과 좀비 소탕에 강한 기관단총.",
			"cost": {"scrap": 16000, "magazine_spring": 3, "scope_lens": 1, "rubber_gasket": 1},
			"result": {"weapon": "mp5", "amount": 1},
			"required_tier": 1,
		},
		{
			# 시작 무기 — 보유 시작이라 평소엔 "제작됨 · 영구 보유". 구세이브의 맨손 복구용.
			"id": "ak47", "gear_id": "ak47",
			"name": "AK-47 캣라시니코프",
			"desc": "시작 소총. 잃을 일은 없지만, 혹시 맨손이라면 여기서 다시 만든다.",
			"cost": {"scrap": 14000, "magazine_spring": 2, "rubber_gasket": 2},
			"result": {"weapon": "ak47", "amount": 1},
			"required_tier": 1,
		},
		{
			"id": "double_barrel", "gear_id": "double_barrel",
			"name": "더블배럴 참치 헌터",
			"desc": "장전 중 무방비가 되지만 초근접 저지력이 강한 산탄총.",
			"cost": {"scrap": 70000, "rubber_gasket": 3, "magazine_spring": 3},
			"result": {"weapon": "double_barrel", "amount": 1},
			"required_tier": 2,
		},
		# ── 무기 사다리 ──
		# 상위 기종을 처음 만들면 아래 단계 강화의 60%가 자동 이관된다.
		{
			"id": "pump_shotgun", "gear_id": "pump_shotgun",
			"name": "펌프 산탄총 하울러",
			"desc": "6발 튜브 탄창 산탄총. 두 발 쏘고 숨을 일이 없다. 첫 제작 시 참치 헌터 강화의 60%를 이어받습니다.",
			"cost": {"scrap": 90000, "rubber_gasket": 4, "magazine_spring": 3, "scope_lens": 1},
			"result": {"weapon": "pump_shotgun", "amount": 1},
			"required_tier": 2,
			"required_workbench": 2,
		},
		{
			"id": "akm", "gear_id": "akm",
			"name": "AKM 개조형",
			"desc": "AK를 손본 개조 소총. 40발 탄창, 더 묵직하고 덜 튄다. 첫 제작 시 AK-47 강화의 60%를 이어받습니다.",
			"cost": {"scrap": 480000, "scope_lens": 3, "magazine_spring": 4, "rubber_gasket": 2, "precision_gear": 2},
			"result": {"weapon": "akm", "amount": 1},
			"required_tier": 3,
			"required_workbench": 3,
		},
		{
			"id": "k2", "gear_id": "k2",
			"name": "K2 전투소총",
			"desc": "용산 봉쇄선의 군용 전투소총. 관통 2, 안정된 반동. 첫 제작 시 AKM(또는 AK) 강화의 60%를 이어받습니다.",
			"cost": {"scrap": 8000000, "scope_lens": 6, "magazine_spring": 6, "rubber_gasket": 4, "precision_gear": 4, "military_alloy": 3},
			"result": {"weapon": "k2", "amount": 1},
			"required_tier": 5,
			"required_workbench": 4,
		},
	],
	# ── 중장비(소모성 화력, 2026-08-29) — 부품의 소비처 ──
	# 만들고 → 들고 나가고 → 쓰면 부서진다. 설계도 조각 불필요(소모품이라 처음부터
	# 제작 가능). 이름·설명은 GameState.HEAVY_GEAR_DEFS가 단일 진실 —
	# _recipes_for_category가 desc를 거기서 채워 넣는다.
	"heavy": [
		{
			"id": "craft_field_mine",
			"name": "대인 지뢰 x3",
			"desc": "",
			"cost": {"scrap": 600, "magazine_spring": 1, "rubber_gasket": 1},
			"result": {"heavy_gear": "field_mine", "amount": 3},
		},
		{
			"id": "craft_salvage_turret",
			"name": "재생 감시포탑",
			"desc": "",
			"cost": {"scrap": 6000, "magazine_spring": 2, "rubber_gasket": 2, "scope_lens": 1, "precision_gear": 1},
			"result": {"heavy_gear": "salvage_turret", "amount": 1},
		},
		{
			"id": "craft_rocket_launcher",
			"name": "로켓 발사기 (3발)",
			"desc": "",
			"cost": {"scrap": 20000, "rubber_gasket": 2, "magazine_spring": 2, "military_alloy": 1},
			"result": {"heavy_gear": "rocket_launcher", "amount": 1},
		},
		# ── 2차(2026-08-29): 호위 드론 + 보급 카트 — 정밀 기어 사다리.
		{
			"id": "craft_escort_drone",
			"name": "호위 드론",
			"desc": "",
			"cost": {"scrap": 12000, "scope_lens": 2, "magazine_spring": 1, "precision_gear": 1},
			"result": {"heavy_gear": "escort_drone", "amount": 1},
		},
		{
			"id": "craft_supply_cart",
			"name": "보급 카트",
			"desc": "",
			"cost": {"scrap": 10000, "magazine_spring": 2, "rubber_gasket": 2, "precision_gear": 1},
			"result": {"heavy_gear": "supply_cart", "amount": 1},
		},
		# ── 3차(2026-08-30): 타격 드론 — 사다리 꼭대기의 '지우개'.
		{
			"id": "craft_strike_drone",
			"name": "타격 드론",
			"desc": "",
			"cost": {"scrap": 28000, "scope_lens": 2, "precision_gear": 2, "military_alloy": 1},
			"result": {"heavy_gear": "strike_drone", "amount": 1},
		},
	],
	"supplies": [
		{
			"id": "repair_kit",
			"name": "임시 총기 수리",
			"desc": "장착 총기의 내구도를 즉시 조금 회복합니다.",
			"cost": {"scrap": 1500, "rubber_gasket": 1},
			"result": {"repair": 18.0},
		},
		{
			"id": "auto_repair",
			"name": "자동 수리 맡기기",
			"desc": "장착 총기를 작업대에 맡겨 쉘터에 없는 동안에도 내구도를 자동 회복합니다.",
			"cost": {},
			"result": {"auto_repair": true},
		},
		{
			"id": "workbench_upgrade",
			"name": "작업대 시설 확장",
			"desc": "작업대 레벨을 높여 상위 총기와 특수 전술 모듈 제작을 해금합니다.",
			"cost": {},
			"result": {"workbench_upgrade": true},
		},
	],
	# 장인 = 돌파 서비스(옛 "장인 뽑기" 폐지). 행은 _recipes_for_category("artisan")가
	# 장착 장비에 대해 동적으로 만든다 — 탭은 없고, 강화 보드의 [돌파] 버튼이 쓴다.
	"artisan": [],
	# 장착 무기 강화 행(데이터 호환) — 보드는 보유 장비 전부를 _enhance_recipe_for로 다룬다.
	"enhance": [
		{
			"id": "enhance_equipped",
			"name": "장착 무기 영구 강화",
			"desc": "장착 중인 무기에 고철을 투자해 +99까지 피해와 안정성을 영구 강화합니다. +10·+20·…에서는 돌파가 필요합니다.",
			"cost": {},
			"result": {"enhance": true},
		},
	],
}

# ── 탭(2026-08-29 재개편): 강화 / 제작 둘뿐 ──
const TAB_ORDER := ["enhance", "craft"]
const TAB_NAMES := {"enhance": "강화", "craft": "제작"}
# 탭 하나가 RECIPES의 어떤 카테고리들을 합치는가.
# 제작 = 무기+방어구 16종 + 하단 '보급품'(수리·확장 — 소모품 제작 경로는 못 없앤다).
# "mods"는 어느 탭에도 없다 — 개조 기능 폐지(별도 재설계 예정), 데이터만 유지.
const TAB_CATEGORIES := {"craft": ["weapons", "armor", "heavy", "supplies"], "enhance": []}
# 제작 탭 서브탭(2026-08-30) — 한 목록에 16종+중장비+보급품을 다 늘어놓던 걸 나눴다.
const CRAFT_SUBCATEGORIES := ["weapons", "armor", "heavy", "supplies"]
const CRAFT_SUBCATEGORY_NAMES := {"weapons": "무기", "armor": "방어구", "heavy": "중장비", "supplies": "보급품"}
var craft_subcategory := "weapons"
# 옛 카테고리 이름으로 selected_category를 잡는 코드(테스트·프로브·구세이브)는 그대로
# 탭으로 접힌다 — 저장값이 "supply"/"mods"여도 크래시 없이 제작 탭으로 열린다.
const LEGACY_CATEGORY_TAB := {
	"armor": "craft", "weapons": "craft", "craft": "craft",
	"mods": "craft", "supplies": "craft", "supply": "craft", "heavy": "craft",
	"artisan": "enhance", "enhance": "enhance",
}
# 레시피 행 상태 색 — 초록=지금 만들 수 있음, 주황=재료만 모자람, 회색=아직 잠김.
const STATE_COLOR_READY := Color("#8fe0a6")
const STATE_COLOR_SHORT := Color("#e2a35e")
const STATE_COLOR_LOCKED := Color("#7e8a86")
# 보드 색 토큰(목업 그대로) — 무기 골드, 방어구 시안, 돌파 관문 붉은색.
const GOLD := Color("#d8bd72")
const GOLD_TEXT := Color("#ead69c")
const GOLD_BRIGHT := Color("#f0d77d")
const CYAN := Color("#7cc7d8")
const GREEN := Color("#7fc79e")
const DANGER := Color("#e06c5c")
const TEXT := Color("#e9f1ec")
const DIM := Color("#93a89d")
const FAINT := Color("#6d7f76")
const WELL := Color(0.063, 0.09, 0.086, 0.84)
const WELL_LINE := Color(0.133, 0.188, 0.169, 0.9)
# (재료 · 창고 합산 패널은 2026-08-29 폐지 — 강화·돌파가 고철 단독이 되면서
#  강화 보드에서 부품을 읽을 이유가 사라졌다. 부품은 제작 탭 비용 행이 보여 준다.)
# 길게 누르면 연타 — 0.42초 뒤부터 0.11초 간격(목업 수치).
const HOLD_REPEAT_DELAY := 0.42
const HOLD_REPEAT_INTERVAL := 0.11
const MAX_BATCH_ENHANCE := 200

@export var interaction_radius := 3.9

# 씬 없이 로직 노드로만 인스턴스될 수 있다 — 스프라이트는 없을 수 있다.
@onready var sprite: Sprite3D = get_node_or_null("WorkbenchSprite") as Sprite3D

var has_focus := false
var ui_layer: CanvasLayer
# 옛 이름 유지(테스트·프로브가 set으로 잡는다). 옛 카테고리 값은 _rebuild_ui가 탭으로 접는다.
var selected_category := "enhance"
var selected_recipe_id := "craft_scav_vest"
var recipe_list: VBoxContainer
var detail_box: VBoxContainer
# 제작 버튼은 상세 스크롤 밖 고정 바에 산다 — 스크롤 아래에 숨으면(세로 실측
# 168px 초과) 유저는 만들 방법이 없다고 읽는다.
var detail_action_bar: VBoxContainer
var resource_value_labels: Dictionary = {}
# 제작 직후 상세 패널에 잠깐 띄우는 성공 피드백(리빌드에서 살아남도록 상태로 보관).
var craft_feedback_text := ""
var craft_feedback_until_msec := 0

# ── 강화 보드 상태 ──
var modal_root: Control
var wallet_labels: Dictionary = {}
var tab_buttons: Dictionary = {}
var enhance_board: Control
var gear_list_box: BoxContainer
var enhance_card: PanelContainer
var enhance_card_body: VBoxContainer
var enhance_primary_button: Button
var enhance_max_button: Button
var toast_panel: PanelContainer
var toast_tween: Tween
# 선택 장비 — kind("weapon"/"armor") + 레시피 id(무기 id / 방어구 기본 id).
var enhance_selected_kind := ""
var enhance_selected_id := ""
# 주 버튼의 현재 역할: "enhance"(강화 +1) / "gate"(돌파) / "craft"(미제작 → 제작) / "none".
var primary_mode := "none"
var hold_timer: Timer
var hold_active := false
# [가능한 만큼] 반복 중엔 매 단계 리빌드를 막고 끝에 한 번만 그린다.
var batch_refresh_depth := 0


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("shelter_workbench")
	set_meta("module_kind", "workbench")
	if sprite != null:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.region_enabled = false
		sprite.no_depth_test = false
		sprite.render_priority = 12


func get_interaction_prompt() -> String:
	# 이름만으로는 무엇을 하는지 모른다. 기능을 한 줄로 말한다.
	return "작업대 · 장비 +99 강화 · 제작"


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.process_shelter_progress()
	GameState.claim_workbench_starter_parts()
	_open_ui()
	return "작업대 강화 보드를 열었습니다."


func set_interaction_focus(value: bool) -> void:
	has_focus = value
	if sprite:
		sprite.modulate = Color(1.15, 1.12, 0.9, 1.0) if has_focus else Color.WHITE


func _open_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "WorkbenchUILayer"
	# 다른 시설 모달(80~90)과 같은 대역 — HUD 액세서리 위에 확실히 얹힌다.
	ui_layer.layer = 84
	# 가방(inventory_ui)이 열릴 때 이 그룹을 보고 시설 모달을 닫는다.
	ui_layer.add_to_group("shelter_modal_ui")
	var ui_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	ui_parent.add_child(ui_layer)
	_rebuild_ui()


func _close_ui() -> void:
	_stop_enhance_hold()
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func _current_tab() -> String:
	return str(LEGACY_CATEGORY_TAB.get(selected_category, "enhance"))


func _rebuild_ui() -> void:
	if not is_instance_valid(ui_layer):
		return
	_stop_enhance_hold()
	for child in ui_layer.get_children():
		child.queue_free()
	# 옛 카테고리 값(armor/weapons/mods/...)은 탭으로 접는다 — 레시피 선택은 그대로 쓴다.
	selected_category = _current_tab()
	enhance_board = null
	gear_list_box = null
	enhance_card = null
	enhance_card_body = null
	enhance_primary_button = null
	enhance_max_button = null
	recipe_list = null
	detail_box = null
	detail_action_bar = null
	toast_panel = null
	wallet_labels.clear()
	tab_buttons.clear()

	# 모달 루트(Control) — 유리 배경(HudFx)이 dim 앞에 백버퍼를 끼우고 맨 위에 연출 레이어를 얹는다.
	modal_root = Control.new()
	modal_root.name = "WorkbenchModal"
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(modal_root)

	var dim := ColorRect.new()
	dim.name = "WorkbenchDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.008, 0.011, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(dim)
	ModalDismiss.install(ui_layer, dim, _close_ui)

	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UISafeArea.get_margins(viewport_size)
	var available_size := Vector2(
		viewport_size.x - safe.x - safe.z,
		viewport_size.y - safe.y - safe.w
	)
	var safe_center_offset := Vector2((safe.x - safe.z) * 0.5, (safe.y - safe.w) * 0.5)
	var compact := viewport_size.x < 900.0 or viewport_size.y < 650.0
	var stacked := viewport_size.x < 760.0
	# 폭·높이 모두 화면 기준 클램프 — 내용물의 최소 폭이 패널을 밀어 키우지 못하게
	# 모든 열은 ELLIPSIS 라벨 + 고정/EXPAND 폭만 쓴다(이전 세로 오버플로 사고 재발 금지).
	var panel_width := minf(1240.0, maxf(300.0, available_size.x - (20.0 if compact else 40.0)))
	var height_room := maxf(340.0, available_size.y - (16.0 if compact else 40.0))
	var panel_height := height_room if stacked else minf(780.0, height_room)
	var root := PanelContainer.new()
	root.name = "WorkbenchPanel"
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -panel_width * 0.5 + safe_center_offset.x
	root.offset_top = -panel_height * 0.5 + safe_center_offset.y
	root.offset_right = panel_width * 0.5 + safe_center_offset.x
	root.offset_bottom = panel_height * 0.5 + safe_center_offset.y
	root.clip_contents = true
	# 유리 위의 반투명 패널(목업 .mod) — 뒤 화면의 블러가 비친다.
	root.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.059, 0.059, 0.8), HudStyle.LINE_GOLD, 2, 10))
	modal_root.add_child(root)
	HudStyle.enter_modal(root)

	var inner_margin := 10 if compact else 16
	var margin := _margin(inner_margin, inner_margin, inner_margin, inner_margin)
	root.add_child(margin)
	var main := VBoxContainer.new()
	main.name = "WorkbenchContent"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8 if compact else 10)
	margin.add_child(main)

	main.add_child(_build_header(stacked))
	if selected_category == "enhance":
		_ensure_enhance_selection()
		main.add_child(_build_enhance_board(stacked, compact))
		_refresh_enhance_board()
	else:
		main.add_child(_build_resource_strip())
		var body: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
		body.name = "WorkbenchBody"
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 12 if compact else 16)
		main.add_child(body)
		body.add_child(_build_recipe_list())
		body.add_child(_build_detail_panel())
		_refresh_recipe_list()
		_refresh_detail_panel()

	# 토스트(모달 바닥 중앙) — 실패 사유·달성·이관 알림이 여기 뜬다.
	toast_panel = PanelContainer.new()
	toast_panel.name = "WorkbenchToast"
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 1.0
	toast_panel.anchor_bottom = 1.0
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.offset_bottom = -maxf(18.0, safe.w + 12.0)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	toast_panel.visible = false
	var toast_style := _panel_style(Color(0.035, 0.059, 0.059, 0.94), HudStyle.LINE_GOLD, 1, 999)
	toast_style.content_margin_left = 16
	toast_style.content_margin_right = 16
	toast_style.content_margin_top = 7
	toast_style.content_margin_bottom = 7
	toast_panel.add_theme_stylebox_override("panel", toast_style)
	var toast_label := _label("", 14, GOLD_TEXT)
	toast_label.name = "WorkbenchToastLabel"
	toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	HudFx.attach_text_glow(toast_label, GOLD, 0.7)
	modal_root.add_child(toast_panel)

	# 표면 연출 — 가방과 같은 유리 배경(블러·스캔라인·그레인·먼지) + 열릴 때 스캔 스윕.
	HudFx.install_glass_backdrop(modal_root, dim)
	HudFx.play_scan_sweep(dim)


# ── 헤더: 눈썹 라벨 · 제목 · 지갑 칩 · 탭 2개(강화/제작) · 닫기 ──────────


func _build_header(stacked: bool) -> Control:
	resource_value_labels.clear()
	var header := VBoxContainer.new()
	header.name = "WorkbenchHeader"
	header.add_theme_constant_override("separation", 8)
	var top_row := HBoxContainer.new()
	top_row.name = "WorkbenchHeaderRow"
	top_row.add_theme_constant_override("separation", 10)
	header.add_child(top_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.clip_contents = true
	title_box.add_theme_constant_override("separation", 2)
	top_row.add_child(title_box)
	var eyebrow := _label("%s · WORKBENCH %02d · SHELTER Lv.%d" % [GameState.player_name, GameState.shelter_workbench_level, GameState.shelter_tier], 10, FAINT)
	eyebrow.name = "WorkbenchEyebrow"
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	eyebrow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(eyebrow)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_box.add_child(title_row)
	var title := _label("작업대", 24, GOLD_TEXT)
	title.name = "WorkbenchTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 짧은 고정 문구 — ELLIPSIS면 최소 폭이 0이 돼 HBox에서 지갑 칩에 밀려 사라진다.
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title_row.add_child(title)
	HudFx.attach_text_glow(title, GOLD)
	HudFx.attach_title_aberration(title)
	title_row.add_child(_build_wallet())

	if not stacked:
		top_row.add_child(_build_tabs())
	var close := _close_button()
	close.pressed.connect(_close_ui)
	top_row.add_child(close)
	if stacked:
		header.add_child(_build_tabs())
	return header


func _build_wallet() -> Control:
	# 지갑 칩 — 강화·돌파가 고철 단독이 되면서(2026-08-29) 인장 칩은 뺐다.
	# 재화 표기 전역 규칙: 아이콘 + 숫자만, 이름은 툴팁.
	var wallet := HBoxContainer.new()
	wallet.name = "WorkbenchWallet"
	wallet.size_flags_vertical = Control.SIZE_SHRINK_END
	wallet.add_theme_constant_override("separation", 6)
	for key in ["scrap"]:
		var chip := PanelContainer.new()
		chip.name = "WorkbenchWalletChip_%s" % key
		chip.tooltip_text = _resource_name(key)
		var chip_style := _panel_style(WELL, HudStyle.LINE, 1, 999)
		chip_style.content_margin_left = 9
		chip_style.content_margin_right = 9
		chip_style.content_margin_top = 2
		chip_style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", chip_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(15, 15)
		icon.texture = _resource_icon(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var value_label := _label("", 12, GOLD)
		value_label.name = "WorkbenchWalletValue_%s" % key
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(value_label)
		HudFx.attach_text_glow(value_label, GOLD, 0.6)
		wallet_labels[key] = value_label
		wallet.add_child(chip)
	_refresh_wallet()
	return wallet


func _refresh_wallet() -> void:
	for key_value in wallet_labels.keys():
		var key := str(key_value)
		var label := wallet_labels[key] as Label
		if is_instance_valid(label):
			label.text = GameState.format_compact_number(_owned_resource(key))


func _build_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.name = "WorkbenchTabs"
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stacked := get_viewport().get_visible_rect().size.x < 760.0
	for tab_value in TAB_ORDER:
		var tab_id := str(tab_value)
		var tab := _button(_tab_text(tab_id), "")
		tab.name = "WorkbenchTab_%s" % tab_id
		tab.toggle_mode = true
		tab.button_pressed = selected_category == tab_id
		tab.custom_minimum_size = Vector2(0, 44)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_FILL
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.clip_text = true
		if not stacked:
			tab.custom_minimum_size.x = 96
		_style_tab(tab, tab.button_pressed)
		tab.pressed.connect(func() -> void:
			selected_category = tab_id
			# 보드의 마지막 결과 문구가 제작 탭 피드백 라벨로 새지 않게 비운다(보드는 토스트가 맡았다).
			craft_feedback_until_msec = 0
			var categories: Array = TAB_CATEGORIES.get(tab_id, [])
			if not categories.is_empty():
				var recipes: Array = _recipes_for_category(tab_id)
				var keep := false
				for recipe_raw in recipes:
					if str((recipe_raw as Dictionary).get("id", "")) == selected_recipe_id:
						keep = true
				if not keep and not recipes.is_empty():
					selected_recipe_id = str((recipes[0] as Dictionary).get("id", ""))
			_rebuild_ui()
		)
		tab_buttons[tab_id] = tab
		tabs.add_child(tab)
	return tabs


func _tab_text(tab_id: String) -> String:
	# 제작 탭은 "조각 3/3 + 재료 = 지금 만들 수 있는 수"를 숫자로 단다.
	if tab_id == "craft":
		var count := _craftable_gear_count()
		return "제작 %d" % count if count > 0 else "제작"
	return str(TAB_NAMES.get(tab_id, tab_id))


func _style_tab(tab: Button, lit: bool) -> void:
	if lit:
		var on := _panel_style(Color("#e2c97f"), GOLD_BRIGHT, 1, 7)
		on.content_margin_left = 12
		on.content_margin_right = 12
		on.content_margin_top = 7
		on.content_margin_bottom = 7
		for state in ["normal", "hover", "pressed"]:
			tab.add_theme_stylebox_override(state, on)
		tab.add_theme_color_override("font_color", Color("#0b100e"))
		tab.add_theme_color_override("font_hover_color", Color("#0b100e"))
		tab.add_theme_color_override("font_pressed_color", Color("#0b100e"))
		tab.add_theme_color_override("font_hover_pressed_color", Color("#0b100e"))
	else:
		tab.add_theme_color_override("font_color", DIM)


func _craftable_gear_count() -> int:
	var count := 0
	for category in ["weapons", "armor"]:
		for recipe_raw in RECIPES[category]:
			if _can_craft(recipe_raw as Dictionary):
				count += 1
	return count


func _refresh_tab_badges() -> void:
	var craft_tab := tab_buttons.get("craft") as Button
	if is_instance_valid(craft_tab):
		craft_tab.text = _tab_text("craft")


func _build_resource_strip() -> Control:
	# 제작·개조 탭의 재료 띠(아이콘 칩) — 레시피 비용을 읽는 맥락.
	var strip := HFlowContainer.new()
	strip.name = "WorkbenchResourceStrip"
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("h_separation", 7)
	strip.add_theme_constant_override("v_separation", 6)
	# 항상 아이콘+수치만(2026-08-30 유저: "재화 표시를 컴팩트하게"). 이름은 툴팁.
	var compact := true
	# 통조림은 제작 재료가 아니므로 자원 띠에서 뺐다(플레이어 소모품).
	# 캣닢도 뺐다(2026-08-29) — 캣닢 비용은 개조품 전용이었는데 개조 탭이 폐지됐다.
	for key in ["scrap", "scope_lens", "rubber_gasket", "magazine_spring", "precision_gear", "military_alloy"]:
		var resource_key := str(key)
		# 재화(고철·캣닢)는 아이콘이 곧 이름이라 수치만 남긴다. 부품·재료는
		# 아이콘만으로 무엇인지 알 수 없어 이름을 유지한다 — 다만 좁은 화면에서는
		# 이름이 수치를 잡아먹으므로 그때도 아이콘에 맡긴다.
		var chip := SHELTER_UI.make_resource_chip(
			resource_key,
			_resource_name(resource_key),
			GameState.format_compact_number(_owned_resource(resource_key)),
			_resource_icon(resource_key),
			_resource_accent(resource_key),
			compact,
			not compact and not ICON_ONLY_RESOURCES.has(resource_key)
		)
		_fit_chip_text(chip, resource_key)
		var value_label := chip.find_child("ResourceValue_%s" % resource_key, true, false) as Label
		if value_label != null:
			resource_value_labels[resource_key] = value_label
		strip.add_child(chip)
	return strip


# ── 토스트 ─────────────────────────────────────────────────────


func _toast(message: String, accent: Color = GOLD_TEXT) -> void:
	if not is_instance_valid(toast_panel) or message.is_empty():
		return
	var label := toast_panel.get_node_or_null("WorkbenchToastLabel") as Label
	if label == null:
		return
	label.text = message
	label.add_theme_color_override("font_color", accent)
	HudFx.set_text_glow_color(label, accent)
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	toast_tween = toast_panel.create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	toast_tween.tween_interval(1.9)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	toast_tween.tween_callback(func() -> void:
		if is_instance_valid(toast_panel):
			toast_panel.visible = false
	)
	SFX.play("toast_pop")


# ══════════════════════════════════════════════════════════════════
# 강화 보드(주인공 탭) — 좌 보유 장비 목록 / 우 강화 카드 + 고정 액션 바, 2열.
# (우측 '재료 · 창고 합산' 열은 고철 단독 개편으로 폐지 — 카드가 그만큼 넓어졌다.)
# 세로(stacked)는 목록이 상단 가로 칩 스크롤로 접힌다.
# ══════════════════════════════════════════════════════════════════


func _build_enhance_board(stacked: bool, compact: bool) -> Control:
	var board: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	board.name = "WorkbenchEnhanceBoard"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 8)
	enhance_board = board

	# ── 좌: 보유 장비 · 평생 귀속 ──
	var list_panel := PanelContainer.new()
	list_panel.name = "WorkbenchGearListPanel"
	list_panel.clip_contents = true
	list_panel.add_theme_stylebox_override("panel", _board_module_style())
	if stacked:
		list_panel.custom_minimum_size = Vector2(0, 96)
		list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		list_panel.custom_minimum_size = Vector2(210 if compact else 240, 0)
		list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_child(list_panel)
	var list_margin := _margin(8, 8, 8, 8)
	list_panel.add_child(list_margin)
	var list_column := VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_theme_constant_override("separation", 4)
	list_margin.add_child(list_column)
	if not stacked:
		var list_title := _label("보유 장비 · 평생 귀속", 11, DIM)
		list_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		list_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list_column.add_child(list_title)
	var list_scroll := HudStyle.make_scroll()
	list_scroll.name = "WorkbenchGearListScroll"
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if stacked:
		list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(list_scroll)
	gear_list_box = HBoxContainer.new() if stacked else VBoxContainer.new()
	gear_list_box.name = "WorkbenchGearList"
	gear_list_box.add_theme_constant_override("separation", 6 if stacked else 5)
	if stacked:
		gear_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		gear_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(gear_list_box)

	# ── 우: 강화 카드(스크롤) + 하단 고정 액션 바 ──
	var stage := PanelContainer.new()
	stage.name = "WorkbenchEnhanceCard"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.add_theme_stylebox_override("panel", _board_module_style())
	board.add_child(stage)
	enhance_card = stage
	var stage_margin := _margin(12 if compact else 14, 10, 12 if compact else 14, 10)
	stage.add_child(stage_margin)
	var stage_column := VBoxContainer.new()
	stage_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_column.add_theme_constant_override("separation", 8)
	stage_margin.add_child(stage_column)
	var card_scroll := HudStyle.make_scroll()
	card_scroll.name = "WorkbenchEnhanceScroll"
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_column.add_child(card_scroll)
	enhance_card_body = VBoxContainer.new()
	enhance_card_body.name = "WorkbenchEnhanceCardBody"
	enhance_card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enhance_card_body.add_theme_constant_override("separation", 8)
	card_scroll.add_child(enhance_card_body)
	# 액션 바 — 스크롤 밖 고정. [강화 +1 | 가능한 만큼] (1.6 : 1).
	var actions := HBoxContainer.new()
	actions.name = "WorkbenchEnhanceActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	actions.add_theme_constant_override("separation", 6)
	stage_column.add_child(actions)
	enhance_primary_button = _button("강화 +1", "")
	enhance_primary_button.name = "WorkbenchEnhanceButton"
	enhance_primary_button.custom_minimum_size = Vector2(0, 52)
	enhance_primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enhance_primary_button.size_flags_stretch_ratio = 1.6
	enhance_primary_button.clip_contents = true
	enhance_primary_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	enhance_primary_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enhance_primary_button.button_down.connect(_on_primary_button_down)
	enhance_primary_button.button_up.connect(_on_primary_button_up)
	enhance_primary_button.pressed.connect(_on_primary_pressed)
	enhance_primary_button.mouse_exited.connect(_stop_enhance_hold)
	actions.add_child(enhance_primary_button)
	enhance_max_button = _button("가능한 만큼", "")
	enhance_max_button.name = "WorkbenchEnhanceMaxButton"
	enhance_max_button.custom_minimum_size = Vector2(0, 52)
	enhance_max_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enhance_max_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	enhance_max_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enhance_max_button.pressed.connect(_enhance_as_much_as_possible)
	actions.add_child(enhance_max_button)
	return board


func _board_module_style() -> StyleBoxFlat:
	var style := _panel_style(Color(0.035, 0.059, 0.059, 0.76), Color(0.247, 0.341, 0.298, 0.7), 1, 8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _well_style(border: Color = WELL_LINE) -> StyleBoxFlat:
	var style := _panel_style(WELL, border, 1, 6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


# ── 보유 장비 목록 ─────────────────────────────────────────────


func _gear_entries() -> Array[Dictionary]:
	# 무기 → 방어구, 각각 보유(강화 가능)를 앞에, 미제작(조각 n/3 잠김)을 뒤에.
	var owned: Array[Dictionary] = []
	var locked: Array[Dictionary] = []
	for category in ["weapons", "armor"]:
		var kind := "weapon" if category == "weapons" else "armor"
		for recipe_raw in RECIPES[category]:
			var recipe: Dictionary = recipe_raw
			var gear_id := str(recipe.get("gear_id", ""))
			if gear_id.is_empty():
				continue
			var entry := {
				"id": gear_id,
				"kind": kind,
				"recipe": recipe,
				"owned": bool(GameState.is_gear_owned(gear_id)),
				"level": int(GameState.get_gear_enhancement_level(kind, gear_id)),
				"shards": mini(int(GameState.get_blueprint_shard_count(gear_id)), GameState.BLUEPRINT_SHARDS_REQUIRED),
				"name": _gear_display_name(kind, gear_id),
				"sub": _gear_kind_text(kind, gear_id),
			}
			if bool(entry["owned"]):
				owned.append(entry)
			else:
				locked.append(entry)
	# 강화 보드에는 보유 장비만(2026-08-30 유저: "작업대에서는 내가 보유한
	# 장비들만 나와야지"). 미제작 장비는 제작 탭이 맡는다.
	var result: Array[Dictionary] = []
	result.append_array(owned)
	return result


func _find_gear_entry(kind: String, gear_id: String) -> Dictionary:
	for entry in _gear_entries():
		if str(entry["kind"]) == kind and str(entry["id"]) == gear_id:
			return entry
	return {}


func _ensure_enhance_selection() -> void:
	# 기본 선택: 장착 무기(보유) → 첫 보유 장비 → 첫 항목.
	if not enhance_selected_id.is_empty() and not _find_gear_entry(enhance_selected_kind, enhance_selected_id).is_empty():
		return
	var entries := _gear_entries()
	var equipped := str(GameState.equipped_weapon_id)
	for entry in entries:
		if str(entry["kind"]) == "weapon" and str(entry["id"]) == equipped and bool(entry["owned"]):
			enhance_selected_kind = "weapon"
			enhance_selected_id = equipped
			return
	for entry in entries:
		if bool(entry["owned"]):
			enhance_selected_kind = str(entry["kind"])
			enhance_selected_id = str(entry["id"])
			return
	if not entries.is_empty():
		enhance_selected_kind = str(entries[0]["kind"])
		enhance_selected_id = str(entries[0]["id"])


func select_gear(kind: String, gear_id: String) -> void:
	# 프로브·튜토리얼이 선택을 바꿀 때 쓰는 진입점.
	enhance_selected_kind = kind
	enhance_selected_id = gear_id
	if selected_category != "enhance":
		selected_category = "enhance"
		_rebuild_ui()
	else:
		_refresh_enhance_board()


func _gear_display_name(kind: String, gear_id: String) -> String:
	return _resource_name(gear_id) if kind == "weapon" else _equipment_display_name(gear_id)


func _gear_short_name(kind: String, gear_id: String) -> String:
	# 토스트·힌트용 짧은 이름 — 'AK-47 "캣라시니코프"' → 'AK-47'.
	if kind == "weapon":
		var display_name := str(WeaponSystem.get_weapon(gear_id).get("display_name", gear_id))
		return display_name.split("\"")[0].strip_edges()
	return _equipment_display_name(gear_id)


func _gear_kind_text(kind: String, gear_id: String) -> String:
	if kind == "weapon":
		var weapon := WeaponSystem.get_weapon(gear_id)
		var caliber := str(weapon.get("ammo_type", ""))
		var caliber_text := str({"762x39": "7.62", "9mm": "9mm", "45_acp": ".45", "12g": "12g"}.get(caliber, caliber))
		return "%s · %s" % [str(weapon.get("category", "무기")), caliber_text]
	var definition := GameState.get_equipment_definition(gear_id)
	var slot_text := str({"body": "몸", "head": "머리", "feet": "발"}.get(str(definition.get("slot", "")), "장비"))
	return "%s · T%d" % [slot_text, int(GameState.get_armor_family_index(gear_id)) + 1]


func _gear_icon(kind: String, gear_id: String) -> Texture2D:
	if kind == "weapon":
		var weapon_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(gear_id)
		return weapon_texture if weapon_texture != null else UI_ICONS.get_icon("weapon", 72, GOLD)
	var armor_texture := _equipment_texture(gear_id)
	return armor_texture if armor_texture != null else UI_ICONS.get_icon("armor", 72, CYAN)


func _refresh_gear_list() -> void:
	if not is_instance_valid(gear_list_box):
		return
	_clear(gear_list_box)
	var stacked := gear_list_box is HBoxContainer
	for entry in _gear_entries():
		var kind := str(entry["kind"])
		var gear_id := str(entry["id"])
		var owned := bool(entry["owned"])
		var selected := kind == enhance_selected_kind and gear_id == enhance_selected_id
		var accent := GOLD if kind == "weapon" else CYAN
		var row := Button.new()
		row.name = "WorkbenchGearRow_%s" % gear_id
		row.toggle_mode = true
		row.button_pressed = selected
		row.focus_mode = Control.FOCUS_NONE
		row.clip_contents = true
		row.custom_minimum_size = Vector2(150 if stacked else 0, 50)
		if not stacked:
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style := _well_style(GOLD_BRIGHT if selected else WELL_LINE)
		row.add_theme_stylebox_override("normal", row_style)
		row.add_theme_stylebox_override("pressed", row_style)
		var row_hover := _well_style(HudStyle.LINE_FOCUS)
		row.add_theme_stylebox_override("hover", row_hover)
		row.add_theme_stylebox_override("hover_pressed", row_style)
		row.pressed.connect(func() -> void:
			enhance_selected_kind = kind
			enhance_selected_id = gear_id
			SFX.play("ui_tap")
			_refresh_enhance_board()
		)
		# 버튼 위 내용 — 입력은 버튼이 받는다(자식은 IGNORE).
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 7
		content.offset_right = -7
		content.offset_top = 4
		content.offset_bottom = -4
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 7)
		row.add_child(content)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.texture = _gear_icon(kind, gear_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.55)
		content.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_box.add_theme_constant_override("separation", 0)
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(text_box)
		var name_label := _label(str(entry["name"]), 12, TEXT if owned else FAINT)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(name_label)
		var sub_label := _label(str(entry["sub"]), 10, FAINT)
		sub_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(sub_label)
		var level_label := _label(
			"+%d" % int(entry["level"]) if owned else "조각 %d/%d" % [int(entry["shards"]), GameState.BLUEPRINT_SHARDS_REQUIRED],
			16 if owned else 10,
			accent if owned else FAINT
		)
		level_label.name = "GearLevel"
		level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(level_label)
		if owned:
			HudFx.attach_text_glow(level_label, accent, 0.8)
		gear_list_box.add_child(row)
		if selected:
			HudFx.attach_rim_pulse(row, GOLD_BRIGHT, 6.0)


# ── 강화 카드 ──────────────────────────────────────────────────


func _enhance_recipe_for(kind: String, gear_id: String) -> Dictionary:
	# 보드가 쓰는 합성 레시피 — 비용·판정·소비·사유는 _effective_cost/_can_craft/_craft가 맡는다.
	if kind == "armor":
		return {
			"id": "enhance_armor_%s" % gear_id,
			"name": "%s 영구 강화" % _equipment_display_name(gear_id),
			"cost": {},
			"result": {"enhance_armor": gear_id},
		}
	return {
		"id": "enhance_weapon_%s" % gear_id,
		"name": "%s 영구 강화" % _resource_name(gear_id),
		"cost": {},
		"result": {"enhance": true, "weapon_id": gear_id},
	}


func _refresh_enhance_board() -> void:
	if not is_instance_valid(enhance_board):
		return
	_ensure_enhance_selection()
	_refresh_wallet()
	_refresh_gear_list()
	_refresh_enhance_card()
	_refresh_enhance_actions()
	_refresh_tab_badges()


func _refresh_enhance_card() -> void:
	if not is_instance_valid(enhance_card_body):
		return
	for child in enhance_card_body.get_children():
		enhance_card_body.remove_child(child)
		child.queue_free()
	var entry := _find_gear_entry(enhance_selected_kind, enhance_selected_id)
	var insert_at := 0
	if entry.is_empty():
		var empty := _label("보유한 장비가 없습니다 — 제작 탭에서 첫 장비를 만드세요.", 14, DIM)
		empty.name = "WorkbenchEnhanceEmpty"
		enhance_card_body.add_child(empty)
		enhance_card_body.move_child(empty, 0)
		return
	var blocks: Array[Control] = []
	if bool(entry["owned"]):
		blocks = _build_owned_card_blocks(entry)
	else:
		blocks = _build_locked_card_blocks(entry)
	for block in blocks:
		enhance_card_body.add_child(block)
		enhance_card_body.move_child(block, insert_at)
		insert_at += 1


func _build_stage_head(entry: Dictionary, big_caption: String, big_text: String, kind_suffix: String) -> Control:
	var kind := str(entry["kind"])
	var accent := GOLD if kind == "weapon" else CYAN
	var head := HBoxContainer.new()
	head.name = "WorkbenchEnhanceHead"
	head.add_theme_constant_override("separation", 10)
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_stylebox_override("panel", _well_style(HudStyle.LINE_GOLD if kind == "weapon" else Color(CYAN, 0.6)))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture = _gear_icon(kind, str(entry["id"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(icon)
	head.add_child(icon_box)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 1)
	head.add_child(text_box)
	var name_label := _label(str(entry["name"]), 17, GOLD_TEXT if kind == "weapon" else Color("#cfeef5"))
	name_label.name = "WorkbenchEnhanceName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	HudFx.attach_text_glow(name_label, accent, 0.8)
	var kind_label := _label("%s · %s" % [str(entry["sub"]), kind_suffix], 10, FAINT)
	kind_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	kind_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(kind_label)
	var big_box := VBoxContainer.new()
	big_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big_box.add_theme_constant_override("separation", 0)
	head.add_child(big_box)
	var caption := _label(big_caption, 9, FAINT)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	big_box.add_child(caption)
	var big := _label(big_text, 28, accent)
	big.name = "WorkbenchEnhanceBigLevel"
	big.autowrap_mode = TextServer.AUTOWRAP_OFF
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	big_box.add_child(big)
	HudFx.attach_text_glow(big, accent)
	return head


func _build_owned_card_blocks(entry: Dictionary) -> Array[Control]:
	var kind := str(entry["kind"])
	var gear_id := str(entry["id"])
	var level := int(entry["level"])
	var blocks: Array[Control] = []
	blocks.append(_build_stage_head(entry, "ENHANCE", "+%d" % level, "평생 귀속"))
	blocks.append(_build_breakthrough_track(kind, gear_id, level))
	blocks.append(_build_stat_grid(kind, gear_id, level))
	blocks.append(_build_perk_row(kind, gear_id, level))
	if kind == "weapon":
		blocks.append(_build_tuning_block(gear_id))
	blocks.append(_build_enhance_cost_row(kind, gear_id, level))
	return blocks


const TUNING_COMPONENT_TEXTURES := {
	"magazine_spring": MAGAZINE_SPRING_TEXTURE,
	"rubber_gasket": RUBBER_GASKET_TEXTURE,
	"scope_lens": SCOPE_LENS_TEXTURE,
}


func _build_tuning_block(gear_id: String) -> Control:
	# 부품 튜닝(인크리멘탈 개조, 2026-08-30 A안) — 부품을 먹여 무기별 게이지를
	# 올린다. 고철 연타 강화와 같은 쾌감 축: 주운 부품 = "한 번 더 누를 수 있다".
	var block := VBoxContainer.new()
	block.name = "WorkbenchTuningBlock"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	var title := _label("부품 튜닝 · 먹인 만큼 이 무기가 영구히 좋아진다", 11, DIM)
	title.name = "WorkbenchTuningTitle"
	block.add_child(title)
	for component_id in ["magazine_spring", "rubber_gasket", "scope_lens"]:
		block.add_child(_build_tuning_row(gear_id, str(component_id)))
	return block


func _build_tuning_row(gear_id: String, component_id: String) -> Control:
	var track := (GameState.WEAPON_TUNING_TRACKS as Dictionary).get(component_id, {}) as Dictionary
	var fed := GameState.get_weapon_tuning_count(gear_id, component_id)
	var bonus := GameState.get_weapon_tuning_bonus(gear_id, component_id)
	var have := GameState.get_mod_component_count(component_id)
	var row := PanelContainer.new()
	row.name = "WorkbenchTuningRow_%s" % component_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _well_style())
	var margin := _margin(8, 4, 8, 4)
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	margin.add_child(line)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.texture = TUNING_COMPONENT_TEXTURES.get(component_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 0)
	line.add_child(text_box)
	var name_label := _label(
		"%s — %s" % [str(track.get("name", "")), str(track.get("effect", ""))], 11, GOLD_TEXT
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	var value_label := _label(
		"+%.1f%% · 먹임 %d · 보유 %d" % [bonus * 100.0, fed, have], 10, GREEN if bonus > 0.0 else DIM
	)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(value_label)
	var feed_one := _button("+1", "")
	feed_one.name = "WorkbenchTuningFeed1_%s" % component_id
	feed_one.custom_minimum_size = Vector2(52, 40)
	feed_one.disabled = have <= 0
	feed_one.pressed.connect(_feed_tuning.bind(gear_id, component_id, 1))
	line.add_child(feed_one)
	var feed_ten := _button("+10", "")
	feed_ten.name = "WorkbenchTuningFeed10_%s" % component_id
	feed_ten.custom_minimum_size = Vector2(58, 40)
	feed_ten.disabled = have <= 0
	feed_ten.pressed.connect(_feed_tuning.bind(gear_id, component_id, 10))
	line.add_child(feed_ten)
	return row


func _feed_tuning(gear_id: String, component_id: String, amount: int) -> void:
	var result: Dictionary = GameState.try_feed_weapon_tuning(gear_id, component_id, amount)
	if bool(result.get("ok", false)):
		_refresh_enhance_card()


func _build_perk_row(kind: String, gear_id: String, level: int) -> Control:
	# 돌파 정체성 보너스(3단계) — 이미 얻은 보너스는 초록 칩, 다음 관문 보너스는 한 줄 예고.
	var row := HFlowContainer.new()
	row.name = "WorkbenchPerkRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	var table: Dictionary = (GameState.BREAKTHROUGH_PERKS as Dictionary).get(kind, {})
	var earned: Array[String] = GameState.get_breakthrough_perks(kind, gear_id)
	for perk_level in GameState.BREAKTHROUGH_PERK_LEVELS:
		var perk: Dictionary = table.get(int(perk_level), {})
		if perk.is_empty() or not earned.has(str(perk.get("id", ""))):
			continue
		var chip := PanelContainer.new()
		chip.name = "PerkChip_%s" % str(perk.get("id", ""))
		chip.tooltip_text = str(perk.get("description", ""))
		var chip_style := _panel_style(Color(0.09, 0.16, 0.13, 0.9), Color(GREEN, 0.7), 1, 999)
		chip_style.content_margin_left = 8
		chip_style.content_margin_right = 8
		chip_style.content_margin_top = 1
		chip_style.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", chip_style)
		var chip_label := _label("+%d %s" % [int(perk_level), str(perk.get("label", ""))], 10, GREEN)
		chip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(chip_label)
		row.add_child(chip)
	var next_perk_level := _next_perk_level(level)
	var next_text := str(GameState.describe_breakthrough_perk(kind, next_perk_level)) if next_perk_level > 0 else ""
	var next_label := _label(("다음 보너스 · %s" % next_text) if not next_text.is_empty() else "돌파 보너스 전부 획득", 10, DANGER if not next_text.is_empty() else FAINT)
	next_label.name = "WorkbenchNextPerk"
	next_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(next_label)
	return row


func _build_breakthrough_track(kind: String, gear_id: String, level: int) -> Control:
	# 10칸 = 이번 10단계(+1~+10). 완료 초록 · 현재 금색 펄스 · 10번째 칸 우측 붉은 관문.
	# 돌파 대기(+10·+20…·미돌파)면 10칸 전부 완료 + 관문이 붉게 깜빡인다.
	var gate_required := bool(GameState.is_breakthrough_required(kind, gear_id))
	var step := GameState.BREAKTHROUGH_STEP
	var decade_base := (level - step) if gate_required else (level / step) * step
	var done := step if gate_required else level % step
	var current := -1 if gate_required else level % step
	var box := VBoxContainer.new()
	box.name = "WorkbenchBreakthroughTrack"
	box.add_theme_constant_override("separation", 3)
	var track := HBoxContainer.new()
	track.name = "TrackCells"
	track.add_theme_constant_override("separation", 3)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(track)
	for index in step:
		var cell := Panel.new()
		cell.name = "TrackCell_%d" % index
		cell.custom_minimum_size = Vector2(0, 8)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		if index < done:
			style.bg_color = Color("#8fd08f")
			style.border_color = Color("#aeea78")
			style.set_border_width_all(0)
			cell.set_meta("state", "done")
		elif index == current:
			style.bg_color = GOLD_BRIGHT
			style.set_border_width_all(0)
			cell.set_meta("state", "cur")
			var pulse := cell.create_tween().set_loops()
			pulse.tween_property(cell, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(cell, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
		else:
			style.bg_color = Color("#13201c")
			style.border_color = Color("#223a30")
			style.set_border_width_all(1)
			cell.set_meta("state", "todo")
		cell.add_theme_stylebox_override("panel", style)
		track.add_child(cell)
		if index == step - 1:
			# 붉은 관문 표시 — "여기서 장인·인장이 든다"를 누르기 전에 말한다.
			var gate := ColorRect.new()
			gate.name = "TrackGate"
			gate.color = DANGER
			gate.anchor_left = 1.0
			gate.anchor_right = 1.0
			gate.anchor_top = 0.0
			gate.anchor_bottom = 1.0
			gate.offset_left = -2
			gate.offset_right = 4
			gate.offset_top = -4
			gate.offset_bottom = 4
			gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(gate)
			# 위험 신호 문법 — 드물게 붉은 점멸(돌파 대기 중엔 또렷하게).
			var blink := gate.create_tween().set_loops()
			blink.tween_interval(0.9 if gate_required else 3.4)
			blink.tween_property(gate, "modulate", Color(1.8, 1.4, 1.4, 1.0), 0.12)
			blink.tween_property(gate, "modulate", Color.WHITE, 0.22)
	var labels := HBoxContainer.new()
	labels.name = "TrackLabels"
	var left := _label("+%d" % decade_base, 10, FAINT)
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(left)
	var right := _label("돌파 +%d" % (decade_base + step), 10, DANGER)
	right.name = "TrackGateLabel"
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels.add_child(right)
	box.add_child(labels)
	return box


func _stat_cells(kind: String, gear_id: String, level: int) -> Array:
	# [라벨, 현재값, 다음값("" = 화살표 없음)] 4칸.
	var cells: Array = []
	if kind == "weapon":
		var no_mods: Array[String] = []
		var now: Dictionary = WeaponSystem.build_stats(gear_id, no_mods, level)
		var next: Dictionary = WeaponSystem.build_stats(gear_id, no_mods, mini(level + 1, GameState.MAX_WEAPON_ENHANCEMENT))
		var pellets := maxi(1, int(now.get("pellet_count", 1)))
		var damage_now := "%d×%d" % [roundi(float(now.get("damage", 0))), pellets] if pellets > 1 else str(roundi(float(now.get("damage", 0))))
		var damage_next := str(roundi(float(next.get("damage", 0))))
		cells.append(["피해", damage_now, "▲%s" % damage_next if level < GameState.MAX_WEAPON_ENHANCEMENT else ""])
		cells.append(["연사", "%d" % roundi(60.0 / maxf(0.01, float(now.get("fire_interval", 0.2)))), ""])
		cells.append(["장탄", str(int(now.get("magazine_size", 0))), ""])
		cells.append(["장전", "%.2fs" % float(now.get("reload_time", 0.0)), ""])
		return cells
	var definition := GameState.get_equipment_definition(gear_id)
	var multiplier_now := float(GameState.armor_enhancement_multiplier_for_level(level))
	var multiplier_next := float(GameState.armor_enhancement_multiplier_for_level(mini(level + 1, GameState.MAX_ARMOR_ENHANCEMENT)))
	var can_grow := level < GameState.MAX_ARMOR_ENHANCEMENT
	if definition.has("damage_reduction"):
		var base := float(definition["damage_reduction"])
		cells.append(["피해 감소", "%d%%" % roundi(base * multiplier_now * 100.0), "▲%d%%" % roundi(base * multiplier_next * 100.0) if can_grow else ""])
	elif definition.has("move_speed_bonus"):
		var base := float(definition["move_speed_bonus"])
		cells.append(["이동", "+%d%%" % roundi(base * multiplier_now * 100.0), "▲%d%%" % roundi(base * multiplier_next * 100.0) if can_grow else ""])
	else:
		cells.append(["효과", "×%.2f" % multiplier_now, "▲×%.2f" % multiplier_next if can_grow else ""])
	cells.append(["무게", "%.1f" % float(definition.get("weight", 0.0)), ""])
	if definition.has("visibility_multiplier"):
		cells.append(["가시성", "+%d%%" % roundi((float(definition["visibility_multiplier"]) - 1.0) * 100.0), ""])
	elif definition.has("scent_multiplier"):
		cells.append(["냄새", "-%d%%" % roundi((1.0 - float(definition["scent_multiplier"])) * 100.0), ""])
	else:
		cells.append(["가시성", "—", ""])
	cells.append(["슬롯", str({"body": "몸", "head": "머리", "feet": "발"}.get(str(definition.get("slot", "")), "—")), ""])
	return cells


func _build_stat_grid(kind: String, gear_id: String, level: int) -> Control:
	var grid := GridContainer.new()
	grid.name = "WorkbenchEnhanceStats"
	grid.columns = 4 if get_viewport().get_visible_rect().size.x >= 560.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for cell_raw in _stat_cells(kind, gear_id, level):
		var cell: Array = cell_raw
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
		panel.add_theme_stylebox_override("panel", _well_style())
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		panel.add_child(column)
		var key := _label(str(cell[0]), 10, FAINT)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(key)
		var value_row := HBoxContainer.new()
		value_row.add_theme_constant_override("separation", 3)
		column.add_child(value_row)
		var value := _label(str(cell[1]), 14, TEXT)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		# 짧은 수치 — ELLIPSIS면 HBox 안에서 폭 0으로 줄어 사라진다(실측).
		value.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		value_row.add_child(value)
		if not str(cell[2]).is_empty():
			var next := _label(str(cell[2]), 10, GREEN)
			next.autowrap_mode = TextServer.AUTOWRAP_OFF
			next.size_flags_vertical = Control.SIZE_SHRINK_END
			value_row.add_child(next)
			HudFx.attach_text_glow(next, GREEN, 0.6)
		grid.add_child(panel)
	return grid


func _cost_pair(label_text: String, value_text: String, ok: bool, resource_key := "") -> Control:
	# 비용 한 쌍 — 모자란 것만 빨강(충족은 초록 글로우).
	# 재화(고철·캣닢·통조림·츄르)는 아이콘이 곧 이름이라 이름 라벨을 걷어내고
	# 아이콘 + 수치만 남긴다(유저 확정: "아이콘 옆에 이름을 또 쓸 필요 없다").
	# 부품·재료는 아이콘만으로 무엇인지 알 수 없으니 이름을 유지한다.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)
	pair.tooltip_text = "%s %s" % [label_text, value_text]
	if ICON_ONLY_RESOURCES.has(resource_key):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(15, 15)
		icon.texture = _resource_icon(resource_key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
	else:
		var key := _label(label_text, 11, DIM)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		pair.add_child(key)
	var value := _label(value_text, 12, GREEN if ok else DANGER)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	pair.add_child(value)
	HudFx.attach_text_glow(value, GREEN if ok else DANGER, 0.6)
	return pair


func _build_enhance_cost_row(kind: String, gear_id: String, level: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "WorkbenchEnhanceCost"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _well_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var flow := HFlowContainer.new()
	flow.name = "CostPairs"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 3)
	row.add_child(flow)
	var gate_required := bool(GameState.is_breakthrough_required(kind, gear_id))
	var max_level := GameState.MAX_WEAPON_ENHANCEMENT if kind == "weapon" else GameState.MAX_ARMOR_ENHANCEMENT
	if gate_required:
		# 돌파 비용 — 고철 단독(2026-08-29 개정: get_breakthrough_cost = {"scrap": 그 단계
		# 강화비 ×3}). 인장·정밀 기어·합금 요구는 폐지 — 고철 칩 하나만, 부족하면 빨강.
		var gate_cost: Dictionary = GameState.get_breakthrough_cost(kind, gear_id)
		var gate_scrap := int(gate_cost.get("scrap", 0))
		flow.add_child(_cost_pair("돌파 · 고철", GameState.format_compact_number(gate_scrap), _owned_resource("scrap") >= gate_scrap, "scrap"))
	elif level >= max_level:
		flow.add_child(_cost_pair("최고 단계", "+%d" % max_level, true))
	else:
		var cost: Dictionary = _effective_cost(_enhance_recipe_for(kind, gear_id))
		var scrap_cost := int(cost.get("scrap", 0))
		flow.add_child(_cost_pair("고철", GameState.format_compact_number(scrap_cost), _owned_resource("scrap") >= scrap_cost, "scrap"))
		for key_value in cost.keys():
			var key := str(key_value)
			if key == "scrap":
				continue
			var need := int(cost[key])
			var have := _owned_resource(key)
			flow.add_child(_cost_pair(_resource_name(key), "%d /%d" % [need, have], have >= need, key))
	var next_label := _label(
		("돌파 +%d" % level) if gate_required else ("다음 +%d" % mini(level + 1, max_level)),
		10, DANGER if gate_required else FAINT
	)
	next_label.name = "WorkbenchEnhanceNext"
	next_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	next_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(next_label)
	return panel


func _build_locked_card_blocks(entry: Dictionary) -> Array[Control]:
	# 미제작 장비 카드 — 조각 n/3 · 비용 · 출처 · 이관 예고. [제작]은 액션 바가 맡는다.
	var kind := str(entry["kind"])
	var gear_id := str(entry["id"])
	var recipe: Dictionary = entry["recipe"]
	var shards := int(entry["shards"])
	var blocks: Array[Control] = []
	blocks.append(_build_stage_head(entry, "설계도", "%d/%d" % [shards, GameState.BLUEPRINT_SHARDS_REQUIRED], "미제작"))
	var panel := PanelContainer.new()
	panel.name = "WorkbenchEnhanceCost"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _well_style())
	var flow := HFlowContainer.new()
	flow.name = "CostPairs"
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 3)
	panel.add_child(flow)
	flow.add_child(_cost_pair("설계도 조각", "%d / %d" % [shards, GameState.BLUEPRINT_SHARDS_REQUIRED], shards >= GameState.BLUEPRINT_SHARDS_REQUIRED))
	var cost := _effective_cost(recipe)
	for key_value in cost.keys():
		var key := str(key_value)
		var need := int(cost[key])
		var have := _owned_resource(key)
		flow.add_child(_cost_pair(_resource_name(key), GameState.format_compact_number(need) if key == "scrap" else "%d /%d" % [need, have], have >= need, key))
	blocks.append(panel)
	var source := _label("조각은 %s에서 나옵니다.%s" % [_blueprint_source_text(gear_id), _transfer_preview_sentence(kind, gear_id)], 12, DIM)
	source.name = "WorkbenchCraftGuide"
	source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocks.append(source)
	# 조각 말고 다른 잠금(티어·작업대 레벨)도 말한다 — 회색 버튼만 보여주는 건 UX가 아니다.
	var required_tier := int(recipe.get("required_tier", 1))
	var required_workbench := int(recipe.get("required_workbench", 1))
	if GameState.shelter_tier < required_tier or GameState.shelter_workbench_level < required_workbench:
		var lock_text := ("쉘터 Tier %d 필요" % required_tier) if GameState.shelter_tier < required_tier else ("작업대 Lv.%d 필요 (제작 탭 하단 '보급품'에서 확장)" % required_workbench)
		var lock_label := _label(lock_text, 12, DANGER)
		lock_label.name = "WorkbenchBlockedReason"
		blocks.append(lock_label)
	return blocks


func _transfer_preview_sentence(kind: String, gear_id: String) -> String:
	# "만들면 AKM +13의 60%를 이어받아 +7로 시작합니다." — 하위 사다리 장비의 최고 강화 기준.
	var lower_ids: Array[String] = []
	if kind == "weapon":
		if GameState.weapon_enhancement_transfers_done.has(gear_id):
			return ""
		lower_ids = WeaponSystem.get_lower_ladder_weapons(gear_id)
	else:
		if GameState.armor_enhancement_transfers_done.has(gear_id):
			return ""
		lower_ids = GameState.get_lower_armor_ladder_ids(gear_id)
	var from_id := ""
	var from_level := 0
	for candidate_id in lower_ids:
		var level := int(GameState.get_gear_enhancement_level(kind, candidate_id))
		if level > from_level:
			from_level = level
			from_id = candidate_id
	if from_id.is_empty() or from_level <= 0:
		return ""
	var transferred := int(floor(float(from_level) * WeaponSystem.ENHANCEMENT_TRANSFER_RATIO))
	return " 만들면 %s +%d의 %d%%를 이어받아 +%d로 시작합니다." % [
		_gear_short_name(kind, from_id), from_level, roundi(WeaponSystem.ENHANCEMENT_TRANSFER_RATIO * 100.0), transferred,
	]


func _next_perk_level(level: int) -> int:
	# 아직 안 얻은 첫 돌파 보너스 단계(+30/50/70/90). 다 얻었으면 0.
	for perk_level in GameState.BREAKTHROUGH_PERK_LEVELS:
		if int(perk_level) > level or (int(perk_level) == level and bool(GameState.is_breakthrough_required(enhance_selected_kind, enhance_selected_id))):
			return int(perk_level)
	return 0


# ── 액션 바: [강화 +1 / 돌파 / 제작] + [가능한 만큼] ───────────────


func _style_action_button(button: Button, mode: String) -> void:
	var accent := HudStyle.LINE_FOCUS
	var fill := Color(0.063, 0.09, 0.086, 0.96)
	var font := TEXT
	match mode:
		"enhance":
			fill = Color("#e2c97f")
			accent = GOLD_BRIGHT
			font = Color("#0b100e")
		"gate":
			fill = Color("#d47a6b")
			accent = Color("#f09a8a")
			font = Color("#0b100e")
		"gate_short":
			# 돌파 고철 부족 — 붉은 글씨의 어두운 버튼(누르면 부족 사유 토스트).
			fill = Color(0.09, 0.05, 0.045, 0.96)
			accent = DANGER
			font = DANGER
		"craft":
			fill = Color(0.063, 0.09, 0.086, 0.96)
			accent = GREEN
			font = TEXT
	var normal := _panel_style(fill, accent, 1, 8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := _panel_style(fill.lightened(0.05), accent, 1, 8)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	var pressed := _panel_style(fill.darkened(0.12), accent, 2, 8)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 7
	pressed.content_margin_bottom = 5
	var disabled := _panel_style(Color(fill.r, fill.g, fill.b, 0.45), Color(accent, 0.4), 1, 8)
	disabled.content_margin_left = 10
	disabled.content_margin_right = 10
	disabled.content_margin_top = 6
	disabled.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_disabled_color", Color(font, 0.6))
	button.add_theme_font_size_override("font_size", 15)


func _refresh_enhance_actions() -> void:
	if not is_instance_valid(enhance_primary_button) or not is_instance_valid(enhance_max_button):
		return
	var entry := _find_gear_entry(enhance_selected_kind, enhance_selected_id)
	# 돌파 모드만 버튼에 고철 아이콘을 얹는다 — 다른 모드로 돌아오면 걷어낸다.
	enhance_primary_button.icon = null
	enhance_primary_button.tooltip_text = ""
	if entry.is_empty():
		primary_mode = "none"
		enhance_primary_button.text = "강화 +1"
		enhance_primary_button.disabled = true
		enhance_max_button.text = "가능한 만큼"
		enhance_max_button.disabled = true
		_style_action_button(enhance_primary_button, "enhance")
		return
	var kind := str(entry["kind"])
	var gear_id := str(entry["id"])
	if not bool(entry["owned"]):
		primary_mode = "craft"
		var recipe: Dictionary = entry["recipe"]
		var missing := GameState.BLUEPRINT_SHARDS_REQUIRED - int(entry["shards"])
		enhance_primary_button.text = "제작 · 조각 %d개 더" % missing if missing > 0 else "제작"
		enhance_primary_button.disabled = not _can_craft(recipe)
		_style_action_button(enhance_primary_button, "craft")
		enhance_max_button.text = "—"
		enhance_max_button.disabled = true
		return
	var level := int(entry["level"])
	var max_level := GameState.MAX_WEAPON_ENHANCEMENT if kind == "weapon" else GameState.MAX_ARMOR_ENHANCEMENT
	if bool(GameState.is_breakthrough_required(kind, gear_id)):
		# 돌파도 고철 단독(2026-08-29) — "돌파 · [고철 아이콘] x49.4K", 부족하면 빨강.
		# 재화 표기 전역 규칙(아이콘 + 숫자, 이름은 툴팁)이라 버튼에도 이름 대신 아이콘.
		primary_mode = "gate"
		var gate_cost: Dictionary = GameState.get_breakthrough_cost(kind, gear_id)
		var gate_scrap := int(gate_cost.get("scrap", 0))
		var gate_ok := _owned_resource("scrap") >= gate_scrap
		enhance_primary_button.text = "돌파 · x%s" % GameState.format_compact_number(gate_scrap)
		enhance_primary_button.icon = _resource_icon("scrap")
		enhance_primary_button.add_theme_constant_override("icon_max_width", 22)
		# CENTER 정렬은 센터 텍스트와 아이콘이 겹친다(실측) — 왼끝 고정이 칩처럼 읽힌다.
		enhance_primary_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enhance_primary_button.tooltip_text = "돌파 · 고철 %s 소모" % GameState.format_compact_number(gate_scrap)
		enhance_primary_button.disabled = false
		_style_action_button(enhance_primary_button, "gate" if gate_ok else "gate_short")
		enhance_max_button.text = "가능한 만큼"
		enhance_max_button.disabled = true
		return
	primary_mode = "enhance"
	enhance_primary_button.text = (
		"강화 +1  [SPACE]\n길게 누르면 연타"
		if level < max_level
		else "최고 단계 +%d" % max_level
	)
	enhance_primary_button.disabled = level >= max_level
	_style_action_button(enhance_primary_button, "enhance")
	enhance_max_button.text = "가능한 만큼"
	enhance_max_button.disabled = level >= max_level


func _unhandled_input(event: InputEvent) -> void:
	# SPACE = 강화 +1(길게 누르면 연타) — 버튼과 같은 경로(유저 요청: 키 가이드 포함).
	if not is_instance_valid(enhance_primary_button) or not enhance_primary_button.is_visible_in_tree():
		return
	if primary_mode != "enhance" or enhance_primary_button.disabled:
		return
	var key := event as InputEventKey
	if key == null or key.keycode != KEY_SPACE or key.echo:
		return
	if key.pressed:
		_on_primary_button_down()
	else:
		_on_primary_button_up()
	get_viewport().set_input_as_handled()


func _on_primary_button_down() -> void:
	# 강화는 누르는 순간 1회 + 길게 누르면 연타(터치도 같은 경로 — 에뮬레이트 마우스).
	if primary_mode != "enhance":
		return
	_enhance_once(true, true)
	_start_enhance_hold()


func _on_primary_button_up() -> void:
	_stop_enhance_hold()


func _on_primary_pressed() -> void:
	# 돌파·제작은 비싼 1회성 행동 — 떼는 순간(pressed)에만.
	match primary_mode:
		"gate":
			_breakthrough_selected()
		"craft":
			_craft_selected_locked()


func _start_enhance_hold() -> void:
	if hold_timer == null:
		hold_timer = Timer.new()
		hold_timer.name = "EnhanceHoldTimer"
		hold_timer.one_shot = true
		hold_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		hold_timer.timeout.connect(_on_hold_tick)
		add_child(hold_timer)
	hold_active = true
	hold_timer.start(HOLD_REPEAT_DELAY)


func _stop_enhance_hold() -> void:
	hold_active = false
	if hold_timer != null:
		hold_timer.stop()


func _primary_is_held() -> bool:
	if not is_instance_valid(enhance_primary_button):
		return false
	var mode := enhance_primary_button.get_draw_mode()
	return mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED


func _on_hold_tick() -> void:
	if not hold_active or primary_mode != "enhance" or not _primary_is_held():
		_stop_enhance_hold()
		return
	if _enhance_once(false, true):
		hold_timer.start(HOLD_REPEAT_INTERVAL)
	else:
		_stop_enhance_hold()


func _enhance_once(show_failure: bool, with_fx: bool) -> bool:
	# 강화 1단계 — 성공이면 true. 판정·소비·사유는 _craft가 맡고, 여기는 연출만 얹는다.
	var kind := enhance_selected_kind
	var gear_id := enhance_selected_id
	if kind.is_empty() or gear_id.is_empty():
		return false
	var before := int(GameState.get_gear_enhancement_level(kind, gear_id))
	_craft(_enhance_recipe_for(kind, gear_id))
	var after := int(GameState.get_gear_enhancement_level(kind, gear_id))
	if after <= before:
		if show_failure:
			_toast(craft_feedback_text, DANGER)
		return false
	if with_fx:
		_play_enhance_fx(after)
		if after % GameState.BREAKTHROUGH_STEP == 0:
			# 돌파는 고철 단독(그 단계 강화비 ×3) — 정확한 값을 미리 말한다.
			var gate_scrap := int((GameState.get_breakthrough_cost(kind, gear_id) as Dictionary).get("scrap", 0))
			_toast("%s +%d 달성! 다음은 돌파 — 고철 %s" % [_gear_short_name(kind, gear_id), after, GameState.format_compact_number(gate_scrap)])
	return true


func _enhance_as_much_as_possible() -> void:
	# 고철·부품이 닿는 데까지 반복. 돌파 관문에서 멈추고 이유를 토스트로 말한다.
	var kind := enhance_selected_kind
	var gear_id := enhance_selected_id
	if kind.is_empty() or gear_id.is_empty() or primary_mode != "enhance":
		return
	var count := 0
	batch_refresh_depth += 1
	while count < MAX_BATCH_ENHANCE and not bool(GameState.is_breakthrough_required(kind, gear_id)):
		if not _enhance_once(false, false):
			break
		count += 1
	batch_refresh_depth -= 1
	_refresh_after_change()
	var short_name := _gear_short_name(kind, gear_id)
	var level := int(GameState.get_gear_enhancement_level(kind, gear_id))
	var stop_reason := "돌파 관문에서 멈춤" if bool(GameState.is_breakthrough_required(kind, gear_id)) else _batch_stop_reason(kind, gear_id)
	if count > 0:
		_play_enhance_fx(level)
		_toast("%s +%d 강화 → +%d (%s)" % [short_name, count, level, stop_reason])
	else:
		_toast("더 올릴 수 없습니다 · %s" % stop_reason, DANGER)


func _batch_stop_reason(kind: String, gear_id: String) -> String:
	var reason := _weapon_enhance_failure_reason(gear_id) if kind == "weapon" else _armor_enhance_failure_reason(gear_id)
	return reason.trim_prefix("강화 불가 · ")


func _breakthrough_selected() -> void:
	var kind := enhance_selected_kind
	var gear_id := enhance_selected_id
	if kind.is_empty() or gear_id.is_empty():
		return
	var before := int(GameState.get_breakthrough_level_done(kind, gear_id))
	_craft(_breakthrough_recipe(kind, gear_id))
	var after := int(GameState.get_breakthrough_level_done(kind, gear_id))
	if after > before:
		_play_breakthrough_fx()
		_toast("돌파 성공 · %s +%d의 벽을 넘었다 — 다음 강화가 열립니다" % [_gear_short_name(kind, gear_id), after])
	else:
		_toast(craft_feedback_text, DANGER)


func _craft_selected_locked() -> void:
	var entry := _find_gear_entry(enhance_selected_kind, enhance_selected_id)
	if entry.is_empty() or bool(entry["owned"]):
		return
	var recipe: Dictionary = entry["recipe"]
	_craft(recipe)
	if bool(GameState.is_gear_owned(str(entry["id"]))):
		_play_breakthrough_fx()
		_toast(craft_feedback_text)
	else:
		_toast(craft_feedback_text, DANGER)


# ── 연출: 버튼 광택 스윕 · "+N" 숫자 팝 · 카드 펀치 · 돌파 골드 플래시 ─────


func _play_enhance_fx(level: int) -> void:
	SFX.play("enhance_clink")
	if is_instance_valid(enhance_primary_button):
		_play_button_shine(enhance_primary_button)
		_spawn_level_pop(enhance_primary_button, "+%d" % level)
	if is_instance_valid(enhance_card):
		enhance_card.pivot_offset = enhance_card.size * 0.5
		var punch := enhance_card.create_tween()
		punch.tween_property(enhance_card, "scale", Vector2(1.018, 1.018), 0.07).set_trans(Tween.TRANS_SINE)
		punch.tween_property(enhance_card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_button_shine(button: Button) -> void:
	if not HudFx.fx_enabled():
		return
	var shine := ColorRect.new()
	shine.name = "ShineSweep"
	shine.color = Color(1.0, 1.0, 1.0, 0.38)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := maxf(24.0, button.size.x * 0.22)
	shine.size = Vector2(width, button.size.y + 8.0)
	shine.position = Vector2(-width, -4.0)
	shine.rotation_degrees = 0.0
	button.add_child(shine)
	var tween := shine.create_tween()
	tween.tween_property(shine, "position:x", button.size.x + width, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(shine.queue_free)


func _spawn_level_pop(anchor: Control, text: String) -> void:
	if not is_instance_valid(modal_root):
		return
	var pop := _label(text, 20, Color.WHITE)
	pop.name = "LevelPop"
	pop.autowrap_mode = TextServer.AUTOWRAP_OFF
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.z_index = 20
	modal_root.add_child(pop)
	var anchor_rect := anchor.get_global_rect()
	var origin := modal_root.get_global_rect().position
	pop.position = Vector2(anchor_rect.position.x + anchor_rect.size.x * 0.5 - 16.0, anchor_rect.position.y - 22.0) - origin
	HudFx.attach_text_glow(pop, GOLD_BRIGHT, 1.1)
	var tween := pop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "position:y", pop.position.y - 26.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pop.queue_free)


func _play_breakthrough_fx() -> void:
	SFX.play("enhance_clink")
	if not is_instance_valid(enhance_card) or not HudFx.fx_enabled():
		return
	# 돌파 = 벽이 깨지는 순간 — 카드를 0.3초 찢었다 되돌리는 글리치(복원형) 위에 골드 플래시.
	HudFx.play_glitch_pulse(enhance_card, 0.3)
	var flash := ColorRect.new()
	flash.name = "GoldFlash"
	flash.color = Color(GOLD_BRIGHT, 0.55)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enhance_card.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)
	var title := modal_root.find_child("WorkbenchTitle", true, false) as Label if is_instance_valid(modal_root) else null
	if title != null and title.material is ShaderMaterial:
		(title.material as ShaderMaterial).set_shader_parameter("shift_px", 1.0)
		var off := get_tree().create_timer(0.08, true)
		off.timeout.connect(func() -> void:
			if is_instance_valid(title) and title.material is ShaderMaterial:
				(title.material as ShaderMaterial).set_shader_parameter("shift_px", 0.0)
		)


# ══════════════════════════════════════════════════════════════════
# 제작 탭(무기·방어구 + 하단 보급품) — 레시피 목록 + 상세(고정 액션 바). 1단계 로직(판정·소비·사유) 포함.
# ══════════════════════════════════════════════════════════════════


func _build_recipe_list() -> Control:
	# 강화 보드의 시각 문법(_board_module_style 패널 + WELL 행)과 같은 문법 — 탭마다
	# 테마가 달라 보이던 것을 통일했다(유저 요구).
	var panel := PanelContainer.new()
	panel.name = "WorkbenchRecipePanel"
	panel.clip_contents = true
	var viewport_size := get_viewport().get_visible_rect().size
	var stacked := viewport_size.x < 760.0
	# 세로 화면은 패널이 화면을 꽉 쓰므로 목록도 더 크게 잡는다.
	panel.custom_minimum_size = Vector2(0.0 if stacked else 330.0, 264.0 if stacked else 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_FILL if stacked else Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _board_module_style())
	var margin := _margin(8, 8, 8, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	if not stacked:
		# 강화 보드의 목록 제목("보유 장비 · 평생 귀속")과 같은 문법.
		var list_title := _label("설계도 · 아직 만들지 않은 것만", 11, DIM)
		list_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		list_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(list_title)
	# 카테고리 서브탭 — 무기 / 방어구 / 중장비 / 보급품(유저: "카테고리별로 탭").
	var subtabs := HBoxContainer.new()
	subtabs.name = "WorkbenchCraftSubtabs"
	subtabs.add_theme_constant_override("separation", 4)
	for sub_value in CRAFT_SUBCATEGORIES:
		var sub_id := str(sub_value)
		var sub_button := _button(str(CRAFT_SUBCATEGORY_NAMES.get(sub_id, sub_id)), "")
		sub_button.name = "WorkbenchCraftSubtab_%s" % sub_id
		sub_button.toggle_mode = true
		sub_button.button_pressed = craft_subcategory == sub_id
		sub_button.focus_mode = Control.FOCUS_NONE
		sub_button.custom_minimum_size = Vector2(0, 34)
		sub_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_button.clip_text = true
		_style_tab(sub_button, sub_button.button_pressed)
		sub_button.pressed.connect(func() -> void:
			craft_subcategory = sub_id
			var sub_recipes: Array = _recipes_for_category(sub_id)
			if not sub_recipes.is_empty():
				selected_recipe_id = str((sub_recipes[0] as Dictionary).get("id", ""))
			_rebuild_ui()
		)
		subtabs.add_child(sub_button)
	column.add_child(subtabs)
	var scroll := HudStyle.make_scroll()
	scroll.name = "WorkbenchRecipeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.name = "WorkbenchRecipeList"
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 5)
	scroll.add_child(recipe_list)
	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "WorkbenchDetailPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	# 강화 카드와 같은 모듈 패널 — 탭별로 다르던 초록톤 테마를 걷어냈다.
	panel.add_theme_stylebox_override("panel", _board_module_style())
	var margin := _margin(14, 10, 14, 10)
	panel.add_child(margin)
	# 설명·재료만 스크롤하고 제작 버튼은 바닥에 고정한다.
	var shell := VBoxContainer.new()
	shell.name = "WorkbenchDetailShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)
	var scroll := HudStyle.make_scroll()
	scroll.name = "WorkbenchDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	detail_box = VBoxContainer.new()
	detail_box.name = "WorkbenchDetailContent"
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 14)
	scroll.add_child(detail_box)
	detail_action_bar = VBoxContainer.new()
	detail_action_bar.name = "WorkbenchDetailActions"
	detail_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_action_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	detail_action_bar.add_theme_constant_override("separation", 6)
	shell.add_child(detail_action_bar)
	return panel


func _refresh_recipe_list() -> void:
	# UI가 열려 있지 않을 때도 _craft가 호출될 수 있다(프로브·자동화). 조용히 넘긴다.
	if not is_instance_valid(recipe_list):
		return
	_clear(recipe_list)
	var recipes: Array = _recipes_for_category(
		craft_subcategory if selected_category == "craft" else selected_category
	)
	# 이미 만든 장비(영구 귀속·1개)는 제작 목록에서 뺀다 — 재제작 불가라 눌러도
	# 거절만 나온다(유저: "제작 탭에는 이미 제작한 무기는 없어야").
	var visible_recipes: Array = []
	for recipe_raw in recipes:
		var candidate: Dictionary = recipe_raw
		var candidate_gear := str(candidate.get("gear_id", ""))
		if not candidate_gear.is_empty() and bool(GameState.is_gear_owned(candidate_gear)):
			continue
		visible_recipes.append(candidate)
	recipes = visible_recipes
	# 섹션 구분선 — 중장비(소모성 화력)는 보급품 위에, 강화 보드와 같은 11px DIM 문법.
	# 보급품(수리·확장·소모품 제작)은 제작 탭 하단 섹션으로 합류(개조·보급 탭 폐지).
	var heavy_ids := {}
	for heavy_raw in RECIPES["heavy"]:
		heavy_ids[str((heavy_raw as Dictionary).get("id", ""))] = true
	var supply_ids := {}
	for supply_raw in RECIPES["supplies"]:
		supply_ids[str((supply_raw as Dictionary).get("id", ""))] = true
	var heavy_divider_added := false
	var supply_divider_added := false
	for recipe_raw in recipes:
		var recipe: Dictionary = recipe_raw
		if not heavy_divider_added and heavy_ids.has(str(recipe.get("id", ""))):
			heavy_divider_added = true
			var heavy_divider := _label("중장비 · 쓰면 부서진다", 11, DIM)
			heavy_divider.name = "WorkbenchHeavySection"
			heavy_divider.autowrap_mode = TextServer.AUTOWRAP_OFF
			recipe_list.add_child(heavy_divider)
		if not supply_divider_added and supply_ids.has(str(recipe.get("id", ""))):
			supply_divider_added = true
			var divider := _label("보급품", 11, DIM)
			divider.name = "WorkbenchSupplySection"
			divider.autowrap_mode = TextServer.AUTOWRAP_OFF
			recipe_list.add_child(divider)
		# 상태를 글자로만 말하면 목록을 한 줄씩 읽어야 한다. 색으로 먼저 말한다.
		var state_color := _recipe_state_color(recipe)
		var selected := str(recipe["id"]) == selected_recipe_id
		var button := _button(
			"%s\n%s" % [str(recipe["name"]), _recipe_list_subtitle(recipe)],
			"",
			state_color
		)
		button.name = "WorkbenchRecipeRow_%s" % str(recipe["id"])
		# 강화 보드의 장비 행과 같은 WELL 문법 — 선택 행만 골드 테두리.
		var row_style := _well_style(GOLD_BRIGHT if selected else WELL_LINE)
		button.add_theme_stylebox_override("normal", row_style)
		button.add_theme_stylebox_override("pressed", row_style)
		button.add_theme_stylebox_override("hover", _well_style(HudStyle.LINE_FOCUS))
		button.add_theme_stylebox_override("hover_pressed", row_style)
		button.add_theme_color_override("font_color", state_color)
		button.add_theme_color_override("font_hover_color", state_color.lightened(0.2))
		button.add_theme_color_override("font_pressed_color", state_color)
		button.add_theme_color_override("font_hover_pressed_color", state_color.lightened(0.2))
		button.icon = _recipe_icon(recipe)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.clip_text = true
		button.toggle_mode = true
		button.button_pressed = selected
		button.pressed.connect(func() -> void:
			selected_recipe_id = str(recipe["id"])
			_refresh_recipe_list()
			_refresh_detail_panel()
		)
		recipe_list.add_child(button)


func _refresh_detail_panel() -> void:
	if not is_instance_valid(detail_box):
		return
	_clear(detail_box)
	# 제작 버튼이 사는 고정 바. 없으면(구버전 트리) 상세 본문으로 되돌아간다.
	var action_host: VBoxContainer = detail_box
	if is_instance_valid(detail_action_bar):
		_clear(detail_action_bar)
		action_host = detail_action_bar
	var recipe := _selected_recipe()
	if recipe.is_empty():
		detail_box.add_child(_label("선택된 설계도가 없습니다.", 16, TEXT))
		return

	# 강화 카드의 헤드와 같은 문법 — 골드 제목 + 글로우, 설명은 DIM.
	var title := _label(str(recipe["name"]), 22, GOLD_TEXT)
	title.name = "WorkbenchRecipeTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_box.add_child(title)
	HudFx.attach_text_glow(title, GOLD, 0.8)
	var description := _label(str(recipe.get("desc", "")), 13, DIM)
	description.name = "WorkbenchRecipeDescription"
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(description)

	var icon_card := PanelContainer.new()
	icon_card.name = "WorkbenchResultCard"
	icon_card.custom_minimum_size = Vector2(170, 108)
	icon_card.add_theme_stylebox_override("panel", _well_style())
	var icon_margin := _margin(12, 10, 12, 10)
	icon_card.add_child(icon_margin)
	var icon_texture := TextureRect.new()
	icon_texture.texture = _recipe_icon(recipe)
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(icon_texture)
	detail_box.add_child(icon_card)

	detail_box.add_child(_section("필요 재료"))
	var cost_box := VBoxContainer.new()
	cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_box.add_theme_constant_override("separation", 6)
	detail_box.add_child(cost_box)
	var effective_cost := _effective_cost(recipe)
	for key in effective_cost.keys():
		var needed := int(effective_cost[key])
		var owned := _owned_resource(str(key))
		# 강화 보드의 충족/부족 색(GREEN/DANGER)과 같은 문법.
		var color := GREEN if owned >= needed else DANGER
		cost_box.add_child(_resource_row(str(key), owned, needed, color))
	var required_tier := int(recipe.get("required_tier", 1))
	if GameState.shelter_tier < required_tier:
		cost_box.add_child(_label("쉘터 Tier %d에서 해금" % required_tier, 14, DANGER))
	if bool((recipe.get("result", {}) as Dictionary).get("enhance", false)):
		var detail_weapon_id := _enhance_weapon_id(recipe)
		var level := GameState.get_weapon_enhancement_level(detail_weapon_id)
		cost_box.add_child(_label("%s  +%d → +%d" % [_gear_short_name("weapon", detail_weapon_id), level, mini(99, level + 1)], 14, GOLD_TEXT))
	if (recipe.get("result", {}) as Dictionary).has("enhance_armor"):
		var armor_id := str((recipe.get("result", {}) as Dictionary)["enhance_armor"])
		var armor_level := int(GameState.get_armor_enhancement_level(armor_id))
		cost_box.add_child(_label("%s  +%d → +%d · 효과 ×%.2f" % [
			_equipment_display_name(armor_id), armor_level, mini(99, armor_level + 1),
			float(GameState.get_armor_enhancement_multiplier(armor_id)),
		], 14, GOLD_TEXT))
	if (recipe.get("result", {}) as Dictionary).has("breakthrough"):
		var target := (recipe.get("result", {}) as Dictionary)["breakthrough"] as Dictionary
		cost_box.add_child(_label("돌파 단계 +%d · 완료한 돌파 +%d" % [
			int(GameState.get_gear_enhancement_level(str(target.get("kind", "")), str(target.get("id", "")))),
			int(GameState.get_breakthrough_level_done(str(target.get("kind", "")), str(target.get("id", "")))),
		], 14, GOLD_TEXT))
	if _is_gear_recipe_owned(recipe):
		cost_box.add_child(_label("제작됨 · 영구 보유 — 잃지 않으며 다시 만들 수 없습니다", 13, GREEN))
	elif not str(recipe.get("gear_id", "")).is_empty():
		cost_box.add_child(_label(str(GameState.get_blueprint_progress_text(str(recipe.get("gear_id", "")))), 13, GOLD_TEXT))

	detail_box.add_child(_section("결과물"))
	detail_box.add_child(_build_result_preview(recipe))

	var craft := _button(_craft_action_text(recipe), _craft_action_icon(recipe))
	craft.name = "WorkbenchCraftButton"
	craft.custom_minimum_size = Vector2(0, 52)
	craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft.disabled = not _can_craft(recipe)
	# 강화 보드 액션 바의 [제작] 모드와 같은 스타일 — 두 탭의 주 행동 버튼이 같은 얼굴.
	_style_action_button(craft, "craft")
	craft.pressed.connect(func() -> void:
		_craft(recipe)
	)
	action_host.add_child(craft)

	# 버튼이 죽어 있으면 이유를 말한다 — 회색 버튼만 보여주는 건 UX가 아니다.
	if craft.disabled:
		var reason := _recipe_list_subtitle(recipe)
		if not reason.is_empty():
			var reason_label := _label("잠긴 이유: %s" % reason, 13, DANGER)
			reason_label.name = "WorkbenchBlockedReason"
			action_host.add_child(reason_label)

	# 제작 직후 성공 피드백 — 리빌드 후에도 잠깐 남아 스르륵 사라진다.
	if not craft_feedback_text.is_empty() and Time.get_ticks_msec() < craft_feedback_until_msec:
		var feedback := _label(craft_feedback_text, 16, GREEN)
		feedback.name = "WorkbenchCraftFeedback"
		feedback.add_theme_font_size_override("font_size", 20)
		action_host.add_child(feedback)
		feedback.pivot_offset = Vector2(0.0, 12.0)
		feedback.scale = Vector2(0.94, 0.94)
		feedback.modulate.a = 0.0
		var tween := feedback.create_tween()
		tween.set_parallel(true)
		tween.tween_property(feedback, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		tween.tween_property(feedback, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(2.2)
		tween.chain().tween_property(feedback, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		# 결과 카드가 튀어오르고 초록빛이 번쩍 — "만들어졌다"를 몸으로 알린다.
		# 문자열 한 줄만으로는 제작 성공을 알아채기 어려웠다(유저 신고).
		if is_instance_valid(icon_card):
			icon_card.pivot_offset = icon_card.custom_minimum_size * 0.5
			var pop := icon_card.create_tween()
			pop.tween_property(icon_card, "scale", Vector2(1.16, 1.16), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.parallel().tween_property(icon_card, "modulate", Color(1.6, 2.1, 1.7, 1.0), 0.14)
			pop.tween_property(icon_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_SINE)
			pop.parallel().tween_property(icon_card, "modulate", Color.WHITE, 0.34)
		# 상단 재화 줄도 함께 깜빡여 "재료가 빠지고 결과가 들어왔다"를 잇는다.
		for key_value in resource_value_labels.keys():
			var resource_label := resource_value_labels[key_value] as Label
			if not is_instance_valid(resource_label):
				continue
			var flash := resource_label.create_tween()
			flash.tween_property(resource_label, "modulate", Color(1.5, 1.9, 1.5, 1.0), 0.12)
			flash.tween_property(resource_label, "modulate", Color.WHITE, 0.4)

func _selected_recipe() -> Dictionary:
	for recipe_raw in _recipes_for_category(selected_category):
		var recipe: Dictionary = recipe_raw
		if str(recipe.get("id", "")) == selected_recipe_id:
			return recipe
	return {}


func _recipes_for_category(category: String) -> Array:
	# 탭 이름(craft)은 RECIPES 카테고리 묶음으로 풀린다. 옛 카테고리 이름도 그대로 받는다.
	if TAB_CATEGORIES.has(category) and not (TAB_CATEGORIES[category] as Array).is_empty():
		var merged: Array = []
		for sub_category in TAB_CATEGORIES[category]:
			merged.append_array(_recipes_for_category(str(sub_category)))
		return merged
	var recipes: Array = (RECIPES.get(category, []) as Array).duplicate(true)
	if category == "heavy":
		# 설명의 단일 진실은 GameState.HEAVY_GEAR_DEFS.description — 여기서 채운다.
		for heavy_recipe_raw in recipes:
			var heavy_recipe: Dictionary = heavy_recipe_raw
			var gear_id := str((heavy_recipe.get("result", {}) as Dictionary).get("heavy_gear", ""))
			var definition := GameState.HEAVY_GEAR_DEFS.get(gear_id, {}) as Dictionary
			if str(heavy_recipe.get("desc", "")).is_empty():
				heavy_recipe["desc"] = "%s\n쓰면 부서지는 소모품 — 부품으로 다시 만든다. 필드에서 T로 선택해 사용." % str(definition.get("description", ""))
		return recipes
	if category == "artisan":
		# 돌파 행 — 장착 무기 + 장착 방어구 3슬롯. 데이터만(2단계 UI가 재구성).
		if bool(GameState.has_ak) and not str(GameState.equipped_weapon_id).is_empty():
			recipes.append(_breakthrough_recipe("weapon", str(GameState.equipped_weapon_id)))
		for slot in ["body", "head", "feet"]:
			var equipped_id := str(GameState.get_equipped_equipment(slot))
			if not equipped_id.is_empty():
				recipes.append(_breakthrough_recipe("armor", str(GameState.armor_enhancement_key(equipped_id))))
		return recipes
	if category != "enhance":
		return recipes
	# 장착 방어구 강화 행(방어구 +99 신설) — 무기 강화와 같은 규칙.
	for slot in ["body", "head", "feet"]:
		var equipped_id := str(GameState.get_equipped_equipment(slot))
		if equipped_id.is_empty():
			continue
		var base_id := str(GameState.armor_enhancement_key(equipped_id))
		recipes.append({
			"id": "enhance_armor_%s" % base_id,
			"name": "%s 영구 강화" % _equipment_display_name(base_id),
			"desc": "장착 중인 방어구를 +99까지 영구 강화합니다. 피해 감소(신발은 이동·스태미나)가 수렴 곡선으로 오릅니다. +10·+20·…에서는 돌파가 필요합니다.",
			"cost": {},
			"result": {"enhance_armor": base_id},
		})
	for mod_id in GameState.equipped_weapon_mods:
		var definition := WeaponSystem.get_mod(mod_id)
		if definition.is_empty():
			continue
		recipes.append({
			"id": "enhance_mod_%s" % mod_id,
			"name": "%s 영구 강화" % str(definition.get("display_name", mod_id)),
			"desc": "장착 파츠의 고유 보정치를 +99까지 영구 강화합니다.",
			"cost": {},
			"result": {"enhance_mod": mod_id},
		})
	return recipes


func _breakthrough_recipe(kind: String, item_id: String) -> Dictionary:
	var level := int(GameState.get_gear_enhancement_level(kind, item_id))
	var display_name := _resource_name(item_id) if kind == "weapon" else _equipment_display_name(item_id)
	return {
		"id": "breakthrough_%s_%s" % [kind, item_id],
		"name": "%s 돌파 (+%d)" % [display_name, level],
		"desc": "고철을 크게 태워(그 단계 강화비 ×3) +10·+20·…·+90의 벽을 넘습니다. 돌파 전엔 그 단계에서 강화가 멈춥니다.",
		"cost": {},
		"result": {"breakthrough": {"kind": kind, "id": item_id}},
	}


func _can_craft(recipe: Dictionary) -> bool:
	if GameState.shelter_tier < int(recipe.get("required_tier", 1)):
		return false
	if GameState.shelter_workbench_level < int(recipe.get("required_workbench", 1)):
		return false
	if not _has_required_blueprint(recipe):
		return false
	# 장비는 1개 영구 — 보유 중이면 재제작 불가.
	if _is_gear_recipe_owned(recipe):
		return false
	for key in _effective_cost(recipe).keys():
		if _owned_resource(str(key)) < int(_effective_cost(recipe)[key]):
			return false
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return GameState.weapon_durability < 100.0 and not GameState.workbench_repair_active
	if bool(result.get("workbench_upgrade", false)):
		return GameState.shelter_workbench_level < 5
	if bool(result.get("enhance", false)):
		var weapon_id := _enhance_weapon_id(recipe)
		return (
			GameState.get_weapon_count(weapon_id) > 0
			and GameState.get_weapon_enhancement_level(weapon_id) < GameState.MAX_WEAPON_ENHANCEMENT
			and not bool(GameState.is_breakthrough_required("weapon", weapon_id))
		)
	if result.has("enhance_armor"):
		var base_id := str(result["enhance_armor"])
		return (
			GameState.is_armor_base_owned(base_id)
			and GameState.get_armor_enhancement_level(base_id) < GameState.MAX_ARMOR_ENHANCEMENT
			and not bool(GameState.is_breakthrough_required("armor", base_id))
		)
	if result.has("breakthrough"):
		var target := result["breakthrough"] as Dictionary
		return str(GameState.get_breakthrough_block_reason(str(target.get("kind", "")), str(target.get("id", "")))).is_empty()
	if result.has("enhance_mod"):
		var mod_id := str(result["enhance_mod"])
		return GameState.equipped_weapon_mods.has(mod_id) and GameState.get_mod_enhancement_level(mod_id) < GameState.MAX_WEAPON_ENHANCEMENT
	return true


func _is_gear_recipe_owned(recipe: Dictionary) -> bool:
	var gear_id := str(recipe.get("gear_id", ""))
	return not gear_id.is_empty() and bool(GameState.is_gear_owned(gear_id))


func _craft(recipe: Dictionary) -> void:
	if not _can_craft(recipe):
		# 조용한 return은 버튼 고장으로 읽힌다 — 못 만드는 이유를 그대로 말한다.
		var blocked_reason := _recipe_list_subtitle(recipe)
		_set_craft_feedback(
			"제작 불가" if blocked_reason.is_empty() else "제작 불가 · %s" % blocked_reason
		)
		return
	var result: Dictionary = recipe.get("result", {})
	if bool(result.get("auto_repair", false)):
		GameState.workbench_repair_active = true
		GameState.workbench_repair_weapon_id = GameState.equipped_weapon_id
		GameState.save_persistent_state()
		_set_craft_feedback("정비 시작 — 다음 출정 복귀까지 수리됩니다")
		_refresh_after_change()
		return
	if bool(result.get("workbench_upgrade", false)):
		if GameState.try_upgrade_workbench():
			GameState.save_persistent_state()
			_set_craft_feedback("작업대 확장 완료 · Lv.%d" % GameState.shelter_workbench_level)
		else:
			# 예전엔 실패하면 아무 말도 없어서 버튼이 고장 난 것처럼 읽혔다.
			_set_craft_feedback(_workbench_upgrade_failure_reason())
		_refresh_after_change()
		return
	if result.has("breakthrough"):
		var target := result["breakthrough"] as Dictionary
		var kind := str(target.get("kind", ""))
		var target_id := str(target.get("id", ""))
		if bool(GameState.try_breakthrough(kind, target_id)):
			_set_craft_feedback("돌파 완료 · +%d의 벽을 넘었다 — 다음 강화가 열립니다" % int(GameState.get_gear_enhancement_level(kind, target_id)))
		else:
			_set_craft_feedback("돌파 불가 · %s" % str(GameState.get_breakthrough_block_reason(kind, target_id)))
		_refresh_after_change()
		return
	if result.has("enhance_armor"):
		var base_id := str(result["enhance_armor"])
		var armor_parts: Dictionary = GameState.get_armor_enhancement_part_cost(base_id)
		var armor_parts_short := false
		for part_key in armor_parts:
			if _owned_resource(str(part_key)) < int(armor_parts[part_key]):
				armor_parts_short = true
		if armor_parts_short:
			_set_craft_feedback(_armor_enhance_failure_reason(base_id))
		elif bool(GameState.try_enhance_armor(base_id)):
			for part_key in armor_parts:
				_consume_resource(str(part_key), int(armor_parts[part_key]))
			GameState.save_persistent_state()
			_set_craft_feedback("강화 완료 · %s +%d" % [
				_equipment_display_name(base_id),
				int(GameState.get_armor_enhancement_level(base_id)),
			])
		else:
			_set_craft_feedback(_armor_enhance_failure_reason(base_id))
		_refresh_after_change()
		return
	if bool(result.get("enhance", false)):
		# 반환 bool을 버리고 무조건 "강화 완료"를 찍던 버그 — 고철이 모자라
		# 아무 일도 안 일어난 판에서도 성공 문구가 나왔다.
		# 부품은 GameState가 모른다(가방+창고 합산·가방 우선 소비는 작업대 규약).
		# 부족하면 고철을 건드리기 전에 멈추고, 성공했을 때만 부품을 태운다.
		var enhance_weapon_id := _enhance_weapon_id(recipe)
		var enhance_parts: Dictionary = GameState.get_weapon_enhancement_part_cost(enhance_weapon_id)
		var parts_short := false
		for part_key in enhance_parts:
			if _owned_resource(str(part_key)) < int(enhance_parts[part_key]):
				parts_short = true
		if parts_short:
			_set_craft_feedback(_weapon_enhance_failure_reason(enhance_weapon_id))
		elif GameState.try_enhance_weapon(enhance_weapon_id):
			for part_key in enhance_parts:
				_consume_resource(str(part_key), int(enhance_parts[part_key]))
			GameState.save_persistent_state()
			_set_craft_feedback("강화 완료 · %s +%d" % [
				_gear_short_name("weapon", enhance_weapon_id),
				GameState.get_weapon_enhancement_level(enhance_weapon_id),
			])
		else:
			_set_craft_feedback(_weapon_enhance_failure_reason(enhance_weapon_id))
		_refresh_after_change()
		return
	if result.has("enhance_mod"):
		var enhance_mod_id := str(result["enhance_mod"])
		if GameState.try_enhance_mod(enhance_mod_id):
			_set_craft_feedback("파츠 강화 완료 · +%d" % GameState.get_mod_enhancement_level(enhance_mod_id))
		else:
			_set_craft_feedback(_mod_enhance_failure_reason(enhance_mod_id))
		_refresh_after_change()
		return
	var cost: Dictionary = _effective_cost(recipe)
	for key in cost.keys():
		_consume_resource(str(key), int(cost[key]))
	if result.has("component"):
		GameState.add_mod_component(str(result["component"]), int(result.get("amount", 1)))
	elif result.has("weapon_mod"):
		GameState.add_weapon_mod(str(result["weapon_mod"]), int(result.get("amount", 1)))
	elif result.has("ammo"):
		var ammo_id := str(result["ammo"])
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + int(result.get("amount", 1)))
	elif result.has("weapon"):
		GameState.add_weapon(str(result["weapon"]), int(result.get("amount", 1)))
	elif result.has("equipment"):
		# 제작품은 항상 기본 레벨(접미사 없음 = Lv.1)이다. 성장은 +99 강화가 맡는다.
		GameState.add_equipment(str(result["equipment"]), int(result.get("amount", 1)))
	elif result.has("heavy_gear"):
		# 중장비 — 소모성 화력. 지급은 GameState.add_heavy_gear(가방 원장).
		GameState.add_heavy_gear(str(result["heavy_gear"]), int(result.get("amount", 1)))
	elif result.has("canned_food"):
		GameState.canned_food += int(result["canned_food"])
	elif result.has("repair"):
		GameState.weapon_durability = minf(100.0, GameState.weapon_durability + float(result["repair"]))
	GameState.save_persistent_state()
	var transfer_notice := GameState.take_weapon_enhancement_transfer_notice()
	if transfer_notice.is_empty():
		transfer_notice = GameState.take_armor_enhancement_transfer_notice()
	if transfer_notice.is_empty():
		_set_craft_feedback("제작 완료 · %s" % str(recipe.get("name", "")))
	else:
		# 사다리 상위 무기 첫 제작 — 강화 이관 결과를 완료 문구에 붙인다.
		_set_craft_feedback("제작 완료 · %s · %s" % [str(recipe.get("name", "")), transfer_notice])
	_refresh_after_change()


func _set_craft_feedback(message: String) -> void:
	craft_feedback_text = message
	craft_feedback_until_msec = Time.get_ticks_msec() + 3000


# ── 실패 사유 ────────────────────────────────────────────────
# GameState의 try_* 는 bool만 돌려준다. "왜 안 됐는지"는 같은 조건을 여기서
# 다시 읽어 만든다. 사유 없는 실패는 유저에게 버튼 고장으로 읽힌다.
func _shortage_text(key: String, cost: int) -> String:
	return "%s %s 부족" % [
		_resource_name(key),
		GameState.format_compact_number(maxi(0, cost - _owned_resource(key))),
	]


func _workbench_upgrade_failure_reason() -> String:
	if GameState.shelter_workbench_level >= 5:
		return "작업대가 이미 최고 레벨(Lv.5)입니다."
	var cost := GameState.get_workbench_upgrade_cost()
	for key in cost.keys():
		var need := int(cost[key])
		if _owned_resource(str(key)) < need:
			return "작업대 확장 불가 · %s" % _shortage_text(str(key), need)
	return "작업대를 지금 확장할 수 없습니다."


func _enhance_weapon_id(recipe: Dictionary) -> String:
	# 보드는 보유 무기 전부를 강화한다(result.weapon_id). 옛 장착 무기 행은 장착 무기.
	return str((recipe.get("result", {}) as Dictionary).get("weapon_id", GameState.equipped_weapon_id))


func _weapon_enhance_failure_reason(weapon_id: String = "") -> String:
	if weapon_id.is_empty():
		weapon_id = str(GameState.equipped_weapon_id)
	if weapon_id.is_empty() or GameState.get_weapon_count(weapon_id) <= 0:
		return "강화 불가 · 보유하지 않은 무기입니다."
	if GameState.get_weapon_enhancement_level(weapon_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
		return "강화 불가 · 이미 최고 강화 단계입니다."
	if bool(GameState.is_breakthrough_required("weapon", weapon_id)):
		return "강화 불가 · +%d 돌파 필요([돌파] 버튼 · 고철 ×3)" % GameState.get_weapon_enhancement_level(weapon_id)
	var cost := GameState.get_weapon_enhancement_cost(weapon_id)
	if GameState.scrap < cost:
		return "강화 불가 · %s" % _shortage_text("scrap", cost)
	var part_cost: Dictionary = GameState.get_weapon_enhancement_part_cost(weapon_id)
	for part_key in part_cost:
		if _owned_resource(str(part_key)) < int(part_cost[part_key]):
			return "강화 불가 · %s (필드에서 구해 오는 부품)" % _shortage_text(str(part_key), int(part_cost[part_key]))
	return "강화에 실패했습니다."


func _armor_enhance_failure_reason(base_id: String) -> String:
	if not bool(GameState.is_armor_base_owned(base_id)):
		return "강화 불가 · 보유하지 않은 방어구입니다."
	if GameState.get_armor_enhancement_level(base_id) >= GameState.MAX_ARMOR_ENHANCEMENT:
		return "강화 불가 · 이미 최고 강화 단계입니다."
	if bool(GameState.is_breakthrough_required("armor", base_id)):
		return "강화 불가 · +%d 돌파 필요([돌파] 버튼 · 고철 ×3)" % GameState.get_armor_enhancement_level(base_id)
	var cost := int(GameState.get_armor_enhancement_cost(base_id))
	if GameState.scrap < cost:
		return "강화 불가 · %s" % _shortage_text("scrap", cost)
	var part_cost: Dictionary = GameState.get_armor_enhancement_part_cost(base_id)
	for part_key in part_cost:
		if _owned_resource(str(part_key)) < int(part_cost[part_key]):
			return "강화 불가 · %s (필드에서 구해 오는 부품)" % _shortage_text(str(part_key), int(part_cost[part_key]))
	return "강화에 실패했습니다."


func _mod_enhance_failure_reason(mod_id: String) -> String:
	if not GameState.equipped_weapon_mods.has(mod_id):
		return "파츠 강화 불가 · 해당 부착물을 장착하지 않았습니다."
	if GameState.get_mod_enhancement_level(mod_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
		return "파츠 강화 불가 · 이미 최고 강화 단계입니다."
	var cost := GameState.get_mod_enhancement_cost(mod_id)
	if GameState.scrap < cost:
		return "파츠 강화 불가 · %s" % _shortage_text("scrap", cost)
	return "파츠 강화에 실패했습니다."


func _largest_shortage_text(recipe: Dictionary) -> String:
	# "재료 부족"만으로는 무엇을 더 주워 와야 하는지 알 수 없다. 가장 많이
	# 모자란 재료 하나만 병기해 다음 출정의 목표로 만든다.
	var cost := _effective_cost(recipe)
	var worst_key := ""
	var worst_gap := 0
	for key in cost.keys():
		var gap := int(cost[key]) - _owned_resource(str(key))
		if gap > worst_gap:
			worst_gap = gap
			worst_key = str(key)
	if worst_key.is_empty():
		return ""
	return "%s %s 부족" % [
		_resource_name(worst_key), GameState.format_compact_number(worst_gap)
	]


func _blueprint_hint_text(recipe_id: String) -> String:
	# 설계도 조각이 어디서 나오는지까지 말해 준다 — 조각은 그 존 가족의 엘리트·보스·
	# 봉인 상자·일반 적(소량)에서 나온다. 모르면 영원히 잠긴 줄로 읽힌다.
	return "%s · %s에서 나옵니다" % [str(GameState.get_blueprint_progress_text(recipe_id)), _blueprint_source_text(recipe_id)]


func _blueprint_source_text(recipe_id: String) -> String:
	# "을지로 지하구역 엘리트·보스·봉인 상자[ · <존> 메인 미션 n단계]" — 보드 카드와 목록 부제가 같이 쓴다.
	var zone_name := ""
	for stage_value in LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE.keys():
		if (LOOT_ECONOMY.BLUEPRINT_SHARD_ZONE_TABLE[stage_value] as Array).has(recipe_id):
			for zone_id in GameState.RAID_ZONES.keys():
				if int((GameState.RAID_ZONES[zone_id] as Dictionary).get("stage_tier", 0)) == int(stage_value):
					zone_name = str((GameState.RAID_ZONES[zone_id] as Dictionary).get("name", ""))
					break
			break
	# 메인 미션 보상에 조각이 들어 있으면 그 단계도 가리킨다(카탈로그가 유일한 진실).
	var mission_source: Dictionary = SHELTER_REQUISITION.get_key_item_source(
		LOOT_ECONOMY.blueprint_shard_item_id(recipe_id)
	)
	var source := "%s 엘리트·보스·봉인 상자" % zone_name if not zone_name.is_empty() else "엘리트·보스·봉인 상자"
	if not mission_source.is_empty():
		var mission_zone := str(GameState.get_raid_zone(str(mission_source.get("zone_id", ""))).get("name", ""))
		source += " · %s 메인 미션 %d단계" % [mission_zone, int(mission_source.get("stage_index", 0)) + 1]
	return source


func get_craftable_count() -> int:
	# 운영 독 배지용 — 지금 당장 만들 수 있는 레시피 수.
	# "mods"는 UI에서 폐지된 카테고리(별도 재설계 예정) — 만들 수 없는 것을 세지 않는다.
	var count := 0
	for category in RECIPES.keys():
		if str(category) == "mods":
			continue
		for recipe_raw in _recipes_for_category(str(category)):
			if _can_craft(recipe_raw as Dictionary):
				count += 1
	return count


func _effective_cost(recipe: Dictionary) -> Dictionary:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("workbench_upgrade", false)):
		return GameState.get_workbench_upgrade_cost()
	if result.has("breakthrough"):
		var target := result["breakthrough"] as Dictionary
		return (GameState.get_breakthrough_cost(str(target.get("kind", "")), str(target.get("id", ""))) as Dictionary).duplicate(true)
	if result.has("enhance_armor"):
		var base_id := str(result["enhance_armor"])
		var armor_cost := {"scrap": int(GameState.get_armor_enhancement_cost(base_id))}
		var armor_parts: Dictionary = GameState.get_armor_enhancement_part_cost(base_id)
		for part_key in armor_parts:
			armor_cost[part_key] = int(armor_parts[part_key])
		return armor_cost
	if bool(result.get("enhance", false)):
		# 고단계 강화는 필드 부품도 든다 — 비용 줄·가능 판정·부족 사유가 전부
		# 이 딕셔너리를 보므로 여기서 합쳐 주면 UI가 따로 알 필요가 없다.
		var cost_weapon_id := _enhance_weapon_id(recipe)
		var enhance_cost := {"scrap": GameState.get_weapon_enhancement_cost(cost_weapon_id)}
		var part_cost: Dictionary = GameState.get_weapon_enhancement_part_cost(cost_weapon_id)
		for part_key in part_cost:
			enhance_cost[part_key] = int(part_cost[part_key])
		return enhance_cost
	if result.has("enhance_mod"):
		return {"scrap": GameState.get_mod_enhancement_cost(str(result["enhance_mod"]))}
	return (recipe.get("cost", {}) as Dictionary).duplicate(true)


func _refresh_after_change() -> void:
	# [가능한 만큼] 반복 중엔 끝에 한 번만 그린다.
	if batch_refresh_depth > 0:
		return
	_refresh_header_resources()
	_refresh_wallet()
	if is_instance_valid(enhance_board):
		_refresh_enhance_board()
	else:
		_refresh_tab_badges()
	_refresh_recipe_list()
	_refresh_detail_panel()


func _refresh_header_resources() -> void:
	for key_value in resource_value_labels.keys():
		var key := str(key_value)
		var value_label := resource_value_labels.get(key) as Label
		if is_instance_valid(value_label):
			value_label.text = "x%s" % GameState.format_compact_number(_owned_resource(key))
			# 수치가 길어져도 ELLIPSIS로 잘리지 않게 최소 폭을 다시 잰다.
			var font := value_label.get_theme_font("font")
			if font != null:
				value_label.custom_minimum_size.x = ceilf(font.get_string_size(
					value_label.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					value_label.get_theme_font_size("font_size")
				).x) + 2.0


func _owned_resource(key: String) -> int:
	# 보유 = 가방 + 창고. 복귀 정산이 재료를 창고로 보내는데 제작대가 가방만
	# 본다면, 매번 창고에서 꺼내 오는 심부름이 제작의 전부가 된다(유저 요구).
	return _bag_resource(key) + _stored_resource(key)


func _bag_resource(key: String) -> int:
	match key:
		"scrap":
			return GameState.scrap
		"rubber_gasket", "scope_lens", "magazine_spring", "precision_gear", "military_alloy":
			return GameState.get_mod_component_count(key)
		"artisan_seal":
			return maxi(0, int(GameState.progression_item_inventory.get(key, 0)))
		"catnip":
			return GameState.catnip
	return 0


func _stored_resource(key: String) -> int:
	match key:
		"rubber_gasket", "scope_lens", "magazine_spring", "precision_gear", "military_alloy":
			return GameState.get_stored_storage_count("component", key)
		"artisan_seal":
			return GameState.get_stored_storage_count("progression", key)
	return 0


func _consume_resource(key: String, amount: int) -> void:
	# 가방 몫을 먼저 태우고, 모자란 만큼만 창고에서 덜어낸다.
	var remaining := maxi(0, amount)
	match key:
		"scrap":
			GameState.scrap = maxi(0, GameState.scrap - remaining)
		"rubber_gasket", "scope_lens", "magazine_spring", "precision_gear", "military_alloy":
			GameState.consume_owned_component(key, remaining)
		"artisan_seal":
			GameState.consume_progression_item(key, remaining)
		"catnip":
			GameState.catnip = maxi(0, GameState.catnip - remaining)


func _is_recipe_locked(recipe: Dictionary) -> bool:
	# 잠금(티어·작업대·설계도 조각)과 단순 재료 부족은 다른 상태다. 전자는 회색으로
	# "아직 네 차례가 아니다", 후자는 주황으로 "조금만 더 모으면 된다"를 말한다.
	# 보유 중인 장비(제작됨·영구 보유)도 회색 — 다시 만들 수 없다.
	if GameState.shelter_tier < int(recipe.get("required_tier", 1)):
		return true
	if GameState.shelter_workbench_level < int(recipe.get("required_workbench", 1)):
		return true
	if _is_gear_recipe_owned(recipe):
		return true
	return not _has_required_blueprint(recipe)


func _has_required_blueprint(recipe: Dictionary) -> bool:
	# 장비 레시피(gear_id)는 설계도 조각 3/3이 해금 조건. 그 외(개조품·보급)는 항상 열림.
	var gear_id := str(recipe.get("gear_id", ""))
	if gear_id.is_empty():
		return true
	return bool(GameState.is_blueprint_unlocked(gear_id))


func _recipe_state_color(recipe: Dictionary) -> Color:
	if _is_recipe_locked(recipe):
		return STATE_COLOR_LOCKED
	if _can_craft(recipe):
		return STATE_COLOR_READY
	return STATE_COLOR_SHORT


func _recipe_list_subtitle(recipe: Dictionary) -> String:
	var gear_id := str(recipe.get("gear_id", ""))
	if _is_gear_recipe_owned(recipe):
		return "제작됨 · 영구 보유"
	if not _has_required_blueprint(recipe):
		# "설계도 조각 n/3 · <존> 엘리트·보스·봉인 상자에서 나옵니다" — 조각 수와 출처만, 접두사 중복 없이.
		return _blueprint_hint_text(gear_id)
	var required_tier := int(recipe.get("required_tier", 1))
	if GameState.shelter_tier < required_tier:
		return "쉘터 Tier %d 필요" % required_tier
	var required_workbench := int(recipe.get("required_workbench", 1))
	if GameState.shelter_workbench_level < required_workbench:
		return "작업대 Lv.%d 필요" % required_workbench
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		if GameState.workbench_repair_active:
			return "수리 진행 중"
		return "수리 가능" if GameState.weapon_durability < 100.0 else "수리 불필요"
	# 강화 계열은 재료가 아니라 단계 상한·돌파에 걸리는 경우가 따로 있다.
	if bool(result.get("enhance", false)):
		var subtitle_weapon_id := _enhance_weapon_id(recipe)
		if subtitle_weapon_id.is_empty() or GameState.get_weapon_count(subtitle_weapon_id) <= 0:
			return "보유한 무기 없음"
		if GameState.get_weapon_enhancement_level(subtitle_weapon_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
			return "최고 강화 단계"
		if bool(GameState.is_breakthrough_required("weapon", subtitle_weapon_id)):
			return "돌파 필요 · 강화 보드 [돌파]"
	if result.has("enhance_armor"):
		var base_id := str(result["enhance_armor"])
		if GameState.get_armor_enhancement_level(base_id) >= GameState.MAX_ARMOR_ENHANCEMENT:
			return "최고 강화 단계"
		if bool(GameState.is_breakthrough_required("armor", base_id)):
			return "돌파 필요 · 강화 보드 [돌파]"
	if result.has("breakthrough"):
		var target := result["breakthrough"] as Dictionary
		var kind := str(target.get("kind", ""))
		var target_id := str(target.get("id", ""))
		if not bool(GameState.is_breakthrough_required(kind, target_id)):
			return "돌파 단계 아님 · 현재 +%d (다음 돌파 +%d)" % [
				int(GameState.get_gear_enhancement_level(kind, target_id)),
				(int(GameState.get_gear_enhancement_level(kind, target_id)) / GameState.BREAKTHROUGH_STEP + 1) * GameState.BREAKTHROUGH_STEP,
			]
		var block := str(GameState.get_breakthrough_block_reason(kind, target_id))
		return "돌파 가능" if block.is_empty() else block
	if result.has("enhance_mod"):
		var subtitle_mod_id := str(result["enhance_mod"])
		if not GameState.equipped_weapon_mods.has(subtitle_mod_id):
			return "해당 부착물 미장착"
		if GameState.get_mod_enhancement_level(subtitle_mod_id) >= GameState.MAX_WEAPON_ENHANCEMENT:
			return "최고 강화 단계"
	# "재료 부족"에는 가장 많이 모자란 재료 하나를 병기한다.
	var shortage := _largest_shortage_text(recipe)
	var short_label := "재료 부족" if shortage.is_empty() else "재료 부족 · %s" % shortage
	if bool(result.get("workbench_upgrade", false)):
		return "최고 레벨" if GameState.shelter_workbench_level >= 5 else ("확장 가능" if _can_craft(recipe) else short_label)
	return "제작 가능" if _can_craft(recipe) else short_label


func _result_text(recipe: Dictionary) -> String:
	var result: Dictionary = recipe.get("result", {})
	if result.has("component"):
		return "%s x%d" % [_resource_name(str(result["component"])), int(result.get("amount", 1))]
	if result.has("weapon_mod"):
		var mod_id := str(result["weapon_mod"])
		return "%s x%d" % [
			str(WeaponSystem.get_mod(mod_id).get("display_name", mod_id)),
			int(result.get("amount", 1)),
		]
	if result.has("ammo"):
		return "%s x%d" % [_resource_name(str(result["ammo"])), int(result.get("amount", 1))]
	if result.has("weapon"):
		return "%s x%d" % [_resource_name(str(result["weapon"])), int(result.get("amount", 1))]
	if result.has("equipment"):
		return "%s x%d" % [
			_equipment_display_name(str(result["equipment"])),
			int(result.get("amount", 1)),
		]
	if result.has("heavy_gear"):
		var heavy_id := str(result["heavy_gear"])
		var heavy_definition := GameState.HEAVY_GEAR_DEFS.get(heavy_id, {}) as Dictionary
		return "%s x%d" % [str(heavy_definition.get("name", heavy_id)), int(result.get("amount", 1))]
	if result.has("canned_food"):
		return "통조림 x%d" % int(result["canned_food"])
	if result.has("repair"):
		return "내구도 +%d%%" % int(result["repair"])
	if bool(result.get("auto_repair", false)):
		return (
			"수리 진행 중 · 시간당 %.0f%%"
			% GameState.get_workbench_repair_per_hour()
			if GameState.workbench_repair_active
			else "시간당 내구도 %.0f%% 회복" % GameState.get_workbench_repair_per_hour()
		)
	if bool(result.get("workbench_upgrade", false)):
		return (
			"최고 레벨"
			if GameState.shelter_workbench_level >= 5
			else "작업대 Lv.%d" % (GameState.shelter_workbench_level + 1)
		)
	if result.has("breakthrough"):
		var target := result["breakthrough"] as Dictionary
		return "+%d 돌파 → 다음 강화 해금" % int(GameState.get_gear_enhancement_level(str(target.get("kind", "")), str(target.get("id", ""))))
	if result.has("enhance_armor"):
		var base_id := str(result["enhance_armor"])
		return "%s +%d" % [_equipment_display_name(base_id), GameState.get_armor_enhancement_level(base_id) + 1]
	if result.has("enhance"):
		return "%s +1" % _gear_short_name("weapon", _enhance_weapon_id(recipe))
	if result.has("enhance_mod"):
		var mod_id := str(result["enhance_mod"])
		return "%s +%d" % [str(WeaponSystem.get_mod(mod_id).get("display_name", mod_id)), GameState.get_mod_enhancement_level(mod_id) + 1]
	return "-"


func _recipe_icon(recipe: Dictionary) -> Texture2D:
	var result: Dictionary = recipe.get("result", {})
	if result.has("weapon"):
		var weapon_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(str(result["weapon"]))
		return weapon_texture if weapon_texture != null else UI_ICONS.get_icon("weapon", 72, Color("#d5ddd8"))
	if result.has("ammo"):
		return AMMO_TEXTURE
	if result.has("component"):
		return _resource_icon(str(result["component"]))
	if result.has("equipment"):
		var equipment_texture := _equipment_texture(str(result["equipment"]))
		if equipment_texture != null:
			return equipment_texture
		return UI_ICONS.get_icon("armor", 72, Color("#a8c6bb"))
	if result.has("weapon_mod"):
		return UI_ICONS.get_icon("mod", 72, Color("#e2a962"))
	if result.has("heavy_gear"):
		# ui_icon_factory 실제 키: 지뢰=alert(경보 삼각), 포탑=parts(부품), 로켓=raid(출격
		# 화살), 드론=dash(기동), 카트=backpack(적재 동반 기물 — 지금은 정산 보너스).
		var heavy_icon: String = str({
			"field_mine": "alert",
			"salvage_turret": "parts",
			"rocket_launcher": "raid",
			"escort_drone": "dash",
			"supply_cart": "backpack",
			"strike_drone": "raid",
		}.get(str(result["heavy_gear"]), "parts"))
		return UI_ICONS.get_icon(heavy_icon, 72, Color("#7fd8c8"))
	if result.has("canned_food"):
		return UI_ICONS.get_icon("food", 72, Color("#e6b65c"))
	if result.has("repair"):
		return UI_ICONS.get_icon("repair", 72, Color("#82c7ba"))
	if bool(result.get("auto_repair", false)):
		return UI_ICONS.get_icon("time", 72, Color("#82c7ba"))
	if bool(result.get("workbench_upgrade", false)):
		return UI_ICONS.get_icon("upgrade", 72, Color("#e2c06b"))
	if result.has("breakthrough"):
		return UI_ICONS.get_icon("craft", 72, Color("#e2c06b"))
	if result.has("enhance_armor"):
		var armor_texture := _equipment_texture(str(result["enhance_armor"]))
		return armor_texture if armor_texture != null else UI_ICONS.get_icon("armor", 72, Color("#a8c6bb"))
	if result.has("enhance"):
		return UI_ICONS.get_icon("upgrade", 72, Color("#e2c06b"))
	if result.has("enhance_mod"):
		return UI_ICONS.get_icon("mod", 72, Color("#e2a962"))
	return UI_ICONS.get_icon("all", 72, Color("#8ca29a"))


func _craft_action_text(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return "수리 진행 중" if GameState.workbench_repair_active else "자동 수리 맡기기"
	if bool(result.get("workbench_upgrade", false)):
		return "최고 레벨" if GameState.shelter_workbench_level >= 5 else "시설 업그레이드"
	return "제작"


func _craft_action_icon(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if bool(result.get("auto_repair", false)):
		return "time"
	if bool(result.get("workbench_upgrade", false)):
		return "upgrade"
	return "craft"


func _resource_icon(key: String) -> Texture2D:
	match key:
		"scope_lens": return SCOPE_LENS_TEXTURE
		"rubber_gasket": return RUBBER_GASKET_TEXTURE
		"magazine_spring": return MAGAZINE_SPRING_TEXTURE
		"precision_gear": return UI_ICONS.get_icon("upgrade", 48, Color("#e8d27a"))
		"military_alloy": return UI_ICONS.get_icon("secure", 48, Color("#9fc3e0"))
		"artisan_seal": return UI_ICONS.get_icon("craft", 48, Color("#e2c06b"))
		"762_fmj", "9mm_fmj", "12g_buckshot": return AMMO_TEXTURE
		"scrap": return UI_ICONS.get_icon("scrap", 48, Color("#b9c4c2"))
		# 캣닢이 빠져 있어 기본값(통조림 그림)이 나왔다. 이름을 떼는 이상 아이콘이 틀리면 안 된다.
		"catnip": return UI_ICONS.get_icon("catnip", 48, Color("#91d46f"))
		"canned_food": return UI_ICONS.get_icon("food", 48, Color("#e6b65c"))
		"churu": return UI_ICONS.get_icon("churu", 48, Color("#e9a66e"))
	return UI_ICONS.get_icon("resource", 48, Color("#9ab4aa"))


func _resource_accent(key: String) -> Color:
	match key:
		"scrap": return Color("#b9c4c2")
		"canned_food": return Color("#efbd66")
		"scope_lens": return Color("#73c5db")
		"rubber_gasket": return Color("#c59b72")
		"magazine_spring": return Color("#d0b16b")
		"precision_gear": return Color("#e8d27a")
		"military_alloy": return Color("#9fc3e0")
	return Color("#9ab4aa")


func _resource_row(key: String, owned: int, needed: int, color: Color) -> Control:
	# 강화 보드의 WELL 행 문법. 재화(고철·캣닢)는 아이콘 + 수치만(이름은 툴팁),
	# 부품·재료는 아이콘만으로 못 알아보니 이름을 유지한다 — 제작은 부품을 쓰는 게 맞다.
	var well := PanelContainer.new()
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.clip_contents = true
	well.add_theme_stylebox_override("panel", _well_style())
	well.tooltip_text = "%s %s / %s" % [_resource_name(key), GameState.format_compact_number(owned), GameState.format_compact_number(needed)]
	var row := HBoxContainer.new()
	row.name = "ResourceCost_%s" % key
	row.custom_minimum_size = Vector2(0, 30)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	well.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.texture = _resource_icon(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_theme_constant_override("separation", 0)
	row.add_child(name_box)
	if not ICON_ONLY_RESOURCES.has(key):
		var name_label := _label(_resource_name(key), 13, TEXT)
		name_label.name = "ResourceName"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_box.add_child(name_label)
	# 어디에 있는 재료인지 밝힌다 — "창고에 있는데 왜 못 만드나"를 없앤다.
	var stored := _stored_resource(key)
	if stored > 0:
		var source_label := _label(
			"가방 %s + 창고 %s" % [
				GameState.format_compact_number(_bag_resource(key)),
				GameState.format_compact_number(stored),
			],
			11,
			FAINT
		)
		source_label.name = "ResourceSource"
		source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_box.add_child(source_label)
	# 충족 여부는 체크 표시로 한눈에. 모자란 줄만 붉게 남는다.
	var amount_label := _label("%s / %s  %s" % [
		GameState.format_compact_number(owned),
		GameState.format_compact_number(needed),
		"✓" if owned >= needed else "✗",
	], 14, color)
	amount_label.name = "ResourceAmount"
	amount_label.custom_minimum_size = Vector2(132, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if ICON_ONLY_RESOURCES.has(key) else Control.SIZE_FILL
	row.add_child(amount_label)
	HudFx.attach_text_glow(amount_label, color, 0.5)
	return well


func _equipment_display_name(equipment_id: String) -> String:
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	if definition.is_empty():
		return equipment_id
	return str(definition.get("display_name", equipment_id))


func _equipment_texture(equipment_id: String) -> Texture2D:
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	var path := str(definition.get("texture_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _equipment_stat_line(equipment_id: String) -> String:
	# 방어구는 숫자로 고르는 물건이다. 이름만 보여 주면 무엇이 나은지 모른다.
	var definition: Dictionary = GameState.get_equipment_definition(equipment_id)
	if definition.is_empty():
		return ""
	var parts: PackedStringArray = []
	if definition.has("damage_reduction"):
		parts.append("피해감소 %d%%" % roundi(float(definition["damage_reduction"]) * 100.0))
	if definition.has("move_speed_bonus"):
		parts.append("이동 +%d%%" % roundi(float(definition["move_speed_bonus"]) * 100.0))
	if definition.has("stamina_cost_multiplier"):
		parts.append(
			"스태미나 소모 -%d%%"
			% roundi((1.0 - float(definition["stamina_cost_multiplier"])) * 100.0)
		)
	if definition.has("visibility_multiplier"):
		parts.append("피탐지 +%d%%" % roundi((float(definition["visibility_multiplier"]) - 1.0) * 100.0))
	return " · ".join(parts)


func _build_result_preview(recipe: Dictionary) -> Control:
	# 제작 버튼 위 결과물 미리보기 — "뭘 만드는 건지"를 버튼 누르기 전에 본다.
	var card := PanelContainer.new()
	card.name = "WorkbenchResultPreview"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 강화 카드 헤드의 WELL + 골드 라인 문법.
	card.add_theme_stylebox_override("panel", _well_style(HudStyle.LINE_GOLD))
	var margin := _margin(12, 10, 12, 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.name = "ResultPreviewIcon"
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = _recipe_icon(recipe)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var name_label := _label(_result_text(recipe), 16, GOLD_TEXT)
	name_label.name = "ResultPreviewName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	HudFx.attach_text_glow(name_label, GOLD, 0.6)
	var stat_line := _result_stat_line(recipe)
	if not stat_line.is_empty():
		var stat_label := _label(stat_line, 12, DIM)
		stat_label.name = "ResultPreviewStats"
		# 이관 안내가 둘째 줄로 붙는다(\n) — 줄바꿈은 살리고 가로만 자른다.
		stat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_box.add_child(stat_label)
	return card


func _enhancement_transfer_preview(weapon_id: String) -> String:
	# 사다리 상위 무기의 결과 미리보기 한 줄 — "AK-47 +10 → AKM +6 (강화 60% 이관)".
	# 이미 이관을 받은(또는 보유한) 무기는 비운다.
	if GameState.weapon_enhancement_transfers_done.has(weapon_id):
		return ""
	var lower_ids: Array[String] = WeaponSystem.get_lower_ladder_weapons(weapon_id)
	if lower_ids.is_empty():
		return ""
	var from_id := ""
	var from_level := 0
	for candidate_id in lower_ids:
		var level := GameState.get_weapon_enhancement_level(candidate_id)
		if level > from_level:
			from_level = level
			from_id = candidate_id
	if from_id.is_empty():
		return "첫 제작 시 하위 무기 강화 60% 이관"
	var transferred := int(floor(float(from_level) * WeaponSystem.ENHANCEMENT_TRANSFER_RATIO))
	return "첫 제작 시 %s +%d → %s +%d (강화 60%% 이관)" % [
		_resource_name(from_id).split(" ")[0], from_level, _resource_name(weapon_id).split(" ")[0], transferred,
	]


func _result_stat_line(recipe: Dictionary) -> String:
	var result := recipe.get("result", {}) as Dictionary
	if result.has("equipment"):
		return _equipment_stat_line(str(result["equipment"]))
	if result.has("weapon"):
		var weapon := WeaponSystem.get_weapon(str(result["weapon"])) as Dictionary
		if weapon.is_empty():
			return ""
		var interval := maxf(0.01, float(weapon.get("fire_interval", 0.2)))
		var line := "피해 %d · 탄창 %d · 연사 %.1f/s" % [
			int(weapon.get("damage", 0)),
			int(weapon.get("magazine_size", 0)),
			1.0 / interval,
		]
		var transfer_line := _enhancement_transfer_preview(str(result["weapon"]))
		if not transfer_line.is_empty():
			line += "\n" + transfer_line
		return line
	if result.has("weapon_mod"):
		var mod := WeaponSystem.get_mod(str(result["weapon_mod"])) as Dictionary
		return str(mod.get("slot", "")).to_upper() if not mod.is_empty() else ""
	if result.has("heavy_gear"):
		var heavy_id := str(result["heavy_gear"])
		var line := "현재 보유 x%d" % GameState.get_heavy_gear_count(heavy_id)
		if heavy_id == "rocket_launcher":
			line += " · 3발 쏘면 소멸"
		return line
	return ""


func _resource_name(key: String) -> String:
	match key:
		"scrap":
			return "고철"
		"catnip":
			return "캣닢"
		"scope_lens":
			return "스코프 렌즈"
		"rubber_gasket":
			return "고무 패킹"
		"magazine_spring":
			return "탄창 스프링"
		"precision_gear":
			return "정밀 기어"
		"military_alloy":
			return "군용 합금"
		"artisan_seal":
			return "장인의 인장"
		"762_fmj":
			return "7.62mm 보통탄"
		"9mm_fmj":
			return "9mm 보통탄"
		"12g_buckshot":
			return "12게이지 벅샷"
		"m1911":
			return "M1911 솜방망이"
		"mp5":
			return "MP5 하악이"
		"ak47":
			return "AK-47 캣라시니코프"
		"double_barrel":
			return "더블배럴 참치 헌터"
		"akm":
			return "AKM 개조형"
		"pump_shotgun":
			return "펌프 산탄총 하울러"
		"k2":
			return "K2 전투소총"
		"canned_food":
			return "통조림"
	# 방어구 ID는 장비 정의가 이름을 안다(레벨 접미사까지 해석한다).
	var equipment_definition: Dictionary = GameState.get_equipment_definition(key)
	if not equipment_definition.is_empty():
		return str(equipment_definition.get("display_name", key))
	return key


func _button(text: String, icon_name := "", accent := HudStyle.LINE_FOCUS) -> Button:
	# 스타일은 디자인 시스템이 정한다. 여기서는 내용(텍스트·아이콘)만.
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = UI_ICONS.get_icon(icon_name, 30, HudStyle.TEXT)
		# 대형 재화 PNG가 버튼 전체로 부풀지 않게 폭을 못 박는다.
		button.add_theme_constant_override("icon_max_width", 28)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return HudStyle.style_button(button, accent)


func _close_button() -> Button:
	var button := _button("", "close")
	button.name = "CloseButton"
	button.custom_minimum_size = Vector2(44, 44)
	button.icon = UI_ICONS.get_icon("close", 24, Color("#dce6df"))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.tooltip_text = "닫기"
	button.focus_mode = Control.FOCUS_NONE
	return button


func _fit_chip_text(chip: PanelContainer, resource_id: String) -> PanelContainer:
	# 자원 칩 이름 라벨은 ELLIPSIS라 최소 폭이 1px이다 — 옆의 수치 라벨이
	# EXPAND_FILL로 남는 폭을 다 먹으면 이름("스코프 렌즈" 등)이 통째로 사라진다.
	for label_name in ["ResourceName_%s" % resource_id, "ResourceValue_%s" % resource_id]:
		var label := chip.find_child(label_name, true, false) as Label
		if label == null:
			continue
		var font := label.get_theme_font("font")
		if font == null:
			continue
		label.custom_minimum_size.x = ceilf(font.get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label.get_theme_font_size("font_size")
		).x) + 2.0
	return chip


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _section(text: String) -> Label:
	# 강화 보드의 소제목("보유 장비 · 평생 귀속")과 같은 문법 — 11px DIM.
	var label := _label(text, 11, DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear(node: Node) -> void:
	# 떼어낸 뒤 지운다 — queue_free만 하면 같은 프레임에 같은 이름(WorkbenchGearRow_ak47 등)으로
	# 다시 만든 행이 "@이름@id"로 자동 개명돼 find_child·튜토리얼 타깃·프로브가 못 잡는다.
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 9
	style.content_margin_top = 8
	style.content_margin_right = 9
	style.content_margin_bottom = 8
	return style
