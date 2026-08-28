extends SceneTree

# 무기 표시 규칙 프로브(--headless 가능).
#   걷기 = 숨김 → 조준 = 표시 → 해제 후 0.5s 유지 → 0.15s 페이드 → 숨김.
# 오프닝·필드·건물 세 곳에서 같은 게이트(scripts/raid/weapon_reveal.gd)를 쓰는지 본다.

const WEAPON_REVEAL := preload("res://scripts/raid/weapon_reveal.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, condition: bool, detail: String = "") -> void:
	if not condition:
		failures += 1
	print("%-52s %s %s" % [label, "OK" if condition else "FAIL", detail])


func _run() -> void:
	print("== WEAPON REVEAL PROBE ==")
	_probe_gate_curve()
	await _probe_opening()
	await _probe_field()
	await _probe_building()
	print("WEAPON_REVEAL_PROBE_%s failures=%d" % ["FAIL" if failures > 0 else "OK", failures])
	quit(1 if failures > 0 else 0)


func _probe_gate_curve() -> void:
	var gate := WEAPON_REVEAL.new()
	_check("gate: 시작(걷기) 숨김", not gate.is_drawn(), "alpha=%.2f" % gate.alpha)
	gate.update(0.016, true)
	_check("gate: 조준 즉시 표시", gate.is_drawn() and is_equal_approx(gate.alpha, 1.0))
	# 해제 직후 0.5s 는 그대로.
	var elapsed := 0.0
	while elapsed < 0.45:
		gate.update(0.05, false)
		elapsed += 0.05
	_check("gate: 해제 0.45s 후 아직 표시", is_equal_approx(gate.alpha, 1.0), "alpha=%.2f" % gate.alpha)
	while elapsed < 0.55:
		gate.update(0.05, false)
		elapsed += 0.05
	_check("gate: 0.5s 유예 종료 후 페이드 시작", gate.alpha < 1.0, "alpha=%.2f" % gate.alpha)
	for _step in 10:
		gate.update(0.05, false)
	_check("gate: 페이드 완료(0.15s) 후 숨김", not gate.is_drawn(), "alpha=%.2f" % gate.alpha)


func _probe_opening() -> void:
	var scene := load("res://scenes/opening_sequence.tscn") as PackedScene
	var opening := scene.instantiate() as Node3D
	root.add_child(opening)
	await process_frame
	await physics_frame
	var weapon := opening.get("weapon_sprite") as Sprite3D
	_check("오프닝: 다리 걷는 중 총 숨김", not weapon.visible)
	opening.call("_start_tutorial_move")
	await physics_frame
	_check("오프닝: 이동 튜토리얼에서도 숨김", not weapon.visible)
	opening.set("aim_held", true)
	opening.call("_update_weapon_visual", 0.016)
	_check("오프닝: 조준하면 표시", weapon.visible)
	opening.set("aim_held", false)
	opening.call("_update_weapon_visual", 0.4)
	_check("오프닝: 해제 0.4s 는 유지", weapon.visible)
	opening.call("_update_weapon_visual", 0.3)
	opening.call("_update_weapon_visual", 0.2)
	_check("오프닝: 유예+페이드 뒤 숨김", not weapon.visible, "alpha=%.2f" % weapon.modulate.a)
	opening.queue_free()
	await process_frame


func _probe_field() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	# 필드는 플레이어·무기를 2D 오버레이(BuildingOverlay 캔버스)로 그린다 —
	# 화면에 실제로 보이는 것은 weapon_overlay 다(weapon_sprite 는 항상 숨김).
	var overlay := main_scene.get("weapon_overlay") as Sprite2D
	var combat = main_scene.get("weapon_combat")
	_check(
		"필드: 총을 든 상태로 시작",
		bool(main_scene.get("has_ak")),
		"has_ak=%s" % str(main_scene.get("has_ak"))
	)
	combat.call("update_weapon_reveal", 1.0)
	main_scene.call("_update_building_overlays")
	_check("필드: 걷는 중 총 숨김", not overlay.visible)
	main_scene.set("laser_aim_held", true)
	combat.call("update_weapon_reveal", 0.016)
	main_scene.call("_update_building_overlays")
	_check("필드: 우클릭 조준하면 표시", overlay.visible)
	main_scene.set("laser_aim_held", false)
	combat.call("update_weapon_reveal", 0.4)
	main_scene.call("_update_building_overlays")
	_check("필드: 해제 0.4s 는 유지", overlay.visible)
	combat.call("update_weapon_reveal", 0.3)
	combat.call("update_weapon_reveal", 0.2)
	main_scene.call("_update_building_overlays")
	_check("필드: 유예+페이드 뒤 숨김", not overlay.visible, "alpha=%.2f" % overlay.modulate.a)
	main_scene.set("weapon_reloading", true)
	combat.call("update_weapon_reveal", 0.016)
	main_scene.call("_update_building_overlays")
	_check("필드: 재장전 중 표시 유지", overlay.visible)
	main_scene.set("weapon_reloading", false)
	main_scene.queue_free()
	await process_frame


func _probe_building() -> void:
	var run_state := root.get_node_or_null("BuildingRunState")
	if run_state == null:
		run_state = load("res://scripts/building_run_state.gd").new()
		run_state.name = "BuildingRunState"
		root.add_child(run_state)
	run_state.call(
		"begin_run",
		"weapon_reveal_probe_tower",
		829173,
		"res://scenes/main.tscn",
		Vector3(3, 0.78, 4),
		5
	)
	var interior: Node = (load("res://scenes/building_interior.tscn") as PackedScene).instantiate()
	root.add_child(interior)
	await process_frame
	await process_frame
	await physics_frame
	var weapon := interior.get("weapon_sprite") as Sprite3D
	if weapon == null:
		_check("건물: 무기 스프라이트 확보", false, "weapon_sprite == null")
		interior.queue_free()
		await process_frame
		return
	interior.call("_update_weapon_reveal", 1.0)
	_check("건물: 걷는 중 총 숨김", not weapon.visible)
	interior.set("laser_aim_held", true)
	interior.call("_update_weapon_reveal", 0.016)
	_check("건물: 조준하면 표시", weapon.visible)
	interior.set("laser_aim_held", false)
	interior.call("_update_weapon_reveal", 0.4)
	_check("건물: 해제 0.4s 는 유지", weapon.visible)
	interior.call("_update_weapon_reveal", 0.3)
	interior.call("_update_weapon_reveal", 0.2)
	_check("건물: 유예+페이드 뒤 숨김", not weapon.visible, "alpha=%.2f" % weapon.modulate.a)
	interior.queue_free()
	await process_frame
