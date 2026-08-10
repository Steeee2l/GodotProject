class_name FieldMissionController
extends RefCounted

# 현장 임무 — 수색/방어/도달/은신 등 판 위에 뿌려지는 부가 목표의 전체 수명주기.
# main.gd에서 31개 함수 741줄을 옮겼다.
#
# 적 소환과 월드 좌표 탐색은 host(main)의 공용 헬퍼를 쓴다. 이 파일은
# 임무의 상태 기계와 보상만 책임진다.


const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_MISSION_ACTIVE_RADIUS := 22.0
const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")
const FIELD_MISSION_COUNT := 6
const FIELD_MISSION_ENEMY_MAX_SITE_DISTANCE := 34.0
const FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE := 16.0
const FIELD_MISSION_ENEMY_MIN_SITE_DISTANCE := 23.0
const FIELD_MISSION_FAIL_RADIUS := 72.0
const FIELD_MISSION_FIRST_WAVE_DELAY := 1.2
const FIELD_MISSION_PREPARE_DURATION := 5.0
const FIELD_MISSION_RESULT_DURATION := 2.8
const FIELD_MISSION_START_HOLD_DURATION := 0.65
const FIELD_MISSION_STEALTH_HOLD_RADIUS := 14.0
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const GENERATED_MISSION_ICON_PATHS := {
	"defense": "res://assets/generated/p0_sliced/mission_icons/defend.png",
	"eliminate": "res://assets/generated/p0_sliced/mission_icons/eliminate.png",
	"collect": "res://assets/generated/p0_sliced/mission_icons/collect_cache.png",
	"investigate": "res://assets/generated/p0_sliced/mission_icons/investigate.png",
	"stealth": "res://assets/generated/p0_sliced/mission_icons/stealth.png",
	"stealth_reach": "res://assets/generated/p0_sliced/mission_icons/waypoint.png",
}
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")

var host: Node
# 타입 추론을 위해 attach에서 캐시하는 host 멤버들
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var field_mission_sites: Array[Node3D] = []
var field_mission_wave_timer := 0.0
var field_mission_prepare_timer := 0.0
var field_mission_phase := "idle"
var field_mission_result_timer := 0.0
var field_mission_runtime := 0.0


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _setup_procedural_field_missions(world: ProceduralCityMap) -> void:
	field_mission_sites.clear()
	host.active_field_mission = null
	host.active_mission_collectibles.clear()
	host.objective_panel.visible = false
	var occupied_positions: Array[Vector3] = []
	for site in host.extraction_sites:
		if is_instance_valid(site):
			occupied_positions.append(site.global_position)
	for interaction in host.field_interactions:
		if is_instance_valid(interaction):
			occupied_positions.append(interaction.global_position)
	for index in FIELD_MISSION_COUNT:
		var mission_position: Vector3 = host._find_randomized_mission_position(
			world,
			38.0,
			36.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(mission_position)
		var definition := _pick_field_mission_definition(index)
		var mission_site := Node3D.new()
		mission_site.name = "FieldMission_%02d" % (index + 1)
		host.add_child(mission_site)
		mission_site.global_position = mission_position
		mission_site.set_meta("mission_id", index + 1)
		mission_site.set_meta("status", "waiting")
		mission_site.set_meta("interaction_type", "mission_start")
		mission_site.set_meta(
			"display_name",
			"현장 작전 · %s · %s" % [
				_get_field_mission_category(str(definition.get("type", "defense"))),
				str(definition.get("title", "현장 임무")),
			]
		)
		mission_site.set_meta("hold_duration", FIELD_MISSION_START_HOLD_DURATION)
		mission_site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE + 0.45)
		mission_site.set_meta("completed", false)
		for key in definition:
			mission_site.set_meta(str(key), definition[key])
		mission_site.add_to_group("field_mission_site")
		mission_site.add_to_group("field_interaction")
		field_mission_sites.append(mission_site)
		host.field_interactions.append(mission_site)
		_build_field_mission_marker(mission_site)


