class_name RaidEventDirector
extends RefCounted

# 한 판에 "이야기"를 만드는 장치.
#
# 기존 긴장도는 순수하게 경과 시간만 봤다. 그래서 가만히 숨어 있어도, 총을
# 난사하며 금고를 털어도 3분째와 15분째가 똑같이 흘렀다. 이 디렉터는 긴장도의
# 입력을 플레이어의 행동으로 바꾼다. 도시는 시계가 아니라 플레이어에게 반응한다.
#
# 단계는 기존 raid_pressure_level 0~3을 그대로 쓴다(정찰/경계/추적/봉쇄).

const LEVEL_QUIET := 0
const LEVEL_ALERT := 1
const LEVEL_HUNT := 2
const LEVEL_LOCKDOWN := 3

# 단계 진입에 필요한 누적 압력.
const LEVEL_THRESHOLDS := [0.0, 120.0, 310.0, 560.0]

# 사건 사이 최소 간격. 레벨 상승 때만 터지면 조용한 판은 끝까지 심심하다.
# 압박이 높을수록 촘촘해진다.
const EVENT_INTERVAL_BY_LEVEL := [95.0, 80.0, 65.0, 52.0]


static func get_event_interval(level: int) -> float:
	return float(EVENT_INTERVAL_BY_LEVEL[clampi(level, 0, EVENT_INTERVAL_BY_LEVEL.size() - 1)])

# ── 압력 축적 계수 ─────────────────────────────────────────────
# 시간은 여전히 흐르지만 이제 가장 약한 입력이다. 소란을 피우면 훨씬 빨리 는다.
const PRESSURE_PER_SECOND := 0.62
const PRESSURE_PER_KILL := 22.0
const PRESSURE_PER_GUNSHOT := 2.2
const PRESSURE_PER_SUPPRESSED_GUNSHOT := 0.55
const PRESSURE_PER_LOOT_VALUE := 0.022
const PRESSURE_PER_ALARM := 45.0
# 웅크려 숨어 있으면 도시가 조금씩 잊는다. 잠입 플레이에 보상을 준다.
# 감쇠가 수동 축적(0.62/s)보다 크면 긴장도는 순수 배수 상태가 되어
# 공격적인 판에서도 레벨 0에 머문다(시뮬 실측). 감쇠는 축적보다 약간
# 낮게 — 조용해도 도시는 천천히 조여 온다.
const PRESSURE_DECAY_PER_SECOND := 0.55

