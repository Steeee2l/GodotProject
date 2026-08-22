class_name EnemyDirector
extends RefCounted

# 적의 존재를 책임지는 모듈 — 분대 소환, 순찰 경로, 증원 호출, 보스 등장,
# 사망 처리와 전리품 드랍까지. main.gd에서 18개 함수를 옮겼다.
#
# raid의 다른 모듈들(jackpot/incidents/field_missions)이 전부 여기의
# 스폰 헬퍼를 쓴다. 적을 만드는 방법은 이 파일 하나만 안다.


const AIM_REVEAL_BUILDING_ALPHA := 0.28
const AK_DROP_TEXTURE := preload("res://assets/weapons/ak47_drop.png")
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
const RAID_ENTRY_ENEMY_SAFE_RADIUS := 30.0
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const REINFORCEMENT_CALL_COOLDOWN := 38.0
# 4.6초 → 8.0초. 예고 배너가 뜨는 순간부터 호출자를 찾아 접근하고 쏘아 죽이기까지
# 4.6초는 "보기도 전에 끝나는" 시간이었다 — 저지가 실력이 아니라 운이었다.
# 유저 요구: "게이지바로 충분한 시간을 주고, 그 안에 다 죽이면 증원이 안 오게".
const REINFORCEMENT_CALL_DURATION := 8.0
const REINFORCEMENT_CALL_TRIGGER_TIME := 30.0
# 저지 성공 보상 — 킬 하나(22 XP)보다 살짝 위. "안 싸우고 도망치는 것보다
# 지금 저 녀석을 잡는 게 이득"이라는 신호를 준다.
const REINFORCEMENT_BLOCK_XP := 25
const REINFORCEMENT_HIDDEN_TRIGGER_TIME := 14.0
# 전투 중 추가 유입 상한 — 동시에 교전(alerted) 중인 적이 이 수 이상이면
# 증원 호출·긴장도 대응 스쿼드·잭팟 웨이브의 추가 스폰을 건너뛰거나 미룬다.
# (유저: "싸우다 보면 적이 너무 많아져 감당이 안 된다") 판의 총 배치 수
# (BASE_ENEMY_COUNT)와 기존 쿨다운은 그대로다 — 문제는 '전투 중 유입'이다.
const MAX_CONCURRENT_ALERTED := 6
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
# 예고 배너가 화면에 떠 있는가. 저지 보상을 한 번만 주기 위한 단일 관문이기도 하다.
var reinforcement_call_banner_active := false
var run_boss_kills := 0
var run_elite_kills := 0
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
		# 장거리 도로 순찰이 진입 지점을 관통해 "시작하자마자 적" 체감을 만들었다
		# (실측: 가만히 서 있으면 30초 내 사망). 경로의 어떤 '구간'도 진입
		# 안전 반경을 스치지 않게 자르고, 남은 구간이 빈약하면 제자리 순찰로 강등.
		var road_route := world.get_long_road_patrol_route(origin, route_seed, [player.get_rid()])
		var entry_point := player.global_position
		var entry_safe := float(host.raid_zone_data.get(
			"entry_safe_radius", RAID_ENTRY_ENEMY_SAFE_RADIUS
		))
		var safe_prefix: Array[Vector3] = []
		for route_point in road_route:
			if not safe_prefix.is_empty():
				var segment_from := safe_prefix.back() as Vector3
				if _segment_distance_to_point_flat(segment_from, route_point, entry_point) < entry_safe:
					break
			elif Vector2(route_point.x - entry_point.x, route_point.z - entry_point.z).length() < entry_safe:
				break
			safe_prefix.append(route_point)
		if safe_prefix.size() >= 2:
			return safe_prefix
		patrol_mode = "route"
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


