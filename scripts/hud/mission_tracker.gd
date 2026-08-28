class_name MissionTracker
extends RefCounted

# 좌상단 임무 트래커 카드 — "메모장 텍스트" 나열(유저 신고: 성의없어 보임)을
# 카드 한 장으로 바꾼다.
#
#   ┌─────────────────────────────┐
#   │ ◆ [방어 작전] 급수탑 방어      [TAB]│  ← 아이콘 + 제목(굵게) + 지도 키캡
#   │   구역 방어 12.4초 · 접근 3   │  ← 현재 목표 1줄
#   │   ▬▬▬▬▬▬▬▬░░░░              │  ← 수치형이면 얇은 바 / 다단계면 핍 ●●○
#   │   ✓ 기초 부품 확보 3/3        │  ← 보조 목표 체크 행
#   │   ○ 지하철역 입구 조사 0/1     │
#   └─────────────────────────────┘
#
# host 패턴: main.gd가 attach → build(objective_panel)만 부른다. 데이터는
# host가 set_state(state)로 밀어 넣는다(방어 타이머처럼 매 프레임 불려도 되게
# 라벨 텍스트만 갱신하고, 행 구조는 시그니처가 바뀔 때만 다시 짓는다).
#
# 전투 중 읽는 UI다 — 애니메이션은 "목표가 바뀐 순간의 펄스 1회"뿐.

const HudStyle := preload("res://scripts/hud/hud_style.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const MAX_WIDTH := 300.0
const PULSE_COOLDOWN := 3.0
const MAX_SUB_ROWS := 4

var host: Node
var panel: PanelContainer
var content: VBoxContainer
var icon_rect: TextureRect
var title_label: Label
var map_key_chip: PanelContainer
var objective_label: Label
var progress_bar: ProgressBar
var progress_fill: StyleBoxFlat
var pip_row: HBoxContainer
var sub_box: VBoxContainer
var pulse_overlay: ColorRect

var last_title := ""
var last_sub_signature := ""
var last_pulse_msec := -100000


func attach(owner_node: Node) -> void:
	host = owner_node


func build(mount: PanelContainer) -> void:
	panel = mount
	# 씬에 있던 통짜 Label은 은퇴 — 노드는 남겨 두되(참조 안전) 그리지 않는다.
	for child in panel.get_children():
		if child is Control:
			(child as Control).visible = false
	var style := HudStyle.panel(HudStyle.INK, HudStyle.LINE_GOLD, HudStyle.RADIUS_CARD)
	style.border_width_left = 3
	style.content_margin_left = 11.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true

	content = VBoxContainer.new()
	content.name = "MissionTrackerBox"
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var header := HBoxContainer.new()
	header.name = "TrackerHeader"
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)
	icon_rect = TextureRect.new()
	icon_rect.name = "TrackerIcon"
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon_rect)
	title_label = HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.GOLD_TEXT)
	title_label.name = "TrackerTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)
	map_key_chip = _build_keycap("TAB", "전술지도")
	map_key_chip.visible = not DisplayServer.is_touchscreen_available()
	header.add_child(map_key_chip)

	objective_label = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.TEXT)
	objective_label.name = "TrackerObjective"
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(objective_label)

	progress_bar = ProgressBar.new()
	progress_bar.name = "TrackerProgress"
	progress_bar.custom_minimum_size = Vector2(0.0, 4.0)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override(
		"background", HudStyle.panel(Color("#101917"), Color("#263b33"), 2)
	)
	progress_fill = HudStyle.panel(HudStyle.GOLD, HudStyle.GOLD.lightened(0.2), 2)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_bar.visible = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress_bar)

	pip_row = HBoxContainer.new()
	pip_row.name = "TrackerPips"
	pip_row.add_theme_constant_override("separation", 4)
	pip_row.visible = false
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pip_row)

	sub_box = VBoxContainer.new()
	sub_box.name = "TrackerSubs"
	sub_box.add_theme_constant_override("separation", 1)
	sub_box.visible = false
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(sub_box)

	# 목표 전환 펄스 — 카드 위를 골드가 한 번 스치고 사라진다.
	pulse_overlay = ColorRect.new()
	pulse_overlay.name = "TrackerPulse"
	pulse_overlay.color = Color(HudStyle.GOLD.r, HudStyle.GOLD.g, HudStyle.GOLD.b, 0.0)
	pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pulse_overlay)


