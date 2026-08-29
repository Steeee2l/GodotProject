class_name CoverSystem
extends RefCounted

# 물리 엄폐 v2 — "숨으면 막히고, 쏘려면 내민다"의 3상태 기계.
#
# 상태(플레이어):
#   open    — 엄폐물 밖. 피해 정상.
#   covered — 낮은 엄폐물 1.2u 이내 + 공격원→플레이어 낮은 레이(0.55)가 그
#             엄폐물에 막히고 머리 레이(1.62)는 통과. 조준도 사격도 안 하는 동안.
#             효과: 그 엄폐물을 지나오는 원거리(bullet) 피해 완전 차단.
#             폭발(blast)·근접(melee)은 차단하지 않는다 — 엄폐 캠핑의 카운터.
#   peeking — 조준(우클릭/모바일 조준·사격 버튼) 유지 중이거나 사격 후 0.5s.
#             노출: 피해 ×1.0. "숨었다가 → 내밀고 → 쏘고 → 다시 숨는" 리듬.
#
# v1의 ×0.55 배율은 폐지했다 — 수치 경감은 '경험'이 안 된다(유저 진단). 차단은
# 각도 문제일 뿐이라 적이 옆으로 세 걸음이면 각이 나온다(엄폐물 HP 없음).
# 판정 인프라(방향 레이 2단 + THREAT_SCAN)는 v1 그대로 재활용, 적(enemy.gd)도
# 같은 static 판정(evaluate_cover_for)을 공유한다. 러버밴딩 없음.

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const BLOCK_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

const COVER_RANGE := 1.2
const LOW_COVER_MAX_HEIGHT := 1.7
const FIRE_EXPOSURE_SECONDS := 0.5
const LOW_RAY_HEIGHT := 0.55
const HEAD_RAY_HEIGHT := 1.62
const PLAYER_GROUND_OFFSET := 0.78
const THREAT_SCAN_RANGE := 34.0
const SCAN_INTERVAL := 0.1
# 웅크림 스쿼시 — 유저 스펙: y 0.82 + 살짝 하강, 트윈 0.12s.
const CROUCH_SCALE_Y := 0.82
const CROUCH_SINK := 0.07
const CROUCH_TWEEN_SECONDS := 0.12
# 차단 피드백 스로틀 — 연사로 스파크·라벨이 도배되지 않게.
const BLOCK_FX_THROTTLE_MSEC := 250
const ARC_COLOR_COVERED := Color("#41e0c9")
const ARC_COLOR_PEEKING := Color("#eab562")
const ARC_COLOR_ENEMY := Color("#ff5f4e")
const BLOCK_LABEL_COLOR := Color("#9fb6c9")

var host: Node
var player: CharacterBody3D
var in_cover := false
var exposed_time := 0.0
var cover_body: Node3D
var scan_timer := 0.0
var last_threat_source := Vector3.INF
# 마지막으로 차단 판정에 성공한 낮은 레이의 명중점(엄폐물 표면) — 차단 FX 위치.
var last_block_point := Vector3.INF
# 통계/프로브용.
var cover_enter_count := 0
var shots_blocked_total := 0
# 플레이어 시각 상태 — 발밑 방패 호 + 스프라이트 웅크림.
var arc_pivot: Node3D
var arc_fill: Sprite3D
var arc_outline: Sprite3D
var crouch_shown := false
var crouch_tween: Tween

static var _arc_fill_texture: Texture2D
static var _arc_outline_texture: Texture2D
static var _last_block_fx_msec := -100000


func attach(owner_node: Node) -> void:
	host = owner_node
	player = owner_node.player


func update(delta: float) -> void:
	exposed_time = maxf(0.0, exposed_time - delta)
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL
		_set_in_cover(_scan_threats())
	_update_player_visuals()


func get_state() -> String:
	if not in_cover:
		return "open"
	return "peeking" if _is_peeking() else "covered"


func _is_peeking() -> bool:
	# 별도 버튼 없음(모바일 대응) — 조준·사격 입력과 사격 후 노출 타이머가 곧 '내밈'.
	if exposed_time > 0.0:
		return true
	if host == null:
		return false
	return (
		bool(host.get("laser_aim_held"))
		or bool(host.get("fire_button_held"))
		or bool(host.get("mouse_fire_held"))
	)


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
	if player == null or not is_instance_valid(player):
		return false
	var result := CoverSystem.evaluate_cover_for(
		player,
		source_position,
		player.global_position.y - PLAYER_GROUND_OFFSET
	)
	if not bool(result.get("covered", false)):
		return false
	cover_body = result.get("blocker") as Node3D
	last_block_point = result.get("point", Vector3.INF)
	return true


