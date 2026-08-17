class_name MainMissionChain
extends RefCounted

# 메인 미션 체인 실행기 — 구역마다 3단계짜리 본편 미션을 굴린다.
#
# 예전 이름은 JackpotEvent였다. 봉인 화물(잭팟) 하나가 어느 구역에서든 똑같이
# 떴고, 그래서 이야기가 한 발도 못 나갔다. 이제 잭팟은 "종로 1단계"라는
# 이름의 한 유형으로 흡수됐고, 실제 내용은 전부 MainMissionCatalog가 쥔다.
# 이 파일은 "어떻게 굴릴지"만 안다 — 스폰 위치·적 소환·알림 같은 실제 손발은
# host(main)의 공용 헬퍼를 부른다.
#
# 단계 골격은 셋뿐이다(신규 기믹 금지):
#   relay   — 떨어진 지점을 차례로 상호작용, 마지막에서 회수
#   defense — 한 지점을 조작한 뒤 그 자리를 일정 시간 지켜 낸다
#   keyed   — 열쇠 지점(적 밀집)에서 열쇠를 얻어 잠긴 거점을 연다
#
# 진행도는 "탈출 정산"에서만 오른다. 회수물을 들고 죽으면 단계는 그대로다.

const MAIN_MISSION_CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")
const FIELD_CINEMATIC := preload("res://scripts/raid/field_cinematic.gd")
const ALARM_WAVE_COUNT := 3
const ALARM_WAVE_INTERVAL := 9.0
const DEFENSE_HOLD_RADIUS := 9.0

# 신규 3D 기물은 만들지 않는다. 이미 있는 사건 프롭 여섯 장을 돌려 쓴다.
const PROP_TEXTURES := {
	"manifest_terminal": preload("res://assets/events/subway_manifest_terminal_v2.png"),
	"generator": preload("res://assets/events/subway_emergency_generator_v2.png"),
	"sealed_cargo": preload("res://assets/events/subway_sealed_cargo_v2.png"),
	"convoy_cache": preload("res://assets/events/crashed_convoy_cache_v1.png"),
	"pharmacy_cache": preload("res://assets/events/pharmacy_emergency_cache_v1.png"),
	"military_cache": preload("res://assets/events/secure_military_cache_v1.png"),
}

var host: Node
var cinematic := FIELD_CINEMATIC.new()

var zone_id := ""
var stage_index := 0
var stage: Dictionary = {}
var points: Array = []
var point_positions: Array[Vector3] = []
var point_index := 0
var point_sites: Dictionary = {}
var state := "idle"
var has_key := false
var alarm_active := false
var alarm_wave_timer := 0.0
var alarm_waves_spawned := 0
var defense_active := false
var defense_elapsed := 0.0
var defense_duration := 0.0
var defense_wave_timer := 0.0
var defense_waves := 0
var defense_waves_spawned := 0
var defense_position := Vector3.ZERO
var carried_sprite: Sprite3D
var repeat_recovery := false


func attach(owner_node: Node) -> void:
	host = owner_node
	cinematic.attach(owner_node)


func is_cinematic_active() -> bool:
	return cinematic.is_active()


# ── 출정 시작 ──────────────────────────────────────────────────


