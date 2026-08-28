class_name ShelterUIComponents
extends RefCounted

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const CURRENCY_NAMES := {
	"scrap": "고철",
	"catnip": "캣닢",
	"food": "통조림",
	"churu": "츄르",
}

const CURRENCY_COLORS := {
	"scrap": Color("#b9c4c2"),
	"catnip": Color("#91d46f"),
	"food": Color("#efbd66"),
	"churu": Color("#eba36d"),
}


# 재화 표기 규칙(유저 확정): 아이콘이 이름이다.
# "🥫 통조림 x14"처럼 아이콘 옆에 이름을 또 쓰지 않는다 — 같은 말을 두 번 하는
# 것이고, 그 이름이 자리를 먹어 정작 숫자가 잘렸다. 화면엔 아이콘 + 수치만,
# 이름은 tooltip에 남긴다. show_name은 '아이콘이 없는 재료' 전용 예외다
# (아이콘도 없고 이름도 없으면 무엇의 비용인지 알 길이 없어진다).
static func make_currency_chip(
	currency_id: String,
	value_text: String,
	compact := false,
	show_name := false
) -> PanelContainer:
	return make_resource_chip(
		currency_id,
		str(CURRENCY_NAMES.get(currency_id, currency_id)),
		value_text,
		UI_ICONS.get_icon(currency_id, 42, get_currency_color(currency_id)),
		get_currency_color(currency_id),
		compact,
		show_name
	)


static func make_resource_chip(
	resource_id: String,
	display_name: String,
	value_text: String,
	texture: Texture2D,
	accent: Color,
	compact := false,
	show_name := false
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResourceChip_%s" % resource_id
	# 이름을 뗐으니 칩은 더 좁아도 된다. 컴팩트 72px는 "x80"에서 마지막 글자가
	# 잘리는 한계선이었다 — 아이콘 + 수치만 남은 지금의 하한은 그보다 조금 위다.
	panel.custom_minimum_size = Vector2(
		(86 if compact else 112) if show_name else (66 if compact else 82),
		36 if compact else 40
	)
	# 이름은 화면에서 사라져도 여기 남는다 — "이게 뭐지"는 툴팁이 답한다.
	panel.tooltip_text = "%s x%s" % [display_name, value_text]
	panel.add_theme_stylebox_override(
		"panel",
		_style(Color(0.035, 0.045, 0.042, 0.96), Color(accent, 0.58), 6)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "ResourceIcon_%s" % resource_id
	icon.custom_minimum_size = Vector2(25 if compact else 28, 25 if compact else 28)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	if show_name:
		var name_label := _label(display_name, 11 if compact else 12, Color("#91a39a"))
		name_label.name = "ResourceName_%s" % resource_id
		# 값 라벨이 EXPAND_FILL로 슬랙을 다 먹어 이름이 폭 1px로 붕괴했다
		# ("고철"/"캣닢"/"스코프 렌즈"가 통째로 증발). 실측 폭을 하한으로 박는다.
		name_label.custom_minimum_size.x = ceilf(
			FONT.get_string_size(
				display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11 if compact else 12
			).x
		) + 2.0
		name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.add_child(name_label)

	var value_font_size := 14 if compact else 16
	var value_string := "x%s" % value_text
	var value_label := _label(value_string, value_font_size, accent)
	value_label.name = "ResourceValue_%s" % resource_id
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 재화가 커지면("x240K") 마지막 글자가 5px씩 잘렸다 — 실측 폭을 최소 폭으로
	# 박아 두고, 칩 자체도 그만큼은 넓어지게 한다. 숫자가 잘리면 칩은 무의미하다.
	var value_width := ceilf(
		FONT.get_string_size(
			value_string, HORIZONTAL_ALIGNMENT_LEFT, -1, value_font_size
		).x
	) + 2.0
	value_label.custom_minimum_size.x = value_width
	value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var name_width := 0.0
	if show_name:
		name_width = ceilf(
			FONT.get_string_size(
				display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11 if compact else 12
			).x
		) + 2.0
	var icon_width := 25.0 if compact else 28.0
	var separation := 6.0 * (2.0 if show_name else 1.0)
	panel.custom_minimum_size.x = maxf(
		panel.custom_minimum_size.x,
		8.0 + 9.0 + icon_width + name_width + value_width + separation
	)
	row.add_child(value_label)
	return panel


static func get_currency_color(currency_id: String) -> Color:
	return CURRENCY_COLORS.get(currency_id, Color("#d9e3dc")) as Color


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