func try_block_ranged(source_position: Vector3) -> bool:
	# 피격 순간 호출(총알만 — blast/melee는 호출부에서 거른다).
	# covered 상태 + 그 공격원 기준 엄폐 기하 성립 = 완전 차단.
	if source_position == Vector3.INF or get_state() != "covered":
		return false
	if not is_covered_from(source_position):
		return false
	shots_blocked_total += 1
	return true


func notify_player_fired() -> void:
	# 엄폐 중 사격 = 0.5s 노출. 숨어서 쏘는 리듬이 생긴다.
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
			host.call(
				"_show_mastery_lesson",
				"cover",
				"엄폐 중 — 엄폐물 방향의 총알이 막힙니다. 조준하면 내밀어 쏩니다"
			)
	else:
		exposed_time = 0.0
		SFX.play("cover_exit")


# ── 플레이어 시각 언어: 발밑 방패 호 + 웅크림 스쿼시 ────────────────

func _update_player_visuals() -> void:
	if player == null or not is_instance_valid(player):
		return
	var state := get_state()
	_ensure_arc_nodes()
	if state == "open":
		arc_pivot.visible = false
	else:
		arc_pivot.visible = true
		var covered := state == "covered"
		arc_fill.visible = covered
		arc_outline.visible = true
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.05
		arc_pivot.scale = Vector3.ONE * pulse
		var color := ARC_COLOR_COVERED if covered else ARC_COLOR_PEEKING
		_set_arc_color(arc_fill, Color(color, 0.68))
		_set_arc_color(arc_outline, Color(color, 1.0 if covered else 0.9))
		if is_instance_valid(cover_body):
			var toward := cover_body.global_position - player.global_position
			toward.y = 0.0
			if toward.length_squared() > 0.01:
				toward = toward.normalized()
				arc_pivot.rotation.y = atan2(-toward.z, toward.x)
	_apply_crouch(state == "covered")


func _ensure_arc_nodes() -> void:
	if arc_pivot != null and is_instance_valid(arc_pivot):
		return
	arc_pivot = Node3D.new()
	arc_pivot.name = "CoverArc"
	player.add_child(arc_pivot)
	arc_pivot.position = Vector3(0, -0.64, 0)
	arc_fill = _build_arc_mesh(arc_pivot, get_cover_arc_texture(true), "CoverArcFill")
	arc_outline = _build_arc_mesh(arc_pivot, get_cover_arc_texture(false), "CoverArcOutline")
	arc_pivot.visible = false


func _apply_crouch(active: bool) -> void:
	if active == crouch_shown:
		return
	crouch_shown = active
	var survivor := host.get("survivor") as AnimatedSprite3D
	if survivor == null or not is_instance_valid(survivor):
		return
	if crouch_tween != null and crouch_tween.is_valid():
		crouch_tween.kill()
	crouch_tween = survivor.create_tween()
	crouch_tween.set_parallel(true)
	# 스프라이트 기본값은 main.tscn — scale ONE, position (0, 0.3, 0).
	var target_scale := Vector3(1.0, CROUCH_SCALE_Y, 1.0) if active else Vector3.ONE
	var target_y := 0.3 - (CROUCH_SINK if active else 0.0)
	crouch_tween.tween_property(survivor, "scale", target_scale, CROUCH_TWEEN_SECONDS)
	crouch_tween.tween_property(survivor, "position:y", target_y, CROUCH_TWEEN_SECONDS)


static func _build_arc_mesh(parent: Node3D, texture: Texture2D, node_name: String) -> Sprite3D:
	# 바닥에 눕힌 Sprite3D(axis Y) — 강화 호출 링(enemy.gd)과 같은 문법:
	# no_depth_test + render_priority(액터 스프라이트 30보다 낮게)로 엄폐물
	# 빌보드 위에 그려지되 고양이·적 스프라이트는 가리지 않는다.
	var arc := Sprite3D.new()
	arc.name = node_name
	arc.texture = texture
	arc.axis = Vector3.AXIS_Y
	arc.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# 호 바깥 반지름 ≈ 1.05u — 발밑을 감싸되 엄폐물 스프라이트 면 위로 올라가지 않게.
	arc.pixel_size = 0.012
	arc.shaded = false
	arc.transparent = true
	arc.no_depth_test = true
	arc.render_priority = 20
	arc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	parent.add_child(arc)
	return arc


static func _set_arc_color(arc: Sprite3D, color: Color) -> void:
	arc.modulate = color


