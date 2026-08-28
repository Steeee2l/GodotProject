class_name PauseMenu
extends Node
## ESC(데스크톱)·안드로이드 뒤로가기(모달이 없을 때) 일시정지 메뉴.
## 지금까지 게임을 끝내는 유일한 수단이 Alt+F4였다 — 저장하고 나가는
## 정상 출구를 만든다. 트리 일시정지 위에서도 동작해야 하므로 ALWAYS.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var can_pause: Callable
var quit_label := "저장 후 종료"
var quit_caption := ""
var layer: CanvasLayer


static func install(
	host: Node, can_pause_check: Callable, quit_text: String, quit_note := ""
) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.name = "PauseMenu"
	menu.can_pause = can_pause_check
	menu.quit_label = quit_text
	menu.quit_caption = quit_note
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
	# 96에서는 필드 HUD(장전 바·조준선 등 높은 레이어)가 창 위로 뚫고 나왔다
	# (유저 스크린샷). 일시정지는 화면의 최상단이어야 한다.
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.009, 0.82)
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
	panel.custom_minimum_size = Vector2(
		minf(340.0, get_viewport().get_visible_rect().size.x - 40.0), 0
	)
	var panel_style := HudStyle.panel(HudStyle.INK, HudStyle.LINE_GOLD, HudStyle.RADIUS_CARD)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := HudStyle.label("일시 정지", HudStyle.TYPE_CAPTION, HudStyle.GOLD_TEXT)
	box.add_child(title)
	var divider := ColorRect.new()
	divider.color = Color(HudStyle.LINE_GOLD, 0.5)
	divider.custom_minimum_size = Vector2(0, 1)
	box.add_child(divider)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	var resume := _button("계속하기", true)
	resume.pressed.connect(_close)
	box.add_child(resume)

	var quit := _button(quit_label, false)
	quit.pressed.connect(func() -> void:
		GameState.save_persistent_state()
		get_tree().quit()
	)
	box.add_child(quit)
	if not quit_caption.is_empty():
		var caption := HudStyle.label(quit_caption, HudStyle.TYPE_CAPTION, HudStyle.TEXT_DIM)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(caption)

	# 등장 모션 — 띡 나오지 않는다.
	HudStyle.enter_modal(panel)


func _close() -> void:
	if not is_open():
		return
	get_tree().paused = false
	layer.queue_free()
	layer = null


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_NONE
	HudStyle.style_button(button, HudStyle.GOLD if primary else HudStyle.TEXT_DIM, primary)
	return button