# ── 사건 테이블 ────────────────────────────────────────────────
#
# 예전에는 사건마다 자기 타이머와 자기 상태 변수를 들고 있었다. 새 사건을
# 하나 추가하려면 main.gd에 스케줄러를 또 쓰는 구조였다.
#
# 이제 발동 판단은 전부 이 표가 한다. main.gd는 handler 이름으로 실행만
# 담당한다. 새 사건 = 여기 한 줄 + 핸들러 함수 하나.
#
#   min_level   이 긴장도 이상에서만 후보가 된다
#   weight      후보들 사이의 추첨 가중치
#   min_delay   판 시작 후 최소 경과 시간(초)
#   cooldown    같은 사건이 다시 뽑히기까지의 간격(초). 0이면 1회성
#   handler     main.gd의 처리 함수 이름
const EVENT_DEFINITIONS := {
	# ── 압박: 도시가 플레이어를 좁혀 온다 ──
	"patrol_sweep": {
		"title": "순찰대 소집",
		"body": "총성을 들은 약탈자들이 구역을 훑기 시작한다.",
		"min_level": LEVEL_ALERT,
		"weight": 3.0,
		"min_delay": 60.0,
		"cooldown": 150.0,
		"color": Color("#d0bd6b"),
		"handler": "_event_spawn_hostile_squad",
	},
	"hunter_pack": {
		"title": "추격조 투입",
		"body": "무장한 추격조가 냄새를 따라온다.",
		"min_level": LEVEL_HUNT,
		"weight": 3.0,
		"min_delay": 120.0,
		"cooldown": 180.0,
		"color": Color("#df8d52"),
		"handler": "_event_spawn_hostile_squad",
	},
	"sniper_watch": {
		"title": "고지 감시",
		"body": "높은 곳에서 누군가 이쪽을 보고 있다. 트인 길을 피해라.",
		"min_level": LEVEL_HUNT,
		"weight": 2.0,
		"min_delay": 150.0,
		"cooldown": 0.0,
		"color": Color("#c98fb0"),
		"handler": "_event_spawn_overwatch",
	},
	"extraction_seal": {
		"title": "탈출로 봉쇄",
		"body": "하수구 하나가 막혔다. 남은 경로로 움직여라.",
		"min_level": LEVEL_LOCKDOWN,
		"weight": 4.0,
		"min_delay": 180.0,
		"cooldown": 0.0,
		"color": Color("#e45d4e"),
		"handler": "_event_seal_extraction",
	},
	"curfew_horns": {
		"title": "통금 사이렌",
		"body": "구역 전체가 깨어났다. 조용히 움직여도 오래 못 숨는다.",
		"min_level": LEVEL_LOCKDOWN,
		"weight": 2.0,
		"min_delay": 240.0,
		"cooldown": 0.0,
		"color": Color("#e0714f"),
		"handler": "_event_curfew",
	},
	# ── 기회: 위험을 감수하면 얻는다 ──
	"supply_drop": {
		"title": "보급 낙하 감지",
		"body": "위험을 무릅쓰면 고가치 보급을 회수할 수 있다.",
		"min_level": LEVEL_ALERT,
		"weight": 2.5,
		"min_delay": 45.0,
		"cooldown": 210.0,
		"color": Color("#6fc4a4"),
		"handler": "_event_supply_drop",
	},
	"convoy_wreck": {
		"title": "수송대 추락",
		"body": "보급을 실은 수송대가 떨어졌다. 두 약탈 세력이 잔해를 두고 맞붙는다 — 승자가 굳기 전에 끼어들어라.",
		"min_level": LEVEL_QUIET,
		"weight": 3.0,
		"min_delay": 55.0,
		"cooldown": 0.0,
		"color": Color("#d8b45c"),
		"handler": "_event_convoy_wreck",
	},
	"scavenger_cache": {
		"title": "약탈자 은닉처 발각",
		"body": "누군가 모아 둔 물건을 찾았다. 주인이 돌아오기 전에.",
		"min_level": LEVEL_ALERT,
		"weight": 2.0,
		"min_delay": 90.0,
		"cooldown": 240.0,
		"color": Color("#8fbf7a"),
		"handler": "_event_scavenger_cache",
	},
	# ── 변화: 판의 규칙이 바뀐다 ──
	"blackout": {
		"title": "구역 정전",
		"body": "전력이 끊겼다. 시야가 좁아지지만 발소리도 묻힌다.",
		"min_level": LEVEL_HUNT,
		"weight": 2.5,
		"min_delay": 100.0,
		"cooldown": 0.0,
		"color": Color("#7f8fd4"),
		"handler": "_event_blackout",
	},
	"downpour": {
		"title": "폭우",
		"body": "빗소리가 발소리를 덮는다. 대신 멀리 보이지 않는다.",
		"min_level": LEVEL_QUIET,
		"weight": 1.5,
		"min_delay": 70.0,
		"cooldown": 0.0,
		"color": Color("#7fa8c4"),
		"handler": "_event_downpour",
	},
}


static func get_event(event_id: String) -> Dictionary:
	return (EVENT_DEFINITIONS.get(event_id, {}) as Dictionary).duplicate(true)


static func resolve_level(pressure: float) -> int:
	var level := 0
	for index in LEVEL_THRESHOLDS.size():
		if pressure >= float(LEVEL_THRESHOLDS[index]):
			level = index
	return level


static func get_level_progress(pressure: float) -> float:
	# 다음 단계까지 0~1. HUD 게이지용.
	var level := resolve_level(pressure)
	if level >= LEVEL_THRESHOLDS.size() - 1:
		return 1.0
	var current := float(LEVEL_THRESHOLDS[level])
	var next := float(LEVEL_THRESHOLDS[level + 1])
	return clampf((pressure - current) / maxf(1.0, next - current), 0.0, 1.0)


static func pick_event(
	level: int,
	elapsed_seconds: float,
	last_fired_at: Dictionary,
	random: RandomNumberGenerator
) -> String:
	# 자격을 갖춘 사건들 중 가중치 추첨. 쿨다운이 0이면 한 판에 한 번뿐이다.
	var candidates: Array[String] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	for event_id in EVENT_DEFINITIONS.keys():
		var key := str(event_id)
		var definition := EVENT_DEFINITIONS[key] as Dictionary
		if level < int(definition.get("min_level", LEVEL_QUIET)):
			continue
		if elapsed_seconds < float(definition.get("min_delay", 0.0)):
			continue
		if last_fired_at.has(key):
			var cooldown := float(definition.get("cooldown", 0.0))
			if cooldown <= 0.0:
				continue  # 1회성 사건
			if elapsed_seconds - float(last_fired_at[key]) < cooldown:
				continue
		var weight := maxf(0.01, float(definition.get("weight", 1.0)))
		candidates.append(key)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return ""
	var roll := random.randf() * total_weight
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates[candidates.size() - 1]


static func is_stealth_decay_allowed(seconds_since_noise: float) -> bool:
	# 마지막 소란 이후 충분히 조용했을 때만 압력이 식는다.
	return seconds_since_noise >= 12.0
