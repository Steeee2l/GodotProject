extends RefCounted

# 적 잡담 — 도시가 살아 있게 만드는 장치(2026-08-30 유저 요청).
#
# 여태 적은 아무 말도 하지 않았다. 통조림에 반응할 때만 한 줄 뱉고, 나머지
# 시간에는 그냥 걸어다니는 표적이었다. 이제 평소에 서로 떠들고, 혼잣말을
# 하고, 남 험담을 하고, 가끔은 이 판의 진실에 스치는 말을 흘린다.
#
# 설계 규칙:
#  · 2인 대화가 기본이다. 가까이 선 둘을 짝지어 A가 말하면 B가 받는다.
#    혼자면 혼잣말. 대화가 대사 목록보다 훨씬 생동감 있다.
#  · 플레이어가 들을 수 있는 거리(CHATTER_HEAR_RANGE)에서만 굴린다 —
#    맵 반대편에서 혼자 떠드는 건 연산 낭비다.
#  · 전투 중에는 잡담이 아니라 전투 바크만, 그것도 드물게.
#  · 서사 단서(SECRET_LINES)는 '사자의 기록'과 주홍의 의심을 뒷받침하되
#    답을 말하지는 않는다 — 보이스 바이블의 "의심 단서는 기록물과 주홍의
#    입에만" 규칙을 침범하지 않는 선에서, 적은 자기가 본 것만 말한다.
#
# host 패턴: main.gd가 attach(host) 후 매 프레임 update(delta)만 부른다.

const SPEECH_BUBBLE := preload("res://scripts/raid/speech_bubble.gd")

# 잡담 굴림 간격 — 판 전체 기준. 너무 잦으면 수다스러운 도시가 된다.
const CHATTER_ROLL_INTERVAL := 5.5
# 플레이어가 이 거리 안에 있을 때만 떠든다(들리지도 않는 대사는 없는 대사다).
const CHATTER_HEAR_RANGE := 34.0
# 짝을 맺을 최대 거리 — 이보다 멀면 서로 대화가 아니라 각자 혼잣말이다.
const PAIR_RANGE := 7.5
# 같은 적이 다시 말하기까지의 최소 간격.
const SPEAKER_COOLDOWN := 22.0
# 대화의 두 번째 줄(받아치기)까지의 지연.
const REPLY_DELAY := 1.9
# 전투 중 바크 확률 — 굴림마다. 낮게 둬야 '가끔 던지는 말'이 된다.
const COMBAT_BARK_CHANCE := 0.28
const COMBAT_BARK_COOLDOWN := 9.0

# ── 대사 풀 ──────────────────────────────────────────────────────
# 약탈자들이다. 배고프고, 지쳤고, 윗선을 믿지 않는다. 문어체·경구 금지.

# 2인 대화 — [먼저 하는 말, 받는 말]. 짝지어 읽어야 말이 되게 쓴다.
const CONVERSATIONS := [
	["어제 배급 받았냐", "받긴 뭘 받아. 명단에 없대"],
	["발 시려", "장화 하나 구해 줄까", "됐어. 네 것도 다 떨어졌잖아"],
	["여기 원래 뭐 하던 데야", "몰라. 간판도 다 떼 갔더라"],
	["저 위층은 아직 안 봤지", "문이 안 열려. 안에서 잠갔더라고"],
	["교대 언제야", "묻지 마. 물어보면 더 늦어져"],
	["배고프다", "아까 그 통조림 네가 다 먹었잖아"],
	["소리 안 났어", "바람이야. 자꾸 그러면 밤에 못 자"],
	["담배 있냐", "끊었어", "거짓말"],
	["오늘 몇 명 왔대", "세지 마. 세면 기분만 나빠져"],
	["여기서 얼마나 더 있어야 돼", "위에서 오라 할 때까지"],
]

# 험담 — 윗선·동료를 씹는다. 이 세계가 어떤 조직인지 대사로 보여 준다.
const GOSSIP := [
	["반장은 오늘도 안 왔지", "걘 원래 여기 안 와. 명단만 적어 가"],
	["윗선은 따뜻한 데 앉아 있겠지", "그러니까 윗선이지"],
	["걔 어제 혼자 먼저 튀었대", "다음엔 나도 튄다"],
	["누가 우리 몫 빼돌린 거 아니야", "말조심해. 그런 말 하다 끌려간 놈 있어"],
	["장비도 안 주고 시키기만 해", "불평은 나중에. 지금 하면 네 이름 적힌다"],
]

# 혼잣말 — 혼자 서 있는 적. 짧게, 속으로 새는 말투로.
const MONOLOGUE := [
	"…춥네",
	"오늘만 버티자",
	"집에 가고 싶다",
	"발소리 들린 것 같은데",
	"아무것도 없잖아, 여긴",
	"배고파",
	"이게 무슨 짓이야, 진짜",
	"조용하네. 너무 조용해",
]

# 이 판의 진실에 스치는 말 — 답을 주지 않는다. 적은 자기가 본 것만 말한다.
const SECRETS := [
	["아래에서 소리 났다니까", "지하는 잠갔어. 신경 꺼"],
	["명단에 왜 고양이 이름이 있어", "적으라니까 적은 거지 뭐"],
	["방송 아직도 나와?", "같은 말만 반복해. 며칠째"],
	["여기 사람들 어디로 갔대", "이송됐다잖아", "누가 그래?"],
	["문이 왜 안에서 잠겨 있냐고", "그만해. 그거 생각하면 잠 안 와"],
]

# 전투 바크 — 싸우면서 던지는 말. 짧고 다급하게.
const COMBAT_BARKS := [
	"저기 있다!",
	"엄폐해!",
	"뭐야 저거, 고양이야?",
	"탄 아껴!",
	"돌아, 돌아!",
	"누가 좀 도와줘!",
	"안 맞아! 움직인다고!",
	"이 정도는 아니었잖아…",
]

