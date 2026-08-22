class_name CombatFeedbackOverlay
extends Control

# 모바일 전투 피드백 3종을 한 장의 오버레이가 그린다:
# ① 오토에임 타깃 브래킷 — 발사 버튼이 지금 누굴 겨누는지 (모서리 4개)
# ② 히트마커 — 내 탄이 맞은 순간 4획 십자, 처치면 X로 커진다
# ③ 재장전 링 — 발사 버튼 테두리를 원형 진행으로 채운다 (엄지가 이미 그곳에 있다)
# 전부 draw 호출이라 노드 낭비가 없고, HudStyle 색 문법을 따른다.

const BRACKET_COLOR := Color("#e08a58")
# 정조준 상승(머리 조준) 중 브래킷 색 — 헤드샷 팝과 같은 주황.
const BRACKET_RAISED_COLOR := Color("#ff8a2a")
const HIT_COLOR := Color("#f2e7c5")
const KILL_COLOR := Color("#ff6b52")
const RELOAD_COLOR := Color("#e3bd67")

var bracket_visible := false
var bracket_center := Vector2.ZERO
var bracket_half := 26.0
var bracket_raised := false
var reload_progress := -1.0
var reload_center := Vector2.ZERO
var reload_radius := 60.0
var hit_markers: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 210


func set_bracket(center: Vector2, half_extent: float, raised: bool = false) -> void:
	bracket_visible = true
	bracket_center = center
	bracket_half = half_extent
	bracket_raised = raised


func clear_bracket() -> void:
	bracket_visible = false


func set_reload(progress: float, center: Vector2, radius: float) -> void:
	reload_progress = progress
	reload_center = center
	reload_radius = radius


func clear_reload() -> void:
	reload_progress = -1.0


func add_hit_marker(screen_position: Vector2, killed: bool) -> void:
	hit_markers.append({
		"position": screen_position,
		"life": 0.22 if not killed else 0.34,
		"max_life": 0.22 if not killed else 0.34,
		"killed": killed,
	})


func _process(delta: float) -> void:
	var dirty := bracket_visible or reload_progress >= 0.0 or not hit_markers.is_empty()
	for index in range(hit_markers.size() - 1, -1, -1):
		hit_markers[index]["life"] = float(hit_markers[index]["life"]) - delta
		if float(hit_markers[index]["life"]) <= 0.0:
			hit_markers.remove_at(index)
	if dirty:
		queue_redraw()


func _draw() -> void:
	if bracket_visible:
		_draw_bracket()
	if reload_progress >= 0.0:
		_draw_reload_ring()
	for marker in hit_markers:
		_draw_hit_marker(marker)


func _draw_bracket() -> void:
	# 숨 쉬는 브래킷 — 정지된 사각형은 UI, 맥동하는 모서리는 조준.
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.06
	var half := bracket_half * pulse
	var arm := maxf(7.0, half * 0.42)
	var width := 3.0
	var color := BRACKET_RAISED_COLOR if bracket_raised else BRACKET_COLOR
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip: Vector2 = bracket_center + corner * half
		draw_line(tip, tip - Vector2(corner.x * arm, 0.0), color, width)
		draw_line(tip, tip - Vector2(0.0, corner.y * arm), color, width)
	if bracket_raised:
		# 머리 조준 표식 — 브래킷 위 작은 점.
		draw_circle(bracket_center + Vector2(0.0, -half - 7.0), 3.0, color)


func _draw_reload_ring() -> void:
	var sweep := TAU * clampf(reload_progress, 0.0, 1.0)
	draw_arc(
		reload_center, reload_radius,
		-PI * 0.5, -PI * 0.5 + sweep,
		40, RELOAD_COLOR, 4.5, true
	)


func _draw_hit_marker(marker: Dictionary) -> void:
	var life := float(marker["life"])
	var max_life := float(marker["max_life"])
	var alpha := clampf(life / max_life, 0.0, 1.0)
	var killed := bool(marker["killed"])
	var center := marker["position"] as Vector2
	var color := (KILL_COLOR if killed else HIT_COLOR)
	color.a = alpha
	var gap := 5.0 if not killed else 7.0
	var length := (9.0 if not killed else 15.0) * (1.0 + (1.0 - alpha) * 0.35)
	var width := 2.5 if not killed else 3.5
	for diagonal: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var from: Vector2 = center + diagonal.normalized() * gap
		var to: Vector2 = center + diagonal.normalized() * (gap + length)
		draw_line(from, to, color, width)