func _segment_distance_to_point_flat(from: Vector3, to: Vector3, point: Vector3) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(point.x, point.z)
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _spawn_enemy(
	kind: String,
	spawn_position: Vector3,
	threat: float,
	assigned_squad_id: int = -1,
	assigned_squad_anchor: Vector3 = Vector3.ZERO,
	formation_offset: Vector3 = Vector3.ZERO,
	forced_weapon_id: String = ""
) -> CharacterBody3D:
	# forced_weapon_id: 엘리트 스폰이 무장을 직접 고르기 위한 선택 인자.
	# 비우면 종전과 동일하게 위협도 기반으로 굴린다.
	var enemy_weapon_id := "baseball_bat"
	if kind != "melee":
		if not forced_weapon_id.is_empty():
			enemy_weapon_id = forced_weapon_id
		else:
			var roll := spawn_random.randf()
			if roll < lerpf(0.48, 0.22, threat):
				enemy_weapon_id = "m1911"
			elif roll < lerpf(0.82, 0.58, threat):
				enemy_weapon_id = "mp5"
			elif roll < lerpf(0.95, 0.88, threat):
				enemy_weapon_id = "ak47"
			else:
				enemy_weapon_id = "double_barrel"
			# 사다리 2단 무장 — 존3+(threat ≥ 0.5)부터 소총/산탄 칸의 일부를 상위
			# 기종으로 바꾼다(0.5→10%, 1.0→30%). 존 threat만 본다 — 러버밴딩 없음.
			# 들고 있던 총은 _enemy_carried_weapon_allowed 경로로 드랍된다(의도).
			# K2는 적 풀에 없다(용산 키 전용 제작).
			if threat >= 0.5 and spawn_random.randf() < lerpf(0.1, 0.3, (threat - 0.5) / 0.5):
				if enemy_weapon_id == "ak47":
					enemy_weapon_id = "akm"
				elif enemy_weapon_id == "double_barrel":
					enemy_weapon_id = "pump_shotgun"
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


# ── 엘리트 ──────────────────────────────────────────────────────
# "모든 적이 같은 값이라 싸울 이유가 있는 표적이 없다"에 대한 답.
# 판당 1~2명(존 티어 1~2 = 1명, 3+ = 2명), 초기 배치에 포함하되 진입 안전
# 반경 밖. 원거리 kind에 상위 무장을 확정으로 쥐여 주고, 처치 시 그 무기가
# 확정 드랍된다(_spawn_elite_loot). 스탯은 존 티어만 따른다 — 플레이어 장비
# 참조(러버밴딩) 금지. 전술 지도에는 안 올린다 — 필드에서 아이콘으로 발견한다.
const ELITE_DISPLAY_NAME := "약탈자 정예 · 무장 강탈자"


func get_initial_elite_count(stage_tier: int) -> int:
	return 1 if stage_tier <= 2 else 2


func spawn_initial_elites(world: ProceduralCityMap) -> void:
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(host.raid_zone_data)
	var elite_count := get_initial_elite_count(stage_tier)
	# 존 티어 위협만 사용 — 야간 보정(night_intensity)도 안 태운다.
	var zone_threat := clampf(float(host.raid_zone_data.get("threat", 0.0)), 0.0, 1.0)
	for elite_index in elite_count:
		var anchor := _find_distributed_enemy_position(world, elite_index + 1, elite_count + 1)
		anchor = _ensure_initial_enemy_safe_anchor(world, anchor, 91 + elite_index)
		# 상위 무장 확정 — 드랍이 보상의 핵심이라 M1911 엘리트는 성립하지 않는다.
		var weapon_roll := spawn_random.randf()
		var elite_weapon_id := "mp5"
		if weapon_roll >= 0.8:
			elite_weapon_id = "double_barrel"
		elif weapon_roll >= 0.45:
			elite_weapon_id = "ak47"
		# 존3+ 엘리트는 절반이 사다리 2단 무장 — 확정 드랍이 사다리를 올려 준다.
		if zone_threat >= 0.5 and spawn_random.randf() < 0.5:
			if elite_weapon_id == "ak47":
				elite_weapon_id = "akm"
			elif elite_weapon_id == "double_barrel":
				elite_weapon_id = "pump_shotgun"
		var elite := _spawn_enemy(
			"pistol",
			anchor,
			zone_threat,
			-1,
			Vector3.ZERO,
			Vector3.ZERO,
			elite_weapon_id
		)
		if elite.has_method("promote_to_elite"):
			elite.call("promote_to_elite", ELITE_DISPLAY_NAME)
		if elite.has_method("configure_patrol"):
			elite.call(
				"configure_patrol",
				"sentry",
				_build_enemy_patrol_route(world, anchor, 173 + elite_index * 7, "sentry")
			)