func setup(world: ProceduralCityMap) -> void:
	host.hud.build_jackpot_hud()
	zone_id = str(GameState.selected_raid_zone)
	# 이어하기: 이미 회수물을 들고 있는 판(시체 회수 등)은 운반 상태로 복원한다.
	if not GameState.raid_special_cargo.is_empty():
		_adopt_stage_from_carried_cargo()
		state = "carried"
		_attach_carry_visual()
		_set_step(
			str(stage.get("carry_title", "탈출 필요")),
			str(stage.get("carry_detail", "회수물 운반 중 · 가장 가까운 하수구로 이동하세요")),
			_total_steps()
		)
		return
	stage_index = GameState.get_main_mission_progress(zone_id)
	stage = MAIN_MISSION_CATALOG.get_stage(zone_id, stage_index)
	if stage.is_empty():
		# 이 구역의 흔적은 끊겼다. 메인 미션이 비운 자리를 반복 사건이 채운다 —
		# 지도에서 사라진 만큼 다른 것이 들어와야 판이 빈손이 되지 않는다.
		if is_instance_valid(host.hud.jackpot_hud):
			host.hud.jackpot_hud.visible = false
		state = "none"
		host.incidents._spawn_dynamic_convoy_incident(world)
		return
	repeat_recovery = GameState.recovered_story_cargo_ids.has(str(stage.get("id", "")))
	points = MAIN_MISSION_CATALOG.get_stage_points(stage)
	point_index = 0
	has_key = false
	state = "running"
	_resolve_point_positions(world)
	# 첫 지점 + 처음부터 보이는 잠긴 거점을 함께 깐다.
	for index in points.size():
		var point := points[index] as Dictionary
		if index == 0 or str(point.get("role", "")) == "locked":
			_spawn_point(index)
	_apply_step_presentation(0)
	_spawn_point_guards(world)
	_play_stage_cinematic("intro")


func _resolve_point_positions(world: ProceduralCityMap) -> void:
	point_positions.clear()
	var occupied: Array[Vector3] = []
	for site in host.extraction_sites:
		if is_instance_valid(site):
			occupied.append(site.global_position)
	# 지점 순서대로 지도를 세 등분해 흩는다 — 한 구석에 몰리면 "지형을 쓰는
	# 미션"이 아니라 "한 자리에서 세 번 F키"가 된다.
	for index in points.size():
		var point := points[index] as Dictionary
		var position: Vector3 = host._find_stratified_map_position(
			world,
			(index + 1) % 3,
			3,
			float(point.get("distance", 36.0)),
			float(point.get("separation", 26.0)),
			occupied,
			0.08
		)
		occupied.append(position)
		point_positions.append(position)


func _spawn_point(index: int) -> void:
	if index < 0 or index >= points.size():
		return
	if point_sites.has(index):
		return
	var point := points[index] as Dictionary
	var role := str(point.get("role", ""))
	var interaction_type := "main_mission_step"
	match role:
		"key":
			interaction_type = "main_mission_key"
		"locked":
			interaction_type = "main_mission_locked"
		"defense":
			interaction_type = "main_mission_defense"
	if bool(point.get("is_recovery", false)) and role != "locked":
		interaction_type = "main_mission_recovery"
	elif bool(point.get("is_recovery", false)) and role == "locked":
		# 잠긴 회수 거점 — 열쇠를 얻으면 잠금만 풀리고 회수 지점으로 바뀐다.
		interaction_type = "main_mission_locked"
	var site: Node3D = host._create_field_interaction(
		interaction_type,
		point_positions[index],
		str(point.get("label", "조사")),
		float(point.get("hold", 2.4))
	)
	site.name = "MainMissionPoint%d" % index
	site.set_meta("interaction_distance", 3.4)
	site.set_meta("main_mission_point", index)
	if role == "locked" and not has_key:
		site.set_meta("locked_reason", str(point.get("locked_reason", "열쇠가 필요하다")))
	_build_point_prop(
		site,
		PROP_TEXTURES.get(str(point.get("prop", "manifest_terminal")), PROP_TEXTURES["manifest_terminal"]),
		0.0011,
		Color(str(point.get("color", "#e7a847"))),
		0.86
	)
	point_sites[index] = site
	_register_marker(index, point_positions[index], str(point.get("map_label", "메인 임무")))


func _spawn_point_guards(world: ProceduralCityMap) -> void:
	# 열쇠는 적이 깔린 자리에서 나온다. 데이터의 guards 수만큼만 미리 세운다.
	for index in points.size():
		var point := points[index] as Dictionary
		var guard_count := int(point.get("guards", 0))
		if guard_count <= 0 or index >= point_positions.size():
			continue
		var kinds: Array[String] = []
		for guard_index in guard_count:
			kinds.append("pistol" if guard_index % 2 == 0 else "melee")
		host._spawn_enemy_squad(
			world,
			point_positions[index],
			kinds,
			maxf(0.5, host.night_intensity),
			point_positions[index],
			{"main_mission_guard": true}
		)


