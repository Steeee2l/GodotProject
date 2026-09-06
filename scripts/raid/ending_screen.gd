extends RefCounted

# 엔딩 화면 — 마지막 출정의 문 앞 연출이 끝난 뒤 딱 한 장.
#
# 여기서 말하는 건 둘뿐이다.
#   (a) 무엇을 봤는가   — 문 안쪽. 서른여섯. 자리는 모자라지 않았다.
#   (b) 사자가 무엇을 놓았는가 — 반년 동안 문 앞에 놓던 통조림, 그리고 세던 숫자.
# 크레딧도 없고 팡파레도 없다. 버튼 하나로 쉘터로 돌아가고, 게임은 계속 돈다.
#
# 레이어 134 — 시네마틱(133) 위, 일시정지 메뉴(135) 아래. 화면 한가운데를 쓰는
# 유일한 예외다(중앙 알림 금지 규칙은 '판이 도는 중'의 이야기고, 여기는 판이 끝난 뒤다).

const HUD_STYLE := preload("res://scripts/hud/hud_style.gd")

const LAYER_INDEX := 134
const PANEL_MAX_WIDTH := 640.0

var host: Node
var layer: CanvasLayer
var panel: PanelContainer
var _on_closed := Callable()


func attach(owner_node: Node) -> void:
	host = owner_node


func is_open() -> bool:
	return is_instance_valid(layer)


func show_ending(sections: Array, on_closed := Callable()) -> void:
	# sections = [{"caption": "본 것", "body": "..."}, ...] — 데이터는 FinalJourney가 쥔다.
	if is_open() or not is_instance_valid(host):
		if on_closed.is_valid():
			on_closed.call()
		return
	_on_closed = on_closed
	layer = CanvasLayer.new()
	layer.name = "EndingScreenLayer"
	layer.layer = LAYER_INDEX
	# 트리가 멈춰 있어도 살아 있어야 한다(연출 직후 그대로 이어받는다).
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.name = "EndingBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 완전 불투명 — 0.985로 뒀더니 위쪽 배너와 HUD가 비쳐서, 판이 끝난 화면에
	# 판이 도는 화면이 겹쳐 보였다.
	backdrop.color = Color(0.016, 0.02, 0.024, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	panel = PanelContainer.new()
	panel.name = "EndingPanel"
	panel.add_theme_stylebox_override("panel", HUD_STYLE.modal())
	var viewport_size := host.get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x = minf(PANEL_MAX_WIDTH, maxf(280.0, viewport_size.x - 40.0))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	column.add_child(HUD_STYLE.label("마지막 출정", HUD_STYLE.TYPE_CAPTION, HUD_STYLE.ACCENT, true))
	column.add_child(HUD_STYLE.label("문 앞에서", HUD_STYLE.TYPE_TITLE, HUD_STYLE.TEXT, true))

	for section_value in sections:
		var section := section_value as Dictionary
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", HUD_STYLE.card())
		column.add_child(card)
		var card_column := VBoxContainer.new()
		card_column.add_theme_constant_override("separation", 6)
		card.add_child(card_column)
		card_column.add_child(
			HUD_STYLE.label(
				str(section.get("caption", "")), HUD_STYLE.TYPE_CAPTION, HUD_STYLE.TEXT_DIM, true
			)
		)
		var body := HUD_STYLE.label(
			GameState.apply_player_name(str(section.get("body", ""))),
			HUD_STYLE.TYPE_BODY,
			HUD_STYLE.TEXT
		)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = panel.custom_minimum_size.x - 80.0
		card_column.add_child(body)

	var footnote := HUD_STYLE.label(
		"서울에서 알아낼 것은 다 알아냈다. 쉘터는 내일도 돌아간다.",
		HUD_STYLE.TYPE_FOOTNOTE,
		HUD_STYLE.TEXT_FAINT
	)
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footnote)

	var button := Button.new()
	button.name = "EndingReturnButton"
	button.text = "쉘터로 돌아간다"
	button.custom_minimum_size.y = 52
	HUD_STYLE.style_button(button, HUD_STYLE.ACCENT, true)
	button.pressed.connect(close, CONNECT_DEFERRED)
	column.add_child(button)

	HUD_STYLE.enter_modal(panel)


func close() -> void:
	if not is_open():
		return
	layer.queue_free()
	layer = null
	panel = null
	var callback := _on_closed
	_on_closed = Callable()
	if callback.is_valid():
		callback.call()
