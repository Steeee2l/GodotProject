class_name FieldMissionCatalog
extends RefCounted

const BASIC_PARTS_TARGET := 2
const BASIC_PARTS_XP := 90
const BASIC_SUBWAY_XP := 120
const BASIC_SUBWAY_BOSS_XP := 260
const BASIC_SUBWAY_RETURN_XP := 180

const REQUIRED_TYPES := [
	"defense",
	"eliminate",
	"collect",
	"stealth",
	"investigate",
	"stealth_reach",
]

const TEMPLATES := [
	{
		"type": "defense",
		"title": "교차로 봉쇄선 방어",
		"description": "약탈대가 몰려온다. 나는 이 자리에서 버틴다.",
		"duration": 14.0,
		"enemy_count": 6,
		"reward": {"canned_food": 2, "ammo": 24},
	},
	{
		"type": "defense",
		"title": "비상 발전기 재가동",
		"description": "발전기가 다시 돌 때까지 나는 이 자리를 지킨다.",
		"duration": 12.0,
		"enemy_count": 6,
		"reward": {"medkits": 1, "ammo": 18},
	},
	{
		"type": "eliminate",
		"title": "약탈대 거점 소탕",
		"description": "약탈대가 이 구역을 차지했다. 나는 그들을 전부 처치한다.",
		"target_count": 3,
		"enemy_count": 5,
		"reward": {"canned_food": 2, "component": 1},
	},
	{
		"type": "eliminate",
		"title": "무장 정찰조 차단",
		"description": "정찰조가 무전을 치기 전에 나는 정찰조를 처치한다.",
		"target_count": 2,
		"enemy_count": 4,
		"reward": {"ammo": 30, "component": 1},
	},
	{
		"type": "collect",
		"title": "흩어진 보급 표식 회수",
		"description": "보급 표식 2개가 구역에 흩어져 있다. 나는 그것을 회수한다.",
		"target_count": 2,
		"enemy_count": 4,
		"reward": {"canned_food": 3, "ammo": 15},
	},
	{
		"type": "collect",
		"title": "통신 기록 수집",
		"description": "부서진 기록 장치 2개가 남아 있다. 나는 그것을 챙긴다.",
		"target_count": 2,
		"enemy_count": 4,
		"reward": {"medkits": 1, "component": 1},
	},
	{
		"type": "stealth",
		"title": "폐점포 잠복",
		"description": "수색대가 지나간다. 나는 폐점포 안에 숨어서 기다린다.",
		"duration": 10.0,
		"guard_count": 2,
		"detection_grace": 1.8,
		"silence_required": true,
		"reward": {"canned_food": 3, "medkits": 1},
	},
	{
		"type": "stealth",
		"title": "순찰대 통과 대기",
		"description": "순찰대가 지나간다. 나는 엄폐물 뒤에서 조용히 기다린다.",
		"duration": 12.0,
		"guard_count": 2,
		"detection_grace": 1.65,
		"silence_required": true,
		"reward": {"ammo": 32, "component": 1},
	},
	{
		"type": "investigate",
		"title": "실종자 흔적 조사",
		"description": "생존자가 흔적을 남겼다. 나는 흔적을 조사해서 생존자가 간 곳을 알아낸다.",
		"target_count": 2,
		"investigate_duration": 1.6,
		"guard_count": 1,
		"silence_required": false,
		"reward": {"canned_food": 3, "component": 1},
	},
	{
		"type": "investigate",
		"title": "감시 초소 기록 읽기",
		"description": "감시 초소에 기록이 남아 있다. 나는 들키지 않고 기록을 차례로 읽는다.",
		"target_count": 2,
		"investigate_duration": 1.8,
		"guard_count": 2,
		"detection_grace": 1.7,
		"silence_required": true,
		"reward": {"medkits": 1, "ammo": 24, "component": 1},
	},
	{
		"type": "stealth_reach",
		"title": "감시망 우회",
		"description": "반대편에 안전 지점이 있다. 나는 총을 쏘지 않고 순찰을 피해서 그곳까지 간다.",
		"target_distance": 32.0,
		"guard_count": 2,
		"detection_grace": 1.6,
		"silence_required": true,
		"reward": {"canned_food": 2, "ammo": 28},
	},
	# ── 확장 내용: 같은 6개 규칙을 쓰되 상황·보상을 다양하게 ──
	{
		"type": "defense",
		"title": "옥상 신호기 방어",
		"description": "옥상에서 구조 신호를 보내고 있다. 나는 신호가 끝날 때까지 옥상 진입로를 막는다.",
		"duration": 16.0,
		"enemy_count": 7,
		"reward": {"ammo": 30, "component": 1},
	},
	{
		"type": "eliminate",
		"title": "약탈대 지휘관 사냥",
		"description": "지휘관이 약탈대를 이끈다. 나는 지휘관과 호위대를 전부 처치한다.",
		"target_count": 3,
		"enemy_count": 6,
		"reward": {"component": 2, "ammo": 18},
	},
	{
		"type": "collect",
		"title": "의약품 상자 수거",
		"description": "의약품 상자가 남아 있다. 나는 약탈대가 가져가기 전에 상자를 챙긴다.",
		"target_count": 3,
		"enemy_count": 5,
		"reward": {"medkits": 2, "canned_food": 2},
	},
	{
		"type": "stealth",
		"title": "경비 교대 틈 노리기",
		"description": "경비 셋이 교대 중이다. 나는 교대가 끝날 때까지 경비의 눈에 띄지 않는다.",
		"duration": 11.0,
		"guard_count": 3,
		"detection_grace": 1.7,
		"silence_required": true,
		"reward": {"component": 1, "ammo": 20},
	},
	{
		"type": "investigate",
		"title": "수송 표식 추적",
		"description": "수송대가 지하로 내려가며 표식을 남겼다. 나는 표식을 차례로 조사한다.",
		"target_count": 3,
		"investigate_duration": 1.7,
		"guard_count": 2,
		"detection_grace": 1.75,
		"silence_required": true,
		"reward": {"component": 1, "canned_food": 3},
	},
	{
		"type": "stealth_reach",
		"title": "봉쇄선 침투",
		"description": "봉쇄선 안쪽에 목표 지점이 있다. 나는 총을 쏘지 않고 그곳까지 들어간다.",
		"target_distance": 38.0,
		"guard_count": 3,
		"detection_grace": 1.7,
		"silence_required": true,
		"reward": {"component": 1, "ammo": 24},
	},
]


