class_name VehicleFootprint
extends RefCounted

# 차량·엄폐물의 '접지 사각형(footprint)'을 계산하는 단 하나의 헬퍼.
#
# 왜 하나로 모았나 —
#   오프닝(opening_sequence), 필드 차량(procedural_map._spawn_vehicle), 도로 엄폐물
#   (procedural_map._spawn_road_cover_obstacle)이 각자 다른 방식으로 스프라이트와
#   충돌 상자를 맞추고 있었다. 그 결과 오프닝의 택시·트럭·버스는 충돌 영역이
#   그림보다 작고 엉뚱한 곳에 놓였다. 이제 셋 다 이 파일의 규칙만 쓴다.
#
# 규칙 —
#   1) 스프라이트는 BILLBOARD_ENABLED 다. 빌보드는 셰이더에서 노드 basis 를 통째로
#      카메라 basis 로 갈아끼우므로 **노드 회전(rotation.z / rotation.y)은 화면에
#      전혀 반영되지 않는다.** 그래서 "스프라이트를 화면에서 기울였으니 충돌 상자도
#      월드에서 돌린다"는 접근은 원리적으로 성립하지 않는다. 아트가 그려진 축을
#      그대로 쓰고, 충돌 상자는 축정렬(yaw=0) 상태로 x/z 크기만 바꿔 맞춘다.
#   2) 아트의 접지면은 footprint_corners_px(원본 아트 픽셀 좌표, [서, 북, 동, 남])로
#      기술한다. 이 네 점이 곧 "그림이 땅을 딛는 자리"다.
#   3) 스프라이트 크기(pixel_size)는 충돌 상자의 접지 폭에서 유도한다.
#      아이소메트릭에서 (x+z) 크기의 접지면은 화면에서 (x+z)/√2 만큼 가로로 퍼진다.
#      카메라 높이와 무관한 값이라 오프닝(10.5,12.5,10.5)과 필드(1,1,1) 모두에서 같다.
#   4) 접지면 중심이 몸통 원점에 오도록 sprite.offset 으로 화면 공간에서 민다.
#      월드 Y 로 스프라이트를 띄우면(과거 오프닝 방식) 화면 위 이동량이 Y×0.8 로
#      줄어들어 반드시 어긋난다. 보정은 반드시 화면 공간(offset)에서 해야 한다.

const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

# 월드 X·Z 가 화면 가로축에 맺히는 성분. 카메라가 XZ 대각선 위에 있으면
# (1,1,1)이든 (10.5,12.5,10.5)든 항상 cos45° 다 — 그래서 상수로 둔다.
const GROUND_SCREEN_RIGHT := 0.7071067811865476

# 알파 실루엣 측정 결과 캐시(텍스처 경로 → Dictionary).
static var _silhouette_cache: Dictionary = {}


static func art_long_axis(definition: Dictionary) -> String:
	# 아트가 그려진 방향. 기본은 "z"(긴 축이 월드 +Z 로 뻗는 그림).
	return str(definition.get("art_axis", "z"))


static func should_flip(definition: Dictionary, along_z: bool) -> bool:
	# 원하는 월드 축과 아트의 축이 다를 때만 좌우 반전한다. 아이소메트릭에서
	# 좌우 반전은 화면 대각선 두 방향을 맞바꾸므로 긴 축이 X↔Z 로 옮겨간다.
	var art_axis := art_long_axis(definition)
	return (art_axis == "z") != along_z


static func world_collision_size(definition: Dictionary, along_z: bool, scale: float = 1.0) -> Vector3:
	# 카탈로그의 collision_size 는 (길이, 높이, 너비) — 길이가 아트의 긴 축이다.
	var base: Vector3 = definition.get("collision_size", Vector3(4.0, 1.4, 1.8))
	var sized := Vector3(base.z, base.y, base.x) if along_z else base
	return sized * scale if not is_equal_approx(scale, 1.0) else sized


static func texture_space_corners(definition: Dictionary, texture: Texture2D) -> Array[Vector2]:
	# 발자국 좌표를 런타임 텍스처 크기로 보정한다(임포트 size_limit 로 줄어든 텍스처 대응).
	var result: Array[Vector2] = []
	if texture == null:
		return result
	var raw_corners: Array = definition.get("footprint_corners_px", [])
	var source_size: Vector2i = definition.get(
		"source_size",
		Vector2i(texture.get_width(), texture.get_height())
	)
	var coordinate_scale := Vector2.ONE
	if source_size.x > 0 and source_size.y > 0:
		coordinate_scale = Vector2(
			float(texture.get_width()) / float(source_size.x),
			float(texture.get_height()) / float(source_size.y)
		)
	for corner_variant in raw_corners:
		var corner: Vector2 = corner_variant
		result.append(corner * coordinate_scale)
	return result


static func centroid(corners: Array) -> Vector2:
	if corners.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for corner_variant in corners:
		total += corner_variant as Vector2
	return total / float(corners.size())


static func projected_ground_width(collision_size: Vector3) -> float:
	# 접지면(x × z)이 화면에서 차지하는 가로 폭(m).
	return (collision_size.x + collision_size.z) / sqrt(2.0)


