extends RefCounted

# 미션 축하 배너(2026-08-30 유저 요청: "미션 달성하면 크게 잘 축하해주면서
# 알려줬으면 좋겠어") — 메인 임무 거점·현장 임무·기본 목표가 끝나는 순간
# 화면 중앙에 큰 금색 배너 + 팡파르가 터진다.
#
# 토스트(_show_field_notice)는 스택 한 줄이라 '진행 로그'지 '축하'가 아니다.
# 이 배너는 그 위에 얹히는 순간 연출이고, 상세 정보는 여전히 토스트가 맡는다.
#
# host 패턴: main이 attach(host) 후 celebrate(제목, 부제)만 부른다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
# 크게 떠 있는 시간(0.5s) → 상단 띠로 수축해 머무는 시간(2.0s).
const BIG_HOLD_SECONDS := 0.5
const STRIP_HOLD_SECONDS := 2.0
const STRIP_SCALE := 0.55
const STRIP_TOP_MARGIN := 10.0
const LAYER := 98

var host: Node
var canvas: CanvasLayer
var panel: PanelContainer
var eyebrow_label: Label
var title_label: Label
var subtitle_label: Label
var banner_tween: Tween
var fanfare_players: Array[AudioStreamPlayer] = []
var fanfare_index := 0
static var fanfare_stream: AudioStreamWAV


func attach(host_node: Node) -> void:
	host = host_node


func celebrate(title: String, subtitle: String = "", eyebrow: String = "임무 완료") -> void:
	if host == null or title.is_empty():
		return
	_ensure_banner()
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	eyebrow_label.text = "—  %s  —" % eyebrow
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	panel.visible = true
	panel.reset_size()
	# 크게 터뜨리고 → 상단 띠로 수축(유저 확정 1안). 큰 상태로 오래 두면
	# 상단 시야를 3초 넘게 가려 전투 중 위에서 오는 적을 놓친다. 팝은 0.5초만,
	# 그 뒤엔 화면 맨 위의 얇은 띠로 물러나 2초 머물다 사라진다.
	var viewport_size := (host.get_viewport() as Viewport).get_visible_rect().size
	var big_position := Vector2(
		(viewport_size.x - panel.size.x) * 0.5,
		viewport_size.y * 0.22 - panel.size.y * 0.5
	)
	# pivot이 중심이라 scale을 줄여도 중심은 그대로다 — 띠의 '위 가장자리'가
	# STRIP_TOP_MARGIN에 오도록 중심 y를 역산한다.
	var strip_center_y := STRIP_TOP_MARGIN + panel.size.y * STRIP_SCALE * 0.5
	var strip_position := Vector2(big_position.x, strip_center_y - panel.size.y * 0.5)
	panel.position = big_position
	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.7, 0.7)
	_play_fanfare()
	banner_tween = host.create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	banner_tween.tween_property(panel, "scale", Vector2(1.06, 1.06), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.set_parallel(false)
	banner_tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	banner_tween.tween_interval(BIG_HOLD_SECONDS)
	# 수축 — 크기와 위치를 같이 움직여 위로 '물러나는' 동작으로 읽히게.
	banner_tween.set_parallel(true)
	banner_tween.tween_property(panel, "scale", Vector2(STRIP_SCALE, STRIP_SCALE), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	banner_tween.tween_property(panel, "position", strip_position, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	banner_tween.set_parallel(false)
	banner_tween.tween_interval(STRIP_HOLD_SECONDS)
	banner_tween.set_parallel(true)
	banner_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	banner_tween.tween_property(panel, "scale", Vector2(STRIP_SCALE * 0.92, STRIP_SCALE * 0.92), 0.4)
	banner_tween.set_parallel(false)
	banner_tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.visible = false
	)


func _ensure_banner() -> void:
	if canvas != null and is_instance_valid(canvas):
		return
	canvas = CanvasLayer.new()
	canvas.name = "MissionCelebration"
	canvas.layer = LAYER
	host.add_child(canvas)

	panel = PanelContainer.new()
	panel.name = "CelebrationPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.05, 0.92)
	style.border_color = Color("#e8c766")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 18.0
	style.shadow_color = Color(0.91, 0.78, 0.4, 0.34)
	style.shadow_size = 22
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)

	eyebrow_label = _make_label(15, Color("#c9b06a"))
	column.add_child(eyebrow_label)
	title_label = _make_label(31, Color("#ffe08a"))
	column.add_child(title_label)
	subtitle_label = _make_label(16, Color("#d8e0d4"))
	column.add_child(subtitle_label)

	# 팡파르 플레이어 2개 — 연속 완료(연쇄 목표)에도 소리가 끊기지 않게.
	for _index in 2:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		voice.volume_db = -5.0
		voice.stream = _get_fanfare_stream()
		canvas.add_child(voice)
		fanfare_players.append(voice)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _play_fanfare() -> void:
	if fanfare_players.is_empty():
		return
	var voice := fanfare_players[fanfare_index % fanfare_players.size()]
	fanfare_index += 1
	if is_instance_valid(voice):
		voice.play()


static func _get_fanfare_stream() -> AudioStreamWAV:
	# 상승 3음 팡파르(C5–E5–G5, 마지막은 옥타브 화음) — 외부 에셋 없이 합성.
	# sfx_bank에 팡파르가 없어 여기서 만든다(kill_impact 킬 컨펌음과 같은 방식).
	if fanfare_stream != null:
		return fanfare_stream
	var sample_rate := 22050
	var note_length := 0.11
	var tail_length := 0.5
	var notes := [523.25, 659.25, 783.99]
	var total_seconds := note_length * notes.size() + tail_length
	var frame_count := int(sample_rate * total_seconds)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / float(sample_rate)
		var value := 0.0
		var note_index := mini(int(t / note_length), notes.size() - 1)
		var is_tail := t >= note_length * notes.size()
		if is_tail:
			# 꼬리: G5 + C6 화음이 함께 울리며 잦아든다.
			var tail_t := t - note_length * notes.size()
			var envelope := exp(-4.2 * tail_t)
			value = (
				sin(TAU * 783.99 * t) * 0.5
				+ sin(TAU * 1046.5 * t) * 0.38
			) * envelope
		else:
			var note_t := t - float(note_index) * note_length
			var envelope := minf(1.0, note_t * 90.0) * exp(-6.0 * note_t)
			var frequency := float(notes[note_index])
			value = (
				sin(TAU * frequency * t)
				+ sin(TAU * frequency * 2.0 * t) * 0.22
			) * envelope * 0.62
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[frame * 2] = sample & 0xFF
		data[frame * 2 + 1] = (sample >> 8) & 0xFF
	fanfare_stream = AudioStreamWAV.new()
	fanfare_stream.format = AudioStreamWAV.FORMAT_16_BITS
	fanfare_stream.mix_rate = sample_rate
	fanfare_stream.data = data
	return fanfare_stream
