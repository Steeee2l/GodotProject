class_name FieldCinematic
extends RefCounted

# 필드용 인게임 시네마틱 실행기 — 레터박스 · 조작 잠금 · 연출 이동 · 대사 ·
# 정지 이미지 컷 · 선택지를 하나의 단계 큐로 돌린다.
#
# 쉘터의 주홍 등장 연출(_play_juhong_entrance_cinematic)이 참고 구현이었다.
# 거기서 "레터박스 → 스크립트 이동 → 대화 → 레터박스 해제"의 뼈대만 뽑아
# 필드에서도 쓸 수 있게 일반화했다. main.gd는 커지지 않는다 — host 패턴으로
# 공용 헬퍼만 빌려 쓴다.
#
# 사용:
#   cinematic.attach(main)
#   cinematic.play([{...단계...}, ...], func() -> void: ...)
#
# ── 단계(step) 종류 ────────────────────────────────────────────
#   {"type": "wait", "duration": 0.6}
#   {"type": "notice", "text": "..."}                     필드 알림 배너
#   {"type": "focus", "position": Vector3, "hold": 1.0}   카메라를 그쪽으로
#   {"type": "focus_player"}                              카메라를 먼지에게로
#   {"type": "flash", "color": Color, "pulses": 3}        경보 섬광
#   {"type": "shake", "strength": 0.32, "duration": 0.45}
#   {"type": "spawn_actor", "key":"juhong", "root":"res://assets/characters/juhong",
#    "display_name":"주홍", "role":"붉은 칼의 전령", "position": Vector3}
#   {"type": "actor_walk", "key":"juhong", "to": Vector3, "duration": 1.6}
#   {"type": "actor_fall", "key":"survivor"}              쓰러지는 연출(사망 암시)
#   {"type": "actor_exit", "key":"juhong", "to": Vector3, "duration": 2.0}
#   {"type": "lines", "speaker":"주홍", "title":"...", "portrait": Texture2D|String,
#    "lines": ["...", "..."]}
#   {"type": "image_cut", "texture": Texture2D|String, "title":"...", "lines":[...]}
#   {"type": "choice", "id":"jongno_survivor", "prompt":"...",
#    "options":[{"id":"take","label":"데려간다","detail":"가방 3칸"}, ...],
#    "on_choice": Callable}
#   {"type": "callback", "call": Callable}
#
# ── 두 가지 모드(classify_mode가 단일 판정 지점) ──────────────────
#   bark  — 스텝이 lines/notice/callback/wait(+monologue)뿐이면: 레터박스도
#           조작 잠금도 무적도 없다. 대사는 화면 하단 바크(FieldMonologue 패널)로
#           자동 진행되고, 플레이어는 그동안 제 할 일을 한다. is_cinematic_active()
#           는 false — main.gd의 잠금 9곳이 열린다. 건너뛰기(작은 버튼)는 바크 전체 취소.
#   event — 배우·이미지 컷·선택지·카메라 포커스·플래시·셰이크가 하나라도 있으면:
#           트리 일시정지(적·투사체·타이머 전부 정지) + 레터박스 + 대화 UI.
#           연출 레이어는 PROCESS_MODE_ALWAYS, 트윈은 레이어 소유라 멈추지 않는다.
#   스텝 배열 첫머리에 {"mode": "event"|"bark"} 메타를 두면 판정을 강제한다.
#   유저 신고: "미션 대사 때마다 캐릭터를 못 움직여 불편하다 — 바크처럼 흘리거나
#   세상을 멈추거나" 에 대한 답이다.
#
# 규칙:
#   * event 모드 중 플레이어는 무적이다(main.take_damage가 is_cinematic_active를 본다).
#     전리품 교체 모달에서 겪은 "연출 보는 동안 맞아 죽는" 사고를 되풀이하지 않는다.
#     어차피 트리가 멈춰 있으니 맞을 일도 없지만, 이중 안전장치로 남긴다.
#   * 모든 연출은 건너뛸 수 있다. 단, 선택지 앞에서는 멈춘다 — 결정을 대신
#     해 주지 않는다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const STORY_CHARACTER_SCRIPT := preload("res://scripts/shelter_story_character.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const BAR_HEIGHT := 62.0
const BAR_TIME := 0.4
const MODE_BARK := "bark"
const MODE_EVENT := "event"
# 이 중 하나라도 있으면 event 모드 — 세상을 멈춰야 읽히는 연출들.
const EVENT_STEP_TYPES := [
	"focus", "focus_player", "flash", "shake",
	"spawn_actor", "actor_walk", "actor_exit", "actor_fall",
	"image_cut", "choice",
]

