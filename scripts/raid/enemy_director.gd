class_name EnemyDirector
extends RefCounted

# 적의 존재를 책임지는 모듈 — 분대 소환, 순찰 경로, 증원 호출, 보스 등장,
# 사망 처리와 전리품 드랍까지. main.gd에서 18개 함수를 옮겼다.
#
# raid의 다른 모듈들(jackpot/incidents/field_missions)이 전부 여기의
# 스폰 헬퍼를 쓴다. 적을 만드는 방법은 이 파일 하나만 안다.


const AIM_REVEAL_BUILDING_ALPHA := 0.28
const AK_DROP_TEXTURE := preload("res://assets/weapons/ak47_drop.png")
const AK_PICKUP_POSITION := Vector3(1.15, 0.32, 0.7)
const AMMO_762_TEXTURE := preload("res://assets/items/ammo_762.png")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const BASE_ENEMY_COUNT := 24
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const CHURU_TEXTURE := preload("res://assets/items/churu_rare.png")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const DEEP_NIGHT_HOUR := 22.0
const DIRECTION_VECTORS := {
	"n": Vector2(0, -1),
	"ne": Vector2(1, -1),
	"e": Vector2(1, 0),
	"se": Vector2(1, 1),
	"s": Vector2(0, 1),
	"sw": Vector2(-1, 1),
	"w": Vector2(-1, 0),
	"nw": Vector2(-1, -1),
}
const ENEMY_PAIR_SQUAD_CHANCE := 0.78
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const ENEMY_VISIBILITY_FADE_IN_SPEED := 10.0
const ENEMY_VISIBILITY_FADE_OUT_SPEED := 3.2
const ENEMY_VISIBILITY_HOLD_SECONDS := 0.32
const FATIGUE_BOSS_NAME := "폐허의 포격수 묘르"
const FATIGUE_BOSS_TRIGGER := 50.0
const FATIGUE_DAMAGE_PER_POINT := 0.045
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_MAX := 100.0
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_SHOT_GAIN := 0.28
const FIELD_LOOT_CACHE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const FIRST_STAGE_SOLO_SQUAD_CHANCE := 0.62
const FIRST_STAGE_ZONE_ID := "jongno_outskirts"
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOOT_CONTAINER_VISUALS := preload("res://scripts/loot_container_visual_catalog.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const MAP_CONTENT_SCALE := ProceduralCityMap.WORLD_SCALE
const MAX_NIGHT_ENEMY_COUNT := 44
const MOBILE_AIM_ASSIST_ANGLE_WEIGHT := 24.0
const MOBILE_AIM_ASSIST_DISTANCE_WEIGHT := 0.32
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 42.0
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 34.0
const NIGHT_START_HOUR := 19.0
const OBJECTIVE_SCENT_GUIDANCE_SCRIPT := preload("res://scripts/objective_scent_guidance.gd")
const OCCLUSION_DEPTH_LIMIT := 14.0
const OCCLUSION_LATERAL_LIMIT := 5.1
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const PERCEPTION_SYSTEM_SCRIPT := preload("res://scripts/perception_system.gd")
const PICKUP_DISTANCE := 1.75
const PICKUP_HOLD_DURATION := 0.9
const RAID_ENTRY_ENEMY_SAFE_RADIUS := 30.0
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const RAID_PRESSURE_REWARD_MULTIPLIERS := [1.0, 1.15, 1.35, 1.65]
const RAID_PRESSURE_THRESHOLDS := [120.0, 300.0, 540.0]
const REINFORCEMENT_CALL_COOLDOWN := 38.0
const REINFORCEMENT_CALL_DURATION := 4.6
const REINFORCEMENT_CALL_TRIGGER_TIME := 30.0
const REINFORCEMENT_HIDDEN_TRIGGER_TIME := 14.0
const ROCKET_BOSS_SCRIPT := preload("res://scripts/rocket_boss.gd")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCENT_TRAIL_MANAGER_SCRIPT := preload("res://scripts/scent_trail_manager.gd")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const SECONDS_PER_GAME_HOUR := 36.0
const SILHOUETTE_COLOR := Color("#26343b")
const STEALTH_TAKEDOWN_PROMPT_SIZE := Vector2(196.0, 54.0)
const STRUCTURE_REVEAL_BUILDING_ALPHA := 0.46
const STRUCTURE_REVEAL_HALF_ANGLE_DEG := 52.5
const STRUCTURE_REVEAL_RADIUS := 9.5
const STRUCTURE_REVEAL_VEHICLE_ALPHA := 0.58
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const WEAPON_FLOAT_DISTANCE := 0.72
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const WEAPON_MUZZLE_FORWARD_DISTANCE := 0.64
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var enemy_spawn_serial := 0
var enemy_ranged_spawn_serial := 0
var enemy_squad_serial := 0
var sustained_combat_time := 0.0
var concealed_combat_time := 0.0
var reinforcement_call_cooldown := 0.0
var active_reinforcement_caller: CharacterBody3D
var run_boss_kills := 0
var fatigue_boss_event_triggered := false


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _find_distributed_enemy_position(
	world: ProceduralCityMap,
	index: int,
	total_count: int
) -> Vector3:
	var entry_safe_radius := float(host.raid_zone_data.get(
		"entry_safe_radius", RAID_ENTRY_ENEMY_SAFE_RADIUS
	))
	var occupied_positions: Array[Vector3] = []
	for enemy in host.enemies:
		if is_instance_valid(enemy):
			occupied_positions.append(enemy.global_position)
	if index == 0:
		var map_limit := world.get_map_limit() - 8.0
		for attempt in 16:
			var angle := TAU * float(attempt) / 16.0 + spawn_random.randf_range(-0.12, 0.12)
			var requested := (
				player.global_position
				+ Vector3(cos(angle), 0.0, sin(angle)) * (entry_safe_radius + 8.0)
			)
			requested.x = clampf(requested.x, -map_limit, map_limit)
			requested.z = clampf(requested.z, -map_limit, map_limit)
			requested.y = 0.78
			var nearby_candidate := world.find_nearest_physically_open_position(
				requested,
				0.62,
				[player.get_rid()]
			)
			nearby_candidate.y = 0.78
			if (
				nearby_candidate.distance_to(player.global_position) >= entry_safe_radius + 3.0
				and world.get_risk_band(nearby_candidate) != "safe"
			):
				return nearby_candidate
	return host._find_stratified_map_position(
		world,
		index - 1,
		total_count - 1,
		entry_safe_radius + 3.0,
		7.0,
		occupied_positions,
		0.78
	)


func _ensure_initial_enemy_safe_anchor(
	world: ProceduralCityMap,
	requested_anchor: Vector3,
	squad_index: int
) -> Vector3:
	var entry_safe_radius := float(host.raid_zone_data.get(
		"entry_safe_radius", RAID_ENTRY_ENEMY_SAFE_RADIUS
	))
	if (
		requested_anchor.distance_to(player.global_position) >= entry_safe_radius + 3.0
		and world.get_risk_band(requested_anchor) != "safe"
	):
		return requested_anchor
	var map_limit := world.get_map_limit() - 8.0
	for attempt in 32:
		var angle := (
			TAU * float(attempt) / 32.0
			+ float(squad_index) * 0.73
			+ spawn_random.randf_range(-0.08, 0.08)
		)
		var distance := entry_safe_radius + spawn_random.randf_range(6.0, 18.0)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		candidate.y = 0.78
		if (
			candidate.distance_to(player.global_position) >= entry_safe_radius + 3.0
			and not world.is_position_in_safe_zone(candidate)
			and world.get_risk_band(candidate) != "safe"
		):
			return candidate
	# 32번 다 실패해도 플레이어 코앞에 떨구지는 않는다. 원래 요청 지점이 너무
	# 가까우면 안전 반경까지 방사형으로 밀어내고, 그 근처의 열린 자리를 잡는다.
	# 출정하자마자 옆에서 적이 튀어나오는 인상을 원천 차단한다.
	if requested_anchor.distance_to(player.global_position) < entry_safe_radius:
		var push_angle := (
			spawn_random.randf_range(0.0, TAU)
			if requested_anchor.distance_to(player.global_position) < 0.5
			else atan2(
				requested_anchor.z - player.global_position.z,
				requested_anchor.x - player.global_position.x
			)
		)
		var pushed := player.global_position + Vector3(
			cos(push_angle), 0.0, sin(push_angle)
		) * (entry_safe_radius + 4.0)
		pushed.x = clampf(pushed.x, -map_limit, map_limit)
		pushed.z = clampf(pushed.z, -map_limit, map_limit)
		var safe_candidate := world.find_nearest_physically_open_position(
			pushed, 0.62, [player.get_rid()]
		)
		safe_candidate.y = 0.78
		return safe_candidate
	return requested_anchor


func _build_enemy_squad_sizes(total_count: int) -> Array[int]:
	var sizes: Array[int] = []
	var remaining := maxi(0, total_count)
	while remaining > 0:
		var squad_size := 1
		if host._is_first_stage_zone():
			if remaining >= 2 and spawn_random.randf() >= FIRST_STAGE_SOLO_SQUAD_CHANCE:
				squad_size = 2
		elif host.active_zone_rule == "crowd":
			# 무리 규칙(남대문): 분대를 더 크게 뭉친다. 좁은 통로에서 몰려온다.
			squad_size = mini(remaining, 3 if remaining >= 3 else remaining)
		elif remaining == 2 or remaining == 4:
			squad_size = 2
		elif remaining == 3:
			squad_size = 3
		elif remaining > 4:
			squad_size = 2 if spawn_random.randf() < ENEMY_PAIR_SQUAD_CHANCE else 3
		sizes.append(squad_size)
		remaining -= squad_size
	return sizes


func _spawn_enemy_squad(
	world: ProceduralCityMap,
	squad_anchor: Vector3,
	kinds: Array[String],
	threat: float,
	order_position: Vector3 = Vector3.INF,
	metadata: Dictionary = {}
) -> Array[CharacterBody3D]:
	var spawned: Array[CharacterBody3D] = []
	var assigned_squad_id := enemy_squad_serial
	enemy_squad_serial += 1
	for member_index in kinds.size():
		var spawn_position: Vector3 = host._find_squad_member_position(
			world,
			squad_anchor,
			member_index,
			kinds.size()
		)
		var enemy := _spawn_enemy(
			kinds[member_index],
			spawn_position,
			threat,
			assigned_squad_id,
			squad_anchor,
			spawn_position - squad_anchor
		)
		for metadata_key in metadata:
			enemy.set_meta(str(metadata_key), metadata[metadata_key])
		if order_position != Vector3.INF and enemy.has_method("receive_reinforcement_order"):
			enemy.call("receive_reinforcement_order", order_position)
		elif enemy.has_method("configure_patrol"):
			var patrol_selector := posmod(assigned_squad_id, 4)
			var patrol_mode := (
				"sentry"
				if patrol_selector == 0
				else ("route" if patrol_selector == 1 else "road_route")
			)
			enemy.call(
				"configure_patrol",
				patrol_mode,
				_build_enemy_patrol_route(
					world,
					spawn_position,
					assigned_squad_id * 7 + member_index,
					patrol_mode
				)
			)
		spawned.append(enemy)
	return spawned


func _build_enemy_patrol_route(
	world: ProceduralCityMap,
	origin: Vector3,
	route_seed: int,
	patrol_mode: String
) -> Array[Vector3]:
	var points: Array[Vector3] = [origin]
	if patrol_mode == "road_route":
		return world.get_long_road_patrol_route(origin, route_seed, [player.get_rid()])
	var point_count := 3 if patrol_mode == "sentry" else 5
	var route_radius := 4.2 if patrol_mode == "sentry" else 8.5
	var base_angle := deg_to_rad(float(posmod(route_seed * 67, 360)))
	for point_index in range(1, point_count):
		var angle := base_angle + TAU * float(point_index) / float(point_count - 1)
		var requested := origin + Vector3(cos(angle), 0.0, sin(angle)) * route_radius
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.58,
			[player.get_rid()]
		)
		candidate.y = origin.y
		var duplicate_point := false
		for existing in points:
			if existing.distance_to(candidate) < 1.4:
				duplicate_point = true
				break
		if (
			not duplicate_point
			and candidate.distance_to(origin) <= route_radius * 1.55
		):
			points.append(candidate)
	return points


