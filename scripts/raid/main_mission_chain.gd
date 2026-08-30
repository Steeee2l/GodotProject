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
const SHELTER_REQUISITION := preload("res://scripts/shelter/requisition.gd")
const HUD_STYLE := preload("res://scripts/hud/hud_style.gd")
const ALARM_WAVE_COUNT := 3
const ALARM_WAVE_INTERVAL := 9.0
const DEFENSE_HOLD_RADIUS := 9.0
# 방어 중에는 지점 마커가 사라져 "어디로 돌아가야 하는지"를 알 수 없었다(유저 제보).
# 사수 지점은 별도 id로 다시 걸고, 방어가 끝날 때만 걷는다.
const DEFENSE_MARKER_ID := "main_mission_defense"
# 회수물을 든 뒤에도 지도에 목표가 하나는 남아야 한다 — 가장 가까운 하수구를 찍어 준다.
const EXTRACTION_MARKER_ID := "main_mission_extraction"
const DEFENSE_ZONE_INSIDE_COLOR := Color("#5fd489")
const DEFENSE_ZONE_OUTSIDE_COLOR := Color("#ef5f45")

# 신규 3D 기물은 만들지 않는다. 이미 있는 사건 프롭 여섯 장을 돌려 쓴다.
const PROP_TEXTURES := {
	"manifest_terminal": preload("res://assets/events/subway_manifest_terminal_v2.png"),
	"generator": preload("res://assets/events/subway_emergency_generator_v2.png"),
	"sealed_cargo": preload("res://assets/events/subway_sealed_cargo_v2.png"),
	"convoy_cache": preload("res://assets/events/crashed_convoy_cache_v1.png"),
	"pharmacy_cache": preload("res://assets/events/pharmacy_emergency_cache_v1.png"),
	"military_cache": preload("res://assets/events/secure_military_cache_v1.png"),
}
# 포인트 프롭의 월드 가로 길이(m). pixel_size 는 런타임 텍스처 폭으로 나눠 구한다 —
# 임포트 size_limit 으로 텍스처가 줄어도 프롭 크기가 변하지 않는다(과거 0.0011 × 원본 px).
const PROP_WORLD_WIDTHS := {
	"manifest_terminal": 1.3794,
	"generator": 1.3794,
	"sealed_cargo": 1.3794,
	"convoy_cache": 1.6896,
	"pharmacy_cache": 1.3794,
	"military_cache": 1.3794,
}
# 들고 나르는 화물 스프라이트는 포인트 프롭의 0.4364배(과거 0.00048/0.0011).
const CARRIED_PROP_SCALE := 0.43636

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
var defense_zone_ring: Node3D
var carried_sprite: Sprite3D
var repeat_recovery := false


func attach(owner_node: Node) -> void:
	host = owner_node
	cinematic.attach(owner_node)


func is_cinematic_active() -> bool:
	# event 모드(조작 잠금·일시정지)만 true. 바크 모드는 조작을 막지 않는다.
	return cinematic.is_active()


func is_bark_active() -> bool:
	# 바크 대사가 하단 슬롯에 흐르는 중 — HUD 겹침 회피용 상태.
	return cinematic.is_bark_active()


# ── 출정 시작 ──────────────────────────────────────────────────


func setup(world: ProceduralCityMap) -> void:
	host.hud.build_jackpot_hud()
	zone_id = str(GameState.selected_raid_zone)
	# 이어하기: 이미 회수물을 들고 있는 판(시체 회수 등)은 운반 상태로 복원한다.
	if not GameState.raid_special_cargo.is_empty():
		_adopt_stage_from_carried_cargo()
		state = "carried"
		_attach_carry_visual()
		_register_extraction_marker()
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
		str(point.get("prop", "manifest_terminal")),
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
	prop_key: String,
	color: Color,
	height: float
) -> void:
	var texture: Texture2D = PROP_TEXTURES.get(prop_key, PROP_TEXTURES["manifest_terminal"])
	var pixel_size := _prop_pixel_size(prop_key, texture, 1.0)
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