func _pick_field_mission_definition(index: int) -> Dictionary:
	return FIELD_MISSION_CATALOG.pick_definition(index, host.mission_random)


func _get_field_mission_category(mission_type: String) -> String:
	return FIELD_MISSION_CATALOG.get_category(mission_type)


func _get_field_mission_active_radius() -> float:
	return float(host.raid_zone_data.get("mission_radius", FIELD_MISSION_ACTIVE_RADIUS))


func _get_field_mission_fail_radius() -> float:
	return maxf(FIELD_MISSION_FAIL_RADIUS, _get_field_mission_active_radius() * 3.0)


func _get_field_mission_rules(site: Node3D) -> String:
	return FIELD_MISSION_CATALOG.build_rules(
		str(site.get_meta("type", "defense")),
		bool(site.get_meta("silence_required", false)),
		_get_field_mission_fail_radius()
	)


func _format_field_mission_reward(reward: Dictionary) -> String:
	return FIELD_MISSION_CATALOG.format_reward(reward)


func _build_field_mission_marker(site: Node3D) -> void:
	var mission_type := str(site.get_meta("type", "defense"))
	var marker_color := Color("#5eb9ad")
	var marker_text := "F · %s 작전" % _get_field_mission_category(mission_type)
	match mission_type:
		"stealth":
			marker_color = Color("#6aa8b9")
		"investigate":
			marker_color = Color("#c5a964")
		"stealth_reach":
			marker_color = Color("#78b59a")
	var marker_material := StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(marker_color, 0.16)
	marker_material.emission_enabled = true
	marker_material.emission = marker_color
	marker_material.emission_energy_multiplier = 1.2
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.5
	ring_mesh.outer_radius = 2.64
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 12
	ring_mesh.material = marker_material
	var ring := MeshInstance3D.new()
	ring.name = "MissionBoundary"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(ring)
	site.set_meta("marker_material", marker_material)

	var active_boundary_material := StandardMaterial3D.new()
	active_boundary_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	active_boundary_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	active_boundary_material.albedo_color = Color(marker_color, 0.10)
	active_boundary_material.emission_enabled = true
	active_boundary_material.emission = marker_color
	active_boundary_material.emission_energy_multiplier = 0.65
	var active_boundary_mesh := TorusMesh.new()
	var active_radius := _get_field_mission_active_radius()
	active_boundary_mesh.inner_radius = active_radius - 0.18
	active_boundary_mesh.outer_radius = active_radius
	active_boundary_mesh.rings = 64
	active_boundary_mesh.ring_segments = 12
	active_boundary_mesh.material = active_boundary_material
	var active_boundary := MeshInstance3D.new()
	active_boundary.name = "MissionPlayArea"
	active_boundary.position.y = 0.025
	active_boundary.mesh = active_boundary_mesh
	active_boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	active_boundary.visible = false
	site.add_child(active_boundary)
	site.set_meta("active_boundary_material", active_boundary_material)

	var marker_label := Label3D.new()
	marker_label.name = "MissionMarkerLabel"
	marker_label.text = marker_text
	marker_label.position = Vector3(0.0, 1.15, 0.0)
	marker_label.font = FONT
	marker_label.font_size = 28
	marker_label.modulate = marker_color.lightened(0.2)
	marker_label.outline_size = 7
	marker_label.outline_modulate = Color(0.01, 0.02, 0.018, 0.94)
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_label.no_depth_test = true
	site.add_child(marker_label)
	var mission_icon_path := str(GENERATED_MISSION_ICON_PATHS.get(mission_type, ""))
	if not mission_icon_path.is_empty() and ResourceLoader.exists(mission_icon_path):
		var mission_icon := Sprite3D.new()
		mission_icon.name = "MissionIcon"
		mission_icon.texture = load(mission_icon_path) as Texture2D
		mission_icon.pixel_size = 0.0048
		mission_icon.position = Vector3(0.0, 0.66, 0.0)
		mission_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mission_icon.shaded = false
		mission_icon.transparent = true
		mission_icon.no_depth_test = true
		mission_icon.render_priority = 18
		site.add_child(mission_icon)
	if is_instance_valid(host.objective_scent_guidance):
		host.objective_scent_guidance.call("register_site", site, "mission", "objective", 7.0)


