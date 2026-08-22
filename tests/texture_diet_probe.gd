extends SceneTree

# 텍스처 다이어트 픽셀 검증 프로브(창 필요 — --headless 금지).
# 같은 시드·같은 카메라로 씬을 띄워 모든 Sprite3D/AnimatedSprite3D 의
# 월드 크기(텍스처 px × pixel_size)와 화면 바운딩 박스(px)를 JSON 으로 남기고
# 스크린샷을 찍는다. size_limit 적용 전/후를 비교하는 용도.
#   godot --path . --script res://tests/texture_diet_probe.gd -- tag=before scene=field
#   scene = field | shelter | building

const OUTPUT_DIR := "res://test-output"

var tag := "probe"
var scene_kind := "field"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := str(arg).split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"tag": tag = parts[1]
			"scene": scene_kind = parts[1]
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("DIET_PROBE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("map_seed", 47291)
	game_state.set("selected_raid_zone", "jongno_outskirts")
	# procedural_map 의 Array.shuffle() 은 전역 RNG 를 쓴다 — 같은 시드로 같은 판이 나오게 고정.
	seed(47291)
	var scene: Node = null
	match scene_kind:
		"field":
			scene = await _spawn_field(game_state)
		"shelter":
			game_state.call("unlock_all_shelter_facilities")
			scene = (load("res://scenes/shelter_interior.tscn") as PackedScene).instantiate()
			root.add_child(scene)
			await _settle(1.2)
		"building":
			var run_state := root.get_node("BuildingRunState")
			run_state.call("begin_run", "diet_probe_tower", 829173, "res://scenes/main.tscn", Vector3(3, 0.78, 4), 5)
			scene = (load("res://scenes/building_interior.tscn") as PackedScene).instantiate()
			root.add_child(scene)
			await _settle(1.2)
	if scene == null:
		push_error("scene spawn failed")
		quit(1)
		return
	var camera := root.get_viewport().get_camera_3d()
	var records: Array = []
	_collect(scene, camera, records)
	var json_path := "%s/diet_%s_%s.json" % [OUTPUT_DIR, tag, scene_kind]
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"tag": tag,
		"scene": scene_kind,
		"viewport": root.get_viewport().get_visible_rect().size,
		"camera_size": camera.size if camera != null else 0.0,
		"game_state_map_seed": game_state.get("map_seed"),
		"raid_serial": game_state.get("raid_serial"),
		"map_seed": _find_map_seed(scene),
		"sprites": records,
	}, "  "))
	file.close()
	print("PROBE_JSON ", ProjectSettings.globalize_path(json_path), " sprites=", records.size())
	await process_frame
	await process_frame
	_capture("%s/diet_%s_%s.png" % [OUTPUT_DIR, tag, scene_kind])
	quit(0)


func _spawn_field(game_state: Node) -> Node:
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	main_scene.set("world_time_hours", 12.0)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	await create_timer(0.8, true, false, true).timeout
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
	# 이후 움직임을 멈춰 전/후 스크린샷의 구도를 고정한다.
	main_scene.set_process(false)
	main_scene.set_physics_process(false)
	for enemy in main_scene.get("enemies") as Array:
		if is_instance_valid(enemy):
			(enemy as Node).set_physics_process(false)
			(enemy as Node).set_process(false)
	await process_frame
	return main_scene


func _find_map_seed(node: Node) -> int:
	var script := node.get_script() as Script
	if script != null and script.resource_path.ends_with("procedural_map.gd"):
		return int(node.get("map_seed"))
	for child in node.get_children():
		var found := _find_map_seed(child)
		if found != 0:
			return found
	return 0


func _settle(seconds: float) -> void:
	await process_frame
	await physics_frame
	await create_timer(seconds, true, false, true).timeout
	await process_frame


func _collect(node: Node, camera: Camera3D, records: Array) -> void:
	if node is SpriteBase3D:
		var sprite := node as SpriteBase3D
		var texture: Texture2D = null
		if sprite is Sprite3D:
			texture = (sprite as Sprite3D).texture
		elif sprite is AnimatedSprite3D:
			var animated := sprite as AnimatedSprite3D
			if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation):
				texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if texture != null:
			var width_px := float(texture.get_width())
			var height_px := float(texture.get_height())
			if texture is AtlasTexture:
				width_px = (texture as AtlasTexture).region.size.x
				height_px = (texture as AtlasTexture).region.size.y
			var world_w := width_px * sprite.pixel_size
			var world_h := height_px * sprite.pixel_size
			var record := {
				"path": str(sprite.get_path()).replace("/root/", ""),
				"texture": texture.resource_path if not texture.resource_path.is_empty() else texture.get_class(),
				"tex_px": [int(width_px), int(height_px)],
				"pixel_size": sprite.pixel_size,
				"world": [snappedf(world_w, 0.0001), snappedf(world_h, 0.0001)],
				"offset_world": [snappedf(sprite.offset.x * sprite.pixel_size, 0.0001), snappedf(sprite.offset.y * sprite.pixel_size, 0.0001)],
				"pos": [snappedf(sprite.global_position.x, 0.001), snappedf(sprite.global_position.y, 0.001), snappedf(sprite.global_position.z, 0.001)],
			}
			if camera != null:
				var basis := camera.global_transform.basis if sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED else sprite.global_transform.basis
				var center := sprite.global_position + basis.x * sprite.offset.x * sprite.pixel_size + basis.y * sprite.offset.y * sprite.pixel_size
				var corner_a := center - basis.x * world_w * 0.5 - basis.y * world_h * 0.5
				var corner_b := center + basis.x * world_w * 0.5 + basis.y * world_h * 0.5
				var corner_c := center + basis.x * world_w * 0.5 - basis.y * world_h * 0.5
				var screen_a := camera.unproject_position(corner_a)
				var screen_b := camera.unproject_position(corner_b)
				var screen_c := camera.unproject_position(corner_c)
				record["screen_px"] = [snappedf(screen_a.distance_to(screen_c), 0.01), snappedf(screen_c.distance_to(screen_b), 0.01)]
				record["screen_center"] = [snappedf((screen_a.x + screen_b.x) * 0.5, 0.01), snappedf((screen_a.y + screen_b.y) * 0.5, 0.01)]
			records.append(record)
	for child in node.get_children():
		_collect(child, camera, records)


func _capture(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("CAPTURE_OK ", ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패(%s): %s" % [path, error_string(error)])
