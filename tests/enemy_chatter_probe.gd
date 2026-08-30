extends SceneTree

# 적 잡담·말풍선·디버그 메뉴 프로브(2026-08-30).
#   ① 공용 말풍선이 실제로 붙고, 배경 판까지 함께 달린다
#   ② 잡담 모듈이 실제 씬에서 말풍선을 만들어 낸다(붙어 선 적 두 명 기준)
#   ③ 대사 풀에 빈 줄이 없고 대화는 최소 2줄이다
#   ④ 디버그 메뉴가 필드에 붙어 있고 9키로 열린다
#   ⑤ 디버그 치트가 실제로 상태를 바꾼다(고철·시설 해금)

const SPEECH_BUBBLE := preload("res://scripts/raid/speech_bubble.gd")
const ENEMY_CHATTER := preload("res://scripts/raid/enemy_chatter.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("CHATTER|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("ENEMY_CHATTER_PROBE_TIMEOUT")
		quit(2)
	)

	# ── ③ 대사 풀 위생 검사(씬 없이) ─────────────────────────────
	var pools := [
		["CONVERSATIONS", ENEMY_CHATTER.CONVERSATIONS],
		["GOSSIP", ENEMY_CHATTER.GOSSIP],
		["SECRETS", ENEMY_CHATTER.SECRETS],
	]
	for pool_entry in pools:
		var pool_name := str(pool_entry[0])
		var pool: Array = pool_entry[1]
		var pool_ok := not pool.is_empty()
		for conversation in pool:
			var lines: Array = conversation
			if lines.size() < 2:
				pool_ok = false
			for line in lines:
				if str(line).strip_edges().is_empty():
					pool_ok = false
		_check(pool_ok, "③ %s — 대화는 2줄 이상이고 빈 줄이 없다" % pool_name)
	var monologue_ok := not ENEMY_CHATTER.MONOLOGUE.is_empty()
	for line in ENEMY_CHATTER.MONOLOGUE:
		if str(line).strip_edges().is_empty():
			monologue_ok = false
	_check(monologue_ok, "③ MONOLOGUE — 빈 줄 없음")
	var bark_ok := not ENEMY_CHATTER.COMBAT_BARKS.is_empty()
	for line in ENEMY_CHATTER.COMBAT_BARKS:
		if str(line).strip_edges().is_empty():
			bark_ok = false
	_check(bark_ok, "③ COMBAT_BARKS — 빈 줄 없음")

	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	# ── ① 공용 말풍선 ────────────────────────────────────────────
	var player := main_scene.get("player") as Node3D
	_check(is_instance_valid(player), "① 플레이어 존재")
	var bubble: Label3D = SPEECH_BUBBLE.show_line(player, "테스트 대사다", SPEECH_BUBBLE.TONE_ENEMY)
	_check(bubble != null and is_instance_valid(bubble), "① show_line이 말풍선을 만든다")
	if bubble != null:
		_check(bubble.text == "테스트 대사다", "① 대사 텍스트가 그대로 들어간다")
		_check(
			bubble.font_size >= 70,
			"① 글자 크기가 충분하다(%d)" % bubble.font_size
		)
		_check(
			bubble.get_node_or_null("BubbleBacking") != null,
			"① 배경 판이 함께 붙는다"
		)
		# 같은 대상에 다시 말하면 이전 말풍선은 치워진다.
		SPEECH_BUBBLE.show_line(player, "두 번째 대사", SPEECH_BUBBLE.TONE_ALLY)
		await process_frame
		var live_bubbles := 0
		for child in player.get_children():
			if child is Label3D and str(child.name) == SPEECH_BUBBLE.BUBBLE_NAME:
				live_bubbles += 1
		_check(live_bubbles == 1, "① 말풍선은 대상당 하나만 남는다(현재 %d)" % live_bubbles)

	# ── ② 잡담 모듈이 실제로 말을 시킨다 ─────────────────────────
	var chatter = main_scene.get("enemy_chatter")
	_check(chatter != null, "② main에 enemy_chatter가 붙어 있다")
	var enemies: Array = main_scene.get("enemies") as Array
	_check(not enemies.is_empty(), "② 적이 배치돼 있다(%d)" % enemies.size())
	if chatter != null and enemies.size() >= 2:
		# 적 둘을 플레이어 옆에 붙여 세운다 — 들리는 거리 + 짝 거리 조건 충족.
		var speaker := enemies[0] as Node3D
		var partner := enemies[1] as Node3D
		speaker.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
		partner.global_position = player.global_position + Vector3(5.0, 0.0, 0.0)
		speaker.set("alerted", false)
		partner.set("alerted", false)
		# 나머지 적은 멀리 치워 이 둘만 후보가 되게 한다.
		for index in range(2, enemies.size()):
			var far_enemy := enemies[index] as Node3D
			if is_instance_valid(far_enemy):
				far_enemy.global_position = player.global_position + Vector3(400.0, 0.0, 400.0)
		var spoke := false
		# 굴림 간격이 있으므로 여러 번 돌린다.
		for attempt in 40:
			chatter.call("update", 3.0)
			await process_frame
			if _find_bubble(speaker) != null or _find_bubble(partner) != null:
				spoke = true
				break
		_check(spoke, "② 붙어 선 적 둘이 말풍선을 띄운다")

	# ── ④⑤ 디버그 메뉴 ──────────────────────────────────────────
	var debug_menu = main_scene.get("debug_menu")
	_check(debug_menu != null and is_instance_valid(debug_menu), "④ 필드에 디버그 메뉴가 붙어 있다")
	if debug_menu != null and is_instance_valid(debug_menu):
		_check(not bool(debug_menu.get("is_open")), "④ 기본은 닫힌 상태")
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_9
		key_event.pressed = true
		main_scene.call("_input", key_event)
		await process_frame
		_check(bool(debug_menu.get("is_open")), "④ 9키로 열린다")
		# ⑤ 치트가 실제 상태를 바꾼다 — 버튼을 직접 눌러 본다.
		var scrap_before := int(game_state.get("scrap"))
		var pressed_scrap := _press_button(debug_menu, "고철")
		_check(pressed_scrap, "⑤ 고철 버튼을 찾았다")
		await process_frame
		_check(
			int(game_state.get("scrap")) > scrap_before,
			"⑤ 고철이 실제로 늘었다(%d → %d)" % [scrap_before, int(game_state.get("scrap"))]
		)
		var pressed_facility := _press_button(debug_menu, "모든 시설 해금")
		_check(pressed_facility, "⑤ 시설 해금 버튼을 찾았다")
		await process_frame
		_check(
			bool(game_state.call("is_shelter_facility_unlocked", "workbench")),
			"⑤ 시설이 실제로 해금됐다"
		)
		main_scene.call("_input", key_event)
		await process_frame
		_check(not bool(debug_menu.get("is_open")), "④ 9키로 다시 닫힌다")

	if failures.is_empty():
		print("ENEMY_CHATTER_PROBE_OK")
		quit(0)
	for failure in failures:
		print("CHATTER|FAIL|%s" % failure)
	push_error("ENEMY_CHATTER_PROBE_FAIL %d" % failures.size())
	quit(1)


func _find_bubble(target: Node3D) -> Label3D:
	if not is_instance_valid(target):
		return null
	return target.get_node_or_null(SPEECH_BUBBLE.BUBBLE_NAME) as Label3D


func _press_button(menu: Node, label_fragment: String) -> bool:
	for node in menu.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text.contains(label_fragment):
			button.pressed.emit()
			return true
	return false