func _update_field_missions(delta: float) -> void:
	if field_mission_result_timer > 0.0:
		field_mission_result_timer = maxf(0.0, field_mission_result_timer - delta)
		if field_mission_result_timer <= 0.0 and not is_instance_valid(host.active_field_mission):
			host.field_objective_title = ""
			host.field_objective_detail = ""
			host._refresh_objective_panel()
	if not is_instance_valid(host.active_field_mission):
		return

	var distance_to_site := player.global_position.distance_to(host.active_field_mission.global_position)
	if distance_to_site > _get_field_mission_fail_radius():
		_fail_field_mission("작전 구역을 너무 멀리 이탈했습니다.")
		return

	if field_mission_phase == "preparing":
		field_mission_prepare_timer = maxf(0.0, field_mission_prepare_timer - delta)
		_set_field_mission_objective(
			"작전 준비 · %s" % str(host.active_field_mission.get_meta("title", "현장 임무")),
			"시작까지 %.1f초 · 주변을 확인하고 엄폐하십시오." % field_mission_prepare_timer,
			Color("#f0c96d")
		)
		if field_mission_prepare_timer <= 0.0:
			_activate_field_mission()
		return

	field_mission_runtime += delta
	_update_field_mission_waves(delta)
	var mission_type := str(host.active_field_mission.get_meta("type", "defense"))
	match mission_type:
		"defense":
			host._update_defense_mission(delta, distance_to_site)
		"eliminate":
			host._update_eliminate_mission()
		"collect":
			host._update_collect_mission()
		"stealth":
			host._update_stealth_mission(delta, distance_to_site)
		"investigate":
			host._update_investigation_mission(delta)
		"stealth_reach":
			host._update_stealth_reach_mission(delta)


func _start_field_mission(site: Node3D) -> void:
	host.active_field_mission = site
	site.set_meta("status", "active")
	host.field_mission_elapsed = 0.0
	field_mission_wave_timer = FIELD_MISSION_FIRST_WAVE_DELAY
	field_mission_prepare_timer = FIELD_MISSION_PREPARE_DURATION
	field_mission_phase = "preparing"
	host.field_mission_spawned_enemies = 0
	host.field_mission_kills = 0
	host.field_mission_collected = 0
	field_mission_result_timer = 0.0
	field_mission_runtime = 0.0
	host.field_mission_detection_time = 0.0
	host.field_mission_investigation_hold = 0.0
	host.field_mission_investigation_target = null
	host.field_mission_noise_breached = false
	host._clear_active_mission_collectibles()
	_set_field_mission_site_state(site, "preparing")
	# 시작 문구는 좌상단 목표 패널 한 곳에서만 말한다. 예전에는 여기(패널)+알림
	# +활성화 알림까지 세 번 같은 말을 해서 두세 곳에서 뜨는 것처럼 보였다.
	_set_field_mission_objective(
		"작전 준비 · %s" % str(site.get_meta("title", "현장 임무")),
		"시작까지 %.1f초 · 준비가 끝나기 전에는 적이 투입되지 않습니다." % field_mission_prepare_timer,
		Color("#f0c96d")
	)


func _activate_field_mission() -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	field_mission_phase = "active"
	field_mission_prepare_timer = 0.0
	field_mission_wave_timer = FIELD_MISSION_FIRST_WAVE_DELAY
	field_mission_runtime = 0.0
	_set_field_mission_site_state(host.active_field_mission, "active")
	var mission_type := str(host.active_field_mission.get_meta("type", "defense"))
	match mission_type:
		"collect":
			_spawn_field_mission_collectibles(int(host.active_field_mission.get_meta("target_count", 3)))
		"investigate":
			_spawn_field_mission_investigation_points(int(host.active_field_mission.get_meta("target_count", 3)))
		"stealth_reach":
			_spawn_field_mission_reach_target(float(host.active_field_mission.get_meta("target_distance", 13.5)))
	_set_field_mission_objective(
		str(host.active_field_mission.get_meta("title", "현장 임무")),
		str(host.active_field_mission.get_meta("description", "현장 목표를 수행하십시오.")),
		Color("#efd06f")
	)
	# 개시 순간에만 짧게 번쩍이는 신호. 세부 목표는 목표 패널이 계속 추적한다.
	host._show_field_notice("▶ 현장 임무 개시")


