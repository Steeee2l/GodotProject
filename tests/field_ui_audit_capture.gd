extends SceneTree

# 필드 UI 전면 검수용 캡처(창 필요). 2026-09-04.
#   field_ui_base.png       : 기본 HUD(위험도·임무 카드·구역 정보·무기 카드·하단 버튼)
#   field_ui_interact.png   : 상호작용 캡슐 + 탄약 줍기 프롬프트
#   field_ui_inventory.png  : 가방
#   field_ui_map.png        : 전술 지도(TAB)
#   field_ui_pause.png      : 일시정지
#   field_ui_lore.png       : 기록 열람
#   field_ui_result.png     : 탈출 정산 + 레벨업 선택
#   field_ui_gameover.png   : 사망 화면
# 실행: godot --path . --script res://tests/field_ui_audit_capture.gd

const OUTPUT_DIR := "res://test-output/field_ui"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	var shots := ["base", "interact", "inventory", "map", "pause", "lore", "result", "gameover"]
	for shot_name in shots:
		game_state.call("reset_run")
		game_state.set("opening_completed", true)
		game_state.set("pending_level_choices", 2)
		var baseline: Array[Node] = []
		for child in root.get_children():
			baseline.append(child)
		var main_scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main_scene)
		for _frame in 12:
			await process_frame
		main_scene.set("world_time_hours", 12.0)
		var chain: Object = main_scene.get("main_mission")
		var cine: Object = chain.get("cinematic")
		await _wait(0.8)
		var guard := 0
		while bool(cine.get("running")) and guard < 40:
			cine.call("skip")
			await _wait(0.2)
			guard += 1
		await _wait(0.4)
		var player := main_scene.get("player") as Node3D
		var hud = main_scene.get("hud")
		match shot_name:
			"interact":
				if main_scene.has_method("_create_field_interaction"):
					main_scene.call("_create_field_interaction", "probe_point", player.global_position + Vector3(1.6, 0.0, 0.0), "무전기 확인", 2.0)
				await _wait(0.4)
			"inventory":
				hud.inventory_ui.call("toggle")
				await _wait(0.5)
			"map":
				(main_scene.get("tactical_map") as Control).call("toggle")
				await _wait(0.5)
			"pause":
				var key := InputEventKey.new()
				key.keycode = KEY_ESCAPE
				key.pressed = true
				var pause_menu := main_scene.get_node_or_null("PauseMenu")
				if pause_menu != null:
					pause_menu.call("_input", key)
				await _wait(0.4)
			"lore":
				var point := Node3D.new()
				point.set_meta("lore_index", 0)
				main_scene.add_child(point)
				main_scene.get("lore_reader").call("show_entry", point)
				await _wait(0.5)
			"result":
				main_scene.set("run_kills", 8)
				# 실제 탈출은 이 플래그를 먼저 세운다 — 안 세우면 조준/체력 캔버스가
				# 정산 패널 위에 그대로 남아 캡처가 실물과 달라진다.
				main_scene.set("extraction_transition_active", true)
				# 실제 탈출은 트리를 멈춘 뒤 정산을 띄운다. 정산 패널은
				# PROCESS_MODE_WHEN_PAUSED라, 멈추지 않으면 보상 칩 등장 트윈이
				# 아예 돌지 않아 칩이 알파 0으로 남는다(캡처가 빈 띠로 나왔다).
				paused = true
				main_scene.call("_show_extraction_result", 0)
				await _wait(1.4)
			"gameover":
				# 사망 화면은 main.gd가 들고 있다(hud 아님). present()는 값만 채우고
				# 패널을 띄우는 건 main의 트윈이라, 캡처에서는 최종 상태를 직접 만든다.
				var over: Object = main_scene.get("game_over_screen")
				over.call("present", {
					# 실물과 같은 모양의 값으로 — main.gd는 _format_survival_time()과
					# format_compact_number()를 넘긴다. 숫자 타일에 문장을 넣으면
					# 검수하는 눈이 레이아웃을 오판한다.
					"kills": 8, "survival_time": "03:34", "damage_text": "1.4K",
					"source_name": "약탈자 사수", "weapon_name": "AK-47", "blocked": 2,
					"loss_value_text": "2.6K", "lesson": "탄약이 다 떨어졌다. 그래서 나는 죽었다. 다음엔 탄창이 하나 남았을 때 탈출구로 간다.",
					"loot": {},
				})
				(over.get("panel") as Control).modulate.a = 1.0
				(over.get("fade") as ColorRect).color.a = 0.62
				await _wait(0.8)
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/field_ui_%s.png" % [OUTPUT_DIR, shot_name]
		if image.save_png(path) == OK:
			print("  SHOT %s" % ProjectSettings.globalize_path(path))
		paused = false
		main_scene.queue_free()
		for child in root.get_children():
			if not baseline.has(child) and child != main_scene:
				child.queue_free()
		await process_frame
		await process_frame
	print("FIELD_UI_AUDIT_CAPTURE_OK")
	quit(0)


func _wait(duration: float) -> void:
	await root.get_tree().create_timer(duration, true, false, true).timeout