var host: Node
var layer: CanvasLayer
var bar_top: ColorRect
var bar_bottom: ColorRect
var skip_button: Button
var dialogue_panel: PanelContainer
var dialogue_speaker_label: Label
var dialogue_title_label: Label
var dialogue_body_label: Label
var dialogue_progress_label: Label
var dialogue_next_button: Button
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var typewriter: Typewriter
var image_cut_root: Control
var choice_root: Control

var running := false
var mode := MODE_EVENT
# 시네마틱이 직접 건 일시정지인가 — 입력 중계 노드의 자가 복구는 이걸 건드리지 않는다.
var _paused_by_cinematic := false
var _sequence: Array = []
var _step_index := 0
var _finished_callback := Callable()
var _actors: Dictionary = {}
var _step_tween: Tween
var _advance_timer: SceneTreeTimer
var _fast_forward := false


func attach(owner_node: Node) -> void:
	host = owner_node


func is_active() -> bool:
	# "조작을 잠가야 하는 연출이 도는가" — event 모드만 true. 바크는 플레이어의
	# 시간을 빼앗지 않으므로 main.gd의 잠금·무적 게이트에 걸리지 않는다.
	return running and mode == MODE_EVENT


func is_running() -> bool:
	return running


func is_bark_active() -> bool:
	# HUD가 하단 슬롯 겹침을 피할 때 쓰는 상태. 조작과는 무관하다.
	return running and mode == MODE_BARK


func get_mode() -> String:
	return mode


static func classify_mode(steps: Array) -> String:
	# 모드 판정의 단일 지점. {"mode": ...} 메타가 있으면 그게 이긴다.
	for step_value in steps:
		if not (step_value is Dictionary):
			continue
		var step := step_value as Dictionary
		if step.has("mode"):
			return MODE_EVENT if str(step["mode"]) == MODE_EVENT else MODE_BARK
	for step_value in steps:
		if not (step_value is Dictionary):
			continue
		if str((step_value as Dictionary).get("type", "")) in EVENT_STEP_TYPES:
			return MODE_EVENT
	return MODE_BARK


func play(sequence: Array, on_finished := Callable()) -> void:
	if sequence.is_empty() or not is_instance_valid(host):
		if on_finished.is_valid():
			on_finished.call()
		return
	if running and mode == MODE_BARK:
		# 바크가 흐르는 중에 새 연출이 오면 바크를 접고 새 것을 튼다 — 바크는
		# 배경음이지 줄 서서 기다릴 본편이 아니다.
		skip()
	if running:
		# 이미 event 연출 중이면 새 연출은 버린다 — 겹치면 조작 잠금이 꼬인다.
		if on_finished.is_valid():
			on_finished.call()
		return
	running = true
	mode = classify_mode(sequence)
	# 선택지·대화 진행은 포인터 UI다 — 조준 레티클 대신 OS 커서를 보여 준다.
	if mode == MODE_EVENT and host.has_method("_refresh_pointer_mode"):
		host.call("_refresh_pointer_mode")
	_sequence = sequence.duplicate()
	_step_index = 0
	_fast_forward = false
	_finished_callback = on_finished
	_actors.clear()
	_build_layer()
	if mode == MODE_BARK:
		_advance()
		return
	_pause_world()
	var tween := _make_tween()
	tween.tween_property(bar_top, "offset_bottom", BAR_HEIGHT, BAR_TIME).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bar_bottom, "offset_top", -BAR_HEIGHT, BAR_TIME).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_wait(BAR_TIME)


func _pause_world() -> void:
	# event 모드: 적·투사체·타이머 전부 멈춘다. 이미 멈춰 있던(ESC 메뉴 등)
	# 일시정지는 우리 것이 아니므로 건드리지 않는다.
	var tree := host.get_tree()
	if tree == null or tree.paused:
		return
	tree.paused = true
	_paused_by_cinematic = true


func _resume_world() -> void:
	if not _paused_by_cinematic:
		return
	_paused_by_cinematic = false
	var tree := host.get_tree() if is_instance_valid(host) else null
	if tree != null:
		tree.paused = false


func _make_tween() -> Tween:
	# 연출 트윈은 레이어(PROCESS_MODE_ALWAYS)에 묶는다 — 트리가 멈춰도 배우가
	# 걷고 레터박스가 닫힌다. 레이어가 없을 때만 호스트 트윈에 process 모드를 건다.
	if is_instance_valid(layer) and layer.is_inside_tree():
		return layer.create_tween()
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func skip() -> void:
	# 남은 단계를 빠르게 소화한다. 선택지를 만나면 거기서 멈춘다.
	if not running:
		return
	_fast_forward = true
	if is_instance_valid(typewriter) and typewriter.is_typing():
		typewriter.skip()
	_close_dialogue()
	_close_image_cut()
	if is_instance_valid(_step_tween):
		_step_tween.kill()
	_cancel_pending_advance()
	if mode == MODE_BARK and is_instance_valid(host) and host.get("monologue") != null:
		# 바크 전체 취소. 흐르던 lines 스텝의 on_done(_advance)이 여기서 불려
		# 남은 스텝을 빨리 감기로 소화할 수 있다 — 그 뒤엔 running이 꺼져 있다.
		host.monologue.cancel_bark()
		if not running:
			return
	_advance()