func _spawn_enemy(
	kind: String,
	spawn_position: Vector3,
	threat: float,
	assigned_squad_id: int = -1,
	assigned_squad_anchor: Vector3 = Vector3.ZERO,
	formation_offset: Vector3 = Vector3.ZERO
) -> CharacterBody3D:
	var enemy_weapon_id := "baseball_bat"
	if kind != "melee":
		var roll := spawn_random.randf()
		if roll < lerpf(0.48, 0.22, threat):
			enemy_weapon_id = "m1911"
		elif roll < lerpf(0.82, 0.58, threat):
			enemy_weapon_id = "mp5"
		elif roll < lerpf(0.95, 0.88, threat):
			enemy_weapon_id = "ak47"
		else:
			enemy_weapon_id = "double_barrel"
		enemy_ranged_spawn_serial += 1
	var enemy := CharacterBody3D.new()
	enemy.name = "%s_%s_Enemy%d" % [kind.capitalize(), enemy_weapon_id, enemy_spawn_serial]
	enemy_spawn_serial += 1
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = spawn_position
	enemy.call("configure", kind, player, {}, threat, enemy_weapon_id)
	enemy.call("set_faction", "feral" if posmod(assigned_squad_id, 4) == 0 else "raider")
	if enemy.has_method("set_detection_profile"):
		if host._is_first_stage_zone():
			enemy.call("set_detection_profile", 1.0, 60.0, 0.9)
		else:
			enemy.call("set_detection_profile", 1.0, 58.0, 1.0)
	enemy.call("set_environment_visibility", host.night_intensity)
	host.add_child(enemy)
	if is_instance_valid(host.scent_system):
		host.scent_system.call("register_mover", enemy, "enemy")
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("damaged"):
		enemy.connect("damaged", _on_enemy_damaged)
	if enemy.has_signal("reinforcement_called"):
		enemy.connect("reinforcement_called", _on_enemy_reinforcement_called)
	host.enemies.append(enemy)
	if assigned_squad_id >= 0 and enemy.has_method("assign_squad"):
		enemy.call("assign_squad", assigned_squad_id, assigned_squad_anchor, formation_offset)
	return enemy


