extends SceneTree

# 캐릭터 이름 짓기 프로브(2026-09-03).
#   ① 조사 선택: 받침·영문·숫자
#   ② {name} 토큰 치환과 화자 치환
#   ③ 플로우: 유효하지 않은 이름은 버튼이 잠기고, 유효한 이름은 확정 → finished → GameState 저장
#   ④ 사자 첫 만남 대사에 이름이 들어간다

const NAMING_PATH := "res://scripts/character_naming.gd"

var failures: Array[String] = []
var received_name := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("NAMING|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func() -> void:
		push_error("NAMING_PROBE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)

	# ① 조사
	_check(game_state.korean_ends_with_consonant("재갈"), "① 재갈 → 받침 있음")
	_check(not game_state.korean_ends_with_consonant("먼지"), "① 먼지 → 받침 없음")
	_check(game_state.korean_ends_with_consonant("Tom"), "① Tom → 자음 끝")
	_check(not game_state.korean_ends_with_consonant("Mia"), "① Mia → 모음 끝")
	_check(game_state.korean_ends_with_consonant("No7"), "① No7 → '칠' 받침")

	# ② 치환
	game_state.set("player_name", "재갈")
	_check(game_state.apply_player_name("{name:이/가} 왔다") == "재갈이 왔다", "② 이/가 (재갈)")
	_check(game_state.apply_player_name("이름이 뭐야. {name:이라고/라고}.") == "이름이 뭐야. 재갈이라고.", "② 이라고/라고")
	game_state.set("player_name", "먼지")
	_check(game_state.apply_player_name("{name:아/야}, 부자다") == "먼지야, 부자다", "② 아/야 (먼지)")
	_check(game_state.apply_player_name("{name} 도착") == "먼지 도착", "② {name}")
	_check(game_state.apply_player_name("먼지가 쌓인 단말") == "먼지가 쌓인 단말", "② 토큰 없는 '먼지'(먼지 명사)는 손대지 않는다")
	game_state.set("player_name", "안개")
	_check(game_state.resolve_speaker("먼지") == "안개" and game_state.resolve_speaker("사자") == "사자", "② 화자 치환")

	# ③ 플로우
	var host := Node.new()
	root.add_child(host)
	var naming = (load(NAMING_PATH) as GDScript).run(host)
	await create_timer(1.6, true, false, true).timeout
	var input := naming.get("name_input") as LineEdit
	var button := naming.get("confirm_button") as Button
	_check(input != null and button != null, "③ 입력창·버튼 존재")
	_check(button.disabled, "③ 빈 이름은 버튼 잠김")
	input.text = "먼지!"
	naming.call("_on_text_changed", input.text)
	_check(button.disabled, "③ 특수문자는 버튼 잠김")
	input.text = "그을음"
	naming.call("_on_text_changed", input.text)
	_check(not button.disabled, "③ 유효한 이름은 버튼 열림")
	naming.finished.connect(func(chosen: String) -> void: received_name = chosen)
	button.pressed.emit()
	await create_timer(4.6, true, false, true).timeout
	_check(received_name == "그을음", "③ finished(이름) 신호(%s)" % received_name)
	_check(str(game_state.get("player_name")) == "그을음", "③ GameState.player_name 저장")

	# ④ 사자 대사
	game_state.set("opening_completed", true)
	game_state.set("contract_agent_intro_seen", false)
	var event: Dictionary = game_state.call("get_pending_shelter_story_event")
	print("NAMING|DIAG|event id=%s lines=%d" % [str(event.get("id", "")), (event.get("lines", []) as Array).size()])
	var found := false
	for line in event.get("lines", []) as Array:
		if game_state.apply_player_name(str(line)).contains("그을음이라고"):
			found = true
	_check(found, "④ 사자 첫 만남에 '그을음이라고'")

	game_state.set("player_name", "먼지")
	if failures.is_empty():
		print("NAMING_PROBE_OK")
		quit(0)
		return
	for failure in failures:
		print("NAMING|FAIL|%s" % failure)
	push_error("NAMING_PROBE_FAIL %d" % failures.size())
	quit(1)
