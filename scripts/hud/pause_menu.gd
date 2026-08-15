class_name PauseMenu
extends Node
## ESC(데스크톱)·안드로이드 뒤로가기(모달이 없을 때) 일시정지 메뉴.
## 지금까지 게임을 끝내는 유일한 수단이 Alt+F4였다 — 저장하고 나가는
## 정상 출구를 만든다. 트리 일시정지 위에서도 동작해야 하므로 ALWAYS.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var can_pause: Callable
var quit_label := "저장 후 종료"
var layer: CanvasLayer


static func install(host: Node, can_pause_check: Callable, quit_text: String) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.name = "PauseMenu"
	menu.can_pause = can_pause_check
	menu.quit_label = quit_text
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(menu)
	return menu


func is_open() -> bool:
	return is_instance_valid(layer)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if is_open():
				_close()
				get_viewport().set_input_as_handled()
			elif can_pause.is_valid() and bool(can_pause.call()):
				_open()
				get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# 모달이 떠 있으면 그쪽 ModalDismiss가 소비한다. 아무것도 없을 때의
	# 안드로이드 뒤로가기는 "나가고 싶다"는 뜻 — 일시정지 메뉴가 받는다.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not is_open():
		if can_pause.is_valid() and bool(can_pause.call()):
			_open()


func _open() -> void:
	if is_open():
		return
	get_tree().paused = true
	layer = CanvasLayer.new()
	layer.name = "PauseMenuLayer"
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.009, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	dim.gui_input.connect(func(dim_event: InputEvent) -> void:
		if dim_event is InputEventMouseButton and not (dim_event as InputEventMouseButton).pressed:
			_close()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", HudStyle.panel(HudStyle.INK, HudStyle.LINE))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := HudStyle.label("일시 정지", HudStyle.TYPE_HEADING, HudStyle.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := _button("계속하기")
	resume.pressed.connect(_close)
	box.add_child(resume)

	var quit := _button(quit_label)
	quit.pressed.connect(func() -> void:
		GameState.save_persistent_state()
		get_tree().quit()
	)
	box.add_child(quit)

	# 등장 모션 — 띡 나오지 않는다.
	panel.pivot_offset = Vector2(160, 60)
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	if not is_open():
		return
	get_tree().paused = false
	layer.queue_free()
	layer = null


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	HudStyle.style_button(button, HudStyle.TEXT_DIM)
	return button