func _on_enemy_died(enemy: CharacterBody3D) -> void:
	host.run_kills += 1
	GameState.raid_kills += 1
	# 처치 확정 셰이크 — 타격 셰이크(0.12/0.16)보다 한 단계 굵게, 죽는
	# 순간이 손에 남게 한다. 엘리트는 더 크게. 보스는 전용 연출이 있으므로
	# 여기서 더 얹지 않는다. 접근성 배율은 main의 적용부에서 곱해진다.
	if not bool(enemy.get_meta("raid_boss", false)):
		var elite_kill := bool(enemy.get_meta("elite", false))
		host.camera_shake_time = maxf(host.camera_shake_time, 0.3 if elite_kill else 0.17)
		host.camera_shake_strength = maxf(
			host.camera_shake_strength, 0.4 if elite_kill else 0.26
		)
	# 처치 흡혈 — 공격이 곧 유지력이다. 방어구를 갖출수록 더 크게 돌아,
	# 장비가 갖춰진 판에서 "쓸어버리는" 궤도가 실제로 성립한다.
	if host.player_health > 0:
		var kill_heal := 3 + GameState.get_equipped_armor_piece_count()
		host.player_health = mini(GameState.get_max_health(), host.player_health + kill_heal)
		GameState.player_health = host.player_health
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
	if bool(enemy.get_meta("elite", false)):
		# 엘리트 처치 집계 — XP는 탈출 정산(extraction_flow)에서 일반 킬의
		# ~3배가 되도록 보너스를 더한다(킬 22 XP + 엘리트 보너스 44).
		run_elite_kills += 1
		if host.hud != null and host.hud.has_method("push_toast"):
			host.hud.push_toast("정예 처치! 확정 전리품이 떨어졌다", Color("#f2bd55"), 2.8)
	if bool(enemy.get_meta("raid_boss", false)):
		run_boss_kills += 1
		GameState.register_boss_defeat()
		# 보스전은 도시 전체가 듣는다. 처치 직후가 가장 위험해야 한다.
		host._add_raid_pressure(RAID_EVENT_DIRECTOR.PRESSURE_PER_ALARM)
		host._play_boss_defeat_sequence(enemy)
		if GameState.subway_story_stage == 1:
			host._advance_basic_mission("subway_boss")
	# 저지 성공 (a) — 무전을 잡은 녀석을 시간 안에 처치했다.
	if enemy == active_reinforcement_caller:
		_resolve_reinforcement_block()
	_spawn_enemy_loot(enemy)
	host.enemies.erase(enemy)
	# 예전엔 킬마다 보충 타이머를 2.5초로 당겼다 — 죽일수록 빨리 채워지는
	# 구조라 "소탕"이라는 행위 자체가 성립하지 않았다(유저 신고). 밀도 보충은
	# 킬과 무관하게 자기 주기로만 돈다.


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
		# 보스는 확정으로 장착 구경 탄약을 두 배 번들로 남긴다 — 보스전에서
		# 태운 탄창을 그 자리에서 갚아 "이겼는데 빈털터리"를 막는다.
		var boss_ammo: Dictionary = LOOT_ECONOMY.roll_matched_ammo_recovery(
			stage_tier, spawn_random
		)
		if not boss_ammo.is_empty():
			var boss_ammo_data := (boss_ammo.get("data", {}) as Dictionary).duplicate(true)
			boss_ammo_data["amount"] = int(boss_ammo_data.get("amount", 6)) * 2
			boss_ammo_data["loot_source"] = "enemy"
			host._create_loot_pickup(
				str(boss_ammo.get("type", "ammo")),
				drop_position + Vector3(-1.0, 0.0, 0.6),
				boss_ammo_data
			)
		return boss_drop
	if bool(enemy.get_meta("elite", false)):
		# 엘리트는 굴림이 아니라 확정 — 위험을 알고 골라 싸운 대가.
		return _spawn_elite_loot(enemy_weapon_id, stage_tier, drop_position)
	# 호환탄 회수 — 사수 시체는 60% 확률로 장착 구경 탄약을 별도로 남긴다.
	# 일반 드랍(방어구·식량·부품) 테이블과 독립이라 그쪽 비중은 안 건드린다.
	# 45%에서 올렸다: 킬당 회수량이 탄창 하나에도 못 미쳐 "쏠수록 가난해진다"는
	# 체감이 남았다(유저 신고). 탄약 제작이 폐지돼 필드 회수가 유일한 보급선이다.
	if str(enemy.get("enemy_kind")) != "melee" and spawn_random.randf() < 0.60:
		var ammo_recovery: Dictionary = LOOT_ECONOMY.roll_matched_ammo_recovery(
			stage_tier, spawn_random
		)
		if (
			not ammo_recovery.is_empty()
			and LOOT_ECONOMY.try_register_loot(GameState, ammo_recovery, "enemy", stage_tier)
		):
			var ammo_data := (ammo_recovery.get("data", {}) as Dictionary).duplicate(true)
			ammo_data["loot_source"] = "enemy"
			host._create_loot_pickup(
				str(ammo_recovery.get("type", "ammo")),
				drop_position + Vector3(-0.9, 0.0, 0.5),
				ammo_data
			)
	var enemy_kind := str(enemy.get("enemy_kind"))
	var definition: Dictionary = LOOT_ECONOMY.roll_enemy_drop(
		stage_tier,
		enemy_kind,
		enemy_weapon_id,
		spawn_random,
		not host.has_ak
	)
	var main_pickup: Node3D = null
	var main_type := ""
	if not definition.is_empty():
		if LOOT_ECONOMY.try_register_loot(GameState, definition, "enemy", stage_tier):
			main_type = str(definition.get("type", "canned_food"))
			var data := (definition.get("data", {}) as Dictionary).duplicate(true)
			data["loot_source"] = "enemy"
			main_pickup = host._create_loot_pickup(main_type, drop_position, data)
		elif str(definition.get("type", "")) == "weapon":
			# 무기 캡·가치 캡에 막힌 총은 조용히 사라지지 않는다 — 그 구경
			# 탄약으로 바꿔 지급한다. 판에 굴러다니는 총이 무한정 늘어나는 건
			# 막되, "죽였는데 아무것도 안 떨어졌다"는 체감은 남기지 않는다.
			main_pickup = _spawn_capped_weapon_ammo_substitute(
				enemy_weapon_id, stage_tier, drop_position
			)
	var dropped_weapon := main_type == "weapon"
	# 처치 보장 — 무기도 방어구도 안 나온 킬은 fallback 장비(무기 40%/방어구
	# 60%)를 확정으로 얹는다. "죽였는데 장비가 하나도 없다"를 없앤다(유저 요구).
	# 기존 굴림(식량·부품·탄약)은 그대로 두고 별도 픽업으로 스폰한다.
	if main_type not in ["weapon", "armor"]:
		var guaranteed: Dictionary = LOOT_ECONOMY.roll_guaranteed_equipment_drop(
			stage_tier, enemy_kind, enemy_weapon_id, spawn_random
		)
		if not guaranteed.is_empty():
			if not LOOT_ECONOMY.try_register_loot(GameState, guaranteed, "enemy", stage_tier):
				if (
					str(guaranteed.get("type", "")) == "weapon"
					and LOOT_ECONOMY.is_enemy_weapon_cap_reached(GameState, stage_tier)
				):
					# 판에 굴러다니는 총이 무한정 늘어나는 것만 막는다. '수' 상한에
					# 걸린 총은 그 구경 탄약으로 바꿔 지급한다 — 예전엔 여기서
					# 그냥 ignore_caps로 줘서 무기 캡 자체가 무의미했다.
					var substitute: Dictionary = LOOT_ECONOMY.roll_weapon_companion_ammo(
						enemy_weapon_id, stage_tier, spawn_random
					)
					guaranteed = (
						substitute
						if not substitute.is_empty()
						else LOOT_ECONOMY.roll_guaranteed_equipment_drop(
							stage_tier, "melee", "baseball_bat", spawn_random
						)
					)
				# 보장은 보장이다 — 가치 캡에 막혀도 집계만 하고 지급한다.
				LOOT_ECONOMY.try_register_loot(GameState, guaranteed, "enemy", stage_tier, true)
			var guaranteed_type := str(guaranteed.get("type", "armor"))
			var guaranteed_data := (guaranteed.get("data", {}) as Dictionary).duplicate(true)
			guaranteed_data["loot_source"] = "enemy"
			var guaranteed_pickup: Node3D = host._create_loot_pickup(
				guaranteed_type,
				drop_position + Vector3(0.9, 0.0, -0.5),
				guaranteed_data
			)
			dropped_weapon = dropped_weapon or guaranteed_type == "weapon"
			if main_pickup == null:
				main_pickup = guaranteed_pickup
	# 총이 떨어졌으면 그 구경 탄약을 정상 스택으로 100% 동반 — 주운 총을 그
	# 자리에서 장전해 써 볼 수 있어야 한다(유저 요구).
	if dropped_weapon:
		var companion_ammo: Dictionary = LOOT_ECONOMY.roll_weapon_companion_ammo(
			enemy_weapon_id, stage_tier, spawn_random
		)
		if not companion_ammo.is_empty():
			if not LOOT_ECONOMY.try_register_loot(GameState, companion_ammo, "enemy", stage_tier):
				LOOT_ECONOMY.try_register_loot(GameState, companion_ammo, "enemy", stage_tier, true)
			var companion_data := (companion_ammo.get("data", {}) as Dictionary).duplicate(true)
			companion_data["loot_source"] = "enemy"
			host._create_loot_pickup(
				str(companion_ammo.get("type", "ammo")),
				drop_position + Vector3(0.4, 0.0, 0.9),
				companion_data
			)
	return main_pickup