func _on_enemy_died(enemy: CharacterBody3D) -> void:
	host.run_kills += 1
	GameState.raid_kills += 1
	# 죽인 만큼 도시가 반응한다. 조용히 지나갈수록 판이 길어진다.
	host._add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_KILL)
	host._advance_contract_progress("kills")
	host.extraction.update_banked_level_watch()
	if (
		is_instance_valid(host.active_field_mission)
		and int(enemy.get_meta("field_mission_id", -1))
		== int(host.active_field_mission.get_meta("mission_id", 0))
	):
		host.field_mission_kills += 1
	if bool(enemy.get_meta("raid_boss", false)):
		run_boss_kills += 1
		GameState.register_boss_defeat()
		# 보스전은 도시 전체가 듣는다. 처치 직후가 가장 위험해야 한다.
		host._add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_ALARM)
		host._play_boss_defeat_sequence(enemy)
		if GameState.subway_story_stage == 1:
			host._advance_basic_mission("subway_boss")
	if enemy == active_reinforcement_caller:
		active_reinforcement_caller = null
		sustained_combat_time = REINFORCEMENT_CALL_TRIGGER_TIME * 0.2
		concealed_combat_time = 0.0
	_spawn_enemy_loot(enemy)
	host.enemies.erase(enemy)
	host.reinforcement_timer = minf(host.reinforcement_timer, 2.5)


