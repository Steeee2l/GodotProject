extends SceneTree

# 전투 사운드 1단계 프로브 —
#   ① 합성 WAV 전부 user://sfx_dump/*.wav로 덤프 + 길이·피크·클리핑·RMS 포락선·
#      영교차율 수치 로그, 총성 3구경이 서로 구분되는지(길이/밝기/꼬리)
#   ② 버스 레이아웃(Master/SFX/UI/Music/Ambient) + 볼륨 슬라이더 → AudioServer 반영
#   ③ 실제 씬(main.tscn): 발사→총성, 적 피격→명중음, 발각→스팅, 장전→클릭,
#      빈 약실→공이 클릭, 근접 스윙/명중, 플레이어 피격, 증원 경보(시작+3초), 토스트,
#      UI 버튼 탭, 같은 프레임 중복 억제, 풀 상한, 피치 지터
#   ④ 건물 내부(building_interior.tscn)에서 발사/장전/피격/근접 동일
#   ⑤ 디버그 키 가드(F5/F8/N, 건물 F8, 쉘터 8/9) — 소스 문자열 검사
# assert()는 쓰지 않는다(헤드리스에서 행이 걸린다) — push_error + quit(1).

const SFX := preload("res://scripts/sfx_bank.gd")
const HUD_STYLE := preload("res://scripts/hud/hud_style.gd")
const DUMP_DIR := "user://sfx_dump"

