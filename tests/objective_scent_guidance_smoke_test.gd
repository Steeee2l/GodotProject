extends SceneTree


class TestWorld extends Node3D:
	func find_nearest_physically_open_position(
		requested: Vector3,
		_radius: float,
		_excluded: Array
	) -> Vector3:
		return requested


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := CharacterBody3D.new()
	var world := TestWorld.new()
	var manager := load("res://scripts/scent_trail_manager.gd").new() as Node3D
	var guidance := load("res://scripts/objective_scent_guidance.gd").new() as Node
	root.add_child(world)
	root.add_child(player)
	root.add_child(manager)
	root.add_child(guidance)
	manager.call("setup", player)
	guidance.call("setup", manager, player, world)

	var primary := Node3D.new()
	primary.position = Vector3(30.0, 0.0, 0.0)
	var marker := MeshInstance3D.new()
	marker.name = "InteractionRing"
	primary.add_child(marker)
	root.add_child(primary)
	guidance.call("register_site", primary, "primary", "objective", 6.5)
	if marker.visible:
		_fail("direct objective marker should start hidden")
	guidance.call("update_guidance", 0.2)
	if str(guidance.get("current_target_id")).is_empty():
		_fail("objective target was not selected")
	if (manager.get("guidance_groups") as Dictionary).is_empty():
		_fail("objective route did not create scent traces")
	manager.call("set_focus_active", true)
	manager.call("_process", 0.1)
	var visible_objective := false
	for entry_value in (manager.get("trails") as Dictionary).values():
		var entry := entry_value as Dictionary
		var scent_marker := entry.get("marker") as Sprite3D
		if str(entry.get("kind", "")) == "objective" and scent_marker.visible:
			visible_objective = true
			break
	if not visible_objective:
		_fail("nearby section of the objective route was not revealed")

	player.position = Vector3(25.0, 0.0, 0.0)
	guidance.call("update_guidance", 0.2)
	if not marker.visible:
		_fail("objective marker did not reveal near the destination")
	print("OBJECTIVE_SCENT_GUIDANCE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