func _on_enemy_damaged(_enemy: CharacterBody3D, amount: int) -> void:
	host.run_damage_dealt += maxi(0, amount)
	# 예전 판정은 "한 발 피해 >= 20"이었다. MP5(18)와 샷건 펠릿(18)이 영원히
	# 걸리지 않아서, 한 방에 144를 넣는 샷건이 가장 밋밋했다. 같은 프레임에
	# 들어간 피해를 합산해서 본다.
	host.hit_stop_damage_accumulator += maxi(0, amount)
	# 문턱 45 / 쿨다운 0.35초. 예전 20/0.12는 AK 연사 거의 매 발에 걸려서,
	# 강조 연출이 아니라 프레임 드랍처럼 읽혔다. 히트스톱은 문장 부호다 —
	# 큰 한 방(샷건 일제사, 크리티컬 뭉치)에만 찍혀야 무게가 산다.
	if host.hit_stop_damage_accumulator >= 45 and host.combat_hit_stop_cooldown <= 0.0:
		host.combat_hit_stop_cooldown = 0.35
		host._trigger_hit_stop(0.06)


func _spawn_enemy_loot(enemy: CharacterBody3D) -> Node3D:
	var drop_position := enemy.global_position
	var enemy_weapon_id := str(enemy.get("weapon_id"))
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(host.raid_zone_data)
	if bool(enemy.get_meta("raid_boss", false)):
		var component_ids := ["rubber_gasket", "scope_lens", "magazine_spring"]
		var component_names := {
			"rubber_gasket": "소음기용 고무 패킹",
			"scope_lens": "스코프 렌즈",
			"magazine_spring": "탄창 스프링",
		}
		var component_id: String = component_ids[spawn_random.randi_range(0, component_ids.size() - 1)]
		var guaranteed_churu := 1
		var boss_drop: Node3D = host._create_loot_pickup(
			"churu",
			drop_position,
			{"amount": guaranteed_churu, "display_name": "보스 보상 츄르"}
		)
		host._create_loot_pickup(
			"mod_component",
			drop_position + Vector3(1.0, 0.0, 0.7),
			{
				"amount": 1,
				"component_id": component_id,
				"display_name": component_names[component_id],
			}
		)
		return boss_drop
	var definition: Dictionary = LOOT_ECONOMY.roll_enemy_drop(
		stage_tier,
		str(enemy.get("enemy_kind")),
		enemy_weapon_id,
		spawn_random,
		not host.has_ak
	)
	if definition.is_empty():
		return null
	if not LOOT_ECONOMY.try_register_loot(
		GameState,
		definition,
		"enemy",
		stage_tier
	):
		return null
	var data := (definition.get("data", {}) as Dictionary).duplicate(true)
	data["loot_source"] = "enemy"
	return host._create_loot_pickup(
		str(definition.get("type", "canned_food")),
		drop_position,
		data
	)