func _build_point_prop(
	point: Node3D,
	texture: Texture2D,
	pixel_size: float,
	color: Color,
	height: float
) -> void:
	var sprite := Sprite3D.new()
	# 이름은 예전 잭팟 그대로 둔다 — 스모크 테스트와 렌더 정렬이 이 이름을 본다.
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


# ── 배너 · 지도 ────────────────────────────────────────────────


func _total_steps() -> int:
	return maxi(1, points.size() + 1)


func _set_step(title: String, detail: String, step: int) -> void:
	if not is_instance_valid(host.hud.jackpot_hud):
		return
	host.hud.jackpot_hud.visible = true
	host.hud.jackpot_step_label.text = title
	host.hud.jackpot_detail_label.text = detail
	host.hud.jackpot_progress.max_value = _total_steps()
	host.hud.jackpot_progress.value = clampi(step, 0, _total_steps())
	# 단계 갱신 순간에만 10초 노출. 운반 중엔 탈출 안내라 상시 유지.
	host.jackpot_banner_reveal_time = 999999.0 if step >= _total_steps() else 10.0
	host.call_deferred("_layout_center_top_banners")
	# 좌상단 상시 목표 패널에도 단계를 반영한다.
	host.call_deferred("_refresh_objective_panel")
	host.hud.jackpot_hud.modulate.a = 0.35
	var tween := host.create_tween()
	tween.tween_property(host.hud.jackpot_hud, "modulate:a", 1.0, 0.25)
	tween.tween_property(host.hud.jackpot_hud, "modulate", Color("#fff0c9"), 0.12)
	tween.tween_property(host.hud.jackpot_hud, "modulate", Color.WHITE, 0.28)


func _apply_step_presentation(index: int) -> void:
	if index < 0 or index >= points.size():
		return
	var point := points[index] as Dictionary
	_set_step(
		str(point.get("step_title", "메인 임무")),
		str(point.get("detail", "지도에 표시된 지점으로 이동하세요")),
		index
	)


func _register_marker(index: int, position: Vector3, label: String) -> void:
	# 출정 시작 시점에는 전술 지도가 아직 없다. 준비되는 다음 프레임에 다시 건다.
	if not is_instance_valid(host.tactical_map):
		call_deferred("_register_marker", index, position, label)
		return
	if host.tactical_map.has_method("register_raid_marker"):
		host.tactical_map.call(
			"register_raid_marker", "main_mission_%d" % index, position, "jackpot", label, true
		)


func _remove_marker(index: int) -> void:
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("remove_raid_marker"):
		host.tactical_map.call("remove_raid_marker", "main_mission_%d" % index)


# ── 지점 처리 ──────────────────────────────────────────────────


func handle_point(point_node: Node3D) -> void:
	if not is_instance_valid(point_node):
		return
	var index := int(point_node.get_meta("main_mission_point", -1))
	if index < 0 or index >= points.size():
		return
	var point := points[index] as Dictionary
	var role := str(point.get("role", ""))
	_remove_marker(index)
	point_sites.erase(index)
	if role == "defense":
		_begin_defense(index, point)
		return
	if role == "key":
		has_key = true
		_unlock_locked_points()
	_finish_point(index, point)


func _finish_point(index: int, point: Dictionary) -> void:
	var notice := str(point.get("complete_notice", ""))
	if not notice.is_empty():
		host._show_field_notice(notice)
	var lines := point.get("complete_monologue", []) as Array
	if not lines.is_empty():
		host.monologue.play(lines)
	point_index = index + 1
	if point_index < points.size():
		_spawn_point(point_index)
		_apply_step_presentation(point_index)
		if bool((points[point_index] as Dictionary).get("alarm", false)):
			_begin_alarm()
	_play_stage_cinematic("point_%d" % index)


func _unlock_locked_points() -> void:
	for index in point_sites.keys():
		var site := point_sites[index] as Node3D
		if not is_instance_valid(site):
			continue
		if str((points[index] as Dictionary).get("role", "")) != "locked":
			continue
		site.remove_meta("locked_reason")
		if bool((points[index] as Dictionary).get("is_recovery", false)):
			site.set_meta("interaction_type", "main_mission_recovery")