func _spawn_elite_loot(
	elite_weapon_id: String,
	stage_tier: int,
	drop_position: Vector3
) -> Node3D:
	# 엘리트 확정 드랍 3종 — ① 들고 있던 무기(희귀도 게이트 면제 경로)
	# ② 동반 탄약 2배 스택 ③ 고가치품(귀중품/부품) 1개.
	# 확정은 확정이다: 캡에 막혀도 집계만 하고 지급한다(처치 보장과 같은 원칙).
	var drops: Array[Dictionary] = LOOT_ECONOMY.roll_elite_drop(
		stage_tier, elite_weapon_id, spawn_random
	)
	var main_pickup: Node3D = null
	var drop_offsets := [
		Vector3.ZERO,
		Vector3(-0.9, 0.0, 0.6),
		Vector3(0.9, 0.0, -0.5),
	]
	for drop_index in drops.size():
		var definition: Dictionary = drops[drop_index]
		if definition.is_empty():
			continue
		if not LOOT_ECONOMY.try_register_loot(GameState, definition, "enemy", stage_tier):
			LOOT_ECONOMY.try_register_loot(GameState, definition, "enemy", stage_tier, true)
		var data := (definition.get("data", {}) as Dictionary).duplicate(true)
		data["loot_source"] = "enemy_elite"
		var pickup: Node3D = host._create_loot_pickup(
			str(definition.get("type", "canned_food")),
			drop_position + (drop_offsets[drop_index % drop_offsets.size()] as Vector3),
			data
		)
		if main_pickup == null:
			main_pickup = pickup
	return main_pickup


