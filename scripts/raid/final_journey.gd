extends RefCounted

# 마지막 출정 — 사자를 데리고 남산 지하 입구까지 가는 판의 서사 담당.
#
# 판 골격(지점 3개·경보·정산)은 MainMissionChain이 그대로 쥔다. 이 모듈은
# 그 위에 얹히는 것만 맡는다:
#   * 길에서 사자가 하는 말(말풍선) — 그는 싸우지 않는다, 말을 한다.
#   * 문 앞 연출(FieldCinematic event 모드)
#   * 엔딩 화면 한 장 → 평소와 같은 탈출 정산 → 쉘터
#
# 클리어 표시(GameState.ending_seen)는 문 앞 연출이 끝나는 순간 찍는다. 정산
# 화면에서 게임을 껐다 켜도 클리어는 남아야 한다.

const COMPANION_SYSTEM := preload("res://scripts/raid/companion.gd")
const ENDING_SCREEN := preload("res://scripts/raid/ending_screen.gd")
const FIELD_CINEMATIC := preload("res://scripts/raid/field_cinematic.gd")

const PORTRAIT_SAJA := "res://assets/characters/saja/down_idle-frame-0.png"
const PORTRAIT_NABI := "res://assets/characters/cat_8way/down_idle_0.png"

# 길에서 흘리는 잡담. 사자는 조용한 걸 못 견딘다 — 그래서 계속 떠든다.
# 유창하지 않다. 딴소리하고, 스스로 고치고, 물어놓고 자기가 답한다.
const ROAD_CHATTER: Array[String] = [
	"여기 원래 계단 있었는데. 없어졌네.",
	"신발 젖었어. 말 안 하려고 했는데.",
	"조용하네. 밤엔 원래 이래?",
	"뒤에 뭐 있어. …아니다. 나무야. 미안.",
	"내가 앞장서야 되는 거 아냐? …아니지. 네가 가. 네가 가.",
	"말 좀 시켜 줘. 조용하면 자꾸 딴 생각 나.",
	"이 산 냄새는 그대로네.",
	"밥은 갔다 와서 먹자. 국은 다시 데우면 돼.",
]
const CHATTER_INTERVAL := 15.0
# 총소리가 나면 잡담을 멈춘다. 이건 딱 한 번만 나오는 말이다.
const COMBAT_LINE := "어어. 어. 나 여기 있을게. 여기 있을게."
const COMBAT_LINE_SECOND := "…미안. 나 총 못 쏴."

var host: Node
var cinematic := FIELD_CINEMATIC.new()
var ending_screen := ENDING_SCREEN.new()

var active := false
var door_position := Vector3.ZERO
var chatter_timer := CHATTER_INTERVAL
var chatter_index := 0
var combat_line_used := false
var ending_played := false


func attach(owner_node: Node) -> void:
	host = owner_node
	cinematic.attach(owner_node)
	ending_screen.attach(owner_node)


func is_active() -> bool:
	return active


func is_cinematic_active() -> bool:
	return cinematic.is_active() or ending_screen.is_open()


func begin(point_positions: Array) -> void:
	# MainMissionChain이 마지막 출정 판을 세운 직후에 부른다.
	active = true
	ending_played = false
	chatter_timer = CHATTER_INTERVAL
	combat_line_used = false
	if point_positions.size() > 0:
		door_position = point_positions[point_positions.size() - 1]
	# 주홍이 같이 나왔다면 한마디는 해야 한다 — 반년 동안 사자를 의심해 온
	# 사람 옆에 사자가 서 있는데 아무 말도 없으면 그게 더 이상하다.
	var tree: SceneTree = host.get_tree()
	if host.companion_system.is_juhong_alive() and tree != null:
		tree.create_timer(6.0, true, false, true).timeout.connect(func() -> void:
			if host.companion_system.is_juhong_alive():
				host.companion_system.juhong.bark("저 노란 놈을 데리고 나온다고?")
		)
		tree.create_timer(10.5, true, false, true).timeout.connect(func() -> void:
			if host.companion_system.is_juhong_alive():
				host.companion_system.juhong.bark("됐어. 네 판이야. 내 총은 앞만 봐.")
		)