# ── 단계 진행 ──────────────────────────────────────────────────


func _advance() -> void:
	if not running:
		return
	# 판이 먼저 정리된 뒤에 대기 타이머가 늦게 도착할 수 있다. 그때는 조용히 접는다.
	if not is_instance_valid(host) or not host.is_inside_tree():
		running = false
		_cancel_pending_advance()
		_resume_world()
		return
	while _step_index < _sequence.size():
		var step := _sequence[_step_index] as Dictionary
		_step_index += 1
		var step_type := str(step.get("type", ""))
		# 빨리 감기 중에는 시간만 먹는 연출을 건너뛴다. 선택지·콜백은 반드시 통과한다.
		if _fast_forward and step_type in [
			"wait", "focus", "focus_player", "flash", "shake",
			"actor_walk", "actor_exit", "lines", "image_cut", "notice", "monologue",
		]:
			_apply_instant_side_effect(step)
			continue
		if _run_step(step):
			return
	_finish()


func _apply_instant_side_effect(step: Dictionary) -> void:
	# 건너뛰어도 "일어난 일"은 남아야 한다 — 등장한 인물은 그 자리에 서고,
	# 쓰러질 인물은 쓰러진 채로 남는다.
	match str(step.get("type", "")):
		"actor_walk", "actor_exit":
			var actor := _get_actor(str(step.get("key", "")))
			if is_instance_valid(actor):
				actor.global_position = step.get("to", actor.global_position)
		"monologue":
			if is_instance_valid(host) and host.get("monologue") != null:
				host.monologue.play(step.get("lines", []))


func _run_step(step: Dictionary) -> bool:
	# true를 돌려주면 "이 단계가 스스로 _advance를 부른다"는 뜻이다.
	match str(step.get("type", "")):
		"wait":
			_wait(float(step.get("duration", 0.5)))
			return true
		"notice":
			host.call("_show_field_notice", str(step.get("text", "")))
			_wait(float(step.get("duration", 0.9)))
			return true
		"monologue":
			host.monologue.play(step.get("lines", []))
			_wait(float(step.get("duration", 1.2)))
			return true
		"focus":
			if mode == MODE_BARK:
				# 바크 모드는 카메라를 빌리지 않는다 — main의 추적이 살아 있어 트윈과
				# 싸운다. 포커스는 조용히 건너뛴다({"mode": "bark"} 강제 시의 안전 장치).
				return false
			_focus_camera(step.get("position", Vector3.ZERO), float(step.get("hold", 1.0)))
			return true
		"focus_player":
			if mode == MODE_BARK:
				return false
			var player := host.get("player") as Node3D
			if is_instance_valid(player):
				_focus_camera(player.global_position, float(step.get("hold", 0.4)))
				return true
			return false
		"flash":
			_play_flash(step.get("color", Color(0.85, 0.16, 0.06)), int(step.get("pulses", 3)))
			_wait(float(step.get("duration", 1.0)))
			return true
		"shake":
			_play_shake(float(step.get("strength", 0.32)), float(step.get("duration", 0.45)))
			_wait(float(step.get("duration", 0.45)))
			return true
		"spawn_actor":
			_spawn_actor(step)
			return false
		"actor_walk":
			return _actor_walk(step, false)
		"actor_exit":
			return _actor_walk(step, true)
		"actor_fall":
			return _actor_fall(step)
		"lines":
			if mode == MODE_BARK:
				# 바크: 하단 패널로 자동 진행. 마지막 줄이 끝나면 다음 스텝.
				host.monologue.play_bark(
					step.get("lines", []), str(step.get("speaker", "먼지")), _advance
				)
				return true
			_open_dialogue(step)
			return true
		"image_cut":
			_open_image_cut(step)
			return true
		"choice":
			_open_choice(step)
			return true
		"callback":
			var call_value: Variant = step.get("call", null)
			if call_value is Callable and (call_value as Callable).is_valid():
				(call_value as Callable).call()
			return false
	return false


func _wait(duration: float) -> void:
	# 단계 진행은 트윈 콜백이 아니라 SceneTreeTimer로 잰다. 트윈은 순수하게
	# "보이는 것"만 맡고, "다음 단계로 언제 넘어가는가"는 타이머 하나가 쥔다.
	# 트윈 체인에 진행 로직을 얹으면 중간에 트윈을 kill 하는 순간(건너뛰기)
	# 진행이 통째로 멈춰 버린다. process_always=true라 일시정지에도 안 멎는다.
	if not is_instance_valid(host) or host.get_tree() == null:
		_advance()
		return
	_cancel_pending_advance()
	_advance_timer = host.get_tree().create_timer(maxf(0.02, duration), true, false, true)
	_advance_timer.timeout.connect(_advance, CONNECT_ONE_SHOT)


