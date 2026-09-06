class_name DebugGate
extends RefCounted

## 개발자 메뉴 잠금 — 코드 한 번 넣어야 열린다.
##
## 빌드를 공개해도 개발자 도구는 나만 쓰려고 만들었다. 예전에는 9키(PC)와
## 좌하단 "DEV" 버튼(모바일)이 그냥 열려 있었다. 이제 입구는 하나(0키 / 구석의
## 표식 없는 버튼)이고, 그 뒤에 4자리 코드 입력이 선다.
##
## 한 번 통과하면 이 프로세스가 끝날 때까지 다시 묻지 않는다(static unlocked) —
## 디버깅 중에 매번 타이핑하면 도구로 쓸모가 없다. 게임을 다시 켜면 다시 잠긴다.
##
## 쓰는 쪽:
##   DebugGate.request(host_node, func() -> void: debug_menu.call("toggle"))

const LOC := preload("res://scripts/hud/loc.gd")

const HudStyle := preload("res://scripts/hud/hud_style.gd")
const CODE := "2943"
const LAYER_INDEX := 142  # 디버그 메뉴(140)보다 위 — 게이트가 메뉴에 가리면 안 된다.

static var unlocked := false


static func request(host: Node, on_unlocked: Callable) -> void:
	# 이미 통과한 세션이면 바로 연다. 아니면 코드 창을 띄운다.
	if host == null or not is_instance_valid(host):
		return
	if unlocked:
		on_unlocked.call()
		return
	var tree := host.get_tree()
	if tree == null or tree.root == null:
		return
	# 창이 이미 떠 있으면 두 번 띄우지 않는다(0키 연타).
	if tree.root.get_node_or_null("DebugGateCanvas") != null:
		return
	_build(tree.root, on_unlocked)


static func _build(root: Node, on_unlocked: Callable) -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugGateCanvas"
	canvas.layer = LAYER_INDEX
	# 일시정지·사망 중에도 열려야 도구다.
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(canvas)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "DebugGatePanel"
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", HudStyle.modal())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(HudStyle.label(LOC.t("잠김"), HudStyle.TYPE_CAPTION, HudStyle.ACCENT, true))
	box.add_child(HudStyle.label(LOC.t("개발자 메뉴"), 22, HudStyle.TEXT, true))

	var field := LineEdit.new()
	field.name = "DebugGateCode"
	field.placeholder_text = LOC.t("코드")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 8
	field.secret = true
	# 폰에서 숫자 자판이 바로 뜨게 — 네 자리를 찾아 헤매지 않는다.
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	field.custom_minimum_size = Vector2(0, 44)
	field.add_theme_font_override("font", HudStyle.bold_tabular())
	field.add_theme_font_size_override("font_size", 20)
	field.add_theme_color_override("font_color", HudStyle.TEXT)
	field.add_theme_color_override("caret_color", HudStyle.ACCENT)
	field.add_theme_stylebox_override("normal", HudStyle.flat(HudStyle.SURFACE_RAISED, 10))
	field.add_theme_stylebox_override("focus", HudStyle.accent_panel(HudStyle.SURFACE_RAISED, HudStyle.ACCENT, 10))
	box.add_child(field)

	var hint := HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.DANGER)
	hint.name = "DebugGateHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = LOC.t("닫기")
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudStyle.style_button(cancel)
	row.add_child(cancel)
	var confirm := Button.new()
	confirm.name = "DebugGateConfirm"
	confirm.text = LOC.t("열기")
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudStyle.style_button(confirm, HudStyle.ACCENT, true)
	row.add_child(confirm)

	var close := func() -> void:
		if is_instance_valid(canvas):
			canvas.queue_free()
	var submit := func() -> void:
		if field.text.strip_edges() == CODE:
			unlocked = true
			close.call()
			on_unlocked.call()
			return
		# 틀리면 이유만 말하고 비운다 — 몇 번 틀렸는지 세지 않는다(나만 쓰는 문이다).
		hint.text = LOC.t("코드가 다릅니다")
		field.text = ""
		field.grab_focus()

	cancel.pressed.connect(close)
	confirm.pressed.connect(submit)
	field.text_submitted.connect(func(_text: String) -> void: submit.call())
	dim.gui_input.connect(func(event: InputEvent) -> void:
		# 딤을 누르면 닫는다(다른 모달과 같은 규칙).
		var tapped := (
			(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		)
		if tapped:
			close.call()
	)
	HudStyle.enter_modal(panel)
	field.call_deferred("grab_focus")