func update(delta: float) -> void:
	if not active or host == null:
		return
	if ending_played or cinematic.is_running() or ending_screen.is_open():
		return
	if not host.companion_system.is_saja_alive():
		return
	# 교전 중엔 잡담을 접는다. 대신 딱 두 줄, 한 번만.
	if host.companion_system.any_enemy_alerted():
		chatter_timer = CHATTER_INTERVAL
		if not combat_line_used:
			combat_line_used = true
			host.companion_system.saja_bark(COMBAT_LINE)
			var tree: SceneTree = host.get_tree()
			if tree != null:
				tree.create_timer(4.0, true, false, true).timeout.connect(func() -> void:
					host.companion_system.saja_bark(COMBAT_LINE_SECOND)
				)
		return
	chatter_timer -= delta
	if chatter_timer > 0.0:
		return
	chatter_timer = CHATTER_INTERVAL
	host.companion_system.saja_bark(ROAD_CHATTER[chatter_index % ROAD_CHATTER.size()])
	chatter_index += 1


func on_point_reached(index: int) -> void:
	# 지점마다 사자가 반응한다. 독백(먼지)은 카탈로그가 말하고, 여기는 그의 입.
	match index:
		0:
			_bark_sequence([
				["차단기. 이거 내가 넘을 수 있나.", 0.2],
				["…넘었네.", 3.4],
			])
		1:
			# 깡통 무더기 = 그가 반년 동안 여기 다녀간 증거. 들키자 말이 꼬인다.
			_bark_sequence([
				["…뭘 봐.", 0.2],
				["놔두라고 했잖아. 아니, 내가 언제 그랬냐. 됐어.", 3.4],
				["매일 새벽에 하나씩. 여섯 시 전에. 걔들 안 돌아다닐 때.", 7.4],
			])


func _bark_sequence(entries: Array) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	for entry_value in entries:
		var entry := entry_value as Array
		var line := str(entry[0])
		var delay := float(entry[1])
		if delay <= 0.05:
			host.companion_system.saja_bark(line)
			continue
		# 프레임이 아니라 실시간으로 센다 — 이 PC는 500fps다.
		tree.create_timer(delay, true, false, true).timeout.connect(func() -> void:
			host.companion_system.saja_bark(line)
		)


# ── 문 앞 ──────────────────────────────────────────────────────


func play_ending() -> void:
	if ending_played:
		return
	ending_played = true
	cinematic.play(_build_ending_steps(), _show_ending_screen)


func _chose_wake() -> bool:
	# 남산 3단계에서 "데리고 온다"를 고른 판은 문이 이미 열려 있다.
	return GameState.get_mission_choice("namsan_final_switch") == "wake"


