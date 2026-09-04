extends SceneTree

# 적 능동 엄폐 프로브(2026-09-04).
#   ① 권총병(enemy_kind "pistol")도 엄폐 판정을 받는다(예전 "ranged" 조건은 죽은 코드였다)
#   ② 플레이어와 자기 사이에 낮은 엄폐물이 있으면 그 반대편 자리를 찾는다
#   ③ 그 자리로 실제로 이동해 붙고 cover_active가 켜진다

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("ECOVER|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("ENEMY_COVER_PROBE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var player := main_scene.get("player") as CharacterBody3D
	# 시네마틱을 걷어내고, 적을 전부 멀리 치운다.
	var chain: Object = main_scene.get("main_mission")
	var cine: Object = chain.get("cinematic")
	var guard := 0
	while bool(cine.get("running")) and guard < 40:
		cine.call("skip")
		await create_timer(0.2, true, false, true).timeout
		guard += 1
	var subject: CharacterBody3D = null
	for raw_enemy in main_scene.get("enemies") as Array:
		var enemy := raw_enemy as CharacterBody3D
		if not is_instance_valid(enemy):
			continue
		enemy.global_position = player.global_position + Vector3(300.0, 0.0, 300.0)
		enemy.set("alerted", false)
		if subject == null and str(enemy.get("enemy_kind")) == "pistol" and not bool(enemy.get_meta("elite", false)):
			subject = enemy
	_check(subject != null, "① 권총병 존재")
	if subject == null:
		_finish()
		return
	# 플레이어 +X 8m에 낮은 엄폐 상자, 사수는 +X 14m(상자 너머).
	var blocker := StaticBody3D.new()
	blocker.name = "ProbeEnemyCover"
	blocker.collision_layer = COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.3, 4.0)
	shape.shape = box
	blocker.add_child(shape)
	main_scene.add_child(blocker)
	blocker.global_position = player.global_position + Vector3(8.0, 0.65 - 0.78, 0.0)
	subject.global_position = player.global_position + Vector3(14.0, 0.0, 1.0)
	subject.set("target", player)
	subject.set("alerted", true)
	subject.set("has_current_line_of_sight", true)
	subject.set("opening_pressure_time", 0.0)
	subject.set("cover_seek_cooldown", 0.0)
	subject.set("cover_seek_retry", 0.0)
	for _frame in 3:
		await physics_frame
	# ① 엄폐 판정이 권총병에게 열려 있다(상자 뒤에 서 있으면 covered).
	subject.global_position = player.global_position + Vector3(9.6, 0.0, 0.0)
	await physics_frame
	subject.call("refresh_cover_state")
	_check(bool(subject.get("cover_active")), "① 권총병이 상자 뒤에서 엄폐 판정을 받는다")
	# ② 자리 찾기 — 14m 지점에서 상자 반대편(플레이어 기준 먼 면 + 0.85m) 자리를 찾는다.
	subject.global_position = player.global_position + Vector3(14.0, 0.0, 1.0)
	subject.set("cover_active", false)
	subject.set("cover_hold_timer", 0.0)
	await physics_frame
	var seek: Vector3 = subject.call("_find_cover_seek_point")
	var seek_x := seek.x - player.global_position.x if seek != Vector3.INF else -1.0
	_check(seek != Vector3.INF and seek_x > 8.6 and seek_x < 10.6, "② 상자 반대편 자리를 찾는다(x=%.2f)" % seek_x)
	# ③ 실제로 이동해 붙는다 — 물리 프레임을 돌린다(사수만 가까이, 나머지는 300m 밖).
	var arrived := false
	for frame in 480:
		subject.set("alerted", true)
		subject.set("has_current_line_of_sight", true)
		await physics_frame
		if frame % 60 == 0:
			print("ECOVER|DIAG|f=%d x=%.2f state=%s seek=%s hold=%.1f cd=%.1f cover=%s los=%s vel=%.2f" % [
				frame, subject.global_position.x - player.global_position.x, subject.get("combat_state"),
				str(subject.get("cover_seek_point")), float(subject.get("cover_hold_timer")),
				float(subject.get("cover_seek_cooldown")), subject.get("cover_active"),
				subject.get("has_current_line_of_sight"), (subject.get("velocity") as Vector3).length()])
		var dx := subject.global_position.x - player.global_position.x
		if bool(subject.get("cover_active")) and dx < 11.0:
			arrived = true
			break
	_check(arrived, "③ 엄폐 자리로 이동해 붙는다(x=%.2f, cover_active=%s)" % [subject.global_position.x - player.global_position.x, str(subject.get("cover_active"))])
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("ENEMY_COVER_PROBE_OK")
		quit(0)
		return
	for failure in failures:
		print("ECOVER|FAIL|%s" % failure)
	push_error("ENEMY_COVER_PROBE_FAIL %d" % failures.size())
	quit(1)