func _spawn_capped_weapon_ammo_substitute(
	enemy_weapon_id: String,
	stage_tier: int,
	drop_position: Vector3
) -> Node3D:
	# 캡에 막힌 무기 드랍의 대체 지급 — 총 대신 그 총의 탄약.
	var substitute: Dictionary = LOOT_ECONOMY.roll_weapon_companion_ammo(
		enemy_weapon_id, stage_tier, spawn_random
	)
	if substitute.is_empty():
		return null
	if not LOOT_ECONOMY.try_register_loot(GameState, substitute, "enemy", stage_tier):
		return null
	var substitute_data := (substitute.get("data", {}) as Dictionary).duplicate(true)
	substitute_data["loot_source"] = "enemy"
	return host._create_loot_pickup(
		str(substitute.get("type", "ammo")),
		drop_position,
		substitute_data
	)


func _on_enemy_reinforcement_called(caller: CharacterBody3D) -> void:
	if caller != active_reinforcement_caller:
		return
	active_reinforcement_caller = null
	reinforcement_call_cooldown = REINFORCEMENT_CALL_COOLDOWN
	concealed_combat_time = 0.0
	# 저지 실패 — 배너는 내리고 증원이 실제로 온다.
	_hide_reinforcement_call_banner()
	_spawn_called_reinforcements()


