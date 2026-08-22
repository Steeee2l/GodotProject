class_name CoverSystem
extends RefCounted

# 엄폐 — "쏘고 숨기"의 리듬을 만드는 규칙. 전투 숙련도 패키지의 세 번째 조각.
#
# 판정(플레이어만 — 적 AI 변경은 범위 밖):
#   플레이어가 낮은 엄폐물(도로 커버·차량·낮은 벽 — 탄막 상자 높이 ≤ 1.7u) 뒤
#   1.2u 이내에 있고, 공격원→플레이어의 '낮은' 레이(지면+0.55)는 그 엄폐물에
#   막히지만 '머리' 높이 레이(지면+1.62)는 통과하는 상태 = 엄폐.
#   완전 차단(머리 레이도 막힘)이면 어차피 못 맞으니 엄폐가 아니라 '가림'이다.
# 효과: 받는 원거리 피해 ×0.55. 엄폐 중 사격하면 0.4s 노출(배율 1.0).
# HUD: 작은 "엄폐"(방패) 칩 — 노출 중엔 "노출"로 바뀐다. 진입/해제 짧은 소리.
#
# 기존 적 감지(LOS) 레이캐스트 인프라와 같은 마스크(WORLD_ONLY_SIGHT_MASK)를 쓴다.
# 러버밴딩 없음 — 적 스탯은 손대지 않고 플레이어의 '자리 잡기'만 보상한다.

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const SFX := preload("res://scripts/sfx_bank.gd")

const COVER_RANGE := 1.2
const LOW_COVER_MAX_HEIGHT := 1.7
const COVER_DAMAGE_MULTIPLIER := 0.55
const FIRE_EXPOSURE_SECONDS := 0.4
const LOW_RAY_HEIGHT := 0.55
const HEAD_RAY_HEIGHT := 1.62
const PLAYER_GROUND_OFFSET := 0.78
const THREAT_SCAN_RANGE := 34.0
const SCAN_INTERVAL := 0.1

var host: Node
var player: CharacterBody3D
var in_cover := false
var exposed_time := 0.0
var cover_body: Node3D
var scan_timer := 0.0
var last_threat_source := Vector3.INF
# 통계/프로브용.
var cover_enter_count := 0
var damage_reduced_total := 0


func attach(owner_node: Node) -> void:
	host = owner_node
	player = owner_node.player


func update(delta: float) -> void:
	exposed_time = maxf(0.0, exposed_time - delta)
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = SCAN_INTERVAL
	_set_in_cover(_scan_threats())


func _scan_threats() -> bool:
	# 경계 상태로 나를 노리는 적 중 하나라도 '엄폐물 건너편'이면 엄폐 중이다.
	if player == null or not is_instance_valid(player):
		return false
	var enemies: Array = host.get("enemies") if host.get("enemies") != null else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if not bool(enemy.get("alerted")):
			continue
		if enemy.has_method("is_targeting_player") and not bool(enemy.call("is_targeting_player")):
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - player.global_position
		offset.y = 0.0
		if offset.length() > THREAT_SCAN_RANGE:
			continue
		if is_covered_from((enemy as Node3D).global_position):
			last_threat_source = (enemy as Node3D).global_position
			return true
	return false