func _get_field_mission_enemy_total() -> int:
	if not is_instance_valid(host.active_field_mission):
		return 0
	var mission_type := str(host.active_field_mission.get_meta("type", "defense"))
	if mission_type in ["stealth", "investigate", "stealth_reach"]:
		return int(host.active_field_mission.get_meta("guard_count", 0))
	return int(host.active_field_mission.get_meta("enemy_count", 0))


func _update_field_mission_waves(delta: float) -> void:
	if field_mission_phase != "active" or not is_instance_valid(host.active_field_mission):
		return
	var total_enemies := _get_field_mission_enemy_total()
	if total_enemies <= 0 or host.field_mission_spawned_enemies >= total_enemies:
		return
	field_mission_wave_timer = maxf(0.0, field_mission_wave_timer - delta)
	if field_mission_wave_timer > 0.0:
		return
	var progress := float(host.field_mission_spawned_enemies) / float(maxi(1, total_enemies))
	var wave_size := 3 if progress >= 0.55 else 2
	wave_size = mini(wave_size, total_enemies - host.field_mission_spawned_enemies)
	var mission_type := str(host.active_field_mission.get_meta("type", "defense"))
	if mission_type in ["stealth", "investigate", "stealth_reach"]:
		_spawn_field_mission_patrols(wave_size, progress)
	else:
		_spawn_field_mission_enemies(wave_size, progress)
	field_mission_wave_timer = lerpf(4.2, 2.2, progress)


func _get_field_mission_wave_status() -> String:
	var total_enemies := _get_field_mission_enemy_total()
	if total_enemies <= 0:
		return ""
	var stage := clampi(
		1 + floori(3.0 * float(host.field_mission_spawned_enemies) / float(maxi(1, total_enemies))),
		1,
		3
	)
	if host.field_mission_spawned_enemies < total_enemies:
		return "다음 접근 %.1f초 · 위협 %d단계" % [field_mission_wave_timer, stage]
	return "현장 투입 완료 · 위협 %d단계" % stage


func _update_field_mission_detection(delta: float) -> bool:
	if field_mission_runtime < 1.0:
		host.field_mission_detection_time = 0.0
		return false
	var detected := _is_player_detected_for_field_mission()
	if detected:
		host.field_mission_detection_time += delta
	else:
		host.field_mission_detection_time = maxf(0.0, host.field_mission_detection_time - delta * 1.8)
	return detected


func _is_player_detected_for_field_mission() -> bool:
	if not is_instance_valid(host.active_field_mission):
		return false
	var mission_id := int(host.active_field_mission.get_meta("mission_id", -1))
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if int(enemy.get_meta("field_mission_id", -2)) != mission_id:
			continue
		if bool(enemy.get("alerted")) and bool(enemy.get("has_current_line_of_sight")):
			return true
	return false


func _active_field_mission_requires_silence() -> bool:
	return (
		is_instance_valid(host.active_field_mission)
		and bool(host.active_field_mission.get_meta("silence_required", false))
	)


