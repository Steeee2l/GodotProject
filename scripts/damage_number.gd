extends Label3D

const DURATION := 0.64

var elapsed := 0.0
var start_position := Vector3.ZERO
var target_position := Vector3.ZERO
var start_scale := 0.58
var peak_scale := 1.12
var end_scale := 0.7
var base_color := Color.WHITE


func setup(
	damage: int,
	is_critical: bool,
	damage_font: Font,
	world_position: Vector3,
	hit_direction: Vector3,
	side_amount: float,
	hit_grade: String = "normal"
) -> void:
	name = "DamageNumber"
	text = str(maxi(0, damage))
	font = damage_font
	var text_scale := clampf(float(AccessibilitySettings.combat_text_scale), 0.8, 1.4)
	# 명중 등급은 1.94배 데미지 차이인데 여태 아무 표시가 없었다. 정조준(center)은
	# 호박색으로 크게, 스침(graze)은 회청색으로 작게 — 조준 실력이 눈에 보이게 한다.
	var grade_size := 58
	base_color = Color("#f2f0e8")
	if hit_grade == "center":
		grade_size = 66
		base_color = Color("#ffb347")
	elif hit_grade == "graze":
		grade_size = 46
		base_color = Color("#9fb2c4")
	font_size = roundi(float(78 if is_critical else grade_size) * text_scale)
	outline_size = roundi(float(18 if is_critical else 14) * text_scale)
	if is_critical:
		base_color = Color("#ffd84a")
	modulate = base_color
	outline_modulate = Color(0.16, 0.08, 0.01, 0.96) if is_critical else Color(0.02, 0.025, 0.025, 0.94)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 127
	start_scale = 0.5 if is_critical else 0.58
	peak_scale = 1.42 if is_critical else 1.12
	end_scale = 0.78 if is_critical else 0.7
	scale = Vector3.ONE * start_scale
	set_meta("critical", is_critical)
	set_meta("damage", damage)
	global_position = world_position
	start_position = global_position
	var side_direction := Vector3(-hit_direction.z, 0.0, hit_direction.x)
	if side_direction.length_squared() <= 0.01:
		side_direction = Vector3.RIGHT
	target_position = start_position + Vector3(0, 1.15 if is_critical else 0.88, 0)
	target_position += side_direction.normalized() * side_amount


func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var flight_progress := 1.0 - pow(1.0 - progress, 4.0)
	global_position = start_position.lerp(target_position, flight_progress)
	if progress < 0.2:
		var pop_progress := progress / 0.2
		var pop_ease := 1.0 - pow(1.0 - pop_progress, 3.0) + sin(pop_progress * PI) * 0.12
		scale = Vector3.ONE * lerpf(start_scale, peak_scale, pop_ease)
	else:
		var settle_progress := smoothstep(0.2, 1.0, progress)
		scale = Vector3.ONE * lerpf(peak_scale, end_scale, settle_progress)
	var alpha := 1.0 - smoothstep(0.58, 1.0, progress)
	modulate = Color(base_color.r, base_color.g, base_color.b, alpha)
	if progress >= 1.0:
		queue_free()