static func get_cover_arc_texture(filled: bool) -> Texture2D:
	# 엄폐물 방향으로 열린 60° 호(+X 기준 ±30°). 채움/테두리 두 장을 캐시한다.
	if filled and _arc_fill_texture != null:
		return _arc_fill_texture
	if not filled and _arc_outline_texture != null:
		return _arc_outline_texture
	var size := 192
	var center := size * 0.5
	var inner := 56.0
	var outer := 88.0
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := float(x) - center
			var dy := float(y) - center
			var radius := sqrt(dx * dx + dy * dy)
			if radius < inner - 2.0 or radius > outer + 3.0:
				continue
			var angle := absf(atan2(dy, dx))
			if angle > deg_to_rad(30.0) + 0.08:
				continue
			# 각도 가장자리 페이드.
			var angular := clampf((deg_to_rad(30.0) + 0.08 - angle) / 0.14, 0.0, 1.0)
			var alpha := 0.0
			if filled:
				var band := clampf((radius - (inner - 2.0)) / 3.0, 0.0, 1.0)
				band = minf(band, clampf(((outer + 1.0) - radius) / 3.0, 0.0, 1.0))
				# 바깥쪽으로 갈수록 진해지는 채움 — '방패'가 바깥을 향해 선다.
				alpha = band * lerpf(0.5, 1.0, clampf((radius - inner) / (outer - inner), 0.0, 1.0))
			else:
				# 테두리 — 바깥 림을 도톰하게(어두운 노면·밝은 엄폐물 양쪽에서 읽히게).
				var rim := 1.0 - clampf(absf(radius - outer) / 3.4, 0.0, 1.0)
				alpha = rim
			alpha *= angular
			if alpha <= 0.01:
				continue
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	if filled:
		_arc_fill_texture = texture
	else:
		_arc_outline_texture = texture
	return texture


# ── 공용 기하 판정 — 플레이어(위)와 적(enemy.gd)이 같은 규칙을 쓴다 ──

