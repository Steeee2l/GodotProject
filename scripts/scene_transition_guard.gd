extends CanvasLayer

signal transition_started(target_path: String)
signal transition_finished(target_path: String)
signal transition_failed(target_path: String, error_code: int)

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var active := false
var target_scene_path := ""
var fallback_scene_path := ""
var fade: ColorRect
var status_label: Label


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
	status_label.modulate.a = 0.0
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)


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
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 0.3)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
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
	call_deferred("_finish_successful_transition", requested_path)


func _finish_successful_transition(requested_path: String) -> void:
	await get_tree().process_frame
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 0.0, 0.42)
	tween.tween_property(status_label, "modulate:a", 0.0, 0.18)
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