func _spawn_field_mission_enemies(count: int, escalation: float = 0.0) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var world := host.get_node("World") as ProceduralCityMap
	var mission_id := int(host.active_field_mission.get_meta("mission_id", 0))
	for squad_size in host._build_enemy_squad_sizes(count):
		var squad_anchor := _find_field_mission_enemy_position(
			world,
			host.active_field_mission.global_position
		)
		var kinds: Array[String] = []
		for member_index in squad_size:
			var loadout_roll := posmod(
				host.field_mission_spawned_enemies + member_index + mission_id,
				7
			)
			kinds.append(
				"grenadier"
					if loadout_roll == 6
					else ("melee" if loadout_roll == 4 else "pistol")
			)
		var threat := maxf(
			host.night_intensity,
			float(host.raid_zone_data.get("threat", 0.0)) + 0.16 + escalation * 0.34
		)
		var spawned: Array[CharacterBody3D] = host._spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			threat,
			host.active_field_mission.global_position,
			{"field_mission_id": mission_id}
		)
		# 의도한 분대 수를 센다. 스폰 위치를 못 찾아 0마리가 나와도 웨이브 카운터가
		# 멈추지 않게 해, 방어 임무가 "마지막 웨이브 미투입"으로 영원히 안 끝나는 걸 막는다.
		host.field_mission_spawned_enemies += maxi(squad_size, spawned.size())


func _spawn_field_mission_patrols(count: int, escalation: float = 0.0) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var world := host.get_node("World") as ProceduralCityMap
	var mission_id := int(host.active_field_mission.get_meta("mission_id", 0))
	var patrol_index := 0
	for squad_size in host._build_enemy_squad_sizes(count):
		var squad_anchor := _find_field_mission_enemy_position(
			world,
			host.active_field_mission.global_position
		)
		var kinds: Array[String] = []
		for member_index in squad_size:
			kinds.append("melee" if (patrol_index + member_index) % 4 == 3 else "pistol")
		var threat := maxf(
			host.night_intensity,
			float(host.raid_zone_data.get("threat", 0.0)) + 0.08 + escalation * 0.26
		)
		var spawned: Array[CharacterBody3D] = host._spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			threat,
			Vector3.INF,
			{
				"field_mission_id": mission_id,
				"stealth_mission_guard": true,
			}
		)
		# 의도한 분대 수를 센다. 스폰 위치를 못 찾아 0마리가 나와도 웨이브 카운터가
		# 멈추지 않게 해, 방어 임무가 "마지막 웨이브 미투입"으로 영원히 안 끝나는 걸 막는다.
		host.field_mission_spawned_enemies += maxi(squad_size, spawned.size())
		patrol_index += squad_size


