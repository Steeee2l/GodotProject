extends SceneTree

# 조용한 한 줄 토스트 프로브(2026-09-02).
#   ① push_toast_minor는 스택에 쌓이지 않고 자리 하나(QuietToast)를 돌려 쓴다
#   ② 굵은 알림이 둘 서 있으면 조용한 한 줄은 뜨지 않는다
#   ③ 굵은 알림은 TOAST_LIMIT(2)까지만, 조용한 한 줄은 언제나 맨 아래
#   ④ 같은 조용한 문장 연타는 ×N으로 합쳐진다

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("QUIET|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("QUIET_TOAST_PROBE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var hud = main_scene.get("hud")
	var stack := hud.get("toast_stack") as VBoxContainer
	_check(stack != null, "토스트 스택 존재")
	# 시작 토스트가 남아 있을 수 있으니 비운다.
	for child in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
	hud.set("quiet_toast", null)
	await process_frame

	# ① 조용한 한 줄은 자리 하나.
	hud.call("push_toast_minor", "탄약 +10", Color.WHITE, 2.0)
	hud.call("push_toast_minor", "고철 +3", Color.WHITE, 2.0)
	await process_frame
	var quiet := stack.get_node_or_null("QuietToast") as PanelContainer
	_check(quiet != null and quiet.visible, "① QuietToast가 하나 붙어 보인다")
	_check(stack.get_child_count() == 1, "① 스택엔 조용한 자리 하나뿐(현재 %d)" % stack.get_child_count())
	if quiet != null:
		var label := quiet.get_meta("label") as Label
		_check(label.text == "고철 +3", "① 마지막 문장으로 교체된다(%s)" % label.text)

	# ④ 같은 문장 연타는 ×N.
	hud.call("push_toast_minor", "고철 +3", Color.WHITE, 2.0)
	await process_frame
	if quiet != null:
		var label := quiet.get_meta("label") as Label
		_check(label.text.ends_with("×2"), "④ 같은 문장은 ×2로 합쳐진다(%s)" % label.text)

	# ③ 굵은 알림 셋 → 둘만 남고, 조용한 자리는 맨 아래.
	hud.call("push_toast", "굵은 1", Color.WHITE, 5.0)
	hud.call("push_toast", "굵은 2", Color.WHITE, 5.0)
	hud.call("push_toast", "굵은 3", Color.WHITE, 5.0)
	await process_frame
	var loud := int(hud.call("_loud_toast_count"))
	_check(loud == 2, "③ 굵은 알림은 둘까지(현재 %d)" % loud)
	_check(
		stack.get_child(stack.get_child_count() - 1) == quiet,
		"③ 조용한 자리는 언제나 맨 아래"
	)

	# ② 굵은 알림 둘이 서 있으면 조용한 한 줄은 새로 뜨지 않는다.
	quiet.visible = false
	hud.call("push_toast_minor", "안 떠야 함", Color.WHITE, 2.0)
	await process_frame
	_check(not quiet.visible, "② 굵은 알림 둘일 땐 조용한 한 줄이 뜨지 않는다")

	if failures.is_empty():
		print("QUIET_TOAST_PROBE_OK")
		quit(0)
		return
	for failure in failures:
		print("QUIET|FAIL|%s" % failure)
	push_error("QUIET_TOAST_PROBE_FAIL %d" % failures.size())
	quit(1)
