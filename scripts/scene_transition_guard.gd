extends CanvasLayer

signal transition_started(target_path: String)
signal transition_finished(target_path: String)
signal transition_failed(target_path: String, error_code: int)

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const HudStyle := preload("res://scripts/hud/hud_style.gd")

const PROGRESS_WIDTH := 260.0
const PROGRESS_HEIGHT := 5.0

var active := false
var target_scene_path := ""
var fallback_scene_path := ""
var fade: ColorRect
var status_label: Label
var progress_track: Panel
var progress_fill: Panel
var progress_tween: Tween


func _ready() -> void:
	layer = 245
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 웹 모바일: 브라우저 주소창을 접고 화면을 꽉 쓰려면 사용자 제스처가
	# 필요하다. 첫 탭에서 한 번만 전체화면을 요청한다.
	set_process_unhandled_input(OS.has_feature("web"))
	# 세로모드 지원의 뿌리: 기준 해상도(1280×720)가 가로 고정이면 세로 화면에서
	# 스케일이 가로폭 기준으로 잡혀 UI 전체가 깨알이 된다. 방향이 바뀔 때마다
	# 기준을 720×1280으로 스왑해, 어느 방향이든 짧은 축이 720으로 유지되게 한다.
	get_viewport().size_changed.connect(_apply_orientation_scale)
	_apply_orientation_scale()


func _apply_orientation_scale() -> void:
	var window := get_window()
	if window == null:
		return
	var window_size := window.size
	var portrait := window_size.y > window_size.x
	var wanted := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
		# content_scale_size 변경은 size_changed를 다시 쏘지 않는다 — 이 핸들러보다
		# 먼저 돌았던 다른 UI 레이아웃들은 스왑 '직전'의 캔버스 폭으로 굳는다
		# (세로모드 무기 상세창이 오른쪽으로 밀리던 원인). 새 기준으로 전원 재통지.
		get_viewport().size_changed.emit.call_deferred()
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.position = Vector2(-180, 36)
	status_label.size = Vector2(360, 40)
	status_label.text = "이동 준비 중"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#b8cac2"))
	status_label.add_theme_font_override("font", HudStyle.bold())
	status_label.modulate.a = 0.0
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	_build_progress_bar()


func _build_progress_bar() -> void:
	# 화면 정중앙(상태 문구 바로 위)에 얇은 트랙 하나. 본편 언어대로 테두리 없이
	# 표면색 트랙 + 민트 채움, 모서리는 알약.
	progress_track = Panel.new()
	progress_track.name = "TransitionProgressTrack"
	progress_track.set_anchors_preset(Control.PRESET_CENTER)
	progress_track.offset_left = -PROGRESS_WIDTH * 0.5
	progress_track.offset_right = PROGRESS_WIDTH * 0.5
	progress_track.offset_top = 8.0
	progress_track.offset_bottom = 8.0 + PROGRESS_HEIGHT
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_theme_stylebox_override(
		"panel", HudStyle.flat(Color(HudStyle.SURFACE_RAISED, 0.85), 999)
	)
	progress_track.modulate.a = 0.0
	add_child(progress_track)
	progress_fill = Panel.new()
	progress_fill.name = "TransitionProgressFill"
	progress_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	progress_fill.offset_left = 0.0
	progress_fill.offset_right = 0.0
	progress_fill.offset_top = 0.0
	progress_fill.offset_bottom = 0.0
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill.add_theme_stylebox_override("panel", HudStyle.flat(HudStyle.ACCENT, 999))
	progress_track.add_child(progress_fill)


func _set_progress(ratio: float, duration: float) -> void:
	# 실제 로드 진척률을 알 수 없는 구간(change_scene_to_file은 동기)이라,
	# 단계별 목표치까지 시간으로 채운다. 뒤로 가지는 않게 최대값만 취한다.
	if progress_track == null or progress_fill == null:
		return
	var target := clampf(ratio, 0.0, 1.0) * PROGRESS_WIDTH
	if target <= progress_fill.offset_right:
		return
	if progress_tween != null and progress_tween.is_valid():
		progress_tween.kill()
	progress_tween = create_tween()
	progress_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	progress_tween.tween_property(progress_fill, "offset_right", target, duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)


func transition_to(scene_path: String, fallback_path: String = "res://scenes/shelter_interior.tscn") -> bool:
	if active or scene_path.is_empty():
		return false
	active = true
	target_scene_path = scene_path
	fallback_scene_path = fallback_path
	transition_started.emit(scene_path)
	_release_held_inputs()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("save_persistent_state"):
		game_state.call("save_persistent_state")
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	status_label.text = "상태 저장 중 · 이동 준비"
	if progress_fill != null:
		progress_fill.offset_right = 0.0
	_set_progress(0.35, 0.3)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 0.3)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(progress_track, "modulate:a", 1.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(_commit_transition)
	return true


func _commit_transition() -> void:
	var requested_path := target_scene_path
	if not ResourceLoader.exists(requested_path):
		_finish_failed_transition(requested_path, ERR_FILE_NOT_FOUND)
		return
	var error := get_tree().change_scene_to_file(requested_path)
	if error != OK:
		_finish_failed_transition(requested_path, error)
		return
	status_label.text = "불러오는 중"
	_set_progress(0.75, 0.25)
	call_deferred("_finish_successful_transition", requested_path)


func _finish_successful_transition(requested_path: String) -> void:
	await get_tree().process_frame
	# 100%를 한 박자 보여 주고 나간다 — 막대가 중간에서 사라지면 실패로 읽힌다.
	_set_progress(1.0, 0.16)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.16)
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 0.0, 0.42)
	tween.tween_property(status_label, "modulate:a", 0.0, 0.18)
	tween.tween_property(progress_track, "modulate:a", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active = false
		transition_finished.emit(requested_path)
	)


func _finish_failed_transition(requested_path: String, error: int) -> void:
	transition_failed.emit(requested_path, error)
	if not fallback_scene_path.is_empty() and fallback_scene_path != requested_path and ResourceLoader.exists(fallback_scene_path):
		target_scene_path = fallback_scene_path
		status_label.text = "이동 실패 · 안전 지점으로 복구"
		call_deferred("_commit_transition")
		return
	status_label.text = "이동할 수 없습니다 · 다시 시도해 주세요"
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 0.0, 0.35)
	tween.tween_property(status_label, "modulate:a", 0.0, 0.35).set_delay(0.8)
	tween.tween_property(progress_track, "modulate:a", 0.0, 0.35).set_delay(0.8)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active = false
	)


func _release_held_inputs() -> void:
	Input.action_release("ui_accept")
	Input.action_release("ui_cancel")
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")


var _fullscreen_requested := false


func _unhandled_input(event: InputEvent) -> void:
	if _fullscreen_requested:
		return
	var is_press := (
		(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	)
	if not is_press:
		return
	_fullscreen_requested = true
	set_process_unhandled_input(false)
	# 브라우저가 거부해도 무해하다(데스크톱 미리보기 포함).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
