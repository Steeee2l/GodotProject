class_name TouchJoystick
extends Control

# 모바일 이동 조이스틱.
#
# 오프닝은 자체 구현(원형 + 노브)을 쓰고 필드/쉘터는 ColorRect 두 장을 쓰는
# 별개 위젯이었다. 조작감이 화면마다 달랐고, 필드 쪽은 손가락에 비해 작았다.
# 오프닝 쪽이 더 나았으므로 그것을 공용 위젯으로 올린다.
#
# 인덱스를 직접 추적한다. Godot의 마우스 에뮬레이션은 첫 터치만 따라가서,
# 조이스틱을 잡은 채 버튼을 누르면 그 입력이 사라진다.

signal moved(vector: Vector2)

const BASE_ALPHA := 0.62
const ACTIVE_ALPHA := 0.86

var move_vector := Vector2.ZERO
var touch_index := -1
var ring_color := Color(0.48, 0.72, 0.64, 0.82)
var knob_color := Color(0.55, 0.86, 0.73, 0.92)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.connect(_draw_stick)


func _draw_stick() -> void:
	var center := size * 0.5
	var radius := _radius()
	var active := touch_index != -1
	draw_circle(center, radius, Color(0.02, 0.04, 0.05, ACTIVE_ALPHA if active else BASE_ALPHA))
	draw_arc(center, radius, 0, TAU, 48, ring_color, 3.0, true)
	# 방향 눈금. 어디로 기울었는지 손가락에 가려도 보이게 한다.
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(
			center + direction * radius * 0.82,
			center + direction * radius * 0.96,
			Color(ring_color, 0.5),
			2.0,
			true
		)
	draw_circle(center + move_vector * radius * 0.72, radius * 0.34, knob_color)


func _radius() -> float:
	return minf(size.x, size.y) * 0.38


func contains_point(position: Vector2) -> bool:
	# 원이 아니라 사각형으로 판정한다. 가장자리를 살짝 벗어나도 잡히는 편이
	# 손가락 조작에서는 훨씬 편하다.
	return get_global_rect().has_point(position)


func begin_touch(index: int, position: Vector2) -> void:
	touch_index = index
	update_touch(position)


func update_touch(position: Vector2) -> void:
	var center := get_global_rect().get_center()
	move_vector = ((position - center) / maxf(_radius(), 1.0)).limit_length(1.0)
	moved.emit(move_vector)
	queue_redraw()


func end_touch() -> void:
	touch_index = -1
	move_vector = Vector2.ZERO
	moved.emit(move_vector)
	queue_redraw()


func handle_touch(touch: InputEventScreenTouch) -> bool:
	if touch.pressed:
		if touch_index != -1 or not contains_point(touch.position):
			return false
		begin_touch(touch.index, touch.position)
		return true
	if touch.index != touch_index:
		return false
	end_touch()
	return true


func handle_drag(drag: InputEventScreenDrag) -> bool:
	if drag.index != touch_index:
		return false
	update_touch(drag.position)
	return true