func _prop_pixel_size(prop_key: String, texture: Texture2D, scale: float) -> float:
	# 목표 월드 폭 × scale / 실제 텍스처 폭.
	var world_width := float(PROP_WORLD_WIDTHS.get(prop_key, PROP_WORLD_WIDTHS["manifest_terminal"]))
	var texture_width := float(texture.get_width()) if texture != null else 0.0
	return world_width * scale / maxf(1.0, texture_width)


# ── 배너 · 지도 ────────────────────────────────────────────────


func _total_steps() -> int:
	return maxi(1, points.size() + 1)


static func localize_control_hint(text: String) -> String:
	# 터치 기기에는 TAB 키가 없다 — 카탈로그의 "TAB 지도 확인"이 15곳에서
	# 있지도 않은 키를 안내하고 있었다. 표시 직전에 기기에 맞게 갈아 끼운다.
	if not DisplayServer.is_touchscreen_available():
		return text
	return text.replace("TAB 지도 확인", "지도 버튼으로 확인").replace("TAB", "지도 버튼")


func _set_step(title: String, detail: String, step: int) -> void:
	if not is_instance_valid(host.hud.jackpot_hud):
		return
	host.hud.jackpot_hud.visible = true
	host.hud.jackpot_step_label.text = title
	host.hud.jackpot_detail_label.text = localize_control_hint(detail)
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


func _register_defense_marker(label: String) -> void:
	# 방어가 도는 동안 사수 지점은 지도에 남아 있어야 한다 — 반경 원까지 같이 넘긴다.
	if not defense_active:
		return
	if not is_instance_valid(host.tactical_map):
		call_deferred("_register_defense_marker", label)
		return
	if host.tactical_map.has_method("register_raid_marker"):
		host.tactical_map.call(
			"register_raid_marker",
			DEFENSE_MARKER_ID,
			defense_position,
			"jackpot",
			label,
			true,
			DEFENSE_HOLD_RADIUS
		)


func _remove_defense_marker() -> void:
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("remove_raid_marker"):
		host.tactical_map.call("remove_raid_marker", DEFENSE_MARKER_ID)


