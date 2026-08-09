class_name UiIconFactory
extends RefCounted

static var _cache: Dictionary = {}
const GENERATED_CURRENCY_PATHS := {
	"scrap": "res://assets/ui/currency/scrap.png",
	"catnip": "res://assets/ui/currency/catnip.png",
	"food": "res://assets/ui/currency/canned_food.png",
	"churu": "res://assets/ui/currency/churu.png",
	# 원자재는 정제 자원과 같은 아이콘을 쓰되 색으로 구분한다.
	"raw_scrap": "res://assets/ui/currency/scrap.png",
	"raw_catnip": "res://assets/ui/currency/catnip.png",
}
const GENERATED_ITEM_ICON_PATHS := {
	"medkit": "res://assets/generated/p0_sliced/item_icons/medkit.png",
	"ammo": "res://assets/generated/p0_sliced/item_icons/ammo_box.png",
	"parts": "res://assets/generated/p0_sliced/item_icons/scrap_bundle.png",
}


static func get_icon(icon_name: String, size := 64, color := Color("#d9e3dc")) -> Texture2D:
	var key := "%s:%d:%s" % [icon_name, size, color.to_html()]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var generated_path := str(GENERATED_CURRENCY_PATHS.get(icon_name, ""))
	if generated_path.is_empty():
		generated_path = str(GENERATED_ITEM_ICON_PATHS.get(icon_name, ""))
	if not generated_path.is_empty() and ResourceLoader.exists(generated_path):
		var generated_texture := load(generated_path) as Texture2D
		if generated_texture != null:
			_cache[key] = generated_texture
			return generated_texture
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var scale := float(size) / 64.0
	match icon_name:
		"backpack":
			_rect(image, Rect2i(_p(15, 18, scale), _p(34, 35, scale)), color)
			_rect(image, Rect2i(_p(20, 12, scale), _p(24, 9, scale)), color.darkened(0.18))
			_rect(image, Rect2i(_p(20, 29, scale), _p(24, 5, scale)), color.darkened(0.28))
			_rect(image, Rect2i(_p(9, 25, scale), _p(7, 23, scale)), color.darkened(0.25))
			_rect(image, Rect2i(_p(48, 25, scale), _p(7, 23, scale)), color.darkened(0.25))
		"close":
			_line(image, _v(17, 17, scale), _v(47, 47, scale), color, 4.5 * scale)
			_line(image, _v(47, 17, scale), _v(17, 47, scale), color, 4.5 * scale)
		"check":
			_line(image, _v(12, 33, scale), _v(27, 48, scale), color, 6.0 * scale)
			_line(image, _v(27, 48, scale), _v(53, 17, scale), color, 6.0 * scale)
		"weapon":
			_line(image, _v(10, 38, scale), _v(51, 23, scale), color, 5.0 * scale)
			_rect(image, Rect2i(_p(16, 35, scale), _p(18, 7, scale)), color.darkened(0.18))
			_line(image, _v(33, 34, scale), _v(39, 47, scale), color, 4.0 * scale)
		"ammo":
			for offset in [0, 12, 24]:
				_rect(image, Rect2i(_p(14 + offset, 15, scale), _p(8, 34, scale)), color)
				_rect(image, Rect2i(_p(13 + offset, 45, scale), _p(10, 6, scale)), color.darkened(0.24))
		"health":
			_circle(image, _v(21, 24, scale), 11.0 * scale, color)
			_circle(image, _v(43, 24, scale), 11.0 * scale, color)
			_polygon_fill(image, [_v(10, 27, scale), _v(54, 27, scale), _v(32, 56, scale)], color)
		"medkit":
			_rect(image, Rect2i(_p(10, 15, scale), _p(44, 38, scale)), color)
			_rect(image, Rect2i(_p(23, 9, scale), _p(18, 9, scale)), color.darkened(0.18))
			_rect(image, Rect2i(_p(28, 22, scale), _p(8, 25, scale)), Color("#f4eee2"))
			_rect(image, Rect2i(_p(20, 30, scale), _p(24, 8, scale)), Color("#f4eee2"))
		"reload":
			_circle_outline(image, _v(32, 32, scale), 21.0 * scale, color, 5.0 * scale)
			_polygon_fill(image, [_v(47, 9, scale), _v(56, 26, scale), _v(38, 24, scale)], color)
		"grenade":
			_circle(image, _v(31, 37, scale), 17.0 * scale, color)
			_rect(image, Rect2i(_p(25, 12, scale), _p(14, 10, scale)), color.darkened(0.2))
			_line(image, _v(38, 15, scale), _v(49, 8, scale), color, 4.0 * scale)
		"alert":
			_polygon_fill(image, [_v(32, 6, scale), _v(59, 55, scale), _v(5, 55, scale)], color)
			_rect(image, Rect2i(_p(29, 20, scale), _p(6, 19, scale)), color.darkened(0.55))
			_circle(image, _v(32, 47, scale), 3.5 * scale, color.darkened(0.55))
		"armor":
			_polygon_fill(image, [_v(32, 8, scale), _v(52, 17, scale), _v(47, 45, scale), _v(32, 57, scale), _v(17, 45, scale), _v(12, 17, scale)], color)
			_polygon_fill(image, [_v(32, 16, scale), _v(43, 21, scale), _v(40, 39, scale), _v(32, 47, scale)], color.darkened(0.25))
		"helmet":
			_circle(image, _v(32, 32, scale), 22.0 * scale, color)
			_rect(image, Rect2i(_p(8, 32, scale), _p(48, 24, scale)), Color.TRANSPARENT)
			_rect(image, Rect2i(_p(8, 34, scale), _p(48, 8, scale)), color.darkened(0.25))
		"footwear":
			_polygon_fill(image, [
				_v(17, 9, scale),
				_v(37, 9, scale),
				_v(39, 35, scale),
				_v(55, 43, scale),
				_v(55, 53, scale),
				_v(12, 53, scale),
				_v(9, 43, scale),
				_v(18, 34, scale),
			], color)
			_rect(image, Rect2i(_p(12, 48, scale), _p(43, 7, scale)), color.darkened(0.25))
		"secure":
			_rect(image, Rect2i(_p(14, 26, scale), _p(36, 29, scale)), color)
			_circle_outline(image, _v(32, 27, scale), 14.0 * scale, color, 5.0 * scale)
			_circle(image, _v(32, 39, scale), 4.0 * scale, color.darkened(0.35))
		"accessory":
			_polygon_fill(image, [_v(32, 7, scale), _v(39, 24, scale), _v(57, 25, scale), _v(43, 37, scale), _v(48, 55, scale), _v(32, 45, scale), _v(16, 55, scale), _v(21, 37, scale), _v(7, 25, scale), _v(25, 24, scale)], color)
		"all":
			for y in [10, 35]:
				for x in [10, 35]:
					_rect(image, Rect2i(_p(x, y, scale), _p(19, 19, scale)), color)
		"resource", "food":
			_rect(image, Rect2i(_p(18, 12, scale), _p(28, 42, scale)), color)
			_rect(image, Rect2i(_p(16, 10, scale), _p(32, 7, scale)), color.lightened(0.16))
			_rect(image, Rect2i(_p(16, 49, scale), _p(32, 7, scale)), color.darkened(0.22))
			_circle(image, _v(32, 33, scale), 8.0 * scale, color.darkened(0.3))
		"mod", "parts":
			_circle_outline(image, _v(32, 32, scale), 20.0 * scale, color, 8.0 * scale)
			_circle(image, _v(32, 32, scale), 7.0 * scale, color.darkened(0.28))
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				_line(image, _v(32, 32, scale) + direction * 18.0 * scale, _v(32, 32, scale) + direction * 27.0 * scale, color, 5.0 * scale)
		"craft", "workbench":
			_line(image, _v(15, 48, scale), _v(47, 16, scale), color, 6.0 * scale)
			_circle_outline(image, _v(46, 17, scale), 10.0 * scale, color, 5.0 * scale)
			_rect(image, Rect2i(_p(10, 43, scale), _p(16, 10, scale)), color.darkened(0.2))
		"repair":
			_line(image, _v(16, 49, scale), _v(46, 19, scale), color, 7.0 * scale)
			_circle_outline(image, _v(47, 18, scale), 11.0 * scale, color, 5.0 * scale)
		"upgrade":
			_polygon_fill(image, [_v(32, 8, scale), _v(53, 31, scale), _v(41, 31, scale), _v(41, 55, scale), _v(23, 55, scale), _v(23, 31, scale), _v(11, 31, scale)], color)
		"collect":
			_line(image, _v(32, 8, scale), _v(32, 39, scale), color, 6.0 * scale)
			_polygon_fill(image, [_v(19, 30, scale), _v(32, 46, scale), _v(45, 30, scale)], color)
			_rect(image, Rect2i(_p(12, 48, scale), _p(40, 7, scale)), color.darkened(0.2))
		"resident":
			_polygon_fill(image, [_v(12, 23, scale), _v(16, 8, scale), _v(27, 18, scale), _v(37, 18, scale), _v(48, 8, scale), _v(52, 23, scale), _v(48, 48, scale), _v(32, 57, scale), _v(16, 48, scale)], color)
			_circle(image, _v(25, 31, scale), 3.0 * scale, color.darkened(0.45))
			_circle(image, _v(39, 31, scale), 3.0 * scale, color.darkened(0.45))
		"catnip":
			_polygon_fill(image, [_v(12, 45, scale), _v(25, 12, scale), _v(52, 8, scale), _v(47, 35, scale), _v(20, 52, scale)], color)
			_line(image, _v(14, 54, scale), _v(43, 19, scale), color.darkened(0.3), 3.0 * scale)
		"scrap":
			_circle_outline(image, _v(32, 32, scale), 20.0 * scale, color, 7.0 * scale)
			_rect(image, Rect2i(_p(28, 6, scale), _p(8, 52, scale)), color)
			_rect(image, Rect2i(_p(6, 28, scale), _p(52, 8, scale)), color)
		"churu":
			_polygon_fill(image, [_v(20, 8, scale), _v(44, 8, scale), _v(39, 55, scale), _v(25, 55, scale)], color)
			_rect(image, Rect2i(_p(18, 7, scale), _p(28, 7, scale)), color.lightened(0.2))
		"time":
			_circle_outline(image, _v(32, 32, scale), 23.0 * scale, color, 5.0 * scale)
			_line(image, _v(32, 32, scale), _v(32, 17, scale), color, 4.0 * scale)
			_line(image, _v(32, 32, scale), _v(44, 38, scale), color, 4.0 * scale)
		"interact":
			_circle_outline(image, _v(32, 32, scale), 21.0 * scale, color, 5.0 * scale)
			_circle(image, _v(32, 32, scale), 6.0 * scale, color)
			_line(image, _v(32, 5, scale), _v(32, 14, scale), color, 4.0 * scale)
			_line(image, _v(32, 50, scale), _v(32, 59, scale), color, 4.0 * scale)
		"dash":
			_polygon_fill(image, [_v(13, 15, scale), _v(43, 32, scale), _v(13, 49, scale), _v(22, 32, scale)], color)
			_line(image, _v(39, 14, scale), _v(54, 14, scale), color, 4.0 * scale)
			_line(image, _v(44, 25, scale), _v(58, 25, scale), color, 4.0 * scale)
		"flashlight":
			_rect(image, Rect2i(_p(9, 24, scale), _p(24, 17, scale)), color)
			_rect(image, Rect2i(_p(29, 19, scale), _p(12, 27, scale)), color.darkened(0.16))
			_polygon_fill(image, [_v(40, 18, scale), _v(59, 8, scale), _v(59, 56, scale), _v(40, 46, scale)], Color(color.r, color.g, color.b, 0.48))
			_line(image, _v(14, 29, scale), _v(14, 36, scale), color.lightened(0.2), 3.0 * scale)
		"map":
			_polygon_fill(image, [_v(7, 12, scale), _v(24, 7, scale), _v(40, 13, scale), _v(57, 8, scale), _v(57, 52, scale), _v(40, 57, scale), _v(24, 51, scale), _v(7, 56, scale)], color)
			_line(image, _v(24, 8, scale), _v(24, 51, scale), color.darkened(0.28), 3.0 * scale)
			_line(image, _v(40, 13, scale), _v(40, 56, scale), color.darkened(0.28), 3.0 * scale)
		"loot":
			_rect(image, Rect2i(_p(10, 22, scale), _p(44, 31, scale)), color)
			_rect(image, Rect2i(_p(15, 13, scale), _p(34, 12, scale)), color.lightened(0.12))
			_rect(image, Rect2i(_p(28, 28, scale), _p(8, 13, scale)), color.darkened(0.35))
		"health":
			_polygon_fill(image, [_v(32, 55, scale), _v(11, 35, scale), _v(11, 20, scale), _v(20, 11, scale), _v(32, 20, scale), _v(44, 11, scale), _v(53, 20, scale), _v(53, 35, scale)], color)
		"stamina":
			_polygon_fill(image, [_v(36, 6, scale), _v(14, 35, scale), _v(29, 35, scale), _v(25, 58, scale), _v(51, 27, scale), _v(36, 27, scale)], color)
		"speed":
			_line(image, _v(8, 22, scale), _v(30, 22, scale), color.darkened(0.2), 4.0 * scale)
			_line(image, _v(5, 34, scale), _v(27, 34, scale), color.darkened(0.2), 4.0 * scale)
			_line(image, _v(10, 46, scale), _v(30, 46, scale), color.darkened(0.2), 4.0 * scale)
			_polygon_fill(image, [_v(28, 10, scale), _v(58, 32, scale), _v(28, 54, scale), _v(37, 32, scale)], color)
		"recovery":
			_circle_outline(image, _v(32, 32, scale), 21.0 * scale, color, 5.0 * scale)
			_polygon_fill(image, [_v(8, 26, scale), _v(23, 13, scale), _v(23, 34, scale)], color)
		"fitness":
			_rect(image, Rect2i(_p(8, 26, scale), _p(48, 12, scale)), color)
			_rect(image, Rect2i(_p(5, 18, scale), _p(8, 28, scale)), color.darkened(0.15))
			_rect(image, Rect2i(_p(51, 18, scale), _p(8, 28, scale)), color.darkened(0.15))
			_rect(image, Rect2i(_p(14, 22, scale), _p(7, 20, scale)), color.lightened(0.08))
			_rect(image, Rect2i(_p(43, 22, scale), _p(7, 20, scale)), color.lightened(0.08))
		"melee":
			_line(image, _v(14, 49, scale), _v(46, 17, scale), color, 8.0 * scale)
			_rect(image, Rect2i(_p(9, 46, scale), _p(15, 8, scale)), color.darkened(0.24))
		"mouse_left":
			_capsule_outline(image, _v(32, 32, scale), 34.0 * scale, 52.0 * scale, color, 4.0 * scale)
			_line(image, _v(32, 7, scale), _v(32, 31, scale), color, 3.0 * scale)
			_line(image, _v(16, 31, scale), _v(48, 31, scale), color, 3.0 * scale)
			_polygon_fill(image, [
				_v(18, 16, scale),
				_v(29, 10, scale),
				_v(29, 28, scale),
				_v(18, 28, scale),
			], Color(color.r, color.g, color.b, 0.42))
		"up":
			_polygon_fill(image, [_v(32, 8, scale), _v(52, 34, scale), _v(40, 34, scale), _v(40, 56, scale), _v(24, 56, scale), _v(24, 34, scale), _v(12, 34, scale)], color)
		"down":
			_polygon_fill(image, [_v(32, 56, scale), _v(52, 30, scale), _v(40, 30, scale), _v(40, 8, scale), _v(24, 8, scale), _v(24, 30, scale), _v(12, 30, scale)], color)
		"raid":
			_polygon_fill(image, [_v(8, 32, scale), _v(34, 10, scale), _v(34, 23, scale), _v(57, 23, scale), _v(57, 41, scale), _v(34, 41, scale), _v(34, 54, scale)], color)
		_:
			_circle_outline(image, _v(32, 32, scale), 22.0 * scale, color, 6.0 * scale)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _p(x: float, y: float, scale: float) -> Vector2i:
	return Vector2i(roundi(x * scale), roundi(y * scale))