static func measure(
	definition: Dictionary,
	texture: Texture2D,
	collision_size: Vector3,
	flip_h: bool
) -> Dictionary:
	# 스프라이트에 그대로 꽂아 넣을 값들을 돌려준다.
	var corners := texture_space_corners(definition, texture)
	if texture == null or corners.size() < 4:
		return {
			"valid": false,
			"pixel_size": float(definition.get("pixel_size", 0.007)),
			"offset": Vector2.ZERO,
			"corners": corners,
			"centroid": Vector2.ZERO,
		}
	var base_pixel_width := maxf(1.0, absf(corners[2].x - corners[0].x))
	var pixel_size := projected_ground_width(collision_size) / base_pixel_width
	var footprint_center := centroid(corners)
	var offset := Vector2(
		texture.get_width() * 0.5 - footprint_center.x,
		texture.get_height() * 0.5 - footprint_center.y
	)
	if flip_h:
		offset.x = -offset.x
	return {
		"valid": true,
		"pixel_size": pixel_size,
		"offset": offset,
		"corners": corners,
		"centroid": footprint_center,
	}


static func apply_to_sprite(
	sprite: Sprite3D,
	definition: Dictionary,
	collision_size: Vector3,
	flip_h: bool,
	ground_local_y: float
) -> Dictionary:
	# 스프라이트 한 장을 접지면에 정확히 세운다. 세 호출처(오프닝·필드 차량·엄폐물)가
	# 전부 이 함수만 쓴다.
	var result := measure(definition, sprite.texture, collision_size, flip_h)
	sprite.pixel_size = float(result["pixel_size"])
	if bool(result["valid"]):
		sprite.offset = result["offset"] as Vector2
	sprite.flip_h = flip_h
	# 스프라이트 원점을 지면에 둔다. 접지면 중심 보정은 offset(화면 공간)이 이미 했다.
	sprite.position = Vector3(0.0, ground_local_y + 0.02, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	return result


# ── 검증용 ────────────────────────────────────────────────────────────

static func ground_screen_up(camera: Camera3D) -> float:
	# 월드 +Y 1m 가 화면에서 올라가는 양(m). 카메라 각도에 따라 다르다
	# (필드 (1,1,1)=0.8165, 오프닝 (10.5,12.5,10.5)=0.765).
	if camera == null:
		return 0.8164965809277261
	return maxf(0.05, camera.global_transform.basis.y.dot(Vector3.UP))


static func ground_screen_depth(camera: Camera3D) -> float:
	# 월드 +X(또는 +Z) 1m 가 화면에서 내려오는 양(m).
	if camera == null:
		return 0.4082482904638631
	return absf(camera.global_transform.basis.y.dot(Vector3.RIGHT))


static func screen_offset_to_ground(offset: Vector2, screen_depth: float) -> Vector2:
	# 지면 위에 있다고 알고 있는 화면 오프셋(오른쪽+, 위+)을 월드 (x, z) 로 되돌린다.
	#   offset.x =  right * (dx - dz)
	#   offset.y = -depth * (dx + dz)
	var sum := -offset.y / maxf(0.0001, screen_depth)
	var diff := offset.x / GROUND_SCREEN_RIGHT
	return Vector2((diff + sum) * 0.5, (sum - diff) * 0.5)


static func visual_footprint_from_sprite(
	sprite: Sprite3D,
	definition: Dictionary,
	camera: Camera3D
) -> Dictionary:
	# 스프라이트 '실물'에서 접지 사각형을 다시 재어 월드 XZ AABB 로 돌려준다.
	# 충돌 상자와 비교하는 프로브가 쓴다 — 카탈로그 숫자가 아니라 실제로 화면에
	# 그려지는 픽셀 위치에서 출발한다.
	var corners := texture_space_corners(definition, sprite.texture)
	if sprite.texture == null or corners.size() < 4:
		return {"valid": false}
	var pixel_size := sprite.pixel_size
	var half := Vector2(sprite.texture.get_width() * 0.5, sprite.texture.get_height() * 0.5)
	var screen_depth := ground_screen_depth(camera)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in corners:
		var local_x := (corner.x - half.x + sprite.offset.x) * pixel_size
		if sprite.flip_h:
			local_x = -(corner.x - half.x - sprite.offset.x) * pixel_size
		var local_y := -(corner.y - half.y + sprite.offset.y) * pixel_size
		var ground := screen_offset_to_ground(Vector2(local_x, local_y), screen_depth)
		minimum = minimum.min(ground)
		maximum = maximum.max(ground)
	return {
		"valid": true,
		"center": (minimum + maximum) * 0.5,
		"size": maximum - minimum,
	}


static func silhouette_ground_bounds(texture: Texture2D) -> Dictionary:
	# 알파 실루엣의 가로 폭(px)과 바닥 여백. 발자국 좌표가 아예 없는 텍스처의
	# 보정 근거이자, 카탈로그 값이 아트에서 얼마나 벗어났는지 재는 자다.
	if texture == null:
		return {"valid": false}
	var cache_key := texture.resource_path
	if not cache_key.is_empty() and _silhouette_cache.has(cache_key):
		return _silhouette_cache[cache_key]
	var image := texture.get_image()
	if image == null or image.is_compressed():
		var missing := {"valid": false}
		if not cache_key.is_empty():
			_silhouette_cache[cache_key] = missing
		return missing
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var max_x := -1
	var min_y := height
	var max_y := -1
	for row in range(0, height, 2):
		for column in range(0, width, 2):
			if image.get_pixel(column, row).a <= 0.04:
				continue
			min_x = mini(min_x, column)
			max_x = maxi(max_x, column)
			min_y = mini(min_y, row)
			max_y = maxi(max_y, row)
	var measured := {"valid": max_x >= min_x and max_y >= min_y}
	if bool(measured["valid"]):
		measured["min"] = Vector2(min_x, min_y)
		measured["max"] = Vector2(max_x, max_y)
		measured["width_px"] = float(max_x - min_x)
		measured["height_px"] = float(max_y - min_y)
		measured["bottom_padding_px"] = float(height - 1 - max_y)
	if not cache_key.is_empty():
		_silhouette_cache[cache_key] = measured
	return measured
