class_name ExtractionFlow
extends RefCounted

# 탈출 — 비콘 생성, 발견, 봉쇄, 진입 연출, 정산까지의 전체 흐름.
# main.gd에서 11개 함수를 옮겼다.


const BROKEN_SENTRY_TEXTURE := preload("res://assets/props/broken_sentry_salvage.png")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const COWERING_RESIDENT_TEXTURE_PATHS := {
	"n": "res://assets/characters/cowering_resident/up_action-frame-0.png",
	"ne": "res://assets/characters/cowering_resident/up_right_action-frame-0.png",
	"e": "res://assets/characters/cowering_resident/right_action-frame-3.png",
	"se": "res://assets/characters/cowering_resident/down_right_action-frame-1.png",
	"s": "res://assets/characters/cowering_resident/down_action-frame-2.png",
	"sw": "res://assets/characters/cowering_resident/down_left_action-frame-2.png",
	"w": "res://assets/characters/cowering_resident/left_action-frame-3.png",
	"nw": "res://assets/characters/cowering_resident/up_left_action-frame-0.png",
}
const ESCORT_SPEED_PENALTY := 0.07
const EXTRACTION_BEACON_TEXTURE := preload("res://assets/extraction/extraction_beacon_generated_v1.png")
const FATIGUE_AIM_HOLD_RATE := 0.09
const FATIGUE_IDLE_RATE := 0.0
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_MAX := 100.0
const FATIGUE_MOVING_RATE := 0.055
const FATIGUE_RESCUE_GAIN := 2.2
const FATIGUE_SALVAGE_GAIN := 3.5
const FATIGUE_SPEED_MIN := 0.58
const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_INTERACTION_FACING_WEIGHT := 1.35
const FIELD_INTERACTION_SIGHT_HEIGHT := 0.48
const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")
const FIELD_MISSION_STEALTH_HOLD_RADIUS := 14.0
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const LORE_CLUE_COUNT := 6
const LORE_ENTRIES := preload("res://scripts/lore_catalog.gd").ENTRIES
const LORE_POSTER_TEXTURE := preload("res://assets/lore/forgotten_notice_board_v1.png")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_EXTRACTION_POLICY := preload("res://scripts/raid_extraction_policy.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const RESCUED_CAT_FOLLOWER_SCRIPT := preload("res://scripts/rescued_cat_follower.gd")
const RESCUE_HOLD_DURATION := 1.8
const RESCUE_POINT_COUNT := 5
const SALVAGE_HOLD_DURATION := 2.4
const SALVAGE_MISC_POINT_COUNT := 4
const SALVAGE_VEHICLE_POINT_COUNT := 10
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const TACTICAL_MAP_SCRIPT := preload("res://scripts/tactical_map.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var extraction_position := Vector3.ZERO
var extraction_prompt: Control
var extraction_success_label: Label
var pending_extraction_xp_result: Dictionary = {}
var selected_extraction_index := 0
var selected_extraction_multiplier := 1.0
var selected_extraction_title := "안전 귀환로"


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _seal_one_extraction_route() -> void:
	# 탈출로 하나를 실제로 잠근다. 계획이 무너지는 순간을 만드는 장치다.
	var sites := host.get_tree().get_nodes_in_group("field_extraction")
	var candidates: Array[Node3D] = []
	for site in sites:
		if not is_instance_valid(site):
			continue
		var node := site as Node3D
		if int(node.get_meta("extraction_index", 0)) == 0:
			continue  # 기본 귀환로는 남겨 둔다. 완전히 갇히면 좌절만 남는다.
		if bool(node.get_meta("extraction_sealed", false)):
			continue
		candidates.append(node)
	if candidates.is_empty():
		return
	var target := candidates[host.raid_event_random.randi_range(0, candidates.size() - 1)]
	target.set_meta("extraction_sealed", true)
	host.raid_sealed_extraction_index = int(target.get_meta("extraction_index", -1))
	target.remove_from_group("field_extraction")
	for child in target.get_children():
		if child is Sprite3D:
			(child as Sprite3D).modulate = Color(0.42, 0.36, 0.36, 0.85)
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("seal_extraction"):
		host.tactical_map.call("seal_extraction", host.raid_sealed_extraction_index)


func _find_random_extraction_position(
	world: ProceduralCityMap,
	random: RandomNumberGenerator,
	minimum_player_distance: float,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var map_limit := world.get_map_limit() * 0.82
	var fallback := world.get_extraction_position()
	fallback.y = 0.08
	var fallback_separation := -1.0
	for _attempt in 160:
		var requested := Vector3(
			random.randf_range(-map_limit, map_limit),
			0.08,
			random.randf_range(-map_limit, map_limit)
		)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		if candidate.distance_to(player.global_position) < minimum_player_distance:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var nearest_extraction_distance := INF
		for occupied_position in occupied_positions:
			nearest_extraction_distance = minf(
				nearest_extraction_distance,
				candidate.distance_to(occupied_position)
			)
		if occupied_positions.is_empty():
			nearest_extraction_distance = 32.0
		if nearest_extraction_distance > fallback_separation:
			fallback = candidate
			fallback_separation = nearest_extraction_distance
		if nearest_extraction_distance >= 32.0:
			return candidate
	return fallback


func _setup_extraction_site(world: ProceduralCityMap) -> void:
	host.extraction_sites.clear()
	host.discovered_extraction_indices.clear()
	var extraction_random := RandomNumberGenerator.new()
	extraction_random.seed = (
		int(GameState.map_seed)
		^ (int(GameState.raid_serial) * 982451653)
		^ 0x45584954
	)
	var positions: Array[Vector3] = []
	for index in 3:
		positions.append(_find_random_extraction_position(
			world,
			extraction_random,
			24.0 + float(index) * 3.0,
			positions
		))
	for index in positions.size():
		var site := _create_extraction_beacon(positions[index], index)
		host.extraction_sites.append(site)
		host.field_interactions.append(site)
		if index == 0:
			site.set_meta("map_discovered", true)
			host.discovered_extraction_indices[index] = true
	host.extraction_site = host.extraction_sites[0]
	extraction_position = host.extraction_site.global_position
	extraction_prompt = host.hud.field_interaction_panel

	host.extraction_fade = ColorRect.new()
	host.extraction_fade.name = "ExtractionFade"
	host.extraction_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.extraction_fade.color = Color(0, 0, 0, 0)
	host.extraction_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.extraction_fade.z_index = 500
	host.get_node("HUD").add_child(host.extraction_fade)
	extraction_success_label = Label.new()
	extraction_success_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	extraction_success_label.text = "탈출 성공"
	extraction_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_success_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extraction_success_label.add_theme_font_override("font", preload("res://assets/fonts/Pretendard-Regular.otf"))
	extraction_success_label.add_theme_font_size_override("font_size", 44)
	extraction_success_label.add_theme_color_override("font_color", Color("#e6dfc4"))
	extraction_success_label.modulate.a = 0.0
	extraction_success_label.z_index = 501
	host.get_node("HUD").add_child(extraction_success_label)
	host.hud.build_extraction_progress_ui()


func _show_extraction_result(rescued_count: int) -> void:
	host._refresh_pointer_mode()
	host._update_combat_overlay_visibility()
	var combat_xp := GameState.get_raid_experience_reward(host.run_kills, host.enemy_director.run_boss_kills)
	var cargo_result: Dictionary = host.jackpot._settle_jackpot_cargo()
	var cargo_xp := int(cargo_result.get("xp", 0))
	var base_xp_reward: int = combat_xp + host.completed_mission_xp + cargo_xp
	var xp_reward := roundi(float(base_xp_reward) * selected_extraction_multiplier)
	var route_xp_bonus := maxi(0, xp_reward - base_xp_reward)
	var route_bonus := _grant_extraction_route_bonus()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(selected_extraction_index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	host.hud.extraction_route_icon.texture = UI_ICONS.get_icon("raid", 44, route_color)
	host.hud.extraction_route_label.text = "%s  ·  정산 배율 ×%.2f\n%s" % [
		selected_extraction_title,
		selected_extraction_multiplier,
		str(route_bonus.get("summary", "경로 보급 보너스 없음")),
	]
	host.hud.extraction_route_label.add_theme_color_override(
		"font_color",
		route_color.lightened(0.18)
	)
	pending_extraction_xp_result = GameState.add_raid_experience(xp_reward)
	host.hud.extraction_result_title.text = "탈출 성공 · Lv.%d" % int(pending_extraction_xp_result.get("new_level", GameState.player_level))
	var mission_summary := "완료한 임무 없음"
	if not host.completed_mission_titles.is_empty():
		mission_summary = "완료 임무 · %s · 임무 XP +%d" % [
			", ".join(host.completed_mission_titles),
			host.completed_mission_xp,
		]
	var cargo_summary := str(cargo_result.get("summary", "특별 화물 없음"))
	# 경로 이름·배율·보급 보너스는 바로 위 extraction_route_label이 이미 말한다.
	# 여기서 한 번 더 반복하지 않는다.
	var lines: PackedStringArray = [
		"처치 %d명 · 보스 %d명 · 주민 후송 %d명" % [
			host.run_kills,
			host.enemy_director.run_boss_kills,
			rescued_count,
		],
		mission_summary,
		cargo_summary,
		"경로 XP +%d · 총 경험치 +%d" % [route_xp_bonus, xp_reward],
	]
	# 가방을 "시간"으로 환산한다. 원자재 12개는 아무 느낌도 없지만
	# "쉘터 가동 3시간 12분"은 다음 출정의 이유가 된다.
	var runtime_seconds := GameState.get_raw_material_runtime_seconds()
	if runtime_seconds > 0.0:
		lines.append("가져온 원자재  →  쉘터 가동 %s" % GameState.format_duration_korean(runtime_seconds))
	# 끝난 것만 정리하지 말고 다음까지 남은 거리를 보여준다.
	var next_goal := GameState.get_active_contract_progress_text()
	if not next_goal.is_empty():
		lines.append(next_goal)
	lines.append("획득품은 가방에 보존됩니다.")
	host.hud.extraction_result_summary.text = "\n".join(lines)
	var new_xp := int(pending_extraction_xp_result.get("new_xp", GameState.player_xp))
	var required := maxi(1, int(pending_extraction_xp_result.get("new_required", GameState.get_xp_required())))
	host.hud.extraction_xp_bar.value = float(new_xp) / float(required) * 100.0
	host.hud.extraction_xp_label.text = "Lv.%d   %d / %d XP" % [GameState.player_level, new_xp, required]
	host.hud.extraction_result_panel.visible = true
	if GameState.pending_level_choices > 0:
		host._show_level_reward_choices()
	else:
		var wait_tween := host.create_tween()
		wait_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		wait_tween.tween_interval(1.25)
		wait_tween.tween_callback(_finish_extraction_to_shelter)


func _finish_extraction_to_shelter() -> void:
	host.get_tree().paused = false
	GameState.returning_from_shelter = false
	GameState.register_shelter_return()
	SceneTransition.transition_to("res://scenes/shelter_interior.tscn")


func _grant_extraction_route_bonus() -> Dictionary:
	var bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(
		selected_extraction_index,
		host.raid_hotspots_opened,
		host.dynamic_incident_state == "claimed",
		host.run_kills,
		GameState.map_seed
	)
	GameState.canned_food += int(bonus.get("food", 0))
	GameState.medkits += int(bonus.get("medkits", 0))
	var component_id := str(bonus.get("component_id", ""))
	var component_count := int(bonus.get("component_count", 0))
	if not component_id.is_empty() and component_count > 0:
		GameState.add_mod_component(component_id, component_count)
	return bonus


func _create_extraction_beacon(world_position: Vector3, index: int) -> Node3D:
	var site := Node3D.new()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	var route_title := str(route_definition.get("title", "안전 귀환로"))
	var reward_multiplier := float(route_definition.get("reward_multiplier", 1.0))
	site.name = "SewerExtraction_%02d" % (index + 1)
	host.add_child(site)
	site.global_position = Vector3(world_position.x, 0.08, world_position.z)
	site.set_meta("interaction_type", "extraction")
	site.set_meta(
		"display_name",
		"안전 귀환 하수구" if index == 0 else route_title
	)
	site.set_meta("hold_duration", 0.0)
	site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE)
	site.set_meta("extraction_index", index)
	site.set_meta("map_discovered", false)
	site.set_meta("route_title", route_title)
	site.set_meta("reward_multiplier", reward_multiplier)
	site.set_meta("route_color", route_color)
	site.add_to_group("field_extraction")

	var sewer_sprite := Sprite3D.new()
	sewer_sprite.name = "SewerHatch"
	sewer_sprite.texture = EXTRACTION_BEACON_TEXTURE
	# The generated beacon is a taller freestanding prop than the old flat hatch.
	# Keep its footprint inside the extraction ring and lift the visual bottom to
	# the ground line instead of letting the transparent canvas sink below it.
	sewer_sprite.pixel_size = 0.0022
	sewer_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sewer_sprite.shaded = false
	sewer_sprite.transparent = true
	sewer_sprite.position.y = 0.92
	sewer_sprite.render_priority = 4
	site.add_child(sewer_sprite)

	host._add_interaction_marker(site, route_color, 1.55, true)
	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(
		route_color.r,
		route_color.g,
		route_color.b,
		0.12
	)
	beam_material.emission_enabled = true
	beam_material.emission = route_color
	beam_material.emission_energy_multiplier = 1.8
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.28
	beam_mesh.bottom_radius = 1.25
	beam_mesh.height = 5.5
	beam_mesh.radial_segments = 24
	beam_mesh.material = beam_material
	var beam := MeshInstance3D.new()
	beam.name = "ExtractionBeacon"
	beam.position.y = 2.75
	beam.mesh = beam_mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(beam)

	var light := OmniLight3D.new()
	light.name = "ExtractionLight"
	light.position.y = 1.15
	light.light_color = route_color
	light.light_energy = 3.2
	light.omni_range = 7.5
	light.shadow_enabled = false
	site.add_child(light)
	return site


func _update_extraction_prompt() -> void:
	host._update_field_interactions(0.0)


func _update_extraction_discovery() -> void:
	for site in host.extraction_sites:
		if not is_instance_valid(site) or bool(site.get_meta("map_discovered", false)):
			continue
		if not _is_extraction_in_player_sight(site):
			continue
		var index := int(site.get_meta("extraction_index", -1))
		if index < 0:
			continue
		site.set_meta("map_discovered", true)
		host.discovered_extraction_indices[index] = true
		if is_instance_valid(host.tactical_map):
			host.tactical_map.call("discover_extraction", index)
		host._show_field_notice("탈출구 발견 · 전술 지도에 하수구 위치가 기록되었습니다.")


func _is_extraction_in_player_sight(site: Node3D) -> bool:
	var offset := site.global_position - player.global_position
	offset.y = 0.0
	var distance := offset.length()
	var in_visibility_shape := distance <= 10.5
	if not in_visibility_shape and host.laser_aim_held and distance <= 32.0:
		var aim_direction: Vector3 = host._get_perception_aim_direction()
		aim_direction.y = 0.0
		in_visibility_shape = aim_direction.normalized().dot(offset.normalized()) >= cos(deg_to_rad(58.0))
	if not in_visibility_shape:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.55, 0),
		site.global_position + Vector3(0, 0.55, 0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _begin_extraction() -> void:
	if host.extraction_transition_active or host.player_death_sequence_active or host.player_health <= 0:
		return
	if is_instance_valid(host.nearby_field_interaction):
		selected_extraction_index = int(
			host.nearby_field_interaction.get_meta("extraction_index", 0)
		)
		selected_extraction_multiplier = float(
			host.nearby_field_interaction.get_meta("reward_multiplier", 1.0)
		)
		selected_extraction_title = str(
			host.nearby_field_interaction.get_meta("route_title", "안전 귀환로")
		)
	else:
		selected_extraction_index = 0
		selected_extraction_multiplier = 1.0
		selected_extraction_title = "안전 귀환로"
	host.extraction_transition_active = true
	host._refresh_pointer_mode()
	host._update_combat_overlay_visibility()
	extraction_prompt.visible = false
	host.fire_button_held = false
	host.mouse_fire_held = false
	host.laser_aim_held = false
	host.field_interaction_keyboard_held = false
	host.hud.field_interaction_touch_held = false
	host.pickup_touch_held = false
	host.touch_vector = Vector2.ZERO
	player.velocity = Vector3.ZERO
	host.recoil_velocity = Vector3.ZERO
	if is_instance_valid(host.extraction_fade):
		host.extraction_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var rescued_count: int = host._commit_rescued_followers()
	extraction_success_label.text = "탈출 성공 · %s" % selected_extraction_title
	GameState.finish_corpse_recovery_attempt()
	host._save_run_state()
	host.get_tree().paused = true
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(host.extraction_fade, "color:a", 1.0, 0.65)
	tween.tween_property(extraction_success_label, "modulate:a", 1.0, 0.32)
	tween.tween_interval(0.55)
	tween.tween_property(extraction_success_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_show_extraction_result.bind(rescued_count))

# ── 판 중 레벨업 확보 예고 ─────────────────────────────────────
# XP는 탈출해야 실제로 들어온다(죽으면 날아가는 판돈). 그 구조는 지키되,
# 쌓아둔 XP가 다음 레벨을 넘는 "순간"을 판 중에 보여준다.
# 도파민과 동시에 "지금 나갈까?"라는 압박을 만든다.
var banked_levels_announced := 0


func reset_banked_level_watch() -> void:
	banked_levels_announced = 0


func update_banked_level_watch() -> void:
	var banked_xp: int = (
		GameState.get_raid_experience_reward(host.run_kills, host.enemy_director.run_boss_kills)
		+ host.completed_mission_xp
	)
	var projected_levels := 0
	var simulated_xp: int = GameState.player_xp + banked_xp
	var simulated_level: int = GameState.player_level
	while simulated_xp >= GameState.get_xp_required(simulated_level):
		simulated_xp -= GameState.get_xp_required(simulated_level)
		simulated_level += 1
		projected_levels += 1
	if projected_levels > banked_levels_announced:
		banked_levels_announced = projected_levels
		host._show_field_notice(
			"레벨업 확보 · 탈출하면 Lv.%d
지금 죽으면 이 경험은 시체와 함께 남는다."
			% simulated_level
		)
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
			Input.vibrate_handheld(30)