func _on_enemy_reinforcement_called(caller: CharacterBody3D) -> void:
	if caller != active_reinforcement_caller:
		return
	active_reinforcement_caller = null
	reinforcement_call_cooldown = REINFORCEMENT_CALL_COOLDOWN
	concealed_combat_time = 0.0
	_spawn_called_reinforcements()


func _update_reinforcement_call(delta: float, effective_threat: float) -> void:
	reinforcement_call_cooldown = maxf(0.0, reinforcement_call_cooldown - delta)
	if active_reinforcement_caller != null and not is_instance_valid(active_reinforcement_caller):
		active_reinforcement_caller = null
	elif active_reinforcement_caller != null and not bool(active_reinforcement_caller.get("reinforcement_call_active")):
		active_reinforcement_caller = null
		sustained_combat_time = REINFORCEMENT_CALL_TRIGGER_TIME * 0.2
		concealed_combat_time = 0.0
	var alerted_count := 0
	var visual_contact_count := 0
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if bool(enemy.get("alerted")):
			alerted_count += 1
			if bool(enemy.get("has_current_line_of_sight")):
				visual_contact_count += 1
	if visual_contact_count > 0:
		sustained_combat_time += delta
		concealed_combat_time = maxf(0.0, concealed_combat_time - delta * 2.0)
	elif alerted_count >= 2:
		concealed_combat_time += delta
		sustained_combat_time = maxf(0.0, sustained_combat_time - delta * 0.2)
	else:
		sustained_combat_time = maxf(0.0, sustained_combat_time - delta * 2.0)
		concealed_combat_time = maxf(0.0, concealed_combat_time - delta * 2.5)
	if active_reinforcement_caller != null or reinforcement_call_cooldown > 0.0:
		return
	var prolonged_firefight := sustained_combat_time >= REINFORCEMENT_CALL_TRIGGER_TIME
	var prolonged_standoff := concealed_combat_time >= REINFORCEMENT_HIDDEN_TRIGGER_TIME
	if not prolonged_firefight and not prolonged_standoff:
		return
	var caller: CharacterBody3D
	var best_score := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")) or not bool(enemy.get("alerted")):
			continue
		if str(enemy.get("enemy_kind")) == "melee":
			continue
		if not enemy.has_method("start_reinforcement_call"):
			continue
		var score: float = enemy.global_position.distance_to(player.global_position)
		if prolonged_standoff and bool(enemy.get("has_current_line_of_sight")):
			score += 18.0
		if score < best_score:
			best_score = score
			caller = enemy
	if caller != null and bool(caller.call("start_reinforcement_call", REINFORCEMENT_CALL_DURATION)):
		active_reinforcement_caller = caller
		sustained_combat_time = 0.0
		concealed_combat_time = 0.0


