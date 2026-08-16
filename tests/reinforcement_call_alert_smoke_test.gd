extends SceneTree

# 증원 호출 예고 배너 + 저지 성공 처리 스모크.
#
# ① 호출이 시작되면 중앙 상단 배너가 뜨고 문구/게이지가 맞는가
# ② 8초 카운트다운이 실제로 줄어드는가(게이지 value)
# ③ 호출자를 죽이면 배너 소멸 + "증원 저지!" 토스트 + XP + 증원 미스폰
# ④ 교전 중인 적이 전부 빠져도(저지 성공 b) 같은 결과가 나오는가


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var director = main_scene.get("enemy_director")
	var hud = main_scene.get("hud")
	var enemies: Array = main_scene.get("enemies")
	assert(is_equal_approx(director.REINFORCEMENT_CALL_DURATION, 8.0))

	var panel := hud.reinforcement_call_panel as PanelContainer
	var bar := hud.reinforcement_call_bar as ProgressBar
	var title := hud.reinforcement_call_title as Label
	assert(is_instance_valid(panel) and is_instance_valid(bar))
	assert(not panel.visible)
	assert(title.text == "적이 증원을 요청 중입니다!")

	# 교전 중인 사수 둘을 만든다(동시 교전 상한 6 아래).
	var squad: Array[CharacterBody3D] = []
	for enemy_value in enemies:
		var enemy := enemy_value as CharacterBody3D
		if str(enemy.get("enemy_kind")) == "melee" or bool(enemy.get_meta("raid_boss", false)):
			continue
		if not enemy.has_method("start_reinforcement_call"):
			continue
		enemy.set("alerted", true)
		enemy.set("has_current_line_of_sight", true)
		squad.append(enemy)
		if squad.size() >= 2:
			break
	assert(squad.size() == 2)

	# ① 호출 시작
	director.sustained_combat_time = director.REINFORCEMENT_CALL_TRIGGER_TIME + 1.0
	director._update_reinforcement_call(0.016, 0.5)
	var caller := director.active_reinforcement_caller as CharacterBody3D
	assert(is_instance_valid(caller))
	assert(bool(caller.get("reinforcement_call_active")))
	assert(is_equal_approx(float(caller.get("reinforcement_call_duration")), 8.0))
	assert(bool(director.reinforcement_call_banner_active))
	assert(is_equal_approx(float(main_scene.get("reinforcement_call_alert_remaining")), 8.0))
	assert(panel.visible)
	assert(is_equal_approx(bar.max_value, 8.0) and is_equal_approx(bar.value, 8.0))
	print("① 배너: visible=%s title=%s bar=%.2f/%.2f" % [
		panel.visible, title.text, bar.value, bar.max_value
	])

	# 호출자 강조(머리 위 "!!" + 발밑 링)
	var marker := caller.get_node_or_null("ReinforcementCallMarker") as Label3D
	var ring := caller.get_node_or_null("ReinforcementCallRing") as Sprite3D
	assert(is_instance_valid(marker) and marker.visible and marker.text == "!!")
	assert(is_instance_valid(ring) and ring.visible)
	print("④ 호출자 강조: marker=%s(%s) ring=%s" % [marker.text, marker.modulate.to_html(false), ring.visible])

	# ② 8초 카운트다운
	var samples: Array[float] = [bar.value]
	for step in 40:
		caller.call("_update_reinforcement_call", 0.1)
		director._update_reinforcement_call(0.1, 0.5)
		if not bool(director.reinforcement_call_banner_active):
			break
		assert(bar.value < samples.back())
		samples.append(bar.value)
	print("② 카운트다운: %.2f → %.2f (%d 샘플, detail=%s)" % [
		samples[0], samples.back(), samples.size(), (hud.reinforcement_call_detail as Label).text
	])
	assert(samples.size() >= 39)
	assert(samples.back() <= 4.2 and samples.back() >= 3.8)

	# ③ 호출자 처치 = 저지 성공
	var enemy_count_before := (main_scene.get("enemies") as Array).size()
	var xp_before := int(game_state.get("player_xp"))
	caller.call("take_hit", 9999, Vector3.RIGHT)
	await process_frame
	var enemy_count_after := (main_scene.get("enemies") as Array).size()
	assert(director.active_reinforcement_caller == null)
	assert(not bool(director.reinforcement_call_banner_active))
	assert(is_equal_approx(float(main_scene.get("reinforcement_call_alert_remaining")), 0.0))
	assert(not panel.visible)
	assert(enemy_count_after == enemy_count_before - 1)
	assert(int(game_state.get("player_xp")) - xp_before == director.REINFORCEMENT_BLOCK_XP)
	var block_toast := false
	for toast_value in (hud.toast_stack as VBoxContainer).get_children():
		if str((toast_value as Control).get_meta("base_text", "")).begins_with("증원 저지!"):
			block_toast = true
	assert(block_toast)
	print("③ 저지(처치): 적 %d→%d, XP +%d, 토스트=%s, 배너=%s" % [
		enemy_count_before,
		enemy_count_after,
		int(game_state.get("player_xp")) - xp_before,
		block_toast,
		panel.visible
	])

	# ④ 교전 중인 적이 전부 빠져도 저지 성공
	director.reinforcement_call_cooldown = 0.0
	director.sustained_combat_time = director.REINFORCEMENT_CALL_TRIGGER_TIME + 1.0
	squad[1].set("alerted", true)
	squad[1].set("has_current_line_of_sight", true)
	director._update_reinforcement_call(0.016, 0.5)
	var second_caller := director.active_reinforcement_caller as CharacterBody3D
	assert(is_instance_valid(second_caller) and panel.visible)
	var xp_before_clear := int(game_state.get("player_xp"))
	var count_before_clear := (main_scene.get("enemies") as Array).size()
	for enemy_value in main_scene.get("enemies"):
		var enemy := enemy_value as CharacterBody3D
		if bool(enemy.get("alerted")):
			enemy.set("dying", true)
	director._update_reinforcement_call(0.1, 0.5)
	assert(not bool(director.reinforcement_call_banner_active))
	assert(not panel.visible)
	assert(director.active_reinforcement_caller == null)
	assert((main_scene.get("enemies") as Array).size() == count_before_clear)
	assert(int(game_state.get("player_xp")) - xp_before_clear == director.REINFORCEMENT_BLOCK_XP)
	print("④ 저지(전멸): 배너=%s XP +%d 증원 스폰 없음(%d)" % [
		panel.visible,
		int(game_state.get("player_xp")) - xp_before_clear,
		count_before_clear
	])

	print("REINFORCEMENT_CALL_ALERT_OK")
	main_scene.process_mode = Node.PROCESS_MODE_INHERIT
	main_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)
