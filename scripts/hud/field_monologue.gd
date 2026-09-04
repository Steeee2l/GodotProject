class_name FieldMonologue
extends RefCounted

# 필드용 자막 독백 — 메인 미션(격리 신호 등)의 순간마다 먼지가 한마디씩 한다.
#
# 전투 중에도 안전해야 하므로 입력을 전혀 잡지 않는 자동 진행형이다:
# 한 줄이 타자기로 흐르고, 잠시 머물렀다가 다음 줄로, 끝나면 스르르 사라진다.
# 판을 멈추는 대화창은 쉘터의 contract_story가 맡고, 필드에서는 이걸 쓴다.
#
# 시네마틱 바크 모드(field_cinematic.gd)도 이 패널을 빌려 쓴다 — 같은 하단
# 슬롯을 쓰는 둘이 따로 패널을 띄우면 겹치므로, 한 큐에 줄을 세운다.
# 바크 줄은 골드 테두리 + 화자 이름, 표시 시간 = 1.6s + 글자당 0.045s(최소 2.2s),
# 패널을 탭하면 빨리 넘어가고, 건너뛰기는 남은 바크를 통째로 접는다.
#
# 사용:
#   monologue.attach(main)                  # host 패턴
#   monologue.play(["첫 줄", "둘째 줄"])     # 재생 중이면 뒤에 이어 붙는다
#   monologue.play_bark(lines, "주홍", on_done)  # 시네마틱 바크(마지막 줄 뒤 콜백)

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const HudStyle := preload("res://scripts/hud/hud_style.gd")
const LINE_HOLD_SECONDS := 1.9
# 바크 표시 시간(타자 시간 포함): 1.6s + 글자당 0.045s, 최소 2.2s.
const BARK_BASE_SECONDS := 1.6
const BARK_PER_CHAR_SECONDS := 0.045
const BARK_MIN_SECONDS := 2.2
# 긴 줄을 타자기가 다 친 뒤에도 최소 이만큼은 머문다 — 마지막 글자를 읽을 틈.
const BARK_MIN_HOLD_AFTER_TYPING := 0.7
const BARK_FAST_HOLD_SECONDS := 0.9
const BORDER_DEFAULT := Color("#7f9c8f")
const BORDER_BARK := Color("#b89545")
const SPEAKER_DEFAULT := Color("#9cc7ae")
const SPEAKER_BARK := Color("#f0ce70")

var host: Node
var panel: PanelContainer
var speaker_label: Label
var line_label: Label
var typewriter: Typewriter
# 큐 항목: {"text", "speaker", "bark": bool, "on_done": Callable(마지막 바크 줄에만)}
var queue: Array[Dictionary] = []
var playing := false
var current: Dictionary = {}
var _hold_timer: SceneTreeTimer
var _fade_tween: Tween
var _line_started_msec := 0
var _fast_hold := false
var _bark_style_active := false


func attach(owner_node: Node) -> void:
	host = owner_node


func play(lines: Array, speaker := "먼지") -> void:
	# host(Variant) 경유 호출은 Array[String] 리터럴을 무타입 Array로 만든다.
	# 무타입으로 받아 내부에서 문자열화한다 — 모듈화 규약의 그 함정.
	for line in lines:
		queue.append({"text": str(line), "speaker": speaker, "bark": false})
	_start_if_idle()


func play_bark(lines: Array, speaker := "먼지", on_done := Callable()) -> void:
	# 시네마틱 바크 — 독백과 같은 큐에 선다. 마지막 줄이 끝나면 on_done을 부른다
	# (시네마틱이 다음 단계로 넘어가는 신호). 건너뛰기로 접혀도 콜백은 온다.
	var appended := 0
	for line in lines:
		var text := str(line)
		if text.is_empty():
			continue
		queue.append({"text": text, "speaker": speaker, "bark": true})
		appended += 1
	if appended == 0:
		if on_done.is_valid():
			on_done.call()
		return
	queue[queue.size() - 1]["on_done"] = on_done
	_start_if_idle()


func is_bark_playing() -> bool:
	if playing and bool(current.get("bark", false)):
		return true
	for entry in queue:
		if bool(entry.get("bark", false)):
			return true
	return false


func fast_forward_bark() -> void:
	# 패널 탭: 타자 중이면 줄을 즉시 다 보여 주고 짧게 머문다, 다 보였으면 다음 줄.
	if not playing or not bool(current.get("bark", false)):
		return
	if is_instance_valid(typewriter) and typewriter.is_typing():
		_fast_hold = true
		typewriter.skip()
		return
	_on_hold_timeout()