func _build_keycap(key_text: String, tip: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "TrackerKeycap_%s" % key_text
	chip.add_theme_stylebox_override("panel", HudStyle.keycap())
	chip.tooltip_text = tip
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key_label := HudStyle.label(key_text, HudStyle.TYPE_FOOTNOTE - 1, HudStyle.TEXT_DIM)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(key_label)
	return chip


# state:
#   icon: String(ui_icon_factory 이름) · title: String · objective: String
#   color: Color(강조색) · progress: {value, max}(수치형) · pips: {count, filled}(다단계)
#   subs: [{done: bool, label: String, count: String}]
func set_state(state: Dictionary) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var title := str(state.get("title", ""))
	if title.is_empty():
		panel.visible = false
		return
	panel.visible = true
	var accent: Color = state.get("color", HudStyle.GOLD_TEXT)
	if title != last_title:
		icon_rect.texture = UI_ICONS.get_icon(str(state.get("icon", "raid")), 20, accent)
		_play_pulse()
	title_label.text = title
	title_label.add_theme_color_override("font_color", accent)
	var objective := str(state.get("objective", ""))
	objective_label.text = objective
	objective_label.visible = not objective.is_empty()

	var progress := state.get("progress", {}) as Dictionary
	if not progress.is_empty():
		progress_bar.max_value = maxf(1.0, float(progress.get("max", 1.0)))
		progress_bar.value = clampf(float(progress.get("value", 0.0)), 0.0, progress_bar.max_value)
		progress_fill.bg_color = accent
		progress_fill.border_color = accent.lightened(0.2)
		progress_bar.visible = true
	else:
		progress_bar.visible = false

	var pips := state.get("pips", {}) as Dictionary
	if not pips.is_empty():
		_refresh_pips(int(pips.get("count", 0)), int(pips.get("filled", 0)), accent)
		pip_row.visible = pip_row.get_child_count() > 0
	else:
		pip_row.visible = false

	var subs: Array = state.get("subs", []) as Array
	_refresh_subs(subs)
	last_title = title


func _refresh_pips(count: int, filled: int, accent: Color) -> void:
	count = clampi(count, 0, 8)
	while pip_row.get_child_count() > count:
		var extra := pip_row.get_child(pip_row.get_child_count() - 1)
		pip_row.remove_child(extra)
		extra.queue_free()
	while pip_row.get_child_count() < count:
		var pip := HudStyle.label("●", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_FAINT)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_row.add_child(pip)
	for index in pip_row.get_child_count():
		var pip := pip_row.get_child(index) as Label
		var done := index < filled
		pip.text = "●" if done else "○"
		pip.add_theme_color_override("font_color", accent if done else HudStyle.TEXT_FAINT)


func _refresh_subs(subs: Array) -> void:
	var trimmed := subs.slice(0, MAX_SUB_ROWS)
	var signature_parts: PackedStringArray = []
	for sub_value in trimmed:
		signature_parts.append(str((sub_value as Dictionary).get("label", "")))
	var signature := "|".join(signature_parts)
	if signature != last_sub_signature:
		last_sub_signature = signature
		for child in sub_box.get_children():
			sub_box.remove_child(child)
			child.queue_free()
		for sub_value in trimmed:
			sub_box.add_child(_build_sub_row())
	for index in sub_box.get_child_count():
		var row := sub_box.get_child(index) as HBoxContainer
		var sub := trimmed[index] as Dictionary
		var done := bool(sub.get("done", false))
		var check := row.get_child(0) as Label
		check.text = "✓" if done else "○"
		check.add_theme_color_override("font_color", HudStyle.GREEN if done else HudStyle.TEXT_FAINT)
		var label := row.get_child(1) as Label
		label.text = str(sub.get("label", ""))
		label.add_theme_color_override(
			"font_color", HudStyle.TEXT_FAINT if done else HudStyle.TEXT_DIM
		)
		var count := row.get_child(2) as Label
		count.text = str(sub.get("count", ""))
		count.visible = not count.text.is_empty()
	sub_box.visible = sub_box.get_child_count() > 0


func _build_sub_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var check := HudStyle.label("○", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_FAINT)
	check.custom_minimum_size = Vector2(12, 0)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var label := HudStyle.label("", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var count := HudStyle.label("", HudStyle.TYPE_FOOTNOTE, HudStyle.TEXT_FAINT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	return row


func _play_pulse() -> void:
	# 첫 세팅(빈 제목 → 첫 제목)이나 트리 밖에서는 펄스를 치지 않는다.
	if last_title.is_empty() or pulse_overlay == null or not pulse_overlay.is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - last_pulse_msec < int(PULSE_COOLDOWN * 1000.0):
		return
	last_pulse_msec = now
	pulse_overlay.color.a = 0.16
	var tween := pulse_overlay.create_tween()
	tween.tween_property(pulse_overlay, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)


func content_height() -> float:
	if panel == null or not is_instance_valid(panel):
		return 72.0
	return maxf(52.0, panel.get_combined_minimum_size().y)
