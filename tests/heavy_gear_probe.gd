extends SceneTree

# 중장비(소모성 화력) 1차 프로브 — 지뢰 → 감시포탑 → 로켓 발사기.
#   헤드리스(검증만):  godot --headless --path . --script res://tests/heavy_gear_probe.gd
#   창 모드(스크린샷): godot --path . --script res://tests/heavy_gear_probe.gd
#
# ① 작업대 제작 — 재료(고철+부품) 소모 / GameState.add_heavy_gear 지급 / 지뢰 3개 1칸
# ② T 순환 목록 — 보유한 것만(통조림→지뢰→포탑→로켓), on_throw_key로 순환
# ③ 지뢰 — 투척→무장(1s)→적 진입→폭발, 적 피해·플레이어 무피해
# ④ 포탑 — 배치·발사(적 조준 사격 수)·동시 1기 제한·만료 파괴
# ⑤ 로켓 — 발사 쿨다운·3발 소진 시 아이템 소멸
# ⑥ 시체 왕복 — 사망 시 heavy가 시체로, get_item_count 합산, 회수로 복귀
#
# 시간 의존 검증(비행·무장·만료)은 전부 create_timer 실시간 대기.

const OUTPUT_DIR := "res://test-output"

# 오토로드(GameState) 식별자를 참조하는 스크립트를 --script 콜드 스타트에서
# preload로 물면 컴파일이 깨진다(enemy.gd의 같은 함정) — 런타임 load로 늦춘다.
var raid_loss_manager: GDScript

var game_state: Node
var main_scene: Node
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _sleep(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
	await process_frame


func _capture(capture_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])