func _cancel_pending_advance() -> void:
	# 대기 중인 진행 타이머를 끊는다 — 건너뛰기 직후 한 단계가 두 번 흐르지 않게.
	if _advance_timer != null and _advance_timer.timeout.is_connected(_advance):
		_advance_timer.timeout.disconnect(_advance)
	_advance_timer = null


func _finish() -> void:
	if not running:
		return
	running = false
	_cancel_pending_advance()
	# 조작 잠금·일시정지는 레터박스가 걷히기 전에 먼저 푼다 — 답답함은 연출이 아니다.
	_resume_world()
	if host.has_method("_refresh_pointer_mode"):
		host.call("_refresh_pointer_mode")
	var closing_layer := layer
	layer = null
	if is_instance_valid(closing_layer):
		var closing_top := closing_layer.get_node_or_null("CineBarTop") as ColorRect
		var closing_bottom := closing_layer.get_node_or_null("CineBarBottom") as ColorRect
		if closing_top == null and closing_bottom == null:
			# 바크 모드 — 레터박스가 없으니 바로 치운다.
			closing_layer.queue_free()
		else:
			var tween := closing_layer.create_tween()
			if closing_top != null:
				tween.tween_property(closing_top, "offset_bottom", 0.0, BAR_TIME)
			if closing_bottom != null:
				tween.parallel().tween_property(closing_bottom, "offset_top", 0.0, BAR_TIME)
			tween.tween_callback(closing_layer.queue_free)
	# 남은 배우는 어둠에 녹여 치운다. 연출이 끝난 자리에 이름표 달린 NPC가
	# 그대로 서 있으면 그건 연출이 아니라 잔해다.
	for actor_value in _actors.values():
		var actor := actor_value as Node3D
		if not is_instance_valid(actor):
			continue
		var fade := host.create_tween()
		fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var actor_sprite := actor.get_node_or_null("CharacterSprite") as GeometryInstance3D
		if actor_sprite != null:
			fade.tween_property(actor_sprite, "modulate:a", 0.0, 0.6)
		else:
			fade.tween_interval(0.6)
		fade.tween_callback(actor.queue_free)
	bar_top = null
	bar_bottom = null
	skip_button = null
	typewriter = null
	dialogue_panel = null
	dialogue_body_label = null
	dialogue_lines.clear()
	_sequence.clear()
	_actors.clear()
	var callback := _finished_callback
	_finished_callback = Callable()
	if callback.is_valid():
		callback.call()


# ── 레이어 ─────────────────────────────────────────────────────


func _build_layer() -> void:
	layer = CanvasLayer.new()
	layer.name = "FieldCinematicLayer"
	layer.layer = 94
	# 트리가 일시정지돼도 연출 UI는 살아 있어야 한다. 실기기(PC 웹) 신고:
	# 대화 1/3에서 모든 입력이 죽는 멈춤 — 포커스 전환 자동 일시정지 등으로
	# 트리가 멈추면 pausable 버튼은 클릭을 못 받아 게임이 벽돌이 됐다.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)
	var relay := CinematicInputRelay.new()
	relay.name = "CineInputRelay"
	relay.cinematic = self
	layer.add_child(relay)
	if mode == MODE_BARK:
		# 바크 모드: 레터박스도 입력 가로채기도 없다. 작은 건너뛰기 버튼 하나만.
		skip_button = _make_button("건너뛰기", "close")
		skip_button.name = "CineSkipButton"
		skip_button.add_theme_font_size_override("font_size", 13)
		skip_button.icon = UI_ICONS.get_icon("close", 16, Color("#cbd9cf"))
		skip_button.modulate.a = 0.8
		# 바크 패널(FieldMonologue: 중앙 하단, 반폭 ≤330, 위 -160) 오른쪽 위 모서리에
		# 붙인다 — 우상단에 두면 살아 있는 HUD의 구역·탈출 거리 표시를 가린다.
		var viewport_width: float = host.get_viewport().get_visible_rect().size.x
		var half_width := minf(330.0, (viewport_width - 24.0) * 0.5)
		skip_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		skip_button.offset_left = half_width - 104.0
		skip_button.offset_right = half_width
		skip_button.offset_top = -198.0
		skip_button.offset_bottom = -164.0
		skip_button.pressed.connect(skip)
		layer.add_child(skip_button)
		return
	bar_top = ColorRect.new()
	bar_top.name = "CineBarTop"
	bar_top.color = Color.BLACK
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar_top)
	bar_bottom = ColorRect.new()
	bar_bottom.name = "CineBarBottom"
	bar_bottom.color = Color.BLACK
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0.0
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar_bottom)
	skip_button = _make_button("건너뛰기", "close")
	skip_button.name = "CineSkipButton"
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -142.0
	skip_button.offset_right = -14.0
	skip_button.offset_top = 14.0
	skip_button.offset_bottom = 58.0
	skip_button.pressed.connect(skip)
	layer.add_child(skip_button)