var host: Node
var player: Node3D
var chatter_timer := 0.0
var random := RandomNumberGenerator.new()
# enemy 인스턴스 ID → 다음에 말해도 되는 시각(초, 판 경과 시간 기준).
var speaker_cooldowns: Dictionary = {}
var elapsed := 0.0
var combat_bark_timer := 0.0


func attach(host_node: Node) -> void:
	host = host_node
	player = host_node.get("player") as Node3D
	random.randomize()
	chatter_timer = random.randf_range(2.0, CHATTER_ROLL_INTERVAL)


func update(delta: float) -> void:
	if host == null or not is_instance_valid(player):
		return
	# 연출 중에는 입을 다문다 — 사망 슬로모나 탈출 전환 위로 잡담이 뜨면
	# 그 장면이 통째로 우스워진다.
	if (
		bool(host.get("player_death_sequence_active"))
		or bool(host.get("extraction_transition_active"))
		or bool(host.get("boss_defeat_sequence_active"))
	):
		return
	elapsed += delta
	combat_bark_timer = maxf(0.0, combat_bark_timer - delta)
	chatter_timer -= delta
	if chatter_timer > 0.0:
		return
	chatter_timer = CHATTER_ROLL_INTERVAL * random.randf_range(0.75, 1.35)
	var candidates := _collect_nearby_enemies()
	if candidates.is_empty():
		return
	# 교전 중이면 잡담이 아니라 전투 바크다.
	var alerted: Array[Node3D] = []
	var calm: Array[Node3D] = []
	for enemy in candidates:
		if bool(enemy.get("alerted")):
			alerted.append(enemy)
		else:
			calm.append(enemy)
	if not alerted.is_empty():
		_roll_combat_bark(alerted)
		# 교전 중에도 멀찍이 떨어진 조용한 적들은 계속 자기 얘기를 한다.
	if calm.is_empty():
		return
	_roll_ambient_chatter(calm)


func _collect_nearby_enemies() -> Array[Node3D]:
	var nearby: Array[Node3D] = []
	var enemies: Array = host.get("enemies") as Array
	if enemies.is_empty():
		return nearby
	for raw_enemy in enemies:
		var enemy := raw_enemy as Node3D
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		# 유인 통조림에 반응 중이면 그쪽 대사가 우선이다 — 겹치지 않게 뺀다.
		if enemy.get("lure_point") != null:
			continue
		if enemy.global_position.distance_to(player.global_position) > CHATTER_HEAR_RANGE:
			continue
		if float(speaker_cooldowns.get(enemy.get_instance_id(), 0.0)) > elapsed:
			continue
		nearby.append(enemy)
	return nearby


func _roll_combat_bark(alerted: Array[Node3D]) -> void:
	if combat_bark_timer > 0.0 or random.randf() > COMBAT_BARK_CHANCE:
		return
	combat_bark_timer = COMBAT_BARK_COOLDOWN
	var speaker := alerted[random.randi() % alerted.size()]
	_speak(speaker, COMBAT_BARKS[random.randi() % COMBAT_BARKS.size()], SPEECH_BUBBLE.TONE_ENEMY)


func _roll_ambient_chatter(calm: Array[Node3D]) -> void:
	var speaker := calm[random.randi() % calm.size()]
	var partner := _find_partner(speaker, calm)
	if partner == null:
		# 혼자다 — 혼잣말.
		_speak(speaker, MONOLOGUE[random.randi() % MONOLOGUE.size()], SPEECH_BUBBLE.TONE_ENEMY)
		return
	# 둘이 붙어 있다 — 대화를 고른다. 잡담 55 / 험담 27 / 단서 18.
	var roll := random.randf()
	var pool := CONVERSATIONS
	var tone: Color = SPEECH_BUBBLE.TONE_ENEMY
	if roll > 0.82:
		pool = SECRETS
		tone = SPEECH_BUBBLE.TONE_ENEMY_SECRET
	elif roll > 0.55:
		pool = GOSSIP
		tone = SPEECH_BUBBLE.TONE_ENEMY_GOSSIP
	var conversation: Array = pool[random.randi() % pool.size()]
	_play_conversation(speaker, partner, conversation, tone)


func _find_partner(speaker: Node3D, calm: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_distance := PAIR_RANGE
	for enemy in calm:
		if enemy == speaker:
			continue
		var distance := enemy.global_position.distance_to(speaker.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _play_conversation(
	speaker: Node3D,
	partner: Node3D,
	conversation: Array,
	tone: Color
) -> void:
	# 대화는 번갈아 간다 — 홀수 줄은 먼저 말한 쪽, 짝수 줄은 받는 쪽.
	# 3줄짜리("거짓말")도 있어서 인덱스로 화자를 정한다.
	for line_index in conversation.size():
		var line := str(conversation[line_index])
		var talker := speaker if line_index % 2 == 0 else partner
		if line_index == 0:
			_speak(talker, line, tone)
			continue
		var delay := REPLY_DELAY * float(line_index)
		var timer := host.get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			# 대화 도중 죽거나 교전에 들어가면 나머지 줄은 삼킨다 —
			# 총 맞는 중에 잡담을 이어가면 그게 더 이상하다.
			if not is_instance_valid(talker) or bool(talker.get("dying")):
				return
			if bool(talker.get("alerted")):
				return
			_speak(talker, line, tone)
		)


func _speak(enemy: Node3D, line: String, tone: Color) -> void:
	if not is_instance_valid(enemy):
		return
	speaker_cooldowns[enemy.get_instance_id()] = elapsed + SPEAKER_COOLDOWN
	SPEECH_BUBBLE.show_line(enemy, line, tone)