func _show_reinforcement_call_banner(duration: float) -> void:
	reinforcement_call_banner_active = true
	host._show_reinforcement_call_banner(duration)


func _hide_reinforcement_call_banner() -> void:
	if not reinforcement_call_banner_active:
		return
	reinforcement_call_banner_active = false
	host._hide_reinforcement_call_banner()


func _resolve_reinforcement_block() -> void:
	# 저지 성공. 배너를 내리고 초록 토스트 + XP로 "네가 막았다"를 확실히 말한다.
	# 배너가 떠 있을 때만 통과하므로 보상이 두 번 나갈 수 없다.
	if not reinforcement_call_banner_active:
		return
	_hide_reinforcement_call_banner()
	if is_instance_valid(active_reinforcement_caller):
		active_reinforcement_caller.call("_cancel_reinforcement_call")
	active_reinforcement_caller = null
	sustained_combat_time = 0.0
	concealed_combat_time = 0.0
	# 막아 놓고 3초 뒤에 옆 적이 또 무전을 잡으면 저지한 감각이 남지 않는다.
	reinforcement_call_cooldown = maxf(
		reinforcement_call_cooldown, REINFORCEMENT_CALL_COOLDOWN * 0.5
	)
	if host.hud != null and host.hud.has_method("push_toast"):
		host.hud.push_toast("증원 저지! +%d XP" % REINFORCEMENT_BLOCK_XP, Color("#7fc79e"), 2.6)
	GameState.add_raid_experience(REINFORCEMENT_BLOCK_XP)


func _update_reinforcement_call(delta: float, effective_threat: float) -> void:
	reinforcement_call_cooldown = maxf(0.0, reinforcement_call_cooldown - delta)
	if active_reinforcement_caller != null and not is_instance_valid(active_reinforcement_caller):
		active_reinforcement_caller = null
		_hide_reinforcement_call_banner()
	elif active_reinforcement_caller != null and not bool(active_reinforcement_caller.get("reinforcement_call_active")):
		# 피격 등으로 호출이 끊긴 경우. 배너만 내린다 — 저지 보상은 '처치'에만
		# 준다(스치는 한 발마다 XP가 나오면 보상이 의미를 잃는다).
		active_reinforcement_caller = null
		sustained_combat_time = REINFORCEMENT_CALL_TRIGGER_TIME * 0.2
		concealed_combat_time = 0.0
		_hide_reinforcement_call_banner()
	elif active_reinforcement_caller != null:
		# 진행 중 — 남은 시간을 배너 게이지에 그대로 흘려보낸다.
		host._update_reinforcement_call_banner(
			float(active_reinforcement_caller.get("reinforcement_call_duration"))
			- float(active_reinforcement_caller.get("reinforcement_call_elapsed"))
		)
	var alerted_count := 0
	var visual_contact_count := 0
	var elite_alerted := false
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if bool(enemy.get("alerted")):
			alerted_count += 1
			if bool(enemy.get_meta("elite", false)):
				elite_alerted = true
			if bool(enemy.get("has_current_line_of_sight")):
				visual_contact_count += 1
	# 저지 성공 (b): 호출이 진행 중인데 교전 중인 적이 하나도 안 남았다 =
	# 제한 시간 안에 그 무리를 전부 정리했다. 호출자만 콕 집어 죽이지 않아도
	# "다 죽이면 증원이 안 온다"가 성립해야 한다(유저 요구).
	if reinforcement_call_banner_active and alerted_count <= 0:
		_resolve_reinforcement_block()
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
	# 이미 상한까지 교전 중이면 증원 호출 자체를 미룬다(타이머는 유지되므로,
	# 수가 줄면 그때 호출이 성립한다).
	if alerted_count >= MAX_CONCURRENT_ALERTED:
		return
	# 엘리트가 교전 중이면 호출 시도가 30% 빨라진다 — "저 녀석을 빨리 잡아야
	# 한다"는 위협 정체성. 동시 교전 상한(MAX_CONCURRENT_ALERTED)·쿨다운·
	# 상시 보충 게이트는 건드리지 않는다.
	var trigger_scale := 0.7 if elite_alerted else 1.0
	var prolonged_firefight := sustained_combat_time >= REINFORCEMENT_CALL_TRIGGER_TIME * trigger_scale
	var prolonged_standoff := concealed_combat_time >= REINFORCEMENT_HIDDEN_TRIGGER_TIME * trigger_scale
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
		# 엘리트가 무전을 우선 잡는다 — 저지 목표가 자연스럽게 엘리트가 된다.
		if bool(enemy.get_meta("elite", false)):
			score -= 60.0
		if prolonged_standoff and bool(enemy.get("has_current_line_of_sight")):
			score += 18.0
		if score < best_score:
			best_score = score
			caller = enemy
	if caller != null and bool(caller.call("start_reinforcement_call", REINFORCEMENT_CALL_DURATION)):
		active_reinforcement_caller = caller
		sustained_combat_time = 0.0
		concealed_combat_time = 0.0
		_show_reinforcement_call_banner(REINFORCEMENT_CALL_DURATION)