func cancel_bark() -> void:
	# 건너뛰기: 남은 바크 줄을 전부 접는다. 일반 독백 줄은 남긴다.
	# 접힌 바크의 on_done은 그래도 부른다 — 시네마틱 진행이 여기서 멎으면 안 된다.
	var callbacks: Array[Callable] = []
	var kept: Array[Dictionary] = []
	for entry in queue:
		if bool(entry.get("bark", false)):
			var done: Variant = entry.get("on_done", null)
			if done is Callable and (done as Callable).is_valid():
				callbacks.append(done as Callable)
		else:
			kept.append(entry)
	queue = kept
	if playing and bool(current.get("bark", false)):
		var done: Variant = current.get("on_done", null)
		if done is Callable and (done as Callable).is_valid():
			callbacks.append(done as Callable)
		_cancel_hold()
		current = {}
		if is_instance_valid(typewriter) and typewriter.is_typing():
			# skip()이 finished를 쏘지만 current가 비어 있어 hold 타이머는 안 선다.
			typewriter.skip()
		_next_line()
	for callback in callbacks:
		callback.call()


func _start_if_idle() -> void:
	_ensure_panel()
	if playing:
		return
	playing = true
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	panel.visible = true
	panel.modulate.a = 0.0
	_fade_tween = host.create_tween()
	_fade_tween.tween_property(panel, "modulate:a", 1.0, 0.25)
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
	panel.gui_input.connect(_on_panel_gui_input)
	var style := HudStyle.panel(HudStyle.INK, BORDER_DEFAULT, 7)
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
	speaker_label.text = GameState.player_name
	speaker_label.add_theme_font_override("font", FONT)
	speaker_label.add_theme_font_size_override("font_size", 12)
	speaker_label.add_theme_color_override("font_color", SPEAKER_DEFAULT)
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


func _apply_style(bark: bool) -> void:
	if bark == _bark_style_active or not is_instance_valid(panel):
		return
	_bark_style_active = bark
	var style := HudStyle.panel(HudStyle.INK, BORDER_BARK if bark else BORDER_DEFAULT, 7)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	speaker_label.add_theme_color_override("font_color", SPEAKER_BARK if bark else SPEAKER_DEFAULT)
	# 바크만 탭을 받는다 — 독백은 예전처럼 입력을 전혀 잡지 않는다.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if bark else Control.MOUSE_FILTER_IGNORE


func _on_panel_gui_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		tapped = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	if not tapped:
		return
	fast_forward_bark()
	panel.accept_event()


func _next_line() -> void:
	_cancel_hold()
	if queue.is_empty():
		playing = false
		current = {}
		if is_instance_valid(panel):
			if is_instance_valid(_fade_tween):
				_fade_tween.kill()
			_fade_tween = host.create_tween()
			_fade_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
			_fade_tween.tween_callback(func() -> void: panel.visible = false)
		return
	current = queue.pop_front()
	var bark := bool(current.get("bark", false))
	speaker_label.text = GameState.resolve_speaker(str(current.get("speaker", "먼지")))
	_apply_style(bark)
	_fast_hold = false
	_line_started_msec = Time.get_ticks_msec()
	typewriter.start(GameState.apply_player_name(str(current.get("text", ""))))


func _on_line_finished() -> void:
	if not playing or current.is_empty():
		return
	var hold := LINE_HOLD_SECONDS
	if bool(current.get("bark", false)):
		var text := str(current.get("text", ""))
		var total := maxf(BARK_MIN_SECONDS, BARK_BASE_SECONDS + BARK_PER_CHAR_SECONDS * float(text.length()))
		var elapsed := float(Time.get_ticks_msec() - _line_started_msec) / 1000.0
		hold = maxf(BARK_MIN_HOLD_AFTER_TYPING, total - elapsed)
		if _fast_hold:
			hold = BARK_FAST_HOLD_SECONDS
	_cancel_hold()
	_hold_timer = host.get_tree().create_timer(hold)
	_hold_timer.timeout.connect(_on_hold_timeout, CONNECT_ONE_SHOT)


func _on_hold_timeout() -> void:
	_hold_timer = null
	if not playing or current.is_empty():
		return
	var finished := current
	# 콜백(시네마틱 _advance)이 다음 바크를 바로 큐에 넣을 수 있으니, 줄을 넘기기
	# 전에 먼저 부른다 — 그래야 패널이 꺼졌다 켜지지 않고 이어서 흐른다.
	current = {}
	var done: Variant = finished.get("on_done", null)
	if done is Callable and (done as Callable).is_valid():
		(done as Callable).call()
	if playing and current.is_empty():
		_next_line()


func _cancel_hold() -> void:
	if _hold_timer != null and _hold_timer.timeout.is_connected(_on_hold_timeout):
		_hold_timer.timeout.disconnect(_on_hold_timeout)
	_hold_timer = null
