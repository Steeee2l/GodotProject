extends SceneTree

# 전투 타격감 패키지 프로브 — 실제 씬(main.tscn + building_interior.tscn)에서
#   ① 처치 히트스톱: time_scale 급감 → 0.2초 내 1.0 복원
#   ② 피격 화이트 플래시: 번쩍 후 기본 틴트+가시성 알파 정확 복원
#   ③ 데미지 팝: 생성·풀 재사용·풀 상한
#   ④ 처치 확인음: 재생 호출 카운트
#   ⑤ 건물 내부에서도 ①~④
# 를 검증한다. 히트스톱 복원 대기는 전부 실시간 타이머(ignore_time_scale)다.

const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")
const KILL_IMPACT := preload("res://scripts/kill_impact.gd")
const BUILDING_SCENE := preload("res://scenes/building_interior.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(45.0, true, false, true).timeout.connect(func() -> void:
		push_error("COMBAT_IMPACT_TEST_TIMEOUT")
		quit(2)
	)
	var accessibility := root.get_node("AccessibilitySettings")
	# 배율을 1.0으로 고정해 히트스톱 길이·플래시 강도를 결정적으로 만든다.
	accessibility.set("camera_shake_scale", 1.0)
	accessibility.set("hit_flash_scale", 1.0)
	accessibility.set("damage_numbers_enabled", true)
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	# 프로브 도중 플레이어가 죽어 사망 슬로모(0.18)가 끼어들지 않게 한다.
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	# 경계 상태의 적이 프로브 중 플레이어를 쏘면 main의 피격 슬로모(0.24)가
	# 히트스톱 측정과 겹친다 — 총알이 플레이어에 안 닿게 충돌 레이어를 끈다.
	(main_scene.get_node("Player") as CharacterBody3D).collision_layer = 0

	var enemies := main_scene.get("enemies") as Array
	_assert(enemies.size() >= 3, "필드에 프로브용 적이 3명 이상 필요합니다.")
	# 처치 시 디렉터가 host.enemies에서 항목을 지워 인덱스가 밀리므로,
	# 프로브 대상 셋을 미리 참조로 잡아 둔다.
	var probe_flash_enemy := enemies[0] as CharacterBody3D
	var probe_kill_enemy := enemies[1] as CharacterBody3D
	var probe_elite_enemy := enemies[2] as CharacterBody3D

	# ── ② 화이트 플래시 + 틴트/알파 복원 ──────────────────────
	var flash_enemy := probe_flash_enemy
	var zone_tint := Color(0.84, 0.9, 1.0, 1.0)
	flash_enemy.set("sprite_base_tint", zone_tint)
	flash_enemy.call("_apply_sprite_base_modulate")
	flash_enemy.call("take_hit", 3, Vector3.RIGHT, false)
	var flash_sprite := flash_enemy.get("sprite") as AnimatedSprite3D
	var flash_peak: Color = flash_sprite.modulate
	_assert(flash_peak.r > 2.0, "피격 직후 스프라이트가 과노출(하얗게)돼야 합니다. r=%.2f" % flash_peak.r)
	# gl_compatibility에서는 과노출 modulate가 클램프되므로 실제 흰 번쩍임은
	# 보조 스프라이트(HitFlashOverlay)가 담당한다 — 켜졌는지 함께 확인.
	var flash_overlay := flash_enemy.get_node("HitFlashOverlay") as Sprite3D
	_assert(flash_overlay != null and flash_overlay.modulate.a > 0.5, "피격 직후 화이트 플래시 오버레이가 켜져야 합니다.")
	await create_timer(0.45, true, false, true).timeout
	var restored: Color = flash_sprite.modulate
	var expected_alpha := float(flash_enemy.get("player_visibility_factor"))
	_assert(absf(restored.r - zone_tint.r) < 0.02, "플래시 후 존 틴트 R 복원 실패: %.3f" % restored.r)
	_assert(absf(restored.g - zone_tint.g) < 0.02, "플래시 후 존 틴트 G 복원 실패: %.3f" % restored.g)
	_assert(absf(restored.b - zone_tint.b) < 0.02, "플래시 후 존 틴트 B 복원 실패: %.3f" % restored.b)
	_assert(absf(restored.a - expected_alpha) < 0.05, "플래시 후 가시성 알파 복원 실패: %.3f (기대 %.3f)" % [restored.a, expected_alpha])
	# 백그라운드 교전의 히트스톱 창이 트윈 시간을 늘릴 수 있어 고정 시점 대신
	# "결국 꺼진다"를 검사한다(최대 1.5초 실시간).
	var overlay_off := false
	var overlay_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - overlay_wait_started <= 1500:
		if flash_overlay.modulate.a < 0.05:
			overlay_off = true
			break
		await process_frame
	_assert(overlay_off, "플래시 오버레이는 번쩍임 후 완전히 꺼져야 합니다: %.3f" % flash_overlay.modulate.a)
	print("PROBE_FLASH_OK peak_r=%.2f restored=(%.3f, %.3f, %.3f, %.3f)" % [flash_peak.r, restored.r, restored.g, restored.b, restored.a])

	# ── ③-0 토글: 끄면 데미지 팝이 생기지 않아야 한다 ───────
	accessibility.set("damage_numbers_enabled", false)
	var labels_before := _count_damage_numbers(flash_enemy.get_parent())
	var pool_before := int(DAMAGE_NUMBER.get_idle_pool_count())
	flash_enemy.call("take_hit", 2, Vector3.RIGHT, false)
	_assert(_count_damage_numbers(flash_enemy.get_parent()) == labels_before, "토글 OFF에서 데미지 팝이 생성되면 안 됩니다.")
	_assert(int(DAMAGE_NUMBER.get_idle_pool_count()) == pool_before, "토글 OFF에서 풀이 소비되면 안 됩니다.")
	accessibility.set("damage_numbers_enabled", true)

	# ── ③ 데미지 팝: 풀 재사용·상한 ──────────────────────────
	for hit_index in 50:
		flash_enemy.call("take_hit", 0, Vector3.RIGHT, false)
	var active_labels := _count_damage_numbers(flash_enemy.get_parent())
	_assert(active_labels >= 40, "연타 50회면 표시 중 라벨이 풀 상한 이상이어야 합니다: %d" % active_labels)
	await create_timer(1.1, true, false, true).timeout
	var pooled := int(DAMAGE_NUMBER.get_idle_pool_count())
	_assert(pooled > 0, "수명이 끝난 데미지 팝은 풀로 반환돼야 합니다.")
	_assert(pooled <= DAMAGE_NUMBER.MAX_POOL_SIZE, "풀 크기는 상한(%d)을 넘으면 안 됩니다: %d" % [DAMAGE_NUMBER.MAX_POOL_SIZE, pooled])
	var pool_top: Label3D = (DAMAGE_NUMBER.idle_pool as Array).back()
	flash_enemy.call("take_hit", 7, Vector3.RIGHT, false)
	_assert(int(DAMAGE_NUMBER.get_idle_pool_count()) == pooled - 1, "재스폰은 새 노드가 아니라 풀에서 꺼내야 합니다.")
	_assert(is_instance_valid(pool_top) and pool_top.visible and int(pool_top.get_meta("damage")) == 7, "풀에서 꺼낸 라벨이 실제로 재사용돼야 합니다.")
	print("PROBE_POOL_OK active_peak=%d pooled=%d cap=%d reused=%s" % [active_labels, pooled, DAMAGE_NUMBER.MAX_POOL_SIZE, str(pool_top.text)])

	# ── ①+④ 처치 히트스톱 + 확인음 (일반) ────────────────────
	var kill_enemy := probe_kill_enemy
	_assert(await _wait_for_time_scale_one(), "처치 프로브 시작 전 time_scale이 1.0이어야 합니다.")
	var confirm_before := int(KILL_IMPACT.kill_confirm_play_count)
	kill_enemy.call("take_hit", 999999, Vector3.RIGHT, false)
	var scale_during := Engine.time_scale
	_assert(absf(scale_during - 0.05) < 0.001, "일반 처치 순간 time_scale이 0.05로 떨어져야 합니다: %.3f" % scale_during)
	_assert(int(KILL_IMPACT.kill_confirm_play_count) == confirm_before + 1, "처치 시 확인음 재생이 1회 호출돼야 합니다.")
	var audio_bank := root.get_node_or_null("KillConfirmAudioBank")
	_assert(audio_bank != null and audio_bank.get_child_count() >= 4, "확인음 플레이어 4개 로테이션 뱅크가 root에 있어야 합니다.")
	var restore_ms := await _measure_restore_ms(250)
	_assert(restore_ms >= 0, "일반 처치 히트스톱이 0.25초 내 1.0으로 복원돼야 합니다.")
	print("PROBE_HITSTOP_NORMAL_OK scale_during=%.3f restore_ms=%d confirm_count=%d" % [scale_during, restore_ms, int(KILL_IMPACT.kill_confirm_play_count)])

	# ── 엘리트: 금색 팝 + 더 긴 히트스톱 ──────────────────────
	var elite_enemy := probe_elite_enemy
	elite_enemy.call("promote_to_elite", "프로브 정예")
	elite_enemy.call("take_hit", 5, Vector3.RIGHT, false)
	var gold_number := _latest_damage_number(elite_enemy.get_parent())
	var gold := Color("#f2bd55")
	_assert(gold_number != null and absf(gold_number.modulate.r - gold.r) < 0.02 and absf(gold_number.modulate.g - gold.g) < 0.02, "엘리트 대상 데미지 팝은 금색이어야 합니다.")
	_assert(await _wait_for_time_scale_one(), "엘리트 처치 프로브 전 time_scale이 1.0이어야 합니다.")
	elite_enemy.call("take_hit", 999999, Vector3.RIGHT, false)
	var elite_scale := Engine.time_scale
	_assert(absf(elite_scale - 0.05) < 0.001, "엘리트 처치 순간 time_scale이 급감해야 합니다: %.3f" % elite_scale)
	var elite_restore_ms := await _measure_restore_ms(250)
	_assert(elite_restore_ms >= 0, "엘리트 처치 히트스톱이 0.25초 내 복원돼야 합니다.")
	_assert(elite_restore_ms > restore_ms, "엘리트 히트스톱(0.09s)은 일반(0.05s)보다 길어야 합니다: %d vs %d" % [elite_restore_ms, restore_ms])
	print("PROBE_ELITE_OK gold=%s restore_ms=%d" % [str(gold_number.modulate), elite_restore_ms])

	# ── 접근성 0이면 히트스톱 스킵 ────────────────────────────
	accessibility.set("camera_shake_scale", 0.0)
	var skip_enemy_list := main_scene.get("enemies") as Array
	if skip_enemy_list.size() > 0:
		var skip_enemy := skip_enemy_list[0] as CharacterBody3D
		_assert(await _wait_for_time_scale_one(), "스킵 프로브 전 time_scale이 1.0이어야 합니다.")
		skip_enemy.call("take_hit", 999999, Vector3.RIGHT, false)
		_assert(is_equal_approx(Engine.time_scale, 1.0), "흔들림 배율 0이면 히트스톱을 건너뛰어야 합니다.")
		print("PROBE_HITSTOP_SKIP_OK")
	accessibility.set("camera_shake_scale", 1.0)

	# ── ⑤ 건물 내부 던전에서 ①~④ ────────────────────────────
	root.remove_child(main_scene)
	main_scene.free()
	Engine.time_scale = 1.0
	await process_frame
	var building_run_state := root.get_node("BuildingRunState")
	building_run_state.call(
		"begin_run",
		"combat_impact_probe_tower",
		733210,
		"res://scenes/main.tscn",
		Vector3(3, 0.78, 4),
		5
	)
	var interior := BUILDING_SCENE.instantiate()
	root.add_child(interior)
	await process_frame
	await physics_frame
	game_state.set("player_health", 9999)
	var interior_enemies := interior.get("enemies") as Array
	_assert(interior_enemies.size() >= 2, "건물 내부에 프로브용 적이 2명 이상 필요합니다.")
	var interior_enemy := interior_enemies[0] as CharacterBody3D
	interior_enemy.call("take_hit", 4, Vector3.RIGHT, false)
	var interior_sprite := interior_enemy.get("sprite") as AnimatedSprite3D
	_assert(interior_sprite.modulate.r > 2.0, "건물 내부에서도 피격 플래시가 켜져야 합니다.")
	var interior_number := _latest_damage_number(interior_enemy.get_parent())
	_assert(interior_number != null and interior_number.visible, "건물 내부에서도 데미지 팝이 떠야 합니다.")
	await create_timer(0.45, true, false, true).timeout
	var interior_restored: Color = interior_sprite.modulate
	_assert(absf(interior_restored.r - 1.0) < 0.02, "건물 내부 플래시 후 기본 틴트로 복원돼야 합니다: %.3f" % interior_restored.r)
	var interior_confirm_before := int(KILL_IMPACT.kill_confirm_play_count)
	_assert(await _wait_for_time_scale_one(), "건물 내부 처치 프로브 전 time_scale이 1.0이어야 합니다.")
	interior_enemy.call("take_hit", 999999, Vector3.RIGHT, false)
	var interior_scale := Engine.time_scale
	_assert(absf(interior_scale - 0.05) < 0.001, "건물 내부 처치 순간에도 히트스톱이 걸려야 합니다: %.3f" % interior_scale)
	_assert(int(KILL_IMPACT.kill_confirm_play_count) == interior_confirm_before + 1, "건물 내부 처치에도 확인음이 재생돼야 합니다.")
	var interior_restore_ms := await _measure_restore_ms(250)
	_assert(interior_restore_ms >= 0, "건물 내부 히트스톱도 0.25초 내 복원돼야 합니다.")
	print("PROBE_BUILDING_OK flash_r=%.2f restore_ms=%d" % [interior_restored.r, interior_restore_ms])

	print("COMBAT_IMPACT_SMOKE_OK")
	interior.free()
	quit(0)


func _wait_for_time_scale_one() -> bool:
	# 다른 연출(피격 슬로모 등)이 소유한 time_scale이 풀릴 때까지 잠깐 기다린다.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= 2000:
		if is_equal_approx(Engine.time_scale, 1.0):
			return true
		await process_frame
	return false


func _measure_restore_ms(limit_ms: int) -> int:
	# time_scale이 1.0으로 돌아올 때까지 실시간으로 잰다. limit 초과 시 -1.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= limit_ms:
		if is_equal_approx(Engine.time_scale, 1.0):
			return Time.get_ticks_msec() - started
		await process_frame
	return -1


func _count_damage_numbers(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Label3D and child.name.begins_with("DamageNumber") and child.visible:
			count += 1
	return count


func _latest_damage_number(parent: Node) -> Label3D:
	var latest: Label3D
	for child in parent.get_children():
		if child is Label3D and child.name.begins_with("DamageNumber") and child.visible:
			latest = child as Label3D
	return latest


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("COMBAT_IMPACT_FAIL: " + message)
	quit(1)