func is_covered_from(source_position: Vector3) -> bool:
	if player == null or not is_instance_valid(player) or source_position == Vector3.INF:
		return false
	var world := player.get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	var ground_y := player.global_position.y - PLAYER_GROUND_OFFSET
	var player_xz := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var source_xz := Vector3(source_position.x, 0.0, source_position.z)
	if source_xz.distance_to(player_xz) < 0.2:
		return false
	# ① 낮은 레이 — 엄폐물에 막혀야 한다.
	var low_query := PhysicsRayQueryParameters3D.create(
		source_xz + Vector3(0.0, ground_y + LOW_RAY_HEIGHT, 0.0),
		player_xz + Vector3(0.0, ground_y + LOW_RAY_HEIGHT, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	low_query.exclude = [player.get_rid()]
	var low_hit := space.intersect_ray(low_query)
	if low_hit.is_empty():
		return false
	var blocker := low_hit.get("collider") as Node3D
	if blocker == null or not _is_low_cover(blocker):
		return false
	if not _is_cover_within_reach(blocker, low_hit.get("position") as Vector3):
		return false
	# ② 머리 레이 — 통과해야 '엄폐'(안 통과하면 완전 차단).
	var head_query := PhysicsRayQueryParameters3D.create(
		source_xz + Vector3(0.0, ground_y + HEAD_RAY_HEIGHT, 0.0),
		player_xz + Vector3(0.0, ground_y + HEAD_RAY_HEIGHT, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	head_query.exclude = [player.get_rid()]
	if not space.intersect_ray(head_query).is_empty():
		return false
	cover_body = blocker
	return true


func get_damage_multiplier(source_position: Vector3) -> float:
	# 피격 순간 호출 — 사격 노출 중이면 배율 없음. 그 외엔 그 공격원 기준으로 판정.
	if source_position == Vector3.INF or exposed_time > 0.0:
		return 1.0
	return COVER_DAMAGE_MULTIPLIER if is_covered_from(source_position) else 1.0


func apply_to_damage(amount: int, source_position: Vector3) -> int:
	var multiplier := get_damage_multiplier(source_position)
	if multiplier >= 0.999:
		return amount
	var reduced := maxi(1, roundi(float(amount) * multiplier))
	damage_reduced_total += maxi(0, amount - reduced)
	return reduced


func notify_player_fired() -> void:
	# 엄폐 중 사격 = 일시 노출. 숨어서 쏘는 리듬이 생긴다.
	if in_cover:
		exposed_time = FIRE_EXPOSURE_SECONDS


func is_exposed() -> bool:
	return in_cover and exposed_time > 0.0


func _set_in_cover(value: bool) -> void:
	if value == in_cover:
		return
	in_cover = value
	if value:
		cover_enter_count += 1
		SFX.play("cover_enter")
		if host != null and host.has_method("_show_mastery_lesson"):
			host.call("_show_mastery_lesson", "cover", "엄폐 중 — 받는 피해 45% 감소. 쏘면 잠깐 노출됩니다")
	else:
		exposed_time = 0.0
		SFX.play("cover_exit")


func _is_low_cover(blocker: Node3D) -> bool:
	# 탄막 상자(ProjectileBlocker)의 부모 기물이 projectile_collision_world_size 메타를 가진다.
	var owner_body := blocker.get_parent() as Node3D
	if owner_body != null and owner_body.has_meta("projectile_collision_world_size"):
		var size: Vector3 = owner_body.get_meta("projectile_collision_world_size")
		return size.y <= LOW_COVER_MAX_HEIGHT
	var shape := _find_box_shape(blocker)
	if shape != null:
		return (shape.shape as BoxShape3D).size.y <= LOW_COVER_MAX_HEIGHT
	return false


func _is_cover_within_reach(blocker: Node3D, hit_position: Vector3) -> bool:
	# 엄폐물 상자까지의 수평 거리(회전 상자 대응 — 상자 로컬 공간에서 잰다).
	var shape := _find_box_shape(blocker)
	if shape != null:
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var local: Vector3 = shape.global_transform.affine_inverse() * player.global_position
		var dx := maxf(0.0, absf(local.x) - size.x * 0.5)
		var dz := maxf(0.0, absf(local.z) - size.z * 0.5)
		return sqrt(dx * dx + dz * dz) <= COVER_RANGE
	var flat_hit := Vector3(hit_position.x, player.global_position.y, hit_position.z)
	return flat_hit.distance_to(player.global_position) <= COVER_RANGE + 0.5


func _find_box_shape(body: Node) -> CollisionShape3D:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null
