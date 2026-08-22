extends SceneTree

const ROCKET_BOSS := preload("res://scripts/rocket_boss.gd")
const ROCKET_PROJECTILE := preload("res://scripts/rocket_projectile.gd")
const BOSS_MINE := preload("res://scripts/boss_mine.gd")


class DummyTarget:
	extends CharacterBody3D
	var received_damage := 0
	var last_attacker_was_valid := false

	func take_hit(amount: int, _direction: Vector3) -> void:
		received_damage += amount

	func take_hostile_hit(amount: int, direction: Vector3, attacker = null) -> void:
		last_attacker_was_valid = is_instance_valid(attacker)
		take_hit(amount, direction)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var target := DummyTarget.new()
	target.position = Vector3(8.0, 0.78, 0.0)
	arena.add_child(target)

	var boss := CharacterBody3D.new()
	boss.set_script(ROCKET_BOSS)
	boss.call("configure_rocket_boss", target, 0.8)
	arena.add_child(boss)
	await process_frame

	assert(boss.is_in_group("rocket_boss"))
	assert(int(boss.call("get_rocket_magazine_ammo")) == 4)
	var sprite := boss.get("sprite") as AnimatedSprite3D
	assert(sprite != null)
	for direction in ["n", "ne", "e", "se", "s", "sw", "w", "nw"]:
		assert(sprite.sprite_frames.get_frame_count("idle_%s" % direction) == 4)
		assert(sprite.sprite_frames.get_frame_count("walk_%s" % direction) == 4)

	var replacement_texture := load("res://assets/enemies/rocket_boss/up_right_walk_0.png") as Texture2D
	var replacement_frame := replacement_texture.get_image()
	assert(replacement_frame.get_width() == 256 and replacement_frame.get_height() == 256)
	assert(replacement_frame.get_pixel(0, 0).a < 0.01)

	for shot in 4:
		boss.call("_fire_rocket", Vector3.RIGHT)
	assert(int(boss.call("get_rocket_magazine_ammo")) == 0)
	boss.call("_start_boss_reload")
	assert(bool(boss.call("is_rocket_reloading")))

	var direct_rocket := Node3D.new()
	direct_rocket.set_script(ROCKET_PROJECTILE)
	direct_rocket.call(
		"configure", boss, target, Vector3(0.0, 1.0, 0.0),
		target.global_position, 40, 2.65
	)
	arena.add_child(direct_rocket)
	await process_frame
	direct_rocket.call("_detonate")
	assert(target.received_damage == 40)

	boss.call("_start_mine_pattern", Vector3.RIGHT, 8.0)
	assert(str(boss.get("boss_action")) == "mine_approach")
	boss.call("_update_boss_dash", 1.0)
	assert(str(boss.get("boss_action")) == "mine_deploy")
	for _step in 8:
		if str(boss.get("boss_action")) != "mine_deploy":
			break
		boss.call("_update_mine_deploy", 0.18, Vector3.RIGHT)
	assert(str(boss.get("boss_action")) == "mine_retreat")
	var spawned_mines: Array[Node] = []
	for child in arena.get_children():
		if child.get_script() == BOSS_MINE:
			spawned_mines.append(child)
	assert(spawned_mines.size() >= 4 and spawned_mines.size() <= 6)
	assert(int(boss.call("get_mines_deployed_total")) == spawned_mines.size())
	var mine := spawned_mines[0] as Node3D
	await process_frame
	assert(mine.get_node_or_null("MineVisual/MineBody") is MeshInstance3D)
	assert(mine.get_node_or_null("ProximityRing") is MeshInstance3D)
	# 강인도: 낱발 피격은 경직을 만들지 못하고, 누적 문턱(최대 체력 16%)을
	# 넘는 순간에만 그로기가 온다 — 연사 스턴락 봉인 검증.
	boss.set("boss_action", "combat")
	var health_before := int(boss.get("health"))
	# 체력식 하향(유저 신고 "아무리 때려도 안 줄어든다"): (1100+위협×900)×(1+0.30×(티어-1)).
	# 위협 0.8·티어 1이면 1,820 — 하한은 1,100(위협 0)이다. 예전 하한 2,400은 옛 식의 값.
	assert(health_before >= 1100, "보스 체력은 티어 스케일 하한(1100) 이상이어야 한다")
	assert(health_before <= 2000, "보스 체력 하향이 되돌아가면 안 된다(위협 0.8·티어 1 = 1,820)")
	boss.call("take_hit", 40, Vector3.RIGHT)
	assert(str(boss.get("combat_state")) != "stagger", "낱발 피격이 보스를 경직시키면 안 된다")
	assert(int(boss.get("health")) == health_before - 40)
	var groggy_seen := false
	for _hit_index in 12:
		boss.call("take_hit", 200, Vector3.RIGHT)
		if str(boss.get("combat_state")) == "stagger":
			groggy_seen = true
			break
	assert(groggy_seen, "누적 피해가 문턱을 넘으면 그로기가 와야 한다")
	assert(float(boss.get("state_timer")) > 0.5, "그로기는 일반 경직보다 길어야 한다")

	boss.queue_free()
	await process_frame
	target.global_position = mine.global_position
	var damage_before_mine := target.received_damage
	mine.call("_detonate")
	assert(target.received_damage > damage_before_mine)
	assert(not target.last_attacker_was_valid, "A surviving mine must discard its freed boss reference.")

	print("ROCKET_BOSS_OK frames=64 magazine=4 mines=%d damage=%d" % [spawned_mines.size(), target.received_damage])
	arena.queue_free()
	await process_frame
	quit(0)