func _find_field_mission_enemy_position(
	world: ProceduralCityMap,
	mission_position: Vector3
) -> Vector3:
	# 적은 작전 반경(그려진 링) 언저리에서 나타나 중심으로 좁혀 온다. 예전엔
	# 고정 23~34m라 링(존별 25~40m)과 어긋나 "전장이 표시 구역 밖"이었다.
	# 이제 반경에 비례해 링 가장자리~바깥에서 스폰돼 범위가 넓고 읽힌다.
	var active_radius := _get_field_mission_active_radius()
	var min_site := maxf(FIELD_MISSION_ENEMY_MIN_SITE_DISTANCE, active_radius * 0.82)
	var max_site := maxf(active_radius * 1.5, min_site + 9.0)
	var fallback := world.find_nearest_physically_open_position(
		mission_position + Vector3(max_site, 0.0, 0.0),
		0.72,
		[player.get_rid()]
	)
	fallback.y = 0.08
	for attempt in 32:
		var angle := spawn_random.randf_range(0.0, TAU)
		var distance := spawn_random.randf_range(min_site, max_site)
		var candidate := world.find_nearest_physically_open_position(
			mission_position + Vector3(cos(angle), 0.0, sin(angle)) * distance,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		fallback = candidate
		if (
			candidate.distance_to(player.global_position) >= FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE
			and not world.is_position_in_safe_zone(candidate)
		):
			return candidate
	if fallback.distance_to(player.global_position) < FIELD_MISSION_ENEMY_MIN_PLAYER_DISTANCE:
		var reinforcement_position: Vector3 = host._find_reinforcement_position()
		if reinforcement_position != Vector3.INF:
			return reinforcement_position
	return fallback


func _spawn_field_mission_investigation_points(count: int) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var world := host.get_node("World") as ProceduralCityMap
	for index in count:
		var angle := (
			TAU * float(index) / float(maxi(1, count))
			+ spawn_random.randf_range(-0.42, 0.42)
		)
		var distance := spawn_random.randf_range(12.0, 24.0)
		var requested: Vector3 = (
			host.active_field_mission.global_position
			+ Vector3(cos(angle), 0.0, sin(angle)) * distance
		)
		var position := world.find_nearest_physically_open_position(
			requested,
			0.52,
			[player.get_rid()]
		)
		var clue := Node3D.new()
		clue.name = "MissionClue_%02d" % (index + 1)
		host.add_child(clue)
		clue.global_position = Vector3(position.x, 0.08, position.z)
		_build_field_mission_investigation_point(clue)
		host.active_mission_collectibles.append(clue)


func _build_field_mission_investigation_point(clue: Node3D) -> void:
	var case_material := StandardMaterial3D.new()
	case_material.albedo_color = Color("#39443f")
	case_material.metallic = 0.38
	case_material.roughness = 0.72
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.52, 0.12, 0.38)
	case_mesh.material = case_material
	var case := MeshInstance3D.new()
	case.name = "EvidenceCase"
	case.position.y = 0.11
	case.rotation.y = spawn_random.randf_range(-0.45, 0.45)
	case.mesh = case_mesh
	clue.add_child(case)
	var signal_material := StandardMaterial3D.new()
	signal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	signal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	signal_material.albedo_color = Color(0.92, 0.73, 0.32, 0.72)
	signal_material.emission_enabled = true
	signal_material.emission = Color("#d8b456")
	signal_material.emission_energy_multiplier = 2.0
	var signal_mesh := CylinderMesh.new()
	signal_mesh.top_radius = 0.09
	signal_mesh.bottom_radius = 0.12
	signal_mesh.height = 0.06
	signal_mesh.material = signal_material
	var signal_marker := MeshInstance3D.new()
	signal_marker.name = "EvidenceSignal"
	signal_marker.position.y = 0.21
	signal_marker.mesh = signal_mesh
	clue.add_child(signal_marker)
	host._add_interaction_marker(clue, Color("#d8b456"), 0.58, false)
	var label := Label3D.new()
	label.name = "EvidenceLabel"
	label.text = "조사"
	label.position = Vector3(0.0, 0.86, 0.0)
	label.font = FONT
	label.font_size = 23
	label.modulate = Color("#f0d994")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	clue.add_child(label)
	if is_instance_valid(host.objective_scent_guidance):
		host.objective_scent_guidance.call("register_site", clue, "active_target", "objective", 6.0)


func _spawn_field_mission_reach_target(target_distance: float) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var world := host.get_node("World") as ProceduralCityMap
	var angle := spawn_random.randf_range(0.0, TAU)
	var requested: Vector3 = (
		host.active_field_mission.global_position
		+ Vector3(cos(angle), 0.0, sin(angle)) * maxf(30.0, target_distance)
	)
	var position := world.find_nearest_physically_open_position(
		requested,
		0.62,
		[player.get_rid()]
	)
	var target := Node3D.new()
	target.name = "StealthReachTarget"
	host.add_child(target)
	target.global_position = Vector3(position.x, 0.08, position.z)
	_build_field_mission_reach_target(target)
	host.active_mission_collectibles.append(target)


func _build_field_mission_reach_target(target: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.34, 0.78, 0.58, 0.22)
	material.emission_enabled = true
	material.emission = Color("#67c898")
	material.emission_energy_multiplier = 1.8
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 0.94
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 10
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.name = "SafeRouteRing"
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(ring)
	var label := Label3D.new()
	label.name = "ReachTargetLabel"
	label.text = "안전 지점"
	label.position = Vector3(0.0, 1.02, 0.0)
	label.font = FONT
	label.font_size = 25
	label.modulate = Color("#9be0bb")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	target.add_child(label)
	if is_instance_valid(host.objective_scent_guidance):
		host.objective_scent_guidance.call("register_site", target, "active_target", "objective", 6.5)


