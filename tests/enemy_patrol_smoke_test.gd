extends SceneTree

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40.0, 0.2, 40.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.75
	floor.add_child(floor_shape)
	root.add_child(floor)

	var target := CharacterBody3D.new()
	target.name = "Player"
	target.position = Vector3(30.0, 0.0, 30.0)
	root.add_child(target)

	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = Vector3.ZERO
	enemy.call("configure", "pistol", target, {}, 0.0, "m1911")
	root.add_child(enemy)
	await physics_frame
	var route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(5.0, 0.0, 0.0),
		Vector3(5.0, 0.0, 5.0),
	]
	enemy.call("configure_patrol", "route", route)
	enemy.set("patrol_pause", 0.0)
	var start := enemy.global_position
	for frame in 90:
		await physics_frame
	if enemy.global_position.distance_to(start) < 0.8:
		push_error("ENEMY_PATROL: patrol enemy remained stationary")
		quit(1)
		return

	target.queue_free()
	await process_frame
	var untargeted_start := enemy.global_position
	enemy.set("patrol_pause", 0.0)
	for frame in 70:
		await physics_frame
	if enemy.global_position.distance_to(untargeted_start) < 0.35:
		push_error("ENEMY_PATROL: enemy stopped permanently after losing its target reference")
		quit(1)
		return

	print("ENEMY_PATROL_OK distance=%.2f" % enemy.global_position.distance_to(start))
	quit(0)
