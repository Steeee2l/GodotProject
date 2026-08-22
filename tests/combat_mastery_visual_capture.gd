extends SceneTree

# 전투 숙련도 패키지 스크린샷 프로브(창 필요 — --headless 금지).
#   1) combat_mastery_grenade_telegraph.png : 착탄 원 + 붉은 포물선 예고
#   2) combat_mastery_aim_line.png          : 사수 조준선 플래시(깜빡임이 켜진 프레임)
#   3) combat_mastery_cover_headshot.png    : 엄폐 칩 + 헤드샷 주황 팝
#
# 1·2번은 3D 예고를 읽히게 하려고 HUD 레이어를 숨기고, 3번은 엄폐 칩이 HUD라 켠다.

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const TELEGRAPH := preload("res://scripts/raid/telegraph_fx.gd")
const GRENADE_OUTPUT := "res://test-output/combat_mastery_grenade_telegraph.png"
const AIM_LINE_OUTPUT := "res://test-output/combat_mastery_aim_line.png"
const COVER_OUTPUT := "res://test-output/combat_mastery_cover_headshot.png"

var main_scene: Node
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_MASTERY_CAPTURE_TIMEOUT")
		quit(2)
	)
	var accessibility := root.get_node("AccessibilitySettings")
	accessibility.set("damage_numbers_enabled", true)
	accessibility.set("hit_flash_scale", 1.0)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	await create_timer(0.8, true, false, true).timeout
	# 필드 진입 시네마틱이 카메라를 점유하면 엉뚱한 곳을 찍는다 — 스킵.
	var main_mission = main_scene.get("main_mission")
	var skip_guard := 0
	while (
		main_mission != null
		and bool(main_mission.call("is_cinematic_active"))
		and skip_guard < 20
	):
		main_mission.get("cinematic").call("skip")
		skip_guard += 1
		await create_timer(0.25, true, false, true).timeout
	await create_timer(0.6, true, false, true).timeout
	player = main_scene.get_node("Player") as CharacterBody3D
	# 캡처 중 적탄에 맞아 화면이 흔들리지 않게.
	player.collision_layer = 0
	# 카메라 크기는 main이 매 프레임 목표값으로 되돌린다 — 캡처 동안 main의
	# 갱신을 멈추고(트윈·예고·데미지 팝은 계속 돈다) 줌을 당겨 예고가 읽히게.
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	var camera := main_scene.get_node("CameraRig/Camera3D") as Camera3D
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size *= 0.62

	await _capture_grenade_telegraph()
	await _capture_aim_line()
	await _capture_cover_headshot()
	quit(0)


func _spawn_enemy(kind: String, offset: Vector3, weapon_id: String) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.name = "CaptureEnemy_%s" % kind
	enemy.set_script(ENEMY_SCRIPT)
	main_scene.add_child(enemy)
	enemy.global_position = player.global_position + offset
	enemy.call("configure", kind, player, {}, 0.3, weapon_id)
	enemy.call("set_player_visibility_factor", 1.0)
	enemy.visible = true
	# 즉시 교전 상태로 — 캡처는 '경계→추격' 연출이 아니라 예고 프레임을 찍는다.
	enemy.set("alerted", true)
	enemy.set("detection_awareness", 1.0)
	enemy.set("combat_reaction_time", 0.0)
	enemy.set("pursuit_time", 100.0)
	enemy.set("perception_state", "combat")
	enemy.set("attack_cooldown", 0.0)
	enemy.set("grenade_cooldown", 0.0)
	enemy.set("opening_shot_pending", false)
	return enemy


func _set_hud_visible(value: bool) -> void:
	(main_scene.get_node("HUD") as CanvasLayer).visible = value


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


# ── 샷 1: 착탄 원 + 포물선 예고 ────────────────────────────────────

func _capture_grenade_telegraph() -> void:
	_set_hud_visible(false)
	# 투척 사거리(7~28) 안 + 던지는 적까지 한 화면에 — 최소 사거리 7.0 바로 위로.
	var enemy := _spawn_enemy("grenadier", Vector3(5.4, 0.0, -5.4), "")
	var winding := await _wait_until(
		func() -> bool:
			return (
				str(enemy.get("combat_state")) == "grenade_windup"
				and int(enemy.call("get_active_telegraph_count")) >= 2
			),
		8.0
	)
	if not winding:
		push_error("샷1: 척탄병이 투척 와인드업에 들어가지 않았습니다(%s)." % str(enemy.get("combat_state")))
	# 착탄 원의 채움 트윈이 가장 진한 초반 + 포물선 구슬이 켜진 프레임.
	await create_timer(0.16, true, false, true).timeout
	await _wait_until(func() -> bool: return _arc_beads_lit(), 0.4)
	await process_frame
	_capture(GRENADE_OUTPUT, "circles=%d arcs=%d" % [
		TELEGRAPH.get_active_count(TELEGRAPH.KIND_LANDING),
		TELEGRAPH.get_active_count(TELEGRAPH.KIND_ARC),
	])
	enemy.call("_clear_telegraphs")
	enemy.queue_free()
	await process_frame