func _run() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		push_error("HEAVY_GEAR_PROBE_TIMEOUT")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	raid_loss_manager = load("res://scripts/raid_loss_manager.gd")
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", false)

	# ── ① 작업대 제작: 소모/지급 ──────────────────────────────
	print("[1] 작업대 중장비 제작 — 재료 소모·지급")
	game_state.set("scrap", 100000)
	game_state.call("add_mod_component", "magazine_spring", 6)
	game_state.call("add_mod_component", "rubber_gasket", 6)
	game_state.call("add_mod_component", "scope_lens", 2)
	game_state.call("add_mod_component", "precision_gear", 1)
	game_state.call("add_mod_component", "military_alloy", 1)
	var workbench: Node3D = load("res://scripts/shelter_workbench_module.gd").new()
	workbench.name = "ProbeWorkbench"
	root.add_child(workbench)
	await process_frame
	var heavy_recipes: Array = workbench.call("_recipes_for_category", "heavy")
	_check(heavy_recipes.size() == 3, "중장비 레시피 3종 (실제: %d)" % heavy_recipes.size())
	var recipe_by_id := {}
	for recipe_raw in heavy_recipes:
		recipe_by_id[str((recipe_raw as Dictionary).get("id", ""))] = recipe_raw
		_check(
			not str((recipe_raw as Dictionary).get("desc", "")).is_empty(),
			"%s 설명이 HEAVY_GEAR_DEFS에서 채워짐" % str((recipe_raw as Dictionary).get("id", ""))
		)
	var scrap_before := int(game_state.get("scrap"))
	var spring_before := int(game_state.call("get_mod_component_count", "magazine_spring"))
	workbench.call("_craft", recipe_by_id["craft_field_mine"])
	_check(int(game_state.call("get_heavy_gear_count", "field_mine")) == 3, "지뢰 x3 지급")
	_check(int(game_state.get("scrap")) == scrap_before - 600, "지뢰 제작 고철 600 소모")
	_check(int(game_state.call("get_mod_component_count", "magazine_spring")) == spring_before - 1, "탄창 스프링 1 소모")
	workbench.call("_craft", recipe_by_id["craft_salvage_turret"])
	_check(int(game_state.call("get_heavy_gear_count", "salvage_turret")) == 1, "포탑 x1 지급")
	_check(int(game_state.call("get_mod_component_count", "precision_gear")) == 0, "정밀 기어 1 소모")
	workbench.call("_craft", recipe_by_id["craft_rocket_launcher"])
	_check(int(game_state.call("get_heavy_gear_count", "rocket_launcher")) == 1, "로켓 발사기 x1 지급")
	_check(int(game_state.call("get_mod_component_count", "military_alloy")) == 0, "군용 합금 1 소모")
	# 재료 부족이면 거절 — 합금이 0이 됐으니 로켓은 더 못 만든다.
	workbench.call("_craft", recipe_by_id["craft_rocket_launcher"])
	_check(int(game_state.call("get_heavy_gear_count", "rocket_launcher")) == 1, "재료 부족 시 제작 거절")
	_check(int(game_state.call("get_raid_item_slot_cost", "heavy", "field_mine", 3)) == 1, "지뢰 3개 = 가방 1칸")
	workbench.queue_free()
	await process_frame

	# ── 필드 씬 기동 ─────────────────────────────────────────
	print("[2] 필드 기동 + T 순환 목록")
	game_state.set("canned_food", 2)
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	await _sleep(0.5)
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	var player := main_scene.get_node("Player") as CharacterBody3D
	# 적탄이 프로브를 흔들지 않게 플레이어 충돌만 끈다(중장비는 물리 무관).
	player.collision_layer = 0

	# ── ② T 순환 ────────────────────────────────────────────
	var can_throw = main_scene.get("can_throw")
	var available: Array = can_throw.call("get_available_kinds")
	_check(
		available == ["canned_food", "field_mine", "salvage_turret", "rocket_launcher"],
		"순환 목록 = 통조림→지뢰→포탑→로켓 (실제: %s)" % str(available)
	)
	can_throw.call("on_throw_key")
	_check(bool(can_throw.call("is_aiming")), "T 1회 = 조준 열림")
	_check(str(can_throw.get("selected_kind")) == "canned_food", "기본 선택 = 통조림")
	can_throw.call("on_throw_key")
	_check(str(can_throw.get("selected_kind")) == "field_mine", "조준 중 T = 지뢰로 순환")
	can_throw.call("on_throw_key")
	_check(str(can_throw.get("selected_kind")) == "salvage_turret", "다음 = 포탑")
	can_throw.call("on_throw_key")
	_check(str(can_throw.get("selected_kind")) == "rocket_launcher", "다음 = 로켓")
	can_throw.call("on_throw_key")
	_check(str(can_throw.get("selected_kind")) == "canned_food", "한 바퀴 돌아 통조림")
	# 통조림만 남기면 T는 취소로 동작한다.
	game_state.set("canned_food", 2)
	var mines_backup := int(game_state.call("get_heavy_gear_count", "field_mine"))
	game_state.call("consume_heavy_gear", "field_mine", mines_backup)
	var turret_backup := int(game_state.call("get_heavy_gear_count", "salvage_turret"))
	game_state.call("consume_heavy_gear", "salvage_turret", turret_backup)
	var rocket_backup := int(game_state.call("get_heavy_gear_count", "rocket_launcher"))
	game_state.call("consume_heavy_gear", "rocket_launcher", rocket_backup)
	can_throw.call("on_throw_key")
	_check(not bool(can_throw.call("is_aiming")), "품목 하나뿐이면 T 재입력 = 취소")
	game_state.call("add_heavy_gear", "field_mine", mines_backup)
	game_state.call("add_heavy_gear", "salvage_turret", turret_backup)
	game_state.call("add_heavy_gear", "rocket_launcher", rocket_backup)

	# ── ③ 지뢰 ──────────────────────────────────────────────
	print("[3] 지뢰 — 무장 → 적 진입 → 폭발")
	var deployables = main_scene.get("deployables")
	var enemies := main_scene.get("enemies") as Array
	_check(enemies.size() >= 2, "필드에 프로브용 적 2명 이상")
	var mine_target: Vector3 = player.global_position + Vector3(8.0, 0.0, 0.0)
	var mines_before := int(game_state.call("get_heavy_gear_count", "field_mine"))
	game_state.call("consume_heavy_gear", "field_mine", 1)
	deployables.call("throw_mine", mine_target)
	_check(int(deployables.get("mines_thrown")) == 1, "지뢰 투척 카운트 1")
	# 비행 0.42s + 무장 1.0s — 실시간 대기 후에도 아직 안 터졌어야 한다.
	await _sleep(1.7)
	_check(int(deployables.get("mine_explosions")) == 0, "적 진입 전에는 터지지 않는다(무장 대기)")
	var mine_enemy := enemies[0] as CharacterBody3D
	var enemy_health_before := int(mine_enemy.get("health"))
	var player_health_before := int(main_scene.get("player_health"))
	mine_enemy.global_position = mine_target + Vector3(0.5, 0.0, 0.0)
	await _sleep(0.8)
	_check(int(deployables.get("mine_explosions")) == 1, "적 1.3m 진입 → 폭발")
	var enemy_health_after := int(mine_enemy.get("health")) if is_instance_valid(mine_enemy) else 0
	_check(
		not is_instance_valid(mine_enemy) or bool(mine_enemy.get("dying")) or enemy_health_after < enemy_health_before,
		"지뢰 폭발이 적에게 피해 (%d → %d)" % [enemy_health_before, enemy_health_after]
	)
	_check(int(main_scene.get("player_health")) == player_health_before, "플레이어는 자기 지뢰에 무피해")
	_check(int(game_state.call("get_heavy_gear_count", "field_mine")) == mines_before - 1, "지뢰 1개 소모")

	# ── ④ 포탑 ──────────────────────────────────────────────
	print("[4] 감시포탑 — 배치·사격·1기 제한·만료")
	var turret_position: Vector3 = player.global_position + Vector3(4.0, 0.0, 0.0)
	game_state.call("consume_heavy_gear", "salvage_turret", 1)
	deployables.call("place_turret", turret_position)
	var turret := deployables.get("active_turret") as Node3D
	_check(is_instance_valid(turret), "포탑 노드 배치")
	_check(turret.get_node_or_null("TurretSprite") != null, "포탑 스프라이트(리컬러) 존재")
	# 적을 사거리 안으로 — 2발/s 사격이 시작돼야 한다.
	var turret_enemy: CharacterBody3D = null
	for enemy_value in enemies:
		var candidate := enemy_value as CharacterBody3D
		# 지뢰 실험의 피해자(빈사)를 고르면 포탑 첫 발에 죽어 사격 수가 1에서 끝난다.
		if is_instance_valid(candidate) and not bool(candidate.get("dying")) and candidate != mine_enemy:
			turret_enemy = candidate
			break
	_check(turret_enemy != null, "포탑 표적용 생존 적 존재")
	if turret_enemy != null:
		turret_enemy.global_position = turret_position + Vector3(4.0, 0.0, 0.0)
		# AI가 걸어 나가거나 벽 뒤로 들어가면 발사 수가 흔들린다 — 표적을 고정하고
		# 체력도 넉넉히 줘서 "서 있으면 2발/s"만 잰다.
		turret_enemy.set_physics_process(false)
		turret_enemy.set("health", 500)
	var shots_before := int(deployables.get("turret_shots_fired"))

	await _sleep(1.6)

	var shots_after := int(deployables.get("turret_shots_fired"))
	_check(shots_after >= shots_before + 2, "1.6s 동안 2발 이상 사격 (실제: %d발)" % (shots_after - shots_before))
	# 동시 1기 제한 — 새로 설치하면 기존 것이 파괴된다.
	game_state.call("add_heavy_gear", "salvage_turret", 1)
	game_state.call("consume_heavy_gear", "salvage_turret", 1)
	deployables.call("place_turret", turret_position + Vector3(1.5, 0.0, 0.0))
	var second_turret := deployables.get("active_turret") as Node3D
	_check(is_instance_valid(second_turret) and second_turret != turret, "재설치 시 새 포탑으로 교체")
	_check(not is_instance_valid(turret) or bool(turret.get("destroyed")), "기존 포탑은 파괴")
	# 만료 — 45초를 기다리는 대신 잔여 시간을 줄여 실시간으로 관찰한다.
	second_turret.set("lifetime_left", 0.4)
	await _sleep(1.4)
	_check(
		not is_instance_valid(second_turret) or bool(second_turret.get("destroyed")),
		"가동 시간 소진 → 포탑 파괴"
	)
	_check(deployables.get("active_turret") == null or not is_instance_valid(deployables.get("active_turret")), "만료 후 active_turret 해제")

	# ── ⑤ 로켓 ──────────────────────────────────────────────
	print("[5] 로켓 발사기 — 쿨다운·3발 소진")
	_check(int(game_state.call("get_heavy_gear_count", "rocket_launcher")) == 1, "발사기 1정 보유")
	var rocket_target: Vector3 = player.global_position + Vector3(10.0, 0.0, 3.0)
	_check(bool(deployables.call("fire_rocket", rocket_target)), "1발 발사")
	_check(int(deployables.get("rocket_charges_left")) == 2, "남은 발수 2")
	_check(not bool(deployables.call("fire_rocket", rocket_target)), "쿨다운 1.2s 중 연사 거절")
	deployables.set("rocket_cooldown_left", 0.0)
	_check(bool(deployables.call("fire_rocket", rocket_target)), "2발 발사")
	deployables.set("rocket_cooldown_left", 0.0)
	_check(bool(deployables.call("fire_rocket", rocket_target)), "3발 발사")
	_check(int(game_state.call("get_heavy_gear_count", "rocket_launcher")) == 0, "3발 소진 → 발사기 소멸")
	_check(int(deployables.get("rocket_charges_left")) == -1, "발수 상태 초기화(다음 발사기는 새 3발)")
	deployables.set("rocket_cooldown_left", 0.0)
	_check(not bool(deployables.call("fire_rocket", rocket_target)), "발사기 없음 → 발사 거절")
	await _sleep(1.2)

	# ── ⑥ 시체 왕복 ─────────────────────────────────────────
	print("[6] 사망 소실 → 시체 회수 왕복")
	game_state.get("heavy_gear_inventory").clear()
	game_state.set("canned_food", 0)
	game_state.set("medkits", 0)
	game_state.set("churu", 0)
	for component_key in game_state.get("mod_component_inventory").keys():
		game_state.get("mod_component_inventory")[component_key] = 0
	for ammo_key in game_state.get("ammo_inventory").keys():
		game_state.get("ammo_inventory")[ammo_key] = 0
	game_state.call("add_heavy_gear", "field_mine", 2)
	game_state.call("add_heavy_gear", "rocket_launcher", 1)
	# 시큐어 슬롯이 시체 몫을 빼돌리지 않게 비운다(중장비는 후보가 아니지만 결정성).
	(game_state.get("secure_dog_items") as Array).clear()
	var corpse_loot: Dictionary = raid_loss_manager.store_death_corpse(player.global_position)
	var corpse_heavy := corpse_loot.get("heavy_gear_inventory", {}) as Dictionary
	_check(int(corpse_heavy.get("field_mine", 0)) == 2, "시체에 지뢰 2")
	_check(int(corpse_heavy.get("rocket_launcher", 0)) == 1, "시체에 발사기 1")
	_check(raid_loss_manager.get_item_count(corpse_loot) >= 3, "중장비만 남아도 회수 대상 개수 > 0")
	game_state.call("clear_carried_raid_inventory_after_death")
	_check(int(game_state.call("get_heavy_gear_count", "field_mine")) == 0, "사망 시 가방 중장비 소실")
	_check(not (game_state.get("pending_corpse_recovery") as Dictionary).is_empty(), "시체 회수 기록 존재")
	main_scene.call("_recover_previous_corpse")
	_check(int(game_state.call("get_heavy_gear_count", "field_mine")) == 2, "회수로 지뢰 2 복귀")
	_check(int(game_state.call("get_heavy_gear_count", "rocket_launcher")) == 1, "회수로 발사기 1 복귀")
	_check((game_state.get("pending_corpse_recovery") as Dictionary).is_empty(), "회수 후 시체 기록 소거")

	await _capture("heavy_gear_field")
	main_scene.queue_free()
	await process_frame
	await process_frame
	print("heavy_gear_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