func _register_extraction_marker(retries: int = 20) -> void:
	# 회수물을 들면 지점 마커가 전부 걷힌다. 그 순간 지도가 빈손이 되지 않도록
	# 가장 가까운 하수구 하나를 "지금 목표"로 찍는다(나머지 탈출로는 여전히 미발견).
	# 이어하기 판은 지도·탈출구가 아직 안 세워졌을 수 있어 몇 프레임 기다린다.
	if state != "carried":
		return
	var nearest: Node3D = null
	var nearest_distance := INF
	for site in host.extraction_sites:
		if not is_instance_valid(site):
			continue
		var distance: float = host.player.global_position.distance_to(site.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = site
	if not is_instance_valid(host.tactical_map) or nearest == null:
		if retries > 0:
			call_deferred("_register_extraction_marker", retries - 1)
		return
	if not host.tactical_map.has_method("register_raid_marker"):
		return
	host.tactical_map.call(
		"register_raid_marker",
		EXTRACTION_MARKER_ID,
		nearest.global_position,
		"jackpot",
		"회수물 반출 · 하수구",
		true
	)


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
		# 다음 지점 방향 핑 — 지도를 안 열어도 어느 쪽인지 8초간 알려 준다.
		if host.has_method("show_objective_ping") and point_index < point_positions.size():
			host.show_objective_ping(
				point_positions[point_index],
				str((points[point_index] as Dictionary).get("map_label", "다음 지점"))
			)
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
	# 상한은 존 stage_tier 기반 함수(종로 3, 그 외 6)로 통일됐다.
	if host.enemy_director.count_alerted_enemies() >= host.enemy_director.get_max_concurrent_alerted():
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
	# 지점 마커는 handle_point가 이미 걷었다. 사수 지점을 반경과 함께 다시 걸고
	# 바닥에도 구역 링을 깐다 — 지도와 세계 양쪽에 "여기"가 남아야 한다.
	_register_defense_marker("사수 지점 · %s" % str(point.get("map_label", "제어반")))
	_build_defense_zone_ring()
	_set_step(
		str(point.get("step_title", "메인 임무")),
		"자리 사수 %.0f초 · 바닥 원 안을 지켜라 · TAB 지도 확인" % defense_duration,
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
	# 밖으로 나갔을 때 "돌아가라"만 띄우면 어디로 돌아갈지 알 수 없었다.
	# 남은 거리와 화면 기준 방향을 같이 말해 준다.
	var away_distance: float = host.player.global_position.distance_to(defense_position)
	_update_defense_zone_ring(inside)
	_set_step(
		str((points[point_index] as Dictionary).get("step_title", "메인 임무")),
		(
			"자리 사수 %.1f초 남음 · 웨이브 %d/%d" % [remaining, defense_waves_spawned, defense_waves]
			if inside
			else "구역을 벗어났다 · 사수 지점 %.0fm %s" % [
				away_distance, _describe_screen_direction(defense_position)
			]
		),
		point_index
	)
	if defense_elapsed < defense_duration:
		return
	defense_active = false
	_remove_defense_marker()
	_clear_defense_zone_ring()
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


# ── 사수 구역 표시 ─────────────────────────────────────────────


func _make_zone_material(color: Color, alpha: float, energy: float, depth_test: bool) -> StandardMaterial3D:
	# 예고 데칼(telegraph_fx)과 같은 계열 — unshaded + 알파 + 발광. 차이는 수명뿐이다.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.no_depth_test = not depth_test
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_defense_zone_ring() -> void:
	# 지도만으로는 "지금 내가 안쪽인지"를 알 수 없다. 바닥에 실제 반경을 깔아
	# 안이면 초록, 밖이면 붉게 점멸시킨다. 방어가 끝나면 사라진다.
	_clear_defense_zone_ring()
	var root := Node3D.new()
	root.name = "MainMissionDefenseZone"
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var disc_mesh := CylinderMesh.new()
	disc_mesh.height = 0.02
	disc_mesh.radial_segments = 56
	disc_mesh.top_radius = DEFENSE_HOLD_RADIUS
	disc_mesh.bottom_radius = DEFENSE_HOLD_RADIUS
	disc_mesh.material = _make_zone_material(DEFENSE_ZONE_INSIDE_COLOR, 0.12, 1.2, true)
	disc.mesh = disc_mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var ring_mesh := TorusMesh.new()
	ring_mesh.rings = 56
	ring_mesh.ring_segments = 8
	ring_mesh.inner_radius = maxf(0.1, DEFENSE_HOLD_RADIUS - 0.22)
	ring_mesh.outer_radius = DEFENSE_HOLD_RADIUS
	ring_mesh.material = _make_zone_material(DEFENSE_ZONE_INSIDE_COLOR, 0.9, 3.2, false)
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	host.add_child(root)
	root.global_position = Vector3(defense_position.x, 0.06, defense_position.z)
	defense_zone_ring = root


func _update_defense_zone_ring(inside: bool) -> void:
	if not is_instance_valid(defense_zone_ring):
		return
	var color := DEFENSE_ZONE_INSIDE_COLOR if inside else DEFENSE_ZONE_OUTSIDE_COLOR
	# 밖일 때만 점멸 — 안쪽에서는 조용히 켜져 있다.
	var pulse := (
		1.0 if inside else 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.006))
	)
	var disc := defense_zone_ring.get_node_or_null("Disc") as MeshInstance3D
	if disc != null:
		var disc_material := (disc.mesh as CylinderMesh).material as StandardMaterial3D
		disc_material.albedo_color = Color(color.r, color.g, color.b, 0.12 * pulse)
		disc_material.emission = color
	var ring := defense_zone_ring.get_node_or_null("Ring") as MeshInstance3D
	if ring != null:
		var ring_material := (ring.mesh as TorusMesh).material as StandardMaterial3D
		ring_material.albedo_color = Color(color.r, color.g, color.b, 0.35 + 0.55 * pulse)
		ring_material.emission = color


func _clear_defense_zone_ring() -> void:
	if is_instance_valid(defense_zone_ring):
		defense_zone_ring.queue_free()
	defense_zone_ring = null