func _spawn_called_reinforcements() -> void:
	var stage_profile: Dictionary = LOOT_ECONOMY.get_stage_profile(
		LOOT_ECONOMY.get_stage_for_zone(host.raid_zone_data)
	)
	var remaining_kills := int(stage_profile.get("raid_kill_cap", 40)) - GameState.raid_kills
	if remaining_kills <= 0:
		return
	var effective_threat := clampf(maxf(0.58, host.night_intensity), 0.0, 1.0)
	var reinforcement_count := mini(
		6 + roundi(host.night_intensity * 4.0),
		remaining_kills
	)
	var world := host.get_node("World") as ProceduralCityMap
	var squad_sizes := _build_enemy_squad_sizes(reinforcement_count)
	var spawned_count := 0
	for squad_size in squad_sizes:
		var squad_anchor := _find_reinforcement_position()
		if squad_anchor == Vector3.INF:
			continue
		var kinds: Array[String] = []
		for member_index in squad_size:
			var enemy_index := spawned_count + member_index
			kinds.append(
				"grenadier"
				if enemy_index == reinforcement_count - 1
				else ("pistol" if enemy_index < reinforcement_count - 2 or spawn_random.randf() < 0.82 else "melee")
			)
		_spawn_enemy_squad(
			world,
			squad_anchor,
			kinds,
			effective_threat,
			player.global_position
		)
		spawned_count += squad_size


func _find_reinforcement_position() -> Vector3:
	var world := host.get_node("World") as ProceduralCityMap
	var map_limit := world.get_map_limit() - 4.0
	for attempt in 16:
		var angle := spawn_random.randf_range(0.0, TAU)
		var distance := spawn_random.randf_range(20.0, 34.0)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		requested.y = 0.78
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		if candidate.distance_to(player.global_position) < 17.0:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var overlaps_enemy := false
		for enemy in host.enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(candidate) < 2.2:
				overlaps_enemy = true
				break
		if not overlaps_enemy:
			return candidate
	return Vector3.INF


func _spawn_zone_boss(world: ProceduralCityMap, spawn_index: int, zone_threat: float) -> void:
	var boss_position := _find_distributed_enemy_position(world, spawn_index, spawn_index + 1)
	_spawn_rocket_boss_at(
		boss_position,
		maxf(0.5, zone_threat),
		"RaidBoss_%s" % GameState.selected_raid_zone
	)


