class_name LoreReader
extends RefCounted

# 설화(로어) 열람 화면. main.gd에서 146줄을 떼어냈다.
#
# 열고 닫을 때 포인터 모드나 HUD를 다시 계산해야 하는데, 그건 이 화면이
# 알 바가 아니다. 시그널로 알리고 main이 처리한다.

signal opened()
signal closed()
signal lore_discovered()

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const HudStyle := preload("res://scripts/hud/hud_style.gd")
const LORE_ENTRIES := preload("res://scripts/lore_catalog.gd").ENTRIES
const LORE_POSTER_TEXTURE := preload("res://assets/lore/forgotten_notice_board_v1.png")

var ui_layer: CanvasLayer
var ui_panel: PanelContainer
var title_label: Label
var body_label: Label
var source_label: Label
var progress_label: Label
var clues_discovered: int = 0


func build(host: Node) -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "LoreReaderLayer"
	ui_layer.layer = 165
	ui_layer.visible = false
	host.add_child(ui_layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.007, 0.008, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(center)
	# 디자인 언어(2026-09-04, 이름 짓기 화면 기준): 거의 검정 모달·보더 없음, 민트
	# 이름표 + 굵은 제목 + 회색 출처, 본문은 흰 글자에 넉넉한 줄간격. 금색 없음.
	ui_panel = PanelContainer.new()
	ui_panel.name = "LoreReaderPanel"
	var panel_style := HudStyle.modal()
	# 안쪽 여백은 아래 MarginContainer가 맡는다(세로 화면에서 apply_layout이 줄인다).
	panel_style.content_margin_left = 0.0
	panel_style.content_margin_right = 0.0
	panel_style.content_margin_top = 0.0
	panel_style.content_margin_bottom = 0.0
	ui_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(ui_panel)

	var margin := MarginContainer.new()
	margin.name = "LoreReaderMargin"
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_name, 28)
	ui_panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 20)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root_box.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 4)
	header.add_child(heading)
	var eyebrow := HudStyle.label("기록", HudStyle.TYPE_CAPTION, HudStyle.ACCENT)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(eyebrow)
	title_label = HudStyle.label("", HudStyle.TYPE_TITLE, HudStyle.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title_label)
	source_label = HudStyle.label("", HudStyle.TYPE_BODY, HudStyle.TEXT_DIM)
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(source_label)
	var close_button := HudStyle.close_button(UI_ICONS.get_icon("close", 22, HudStyle.TEXT))
	close_button.name = "LoreCloseButton"
	close_button.tooltip_text = "기록 닫기"
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var content := HBoxContainer.new()
	content.name = "LoreReaderContent"
	content.add_theme_constant_override("separation", 22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content)
	# 포스터는 무광 표면 카드 위에 얹는다.
	var preview_card := PanelContainer.new()
	preview_card.name = "LorePosterCard"
	var preview_style := HudStyle.flat(HudStyle.INK_WELL, HudStyle.RADIUS_CARD)
	preview_style.content_margin_left = 10.0
	preview_style.content_margin_right = 10.0
	preview_style.content_margin_top = 10.0
	preview_style.content_margin_bottom = 10.0
	preview_card.add_theme_stylebox_override("panel", preview_style)
	preview_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview_card)
	var preview := TextureRect.new()
	preview.name = "LorePosterPreview"
	preview.texture = LORE_POSTER_TEXTURE
	preview.custom_minimum_size = Vector2(330, 250)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.add_child(preview)

	var text_box := VBoxContainer.new()
	text_box.name = "LoreReaderText"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 12)
	content.add_child(text_box)
	var scroll := HudStyle.make_scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_box.add_child(scroll)
	body_label = HudStyle.label("", HudStyle.TYPE_HEADING, HudStyle.TEXT)
	body_label.custom_minimum_size = Vector2(360, 190)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_constant_override("line_spacing", 9)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body_label)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_override("font", HudStyle.tabular())
	progress_label.add_theme_font_size_override("font_size", HudStyle.TYPE_CAPTION + 1)
	progress_label.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(progress_label)


func is_open() -> bool:
	return is_instance_valid(ui_layer) and ui_layer.visible


func show_entry(point: Node3D) -> void:
	if not is_instance_valid(point):
		return
	var entry_index := clampi(int(point.get_meta("lore_index", 0)), 0, LORE_ENTRIES.size() - 1)
	var entry := LORE_ENTRIES[entry_index] as Dictionary
	if not bool(point.get_meta("read", false)):
		point.set_meta("read", true)
		clues_discovered += 1
		lore_discovered.emit()
		var marker_label := point.get_node_or_null("LoreMarkerLabel") as Label3D
		if marker_label:
			marker_label.text = "확인한 기록"
			marker_label.modulate = HudStyle.TEXT_DIM
	title_label.text = str(entry.get("title", "이름 없는 기록"))
	source_label.text = str(entry.get("source", "출처 불명"))
	body_label.text = str(entry.get("body", "기록이 심하게 망가져서 읽을 수 없다."))
	progress_label.text = "발견한 세계 기록  %d / %d" % [
		clues_discovered,
		LORE_ENTRIES.size(),
	]
	ui_layer.visible = true
	HudStyle.enter_modal(ui_panel)
	opened.emit()


func close() -> void:
	if not is_instance_valid(ui_layer):
		return
	ui_layer.visible = false
	closed.emit()

func apply_layout(viewport_size: Vector2) -> void:
	if ui_panel == null:
		return
	var lore_compact := viewport_size.x < 760.0 or viewport_size.y < 540.0
	var lore_margin := 16 if lore_compact else 28
	ui_panel.custom_minimum_size = Vector2(
		maxf(280.0, minf(900.0, viewport_size.x - 20.0)),
		maxf(260.0, minf(540.0, viewport_size.y - 20.0))
	)
	var lore_margin_container := ui_panel.get_node_or_null(
		"LoreReaderMargin"
	) as MarginContainer
	if lore_margin_container:
		for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			lore_margin_container.add_theme_constant_override(margin_name, lore_margin)
	var lore_content := ui_panel.find_child(
		"LoreReaderContent",
		true,
		false
	) as HBoxContainer
	if lore_content:
		lore_content.add_theme_constant_override("separation", 10 if lore_compact else 22)
	var lore_preview := ui_panel.find_child(
		"LorePosterPreview",
		true,
		false
	) as TextureRect
	if lore_preview:
		lore_preview.custom_minimum_size = (
			Vector2(clampf(viewport_size.x * 0.25, 90.0, 180.0), 150.0)
			if lore_compact
			else Vector2(330.0, 250.0)
		)
	if body_label:
		body_label.custom_minimum_size = (
			Vector2(clampf(viewport_size.x * 0.38, 130.0, 250.0), 130.0)
			if lore_compact
			else Vector2(360.0, 190.0)
		)
	if title_label:
		title_label.add_theme_font_size_override(
			"font_size",
			HudStyle.TYPE_NUMBER if lore_compact else HudStyle.TYPE_TITLE
		)

