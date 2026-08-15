class_name ModalDismiss
extends Node

# 모달 닫기의 단일 문법. 시설 다섯 개가 각자 다른 방식(람다/메서드/무ESC)으로
# 닫히던 것을 하나로 모은다: ESC · 안드로이드 뒤로가기 · 바깥(딤) 탭.
# 사용: ModalDismiss.install(ui_layer, dim, close_callable)

var close_action: Callable


static func install(layer_node: Node, dim: Control, close_action_value: Callable) -> ModalDismiss:
	var relay := ModalDismiss.new()
	relay.name = "ModalDismiss"
	relay.close_action = close_action_value
	layer_node.add_child(relay)
	if dim != null:
		dim.gui_input.connect(func(event: InputEvent) -> void:
			var released: bool = (
				(event is InputEventMouseButton and not event.pressed
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
				or (event is InputEventScreenTouch and not event.pressed)
			)
			if released:
				relay._close()
		)
	return relay


func _close() -> void:
	if close_action.is_valid():
		close_action.call()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()


func _notification(what: int) -> void:
	# 안드로이드 시스템 뒤로가기 — 주 플랫폼인데 지금까지 전면 미대응이었다.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()