# _assert는 quit(1)만 예약할 뿐 호출자를 멈추지 못한다 — 실패 후 씬을 더 띄우면
# 종료 시 크래시가 나므로 단계마다 이 플래그를 보고 조기 반환한다.
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("SFX_BANK_TEST_TIMEOUT")
		quit(2)
	)
	# 웹 오디오 정책 대비 — 사용자 입력 한 번 없이, 씬도 없이 가장 먼저 호출해도
	# 에러 없이 지나가야 한다(웹에서는 AudioContext가 풀릴 때까지 무음으로 버려진다).
	var early_ok := SFX.play("ui_tap")
	_assert(early_ok, "씬 없이도 play()가 에러 없이 재생을 걸어야 합니다.")
	_assert(root.get_node_or_null("SfxBank") != null, "첫 호출에서 root/SfxBank 풀이 생겨야 합니다.")

	# ── ① 합성 덤프 + 분석 ──────────────────────────────────
	var dump_path := ProjectSettings.globalize_path(DUMP_DIR)
	DirAccess.make_dir_recursive_absolute(dump_path)
	var analyses: Dictionary = {}
	for id_variant in SFX.sound_ids():
		var id := str(id_variant)
		var stream: AudioStreamWAV = SFX.get_stream(id)
		_assert(stream != null and stream.data.size() > 0, "'%s' 스트림이 생성돼야 합니다." % id)
		var save_error := stream.save_to_wav("%s/%s.wav" % [DUMP_DIR, id])
		_assert(save_error == OK, "'%s' WAV 저장 실패: %d" % [id, save_error])
		var analysis := _analyze(stream)
		analyses[id] = analysis
		print("SFX_DUMP %-16s len=%.3fs peak=%.3f clip=%.3f%% rms=%.3f zcr=%.0f/s tail=%.2f env=%s" % [
			id,
			float(analysis["duration"]),
			float(analysis["peak"]),
			float(analysis["clip_ratio"]) * 100.0,
			float(analysis["rms"]),
			float(analysis["zcr"]),
			float(analysis["tail_ratio"]),
			str(analysis["envelope"]),
		])
		_assert(float(analysis["clip_ratio"]) < 0.005, "'%s' 클리핑 비율이 0.5%% 이상입니다: %.3f%%" % [id, float(analysis["clip_ratio"]) * 100.0])
		_assert(float(analysis["peak"]) > 0.5 and float(analysis["peak"]) <= 0.95, "'%s' 피크가 정규화 범위를 벗어났습니다: %.3f" % [id, float(analysis["peak"])])
		_assert(float(analysis["duration"]) >= 0.03 and float(analysis["duration"]) <= 1.0, "'%s' 길이가 비정상입니다: %.3f" % [id, float(analysis["duration"])])
	print("SFX_DUMP_DIR %s" % dump_path)
	# 총성 3구경 구분 — 길이(권총<소총<산탄), 밝기(영교차율: 권총>소총>산탄),
	# 꼬리 에너지 비(산탄>소총>권총).
	var pistol: Dictionary = analyses["pistol_shot"]
	var rifle: Dictionary = analyses["rifle_shot"]
	var shotgun: Dictionary = analyses["shotgun_shot"]
	_assert(float(pistol["duration"]) < float(rifle["duration"]) and float(rifle["duration"]) < float(shotgun["duration"]), "총성 길이 순서(권총<소총<산탄)가 깨졌습니다.")
	_assert(float(pistol["zcr"]) > float(rifle["zcr"]) and float(rifle["zcr"]) > float(shotgun["zcr"]), "총성 밝기 순서(영교차율 권총>소총>산탄)가 깨졌습니다: %.0f / %.0f / %.0f" % [float(pistol["zcr"]), float(rifle["zcr"]), float(shotgun["zcr"])])
	_assert(float(shotgun["tail_ratio"]) > float(rifle["tail_ratio"]) and float(rifle["tail_ratio"]) > float(pistol["tail_ratio"]), "총성 꼬리 순서(산탄>소총>권총)가 깨졌습니다: %.2f / %.2f / %.2f" % [float(shotgun["tail_ratio"]), float(rifle["tail_ratio"]), float(pistol["tail_ratio"])])
	# 명중음 2종은 서로 다른 파형이어야 한다.
	_assert(absf(float(analyses["hit_enemy"]["zcr"]) - float(analyses["hit_player"]["zcr"])) > 40.0 or absf(float(analyses["hit_enemy"]["duration"]) - float(analyses["hit_player"]["duration"])) > 0.03, "적 피격음과 플레이어 피격음이 구분돼야 합니다.")
	print("PROBE_SYNTH_OK count=%d" % analyses.size())
	if failed:
		return

	# ── ② 버스 + 볼륨 슬라이더 ──────────────────────────────
	for bus_name in ["Master", "SFX", "UI", "Music", "Ambient"]:
		_assert(AudioServer.get_bus_index(bus_name) >= 0, "오디오 버스 '%s'가 있어야 합니다." % bus_name)
	var accessibility := root.get_node("AccessibilitySettings")
	var sliders := accessibility.find_children("", "HSlider", true, false)
	_assert(sliders.size() >= 10, "설정 UI에 볼륨 슬라이더 3개가 추가돼 HSlider가 10개 이상이어야 합니다: %d" % sliders.size())
	var master_slider := sliders[7] as HSlider
	var sfx_slider := sliders[8] as HSlider
	var ui_slider := sliders[9] as HSlider
	_assert(master_slider.max_value == 100.0 and sfx_slider.max_value == 100.0 and ui_slider.max_value == 100.0, "볼륨 슬라이더 범위는 0~100이어야 합니다.")
	master_slider.value = 50.0
	sfx_slider.value = 25.0
	ui_slider.value = 100.0
	var master_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	var ui_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI"))
	_assert(absf(master_db - linear_to_db(0.5)) < 0.05, "마스터 50 → %.2f dB여야 합니다: %.2f" % [linear_to_db(0.5), master_db])
	_assert(absf(sfx_db - linear_to_db(0.25)) < 0.05, "효과음 25 → %.2f dB여야 합니다: %.2f" % [linear_to_db(0.25), sfx_db])
	_assert(absf(ui_db) < 0.05, "UI 100 → 0 dB여야 합니다: %.2f" % ui_db)
	_assert(float(accessibility.get("master_volume")) == 50.0 and float(accessibility.get("sfx_volume")) == 25.0, "슬라이더 값이 설정 변수에 반영돼야 합니다.")
	sfx_slider.value = 0.0
	_assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) <= -79.0, "효과음 0은 사실상 무음(-80dB)이어야 합니다.")
	# 저장/로드 키
	accessibility.call("_save_settings")
	var config := ConfigFile.new()
	_assert(config.load("user://accessibility.cfg") == OK, "설정 파일이 저장돼야 합니다.")
	_assert(config.has_section_key("accessibility", "master_volume") and config.has_section_key("accessibility", "sfx_volume") and config.has_section_key("accessibility", "ui_volume"), "볼륨 3종이 설정 파일에 저장돼야 합니다.")
	# 기본값으로 복구(다음 테스트·플레이에 영향 없게)
	master_slider.value = 80.0
	sfx_slider.value = 80.0
	ui_slider.value = 70.0
	accessibility.call("_save_settings")
	print("PROBE_BUS_OK master=%.2f sfx=%.2f ui=%.2f" % [master_db, sfx_db, ui_db])
	# 기존 플레이어 버스 이동 — 처치 확인음 뱅크는 SFX, 타자기는 UI
	var kill_impact := load("res://scripts/kill_impact.gd")
	kill_impact.play_kill_confirm(false)
	var kill_bank := root.get_node_or_null("KillConfirmAudioBank")
	_assert(kill_bank != null and (kill_bank.get_child(0) as AudioStreamPlayer).bus == "SFX", "처치 확인음 플레이어는 SFX 버스여야 합니다.")
	var typewriter_script := load("res://scripts/hud/typewriter.gd")
	var typewriter: Node = typewriter_script.new()
	root.add_child(typewriter)
	await process_frame
	_assert((typewriter.get_child(0) as AudioStreamPlayer).bus == "UI", "타자기 틱은 UI 버스여야 합니다.")
	typewriter.queue_free()
	if failed:
		return

	# ── ③ 필드 씬 프로브 ─────────────────────────────────────
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("has_ak", true)
	game_state.set("equipped_weapon_id", "ak47")
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	await _settle()
	await physics_frame
	await _settle()
	main_scene.set("player_health", 9999)
	game_state.set("player_health", 9999)
	(main_scene.get_node("Player") as CharacterBody3D).collision_layer = 0
	_assert(SFX.streams.size() >= SFX.SOUNDS.size(), "씬 시작 시 warm_up으로 전 효과음이 미리 합성돼야 합니다.")
	var weapon_combat = main_scene.get("weapon_combat")
	_assert(weapon_combat != null, "main.weapon_combat 모듈이 있어야 합니다.")
	main_scene.set("has_ak", true)
	main_scene.set("magazine_ammo", 10)
	main_scene.set("reserve_ammo", 30)
	main_scene.set("weapon_durability", 100.0)
	main_scene.set("fire_cooldown", 0.0)
	main_scene.set("weapon_reloading", false)
	# 발사 → 소총 총성(장착 AK)
	var rifle_before := SFX.get_play_count("rifle_shot")
	weapon_combat.call("_fire_ak47")
	_assert(SFX.get_play_count("rifle_shot") == rifle_before + 1, "AK 발사 시 rifle_shot이 1회 재생돼야 합니다.")
	_assert(SFX.last_played_id == "rifle_shot", "마지막 재생이 rifle_shot이어야 합니다: %s" % SFX.last_played_id)
	# 같은 프레임 중복 억제
	var dup_before := SFX.get_play_count("hit_enemy")
	var first := SFX.play("hit_enemy", Vector3.ZERO)
	var second := SFX.play("hit_enemy", Vector3.ZERO)
	_assert(first and not second and SFX.get_play_count("hit_enemy") == dup_before + 1, "같은 프레임 같은 종류는 한 번만 울려야 합니다.")
	# 풀 상한 — 프레임마다 연사 20발, 플레이어 12개를 넘어도 에러 없이 재사용
	var pitches: Array[float] = []
	var bank := root.get_node("SfxBank")
	for shot_index in 20:
		await _settle()
		main_scene.set("magazine_ammo", 10)
		main_scene.set("fire_cooldown", 0.0)
		var shot_before := SFX.get_play_count("rifle_shot")
		weapon_combat.call("_fire_ak47")
		_assert(SFX.get_play_count("rifle_shot") == shot_before + 1, "연사 %d발째 총성이 재생돼야 합니다." % shot_index)
		for child in bank.get_children():
			if child is AudioStreamPlayer and child.playing and child.stream == SFX.get_stream("rifle_shot"):
				if not pitches.has(child.pitch_scale):
					pitches.append(child.pitch_scale)
	var pool_2d := 0
	for child in bank.get_children():
		if child is AudioStreamPlayer:
			pool_2d += 1
	_assert(pool_2d == SFX.PLAYER_POOL_SIZE, "2D 플레이어 풀은 상한(%d)을 넘지 않아야 합니다: %d" % [SFX.PLAYER_POOL_SIZE, pool_2d])
	_assert(pitches.size() >= 3, "연사 총성은 피치 지터로 서로 달라야 합니다: %d종" % pitches.size())
	for pitch in pitches:
		_assert(pitch >= 0.91 and pitch <= 1.09, "피치 지터는 ±8%% 이내여야 합니다: %.3f" % pitch)
	print("PROBE_FIRE_OK rifle=%d pitches=%d" % [SFX.get_play_count("rifle_shot"), pitches.size()])
	# 장전 시작/끝
	main_scene.set("magazine_ammo", 1)
	main_scene.set("reserve_ammo", 30)
	main_scene.set("loafing", false)
	var reload_start_before := SFX.get_play_count("reload_start")
	weapon_combat.call("_reload_ak47")
	_assert(SFX.get_play_count("reload_start") == reload_start_before + 1, "장전 시작 클릭이 1회 재생돼야 합니다.")
	var reload_end_before := SFX.get_play_count("reload_end")
	weapon_combat.call("_finish_reload")
	_assert(SFX.get_play_count("reload_end") == reload_end_before + 1, "장전 완료 클릭이 1회 재생돼야 합니다.")
	# 빈 약실 공이 클릭
	main_scene.set("magazine_ammo", 0)
	main_scene.set("reserve_ammo", 0)
	main_scene.set("fire_cooldown", 0.0)
	var dry_before := SFX.get_play_count("dry_fire")
	weapon_combat.call("_fire_ak47")
	_assert(SFX.get_play_count("dry_fire") == dry_before + 1, "빈 약실 발사 시 공이 클릭이 1회 재생돼야 합니다.")
	weapon_combat.call("_fire_ak47")
	_assert(SFX.get_play_count("dry_fire") == dry_before + 1, "공이 클릭 연타는 최소 간격으로 억제돼야 합니다.")
	main_scene.set("magazine_ammo", 10)
	main_scene.set("reserve_ammo", 30)
	# 근접 스윙
	main_scene.set("melee_attack_cooldown", 0.0)
	main_scene.set("melee_attack_active", false)
	var swing_before := SFX.get_play_count("melee_swing")
	main_scene.call("_try_melee_attack")
	_assert(SFX.get_play_count("melee_swing") == swing_before + 1, "근접 스윙 휘두름 소리가 1회 재생돼야 합니다.")
	# 적 피격 → 명중음(3D), 발각 스팅, 적 총성(3D 위치), 근접 명중
	var enemies := main_scene.get("enemies") as Array
	_assert(enemies.size() >= 2, "필드에 프로브용 적이 2명 이상 필요합니다.")
	var hit_enemy := enemies[0] as CharacterBody3D
	await _settle()
	var hit_before := SFX.get_play_count("hit_enemy")
	hit_enemy.call("take_hit", 2, Vector3.RIGHT, false)
	_assert(SFX.get_play_count("hit_enemy") == hit_before + 1, "적 피격 시 명중음이 1회 재생돼야 합니다.")
	var positional_found := false
	for child in bank.get_children():
		if child is AudioStreamPlayer3D and child.playing and child.stream == SFX.get_stream("hit_enemy"):
			positional_found = child.global_position.distance_to(hit_enemy.global_position) < 0.01 and child.max_distance > 10.0
	_assert(positional_found, "명중음은 적 위치의 3D 플레이어로 울려야 합니다.")
	var alert_enemy := enemies[1] as CharacterBody3D
	alert_enemy.set("alerted", false)
	await create_timer(0.3, true, false, true).timeout
	var sting_before := SFX.get_play_count("alert_sting")
	alert_enemy.call("_become_alerted")
	_assert(SFX.get_play_count("alert_sting") == sting_before + 1, "발각 순간 스팅이 1회 재생돼야 합니다(targeting_player=%s)." % str(alert_enemy.call("is_targeting_player")))
	var ranged_enemy: CharacterBody3D
	for enemy in enemies:
		if is_instance_valid(enemy) and str(enemy.get("weapon_id")) != "baseball_bat":
			ranged_enemy = enemy
			break
	await _settle()
	var enemy_shot_id := SFX.shot_sound_for_weapon(str(ranged_enemy.get("weapon_id")) if ranged_enemy != null else "m1911")
	var enemy_shot_before := SFX.get_play_count(enemy_shot_id)
	if ranged_enemy != null:
		ranged_enemy.call("_play_enemy_gunshot")
	else:
		SFX.play_weapon_shot("m1911", Vector3(5, 0, 5), -4.0)
	_assert(SFX.get_play_count(enemy_shot_id) == enemy_shot_before + 1, "적 총성(%s)이 1회 재생돼야 합니다." % enemy_shot_id)
	var enemy_shot_positional := false
	for child in bank.get_children():
		if child is AudioStreamPlayer3D and child.playing and child.stream == SFX.get_stream(enemy_shot_id):
			enemy_shot_positional = child.volume_db < float(SFX.SOUNDS[enemy_shot_id]["volume_db"]) - 3.0
	_assert(enemy_shot_positional, "적 총성은 3D 플레이어에 플레이어 총성보다 낮은 볼륨으로 울려야 합니다.")
	# 플레이어 피격 — 출정 인트로 시네마틱이 떠 있으면 take_damage가 무시되므로 먼저 스킵한다.
	var cinematic = main_scene.get("main_mission").get("cinematic")
	if cinematic != null and bool(cinematic.call("is_active")):
		cinematic.call("skip")
	await _settle()
	var player_hit_before := SFX.get_play_count("hit_player")
	main_scene.call("take_damage", 1)
	_assert(SFX.get_play_count("hit_player") == player_hit_before + 1, "플레이어 피격음이 1회 재생돼야 합니다.")
	# 증원 경보 — 시작 1회 + 3초 남았을 때 1회, 그 외엔 없음
	var alarm_before := SFX.get_play_count("reinforce_alarm")
	main_scene.call("_show_reinforcement_call_banner", 8.0)
	_assert(SFX.get_play_count("reinforce_alarm") == alarm_before + 1, "증원 배너 시작 시 경보가 1회 울려야 합니다.")
	main_scene.call("_update_reinforcement_call_banner", 6.0)
	main_scene.call("_update_reinforcement_call_banner", 4.0)
	_assert(SFX.get_play_count("reinforce_alarm") == alarm_before + 1, "3초 전까지는 경보가 다시 울리면 안 됩니다.")
	await create_timer(0.45, true, false, true).timeout
	main_scene.call("_update_reinforcement_call_banner", 2.9)
	_assert(SFX.get_play_count("reinforce_alarm") == alarm_before + 2, "3초 남았을 때 경보가 한 번 더 울려야 합니다.")
	await create_timer(0.45, true, false, true).timeout
	main_scene.call("_update_reinforcement_call_banner", 1.5)
	_assert(SFX.get_play_count("reinforce_alarm") == alarm_before + 2, "3초 경보는 한 번만 울려야 합니다.")
	main_scene.call("_hide_reinforcement_call_banner")
	# 토스트 톡 + UI 버튼 탭
	await _settle()
	var toast_before := SFX.get_play_count("toast_pop")
	main_scene.get("hud").call("push_toast", "효과음 프로브 토스트", Color.WHITE, 1.0)
	_assert(SFX.get_play_count("toast_pop") == toast_before + 1, "새 토스트 등장 시 톡 소리가 1회 재생돼야 합니다.")
	var tap_before := SFX.get_play_count("ui_tap")
	var probe_button := Button.new()
	HUD_STYLE.style_button(probe_button)
	HUD_STYLE.style_button(probe_button) # 두 번 입혀도 연결은 한 번
	root.add_child(probe_button)
	probe_button.pressed.emit()
	_assert(SFX.get_play_count("ui_tap") == tap_before + 1, "스타일 버튼 탭 시 클릭음이 정확히 1회 재생돼야 합니다: +%d" % (SFX.get_play_count("ui_tap") - tap_before))
	probe_button.queue_free()
	# 컨테이너 열기(필드 은닉처)
	var field_containers := main_scene.get("field_loot_containers") as Array
	if field_containers.size() > 0 and is_instance_valid(field_containers[0]):
		await _settle()
		var container_before := SFX.get_play_count("container_open")
		main_scene.call("_open_field_loot_container", field_containers[0])
		_assert(SFX.get_play_count("container_open") == container_before + 1, "필드 컨테이너 열기 소리가 1회 재생돼야 합니다.")
		print("PROBE_FIELD_CONTAINER_OK")
	else:
		print("PROBE_FIELD_CONTAINER_SKIPPED (no container)")
	print("PROBE_FIELD_OK counts=%s" % str(SFX.play_counts))
	if failed:
		main_scene.free()
		return

	# ── ④ 건물 내부 ──────────────────────────────────────────
	root.remove_child(main_scene)
	main_scene.free()
	Engine.time_scale = 1.0
	await _settle()
	var building_run_state := root.get_node("BuildingRunState")
	building_run_state.call(
		"begin_run",
		"sfx_probe_tower",
		733211,
		"res://scenes/main.tscn",
		Vector3(3, 0.78, 4),
		5
	)
	# 건물 씬은 런타임 load — const preload는 오토로드 등록 전 콜드 스타트라
	# game_over_screen/raid_loss_manager의 GameState 식별자 컴파일이 깨진다.
	var building_scene: PackedScene = load("res://scenes/building_interior.tscn")
	var interior := building_scene.instantiate()
	root.add_child(interior)
	await _settle()
	await physics_frame
	await _settle()
	game_state.set("player_health", 9999)
	game_state.set("magazine_ammo", 5)
	game_state.call("set_ammo_count", str(game_state.get("equipped_ammo_id")), 30)
	interior.set("fire_cooldown", 0.0)
	interior.set("weapon_reloading", false)
	var interior_player := interior.get("player") as Node3D
	var interior_rifle_before := SFX.get_play_count("rifle_shot")
	interior.call("_fire_toward_world", interior_player.global_position + Vector3(3, 0, 0))
	_assert(SFX.get_play_count("rifle_shot") == interior_rifle_before + 1, "건물 내부 발사 시 총성이 1회 재생돼야 합니다.")
	game_state.set("magazine_ammo", 1)
	var interior_reload_before := SFX.get_play_count("reload_start")
	interior.call("_start_reload")
	_assert(SFX.get_play_count("reload_start") == interior_reload_before + 1, "건물 내부 장전 시작 클릭이 1회 재생돼야 합니다.")
	var interior_reload_end_before := SFX.get_play_count("reload_end")
	interior.call("_finish_reload")
	_assert(SFX.get_play_count("reload_end") == interior_reload_end_before + 1, "건물 내부 장전 완료 클릭이 1회 재생돼야 합니다.")
	await _settle()
	var interior_hit_before := SFX.get_play_count("hit_player")
	interior.call("take_damage", 1)
	_assert(SFX.get_play_count("hit_player") == interior_hit_before + 1, "건물 내부 플레이어 피격음이 1회 재생돼야 합니다.")
	interior.set("melee_attack_cooldown", 0.0)
	interior.set("melee_attack_active", false)
	var interior_swing_before := SFX.get_play_count("melee_swing")
	interior.call("_try_melee_attack", Vector2(640, 360))
	_assert(SFX.get_play_count("melee_swing") == interior_swing_before + 1, "건물 내부 근접 스윙 소리가 1회 재생돼야 합니다.")
	var interior_enemies := interior.get("enemies") as Array
	_assert(interior_enemies.size() >= 1, "건물 내부에 프로브용 적이 필요합니다.")
	await _settle()
	var interior_enemy_hit_before := SFX.get_play_count("hit_enemy")
	(interior_enemies[0] as CharacterBody3D).call("take_hit", 2, Vector3.RIGHT, false)
	_assert(SFX.get_play_count("hit_enemy") == interior_enemy_hit_before + 1, "건물 내부 적 피격 명중음이 1회 재생돼야 합니다.")
	# 루팅 — 컨테이너/픽업 모듈이 있으면 상호작용해 소리를 확인(가방 상태에 따라 스킵)
	var loot_modules := get_nodes_in_group("building_loot_module")
	var loot_sound_checked := false
	for loot_module in loot_modules:
		if not is_instance_valid(loot_module):
			continue
		await _settle()
		var is_container := not str(loot_module.get("container_type")).is_empty()
		var loot_sound := "container_open" if is_container else "pickup"
		var loot_before := SFX.get_play_count(loot_sound)
		var result := str(loot_module.call("interact"))
		if SFX.get_play_count(loot_sound) == loot_before + 1:
			loot_sound_checked = true
			print("PROBE_BUILDING_LOOT_OK %s -> %s" % [loot_sound, result])
			break
	if not loot_sound_checked:
		print("PROBE_BUILDING_LOOT_SKIPPED modules=%d" % loot_modules.size())
	print("PROBE_BUILDING_OK")
	interior.free()
	if failed:
		return

	# ── ⑤ 디버그 키 가드 — 소스 검사 ─────────────────────────
	var main_source := _read_source("res://scripts/main.gd")
	_assert(main_source.contains("key == KEY_F5 and OS.is_debug_build()"), "main.gd F5 보스 소환은 OS.is_debug_build() 가드가 있어야 합니다.")
	_assert(main_source.contains("key == KEY_F8 and OS.is_debug_build()"), "main.gd F8 충돌 디버그는 OS.is_debug_build() 가드가 있어야 합니다.")
	_assert(main_source.contains("key == KEY_N and key_event.pressed and OS.is_debug_build()"), "main.gd N 맵 리롤은 OS.is_debug_build() 가드가 있어야 합니다.")
	var building_source := _read_source("res://scripts/building_interior.gd")
	_assert(building_source.contains("KEY_F8 and event.pressed and OS.is_debug_build()"), "building_interior.gd F8은 OS.is_debug_build() 가드가 있어야 합니다.")
	var shelter_source := _read_source("res://scripts/shelter_interior.gd")
	_assert(shelter_source.contains("KEY_8 and OS.is_debug_build()") and shelter_source.contains("KEY_9 and OS.is_debug_build()"), "shelter_interior.gd 8/9 디버그 키는 OS.is_debug_build() 가드가 있어야 합니다.")
	print("PROBE_DEBUG_GUARD_OK")

	print("SFX_BANK_SMOKE_OK")
	quit(0)