func _make_button(text: String, icon_name: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#e5ece7"))
	button.icon = UI_ICONS.get_icon(icon_name, 22, Color("#cbd9cf"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.05, 0.92)
	style.border_color = Color("#7f9488")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	return button


# ── 카메라 · 화면 효과 ─────────────────────────────────────────


func _focus_camera(target: Vector3, hold: float) -> void:
	var rig := host.get("camera_rig") as Node3D
	if not is_instance_valid(rig):
		_wait(hold)
		return
	var destination := Vector3(target.x, rig.position.y, target.z)
	_step_tween = _make_tween()
	_step_tween.tween_property(rig, "position", destination, 0.75).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_wait(0.75 + maxf(0.05, hold))


func _play_flash(color: Color, pulses: int) -> void:
	if not is_instance_valid(layer):
		return
	var flash := ColorRect.new()
	flash.name = "CineFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	layer.move_child(flash, 0)
	var tween := _make_tween()
	for _pulse in maxi(1, pulses):
		tween.tween_property(flash, "color:a", 0.2, 0.12)
		tween.tween_property(flash, "color:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func _play_shake(strength: float, duration: float) -> void:
	if mode == MODE_BARK:
		# 세상이 돌고 있으면 main의 셰이크 경로를 그대로 쓴다.
		host.set("camera_shake_time", duration)
		host.set("camera_shake_strength", strength)
		return
	# main의 카메라 셰이크는 _physics_process가 맡는데 event 모드는 트리가
	# 멈춰 있다. 그래서 연출이 직접 리그를 흔든다 — 레이어 트윈이라 멈추지 않는다.
	var rig := host.get("camera_rig") as Node3D
	if not is_instance_valid(rig):
		return
	# 오토로드는 식별자 대신 런타임 조회 — preload 기반 테스트에서 오토로드 등록 전
	# 컴파일 캐스케이드가 나는 함정(rocket_boss.gd의 GameState 조회와 같은 이유).
	var scale := 1.0
	var accessibility := host.get_tree().root.get_node_or_null("AccessibilitySettings")
	if accessibility != null:
		scale = clampf(float(accessibility.get("camera_shake_scale")), 0.0, 1.0)
	if scale <= 0.0 or duration <= 0.0:
		return
	var origin := rig.position
	var rng := RandomNumberGenerator.new()
	var tween := _make_tween()
	tween.tween_method(func(progress: float) -> void:
		if not is_instance_valid(rig):
			return
		var amplitude := strength * scale * (1.0 - progress)
		rig.position = origin + Vector3(
			rng.randf_range(-amplitude, amplitude), 0.0, rng.randf_range(-amplitude, amplitude)
		)
	, 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		if is_instance_valid(rig):
			rig.position = origin
	)


# ── 배우 ───────────────────────────────────────────────────────


func _get_actor(key: String) -> Node3D:
	return _actors.get(key, null) as Node3D


func _spawn_actor(step: Dictionary) -> void:
	var key := str(step.get("key", "actor"))
	var actor := STORY_CHARACTER_SCRIPT.new() as Node3D
	actor.call(
		"configure",
		key,
		str(step.get("display_name", "생존자")),
		str(step.get("role", "")),
		"대화하기",
		str(step.get("root", "res://assets/characters/juhong")),
		str(step.get("facing", "down_left")),
		float(step.get("pixel_size", 0.0105))
	)
	actor.position = step.get("position", Vector3.ZERO)
	# event 모드는 트리를 멈추므로 배우만은 항상 처리 — 멈춘 세상에서 걷는다.
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(actor)
	# 연출용 배우는 길을 막지 않는다 — 필드에서는 정지 충돌체가 플레이어를 가둔다.
	var body := actor.get_node_or_null("CharacterBody") as StaticBody3D
	if body != null:
		body.collision_layer = 0
		body.collision_mask = 0
	_actors[key] = actor


func _actor_walk(step: Dictionary, exiting: bool) -> bool:
	var actor := _get_actor(str(step.get("key", "")))
	if not is_instance_valid(actor):
		return false
	var destination: Vector3 = step.get("to", actor.global_position)
	destination.y = actor.global_position.y
	var walk_duration := maxf(0.2, float(step.get("duration", 1.4)))
	actor.call("begin_scripted_walk")
	_step_tween = _make_tween()
	_step_tween.tween_property(
		actor, "global_position", destination, walk_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_step_tween.tween_callback(func() -> void:
		if not is_instance_valid(actor):
			return
		actor.call("end_scripted_walk")
		var player := host.get("player") as Node3D
		if is_instance_valid(player) and not exiting:
			actor.call(
				"set_facing_from_world_direction",
				player.global_position - actor.global_position
			)
		if exiting:
			actor.queue_free()
	)
	_wait(walk_duration + 0.1)
	return true


func _actor_fall(step: Dictionary) -> bool:
	# 신규 사망 애니메이션은 만들지 않는다. 기존 스프라이트를 옆으로 눕히고
	# 색을 죽이는 것만으로 "쓰러졌다"는 문장은 충분히 읽힌다.
	var actor := _get_actor(str(step.get("key", "")))
	if not is_instance_valid(actor):
		return false
	var sprite := actor.get_node_or_null("CharacterSprite") as Node3D
	_play_shake(0.26, 0.28)
	_step_tween = _make_tween()
	if sprite != null:
		_step_tween.tween_property(sprite, "rotation:z", deg_to_rad(-78.0), 0.42).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_step_tween.parallel().tween_property(sprite, "position:y", 0.24, 0.42)
		_step_tween.tween_property(sprite, "modulate", Color(0.42, 0.36, 0.36, 0.85), 0.5)
	else:
		_step_tween.tween_interval(0.6)
	_wait(0.95 + float(step.get("hold", 0.5)))
	return true


# ── 대사 패널 ──────────────────────────────────────────────────


func _open_dialogue(step: Dictionary) -> void:
	dialogue_lines.assign(step.get("lines", []))
	if dialogue_lines.is_empty():
		_advance()
		return
	dialogue_index = 0
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 760.0
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "CineDialoguePanel"
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half := minf(450.0, (viewport_size.x - 24.0) * 0.5)
	dialogue_panel.offset_left = -half
	dialogue_panel.offset_right = half
	dialogue_panel.offset_bottom = -26.0
	dialogue_panel.offset_top = -26.0 - (196.0 if compact else 178.0)
	dialogue_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.012, 0.019, 0.018, 0.985), Color("#b89545"))
	)
	layer.add_child(dialogue_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	dialogue_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var portrait_texture := _resolve_texture(step.get("portrait", null))
	if portrait_texture != null:
		var portrait_frame := PanelContainer.new()
		var portrait_size := 64.0 if compact else 72.0
		portrait_frame.custom_minimum_size = Vector2(portrait_size, portrait_size)
		portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_frame.add_theme_stylebox_override(
			"panel", _panel_style(Color("#101815"), Color("#6e856f"))
		)
		row.add_child(portrait_frame)
		var portrait := TextureRect.new()
		portrait.texture = portrait_texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 7)
	row.add_child(text_box)
	var speaker_row := HBoxContainer.new()
	text_box.add_child(speaker_row)
	dialogue_speaker_label = Label.new()
	dialogue_speaker_label.text = str(step.get("speaker", "먼지"))
	dialogue_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_speaker_label.add_theme_font_override("font", FONT)
	dialogue_speaker_label.add_theme_font_size_override("font_size", 16)
	dialogue_speaker_label.add_theme_color_override("font_color", Color("#f0ce70"))
	speaker_row.add_child(dialogue_speaker_label)
	dialogue_progress_label = Label.new()
	dialogue_progress_label.add_theme_font_override("font", FONT)
	dialogue_progress_label.add_theme_font_size_override("font_size", 14)
	dialogue_progress_label.add_theme_color_override("font_color", Color("#82998d"))
	speaker_row.add_child(dialogue_progress_label)
	dialogue_title_label = Label.new()
	dialogue_title_label.text = str(step.get("title", ""))
	dialogue_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_title_label.add_theme_font_override("font", FONT)
	dialogue_title_label.add_theme_font_size_override("font_size", 14)
	dialogue_title_label.add_theme_color_override("font_color", Color("#e7d49a"))
	text_box.add_child(dialogue_title_label)
	dialogue_body_label = Label.new()
	dialogue_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body_label.add_theme_font_override("font", FONT)
	dialogue_body_label.add_theme_font_size_override("font_size", 17)
	dialogue_body_label.add_theme_color_override("font_color", Color("#e5ece7"))
	text_box.add_child(dialogue_body_label)
	typewriter = Typewriter.new()
	layer.add_child(typewriter)
	typewriter.attach(dialogue_body_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	text_box.add_child(actions)
	dialogue_next_button = _make_button("다음", "collect")
	dialogue_next_button.custom_minimum_size = Vector2(132 if compact else 170, 44)
	dialogue_next_button.pressed.connect(_advance_dialogue)
	actions.add_child(dialogue_next_button)
	_refresh_dialogue()


func _refresh_dialogue() -> void:
	if not is_instance_valid(dialogue_body_label):
		return
	if is_instance_valid(typewriter):
		typewriter.start(dialogue_lines[dialogue_index])
	else:
		dialogue_body_label.text = dialogue_lines[dialogue_index]
	dialogue_progress_label.text = "%d / %d" % [dialogue_index + 1, dialogue_lines.size()]
	var last_line := dialogue_index >= dialogue_lines.size() - 1
	dialogue_next_button.text = "계속" if last_line else "다음"


func _advance_dialogue() -> void:
	# 타이핑 중이면 첫 입력은 "전부 즉시 표시". 그 다음 입력에서 넘어간다.
	if is_instance_valid(typewriter) and typewriter.is_typing():
		typewriter.skip()
		return
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size():
		_refresh_dialogue()
		return
	_close_dialogue()
	_advance()


func _close_dialogue() -> void:
	if is_instance_valid(dialogue_panel):
		dialogue_panel.queue_free()
	if is_instance_valid(typewriter):
		typewriter.queue_free()
	dialogue_panel = null
	dialogue_body_label = null
	typewriter = null
	dialogue_lines.clear()
	dialogue_index = 0


# ── 정지 이미지 컷(기록 화면) ──────────────────────────────────


func _open_image_cut(step: Dictionary) -> void:
	# 신규 아트는 만들지 않는다. 이미 있는 프롭·초상 텍스처를 크게 띄우고
	# 비네팅과 타자기 문장을 얹어 "회수한 문서를 들여다보는 순간"으로 쓴다.
	var lines: Array[String] = []
	lines.assign(step.get("lines", []))
	image_cut_root = Control.new()
	image_cut_root.name = "CineImageCut"
	image_cut_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_cut_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(image_cut_root)
	layer.move_child(image_cut_root, 0)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.008, 0.008, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	image_cut_root.add_child(dim)
	var picture := TextureRect.new()
	picture.name = "CutPicture"
	picture.texture = _resolve_texture(step.get("texture", null))
	picture.set_anchors_preset(Control.PRESET_CENTER)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var picture_size := minf(viewport_size.x * 0.52, viewport_size.y * 0.46)
	picture.offset_left = -picture_size * 0.5
	picture.offset_right = picture_size * 0.5
	picture.offset_top = -picture_size * 0.5 - 42.0
	picture.offset_bottom = picture_size * 0.5 - 42.0
	picture.modulate = Color(1.0, 0.96, 0.86, 0.0)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_cut_root.add_child(picture)
	var caption_panel := PanelContainer.new()
	caption_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half := minf(430.0, (viewport_size.x - 32.0) * 0.5)
	caption_panel.offset_left = -half
	caption_panel.offset_right = half
	caption_panel.offset_bottom = -96.0
	caption_panel.offset_top = -96.0 - 118.0
	caption_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.02, 0.03, 0.028, 0.92), Color("#8a7b4c"))
	)
	image_cut_root.add_child(caption_panel)
	var caption_box := VBoxContainer.new()
	caption_box.add_theme_constant_override("separation", 8)
	caption_panel.add_child(caption_box)
	var cut_title := Label.new()
	cut_title.text = str(step.get("title", "회수한 기록"))
	cut_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_title.add_theme_font_override("font", FONT)
	cut_title.add_theme_font_size_override("font_size", 15)
	cut_title.add_theme_color_override("font_color", Color("#e7d49a"))
	caption_box.add_child(cut_title)
	var cut_body := Label.new()
	cut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cut_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cut_body.add_theme_font_override("font", FONT)
	cut_body.add_theme_font_size_override("font_size", 16)
	cut_body.add_theme_color_override("font_color", Color("#d9e2dc"))
	caption_box.add_child(cut_body)
	var close_button := _make_button("계속", "collect")
	close_button.custom_minimum_size = Vector2(150, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func() -> void:
		_close_image_cut()
		_advance()
	)
	caption_box.add_child(close_button)
	dialogue_lines.assign(lines)
	typewriter = Typewriter.new()
	layer.add_child(typewriter)
	typewriter.attach(cut_body)
	typewriter.start("\n".join(lines))
	var tween := _make_tween()
	tween.tween_property(picture, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func _close_image_cut() -> void:
	if is_instance_valid(image_cut_root):
		image_cut_root.queue_free()
	image_cut_root = null
	if is_instance_valid(typewriter):
		typewriter.queue_free()
	typewriter = null


# ── 선택지 ─────────────────────────────────────────────────────


func _open_choice(step: Dictionary) -> void:
	var options := step.get("options", []) as Array
	if options.is_empty():
		_advance()
		return
	# 선택지는 빨리 감기로도 못 넘긴다. 여기서 fast_forward를 끊는다.
	_fast_forward = false
	choice_root = Control.new()
	choice_root.name = "CineChoiceRoot"
	choice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(choice_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.008, 0.008, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_root.add_child(dim)
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half := minf(430.0, (viewport_size.x - 32.0) * 0.5)
	panel.offset_left = -half
	panel.offset_right = half
	panel.offset_bottom = -40.0
	panel.offset_top = -40.0 - 44.0 - float(options.size()) * 62.0
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.012, 0.019, 0.018, 0.985), Color("#c9a24d"))
	)
	choice_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var prompt := Label.new()
	prompt.text = str(step.get("prompt", "결정해라"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_override("font", FONT)
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color("#e7d49a"))
	box.add_child(prompt)
	var choice_id := str(step.get("id", "choice"))
	var handler: Variant = step.get("on_choice", null)
	for option_value in options:
		var option := option_value as Dictionary
		var button := _make_button(str(option.get("label", "…")), "collect")
		button.custom_minimum_size = Vector2(0, 52)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var detail := str(option.get("detail", ""))
		if not detail.is_empty():
			button.text = "%s   —   %s" % [str(option.get("label", "…")), detail]
		button.pressed.connect(func() -> void:
			_resolve_choice(choice_id, option, handler)
		)
		box.add_child(button)


func _resolve_choice(choice_id: String, option: Dictionary, handler: Variant) -> void:
	if is_instance_valid(choice_root):
		choice_root.queue_free()
	choice_root = null
	# 선택은 저장에 남는다 — 나중 대사와 엔딩 문구가 이걸 읽는다.
	GameState.record_mission_choice(choice_id, str(option.get("id", "")))
	if handler is Callable and (handler as Callable).is_valid():
		(handler as Callable).call(str(option.get("id", "")))
	_advance()


# ── 공용 ───────────────────────────────────────────────────────


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _resolve_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	var path := str(value)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func is_waiting_for_input() -> bool:
	return (
		is_instance_valid(dialogue_panel)
		or is_instance_valid(image_cut_root)
		or is_instance_valid(choice_root)
	)


func advance_from_anywhere() -> bool:
	# '다음' 버튼을 못 찾거나 못 누르는 상황(작은 버튼, 겹침, 입력 경로 문제)
	# 에서도 연출이 벽이 되지 않게 — 화면 아무 곳이나 탭/클릭, 스페이스/엔터로
	# 진행한다. 선택지는 예외: 결정을 대신 해 주지 않는다.
	if is_instance_valid(choice_root):
		return false
	if is_instance_valid(dialogue_panel):
		_advance_dialogue()
		return true
	if is_instance_valid(image_cut_root):
		_close_image_cut()
		_advance()
		return true
	return false


class CinematicInputRelay extends Node:
	# 연출 레이어에 붙는 입력 중계 + 멈춤 자가 복구 노드.
	var cinematic: RefCounted

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _exit_tree() -> void:
		# 연출 도중 판이 치워지면(사망·탈출·씬 교체) 시네마틱이 건 일시정지를
		# 반드시 돌려놓는다 — 다음 씬이 멈춘 채 태어나면 안 된다.
		# 단, 정상 종료로 치워지는 옛 레이어(_finish가 layer를 null로 비운 뒤
		# queue_free)는 제외 — 바크 직후 시작한 event 연출의 일시정지를 풀어 버린다.
		if cinematic == null or cinematic.get("layer") != get_parent():
			return
		if bool(cinematic.get("_paused_by_cinematic")):
			cinematic.call("_resume_world")

	func _process(_delta: float) -> void:
		# 시네마틱 도중 트리가 일시정지로 남으면(포커스 자동 일시정지가
		# 안 풀리는 등) 대화·트윈·버튼이 전부 죽어 '벽돌'이 된다. 연출 중
		# 정당한 일시정지는 ESC 메뉴와 시네마틱 자신(event 모드)뿐이므로,
		# 그 외에는 즉시 되살린다. 바크 모드는 조작이 살아 있어 전리품 교체 모달 등
		# 정당한 일시정지가 얼마든지 올 수 있다 — 복구 대상이 아니다(is_active = event만).
		if cinematic == null or not bool(cinematic.call("is_active")):
			return
		if bool(cinematic.get("_paused_by_cinematic")):
			return
		var tree := get_tree()
		if tree == null or not tree.paused:
			return
		var cinematic_host: Node = cinematic.get("host")
		if cinematic_host != null:
			var menu := cinematic_host.get_node_or_null("PauseMenu")
			if menu != null and bool(menu.call("is_open")):
				return
		tree.paused = false

	func _unhandled_input(event: InputEvent) -> void:
		# 바크 모드는 입력을 가로채지 않는다 — 클릭은 사격이고 탭은 이동이다.
		if cinematic == null or not bool(cinematic.call("is_active")):
			return
		var advance := false
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			advance = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			advance = (event as InputEventScreenTouch).pressed
		elif event is InputEventKey:
			var key := event as InputEventKey
			advance = (
				key.pressed
				and not key.echo
				and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_F]
			)
		if not advance:
			return
		if bool(cinematic.call("advance_from_anywhere")):
			get_viewport().set_input_as_handled()