static func _v(x: float, y: float, scale: float) -> Vector2:
	return Vector2(x * scale, y * scale)


static func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(maxi(0, rect.position.y), mini(image.get_height(), rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(image.get_width(), rect.end.x)):
			image.set_pixel(x, y, color)


static func _circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(image.get_width() - 1, ceili(center.x + radius))
	var min_y := maxi(0, floori(center.y - radius))
	var max_y := mini(image.get_height() - 1, ceili(center.y + radius))
	var radius_squared := radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x, y).distance_squared_to(center) <= radius_squared:
				image.set_pixel(x, y, color)


static func _circle_outline(image: Image, center: Vector2, radius: float, color: Color, thickness: float) -> void:
	_circle(image, center, radius, color)
	_circle(image, center, maxf(0.0, radius - thickness), Color(0, 0, 0, 0))
	var inner := maxf(0.0, radius - thickness)
	var min_x := maxi(0, floori(center.x - inner))
	var max_x := mini(image.get_width() - 1, ceili(center.x + inner))
	var min_y := maxi(0, floori(center.y - inner))
	var max_y := mini(image.get_height() - 1, ceili(center.y + inner))
	var inner_squared := inner * inner
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x, y).distance_squared_to(center) <= inner_squared:
				image.set_pixel(x, y, Color.TRANSPARENT)