func _arc_beads_lit() -> bool:
	# 포물선 구슬은 0.16s 주기로 투명도를 오르내린다 — 진한(투명도 낮은) 프레임을 고른다.
	for node in TELEGRAPH.get_active_nodes(TELEGRAPH.KIND_ARC):
		var beads := node.get_node_or_null("Beads")
		if beads == null or beads.get_child_count() == 0:
			continue
		if float((beads.get_child(0) as GeometryInstance3D).transparency) < 0.2:
			return true
	return false


# ── 샷 2: 사수 조준선 플래시 ───────────────────────────────────────

func _capture_aim_line() -> void:
	_set_hud_visible(false)
	var enemy := _spawn_enemy("ranged", Vector3(5.6, 0.0, -3.2), "m1911")
	var shown := await _wait_until(
		func() -> bool:
			return (
				bool(enemy.get("aim_line_shown"))
				and TELEGRAPH.get_active_count(TELEGRAPH.KIND_AIM_LINE) >= 1
			),
		8.0
	)
	if not shown:
		push_error("샷2: 조준선 예고가 뜨지 않았습니다(%s)." % str(enemy.get("combat_state")))
	# 조준선은 0.15s 주기로 깜빡인다 — 선이 켜진(불투명한) 프레임에서 찍는다.
	var lit := await _wait_until(func() -> bool: return _aim_beam_lit(), 0.5)
	if not lit:
		push_error("샷2: 조준선이 켜진 프레임을 잡지 못했습니다.")
	await process_frame
	_capture(AIM_LINE_OUTPUT, "aim_lines=%d" % TELEGRAPH.get_active_count(TELEGRAPH.KIND_AIM_LINE))
	enemy.call("_clear_telegraphs")
	enemy.queue_free()
	await process_frame


func _aim_beam_lit() -> bool:
	for node in TELEGRAPH.get_active_nodes(TELEGRAPH.KIND_AIM_LINE):
		var beam := node.get_node_or_null("Beam") as GeometryInstance3D
		if beam != null and beam.transparency < 0.25:
			return true
	return false


# ── 샷 3: 엄폐 칩 + 헤드샷 주황 팝 ─────────────────────────────────

func _capture_cover_headshot() -> void:
	# 엄폐 칩은 HUD라 이번 샷은 HUD를 켠다.
	_set_hud_visible(true)
	# 진입 시네마틱·냄새 독백이 남긴 토스트가 엄폐 칩을 가린다 — 한 번 비우면
	# 이 샷에서 새로 뜨는 건 숙련도 레슨(착탄 원·헤드샷)뿐이다.
	var hud_node = main_scene.get("hud")
	var toast_stack := hud_node.get("toast_stack") as Node
	if toast_stack != null:
		for toast in toast_stack.get_children():
			toast.queue_free()
		await process_frame
	var cover_system = main_scene.get("cover_system")
	# 시야 안개의 밝은 원 안(팝이 가려지지 않는다) + 데미지 팝이 화면 중앙
	# 토스트 스택 위로 떠서 겹치지 않는 자리.
	var target := _spawn_enemy("melee", Vector3(-2.6, 0.0, 1.5), "")
	target.set_physics_process(false)
	target.set("health", 100000)
	target.set("max_health", 100000)
	await create_timer(0.3, true, false, true).timeout
	# 엄폐 상태를 켠 뒤 칩을 한 번 갱신한다(main의 매 프레임 갱신은 멈춰 있다).
	cover_system.set("in_cover", true)
	cover_system.set("exposed_time", 0.0)
	main_scene.call("_update_cover_feedback")
	# 헤드샷 — hit_zone "head"가 ×1.6 피해와 주황 팝을 만든다(탄이 정하는 게 아니라
	# 적이 정한다: enemy.take_projectile_hit).
	target.call("take_projectile_hit", 42, Vector3.RIGHT, false, 1.65, "head", null)
	await create_timer(0.1, true, false, true).timeout
	target.call("take_projectile_hit", 38, Vector3.RIGHT, false, 1.65, "head", null)
	main_scene.call("_update_cover_feedback")
	await create_timer(0.06, true, false, true).timeout
	await process_frame
	_capture(COVER_OUTPUT, "chip=%s headshots=%d" % [
		str(hud_node.get("cover_chip_state")), int(target.get("headshots_taken")),
	])
	target.queue_free()
	await process_frame


func _capture(path: String, note: String = "") -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK %s %s" % [ProjectSettings.globalize_path(path), note])
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