func _spawn_field_mission_collectibles(count: int) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var world := host.get_node("World") as ProceduralCityMap
	for index in count:
		var angle := TAU * float(index) / float(maxi(1, count)) + spawn_random.randf_range(-0.35, 0.35)
		var requested: Vector3 = (
			host.active_field_mission.global_position
			+ Vector3(cos(angle), 0.0, sin(angle))
			* spawn_random.randf_range(11.0, 22.0)
		)
		var position := world.find_nearest_physically_open_position(
			requested,
			0.52,
			[player.get_rid()]
		)
		var collectible := Node3D.new()
		collectible.name = "MissionCollectible_%02d" % (index + 1)
		host.add_child(collectible)
		collectible.global_position = Vector3(position.x, 0.08, position.z)
		_build_field_mission_collectible(collectible)
		host.active_mission_collectibles.append(collectible)


func _build_field_mission_collectible(collectible: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#e2c56a")
	material.emission_enabled = true
	material.emission = Color("#f2cf69")
	material.emission_energy_multiplier = 2.2
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.28
	mesh.height = 0.42
	mesh.radial_segments = 12
	mesh.material = material
	var prop := MeshInstance3D.new()
	prop.name = "MissionCollectibleSignal"
	prop.position.y = 0.24
	prop.mesh = mesh
	collectible.add_child(prop)
	host._add_interaction_marker(collectible, Color("#efd06f"), 0.68, false)
	var label := Label3D.new()
	label.name = "MissionCollectibleLabel"
	label.text = "회수"
	label.position = Vector3(0.0, 0.94, 0.0)
	label.font = FONT
	label.font_size = 24
	label.modulate = Color("#ffe79a")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	collectible.add_child(label)
	if is_instance_valid(host.objective_scent_guidance):
		host.objective_scent_guidance.call("register_site", collectible, "active_target", "objective", 6.0)


func _complete_field_mission() -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var completed_site: Node3D = host.active_field_mission
	completed_site.set_meta("status", "completed")
	var reward_text := _grant_field_mission_reward(
		completed_site.get_meta("reward", {}) as Dictionary
	)
	var mission_title := str(completed_site.get_meta("title", "현장 임무"))
	if not host.completed_mission_titles.has(mission_title):
		host.completed_mission_titles.append(mission_title)
		host.completed_mission_xp += 70
		host.extraction.update_banked_level_watch()
	_set_field_mission_site_state(completed_site, "completed")
	_set_field_mission_objective(
		"임무 완료 · %s" % mission_title,
		"보상  %s · 경험치 +70" % reward_text,
		Color("#7de0a8")
	)
	host._show_field_notice("임무 완료 · %s" % reward_text)
	host._advance_contract_progress("field_mission")
	field_mission_result_timer = FIELD_MISSION_RESULT_DURATION
	field_mission_phase = "idle"
	field_mission_prepare_timer = 0.0
	host.active_field_mission = null
	host._clear_active_mission_collectibles()


func _fail_field_mission(reason: String) -> void:
	if not is_instance_valid(host.active_field_mission):
		return
	var failed_site: Node3D = host.active_field_mission
	failed_site.set_meta("status", "failed")
	_set_field_mission_site_state(failed_site, "failed")
	_set_field_mission_objective(
		"임무 실패 · %s" % str(failed_site.get_meta("title", "현장 임무")),
		reason,
		Color("#ef796f")
	)
	host._show_field_notice("임무 실패 · %s" % reason)
	field_mission_result_timer = FIELD_MISSION_RESULT_DURATION
	field_mission_phase = "idle"
	field_mission_prepare_timer = 0.0
	host.active_field_mission = null
	host._clear_active_mission_collectibles()


func _grant_field_mission_reward(reward: Dictionary) -> String:
	var reward_parts: Array[String] = []
	var canned_food_reward := int(reward.get("canned_food", 0))
	var medkit_reward := int(reward.get("medkits", 0))
	var ammo_reward := int(reward.get("ammo", 0))
	if canned_food_reward > 0:
		GameState.canned_food += canned_food_reward
		reward_parts.append("통조림 %d" % canned_food_reward)
	if medkit_reward > 0:
		GameState.medkits += medkit_reward
		reward_parts.append("구급약 %d" % medkit_reward)
	if ammo_reward > 0:
		var ammo_id := GameState.get_mission_reward_ammo_id()
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + ammo_reward)
		if ammo_id == GameState.equipped_ammo_id:
			host.reserve_ammo = GameState.get_ammo_count(ammo_id)
			GameState.reserve_ammo = host.reserve_ammo
		reward_parts.append("%s %d발" % [
			str(WEAPON_SYSTEM.get_ammo(ammo_id).get("display_name", "탄환")),
			ammo_reward,
		])
	var component_reward := maxi(0, int(reward.get("component", 0)))
	if component_reward > 0:
		var component_ids := ["rubber_gasket", "scope_lens", "magazine_spring"]
		var component_names := ["고무 패킹", "스코프 렌즈", "탄창 스프링"]
		var rewarded_components: Array[String] = []
		for _reward_index in component_reward:
			var component_index := spawn_random.randi_range(0, component_ids.size() - 1)
			GameState.add_mod_component(component_ids[component_index], 1)
			rewarded_components.append(component_names[component_index])
		reward_parts.append("부품 %d개 · %s" % [
			component_reward,
			", ".join(rewarded_components),
		])
	GameState.save_persistent_state()
	host._update_equipment_ui()
	return ", ".join(reward_parts) if not reward_parts.is_empty() else "현장 보급품"


