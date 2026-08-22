class_name FieldIncidents
extends RefCounted

# 판 위의 돌발 상황들 — 고가치 핫스팟, 추락 수송대 쟁탈전, 세력 충돌.
# main.gd에서 10개 함수를 옮겼다. 발동 시점은 raid_event_director가 정하고,
# 여기는 각 사건의 수명주기만 책임진다.


const AIM_REVEAL_BUILDING_ALPHA := 0.28
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const CRASHED_CONVOY_CACHE_TEXTURE := preload("res://assets/events/crashed_convoy_cache_v1.png")
const DYNAMIC_INCIDENT_DURATION := 150.0
const DYNAMIC_INCIDENT_GUARD_RADIUS := 6.0
const DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS := 6
const FATIGUE_DAMAGE_PER_POINT := 0.045
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const MAP_CONTENT_SCALE := ProceduralCityMap.WORLD_SCALE
const OCCLUSION_DEPTH_LIMIT := 14.0
const OCCLUSION_LATERAL_LIMIT := 5.1
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const PHARMACY_EMERGENCY_CACHE_TEXTURE := preload("res://assets/events/pharmacy_emergency_cache_v1.png")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_HOTSPOT_COUNT := 3
const RAID_HOTSPOT_DISCOVERY_DISTANCE := 24.0
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const SECURE_MILITARY_CACHE_TEXTURE := preload("res://assets/events/secure_military_cache_v1.png")
const SILHOUETTE_COLOR := Color("#26343b")
const STRUCTURE_REVEAL_BUILDING_ALPHA := 0.46
const STRUCTURE_REVEAL_HALF_ANGLE_DEG := 52.5
const STRUCTURE_REVEAL_RADIUS := 9.5
const STRUCTURE_REVEAL_VEHICLE_ALPHA := 0.58
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var faction_conflict_tick := 0.0


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _spawn_high_value_hotspots(world: ProceduralCityMap) -> void:
	host.raid_hotspots.clear()
	var occupied_positions: Array[Vector3] = []
	for site in host.extraction_sites:
		if is_instance_valid(site):
			occupied_positions.append(site.global_position)
	var hotspot_types := ["military", "pharmacy", "sealed_parts"]
	for index in RAID_HOTSPOT_COUNT:
		var position: Vector3 = host._find_stratified_map_position(
			world,
			index,
			RAID_HOTSPOT_COUNT,
			30.0,
			24.0,
			occupied_positions,
			0.08
		)
		occupied_positions.append(position)
		var hotspot_type: String = hotspot_types[index % hotspot_types.size()]
		var display_name := "봉쇄 약국 응급 캐시"
		if hotspot_type == "military":
			display_name = "잠긴 군용 보급함"
		elif hotspot_type == "sealed_parts":
			display_name = "기밀 정비 부품함"
		var point: Node3D = host._create_field_interaction(
			"high_value_cache",
			position,
			display_name,
			3.0
		)
		var marker_id := "hotspot_%02d" % index
		point.name = "HighValueHotspot_%02d" % index
		point.set_meta("hotspot_type", hotspot_type)
		point.set_meta("map_marker_id", marker_id)
		point.set_meta("map_discovered", false)
		point.set_meta("interaction_distance", 3.2)
		_build_high_value_hotspot_prop(point, hotspot_type)
		host.raid_hotspots.append(point)


func _build_high_value_hotspot_prop(point: Node3D, hotspot_type: String) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "HotspotSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 9
	sprite.position.y = 0.72
	var color := Color("#dfb85d")
	# pixel_size 는 월드 폭(m)/텍스처 폭 — 임포트 size_limit 으로 해상도가 바뀌어도 같은 크기.
	match hotspot_type:
		"pharmacy":
			sprite.texture = PHARMACY_EMERGENCY_CACHE_TEXTURE
			sprite.pixel_size = 1.8183 / float(maxi(1, sprite.texture.get_width()))
			sprite.position.y = 1.02
			color = Color("#62d5d8")
		"sealed_parts":
			sprite.texture = SECURE_MILITARY_CACHE_TEXTURE
			sprite.pixel_size = 2.3199 / float(maxi(1, sprite.texture.get_width()))
			sprite.modulate = Color("#b6cee0")
			color = Color("#8fb9db")
		_:
			sprite.texture = SECURE_MILITARY_CACHE_TEXTURE
			sprite.pixel_size = 2.3199 / float(maxi(1, sprite.texture.get_width()))
	point.add_child(sprite)
	host._add_interaction_marker(point, color, 1.55, false)
	var marker := Sprite3D.new()
	marker.name = "HotspotBeacon"
	marker.texture = host._get_loot_glow_texture()
	marker.position = Vector3(0, 2.35, 0)
	marker.pixel_size = 0.0055
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.transparent = true
	marker.no_depth_test = true
	marker.render_priority = 121
	marker.modulate = color
	point.add_child(marker)