static func _capsule_outline(
	image: Image,
	center: Vector2,
	width: float,
	height: float,
	color: Color,
	thickness: float
) -> void:
	var radius := width * 0.5
	var inner_radius := maxf(0.0, radius - thickness)
	var segment_half := maxf(0.0, (height - width) * 0.5)
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(image.get_width() - 1, ceili(center.x + radius))
	var min_y := maxi(0, floori(center.y - height * 0.5))
	var max_y := mini(image.get_height() - 1, ceili(center.y + height * 0.5))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(x, y)
			var closest_y := clampf(point.y, center.y - segment_half, center.y + segment_half)
			var distance := point.distance_to(Vector2(center.x, closest_y))
			if distance <= radius and distance >= inner_radius:
				image.set_pixel(x, y, color)


static func _line(image: Image, from: Vector2, to: Vector2, color: Color, thickness: float) -> void:
	var steps := maxi(1, ceili(from.distance_to(to)))
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / float(steps))
		_circle(image, point, thickness * 0.5, color)


static func _polygon_fill(image: Image, points: Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_y := image.get_height() - 1
	var max_y := 0
	for point_variant in points:
		var point: Vector2 = point_variant
		min_y = mini(min_y, floori(point.y))
		max_y = maxi(max_y, ceili(point.y))
	for y in range(maxi(0, min_y), mini(image.get_height() - 1, max_y) + 1):
		var intersections: Array[float] = []
		for index in points.size():
			var a: Vector2 = points[index]
			var b: Vector2 = points[(index + 1) % points.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(a.x + (float(y) - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for index in range(0, intersections.size() - 1, 2):
			for x in range(maxi(0, ceili(intersections[index])), mini(image.get_width() - 1, floori(intersections[index + 1])) + 1):
				image.set_pixel(x, y, color)
