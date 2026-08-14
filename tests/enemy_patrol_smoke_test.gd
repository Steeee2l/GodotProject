extends SceneTree

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BULLET_SCRIPT := preload("res://scripts/bullet_projectile.gd")


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

	var decoy := CharacterBody3D.new()
	decoy.position = enemy.global_position + Vector3(4.0, 0.0, 0.0)
	root.add_child(decoy)
	enemy.set("target", decoy)
	enemy.set("alerted", false)
	enemy.set("detection_awareness", 0.0)
	enemy.set("opening_shot_pending", false)
	enemy.set("attack_cooldown", 1.0)
	target.position = enemy.global_position + Vector3(8.0, 0.0, 0.0)
	var player_bullet := Area3D.new()
	player_bullet.set_script(BULLET_SCRIPT)
	player_bullet.set("source_body", target)
	player_bullet.set("direction", Vector3.RIGHT)
	player_bullet.set("damage", 1)
	root.add_child(player_bullet)
	player_bullet.call("_apply_hit", enemy, player_bullet.global_position)
	assert(enemy.get("target") == target, "A player bullet must immediately replace the current combat target.")
	assert(bool(enemy.get("alerted")), "A hit enemy must immediately enter combat.")
	assert(is_equal_approx(float(enemy.get("detection_awareness")), 1.0))
	assert(bool(enemy.get("opening_shot_pending")), "A ranged enemy must prepare immediate return fire.")
	assert(is_zero_approx(float(enemy.get("attack_cooldown"))))
	var ammo_before_return_fire := int(enemy.get("magazine_ammo"))
	# 사거리 밖(8m)에서 맞았으므로 접근+예비동작 시간이 필요하다. 30프레임은
	# 이동속도 리밸런스 후 빠듯해졌다.
	for frame in 150:
		await physics_frame
	assert(
		int(enemy.get("magazine_ammo")) < ammo_before_return_fire,
		"A hit ranged enemy must actually fire back once its short hit reaction ends."
	)
	decoy.queue_free()

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