func _describe_screen_direction(target: Vector3) -> String:
	# 화면 가장자리 화살표 UI는 아직 없다(폰트 화살표는 이 프로젝트에서 안 쓴다).
	# 대신 카메라 기준 8방위를 말로 준다 — "왼쪽 뒤"면 몸을 어디로 돌릴지 바로 안다.
	var camera := host.camera as Camera3D
	if not is_instance_valid(camera) or not is_instance_valid(host.player):
		return ""
	var offset: Vector3 = target - host.player.global_position
	offset.y = 0.0
	if offset.length() < 0.05:
		return ""
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		return ""
	var right := camera.global_transform.basis.x
	right.y = 0.0
	var angle := atan2(offset.normalized().dot(right.normalized()), offset.normalized().dot(forward.normalized()))
	var octant := int(roundf(rad_to_deg(angle) / 45.0)) % 8
	if octant < 0:
		octant += 8
	return [
		"정면", "오른쪽 앞", "오른쪽", "오른쪽 뒤", "뒤쪽", "왼쪽 뒤", "왼쪽", "왼쪽 앞"
	][octant]


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
	# 메인 미션 회수물은 가방과 무관하게 먹힌다(칸 0·만재 검사 없음·교체 모달 없음).
	# 유일한 거절 사유는 "이미 하나 들고 있다"뿐이다.
	if not GameState.try_take_story_cargo(cargo):
		host._show_field_notice("이미 회수물을 들고 있다 — 먼저 탈출해서 정산하라")
		return
	host.hud.push_toast(
		"%s 확보 · 임무 품목" % str(cargo.get("title", "회수물")),
		HUD_STYLE.GOLD,
		2.8
	)
	var index := int(point_node.get_meta("main_mission_point", -1))
	point_node.set_meta("completed", true)
	host.field_interactions.erase(point_node)
	host.nearby_field_interaction = null
	host.field_interaction_hold_time = 0.0
	host.field_interaction_keyboard_held = false
	host.hud.field_interaction_touch_held = false
	host.hud.set_field_interaction_visible(false)
	_remove_marker(index)
	_remove_defense_marker()
	_clear_defense_zone_ring()
	point_sites.erase(index)
	point_node.queue_free()
	state = "carried"
	_attach_carry_visual()
	_register_extraction_marker()
	GameState.save_persistent_state()
	_set_step(
		str(stage.get("carry_title", "탈출 필요")),
		str(stage.get("carry_detail", "회수물 운반 중 · 가장 가까운 하수구로 이동하세요")),
		_total_steps()
	)
	var notice := str(stage.get("carry_notice", ""))
	if not notice.is_empty():
		host._show_field_notice(notice)
	# 존 클라이맥스 — 이 구역 체인의 '마지막' 회수물을 드는 순간 구역 보스가
	# 되찾으러 온다(유저 확정: 스테이지 보스는 메인 임무 막바지의 확정 전투).
	if MAIN_MISSION_CATALOG.get_stage(zone_id, stage_index + 1).is_empty():
		host.enemy_director.spawn_chain_climax_boss()
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
	var carried_key := str(recovery.get("prop", "sealed_cargo"))
	carried_sprite.texture = PROP_TEXTURES.get(carried_key, PROP_TEXTURES["sealed_cargo"])
	carried_sprite.pixel_size = _prop_pixel_size(carried_key, carried_sprite.texture, CARRIED_PROP_SCALE)
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
	defense_active = false
	_remove_defense_marker()
	_clear_defense_zone_ring()
	state = "carried"
	_attach_carry_visual()
	_register_extraction_marker()
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
	# 서사 키(쉘터 확장 키 등) — 첫 회수 보상에만 들어 있다. 받는 순간 "이게 어디에
	# 쓰이는지" 한 줄을 정산 요약에 붙인다. 가방 칸은 0(progression 타입).
	for progression_item_id in (reward.get("progression_items", {}) as Dictionary).keys():
		GameState.add_progression_item(
			str(progression_item_id), int((reward["progression_items"] as Dictionary)[progression_item_id])
		)
		var grant_line := SHELTER_REQUISITION.describe_key_item_grant(str(progression_item_id))
		if not grant_line.is_empty():
			summary += "\n%s" % grant_line
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
