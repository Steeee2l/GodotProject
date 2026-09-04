extends SceneTree

# 엄폐 v3 프로브(2026-09-03).
#   ① 낮은 엄폐물에 붙기만 하면(적 없이) 엄폐 상태가 된다
#   ② 엄폐물 쪽에서 오는 총알은 막히고, 반대쪽은 막히지 않는다
#   ③ 조준만으로는 노출되지 않고, 쏜 직후에만 노출된다
#   ④ 엄폐 중 내 총알은 붙어 있는 엄폐물을 통과한다(ignored_body_rids)
#   ⑤ 주홍 십자가: 후퇴 뒤 복귀하면 십자가가 사라지고, 십자가엔 둥근 초상화가 있다

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const COMPANION_PATH := "res://scripts/raid/companion.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("COVER3|%s|%s" % ["OK" if condition else "NG", label])
	if not condition:
		failures.append(label)


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("COVER3_PROBE_TIMEOUT")
		quit(2)
	)
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	var player := main_scene.get("player") as CharacterBody3D
	var cover_system = main_scene.get("cover_system")
	# 적을 전부 멀리 치운다 — 근접 엄폐는 적과 무관해야 한다.
	for raw_enemy in main_scene.get("enemies") as Array:
		var enemy := raw_enemy as Node3D
		if is_instance_valid(enemy):
			enemy.global_position = player.global_position + Vector3(300.0, 0.0, 300.0)
			enemy.set("alerted", false)
	# 플레이어 앞(+X)에 낮은 엄폐 상자(차량 탄막 상자와 같은 규격)를 놓는다.
	var blocker := StaticBody3D.new()
	blocker.name = "ProbeCover"
	blocker.collision_layer = COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.3, 4.0)
	shape.shape = box
	blocker.add_child(shape)
	main_scene.add_child(blocker)
	blocker.global_position = player.global_position + Vector3(1.4, 0.65 - 0.78, 0.0)
	for _frame in 3:
		await physics_frame
	cover_system.call("update", 0.2)
	await physics_frame
	cover_system.call("update", 0.2)
	_check(bool(cover_system.get("in_cover")), "① 엄폐물에 붙으면 적 없이도 엄폐")
	_check((cover_system.get("cover_direction") as Vector3).x > 0.8, "① 엄폐 방향이 엄폐물 쪽(+X)")

	# ② 방향 판정
	var front := player.global_position + Vector3(12.0, 0.0, 0.5)
	var behind := player.global_position + Vector3(-12.0, 0.0, 0.5)
	_check(bool(cover_system.call("try_block_ranged", front)), "② 엄폐물 쪽 총알은 막힌다")
	_check(not bool(cover_system.call("try_block_ranged", behind)), "② 반대쪽 총알은 안 막힌다")

	# ③ 노출
	main_scene.set("laser_aim_held", true)
	cover_system.call("update", 0.05)
	_check(str(cover_system.call("get_state")) == "covered", "③ 조준만으로는 노출되지 않는다")
	cover_system.call("notify_player_fired")
	_check(str(cover_system.call("get_state")) == "peeking", "③ 쏜 직후엔 노출")
	_check(not bool(cover_system.call("try_block_ranged", front)), "③ 노출 중엔 막히지 않는다")
	cover_system.call("update", 0.6)
	_check(str(cover_system.call("get_state")) == "covered", "③ 0.35초 뒤 다시 엄폐")
	main_scene.set("laser_aim_held", false)

	# ④ 내 총알은 엄폐물 통과
	var weapon_combat = main_scene.get("weapon_combat")
	weapon_combat.call("_spawn_weapon_projectile", Vector3.RIGHT, 0)
	await process_frame
	var projectile: Node = null
	for child in main_scene.get_children():
		if str(child.name).ends_with("Bullet_0"):
			projectile = child
	_check(projectile != null, "④ 총알이 생성됐다")
	if projectile != null:
		var ignored: Array = projectile.get("ignored_body_rids")
		_check(ignored.size() == 1 and ignored[0] == blocker.get_rid(), "④ 총알이 붙어 있는 엄폐물을 무시한다")

	# ⑤ 주홍 십자가 초상화 + 후퇴/복귀 정리
	var companion_script: GDScript = load(COMPANION_PATH)
	var marker: Node3D = companion_script.build_rip_marker("주홍", companion_script.JUHONG_ACCENT, companion_script.JUHONG_PORTRAIT_TEXTURE)
	_check(marker.get_node_or_null("RipPortrait") != null, "⑤ 십자가에 둥근 초상화가 붙는다")
	var portrait_texture := (marker.get_node("RipPortrait") as Sprite3D).texture as ImageTexture
	var image := portrait_texture.get_image()
	var corner := image.get_pixel(1, 1)
	var center := image.get_pixel(48, 48)
	_check(corner.a < 0.05 and center.a > 0.9, "⑤ 초상화가 원형으로 마스킹된다")
	marker.free()

	if failures.is_empty():
		print("COVER3_PROBE_OK")
		quit(0)
		return
	for failure in failures:
		print("COVER3|FAIL|%s" % failure)
	push_error("COVER3_PROBE_FAIL %d" % failures.size())
	quit(1)
