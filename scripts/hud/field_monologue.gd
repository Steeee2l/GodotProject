class_name FieldMonologue
extends RefCounted

# 필드용 자막 독백 — 메인 미션(격리 신호 등)의 순간마다 나비가 한마디씩 한다.
#
# 전투 중에도 안전해야 하므로 입력을 전혀 잡지 않는 자동 진행형이다:
# 한 줄이 타자기로 흐르고, 잠시 머물렀다가 다음 줄로, 끝나면 스르르 사라진다.
# 판을 멈추는 대화창은 쉘터의 contract_story가 맡고, 필드에서는 이걸 쓴다.
#
# 사용:
#   monologue.attach(main)                  # host 패턴
#   monologue.play(["첫 줄", "둘째 줄"])     # 재생 중이면 뒤에 이어 붙는다

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const HudStyle := preload("res://scripts/hud/hud_style.gd")
const LINE_HOLD_SECONDS := 1.9

var host: Node
var panel: PanelContainer
var speaker_label: Label
var line_label: Label
var typewriter: Typewriter
var queue: Array[String] = []
var playing := false


func attach(owner_node: Node) -> void:
	host = owner_node


func play(lines: Array, speaker := "나비") -> void:
	# host(Variant) 경유 호출은 Array[String] 리터럴을 무타입 Array로 만든다.
	# 무타입으로 받아 내부에서 문자열화한다 — 모듈화 규약의 그 함정.
	for line in lines:
		queue.append(str(line))
	_ensure_panel()
	speaker_label.text = speaker
	if not playing:
		playing = true
		panel.visible = true
		panel.modulate.a = 0.0
		var tween := host.create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.25)
		_next_line()


func _ensure_panel() -> void:
	if is_instance_valid(panel):
		return
	panel = PanelContainer.new()
	panel.name = "FieldMonologuePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var viewport_width: float = host.get_viewport().get_visible_rect().size.x
	var half_width := minf(330.0, (viewport_width - 24.0) * 0.5)
	panel.offset_left = -half_width
	panel.offset_right = half_width
	# 상호작용 카드(-24% 지점)보다 위. 자막이라 낮게 깔린다.
	panel.offset_bottom = -84.0
	panel.offset_top = -160.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := HudStyle.panel(Color(0.012, 0.018, 0.019, 0.92), Color("#7f9c8f"), 7)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	host.get_node("HUD").add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	speaker_label = Label.new()
	speaker_label.text = "나비"
	speaker_label.add_theme_font_override("font", FONT)
	speaker_label.add_theme_font_size_override("font_size", 12)
	speaker_label.add_theme_color_override("font_color", Color("#9cc7ae"))
	box.add_child(speaker_label)
	line_label = Label.new()
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.add_theme_font_override("font", FONT)
	line_label.add_theme_font_size_override("font_size", 16)
	line_label.add_theme_color_override("font_color", Color("#eef3ef"))
	box.add_child(line_label)
	typewriter = Typewriter.new()
	host.get_node("HUD").add_child(typewriter)
	typewriter.attach(line_label)
	typewriter.finished.connect(_on_line_finished)


func _next_line() -> void:
	if queue.is_empty():
		playing = false
		if is_instance_valid(panel):
			var tween := host.create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.4)
			tween.tween_callback(func() -> void: panel.visible = false)
		return
	var line: String = queue.pop_front()
	typewriter.start(line)


func _on_line_finished() -> void:
	if not playing:
		return
	host.get_tree().create_timer(LINE_HOLD_SECONDS).timeout.connect(_next_line)