func count_alerted_enemies() -> int:
	# 지금 '전투에 참여 중'인 적 수. 전투 중 추가 스폰 게이트의 단일 기준.
	var count := 0
	for enemy in host.enemies:
		if (
			is_instance_valid(enemy)
			and not bool(enemy.get("dying"))
			and bool(enemy.get("alerted"))
		):
			count += 1
	return count


func _spawn_called_reinforcements() -> void:
	var stage_profile: Dictionary = LOOT_ECONOMY.get_stage_profile(
		LOOT_ECONOMY.get_stage_for_zone(host.raid_zone_data)
	)
	var remaining_kills := int(stage_profile.get("raid_kill_cap", 40)) - GameState.raid_kills
	if remaining_kills <= 0:
		return
	var effective_threat := clampf(maxf(0.58, host.night_intensity), 0.0, 1.0)
	# 증원 규모는 교전 상한의 남은 자리만큼만 — 예전 6~10명 고정 유입이
	# "무한 누적" 체감의 최대 원인이었다.
	var reinforcement_budget := MAX_CONCURRENT_ALERTED - count_alerted_enemies()
	if reinforcement_budget <= 0:
		return
	var reinforcement_count := mini(
		mini(6 + roundi(host.night_intensity * 4.0), reinforcement_budget),
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


func _find_reinforcement_position(minimum_distance: float = 0.0) -> Vector3:
	# minimum_distance를 주면 그 거리 '밖'에서만 자리를 찾는다. 상시 밀도 보충은
	# 플레이어 구역 바깥에만 떨어져야 하고(소탕한 곳은 조용해야 한다), 무전 호출
	# 증원은 예전처럼 가까이 와야 저지 실패가 압박으로 읽힌다 — 그래서 인자로 뺐다.
	var world := host.get_node("World") as ProceduralCityMap
	var map_limit := world.get_map_limit() - 4.0
	var near_distance := maxf(20.0, minimum_distance)
	var far_distance := maxf(34.0, minimum_distance + 26.0)
	var reject_distance := maxf(17.0, minimum_distance)
	for attempt in 16:
		var angle := spawn_random.randf_range(0.0, TAU)
		var distance := spawn_random.randf_range(near_distance, far_distance)
		var requested := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		requested.x = clampf(requested.x, -map_limit, map_limit)
		requested.z = clampf(requested.z, -map_limit, map_limit)
		requested.y = 0.78
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.62,
			[player.get_rid()]
		)
		if candidate.distance_to(player.global_position) < reject_distance:
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
		host._show_field_notice("연속 임무 갱신 · 포격 신호의 주인을 잡는다")


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
