class_name CompanionSystem
extends RefCounted

# 주홍 동행 — 코옵 느낌의 AI 아군(host 패턴, main.gd가 attach/update를 부른다).
#
# 구조:
#   CompanionSystem(이 파일) — 소환/해제, 적 어그로 배분(60/40), 플레이어 다운·소생
#                              오케스트레이션, HUD 칩 갱신, 스쿼드 소탕·탈출 바크.
#   JuhongBody(내부 클래스)  — 필드 AI 본체. 리시 추종(지연 lerp)·교전 거리 유지·
#                              스트레이프·엄폐 v2 편승·더블배럴 사격·바크·다운/소생.
#
# 규칙(스펙 고정):
#   이동   — 전투 밖 2.2m 뒤따름 / 전투 중 리시 11m 안에서 표적과 4~9m 유지, 스트레이프.
#            플레이어와 16m 이상 벌어지면 교전 포기·복귀. 2.5s 끼임이면 연막 재배치.
#   전투   — 더블배럴: 사거리 12m(유지 밴드 4~9m를 전부 덮는다 — 예전엔 사거리 7m가
#            밴드보다 짧아 7~9m '못 쏘는 구간'에 갇혔다), 2연발 후 재장전 2.2s, 발당 26.
#            LOS 필수 — 몸높이 레이가 막히면 엄폐 중일 때 머리 높이로 내밀어 쏜다.
#            표적 우선순위 ①플레이어를 공격 중인 적 ②자신을 공격하는 적 ③최근접.
#            아군 오사 없음(bullet_projectile이 동행 탄↔플레이어를 통과시킨다).
#   엄폐   — CoverSystem.evaluate_cover_for 공유. 엄폐물 1.2u 이내 covered(웅크림+
#            청록 호), 사격 시 내밈. covered 중 그 엄폐물을 지나오는 총알 차단.
#   은신   — 경보 전(alerted 적 없음)엔 사격 금지, 플레이어 식빵 자세를 따라 웅크림.
#   소생   — 주홍 다운: 45s 출혈, [F] 홀드 3s → HP 40%. 횟수 제한 없음(제한을 두면
#            칩은 "일으켜라"인데 실제론 안 살려지는 모순이 생겼다 — 유저 신고).
#            45s를 넘기면 이탈 → 무전기 루프. 플레이어 다운: 30s, 주홍이 달려와
#            4s 채널 → HP 40% — 이쪽만 판당 1회(안전망은 한 번).

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const COVER_SYSTEM := preload("res://scripts/raid/cover_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const BARK_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SPEECH_BUBBLE := preload("res://scripts/raid/speech_bubble.gd")

const JUHONG_ANIMATION_ROOT := "res://assets/characters/juhong"
const JUHONG_PORTRAIT_PATH := "res://assets/characters/juhong/down_idle-frame-0.png"
const JUHONG_ACCENT := Color("#41e0c9")

# 어그로 — 경보 적의 표적 선택에 주홍 포함: 적당 1회 40% 확률로 주홍을 문다.
# enemy.gd는 손대지 않는다(set_combat_target 공개 API만 사용).
const AGGRO_ROLL_INTERVAL := 1.5
const AGGRO_JUHONG_WEIGHT := 0.4
const AGGRO_ROLL_META := "juhong_aggro_rolled"
const AGGRO_MAX_DISTANCE := 18.0

const PLAYER_DOWN_SECONDS := 30.0
const PLAYER_REVIVE_CHANNEL_SECONDS := 4.0
const PLAYER_REVIVE_REACH := 1.7
const REVIVE_HEALTH_RATIO := 0.4
const JUHONG_BLEED_SECONDS := 45.0
const JUHONG_REVIVE_HOLD_SECONDS := 3.0
# 스펙 1.5m는 수평 기준 — 판정(distance_to)은 플레이어 y(0.78)와 지점 y(0.08)의
# 0.7 차이까지 먹는 3D 거리라 그만큼 보정한다(수평 실효 ≈ 1.5m).
const JUHONG_REVIVE_DISTANCE := 1.9
const RADIO_HOLD_SECONDS := 2.5
const EXTRACTION_BARK_DISTANCE := 5.5
const DOWN_SATURATION := 0.26

var host: Node
var juhong: JuhongBody

# 플레이어 소생만 판당 1회 — 주홍 소생은 무제한(45s 안에 [F]만 하면 된다).
var player_revive_used := false

# 플레이어 다운 상태(사망 시퀀스 대신 들어오는 30초의 기회).
var player_downed := false
var player_down_remaining := 0.0
var player_revive_channel_remaining := 0.0
# 프로브가 채널을 줄일 수 있게 상수 대신 변수로 둔다.
var player_down_seconds := PLAYER_DOWN_SECONDS
var player_revive_channel_seconds := PLAYER_REVIVE_CHANNEL_SECONDS

var aggro_timer := 0.0
var extraction_bark_done := false
var had_alerted_combat := false
# 전투 후 회수 — 최근 처치 지점(스쿼드 하나 분량만 기억한다).
var loot_spots: Array[Vector3] = []
var revive_point: Node3D
var radio_point: Node3D
var radio_grave: Node3D
var radio_indicator: EdgeIndicator
var player_rip_marker: Node3D
# 다운 연출 원복용 — WorldEnvironment 리소스는 캐시가 공유되므로 반드시 되돌린다.
var _saved_adjustment_enabled := false
var _saved_saturation := 1.0
var _down_visual_active := false


func attach(owner_node: Node) -> void:
	host = owner_node


func spawn_if_active() -> void:
	# 필드(main.tscn) 전용 v1 — 오프닝·건물 내부는 동행 제외.
	if juhong != null and is_instance_valid(juhong):
		return
	if not GameState.opening_completed:
		return
	if not GameState.is_companion_raid_active():
		return
	# 무전기 루프 — 지난 판에서 무전기를 못 찾고 나왔으면 그만큼의 출정 동안
	# 부재. 다 깎이면 쉘터 복귀 인사(radio_return)가 걸릴 때까지도 없다.
	if GameState.juhong_radio_return_pending:
		return
	if GameState.juhong_absent_runs > 0:
		GameState.juhong_absent_runs -= 1
		if GameState.juhong_absent_runs <= 0:
			GameState.juhong_radio_return_pending = true
		return
	juhong = JuhongBody.new()
	juhong.system = self
	juhong.host = host
	host.add_child(juhong)
	# 첫 동행 판이면 옆이 아니라 조금 떨어진 곳에서 걸어와 붙는다(합류 서사 연결).
	var first_field_run: bool = not GameState.juhong_field_intro_seen
	var spawn_offset := Vector3(-5.5, 0.0, 4.5) if first_field_run else Vector3(-1.4, 0.0, 1.1)
	var spawn_origin: Vector3 = host.player.global_position + spawn_offset
	var world: Node = host.get_node("World")
	if world != null and world.has_method("find_nearest_physically_open_position"):
		spawn_origin = world.call(
			"find_nearest_physically_open_position", spawn_origin, 0.58, [host.player.get_rid()]
		)
	juhong.global_position = Vector3(spawn_origin.x, 0.78, spawn_origin.z)
	if host.get("hud") != null and host.hud.has_method("build_companion_chip"):
		host.hud.build_companion_chip(load(JUHONG_PORTRAIT_PATH) as Texture2D)
	if first_field_run:
		GameState.juhong_field_intro_seen = true
		_play_field_intro()


func _play_field_intro() -> void:
	# 쉘터 합류("다음 출정부터 나도 간다")를 필드에서 받아 주는 첫 마디 —
	# 이게 없으면 아무 설명 없이 옆에 서 있는 낯선 아군이 된다(유저 지적).
	if not is_juhong_alive():
		return
	juhong.bark("나야. 다음 출정부터 같이 간다고 했잖아.")
	if host.get("hud") != null and host.hud.has_method("push_toast"):
		host.hud.push_toast(
			"주홍 동행. 한쪽이 쓰러지면 다른 쪽이 일으킬 수 있다. (판당 각 1회)",
			JUHONG_ACCENT,
			4.4
		)
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.create_timer(4.6).timeout.connect(func() -> void:
			if is_juhong_alive():
				juhong.bark("앞장 서. 네 뒤는 내가 봐 줄게. 공짜는 아니야.")
		)


func is_active() -> bool:
	return juhong != null and is_instance_valid(juhong) and not juhong.retreated


func is_juhong_alive() -> bool:
	return is_active() and not juhong.downed


func is_player_downed() -> bool:
	return player_downed


func update(delta: float) -> void:
	if host == null:
		return
	_update_player_down(delta)
	# 무전기 방향 인디케이터 — 주홍이 이탈한 동안(is_active false)에만 살아 있다.
	_update_radio_indicator()
	if not is_active():
		_refresh_hud_chip()
		return
	aggro_timer -= delta
	if aggro_timer <= 0.0:
		aggro_timer = AGGRO_ROLL_INTERVAL
		_roll_enemy_aggro()
	_track_kill_spots()
	_update_squad_clear_bark()
	_update_extraction_bark()
	_refresh_hud_chip()


func _track_kill_spots() -> void:
	# 죽는 적의 자리를 기억해 둔다 — 전투가 끝나면 주홍이 돌며 회수한다.
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or not bool(enemy.get("dying")):
			continue
		if enemy.has_meta("juhong_loot_scanned"):
			continue
		enemy.set_meta("juhong_loot_scanned", true)
		if loot_spots.size() < 3:
			loot_spots.append((enemy as Node3D).global_position)


# ── 적 어그로 배분(플레이어 60% / 주홍 40%) ─────────────────────────

func _roll_enemy_aggro() -> void:
	if not is_juhong_alive():
		return
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if not bool(enemy.get("alerted")):
			continue
		if enemy.has_meta(AGGRO_ROLL_META):
			continue
		if not enemy.has_method("is_targeting_player") or not bool(enemy.call("is_targeting_player")):
			continue
		var distance: float = (enemy as Node3D).global_position.distance_to(juhong.global_position)
		if distance > AGGRO_MAX_DISTANCE:
			continue
		enemy.set_meta(AGGRO_ROLL_META, true)
		if randf() < AGGRO_JUHONG_WEIGHT and enemy.has_method("set_combat_target"):
			enemy.call("set_combat_target", juhong)


func _release_enemy_aggro_from_juhong() -> void:
	# 주홍 다운/이탈 — 주홍을 물던 적을 플레이어에게 되돌린다(다운 표적 제외 규칙).
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		enemy.remove_meta(AGGRO_ROLL_META)
		if enemy.get("target") == juhong and enemy.has_method("set_combat_target"):
			enemy.call("set_combat_target", host.player)


func any_enemy_alerted() -> bool:
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if is_instance_valid(enemy) and not bool(enemy.get("dying")) and bool(enemy.get("alerted")):
			return true
	return false


func _update_squad_clear_bark() -> void:
	var engaged := any_enemy_alerted()
	if engaged:
		had_alerted_combat = true
	elif had_alerted_combat:
		had_alerted_combat = false
		if is_juhong_alive():
			juhong.bark("조용해졌네. 다 정리된 것 같아.")


func _update_extraction_bark() -> void:
	if extraction_bark_done or not is_juhong_alive():
		return
	var sites: Array = host.get("extraction_sites") if host.get("extraction_sites") != null else []
	for site in sites:
		if not is_instance_valid(site):
			continue
		if host.player.global_position.distance_to((site as Node3D).global_position) <= EXTRACTION_BARK_DISTANCE:
			extraction_bark_done = true
			juhong.bark("먼저 나가. 뒤는 내가 막을게.")
			return


# ── 주홍 다운 → [F] 소생 ─────────────────────────────────────────────

func on_juhong_down() -> void:
	_release_enemy_aggro_from_juhong()
	if host.get("hud") != null and host.hud.has_method("push_toast"):
		host.hud.push_toast("주홍이 쓰러졌다. %.0f초 안에 [F]로 일으킨다" % juhong.down_remaining, HudStyle.DANGER, 3.2)
	# 기존 상호작용 캡슐+링 게이지 문법을 그대로 태운다(main이 홀드·완료를 처리).
	revive_point = host._create_field_interaction(
		"companion_revive",
		juhong.global_position,
		"주홍",
		JUHONG_REVIVE_HOLD_SECONDS
	)
	revive_point.set_meta("interaction_distance", JUHONG_REVIVE_DISTANCE)


func finish_juhong_revive() -> void:
	# main._complete_field_interaction("companion_revive")가 부른다.
	if not is_active() or not juhong.downed:
		return
	_clear_revive_point()
	juhong.revive()


func on_juhong_retreated() -> void:
	_clear_revive_point()
	_release_enemy_aggro_from_juhong()
	if player_downed:
		# 구조자가 사라졌다 — 남은 시간과 무관하게 기존 사망 흐름으로.
		_fail_player_down()
	# 무전기 루프 — 출혈사는 공짜가 아니다. 쓰러진 자리에 무전기가 남는다:
	# 이 판에서 회수하면 즉시 복귀, 못 하면 3출정 부재 후 쉘터로 스스로 온다.
	GameState.juhong_absent_runs = 3
	GameState.juhong_radio_loss_count += 1
	if juhong != null and is_instance_valid(juhong):
		_drop_radio(juhong.global_position)
	if host.get("hud") != null and host.hud.has_method("push_toast"):
		host.hud.push_toast(
			"주홍이 빠져나갔다. 쓰러진 자리에 무전기가 남았다. 무전기를 주우면 주홍이 돌아온다",
			HudStyle.WARN,
			3.6
		)


func _drop_radio(world_position: Vector3) -> void:
	if radio_point != null and is_instance_valid(radio_point):
		return
	radio_point = host._create_field_interaction(
		"companion_radio",
		world_position,
		"주홍의 무전기",
		RADIO_HOLD_SECONDS
	)
	radio_point.set_meta("interaction_distance", JUHONG_REVIVE_DISTANCE)
	# 이탈 지점의 십자가 — 주홍 노드는 통째로 숨었으니 독립 마커로 세운다.
	radio_grave = CompanionSystem.build_rip_marker("주홍", JUHONG_ACCENT, CompanionSystem.JUHONG_PORTRAIT_TEXTURE)
	host.add_child(radio_grave)
	radio_grave.global_position = Vector3(world_position.x, 0.78, world_position.z)


func finish_radio_recall() -> void:
	# main._complete_field_interaction("companion_radio")가 부른다 — 부재를 지우고
	# 연막에서 걸어 나온다. 판당 소생 사용 여부는 그대로다(부활이 소생을 되돌리진 않는다).
	GameState.juhong_absent_runs = 0
	GameState.juhong_radio_return_pending = false
	_clear_radio_point()
	if juhong == null or not is_instance_valid(juhong):
		return
	var recall_origin: Vector3 = host.player.global_position + Vector3(2.4, 0.0, -1.8)
	var world: Node = host.get_node_or_null("World")
	if world != null and world.has_method("find_nearest_physically_open_position"):
		recall_origin = world.call(
			"find_nearest_physically_open_position", recall_origin, 0.58, [host.player.get_rid()]
		)
	juhong.return_from_retreat(recall_origin)


func _clear_radio_point() -> void:
	if radio_point != null and is_instance_valid(radio_point):
		if host.get("field_interactions") != null:
			host.field_interactions.erase(radio_point)
		radio_point.queue_free()
	radio_point = null
	if radio_grave != null and is_instance_valid(radio_grave):
		radio_grave.queue_free()
	radio_grave = null


func _clear_revive_point() -> void:
	if revive_point != null and is_instance_valid(revive_point):
		if host.get("field_interactions") != null:
			host.field_interactions.erase(revive_point)
		revive_point.queue_free()
	revive_point = null


# ── 플레이어 다운 → 주홍 소생(코옵의 심장) ──────────────────────────

func try_begin_player_down() -> bool:
	# main.take_damage의 사망 진입 지점에서 딱 한 곳 분기한다.
	# 조건: 주홍 생존 + 이번 판 아직 플레이어 소생을 안 씀.
	if player_downed or player_revive_used:
		return false
	if not is_juhong_alive():
		return false
	player_downed = true
	player_revive_used = true
	player_down_remaining = player_down_seconds
	player_revive_channel_remaining = player_revive_channel_seconds
	_apply_down_visuals()
	# 적을 주홍 쪽으로 돌린다 — "전투를 정리하며 달려온다"의 실체.
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if bool(enemy.get("alerted")) and enemy.has_method("is_targeting_player") \
				and bool(enemy.call("is_targeting_player")) and enemy.has_method("set_combat_target"):
			enemy.call("set_combat_target", juhong)
	juhong.begin_rescue()
	return true


func _update_player_down(delta: float) -> void:
	if not player_downed:
		return
	player_down_remaining -= delta
	if not is_juhong_alive():
		_fail_player_down()
		return
	if player_down_remaining <= 0.0:
		_fail_player_down()
		return
	# 채널 — 주홍이 닿아 있는 동안만 찬다(끊겨도 진행은 남는다).
	var in_reach: bool = juhong.global_position.distance_to(host.player.global_position) <= PLAYER_REVIVE_REACH
	if in_reach:
		juhong.channeling_revive = true
		player_revive_channel_remaining = maxf(0.0, player_revive_channel_remaining - delta)
		if player_revive_channel_remaining <= 0.0:
			_complete_player_revive()
			return
	else:
		juhong.channeling_revive = false
	_update_down_gauge(in_reach)


func _update_down_gauge(channeling: bool) -> void:
	if host.get("hud") == null or not host.hud.has_method("update_companion_revive_gauge"):
		return
	var camera: Camera3D = host.get("camera")
	if camera == null:
		return
	var anchor: Vector2 = camera.unproject_position(host.player.global_position + Vector3(0, 2.35, 0))
	var ratio: float = 1.0 - clampf(player_revive_channel_remaining / maxf(0.05, player_revive_channel_seconds), 0.0, 1.0)
	host.hud.update_companion_revive_gauge(
		true,
		anchor,
		ratio,
		"주홍 소생 중" if channeling else "주홍 접근 중 · %.0f초" % maxf(0.0, player_down_remaining)
	)


func _complete_player_revive() -> void:
	player_downed = false
	juhong.channeling_revive = false
	juhong.state = "follow"
	_restore_down_visuals()
	var restored := maxi(1, roundi(float(GameState.get_max_health()) * REVIVE_HEALTH_RATIO))
	host.player_health = restored
	GameState.player_health = restored
	var health_bar: ProgressBar = host.get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
	if health_bar:
		health_bar.value = restored
	if host.get("hud") != null:
		if host.hud.has_method("reset_player_health_trail"):
			host.hud.reset_player_health_trail(
				clampf(float(restored) / float(GameState.get_max_health()), 0.0, 1.0)
			)
		if host.hud.has_method("update_companion_revive_gauge"):
			host.hud.update_companion_revive_gauge(false, Vector2.ZERO, 0.0, "")
	juhong.bark("일어나. 아직 안 끝났어. 이건 빚 하나야.")
	SFX.play("cover_enter")


func _fail_player_down() -> void:
	# 30s 초과 또는 주홍 부재/다운 — 기존 사망 흐름 그대로(페널티·시체 로직 무변경).
	if not player_downed:
		return
	player_downed = false
	if is_active():
		juhong.channeling_revive = false
		if juhong.state == "rescue":
			juhong.state = "follow"
	_restore_down_visuals()
	if host.get("hud") != null and host.hud.has_method("update_companion_revive_gauge"):
		host.hud.update_companion_revive_gauge(false, Vector2.ZERO, 0.0, "")
	host._begin_player_death_sequence()


func _apply_down_visuals() -> void:
	# 화면 데세츄레이션 + 출혈 비네트. 사망 시퀀스가 아니라 "아직 기회가 있다"의 색.
	_down_visual_active = true
	var environment_node: WorldEnvironment = host.get("world_environment")
	if environment_node != null and environment_node.environment != null:
		var env := environment_node.environment
		_saved_adjustment_enabled = env.adjustment_enabled
		_saved_saturation = env.adjustment_saturation
		env.adjustment_enabled = true
		env.adjustment_saturation = DOWN_SATURATION
	if host.get("hud") != null and host.hud.get("damage_vignette_material") != null:
		host.hud.damage_vignette_material.set_shader_parameter("intensity", 0.85)
	# 다운 = RIP 십자가 + 이름(유저 확정: 쓰러진 스프라이트 말고 십자가).
	var survivor: AnimatedSprite3D = host.get("survivor")
	if survivor != null:
		survivor.visible = false
	var weapon_sprite = host.get("weapon_sprite")
	if weapon_sprite != null and weapon_sprite is Node3D:
		(weapon_sprite as Node3D).visible = false
	_set_player_rip(true)
	if host.get("state_label") != null:
		host.state_label.text = "행동 불능. 주홍이 오고 있다"


func _restore_down_visuals() -> void:
	if not _down_visual_active:
		return
	_down_visual_active = false
	var environment_node: WorldEnvironment = host.get("world_environment")
	if environment_node != null and environment_node.environment != null:
		var env := environment_node.environment
		env.adjustment_saturation = _saved_saturation
		env.adjustment_enabled = _saved_adjustment_enabled
	if host.get("hud") != null and host.hud.get("damage_vignette_material") != null:
		host.hud.damage_vignette_material.set_shader_parameter("intensity", 0.0)
	var survivor: AnimatedSprite3D = host.get("survivor")
	if survivor != null:
		survivor.visible = true
		survivor.modulate = Color.WHITE
		survivor.rotation.z = 0.0
		survivor.position.y = 0.3
		survivor.scale = Vector3.ONE
	var weapon_sprite = host.get("weapon_sprite")
	if weapon_sprite != null and weapon_sprite is Node3D:
		# 표시 여부는 다음 프레임의 update_weapon_reveal(조준 시에만)이 다시 정한다.
		(weapon_sprite as Node3D).visible = true
	_set_player_rip(false)


# ── RIP 마커 — 다운/이탈 지점의 십자가+이름(쓰러진 스프라이트 대신) ──

static var _rip_cross_texture: Texture2D


static func get_rip_cross_texture() -> Texture2D:
	if _rip_cross_texture != null:
		return _rip_cross_texture
	var image := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color(0.09, 0.08, 0.07, 0.96)
	var wood := Color(0.55, 0.5, 0.44, 1.0)
	var wood_light := Color(0.66, 0.61, 0.54, 1.0)
	# 판자 십자가 — 외곽 2px 테두리 + 좌/상단 하이라이트.
	image.fill_rect(Rect2i(17, 4, 14, 54), outline)
	image.fill_rect(Rect2i(5, 16, 38, 14), outline)
	image.fill_rect(Rect2i(19, 6, 10, 50), wood)
	image.fill_rect(Rect2i(7, 18, 34, 10), wood)
	image.fill_rect(Rect2i(19, 6, 3, 50), wood_light)
	image.fill_rect(Rect2i(7, 18, 34, 3), wood_light)
	# 흙무덤.
	image.fill_rect(Rect2i(10, 58, 28, 4), Color(0.24, 0.2, 0.16, 0.9))
	image.fill_rect(Rect2i(14, 56, 20, 2), Color(0.3, 0.25, 0.2, 0.9))
	_rip_cross_texture = ImageTexture.create_from_image(image)
	return _rip_cross_texture


const PLAYER_PORTRAIT_TEXTURE := preload("res://assets/characters/cat_8way/down_idle_0.png")
const JUHONG_PORTRAIT_TEXTURE := preload("res://assets/characters/juhong/down_idle-frame-0.png")
# 256 전신 프레임에서 귀 끝~가슴 정사각.
const PORTRAIT_BUST_REGION := Rect2i(48, 22, 160, 160)
const PORTRAIT_PIXELS := 96
static var _circle_portrait_cache: Dictionary = {}


static func build_circle_portrait_texture(texture: Texture2D, accent: Color) -> ImageTexture:
	# 상반신을 잘라 원형으로 마스킹하고 가장자리에 2px 테두리(accent)를 두른다.
	var cache_key := "%s|%s" % [texture.resource_path, accent.to_html(false)]
	if _circle_portrait_cache.has(cache_key):
		return _circle_portrait_cache[cache_key]
	var source := texture.get_image()
	if source == null:
		return null
	if source.is_compressed():
		source.decompress()
	var bust := source.get_region(PORTRAIT_BUST_REGION)
	bust.resize(PORTRAIT_PIXELS, PORTRAIT_PIXELS, Image.INTERPOLATE_NEAREST)
	if bust.get_format() != Image.FORMAT_RGBA8:
		bust.convert(Image.FORMAT_RGBA8)
	var center := float(PORTRAIT_PIXELS) * 0.5
	var radius := center - 1.0
	var ring := 2.5
	var background := Color(0.06, 0.08, 0.085, 1.0)
	for y in PORTRAIT_PIXELS:
		for x in PORTRAIT_PIXELS:
			var distance := Vector2(float(x) + 0.5 - center, float(y) + 0.5 - center).length()
			var pixel := bust.get_pixel(x, y)
			if pixel.a < 0.5:
				pixel = background
			if distance > radius:
				pixel.a = 0.0
			elif distance > radius - ring:
				pixel = accent
			bust.set_pixel(x, y, pixel)
	var result := ImageTexture.create_from_image(bust)
	_circle_portrait_cache[cache_key] = result
	return result


static func build_rip_marker(name_text: String, accent: Color, portrait: Texture2D = null) -> Node3D:
	# 배치 규약: 액터 원점(지면 +0.78)에 붙인다 — 십자가가 발치에 서고 이름이 위에,
	# 그 위에 둥근 초상화(2026-09-03 유저: "십자가 위에 초상화 동그랗게").
	var marker := Node3D.new()
	marker.name = "RipMarker"
	var cross := Sprite3D.new()
	cross.name = "RipCross"
	cross.texture = get_rip_cross_texture()
	cross.pixel_size = 0.014
	cross.position = Vector3(0, 0.05, 0)
	cross.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cross.shaded = false
	cross.transparent = true
	cross.no_depth_test = true
	cross.render_priority = 28
	marker.add_child(cross)
	var label := Label3D.new()
	label.name = "RipName"
	label.text = name_text
	label.font = BARK_FONT
	label.font_size = 30
	label.pixel_size = 0.005
	label.position = Vector3(0, 0.85, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 118
	label.modulate = accent
	label.outline_modulate = Color(0.03, 0.05, 0.05, 0.94)
	label.outline_size = 8
	marker.add_child(label)
	if portrait != null:
		var circle := build_circle_portrait_texture(portrait, accent)
		if circle != null:
			var face := Sprite3D.new()
			face.name = "RipPortrait"
			face.texture = circle
			face.pixel_size = 0.011
			face.position = Vector3(0, 1.5, 0)
			face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			face.shaded = false
			face.transparent = true
			face.no_depth_test = true
			face.render_priority = 119
			marker.add_child(face)
	return marker


func _set_player_rip(active: bool) -> void:
	if active:
		if player_rip_marker == null or not is_instance_valid(player_rip_marker):
			player_rip_marker = CompanionSystem.build_rip_marker(GameState.player_name, Color("#e8b64c"), CompanionSystem.PLAYER_PORTRAIT_TEXTURE)
			host.player.add_child(player_rip_marker)
			player_rip_marker.position = Vector3.ZERO
		player_rip_marker.visible = true
	elif player_rip_marker != null and is_instance_valid(player_rip_marker):
		player_rip_marker.queue_free()
		player_rip_marker = null


# ── 무전기 방향 인디케이터 — 공용 EdgeIndicator(안전 여백 포함) ──

func _update_radio_indicator() -> void:
	var radio_active := radio_point != null and is_instance_valid(radio_point)
	if not radio_active:
		if radio_indicator != null:
			radio_indicator.hide()
		return
	if radio_indicator == null or not radio_indicator.is_valid():
		radio_indicator = EdgeIndicator.create(host, JUHONG_ACCENT, 88)
	radio_indicator.point_at(
		radio_point.global_position,
		"무전기 %dm" % int(
			round(host.player.global_position.distance_to(radio_point.global_position))
		)
	)


# ── HUD 칩(우상단) ──────────────────────────────────────────────────

func _refresh_hud_chip() -> void:
	if host.get("hud") == null or not host.hud.has_method("update_companion_chip"):
		return
	if juhong == null or not is_instance_valid(juhong):
		host.hud.update_companion_chip(false, 0.0, "", HudStyle.TEXT_DIM)
		return
	if juhong.retreated:
		host.hud.update_companion_chip(true, 0.0, "이탈. 무전기를 찾아라", HudStyle.TEXT_FAINT)
		return
	var ratio := clampf(float(juhong.health) / float(juhong.max_health), 0.0, 1.0)
	if juhong.downed:
		host.hud.update_companion_chip(
			true, ratio, "다운 %.0f초. 일으켜라" % maxf(0.0, juhong.down_remaining), HudStyle.DANGER
		)
	elif juhong.state == "rescue":
		host.hud.update_companion_chip(true, ratio, "구조하러 가는 중", HudStyle.WARN)
	elif juhong.state == "combat":
		var combat_status := "장전 중" if juhong.reload_remaining > 0.0 else "교전 중"
		host.hud.update_companion_chip(true, ratio, combat_status, HudStyle.WARN)
	elif juhong.state == "loot":
		host.hud.update_companion_chip(true, ratio, "시체 회수 중", JUHONG_ACCENT)
	elif juhong.motion_state == "walk":
		host.hud.update_companion_chip(true, ratio, "따라가는 중", JUHONG_ACCENT)
	else:
		host.hud.update_companion_chip(true, ratio, "주변 경계", JUHONG_ACCENT)


# ════════════════════════════════════════════════════════════════════
# JuhongBody — 필드 AI 본체
# ════════════════════════════════════════════════════════════════════

class JuhongBody:
	extends CharacterBody3D

	const DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
	const DIRECTION_STATES := {
		"n": "up", "ne": "up_right", "e": "right", "se": "down_right",
		"s": "down", "sw": "down_left", "w": "left", "nw": "up_left",
	}
	const FRAME_COUNT := 4
	const WALK_SPEED := 5.6
	const RESCUE_SPEED := 6.3
	const FOLLOW_STOP := 2.2
	const FOLLOW_RESUME := 2.8
	const COMBAT_LEASH := 11.0
	const BREAK_OFF_DISTANCE := 16.0
	const ENGAGE_MIN := 4.0
	const ENGAGE_MAX := 9.0
	# 사거리는 반드시 ENGAGE_MAX보다 넉넉해야 한다 — 짧으면 유지 밴드 바깥
	# 구간(7~9m)에서 스트레이프만 하며 영영 못 쏜다(실플레이 "총을 안 쏜다" 원인).
	const FIRE_RANGE := 12.0
	const SHOT_DAMAGE := 26
	const SHOT_INTERVAL := 0.42
	const RELOAD_SECONDS := 2.2
	const MAGAZINE_SIZE := 2
	const MAX_HEALTH := 160
	const STUCK_TELEPORT_SECONDS := 2.5
	const BARK_THROTTLE_SECONDS := 4.0
	const COVER_SCAN_INTERVAL := 0.25
	const PEEK_SECONDS := 0.6
	const CROUCH_SCALE_Y := 0.8
	const STEERING_LOCK_MSEC := 220
	const LOOT_SECONDS := 1.2
	const LOOT_AMMO_CHANCE := 0.65
	# 주홍 본인의 산탄 — 무한이 아니다(유저 지적). 시체를 회수할 때 자기 몫을
	# 먼저 챙겨 자급자족하므로 플레이어가 관리할 일은 없다.
	const START_SHELLS := 24
	const MAX_SHELLS := 30
	const SELF_SHELL_LOOT_MIN := 3
	const SELF_SHELL_LOOT_MAX := 6

	var system  # CompanionSystem
	var host: Node
	var sprite: AnimatedSprite3D
	var weapon_visual: Sprite3D
	var name_label: Label3D
	var health_bar_background: Sprite3D
	var health_bar_fill: Sprite3D
	var facing := "s"
	var motion_state := "idle"
	var state := "follow"  # follow / combat / rescue / loot / down / retreated
	var loot_timer := 0.0
	var rip_marker: Node3D
	var health := MAX_HEALTH
	var max_health := MAX_HEALTH
	var downed := false
	var retreated := false
	var down_remaining := 0.0
	# 프로브가 출혈 시간을 조절할 수 있게 변수.
	var bleed_seconds := CompanionSystem.JUHONG_BLEED_SECONDS
	var channeling_revive := false
	var combat_target: CharacterBody3D
	var magazine_ammo := MAGAZINE_SIZE
	var shell_reserve := START_SHELLS
	var dry_barked := false
	var fire_cooldown := 0.0
	var reload_remaining := 0.0
	var peek_time := 0.0
	var strafe_sign := 1.0
	var strafe_switch_time := 0.0
	# 지연 lerp 추종 — 플레이어 위치를 한 박자 늦게 따라간다(그림자처럼 붙지 않게).
	var lagged_player_position := Vector3.INF
	var stuck_time := 0.0
	var last_frame_position := Vector3.INF
	var bark_cooldown := 0.0
	var bark_label: Label3D
	var engage_barked := false
	var rescue_barked := false
	var hit_flash_time := 0.0
	# 엄폐 v2 상태(플레이어·적과 같은 판정 공유).
	var cover_active := false
	var cover_body: Node3D
	var cover_scan_timer := 0.0
	var cover_arc: Node3D
	var crouch_shown := false
	var crouch_tween: Tween
	# 처치 바크용 — 마지막으로 내 탄을 맞은 적.
	var last_shot_target: CharacterBody3D
	var last_shot_msec := 0
	var kill_count := 0
	var steering_direction_cache := Vector3.ZERO
	var steering_lock_until_msec := 0


	func _ready() -> void:
		name = "JuhongCompanion"
		add_to_group("companion")
		# PLAYER_LAYER를 겸한다 — 적탄의 스윕 레이(PROJECTILE_MASK)가 주홍을 볼 수
		# 있는 유일한 레이어다. 아군 탄은 bullet_projectile의 동행 통과 규칙이 거른다.
		collision_layer = COLLISION_PROFILES.PLAYER_LAYER | COLLISION_PROFILES.COMPANION_LAYER
		collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.34
		shape.height = 1.3
		collision.shape = shape
		add_child(collision)

		sprite = AnimatedSprite3D.new()
		sprite.name = "JuhongSprite"
		sprite.sprite_frames = _create_sprite_frames()
		sprite.position = Vector3(0, 0.48, 0)
		sprite.pixel_size = 0.0092
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.transparent = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.no_depth_test = true
		sprite.render_priority = 30
		add_child(sprite)

		weapon_visual = Sprite3D.new()
		weapon_visual.name = "JuhongDoubleBarrel"
		weapon_visual.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture("double_barrel")
		weapon_visual.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size("double_barrel", 0.0042)
		weapon_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		weapon_visual.shaded = false
		weapon_visual.transparent = true
		weapon_visual.no_depth_test = true
		weapon_visual.render_priority = 34
		weapon_visual.position = Vector3(0.12, 0.42, 0.0)
		add_child(weapon_visual)

		# 이름표 "주홍" + 소형 체력바(적 인프라 문법, 색만 청록).
		name_label = Label3D.new()
		name_label.name = "JuhongNameLabel"
		name_label.text = "주홍"
		name_label.font = BARK_FONT
		name_label.font_size = 28
		name_label.pixel_size = 0.005
		name_label.position = Vector3(0, 1.92, 0)
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.no_depth_test = true
		name_label.render_priority = 120
		name_label.modulate = CompanionSystem.JUHONG_ACCENT
		name_label.outline_modulate = Color(0.02, 0.07, 0.06, 0.94)
		name_label.outline_size = 8
		add_child(name_label)
		_setup_health_bar()
		_play_animation()


	# ── 메인 루프 ────────────────────────────────────────────────────

	func _physics_process(delta: float) -> void:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)
		bark_cooldown = maxf(0.0, bark_cooldown - delta)
		peek_time = maxf(0.0, peek_time - delta)
		hit_flash_time = maxf(0.0, hit_flash_time - delta)
		if hit_flash_time <= 0.0 and not downed and sprite.modulate != Color.WHITE:
			sprite.modulate = Color.WHITE
		if retreated:
			return
		if downed:
			down_remaining -= delta
			if down_remaining <= 0.0:
				retreat()
			return
		if host == null or not is_instance_valid(host.get("player")):
			velocity = Vector3.ZERO
			return
		_update_kill_bark()
		_update_reload(delta)
		# 조작이 잠기는 국면(시네마틱·추출 전환·플레이어 사망 연출)엔 얌전히 선다.
		if (
			bool(host.get("extraction_transition_active"))
			or bool(host.get("player_death_sequence_active"))
			or (host.has_method("is_cinematic_active") and bool(host.call("is_cinematic_active")))
		):
			velocity = Vector3.ZERO
			_set_motion_state("idle")
			return
		if bool(system.player_downed):
			_update_rescue(delta)
		else:
			_update_field_ai(delta)
		_update_cover(delta)
		move_and_slide()
		_update_stuck_recovery(delta)


	func _update_field_ai(delta: float) -> void:
		var player: CharacterBody3D = host.player
		var engagement_allowed: bool = system.any_enemy_alerted()
		if not engagement_allowed:
			# 은신 존중 — 경보 전엔 표적을 버리고 사격 금지. 식빵 자세는 따라 웅크린다.
			combat_target = null
			engage_barked = false
			# 전투가 끝났으면 근처 시체부터 회수한다(탄약은 플레이어 몫).
			if _update_looting(delta):
				return
			state = "follow"
			_update_follow(delta, bool(host.get("loafing")))
			return
		var player_distance := global_position.distance_to(player.global_position)
		if player_distance > BREAK_OFF_DISTANCE:
			# 12m 이상 벌어지면 교전을 포기하고 복귀한다.
			combat_target = null
			state = "follow"
			_update_follow(delta, false)
			return
		combat_target = select_combat_target()
		if combat_target == null:
			state = "follow"
			engage_barked = false
			_update_follow(delta, false)
			return
		if state != "combat":
			state = "combat"
			_bark_engage()
		_update_combat(delta)


	func _update_follow(delta: float, sneak: bool) -> void:
		var player: CharacterBody3D = host.player
		if lagged_player_position == Vector3.INF:
			lagged_player_position = player.global_position
		# 지연 lerp — 목표점 자체가 한 박자 늦게 따라온다.
		lagged_player_position = lagged_player_position.lerp(
			player.global_position, 1.0 - exp(-3.2 * delta)
		)
		var offset := lagged_player_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		var moving := distance > (FOLLOW_STOP if motion_state == "walk" else FOLLOW_RESUME)
		if moving and distance > 0.01:
			var direction := _steer_around_obstacles(offset / distance)
			var speed := WALK_SPEED * (0.6 if sneak else 1.0)
			velocity = direction * speed
			if direction.length_squared() > 0.01:
				_set_facing_from_world_direction(direction)
			_set_motion_state("walk")
		else:
			velocity = Vector3.ZERO
			_set_motion_state("idle")
			# 대기 중엔 플레이어가 보는 곳을 같이 본다.
			var player_offset := player.global_position - global_position
			player_offset.y = 0.0
			if player_offset.length_squared() > 0.04:
				_set_facing_from_world_direction(player_offset.normalized())
		_apply_crouch_visual(sneak or (cover_active and peek_time <= 0.0))


	func _update_combat(delta: float) -> void:
		var player: CharacterBody3D = host.player
		var target := combat_target
		if not is_instance_valid(target) or bool(target.get("dying")):
			combat_target = null
			return
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var target_distance := to_target.length()
		var to_player := player.global_position - global_position
		to_player.y = 0.0

		# 이동 — 리시 8m 안에서 표적과 4~9m 유지 + 스트레이프.
		strafe_switch_time -= delta
		if strafe_switch_time <= 0.0:
			strafe_switch_time = randf_range(1.1, 2.2)
			strafe_sign = -strafe_sign
		var desired := Vector3.ZERO
		if to_player.length() > COMBAT_LEASH:
			desired = to_player.normalized()
		elif target_distance > ENGAGE_MAX:
			desired = to_target / maxf(target_distance, 0.01)
		elif target_distance < ENGAGE_MIN:
			desired = -to_target / maxf(target_distance, 0.01)
		else:
			desired = Vector3(-to_target.z, 0.0, to_target.x).normalized() * strafe_sign * 0.7
		if desired.length_squared() > 0.01:
			var direction := _steer_around_obstacles(desired.normalized())
			velocity = direction * WALK_SPEED * 0.92
			_set_motion_state("walk")
		else:
			velocity = Vector3.ZERO
			_set_motion_state("idle")
		if to_target.length_squared() > 0.01:
			_set_facing_from_world_direction(to_target.normalized())

		_try_fire(target, target_distance)
		_apply_crouch_visual(cover_active and peek_time <= 0.0)


	func _update_rescue(delta: float) -> void:
		var player: CharacterBody3D = host.player
		state = "rescue"
		if not rescue_barked:
			rescue_barked = true
			bark("버텨! 내가 지금 간다!")
		var offset := player.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > CompanionSystem.PLAYER_REVIVE_REACH * 0.85:
			var direction := _steer_around_obstacles(offset / maxf(distance, 0.01))
			velocity = direction * RESCUE_SPEED
			if direction.length_squared() > 0.01:
				_set_facing_from_world_direction(direction)
			_set_motion_state("walk")
			# 달려가는 길에도 코앞의 위협은 정리한다.
			var threat := select_combat_target()
			if threat != null and global_position.distance_to(threat.global_position) <= FIRE_RANGE:
				_try_fire(threat, global_position.distance_to(threat.global_position))
		else:
			velocity = Vector3.ZERO
			_set_motion_state("idle")
			if offset.length_squared() > 0.01:
				_set_facing_from_world_direction(offset.normalized())
		_apply_crouch_visual(channeling_revive)


	# ── 전투 후 회수 — 시체를 돌며 장착 구경 탄약을 챙겨 준다 ────────

	func _update_looting(delta: float) -> bool:
		# 전투가 끝났을 때만. 플레이어가 식빵 자세(은신)면 돌아다니지 않는다.
		if bool(host.get("loafing")):
			return false
		# ① 플레이어 예비탄이 1탄창 이하면 — 바닥의 장착 구경 탄약부터 대신
		# 주워 온다(유저 요청: "탄약이 모자라면 지가 가서 루팅도 하고").
		var ammo_fetch := _find_ammo_fetch_target()
		if ammo_fetch != null:
			if state != "loot":
				state = "loot"
				bark("탄 떨어졌지? 잠깐 있어 봐.")
			var fetch_offset := ammo_fetch.global_position - global_position
			fetch_offset.y = 0.0
			var fetch_distance := fetch_offset.length()
			if fetch_distance > 1.0:
				loot_timer = 0.0
				var fetch_direction := _steer_around_obstacles(
					fetch_offset / maxf(fetch_distance, 0.01)
				)
				velocity = fetch_direction * WALK_SPEED
				if fetch_direction.length_squared() > 0.01:
					_set_facing_from_world_direction(fetch_direction)
				_set_motion_state("walk")
				_apply_crouch_visual(false)
				return true
			velocity = Vector3.ZERO
			_set_motion_state("idle")
			_apply_crouch_visual(true)
			loot_timer += delta
			if loot_timer >= LOOT_SECONDS:
				loot_timer = 0.0
				_collect_ammo_pickup(ammo_fetch)
			return true
		# ② 처치 지점 회수 — 플레이어가 멀어지면 지점을 버리고 따라간다.
		while not system.loot_spots.is_empty():
			var stale: Vector3 = system.loot_spots[0]
			if host.player.global_position.distance_to(stale) > 20.0:
				system.loot_spots.pop_front()
				continue
			break
		if system.loot_spots.is_empty():
			return false
		if state != "loot":
			state = "loot"
			bark("잠깐만. 챙길 게 있어.")
		var spot: Vector3 = system.loot_spots[0]
		var offset := spot - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 1.0:
			loot_timer = 0.0
			var direction := _steer_around_obstacles(offset / maxf(distance, 0.01))
			velocity = direction * WALK_SPEED
			if direction.length_squared() > 0.01:
				_set_facing_from_world_direction(direction)
			_set_motion_state("walk")
			_apply_crouch_visual(false)
			return true
		velocity = Vector3.ZERO
		_set_motion_state("idle")
		_apply_crouch_visual(true)
		loot_timer += delta
		if loot_timer >= LOOT_SECONDS:
			loot_timer = 0.0
			system.loot_spots.pop_front()
			_finish_loot_roll()
		return true


	func _find_ammo_fetch_target() -> Node3D:
		# 플레이어 예비탄이 1탄창 이하일 때만 발동. 대상: 바닥의 장착 구경 탄약
		# 픽업(주홍 기준 18m·플레이어 기준 22m 안). 플레이어가 지금 줍고 있는
		# 픽업은 건드리지 않는다.
		if not bool(GameState.has_ak):
			return null
		var weapon_stats = host.get("weapon_stats")
		var magazine_size := 30
		if weapon_stats is Dictionary:
			magazine_size = int((weapon_stats as Dictionary).get("magazine_size", 30))
		if int(host.get("reserve_ammo")) > magazine_size:
			return null
		var equipped_ammo := str(GameState.equipped_ammo_id)
		if equipped_ammo.is_empty():
			return null
		var loot = host.get("loot_system")
		if loot == null:
			return null
		var best: Node3D = null
		var best_distance := 18.0
		for pickup_value in loot.ammo_pickups:
			var pickup := pickup_value as Node3D
			if pickup == null or not is_instance_valid(pickup):
				continue
			if str(pickup.get_meta("loot_type", "")) != "ammo":
				continue
			if str(pickup.get_meta("ammo_id", "")) != equipped_ammo:
				continue
			if pickup == host.get("nearby_ammo_pickup"):
				continue
			if host.player.global_position.distance_to(pickup.global_position) > 22.0:
				continue
			var pickup_distance := global_position.distance_to(pickup.global_position)
			if pickup_distance < best_distance:
				best_distance = pickup_distance
				best = pickup
		return best


	func _collect_ammo_pickup(pickup: Node3D) -> void:
		# 플레이어 픽업 경로의 최소 재현 — 탄약만 다루므로 가방 검사 불필요.
		if pickup == null or not is_instance_valid(pickup):
			return
		var ammo_id := str(pickup.get_meta("ammo_id", "762_fmj"))
		var amount := int(pickup.get_meta("amount", 1))
		var updated := GameState.get_ammo_count(ammo_id) + amount
		GameState.set_ammo_count(ammo_id, updated)
		if GameState.equipped_ammo_id == ammo_id:
			host.reserve_ammo = updated
			GameState.reserve_ammo = updated
		if host.has_method("_update_equipment_ui"):
			host.call("_update_equipment_ui")
		var loot = host.get("loot_system")
		if loot != null:
			loot.ammo_pickups.erase(pickup)
		if pickup == host.get("nearby_ammo_pickup"):
			host.set("nearby_ammo_pickup", null)
		pickup.queue_free()
		show_loot_popup("탄약 +%d" % amount)


	func _finish_loot_roll() -> void:
		# "내 몫은 내가 챙긴다" — 자기 산탄부터 먼저(청록 팝업), 부족할 때만.
		if shell_reserve < MAX_SHELLS:
			var self_shells := mini(
				randi_range(SELF_SHELL_LOOT_MIN, SELF_SHELL_LOOT_MAX),
				MAX_SHELLS - shell_reserve
			)
			if self_shells > 0:
				shell_reserve += self_shells
				dry_barked = false
				show_loot_popup("산탄 +%d" % self_shells, CompanionSystem.JUHONG_ACCENT)
		# 65%: 장착 무기 구경 탄약을 플레이어 몫으로(금색 팝업).
		if randf() >= LOOT_AMMO_CHANCE or not bool(GameState.has_ak):
			return
		var ammo_id := str(GameState.equipped_ammo_id)
		if ammo_id.is_empty():
			return
		var amount := randi_range(5, 10)
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + amount)
		if host.get("reserve_ammo") != null:
			host.reserve_ammo = GameState.get_ammo_count(ammo_id)
		if host.has_method("_update_equipment_ui"):
			host.call("_update_equipment_ui")
		show_loot_popup("탄약 +%d" % amount)


	func show_loot_popup(text: String, accent: Color = Color("#ffd45e")) -> void:
		# 바크와 다른 층위 — 짧게 떠오르고 사라지는 획득 팝업.
		# 금색 = 플레이어 몫, 청록 = 주홍 본인 몫.
		var popup := Label3D.new()
		popup.name = "JuhongLootPopup"
		popup.text = text
		popup.font = BARK_FONT
		popup.font_size = 44
		popup.pixel_size = 0.0042
		popup.modulate = accent
		popup.outline_size = 12
		popup.outline_modulate = Color(0.09, 0.06, 0.01, 0.92)
		popup.position = Vector3(0, 1.55, 0)
		popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		popup.no_depth_test = true
		popup.render_priority = 121
		add_child(popup)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup, "position:y", 2.25, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup, "modulate:a", 0.0, 0.55).set_delay(0.45)
		tween.chain().tween_callback(popup.queue_free)


	# ── 표적 선택(스펙 고정 우선순위) ────────────────────────────────

	func select_combat_target() -> CharacterBody3D:
		var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
		var attacking_player: CharacterBody3D = null
		var attacking_player_distance := INF
		var attacking_self: CharacterBody3D = null
		var attacking_self_distance := INF
		var nearest: CharacterBody3D = null
		var nearest_distance := INF
		for enemy in enemies:
			if not is_instance_valid(enemy) or bool(enemy.get("dying")):
				continue
			if not bool(enemy.get("alerted")):
				continue
			var body := enemy as CharacterBody3D
			var distance := global_position.distance_to(body.global_position)
			if distance > 26.0:
				continue
			if enemy.get("target") == host.player and distance < attacking_player_distance:
				attacking_player = body
				attacking_player_distance = distance
			if enemy.get("target") == self and distance < attacking_self_distance:
				attacking_self = body
				attacking_self_distance = distance
			if distance < nearest_distance:
				nearest = body
				nearest_distance = distance
		if attacking_player != null:
			return attacking_player
		if attacking_self != null:
			return attacking_self
		return nearest


	# ── 사격(더블배럴 지원 화력 — 주인공은 먼지다) ───────────────────

	func _update_reload(delta: float) -> void:
		if reload_remaining > 0.0:
			reload_remaining -= delta
			if reload_remaining <= 0.0:
				# 예비 산탄에서 채운다 — 바닥나면 빈 총이고, 시체 회수가 곧 보급이다.
				var loaded := mini(MAGAZINE_SIZE, shell_reserve)
				magazine_ammo = loaded
				shell_reserve -= loaded
				if loaded <= 0 and not dry_barked:
					dry_barked = true
					bark("탄 없어. 시체 좀 뒤질게.")


	func _try_fire(target: CharacterBody3D, target_distance: float) -> void:
		if fire_cooldown > 0.0 or reload_remaining > 0.0 or magazine_ammo <= 0:
			return
		if target_distance > FIRE_RANGE:
			return
		# 몸높이 레이가 막혀도 낮은 엄폐물 뒤라면 머리 높이(엄폐 머리 레이 0.84)로
		# 내밀어 쏜다 — 안 그러면 자기 엄폐물에 시야가 막혀 엄폐 중 영영 침묵한다.
		var muzzle_height := 0.62
		if not _has_line_of_sight_to(target, muzzle_height):
			muzzle_height = 0.84
			if not (cover_active and _has_line_of_sight_to(target, muzzle_height)):
				return
		var aim := target.global_position - global_position
		aim.y = 0.0
		if aim.length_squared() < 0.0001:
			return
		peek_time = PEEK_SECONDS
		magazine_ammo -= 1
		fire_cooldown = SHOT_INTERVAL
		var spread := deg_to_rad(randf_range(-2.6, 2.6))
		var direction := aim.normalized().rotated(Vector3.UP, spread)
		var projectile := Area3D.new()
		projectile.name = "Juhong_DoubleBarrel_Shot"
		projectile.set_script(BULLET_PROJECTILE)
		projectile.set("direction", direction)
		projectile.set("source_body", self)
		projectile.set("damage", SHOT_DAMAGE)
		projectile.set("hostile", false)
		projectile.set("critical_chance", 0.0)
		projectile.set("effective_range", FIRE_RANGE)
		projectile.set("maximum_range", 18.0)
		projectile.set("minimum_damage_multiplier", 0.3)
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector3(0, muzzle_height, 0) + direction * 0.5
		SFX.play_weapon_shot("double_barrel", global_position, -3.0)
		last_shot_target = target
		last_shot_msec = Time.get_ticks_msec()
		if magazine_ammo <= 0:
			reload_remaining = RELOAD_SECONDS
			bark("장전한다!")


	func _has_line_of_sight_to(target: Node3D, eye_height: float = 0.62) -> bool:
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, eye_height, 0),
			target.global_position + Vector3(0, 0.45, 0),
			COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
		)
		query.exclude = [get_rid()]
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


	func _update_kill_bark() -> void:
		if last_shot_target == null:
			return
		if not is_instance_valid(last_shot_target) or bool(last_shot_target.get("dying")):
			if Time.get_ticks_msec() - last_shot_msec <= 1600:
				kill_count += 1
				bark("하나 잡았어." if kill_count % 2 == 1 else "됐고, 다음 놈.")
			last_shot_target = null


	func _bark_engage() -> void:
		if engage_barked:
			return
		engage_barked = true
		if combat_target == null or not is_instance_valid(combat_target):
			bark("적이야. 이쪽으로 온다.")
			return
		# 방향은 실제 표적 방위(플레이어 시선 기준)로 좌/우/뒤 치환.
		var player: CharacterBody3D = host.player
		var heading: Vector3 = player.get_meta("tactical_heading", Vector3.FORWARD)
		heading.y = 0.0
		var to_threat := combat_target.global_position - player.global_position
		to_threat.y = 0.0
		if heading.length_squared() < 0.01 or to_threat.length_squared() < 0.01:
			bark("적이야. 이쪽으로 온다.")
			return
		heading = heading.normalized()
		to_threat = to_threat.normalized()
		var forward_dot := heading.dot(to_threat)
		if forward_dot < -0.5:
			bark("적이 뒤에 있어!")
		elif heading.cross(to_threat).y > 0.0:
			bark("적이 왼쪽에 있어!")
		elif forward_dot < 0.85:
			bark("적이 오른쪽에 있어!")
		else:
			bark("적이야. 이쪽으로 온다.")


	# ── 바크(말풍선 — 적 유인 대사 인프라 문법, 4s 스로틀) ───────────

	func bark(line: String) -> void:
		if bark_cooldown > 0.0 or retreated:
			return
		bark_cooldown = BARK_THROTTLE_SECONDS
		# 말풍선 그리기는 공용 모듈(speech_bubble)이 한다 — 적·동료가 같은
		# 크기·같은 배경 판을 쓰게 해 화면에서 대사가 일관되게 읽힌다.
		bark_label = SPEECH_BUBBLE.show_line(
			self, line, SPEECH_BUBBLE.TONE_ALLY, 2.6, 2.2
		)


	# ── 엄폐 v2 편승 ─────────────────────────────────────────────────

	func _update_cover(delta: float) -> void:
		cover_scan_timer -= delta
		if cover_scan_timer > 0.0:
			return
		cover_scan_timer = COVER_SCAN_INTERVAL
		var threat_position := Vector3.INF
		if is_instance_valid(combat_target):
			threat_position = combat_target.global_position
		elif state == "combat" or system.any_enemy_alerted():
			var nearest := select_combat_target()
			if nearest != null:
				threat_position = nearest.global_position
		if threat_position == Vector3.INF:
			_set_cover_state(false, null)
			return
		var result := COVER_SYSTEM.evaluate_cover_for(self, threat_position, global_position.y - 0.78)
		_set_cover_state(bool(result.get("covered", false)), result.get("blocker") as Node3D)


	func _set_cover_state(active: bool, blocker: Node3D) -> void:
		cover_active = active
		cover_body = blocker
		_ensure_cover_arc()
		var covered_now := active and peek_time <= 0.0 and not downed
		cover_arc.visible = covered_now
		if covered_now and is_instance_valid(cover_body):
			var toward := cover_body.global_position - global_position
			toward.y = 0.0
			if toward.length_squared() > 0.01:
				toward = toward.normalized()
				cover_arc.rotation.y = atan2(-toward.z, toward.x)


	func _ensure_cover_arc() -> void:
		if cover_arc != null and is_instance_valid(cover_arc):
			return
		# 플레이어와 같은 호 텍스처 — 색만 청록(같은 시각 문법).
		cover_arc = COVER_SYSTEM.build_cover_arc_indicator(self, -0.64)
		cover_arc.name = "JuhongCoverArc"
		var fill := cover_arc.get_node_or_null("Fill") as Sprite3D
		var outline := cover_arc.get_node_or_null("Outline") as Sprite3D
		if fill != null:
			fill.pixel_size = 0.012
			fill.modulate = Color(CompanionSystem.JUHONG_ACCENT, 0.68)
		if outline != null:
			outline.pixel_size = 0.012
			outline.modulate = Color(CompanionSystem.JUHONG_ACCENT, 1.0)


	func is_cover_crouching() -> bool:
		return cover_active and peek_time <= 0.0 and not downed


	func _apply_crouch_visual(active: bool) -> void:
		if active == crouch_shown or downed:
			return
		crouch_shown = active
		if crouch_tween != null and crouch_tween.is_valid():
			crouch_tween.kill()
		crouch_tween = sprite.create_tween()
		crouch_tween.set_parallel(true)
		var target_scale := Vector3(1.0, CROUCH_SCALE_Y, 1.0) if active else Vector3.ONE
		var target_y := 0.48 - (0.08 if active else 0.0)
		crouch_tween.tween_property(sprite, "scale", target_scale, 0.12)
		crouch_tween.tween_property(sprite, "position:y", target_y, 0.12)


	# ── 피격/다운/소생 ───────────────────────────────────────────────

	func get_projectile_hit_center() -> Vector3:
		return global_position + Vector3(0, 0.52, 0)


	func get_projectile_hit_radius() -> float:
		return 0.5


	func get_faction_id() -> String:
		return "companion"


	func take_damage(amount: int) -> void:
		take_hostile_hit(amount, Vector3.ZERO)


	func take_hostile_hit(
		amount: int,
		hit_direction: Vector3,
		attacker = null,
		source_position: Vector3 = Vector3.INF,
		impact_kind: String = "bullet"
	) -> void:
		if downed or retreated:
			return
		# 엄폐 v2 — covered 중 그 엄폐물을 지나오는 총알은 차단(폭발·근접은 그대로).
		var cover_source := source_position
		if cover_source == Vector3.INF and is_instance_valid(attacker) and attacker is Node3D:
			cover_source = (attacker as Node3D).global_position
		if impact_kind == "bullet" and is_cover_crouching() and cover_source != Vector3.INF:
			var result := COVER_SYSTEM.evaluate_cover_for(self, cover_source, global_position.y - 0.78)
			if bool(result.get("covered", false)):
				COVER_SYSTEM.spawn_block_fx(self, result.get("point", global_position))
				return
		health = maxi(0, health - amount)
		hit_flash_time = 0.16
		sprite.modulate = Color(2.0, 0.3, 0.24, 1.0)
		_update_health_bar()
		if health <= 0:
			begin_down()


	func begin_down() -> void:
		if downed:
			return
		downed = true
		state = "down"
		down_remaining = bleed_seconds
		channeling_revive = false
		velocity = Vector3.ZERO
		collision_layer = 0
		# 다운 = RIP 십자가 + 이름(유저 확정: 쓰러진 스프라이트 말고 십자가).
		sprite.visible = false
		name_label.visible = false
		_set_rip_visible(true)
		if weapon_visual != null:
			weapon_visual.visible = false
		if cover_arc != null and is_instance_valid(cover_arc):
			cover_arc.visible = false
		_update_health_bar()
		bark_cooldown = 0.0
		bark("젠장. 나 맞았어. 이쪽 좀 봐.")
		system.on_juhong_down()


	func revive() -> void:
		if not downed:
			return
		downed = false
		retreated = false
		state = "follow"
		health = maxi(1, roundi(float(max_health) * CompanionSystem.REVIVE_HEALTH_RATIO))
		collision_layer = COLLISION_PROFILES.PLAYER_LAYER | COLLISION_PROFILES.COMPANION_LAYER
		sprite.visible = true
		sprite.rotation.z = 0.0
		sprite.position.y = 0.48
		sprite.modulate = Color.WHITE
		name_label.visible = true
		_set_rip_visible(false)
		if weapon_visual != null:
			weapon_visual.visible = true
		_update_health_bar()
		bark_cooldown = 0.0
		bark("빚졌네. 이건 꼭 갚을게.")
		SFX.play("cover_enter")


	func retreat() -> void:
		if retreated:
			return
		retreated = true
		downed = false
		state = "retreated"
		# 연막 페이드 — 티 안 나게 사라진다(영구 사망 없음, 판 끝나면 쉘터 복귀).
		if host != null and host.has_method("_spawn_smoke_cloud"):
			host._spawn_smoke_cloud(global_position + Vector3(0, 0.4, 0), Vector3.UP)
		visible = false
		collision_layer = 0
		collision_mask = 0
		# 십자가는 다운 상태의 표식이다 — 후퇴하면 치운다. 안 치우면 무전기로 복귀할 때
		# 십자가를 단 채 따라다녔다(2026-09-03 유저 신고).
		_set_rip_visible(false)
		set_physics_process(false)
		system.on_juhong_retreated()


	func begin_rescue() -> void:
		rescue_barked = false
		state = "rescue"


	func _set_rip_visible(active: bool) -> void:
		if active:
			if rip_marker == null or not is_instance_valid(rip_marker):
				rip_marker = CompanionSystem.build_rip_marker("주홍", CompanionSystem.JUHONG_ACCENT, CompanionSystem.JUHONG_PORTRAIT_TEXTURE)
				add_child(rip_marker)
			rip_marker.visible = true
		elif rip_marker != null and is_instance_valid(rip_marker):
			rip_marker.visible = false


	func return_from_retreat(origin: Vector3) -> void:
		_set_rip_visible(false)
		# 무전기 회수 — 연막에서 돌아온다. 체력 60%, 판당 소생 카운트는 그대로.
		if not retreated:
			return
		retreated = false
		downed = false
		state = "follow"
		health = maxi(1, roundi(float(max_health) * 0.6))
		collision_layer = COLLISION_PROFILES.PLAYER_LAYER | COLLISION_PROFILES.COMPANION_LAYER
		collision_mask = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		set_physics_process(true)
		visible = true
		global_position = Vector3(origin.x, 0.78, origin.z)
		sprite.rotation.z = 0.0
		sprite.position.y = 0.48
		sprite.modulate = Color.WHITE
		if weapon_visual != null:
			weapon_visual.visible = true
		lagged_player_position = Vector3.INF
		last_frame_position = Vector3.INF
		_update_health_bar()
		if host != null and host.has_method("_spawn_smoke_cloud"):
			host._spawn_smoke_cloud(global_position + Vector3(0, 0.4, 0), Vector3.UP)
		bark_cooldown = 0.0
		bark("무전 잘 받았어. 빚 하나 추가야.")
		SFX.play("cover_enter")


	# ── 끼임 방지 — 2.5s 제자리면 플레이어 옆 연막 재배치 ────────────

	func _update_stuck_recovery(delta: float) -> void:
		if last_frame_position == Vector3.INF:
			last_frame_position = global_position
			return
		var moved := global_position.distance_to(last_frame_position)
		last_frame_position = global_position
		if velocity.length_squared() > 0.4 and moved < 0.02:
			stuck_time += delta
		else:
			stuck_time = 0.0
		if stuck_time < STUCK_TELEPORT_SECONDS:
			return
		stuck_time = 0.0
		var player: CharacterBody3D = host.player
		var requested: Vector3 = player.global_position + Vector3(-1.2, 0.0, 1.0)
		var world: Node = host.get_node_or_null("World")
		if world != null and world.has_method("find_nearest_physically_open_position"):
			requested = world.call(
				"find_nearest_physically_open_position", requested, 0.58, [player.get_rid(), get_rid()]
			)
		if host.has_method("_spawn_smoke_cloud"):
			host._spawn_smoke_cloud(global_position + Vector3(0, 0.4, 0), Vector3.UP)
		global_position = Vector3(requested.x, 0.78, requested.z)
		if host.has_method("_spawn_smoke_cloud"):
			host._spawn_smoke_cloud(global_position + Vector3(0, 0.4, 0), Vector3.UP)


	func _steer_around_obstacles(desired_direction: Vector3) -> Vector3:
		# enemy.gd의 조향 각도 스캔 재활용(간이판) — 캐시 + 회전 후보.
		if desired_direction.length_squared() <= 0.01:
			steering_direction_cache = Vector3.ZERO
			return Vector3.ZERO
		var desired := desired_direction.normalized()
		var now_msec := Time.get_ticks_msec()
		if (
			now_msec < steering_lock_until_msec
			and steering_direction_cache.length_squared() > 0.01
			and steering_direction_cache.dot(desired) >= 0.35
			and _is_steering_direction_clear(steering_direction_cache, 2.0)
		):
			return steering_direction_cache
		var angles := [0.0, 24.0, -24.0, 48.0, -48.0, 76.0, -76.0, 112.0, -112.0]
		for angle in angles:
			var candidate := desired.rotated(Vector3.UP, deg_to_rad(angle))
			var probe_distance := 2.8 if is_zero_approx(angle) else 2.1
			if _is_steering_direction_clear(candidate, probe_distance):
				steering_direction_cache = candidate
				steering_lock_until_msec = now_msec + STEERING_LOCK_MSEC
				return candidate
		steering_direction_cache = Vector3.ZERO
		return desired


	func _is_steering_direction_clear(direction: Vector3, probe_distance: float) -> bool:
		if direction.length_squared() <= 0.01:
			return false
		var from := global_position + Vector3(0, 0.32, 0)
		var query := PhysicsRayQueryParameters3D.create(
			from,
			from + direction.normalized() * probe_distance,
			COLLISION_PROFILES.WORLD_MOVEMENT_LAYER
		)
		query.exclude = [get_rid()]
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


	# ── 스프라이트/애니메이션(_add_file_animation 패턴 재활용) ───────

	func _set_facing_from_world_direction(world_direction: Vector3) -> void:
		if world_direction.length_squared() <= 0.01:
			return
		var screen_direction := Vector2(
			world_direction.x - world_direction.z,
			world_direction.x + world_direction.z
		).normalized()
		var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
		var index := int(round(angle / 45.0)) % DIRECTION_NAMES.size()
		_set_facing(DIRECTION_NAMES[index])


	func _set_facing(next_facing: String) -> void:
		if facing == next_facing:
			return
		facing = next_facing
		_play_animation()


	func _set_motion_state(next_state: String) -> void:
		if motion_state == next_state:
			return
		motion_state = next_state
		_play_animation()


	func _play_animation() -> void:
		if sprite != null and sprite.sprite_frames != null:
			sprite.play("%s_%s" % [motion_state, facing])


	func _create_sprite_frames() -> SpriteFrames:
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for direction_name in DIRECTION_NAMES:
			_add_file_animation(frames, direction_name, "idle", [0, 1, 2, 3], 4.0, true)
			_add_file_animation(frames, direction_name, "walk", [0, 1, 2, 3], 8.5, true)
		return frames


	func _add_file_animation(
		frames: SpriteFrames,
		direction_name: String,
		state_name: String,
		frame_indices: Array,
		speed: float,
		looped: bool
	) -> void:
		var animation_name := "%s_%s" % [state_name, direction_name]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, looped)
		frames.set_animation_speed(animation_name, speed)
		var direction_prefix: String = DIRECTION_STATES[direction_name]
		for frame_index in frame_indices:
			var texture_path := "%s/%s_%s-frame-%d.png" % [
				JUHONG_ANIMATION_ROOT, direction_prefix, state_name, int(frame_index)
			]
			var texture := load(texture_path) as Texture2D
			if texture == null:
				push_error("Missing juhong animation frame: %s" % texture_path)
				continue
			frames.add_frame(animation_name, texture)


	# ── 머리 위 소형 체력바(적 인프라 재활용, 청록) ──────────────────

	func _setup_health_bar() -> void:
		health_bar_background = Sprite3D.new()
		health_bar_background.name = "JuhongHealthBackground"
		health_bar_background.texture = _create_bar_texture(Color(0.03, 0.045, 0.045, 0.94), true)
		health_bar_background.position = Vector3(0, 1.7, 0)
		health_bar_background.pixel_size = 0.007
		health_bar_background.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		health_bar_background.shaded = false
		health_bar_background.no_depth_test = true
		health_bar_background.render_priority = 118
		health_bar_background.visible = false
		add_child(health_bar_background)
		health_bar_fill = Sprite3D.new()
		health_bar_fill.name = "JuhongHealthFill"
		health_bar_fill.texture = _create_bar_texture(CompanionSystem.JUHONG_ACCENT, false)
		health_bar_fill.position = Vector3(0, 1.7, 0)
		health_bar_fill.pixel_size = 0.007
		health_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		health_bar_fill.shaded = false
		health_bar_fill.no_depth_test = true
		health_bar_fill.render_priority = 119
		health_bar_fill.centered = false
		health_bar_fill.offset = Vector2(-35, -4)
		health_bar_fill.region_enabled = true
		health_bar_fill.visible = false
		add_child(health_bar_fill)


	func _create_bar_texture(color: Color, bordered: bool) -> Texture2D:
		var image := Image.create(70, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		if bordered:
			image.fill_rect(Rect2i(0, 0, 70, 8), Color(0.0, 0.0, 0.0, 0.86))
			image.fill_rect(Rect2i(2, 2, 66, 4), color)
		else:
			image.fill_rect(Rect2i(0, 0, 70, 8), color)
		return ImageTexture.create_from_image(image)


	func _update_health_bar() -> void:
		if health_bar_background == null:
			return
		var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
		health_bar_background.visible = ratio < 0.999 and not downed and not retreated
		health_bar_fill.visible = health_bar_background.visible
		health_bar_fill.region_rect = Rect2(0, 0, maxf(1.0, 70.0 * ratio), 8)
