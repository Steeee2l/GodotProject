extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := load("res://scripts/scent_trail_manager.gd").new() as Node3D
	var player := Node3D.new()
	var enemy := Node3D.new()
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(manager)
	manager.call("setup", player)
	manager.call("register_mover", enemy, "enemy")
	enemy.position = Vector3(3, 0, 0)
	manager.call("_update_movers", 0.2)
	enemy.position = Vector3(6, 0, 0)
	manager.call("_update_movers", 0.2)
	if float(manager.call("get_strength_near", Vector3(3, 0, 0), "enemy", 3.0)) < 90.0:
		_fail("enemy trail was not recorded at full strength")
	for index in 45:
		manager.call("_update_movers", 0.2)
	if float(manager.call("get_strength_near", player.position, "player", 3.0)) < 60.0:
		_fail("stationary player scent did not accumulate")
	manager.call("set_focus_active", true)
	manager.call("set_guidance_trail", "test_objective", [
		Vector3(2.5, 0.0, 2.5),
		Vector3(5.0, 0.0, 5.0),
		Vector3(10.0, 0.0, 10.0),
	], "objective")
	manager.call("_process", 0.1)
	var visible_marker := false
	var visible_objective_marker := false
	for entry in (manager.get("trails") as Dictionary).values():
		var marker := (entry as Dictionary).get("marker") as Sprite3D
		if is_instance_valid(marker) and marker.visible:
			visible_marker = true
			if str((entry as Dictionary).get("kind", "")) == "objective":
				visible_objective_marker = true
	if not visible_marker:
		_fail("scent focus did not reveal nearby markers")
	if not visible_objective_marker:
		_fail("objective guidance was not visible inside the focus radius")
	var trail_count_before_clear := (manager.get("trails") as Dictionary).size()
	manager.call("clear_guidance_trail", "test_objective")
	if (manager.get("trails") as Dictionary).size() >= trail_count_before_clear:
		_fail("objective guidance trail was not cleared")
	enemy.queue_free()
	await process_frame
	manager.call("_update_movers", 0.2)
	if (manager.get("tracked") as Dictionary).size() != 1:
		_fail("freed mover reference was not removed safely")
	print("SCENT_TRAIL_OK trails=%d" % (manager.get("trails") as Dictionary).size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
