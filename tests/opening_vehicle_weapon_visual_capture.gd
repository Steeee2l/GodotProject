extends SceneTree

# 스크린샷 프로브(창 필요 — --headless 금지).
#   1) opening_taxi_collision_overlay.png : 택시 위 붉은 충돌 표시가 그림과 맞는가
#   2) opening_weapon_hidden_walk.png     : 걷는 중 — 손에 총이 없다
#   3) opening_weapon_shown_aim.png       : 조준 중 — 총이 나타난다

const TAXI_SHOT := "res://test-output/opening_taxi_collision_overlay.png"
const WALK_SHOT := "res://test-output/opening_weapon_hidden_walk.png"
const AIM_SHOT := "res://test-output/opening_weapon_shown_aim.png"

var opening: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("OPENING_CAPTURE_TIMEOUT")
		quit(2)
	)
	var scene := load("res://scenes/opening_sequence.tscn") as PackedScene
	opening = scene.instantiate() as Node3D
	root.add_child(opening)
	await process_frame
	await physics_frame
	await create_timer(0.6, true, false, true).timeout

	# ── 1) 택시 충돌 표시 정합 ──────────────────────────────────────
	# 카메라를 택시 위로 옮기고 줌을 당긴다. 시야 안개·HUD 는 그림을 가리므로 끈다.
	var camera := opening.get("camera") as Camera3D
	var camera_rig := opening.get("camera_rig") as Node3D
	opening.set_physics_process(false)
	opening.set_process(false)
	var visibility_rect := opening.get("visibility_rect") as ColorRect
	if visibility_rect != null:
		visibility_rect.visible = false
	for hud_layer in opening.get_children():
		if hud_layer is CanvasLayer:
			(hud_layer as CanvasLayer).visible = false
	camera_rig.position = Vector3(-3.5, 0.0, 27.0)
	camera.size = 9.0
	camera.look_at(camera_rig.global_position + Vector3(0, 0.4, 0))
	await process_frame
	await process_frame
	_capture(TAXI_SHOT, "taxi collision overlay")

	# ── 2) 걷는 중 무기 숨김 ────────────────────────────────────────
	opening.set_physics_process(true)
	opening.set_process(true)
	opening.call("_start_tutorial_move")
	await physics_frame
	opening.set("aim_held", false)
	opening.set("fire_held", false)
	for _step in 30:
		await physics_frame
	opening.set_physics_process(false)
	camera.size = 6.5
	await process_frame
	var weapon := opening.get("weapon_sprite") as Sprite3D
	_capture(WALK_SHOT, "weapon_visible=%s" % str(weapon.visible))

	# ── 3) 조준 중 무기 표시 ────────────────────────────────────────
	opening.set("aim_held", true)
	opening.call("_update_weapon_visual", 0.016)
	await process_frame
	await process_frame
	_capture(AIM_SHOT, "weapon_visible=%s" % str(weapon.visible))
	quit(0)


func _capture(path: String, note: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK %s %s" % [ProjectSettings.globalize_path(path), note])
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
