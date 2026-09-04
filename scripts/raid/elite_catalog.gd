extends RefCounted

# 엘리트 카탈로그(2026-09-03 유저: "강적. 엘리트라고 부르자. 덩치 약간 크고,
# 위에 이름을 빨갛게, 더 강하고 대미지도 세게, 스테이지별로 잘 배치, 이름도 잘").
#
# 존 단계(stage_tier 1~5)마다 이름 있는 엘리트 풀이 있다. 판마다 풀에서
# 겹치지 않게 뽑아 배치한다. 스탯 배율은 단계가 오를수록 커진다(플레이어
# 장비 참조 금지 — 존 단계만 본다).
#
# 대사(barks)는 enemy_chatter가 상황별로 꺼내 쓴다: engage(발각), hit(피격),
# reload(재장전), ally_down(동료 사망). 없으면 공용 전투 대사로 떨어진다.

const ELITE_NAME_COLOR := Color("#ff4b3a")

# 단계별 동시 배치 수.
const COUNT_BY_TIER := {1: 1, 2: 2, 3: 2, 4: 3, 5: 3}

# 단계별 호위 수(같은 분대로 붙는 일반 적).
const ESCORTS_BY_TIER := {1: 1, 2: 1, 3: 2, 4: 2, 5: 2}

const POOLS := {
	1: [
		{
			"id": "saw", "name": "쇠톱", "kind": "pistol", "weapon": "double_barrel",
			"health": 2.4, "damage": 1.6, "speed": 1.08, "scale": 1.24,
			"barks": {
				"engage": ["톱질 시작이다.", "가까이 와라. 두 발이면 끝난다."],
				"hit": ["그 정도로는 안 넘어간다.", "이가 갈린다."],
				"reload": ["두 발 더 넣는다. 도망갈 시간이다."],
				"ally_down": ["쓸모없는 놈들. 내가 한다."],
			},
		},
		{
			"id": "rust_fang", "name": "녹슨 이빨", "kind": "melee", "weapon": "",
			"health": 3.0, "damage": 1.7, "speed": 1.18, "scale": 1.26,
			"barks": {
				"engage": ["뛰어. 내가 더 빠르다.", "냄새 좋다, 고양이."],
				"hit": ["긁혔네. 더 해봐."],
				"ally_down": ["비켜. 내 먹이다."],
			},
		},
	],
	2: [
		{
			"id": "bolt", "name": "빗장", "kind": "pistol", "weapon": "mp5",
			"health": 2.7, "damage": 1.72, "speed": 1.1, "scale": 1.24,
			"barks": {
				"engage": ["문은 닫혔다. 나갈 길은 없어.", "빗장 걸었다. 여기서 끝내자."],
				"hit": ["문이 흔들리네."],
				"reload": ["잠깐. 자물쇠 갈아 끼운다."],
				"ally_down": ["하나 빠졌다. 문은 여전히 닫혔어."],
			},
		},
		{
			"id": "gag", "name": "재갈", "kind": "pistol", "weapon": "ak47",
			"health": 2.7, "damage": 1.72, "speed": 1.08, "scale": 1.24,
			"barks": {
				"engage": ["입 다물게 해 주지.", "소리 지르지 마라. 금방 끝난다."],
				"hit": ["말이 많다."],
				"reload": ["숨 쉬어라. 곧 다시 막는다."],
				"ally_down": ["조용해서 좋군."],
			},
		},
		{
			"id": "chimney", "name": "굴뚝", "kind": "grenadier", "weapon": "mp5",
			"health": 2.6, "damage": 1.6, "speed": 1.04, "scale": 1.26,
			"barks": {
				"engage": ["연기 나간다!", "머리 숙여도 소용없어."],
				"hit": ["콜록. 그게 다야?"],
				"reload": ["잠깐, 불 붙인다."],
				"ally_down": ["재가 됐네."],
			},
		},
	],
	3: [
		{
			"id": "black_tongue", "name": "검은 혀", "kind": "pistol", "weapon": "akm",
			"health": 3.0, "damage": 1.84, "speed": 1.1, "scale": 1.24,
			"barks": {
				"engage": ["다리 건너온 고양이. 소문대로군.", "네 얘기는 들었다."],
				"hit": ["소문보다 낫네."],
				"reload": ["잠깐 이야기나 하자."],
				"ally_down": ["말 안 듣더니."],
			},
		},
		{
			"id": "molten", "name": "쇳물", "kind": "pistol", "weapon": "pump_shotgun",
			"health": 3.1, "damage": 1.84, "speed": 1.06, "scale": 1.26,
			"barks": {
				"engage": ["녹여 주마.", "가까이 오면 다 녹는다."],
				"hit": ["뜨겁지? 나도 그래."],
				"reload": ["끓는 중이다. 기다려."],
				"ally_down": ["식은 놈은 버린다."],
			},
		},
		{
			"id": "chimney", "name": "굴뚝", "kind": "grenadier", "weapon": "mp5",
			"health": 2.9, "damage": 1.76, "speed": 1.04, "scale": 1.26,
			"barks": {
				"engage": ["연기 나간다!", "머리 숙여도 소용없어."],
				"hit": ["콜록. 그게 다야?"],
				"reload": ["잠깐, 불 붙인다."],
				"ally_down": ["재가 됐네."],
			},
		},
	],
	4: [
		{
			"id": "muzzle", "name": "총구", "kind": "pistol", "weapon": "akm",
			"health": 3.3, "damage": 1.96, "speed": 1.1, "scale": 1.24,
			"barks": {
				"engage": ["총구는 이쪽을 본다.", "군은 안쪽을 겨눴지. 나도 그렇다."],
				"hit": ["겨냥이 좋군."],
				"reload": ["탄띠 간다. 도망쳐 봐."],
				"ally_down": ["다음은 너다."],
			},
		},
		{
			"id": "ash", "name": "잿더미", "kind": "pistol", "weapon": "pump_shotgun",
			"health": 3.4, "damage": 1.96, "speed": 1.06, "scale": 1.26,
			"barks": {
				"engage": ["다 타고 남은 게 나다.", "재 속에서 뭘 찾는 거지?"],
				"hit": ["또 타오르네."],
				"reload": ["숨 고른다."],
				"ally_down": ["재는 재로."],
			},
		},
		{
			"id": "fang", "name": "송곳니", "kind": "melee", "weapon": "",
			"health": 3.8, "damage": 2.0, "speed": 1.22, "scale": 1.28,
			"barks": {
				"engage": ["뛰지 마. 더 재밌어지니까.", "이빨부터 간다."],
				"hit": ["긁혔군."],
				"ally_down": ["내 몫이 늘었네."],
			},
		},
	],
	5: [
		{
			"id": "ember", "name": "불씨", "kind": "pistol", "weapon": "akm",
			"health": 3.6, "damage": 2.08, "speed": 1.12, "scale": 1.26,
			"barks": {
				"engage": ["남산은 내 구역이다.", "여기까지 온 고양이는 네가 처음이다."],
				"hit": ["아직 꺼지지 않았다."],
				"reload": ["잠깐. 불씨 살린다."],
				"ally_down": ["다 죽어도 불씨는 남는다."],
			},
		},
		{
			"id": "dead_air", "name": "빈 무전", "kind": "pistol", "weapon": "pump_shotgun",
			"health": 3.7, "damage": 2.08, "speed": 1.06, "scale": 1.26,
			"barks": {
				"engage": ["무전은 내가 끊었다.", "신호 따라온 거냐. 잘 왔다."],
				"hit": ["치직. 들리나."],
				"reload": ["교신 끊긴다. 잠시."],
				"ally_down": ["응답 없음."],
			},
		},
		{
			"id": "grey_hand", "name": "회색 손", "kind": "melee", "weapon": "",
			"health": 4.2, "damage": 2.1, "speed": 1.22, "scale": 1.28,
			"barks": {
				"engage": ["손 하나면 충분하다.", "이 손으로 문을 잠갔다."],
				"hit": ["아직 손은 멀쩡하다."],
				"ally_down": ["손이 줄었군. 상관없다."],
			},
		},
		{
			"id": "padlock", "name": "자물쇠", "kind": "grenadier", "weapon": "mp5",
			"health": 3.4, "damage": 1.96, "speed": 1.04, "scale": 1.26,
			"barks": {
				"engage": ["출구는 내가 잠갔다.", "열쇠는 없다. 돌아가라."],
				"hit": ["열리지 않아."],
				"reload": ["잠깐, 잠근다."],
				"ally_down": ["빗장 하나 빠졌군."],
			},
		},
	],
}