func _spawn_rocket_boss_at(
	spawn_position: Vector3,
	boss_threat: float,
	boss_name: String
) -> CharacterBody3D:
	var boss := CharacterBody3D.new()
	boss.set_script(ROCKET_BOSS_SCRIPT)
	boss.position = spawn_position
	boss.call("configure_rocket_boss", player, clampf(boss_threat, 0.0, 1.0))
	host.add_child(boss)
	if is_instance_valid(host.scent_system):
		host.scent_system.call("register_mover", boss, "enemy")
	boss.died.connect(_on_enemy_died)
	if boss.has_signal("damaged"):
		boss.connect("damaged", _on_enemy_damaged)
	host.enemies.append(boss)
	boss.name = boss_name
	boss.set_meta("raid_boss", true)
	boss.set_meta("zone_id", GameState.selected_raid_zone)
	boss.set_meta("display_name", "로켓 약탈대장")
	var marker := Label3D.new()
	marker.name = "BossMarker"
	marker.text = "로켓 약탈대장"
	marker.position = Vector3(0.0, 3.55, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.render_priority = 127
	marker.font = FONT
	marker.font_size = 42
	marker.pixel_size = 0.005
	marker.modulate = Color("#f1c45d")
	marker.outline_modulate = Color(0.08, 0.02, 0.01, 0.95)
	marker.outline_size = 10
	boss.add_child(marker)
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("register_boss"):
		host.tactical_map.call("register_boss", boss)
	return boss


func _spawn_test_boss_near_player() -> void:
	if host.player_health <= 0 or host.extraction_transition_active:
		return
	var world := host.get_node("World") as ProceduralCityMap
	var forward: Vector3 = host._get_current_facing_world_direction()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var candidate_offsets := [
		forward * 11.0,
		(forward * 12.0 + side * 4.0),
		(forward * 12.0 - side * 4.0),
		forward * 15.0,
	]
	var spawn_position := Vector3.INF
	for offset in candidate_offsets:
		var candidate := world.find_nearest_physically_open_position(
			player.global_position + offset,
			1.05,
			[player.get_rid()]
		)
		candidate.y = 0.78
		if candidate.distance_to(player.global_position) < 7.0:
			continue
		var shape := SphereShape3D.new()
		shape.radius = 1.05
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0.0, 0.7, 0.0))
		query.collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		query.exclude = [player.get_rid()]
		if player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			spawn_position = candidate
			break
	if spawn_position == Vector3.INF:
		host._show_field_notice("보스 소환 실패 · 주변에 충분한 공간이 없습니다.")
		return
	var boss := _spawn_rocket_boss_at(
		spawn_position,
		maxf(0.75, host.night_intensity),
		"RaidBoss_Test_%d" % Time.get_ticks_msec()
	)
	if boss.has_method("receive_reinforcement_order"):
		boss.call("receive_reinforcement_order", player.global_position)
	host._show_field_notice("테스트 보스 출현 · 로켓 약탈대장이 접근합니다.")


func _trigger_fatigue_boss_event() -> void:
	if fatigue_boss_event_triggered or host.fatigue < FATIGUE_BOSS_TRIGGER:
		return
	var boss: CharacterBody3D
	for enemy in host.enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("raid_boss", false)):
			boss = enemy
			break
	if boss == null:
		var spawn_position := _find_reinforcement_position()
		if spawn_position == Vector3.INF:
			return
		boss = _spawn_rocket_boss_at(
			spawn_position,
			maxf(0.45, float(host.raid_zone_data.get("threat", 0.0))),
			"FatigueBoss_%d" % Time.get_ticks_msec()
		)
	var marker := boss.get_node_or_null("BossMarker") as Label3D
	if marker:
		marker.text = FATIGUE_BOSS_NAME
	boss.set_meta("display_name", FATIGUE_BOSS_NAME)
	fatigue_boss_event_triggered = true
	host._show_boss_alert(FATIGUE_BOSS_NAME)
	if GameState.subway_story_stage == 1:
		host._show_field_notice("연속 임무 갱신 · 포격 신호의 주인을 처치하십시오.")


func _find_event_position_near_player(
	world: ProceduralCityMap,
	minimum_distance: float,
	maximum_distance: float
) -> Vector3:
	var map_limit := world.get_map_limit() - 8.0
	var fallback: Vector3 = host._find_random_field_position(world, minimum_distance)
	for attempt in 48:
		var angle := TAU * float(attempt) / 48.0 + spawn_random.randf_range(-0.08, 0.08)
		var distance := spawn_random.randf_range(minimum_distance, maximum_distance)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		var player_distance := candidate.distance_to(player.global_position)
		if (
			player_distance >= minimum_distance
			and player_distance <= maximum_distance
			and not world.is_position_in_safe_zone(candidate)
		):
			return candidate
	return fallback
