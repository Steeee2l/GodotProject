extends SceneTree

const ENTRANCE_SCENE := preload("res://scenes/modules/building_entrance_portal.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var portal := ENTRANCE_SCENE.instantiate()
	root.add_child(portal)
	await process_frame
	portal.call("enter_building", null)
	assert(bool(portal.get("transition_pending")))
	assert(bool(root.get_node("BuildingRunState").get("active")))
	portal.call("enter_building", null)
	await process_frame
	await process_frame
	assert(current_scene != null)
	assert(current_scene.scene_file_path == "res://scenes/building_interior.tscn")
	print("BUILDING_PORTAL_TRANSITION_OK")
	quit(0)
