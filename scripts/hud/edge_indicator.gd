class_name EdgeIndicator
extends RefCounted

# 화면 가장자리 방향 인디케이터 — 월드의 한 지점을 향해 화살표+거리 라벨을 띄운다.
# 대상이 화면 안이면 머리 위에서 아래로 가리키고, 밖이면 가장자리에 붙어 방향을
# 가리킨다. 주홍 무전기(청록)와 다음 임무 지점 핑(골드)이 같은 문법을 쓴다.
#
# 안전 여백: 상단 HUD(구역 정보·임무 카드)와 하단 버튼 밴드를 침범하지 않도록
# 클램프 영역을 화면 안쪽으로 크게 잡는다 — 우상단 구역 텍스트를 덮던 사고의 재발 방지.

const ACTIVE_TUTORIAL := preload("res://scripts/shelter/active_tutorial.gd")
const LABEL_FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

const ARROW_SIZE := 26.0
const MARGIN_SIDE := 70.0
const MARGIN_TOP := 130.0
const MARGIN_BOTTOM := 160.0

var host: Node
var layer: CanvasLayer
var arrow: Control
var label: Label
var accent := Color.WHITE


static func create(owner_node: Node, accent_color: Color, layer_index: int = 88) -> EdgeIndicator:
	var indicator := EdgeIndicator.new()
	indicator.host = owner_node
	indicator.accent = accent_color
	indicator.layer = CanvasLayer.new()
	indicator.layer.name = "EdgeIndicatorLayer"
	indicator.layer.layer = layer_index
	owner_node.add_child(indicator.layer)
	indicator.arrow = ACTIVE_TUTORIAL.TutorialArrow.new()
	indicator.arrow.name = "EdgeArrow"
	indicator.arrow.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	indicator.arrow.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	indicator.arrow.modulate = accent_color
	indicator.arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.layer.add_child(indicator.arrow)
	indicator.label = Label.new()
	indicator.label.name = "EdgeLabel"
	indicator.label.add_theme_font_override("font", LABEL_FONT)
	indicator.label.add_theme_font_size_override("font_size", 13)
	indicator.label.add_theme_color_override("font_color", accent_color)
	indicator.label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
	indicator.label.add_theme_constant_override("outline_size", 7)
	indicator.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.layer.add_child(indicator.label)
	indicator.layer.visible = false
	return indicator


func is_valid() -> bool:
	return layer != null and is_instance_valid(layer)


func hide() -> void:
	if is_valid():
		layer.visible = false


func point_at(world_position: Vector3, text: String) -> void:
	if not is_valid() or host == null or not is_instance_valid(host):
		return
	var camera: Camera3D = host.get_viewport().get_camera_3d()
	if camera == null:
		layer.visible = false
		return
	layer.visible = true
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var anchor: Vector3 = world_position + Vector3(0, 1.2, 0)
	var behind := camera.is_position_behind(anchor)
	var screen_point := camera.unproject_position(anchor)
	var center := viewport_size * 0.5
	if behind:
		screen_point = center + (center - screen_point)
	var safe_rect := Rect2(
		Vector2(MARGIN_SIDE, MARGIN_TOP),
		viewport_size - Vector2(MARGIN_SIDE * 2.0, MARGIN_TOP + MARGIN_BOTTOM)
	)
	var on_screen := not behind and safe_rect.has_point(screen_point)
	var direction := Vector2.DOWN
	var arrow_center := screen_point + Vector2(0.0, -34.0)
	if not on_screen:
		var to_target := screen_point - center
		if to_target.length_squared() < 1.0:
			to_target = Vector2.DOWN
		direction = to_target.normalized()
		arrow_center = Vector2(
			clampf(screen_point.x, safe_rect.position.x, safe_rect.end.x),
			clampf(screen_point.y, safe_rect.position.y, safe_rect.end.y)
		)
	arrow.set("direction", direction)
	arrow.position = arrow_center - Vector2(ARROW_SIZE, ARROW_SIZE) * 0.5
	arrow.queue_redraw()
	label.text = text
	label.reset_size()
	var label_position: Vector2 = arrow_center + Vector2(-label.size.x * 0.5, ARROW_SIZE * 0.5 + 6.0)
	label_position.x = clampf(label_position.x, 8.0, viewport_size.x - label.size.x - 8.0)
	label_position.y = clampf(label_position.y, MARGIN_TOP - 40.0, viewport_size.y - 34.0)
	label.position = label_position


func destroy() -> void:
	if is_valid():
		layer.queue_free()
	layer = null