func _build_ending_steps() -> Array:
	var steps: Array = [
		{"mode": "event"},
		{"type": "wait", "duration": 0.5},
		{"type": "focus", "position": door_position, "hold": 1.5},
		{
			"type": "lines",
			"speaker": "사자",
			"title": "문",
			"portrait": PORTRAIT_SAJA,
			"lines": [
				"여기야?",
				"…문이 작네. 더 클 줄 알았는데.",
				"불 켜져 있어. 저기, 밑에.",
			],
		},
	]
	# 문의 상태만 갈린다. 안에 몇이 있는지는 어느 쪽이든 같다.
	var door_lines: Array[String] = [
		"문에 손을 대 본다. 안에서 잠겨 있다.",
		"바닥이 떨린다. 기계가 아니다. 숨소리다.",
		"세어 볼 것도 없다. 서른여섯이다.",
	]
	if _chose_wake():
		door_lines = [
			"문이 열려 있다. 우리가 열어 놨다.",
			"안에서 발소리가 올라온다. 아직 멀다.",
			"세어 볼 것도 없다. 서른여섯이다.",
		]
	steps.append({
		"type": "lines",
		"speaker": "먼지",
		"title": "문",
		"portrait": PORTRAIT_NABI,
		"lines": door_lines,
	})
	steps.append({
		"type": "lines",
		"speaker": "사자",
		"title": "문",
		"portrait": PORTRAIT_SAJA,
		"lines": [
			"…서른여섯?",
			"네가 셌어?",
			"…",
			"그럼 아홉은.",
			"아홉도 안에 있는 거네.",
			"…",
			"내가 반년을 뭘 한 거야.",
		],
	})
	steps.append({"type": "wait", "duration": 0.6})
	steps.append({
		"type": "lines",
		"speaker": "먼지",
		"title": "문",
		"portrait": PORTRAIT_NABI,
		"lines": [
			"사자가 가방을 연다.",
			"통조림 하나를 꺼내 문 앞에 놓는다.",
			"매일 놓던 자리다. 오늘은 뚜껑을 안 딴다.",
		],
	})
	var closing_lines: Array[String] = [
		"마지막 거야, 이거.",
		"내일부터는 안 와.",
		"…안에서 먹겠지. 안에 있으면.",
	]
	if _chose_wake():
		closing_lines.append("올라오면 뭐라고 하지. …몰라. 그건 올라오면 생각하자.")
	closing_lines.append("{name:아/야}. 가자.")
	closing_lines.append("…국 식겠다.")
	steps.append({
		"type": "lines",
		"speaker": "사자",
		"title": "문",
		"portrait": PORTRAIT_SAJA,
		"lines": closing_lines,
	})
	steps.append({"type": "focus_player", "hold": 0.5})
	return steps


func _show_ending_screen() -> void:
	# 여기가 클리어 지점이다. 정산 화면에서 껐다 켜도 남아야 하므로 즉시 저장한다.
	GameState.mark_ending_seen()
	# 연출은 끝나면서 세상을 다시 돌린다(FieldCinematic._finish). 엔딩 화면 뒤에서
	# 적이 돌아다니면 안 되니 여기서 다시 멈춘다 — 화면 레이어는 ALWAYS라 살아 있다.
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.paused = true
	var seen_body := (
		"남산 지하 입구. 문은 안에서 잠겨 있었다. 안에 서른여섯 명이 자고 있다."
		+ " 셔터 앞에서 돌아선 아홉도 그 안에 있다. 자리는 모자라지 않았다."
	)
	if _chose_wake():
		seen_body = (
			"남산 지하 입구. 문은 열려 있었다. 안에서 서른여섯 명이 올라오는 중이다."
			+ " 셔터 앞에서 돌아선 아홉도 그 안에 있었다. 자리는 모자라지 않았다."
		)
	ending_screen.show_ending(
		[
			{"caption": "본 것", "body": seen_body},
			{
				"caption": "사자가 놓은 것",
				"body": (
					"통조림 하나. 반년 동안 매일 새벽 그 문 앞에 놓던 것."
					+ " 오늘은 뚜껑을 안 땄다."
					+ " 그리고 세던 걸 놓았다. 스물일곱까지 세고 아홉이 남던 계산을."
				),
			},
			{
				"caption": "돌아가는 길",
				"body": "{name:이/가} 앞장선다. 사자는 국이 식는다고 두 번 말한다.",
			},
		],
		_return_to_shelter
	)


func _return_to_shelter() -> void:
	active = false
	GameState.final_raid_run = false
	GameState.save_persistent_state()
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.paused = false
	# 정산은 평소 탈출과 같은 길을 탄다 — 엔딩을 봤다는 이유로 이 판에서 주운
	# 것과 경험치가 사라지면 그건 보상이 아니라 벌이다.
	host.extraction._begin_extraction()