static func get_count(stage_tier: int) -> int:
	return int(COUNT_BY_TIER.get(clampi(stage_tier, 1, 5), 2))


static func get_escort_count(stage_tier: int) -> int:
	return int(ESCORTS_BY_TIER.get(clampi(stage_tier, 1, 5), 1))


static func pick_profiles(stage_tier: int, count: int, random: RandomNumberGenerator) -> Array[Dictionary]:
	# 풀에서 겹치지 않게 뽑는다. 풀이 모자라면 앞 단계 풀에서 채운다.
	var tier := clampi(stage_tier, 1, 5)
	var pool: Array = (POOLS.get(tier, []) as Array).duplicate()
	var fallback_tier := tier - 1
	while pool.size() < count and fallback_tier >= 1:
		for extra in POOLS.get(fallback_tier, []) as Array:
			var duplicate_id := false
			for existing in pool:
				if str((existing as Dictionary).get("id", "")) == str((extra as Dictionary).get("id", "")):
					duplicate_id = true
					break
			if not duplicate_id:
				pool.append(extra)
		fallback_tier -= 1
	var picked: Array[Dictionary] = []
	while picked.size() < count and not pool.is_empty():
		var index := random.randi() % pool.size()
		picked.append((pool[index] as Dictionary).duplicate(true))
		pool.remove_at(index)
	return picked


static func get_bark(profile: Dictionary, kind: String, random: RandomNumberGenerator) -> String:
	var barks := profile.get("barks", {}) as Dictionary
	var lines: Array = barks.get(kind, []) as Array
	if lines.is_empty():
		return ""
	return str(lines[random.randi() % lines.size()])
