extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(6.0).timeout.connect(func() -> void:
		push_error("DAMAGE_NUMBER_TEST_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	var enemies := main_scene.get("enemies") as Array
	var normal_enemy := enemies[0] as CharacterBody3D
	var enemy_health_fill := normal_enemy.get_node("HealthBarFill") as Sprite3D
	var enemy_damage_trail := normal_enemy.get_node("HealthBarDamageTrail") as Sprite3D
	assert(normal_enemy.get_node_or_null("HealthBarBackground") is Sprite3D)
	var normal_health := int(normal_enemy.get("health"))
	normal_enemy.call("take_hit", 9, Vector3.RIGHT, false)
	await process_frame
	assert(enemy_health_fill.region_rect.size.x < enemy_health_fill.texture.get_width())
	assert(enemy_damage_trail.region_rect.size.x > enemy_health_fill.region_rect.size.x)
	var normal_number := _latest_damage_number(main_scene)
	assert(normal_number != null)
	assert(normal_number.text == "9")
	assert(not bool(normal_number.get_meta("critical")))
	assert(int(normal_enemy.get("health")) == normal_health - 9)
	var normal_start_y := normal_number.global_position.y
	await create_timer(0.14).timeout
	assert(normal_number.global_position.y > normal_start_y + 0.01)

	var critical_enemy := enemies[1] as CharacterBody3D
	var critical_health := int(critical_enemy.get("health"))
	critical_enemy.call("take_projectile_hit", 10, Vector3.RIGHT, true, 1.7, "body")
	await process_frame
	var critical_number := _latest_damage_number(main_scene)
	assert(critical_number != null)
	assert(critical_number.text == "17")
	assert(bool(critical_number.get_meta("critical")))
	assert(critical_number.font_size > normal_number.font_size)
	assert(int(critical_enemy.get("health")) == critical_health - 17)

	var head_enemy := enemies[2] as CharacterBody3D
	var head_health := int(head_enemy.get("health"))
	# 어서션 갱신: hit_zone은 명중 등급("center"/"normal"/"graze")이고 "head"
	# 특수 처리(2배·치명타 승격)는 죽은 분기로 제거됐다(take_projectile_hit 주석
	# 참조). is_critical=false면 배율 없이 원래 피해가 그대로 표시되는 게 현재
	# 사양이다 — 이 테스트는 HEAD에서도 이미 깨져 있었다.
	head_enemy.call("take_projectile_hit", 8, Vector3.LEFT, false, 2.0, "head")
	await process_frame
	var head_number := _latest_damage_number(main_scene)
	assert(head_number.text == "8")
	assert(not bool(head_number.get_meta("critical")))
	assert(int(head_enemy.get("health")) == head_health - 8)

	var bullet_script: Script = load("res://scripts/bullet_projectile.gd")
	var projectile: Area3D = bullet_script.new()
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	projectile.set("damage", 10)
	projectile.set("critical_chance", 1.0)
	projectile.set("critical_multiplier", 1.5)
	projectile.set("direction", Vector3.RIGHT)
	main_scene.add_child(projectile)
	var projectile_collision := projectile.get_child(projectile.get_child_count() - 1) as CollisionShape3D
	assert(is_equal_approx((projectile_collision.shape as BoxShape3D).size.x, 0.22))
	var bullet_enemy := enemies[3] as CharacterBody3D
	var centered_origin := bullet_enemy.global_position - Vector3.RIGHT * 3.0
	assert(is_equal_approx(float(projectile.call("_get_hit_damage_scale", bullet_enemy, centered_origin)), 1.3))
	var graze_origin := centered_origin + Vector3(0, 0, 0.48)
	assert(is_equal_approx(float(projectile.call("_get_hit_damage_scale", bullet_enemy, graze_origin)), 0.65))
	var bullet_health := int(bullet_enemy.get("health"))
	projectile.call("_apply_hit", bullet_enemy)
	assert(bool(projectile.get("last_hit_was_critical")))
	var bullet_number := _latest_damage_number(main_scene)
	assert(bullet_number.text == "15")
	assert(bool(bullet_number.get_meta("critical")))
	assert(int(bullet_enemy.get("health")) == bullet_health - 15)

	print("DAMAGE_NUMBER_OK normal=9 critical=17 head=8 projectile=15")
	quit(0)


func _latest_damage_number(main_scene: Node) -> Label3D:
	var latest: Label3D
	for child in main_scene.get_children():
		if child is Label3D and child.name.begins_with("DamageNumber"):
			latest = child as Label3D
	return latest