func _update_hotspot_discovery() -> void:
	for point in host.raid_hotspots:
		if (
			not is_instance_valid(point)
			or bool(point.get_meta("completed", false))
			or bool(point.get_meta("map_discovered", false))
		):
			continue
		if player.global_position.distance_to(point.global_position) > RAID_HOTSPOT_DISCOVERY_DISTANCE:
			continue
		point.set_meta("map_discovered", true)
		var marker_id := str(point.get_meta("map_marker_id", ""))
		if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("discover_raid_marker"):
			host.tactical_map.call("discover_raid_marker", marker_id)
		host._show_field_notice(
			"고가치 지점 발견 · %s" % str(point.get_meta("display_name", "보급 거점"))
		)


func _update_dynamic_incident_winner_guard() -> void:
	if (
		host.dynamic_incident_state != "active"
		or not is_instance_valid(host.dynamic_incident_site)
		or not host.dynamic_incident_winning_faction.is_empty()
	):
		return
	var survivors: Array[CharacterBody3D] = []
	var surviving_factions: Array[String] = []
	for enemy in host.enemies:
		if (
			not is_instance_valid(enemy)
			or bool(enemy.get("dying"))
			or not bool(enemy.get_meta("dynamic_incident", false))
			or not enemy.has_method("get_faction_id")
		):
			continue
		var faction_id := str(enemy.call("get_faction_id"))
		if faction_id.is_empty():
			continue
		survivors.append(enemy)
		if not surviving_factions.has(faction_id):
			surviving_factions.append(faction_id)
	if survivors.is_empty() or surviving_factions.size() != 1:
		return
	host.dynamic_incident_winning_faction = surviving_factions[0]
	var route := _build_dynamic_incident_guard_route(host.dynamic_incident_site.global_position)
	for survivor_index in survivors.size():
		var survivor: Node3D = survivors[survivor_index]
		survivor.set_meta("dynamic_incident_guard", true)
		if survivor.has_method("restore_player_target"):
			survivor.call("restore_player_target")
		if survivor.has_method("assign_squad"):
			var angle := TAU * float(survivor_index) / float(maxi(1, survivors.size()))
			var formation_offset := Vector3(cos(angle), 0.0, sin(angle)) * 1.8
			survivor.call(
				"assign_squad",
				9000,
				host.dynamic_incident_site.global_position,
				formation_offset
			)
		if survivor.has_method("configure_patrol"):
			var assigned_route: Array[Vector3] = []
			for route_offset in route.size():
				assigned_route.append(route[(route_offset + survivor_index) % route.size()])
			survivor.call("configure_patrol", "route", assigned_route)
	host._show_field_notice("수송품 교전 종료 · 승리 세력이 보급품 주변을 경계합니다.")


