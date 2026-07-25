extends SceneTree

const SHELTER_SCENE_PATH := "res://scenes/shelter_interior.tscn"
const FLOOR_TEXTURE_PATH := "res://assets/interiors/shelter_floor_topdown_v3.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/shelter_wall_panel_v3.png"
const BED_TEXTURE_PATH := "res://assets/interiors/shelter_bed_module_v2.png"
const PIPE_TEXTURE_PATH := "res://assets/interiors/shelter_escape_pipe_v1.png"
const WORKBENCH_TEXTURE_PATH := "res://assets/interiors/modules/shelter_workbench_isometric_v6.png"
const SCRATCHER_BANK_TEXTURE_PATH := "res://assets/interiors/modules/scratcher_bank_isometric_v6.png"
const CATNIP_SCRAPER_TEXTURE_PATH := "res://assets/interiors/modules/catnip_scraper_isometric_v5.png"
const TRAINING_TEXTURE_PATH := "res://assets/interiors/modules/shelter_training_isometric_v6.png"
const STORAGE_TEXTURE_PATH := "res://assets/interiors/modules/shelter_storage_wall_v1.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	assert(is_equal_approx(pipe.pixel_size, 0.0043))
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
	var workbench := get_nodes_in_group("shelter_workbench")[0] as Node
	var workbench_sprite := workbench.get_node("WorkbenchSprite") as Sprite3D
	assert(workbench_sprite.texture.resource_path == WORKBENCH_TEXTURE_PATH)
	assert(workbench_sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(workbench_sprite.position.y, 1.95))
	assert(is_equal_approx(workbench_sprite.position.z, 0.02))
	assert(is_equal_approx(workbench_sprite.pixel_size, 0.0042))
	assert(workbench_sprite.scale == Vector3.ONE)
	assert(workbench_sprite.no_depth_test)
	assert(workbench.get_node("GroundShadow") is MeshInstance3D)
	assert(workbench.has_method("interact"))
	var bank := get_nodes_in_group("scratcher_bank")[0] as Node
	var bank_sprite := bank.get_node("BankSprite") as Sprite3D
	assert(bank_sprite.texture.resource_path == SCRATCHER_BANK_TEXTURE_PATH)
	assert(bank_sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(bank_sprite.position.y, 1.98))
	assert(is_equal_approx(bank_sprite.position.z, 0.02))
	assert(bank_sprite.no_depth_test)
	assert(bank.get_node("GroundShadow") is MeshInstance3D)
	assert(bank.has_method("interact"))
	var catnip_scraper := get_nodes_in_group("catnip_scraper")[0] as Node
	var catnip_sprite := catnip_scraper.get_node("ScraperSprite") as Sprite3D
	assert(catnip_sprite.texture.resource_path == CATNIP_SCRAPER_TEXTURE_PATH)
	assert(catnip_sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(catnip_sprite.position.z, 0.02))
	assert(catnip_scraper.get_node("GroundShadow") is MeshInstance3D)
	assert(catnip_scraper.has_method("interact"))
	var training := get_nodes_in_group("training_facility")[0] as Node
	var training_sprite := training.get_node("TrainingSprite") as Sprite3D
	assert(training_sprite.texture.resource_path == TRAINING_TEXTURE_PATH)
	assert(training_sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(training_sprite.position.y, 2.02))
	assert(is_equal_approx(training_sprite.position.z, 0.02))
	assert(training.get_node("GroundShadow") is MeshInstance3D)
	assert(training.has_method("interact"))
	var storage := get_nodes_in_group("shelter_storage")[0] as Node
	var storage_sprite := storage.get_node("StorageSprite") as Sprite3D
	assert(storage_sprite.texture.resource_path == STORAGE_TEXTURE_PATH)
	assert(storage_sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(storage_sprite.position.y, 1.89))
	assert(is_equal_approx(storage_sprite.pixel_size, 0.0041))
	assert(storage_sprite.scale == Vector3.ONE)
	assert(storage_sprite.no_depth_test)
	assert(storage.get_node("GroundShadow") is MeshInstance3D)
	assert(storage.has_method("interact"))
	assert(storage.position.z == catnip_scraper.position.z)
	assert(workbench.position.z == catnip_scraper.position.z)
	assert(bank.position.z == catnip_scraper.position.z)
	assert(training.position.z == catnip_scraper.position.z)

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

	print("SHELTER_MODULAR_OK beds=1 catnip_scraper=true training=true pipe_exit=true room=48x28")
	quit(0)
