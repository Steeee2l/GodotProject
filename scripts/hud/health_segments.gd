extends Control

# 세그먼트 체력바의 눈금 오버레이 — 채움 Panel 위에 칸 구분선만 그린다.
# 채움·잔상은 기존 Panel이 맡고, 이 컨트롤은 그 위에서 "10칸"으로 읽히게 한다.

const SEGMENT_COUNT := 10
# 칸 사이 홈 — 배경색과 같은 2px. 채움 위에 얹혀 칸을 실제로 '끊어' 보이게 한다.
const DIVIDER_COLOR := Color(0.03, 0.04, 0.045, 0.96)
const DIVIDER_WIDTH := 2.0
const INSET := 2.0
# 칸 위쪽 얇은 하이라이트 — 납작한 띠가 아니라 살짝 볼록한 칸으로 읽히게.
const HIGHLIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.16)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var inner_width := size.x - INSET * 2.0
	var segment_width := inner_width / float(SEGMENT_COUNT)
	for index in range(1, SEGMENT_COUNT):
		var x := roundf(INSET + float(index) * segment_width - DIVIDER_WIDTH * 0.5)
		draw_rect(Rect2(x, 0.0, DIVIDER_WIDTH, size.y), DIVIDER_COLOR)
	draw_rect(Rect2(INSET, INSET, inner_width, 1.0), HIGHLIGHT_COLOR)