static func build_basic_missions(story_stage: int) -> Array[Dictionary]:
	var missions: Array[Dictionary] = [get_basic_mission("parts")]
	match story_stage:
		0:
			missions.append(get_basic_mission("subway"))
		1:
			missions.append(get_basic_mission("subway_boss"))
		2:
			missions.append(get_basic_mission("subway_return"))
		_:
			missions.append(get_basic_mission("subway_complete"))
	return missions


static func get_basic_mission(mission_id: String) -> Dictionary:
	match mission_id:
		"parts":
			return _mission("parts", "기초 부품 확보", "나는 총기 개조 부품을 찾아서 챙긴다.", BASIC_PARTS_TARGET, BASIC_PARTS_XP)
		"subway":
			return _mission("subway", "지하철역 입구 조사", "지하철역 입구에서 포격 신호가 난다. 나는 신호를 확인한다.", 1, BASIC_SUBWAY_XP)
		"subway_boss":
			return _mission("subway_boss", "포격 신호의 주인 추적", "위험도가 50%를 넘으면 묘르가 나온다. 나는 묘르를 처치한다.", 1, BASIC_SUBWAY_BOSS_XP)
		"subway_return":
			return _mission("subway_return", "지하 보급로 봉쇄", "묘르가 지하철 통로를 썼다. 나는 그 통로를 확인한다.", 1, BASIC_SUBWAY_RETURN_XP)
		"subway_complete":
			var completed := _mission("subway_complete", "종로 지하선 확보", "연속 임무를 끝냈다.", 1, 0)
			completed["progress"] = 1
			completed["completed"] = true
			return completed
	return {}


static func pick_definition(index: int, random: RandomNumberGenerator) -> Dictionary:
	var required_type := str(REQUIRED_TYPES[index]) if index < REQUIRED_TYPES.size() else ""
	var candidates: Array[Dictionary] = []
	for template_value in TEMPLATES:
		var template := template_value as Dictionary
		if required_type.is_empty() or str(template.get("type", "")) == required_type:
			candidates.append(template)
	if candidates.is_empty():
		for template_value in TEMPLATES:
			candidates.append(template_value as Dictionary)
	return candidates[random.randi_range(0, candidates.size() - 1)].duplicate(true)


static func get_category(mission_type: String) -> String:
	match mission_type:
		"stealth":
			return "은신"
		"investigate":
			return "조사"
		"stealth_reach":
			return "우회"
		"defense":
			return "방어"
		"eliminate":
			return "제압"
		"collect":
			return "회수"
	return "현장"


static func build_rules(mission_type: String, silence_required: bool, fail_radius: float) -> String:
	var rules: Array[String] = ["작전 중심에서 %.0fm 이상 이탈 시 실패" % fail_radius]
	if silence_required:
		rules.append("총성 발생 시 실패")
	if mission_type in ["stealth", "stealth_reach"]:
		rules.append("적에게 발각되면 실패")
	elif mission_type == "investigate" and silence_required:
		rules.append("조사 중 발각되면 실패")
	return " / ".join(rules)


static func format_reward(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"canned_food": "통조림",
		"medkits": "구급약",
		"ammo": "탄약",
		"component": "총기 부품",
	}
	for key in ["canned_food", "medkits", "ammo", "component"]:
		var amount := maxi(0, int(reward.get(key, 0)))
		if amount > 0:
			parts.append("%s %d" % [str(labels[key]), amount])
	return " / ".join(parts) if not parts.is_empty() else "현장 보급품"


static func get_basic_mission_lines(missions: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for mission in missions:
		if bool(mission.get("completed", false)):
			continue
		lines.append("%s %d/%d" % [
			str(mission.get("title", "기본 목표")),
			int(mission.get("progress", 0)),
			maxi(1, int(mission.get("target", 1))),
		])
	return lines


static func _mission(
	id: String,
	title: String,
	detail: String,
	target: int,
	xp: int
) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"detail": detail,
		"progress": 0,
		"target": target,
		"xp": xp,
		"completed": false,
	}
