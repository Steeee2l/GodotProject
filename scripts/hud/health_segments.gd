extends Control

# 세그먼트 체력바의 눈금 오버레이 — 채움 Panel 위에 칸 구분선만 그린다.
# 채움·잔상은 기존 Panel이 맡고, 이 컨트롤은 그 위에서 "10칸"으로 읽히게 한다.

const SEGMENT_COUNT := 10
const DIVIDER_COLOR := Color(0.02, 0.025, 0.028, 0.92)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var segment_width := size.x / float(SEGMENT_COUNT)
	for index in range(1, SEGMENT_COUNT):
		var x := roundf(float(index) * segment_width)
		draw_rect(Rect2(x - 0.5, 0.0, 1.0, size.y), DIVIDER_COLOR)