func _analyze(stream: AudioStreamWAV) -> Dictionary:
	# 16비트 모노 PCM 분석 — 길이/피크/클리핑 비율(|s|>=0.98)/RMS/영교차율/
	# 8구간 RMS 포락선/꼬리 에너지 비(뒤 절반 RMS ÷ 앞 절반 RMS).
	var data := stream.data
	var count := data.size() / 2
	var peak := 0.0
	var clipped := 0
	var sum_squares := 0.0
	var zero_crossings := 0
	var previous := 0.0
	var segments := 8
	var segment_sums: Array[float] = []
	segment_sums.resize(segments)
	segment_sums.fill(0.0)
	var first_half := 0.0
	var second_half := 0.0
	for index in count:
		var raw := data[index * 2] | (data[index * 2 + 1] << 8)
		if raw >= 32768:
			raw -= 65536
		var sample := float(raw) / 32767.0
		var magnitude := absf(sample)
		peak = maxf(peak, magnitude)
		if magnitude >= 0.98:
			clipped += 1
		sum_squares += sample * sample
		if index > 0 and ((previous < 0.0 and sample >= 0.0) or (previous >= 0.0 and sample < 0.0)):
			zero_crossings += 1
		previous = sample
		var segment := mini(segments - 1, index * segments / maxi(1, count))
		segment_sums[segment] += sample * sample
		if index < count / 2:
			first_half += sample * sample
		else:
			second_half += sample * sample
	var duration := float(count) / float(stream.mix_rate)
	var envelope: Array[String] = []
	for segment in segments:
		envelope.append("%.2f" % sqrt(segment_sums[segment] / maxf(1.0, float(count) / segments)))
	var first_rms := sqrt(first_half / maxf(1.0, count * 0.5))
	var second_rms := sqrt(second_half / maxf(1.0, count * 0.5))
	return {
		"duration": duration,
		"peak": peak,
		"clip_ratio": float(clipped) / maxf(1.0, float(count)),
		"rms": sqrt(sum_squares / maxf(1.0, float(count))),
		"zcr": float(zero_crossings) / maxf(0.001, duration),
		"envelope": ",".join(envelope),
		"tail_ratio": second_rms / maxf(0.0001, first_rms),
	}


func _settle() -> void:
	# 같은 종류 중복 억제는 "같은 프로세스 프레임" 기준이다. physics_frame 뒤의
	# process_frame은 같은 반복(iteration) 안에서 돌아오므로, 프로브 사이는
	# 실시간 타이머로 확실히 다음 프레임들로 넘긴다.
	await create_timer(0.02, true, false, true).timeout


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().replace("\r\n", "\n")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SFX_BANK_FAIL: " + message)
	quit(1)
