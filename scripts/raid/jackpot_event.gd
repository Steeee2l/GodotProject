class_name JackpotEvent
extends RefCounted

# 봉인 화물(잭팟) 사건 — 단서를 모아 전원을 복구하고 대형 화물을 탈출시키는
# 한 판짜리 하이리스크 목표. main.gd에서 15개 함수 313줄을 옮겼다.
#
# 규칙: 이 파일은 잭팟의 "무엇"만 안다. 스폰 위치/적 소환/알림 같은
# "어떻게"는 host(main)의 공용 헬퍼를 부른다.


const CRASHED_CONVOY_CACHE_TEXTURE := preload("res://assets/events/crashed_convoy_cache_v1.png")
const DYNAMIC_INCIDENT_DURATION := 150.0
const JACKPOT_ALARM_WAVE_COUNT := 3
const JACKPOT_ALARM_WAVE_INTERVAL := 9.0
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const PHARMACY_EMERGENCY_CACHE_TEXTURE := preload("res://assets/events/pharmacy_emergency_cache_v1.png")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_EXTRACTION_POLICY := preload("res://scripts/raid_extraction_policy.gd")
const RAID_HOTSPOT_COUNT := 3
const RAID_HOTSPOT_DISCOVERY_DISTANCE := 24.0
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const SECURE_MILITARY_CACHE_TEXTURE := preload("res://assets/events/secure_military_cache_v1.png")
const SUBWAY_EMERGENCY_GENERATOR_TEXTURE := preload("res://assets/events/subway_emergency_generator_v2.png")
const SUBWAY_MANIFEST_TERMINAL_TEXTURE := preload("res://assets/events/subway_manifest_terminal_v2.png")
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
const TACTICAL_MAP_SCRIPT := preload("res://scripts/tactical_map.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

var host: Node
var jackpot_clue_site: Node3D
var jackpot_power_site: Node3D
var jackpot_cargo_site: Node3D
var jackpot_power_position := Vector3.ZERO
var jackpot_cargo_position := Vector3.ZERO
var jackpot_state := "clue"
var jackpot_alarm_wave_timer := 0.0
var jackpot_alarm_waves_spawned := 0
var jackpot_carried_sprite: Sprite3D


func attach(owner_node: Node) -> void:
	host = owner_node


func _setup_jackpot_event(world: ProceduralCityMap) -> void:
	host.hud.build_jackpot_hud()
	if not GameState.raid_special_cargo.is_empty():
		jackpot_state = "carried"
		_attach_jackpot_cargo_visual()
		_set_jackpot_step(
			"탈출 필요 · 4/4",
			"특수 화물 운반 중 · 가장 가까운 하수구로 이동하세요",
			4
		)
		return
	var occupied: Array[Vector3] = []
	for site in host.extraction_sites:
		if is_instance_valid(site):
			occupied.append(site.global_position)
	var clue_position: Vector3 = host._find_stratified_map_position(world, 1, 3, 34.0, 22.0, occupied, 0.08)
	occupied.append(clue_position)
	jackpot_power_position = host._find_stratified_map_position(world, 2, 3, 42.0, 26.0, occupied, 0.08)
	occupied.append(jackpot_power_position)
	jackpot_cargo_position = host._find_stratified_map_position(world, 0, 3, 48.0, 30.0, occupied, 0.08)
	jackpot_state = "clue"
	jackpot_clue_site = host._create_field_interaction(
		"jackpot_clue",
		clue_position,
		"격리 수송 기록 판독",
		1.6
	)
	jackpot_clue_site.name = "JackpotManifestTerminal"
	jackpot_clue_site.set_meta("interaction_distance", 3.2)
	_build_jackpot_prop(
		jackpot_clue_site,
		SUBWAY_MANIFEST_TERMINAL_TEXTURE,
		0.00105,
		Color("#62c9ca"),
		0.95
	)
	_set_jackpot_step(
		"특별 기회 · 격리 신호 0/4",
		"TAB 지도 확인 → 주황 신호의 단말을 조사하세요",
		0
	)
	call_deferred("_register_jackpot_map_marker", "jackpot_clue", clue_position, "불명 격리 신호")


func _set_jackpot_step(title: String, detail: String, step: int) -> void:
	if not is_instance_valid(host.hud.jackpot_hud):
		return
	host.hud.jackpot_step_label.text = title
	host.hud.jackpot_detail_label.text = detail
	host.hud.jackpot_progress.value = clampi(step, 0, 4)
	host.hud.jackpot_hud.modulate.a = 0.35
	var tween := host.create_tween()
	tween.tween_property(host.hud.jackpot_hud, "modulate:a", 1.0, 0.25)
	tween.tween_property(host.hud.jackpot_hud, "modulate", Color("#fff0c9"), 0.12)
	tween.tween_property(host.hud.jackpot_hud, "modulate", Color.WHITE, 0.28)


func _build_jackpot_prop(
	point: Node3D,
	texture: Texture2D,
	pixel_size: float,
	color: Color,
	height: float
) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "JackpotPropSprite"
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position.y = height
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 12
	point.add_child(sprite)
	host._add_interaction_marker(point, color, 1.35, false)
	var beacon := Sprite3D.new()
	beacon.name = "JackpotBeacon"
	beacon.texture = host._get_loot_glow_texture()
	beacon.position = Vector3(0, 2.35, 0)
	beacon.pixel_size = 0.0065
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.shaded = false
	beacon.transparent = true
	beacon.no_depth_test = true
	beacon.render_priority = 122
	beacon.modulate = color
	point.add_child(beacon)


func _register_jackpot_map_marker(
	marker_id: String,
	position: Vector3,
	label: String
) -> void:
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("register_raid_marker"):
		host.tactical_map.call("register_raid_marker", marker_id, position, "jackpot", label, true)


func _remove_jackpot_map_marker(marker_id: String) -> void:
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("remove_raid_marker"):
		host.tactical_map.call("remove_raid_marker", marker_id)


func _handle_jackpot_clue() -> void:
	jackpot_state = "power"
	_remove_jackpot_map_marker("jackpot_clue")
	jackpot_power_site = host._create_field_interaction(
		"jackpot_power",
		jackpot_power_position,
		"지하선 비상 전력 복구",
		2.8
	)
	jackpot_power_site.name = "JackpotEmergencyGenerator"
	jackpot_power_site.set_meta("interaction_distance", 3.4)
	_build_jackpot_prop(
		jackpot_power_site,
		SUBWAY_EMERGENCY_GENERATOR_TEXTURE,
		0.00115,
		Color("#e7a847"),
		0.72
	)
	_register_jackpot_map_marker(
		"jackpot_power",
		jackpot_power_position,
		"지하선 비상 발전기"
	)
	_set_jackpot_step(
		"비상 전력 복구 · 1/4",
		"주황 발전기로 이동해 전력을 복구하세요",
		1
	)
	host._show_field_notice("격리 기록 복원 · 지하선 3번 화물의 비상 전력 좌표가 지도에 표시됩니다.")
	# 메인 미션의 발견 순간마다 나비가 한마디씩. 수수께끼가 한 겹씩 벗겨진다.
	host.monologue.play([
		"단말이 아직 살아 있다… 이 격리 기록, 사람이 지워지던 그 밤의 것이다.",
		"지하선 3번 화물. 누군가, 이게 발견되지 않기를 바랐어.",
	])


func _handle_jackpot_power() -> void:
	jackpot_state = "alarm"
	jackpot_alarm_wave_timer = 0.8
	jackpot_alarm_waves_spawned = 0
	_remove_jackpot_map_marker("jackpot_power")
	jackpot_cargo_site = host._create_field_interaction(
		"jackpot_cargo",
		jackpot_cargo_position,
		"봉인 화물 분리",
		4.2
	)
	jackpot_cargo_site.name = "JackpotSealedCargo"
	jackpot_cargo_site.set_meta("interaction_distance", 3.5)
	_build_jackpot_prop(
		jackpot_cargo_site,
		SUBWAY_SEALED_CARGO_TEXTURE,
		0.00118,
		Color("#e66a47"),
		0.82
	)
	_register_jackpot_map_marker(
		"jackpot_cargo",
		jackpot_cargo_position,
		"경보 발생 · 봉인 화물"
	)
	_set_jackpot_step(
		"봉인 화물 회수 · 2/4",
		"붉은 화물 위치로 이동 · 접근하는 약탈대를 경계하세요",
		2
	)
	_show_jackpot_alarm_flash()
	host._show_field_notice("경보 발생 · 화물 좌표 노출 · 대응대가 온다")
	host.monologue.play([
		"전력이 돌아왔다. 삼백 밤 만에, 도시의 일부가 눈을 떴다.",
		"…도시가 눈을 뜨면 다른 것들도 함께 깨어난다. 서둘러야 해.",
	])


func _show_jackpot_alarm_flash() -> void:
	var flash := ColorRect.new()
	flash.name = "JackpotAlarmFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.16, 0.06, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 81
	host.get_node("HUD").add_child(flash)
	var tween := host.create_tween()
	for pulse in 3:
		tween.tween_property(flash, "color:a", 0.16, 0.12)
		tween.tween_property(flash, "color:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func _update_jackpot_event(delta: float) -> void:
	if jackpot_state != "alarm" or jackpot_alarm_waves_spawned >= JACKPOT_ALARM_WAVE_COUNT:
		return
	jackpot_alarm_wave_timer -= delta
	if jackpot_alarm_wave_timer > 0.0:
		return
	_spawn_jackpot_alarm_wave()
	jackpot_alarm_waves_spawned += 1
	jackpot_alarm_wave_timer = JACKPOT_ALARM_WAVE_INTERVAL
	_set_jackpot_step(
		"봉인 화물 회수 · 3/4",
		"대응대 %d/%d · 화물에 접근해 분리하세요" % [
			jackpot_alarm_waves_spawned,
			JACKPOT_ALARM_WAVE_COUNT,
		],
		3
	)


func _spawn_jackpot_alarm_wave() -> void:
	var world := host.get_node("World") as ProceduralCityMap
	var anchor: Vector3 = host._find_event_position_near_player(world, 17.0, 26.0)
	var kinds: Array[String] = ["pistol", "melee"]
	if jackpot_alarm_waves_spawned == 1:
		kinds = ["pistol", "pistol"]
	elif jackpot_alarm_waves_spawned >= 2:
		kinds = ["pistol", "grenadier", "pistol"]
	host._spawn_enemy_squad(
		world,
		anchor,
		kinds,
		maxf(0.58, host.night_intensity),
		jackpot_cargo_position,
		{"jackpot_response": true}
	)


func _attempt_take_jackpot_cargo(point: Node3D) -> void:
	var cargo := {
		"id": "seoul_line3_relief_core",
		"title": "서울 지하선 3번 보급 코어",
		"description": "인간 격리 당시 보호소 이송 명부와 냉각 보급품이 함께 봉인된 대형 화물입니다.",
	}
	if not GameState.can_add_raid_item("special_cargo", str(cargo.id), 1):
		host._show_bag_full_notice()
		return
	_claim_jackpot_cargo(point)


func _claim_jackpot_cargo(point: Node3D) -> void:
	if not is_instance_valid(point):
		return
	var cargo := {
		"id": "seoul_line3_relief_core",
		"title": "서울 지하선 3번 보급 코어",
		"description": "인간 격리 당시 보호소 이송 명부와 냉각 보급품이 함께 봉인된 대형 화물입니다.",
	}
	if not GameState.try_take_story_cargo(cargo):
		host._show_bag_full_notice()
		return
	point.set_meta("completed", true)
	host.field_interactions.erase(point)
	host.nearby_field_interaction = null
	host.field_interaction_hold_time = 0.0
	host.field_interaction_keyboard_held = false
	host.hud.field_interaction_touch_held = false
	if host.hud.field_interaction_panel:
		host.hud.field_interaction_panel.visible = false
	_remove_jackpot_map_marker("jackpot_cargo")
	point.queue_free()
	jackpot_cargo_site = null
	jackpot_state = "carried"
	_attach_jackpot_cargo_visual()
	GameState.save_persistent_state()
	_set_jackpot_step(
		"탈출 필요 · 4/4",
		"특수 화물 운반 중 · 가장 가까운 하수구로 이동하세요",
		4
	)
	host._show_field_notice("특수 화물 확보 · 탈출 시 특별 보상과 기록 해금")
	host.monologue.play([
		"무겁다. 그리고 봉인 너머에서… 희미하게 심장 소리 같은 게 난다.",
		"묻는 건 나중이다. 지금은 산 채로 들고 나간다.",
	])


func _attach_jackpot_cargo_visual() -> void:
	if is_instance_valid(jackpot_carried_sprite):
		return
	jackpot_carried_sprite = Sprite3D.new()
	jackpot_carried_sprite.name = "CarriedSubwayCargo"
	jackpot_carried_sprite.texture = SUBWAY_SEALED_CARGO_TEXTURE
	jackpot_carried_sprite.pixel_size = 0.00048
	jackpot_carried_sprite.position = Vector3(-0.62, 0.48, 0.42)
	jackpot_carried_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	jackpot_carried_sprite.shaded = false
	jackpot_carried_sprite.transparent = true
	jackpot_carried_sprite.no_depth_test = true
	jackpot_carried_sprite.render_priority = 124
	host.player.add_child(jackpot_carried_sprite)


func _restore_jackpot_cargo_presentation() -> void:
	if GameState.raid_special_cargo.is_empty():
		return
	for site in [jackpot_clue_site, jackpot_power_site, jackpot_cargo_site]:
		if not is_instance_valid(site):
			continue
		host.field_interactions.erase(site)
		site.queue_free()
	jackpot_clue_site = null
	jackpot_power_site = null
	jackpot_cargo_site = null
	for marker_id in ["jackpot_clue", "jackpot_power", "jackpot_cargo"]:
		_remove_jackpot_map_marker(marker_id)
	jackpot_state = "carried"
	_attach_jackpot_cargo_visual()
	_set_jackpot_step(
		"화물 재회수 · 4/4",
		"되찾은 특수 화물을 운반해 하수구로 탈출하세요",
		4
	)


func _settle_jackpot_cargo() -> Dictionary:
	var cargo := GameState.complete_story_cargo()
	if cargo.is_empty():
		return {"xp": 0, "summary": "특별 화물 없음"}
	GameState.canned_food += 8
	GameState.churu += 1
	GameState.add_mod_component("scope_lens", 1)
	var cargo_lore := (
		"붉은비 격리 기록 · 3번선 마지막 명부\n"
		+ "봉인된 명부에는 인간이 떠나기 직전 개방한 고양이 보호소 27곳이 적혀 있었다. "
		+ "누군가는 재난의 마지막 순간까지 이 도시의 작은 생존자들이 지하로 도망칠 길을 남겨 두었다."
	)
	if not GameState.unlocked_contract_lore.has(cargo_lore):
		GameState.unlocked_contract_lore.append(cargo_lore)
	if is_instance_valid(jackpot_carried_sprite):
		jackpot_carried_sprite.queue_free()
	jackpot_carried_sprite = null
	return {
		"xp": 220,
		"summary": "지하선 3번 보급 코어 개봉 · 통조림 +8 · 츄르 +1 · 스코프 렌즈 +1 · XP +220\n새 세계 기록 · ‘3번선 마지막 명부’ 해금",
	}
