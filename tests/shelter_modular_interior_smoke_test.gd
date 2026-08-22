extends SceneTree

const SHELTER_SCENE_PATH := "res://scenes/shelter_interior.tscn"
const FLOOR_TEXTURE_PATH := "res://assets/interiors/shelter_floor_topdown_v3.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/shelter_wall_panel_v3.png"
const BED_TEXTURE_PATH := "res://assets/interiors/shelter_bed_module_v2.png"
const PIPE_TEXTURE_PATH := "res://assets/interiors/shelter_escape_pipe_v1.png"
const WORKBENCH_TEXTURE_PATH := "res://assets/interiors/modules/shelter_workbench_wall_aligned_v4.png"
const SCRATCHER_BANK_TEXTURE_PATH := "res://assets/interiors/modules/scratcher_bank_wall_aligned_v1.png"
const CATNIP_SCRAPER_TEXTURE_PATH := "res://assets/interiors/modules/catnip_scraper_wall_aligned_v1.png"
const TRAINING_TEXTURE_PATH := "res://assets/interiors/modules/shelter_training_wall_aligned_v1.png"
const STORAGE_TEXTURE_PATH := "res://assets/interiors/modules/shelter_storage_wall_aligned_v4.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	assert(ResourceLoader.exists(FLOOR_TEXTURE_PATH))
	assert(ResourceLoader.exists(WALL_TEXTURE_PATH))
	assert(ResourceLoader.exists(BED_TEXTURE_PATH))
	assert(ResourceLoader.exists(PIPE_TEXTURE_PATH))
	assert(ResourceLoader.exists(WORKBENCH_TEXTURE_PATH))
	assert(ResourceLoader.exists(SCRATCHER_BANK_TEXTURE_PATH))
	assert(ResourceLoader.exists(CATNIP_SCRAPER_TEXTURE_PATH))
	assert(ResourceLoader.exists(TRAINING_TEXTURE_PATH))
	assert(ResourceLoader.exists(STORAGE_TEXTURE_PATH))
	var shelter := load(SHELTER_SCENE_PATH).instantiate() as Node3D
	root.add_child(shelter)
	await process_frame
	await physics_frame

	var room_art := shelter.get_node("ShelterInteriorArt") as MeshInstance3D
	assert(room_art != null)
	var room_mesh := room_art.mesh as PlaneMesh
	assert(room_mesh.size == Vector2(48.0, 28.0))
	var room_material := room_mesh.material as StandardMaterial3D
	assert(room_material.albedo_texture.resource_path == FLOOR_TEXTURE_PATH)
	assert(room_material.texture_repeat)
	assert(shelter.get_node("NorthWall01") is MeshInstance3D)
	assert(shelter.get_node("WestWall01") is MeshInstance3D)
	assert(not shelter.has_node("SouthLowWallLeft"))
	assert(not shelter.has_node("EastLowWall"))
	var outside_mesh := (shelter.get_node("BlackOutside") as MeshInstance3D).mesh as PlaneMesh
	assert(outside_mesh.size == Vector2(240.0, 240.0))
	var pipe := shelter.get_node("EscapePipe") as Sprite3D
	assert(pipe.texture.resource_path == PIPE_TEXTURE_PATH)
	# 텍스처 다이어트(size_limit) 이후 pixel_size 는 텍스처 폭에 따라 달라진다 — 월드 폭(4.82m)으로 검증.
	assert(absf(pipe.pixel_size * float(pipe.texture.get_width()) - 4.8246) < 0.01)
	assert(pipe.is_in_group("shelter_exit_pipe"))
	assert(shelter.get_node("EscapePipeCollision") is StaticBody3D)
	var camera := shelter.get_node("ShelterCamera") as Camera3D
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	assert(is_equal_approx(camera.size, 27.0))

	var module_root := shelter.get_node("StageOneModules") as Node3D
	assert(int(module_root.get_meta("stage")) == 1)
	assert(int(module_root.get_meta("cat_capacity")) == 5)
	assert(module_root.get_meta("module_grid_size") == Vector2(2.65, 3.45))
	assert(get_nodes_in_group("shelter_module_slot").size() == 1)
	assert(get_nodes_in_group("shelter_bed").size() == 1)
	assert(get_nodes_in_group("shelter_workbench").size() == 1)
	assert(get_nodes_in_group("scratcher_bank").size() == 1)
	assert(get_nodes_in_group("catnip_scraper").size() == 1)
	assert(get_nodes_in_group("training_facility").size() == 1)
	assert(get_nodes_in_group("shelter_storage").size() == 1)
	for slot in get_nodes_in_group("shelter_module_slot"):
		assert(bool(slot.get_meta("replaceable")))
		assert(str(slot.get_meta("module_kind")) == "bed")
		assert((slot as Node).get_node("ModuleFloorPlate") is MeshInstance3D)
	for bed in get_nodes_in_group("shelter_bed"):
		var sprite := (bed as Node).get_node("BedSprite") as Sprite3D
		assert(sprite.texture.resource_path == BED_TEXTURE_PATH)
		assert(sprite.flip_h)
		var collision := (bed as Node).get_node("BedBody/CollisionShape3D") as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		assert(shape.size == Vector3(2.35, 0.9, 2.95))
		assert((bed as Node).get_node("GroundShadow") is MeshInstance3D)
	# 기계 기물은 전부 걷어냈다 — 시설은 스프라이트 없는 로직 노드로만 존재하고
	# UI(운영 독)에서 연다. 쉘터 바닥에는 침대·NPC·주민만 남는다.
	for facility_group in [
		"shelter_workbench",
		"scratcher_bank",
		"catnip_scraper",
		"training_facility",
		"shelter_storage",
	]:
		var facility := get_nodes_in_group(facility_group)[0] as Node3D
		assert(facility.has_method("interact"))
		assert(facility.get_child_count() == 0)
		assert(not facility.is_in_group("shelter_module"))
	# 접근 상호작용 그룹에는 침대만 남는다.
	for interactive_module in get_nodes_in_group("shelter_module"):
		assert(str((interactive_module as Node).get_meta("module_kind", "")) == "bed")
	# 운영 독이 시설 5종을 연다.
	var ops_dock := shelter.find_child("ShelterOpsDock", true, false) as VBoxContainer
	assert(ops_dock != null)
	for facility_id in [
		"scratcher_bank", "catnip_scraper", "workbench", "training", "storage",
	]:
		assert(ops_dock.get_node_or_null("OpsButton_%s" % facility_id) is Button)

	assert(shelter.get_node("ShelterPlayer") is CharacterBody3D)
	assert(shelter.get("dash_button") is Button)
	for wall_name in [
		"NorthWallCollision", "SouthWallCollision",
		"WestWallCollision", "EastWallCollision",
	]:
		assert(shelter.get_node(wall_name) is StaticBody3D)

	var shortcut := root.get_node_or_null("ShelterDebugShortcut")
	assert(shortcut != null)
	assert(str(ProjectSettings.get_setting("autoload/ShelterDebugShortcut")).ends_with("shelter_debug_shortcut.gd"))
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_1
	key_event.pressed = true
	assert(bool(shortcut.call("is_shelter_shortcut", key_event)))

	print("SHELTER_MODULAR_OK factory_line=true workers=true beds=1 room=48x28")
	quit(0)