func notify_locked() -> void:
	host._show_field_notice("문이 잠겨 있다 · 지도의 다른 신호에서 열쇠를 먼저 찾아라")


# ── 경보 웨이브 ────────────────────────────────────────────────


func _begin_alarm() -> void:
	if alarm_active:
		return
	alarm_active = true
	alarm_wave_timer = 0.8
	alarm_waves_spawned = 0
	_show_alarm_flash()


func _show_alarm_flash() -> void:
	var flash := ColorRect.new()
	flash.name = "MainMissionAlarmFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.16, 0.06, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 81
	host.get_node("HUD").add_child(flash)
	var tween := host.create_tween()
	for _pulse in 3:
		tween.tween_property(flash, "color:a", 0.16, 0.12)
		tween.tween_property(flash, "color:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func update(delta: float) -> void:
	_update_defense(delta)
	if not alarm_active or alarm_waves_spawned >= ALARM_WAVE_COUNT:
		return
	alarm_wave_timer -= delta
	if alarm_wave_timer > 0.0:
		return
	# 전투 중 추가 유입 상한 — 교전 중인 적이 이미 상한이면 웨이브를 미룬다.
	if host.enemy_director.count_alerted_enemies() >= EnemyDirector.MAX_CONCURRENT_ALERTED:
		alarm_wave_timer = 2.0
		return
	_spawn_alarm_wave()
	alarm_waves_spawned += 1
	alarm_wave_timer = ALARM_WAVE_INTERVAL
	if point_index < points.size():
		var point := points[point_index] as Dictionary
		_set_step(
			str(point.get("step_title", "메인 임무")),
			"대응대 %d/%d · %s" % [
				alarm_waves_spawned,
				ALARM_WAVE_COUNT,
				str(point.get("detail", "목표 지점으로 이동하세요")),
			],
			point_index
		)


func _spawn_alarm_wave() -> void:
	var world := host.get_node("World") as ProceduralCityMap
	var anchor: Vector3 = host._find_event_position_near_player(world, 17.0, 26.0)
	var kinds: Array[String] = ["pistol", "melee"]
	if alarm_waves_spawned == 1:
		kinds = ["pistol", "pistol"]
	elif alarm_waves_spawned >= 2:
		kinds = ["pistol", "grenadier", "pistol"]
	var order_position := (
		point_positions[point_index] if point_index < point_positions.size() else anchor
	)
	host._spawn_enemy_squad(
		world,
		anchor,
		kinds,
		maxf(0.58, host.night_intensity),
		order_position,
		{"jackpot_response": true}
	)


# ── 방어 단계 ──────────────────────────────────────────────────


func _begin_defense(index: int, point: Dictionary) -> void:
	defense_active = true
	defense_elapsed = 0.0
	defense_duration = float(point.get("defense_duration", 15.0))
	defense_waves = int(point.get("defense_waves", 3))
	defense_waves_spawned = 0
	defense_wave_timer = 1.2
	defense_position = point_positions[index]
	point_index = index
	var notice := str(point.get("complete_notice", ""))
	if not notice.is_empty():
		host._show_field_notice(notice)
	var lines := point.get("complete_monologue", []) as Array
	if not lines.is_empty():
		host.monologue.play(lines)
	_show_alarm_flash()
	_set_step(
		str(point.get("step_title", "메인 임무")),
		"자리 사수 %.0f초 · 이탈하면 진행이 멈춘다" % defense_duration,
		index
	)


func _update_defense(delta: float) -> void:
	if not defense_active:
		return
	var inside: bool = (
		host.player.global_position.distance_to(defense_position) <= DEFENSE_HOLD_RADIUS
	)
	if inside:
		defense_elapsed += delta
	defense_wave_timer -= delta
	if defense_wave_timer <= 0.0 and defense_waves_spawned < defense_waves:
		_spawn_defense_wave()
		defense_waves_spawned += 1
		defense_wave_timer = maxf(3.0, defense_duration / float(maxi(1, defense_waves)))
	var remaining := maxf(0.0, defense_duration - defense_elapsed)
	_set_step(
		str((points[point_index] as Dictionary).get("step_title", "메인 임무")),
		(
			"자리 사수 %.1f초 남음 · 웨이브 %d/%d" % [remaining, defense_waves_spawned, defense_waves]
			if inside
			else "구역을 벗어났다 · 제어반으로 돌아가라"
		),
		point_index
	)
	if defense_elapsed < defense_duration:
		return
	defense_active = false
	host._show_field_notice("봉쇄 해제 완료 · 안쪽의 회수물을 챙겨라")
	point_index += 1
	if point_index < points.size():
		# 방어를 끝낸 그 자리에 회수물이 열린다 — 새 좌표로 또 걸어가게 하지 않는다.
		point_positions[point_index] = defense_position
		_spawn_point(point_index)
		_apply_step_presentation(point_index)
		if bool((points[point_index] as Dictionary).get("alarm", false)):
			_begin_alarm()
	_play_stage_cinematic("point_%d" % (point_index - 1))


func _spawn_defense_wave() -> void:
	var world := host.get_node("World") as ProceduralCityMap
	var anchor: Vector3 = host._find_event_position_near_player(world, 14.0, 22.0)
	var kinds: Array[String] = ["melee", "pistol"]
	if defense_waves_spawned >= 2:
		kinds = ["pistol", "melee", "pistol"]
	host._spawn_enemy_squad(
		world,
		anchor,
		kinds,
		maxf(0.58, host.night_intensity),
		defense_position,
		{"jackpot_response": true}
	)


# ── 회수물 ─────────────────────────────────────────────────────


func attempt_take_recovery(point_node: Node3D) -> void:
	if not is_instance_valid(point_node) or stage.is_empty():
		return
	var recovery := stage.get("recovery", {}) as Dictionary
	var cargo := {
		"id": str(recovery.get("id", "main_mission_recovery")),
		"title": str(recovery.get("title", "회수물")),
		"description": str(recovery.get("description", "")),
	}
	if not GameState.can_add_raid_item("special_cargo", str(cargo.id), 1):
		host._show_bag_full_notice()
		return
	if not GameState.try_take_story_cargo(cargo):
		host._show_bag_full_notice()
		return
	var index := int(point_node.get_meta("main_mission_point", -1))
	point_node.set_meta("completed", true)
	host.field_interactions.erase(point_node)
	host.nearby_field_interaction = null
	host.field_interaction_hold_time = 0.0
	host.field_interaction_keyboard_held = false
	host.hud.field_interaction_touch_held = false
	if host.hud.field_interaction_panel:
		host.hud.field_interaction_panel.visible = false
	_remove_marker(index)
	point_sites.erase(index)
	point_node.queue_free()
	state = "carried"
	_attach_carry_visual()
	GameState.save_persistent_state()
	_set_step(
		str(stage.get("carry_title", "탈출 필요")),
		str(stage.get("carry_detail", "회수물 운반 중 · 가장 가까운 하수구로 이동하세요")),
		_total_steps()
	)
	var notice := str(stage.get("carry_notice", ""))
	if not notice.is_empty():
		host._show_field_notice(notice)
	var lines := stage.get("carry_monologue", []) as Array
	if not lines.is_empty():
		host.monologue.play(lines)
	_play_stage_cinematic("recovery")


func _attach_carry_visual() -> void:
	if is_instance_valid(carried_sprite):
		return
	var recovery := stage.get("recovery", {}) as Dictionary
	carried_sprite = Sprite3D.new()
	carried_sprite.name = "CarriedMainMissionCargo"
	carried_sprite.texture = PROP_TEXTURES.get(
		str(recovery.get("prop", "sealed_cargo")), PROP_TEXTURES["sealed_cargo"]
	)
	carried_sprite.pixel_size = 0.00048
	carried_sprite.position = Vector3(-0.62, 0.48, 0.42)
	carried_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	carried_sprite.shaded = false
	carried_sprite.transparent = true
	carried_sprite.no_depth_test = true
	carried_sprite.render_priority = 124
	host.player.add_child(carried_sprite)


func restore_carry_presentation() -> void:
	# 시체 회수로 특수 화물을 되찾은 직후 — 현장 지점과 마커를 걷고 운반 상태로.
	if GameState.raid_special_cargo.is_empty():
		return
	if stage.is_empty():
		_adopt_stage_from_carried_cargo()
	for index in point_sites.keys():
		var site := point_sites[index] as Node3D
		if is_instance_valid(site):
			host.field_interactions.erase(site)
			site.queue_free()
		_remove_marker(index)
	point_sites.clear()
	state = "carried"
	_attach_carry_visual()
	_set_step(
		"회수물 재확보 · %d/%d" % [_total_steps(), _total_steps()],
		"되찾은 회수물을 운반해 하수구로 탈출하세요",
		_total_steps()
	)


func _adopt_stage_from_carried_cargo() -> void:
	# 저장에서 돌아온 판은 어느 단계의 회수물을 들고 있는지부터 되찾아야 한다.
	var cargo_id := str(GameState.raid_special_cargo.get("id", ""))
	var found := MAIN_MISSION_CATALOG.find_stage_by_recovery_id(cargo_id)
	if found.is_empty():
		return
	zone_id = str(found.get("zone_id", zone_id))
	stage_index = int(found.get("stage_index", 0))
	stage = found.get("stage", {}) as Dictionary
	points = MAIN_MISSION_CATALOG.get_stage_points(stage)
	repeat_recovery = GameState.recovered_story_cargo_ids.has(cargo_id)


# ── 정산 ───────────────────────────────────────────────────────


func settle() -> Dictionary:
	if GameState.raid_special_cargo.is_empty():
		return {"xp": 0, "summary": "특별 화물 없음"}
	if stage.is_empty():
		_adopt_stage_from_carried_cargo()
	# 정산 전에 물어봐야 한다 — complete_story_cargo가 회수 목록에 id를 넣어 버리면
	# 첫 회수와 재회수를 구분할 수 없다.
	var already_recovered := GameState.recovered_story_cargo_ids.has(
		str(GameState.raid_special_cargo.get("id", ""))
	)
	var cargo := GameState.complete_story_cargo()
	if cargo.is_empty() or stage.is_empty():
		return {"xp": 0, "summary": "특별 화물 없음"}
	if is_instance_valid(carried_sprite):
		carried_sprite.queue_free()
	carried_sprite = null
	# 두 번째부터는 이야기가 아니라 부업이다. 보상도 그만큼만 — 반복 파밍 방지.
	var reward := (
		stage.get("repeat_reward", {}) if already_recovered else stage.get("reward", {})
	) as Dictionary
	GameState.canned_food += int(reward.get("canned_food", 0))
	GameState.churu += int(reward.get("churu", 0))
	for component_id in (reward.get("components", {}) as Dictionary).keys():
		GameState.add_mod_component(
			str(component_id), int((reward["components"] as Dictionary)[component_id])
		)
	var summary := str(reward.get("summary", "회수물 정산"))
	if not already_recovered:
		var lore := str(stage.get("lore", ""))
		if not lore.is_empty() and not GameState.unlocked_contract_lore.has(lore):
			GameState.unlocked_contract_lore.append(lore)
		# 단계 진행은 여기서만 오른다 — 들고 죽으면 단계는 그대로다.
		var progress := GameState.advance_main_mission(zone_id, stage_index)
		if progress >= MAIN_MISSION_CATALOG.get_stage_count(zone_id):
			summary += "\n%s" % get_zone_completion_text(zone_id)
	return {"xp": int(reward.get("xp", 0)), "summary": summary}


func get_zone_completion_text(completed_zone_id: String) -> String:
	# "○○의 흔적은 여기서 끊긴다 — 다음은 △△."
	var current_name := str(GameState.get_raid_zone(completed_zone_id).get("name", "이 구역"))
	var next_zone := MAIN_MISSION_CATALOG.get_next_zone(completed_zone_id)
	if next_zone.is_empty():
		return "%s의 마지막 기록까지 손에 넣었다. 서울에서 더 쫓을 흔적은 없다." % current_name
	var next_name := str(GameState.get_raid_zone(next_zone).get("name", "다음 구역"))
	var text := "%s의 흔적은 여기서 끊긴다 — 다음은 %s." % [current_name, next_name]
	if not GameState.is_raid_zone_unlocked(next_zone):
		text += " %s" % GameState.get_zone_unlock_hint(next_zone)
	return text


# ── 시네마틱 ───────────────────────────────────────────────────


func _play_stage_cinematic(slot: String) -> void:
	if stage.is_empty():
		return
	var scripts := stage.get("cinematics", {}) as Dictionary
	if not scripts.has(slot):
		return
	var cinematic_id := "%s:%s" % [str(stage.get("id", "")), slot]
	# 이미 본 연출은 다시 틀지 않는다. 두 번째 판부터 같은 장면을 또 보면
	# 그건 연출이 아니라 통행세다.
	if GameState.has_seen_field_cinematic(cinematic_id):
		return
	GameState.mark_field_cinematic_seen(cinematic_id)
	var steps := _resolve_cinematic_steps(scripts[slot] as Array)
	if steps.is_empty():
		return
	cinematic.play(steps)


func _resolve_cinematic_steps(script_steps: Array) -> Array:
	# 데이터는 좌표를 모른다. 상징 앵커("player"/"site"/"next_site")를 여기서
	# 실제 Vector3로 바꾼다.
	var resolved: Array = []
	for step_value in script_steps:
		var step := (step_value as Dictionary).duplicate(true)
		if step.has("at"):
			step["position"] = _resolve_anchor(str(step["at"])) + step.get("offset", Vector3.ZERO)
		if step.has("to_at"):
			step["to"] = _resolve_anchor(str(step["to_at"])) + step.get("to_offset", Vector3.ZERO)
		if step.has("texture") and step["texture"] is String:
			var key := str(step["texture"])
			if PROP_TEXTURES.has(key):
				step["texture"] = PROP_TEXTURES[key]
		# 색은 데이터에서 문자열로 온다 — const 사전 안에서는 Color()를 못 쓴다.
		if step.has("color") and step["color"] is String:
			step["color"] = Color(str(step["color"]))
		if str(step.get("type", "")) == "choice":
			step["on_choice"] = Callable(self, "_apply_choice_effect").bind(step)
		resolved.append(step)
	return resolved


func _resolve_anchor(anchor: String) -> Vector3:
	match anchor:
		"player":
			return host.player.global_position
		"site":
			if point_index < point_positions.size():
				return point_positions[point_index]
			return host.player.global_position
		"prev_site":
			var previous := maxi(0, point_index - 1)
			if previous < point_positions.size():
				return point_positions[previous]
			return host.player.global_position
	return host.player.global_position


func _apply_choice_effect(option_id: String, step: Dictionary) -> void:
	# 선택은 실제로 갈려야 한다. 데이터의 effect 사전을 여기서 손발로 옮긴다.
	for option_value in step.get("options", []) as Array:
		var option := option_value as Dictionary
		if str(option.get("id", "")) != option_id:
			continue
		var effect := option.get("effect", {}) as Dictionary
		if bool(effect.get("rescue", false)):
			host._add_rescued_follower(
				host.player.global_position + Vector3(1.6, 0.0, 1.2)
			)
		var extra_multiplier := float(effect.get("reward_multiplier", 0.0))
		if extra_multiplier > 0.0:
			host.raid_reward_multiplier += extra_multiplier
		var pressure := float(effect.get("pressure", 0.0))
		if pressure > 0.0:
			host._add_raid_pressure(pressure)
		elif pressure < 0.0:
			host.raid_pressure_points = maxf(0.0, host.raid_pressure_points + pressure)
		var scrap := int(effect.get("scrap", 0))
		if scrap > 0:
			GameState.scrap += scrap
		var notice := str(effect.get("notice", ""))
		if not notice.is_empty():
			host._show_field_notice(notice)
		var lines := effect.get("monologue", []) as Array
		if not lines.is_empty():
			host.monologue.play(lines)
		return