static func evaluate_cover_for(
	body: CollisionObject3D,
	source_position: Vector3,
	ground_y: float
) -> Dictionary:
	# {covered: bool, blocker: Node3D, point: Vector3}
	# ① 낮은 레이(0.55)가 1.2u 이내 '낮은 엄폐물'에 막히고
	# ② 머리 레이(1.62)는 통과해야 엄폐(둘 다 막히면 '가림'이지 엄폐가 아니다).
	var missed := {"covered": false, "blocker": null, "point": Vector3.INF}
	if body == null or not is_instance_valid(body) or source_position == Vector3.INF:
		return missed
	var world := body.get_world_3d()
	if world == null:
		return missed
	var space := world.direct_space_state
	var body_xz := Vector3(body.global_position.x, 0.0, body.global_position.z)
	var source_xz := Vector3(source_position.x, 0.0, source_position.z)
	if source_xz.distance_to(body_xz) < 0.2:
		return missed
	var low_query := PhysicsRayQueryParameters3D.create(
		source_xz + Vector3(0.0, ground_y + LOW_RAY_HEIGHT, 0.0),
		body_xz + Vector3(0.0, ground_y + LOW_RAY_HEIGHT, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	low_query.exclude = [body.get_rid()]
	var low_hit := space.intersect_ray(low_query)
	if low_hit.is_empty():
		return missed
	var blocker := low_hit.get("collider") as Node3D
	if blocker == null or not _is_low_cover(blocker):
		return missed
	if not _is_cover_within_reach(blocker, low_hit.get("position") as Vector3, body.global_position):
		return missed
	var head_query := PhysicsRayQueryParameters3D.create(
		source_xz + Vector3(0.0, ground_y + HEAD_RAY_HEIGHT, 0.0),
		body_xz + Vector3(0.0, ground_y + HEAD_RAY_HEIGHT, 0.0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	head_query.exclude = [body.get_rid()]
	if not space.intersect_ray(head_query).is_empty():
		return missed
	return {"covered": true, "blocker": blocker, "point": low_hit.get("position")}


static func _is_low_cover(blocker: Node3D) -> bool:
	# 탄막 상자(ProjectileBlocker)의 부모 기물이 projectile_collision_world_size 메타를 가진다.
	var owner_body := blocker.get_parent() as Node3D
	if owner_body != null and owner_body.has_meta("projectile_collision_world_size"):
		var size: Vector3 = owner_body.get_meta("projectile_collision_world_size")
		return size.y <= LOW_COVER_MAX_HEIGHT
	var shape := _find_box_shape(blocker)
	if shape != null:
		return (shape.shape as BoxShape3D).size.y <= LOW_COVER_MAX_HEIGHT
	return false


static func _is_cover_within_reach(
	blocker: Node3D,
	hit_position: Vector3,
	body_position: Vector3
) -> bool:
	# 엄폐물 상자까지의 수평 거리(회전 상자 대응 — 상자 로컬 공간에서 잰다).
	var shape := _find_box_shape(blocker)
	if shape != null:
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var local: Vector3 = shape.global_transform.affine_inverse() * body_position
		var dx := maxf(0.0, absf(local.x) - size.x * 0.5)
		var dz := maxf(0.0, absf(local.z) - size.z * 0.5)
		return sqrt(dx * dx + dz * dz) <= COVER_RANGE
	var flat_hit := Vector3(hit_position.x, body_position.y, hit_position.z)
	return flat_hit.distance_to(body_position) <= COVER_RANGE + 0.5


static func _find_box_shape(body: Node) -> CollisionShape3D:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null


# ── 차단 피드백 — 스파크 + "막힘" 미니 라벨(0.25s 스로틀) ────────────

static func spawn_block_fx(context: Node, point: Vector3) -> void:
	# 피해 숫자가 아니다 — 회청색 소형 라벨. 어디서 막혔는지(엄폐물 윗면)를 보여 준다.
	if context == null or not context.is_inside_tree() or point == Vector3.INF:
		return
	var now := Time.get_ticks_msec()
	if now - _last_block_fx_msec < BLOCK_FX_THROTTLE_MSEC:
		return
	_last_block_fx_msec = now
	var tree := context.get_tree()
	var parent := context.get_tree().current_scene if tree != null else null
	if parent == null:
		parent = context
	var fx := Node3D.new()
	fx.name = "CoverBlockFx"
	parent.add_child(fx)
	fx.global_position = point + Vector3(0.0, 0.22, 0.0)
	# 스파크 — 총구 화염풍 구 플래시 + 퍼지는 링(bullet_projectile 임팩트 재활용 스타일).
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(0.78, 0.9, 1.0, 0.9)
	flash_material.emission_enabled = true
	flash_material.emission = Color("#bfe2ff")
	flash_material.emission_energy_multiplier = 5.0
	flash_material.no_depth_test = true
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.09
	flash_mesh.height = 0.18
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	flash_mesh.material = flash_material
	var flash := MeshInstance3D.new()
	flash.name = "BlockSpark"
	flash.mesh = flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(flash)
	var ring_material := flash_material.duplicate() as StandardMaterial3D
	ring_material.albedo_color = Color(0.62, 0.76, 0.86, 0.7)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.06
	ring_mesh.outer_radius = 0.11
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 8
	ring_mesh.material = ring_material
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(ring)
	# "막힘" 라벨 — 12px 상당(pixel_size 축소), 회청색, 0.4s 페이드.
	var label := Label3D.new()
	label.name = "BlockLabel"
	label.text = "막힘"
	label.font = BLOCK_FONT
	label.font_size = 36
	label.pixel_size = 0.0062
	label.modulate = BLOCK_LABEL_COLOR
	label.outline_size = 8
	label.outline_modulate = Color(0.05, 0.09, 0.12, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.26, 0.0)
	fx.add_child(label)
	var tween := fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, 0.16)
	tween.tween_property(ring, "scale", Vector3.ONE * 2.8, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.2)
	tween.tween_property(label, "position:y", 0.55, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	if tree != null:
		tree.create_timer(0.45).timeout.connect(fx.queue_free)


static func build_cover_arc_indicator(parent: Node3D, feet_offset_y: float) -> Node3D:
	# 적 발밑 붉은 호(enemy.gd가 쓴다) — 플레이어와 같은 텍스처, 색만 다르다.
	var pivot := Node3D.new()
	pivot.name = "EnemyCoverArc"
	parent.add_child(pivot)
	pivot.position = Vector3(0.0, feet_offset_y, 0.0)
	var fill := _build_arc_mesh(pivot, get_cover_arc_texture(true), "Fill")
	var outline := _build_arc_mesh(pivot, get_cover_arc_texture(false), "Outline")
	# 적 호는 살짝 더 크게 — 웅크린 적 스프라이트가 호 중심부를 가리기 때문.
	fill.pixel_size = 0.0135
	outline.pixel_size = 0.0135
	_set_arc_color(fill, Color(ARC_COLOR_ENEMY, 0.7))
	_set_arc_color(outline, Color(ARC_COLOR_ENEMY, 1.0))
	pivot.visible = false
	return pivot