func _set_field_mission_site_state(site: Node3D, state: String) -> void:
	var color := Color("#5eb9ad")
	var label_text := str(site.get_meta("title", "현장 임무"))
	match state:
		"preparing":
			color = Color("#e0b957")
			label_text = "작전 준비 중"
		"active":
			color = Color("#e7c765")
			label_text = "작전 진행 중"
		"completed":
			color = Color("#69d89c")
			label_text = "완료"
		"failed":
			color = Color("#d35f5f")
			label_text = "실패"
	var marker_material := site.get_meta("marker_material", null) as StandardMaterial3D
	if marker_material:
		marker_material.albedo_color = Color(color.r, color.g, color.b, 0.24)
		marker_material.emission = color
	var marker_label := site.get_node_or_null("MissionMarkerLabel") as Label3D
	if marker_label:
		marker_label.text = label_text
		marker_label.modulate = color
	var active_boundary := site.get_node_or_null("MissionPlayArea") as MeshInstance3D
	if active_boundary:
		active_boundary.visible = state in ["preparing", "active"]
	var active_boundary_material := (
		site.get_meta("active_boundary_material", null) as StandardMaterial3D
	)
	if active_boundary_material:
		active_boundary_material.albedo_color = Color(color.r, color.g, color.b, 0.10)
		active_boundary_material.emission = color


func _set_field_mission_objective(title: String, detail: String, color: Color) -> void:
	var objective_detail := detail
	var objective_title := title
	if is_instance_valid(host.active_field_mission):
		var category := _get_field_mission_category(
			str(host.active_field_mission.get_meta("type", "defense"))
		)
		if not objective_title.begins_with("["):
			objective_title = "[%s 작전] %s" % [category, objective_title]
		if (
			str(host.active_field_mission.get_meta("status", "")) == "active"
			and field_mission_phase == "active"
		):
			var wave_status := _get_field_mission_wave_status()
			if not wave_status.is_empty():
				var compact_detail_lines := objective_detail.split("\n", false)
				var compact_detail := (
					compact_detail_lines[0]
					if not compact_detail_lines.is_empty()
					else "현장 목표 수행 중"
				)
				objective_detail = "%s · %s" % [
					compact_detail,
					wave_status,
				]
	host.field_objective_title = objective_title
	host.field_objective_detail = objective_detail
	host.field_objective_color = color
	host._refresh_objective_panel()