func _build_dynamic_incident_guard_route(center: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var world := host.get_node_or_null("World") as ProceduralCityMap
	if world == null:
		route.append(center)
		return route
	for index in DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS:
		var angle := TAU * float(index) / float(DYNAMIC_INCIDENT_GUARD_ROUTE_POINTS)
		var requested := center + Vector3(cos(angle), 0.0, sin(angle)) * DYNAMIC_INCIDENT_GUARD_RADIUS
		var position := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		# 지형 스냅이 경로점을 화물에서 멀리 밀어낼 수 있다. 경비는 화물 곁을
		# 지키는 게 목적이므로 반경 7m 안으로 되당긴다(맵에 따라 간헐 실패하던 원인).
		var from_center := position - center
		from_center.y = 0.0
		if from_center.length() > 7.0:
			position = center + from_center.normalized() * 6.0
		position.y = 0.78
		route.append(position)
	return route


func _update_dynamic_incident(delta: float) -> void:
	# 발동 시점은 이제 raid_event_director가 정한다. 여기서는 진행 중인
	# 사건의 남은 시간과 HUD만 돌본다.
	if host.dynamic_incident_state != "active":
		return
	host.dynamic_incident_timer = maxf(0.0, host.dynamic_incident_timer - delta)
	if is_instance_valid(host.hud.dynamic_incident_hud):
		var distance: float = (
			player.global_position.distance_to(host.dynamic_incident_site.global_position)
			if is_instance_valid(host.dynamic_incident_site)
			else 0.0
		)
		var remaining := ceili(host.dynamic_incident_timer)
		host.hud.dynamic_incident_detail.text = "수송품 쟁탈전 · %dm · %02d:%02d" % [
			roundi(distance),
			remaining / 60,
			remaining % 60,
		]
		host.hud.dynamic_incident_progress.value = host.dynamic_incident_timer
	if host.dynamic_incident_timer <= 0.0:
		_expire_dynamic_incident()


func _expire_dynamic_incident() -> void:
	host.dynamic_incident_state = "expired"
	host._layout_center_top_banners()
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("remove_raid_marker"):
		host.tactical_map.call("remove_raid_marker", "dynamic_convoy")
	if is_instance_valid(host.dynamic_incident_site):
		host.field_interactions.erase(host.dynamic_incident_site)
		host.field_loot_containers.erase(host.dynamic_incident_site)
		host.dynamic_incident_site.queue_free()
	host.dynamic_incident_site = null
	host._show_field_notice("돌발 사건 종료 · 수송품이 다른 세력에게 넘어갔습니다.")


func _spawn_dynamic_incident_rewards(origin: Vector3) -> int:
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(host.raid_zone_data)
	var random := RandomNumberGenerator.new()
	random.seed = GameState.map_seed ^ 0x51C7 ^ hash(origin)
	var container_type := "secure_cache" if stage_tier >= 3 else "weapon_case"
	var definitions: Array[Dictionary] = LOOT_ECONOMY.roll_container(
		container_type,
		stage_tier,
		"open_space_edge",
		random
	)
	var spawned_count: int = host._spawn_opportunity_definitions(
		origin,
		definitions,
		false
	)
	for item_id in ["ammo", "medkit", "scope_lens"]:
		var definition: Dictionary = host._build_guaranteed_opportunity_definition(
			item_id,
			stage_tier,
			random
		)
		if host._spawn_opportunity_definition(
			origin,
			definition,
			spawned_count,
			true
		):
			spawned_count += 1
	return spawned_count


func _spawn_dynamic_convoy_incident(world: ProceduralCityMap) -> void:
	# 가드의 목적은 중복 스폰 방지다. 예전 자체 타이머 시절의 "scheduled"
	# 전제가 남아 있어서, 디렉터가 idle 상태에서 부르면 조용히 무시됐다.
	if host.dynamic_incident_state == "active":
		return
	host.dynamic_incident_winning_faction = ""
	var incident_position: Vector3 = host._find_event_position_near_player(world, 36.0, 58.0)
	host.dynamic_incident_site = host._create_field_interaction(
		"dynamic_incident_cache",
		incident_position,
		"추락 수송대 보급품 확보",
		2.8
	)
	host.dynamic_incident_site.name = "DynamicConvoyIncident"
	host.dynamic_incident_site.set_meta("map_marker_id", "dynamic_convoy")
	host.dynamic_incident_site.set_meta("map_discovered", true)
	host.dynamic_incident_site.set_meta("interaction_distance", 3.5)
	var sprite := Sprite3D.new()
	sprite.name = "ConvoyWreck"
	sprite.texture = CRASHED_CONVOY_CACHE_TEXTURE
	# 월드 폭 2.92m 고정(텍스처 해상도 무관).
	sprite.pixel_size = 2.9184 / float(maxi(1, sprite.texture.get_width()))
	sprite.position.y = 0.86
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 9
	host.dynamic_incident_site.add_child(sprite)
	host._add_interaction_marker(
		host.dynamic_incident_site,
		Color("#e76549"),
		1.85,
		false
	)
	var conflict_axis := Vector3(
		spawn_random.randf_range(-1.0, 1.0),
		0.0,
		spawn_random.randf_range(-1.0, 1.0)
	).normalized()
	if conflict_axis.length_squared() < 0.1:
		conflict_axis = Vector3.RIGHT
	var first_anchor := world.find_nearest_physically_open_position(
		incident_position + conflict_axis * 6.5,
		0.62,
		[player.get_rid()]
	)
	var second_anchor := world.find_nearest_physically_open_position(
		incident_position - conflict_axis * 6.5,
		0.62,
		[player.get_rid()]
	)
	first_anchor.y = 0.78
	second_anchor.y = 0.78
	var squad_kinds_1: Array[String] = ["pistol", "melee"]
	var first_squad: Array[CharacterBody3D] = host._spawn_enemy_squad(
		world,
		first_anchor,
		squad_kinds_1,
		maxf(0.45, host.night_intensity),
		Vector3.INF,
		{"dynamic_incident": true}
	)
	var squad_kinds_2: Array[String] = ["pistol", "pistol"]
	var second_squad: Array[CharacterBody3D] = host._spawn_enemy_squad(
		world,
		second_anchor,
		squad_kinds_2,
		maxf(0.5, host.night_intensity),
		Vector3.INF,
		{"dynamic_incident": true}
	)
	for enemy in first_squad:
		enemy.call("set_faction", "raider")
	for enemy in second_squad:
		enemy.call("set_faction", "feral")
	if not first_squad.is_empty() and not second_squad.is_empty():
		for enemy in first_squad:
			enemy.call("set_combat_target", second_squad[0])
		for enemy in second_squad:
			enemy.call("set_combat_target", first_squad[0])
	host.dynamic_incident_state = "active"
	host.dynamic_incident_timer = DYNAMIC_INCIDENT_DURATION
	# 표시 여부와 위치는 중앙 상단 배너 스택이 정한다. 직접 visible을 켜면
	# 보스 경고나 긴장도 알림과 같은 자리에 겹쳐 뜬다.
	host._layout_center_top_banners()
	host.hud.dynamic_incident_progress.value = DYNAMIC_INCIDENT_DURATION
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("register_raid_marker"):
		host.tactical_map.call(
			"register_raid_marker",
			"dynamic_convoy",
			incident_position,
			"incident",
			"추락 수송대",
			true
		)
	# 시작 배너는 raid_event_director가 이미 띄운다(같은 프레임에 또 띄우면 덮어써서
	# 원래 문구가 안 보였다). 여기서는 지도 마커만 남기고 알림은 중복 발화하지 않는다.


func _update_faction_conflicts(delta: float) -> void:
	faction_conflict_tick += delta
	if faction_conflict_tick < 0.8:
		return
	faction_conflict_tick = 0.0
	_update_dynamic_incident_winner_guard()
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("get_faction_id"):
			continue
		if bool(enemy.get_meta("dynamic_incident_guard", false)):
			continue
		var is_dynamic_incident_actor := bool(enemy.get_meta("dynamic_incident", false))
		if (
			not is_dynamic_incident_actor
			and enemy.has_method("is_targeting_player")
			and not bool(enemy.call("is_targeting_player"))
		):
			continue
		if not is_dynamic_incident_actor and bool(enemy.get("alerted")):
			continue
		var nearest_hostile: CharacterBody3D
		var nearest_distance := 30.0 if is_dynamic_incident_actor else 14.0
		for other in host.enemies:
			if (
				not is_instance_valid(other)
				or bool(other.get("dying"))
				or other == enemy
				or not other.has_method("get_faction_id")
			):
				continue
			if is_dynamic_incident_actor and not bool(other.get_meta("dynamic_incident", false)):
				continue
			if str(other.call("get_faction_id")) == str(enemy.call("get_faction_id")):
				continue
			var distance: float = enemy.global_position.distance_to(other.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_hostile = other
		if is_instance_valid(nearest_hostile) and enemy.has_method("set_combat_target"):
			enemy.call("set_combat_target", nearest_hostile)
